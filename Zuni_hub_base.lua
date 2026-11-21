-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ZUNI HUB - ALL IN ONE (Farm Edition)                              ║
-- ║  Abas únicas, sem duplicação. Foco total em Farm.                  ║
-- ╚══════════════════════════════════════════════════════════════════════╝

local Player       = game.Players.LocalPlayer
local PlayerGui    = Player:WaitForChild("PlayerGui")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local HttpService  = game:GetService("HttpService")
local VIM          = game:GetService("VirtualInputManager")

-- 1. LIMPEZA E CONFIGURAÇÃO INICIAL
if _G.ZuniHub then pcall(function() _G.ZuniHub.Alive = false end) _G.ZuniHub = nil end
for _, guiName in ipairs({"ZuniHub", "ZuniNotify"}) do
    local g = PlayerGui:FindFirstChild(guiName)
    if g then pcall(function() g:Destroy() end) end
end
task.wait(0.1)

local Colors = {
    Bg          = Color3.fromRGB(10, 10, 16),
    BgSoft      = Color3.fromRGB(16, 16, 24),
    Sidebar     = Color3.fromRGB(20, 20, 30),
    Card        = Color3.fromRGB(26, 26, 38),
    CardHover   = Color3.fromRGB(32, 32, 48),
    Accent      = Color3.fromRGB(90, 140, 255),
    AccentLight = Color3.fromRGB(140, 180, 255),
    AccentDark  = Color3.fromRGB(60, 100, 200),
    Purple      = Color3.fromRGB(160, 100, 255),
    Success     = Color3.fromRGB(80, 220, 130),
    Warning     = Color3.fromRGB(255, 200, 70),
    Danger      = Color3.fromRGB(255, 80, 90),
    Text        = Color3.fromRGB(245, 245, 255),
    TextDim     = Color3.fromRGB(155, 155, 175),
    TextMuted   = Color3.fromRGB(100, 100, 125),
    Border      = Color3.fromRGB(50, 50, 72),
    BorderLight = Color3.fromRGB(65, 65, 95),
    Divider     = Color3.fromRGB(38, 38, 52),
    Shadow      = Color3.fromRGB(0, 0, 0),
}

_G.ZuniHub = { Version = "3.1", Alive = true, Colors = Colors, SavedStates = {}, UI = {}, Connections = {} }
local Z = _G.ZuniHub

-- Persistência
local ConfigKey = "ZuniHub_Config_Farm"
pcall(function()
    local raw = _G[ConfigKey]
    if raw then
        local decoded = HttpService:JSONDecode(raw)
        for k, v in pairs(decoded) do Z.SavedStates[k] = v end
    end
end)
function Z.SaveConfig() pcall(function() _G[ConfigKey] = HttpService:JSONEncode(Z.SavedStates) end) end
function Z.Track(conn) if conn then table.insert(Z.Connections, conn) end return conn end

-- 2. UI PRINCIPAL
local Hub = Instance.new("ScreenGui", PlayerGui)
Hub.Name, Hub.ResetOnSpawn, Hub.IgnoreGuiInset, Hub.ZIndexBehavior = "ZuniHub", false, true, Enum.ZIndexBehavior.Sibling
Hub.DisplayOrder = 999

local NotifyGui = Instance.new("ScreenGui", PlayerGui)
NotifyGui.Name, NotifyGui.ResetOnSpawn, NotifyGui.IgnoreGuiInset = "ZuniNotify", false, true
NotifyGui.DisplayOrder = 1000

-- Notificações Toast
local notifyContainer = Instance.new("Frame", NotifyGui)
notifyContainer.Size, notifyContainer.Position, notifyContainer.BackgroundTransparency = UDim2.new(0, 320, 1, 0), UDim2.new(1, -340, 0, 20), 1
notifyContainer.ZIndex = 100
local notifyLayout = Instance.new("UIListLayout", notifyContainer)
notifyLayout.Padding, notifyLayout.SortOrder = UDim.new(0, 8), Enum.SortOrder.LayoutOrder
local notifyCounter = 0

function Z.Notify(title, text, color, duration)
    duration, color = duration or 4, color or Colors.Accent
    notifyCounter += 1
    local toast = Instance.new("Frame", notifyContainer)
    toast.Size, toast.BackgroundColor3, toast.BorderSizePixel, toast.ZIndex, toast.LayoutOrder = UDim2.new(1, 0, 0, 0), Colors.Card, 0, 101, notifyCounter
    Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)
    local accent = Instance.new("Frame", toast)
    accent.Size, accent.Position, accent.BackgroundColor3, accent.BorderSizePixel = UDim2.new(0, 4, 1, -12), UDim2.new(0, 4, 0, 6), color, 0
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 10)
    Instance.new("UIStroke", toast).Color = color

    local titleLbl = Instance.new("TextLabel", toast)
    titleLbl.Size, titleLbl.Position, titleLbl.BackgroundTransparency = UDim2.new(1, -24, 0, 20), UDim2.fromOffset(16, 10), 1
    titleLbl.Text, titleLbl.Font, titleLbl.TextSize, titleLbl.TextColor3, titleLbl.TextXAlignment = title, Enum.Font.GothamBold, 12, Colors.Text, Enum.TextXAlignment.Left
    titleLbl.ZIndex = 102

    local textLbl = Instance.new("TextLabel", toast)
    textLbl.Size, textLbl.Position, textLbl.BackgroundTransparency = UDim2.new(1, -24, 0, 32), UDim2.fromOffset(16, 30), 1
    textLbl.Text, textLbl.Font, textLbl.TextSize, textLbl.TextColor3, textLbl.TextXAlignment, textLbl.TextWrapped = text, Enum.Font.Gotham, 10, Colors.TextDim, Enum.TextXAlignment.Left, true
    textLbl.ZIndex = 102

    local progress = Instance.new("Frame", toast)
    progress.Size, progress.Position, progress.BackgroundColor3, progress.BorderSizePixel = UDim2.new(1, -20, 0, 2), UDim2.new(0, 10, 1, -6), color, 0
    Instance.new("UICorner", progress).CornerRadius = UDim.new(1, 0)

    TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Size = UDim2.new(1, 0, 0, 68)}):Play()
    TweenService:Create(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 2)}):Play()

    task.delay(duration, function()
        if not toast or not toast.Parent then return end
        local tw = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1})
        tw:Play()
        tw.Completed:Connect(function() pcall(function() toast:Destroy() end) end)
    end)
end

local Shadow = Instance.new("Frame", Hub)
Shadow.Size, Shadow.BackgroundColor3, Shadow.BackgroundTransparency, Shadow.BorderSizePixel, Shadow.ZIndex, Shadow.Visible = UDim2.fromScale(1, 1), Colors.Shadow, 1, 0, 1, false

local Main = Instance.new("Frame", Hub)
Main.Size, Main.Position, Main.AnchorPoint = UDim2.fromOffset(600, 500), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
Main.BackgroundColor3, Main.BorderSizePixel, Main.ZIndex, Main.Visible, Main.Active, Main.Draggable = Colors.Bg, 0, 2, false, true, true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 16)
local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color, MainStroke.Thickness, MainStroke.Transparency = Colors.BorderLight, 1.5, 0.4

local TopGlow = Instance.new("Frame", Main)
TopGlow.Size, TopGlow.BackgroundColor3, TopGlow.BorderSizePixel, TopGlow.ZIndex = UDim2.new(1, 0, 0, 3), Colors.Accent, 0, 3
local grad = Instance.new("UIGradient", TopGlow)
grad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Colors.Accent), ColorSequenceKeypoint.new(0.5, Colors.Purple), ColorSequenceKeypoint.new(1, Colors.Accent)})

local Sidebar = Instance.new("Frame", Main)
Sidebar.Size, Sidebar.BackgroundColor3, Sidebar.BorderSizePixel, Sidebar.ZIndex = UDim2.fromOffset(180, 500), Colors.Sidebar, 0, 3
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 16)
local sideCover = Instance.new("Frame", Sidebar)
sideCover.Size, sideCover.Position, sideCover.BackgroundColor3, sideCover.BorderSizePixel, sideCover.ZIndex = UDim2.fromOffset(16, 500), UDim2.new(1, -16, 0, 0), Colors.Sidebar, 0, 4

local LogoCard = Instance.new("Frame", Sidebar)
LogoCard.Size, LogoCard.Position, LogoCard.BackgroundColor3, LogoCard.BorderSizePixel, LogoCard.ZIndex = UDim2.new(1, -20, 0, 58), UDim2.fromOffset(10, 12), Colors.Card, 0, 5
Instance.new("UICorner", LogoCard).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", LogoCard).Color, Instance.new("UIStroke", LogoCard).Transparency = Colors.Accent, 0.7

local LogoTitle = Instance.new("TextLabel", LogoCard)
LogoTitle.Size, LogoTitle.Position, LogoTitle.BackgroundTransparency = UDim2.new(1, -60, 0, 24), UDim2.fromOffset(55, 6), 1
LogoTitle.Text, LogoTitle.Font, LogoTitle.TextSize, LogoTitle.TextColor3, LogoTitle.TextXAlignment = "⚡ ZUNI", Enum.Font.GothamBlack, 16, Colors.Text, Enum.TextXAlignment.Left

local LogoSub = Instance.new("TextLabel", LogoCard)
LogoSub.Size, LogoSub.Position, LogoSub.BackgroundTransparency = UDim2.new(1, -60, 0, 16), UDim2.fromOffset(55, 30), 1
LogoSub.Text, LogoSub.Font, LogoSub.TextSize, LogoSub.TextColor3, LogoSub.TextXAlignment = "FARM EDITION", Enum.Font.Gotham, 9, Colors.AccentLight, Enum.TextXAlignment.Left

-- Área de Tabs (O Segredo para não duplicar está aqui: Limpamos antes de criar)
local TabsScroll = Instance.new("ScrollingFrame", Sidebar)
TabsScroll.Size, TabsScroll.Position, TabsScroll.BackgroundTransparency, TabsScroll.BorderSizePixel = UDim2.new(1, -12, 1, -90), UDim2.fromOffset(6, 80), 1, 0
TabsScroll.ScrollBarThickness, TabsScroll.ScrollBarImageColor3 = 2, Colors.Accent
TabsScroll.CanvasSize, TabsScroll.ZIndex, TabsScroll.AutomaticCanvasSize = UDim2.new(0, 0, 0, 0), 5, Enum.AutomaticSize.Y
local TabsLayout = Instance.new("UIListLayout", TabsScroll)
TabsLayout.Padding, TabsLayout.SortOrder = UDim.new(0, 5), Enum.SortOrder.LayoutOrder

local Content = Instance.new("Frame", Main)
Content.Size, Content.Position, Content.BackgroundTransparency, Content.ZIndex = UDim2.new(1, -190, 1, -20), UDim2.fromOffset(190, 10), 1, 3

local TabTitle = Instance.new("TextLabel", Content)
TabTitle.Size, TabTitle.BackgroundTransparency, TabTitle.Text = UDim2.new(1, -80, 0, 32), 1, "Home"
TabTitle.Font, TabTitle.TextSize, TabTitle.TextColor3, TabTitle.TextXAlignment = Enum.Font.GothamBold, 20, Colors.Text, Enum.TextXAlignment.Left
TabTitle.ZIndex = 5

local TitleDivider = Instance.new("Frame", Content)
TitleDivider.Size, TitleDivider.Position, TitleDivider.BackgroundColor3, TitleDivider.BorderSizePixel, TitleDivider.BackgroundTransparency = UDim2.new(1, 0, 0, 2), UDim2.fromOffset(0, 36), Colors.Accent, 0, 0.5

local Scroll = Instance.new("ScrollingFrame", Content)
Scroll.Size, Scroll.Position, Scroll.BackgroundTransparency, Scroll.BorderSizePixel = UDim2.new(1, 0, 1, -50), UDim2.fromOffset(0, 45), 1, 0
Scroll.ScrollBarThickness, Scroll.ScrollBarImageColor3 = 4, Colors.Accent
Scroll.CanvasSize, Scroll.AutomaticCanvasSize, Scroll.ZIndex = UDim2.new(0, 0, 0, 0), Enum.AutomaticSize.Y, 4
local ContentLayout = Instance.new("UIListLayout", Scroll)
ContentLayout.Padding, ContentLayout.SortOrder = UDim.new(0, 8), Enum.SortOrder.LayoutOrder

Z.GUI = { Hub = Hub, Main = Main, Sidebar = Sidebar, Scroll = Scroll, Content = Content, TabTitle = TabTitle }
function Z.GUI.Clear() for _, v in ipairs(Scroll:GetChildren()) do if not v:IsA("UIListLayout") then v:Destroy() end end end

-- Funções de UI
local function TopBtn(icon, color, offset)
    local b = Instance.new("TextButton", Main)
    b.Size, b.Position, b.Text, b.Font, b.TextSize, b.TextColor3, b.BackgroundColor3, b.BorderSizePixel, b.AutoButtonColor, b.ZIndex = UDim2.fromOffset(28, 28), UDim2.new(1, offset, 0, 10), icon, Enum.Font.GothamBold, 14, Colors.Text, color, 0, false, 10
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = color:Lerp(Color3.new(1,1,1), 0.3)}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = color}):Play() end)
    return b
end
local MinBtn, CloseBtn = TopBtn("─", Colors.Card, -76), TopBtn("✕", Colors.Danger, -40)

function Z.ShowHub()
    Shadow.Visible, Main.Visible, Main.Size, Main.BackgroundTransparency, Sidebar.BackgroundTransparency, Shadow.BackgroundTransparency = true, true, UDim2.fromOffset(0, 0), 1, 1, 1
    TweenService:Create(Main, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(600, 500), BackgroundTransparency = 0}):Play()
    TweenService:Create(Sidebar, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
    TweenService:Create(Shadow, TweenInfo.new(0.35), {BackgroundTransparency = 0.5}):Play()
end

function Z.HideHub(cb)
    TweenService:Create(Main, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1}):Play()
    TweenService:Create(Sidebar, TweenInfo.new(0.22), {BackgroundTransparency = 1}):Play()
    local t = TweenService:Create(Shadow, TweenInfo.new(0.22), {BackgroundTransparency = 1})
    t:Play()
    t.Completed:Connect(function() Shadow.Visible, Main.Visible, Main.Size = false, false, UDim2.fromOffset(600, 500) if cb then cb() end end)
end

-- Widgets
function Z.Sep(text)
    local f = Instance.new("Frame", Scroll)
    f.Size, f.BackgroundTransparency, f.BorderSizePixel = UDim2.new(1, 0, 0, 28), 1, 0
    local line = Instance.new("Frame", f)
    line.Size, line.Position, line.BackgroundColor3, line.BorderSizePixel = UDim2.new(1, 0, 0, 1), UDim2.new(0, 0, 0.5, 0), Colors.Divider, 0
    local lbl = Instance.new("TextLabel", f)
    lbl.Size, lbl.Position, lbl.BackgroundColor3, lbl.BorderSizePixel, lbl.Text = UDim2.new(0, 200, 1, 0), UDim2.new(0.5, -100, 0, 0), Colors.Bg, 0, text
    lbl.Font, lbl.TextSize, lbl.TextColor3 = Enum.Font.GothamBold, 10, Colors.AccentLight
end

function Z.Info(text)
    local l = Instance.new("TextLabel", Scroll)
    l.Size, l.BackgroundTransparency, l.Text = UDim2.new(1, 0, 0, 16), 1, text
    l.Font, l.TextSize, l.TextColor3, l.TextXAlignment = Enum.Font.Gotham, 9, Colors.TextMuted, Enum.TextXAlignment.Left
end

function Z.Toggle(name, defaultState, callback)
    local f = Instance.new("Frame", Scroll)
    f.Size, f.BackgroundColor3, f.BorderSizePixel = UDim2.new(1, 0, 0, 42), Colors.Card, 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", f)
    stroke.Color, stroke.Transparency = Colors.Border, 0.5
    local lbl = Instance.new("TextLabel", f)
    lbl.Size, lbl.Position, lbl.BackgroundTransparency, lbl.Text = UDim2.new(1, -60, 1, 0), UDim2.fromOffset(14, 0), 1, name
    lbl.Font, lbl.TextSize, lbl.TextColor3, lbl.TextXAlignment = Enum.Font.GothamBold, 11, Colors.Text, Enum.TextXAlignment.Left
    local box = Instance.new("Frame", f)
    box.Size, box.Position, box.BackgroundColor3, box.BorderSizePixel = UDim2.fromOffset(34, 18), UDim2.new(1, -48, 0.5, -9), defaultState and Colors.Accent or Colors.CardHover, 0
    Instance.new("UICorner", box).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame", box)
    knob.Size, knob.Position, knob.BackgroundColor3, knob.BorderSizePixel = UDim2.fromOffset(14, 14), UDim2.new(0, defaultState and 18 or 2, 0.5, -7), Colors.Text, 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local click = Instance.new("TextButton", f)
    click.Size, click.BackgroundTransparency, click.Text = UDim2.new(1, 0, 1, 0), 1, ""
    local state = defaultState
    local function updateVisual(v)
        TweenService:Create(box, TweenInfo.new(0.15), {BackgroundColor3 = v and Colors.Accent or Colors.CardHover}):Play()
        TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, v and 18 or 2, 0.5, -7)}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {Color = v and Colors.Accent or Colors.Border, Transparency = v and 0.2 or 0.5}):Play()
    end
    click.MouseButton1Click:Connect(function() state = not state updateVisual(state) if callback then callback(state) end end)
    f.SetState = function(v, silent) state = v updateVisual(v) if not silent and callback then callback(v) end end
    return f
end

function Z.Slider(name, min, max, default, callback)
    local f = Instance.new("Frame", Scroll)
    f.Size, f.BackgroundColor3, f.BorderSizePixel = UDim2.new(1, 0, 0, 55), Colors.Card, 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", f).Color = Colors.Border
    local lbl = Instance.new("TextLabel", f)
    lbl.Size, lbl.Position, lbl.BackgroundTransparency, lbl.Text = UDim2.new(1, -20, 0, 18), UDim2.fromOffset(14, 8), 1, name
    lbl.Font, lbl.TextSize, lbl.TextColor3, lbl.TextXAlignment = Enum.Font.GothamBold, 10, Colors.Text, Enum.TextXAlignment.Left
    local valLbl = Instance.new("TextLabel", f)
    valLbl.Size, valLbl.Position, valLbl.BackgroundTransparency, valLbl.Text = UDim2.new(0, 60, 0, 18), UDim2.new(1, -74, 0, 8), 1, tostring(default)
    valLbl.Font, valLbl.TextSize, valLbl.TextColor3, valLbl.TextXAlignment = Enum.Font.GothamBold, 10, Colors.Accent, Enum.TextXAlignment.Right
    local bar = Instance.new("Frame", f)
    bar.Size, bar.Position, bar.BackgroundColor3, bar.BorderSizePixel = UDim2.new(1, -28, 0, 6), UDim2.fromOffset(14, 35), Colors.CardHover, 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    local range = math.max(1e-6, max - min)
    local fill = Instance.new("Frame", bar)
    fill.Size, fill.BackgroundColor3, fill.BorderSizePixel = UDim2.fromScale((default - min) / range, 1), Colors.Accent, 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame", bar)
    knob.Size, knob.AnchorPoint, knob.Position, knob.BackgroundColor3, knob.BorderSizePixel = UDim2.fromOffset(14, 14), Vector2.new(0.5, 0.5), UDim2.fromScale(fill.Size.X.Scale, 0.5), Colors.Text, 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    Instance.new("UIStroke", knob).Color = Colors.Accent
    local dragging = false
    local function update(x)
        local s = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        fill.Size, knob.Position = UDim2.fromScale(s, 1), UDim2.fromScale(s, 0.5)
        local v = math.floor(min + range * s + 0.5)
        valLbl.Text = tostring(v)
        if callback then callback(v) end
    end
    bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; update(i.Position.X) end end)
    knob.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
    UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i.Position.X) end end)
    return f
end

local activeTab = nil
function Z.AddTab(name, icon, callback)
    local btn = Instance.new("TextButton", TabsScroll)
    btn.Size, btn.BackgroundColor3, btn.BorderSizePixel, btn.AutoButtonColor = UDim2.new(1, 0, 0, 40), Colors.Card, 0, false
    btn.Text, btn.Font, btn.TextSize, btn.TextColor3, btn.TextXAlignment = "  " .. icon .. "  " .. name, Enum.Font.GothamBold, 11, Colors.TextDim, Enum.TextXAlignment.Left
    btn.ZIndex = 6
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local indicator = Instance.new("Frame", btn)
    indicator.Size, indicator.Position, indicator.BackgroundColor3, indicator.BackgroundTransparency, indicator.BorderSizePixel = UDim2.fromOffset(3, 20), UDim2.fromOffset(3, 10), Colors.Accent, 1, 0
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)
    btn.MouseEnter:Connect(function() if activeTab ~= btn then TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Colors.CardHover}):Play() end end)
    btn.MouseLeave:Connect(function() if activeTab ~= btn then TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Colors.Card}):Play() end end)
    btn.MouseButton1Click:Connect(function()
        if activeTab == btn then return end
        if activeTab then
            local oldInd = activeTab:FindFirstChild("Frame")
            if oldInd then TweenService:Create(oldInd, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play() end
            TweenService:Create(activeTab, TweenInfo.new(0.2), {BackgroundColor3 = Colors.Card, TextColor3 = Colors.TextDim}):Play()
        end
        activeTab = btn
        TweenService:Create(indicator, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Colors.AccentDark, TextColor3 = Colors.Text}):Play()
        if callback then pcall(callback) end
    end)
    return btn
end

-- 3. MÓDULO ETW (Farm)
local S = Z.SavedStates
local function Def(k, v) if S[k] == nil then S[k] = v end end
Def("grabActive", false) Def("grabInterval", 500) Def("grabPauseDuration", 5) Def("grabSellOnFail", false)
Def("eatActive", false) Def("eatInterval", 300) Def("throwActive", false) Def("throwInterval", 500)
Def("sellTimerActive", false) Def("sellTimerInterval", 12000) Def("smartSellActive", false) Def("smartSellThreshold", 5)
Def("walkActive", false) Def("walkInterval", 800) Def("autoRewardsActive", false) Def("autoRewardsDelay", 3)

local F = { grab = false, eat = false, throw = false, sellTimer = false, smartSell = false, walk = false, autoRewards = false }
local Gen = { grab = 0, eat = 0, throw = 0, sellTimer = 0, smartSell = 0, walk = 0, autoRewards = 0 }

local function GetEvents() local c = Player.Character return c and c:FindFirstChild("Events") or nil end
local function FireEvent(name)
    local events = GetEvents()
    if not events then return false end
    local ev = events:FindFirstChild(name)
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

local function StartGrab()
    Gen.grab += 1 local myGen = Gen.grab
    task.spawn(function()
        local paused, pauseEnd = false, 0
        while F.grab and Gen.grab == myGen and Z.Alive do
            if paused then if tick() < pauseEnd then task.wait(0.5); continue end paused = false end
            if not HasChunk() then
                FireEvent("Grab"); task.wait(0.35)
                if not HasChunk() then paused = true; pauseEnd = tick() + S.grabPauseDuration; if S.grabSellOnFail then FireEvent("Sell") end end
            end
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
            if stuckTime >= S.smartSellThreshold and cur > 0 then FireEvent("Sell") Z.Notify("Smart Sell", "Size travado em " .. cur .. ". Vendendo...", Colors.Success, 3) stuckTime = 0 task.wait(2) end
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

local UI = Z.UI
local function SetGrab(v) v = not not v F.grab = v S.grabActive = v if UI.grab and UI.grab.SetState then UI.grab:SetState(v, true) end if v then StartGrab() else StopGrab() end end
local function SetEat(v) v = not not v F.eat = v S.eatActive = v if UI.eat and UI.eat.SetState then UI.eat:SetState(v, true) end if v then StartEat() else StopEat() end end
local function SetThrow(v) v = not not v F.throw = v S.throwActive = v if UI.throw and UI.throw.SetState then UI.throw:SetState(v, true) end if v then StartThrow() else StopThrow() end end
local function SetSellTimer(v) v = not not v F.sellTimer = v S.sellTimerActive = v if UI.sellTimer and UI.sellTimer.SetState then UI.sellTimer:SetState(v, true) end if v then if F.smartSell then SetSmartSell(false) end StartSellTimer() else StopSellTimer() end end
local function SetSmartSell(v) v = not not v F.smartSell = v S.smartSellActive = v if UI.smartSell and UI.smartSell.SetState then UI.smartSell:SetState(v, true) end if v then if F.sellTimer then SetSellTimer(false) end StartSmartSell() else StopSmartSell() end end
local function SetWalk(v) v = not not v F.walk = v S.walkActive = v if UI.walk and UI.walk.SetState then UI.walk:SetState(v, true) end if v then StartWalk() else StopWalk() end end

-- 4. ABA ÚNICA: AUTO FARM
local function LoadAutoFarm()
    Z.GUI.Clear()
    Z.GUI.TabTitle.Text = "🌾 Auto Farm"

    Z.Sep("🖐️  AUTO GRAB")
    Z.Info("Pega objetos automaticamente. Só tenta se não tiver chunk.")
    UI.grab = Z.Toggle("Ativar Auto Grab", F.grab, SetGrab)
    Z.Slider("Intervalo entre tentativas (ms)", 100, 3000, S.grabInterval, function(v) S.grabInterval = v end)
    Z.Slider("Pausa após falha (s)", 1, 15, S.grabPauseDuration, function(v) S.grabPauseDuration = v end)

    Z.Sep("🍽️  AUTO EAT")
    Z.Info("Come automaticamente. Ideal para crescer rapidamente.")
    UI.eat = Z.Toggle("Ativar Auto Eat", F.eat, SetEat)
    Z.Slider("Intervalo entre mordidas (ms)", 100, 3000, S.eatInterval, function(v) S.eatInterval = v end)

    Z.Sep("🗑️  AUTO THROW")
    Z.Info("Joga o que estiver na mão fora. Útil para liberar grab.")
    UI.throw = Z.Toggle("Ativar Auto Throw", F.throw, SetThrow)
    Z.Slider("Intervalo entre arremessos (ms)", 100, 3000, S.throwInterval, function(v) S.throwInterval = v end)

    Z.Sep("💰  AUTO SELL (TIMER)")
    Z.Info("Vende a cada X ms. Simples e direto.")
    UI.sellTimer = Z.Toggle("Ativar Auto Sell", F.sellTimer, SetSellTimer)
    Z.Slider("Vender a cada (ms)", 1000, 60000, S.sellTimerInterval, function(v) S.sellTimerInterval = v end)

    Z.Sep("🧠  SMART SELL (TAMANHO)")
    Z.Info("Verifica leaderstats.Size. Se parar de crescer, vende.")
    UI.smartSell = Z.Toggle("Ativar Smart Sell", F.smartSell, SetSmartSell)
    Z.Slider("Tempo travado para vender (s)", 2, 20, S.smartSellThreshold, function(v) S.smartSellThreshold = v end)

    Z.Sep("🚶  AUTO WALK")
    Z.Info("Anda aleatoriamente pelo mapa com detecção de chão.")
    UI.walk = Z.Toggle("Ativar Auto Walk", F.walk, SetWalk)
    Z.Slider("Intervalo de passos (ms)", 200, 3000, S.walkInterval, function(v) S.walkInterval = v end)
end

-- O SEGREDO PARA NÃO DUPLICAR: Limpar abas antigas da UI antes de iniciar
for _, v in ipairs(TabsScroll:GetChildren()) do
    if v:IsA("TextButton") then v:Destroy() end
end

Z.AddTab("Auto Farm", "🌾", LoadAutoFarm)
-- Força o clique na aba para inicializar
TabsScroll:GetChildren()[2]:FindFirstChildWhichIsA("TextButton"):WaitForChild("UIStroke") -- gambiarra só pra garantir o carregamento

Z.ShowHub()
Z.Ready = true
Z.Notify("Zuni Hub", "Hub e Módulo Farm carregados!", Colors.Success, 4)
print("⚡ Zuni Hub (Farm Edition) Iniciado com Sucesso!")
