-- ╔══════════════════════════════════════════════════════════════╗
-- ║   N3on Hub - Eat The World Module v13                      ║
-- ║   Correções: sync UI↔keybind, antiKnock, smartSell, etc.   ║
-- ╚══════════════════════════════════════════════════════════════╝

if not _G.N3onHub or not _G.N3onHub.Ready then
    warn("[ETW] Base não pronta! Execute o Base primeiro.")
    return
end

local Player       = game.Players.LocalPlayer
local PlayerGui    = Player:WaitForChild("PlayerGui")
local UIS          = game:GetService("UserInputService")
local VIM          = game:GetService("VirtualInputManager")
local RunService   = game:GetService("RunService")

print("[ETW Module v13] Loading...")

-- ═══════════════════════════════════════════════════════════════
-- SAVED STATES (NÃO sobrescreve — só garante defaults)
-- ═══════════════════════════════════════════════════════════════
local S = _G.N3onHub.SavedStates
local function def(k, v) if S[k] == nil then S[k] = v end end

def("grabActive", false)
def("grabInterval", 500)
def("eatActive", false)
def("eatInterval", 500)
def("throwActive", false)
def("throwInterval", 500)
def("sellActive", false)
def("sellInterval", 12000)
def("smartSellActive", false)
def("smartSellThreshold", 0.95)
def("walkActive", false)
def("teleActive", false)
def("teleInterval", 6)
def("teleRadius", 2048)
def("antiKnock", false)
def("noclip", false)      -- já existe na base, preserva
def("infjump", false)     -- já existe na base, preserva
def("antiAfk", false)
def("grabPauseDuration", 5)

-- ═══════════════════════════════════════════════════════════════
-- REFERÊNCIAS UI (para sincronizar keybinds com checkboxes)
-- ═══════════════════════════════════════════════════════════════
local UI = {
    grab      = nil,
    eat       = nil,
    throw     = nil,
    sell      = nil,
    smartSell = nil,
    walk      = nil,
    tele      = nil,
    antiAfk   = nil,
}

-- ═══════════════════════════════════════════════════════════════
-- FLAGS LOCAIS
-- ═══════════════════════════════════════════════════════════════
local grabActive      = false
local eatActive       = false
local throwActive     = false
local sellActive      = false
local smartSellActive = false
local walkActive      = false
local teleActive      = false
local antiKnock       = false
local antiAfkActive   = false

local grabGen, eatGen, throwGen, sellGen, walkGen, teleGen, antiAfkGen = 0,0,0,0,0,0,0

local smartSellConn = nil
local lastSmartSell = 0
local grabPaused = false
local grabPauseEnd = 0

-- ═══════════════════════════════════════════════════════════════
-- HELPERS — EVENTOS
-- ═══════════════════════════════════════════════════════════════
local function GetEvents()
    local char = Player.Character
    return char and char:FindFirstChild("Events") or nil
end

local function FireEvent(name)
    local events = GetEvents()
    if not events then return false end
    local ev = events:FindFirstChild(name)
    if not ev then return false end
    pcall(function()
        if ev:IsA("RemoteEvent") then ev:FireServer()
        elseif ev:IsA("RemoteFunction") then ev:InvokeServer()
        elseif ev:IsA("BindableEvent") then ev:Fire()
        elseif ev:IsA("BindableFunction") then ev:Invoke()
        end
    end)
    return true
end

local function Click()
    local vp = workspace.CurrentCamera.ViewportSize
    VIM:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, true, game, 1)
    task.wait(0.04)
    VIM:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, false, game, 1)
end

-- ═══════════════════════════════════════════════════════════════
-- HELPERS — MOVIMENTO
-- ═══════════════════════════════════════════════════════════════
local function GetHRP()
    local c = Player.Character; return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetHum()
    local c = Player.Character; return c and c:FindFirstChildOfClass("Humanoid")
end

local function FindGround(origin)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    if Player.Character then rp.FilterDescendantsInstances = {Player.Character} end
    local hit = workspace:Raycast(origin, Vector3.new(0,-800,0), rp)
    return hit and (hit.Position + Vector3.new(0,3.5,0)) or nil
end

local function RandomWalkablePos(origin, radius)
    for _ = 1, 20 do
        local ang  = math.random()*2*math.pi
        local dist = math.random(10, radius)
        local land = FindGround(Vector3.new(
            origin.X + math.cos(ang)*dist,
            origin.Y + 600,
            origin.Z + math.sin(ang)*dist
        ))
        if land then return land end
    end
    return nil
end

local function CastCheck(origin, dir, dist)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    if Player.Character then rp.FilterDescendantsInstances = {Player.Character} end
    return workspace:Raycast(origin, dir * dist, rp)
end

local function FindWalkTarget(hrp)
    local origin = hrp.Position
    for _ = 1, 16 do
        local ang      = math.random()*2*math.pi
        local stepDist = math.random(8, 32)
        local dir      = Vector3.new(math.cos(ang), 0, math.sin(ang))
        if CastCheck(origin + Vector3.new(0,1.2,0), dir, stepDist) then continue end
        local destXZ    = origin + dir * stepDist
        local groundHit = CastCheck(
            Vector3.new(destXZ.X, origin.Y+60, destXZ.Z),
            Vector3.new(0,-1,0), 200
        )
        if not groundHit then continue end
        if groundHit.Position.Y - origin.Y > 12 then continue end
        return groundHit.Position + Vector3.new(0, 3.2, 0)
    end
    return RandomWalkablePos(origin, 60)
end

-- ═══════════════════════════════════════════════════════════════
-- CHUNK OWNER CHECK
-- ═══════════════════════════════════════════════════════════════
local function IsPlayerOwnerOfAnyChunk()
    local chunks = workspace:FindFirstChild("Chunks")
    if not chunks then return false end
    for _, chunk in ipairs(chunks:GetChildren()) do
        local owner = chunk:FindFirstChild("Owner")
        if owner and owner:IsA("ObjectValue") and owner.Value == Player then
            return true
        end
        for _, sub in ipairs(chunk:GetChildren()) do
            if sub:IsA("Model") or sub:IsA("Folder") then
                local subOwner = sub:FindFirstChild("Owner")
                if subOwner and subOwner:IsA("ObjectValue") and subOwner.Value == Player then
                    return true
                end
            end
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- FORÇA SOLTAR GRAB (usado só em botão dedicado)
-- ═══════════════════════════════════════════════════════════════
local function ForceReleaseGrab()
    FireEvent("GrabRelease")
    FireEvent("ReleaseGrab")
    FireEvent("Drop")
    FireEvent("LetGo")
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.G, false, nil)
        task.wait(0.05)
        VIM:SendKeyEvent(false, Enum.KeyCode.G, false, nil)
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- SMART SELL
-- ═══════════════════════════════════════════════════════════════
local function FindSellUI()
    for _, sg in ipairs(PlayerGui:GetChildren()) do
        if sg:IsA("ScreenGui") then
            local sell = sg:FindFirstChild("Sell", true)
            if sell then
                local bar = sell:FindFirstChild("ProgressBar", true)
                if not bar then
                    for _, d in ipairs(sell:GetDescendants()) do
                        if d:IsA("Frame") and (d.Name:lower():find("progress") or d.Name:lower():find("fill")) then
                            bar = d; break
                        end
                    end
                end
                if bar then return bar, sell end
            end
        end
    end
    return nil, nil
end

local function GetSellRatio(bar, frame)
    -- Preferência: Size.X.Scale (mais confiável que AbsoluteSize)
    if bar.Size.X.Scale > 0 and bar.Size.X.Scale <= 1 then
        return bar.Size.X.Scale
    end
    local bw = bar.AbsoluteSize.X
    local fw = frame.AbsoluteSize.X
    if fw <= 0 then return 0 end
    return math.clamp(bw / fw, 0, 1)
end

local function StartSmartSell()
    if smartSellConn then smartSellConn:Disconnect() end
    smartSellConn = RunService.RenderStepped:Connect(function()
        if not smartSellActive or not _G.N3onHub.Alive then return end
        local bar, frame = FindSellUI()
        if not bar or not frame then return end
        if GetSellRatio(bar, frame) >= S.smartSellThreshold then
            local now = tick()
            if now - lastSmartSell > 1.5 then
                lastSmartSell = now
                FireEvent("Sell")
            end
        end
    end)
end

local function StopSmartSell()
    if smartSellConn then smartSellConn:Disconnect(); smartSellConn = nil end
end

-- ═══════════════════════════════════════════════════════════════
-- ANTI AFK (tecla inofensiva em vez de clique)
-- ═══════════════════════════════════════════════════════════════
local function StartAntiAfk()
    antiAfkGen += 1
    local myGen = antiAfkGen
    task.spawn(function()
        while antiAfkActive and antiAfkGen == myGen and _G.N3onHub.Alive do
            pcall(function()
                VIM:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, nil)
                task.wait(0.05)
                VIM:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, nil)
            end)
            task.wait(math.random(30, 60))
        end
    end)
end

local function StopAntiAfk()
    antiAfkActive = false
    antiAfkGen += 1
end

-- ═══════════════════════════════════════════════════════════════
-- ANTI KNOCK (agora NÃO quebra movimento)
-- ═══════════════════════════════════════════════════════════════
local antiKnockConn = RunService.Heartbeat:Connect(function()
    if not antiKnock or not _G.N3onHub.Alive then return end
    local hrp = GetHRP()
    if not hrp then return end
    local hum = GetHum()
    -- Só zera X/Z se o jogador NÃO estiver se movendo manualmente
    if hum and hum.MoveDirection.Magnitude < 0.1 then
        local v = hrp.AssemblyLinearVelocity
        if math.abs(v.X) > 5 or math.abs(v.Z) > 5 then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
            end)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- LOOPS
-- ═══════════════════════════════════════════════════════════════
local function StartGrabLoop()
    grabGen += 1; local myGen = grabGen
    grabPaused = false
    task.spawn(function()
        while grabActive and grabGen == myGen and _G.N3onHub.Alive do
            if grabPaused then
                if tick() < grabPauseEnd then
                    task.wait(1); continue
                else
                    grabPaused = false
                end
            end
            if not IsPlayerOwnerOfAnyChunk() then
                FireEvent("Grab")
                task.wait(0.3)
                if not IsPlayerOwnerOfAnyChunk() then
                    print("⚠️ Nada para pegar. Pausa " .. S.grabPauseDuration .. "s")
                    grabPaused = true
                    grabPauseEnd = tick() + S.grabPauseDuration
                end
            end
            task.wait(math.max(0.05, S.grabInterval/1000))
        end
    end)
end

local function StopGrabLoop()
    grabActive = false
    grabGen += 1
    grabPaused = false
    -- NÃO força soltar automaticamente — só quando o usuário clica no botão dedicado
end

local function StartEatLoop()
    eatGen += 1; local myGen = eatGen
    task.spawn(function()
        while eatActive and eatGen == myGen and _G.N3onHub.Alive do
            FireEvent("Eat")
            task.wait(math.max(0.05, S.eatInterval/1000))
        end
    end)
end
local function StopEatLoop() eatActive = false; eatGen += 1 end

local function StartThrowLoop()
    throwGen += 1; local myGen = throwGen
    task.spawn(function()
        while throwActive and throwGen == myGen and _G.N3onHub.Alive do
            FireEvent("Throw")
            task.wait(math.max(0.05, S.throwInterval/1000))
        end
    end)
end
local function StopThrowLoop() throwActive = false; throwGen += 1 end

local function StartSellLoop()
    sellGen += 1; local myGen = sellGen
    task.spawn(function()
        while sellActive and sellGen == myGen and _G.N3onHub.Alive do
            FireEvent("Sell")
            task.wait(math.max(0.05, S.sellInterval/1000))
        end
    end)
end
local function StopSellLoop() sellActive = false; sellGen += 1 end

local function StartWalkLoop()
    walkGen += 1; local myGen = walkGen
    task.spawn(function()
        while walkActive and walkGen == myGen and _G.N3onHub.Alive do
            local hrp = GetHRP(); local hum = GetHum()
            if hrp and hum and hum.Health > 0 then
                local target = FindWalkTarget(hrp)
                if target then
                    hum:MoveTo(target)
                    local t0 = tick()
                    repeat task.wait(0.08)
                        local h = GetHRP()
                        if h and (h.Position - target).Magnitude < 4 then break end
                    until tick()-t0 > 2.5 or not walkActive or walkGen ~= myGen
                    task.wait(math.random(20,60)/100)
                else
                    task.wait(0.5)
                end
            else
                task.wait(0.3)
            end
        end
        local hum = GetHum(); local hrp = GetHRP()
        if hum and hrp then hum:MoveTo(hrp.Position) end
    end)
end

local function StopWalkLoop()
    walkActive = false; walkGen += 1
    local hum = GetHum(); local hrp = GetHRP()
    if hum and hrp then hum:MoveTo(hrp.Position) end
end

local function StartTeleLoop()
    teleGen += 1; local myGen = teleGen
    task.spawn(function()
        while teleActive and teleGen == myGen and _G.N3onHub.Alive do
            task.wait(S.teleInterval)
            if not teleActive or teleGen ~= myGen then break end
            local hrp = GetHRP()
            if hrp then
                local dest = RandomWalkablePos(hrp.Position, S.teleRadius)
                if dest then hrp.CFrame = CFrame.new(dest) end
            end
        end
    end)
end
local function StopTeleLoop() teleActive = false; teleGen += 1 end

-- ═══════════════════════════════════════════════════════════════
-- API PÚBLICA DE TOGGLE (usada por UI e keybind — sincroniza ambos)
-- ═══════════════════════════════════════════════════════════════
local function setGrab(v)
    v = not not v
    grabActive = v; S.grabActive = v
    if UI.grab and UI.grab.SetState then UI.grab:SetState(v, true) end
    if v then StartGrabLoop() else StopGrabLoop() end
end

local function setEat(v)
    v = not not v
    eatActive = v; S.eatActive = v
    if UI.eat and UI.eat.SetState then UI.eat:SetState(v, true) end
    if v then StartEatLoop() else StopEatLoop() end
end

local function setThrow(v)
    v = not not v
    throwActive = v; S.throwActive = v
    if UI.throw and UI.throw.SetState then UI.throw:SetState(v, true) end
    if v then StartThrowLoop() else StopThrowLoop() end
end

local function setSellTimer(v)
    v = not not v
    sellActive = v; S.sellActive = v
    if UI.sell and UI.sell.SetState then UI.sell:SetState(v, true) end
    if v then
        if smartSellActive then
            smartSellActive = false; S.smartSellActive = false
            if UI.smartSell and UI.smartSell.SetState then UI.smartSell:SetState(false, true) end
            StopSmartSell()
        end
        StartSellLoop()
    else
        StopSellLoop()
    end
end

local function setSmartSell(v)
    v = not not v
    smartSellActive = v; S.smartSellActive = v
    if UI.smartSell and UI.smartSell.SetState then UI.smartSell:SetState(v, true) end
    if v then
        if sellActive then
            sellActive = false; S.sellActive = false
            if UI.sell and UI.sell.SetState then UI.sell:SetState(false, true) end
            StopSellLoop()
        end
        StartSmartSell()
    else
        StopSmartSell()
    end
end

local function setWalk(v)
    v = not not v
    walkActive = v; S.walkActive = v
    if UI.walk and UI.walk.SetState then UI.walk:SetState(v, true) end
    if v then StartWalkLoop() else StopWalkLoop() end
end

local function setTele(v)
    v = not not v
    teleActive = v; S.teleActive = v
    if UI.tele and UI.tele.SetState then UI.tele:SetState(v, true) end
    if v then StartTeleLoop() else StopTeleLoop() end
end

local function setAntiAfk(v)
    v = not not v
    antiAfkActive = v; S.antiAfk = v
    if UI.antiAfk and UI.antiAfk.SetState then UI.antiAfk:SetState(v, true) end
    if v then StartAntiAfk() else StopAntiAfk() end
end

local function setAntiKnock(v)
    v = not not v
    antiKnock = v; S.antiKnock = v
end

-- ═══════════════════════════════════════════════════════════════
-- KEYBINDS (sincronizam com UI)
-- ═══════════════════════════════════════════════════════════════
UIS.InputBegan:Connect(function(input, gpe)
    if gpe or not _G.N3onHub.Alive then return end
    if input.KeyCode == Enum.KeyCode.G then
        setGrab(not grabActive)
    elseif input.KeyCode == Enum.KeyCode.E then
        setEat(not eatActive)
    elseif input.KeyCode == Enum.KeyCode.T then
        setThrow(not throwActive)
    elseif input.KeyCode == Enum.KeyCode.V then
        if smartSellActive then
            setSmartSell(false)
            setSellTimer(true)
        elseif sellActive then
            setSellTimer(false)
            setSmartSell(true)
        else
            setSellTimer(true)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- STATUS BAR (dentro do MainContainer)
-- ═══════════════════════════════════════════════════════════════
local Main = _G.N3onHub.GUI.MainContainer
local statusLbl = Instance.new("TextLabel", Main)
statusLbl.Name = "ETW_StatusBar"
statusLbl.Size = UDim2.new(1, -220, 0, 24)
statusLbl.Position = UDim2.new(0, 210, 1, -34)
statusLbl.BackgroundColor3 = Color3.fromRGB(22, 22, 38)
statusLbl.BackgroundTransparency = 0.1
statusLbl.BorderSizePixel = 0
statusLbl.TextColor3 = Color3.fromRGB(220, 210, 255)
statusLbl.Font = Enum.Font.GothamBold
statusLbl.TextScaled = true
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.ZIndex = 20
Instance.new("UICorner", statusLbl).CornerRadius = UDim.new(0, 8)
local ss = Instance.new("UIStroke", statusLbl)
ss.Color = Color3.fromRGB(90, 70, 180)
local slp = Instance.new("UIPadding", statusLbl)
slp.PaddingLeft = UDim.new(0, 8)

RunService.Heartbeat:Connect(function()
    if not statusLbl or not statusLbl.Parent or not _G.N3onHub.Alive then return end
    local sellIcon, sellLabel = "⏹", "Sell"
    if smartSellActive then sellIcon, sellLabel = "🧠", "SmartSell"
    elseif sellActive then sellIcon, sellLabel = "✅", "Sell" end

    statusLbl.Text = (grabActive and "✅" or "⏹").." Grab [G]  "
        .. (eatActive and "✅" or "⏹").." Eat [E]  "
        .. (throwActive and "✅" or "⏹").." Throw [T]  "
        .. sellIcon.." "..sellLabel.." [V]  "
        .. (walkActive and "✅" or "⏹").." Walk  "
        .. (antiAfkActive and "👆" or "😴")
end)

-- ═══════════════════════════════════════════════════════════════
-- TABS
-- ═══════════════════════════════════════════════════════════════
local function LoadFarmTab()
    _G.N3onHub.GUI.Clear()
    local C = _G.N3onHub.Colors
    _G.N3onHub.GUI.TabTitle.Text = "🌾 Auto Farm"

    _G.N3onHub.Sep("🖐️  AUTO GRAB")
    _G.N3onHub.Info("  Grab inteligente: só pega se não tiver chunk")
    _G.N3onHub.Info("  Tecla [G]")

    UI.grab = _G.N3onHub.Checkbox("Auto Grab", grabActive, function(v) setGrab(v) end)
    _G.N3onHub.Slider("Intervalo Grab (ms)", 100, 3000, S.grabInterval, function(v)
        S.grabInterval = v
    end)
    _G.N3onHub.Slider("Pausa após falha (s)", 1, 15, S.grabPauseDuration, function(v)
        S.grabPauseDuration = v
    end)

    _G.N3onHub.Sep("🍽️  AUTO EAT")
    _G.N3onHub.Info("  Envia evento 'Eat' | Tecla [E]")
    UI.eat = _G.N3onHub.Checkbox("Auto Eat", eatActive, function(v) setEat(v) end)
    _G.N3onHub.Slider("Intervalo Eat (ms)", 100, 3000, S.eatInterval, function(v)
        S.eatInterval = v
    end)

    _G.N3onHub.Sep("🗑️  AUTO THROW")
    _G.N3onHub.Info("  Envia evento 'Throw' | Tecla [T]")
    UI.throw = _G.N3onHub.Checkbox("Auto Throw", throwActive, function(v) setThrow(v) end)
    _G.N3onHub.Slider("Intervalo Throw (ms)", 100, 3000, S.throwInterval, function(v)
        S.throwInterval = v
    end)

    _G.N3onHub.Sep("💰  AUTO SELL (TIMER)")
    _G.N3onHub.Info("  Envia evento 'Sell' a cada X ms | Tecla [V]")
    UI.sell = _G.N3onHub.Checkbox("Auto Sell (Timer)", sellActive, function(v) setSellTimer(v) end)
    _G.N3onHub.Slider("Intervalo Sell (ms)", 1000, 60000, S.sellInterval, function(v)
        S.sellInterval = v
    end)

    _G.N3onHub.Sep("🧠  SMART SELL (ProgressBar)")
    _G.N3onHub.Info("  Detecta PlayerGui > Sell > ProgressBar")
    _G.N3onHub.Info("  Vende quando a barra estiver cheia")
    UI.smartSell = _G.N3onHub.Checkbox("Smart Sell", smartSellActive, function(v) setSmartSell(v) end)
    _G.N3onHub.Slider("Threshold (%)", 50, 100, math.floor(S.smartSellThreshold * 100), function(v)
        S.smartSellThreshold = v / 100
    end)

    _G.N3onHub.Sep("🚶  AUTO WALK ALEATÓRIO")
    _G.N3onHub.Info("  Raycast avançado: evita paredes e buracos")
    UI.walk = _G.N3onHub.Checkbox("Auto Walk", walkActive, function(v) setWalk(v) end)

    _G.N3onHub.Sep("🌀  AUTO TELEPORT")
    _G.N3onHub.Info("  Teleporta para posições aleatórias com ground check")
    UI.tele = _G.N3onHub.Checkbox("Auto Teleport", teleActive, function(v) setTele(v) end)
    _G.N3onHub.Slider("Intervalo Tele (s)", 1, 120, S.teleInterval, function(v)
        S.teleInterval = v
    end)
    _G.N3onHub.Slider("Raio Tele (studs)", 50, 4096, S.teleRadius, function(v)
        S.teleRadius = v
    end)
end

local function LoadMiscTab()
    _G.N3onHub.GUI.Clear()
    local C = _G.N3onHub.Colors
    _G.N3onHub.GUI.TabTitle.Text = "⚙️ Misc"

    _G.N3onHub.Sep("🛡️  UTILIDADES")

    _G.N3onHub.Checkbox("Noclip", S.noclip, function(v)
        S.noclip = v
    end)
    _G.N3onHub.Checkbox("Infinite Jump", S.infjump, function(v)
        S.infjump = v
    end)
    _G.N3onHub.Checkbox("Anti Knockback", S.antiKnock, function(v) setAntiKnock(v) end)
    UI.antiAfk = _G.N3onHub.Checkbox("Anti AFK (Click)", antiAfkActive, function(v) setAntiAfk(v) end)

    _G.N3onHub.Sep("🔧  AÇÕES RÁPIDAS")

    _G.N3onHub.Button("🔄 Respawn", C.AccentDark, function()
        Player:LoadCharacter()
    end)
    _G.N3onHub.Button("🏠 TP para Origem", C.AccentDark, function()
        local hrp = GetHRP()
        if hrp then
            local ground = FindGround(Vector3.new(0, 600, 0))
            hrp.CFrame = CFrame.new(ground or Vector3.new(0, 5, 0))
        end
    end)
    _G.N3onHub.Button("🖐️ Forçar Soltar Grab", C.Danger, function()
        ForceReleaseGrab()
    end)

    _G.N3onHub.Sep("📋  INFO")
    _G.N3onHub.Info("  [G] Grab  |  [E] Eat  |  [T] Throw")
    _G.N3onHub.Info("  [V] Alterna Sell / Smart Sell")
    _G.N3onHub.Info("  Grab automático: só ativa se não tiver chunk")
    _G.N3onHub.Info("  Pausa automática se não encontrar nada")
    _G.N3onHub.Info("  👆 na status bar = Anti AFK ativo")
end

_G.N3onHub.Tab("Auto Farm", "🌾", 0, LoadFarmTab)
_G.N3onHub.Tab("Misc",      "⚙️", 0, LoadMiscTab)

print("[ETW Module v13] ✓ Eat The World carregado!")
