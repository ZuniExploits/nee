-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ZUNI HUB - NDS MODULE v1.0                                        ║
-- ║  Fling • Aim Fling • Fling All • Safezone • ESP • Utilidades       ║
-- ╚══════════════════════════════════════════════════════════════════════╝

if not _G.ZuniHub or not _G.ZuniHub.Ready then
    warn("[NDS] Base não está pronta!")
    return
end

local Z = _G.ZuniHub
if Z.NDSLoaded then return end
Z.NDSLoaded = true
Z.ModuleName = "NDS"

local C      = Z.Colors
local S      = Z.SavedStates
local UI     = Z.UI
local Player = game:GetService("Players").LocalPlayer
local UIS    = game:GetService("UserInputService")
local RS     = game:GetService("RunService")
local Players = game:GetService("Players")

-- ═══════════════════════════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════════════════════════
local function Def(k, v) if S[k] == nil then S[k] = v end end
Def("safezoneHealth", 30)
Def("safezoneEnabled", false)
Def("espEnabled", false)
Def("espName", true)
Def("espHealth", true)
Def("espDistance", true)

-- ═══════════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════════
local function GetChar(p)
    p = p or Player
    return p.Character
end

local function GetHRP(p)
    local c = GetChar(p)
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetHum(p)
    local c = GetChar(p)
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function IsAlive(p)
    local h = GetHum(p)
    return h and h.Health > 0
end

-- ═══════════════════════════════════════════════════════════════════════
-- WIDGET: PLAYER DROPDOWN (lista de jogadores atualizada automaticamente)
-- ═══════════════════════════════════════════════════════════════════════
local function PlayerDropdown(name, callback, desc)
    local card = Z.Card(desc and 62 or 50)
    card.ClipsDescendants = true

    Z.Util.Label(card, name, 14, C.Text, Enum.Font.GothamBold,
        UDim2.fromOffset(16, desc and 10 or 0), UDim2.new(1, -32, 0, desc and 20 or 50))
    if desc then
        Z.Util.Label(card, desc, 12, C.TextDim, Enum.Font.Gotham,
            UDim2.fromOffset(16, 33), UDim2.new(1, -32, 0, 20))
    end

    local selY = desc and 46 or 30
    local selectBtn = Z.Util.New("TextButton", {
        Size = UDim2.new(1, -32, 0, 32),
        Position = UDim2.fromOffset(16, selY),
        BackgroundColor3 = C.CardHover,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
    }, card)
    Z.Util.Corner(selectBtn, 8)
    Z.Util.Stroke(selectBtn, C.Border, 1, 0.5)

    local valLbl = Z.Util.Label(selectBtn, "Selecionar jogador...", 13, C.TextMuted,
        Enum.Font.GothamMedium, UDim2.fromOffset(12, 0), UDim2.new(1, -34, 1, 0))

    local listHolder = Z.Util.New("ScrollingFrame", {
        Size = UDim2.new(1, -32, 0, 0),
        Position = UDim2.fromOffset(16, selY + 38),
        BackgroundColor3 = C.Bg,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.Accent,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, card)
    Z.Util.Corner(listHolder, 8)
    Z.Util.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, listHolder)

    local selected, isOpen, itemButtons = nil, false, {}

    local function CloseList()
        if not isOpen then return end
        isOpen = false
        Z.Util.Tween(card, 0.15, { Size = UDim2.new(1, 0, 0, desc and 62 or 50) })
        task.delay(0.15, function()
            if not isOpen and listHolder.Parent then listHolder.Visible = false end
        end)
    end

    local function RenderItems()
        for _, b in ipairs(itemButtons) do b:Destroy() end
        table.clear(itemButtons)

        local players = Players:GetPlayers()
        for i, p in ipairs(players) do
            if p == Player then continue end
            local item = Z.Util.New("TextButton", {
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundColor3 = C.Accent,
                BackgroundTransparency = 1,
                Text = "  " .. p.Name,
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextColor3 = C.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                LayoutOrder = i,
            }, listHolder)
            item.MouseEnter:Connect(function() Z.Util.Tween(item, 0.1, { BackgroundTransparency = 0.45 }) end)
            item.MouseLeave:Connect(function() Z.Util.Tween(item, 0.1, { BackgroundTransparency = 1 }) end)
            item.MouseButton1Click:Connect(function()
                selected = p
                valLbl.Text = p.Name
                valLbl.TextColor3 = C.Text
                CloseList()
                if callback then pcall(callback, p) end
            end)
            table.insert(itemButtons, item)
        end
    end

    local function OpenList()
        if isOpen then return end
        RenderItems()
        if #itemButtons == 0 then
            Z.Notify("NDS", "Nenhum outro jogador no servidor.", C.Warning, 2)
            return
        end
        isOpen = true
        listHolder.Visible = true
        local h = math.min(150, #itemButtons * 28 + 4)
        listHolder.Size = UDim2.new(1, -32, 0, h)
        Z.Util.Tween(card, 0.15, { Size = UDim2.new(1, 0, 0, (desc and 62 or 50) + h + 8) })
    end

    selectBtn.MouseButton1Click:Connect(function()
        if isOpen then CloseList() else OpenList() end
    end)

    -- Atualiza lista quando jogadores entram/saem
    Z.PageTrack(Players.PlayerAdded:Connect(function()
        if isOpen then RenderItems() end
    end))
    Z.PageTrack(Players.PlayerRemoving:Connect(function(p)
        if selected == p then
            selected = nil
            valLbl.Text = "Selecionar jogador..."
            valLbl.TextColor3 = C.TextMuted
        end
        if isOpen then RenderItems() end
    end))

    return {
        Frame = card,
        Get = function() return selected end,
        Set = function(p, silent)
            selected = p
            valLbl.Text = p and p.Name or "Selecionar jogador..."
            valLbl.TextColor3 = p and C.Text or C.TextMuted
            if not silent and callback then pcall(callback, p) end
        end,
    }
end

-- ═══════════════════════════════════════════════════════════════════════
-- FLING (genérico — baseado em velocidade angular / colisão)
-- ═══════════════════════════════════════════════════════════════════════
local flingActive = false
local flingTarget = nil
local flingConn = nil

local function StopFling()
    flingActive = false
    if flingConn then
        pcall(function() flingConn:Disconnect() end)
        flingConn = nil
    end
    -- Restaura HRP se possível
    local hrp = GetHRP()
    if hrp then
        pcall(function()
            hrp.Velocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
        end)
    end
end

local function StartFling(targetPlayer)
    if flingActive then StopFling() end
    if not targetPlayer or not IsAlive(targetPlayer) then return end

    flingActive = true
    flingTarget = targetPlayer

    flingConn = RS.Heartbeat:Connect(function()
        if not flingActive then return end

        local myChar = GetChar()
        local myHRP = GetHRP()
        local tgtHRP = GetHRP(flingTarget)
        local tgtHum = GetHum(flingTarget)

        if not (myChar and myHRP and tgtHRP and tgtHum and tgtHum.Health > 0) then
            StopFling()
            Z.Notify("NDS", "Fling parado (alvo morto ou saiu).", C.TextDim, 2)
            return
        end

        -- Teleporta para o alvo e aplica velocidade angular alta
        pcall(function()
            myHRP.CFrame = tgtHRP.CFrame * CFrame.new(0, 0, -1.5)
            myHRP.Velocity = Vector3.new(0, 50, 0)
            myHRP.RotVelocity = Vector3.new(0, 5000, 0)
        end)
    end)

    Z.Notify("NDS", "Fling ativado em " .. targetPlayer.Name, C.Success, 3)
end

-- ═══════════════════════════════════════════════════════════════════════
-- FLING ALL (uma vez — botão)
-- ═══════════════════════════════════════════════════════════════════════
local function FlingAllOnce()
    local myHRP = GetHRP()
    if not myHRP then return end

    for _, p in ipairs(Players:GetPlayers()) do
        if p == Player then continue end
        local hrp = GetHRP(p)
        local hum = GetHum(p)
        if hrp and hum and hum.Health > 0 then
            pcall(function()
                -- Aproxima e aplica impulso
                myHRP.CFrame = hrp.CFrame * CFrame.new(0, 0, -1)
                myHRP.Velocity = Vector3.new(0, 200, 0)
                myHRP.RotVelocity = Vector3.new(0, 8000, 0)
            end)
            task.wait(0.1)
        end
    end
    Z.Notify("NDS", "Fling All executado.", C.Accent, 2)
end

-- ═══════════════════════════════════════════════════════════════════════
-- SAFEZONE (quando vida baixa)
-- ═══════════════════════════════════════════════════════════════════════
local safezoneActive = false
local safezoneConn = nil

local function StopSafezone()
    safezoneActive = false
    if safezoneConn then
        pcall(function() safezoneConn:Disconnect() end)
        safezoneConn = nil
    end
end

local function StartSafezone()
    if safezoneActive then return end
    safezoneActive = true

    safezoneConn = RS.Heartbeat:Connect(function()
        if not safezoneActive then return end
        local hum = GetHum()
        local hrp = GetHRP()
        if not (hum and hrp) then return end

        if hum.Health <= S.safezoneHealth and hum.Health > 0 then
            -- Teleporta para longe (cima) e aplica ghost temporário
            pcall(function()
                hrp.CFrame = hrp.CFrame + Vector3.new(0, 500, 0)
                hrp.Velocity = Vector3.zero
            end)
            task.wait(1)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- ESP (Highlights + BillboardGui simples)
-- ═══════════════════════════════════════════════════════════════════════
local espObjects = {}
local espConn = nil

local function ClearESP()
    for p, data in pairs(espObjects) do
        if data.highlight then pcall(function() data.highlight:Destroy() end) end
        if data.billboard then pcall(function() data.billboard:Destroy() end) end
    end
    table.clear(espObjects)
end

local function CreateESPForPlayer(p)
    if p == Player then return end
    local char = GetChar(p)
    if not char then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "ZuniESP_" .. p.Name
    highlight.FillColor = C.Accent
    highlight.FillTransparency = 0.6
    highlight.OutlineColor = C.AccentLight
    highlight.OutlineTransparency = 0
    highlight.Parent = char

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ZuniESP_BB_" .. p.Name
    billboard.Size = UDim2.new(0, 200, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "Name"
    nameLbl.Size = UDim2.new(1, 0, 0, 20)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = p.Name
    nameLbl.TextColor3 = C.Text
    nameLbl.TextSize = 14
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.Parent = billboard

    local healthLbl = Instance.new("TextLabel")
    healthLbl.Name = "Health"
    healthLbl.Size = UDim2.new(1, 0, 0, 16)
    healthLbl.Position = UDim2.new(0, 0, 0, 20)
    healthLbl.BackgroundTransparency = 1
    healthLbl.Text = "HP: --"
    healthLbl.TextColor3 = C.Success
    healthLbl.TextSize = 12
    healthLbl.Font = Enum.Font.Gotham
    healthLbl.Parent = billboard

    local distLbl = Instance.new("TextLabel")
    distLbl.Name = "Distance"
    distLbl.Size = UDim2.new(1, 0, 0, 16)
    distLbl.Position = UDim2.new(0, 0, 0, 36)
    distLbl.BackgroundTransparency = 1
    distLbl.Text = "-- studs"
    distLbl.TextColor3 = C.TextDim
    distLbl.TextSize = 11
    distLbl.Font = Enum.Font.Gotham
    distLbl.Parent = billboard

    espObjects[p] = { highlight = highlight, billboard = billboard }
end

local function StartESP()
    ClearESP()
    for _, p in ipairs(Players:GetPlayers()) do
        CreateESPForPlayer(p)
    end

    espConn = RS.RenderStepped:Connect(function()
        if not S.espEnabled then return end
        local myHRP = GetHRP()
        if not myHRP then return end

        for p, data in pairs(espObjects) do
            local char = GetChar(p)
            local hrp = GetHRP(p)
            local hum = GetHum(p)
            if not (char and hrp and hum and hum.Health > 0) then
                if data.billboard then data.billboard.Enabled = false end
                if data.highlight then data.highlight.Enabled = false end
                continue
            end

            if data.highlight then data.highlight.Enabled = true end
            if data.billboard then
                data.billboard.Enabled = true
                local nameLbl = data.billboard:FindFirstChild("Name")
                local healthLbl = data.billboard:FindFirstChild("Health")
                local distLbl = data.billboard:FindFirstChild("Distance")

                if nameLbl then nameLbl.Visible = S.espName end
                if healthLbl then
                    healthLbl.Visible = S.espHealth
                    healthLbl.Text = string.format("HP: %d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth))
                    local ratio = hum.Health / hum.MaxHealth
                    healthLbl.TextColor3 = ratio > 0.6 and C.Success or (ratio > 0.3 and C.Warning or C.Danger)
                end
                if distLbl then
                    distLbl.Visible = S.espDistance
                    distLbl.Text = string.format("%d studs", math.floor((hrp.Position - myHRP.Position).Magnitude))
                end
            end
        end
    end)

    Z.PageTrack(Players.PlayerAdded:Connect(function(p)
        task.wait(1)
        if S.espEnabled then CreateESPForPlayer(p) end
    end))
    Z.PageTrack(Players.PlayerRemoving:Connect(function(p)
        local data = espObjects[p]
        if data then
            if data.highlight then pcall(function() data.highlight:Destroy() end) end
            if data.billboard then pcall(function() data.billboard:Destroy() end) end
            espObjects[p] = nil
        end
    end))
end

local function StopESP()
    if espConn then
        pcall(function() espConn:Disconnect() end)
        espConn = nil
    end
    ClearESP()
end

-- ═══════════════════════════════════════════════════════════════════════
-- UTILIDADES: Noclip, Inf Jump, Fly
-- ═══════════════════════════════════════════════════════════════════════
local noclipConn = nil
local flyConn = nil
local infJumpConn = nil
local flyActive, flySpeed = false, 100

local function StartNoclip()
    if noclipConn then return end
    noclipConn = RS.Stepped:Connect(function()
        local char = GetChar()
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function() part.CanCollide = false end)
            end
        end
    end)
end

local function StopNoclip()
    if noclipConn then
        pcall(function() noclipConn:Disconnect() end)
        noclipConn = nil
    end
    local char = GetChar()
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                pcall(function() part.CanCollide = true end)
            end
        end
    end
end

local function StartFly()
    if flyConn then return end
    flyActive = true
    local bodyVel = nil
    local bodyGyro = nil

    flyConn = RS.Heartbeat:Connect(function()
        if not flyActive then return end
        local hrp = GetHRP()
        if not hrp then return end

        if not bodyVel or not bodyVel.Parent then
            bodyVel = Instance.new("BodyVelocity")
            bodyVel.Name = "ZuniFly"
            bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bodyVel.Velocity = Vector3.zero
            bodyVel.Parent = hrp
        end
        if not bodyGyro or not bodyGyro.Parent then
            bodyGyro = Instance.new("BodyGyro")
            bodyGyro.Name = "ZuniFlyGyro"
            bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bodyGyro.P = 10000
            bodyGyro.D = 500
            bodyGyro.Parent = hrp
        end

        local cam = workspace.CurrentCamera
        local moveDir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then moveDir += cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then moveDir -= cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then moveDir -= cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then moveDir += cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir -= Vector3.new(0, 1, 0) end

        bodyVel.Velocity = moveDir * flySpeed
        bodyGyro.CFrame = cam.CFrame
    end)
end

local function StopFly()
    flyActive = false
    if flyConn then
        pcall(function() flyConn:Disconnect() end)
        flyConn = nil
    end
    local hrp = GetHRP()
    if hrp then
        local bv = hrp:FindFirstChild("ZuniFly")
        local bg = hrp:FindFirstChild("ZuniFlyGyro")
        if bv then bv:Destroy() end
        if bg then bg:Destroy() end
    end
end

local function StartInfJump()
    if infJumpConn then return end
    infJumpConn = UIS.JumpRequest:Connect(function()
        local hum = GetHum()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

local function StopInfJump()
    if infJumpConn then
        pcall(function() infJumpConn:Disconnect() end)
        infJumpConn = nil
    end
end

-- ═══════════════════════════════════════════════════════════════════════
-- ABA MAIN
-- ═══════════════════════════════════════════════════════════════════════
local function LoadMain()
    -- FLING ---------------------------------------------------------------
    Z.Sep("🎯  FLING")
    Z.Button("Fling All (uma vez)", C.Warning, FlingAllOnce)

    -- Dropdown de alvo para Aim Fling
    UI.flingTarget = PlayerDropdown("Alvo do Fling", function(p)
        flingTarget = p
    end, "Escolha um jogador para flingar continuamente")

    local flingToggle = Z.Toggle("Aim Fling (contínuo)", false, function(v)
        if v then
            local target = UI.flingTarget and UI.flingTarget.Get()
            if not target then
                Z.Notify("NDS", "Selecione um alvo primeiro.", C.Warning, 2)
                if flingToggle then flingToggle.Set(false, true) end
                return
            end
            StartFling(target)
        else
            StopFling()
        end
    end, "Flinga o alvo selecionado sem parar")

    Z.Button("Parar Fling", C.Danger, function()
        StopFling()
        if flingToggle then flingToggle.Set(false, true) end
        Z.Notify("NDS", "Fling parado.", C.TextDim, 2)
    end)

    -- SAFEZONE ------------------------------------------------------------
    Z.Sep("🛡️  SAFEZONE")
    Z.Toggle("Safezone (vida baixa)", S.safezoneEnabled, function(v)
        S.safezoneEnabled = v
        if v then StartSafezone() else StopSafezone() end
    end, "Teleporta para cima quando a vida fica abaixo do limite")
    Z.Slider("Vida mínima", 10, 80, S.safezoneHealth, function(v)
        S.safezoneHealth = v
    end, { step = 5, suffix = " HP" })

    -- ESP ----------------------------------------------------------------
    Z.Sep("👁️  ESP")
    local espToggle = Z.Toggle("Ativar ESP", S.espEnabled, function(v)
        S.espEnabled = v
        if v then StartESP() else StopESP() end
    end, "Mostra nome, vida e distância dos jogadores")

    Z.Toggle("Mostrar nome", S.espName, function(v) S.espName = v end)
    Z.Toggle("Mostrar vida", S.espHealth, function(v) S.espHealth = v end)
    Z.Toggle("Mostrar distância", S.espDistance, function(v) S.espDistance = v end)

    -- UTILIDADES ---------------------------------------------------------
    Z.Sep("⚙️  UTILIDADES")

    local noclipToggle = Z.Toggle("Noclip", false, function(v)
        if v then StartNoclip() else StopNoclip() end
    end, "Atravessa paredes e objetos")

    local infJumpToggle = Z.Toggle("Infinite Jump", false, function(v)
        if v then StartInfJump() else StopInfJump() end
    end, "Pula infinitas vezes no ar")

    local flyToggle = Z.Toggle("Fly", false, function(v)
        if v then StartFly() else StopFly() end
    end, "Voa com WASD + Space/Ctrl")

    Z.Slider("Velocidade do Fly", 20, 500, flySpeed, function(v)
        flySpeed = v
    end, { step = 10, suffix = " studs/s" })

    -- Limpeza ao trocar de aba
    Z.PageTrack({ Disconnect = function()
        StopFling()
        StopSafezone()
        StopESP()
        StopNoclip()
        StopInfJump()
        StopFly()
    end })
end

Z.AddTab("NDS", "⚔️", LoadMain)
Z.SelectTab("NDS")
Z.Notify("Zuni Hub", "Módulo NDS v1.0 carregado!", C.Success, 3)
print("⚔️ NDS Module v1.0 iniciado")
