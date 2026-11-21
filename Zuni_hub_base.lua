-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ZUNI HUB - PREMIUM UI BASE v4.0                                   ║
-- ║  Apenas UI, Home e Player. Design ultra limpo.                     ║
-- ╚══════════════════════════════════════════════════════════════════════╝

local Player       = game.Players.LocalPlayer
local PlayerGui    = Player:WaitForChild("PlayerGui")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

-- ═══════════════════════════════════════════════════════════════════════
-- PALETA PREMIUM
-- ═══════════════════════════════════════════════════════════════════════
local Colors = {
    Bg          = Color3.fromRGB(12, 12, 18),
    BgSoft      = Color3.fromRGB(18, 18, 26),
    Sidebar     = Color3.fromRGB(22, 22, 32),
    Card        = Color3.fromRGB(30, 30, 42),
    CardHover   = Color3.fromRGB(38, 38, 55),
    Accent      = Color3.fromRGB(110, 160, 255),
    AccentLight = Color3.fromRGB(160, 200, 255),
    AccentDark  = Color3.fromRGB(70, 110, 200),
    Purple      = Color3.fromRGB(180, 120, 255),
    Success     = Color3.fromRGB(80, 220, 130),
    Warning     = Color3.fromRGB(255, 200, 70),
    Danger      = Color3.fromRGB(255, 80, 90),
    Text        = Color3.fromRGB(245, 245, 255),
    TextDim     = Color3.fromRGB(160, 160, 180),
    TextMuted   = Color3.fromRGB(100, 100, 125),
    Border      = Color3.fromRGB(55, 55, 75),
    Divider     = Color3.fromRGB(40, 40, 55),
    Shadow      = Color3.fromRGB(0, 0, 0),
}

-- Limpeza
if _G.ZuniHub then pcall(function() _G.ZuniHub.Alive = false end) _G.ZuniHub = nil end
for _, guiName in ipairs({"ZuniHub", "ZuniNotify"}) do
    local g = PlayerGui:FindFirstChild(guiName)
    if g then pcall(function() g:Destroy() end) end
end
task.wait(0.1)

_G.ZuniHub = { Version = "4.0", Alive = true, Colors = Colors, SavedStates = {}, UI = {}, Connections = {} }
local Z = _G.ZuniHub
function Z.Track(conn) if conn then table.insert(Z.Connections, conn) end return conn end

-- ═══════════════════════════════════════════════════════════════════════
-- SCREEN GUIS
-- ═══════════════════════════════════════════════════════════════════════
local Hub = Instance.new("ScreenGui", PlayerGui)
Hub.Name, Hub.ResetOnSpawn, Hub.IgnoreGuiInset, Hub.ZIndexBehavior = "ZuniHub", false, true, Enum.ZIndexBehavior.Sibling
Hub.DisplayOrder = 999

local NotifyGui = Instance.new("ScreenGui", PlayerGui)
NotifyGui.Name, NotifyGui.ResetOnSpawn, NotifyGui.IgnoreGuiInset = "ZuniNotify", false, true
NotifyGui.DisplayOrder = 1000

-- ═══════════════════════════════════════════════════════════════════════
-- SISTEMA DE NOTIFICAÇÃO
-- ═══════════════════════════════════════════════════════════════════════
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
    Instance.new("UIStroke", toast).Color = color
    
    local accent = Instance.new("Frame", toast)
    accent.Size, accent.Position, accent.BackgroundColor3, accent.BorderSizePixel = UDim2.new(0, 4, 1, -12), UDim2.new(0, 4, 0, 6), color, 0
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 10)

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

-- ═══════════════════════════════════════════════════════════════════════
-- JANELA PRINCIPAL
-- ═══════════════════════════════════════════════════════════════════════
local Shadow = Instance.new("Frame", Hub)
Shadow.Size, Shadow.BackgroundColor3, Shadow.BackgroundTransparency, Shadow.BorderSizePixel, Shadow.ZIndex, Shadow.Visible = UDim2.fromScale(1, 1), Colors.Shadow, 1, 0, 1, false

local Main = Instance.new("Frame", Hub)
Main.Size, Main.Position, Main.AnchorPoint = UDim2.fromOffset(650, 480), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
Main.BackgroundColor3, Main.BorderSizePixel, Main.ZIndex, Main.Visible, Main.Active, Main.Draggable = Colors.Bg, 0, 2, false, true, true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 16)
local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color, MainStroke.Thickness, MainStroke.Transparency = Colors.Border, 1.5, 0.3

local TopGlow = Instance.new("Frame", Main)
TopGlow.Size, TopGlow.BackgroundColor3, TopGlow.BorderSizePixel, TopGlow.ZIndex = UDim2.new(1, 0, 0, 3), Colors.Accent, 0, 3
local grad = Instance.new("UIGradient", TopGlow)
grad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Colors.Accent), ColorSequenceKeypoint.new(0.5, Colors.Purple), ColorSequenceKeypoint.new(1, Colors.Accent)})

-- SIDEBAR
local Sidebar = Instance.new("Frame", Main)
Sidebar.Size, Sidebar.BackgroundColor3, Sidebar.BorderSizePixel, Sidebar.ZIndex = UDim2.fromOffset(180, 480), Colors.Sidebar, 0, 3
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 16)
local sideCover = Instance.new("Frame", Sidebar)
sideCover.Size, sideCover.Position, sideCover.BackgroundColor3, sideCover.BorderSizePixel, sideCover.ZIndex = UDim2.fromOffset(16, 480), UDim2.new(1, -16, 0, 0), Colors.Sidebar, 0, 4

local LogoCard = Instance.new("Frame", Sidebar)
LogoCard.Size, LogoCard.Position, LogoCard.BackgroundColor3, LogoCard.BorderSizePixel, LogoCard.ZIndex = UDim2.new(1, -20, 0, 58), UDim2.fromOffset(10, 12), Colors.Card, 0, 5
Instance.new("UICorner", LogoCard).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", LogoCard).Color, Instance.new("UIStroke", LogoCard).Transparency = Colors.Accent, 0.7

local LogoTitle = Instance.new("TextLabel", LogoCard)
LogoTitle.Size, LogoTitle.Position, LogoTitle.BackgroundTransparency = UDim2.new(1, -60, 0, 24), UDim2.fromOffset(55, 6), 1
LogoTitle.Text, LogoTitle.Font, LogoTitle.TextSize, LogoTitle.TextColor3, LogoTitle.TextXAlignment = "⚡ ZUNI", Enum.Font.GothamBlack, 18, Colors.Text, Enum.TextXAlignment.Left

local LogoSub = Instance.new("TextLabel", LogoCard)
LogoSub.Size, LogoSub.Position, LogoSub.BackgroundTransparency = UDim2.new(1, -60, 0, 16), UDim2.fromOffset(55, 30), 1
LogoSub.Text, LogoSub.Font, LogoSub.TextSize, LogoSub.TextColor3, LogoSub.TextXAlignment = "HUB v4.0", Enum.Font.Gotham, 9, Colors.AccentLight, Enum.TextXAlignment.Left

local TabsScroll = Instance.new("ScrollingFrame", Sidebar)
TabsScroll.Size, TabsScroll.Position, TabsScroll.BackgroundTransparency, TabsScroll.BorderSizePixel = UDim2.new(1, -12, 1, -90), UDim2.fromOffset(6, 80), 1, 0
TabsScroll.ScrollBarThickness, TabsScroll.ScrollBarImageColor3 = 2, Colors.Accent
TabsScroll.CanvasSize, TabsScroll.ZIndex, TabsScroll.AutomaticCanvasSize = UDim2.new(0, 0, 0, 0), 5, Enum.AutomaticSize.Y
local TabsLayout = Instance.new("UIListLayout", TabsScroll)
TabsLayout.Padding, TabsLayout.SortOrder = UDim.new(0, 5), Enum.SortOrder.LayoutOrder

-- ÁREA DE CONTEÚDO
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

-- BOTÕES DO TOPO
local function TopBtn(icon, color, offset)
    local b = Instance.new("TextButton", Main)
    b.Size, b.Position, b.Text, b.Font, b.TextSize, b.TextColor3, b.BackgroundColor3, b.BorderSizePixel, b.AutoButtonColor, b.ZIndex = UDim2.fromOffset(28, 28), UDim2.new(1, offset, 0, 10), icon, Enum.Font.GothamBold, 14, Colors.Text, color, 0, false, 10
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = color:Lerp(Color3.new(1,1,1), 0.3)}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = color}):Play() end)
    return b
end
local MinBtn, CloseBtn = TopBtn("─", Colors.Card, -76), TopBtn("✕", Colors.Danger, -40)

-- MOSTRAR / ESCONDER
function Z.ShowHub()
    Shadow.Visible, Main.Visible, Main.Size, Main.BackgroundTransparency, Sidebar.BackgroundTransparency, Shadow.BackgroundTransparency = true, true, UDim2.fromOffset(0, 0), 1, 1, 1
    TweenService:Create(Main, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(650, 480), BackgroundTransparency = 0}):Play()
    TweenService:Create(Sidebar, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
    TweenService:Create(Shadow, TweenInfo.new(0.35), {BackgroundTransparency = 0.5}):Play()
end

function Z.HideHub(cb)
    TweenService:Create(Main, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1}):Play()
    TweenService:Create(Sidebar, TweenInfo.new(0.22), {BackgroundTransparency = 1}):Play()
    local t = TweenService:Create(Shadow, TweenInfo.new(0.22), {BackgroundTransparency = 1})
    t:Play()
    t.Completed:Connect(function() Shadow.Visible, Main.Visible, Main.Size = false, false, UDim2.fromOffset(650, 480) if cb then cb() end end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- WIDGETS (Slider, Toggle, Button)
-- ═══════════════════════════════════════════════════════════════════════
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

function Z.Button(name, color, callback)
    color = color or Colors.Accent
    local b = Instance.new("TextButton", Scroll)
    b.Size, b.BackgroundColor3, b.Text, b.Font, b.TextSize, b.TextColor3, b.BorderSizePixel, b.AutoButtonColor = UDim2.new(1, 0, 0, 38), color, name, Enum.Font.GothamBold, 11, Colors.Text, 0, false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = color:Lerp(Color3.new(1,1,1), 0.2)}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = color}):Play() end)
    b.MouseButton1Click:Connect(function() if callback then pcall(callback) end end)
    return b
end

-- ═══════════════════════════════════════════════════════════════════════
-- SISTEMA DE TABS
-- ═══════════════════════════════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════════════════════════════
-- MINIMIZAR / FECHAR
-- ═══════════════════════════════════════════════════════════════════════
local isMini, Bubble = false, nil
MinBtn.MouseButton1Click:Connect(function()
    if isMini then return end
    isMini = true
    Z.HideHub(function()
        Bubble = Instance.new("TextButton", Hub)
        Bubble.AnchorPoint, Bubble.Position, Bubble.Size, Bubble.Text, Bubble.Font, Bubble.TextSize, Bubble.TextColor3, Bubble.BackgroundColor3, Bubble.AutoButtonColor, Bubble.BorderSizePixel, Bubble.ZIndex = Vector2.new(0.5, 0.5), UDim2.new(0.85, 0, 0.85, 0), UDim2.fromOffset(0, 0), "Z", Enum.Font.GothamBlack, 22, Colors.Text, Colors.Accent, false, 0, 100
        Instance.new("UICorner", Bubble).CornerRadius = UDim.new(1, 0)
        local s = Instance.new("UIStroke", Bubble); s.Color, s.Thickness = Colors.AccentLight, 2
        TweenService:Create(Bubble, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Size = UDim2.fromOffset(58, 58)}):Play()
        Bubble.MouseButton1Click:Connect(function()
            TweenService:Create(Bubble, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = UDim2.fromOffset(0, 0)}):Play()
            task.delay(0.2, function() if Bubble then Bubble:Destroy(); Bubble = nil; isMini = false; Z.ShowHub() end end)
        end)
    end)
end)

CloseBtn.MouseButton1Click:Connect(function()
    Z.Alive = false
    Hub:Destroy()
    NotifyGui:Destroy()
end)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        if isMini and Bubble then
            TweenService:Create(Bubble, TweenInfo.new(0.2), {Size = UDim2.fromOffset(0, 0)}):Play()
            task.delay(0.2, function() if Bubble then Bubble:Destroy(); Bubble = nil; isMini = false; Z.ShowHub() end end)
        elseif not Main.Visible then
            Z.ShowHub()
        elseif Main.Visible then
            isMini = true
            Z.HideHub(function()
                Bubble = Instance.new("TextButton", Hub)
                Bubble.AnchorPoint, Bubble.Position, Bubble.Size, Bubble.Text, Bubble.Font, Bubble.TextSize, Bubble.TextColor3, Bubble.BackgroundColor3, Bubble.AutoButtonColor, Bubble.BorderSizePixel, Bubble.ZIndex = Vector2.new(0.5, 0.5), UDim2.new(0.85, 0, 0.85, 0), UDim2.fromOffset(58, 58), "Z", Enum.Font.GothamBlack, 22, Colors.Text, Colors.Accent, false, 0, 100
                Instance.new("UICorner", Bubble).CornerRadius = UDim.new(1, 0)
                local s = Instance.new("UIStroke", Bubble); s.Color, s.Thickness = Colors.AccentLight, 2
                Bubble.MouseButton1Click:Connect(function() Bubble:Destroy(); Bubble = nil; isMini = false; Z.ShowHub() end)
            end)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- TABS PADRÃO: HOME E PLAYER (Apenas o básico)
-- ═══════════════════════════════════════════════════════════════════════
local function LoadHome()
    Z.GUI.Clear()
    Z.GUI.TabTitle.Text = "🏠 Home"
    
    local card = Instance.new("Frame", Scroll)
    card.Size, card.BackgroundColor3, card.BorderSizePixel = UDim2.new(1, 0, 0, 120), Colors.Card, 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    Instance.new("UIStroke", card).Color = Colors.Border

    local title = Instance.new("TextLabel", card)
    title.Size, title.Position, title.BackgroundTransparency = UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, 10), 1
    title.Text, title.Font, title.TextSize, title.TextColor3, title.TextXAlignment = "Bem-vindo ao Zuni Hub", Enum.Font.GothamBold, 16, Colors.Text, Enum.TextXAlignment.Left

    local desc = Instance.new("TextLabel", card)
    desc.Size, desc.Position, desc.BackgroundTransparency, desc.Text = UDim2.new(1, -20, 0, 70), UDim2.fromOffset(10, 40), 1, "O melhor hub multi-jogo.\nSelecione uma aba ao lado para começar.\nUse INSERT para esconder/mostrar a interface."
    desc.Font, desc.TextSize, desc.TextColor3, desc.TextXAlignment, desc.TextWrapped = Enum.Font.Gotham, 10, Colors.TextDim, Enum.TextXAlignment.Left, true
end

local function LoadPlayer()
    Z.GUI.Clear()
    Z.GUI.TabTitle.Text = "👤 Player"
    
    Z.Sep("🏃 Movimento")
    Z.Slider("Walk Speed", 16, 200, S.walkSpeed or 16, function(v)
        S.walkSpeed = v
        local char = Player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char:FindFirstChildOfClass("Humanoid").WalkSpeed = v
        end
    end)
    Z.Slider("Jump Power", 50, 200, S.jumpPower or 50, function(v)
        S.jumpPower = v
        local char = Player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char:FindFirstChildOfClass("Humanoid").JumpPower = v
        end
    end)
end

-- Registra Home e Player
for _, v in ipairs(TabsScroll:GetChildren()) do
    if v:IsA("TextButton") then v:Destroy() end
end
Z.AddTab("Home", "🏠", LoadHome)
Z.AddTab("Player", "👤", LoadPlayer)

Z.ShowHub()
Z.Ready = true
print("✅ Zuni Hub Base v4.0 Carregada. (Apenas UI e Abas Base)")
