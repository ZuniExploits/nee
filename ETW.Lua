-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ZUNI HUB - ETW MODULE (v5.0)                                      ║
-- ║  Separadores visuais, UI bonita, Otimizado                         ║
-- ╚══════════════════════════════════════════════════════════════════════╝

if not _G.ZuniHub or not _G.ZuniHub.Ready then
    warn("[ETW] Base não pronta!")
    return
end

local Z = _G.ZuniHub
local C = Z.Colors
local S = Z.SavedStates
local Player = game.Players.LocalPlayer

local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

-- Defaults
local function Def(k, v) if S[k] == nil then S[k] = v end end
Def("grabActive", false) Def("grabInterval", 500) Def("grabPauseDuration", 5)
Def("eatActive", false) Def("eatInterval", 300)
Def("throwActive", false) Def("throwInterval", 500)
Def("sellTimerActive", false) Def("sellTimerInterval", 12000)
Def("smartSellActive", false) Def("smartSellThreshold", 5)
Def("walkActive", false) Def("walkInterval", 800)

local F = { grab = false, eat = false, throw = false, sellTimer = false, smartSell = false, walk = false }
local Gen = { grab = 0, eat = 0, throw = 0, sellTimer = 0, smartSell = 0, walk = 0 }

-- Helpers
local function GetEvents() local c = Player.Character return c and c:FindFirstChild("Events") or nil end
local function FireEvent(name)
    local ev = GetEvents() and GetEvents():FindFirstChild(name)
    if not ev then return false end
    if ev:IsA("RemoteEvent") then ev:FireServer() elseif ev:IsA("RemoteFunction") then ev:InvokeServer() end
    return true
end
local function GetHRP() local c = Player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHum() local c = Player.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function HasChunk()
    local chunks = workspace:FindFirstChild("Chunks")
    if not chunks then return false end
    for _, c in ipairs(chunks:GetChildren()) do
        local o = c:FindFirstChild("Owner")
        if o and o:IsA("ObjectValue") and o.Value == Player then return true end
    end
    return false
end

-- Loops (Auto Grab, Eat, Throw, Sell, SmartSell, Walk) - Mantidos iguais
local function StartGrab()
    Gen.grab += 1 local myGen = Gen.grab
    task.spawn(function()
        local paused, pauseEnd = false, 0
        while F.grab and Gen.grab == myGen and Z.Alive do
            if paused then if tick() < pauseEnd then task.wait(0.5); continue end paused = false end
            if not HasChunk() then FireEvent("Grab") task.wait(0.35) if not HasChunk() then paused = true pauseEnd = tick() + S.grabPauseDuration end end
            task.wait(math.max(0.05, S.grabInterval / 1000))
        end
    end)
end
local function StopGrab() F.grab = false; Gen.grab += 1 end

local function StartEat() Gen.eat += 1 local myGen = Gen.eat task.spawn(function() while F.eat and Gen.eat == myGen and Z.Alive do FireEvent("Eat"); task.wait(math.max(0.05, S.eatInterval / 1000)) end end) end
local function StopEat() F.eat = false; Gen.eat += 1 end

local function StartThrow() Gen.throw += 1 local myGen = Gen.throw task.spawn(function() while F.throw and Gen.throw == myGen and Z.Alive do FireEvent("Throw"); task.wait(math.max(0.05, S.throwInterval / 1000)) end end) end
local function StopThrow() F.throw = false; Gen.throw += 1 end

local function StartSellTimer() Gen.sellTimer += 1 local myGen = Gen.sellTimer task.spawn(function() while F.sellTimer and Gen.sellTimer == myGen and Z.Alive do FireEvent("Sell"); task.wait(math.max(0.05, S.sellTimerInterval / 1000)) end end) end
local function StopSellTimer() F.sellTimer = false; Gen.sellTimer += 1 end

local function StartSmartSell()
    Gen.smartSell += 1 local myGen = Gen.smartSell
    task.spawn(function()
        local lastSize, stuckTime = -1, 0
        while F.smartSell and Gen.smartSell == myGen and Z.Alive do
            local ls = Player:FindFirstChild("leaderstats")
            local sz = ls and ls:FindFirstChild("Size")
            local cur = sz and sz.Value or 0
            if cur ~= lastSize then lastSize, stuckTime = cur, 0 else stuckTime += 1 end
            if stuckTime >= S.smartSellThreshold and cur > 0 then FireEvent("Sell") Z.Notify("Smart Sell", "Vendendo...", C.Success, 2) stuckTime = 0 task.wait(2) end
            task.wait(1)
        end
    end)
end
local function StopSmartSell() F.smartSell = false; Gen.smartSell += 1 end

local function FindGround(origin) local rp = RaycastParams.new() rp.FilterType = Enum.RaycastFilterType.Exclude if Player.Character then rp.FilterDescendantsInstances = {Player.Character} end local hit = workspace:Raycast(origin, Vector3.new(0, -1000, 0), rp) return hit and (hit.Position + Vector3.new(0, 3.5, 0)) or nil end
local function RandomWalkablePos(origin, radius) for _ = 1, 20 do local ang = math.random() * 2 * math.pi local dist = math.random(15, radius) local pos = FindGround(Vector3.new(origin.X + math.cos(ang) * dist, origin.Y + 500, origin.Z + math.sin(ang) * dist)) if pos then return pos end end return nil end

local function StartWalk()
    Gen.walk += 1 local myGen = Gen.walk
    task.spawn(function()
        while F.walk and Gen.walk == myGen and Z.Alive do
            local hrp, hum = GetHRP(), GetHum()
            if hrp and hum then local target = RandomWalkablePos(hrp.Position, 30) if target then hum:MoveTo(target); task.wait(S.walkInterval / 1000) end end
            task.wait(0.2)
        end
        local hum, hrp = GetHum(), GetHRP() if hum and hrp then hum:MoveTo(hrp.Position) end
    end)
end
local function StopWalk() F.walk = false; Gen.walk += 1 local hum, hrp = GetHum(), GetHRP() if hum and hrp then hum:MoveTo(hrp.Position) end end

-- Setters
local UI = Z.UI
local function SetGrab(v) v = not not v F.grab = v S.grabActive = v if UI.grab and UI.grab.SetState then UI.grab:SetState(v, true) end if v then StartGrab() else StopGrab() end end
local function SetEat(v) v = not not v F.eat = v S.eatActive = v if UI.eat and UI.eat.SetState then UI.eat:SetState(v, true) end if v then StartEat() else StopEat() end end
local function SetThrow(v) v = not not v F.throw = v S.throwActive = v if UI.throw and UI.throw.SetState then UI.throw:SetState(v, true) end if v then StartThrow() else StopThrow() end end
local function SetSellTimer(v) v = not not v F.sellTimer = v S.sellTimerActive = v if UI.sellTimer and UI.sellTimer.SetState then UI.sellTimer:SetState(v, true) end if v then if F.smartSell then SetSmartSell(false) end StartSellTimer() else StopSellTimer() end end
local function SetSmartSell(v) v = not not v F.smartSell = v S.smartSellActive = v if UI.smartSell and UI.smartSell.SetState then UI.smartSell:SetState(v, true) end if v then if F.sellTimer then SetSellTimer(false) end StartSmartSell() else StopSmartSell() end end
local function SetWalk(v) v = not not v F.walk = v S.walkActive = v if UI.walk and UI.walk.SetState then UI.walk:SetState(v, true) end if v then StartWalk() else StopWalk() end end

-- ═══════════════════════════════════════════════════════════════════════
-- ABA MAIN COM SEPARADORES
-- ═══════════════════════════════════════════════════════════════════════
local function LoadMain()
    Z.GUI.Clear()
    Z.GUI.TabTitle.Text = "🎮 Main (ETW)"

    -- SEPARADOR: FARM
    Z.Sep("🌾  FARM - AUTO GRAB")
    Z.Info("Pega objetos automaticamente.")
    UI.grab = Z.Toggle("Ativar Auto Grab", F.grab, SetGrab)
    Z.Slider("Intervalo (ms)", 100, 3000, S.grabInterval, function(v) S.grabInterval = v end)

    Z.Sep("🍽️  FARM - AUTO EAT")
    Z.Info("Come automaticamente.")
    UI.eat = Z.Toggle("Ativar Auto Eat", F.eat, SetEat)
    Z.Slider("Intervalo (ms)", 100, 3000, S.eatInterval, function(v) S.eatInterval = v end)

    Z.Sep("💰  FARM - AUTO SELL")
    Z.Info("Vende por tempo ou por tamanho.")
    UI.sellTimer = Z.Toggle("Auto Sell (Timer)", F.sellTimer, SetSellTimer)
    Z.Slider("Vender a cada (ms)", 1000, 60000, S.sellTimerInterval, function(v) S.sellTimerInterval = v end)
    
    UI.smartSell = Z.Toggle("Smart Sell (Size)", F.smartSell, SetSmartSell)
    Z.Slider("Tempo travado (s)", 2, 20, S.smartSellThreshold, function(v) S.smartSellThreshold = v end)

    Z.Sep("🗑️  FARM - AUTO THROW")
    Z.Info("Joga o que está na mão fora.")
    UI.throw = Z.Toggle("Ativar Auto Throw", F.throw, SetThrow)
    Z.Slider("Intervalo (ms)", 100, 3000, S.throwInterval, function(v) S.throwInterval = v end)

    -- SEPARADOR: MOVIMENTO (como você pediu, ex: PVP, etc)
    Z.Sep("🏃  MOVIMENTO - AUTO WALK")
    Z.Info("Anda aleatoriamente pelo mapa.")
    UI.walk = Z.Toggle("Ativar Auto Walk", F.walk, SetWalk)
    Z.Slider("Intervalo de passos (ms)", 200, 3000, S.walkInterval, function(v) S.walkInterval = v end)
    
    -- Exemplo de como você adicionaria PVP futuramente:
    -- Z.Sep("⚔️  PVP - COMBATE")
    -- Z.Button("Ativar Aimbot", C.Danger, function() print("Aimbot") end)
end

-- Limpa abas antigas e adiciona a Main
for _, v in ipairs(Z.GUI.Sidebar:FindFirstChild("ScrollingFrame"):GetChildren()) do
    if v:IsA("TextButton") then v:Destroy() end
end

Z.AddTab("Main", "🎮", LoadMain)

-- Keybinds Rápidos (G, E, T, V)
UIS.InputBegan:Connect(function(input, gpe)
    if gpe or not Z.Alive then return end
    if input.KeyCode == Enum.KeyCode.G then SetGrab(not F.grab)
    elseif input.KeyCode == Enum.KeyCode.E then SetEat(not F.eat)
    elseif input.KeyCode == Enum.KeyCode.T then SetThrow(not F.throw)
    elseif input.KeyCode == Enum.KeyCode.V then if F.smartSell then SetSmartSell(false); SetSellTimer(true) else SetSellTimer(false); SetSmartSell(true) end end
end)

Z.Notify("Zuni Hub", "Módulo ETW v5.0 carregado!", C.Success, 3)
print("⚡ ETW Module v5.0 Iniciado")
