-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ZUNI HUB - ETW MODULE v7.1                                        ║
-- ║  Grab rápido • Walk real • Auto Rewards • Skip / Pause / Inf Map    ║
-- ╚══════════════════════════════════════════════════════════════════════╝

if not _G.ZuniHub or not _G.ZuniHub.Ready then
    warn("[ETW] Base não está pronta!")
    return
end

local Z = _G.ZuniHub
if Z.ETWLoaded then return end
Z.ETWLoaded = true
Z.ModuleName = "ETW"

local C      = Z.Colors
local S      = Z.SavedStates
local UI     = Z.UI
local Player = game:GetService("Players").LocalPlayer
local UIS    = game:GetService("UserInputService")
local RS     = game:GetService("ReplicatedStorage")

-- ═══════════════════════════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════════════════════════
local Keys = {
    grab  = Enum.KeyCode.G,
    eat   = Enum.KeyCode.E,
    throw = Enum.KeyCode.T,
    sell  = Enum.KeyCode.V, -- alterna: Timer -> Smart -> Desligado
}
local GROUP_ID     = 10587104 -- grupo exigido pro giro (spin) das rewards
local SKIP_MAPTIME = 0        -- valor de MapTime enviado no Skip Map

local function Def(k, v) if S[k] == nil then S[k] = v end end
Def("grabInterval", 150)
Def("eatInterval", 300)
Def("throwInterval", 500)
Def("sellTimerInterval", 12000)
Def("smartSellThreshold", 5)
Def("walkInterval", 300)
Def("walkRadius", 40)
Def("walkSpeed", 30)            -- WalkSpeed aplicado enquanto o Auto Walk está ligado
Def("rewardSpin", true)
Def("skipInterval", 60)
Def("skipStuckTime", 15)

-- ═══════════════════════════════════════════════════════════════════════
-- HELPERS DO JOGO
-- ═══════════════════════════════════════════════════════════════════════
local function GetHRP() local c = Player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHum() local c = Player.Character return c and c:FindFirstChildOfClass("Humanoid") end

local function FireEvent(name)
    local c = Player.Character
    local evs = c and c:FindFirstChild("Events")
    local ev = evs and evs:FindFirstChild(name)
    if not ev then return false end
    if ev:IsA("RemoteEvent") then ev:FireServer()
    elseif ev:IsA("RemoteFunction") then ev:InvokeServer()
    else return false end
    return true
end

local function GetEvent(name)
    local evs = RS:FindFirstChild("Events")
    return evs and evs:FindFirstChild(name) or nil
end
local function GetServerSettings() return RS:FindFirstChild("ServerSettings") end

local function HasChunk()
    local chunks = workspace:FindFirstChild("Chunks")
    if not chunks then return false end
    for _, c in ipairs(chunks:GetChildren()) do
        local o = c:FindFirstChild("Owner")
        if o and o:IsA("ObjectValue") and o.Value == Player then return true end
    end
    return false
end

local function GetSize()
    local ls = Player:FindFirstChild("leaderstats")
    local sz = ls and ls:FindFirstChild("Size")
    return sz and tonumber(sz.Value) or nil
end

local function Fmt(sec)
    sec = math.max(0, math.floor(sec))
    local h, m, s = sec // 3600, (sec % 3600) // 60, sec % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%02d:%02d", m, s)
end

local function FindGround(origin)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    if Player.Character then rp.FilterDescendantsInstances = { Player.Character } end
    local hit = workspace:Raycast(origin, Vector3.new(0, -1000, 0), rp)
    return hit and (hit.Position + Vector3.new(0, 3.5, 0)) or nil
end

local function RandomWalkablePos(origin, radius)
    radius = math.max(16, radius)
    for _ = 1, 20 do
        local ang = math.random() * 2 * math.pi
        local dist = math.random(15, radius)
        local pos = FindGround(Vector3.new(origin.X + math.cos(ang) * dist, origin.Y + 500, origin.Z + math.sin(ang) * dist))
        if pos then return pos end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════
-- SISTEMA DE FEATURES
-- ═══════════════════════════════════════════════════════════════════════
local Features = {}

local function NewFeature(key, label, body, opts)
    opts = opts or {}
    Features[key] = {
        key = key, label = label, body = body, running = false, gen = 0,
        exclusive = opts.exclusive, onStart = opts.onStart, onStop = opts.onStop,
    }
end

local function RunLoop(ft)
    ft.gen += 1
    local my = ft.gen
    task.spawn(function()
        while ft.running and ft.gen == my and Z.Alive do
            local ok, res = pcall(ft.body)
            local wait = 0.25
            if ok then
                wait = tonumber(res) or wait
            else
                warn("[ETW] " .. ft.label .. ": " .. tostring(res))
                wait = 1
            end
            task.wait(math.max(0.03, wait))
        end
    end)
end

local function SetFeature(key, v, quiet)
    local ft = Features[key]
    if not ft then return end
    v = not not v
    if v == ft.running then return end

    if v and ft.exclusive then SetFeature(ft.exclusive, false, true) end

    ft.running = v
    if v then
        if ft.onStart then pcall(ft.onStart) end
        RunLoop(ft)
    else
        ft.gen += 1
        if ft.onStop then pcall(ft.onStop) end
    end

    local ui = UI[key]
    if ui and ui.Frame.Parent then ui.Set(v, true) end
    if not quiet then
        Z.Notify(ft.label, v and "Ativado" or "Desativado", v and C.Success or C.TextDim, 1.5)
    end
end

local function CountActive()
    local n = 0
    for _, ft in pairs(Features) do if ft.running then n += 1 end end
    return n
end

-- ═══════════════════════════════════════════════════════════════════════
-- MAPA: SKIP / PAUSE / INF MAP (SetServerSettings)
-- ═══════════════════════════════════════════════════════════════════════
local grabState = { failSince = nil }
local lastSkip = 0
local infMapApplied = false

local function SkipMap(reason)
    local ev = GetEvent("SetServerSettings")
    if not ev then
        Z.Notify("Skip Map", "Evento SetServerSettings não encontrado.", C.Danger, 3)
        return false
    end
    ev:FireServer({ MapTime = SKIP_MAPTIME })
    lastSkip = tick()
    grabState.failSince = nil
    Z.Notify("Skip Map", reason or "Mapa pulado.", C.Accent, 2)
    return true
end

local function SetMapPaused(v)
    local ev = GetEvent("SetServerSettings")
    if not ev then
        Z.Notify("Pause Map", "Evento SetServerSettings não encontrado.", C.Danger, 3)
        return false
    end
    ev:FireServer({ Paused = v })
    return true
end

-- ═══════════════════════════════════════════════════════════════════════
-- FEATURES
-- ═══════════════════════════════════════════════════════════════════════

-- Auto Grab
local function ResetGrab() grabState.failSince = nil end
NewFeature("grab", "Auto Grab", function()
    if HasChunk() then
        grabState.failSince = nil
        return 0.1
    end
    if not grabState.failSince then grabState.failSince = tick() end
    task.spawn(FireEvent, "Grab")
    return S.grabInterval / 1000
end, { onStart = ResetGrab, onStop = ResetGrab })

NewFeature("eat", "Auto Eat", function()
    FireEvent("Eat")
    return S.eatInterval / 1000
end)

NewFeature("throw", "Auto Throw", function()
    FireEvent("Throw")
    return S.throwInterval / 1000
end)

NewFeature("sellTimer", "Auto Sell (Timer)", function()
    FireEvent("Sell")
    return S.sellTimerInterval / 1000
end, { exclusive = "smartSell" })

local smart = { last = -1, stuck = 0 }
NewFeature("smartSell", "Smart Sell", function()
    local cur = GetSize() or 0
    if cur ~= smart.last then
        smart.last, smart.stuck = cur, 0
    else
        smart.stuck += 1
    end
    if smart.stuck >= S.smartSellThreshold and cur > 0 then
        FireEvent("Sell")
        Z.Notify("Smart Sell", "Vendendo...", C.Success, 2)
        smart.stuck = 0
        return 2
    end
    return 1
end, {
    exclusive = "sellTimer",
    onStart = function() smart.last, smart.stuck = -1, 0 end,
})

-- Auto Walk (MoveTo respeita WalkSpeed; aplicamos WalkSpeed ao iniciar)
local function StopMoving()
    local hum, hrp = GetHum(), GetHRP()
    if hum and hrp then hum:MoveTo(hrp.Position) end
end

local function ApplyWalkSpeed()
    local hum = GetHum()
    if hum then hum.WalkSpeed = S.walkSpeed end
end

NewFeature("walk", "Auto Walk", function()
    local hrp, hum = GetHRP(), GetHum()
    if not (hrp and hum and hum.Health > 0) then return 0.5 end

    -- Garante que o WalkSpeed escolhido está aplicado (MoveTo usa ele nativamente)
    if hum.WalkSpeed ~= S.walkSpeed then hum.WalkSpeed = S.walkSpeed end

    local target = RandomWalkablePos(hrp.Position, S.walkRadius)
    if not target then return 0.5 end

    hum:MoveTo(target)
    local startT, lastCheck, lastPos = tick(), tick(), hrp.Position
    while Features.walk.running and Z.Alive and tick() - startT < 8 do
        task.wait(0.15)
        hrp, hum = GetHRP(), GetHum()
        if not (hrp and hum) or hum.Health <= 0 then break end
        local flat = Vector3.new(target.X - hrp.Position.X, 0, target.Z - hrp.Position.Z).Magnitude
        if flat < 4 then break end
        if tick() - lastCheck > 1 then
            if (hrp.Position - lastPos).Magnitude < 1 then hum.Jump = true end
            lastPos, lastCheck = hrp.Position, tick()
        end
    end
    return S.walkInterval / 1000
end, { onStart = ApplyWalkSpeed, onStop = StopMoving })

-- Auto Redeem Rewards
local rewardSent, lastSpin = {}, 0
local RewardInfo = nil
local groupOk, groupCheckedAt = false, -math.huge

local function GetRewardInfo()
    if RewardInfo == nil then
        local m = RS:FindFirstChild("RewardInfo")
        if m then
            local ok, r = pcall(require, m)
            RewardInfo = ok and r or false
        end
    end
    return RewardInfo or nil
end

local function InGroup()
    if groupOk then return true end
    if tick() - groupCheckedAt > 30 then
        groupCheckedAt = tick()
        local ok, r = pcall(function() return Player:IsInGroup(GROUP_ID) end)
        groupOk = ok and r or false
    end
    return groupOk
end

NewFeature("rewards", "Auto Redeem Rewards", function()
    local tr = Player:FindFirstChild("TimedRewards")
    local rewardEvent = GetEvent("RewardEvent")
    if tr and rewardEvent then
        for _, child in ipairs(tr:GetChildren()) do
            if child:IsA("ValueBase") then
                local v = child.Value
                if type(v) == "number" and v >= 0 and v <= os.time() then
                    local sent = rewardSent[child]
                    if not sent or tick() - sent > 3 then
                        rewardSent[child] = tick()
                        rewardEvent:FireServer(child)
                        task.wait(0.4)
                    end
                end
            end
        end
    end

    if S.rewardSpin and tick() - lastSpin > 8 then
        local info = GetRewardInfo()
        local stats = Player:FindFirstChild("Stats")
        local last = stats and stats:FindFirstChild("LastGroupSpin")
        local spinEvent = GetEvent("SpinEvent")
        if info and info.GroupInterval and last and spinEvent and InGroup() then
            local seed = math.floor(os.time() / info.GroupInterval)
            if last.Value < seed * info.GroupInterval then
                lastSpin = tick()
                spinEvent:FireServer()
            end
        end
    end
    return 1
end)

-- Skip Map por tempo
local skipNext = 0
NewFeature("skipTimer", "Skip Map (Tempo)", function()
    local now = tick()
    if skipNext - now > S.skipInterval then skipNext = now + S.skipInterval end
    if now >= skipNext then
        SkipMap("Mapa pulado (tempo).")
        skipNext = tick() + S.skipInterval
    end
    return 0.5
end, { onStart = function() skipNext = tick() + S.skipInterval end })

-- Skip Map quando não consegue pegar chunk
NewFeature("skipStuck", "Skip Map (Sem Chunk)", function()
    local fs = grabState.failSince
    if fs and tick() - fs >= S.skipStuckTime and tick() - lastSkip > 3 then
        SkipMap("Mapa pulado (sem chunk por " .. S.skipStuckTime .. "s).")
    end
    return 0.5
end)

-- Inf Map: aplica MapTime = 9999 uma única vez após o mapa resetar (MapTime == 0)
NewFeature("infMap", "Inf Map", function()
    local ss = GetServerSettings()
    if not ss then return 1 end
    local mapTime = ss:FindFirstChild("MapTime")
    if not mapTime then return 1 end

    -- Detecta reset: MapTime voltou para 0
    if mapTime.Value == 0 then
        infMapApplied = false
    end

    if not infMapApplied and mapTime.Value == 0 then
        local ev = GetEvent("SetServerSettings")
        if ev then
            ev:FireServer({ MapTime = 9999 })
            infMapApplied = true
            Z.Notify("Inf Map", "MapTime definido para 9999.", C.Accent, 2)
        end
    end
    return 0.5
end, {
    onStart = function() infMapApplied = false end,
    onStop  = function() infMapApplied = false end,
})

-- ═══════════════════════════════════════════════════════════════════════
-- ABA MAIN
-- ═══════════════════════════════════════════════════════════════════════
local function FeatureToggle(key, name, desc)
    UI[key] = Z.Toggle(name, Features[key].running, function(v) SetFeature(key, v, true) end, desc)
end

local function NextRewardIn()
    local tr = Player:FindFirstChild("TimedRewards")
    if not tr then return nil end
    local best
    for _, c in ipairs(tr:GetChildren()) do
        if c:IsA("ValueBase") then
            local v = c.Value
            if type(v) == "number" and v >= 0 and (not best or v < best) then best = v end
        end
    end
    return best and (best - os.time()) or nil
end

local function LoadMain()
    -- STATUS --------------------------------------------------------------
    Z.Sep("📊  STATUS")
    local stSize   = Z.Stat("Tamanho", "—")
    local stChunk  = Z.Stat("Chunk", "—")
    local stFail   = Z.Stat("Sem conseguir pegar há", "—")
    local stMap    = Z.Stat("Mapa", "—")
    local stReward = Z.Stat("Próxima reward", "—")
    local stActive = Z.Stat("Funções ativas", "0")
    Z.PageLoop(0.5, function()
        local sz = GetSize()
        stSize.Set(sz and tostring(sz) or "—")
        local has = HasChunk()
        stChunk.Set(has and "Sim" or "Não", has and C.Success or C.TextDim)
        local fs = grabState.failSince
        stFail.Set(fs and (math.floor(tick() - fs) .. " s") or "—", fs and C.Warning or C.TextDim)
        local ss = GetServerSettings()
        local paused = ss and ss:FindFirstChild("Paused")
        if paused then stMap.Set(paused.Value and "Pausado" or "Rodando", paused.Value and C.Danger or C.Success) end
        local nr = NextRewardIn()
        if nr == nil then stReward.Set("—")
        elseif nr <= 0 then stReward.Set("Pronta!", C.Success)
        else stReward.Set(Fmt(nr)) end
        local n = CountActive()
        stActive.Set(tostring(n), n > 0 and C.Success or C.TextDim)
    end)

    -- CONTROLES RÁPIDOS ---------------------------------------------------
    Z.Sep("🎛️  CONTROLES RÁPIDOS")
    Z.Button("▶  Ativar farm completo (Grab + Eat + Smart Sell + Rewards)", C.Success, function()
        for _, k in ipairs({ "grab", "eat", "smartSell", "rewards" }) do SetFeature(k, true, true) end
        Z.Notify("ETW", "Farm completo ativado.", C.Success, 2)
    end)
    Z.Button("⏭  Pular mapa agora", C.Accent, function() SkipMap("Mapa pulado.") end)
    Z.Button("⏹  Desligar tudo", C.Danger, function()
        for key in pairs(Features) do SetFeature(key, false, true) end
        Z.Notify("ETW", "Todas as funções desligadas.", C.TextDim, 2)
    end)

    -- MAPA ----------------------------------------------------------------
    Z.Sep("🗺️  MAPA")
    local ss = GetServerSettings()
    local paused = ss and ss:FindFirstChild("Paused")
    if paused then
        UI.pause = Z.Toggle("Pausar mapa", paused.Value, function(v)
            if not SetMapPaused(v) and UI.pause then UI.pause.Set(not v, true) end
        end, "Pausa / retoma o tempo do mapa")
        Z.PageTrack(paused.Changed:Connect(function(val)
            if UI.pause and UI.pause.Frame.Parent then UI.pause.Set(val, true) end
        end))
    else
        Z.Info("⚠ ServerSettings.Paused não encontrado neste servidor.")
    end

    FeatureToggle("skipTimer", "Auto Skip Map (por tempo)", "Pula o mapa a cada X segundos")
    Z.Slider("Pular a cada", 5, 900, S.skipInterval, function(v) S.skipInterval = v end, { step = 5, suffix = " s" })

    FeatureToggle("skipStuck", "Auto Skip Map (sem chunk)", "Pula se tentar pegar e não conseguir por X s")
    Z.Slider("Tempo sem pegar chunk", 3, 120, S.skipStuckTime, function(v) S.skipStuckTime = v end, { suffix = " s" })

    FeatureToggle("infMap", "Inf Map", "Define MapTime = 9999 quando o mapa reseta")
    Z.Info("Quando o mapa resetar (MapTime = 0), envia 9999 uma única vez. Precisa estar ligado.")

    -- COLETA --------------------------------------------------------------
    Z.Sep("🌾  COLETA — AUTO GRAB")
    FeatureToggle("grab", "Auto Grab", "Tenta pegar chunk sem parar até conseguir")
    Z.Slider("Intervalo entre tentativas", 50, 3000, S.grabInterval, function(v) S.grabInterval = v end, { step = 25, suffix = " ms" })

    Z.Sep("🍽️  COMER — AUTO EAT")
    FeatureToggle("eat", "Auto Eat", "Come automaticamente")
    Z.Slider("Intervalo", 100, 3000, S.eatInterval, function(v) S.eatInterval = v end, { step = 50, suffix = " ms" })

    -- REWARDS -------------------------------------------------------------
    Z.Sep("🎁  REWARDS")
    FeatureToggle("rewards", "Auto Redeem Rewards", "Resgata as rewards por tempo assim que ficam prontas")
    Z.Toggle("Incluir giro do grupo (Spin)", S.rewardSpin, function(v) S.rewardSpin = v end, "Só funciona se você estiver no grupo do jogo")

    -- VENDA ---------------------------------------------------------------
    Z.Sep("💰  VENDA — AUTO SELL")
    FeatureToggle("sellTimer", "Auto Sell (Timer)", "Vende em intervalos fixos")
    Z.Slider("Vender a cada", 1000, 60000, S.sellTimerInterval, function(v) S.sellTimerInterval = v end, { step = 500, suffix = " ms" })
    FeatureToggle("smartSell", "Smart Sell (Tamanho)", "Vende quando o tamanho para de crescer")
    Z.Slider("Considerar parado após", 2, 20, S.smartSellThreshold, function(v) S.smartSellThreshold = v end, { suffix = " s" })

    -- EXTRAS --------------------------------------------------------------
    Z.Sep("🗑️  EXTRAS — AUTO THROW")
    FeatureToggle("throw", "Auto Throw", "Joga fora o que está na mão")
    Z.Slider("Intervalo", 100, 3000, S.throwInterval, function(v) S.throwInterval = v end, { step = 50, suffix = " ms" })

    Z.Sep("🚶  MOVIMENTO — AUTO WALK")
    FeatureToggle("walk", "Auto Walk", "Anda de verdade até pontos aleatórios (usa MoveTo + WalkSpeed)")
    Z.Slider("WalkSpeed no walk", 16, 150, S.walkSpeed, function(v) S.walkSpeed = v end, { step = 2, suffix = " studs/s" })
    Z.Slider("Raio de caminhada", 20, 150, S.walkRadius, function(v) S.walkRadius = v end, { step = 5, suffix = " studs" })
    Z.Slider("Pausa entre destinos", 0, 3000, S.walkInterval, function(v) S.walkInterval = v end, { step = 50, suffix = " ms" })

    -- ATALHOS -------------------------------------------------------------
    Z.Sep("⌨️  ATALHOS")
    Z.Info(string.format(
        "%s = Auto Grab   •   %s = Auto Eat   •   %s = Auto Throw\n%s = Auto Sell (Timer → Smart → Desligado)",
        Keys.grab.Name, Keys.eat.Name, Keys.throw.Name, Keys.sell.Name
    ))
end

Z.AddTab("Main", "🎮", LoadMain)

-- ═══════════════════════════════════════════════════════════════════════
-- ATALHOS DE TECLADO
-- ═══════════════════════════════════════════════════════════════════════
local function Flip(key) SetFeature(key, not Features[key].running) end

Z.Track(UIS.InputBegan:Connect(function(input, gpe)
    if gpe or not Z.Alive then return end
    local k = input.KeyCode
    if k == Keys.grab then Flip("grab")
    elseif k == Keys.eat then Flip("eat")
    elseif k == Keys.throw then Flip("throw")
    elseif k == Keys.sell then
        local t, s = Features.sellTimer.running, Features.smartSell.running
        if not t and not s then SetFeature("sellTimer", true)
        elseif t then SetFeature("smartSell", true)
        else SetFeature("smartSell", false) end
    end
end))

Z.SelectTab("Main")
Z.Notify("Zuni Hub", "Módulo ETW v7.1 carregado!", C.Success, 3)
print("⚡ ETW Module v7.1 iniciado")
