-- ╔══════════════════════════════════════════════════════════════╗
-- ║   N3on Hub - Eat The World Module v14                      ║
-- ║   Smart Sell (Size) + Timer Sell + UI Legível              ║
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

print("[ETW Module v14] Loading...")

-- ═══════════════════════════════════════════════════════════════
-- SAVED STATES (Garante que não sobrescreve o que já existe)
-- ═══════════════════════════════════════════════════════════════
local S = _G.N3onHub.SavedStates
local function def(k, v) if S[k] == nil then S[k] = v end end

def("grabActive", false)
def("grabInterval", 500)
def("grabPauseDuration", 5)

def("eatActive", false)
def("eatInterval", 500)

def("throwActive", false)
def("throwInterval", 500)

def("sellActive", false)
def("sellInterval", 12000)

def("smartSellActive", false)       -- O novo Smart Sell (Size)
def("smartSellSizeThreshold", 5)    -- Tempo que o size precisa ficar igual para vender

def("walkActive", false)
def("teleActive", false)
def("teleInterval", 6)
def("teleRadius", 2048)

def("antiKnock", false)
def("antiAfk", false)

-- ═══════════════════════════════════════════════════════════════
-- REFERÊNCIAS UI
-- ═══════════════════════════════════════════════════════════════
local UI = { grab = nil, eat = nil, throw = nil, sell = nil, smartSell = nil, walk = nil, tele = nil, antiAfk = nil }

-- ═══════════════════════════════════════════════════════════════
-- FLAGS LOCAIS
-- ═══════════════════════════════════════════════════════════════
local grabActive, eatActive, throwActive, sellActive, smartSellActive = false, false, false, false, false
local walkActive, teleActive, antiAfkActive = false, false, false
local antiKnock = false

local grabGen, eatGen, throwGen, sellGen, walkGen, teleGen, antiAfkGen, smartSellGen = 0,0,0,0,0,0,0,0

local grabPaused = false
local grabPauseEnd = 0
local lastEatSize = 0

-- ═══════════════════════════════════════════════════════════════
-- HELPERS BÁSICOS
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

local function GetHRP()
    local c = Player.Character; return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetHum()
    local c = Player.Character; return c and c:FindFirstChildOfClass("Humanoid")
end

local function Click()
    local vp = workspace.CurrentCamera.ViewportSize
    VIM:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, true, game, 1)
    task.wait(0.04)
    VIM:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, false, game, 1)
end

-- Movimento / Raycast
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
        local land = FindGround(Vector3.new(origin.X + math.cos(ang)*dist, origin.Y + 600, origin.Z + math.sin(ang)*dist))
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
        local groundHit = CastCheck(Vector3.new(destXZ.X, origin.Y+60, destXZ.Z), Vector3.new(0,-1,0), 200)
        if not groundHit then continue end
        if groundHit.Position.Y - origin.Y > 12 then continue end
        return groundHit.Position + Vector3.new(0, 3.2, 0)
    end
    return RandomWalkablePos(origin, 60)
end

local function IsPlayerOwnerOfAnyChunk()
    local chunks = workspace:FindFirstChild("Chunks")
    if not chunks then return false end
    for _, chunk in ipairs(chunks:GetChildren()) do
        local owner = chunk:FindFirstChild("Owner")
        if owner and owner:IsA("ObjectValue") and owner.Value == Player then
            return true
        end
    end
    return false
end

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
-- LOOPS (Todos protegidos com Alive e myGen)
-- ═══════════════════════════════════════════════════════════════

local function StartGrabLoop()
    grabGen += 1; local myGen = grabGen
    grabPaused = false
    task.spawn(function()
        while grabActive and grabGen == myGen and _G.N3onHub.Alive do
            if grabPaused then
                if tick() < grabPauseEnd then task.wait(1); continue else grabPaused = false end
            end
            if not IsPlayerOwnerOfAnyChunk() then
                FireEvent("Grab")
                task.wait(0.3)
                if not IsPlayerOwnerOfAnyChunk() then
                    print("⚠️ Nada para pegar. Pausa " .. S.grabPauseDuration .. "s")
                    grabPaused = true; grabPauseEnd = tick() + S.grabPauseDuration
                end
            end
            task.wait(math.max(0.05, S.grabInterval/1000))
        end
    end)
end
local function StopGrabLoop() grabActive = false; grabGen += 1; grabPaused = false end

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

-- 🧠 NOVO SMART SELL (Por Tamanho do Leaderstats)
local function StartSmartSell()
    smartSellGen += 1; local myGen = smartSellGen
    
    task.spawn(function()
        local lastSize = -1
        local stuckTime = 0
        
        while smartSellActive and smartSellGen == myGen and _G.N3onHub.Alive do
            local ls = Player:FindFirstChild("leaderstats")
            local sizeObj = ls and ls:FindFirstChild("Size")
            local currentSize = sizeObj and sizeObj.Value or 0

            -- Se o tamanho mudou, reseta o timer de "travado"
            if currentSize ~= lastSize then
                lastSize = currentSize
                stuckTime = 0
            else
                -- Se o tamanho não muda, acumula o tempo
                stuckTime += 1
            end

            -- Se o tamanho ficou travado pelo tempo definido e for maior que 0, vende
            if stuckTime >= S.smartSellSizeThreshold and currentSize > 0 then
                FireEvent("Sell")
                print("🧠 Smart Sell: Size travado em " .. currentSize .. ". Vendendo...")
                stuckTime = 0 -- Reseta para não vender em loop infinito
                task.wait(2) -- Espera a animação de venda terminar
            end

            task.wait(1) -- Checa o size a cada 1 segundo
        end
    end)
end
local function StopSmartSell() smartSellActive = false; smartSellGen += 1 end

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

local function StartAntiAfk()
    antiAfkGen += 1; local myGen = antiAfkGen
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
local function StopAntiAfk() antiAfkActive = false; antiAfkGen += 1 end

-- Anti Knockback Inteligente
RunService.Heartbeat:Connect(function()
    if not antiKnock or not _G.N3onHub.Alive then return end
    local hrp = GetHRP(); local hum = GetHum()
    if not hrp or not hum then return end
    if hum.MoveDirection.Magnitude < 0.1 then
        local v = hrp.AssemblyLinearVelocity
        if math.abs(v.X) > 5 or math.abs(v.Z) > 5 then
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0) end)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- API DE TOGGLE (Sincroniza UI com Keybinds)
-- ═══════════════════════════════════════════════════════════════
local function setGrab(v)
    v = not not v; grabActive = v; S.grabActive = v
    if UI.grab and UI.grab.SetState then UI.grab:SetState(v, true) end
    if v then StartGrabLoop() else StopGrabLoop() end
end

local function setEat(v)
    v = not not v; eatActive = v; S.eatActive = v
    if UI.eat and UI.eat.SetState then UI.eat:SetState(v, true) end
    if v then StartEatLoop() else StopEatLoop() end
end

local function setThrow(v)
    v = not not v; throwActive = v; S.throwActive = v
    if UI.throw and UI.throw.SetState then UI.throw:SetState(v, true) end
    if v then StartThrowLoop() else StopThrowLoop() end
end

local function setSellTimer(v)
    v = not not v; sellActive = v; S.sellActive = v
    if UI.sell and UI.sell.SetState then UI.sell:SetState(v, true) end
    if v then
        if smartSellActive then setSmartSell(false) end
        StartSellLoop()
    else
        StopSellLoop()
    end
end

local function setSmartSell(v)
    v = not not v; smartSellActive = v; S.smartSellActive = v
    if UI.smartSell and UI.smartSell.SetState then UI.smartSell:SetState(v, true) end
    if v then
        if sellActive then setSellTimer(false) end
        StartSmartSell()
    else
        StopSmartSell()
    end
end

local function setWalk(v)
    v = not not v; walkActive = v; S.walkActive = v
    if UI.walk and UI.walk.SetState then UI.walk:SetState(v, true) end
    if v then StartWalkLoop() else StopWalkLoop() end
end

local function setTele(v)
    v = not not v; teleActive = v; S.teleActive = v
    if UI.tele and UI.tele.SetState then UI.tele:SetState(v, true) end
    if v then StartTeleLoop() else StopTeleLoop() end
end

local function setAntiAfk(v)
    v = not not v; antiAfkActive = v; S.antiAfk = v
    if UI.antiAfk and UI.antiAfk.SetState then UI.antiAfk:SetState(v, true) end
    if v then StartAntiAfk() else StopAntiAfk() end
end

local function setAntiKnock(v)
    v = not not v; antiKnock = v; S.antiKnock = v
end

-- Keybinds Rápidos
UIS.InputBegan:Connect(function(input, gpe)
    if gpe or not _G.N3onHub.Alive then return end
    if input.KeyCode == Enum.KeyCode.G then setGrab(not grabActive)
    elseif input.KeyCode == Enum.KeyCode.E then setEat(not eatActive)
    elseif input.KeyCode == Enum.KeyCode.T then setThrow(not throwActive)
    elseif input.KeyCode == Enum.KeyCode.V then
        if smartSellActive then setSmartSell(false); setSellTimer(true)
        elseif sellActive then setSellTimer(false); setSmartSell(true)
        else setSellTimer(true) end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- TAB: AUTO FARM
-- ═══════════════════════════════════════════════════════════════
local function LoadFarmTab()
    _G.N3onHub.GUI.Clear()
    local C = _G.N3onHub.Colors
    _G.N3onHub.GUI.TabTitle.Text = "🌾 Auto Farm"

    _G.N3onHub.Sep("🖐️  AUTO GRAB (PEGAR)")
    _G.N3onHub.Info("  Só pega se não estiver segurando nada. Tecla [G]")
    UI.grab = _G.N3onHub.Checkbox("Ativar Auto Grab", grabActive, function(v) setGrab(v) end)
    _G.N3onHub.Slider("Intervalo entre tentativas (ms)", 100, 3000, S.grabInterval, function(v) S.grabInterval = v end)
    _G.N3onHub.Slider("Tempo de pausa se falhar (s)", 1, 15, S.grabPauseDuration, function(v) S.grabPauseDuration = v end)

    _G.N3onHub.Sep("🍽️  AUTO EAT (COMER)")
    _G.N3onHub.Info("  Come automaticamente para aumentar o tamanho. Tecla [E]")
    UI.eat = _G.N3onHub.Checkbox("Ativar Auto Eat", eatActive, function(v) setEat(v) end)
    _G.N3onHub.Slider("Intervalo entre mordidas (ms)", 100, 3000, S.eatInterval, function(v) S.eatInterval = v end)

    _G.N3onHub.Sep("🗑️  AUTO THROW (JOGAR FORA)")
    _G.N3onHub.Info("  Joga o que estiver na mão fora. Tecla [T]")
    UI.throw = _G.N3onHub.Checkbox("Ativar Auto Throw", throwActive, function(v) setThrow(v) end)
    _G.N3onHub.Slider("Intervalo entre arremessos (ms)", 100, 3000, S.throwInterval, function(v) S.throwInterval = v end)

    _G.N3onHub.Sep("💰  VENDER AUTOMÁTICO")
    
    _G.N3onHub.Info("  ▶ [MODO 1] Vender por Tempo (Timer)")
    _G.N3onHub.Info("  Envia o comando de venda a cada X segundos.")
    UI.sell = _G.N3onHub.Checkbox("Vender por Tempo (Timer)", sellActive, function(v) setSellTimer(v) end)
    _G.N3onHub.Slider("Vender a cada (ms)", 1000, 60000, S.sellInterval, function(v) S.sellInterval = v end)

    _G.N3onHub.Info("  ▶ [MODO 2] Smart Sell (Por Tamanho)")
    _G.N3onHub.Info("  Verifica o 'Size' no leaderstats. Se parar de subir, vende.")
    UI.smartSell = _G.N3onHub.Checkbox("Smart Sell (Monitorar Size)", smartSellActive, function(v) setSmartSell(v) end)
    _G.N3onHub.Slider("Tempo de Size travado para vender (s)", 2, 20, S.smartSellSizeThreshold, function(v) S.smartSellSizeThreshold = v end)

    _G.N3onHub.Sep("🚶  AUTO WALK (ANDAR ALEATÓRIO)")
    _G.N3onHub.Info("  Desvia de paredes e buracos.")
    UI.walk = _G.N3onHub.Checkbox("Ativar Auto Walk", walkActive, function(v) setWalk(v) end)

    _G.N3onHub.Sep("🌀  AUTO TELEPORT")
    _G.N3onHub.Info("  Teleporta para locais aleatórios no mapa.")
    UI.tele = _G.N3onHub.Checkbox("Ativar Auto Teleport", teleActive, function(v) setTele(v) end)
    _G.N3onHub.Slider("Teleportar a cada (s)", 1, 120, S.teleInterval, function(v) S.teleInterval = v end)
    _G.N3onHub.Slider("Raio de distância (studs)", 50, 4096, S.teleRadius, function(v) S.teleRadius = v end)
end

-- ═══════════════════════════════════════════════════════════════
-- TAB: MISC (UTILIDADES)
-- ═══════════════════════════════════════════════════════════════
local function LoadMiscTab()
    _G.N3onHub.GUI.Clear()
    local C = _G.N3onHub.Colors
    _G.N3onHub.GUI.TabTitle.Text = "⚙️ Misc"

    _G.N3onHub.Sep("🛡️  UTILIDADES")
    
    _G.N3onHub.Info("  Anti Knockback: Impede de ser empurrado.")
    _G.N3onHub.Checkbox("Ativar Anti Knockback", S.antiKnock, function(v) setAntiKnock(v) end)

    _G.N3onHub.Info("  Anti AFK: Envia teclas para não ser kickado.")
    UI.antiAfk = _G.N3onHub.Checkbox("Ativar Anti AFK", antiAfkActive, function(v) setAntiAfk(v) end)

    _G.N3onHub.Sep("🔧  AÇÕES RÁPIDAS")
    
    _G.N3onHub.Button("🔄 Respawn (Voltar à vida)", C.AccentDark, function()
        Player:LoadCharacter()
    end)
    _G.N3onHub.Button("🏠 TP para Origem (Spawn)", C.AccentDark, function()
        local hrp = GetHRP()
        if hrp then
            local ground = FindGround(Vector3.new(0, 600, 0))
            hrp.CFrame = CFrame.new(ground or Vector3.new(0, 5, 0))
        end
    end)
    _G.N3onHub.Button("🖐️ Forçar Soltar Grab", C.Danger, function()
        ForceReleaseGrab()
    end)

    _G.N3onHub.Sep("📋  INFORMAÇÕES E ATALHOS")
    _G.N3onHub.Info("  [G] Grab | [E] Eat | [T] Throw")
    _G.N3onHub.Info("  [V] Alterna entre Timer Sell e Smart Sell")
    _G.N3onHub.Info("  O Smart Sell monitora o tamanho no leaderstats.")
    _G.N3onHub.Info("  Se o tamanho parar de aumentar, ele vende.")
end

_G.N3onHub.Tab("Auto Farm", "🌾", 0, LoadFarmTab)
_G.N3onHub.Tab("Misc",      "⚙️", 0, LoadMiscTab)

print("[ETW Module v14] ✓ Eat The World carregado com Smart Sell!")
