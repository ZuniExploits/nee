-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ZUNI HUB - ETW MODULE v3.0                                         ║
-- ║  Auto Grab / Eat / Throw / Sell / Smart / Rewards / Walk / Jump     ║
-- ╚══════════════════════════════════════════════════════════════════════╝

if not _G.ZuniHub or not _G.ZuniHub.Ready then
    warn("[ETW] Base não carregada!")
    return
end

local Z = _G.ZuniHub
local C = Z.Colors
local S = Z.SavedStates

local Player     = game.Players.LocalPlayer
local UIS        = game:GetService("UserInputService")
local VIM        = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- ═══════════════════════════════════════════════════════════════════════
-- DEFAULTS
-- ═══════════════════════════════════════════════════════════════════════
local function Def(k, v) if S[k] == nil then S[k] = v end end

Def("grabActive", false)
Def("grabInterval", 500)
Def("grabPauseDuration", 5)
Def("grabSellOnFail", false)

Def("eatActive", false)
Def("eatInterval", 300)

Def("throwActive", false)
Def("throwInterval", 500)

Def("sellTimerActive", false)
Def("sellTimerInterval", 12000)

Def("smartSellActive", false)
Def("smartSellThreshold", 5)

Def("autoRewardsActive", false)
Def("autoRewardsDelay", 3)

Def("walkActive", false)
Def("walkInterval", 800)

Def("teleActive", false)
Def("teleInterval", 6)
Def("teleRadius", 2048)

Def("jumpActive", false)
Def("antiKnockActive", false)
Def("antiAfkActive", false)

-- ═══════════════════════════════════════════════════════════════════════
-- LOCAL FLAGS
-- ═══════════════════════════════════════════════════════════════════════
local F = {
    grab = false, eat = false, throw = false,
    sellTimer = false, smartSell = false,
    autoRewards = false,
    walk = false, tele = false,
    jump = false, antiKnock = false, antiAfk = false,
}

local Gen = {
    grab = 0, eat = 0, throw = 0,
    sellTimer = 0, smartSell = 0,
    autoRewards = 0,
    walk = 0, tele = 0, antiAfk = 0,
}

-- ═══════════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════════
local function GetEvents()
    local c = Player.Character
    return c and c:FindFirstChild("Events") or nil
end

local function FireEvent(name, ...)
    local events = GetEvents()
    if not events then return false end
    local ev = events:FindFirstChild(name)
    if not ev then return false end
    pcall(function()
        if ev:IsA("RemoteEvent") then ev:FireServer(...)
        elseif ev:IsA("RemoteFunction") then ev:InvokeServer(...)
        end
    end)
    return true
end

local function GetHRP()
    local c = Player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetHum()
    local c = Player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ═══════════════════════════════════════════════════════════════════════
-- CHUNK OWNER
-- ═══════════════════════════════════════════════════════════════════════
local function HasChunk()
    local chunks = workspace:FindFirstChild("Chunks")
    if not chunks then return false end
    for _, c in ipairs(chunks:GetChildren()) do
        local o = c:FindFirstChild("Owner")
        if o and o:IsA("ObjectValue") and o.Value == Player then
            return true
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════
-- GRAB
-- ═══════════════════════════════════════════════════════════════════════
local function StartGrab()
    Gen.grab = Gen.grab + 1
    local myGen = Gen.grab
    task.spawn(function()
        local paused = false
        local pauseEnd = 0
        while F.grab and Gen.grab == myGen and Z.Alive do
            if paused then
                if tick() < pauseEnd then task.wait(0.5); continue end
                paused = false
            end
            if not HasChunk() then
                FireEvent("Grab")
                task.wait(0.35)
                if not HasChunk() then
                    paused = true
                    pauseEnd = tick() + S.grabPauseDuration
                    if S.grabSellOnFail then
                        FireEvent("Sell")
                    end
                end
            end
            task.wait(math.max(0.05, S.grabInterval / 1000))
        end
    end)
end

local function StopGrab()
    F.grab = false
    Gen.grab = Gen.grab + 1
end

-- ═══════════════════════════════════════════════════════════════════════
-- EAT
-- ═══════════════════════════════════════════════════════════════════════
local function StartEat()
    Gen.eat = Gen.eat + 1
    local myGen = Gen.eat
    task.spawn(function()
        while F.eat and Gen.eat == myGen and Z.Alive do
            FireEvent("Eat")
            task.wait(math.max(0.05, S.eatInterval / 1000))
        end
    end)
end
local function StopEat() F.eat = false; Gen.eat = Gen.eat + 1 end

-- ═══════════════════════════════════════════════════════════════════════
-- THROW
-- ═══════════════════════════════════════════════════════════════════════
local function StartThrow()
    Gen.throw = Gen.throw + 1
    local myGen = Gen.throw
    task.spawn(function()
        while F.throw and Gen.throw == myGen and Z.Alive do
            FireEvent("Throw")
            task.wait(math.max(0.05, S.throwInterval / 1000))
        end
    end)
end
local function StopThrow() F.throw = false; Gen.throw = Gen.throw + 1 end

-- ═══════════════════════════════════════════════════════════════════════
-- SELL TIMER
-- ═══════════════════════════════════════════════════════════════════════
local function StartSellTimer()
    Gen.sellTimer = Gen.sellTimer + 1
    local myGen = Gen.sellTimer
    task.spawn(function()
        while F.sellTimer and Gen.sellTimer == myGen and Z.Alive do
            FireEvent("Sell")
            task.wait(math.max(0.05, S.sellTimerInterval / 1000))
        end
    end)
end
local function StopSellTimer() F.sellTimer = false; Gen.sellTimer = Gen.sellTimer + 1 end

-- ═══════════════════════════════════════════════════════════════════════
-- SMART SELL (by Size)
-- ═══════════════════════════════════════════════════════════════════════
local function StartSmartSell()
    Gen.smartSell = Gen.smartSell + 1
    local myGen = Gen.smartSell
    task.spawn(function()
        local lastSize = -1
        local stuckTime = 0
        while F.smartSell and Gen.smartSell == myGen and Z.Alive do
            local ls = Player:FindFirstChild("leaderstats")
            local sz = ls and ls:FindFirstChild("Size")
            local cur = sz and sz.Value or 0

            if cur ~= lastSize then
                lastSize = cur
                stuckTime = 0
            else
                stuckTime = stuckTime + 1
            end

            if stuckTime >= S.smartSellThreshold and cur > 0 then
                FireEvent("Sell")
                Z.Notify("Smart Sell", "Size travado em " .. cur .. ". Vendendo...", C.Success, 3)
                stuckTime = 0
                task.wait(2)
            end
            task.wait(1)
        end
    end)
end
local function StopSmartSell() F.smartSell = false; Gen.smartSell = Gen.smartSell + 1 end

-- ═══════════════════════════════════════════════════════════════════════
-- AUTO REWARDS
-- ═══════════════════════════════════════════════════════════════════════
local function StartAutoRewards()
    Gen.autoRewards = Gen.autoRewards + 1
    local myGen = Gen.autoRewards
    task.spawn(function()
        while F.autoRewards and Gen.autoRewards == myGen and Z.Alive do
            local timed = Player:FindFirstChild("TimedRewards")
            if timed then
                for _, reward in ipairs(timed:GetChildren()) do
                    if reward:IsA("NumberValue") and reward.Value ~= -1 and reward.Value <= os.time() then
                        local ok = pcall(function()
                            game.ReplicatedStorage.Events.RewardEvent:FireServer(reward)
                        end)
                        if ok then
                            Z.Notify("Reward", "Resgatando: " .. reward.Name, C.Success, 2)
                            task.wait(S.autoRewardsDelay)
                        end
                    end
                end
            end
            task.wait(1)
        end
    end)
end
local function StopAutoRewards() F.autoRewards = false; Gen.autoRewards = Gen.autoRewards + 1 end

-- ═══════════════════════════════════════════════════════════════════════
-- WALK
-- ═══════════════════════════════════════════════════════════════════════
local function FindGround(origin)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    if Player.Character then rp.FilterDescendantsInstances = {Player.Character} end
    local hit = workspace:Raycast(origin, Vector3.new(0, -1000, 0), rp)
    return hit and (hit.Position + Vector3.new(0, 3.5, 0)) or nil
end

local function RandomWalkablePos(origin, radius)
    for _ = 1, 20 do
        local ang = math.random() * 2 * math.pi
        local dist = math.random(15, radius)
        local pos = FindGround(Vector3.new(
            origin.X + math.cos(ang) * dist,
            origin.Y + 500,
            origin.Z + math.sin(ang) * dist
        ))
        if pos then return pos end
    end
    return nil
end

local function StartWalk()
    Gen.walk = Gen.walk + 1
    local myGen = Gen.walk
    task.spawn(function()
        while F.walk and Gen.walk == myGen and Z.Alive do
            local hrp = GetHRP()
            local hum = GetHum()
            if hrp and hum then
                local target = RandomWalkablePos(hrp.Position, 30)
                if target then
                    hum:MoveTo(target)
                    task.wait(S.walkInterval / 1000)
                end
            end
            task.wait(0.2)
        end
        local hum = GetHum(); local hrp = GetHRP()
        if hum and hrp then hum:MoveTo(hrp.Position) end
    end)
end
local function StopWalk()
    F.walk = false; Gen.walk = Gen.walk + 1
    local hum = GetHum(); local hrp = GetHRP()
    if hum and hrp then hum:MoveTo(hrp.Position) end
end

-- ═══════════════════════════════════════════════════════════════════════
-- TELEPORT
-- ═══════════════════════════════════════════════════════════════════════
local function StartTele()
    Gen.tele = Gen.tele + 1
    local myGen = Gen.tele
    task.spawn(function()
        while F.tele and Gen.tele == myGen and Z.Alive do
            task.wait(S.teleInterval)
            if not F.tele or Gen.tele ~= myGen then break end
            local hrp = GetHRP()
            if hrp then
                local dest = RandomWalkablePos(hrp.Position, S.teleRadius)
                if dest then hrp.CFrame = CFrame.new(dest) end
            end
        end
    end)
end
local function StopTele() F.tele = false; Gen.tele = Gen.tele + 1 end

-- ═══════════════════════════════════════════════════════════════════════
-- JUMP (infinito)
-- ═══════════════════════════════════════════════════════════════════════
Z.Track(UIS.JumpRequest:Connect(function()
    if F.jump and Z.Alive then
        local hum = GetHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

-- ═══════════════════════════════════════════════════════════════════════
-- ANTI-KNOCK
-- ═══════════════════════════════════════════════════════════════════════
Z.Track(RunService.Heartbeat:Connect(function()
    if not F.antiKnock or not Z.Alive then return end
    local hrp = GetHRP(); local hum = GetHum()
    if not hrp or not hum then return end
    if hum.MoveDirection.Magnitude < 0.1 then
        local v = hrp.AssemblyLinearVelocity
        if math.abs(v.X) > 5 or math.abs(v.Z) > 5 then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
            end)
        end
    end
end))

-- ═══════════════════════════════════════════════════════════════════════
-- ANTI-AFK
-- ═══════════════════════════════════════════════════════════════════════
local function StartAntiAfk()
    Gen.antiAfk = Gen.antiAfk + 1
    local myGen = Gen.antiAfk
    task.spawn(function()
        while F.antiAfk and Gen.antiAfk == myGen and Z.Alive do
            pcall(function()
                VIM:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, nil)
                task.wait(0.05)
                VIM:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, nil)
            end)
            task.wait(math.random(30, 60))
        end
    end)
end
local function StopAntiAfk() F.antiAfk = false; Gen.antiAfk = Gen.antiAfk + 1 end

-- ═══════════════════════════════════════════════════════════════════════
-- SETTERS (sincroniza UI + lógica)
-- ═══════════════════════════════════════════════════════════════════════
local UI = Z.UI

local function SetGrab(v)
    v = not not v
    F.grab = v; S.grabActive = v
    if UI.grab and UI.grab.SetState then UI.grab:SetState(v, true) end
    if v then StartGrab() else StopGrab() end
end

local function SetEat(v)
    v = not not v
    F.eat = v; S.eatActive = v
    if UI.eat and UI.eat.SetState then UI.eat:SetState(v, true) end
    if v then StartEat() else StopEat() end
end

local function SetThrow(v)
    v = not not v
    F.throw = v; S.throwActive = v
    if UI.throw and UI.throw.SetState then UI.throw:SetState(v, true) end
    if v then StartThrow() else StopThrow() end
end

local function SetSellTimer(v)
    v = not not v
    F.sellTimer = v; S.sellTimerActive = v
    if UI.sellTimer and UI.sellTimer.SetState then UI.sellTimer:SetState(v, true) end
    if v then
        if F.smartSell then SetSmartSell(false) end
        StartSellTimer()
    else
        StopSellTimer()
    end
end

local function SetSmartSell(v)
    v = not not v
    F.smartSell = v; S.smartSellActive = v
    if UI.smartSell and UI.smartSell.SetState then UI.smartSell:SetState(v, true) end
    if v then
        if F.sellTimer then SetSellTimer(false) end
        StartSmartSell()
    else
        StopSmartSell()
    end
end

local function SetAutoRewards(v)
    v = not not v
    F.autoRewards = v; S.autoRewardsActive = v
    if UI.autoRewards and UI.autoRewards.SetState then UI.autoRewards:SetState(v, true) end
    if v then StartAutoRewards() else StopAutoRewards() end
end

local function SetWalk(v)
    v = not not v
    F.walk = v; S.walkActive = v
    if UI.walk and UI.walk.SetState then UI.walk:SetState(v, true) end
    if v then StartWalk() else StopWalk() end
end

local function SetTele(v)
    v = not not v
    F.tele = v; S.teleActive = v
    if UI.tele and UI.tele.SetState then UI.tele:SetState(v, true) end
    if v then StartTele() else StopTele() end
end

local function SetJump(v)
    v = not not v
    F.jump = v; S.jumpActive = v
    if UI.jump and UI.jump.SetState then UI.jump:SetState(v, true) end
end

local function SetAntiKnock(v)
    v = not not v
    F.antiKnock = v; S.antiKnockActive = v
    if UI.antiKnock and UI.antiKnock.SetState then UI.antiKnock:SetState(v, true) end
end

local function SetAntiAfk(v)
    v = not not v
    F.antiAfk = v; S.antiAfkActive = v
    if UI.antiAfk and UI.antiAfk.SetState then UI.antiAfk:SetState(v, true) end
    if v then StartAntiAfk() else StopAntiAfk() end
end

-- ═══════════════════════════════════════════════════════════════════════
-- KEYBINDS
-- ═══════════════════════════════════════════════════════════════════════
Z.Track(UIS.InputBegan:Connect(function(input, gpe)
    if gpe or not Z.Alive then return end
    if input.KeyCode == Enum.KeyCode.G then
        SetGrab(not F.grab)
        Z.Notify("Grab", F.grab and "Ativado" or "Desativado", F.grab and C.Success or C.TextDim, 2)
    elseif input.KeyCode == Enum.KeyCode.E then
        SetEat(not F.eat)
        Z.Notify("Eat", F.eat and "Ativado" or "Desativado", F.eat and C.Success or C.TextDim, 2)
    elseif input.KeyCode == Enum.KeyCode.T then
        SetThrow(not F.throw)
        Z.Notify("Throw", F.throw and "Ativado" or "Desativado", F.throw and C.Success or C.TextDim, 2)
    elseif input.KeyCode == Enum.KeyCode.V then
        if F.smartSell then
            SetSmartSell(false); SetSellTimer(true)
        elseif F.sellTimer then
            SetSellTimer(false); SetSmartSell(true)
        else
            SetSellTimer(true)
        end
    end
end))

-- ═══════════════════════════════════════════════════════════════════════
-- STATUS BAR
-- ═══════════════════════════════════════════════════════════════════════
local Main = Z.GUI.Main

local statusFrame = Instance.new("Frame", Main)
statusFrame.Size = UDim2.new(1, -220, 0, 22)
statusFrame.Position = UDim2.new(0, 210, 1, -32)
statusFrame.BackgroundColor3 = C.Card
statusFrame.BorderSizePixel = 0
statusFrame.ZIndex = 20
Instance.new("UICorner", statusFrame).CornerRadius = UDim.new(0, 6)

local statusText = Instance.new("TextLabel", statusFrame)
statusText.Size = UDim2.new(1, -16, 1, 0)
statusText.Position = UDim2.fromOffset(8, 0)
statusText.BackgroundTransparency = 1
statusText.Font = Enum.Font.GothamBold
statusText.TextSize = 10
statusText.TextColor3 = C.TextDim
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.ZIndex = 21

Z.Track(RunService.Heartbeat:Connect(function()
    if not Z.Alive or not statusFrame.Parent then return end
    local active = {}
    if F.grab then table.insert(active, "🖐") end
    if F.eat then table.insert(active, "🍽") end
    if F.throw then table.insert(active, "🗑") end
    if F.sellTimer then table.insert(active, "💰") end
    if F.smartSell then table.insert(active, "🧠") end
    if F.autoRewards then table.insert(active, "🎁") end
    if F.walk then table.insert(active, "🚶") end
    if F.tele then table.insert(active, "🌀") end
    if F.jump then table.insert(active, "⬆") end
    if F.antiAfk then table.insert(active, "👆") end

    if #active == 0 then
        statusText.Text = "💤 Nenhum módulo ativo"
    else
        statusText.Text = "✅ Ativos: " .. table.concat(active, " ")
    end
end))

-- ═══════════════════════════════════════════════════════════════════════
-- TAB: AUTO FARM
-- ═══════════════════════════════════════════════════════════════════════
local function LoadAutoFarm()
    Z.GUI.Clear()
    Z.GUI.TabTitle.Text = "🌾 Auto Farm"

    -- AUTO GRAB
    Z.Sep("🖐️  AUTO GRAB")
    Z.Info("Pega objetos automaticamente. Só tenta se não tiver chunk.")
    UI.grab = Z.Toggle("Ativar Auto Grab", F.grab, SetGrab)
    Z.Slider("Intervalo entre tentativas (ms)", 100, 3000, S.grabInterval, function(v)
        S.grabInterval = v
    end)
    Z.Slider("Pausa após falha (s)", 1, 15, S.grabPauseDuration, function(v)
        S.grabPauseDuration = v
    end)
    UI.grabSellOnFail = Z.Toggle("Auto Sell ao falhar grab", S.grabSellOnFail, function(v)
        S.grabSellOnFail = v
    end)

    -- AUTO EAT
    Z.Sep("🍽️  AUTO EAT")
    Z.Info("Come automaticamente. Ideal para crescer rapidamente.")
    UI.eat = Z.Toggle("Ativar Auto Eat", F.eat, SetEat)
    Z.Slider("Intervalo entre mordidas (ms)", 100, 3000, S.eatInterval, function(v)
        S.eatInterval = v
    end)

    -- AUTO THROW
    Z.Sep("🗑️  AUTO THROW")
    Z.Info("Joga o que estiver na mão fora. Útil para liberar grab.")
    UI.throw = Z.Toggle("Ativar Auto Throw", F.throw, SetThrow)
    Z.Slider("Intervalo entre arremessos (ms)", 100, 3000, S.throwInterval, function(v)
        S.throwInterval = v
    end)

    -- AUTO SELL
    Z.Sep("💰  AUTO SELL (TIMER)")
    Z.Info("Vende a cada X ms. Simples e direto.")
    UI.sellTimer = Z.Toggle("Ativar Sell Timer", F.sellTimer, SetSellTimer)
    Z.Slider("Vender a cada (ms)", 1000, 60000, S.sellTimerInterval, function(v)
        S.sellTimerInterval = v
    end)

    -- SMART SELL
    Z.Sep("🧠  SMART SELL (TAMANHO)")
    Z.Info("Verifica leaderstats.Size. Se parar de crescer, vende.")
    UI.smartSell = Z.Toggle("Ativar Smart Sell", F.smartSell, SetSmartSell)
    Z.Slider("Tempo travado para vender (s)", 2, 20, S.smartSellThreshold, function(v)
        S.smartSellThreshold = v
    end)

    -- AUTO REWARDS
    Z.Sep("🎁  AUTO RESGATAR RECOMPENSAS")
    Z.Info("Resgata recompensas de tempo (TimedRewards) automaticamente.")
    UI.autoRewards = Z.Toggle("Ativar Auto Rewards", F.autoRewards, SetAutoRewards)
    Z.Slider("Delay entre resgates (s)", 1, 10, S.autoRewardsDelay, function(v)
        S.autoRewardsDelay = v
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- TAB: MOVIMENTO
-- ═══════════════════════════════════════════════════════════════════════
local function LoadMovement()
    Z.GUI.Clear()
    Z.GUI.TabTitle.Text = "🚶 Movimento"

    Z.Sep("🚶  AUTO WALK")
    Z.Info("Anda aleatoriamente pelo mapa com detecção de chão.")
    UI.walk = Z.Toggle("Ativar Auto Walk", F.walk, SetWalk)
    Z.Slider("Intervalo de passos (ms)", 200, 3000, S.walkInterval, function(v)
        S.walkInterval = v
    end)

    Z.Sep("🌀  AUTO TELEPORT")
    Z.Info("Teleporta para posições aleatórias próximas.")
    UI.tele = Z.Toggle("Ativar Auto Teleport", F.tele, SetTele)
    Z.Slider("Teleportar a cada (s)", 1, 120, S.teleInterval, function(v)
        S.teleInterval = v
    end)
    Z.Slider("Raio de distância (studs)", 50, 4096, S.teleRadius, function(v)
        S.teleRadius = v
    end)

    Z.Sep("⬆️  AUTO JUMP")
    Z.Info("Permite pular infinitamente no ar.")
    UI.jump = Z.Toggle("Ativar Auto Jump", F.jump, SetJump)
end

-- ═══════════════════════════════════════════════════════════════════════
-- TAB: MISC
-- ═══════════════════════════════════════════════════════════════════════
local function LoadMisc()
    Z.GUI.Clear()
    Z.GUI.TabTitle.Text = "⚙️ Misc"

    Z.Sep("🛡️  UTILIDADES")
    Z.Info("Anti Knockback: impede empurrões.")
    UI.antiKnock = Z.Toggle("Ativar Anti Knockback", F.antiKnock, SetAntiKnock)
    Z.Info("Anti AFK: teclas periódicas para evitar kick.")
    UI.antiAfk = Z.Toggle("Ativar Anti AFK", F.antiAfk, SetAntiAfk)

    Z.Sep("🔧  AÇÕES RÁPIDAS")
    Z.Button("🔄 Respawn", C.AccentDark, function()
        Player:LoadCharacter()
        Z.Notify("Respawn", "Personagem recriado", C.Success, 2)
    end)

    Z.Button("🏠 TP para Origem", C.AccentDark, function()
        local hrp = GetHRP()
        if hrp then
            local ground = FindGround(Vector3.new(0, 500, 0))
            hrp.CFrame = CFrame.new(ground or Vector3.new(0, 5, 0))
            Z.Notify("Teleport", "Teleportado para origem", C.Success, 2)
        end
    end)

    Z.Button("🖐️ Soltar Grab Forçado", C.Danger, function()
        FireEvent("GrabRelease")
        FireEvent("ReleaseGrab")
        FireEvent("Drop")
        FireEvent("LetGo")
        pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.G, false, nil)
            task.wait(0.05)
            VIM:SendKeyEvent(false, Enum.KeyCode.G, false, nil)
        end)
        Z.Notify("Grab", "Chunk solto forçadamente", C.Warning, 2)
    end)

    Z.Sep("📋  INFO")
    Z.Info("[G] Grab | [E] Eat | [T] Throw")
    Z.Info("[V] Alterna entre Timer Sell e Smart Sell")
    Z.Info("Pressione INSERT para abrir/fechar")
end

-- ═══════════════════════════════════════════════════════════════════════
-- REGISTER TABS
-- ═══════════════════════════════════════════════════════════════════════
Z.AddTab("Auto Farm", "🌾", LoadAutoFarm)
Z.AddTab("Movimento", "🚶", LoadMovement)
Z.AddTab("Misc",      "⚙️", LoadMisc)

-- ═══════════════════════════════════════════════════════════════════════
-- WELCOME
-- ═══════════════════════════════════════════════════════════════════════
Z.Notify("Zuni Hub", "Módulo ETW carregado com sucesso!", C.Success, 4)

print("[ETW Module v3.0] ✓ Carregado")
print("  - Auto Grab / Eat / Throw")
print("  - Sell Timer / Smart Sell (Size)")
print("  - Auto Rewards (TimedRewards)")
print("  - Auto Walk / Teleport / Jump")
print("  - Anti Knock / Anti AFK")
