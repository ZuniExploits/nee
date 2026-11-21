-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ZUNI HUB - ETW MODULE v6.0                                        ║
-- ║  Farm automático com UI organizada, status ao vivo e atalhos       ║
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

-- ═══════════════════════════════════════════════════════════════════════
-- CONFIG (mude as teclas aqui se quiser)
-- ═══════════════════════════════════════════════════════════════════════
local Keys = {
    grab  = Enum.KeyCode.G,
    eat   = Enum.KeyCode.E,
    throw = Enum.KeyCode.T,
    sell  = Enum.KeyCode.V, -- alterna: Timer -> Smart -> Desligado
}

local function Def(k, v) if S[k] == nil then S[k] = v end end
Def("grabInterval", 500)   Def("grabPauseDuration", 5)
Def("eatInterval", 300)
Def("throwInterval", 500)
Def("sellTimerInterval", 12000)
Def("smartSellThreshold", 5)
Def("walkInterval", 800)

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

local function FindGround(origin)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    if Player.Character then rp.FilterDescendantsInstances = { Player.Character } end
    local hit = workspace:Raycast(origin, Vector3.new(0, -1000, 0), rp)
    return hit and (hit.Position + Vector3.new(0, 3.5, 0)) or nil
end

local function RandomWalkablePos(origin, radius)
    for _ = 1, 20 do
        local ang = math.random() * 2 * math.pi
        local dist = math.random(15, radius)
        local pos = FindGround(Vector3.new(origin.X + math.cos(ang) * dist, origin.Y + 500, origin.Z + math.sin(ang) * dist))
        if pos then return pos end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════
-- SISTEMA DE FEATURES (um loop genérico para todas as funções)
-- body() roda em loop e devolve quantos segundos esperar até a próxima volta
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
            task.wait(math.max(0.05, wait))
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

-- Auto Grab: pega quando não há chunk; se falhar, pausa um tempo
NewFeature("grab", "Auto Grab", function()
    if not HasChunk() then
        FireEvent("Grab")
        task.wait(0.35)
        if not HasChunk() then return S.grabPauseDuration end
    end
    return S.grabInterval / 1000
end)

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

local function StopMoving()
    local hum, hrp = GetHum(), GetHRP()
    if hum and hrp then hum:MoveTo(hrp.Position) end
end
NewFeature("walk", "Auto Walk", function()
    local hrp, hum = GetHRP(), GetHum()
    if hrp and hum and hum.Health > 0 then
        local target = RandomWalkablePos(hrp.Position, 30)
        if target then
            hum:MoveTo(target)
            return S.walkInterval / 1000
        end
    end
    return 0.5
end, { onStop = StopMoving })

-- ═══════════════════════════════════════════════════════════════════════
-- ABA MAIN
-- ═══════════════════════════════════════════════════════════════════════
local function FeatureToggle(key, name, desc)
    UI[key] = Z.Toggle(name, Features[key].running, function(v) SetFeature(key, v, true) end, desc)
end

local function LoadMain()
    -- STATUS --------------------------------------------------------------
    Z.Sep("📊  STATUS")
    local stSize   = Z.Stat("Tamanho", "—")
    local stChunk  = Z.Stat("Chunk", "—")
    local stActive = Z.Stat("Funções ativas", "0")
    Z.PageLoop(0.5, function()
        local sz = GetSize()
        stSize.Set(sz and tostring(sz) or "—")
        local has = HasChunk()
        stChunk.Set(has and "Sim" or "Não", has and C.Success or C.TextDim)
        local n = CountActive()
        stActive.Set(tostring(n), n > 0 and C.Success or C.TextDim)
    end)

    -- CONTROLES RÁPIDOS ---------------------------------------------------
    Z.Sep("🎛️  CONTROLES RÁPIDOS")
    Z.Button("▶  Ativar farm completo (Grab + Eat + Smart Sell)", C.Success, function()
        SetFeature("grab", true, true)
        SetFeature("eat", true, true)
        SetFeature("smartSell", true, true)
        Z.Notify("ETW", "Farm completo ativado.", C.Success, 2)
    end)
    Z.Button("⏹  Desligar tudo", C.Danger, function()
        for key in pairs(Features) do SetFeature(key, false, true) end
        Z.Notify("ETW", "Todas as funções desligadas.", C.TextDim, 2)
    end)

    -- COLETA --------------------------------------------------------------
    Z.Sep("🌾  COLETA — AUTO GRAB")
    FeatureToggle("grab", "Auto Grab", "Pega objetos automaticamente")
    Z.Slider("Intervalo", 100, 3000, S.grabInterval, function(v) S.grabInterval = v end, { step = 50, suffix = " ms" })

    Z.Sep("🍽️  COMER — AUTO EAT")
    FeatureToggle("eat", "Auto Eat", "Come automaticamente")
    Z.Slider("Intervalo", 100, 3000, S.eatInterval, function(v) S.eatInterval = v end, { step = 50, suffix = " ms" })

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
    FeatureToggle("walk", "Auto Walk", "Anda aleatoriamente pelo mapa")
    Z.Slider("Intervalo de passos", 200, 3000, S.walkInterval, function(v) S.walkInterval = v end, { step = 50, suffix = " ms" })

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
Z.Notify("Zuni Hub", "Módulo ETW v6.0 carregado!", C.Success, 3)
print("⚡ ETW Module v6.0 iniciado")
