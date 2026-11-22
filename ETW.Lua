-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ZUNI HUB - ETW MODULE v8.6                                        ║
-- ║  Grab check 1s • Bedrock • Auto-Off • Presets                      ║
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
    sell  = Enum.KeyCode.V,
}
local GROUP_ID     = 10587104
local SKIP_MAPTIME = 0

local function Def(k, v) if S[k] == nil then S[k] = v end end
Def("grabInterval", 150)
Def("eatInterval", 300)
Def("throwInterval", 500)
Def("sellTimerInterval", 12000)
Def("smartSellThreshold", 5)
Def("walkInterval", 300)
Def("walkRadius", 40)
Def("walkSpeed", 30)
Def("rewardSpin", true)
Def("skipInterval", 60)
Def("skipStuckTime", 15)
Def("autoPauseAfterSkip", true)
Def("autoPauseDelay", 5)
Def("grabWalkFallback", true)
Def("grabWalkWait", 1.5)
Def("grabStuckTime", 1.5)
Def("walkStuckTime", 2.0)
Def("grabFailMoveDuration", 3.0)
Def("grabFailCooldown", 3.0)
Def("bedrockSkipTime", 4.0)
Def("skipOnSmartSell", false)
Def("autoOffGrabThreshold", 5.0)
Def("autoOffGrabEnabled", true)

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
    if ev:IsA("RemoteEvent") then 
        pcall(function() ev:FireServer() end) 
    elseif ev:IsA("RemoteFunction") then 
        pcall(function() ev:InvokeServer() end) 
    else 
        return false 
    end
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

local function IsOnBedrock()
    local hrp = GetHRP()
    if not hrp then return false end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    if Player.Character then rp.FilterDescendantsInstances = { Player.Character } end
    local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -10, 0), rp)
    return hit and hit.Instance and hit.Instance.Name == "Bedrock"
end

local function IsHRPAnchored()
    local hrp = GetHRP()
    return hrp and hrp.Anchored or false
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
-- MAPA
-- ═══════════════════════════════════════════════════════════════════════
local grabState = { failSince = nil, lastGrabAt = 0, lastPos = nil, stuckSince = nil }
local lastSkip = 0
local pauseToken = 0

local function SetMapPaused(v)
    local ev = GetEvent("SetServerSettings")
    if not ev then return false end
    pcall(function() ev:FireServer({ Paused = v }) end)
    return true
end

local function SkipMap(reason)
    local ev = GetEvent("SetServerSettings")
    if not ev then
        Z.Notify("Skip Map", "Evento SetServerSettings não encontrado.", C.Danger, 3)
        return false
    end
    pcall(function() ev:FireServer({ MapTime = SKIP_MAPTIME }) end)
    lastSkip = tick()
    grabState.failSince = nil
    grabState.stuckSince = nil
    pcall(function() ev:FireServer({ Paused = false }) end)
    Z.Notify("Skip Map", reason or "Mapa pulado.", C.Accent, 2)
    if S.autoPauseAfterSkip then
        pauseToken += 1
        local my = pauseToken
        task.delay(math.max(0.5, S.autoPauseDelay), function()
            if my ~= pauseToken then return end
            if not Z.Alive then return end
            local ok = SetMapPaused(true)
            if ok then
                Z.Notify("Auto Pause", "Mapa pausado após " .. S.autoPauseDelay .. "s do skip.", C.Warning, 2)
            end
        end)
    end
    return true
end

-- ═══════════════════════════════════════════════════════════════════════
-- AUTO-OFF DO GRAB (HRP ancorado + sem crescer + parado)
-- ═══════════════════════════════════════════════════════════════════════
local autoOff = {
    lastSize = nil, sameSizeSince = nil,
    lastPos = nil, stuckSince = nil,
    watching = false, offSince = 0,
}

local function ResetAutoOff()
    autoOff.lastSize = nil
    autoOff.sameSizeSince = nil
    autoOff.lastPos = nil
    autoOff.stuckSince = nil
    autoOff.watching = false
    autoOff.offSince = 0
end

task.spawn(function()
    task.wait(1)
    local okS, RunService = pcall(function() return game:GetService("RunService") end)
    if not okS or not RunService then return end
    
    local conn = RunService.Heartbeat:Connect(function()
        pcall(function()
            if not Z.Alive then return end
            if not S.autoOffGrabEnabled then
                if autoOff.watching then ResetAutoOff() end
                return
            end
            if Features.grab and Features.grab.running then
                autoOff.offSince = 0
                local hrp = GetHRP()
                local pos = hrp and hrp.Position or nil
                local sz = GetSize()
                local now = tick()

                if sz ~= nil then
                    if autoOff.lastSize == nil then
                        autoOff.lastSize = sz
                        autoOff.sameSizeSince = now
                    elseif sz ~= autoOff.lastSize then
                        autoOff.lastSize = sz
                        autoOff.sameSizeSince = now
                    end
                end
                if pos and autoOff.lastPos then
                    local moved = (pos - autoOff.lastPos).Magnitude
                    if moved < 0.5 then
                        if not autoOff.stuckSince then autoOff.stuckSince = now end
                    else
                        autoOff.stuckSince = nil
                    end
                end
                autoOff.lastPos = pos

                local sizeStuck = autoOff.sameSizeSince and (now - autoOff.sameSizeSince >= S.autoOffGrabThreshold)
                local posStuck  = autoOff.stuckSince and (now - autoOff.stuckSince >= S.autoOffGrabThreshold)

                if sizeStuck and posStuck and not autoOff.watching then
                    autoOff.watching = true
                    autoOff.offSince = now
                    SetFeature("grab", false, false)
                    Z.Notify("Auto Grab", "Desligado: sem crescer e parado. Aguardando HRP desancorar.", C.Warning, 4)
                end
                return
            end
            if autoOff.watching then
                local hrp = GetHRP()
                if hrp and not hrp.Anchored then
                    autoOff.watching = false
                    ResetAutoOff()
                    SetFeature("grab", true, false)
                    Z.Notify("Auto Grab", "HRP desancorado. Auto Grab religado.", C.Success, 3)
                end
            end
        end)
    end)
    if conn then Z.Track(conn) end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- GRAB
-- ═══════════════════════════════════════════════════════════════════════
local grabFallback = { walking = false, wasWalkOn = false, moveUntil = 0 }
local grabCooldown = { until_ = 0 }
local bedrockState = { since = nil }

local function StartTempWalk()
    if grabFallback.walking then return end
    grabFallback.wasWalkOn = Features.walk and Features.walk.running or false
    grabFallback.walking = true
    SetFeature("walk", true, true)
end

local function StopTempWalk()
    if not grabFallback.walking then return end
    grabFallback.walking = false
    if not grabFallback.wasWalkOn then
        SetFeature("walk", false, true)
    end
end

local function ResetGrab()
    grabState.failSince = nil
    grabState.stuckSince = nil
    grabState.lastPos = nil
    bedrockState.since = nil
    grabCooldown.until_ = 0
    StopTempWalk()
end

NewFeature("grab", "Auto Grab", function()
    local hrp = GetHRP()
    local pos = hrp and hrp.Position or nil
    local now = tick()

    -- Bedrock
    if IsOnBedrock() then
        if not bedrockState.since then bedrockState.since = now end
        if now - bedrockState.since >= S.bedrockSkipTime then
            SkipMap("Mapa pulado (preso na Bedrock).")
            bedrockState.since = nil
        else
            if not (Features.walk and Features.walk.running) then
                StartTempWalk()
                task.delay(S.grabWalkWait, function()
                    if grabFallback.walking and not (Features.walk and Features.walk.running) then
                        StopTempWalk()
                    end
                end)
            end
        end
        return S.grabInterval / 1000
    end
    bedrockState.since = nil

    -- Tem chunk
    if HasChunk() then
        grabState.failSince = nil
        grabState.stuckSince = nil
        grabState.lastPos = pos
        grabCooldown.until_ = 0
        if grabFallback.walking and now >= grabFallback.moveUntil then
            StopTempWalk()
        end
        return 0.1
    end

    -- Cooldown (após falha)
    if now < grabCooldown.until_ then
        return S.grabInterval / 1000
    end

    -- Travado na posição
    if pos and grabState.lastPos then
        local moved = (pos - grabState.lastPos).Magnitude
        if moved < 0.5 then
            if not grabState.stuckSince then grabState.stuckSince = now end
        else
            grabState.stuckSince = nil
        end
    end
    grabState.lastPos = pos

    -- Tenta pegar
    task.spawn(FireEvent, "Grab")

    -- Verifica falha apenas depois de 1 segundo (1000ms)
    task.delay(1.0, function()
        if not Features.grab or not Features.grab.running then return end
        if HasChunk() then return end -- Deu certo, pegou chunk!
        
        -- Falhou de verdade
        grabCooldown.until_ = tick() + S.grabFailCooldown
        if S.grabWalkFallback and not grabFallback.walking then
            StartTempWalk()
            grabFallback.moveUntil = tick() + S.grabFailMoveDuration
        end
        Z.Notify("Auto Grab", "Falhou ao pegar. Aguardando " .. S.grabFailCooldown .. "s.", C.Warning, 2)
    end)

    -- Se ficou muito tempo parado (sem chunk), teleporta
    if grabState.stuckSince and (now - grabState.stuckSince) >= S.grabStuckTime then
        if pos then
            local target = RandomWalkablePos(pos, S.walkRadius)
            if target and hrp then
                pcall(function() hrp.CFrame = CFrame.new(target) end)
            end
        end
        grabState.stuckSince = nil
        grabState.lastPos = nil
    end

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

-- Smart Sell + SkipOnSmartSell
local smart = { last = -1, stuck = 0 }
NewFeature("smartSell", "Smart Sell (com chunk)", function()
    local hasChunk = HasChunk()
    if not hasChunk then
        smart.last, smart.stuck = -1, 0
        return 1
    end
    local cur = GetSize() or 0
    if cur ~= smart.last then
        smart.last, smart.stuck = cur, 0
    else
        smart.stuck += 1
    end
    if smart.stuck >= S.smartSellThreshold and cur > 0 then
        FireEvent("Sell")
        Z.Notify("Smart Sell", "Vendendo (chunk parado)...", C.Success, 2)
        smart.stuck = 0
        if S.skipOnSmartSell then
            SkipMap("Mapa pulado (Smart Sell).")
        end
        return 2
    end
    return 1
end, {
    exclusive = "sellTimer",
    onStart = function() smart.last, smart.stuck = -1, 0 end,
})

-- ═══════════════════════════════════════════════════════════════════════
-- AUTO WALK
-- ═══════════════════════════════════════════════════════════════════════
local walkState = { target = nil, lastPos = nil, stuckSince = nil, lastMoveAt = 0 }

local function StopMoving()
    local hum, hrp = GetHum(), GetHRP()
    if hum and hrp then hum:MoveTo(hrp.Position) end
    walkState.target = nil
    walkState.stuckSince = nil
end

local function ApplyWalkSpeed()
    local hum = GetHum()
    if hum then hum.WalkSpeed = S.walkSpeed end
    walkState.target = nil
    walkState.lastPos = nil
    walkState.stuckSince = nil
end

NewFeature("walk", "Auto Walk", function()
    local hrp, hum = GetHRP(), GetHum()
    if not (hrp and hum and hum.Health > 0) then return 0.3 end
    if hrp.Anchored then return 0.3 end

    if hum.WalkSpeed ~= S.walkSpeed then hum.WalkSpeed = S.walkSpeed end

    local now = tick()
    local pos = hrp.Position

    if walkState.lastPos then
        local moved = (pos - walkState.lastPos).Magnitude
        if moved < 0.5 then
            if not walkState.stuckSince then walkState.stuckSince = now end
        else
            walkState.stuckSince = nil
        end
    end
    walkState.lastPos = pos

    if walkState.stuckSince and (now - walkState.stuckSince) >= S.walkStuckTime then
        hum.Jump = true
        walkState.target = nil
        walkState.stuckSince = nil
        walkState.lastMoveAt = 0
        return 0.2
    end

    if not walkState.target then
        walkState.target = RandomWalkablePos(pos, S.walkRadius)
        if not walkState.target then return 0.5 end
        walkState.lastMoveAt = now
    end

    hum:MoveTo(walkState.target)

    local flat = Vector3.new(walkState.target.X - pos.X, 0, walkState.target.Z - pos.Z).Magnitude
    if flat < 5 then
        walkState.target = nil
        walkState.stuckSince = nil
        walkState.lastMoveAt = 0
        return S.walkInterval / 1000
    end

    if now - walkState.lastMoveAt > 6 then
        walkState.target = nil
        walkState.stuckSince = nil
        walkState.lastMoveAt = 0
        return 0.2
    end

    return 0.25
end, { onStart = ApplyWalkSpeed, onStop = StopMoving })

-- ═══════════════════════════════════════════════════════════════════════
-- AUTO REWARDS
-- ═══════════════════════════════════════════════════════════════════════
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
                        pcall(function() rewardEvent:FireServer(child) end)
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
                pcall(function() spinEvent:FireServer() end)
            end
        end
    end
    return 1
end)

-- ═══════════════════════════════════════════════════════════════════════
-- SKIP MAP
-- ═══════════════════════════════════════════════════════════════════════
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

NewFeature("skipStuck", "Skip Map (Sem Chunk)", function()
    local fs = grabState.failSince
    if fs and tick() - fs >= S.skipStuckTime and tick() - lastSkip > 3 then
        SkipMap("Mapa pulado (sem chunk por " .. S.skipStuckTime .. "s).")
    end
    return 0.5
end)

-- ═══════════════════════════════════════════════════════════════════════
-- PRESETS
-- ═══════════════════════════════════════════════════════════════════════
local function ApplyPreset(name)
    for key in pairs(Features) do SetFeature(key, false, true) end
    grabState.failSince = nil
    grabState.stuckSince = nil
    grabState.lastPos = nil
    grabCooldown.until_ = 0
    ResetAutoOff()
    StopTempWalk()

    if name == "normal" then
        SetFeature("grab", true, true)
        SetFeature("eat", true, true)
        SetFeature("smartSell", true, true)
        SetFeature("rewards", true, true)
        SetFeature("skipStuck", true, true)
        SetFeature("walk", true, true)
        S.skipOnSmartSell = false
        S.walkSpeed = 30
        S.grabWalkFallback = true
        Z.Notify("Preset", "Normal Farm ativado.", C.Success, 3)
    elseif name == "static" then
        SetFeature("grab", true, true)
        SetFeature("eat", true, true)
        SetFeature("smartSell", true, true)
        SetFeature("rewards", true, true)
        SetFeature("skipStuck", true, true)
        SetFeature("walk", false, true)
        S.skipOnSmartSell = true
        S.walkSpeed = 16
        S.grabWalkFallback = false
        Z.Notify("Preset", "Farm #1 (parado + SkipOnSmartSell) ativado.", C.Success, 3)
    end

    if Z.CurrentTab == "Main" then
        for key, ui in pairs(UI) do
            if ui and ui.Set and Features[key] then
                pcall(function() ui.Set(Features[key].running, true) end)
            end
        end
    end
end

local function LoadPresets()
    Z.Sep("📦  PRESETS")
    Z.Info("Aplica uma combinação pronta. Você pode ajustar depois na aba Main.")
    Z.Button("🌾  Normal Farm (andando)", C.Success, function() ApplyPreset("normal") end)
    Z.Button("🧱  Farm #1 (parado + SkipOnSmartSell)", C.Accent, function() ApplyPreset("static") end)
    Z.Sep("ℹ️  SOBRE")
    Z.Info("Normal Farm: Grab + Eat + Smart Sell + Rewards + Skip sem chunk + Auto Walk.\n" ..
           "Farm #1: o mesmo, mas sem Auto Walk e com SkipOnSmartSell (pula o mapa após cada Smart Sell).")
end

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
    Z.Sep("📊  STATUS")
    local stSize   = Z.Stat("Tamanho", "—")
    local stChunk  = Z.Stat("Chunk", "—")
    local stBed    = Z.Stat("Bedrock", "—")
    local stFail   = Z.Stat("Sem conseguir pegar há", "—")
    local stCd     = Z.Stat("Cooldown do grab", "—")
    local stHrp    = Z.Stat("HRP ancorado", "—")
    local stMap    = Z.Stat("Mapa", "—")
    local stReward = Z.Stat("Próxima reward", "—")
    local stActive = Z.Stat("Funções ativas", "0")
    Z.PageLoop(0.5, function()
        pcall(function()
            local sz = GetSize()
            stSize.Set(sz and tostring(sz) or "—")
            local has = HasChunk()
            stChunk.Set(has and "Sim" or "Não", has and C.Success or C.TextDim)
            local bed = IsOnBedrock()
            stBed.Set(bed and "Sim" or "Não", bed and C.Warning or C.TextDim)
            local fs = grabState.failSince
            stFail.Set(fs and (math.floor(tick() - fs) .. " s") or "—", fs and C.Warning or C.TextDim)
            local cd = grabCooldown.until_ - tick()
            stCd.Set(cd > 0 and (string.format("%.1f s", cd)) or "—", cd > 0 and C.Warning or C.TextDim)
            local anch = IsHRPAnchored()
            stHrp.Set(anch and "Sim" or "Não", anch and C.Danger or C.Success)
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
    end)

    Z.Sep("🎛️  CONTROLES RÁPIDOS")
    Z.Button("▶  Ativar farm completo (Grab + Eat + Smart Sell + Rewards)", C.Success, function()
        for _, k in ipairs({ "grab", "eat", "smartSell", "rewards" }) do SetFeature(k, true, true) end
        Z.Notify("ETW", "Farm completo ativado.", C.Success, 2)
    end)
    Z.Button("⏭  Pular mapa agora", C.Accent, function() SkipMap("Mapa pulado.") end)
    Z.Button("⏹  Desligar tudo", C.Danger, function()
        for key in pairs(Features) do SetFeature(key, false, true) end
        ResetAutoOff()
        Z.Notify("ETW", "Todas as funções desligadas.", C.TextDim, 2)
    end)

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

    Z.Toggle("Auto Pause após Skip", S.autoPauseAfterSkip, function(v)
        S.autoPauseAfterSkip = v
    end, "Pausa o mapa automaticamente alguns segundos depois de pular")
    Z.Slider("Delay do pause", 1, 30, S.autoPauseDelay, function(v)
        S.autoPauseDelay = v
    end, { suffix = " s" })

    FeatureToggle("skipTimer", "Auto Skip Map (por tempo)", "Pula o mapa a cada X segundos")
    Z.Slider("Pular a cada", 5, 900, S.skipInterval, function(v) S.skipInterval = v end, { step = 5, suffix = " s" })

    FeatureToggle("skipStuck", "Auto Skip Map (sem chunk)", "Pula se tentar pegar e não conseguir por X s")
    Z.Slider("Tempo sem pegar chunk", 3, 120, S.skipStuckTime, function(v) S.skipStuckTime = v end, { suffix = " s" })

    Z.Sep("🌾  COLETA — AUTO GRAB")
    FeatureToggle("grab", "Auto Grab", "Tenta pegar chunk. Se falhar, entra em cooldown e (opcional) anda.")
    Z.Slider("Intervalo entre tentativas", 50, 3000, S.grabInterval, function(v) S.grabInterval = v end, { step = 25, suffix = " ms" })

    Z.Slider("Cooldown após falha", 0.5, 15, S.grabFailCooldown, function(v)
        S.grabFailCooldown = v
    end, { step = 0.5, suffix = " s" })
    Z.Info("Depois de tentar pegar e não conseguir chunk, o Grab fica sem tentar por esse tempo. O script aguarda 1s antes de confirmar que falhou.")

    Z.Toggle("Movimento aleatório após falha", S.grabWalkFallback, function(v)
        S.grabWalkFallback = v
    end, "Se tentar pegar e não conseguir chunk, anda aleatoriamente por alguns segundos")
    Z.Slider("Duração do movimento", 0.5, 10, S.grabFailMoveDuration, function(v)
        S.grabFailMoveDuration = v
    end, { step = 0.5, suffix = " s" })
    Z.Slider("Tempo para considerar travado", 0.5, 5, S.grabStuckTime, function(v)
        S.grabStuckTime = v
    end, { step = 0.1, suffix = " s" })
    Z.Slider("Tempo na Bedrock até pular", 1, 30, S.bedrockSkipTime, function(v)
        S.bedrockSkipTime = v
    end, { step = 0.5, suffix = " s" })

    Z.Sep("⏸️  AUTO-OFF DO GRAB")
    Z.Toggle("Desligar grab se parado e sem crescer", S.autoOffGrabEnabled, function(v)
        S.autoOffGrabEnabled = v
        if not v then ResetAutoOff() end
    end, "Desliga o Auto Grab quando o jogador fica parado e o tamanho não cresce")
    Z.Slider("Tempo sem crescer + parado", 1, 30, S.autoOffGrabThreshold, function(v)
        S.autoOffGrabThreshold = v
    end, { step = 0.5, suffix = " s" })
    Z.Info("Quando o Grab é desligado por esse motivo, ele só religa sozinho quando o HRP do jogador desancorar.")

    Z.Sep("🍽️  COMER — AUTO EAT")
    FeatureToggle("eat", "Auto Eat", "Come automaticamente")
    Z.Slider("Intervalo", 100, 3000, S.eatInterval, function(v) S.eatInterval = v end, { step = 50, suffix = " ms" })

    Z.Sep("🎁  REWARDS")
    FeatureToggle("rewards", "Auto Redeem Rewards", "Resgata as rewards por tempo assim que ficam prontas")
    Z.Toggle("Incluir giro do grupo (Spin)", S.rewardSpin, function(v) S.rewardSpin = v end, "Só funciona se você estiver no grupo do jogo")

    Z.Sep("💰  VENDA — AUTO SELL")
    FeatureToggle("sellTimer", "Auto Sell (Timer)", "Vende em intervalos fixos")
    Z.Slider("Vender a cada", 1000, 60000, S.sellTimerInterval, function(v) S.sellTimerInterval = v end, { step = 500, suffix = " ms" })
    FeatureToggle("smartSell", "Smart Sell (com chunk)", "Vende quando você está com chunk na mão e o tamanho parou de crescer")
    Z.Slider("Considerar parado após", 2, 20, S.smartSellThreshold, function(v) S.smartSellThreshold = v end, { suffix = " s" })
    Z.Toggle("SkipOnSmartSell", S.skipOnSmartSell, function(v)
        S.skipOnSmartSell = v
    end, "Pula o mapa assim que o Smart Sell vender")

    Z.Sep("🗑️  EXTRAS — AUTO THROW")
    FeatureToggle("throw", "Auto Throw", "Joga fora o que está na mão")
    Z.Slider("Intervalo", 100, 3000, S.throwInterval, function(v) S.throwInterval = v end, { step = 50, suffix = " ms" })

    Z.Sep("🚶  MOVIMENTO — AUTO WALK")
    FeatureToggle("walk", "Auto Walk", "Anda de verdade com MoveTo contínuo + anti-travamento")
    Z.Slider("WalkSpeed no walk", 16, 150, S.walkSpeed, function(v) S.walkSpeed = v end, { step = 2, suffix = " studs/s" })
    Z.Slider("Raio de caminhada", 20, 150, S.walkRadius, function(v) S.walkRadius = v end, { step = 5, suffix = " studs" })
    Z.Slider("Pausa entre destinos", 0, 3000, S.walkInterval, function(v) S.walkInterval = v end, { step = 50, suffix = " ms" })
    Z.Slider("Tempo para considerar travado no walk", 1, 10, S.walkStuckTime, function(v) S.walkStuckTime = v end, { step = 0.5, suffix = " s" })

    Z.Sep("⌨️  ATALHOS")
    Z.Info(string.format(
        "%s = Auto Grab   •   %s = Auto Eat   •   %s = Auto Throw\n%s = Auto Sell (Timer → Smart → Desligado)",
        Keys.grab.Name, Keys.eat.Name, Keys.throw.Name, Keys.sell.Name
    ))
end

Z.AddTab("Main", "🎮", LoadMain)
Z.AddTab("Presets", "📦", LoadPresets)

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
Z.Notify("Zuni Hub", "Módulo ETW v8.6 carregado!", C.Success, 3)
print("⚡ ETW Module v8.6 iniciado")
