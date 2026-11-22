-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ZUNI HUB - ETW MODULE v13.8 - EDICÃO LEVE + SALVAMENTO            ║
-- ║  Anti-Void • Auto Upgrade c/ saldo • Teleporte Timed 91min         ║
-- ║  Contagem persistente • Botão de ciclo manual • SEM rejoin         ║
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
local RunService = game:GetService("RunService")

local HttpService = game:GetService("HttpService")
local SAVE_FILE = "ZuniETW_Config.json"
local TELEPORT_MAX = 2
local TELEPORT_WAIT = 10
local TELEPORT_BASE_INTERVAL = 91 * 60  -- 91 minutos em segundos

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

-- Grab
Def("grabTeleportEnabled", true)
Def("grabFailTeleportDelay", 3.0)
Def("grabFailCooldown", 3.0)
Def("grabWalkFallback", true)
Def("grabFailMoveDuration", 3.0)
Def("grabWalkWait", 1.5)
Def("grabStuckTime", 1.5)
Def("grabBedrockSkipEnabled", true)
Def("bedrockSkipTime", 4.0)

-- Auto-off
Def("autoOffGrabEnabled", true)
Def("autoOffGrabThreshold", 5.0)

-- Eat / Throw / Sell
Def("eatInterval", 50)
Def("throwInterval", 500)
Def("sellTimerInterval", 12000)
Def("smartSellThreshold", 5)
Def("skipOnSmartSell", false)

-- Walk
Def("walkInterval", 300)
Def("walkRadius", 40)
Def("walkSpeed", 30)
Def("walkStuckTime", 2.0)

-- Rewards
Def("rewardSpin", true)

-- Skip
Def("skipTimerEnabled", false)
Def("skipInterval", 60)
Def("skipStuckEnabled", false)
Def("skipStuckTime", 15)

-- Size stuck
Def("sizeStuckSkipEnabled", true)
Def("sizeStuckThreshold", 10.0)
Def("sizeStuckRepauseDelay", 5.0)

-- Skip/pause geral
Def("autoPauseAfterSkip", true)
Def("autoPauseDelay", 5)

-- Auto Upgrades
Def("autoUpgradesEnabled", false)
Def("autoUpgradesSelectedName", nil)

-- Teleporte Timed Mega/Normal
Def("teleportTimedEnabled", false)
Def("teleportTimedInterval", TELEPORT_BASE_INTERVAL)
Def("teleportCount", 0)
Def("teleportMapType", "Normal")
Def("teleportLastRunAt", 0)  -- tick() da última execução bem-sucedida

-- Anti-Void
Def("antiVoidEnabled", true)
Def("antiVoidPartName", "ZuniAntiVoid")
Def("antiVoidThickness", 5)
Def("antiVoidSize", 4000)

-- Estado das Features
Def("ActiveFeatures", {})

-- ═══════════════════════════════════════════════════════════════════════
-- SALVAMENTO E CARREGAMENTO
-- ═══════════════════════════════════════════════════════════════════════
local function SaveConfig()
    if not writefile then return end
    local saveData = {
        settings = S,
        activeFeatures = S.ActiveFeatures,
    }
    local ok, json = pcall(function() return HttpService:JSONEncode(saveData) end)
    if ok then
        pcall(function() writefile(SAVE_FILE, json) end)
    end
end

local function LoadConfig()
    if not isfile or not isfile(SAVE_FILE) then return end
    local ok, content = pcall(readfile, SAVE_FILE)
    if not ok or not content or content == "" then return end
    local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
    if ok2 and type(data) == "table" then
        for k, v in pairs(data.settings or {}) do S[k] = v end
        S.ActiveFeatures = data.activeFeatures or {}
    end
end

LoadConfig()

-- ═══════════════════════════════════════════════════════════════════════
-- HELPERS
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
    if not evs then return nil end
    return evs:FindFirstChild(name)
end

local function GetPurchaseEvent()
    local evs = RS:FindFirstChild("Events")
    if not evs then
        warn("[ETW] ReplicatedStorage.Events não encontrado!")
        return nil
    end
    local ev = evs:FindFirstChild("PurchaseEvent")
    if not ev then
        warn("[ETW] ReplicatedStorage.Events.PurchaseEvent não encontrado!")
        return nil
    end
    if not ev:IsA("RemoteEvent") then
        warn("[ETW] PurchaseEvent não é RemoteEvent! É: " .. ev.ClassName)
        return nil
    end
    return ev
end

local function GetRequestTeleportEvent()
    local evs = RS:FindFirstChild("Events")
    if not evs then return nil end
    local ev = evs:FindFirstChild("RequestTeleport")
    if ev and ev:IsA("RemoteEvent") then return ev end
    return nil
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
    if not ls then return nil end
    local sz = ls:FindFirstChild("Size") or ls:FindFirstChild("Mass")
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

local function TeleportToPlatform()
    local hrp = GetHRP()
    if not hrp then return false end
    local target = RandomWalkablePos(hrp.Position, S.walkRadius)
    if not target then return false end
    pcall(function() hrp.CFrame = CFrame.new(target) end)
    return true
end

-- ═══════════════════════════════════════════════════════════════════════
-- CUBES — espelho local
-- ═══════════════════════════════════════════════════════════════════════
local cubesState = { value = nil, lastUpdate = 0 }

local function UpdateCubesFromEvent(newValue)
    if type(newValue) == "number" then
        cubesState.value = newValue
        cubesState.lastUpdate = tick()
    end
end

do
    local evs = RS:FindFirstChild("Events")
    local setCubes = evs and evs:FindFirstChild("SetCubes")
    if setCubes and setCubes:IsA("RemoteEvent") then
        local conn = setCubes.OnClientEvent:Connect(function(v)
            UpdateCubesFromEvent(v)
        end)
        if Z.Track then Z.Track(conn) end
    end
end

do
    local evs = RS:FindFirstChild("Events")
    local cubesAdded = evs and evs:FindFirstChild("CubesAdded")
    if cubesAdded and cubesAdded:IsA("RemoteEvent") then
        local conn = cubesAdded.OnClientEvent:Connect(function(amount, newTotal)
            if type(amount) == "number" and amount < 0 and type(newTotal) == "number" then
                UpdateCubesFromEvent(newTotal)
            elseif cubesState.value ~= nil and type(amount) == "number" then
                UpdateCubesFromEvent(cubesState.value + amount)
            end
        end)
        if Z.Track then Z.Track(conn) end
    end
end

task.spawn(function()
    task.wait(2)
    local evs = RS:FindFirstChild("Events")
    local setCubes = evs and evs:FindFirstChild("SetCubes")
    if setCubes and setCubes:IsA("RemoteEvent") then
        pcall(function() setCubes:FireServer() end)
    end
end)

local function GetCubes()
    if cubesState.value ~= nil then
        return cubesState.value
    end
    local pg = Player:FindFirstChild("PlayerGui")
    local sg = pg and pg:FindFirstChild("ScreenGui")
    local cubesGui = sg and sg:FindFirstChild("Cubes")
    if cubesGui then
        local counterFrame = cubesGui:FindFirstChild("CounterFrame")
        local textLabel = counterFrame and counterFrame:FindFirstChild("TextLabel")
        if textLabel and textLabel:IsA("TextLabel") then
            local txt = textLabel.Text:gsub(",", "")
            local n = tonumber(txt)
            if n then return n end
        end
    end
    local cubes = Player:FindFirstChild("Cubes")
    if cubes and (cubes:IsA("NumberValue") or cubes:IsA("IntValue")) then
        return cubes.Value
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════
-- ANTI-VOID
-- ═══════════════════════════════════════════════════════════════════════
local antiVoidPart = nil

local function FindBedrockBase()
    local map = workspace:FindFirstChild("Map")
    if map then
        local bed = map:FindFirstChild("Bedrock")
        if bed then
            if bed:IsA("BasePart") then return bed end
            if bed:IsA("Model") then
                if bed.PrimaryPart then return bed.PrimaryPart end
                for _, d in ipairs(bed:GetDescendants()) do
                    if d:IsA("BasePart") then return d end
                end
            end
        end
    end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and d.Name == "Bedrock" then
            return d
        end
    end
    return nil
end

local function CreateAntiVoid()
    if antiVoidPart and antiVoidPart.Parent then
        return antiVoidPart
    end

    local base = FindBedrockBase()
    local center, size
    if base then
        center = base.Position
        size = Vector3.new(S.antiVoidSize, S.antiVoidThickness, S.antiVoidSize)
    else
        local hrp = GetHRP()
        if hrp then
            center = Vector3.new(hrp.Position.X, hrp.Position.Y - 50, hrp.Position.Z)
            size = Vector3.new(S.antiVoidSize, S.antiVoidThickness, S.antiVoidSize)
        else
            center = Vector3.new(0, -50, 0)
            size = Vector3.new(S.antiVoidSize, S.antiVoidThickness, S.antiVoidSize)
        end
    end

    local part = Instance.new("Part")
    part.Name = S.antiVoidPartName
    part.Anchored = true
    part.CanCollide = true
    part.Size = size
    part.Position = center
    part.Transparency = 1
    part.Material = Enum.Material.SmoothPlastic
    part.Color = Color3.fromRGB(0, 0, 0)
    part.CanQuery = true
    part.CanTouch = false

    local map = workspace:FindFirstChild("Map")
    part.Parent = map or workspace

    antiVoidPart = part
    return part
end

local function DestroyAntiVoid()
    if antiVoidPart and antiVoidPart.Parent then
        antiVoidPart:Destroy()
    end
    antiVoidPart = nil
end

local function SetAntiVoidEnabled(v)
    S.antiVoidEnabled = v
    if v then
        CreateAntiVoid()
        Z.Notify("Anti-Void", "Ativado (Part gigante na Bedrock).", C.Success, 2)
    else
        DestroyAntiVoid()
        Z.Notify("Anti-Void", "Desativado.", C.TextDim, 2)
    end
    SaveConfig()
end

task.spawn(function()
    task.wait(3)
    if S.antiVoidEnabled then
        CreateAntiVoid()
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- AUTO UPGRADES — helpers
-- ═══════════════════════════════════════════════════════════════════════
local ItemInfo = nil
local function GetItemInfo()
    if ItemInfo == nil then
        local m = RS:FindFirstChild("ItemInfo")
        if m then
            local ok, r = pcall(require, m)
            ItemInfo = ok and r or false
        end
    end
    return ItemInfo or nil
end

local AUTO_UPGRADE_NAMES = {
    "Size",
    "Speed",
    "SizeMultiplier",
    "EatSpeed",
}

local function GetUpgradeValue(name)
    local upgrades = Player:FindFirstChild("Upgrades")
    if not upgrades then return nil end
    local val = upgrades:FindFirstChild(name)
    if val and (val:IsA("NumberValue") or val:IsA("IntValue")) then
        return val.Value
    end
    return nil
end

local function GetUpgradePrice(name)
    local info = GetItemInfo()
    if not info or not info.Upgrades or not info.Upgrades[name] then return nil end
    local currentLevel = GetUpgradeValue(name)
    if currentLevel == nil then return nil end
    local ok, price = pcall(function() return info.Upgrades[name].priceFunction(currentLevel + 1) end)
    if ok then return price end
    return nil
end

local function GetUpgradeDisplayName(name)
    local info = GetItemInfo()
    if info and info.Upgrades and info.Upgrades[name] then
        return info.Upgrades[name].name or name
    end
    local pretty = name:gsub("(%l)(%u)", "%1 %2")
    return pretty
end

-- ═══════════════════════════════════════════════════════════════════════
-- FEATURES
-- ═══════════════════════════════════════════════════════════════════════
local Features = {}
local FeatureConns = {}

local function NewFeature(key, label, body, opts)
    opts = opts or {}
    Features[key] = {
        key = key, label = label, body = body, running = false, gen = 0,
        exclusive = opts.exclusive, onStart = opts.onStart, onStop = opts.onStop,
    }
    FeatureConns[key] = {}
end

local function RunLoop(ft)
    ft.gen += 1
    local my = ft.gen
    task.spawn(function()
        while ft.running and ft.gen == my and Z.Alive do
            local ok, res = pcall(ft.body)
            local wait = 0.05
            if ok then wait = tonumber(res) or wait
            else
                warn("[ETW] " .. ft.label .. ": " .. tostring(res))
                wait = 1
            end
            task.wait(math.max(0.03, wait))
        end
    end)
end

local function CleanupFeature(key)
    local conns = FeatureConns[key]
    if conns then
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        table.clear(conns)
    end
end

local function SetFeature(key, v, quiet, isRestoring)
    local ft = Features[key]
    if not ft then return end
    v = not not v
    if v == ft.running then return end
    
    if not v then
        ft.gen += 1
        CleanupFeature(key)
        if ft.onStop then pcall(ft.onStop) end
        S.ActiveFeatures[key] = nil
    else
        S.ActiveFeatures[key] = true
    end
    
    if v and ft.exclusive then SetFeature(ft.exclusive, false, true, isRestoring) end
    ft.running = v
    
    if v then
        if ft.onStart then pcall(ft.onStart) end
        RunLoop(ft)
    end
    
    local ui = UI[key]
    if ui and ui.Frame.Parent and type(ui.Set) == "function" then
        ui.Set(v, true)
    end
    
    if not quiet then
        Z.Notify(ft.label, v and "Ativado" or "Desativado", v and C.Success or C.TextDim, 1.5)
    end
    
    if not isRestoring then
        SaveConfig()
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
local grabState = { failSince = nil, lastPos = nil, stuckSince = nil }
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
    if not ev then return false end
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
            if SetMapPaused(true) then
                Z.Notify("Auto Pause", "Mapa pausado após " .. S.autoPauseDelay .. "s do skip.", C.Warning, 2)
            end
        end)
    end
    return true
end

local function UnpauseSkipPause(reason)
    local ev = GetEvent("SetServerSettings")
    if not ev then return false end
    pcall(function() ev:FireServer({ Paused = false }) end)
    task.wait(0.25)
    pcall(function() ev:FireServer({ MapTime = SKIP_MAPTIME }) end)
    lastSkip = tick()
    grabState.failSince = nil
    grabState.stuckSince = nil
    Z.Notify("Unstuck", reason or "Travado. Mapa pulado.", C.Accent, 2.5)
    local delay = math.max(0.5, S.sizeStuckRepauseDelay or 5.0)
    pauseToken += 1
    local my = pauseToken
    task.delay(delay, function()
        if my ~= pauseToken then return end
        if not Z.Alive then return end
        if SetMapPaused(true) then
            Z.Notify("Unstuck", string.format("Mapa re-pausado %.0fs após o skip.", delay), C.Warning, 2)
        end
    end)
    return true
end

-- ═══════════════════════════════════════════════════════════════════════
-- TELEPORTE TIMED MEGA/NORMAL
-- ═══════════════════════════════════════════════════════════════════════
-- A cada 91 min, faz o ciclo:
--   1. Teleporta pro mapa OPOSTO ao atual
--   2. Espera 10s -> teleportCount = 1
--   3. Teleporta de volta pro original
--   4. Espera 10s -> teleportCount = 2
--   5. Reseta pra 0 e espera mais 91 min
--
-- A contagem é persistida no JSON e NÃO é resetada ao re-entrar.
-- Se o player sair no meio de um ciclo, a contagem fica onde estava.
-- Só incrementa quando o passo termina com sucesso.
-- O timer (teleportLastRunAt) também é salvo: se o player ficou 2h offline,
-- o próximo ciclo acontece assim que ele entrar (não espera 91 min de novo).

local function GetCurrentMapType()
    return S.teleportMapType or "Normal"
end

local function SetCurrentMapType(t)
    S.teleportMapType = t
    SaveConfig()
end

local function DoMapTeleport(targetType)
    local ev = GetRequestTeleportEvent()
    if not ev then
        Z.Notify("Teleporte", "RequestTeleport não encontrado!", C.Danger, 3)
        return false
    end
    local ok, err = pcall(function()
        ev:FireServer(targetType)
    end)
    if ok then
        SetCurrentMapType(targetType)
        Z.Notify("Teleporte", "Indo para: " .. targetType, C.Success, 2)
        return true
    else
        Z.Notify("Teleporte", "Erro: " .. tostring(err), C.Danger, 3)
        return false
    end
end

-- Executa o ciclo completo. Retorna true se concluiu.
local function RunTeleportCycleBlocking(reason)
    local count = tonumber(S.teleportCount) or 0

    -- Se já está no máximo (2), reseta e não teleporta
    if count >= TELEPORT_MAX then
        Z.Notify("Teleporte",
            string.format("Contagem já em %d/%d. Resetando para 0.", count, TELEPORT_MAX),
            C.TextDim, 2)
        S.teleportCount = 0
        SaveConfig()
        return true
    end

    -- Passo 1: teleporta pro mapa oposto
    local current = GetCurrentMapType()
    local firstTarget = (current == "Mega") and "Normal" or "Mega"
    Z.Notify("Teleporte",
        string.format("[%d/%d] Indo para %s...", count + 1, TELEPORT_MAX, firstTarget),
        C.Accent, 3)
    if not DoMapTeleport(firstTarget) then
        return false
    end

    task.wait(TELEPORT_WAIT)
    if not Z.Alive then return false end

    -- ✅ Só incrementa a contagem APÓS o teleporte ter sucesso
    S.teleportCount = count + 1
    SaveConfig()
    Z.Notify("Teleporte",
        string.format("Carregou. Contagem = %d/%d", S.teleportCount, TELEPORT_MAX),
        C.Success, 2)

    -- Passo 2: se chegou em 2, volta pro original e reseta
    if S.teleportCount >= TELEPORT_MAX then
        local secondTarget = (firstTarget == "Mega") and "Normal" or "Mega"
        Z.Notify("Teleporte",
            string.format("[%d/%d] Voltando para %s...", S.teleportCount, TELEPORT_MAX, secondTarget),
            C.Accent, 3)
        if not DoMapTeleport(secondTarget) then
            return false
        end

        task.wait(TELEPORT_WAIT)
        if not Z.Alive then return false end

        S.teleportCount = 0
        SaveConfig()
        Z.Notify("Teleporte",
            "Ciclo completo. Contagem resetada para 0.",
            C.Warning, 4)
    end

    return true
end

-- Feature: Teleporte Timed Mega/Normal
local teleportTimerState = { lastRunAt = 0 }

local function InitTeleportTimer()
    -- Restaura o timer do JSON. Se o player ficou offline por mais de 91 min,
    -- o próximo ciclo acontece no próximo tick.
    teleportTimerState.lastRunAt = tonumber(S.teleportLastRunAt) or 0
end

local function SaveTeleportTimer()
    S.teleportLastRunAt = teleportTimerState.lastRunAt
    SaveConfig()
end

NewFeature("teleportTimed", "Teleporte Mega/Normal (Timed)", function()
    if not S.teleportTimedEnabled then return 5 end

    local now = tick()
    local interval = tonumber(S.teleportTimedInterval) or TELEPORT_BASE_INTERVAL
    local last = teleportTimerState.lastRunAt

    -- Primeira vez: inicializa o timer sem teleportar
    if last == 0 then
        teleportTimerState.lastRunAt = now
        SaveTeleportTimer()
        return 5
    end

    -- Verifica se já passou o intervalo
    if (now - last) < interval then
        return 5
    end

    -- Atualiza o timer ANTES de rodar (se o ciclo falhar, tenta de novo no próximo intervalo)
    teleportTimerState.lastRunAt = now
    SaveTeleportTimer()

    -- Roda o ciclo (bloqueante)
    task.spawn(function()
        RunTeleportCycleBlocking("Timed 91min")
    end)

    return 5
end, {
    onStart = function()
        InitTeleportTimer()
        Z.Notify("Teleporte Timed", "Ativado. Intervalo: 91 min.", C.Success, 3)
    end,
    onStop = function()
        Z.Notify("Teleporte Timed", "Desativado.", C.TextDim, 2)
    end
})

-- ═══════════════════════════════════════════════════════════════════════
-- AUTO-OFF DO GRAB
-- ═══════════════════════════════════════════════════════════════════════
local autoOff = { lastSize = nil, sameSizeSince = nil, lastPos = nil, stuckSince = nil, watching = false }

local function ResetAutoOff()
    autoOff.lastSize = nil; autoOff.sameSizeSince = nil
    autoOff.lastPos = nil; autoOff.stuckSince = nil
    autoOff.watching = false
end

task.spawn(function()
    task.wait(1)
    local conn = RunService.Heartbeat:Connect(function()
        pcall(function()
            if not Z.Alive then return end
            if not S.autoOffGrabEnabled then
                if autoOff.watching then ResetAutoOff() end
                return
            end
            if Features.grab and Features.grab.running then
                local hrp = GetHRP()
                local pos = hrp and hrp.Position or nil
                local sz = GetSize()
                local now = tick()
                if sz ~= nil then
                    if autoOff.lastSize == nil then
                        autoOff.lastSize = sz; autoOff.sameSizeSince = now
                    elseif sz ~= autoOff.lastSize then
                        autoOff.lastSize = sz; autoOff.sameSizeSince = now
                    end
                end
                if pos and autoOff.lastPos then
                    if (pos - autoOff.lastPos).Magnitude < 0.5 then
                        if not autoOff.stuckSince then autoOff.stuckSince = now end
                    else autoOff.stuckSince = nil end
                end
                autoOff.lastPos = pos
                local sizeStuck = autoOff.sameSizeSince and (now - autoOff.sameSizeSince >= S.autoOffGrabThreshold)
                local posStuck  = autoOff.stuckSince and (now - autoOff.stuckSince >= S.autoOffGrabThreshold)
                if sizeStuck and posStuck and not autoOff.watching then
                    autoOff.watching = true
                    SetFeature("grab", false, false)
                    Z.Notify("Auto Grab", "Desligado: sem crescer e parado.", C.Warning, 4)
                end
                return
            end
            if autoOff.watching then
                local hrp = GetHRP()
                if hrp and not hrp.Anchored then
                    autoOff.watching = false; ResetAutoOff()
                    SetFeature("grab", true, false)
                    Z.Notify("Auto Grab", "HRP desancorado. Religado.", C.Success, 3)
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
local grabTried = false
local grabSucceeded = false

local function StartTempWalk()
    if grabFallback.walking then return end
    grabFallback.wasWalkOn = Features.walk and Features.walk.running or false
    grabFallback.walking = true
    SetFeature("walk", true, true)
end

local function StopTempWalk()
    if not grabFallback.walking then return end
    grabFallback.walking = false
    if not grabFallback.wasWalkOn then SetFeature("walk", false, true) end
end

local function ResetGrab()
    grabState.failSince = nil; grabState.stuckSince = nil; grabState.lastPos = nil
    bedrockState.since = nil; grabCooldown.until_ = 0
    grabTried = false; grabSucceeded = false
    StopTempWalk()
end

NewFeature("grab", "Auto Grab", function()
    if HasChunk() then
        grabSucceeded = true; grabTried = false
        grabState.failSince = nil; grabState.stuckSince = nil
        grabCooldown.until_ = 0
        if grabFallback.walking and tick() >= grabFallback.moveUntil then StopTempWalk() end
        return 0.05
    end
    if grabTried then return 0.05 end

    local hrp = GetHRP()
    local pos = hrp and hrp.Position or nil
    local now = tick()

    if S.grabBedrockSkipEnabled and IsOnBedrock() then
        if not bedrockState.since then bedrockState.since = now end
        if now - bedrockState.since >= S.bedrockSkipTime then
            SkipMap("Mapa pulado (preso na Bedrock).")
            bedrockState.since = nil; grabTried = false
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
        return 0.05
    end
    bedrockState.since = nil

    if now < grabCooldown.until_ then return 0.05 end

    grabTried = true; grabSucceeded = false
    task.spawn(FireEvent, "Grab")

    task.delay(math.max(0.5, S.grabFailTeleportDelay), function()
        if not Features.grab or not Features.grab.running then return end
        if grabSucceeded or HasChunk() then grabTried = false; return end
        grabTried = false
        grabCooldown.until_ = tick() + S.grabFailCooldown

        if S.grabTeleportEnabled then
            local ok = TeleportToPlatform()
            Z.Notify("Auto Grab",
                ok and string.format("Sem chunk após %.1fs. Teleportado.", S.grabFailTeleportDelay)
                   or string.format("Sem chunk após %.1fs. Sem plataforma.", S.grabFailTeleportDelay),
                ok and C.Accent or C.Warning, 2)
            if S.grabWalkFallback and not grabFallback.walking then
                StartTempWalk()
                grabFallback.moveUntil = tick() + S.grabFailMoveDuration
            end
        else
            Z.Notify("Auto Grab", "Sem chunk após teleporte desativado.", C.Warning, 2)
        end
    end)

    if grabState.stuckSince and (now - grabState.stuckSince) >= S.grabStuckTime then
        if pos then
            local target = RandomWalkablePos(pos, S.walkRadius)
            if target and hrp then pcall(function() hrp.CFrame = CFrame.new(target) end) end
        end
        grabState.stuckSince = nil; grabState.lastPos = nil
    end

    return 0.05
end, { onStart = ResetGrab, onStop = ResetGrab })

-- ═══════════════════════════════════════════════════════════════════════
-- SIZE STUCK
-- ═══════════════════════════════════════════════════════════════════════
local sizeStuck = { lastSize = nil, since = nil, busy = false }

local function ResetSizeStuck()
    sizeStuck.lastSize = nil; sizeStuck.since = nil; sizeStuck.busy = false
end

NewFeature("sizeStuckSkip", "Skip se Size parar", function()
    if not S.sizeStuckSkipEnabled then return 1 end
    local sz = GetSize()
    if sz == nil then
        sizeStuck.lastSize = nil; sizeStuck.since = nil
        return 0.5
    end
    local now = tick()
    if sizeStuck.lastSize == nil then
        sizeStuck.lastSize = sz; sizeStuck.since = now
        return 0.5
    end
    if sz ~= sizeStuck.lastSize then
        sizeStuck.lastSize = sz; sizeStuck.since = now
        return 0.5
    end
    if not sizeStuck.busy and (now - sizeStuck.since) >= S.sizeStuckThreshold then
        sizeStuck.busy = true
        Z.Notify("Unstuck",
            string.format("Size parado há %ds. Unpause → Skip → (re-pause em %.0fs).",
                math.floor(S.sizeStuckThreshold), S.sizeStuckRepauseDelay),
            C.Warning, 3)
        task.spawn(function()
            UnpauseSkipPause(string.format("Size parado há %ds.", math.floor(S.sizeStuckThreshold)))
            task.wait(0.5)
            sizeStuck.lastSize = GetSize(); sizeStuck.since = tick()
            sizeStuck.busy = false
        end)
    end
    return 0.5
end, { onStart = ResetSizeStuck, onStop = ResetSizeStuck })

-- ═══════════════════════════════════════════════════════════════════════
-- EAT / THROW / SELL
-- ═══════════════════════════════════════════════════════════════════════
NewFeature("eat", "Auto Eat", function()
    if HasChunk() then FireEvent("Eat") end
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
NewFeature("smartSell", "Smart Sell (com chunk)", function()
    if not HasChunk() then
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
        if S.skipOnSmartSell then SkipMap("Mapa pulado (Smart Sell).") end
        return 2
    end
    return 1
end, { exclusive = "sellTimer", onStart = function() smart.last, smart.stuck = -1, 0 end })

-- ═══════════════════════════════════════════════════════════════════════
-- WALK
-- ═══════════════════════════════════════════════════════════════════════
local walkState = { target = nil, lastPos = nil, stuckSince = nil, lastMoveAt = 0 }

local function StopMoving()
    local hum, hrp = GetHum(), GetHRP()
    if hum and hrp then hum:MoveTo(hrp.Position) end
    walkState.target = nil; walkState.stuckSince = nil
end

local function ApplyWalkSpeed()
    local hum = GetHum()
    if hum then hum.WalkSpeed = S.walkSpeed end
    walkState.target = nil; walkState.lastPos = nil; walkState.stuckSince = nil
end

NewFeature("walk", "Auto Walk", function()
    local hrp, hum = GetHRP(), GetHum()
    if not (hrp and hum and hum.Health > 0) then return 0.3 end
    if hrp.Anchored then return 0.3 end
    if hum.WalkSpeed ~= S.walkSpeed then hum.WalkSpeed = S.walkSpeed end
    local now = tick()
    local pos = hrp.Position
    if walkState.lastPos then
        if (pos - walkState.lastPos).Magnitude < 0.5 then
            if not walkState.stuckSince then walkState.stuckSince = now end
        else walkState.stuckSince = nil end
    end
    walkState.lastPos = pos
    if walkState.stuckSince and (now - walkState.stuckSince) >= S.walkStuckTime then
        hum.Jump = true
        walkState.target = nil; walkState.stuckSince = nil; walkState.lastMoveAt = 0
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
        walkState.target = nil; walkState.stuckSince = nil; walkState.lastMoveAt = 0
        return S.walkInterval / 1000
    end
    if now - walkState.lastMoveAt > 6 then
        walkState.target = nil; walkState.stuckSince = nil; walkState.lastMoveAt = 0
        return 0.2
    end
    return 0.25
end, { onStart = ApplyWalkSpeed, onStop = StopMoving })

-- ═══════════════════════════════════════════════════════════════════════
-- REWARDS
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
-- AUTO UPGRADES
-- ═══════════════════════════════════════════════════════════════════════
local autoUpgState = { lastCanBuy = nil }

NewFeature("autoUpgrades", "Auto Upgrades", function()
    local selectedName = S.autoUpgradesSelectedName
    if not selectedName or selectedName == "" then
        autoUpgState.lastCanBuy = nil
        return 2
    end

    local upgrades = Player:FindFirstChild("Upgrades")
    if not upgrades then
        autoUpgState.lastCanBuy = nil
        return 2
    end
    local upgradeValue = upgrades:FindFirstChild(selectedName)
    if not upgradeValue then
        autoUpgState.lastCanBuy = nil
        return 5
    end

    local price = GetUpgradePrice(selectedName)
    local cubes = GetCubes()

    if price == nil or cubes == nil then
        if autoUpgState.lastCanBuy ~= false then
            autoUpgState.lastCanBuy = false
            Z.Notify("Auto Upgrades",
                "Não foi possível ler preço ou saldo. Compra pausada.",
                C.Warning, 3)
        end
        return 5
    end

    if cubes < price then
        if autoUpgState.lastCanBuy ~= false then
            autoUpgState.lastCanBuy = false
            Z.Notify("Auto Upgrades",
                string.format("Sem saldo: %s/%s (faltam %s). Aguardando...",
                    tostring(cubes), tostring(price), tostring(price - cubes)),
                C.Warning, 3)
        end
        return 5
    end

    autoUpgState.lastCanBuy = true

    local purchaseEvent = GetPurchaseEvent()
    if not purchaseEvent then
        Z.Notify("Auto Upgrades", "PurchaseEvent não encontrado!", C.Danger, 3)
        return 5
    end

    local ok, err = pcall(function()
        purchaseEvent:FireServer(selectedName)
    end)

    if ok then
        Z.Notify("Auto Upgrades",
            string.format("Comprado: %q | Nível: %s | %s/%s",
                selectedName,
                tostring(upgradeValue.Value),
                tostring(cubes), tostring(price)),
            C.Success, 2)
        print(string.format("[ETW AutoUpgrades] FireServer(%q) | Nível: %s | Cubes: %s | Preço: %s",
            selectedName,
            tostring(upgradeValue.Value),
            tostring(cubes), tostring(price)))
    else
        Z.Notify("Auto Upgrades", "Erro: " .. tostring(err), C.Danger, 3)
        warn("[ETW AutoUpgrades] Erro ao disparar:", err)
    end

    return 10
end, {
    onStart = function()
        S.autoUpgradesEnabled = true
        autoUpgState.lastCanBuy = nil
        Z.Notify("Auto Upgrades", "Loop iniciado (10s). Só compra se tiver saldo.", C.Success, 2)
    end,
    onStop = function()
        S.autoUpgradesEnabled = false
        autoUpgState.lastCanBuy = nil
    end
})

-- ═══════════════════════════════════════════════════════════════════════
-- ABA: MAIN
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
    local stCd     = Z.Stat("Cooldown do grab", "—")
    local stHrp    = Z.Stat("HRP ancorado", "—")
    local stMap    = Z.Stat("Mapa", "—")
    local stReward = Z.Stat("Próxima reward", "—")
    local stActive = Z.Stat("Funções ativas", "0")
    local stSizeStuck = Z.Stat("Size parado há", "—")
    local stCubes  = Z.Stat("Cubes (espelho)", "—")
    local stAnti   = Z.Stat("Anti-Void", "—")
    local stTpCount = Z.Stat("Teleporte (contagem)", "0/2")
    local stTpMap  = Z.Stat("Mapa atual", "—")
    local stTpNext = Z.Stat("Próximo teleporte", "—")
    Z.PageLoop(0.5, function()
        pcall(function()
            local sz = GetSize()
            stSize.Set(sz and tostring(sz) or "—")
            local has = HasChunk()
            stChunk.Set(has and "Sim" or "Não", has and C.Success or C.TextDim)
            local bed = IsOnBedrock()
            stBed.Set(bed and "Sim" or "Não", bed and C.Warning or C.TextDim)
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
            if sizeStuck.since then
                stSizeStuck.Set(string.format("%.1f s", tick() - sizeStuck.since), C.Warning)
            else
                stSizeStuck.Set("—", C.TextDim)
            end
            local cubes = GetCubes()
            stCubes.Set(cubes and tostring(cubes) or "—", cubes and C.Accent or C.TextDim)
            stAnti.Set(antiVoidPart and antiVoidPart.Parent and "Ativa" or "—",
                antiVoidPart and antiVoidPart.Parent and C.Success or C.TextDim)
            local tc = tonumber(S.teleportCount) or 0
            stTpCount.Set(tostring(tc) .. "/" .. TELEPORT_MAX, tc >= TELEPORT_MAX and C.Danger or C.Accent)
            stTpMap.Set(S.teleportMapType or "—", C.TextDim)
            if not S.teleportTimedEnabled then
                stTpNext.Set("Desligado", C.TextDim)
            else
                local interval = tonumber(S.teleportTimedInterval) or TELEPORT_BASE_INTERVAL
                local last = teleportTimerState.lastRunAt
                if last == 0 then
                    stTpNext.Set("Aguardando...", C.TextDim)
                else
                    local remaining = math.max(0, interval - (tick() - last))
                    stTpNext.Set(Fmt(remaining), remaining <= 60 and C.Danger or C.Success)
                end
            end
        end)
    end)

    Z.Sep("🎛️  CONTROLES RÁPIDOS")
    Z.Button("▶  Ativar farm completo (Grab + Eat + Smart Sell + Rewards + Unstuck)", C.Success, function()
        for _, k in ipairs({ "grab", "eat", "smartSell", "rewards", "sizeStuckSkip" }) do
            SetFeature(k, true, true)
        end
        Z.Notify("ETW", "Farm completo ativado.", C.Success, 2)
    end)
    Z.Button("⏭  Pular mapa agora", C.Accent, function() SkipMap("Mapa pulado.") end)
    Z.Button("🔁  Fazer ciclo Mega/Normal agora", C.Warning, function()
        task.spawn(function()
            RunTeleportCycleBlocking("Manual")
        end)
    end)
    Z.Button("🔄  Resetar contagem de teleporte", C.Purple, function()
        S.teleportCount = 0
        SaveConfig()
        Z.Notify("Teleporte", "Contagem resetada para 0.", C.Success, 2)
    end)
    Z.Button("⏹  Desligar tudo", C.Danger, function()
        for key in pairs(Features) do SetFeature(key, false, true) end
        ResetAutoOff(); ResetSizeStuck()
        Z.Notify("ETW", "Todas as funções desligadas.", C.TextDim, 2)
    end)
    Z.Button("🧹  Limpar Memória (Garbage Collector)", C.Purple, function()
        collectgarbage("collect")
        Z.Notify("Sistema", "Memória limpa (Garbage Collector executado).", C.Success, 2)
    end)
    Z.Button("💾  Salvar Configurações", C.Success, function()
        SaveConfig()
        Z.Notify("Sistema", "Configurações salvas manualmente.", C.Success, 2)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- ABA: GRAB
-- ═══════════════════════════════════════════════════════════════════════
local function LoadGrab()
    Z.Sep("🌾  AUTO GRAB")
    FeatureToggle("grab", "Auto Grab", "Tenta pegar chunk UMA vez. Só tenta de novo depois que perder o chunk atual.")
    Z.Info("O Grab só dispara se você NÃO tiver chunk, e apenas UMA vez até conseguir ou falhar.")

    Z.Slider("Cooldown após falha", 0.5, 15, S.grabFailCooldown, function(v)
        S.grabFailCooldown = v
        SaveConfig()
    end, { step = 0.5, suffix = " s" })
end

-- ═══════════════════════════════════════════════════════════════════════
-- ABA: EAT / SELL / THROW
-- ═══════════════════════════════════════════════════════════════════════
local function LoadEatSell()
    Z.Sep("🍽️  AUTO EAT")
    FeatureToggle("eat", "Auto Eat", "Come automaticamente se tiver um chunk.")
    Z.Slider("Intervalo do Eat", 50, 1000, S.eatInterval, function(v)
        S.eatInterval = v
        SaveConfig()
    end, { step = 10, suffix = " ms" })
    Z.Info("O Eat só dispara se você TIVER um chunk na mão.")

    Z.Sep("💰  AUTO SELL")
    FeatureToggle("sellTimer", "Auto Sell (Timer)", "Vende em intervalos fixos")
    Z.Slider("Vender a cada", 1000, 60000, S.sellTimerInterval, function(v) S.sellTimerInterval = v; SaveConfig() end, { step = 500, suffix = " ms" })
    FeatureToggle("smartSell", "Smart Sell (com chunk)", "Vende quando você está com chunk na mão e o tamanho parou de crescer")
    Z.Slider("Considerar parado após", 2, 20, S.smartSellThreshold, function(v) S.smartSellThreshold = v; SaveConfig() end, { suffix = " s" })
    Z.Toggle("SkipOnSmartSell", S.skipOnSmartSell, function(v)
        S.skipOnSmartSell = v
        SaveConfig()
    end, "Pula o mapa assim que o Smart Sell vender")

    Z.Sep("🗑️  AUTO THROW")
    FeatureToggle("throw", "Auto Throw", "Joga fora o que está na mão")
    Z.Slider("Intervalo", 100, 3000, S.throwInterval, function(v) S.throwInterval = v; SaveConfig() end, { step = 50, suffix = " ms" })
end

-- ═══════════════════════════════════════════════════════════════════════
-- ABA: WALK
-- ═══════════════════════════════════════════════════════════════════════
local function LoadWalk()
    Z.Sep("🚶  AUTO WALK")
    FeatureToggle("walk", "Auto Walk", "Anda de verdade com MoveTo contínuo + anti-travamento")
    Z.Slider("WalkSpeed no walk", 16, 150, S.walkSpeed, function(v) S.walkSpeed = v; SaveConfig() end, { step = 2, suffix = " studs/s" })
    Z.Slider("Raio de caminhada", 20, 150, S.walkRadius, function(v) S.walkRadius = v; SaveConfig() end, { step = 5, suffix = " studs" })
    Z.Slider("Pausa entre destinos", 0, 3000, S.walkInterval, function(v) S.walkInterval = v; SaveConfig() end, { step = 50, suffix = " ms" })
end

-- ═══════════════════════════════════════════════════════════════════════
-- ABA: REWARDS
-- ═══════════════════════════════════════════════════════════════════════
local function LoadRewards()
    Z.Sep("🎁  AUTO REDEEM REWARDS")
    FeatureToggle("rewards", "Auto Redeem Rewards", "Resgata as rewards por tempo assim que ficam prontas")
    Z.Toggle("Incluir giro do grupo (Spin)", S.rewardSpin, function(v)
        S.rewardSpin = v
        SaveConfig()
    end, "Só funciona se você estiver no grupo do jogo")
end

-- ═══════════════════════════════════════════════════════════════════════
-- ABA: MAP
-- ═══════════════════════════════════════════════════════════════════════
local function LoadMap()
    Z.Sep("🗺️  CONTROLE DO MAPA")
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

    Z.Sep("⏸️  AUTO PAUSE APÓS SKIP")
    Z.Toggle("Auto Pause após Skip", S.autoPauseAfterSkip, function(v)
        S.autoPauseAfterSkip = v
        SaveConfig()
    end, "Pausa o mapa automaticamente alguns segundos depois de pular")
    Z.Slider("Delay do pause", 1, 30, S.autoPauseDelay, function(v)
        S.autoPauseDelay = v
        SaveConfig()
    end, { suffix = " s" })

    Z.Sep("⏭️  SKIP POR TEMPO")
    UI.skipTimer = Z.Toggle("Skip Map (Tempo)", Features.skipTimer.running, function(v) SetFeature("skipTimer", v, true) end, "Pula o mapa a cada X segundos")
    Z.Toggle("Ativar Skip por tempo", S.skipTimerEnabled, function(v) S.skipTimerEnabled = v; SaveConfig() end,
        "Precisa estar ligado para o Skip por tempo funcionar.")
    Z.Slider("Pular a cada", 5, 900, S.skipInterval, function(v) S.skipInterval = v; SaveConfig() end, { step = 5, suffix = " s" })

    Z.Sep("⏭️  SKIP SEM CHUNK")
    UI.skipStuck = Z.Toggle("Skip Map (Sem Chunk)", Features.skipStuck.running, function(v) SetFeature("skipStuck", v, true) end, "Pula se tentar pegar e não conseguir por X s")
    Z.Toggle("Ativar Skip sem chunk", S.skipStuckEnabled, function(v) S.skipStuckEnabled = v; SaveConfig() end,
        "Precisa estar ligado para o Skip sem chunk funcionar.")
    Z.Slider("Tempo sem pegar chunk", 3, 120, S.skipStuckTime, function(v) S.skipStuckTime = v; SaveConfig() end, { suffix = " s" })
end

-- ═══════════════════════════════════════════════════════════════════════
-- ABA: UNSTUCK
-- ═══════════════════════════════════════════════════════════════════════
local function LoadUnstuck()
    Z.Sep("📏  SKIP SE SIZE PARAR")
    FeatureToggle("sizeStuckSkip", "Skip se Size parar",
        "Se o Size não mudar por X segundos, unpause → skip → re-pause após Y segundos.")
    Z.Toggle("Ativar skip por Size parado", S.sizeStuckSkipEnabled, function(v)
        S.sizeStuckSkipEnabled = v
        if not v then ResetSizeStuck() end
        SaveConfig()
    end, "Se desligado, a feature fica inativa mesmo que o toggle esteja ligado.")
    Z.Slider("Size parado por", 3, 60, S.sizeStuckThreshold, function(v)
        S.sizeStuckThreshold = v
        SaveConfig()
    end, { step = 0.5, suffix = " s" })
    Z.Slider("Re-pausar após skip", 1, 30, S.sizeStuckRepauseDelay, function(v)
        S.sizeStuckRepauseDelay = v
        SaveConfig()
    end, { step = 0.5, suffix = " s" })

    Z.Sep("📡  TELEPORTE APÓS FALHA DO GRAB")
    Z.Toggle("Teleportar após falha", S.grabTeleportEnabled, function(v)
        S.grabTeleportEnabled = v
        SaveConfig()
    end, "Se não conseguir chunk após X segundos, teleporta para uma plataforma aleatória")
    Z.Slider("Teleportar após (sem chunk)", 1, 15, S.grabFailTeleportDelay, function(v)
        S.grabFailTeleportDelay = v
        SaveConfig()
    end, { step = 0.5, suffix = " s" })
    Z.Toggle("Movimento aleatório após teleporte", S.grabWalkFallback, function(v)
        S.grabWalkFallback = v
        SaveConfig()
    end, "Depois de teleportar por falha, anda aleatoriamente")
    Z.Slider("Duração do movimento", 0.5, 10, S.grabFailMoveDuration, function(v)
        S.grabFailMoveDuration = v
        SaveConfig()
    end, { step = 0.5, suffix = " s" })

    Z.Sep("🧱  BEDROCK")
    Z.Toggle("Pular mapa se preso na Bedrock", S.grabBedrockSkipEnabled, function(v)
        S.grabBedrockSkipEnabled = v
        SaveConfig()
    end, "Pula o mapa se ficar muito tempo em cima de Bedrock")
    Z.Slider("Tempo na Bedrock até pular", 1, 30, S.bedrockSkipTime, function(v)
        S.bedrockSkipTime = v
        SaveConfig()
    end, { step = 0.5, suffix = " s" })

    Z.Sep("⏸️  AUTO-OFF DO GRAB")
    Z.Toggle("Desligar grab se parado e sem crescer", S.autoOffGrabEnabled, function(v)
        S.autoOffGrabEnabled = v
        if not v then ResetAutoOff() end
        SaveConfig()
    end, "Desliga o Auto Grab quando o jogador fica parado e o tamanho não cresce")
    Z.Slider("Tempo sem crescer + parado", 1, 30, S.autoOffGrabThreshold, function(v)
        S.autoOffGrabThreshold = v
        SaveConfig()
    end, { step = 0.5, suffix = " s" })

    Z.Sep("🧍  STUCK DO GRAB / WALK")
    Z.Slider("Grab: tempo para considerar travado", 0.5, 5, S.grabStuckTime, function(v)
        S.grabStuckTime = v
        SaveConfig()
    end, { step = 0.1, suffix = " s" })
    Z.Slider("Walk: tempo para considerar travado", 1, 10, S.walkStuckTime, function(v)
        S.walkStuckTime = v
        SaveConfig()
    end, { step = 0.5, suffix = " s" })
end

-- ═══════════════════════════════════════════════════════════════════════
-- ABA: AUTO UPGRADES
-- ═══════════════════════════════════════════════════════════════════════
local function LoadAutoUpgrades()
    Z.Sep("⚡  AUTO UPGRADES")
    Z.Info("NÃO é cego: só compra se o saldo de Cubes (espelhado via SetCubes/CubesAdded) cobrir o preço do próximo nível.")

    local options = {}
    local upgradesFolder = Player:FindFirstChild("Upgrades")

    if upgradesFolder then
        for _, child in ipairs(upgradesFolder:GetChildren()) do
            if child:IsA("NumberValue") or child:IsA("IntValue") then
                table.insert(options, child.Name)
            end
        end
    end

    if #options == 0 then
        for _, name in ipairs(AUTO_UPGRADE_NAMES) do
            table.insert(options, name)
        end
        Z.Info("⚠ LocalPlayer.Upgrades não encontrado. Usando lista fixa (nomes internos).")
    end

    table.sort(options)

    local dropdownObj = Z.Dropdown("Upgrade Alvo", options, nil, function(selected)
        if selected and selected ~= "" then
            S.autoUpgradesSelectedName = selected
            autoUpgState.lastCanBuy = nil
            local upgrades = Player:FindFirstChild("Upgrades")
            local val = upgrades and upgrades:FindFirstChild(selected)
            local lvl = val and val.Value or "?"
            Z.Notify("Auto Upgrades", "Selecionado: " .. selected .. " (Nível: " .. tostring(lvl) .. ")", C.Success, 2)
            print(string.format("[ETW AutoUpgrades] Selecionado: %q | Nível: %s", selected, tostring(lvl)))
        else
            S.autoUpgradesSelectedName = nil
            autoUpgState.lastCanBuy = nil
        end
        SaveConfig()
    end, "Nome interno do upgrade (igual ao ShopScript)")

    if S.autoUpgradesSelectedName then
        dropdownObj.Set(S.autoUpgradesSelectedName, true)
    end

    Z.Sep("📊  STATUS")
    local stUpgName  = Z.Stat("Upgrade (interno)", "—")
    local stUpgLevel = Z.Stat("Nível", "—")
    local stUpgPrice = Z.Stat("Preço próximo", "—")
    local stCubes    = Z.Stat("Cubes (espelho)", "—")
    local stCanBuy   = Z.Stat("Pode comprar?", "—")
    local stLoop     = Z.Stat("Loop ativo?", "—")
    Z.PageLoop(0.5, function()
        pcall(function()
            local name = S.autoUpgradesSelectedName
            stUpgName.Set(name or "—")
            stUpgLevel.Set(name and tostring(GetUpgradeValue(name) or "—") or "—")
            local price = name and GetUpgradePrice(name) or nil
            stUpgPrice.Set(price and tostring(price) or "—")
            local cubes = GetCubes()
            stCubes.Set(cubes and tostring(cubes) or "—")
            if price ~= nil and cubes ~= nil then
                if cubes >= price then
                    stCanBuy.Set("Sim", C.Success)
                else
                    stCanBuy.Set("Não (faltam " .. (price - cubes) .. ")", C.Warning)
                end
            else
                stCanBuy.Set("?", C.TextDim)
            end
            local running = Features.autoUpgrades and Features.autoUpgrades.running
            stLoop.Set(running and "SIM" or "NÃO", running and C.Success or C.Danger)
        end)
    end)

    Z.Sep("🤖  AUTOMAÇÃO")
    FeatureToggle("autoUpgrades", "Auto Upgrade (com verificação de saldo)",
        "Só dispara PurchaseEvent:FireServer(nomeInternoExato) se cubes >= price. Não é cego.")

    Z.Button("🧪  Testar compra agora (manual)", C.Accent, function()
        local name = S.autoUpgradesSelectedName
        if not name then
            Z.Notify("Auto Upgrades", "Selecione um upgrade primeiro!", C.Warning, 2)
            return
        end
        local upgrades = Player:FindFirstChild("Upgrades")
        if not upgrades or not upgrades:FindFirstChild(name) then
            Z.Notify("Auto Upgrades", "Nome inválido: " .. tostring(name), C.Danger, 2)
            return
        end
        local price = GetUpgradePrice(name)
        local cubes = GetCubes()
        if price == nil or cubes == nil then
            Z.Notify("Auto Upgrades", "Não foi possível ler preço ou saldo.", C.Warning, 2)
            return
        end
        if cubes < price then
            Z.Notify("Auto Upgrades",
                string.format("Sem saldo: %s/%s (faltam %s)",
                    tostring(cubes), tostring(price), tostring(price - cubes)),
                C.Warning, 2)
            return
        end
        local ev = GetPurchaseEvent()
        if not ev then
            Z.Notify("Auto Upgrades", "PurchaseEvent não encontrado!", C.Danger, 2)
            return
        end
        local ok, err = pcall(function() ev:FireServer(name) end)
        if ok then
            Z.Notify("Auto Upgrades",
                string.format("Teste enviado: %q | %s/%s",
                    name, tostring(cubes), tostring(price)),
                C.Success, 2)
            print(string.format("[ETW AutoUpgrades] TESTE manual: FireServer(%q) | Cubes: %s | Preço: %s",
                name, tostring(cubes), tostring(price)))
        else
            Z.Notify("Auto Upgrades", "Erro: " .. tostring(err), C.Danger, 2)
            warn("[ETW AutoUpgrades] Erro no teste:", err)
        end
    end)

    Z.Info("💡 O saldo é espelhado via SetCubes/CubesAdded (igual ao script Cubes.Cubes), então não depende da UI estar funcionando.")
end

-- ═══════════════════════════════════════════════════════════════════════
-- ABA: TELEPORTE
-- ═══════════════════════════════════════════════════════════════════════
local function LoadTeleport()
    Z.Sep("🔁  TELEPORTE MEGA/NORMAL (TIMED)")
    Z.Info("A cada 91 min (1:31), faz o ciclo: vai pro mapa oposto, espera 10s, volta, espera 10s. Contagem reseta em 2.")

    UI.teleportTimed = Z.Toggle("Ativar Teleporte Timed (91 min)", Features.teleportTimed.running, function(v)
        SetFeature("teleportTimed", v, true)
    end, "Liga/desliga o ciclo automático a cada 91 min.")

    Z.Slider("Intervalo (minutos)", 1, 180, math.floor((S.teleportTimedInterval or TELEPORT_BASE_INTERVAL) / 60), function(v)
        S.teleportTimedInterval = v * 60
        SaveConfig()
    end, { step = 1, suffix = " min" })

    Z.Button("🔁  Fazer ciclo Mega/Normal agora", C.Warning, function()
        task.spawn(function()
            RunTeleportCycleBlocking("Manual")
        end)
    end)
    Z.Button("🔄  Resetar contagem de teleporte", C.Purple, function()
        S.teleportCount = 0
        SaveConfig()
        Z.Notify("Teleporte", "Contagem resetada para 0.", C.Success, 2)
    end)
    Z.Button("⏱  Resetar timer (força próximo ciclo agora)", C.Accent, function()
        teleportTimerState.lastRunAt = 0
        SaveTeleportTimer()
        Z.Notify("Teleporte", "Timer resetado. Próximo ciclo no próximo tick.", C.Success, 2)
    end)

    Z.Sep("📊  STATUS")
    local stCount = Z.Stat("Contagem", "0/2")
    local stMap   = Z.Stat("Mapa atual", "—")
    local stNext  = Z.Stat("Próximo ciclo", "—")
    local stLast  = Z.Stat("Último ciclo", "—")
    Z.PageLoop(0.5, function()
        pcall(function()
            local tc = tonumber(S.teleportCount) or 0
            stCount.Set(tostring(tc) .. "/" .. TELEPORT_MAX, tc >= TELEPORT_MAX and C.Danger or C.Accent)
            stMap.Set(S.teleportMapType or "—", C.TextDim)
            if not S.teleportTimedEnabled then
                stNext.Set("Desligado", C.TextDim)
            else
                local interval = tonumber(S.teleportTimedInterval) or TELEPORT_BASE_INTERVAL
                local last = teleportTimerState.lastRunAt
                if last == 0 then
                    stNext.Set("Aguardando...", C.TextDim)
                else
                    local remaining = math.max(0, interval - (tick() - last))
                    stNext.Set(Fmt(remaining), remaining <= 60 and C.Danger or C.Success)
                end
            end
            local last = teleportTimerState.lastRunAt
            if last == 0 then stLast.Set("—", C.TextDim)
            else stLast.Set(Fmt(tick() - last) .. " atrás", C.TextDim) end
        end)
    end)

    Z.Sep("ℹ️  SOBRE")
    Z.Info("A contagem é persistida no JSON e NÃO é resetada ao re-entrar. " ..
           "Se o player sair no meio do ciclo, a contagem fica onde estava. " ..
           "O timer também é salvo: se o player ficou 2h offline, o próximo ciclo acontece assim que ele entrar.")
end

-- ═══════════════════════════════════════════════════════════════════════
-- REGISTRO DAS ABAS
-- ═══════════════════════════════════════════════════════════════════════
Z.AddTab("Main",        "🎮", LoadMain)
Z.AddTab("Grab",        "🌾", LoadGrab)
Z.AddTab("Eat/Sell",    "🍽️", LoadEatSell)
Z.AddTab("Walk",        "🚶", LoadWalk)
Z.AddTab("Rewards",     "🎁", LoadRewards)
Z.AddTab("Map",         "🗺️", LoadMap)
Z.AddTab("Unstuck",     "📏", LoadUnstuck)
Z.AddTab("Auto Upgrades","⚡", LoadAutoUpgrades)
Z.AddTab("Teleporte",   "🔁", LoadTeleport)

-- ═══════════════════════════════════════════════════════════════════════
-- RESTAURA AS FUNÇÕES ATIVAS (AUTO-START)
-- ═══════════════════════════════════════════════════════════════════════
task.spawn(function()
    task.wait(1)
    if S.ActiveFeatures then
        for key, state in pairs(S.ActiveFeatures) do
            if state and Features[key] then
                SetFeature(key, true, true, true)
            end
        end
    end
end)

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
Z.Notify("Zuni Hub", "Módulo ETW v13.8 (Teleporte 91min + contagem persistente) carregado!", C.Success, 3)
print("⚡ ETW Module v13.8 iniciado")
