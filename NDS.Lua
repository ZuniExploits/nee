-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ZUNI HUB - NDS MODULE v1.0  (Natural Disaster Survival)           ║
-- ║  Fling • Aim Fling • Fling All • Safezone • ESP                    ║
-- ╚══════════════════════════════════════════════════════════════════════╝

if not _G.ZuniHub or not _G.ZuniHub.Ready then
    warn("[NDS] Base não está pronta!")
    return
end

local Z = _G.ZuniHub
if Z.NDSLoaded then return end
Z.NDSLoaded = true
Z.ModuleName = "NDS"

local C          = Z.Colors
local S          = Z.SavedStates
local UI         = Z.UI
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Player     = Players.LocalPlayer
local ZERO       = Vector3.zero

-- ═══════════════════════════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════════════════════════
local SAFE_POS = Vector3.new(4000, 1200, 4000) -- plataforma local, longe do mapa

local function Def(k, v) if S[k] == nil then S[k] = v end end
Def("ndsTarget", nil)        -- UserId do alvo (Aim Fling)
Def("flingPower", 500)       -- em milhares
Def("flingTime", 3)          -- segundos máx. por alvo
Def("walkFling", false)
Def("aimFling", false)
Def("safeOn", false)
Def("safeThreshold", 35)     -- % de vida pra entrar na safezone
Def("safeReturn", true)
Def("safeReturnAt", 90)      -- % de vida pra voltar sozinho
Def("espOn", false)
Def("espName", true)
Def("espHealth", true)
Def("espDist", true)
Def("espTool", false)
Def("espBox", true)
Def("espMaxDist", 1500)

-- ═══════════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════════
local function GetHRP() local c = Player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHum() local c = Player.Character return c and c:FindFirstChildOfClass("Humanoid") end

local function TargetParts(p)
    local ch = p and p.Character
    if not ch then return nil end
    local h  = ch:FindFirstChild("HumanoidRootPart")
    local hu = ch:FindFirstChildOfClass("Humanoid")
    if h and hu and hu.Health > 0 then return h, hu end
    return nil
end

local function GetTarget()
    if not S.ndsTarget then return nil end
    return Players:GetPlayerByUserId(S.ndsTarget)
end

-- ═══════════════════════════════════════════════════════════════════════
-- SAFEZONE
-- Plataforma LOCAL (só você vê) no céu, longe do mapa. O servidor confia na
-- posição do seu personagem, então você fica fora do alcance dos desastres.
-- ═══════════════════════════════════════════════════════════════════════
local Safe = { active = false, manual = false, saved = nil, part = nil }

local function EnsurePlatform()
    if Safe.part and Safe.part.Parent then return end
    local p = Instance.new("Part")
    p.Name = "ZuniSafe"
    p.Anchored = true
    p.Size = Vector3.new(80, 2, 80)
    p.Position = SAFE_POS
    p.Transparency = 0.6
    p.Material = Enum.Material.ForceField
    p.Color = C.Success
    p.Parent = workspace
    Safe.part = p
end

local function GoSafe(manual, reason)
    if Safe.active then return end
    local hrp = GetHRP()
    if not hrp then return end
    Safe.saved = hrp.CFrame
    Safe.active, Safe.manual = true, manual or false
    EnsurePlatform()
    hrp.AssemblyLinearVelocity = ZERO
    hrp.AssemblyAngularVelocity = ZERO
    hrp.CFrame = CFrame.new(SAFE_POS + Vector3.new(0, 4, 0))
    Z.Notify("Safezone", reason or "Você está na safezone.", C.Warning, 3)
end

local function LeaveSafe()
    if not Safe.active then return end
    Safe.active, Safe.manual = false, false
    local hrp = GetHRP()
    if hrp and Safe.saved then
        hrp.AssemblyLinearVelocity = ZERO
        hrp.CFrame = Safe.saved
    end
    Safe.saved = nil
    if Safe.part then pcall(function() Safe.part:Destroy() end) Safe.part = nil end
    Z.Notify("Safezone", "Você saiu da safezone.", C.Accent, 2)
end

Z.Track(Player.CharacterAdded:Connect(function()
    Safe.active, Safe.manual, Safe.saved = false, false, nil
end))

task.spawn(function()
    while Z.Alive do
        task.wait(0.1)
        local hum, hrp = GetHum(), GetHRP()
        if hum and hrp and hum.Health > 0 then
            local pct = hum.Health / math.max(hum.MaxHealth, 1) * 100
            if not Safe.active then
                if S.safeOn and pct <= S.safeThreshold then
                    GoSafe(false, string.format("Vida baixa (%d%%). Teleportado!", math.floor(pct)))
                end
            else
                if hrp.Position.Y < SAFE_POS.Y - 60 then -- caiu da plataforma
                    hrp.AssemblyLinearVelocity = ZERO
                    hrp.CFrame = CFrame.new(SAFE_POS + Vector3.new(0, 4, 0))
                end
                if S.safeReturn and not Safe.manual and pct >= S.safeReturnAt then
                    LeaveSafe()
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- FLING
-- Como funciona: o Roblox deixa o CLIENTE simular a física do próprio
-- personagem. Se o seu HumanoidRootPart gira/anda com velocidade absurda e
-- encosta em outro player, a colisão transfere esse momento e ele é
-- arremessado. Depois zeramos a nossa velocidade e voltamos pro lugar.
--  • Fling (toque): trapaça de velocidade (aplica a velocidade enorme só no
--    passo de física e devolve a normal antes de renderizar) -> você anda
--    normal, mas quem encosta voa.
--  • Aim Fling / Fling All: teleporta pra cima do alvo a cada frame girando
--    com velocidade enorme até ele voar, depois volta pra sua posição.
-- ═══════════════════════════════════════════════════════════════════════
local Fling = { busy = false, lock = false, walkGen = 0, aimGen = 0 }

local function Power() return (S.flingPower or 500) * 1000 end

local OFFSETS = {
    Vector3.new(0, 1.2, 0), Vector3.new(0, -1.2, 0),
    Vector3.new(1.5, 0, 0), Vector3.new(-1.5, 0, 0),
    Vector3.new(0, 0, 1.5), Vector3.new(0, 0, -1.5),
}

local function FlingPlayer(target, maxTime)
    if Fling.busy or Safe.active then return false end
    local hrp, hum = GetHRP(), GetHum()
    if not (hrp and hum and hum.Health > 0) then return false end
    local tHrp, tHum = TargetParts(target)
    if not tHrp then return false end

    Fling.busy = true
    Z.NoclipPaused = true -- precisa colidir com o alvo
    local origin   = hrp.CFrame
    local cam      = workspace.CurrentCamera
    local oldProps = hrp.CustomPhysicalProperties
    hrp.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
    pcall(function() cam.CameraSubject = tHum end) -- câmera no alvo (menos tontura)

    local startPos = tHrp.Position
    local t0, i, flung = tick(), 0, false

    local ok, err = pcall(function()
        while Z.Alive and tick() - t0 < maxTime do
            RunService.Heartbeat:Wait()
            hrp, hum = GetHRP(), GetHum()
            tHrp, tHum = TargetParts(target)
            if not (hrp and hum and hum.Health > 0 and tHrp) or Safe.active then break end

            if tHrp.AssemblyLinearVelocity.Magnitude > 600 or (tHrp.Position - startPos).Magnitude > 300 then
                flung = true
                break
            end

            i += 1
            local P = Power()
            local pred = tHrp.AssemblyLinearVelocity * 0.1
            hrp.CanCollide = true
            hrp.CFrame = CFrame.new(tHrp.Position + pred + OFFSETS[i % #OFFSETS + 1])
                * CFrame.Angles(math.rad(i * 53), math.rad(i * 31), 0)
            hrp.AssemblyAngularVelocity = Vector3.new(P, P, P)
            hrp.AssemblyLinearVelocity = Vector3.new(P * 0.1, P * 0.1, P * 0.1)
        end
    end)

    pcall(function()
        local h = GetHRP()
        if h then
            h.CustomPhysicalProperties = oldProps
            for _ = 1, 12 do
                h.AssemblyLinearVelocity = ZERO
                h.AssemblyAngularVelocity = ZERO
                if not Safe.active then h.CFrame = origin end
                RunService.Heartbeat:Wait()
            end
        end
        local mh = GetHum()
        if mh then cam.CameraSubject = mh end
    end)

    Z.NoclipPaused = false
    Fling.busy = false
    if not ok then warn("[NDS] Fling: " .. tostring(err)) end
    return flung
end

-- Fling (toque / walk fling) ---------------------------------------------
local function SetWalkFling(v)
    S.walkFling = v
    Fling.walkGen += 1
    if not v then return end
    local my = Fling.walkGen
    task.spawn(function()
        local mov = 0.1
        while S.walkFling and Fling.walkGen == my and Z.Alive do
            RunService.Heartbeat:Wait()
            local hrp = GetHRP()
            if hrp and not Fling.busy and not Fling.lock and not Safe.active then
                local mult = Power() / 50
                local vel = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = vel * mult + Vector3.new(0, mult, 0)
                RunService.RenderStepped:Wait()
                hrp.AssemblyLinearVelocity = vel
                RunService.Stepped:Wait()
                hrp.AssemblyLinearVelocity = vel + Vector3.new(0, mov, 0)
                mov = -mov
            end
        end
    end)
end

-- Aim Fling (contínuo em um alvo) -----------------------------------------
local function SetAim(v)
    S.aimFling = v
    Fling.aimGen += 1
    if not v then return end
    local my = Fling.aimGen
    task.spawn(function()
        while S.aimFling and Fling.aimGen == my and Z.Alive do
            local t = GetTarget()
            if not t then
                S.aimFling = false
                if UI.aim and UI.aim.Frame.Parent then UI.aim.Set(false, true) end
                Z.Notify("Aim Fling", "Alvo saiu do servidor. Desligado.", C.Warning, 3)
                break
            end
            if not Fling.lock and not Fling.busy then FlingPlayer(t, S.flingTime) end
            task.wait(0.4)
        end
    end)
end

-- Fling All (uma vez) ------------------------------------------------------
local function FlingAll()
    if Fling.lock or Fling.busy then
        Z.Notify("Fling All", "Já existe um fling em andamento.", C.Warning, 2)
        return
    end
    if Safe.active then
        Z.Notify("Fling All", "Saia da safezone primeiro.", C.Warning, 2)
        return
    end
    Fling.lock = true
    task.spawn(function()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Player and TargetParts(p) then table.insert(list, p) end
        end
        if #list == 0 then
            Fling.lock = false
            Z.Notify("Fling All", "Ninguém para flingar.", C.TextDim, 2)
            return
        end
        Z.Notify("Fling All", "Flingando " .. #list .. " player(s)...", C.Accent, 2)
        local n = 0
        for _, p in ipairs(list) do
            if not Z.Alive or Safe.active then break end
            if p.Parent == Players and FlingPlayer(p, S.flingTime) then n += 1 end
        end
        Fling.lock = false
        Z.Notify("Fling All", n .. "/" .. #list .. " arremessados.", C.Success, 3)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- ESP
-- ═══════════════════════════════════════════════════════════════════════
local ESP = { entries = {}, gen = 0 }
local espParent = (Z.GUI and Z.GUI.Hub and Z.GUI.Hub.Parent) or Player:WaitForChild("PlayerGui")
pcall(function()
    local old = espParent:FindFirstChild("ZuniESP")
    if old then old:Destroy() end
end)
local espFolder = Instance.new("Folder")
espFolder.Name = "ZuniESP"
espFolder.Parent = espParent

local function MakeEntry(plr)
    local bb = Instance.new("BillboardGui")
    bb.Name = plr.Name
    bb.Size = UDim2.fromOffset(190, 46)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.ResetOnSpawn = false
    bb.Parent = espFolder

    local function txt(y, size, font)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Size = UDim2.new(1, 0, 0, 16)
        l.Position = UDim2.fromOffset(0, y)
        l.Font = font
        l.TextSize = size
        l.TextColor3 = C.Text
        l.TextStrokeColor3 = Color3.new(0, 0, 0)
        l.TextStrokeTransparency = 0.35
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.Text = ""
        l.Parent = bb
        return l
    end
    local nameL = txt(0, 14, Enum.Font.GothamBold)

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(0.7, 0, 0, 6)
    barBg.Position = UDim2.new(0.15, 0, 0, 19)
    barBg.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    barBg.BorderSizePixel = 0
    barBg.Parent = bb
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 3)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(1, 1)
    fill.BackgroundColor3 = C.Success
    fill.BorderSizePixel = 0
    fill.Parent = barBg
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

    local infoL = txt(28, 12, Enum.Font.GothamMedium)

    local hl = Instance.new("Highlight")
    hl.FillTransparency = 0.8
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = espFolder

    return { bb = bb, name = nameL, bar = barBg, fill = fill, info = infoL, hl = hl }
end

local function DropEntry(plr)
    local e = ESP.entries[plr]
    if e then
        pcall(function() e.bb:Destroy() end)
        pcall(function() e.hl:Destroy() end)
        ESP.entries[plr] = nil
    end
end

local function ClearESP()
    for plr in pairs(ESP.entries) do DropEntry(plr) end
end

local function EspStep()
    local myHrp = GetHRP()
    local seen = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player then
            local ch  = plr.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                seen[plr] = true
                local e = ESP.entries[plr]
                if not e then e = MakeEntry(plr) ESP.entries[plr] = e end

                local dist  = myHrp and (hrp.Position - myHrp.Position).Magnitude or 0
                local vis   = dist <= S.espMaxDist
                local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                local col   = C.Danger:Lerp(C.Success, ratio)

                e.bb.Adornee = ch:FindFirstChild("Head") or hrp
                e.bb.Enabled = vis
                e.name.Visible = S.espName
                e.name.Text = (plr.DisplayName ~= plr.Name) and (plr.DisplayName .. " (@" .. plr.Name .. ")") or plr.Name
                e.bar.Visible = S.espHealth
                e.fill.Size = UDim2.fromScale(ratio, 1)
                e.fill.BackgroundColor3 = col

                local parts = {}
                if S.espHealth then table.insert(parts, math.floor(hum.Health) .. " HP") end
                if S.espDist then table.insert(parts, math.floor(dist) .. " m") end
                if S.espTool then
                    local tool = ch:FindFirstChildOfClass("Tool")
                    if tool then table.insert(parts, tool.Name) end
                end
                e.info.Text = table.concat(parts, "  •  ")
                e.info.Visible = #parts > 0

                e.hl.Adornee = ch
                e.hl.Enabled = vis and S.espBox
                e.hl.OutlineColor = col
                e.hl.FillColor = col
            end
        end
    end
    for plr in pairs(ESP.entries) do
        if not seen[plr] then DropEntry(plr) end
    end
end

local function SetESP(v)
    S.espOn = v
    ESP.gen += 1
    if v then
        local my = ESP.gen
        task.spawn(function()
            while S.espOn and ESP.gen == my and Z.Alive do
                local ok, err = pcall(EspStep)
                if not ok then warn("[NDS] ESP: " .. tostring(err)) end
                task.wait(0.1)
            end
        end)
    else
        ClearESP()
    end
end

-- ═══════════════════════════════════════════════════════════════════════
-- LIMPEZA AO FECHAR O HUB
-- ═══════════════════════════════════════════════════════════════════════
if Z.OnDestroy then
    table.insert(Z.OnDestroy, function()
        S.walkFling, S.aimFling = false, false
        Fling.walkGen += 1
        Fling.aimGen += 1
        S.espOn = false
        ESP.gen += 1
        ClearESP()
        pcall(function() espFolder:Destroy() end)
        LeaveSafe()
        Z.NoclipPaused = false
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- ABA FLING
-- ═══════════════════════════════════════════════════════════════════════
local function LoadFling()
    Z.Sep("📊  STATUS")
    local stTarget = Z.Stat("Alvo (Aim Fling)", "—")
    local stState  = Z.Stat("Estado", "Parado")
    Z.PageLoop(0.3, function()
        local t = GetTarget()
        stTarget.Set(t and t.Name or "—", t and C.Text or C.TextDim)
        if Safe.active then stState.Set("Na safezone", C.Warning)
        elseif Fling.busy then stState.Set("Flingando...", C.Danger)
        elseif S.walkFling or S.aimFling then stState.Set("Ativo", C.Success)
        else stState.Set("Parado", C.TextDim) end
    end)

    Z.Sep("💫  FLING (TOQUE)")
    UI.walk = Z.Toggle("Fling (toque)", S.walkFling, function(v) SetWalkFling(v) end,
        "Ande normal; quem encostar em você é arremessado")
    Z.Slider("Força", 100, 2000, S.flingPower, function(v) S.flingPower = v end, { step = 50, suffix = " k" })
    Z.Slider("Tempo máx. por alvo", 1, 8, S.flingTime, function(v) S.flingTime = v end, { step = 0.5, suffix = " s" })

    Z.Sep("🎯  AIM FLING (UM PLAYER)")
    local ddPlayer = Z.PlayerDropdown("Alvo", function(p)
        S.ndsTarget = p and p.UserId or nil
    end, "Escolha o player na lista", GetTarget())
    UI.dd = ddPlayer
    UI.aim = Z.Toggle("Aim Fling (contínuo)", S.aimFling, function(v)
        if v and not GetTarget() then
            Z.Notify("Aim Fling", "Selecione um alvo primeiro.", C.Warning, 2)
            if UI.aim then UI.aim.Set(false, true) end
            S.aimFling = false
            return
        end
        SetAim(v)
    end, "Fica flingando o alvo até você desligar")
    Z.Button("🎯  Flingar alvo (1x)", C.Accent, function()
        local t = GetTarget()
        if not t then Z.Notify("Aim Fling", "Selecione um alvo primeiro.", C.Warning, 2) return end
        task.spawn(function()
            if not FlingPlayer(t, S.flingTime) then
                Z.Notify("Aim Fling", "Não foi possível arremessar (alvo morto/ausente ou ocupado).", C.TextDim, 3)
            end
        end)
    end)

    Z.Sep("💥  FLING ALL")
    Z.Button("💥  Fling All (uma vez)", C.Danger, FlingAll)
    Z.Info("Fling All passa por todos os players uma única vez e volta você pra posição original. Se a vida ficar baixa e a Safezone automática estiver ligada, o fling é interrompido.")
end

-- ═══════════════════════════════════════════════════════════════════════
-- ABA SURVIVAL (SAFEZONE)
-- ═══════════════════════════════════════════════════════════════════════
local function LoadSurvival()
    Z.Sep("📊  STATUS")
    local stHp   = Z.Stat("Vida", "—")
    local stSafe = Z.Stat("Safezone", "Fora")
    Z.PageLoop(0.2, function()
        local hum = GetHum()
        if hum then
            local pct = hum.Health / math.max(hum.MaxHealth, 1) * 100
            stHp.Set(math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth),
                pct > 60 and C.Success or (pct > 30 and C.Warning or C.Danger))
        else
            stHp.Set("—", C.TextDim)
        end
        stSafe.Set(Safe.active and "Dentro" or "Fora", Safe.active and C.Warning or C.TextDim)
    end)

    Z.Sep("🛡️  SAFEZONE")
    Z.Toggle("Safezone automática", S.safeOn, function(v) S.safeOn = v end,
        "Teleporta pro céu quando a vida ficar baixa")
    Z.Slider("Entrar com vida ≤", 5, 90, S.safeThreshold, function(v) S.safeThreshold = v end, { step = 5, suffix = " %" })
    Z.Toggle("Voltar sozinho ao curar", S.safeReturn, function(v) S.safeReturn = v end,
        "Volta pro lugar onde você estava")
    Z.Slider("Voltar com vida ≥", 30, 100, S.safeReturnAt, function(v) S.safeReturnAt = v end, { step = 5, suffix = " %" })

    Z.Sep("🔧  AÇÕES")
    Z.Button("🛡️  Ir para a safezone agora", C.Success, function() GoSafe(true, "Safezone manual.") end)
    Z.Button("↩  Sair da safezone", C.AccentDark, LeaveSafe)
    Z.Info("A plataforma é local (só você vê) e fica longe do mapa. Entrada manual não volta sozinha; use 'Sair da safezone'.")
end

-- ═══════════════════════════════════════════════════════════════════════
-- ABA ESP
-- ═══════════════════════════════════════════════════════════════════════
local function LoadESP()
    Z.Sep("👁️  ESP")
    UI.esp = Z.Toggle("ESP de players", S.espOn, function(v) SetESP(v) end, "Mostra informações acima dos players")

    Z.Sep("⚙️  O QUE MOSTRAR")
    Z.Toggle("Nome", S.espName, function(v) S.espName = v end)
    Z.Toggle("Vida (barra + HP)", S.espHealth, function(v) S.espHealth = v end)
    Z.Toggle("Distância", S.espDist, function(v) S.espDist = v end)
    Z.Toggle("Item na mão", S.espTool, function(v) S.espTool = v end)
    Z.Toggle("Contorno (Highlight)", S.espBox, function(v) S.espBox = v end, "Cor muda conforme a vida")
    Z.Slider("Distância máxima", 100, 5000, S.espMaxDist, function(v) S.espMaxDist = v end, { step = 50, suffix = " m" })
end

Z.AddTab("Fling", "💫", LoadFling)
Z.AddTab("Survival", "🛡️", LoadSurvival)
Z.AddTab("ESP", "👁️", LoadESP)

Z.SelectTab("Fling")
Z.Notify("Zuni Hub", "Módulo NDS v1.0 carregado!", C.Success, 3)
print("⚡ NDS Module v1.0 iniciado")
