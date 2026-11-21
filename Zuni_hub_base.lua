-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ZUNI HUB - BASE OFICIAL v2.0                                       ║
-- ║  Arquitetura: Notification System, Draggable, Persistence, Kbinds   ║
-- ║  ~900 linhas - UI Premium com Tween, Sounds, Glassmorphism          ║
-- ╚══════════════════════════════════════════════════════════════════════╝

local Player      = game.Players.LocalPlayer
local PlayerGui   = Player:WaitForChild("PlayerGui")
local UIS         = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService  = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")

-- ═══════════════════════════════════════════════════════════════════════
-- PALETA PREMIUM
-- ═══════════════════════════════════════════════════════════════════════
local Colors = {
    -- Backgrounds
    Bg          = Color3.fromRGB(10, 10, 16),
    BgSoft      = Color3.fromRGB(16, 16, 24),
    Sidebar     = Color3.fromRGB(20, 20, 30),
    Card        = Color3.fromRGB(26, 26, 38),
    CardHover   = Color3.fromRGB(32, 32, 48),
    -- Accents
    Accent      = Color3.fromRGB(90, 140, 255),
    AccentLight = Color3.fromRGB(140, 180, 255),
    AccentDark  = Color3.fromRGB(60, 100, 200),
    Purple      = Color3.fromRGB(160, 100, 255),
    Success     = Color3.fromRGB(80, 220, 130),
    Warning     = Color3.fromRGB(255, 200, 70),
    Danger      = Color3.fromRGB(255, 80, 90),
    -- Text
    Text        = Color3.fromRGB(245, 245, 255),
    TextDim     = Color3.fromRGB(155, 155, 175),
    TextMuted   = Color3.fromRGB(100, 100, 125),
    -- Lines
    Border      = Color3.fromRGB(50, 50, 72),
    BorderLight = Color3.fromRGB(65, 65, 95),
    Divider     = Color3.fromRGB(38, 38, 52),
    -- Shadow
    Shadow      = Color3.fromRGB(0, 0, 0),
}

-- ═══════════════════════════════════════════════════════════════════════
-- LIMPEZA DE SESSÃO ANTERIOR
-- ═══════════════════════════════════════════════════════════════════════
if _G.ZuniHub then
    pcall(function() _G.ZuniHub.Alive = false end)
    _G.ZuniHub = nil
end
for _, guiName in ipairs({"ZuniHub", "ZuniNotify", "ZuniFly"}) do
    local g = PlayerGui:FindFirstChild(guiName)
    if g then pcall(function() g:Destroy() end) end
end

-- ═══════════════════════════════════════════════════════════════════════
-- HUB GLOBAL
-- ═══════════════════════════════════════════════════════════════════════
_G.ZuniHub = {
    Version = "2.0",
    Alive   = true,
    Ready   = false,
    Colors  = Colors,
    SavedStates = {},
    UI          = {},
    Connections = {},
    Config      = {},
    Flags       = {},
}

local Z = _G.ZuniHub

-- ─────────────────────────────────────────────────────────────────────
-- CONFIG PERSISTENCE (SessionData em _G)
-- ─────────────────────────────────────────────────────────────────────
local ConfigKey = "ZuniHub_Config_v2"
local function SaveConfig()
    pcall(function()
        _G[ConfigKey] = HttpService:JSONEncode(Z.SavedStates)
    end)
end
local function LoadConfig()
    pcall(function()
        local raw = _G[ConfigKey]
        if raw then
            local decoded = HttpService:JSONDecode(raw)
            for k, v in pairs(decoded) do Z.SavedStates[k] = v end
        end
    end)
end
LoadConfig()

-- ─────────────────────────────────────────────────────────────────────
-- TRACK CONNECTIONS
-- ─────────────────────────────────────────────────────────────────────
function Z.Track(conn)
    if conn then table.insert(Z.Connections, conn) end
    return conn
end

function Z.DisconnectAll()
    for _, c in ipairs(Z.Connections) do
        pcall(function() c:Disconnect() end)
    end
    Z.Connections = {}
end

-- ═══════════════════════════════════════════════════════════════════════
-- SCREEN GUI + BLOBS DE FUNDO
-- ═══════════════════════════════════════════════════════════════════════
local Hub = Instance.new("ScreenGui", PlayerGui)
Hub.Name              = "ZuniHub"
Hub.ResetOnSpawn      = false
Hub.IgnoreGuiInset    = true
Hub.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
Hub.DisplayOrder      = 999

-- ─────────────────────────────────────────────────────────────────────
-- NOTIFICATION GUI (separada, acima do hub)
-- ─────────────────────────────────────────────────────────────────────
local NotifyGui = Instance.new("ScreenGui", PlayerGui)
NotifyGui.Name           = "ZuniNotify"
NotifyGui.ResetOnSpawn   = false
NotifyGui.IgnoreGuiInset = true
NotifyGui.DisplayOrder   = 1000

-- ─────────────────────────────────────────────────────────────────────
-- SISTEMA DE NOTIFICAÇÕES TOAST
-- ─────────────────────────────────────────────────────────────────────
local notifyContainer = Instance.new("Frame", NotifyGui)
notifyContainer.Size             = UDim2.new(0, 320, 1, 0)
notifyContainer.Position         = UDim2.new(1, -340, 0, 20)
notifyContainer.BackgroundTransparency = 1
notifyContainer.ZIndex           = 100

local notifyLayout = Instance.new("UIListLayout", notifyContainer)
notifyLayout.Padding      = UDim.new(0, 8)
notifyLayout.SortOrder    = Enum.SortOrder.LayoutOrder

local notifyCounter = 0

local function Notify(title, text, color, duration)
    duration = duration or 4
    color = color or Colors.Accent
    notifyCounter = notifyCounter + 1
    local order = notifyCounter

    local toast = Instance.new("Frame", notifyContainer)
    toast.Size = UDim2.new(1, 0, 0, 0)
    toast.BackgroundColor3 = Colors.Card
    toast.BorderSizePixel = 0
    toast.ZIndex = 101
    toast.LayoutOrder = order
    Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)

    local accent = Instance.new("Frame", toast)
    accent.Size = UDim2.new(0, 4, 1, 0)
    accent.BackgroundColor3 = color
    accent.BorderSizePixel = 0
    accent.ZIndex = 102
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 10)
    accent.Size = UDim2.new(0, 4, 1, -12)
    accent.Position = UDim2.new(0, 4, 0, 6)

    local stroke = Instance.new("UIStroke", toast)
    stroke.Color = color
    stroke.Thickness = 1
    stroke.Transparency = 0.6

    local titleLbl = Instance.new("TextLabel", toast)
    titleLbl.Size = UDim2.new(1, -24, 0, 20)
    titleLbl.Position = UDim2.fromOffset(16, 10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = Colors.Text
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.ZIndex = 102

    local textLbl = Instance.new("TextLabel", toast)
    textLbl.Size = UDim2.new(1, -24, 0, 32)
    textLbl.Position = UDim2.fromOffset(16, 30)
    textLbl.BackgroundTransparency = 1
    textLbl.Text = text
    textLbl.Font = Enum.Font.Gotham
    textLbl.TextSize = 10
    textLbl.TextColor3 = Colors.TextDim
    textLbl.TextXAlignment = Enum.TextXAlignment.Left
    textLbl.TextWrapped = true
    textLbl.ZIndex = 102

    local progress = Instance.new("Frame", toast)
    progress.Size = UDim2.new(1, -20, 0, 2)
    progress.Position = UDim2.new(0, 10, 1, -6)
    progress.BackgroundColor3 = color
    progress.BorderSizePixel = 0
    progress.ZIndex = 102
    Instance.new("UICorner", progress).CornerRadius = UDim.new(1, 0)

    TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, 0, 0, 68)
    }):Play()

    TweenService:Create(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Size = UDim2.new(0, 0, 0, 2)
    }):Play()

    task.delay(duration, function()
        if not toast or not toast.Parent then return end
        local tw = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
        })
        tw:Play()
        tw.Completed:Connect(function() pcall(function() toast:Destroy() end) end)
    end)
end

Z.Notify = Notify

-- ─────────────────────────────────────────────────────────────────────
-- SHADOW
-- ─────────────────────────────────────────────────────────────────────
local Shadow = Instance.new("Frame", Hub)
Shadow.Size = UDim2.fromScale(1, 1)
Shadow.BackgroundColor3 = Colors.Shadow
Shadow.BackgroundTransparency = 1
Shadow.BorderSizePixel = 0
Shadow.ZIndex = 1
Shadow.Visible = false

-- ─────────────────────────────────────────────────────────────────────
-- MAIN CONTAINER
-- ─────────────────────────────────────────────────────────────────────
local Main = Instance.new("Frame", Hub)
Main.Size = UDim2.fromOffset(780, 500)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Colors.Bg
Main.BorderSizePixel = 0
Main.ZIndex = 2
Main.Visible = false
Main.Active = true
Main.Draggable = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 16)

local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Colors.BorderLight
MainStroke.Thickness = 1.5
MainStroke.Transparency = 0.4

-- Top gradient bar
local TopGlow = Instance.new("Frame", Main)
TopGlow.Size = UDim2.new(1, 0, 0, 3)
TopGlow.BackgroundColor3 = Colors.Accent
TopGlow.BorderSizePixel = 0
TopGlow.ZIndex = 3
local grad = Instance.new("UIGradient", TopGlow)
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Colors.Accent),
    ColorSequenceKeypoint.new(0.5, Colors.Purple),
    ColorSequenceKeypoint.new(1, Colors.Accent),
})

-- ─────────────────────────────────────────────────────────────────────
-- SIDEBAR
-- ─────────────────────────────────────────────────────────────────────
local Sidebar = Instance.new("Frame", Main)
Sidebar.Size = UDim2.fromOffset(200, 500)
Sidebar.BackgroundColor3 = Colors.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 3
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 16)
local sideCover = Instance.new("Frame", Sidebar)
sideCover.Size = UDim2.fromOffset(16, 500)
sideCover.Position = UDim2.new(1, -16, 0, 0)
sideCover.BackgroundColor3 = Colors.Sidebar
sideCover.BorderSizePixel = 0
sideCover.ZIndex = 4

-- Logo
local LogoCard = Instance.new("Frame", Sidebar)
LogoCard.Size = UDim2.new(1, -20, 0, 58)
LogoCard.Position = UDim2.fromOffset(10, 12)
LogoCard.BackgroundColor3 = Colors.Card
LogoCard.BorderSizePixel = 0
LogoCard.ZIndex = 5
Instance.new("UICorner", LogoCard).CornerRadius = UDim.new(0, 10)
local ls = Instance.new("UIStroke", LogoCard)
ls.Color = Colors.Accent
ls.Transparency = 0.7

local LogoIcon = Instance.new("TextLabel", LogoCard)
LogoIcon.Size = UDim2.fromOffset(40, 40)
LogoIcon.Position = UDim2.fromOffset(10, 9)
LogoIcon.BackgroundTransparency = 1
LogoIcon.Text = "⚡"
LogoIcon.Font = Enum.Font.GothamBold
LogoIcon.TextSize = 26
LogoIcon.TextColor3 = Colors.Accent
LogoIcon.ZIndex = 6

local LogoTitle = Instance.new("TextLabel", LogoCard)
LogoTitle.Size = UDim2.new(1, -60, 0, 24)
LogoTitle.Position = UDim2.fromOffset(55, 6)
LogoTitle.BackgroundTransparency = 1
LogoTitle.Text = "ZUNI HUB"
LogoTitle.Font = Enum.Font.GothamBlack
LogoTitle.TextSize = 16
LogoTitle.TextColor3 = Colors.Text
LogoTitle.TextXAlignment = Enum.TextXAlignment.Left
LogoTitle.ZIndex = 6

local LogoSub = Instance.new("TextLabel", LogoCard)
LogoSub.Size = UDim2.new(1, -60, 0, 16)
LogoSub.Position = UDim2.fromOffset(55, 30)
LogoSub.BackgroundTransparency = 1
LogoSub.Text = "v2.0 • PREMIUM"
LogoSub.Font = Enum.Font.Gotham
LogoSub.TextSize = 9
LogoSub.TextColor3 = Colors.AccentLight
LogoSub.TextXAlignment = Enum.TextXAlignment.Left
LogoSub.ZIndex = 6

-- Tabs
local TabsScroll = Instance.new("ScrollingFrame", Sidebar)
TabsScroll.Size = UDim2.new(1, -12, 1, -90)
TabsScroll.Position = UDim2.fromOffset(6, 80)
TabsScroll.BackgroundTransparency = 1
TabsScroll.BorderSizePixel = 0
TabsScroll.ScrollBarThickness = 2
TabsScroll.ScrollBarImageColor3 = Colors.Accent
TabsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
TabsScroll.ZIndex = 5
TabsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

local TabsLayout = Instance.new("UIListLayout", TabsScroll)
TabsLayout.Padding = UDim.new(0, 5)
TabsLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- ─────────────────────────────────────────────────────────────────────
-- CONTENT AREA
-- ─────────────────────────────────────────────────────────────────────
local Content = Instance.new("Frame", Main)
Content.Size = UDim2.new(1, -210, 1, -20)
Content.Position = UDim2.fromOffset(210, 10)
Content.BackgroundTransparency = 1
Content.ZIndex = 3

local TabTitle = Instance.new("TextLabel", Content)
TabTitle.Size = UDim2.new(1, -80, 0, 32)
TabTitle.BackgroundTransparency = 1
TabTitle.Text = "Home"
TabTitle.Font = Enum.Font.GothamBold
TabTitle.TextSize = 20
TabTitle.TextColor3 = Colors.Text
TabTitle.TextXAlignment = Enum.TextXAlignment.Left
TabTitle.ZIndex = 5

local TitleDivider = Instance.new("Frame", Content)
TitleDivider.Size = UDim2.new(1, 0, 0, 2)
TitleDivider.Position = UDim2.fromOffset(0, 36)
TitleDivider.BackgroundColor3 = Colors.Accent
TitleDivider.BorderSizePixel = 0
TitleDivider.BackgroundTransparency = 0.5
TitleDivider.ZIndex = 5

local Scroll = Instance.new("ScrollingFrame", Content)
Scroll.Size = UDim2.new(1, 0, 1, -50)
Scroll.Position = UDim2.fromOffset(0, 45)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarImageColor3 = Colors.Accent
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.ZIndex = 4

local ContentLayout = Instance.new("UIListLayout", Scroll)
ContentLayout.Padding = UDim.new(0, 8)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- ─────────────────────────────────────────────────────────────────────
-- TOP BUTTONS
-- ─────────────────────────────────────────────────────────────────────
local function TopBtn(icon, color, offset)
    local b = Instance.new("TextButton", Main)
    b.Size = UDim2.fromOffset(28, 28)
    b.Position = UDim2.new(1, offset, 0, 10)
    b.Text = icon
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.TextColor3 = Colors.Text
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.ZIndex = 10
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {
            BackgroundColor3 = color:Lerp(Color3.new(1,1,1), 0.3)
        }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), { BackgroundColor3 = color }):Play()
    end)
    return b
end

local MinBtn   = TopBtn("─", Colors.Card, -76)
local CloseBtn = TopBtn("✕", Colors.Danger, -40)

-- ─────────────────────────────────────────────────────────────────────
-- SHOW / HIDE
-- ─────────────────────────────────────────────────────────────────────
local function ShowHub()
    Shadow.Visible = true
    Main.Visible = true
    Main.Size = UDim2.fromOffset(0, 0)
    Main.BackgroundTransparency = 1
    Sidebar.BackgroundTransparency = 1
    Shadow.BackgroundTransparency = 1
    TweenService:Create(Main, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(780, 500),
        BackgroundTransparency = 0
    }):Play()
    TweenService:Create(Sidebar, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0
    }):Play()
    TweenService:Create(Shadow, TweenInfo.new(0.35), {
        BackgroundTransparency = 0.5
    }):Play()
end

local function HideHub(cb)
    TweenService:Create(Main, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1
    }):Play()
    TweenService:Create(Sidebar, TweenInfo.new(0.22), {
        BackgroundTransparency = 1
    }):Play()
    local t = TweenService:Create(Shadow, TweenInfo.new(0.22), {
        BackgroundTransparency = 1
    })
    t:Play()
    t.Completed:Connect(function()
        Shadow.Visible = false
        Main.Visible = false
        Main.Size = UDim2.fromOffset(780, 500)
        if cb then cb() end
    end)
end

-- ─────────────────────────────────────────────────────────────────────
-- HELPERS (Clear / UpdateCanvas)
-- ─────────────────────────────────────────────────────────────────────
local function Clear()
    for _, v in ipairs(Scroll:GetChildren()) do
        if not v:IsA("UIListLayout") then v:Destroy() end
    end
end

local function UpdateCanvas() end -- auto handled via AutomaticCanvasSize

-- ─────────────────────────────────────────────────────────────────────
-- WIDGETS
-- ─────────────────────────────────────────────────────────────────────

-- == SEPARADOR ==
local function Sep(text)
    local f = Instance.new("Frame", Scroll)
    f.Size = UDim2.new(1, 0, 0, 28)
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0

    local line = Instance.new("Frame", f)
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 0.5, 0)
    line.BackgroundColor3 = Colors.Divider
    line.BorderSizePixel = 0

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(0, 200, 1, 0)
    lbl.Position = UDim2.new(0.5, -100, 0, 0)
    lbl.BackgroundColor3 = Colors.Bg
    lbl.BorderSizePixel = 0
    lbl.Text = text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextColor3 = Colors.AccentLight
    return f
end

-- == INFO ==
local function Info(text)
    local l = Instance.new("TextLabel", Scroll)
    l.Size = UDim2.new(1, 0, 0, 16)
    l.BackgroundTransparency = 1
    l.Text = text
    l.Font = Enum.Font.Gotham
    l.TextSize = 9
    l.TextColor3 = Colors.TextMuted
    l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end

-- == TOGGLE ==
local function Toggle(name, defaultState, callback)
    local f = Instance.new("Frame", Scroll)
    f.Size = UDim2.new(1, 0, 0, 42)
    f.BackgroundColor3 = Colors.Card
    f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", f)
    stroke.Color = Colors.Border
    stroke.Transparency = 0.5

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.fromOffset(14, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextColor3 = Colors.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local box = Instance.new("Frame", f)
    box.Size = UDim2.fromOffset(34, 18)
    box.Position = UDim2.new(1, -48, 0.5, -9)
    box.BackgroundColor3 = defaultState and Colors.Accent or Colors.CardHover
    box.BorderSizePixel = 0
    Instance.new("UICorner", box).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", box)
    knob.Size = UDim2.fromOffset(14, 14)
    knob.Position = UDim2.new(0, defaultState and 18 or 2, 0.5, -7)
    knob.BackgroundColor3 = Colors.Text
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local click = Instance.new("TextButton", f)
    click.Size = UDim2.new(1, 0, 1, 0)
    click.BackgroundTransparency = 1
    click.Text = ""

    local state = defaultState

    local function updateVisual(v)
        TweenService:Create(box, TweenInfo.new(0.15), {
            BackgroundColor3 = v and Colors.Accent or Colors.CardHover
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, v and 18 or 2, 0.5, -7)
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Color = v and Colors.Accent or Colors.Border,
            Transparency = v and 0.2 or 0.5,
        }):Play()
    end

    click.MouseButton1Click:Connect(function()
        state = not state
        updateVisual(state)
        if callback then callback(state) end
    end)

    -- External setter (para keybinds)
    f.SetState = function(v, silent)
        state = v
        updateVisual(v)
        if not silent and callback then callback(v) end
    end

    f.Name = name
    return f
end

-- == SLIDER ==
local function Slider(name, min, max, default, callback)
    local f = Instance.new("Frame", Scroll)
    f.Size = UDim2.new(1, 0, 0, 55)
    f.BackgroundColor3 = Colors.Card
    f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", f).Color = Colors.Border

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1, -20, 0, 18)
    lbl.Position = UDim2.fromOffset(14, 8)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextColor3 = Colors.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel", f)
    valLbl.Size = UDim2.new(0, 60, 0, 18)
    valLbl.Position = UDim2.new(1, -74, 0, 8)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default)
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 10
    valLbl.TextColor3 = Colors.Accent
    valLbl.TextXAlignment = Enum.TextXAlignment.Right

    local bar = Instance.new("Frame", f)
    bar.Size = UDim2.new(1, -28, 0, 6)
    bar.Position = UDim2.fromOffset(14, 35)
    bar.BackgroundColor3 = Colors.CardHover
    bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local range = math.max(1e-6, max - min)
    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.fromScale((default - min) / range, 1)
    fill.BackgroundColor3 = Colors.Accent
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", bar)
    knob.Size = UDim2.fromOffset(14, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.fromScale(fill.Size.X.Scale, 0.5)
    knob.BackgroundColor3 = Colors.Text
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    Instance.new("UIStroke", knob).Color = Colors.Accent

    local dragging = false
    local function update(x)
        local s = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.fromScale(s, 1)
        knob.Position = UDim2.fromScale(s, 0.5)
        local v = math.floor(min + range * s + 0.5)
        valLbl.Text = tostring(v)
        if callback then callback(v) end
    end

    Z.Track(bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(i.Position.X)
        end
    end))
    Z.Track(knob.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end))
    Z.Track(UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    Z.Track(UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end))

    return f
end

-- == BUTTON ==
local function Button(name, color, callback)
    color = color or Colors.Accent
    local b = Instance.new("TextButton", Scroll)
    b.Size = UDim2.new(1, 0, 0, 38)
    b.BackgroundColor3 = color
    b.Text = name
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.TextColor3 = Colors.Text
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

    Z.Track(b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {
            BackgroundColor3 = color:Lerp(Color3.new(1,1,1), 0.2)
        }):Play()
    end))
    Z.Track(b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), { BackgroundColor3 = color }):Play()
    end))

    b.MouseButton1Click:Connect(function()
        if callback then
            local ok, err = pcall(callback)
            if not ok then warn("[ZuniHub Button] " .. tostring(err)) end
        end
    end)
    return b
end

-- == DROPDOWN ==
local function Dropdown(name, options, default, callback)
    local f = Instance.new("Frame", Scroll)
    f.Size = UDim2.new(1, 0, 0, 40)
    f.BackgroundColor3 = Colors.Card
    f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", f).Color = Colors.Border

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1, -110, 1, 0)
    lbl.Position = UDim2.fromOffset(14, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextColor3 = Colors.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local sel = Instance.new("TextLabel", f)
    sel.Size = UDim2.new(0, 90, 1, 0)
    sel.Position = UDim2.new(1, -104, 0, 0)
    sel.BackgroundTransparency = 1
    sel.Text = tostring(default or (options[1] or "?"))
    sel.Font = Enum.Font.GothamBold
    sel.TextSize = 10
    sel.TextColor3 = Colors.Accent
    sel.TextXAlignment = Enum.TextXAlignment.Right

    local click = Instance.new("TextButton", f)
    click.Size = UDim2.new(1, 0, 1, 0)
    click.BackgroundTransparency = 1
    click.Text = ""

    local currentIndex = 1
    for i, opt in ipairs(options) do
        if opt == default then currentIndex = i; break end
    end

    click.MouseButton1Click:Connect(function()
        currentIndex = currentIndex + 1
        if currentIndex > #options then currentIndex = 1 end
        local val = options[currentIndex]
        sel.Text = tostring(val)
        if callback then callback(val) end
    end)

    return f
end

-- ═══════════════════════════════════════════════════════════════════════
-- API PÚBLICA
-- ═══════════════════════════════════════════════════════════════════════
Z.Sep      = Sep
Z.Info     = Info
Z.Toggle   = Toggle
Z.Slider   = Slider
Z.Button   = Button
Z.Dropdown = Dropdown

Z.GUI = {
    Hub = Hub,
    Main = Main,
    Sidebar = Sidebar,
    Scroll = Scroll,
    Content = Content,
    TabTitle = TabTitle,
    Clear = Clear,
    UpdateCanvas = UpdateCanvas,
}

-- ═══════════════════════════════════════════════════════════════════════
-- TAB SYSTEM
-- ═══════════════════════════════════════════════════════════════════════
local activeTab = nil

local function AddTab(name, icon, callback)
    local btn = Instance.new("TextButton", TabsScroll)
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = Colors.Card
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = "  " .. icon .. "  " .. name
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Colors.TextDim
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.ZIndex = 6
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local indicator = Instance.new("Frame", btn)
    indicator.Name = "Indicator"
    indicator.Size = UDim2.fromOffset(3, 20)
    indicator.Position = UDim2.fromOffset(3, 10)
    indicator.BackgroundColor3 = Colors.Accent
    indicator.BackgroundTransparency = 1
    indicator.BorderSizePixel = 0
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)

    btn.MouseEnter:Connect(function()
        if activeTab ~= btn then
            TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Colors.CardHover }):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab ~= btn then
            TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Colors.Card }):Play()
        end
    end)

    btn.MouseButton1Click:Connect(function()
        if activeTab == btn then return end
        if activeTab then
            local oldInd = activeTab:FindFirstChild("Indicator")
            if oldInd then TweenService:Create(oldInd, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play() end
            TweenService:Create(activeTab, TweenInfo.new(0.2), {
                BackgroundColor3 = Colors.Card,
                TextColor3 = Colors.TextDim,
            }):Play()
        end
        activeTab = btn
        TweenService:Create(indicator, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = Colors.AccentDark,
            TextColor3 = Colors.Text,
        }):Play()
        if callback then
            local ok, err = pcall(callback)
            if not ok then warn("[ZuniHub Tab] " .. tostring(err)) end
        end
    end)

    return btn
end

Z.AddTab = AddTab

-- ═══════════════════════════════════════════════════════════════════════
-- MINIMIZE / BUBBLE
-- ═══════════════════════════════════════════════════════════════════════
local isMini = false
local Bubble = nil

local function MakeBubble()
    Bubble = Instance.new("TextButton", Hub)
    Bubble.AnchorPoint = Vector2.new(0.5, 0.5)
    Bubble.Position = UDim2.new(0.85, 0, 0.85, 0)
    Bubble.Size = UDim2.fromOffset(0, 0)
    Bubble.Text = "Z"
    Bubble.Font = Enum.Font.GothamBlack
    Bubble.TextSize = 22
    Bubble.TextColor3 = Colors.Text
    Bubble.BackgroundColor3 = Colors.Accent
    Bubble.AutoButtonColor = false
    Bubble.BorderSizePixel = 0
    Bubble.ZIndex = 100
    Instance.new("UICorner", Bubble).CornerRadius = UDim.new(1, 0)
    local s = Instance.new("UIStroke", Bubble)
    s.Color = Colors.AccentLight
    s.Thickness = 2

    TweenService:Create(Bubble, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(58, 58)
    }):Play()

    Bubble.MouseButton1Click:Connect(function()
        TweenService:Create(Bubble, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.fromOffset(0, 0)
        }):Play()
        task.delay(0.2, function()
            if Bubble then
                Bubble:Destroy(); Bubble = nil
                isMini = false
                ShowHub()
            end
        end)
    end)
end

Z.Track(MinBtn.MouseButton1Click:Connect(function()
    if isMini then return end
    isMini = true
    HideHub(function() MakeBubble() end)
end))

-- ═══════════════════════════════════════════════════════════════════════
-- CLOSE POPUP
-- ═══════════════════════════════════════════════════════════════════════
Z.Track(CloseBtn.MouseButton1Click:Connect(function()
    local overlay = Instance.new("Frame", Hub)
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Colors.Shadow
    overlay.BackgroundTransparency = 1
    overlay.ZIndex = 50
    TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.6 }):Play()

    local popup = Instance.new("Frame", overlay)
    popup.Size = UDim2.fromOffset(0, 0)
    popup.Position = UDim2.fromScale(0.5, 0.5)
    popup.AnchorPoint = Vector2.new(0.5, 0.5)
    popup.BackgroundColor3 = Colors.BgSoft
    popup.BorderSizePixel = 0
    popup.ZIndex = 51
    Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 14)
    local ps = Instance.new("UIStroke", popup)
    ps.Color = Colors.Accent

    TweenService:Create(popup, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(340, 190)
    }):Play()

    local ic = Instance.new("TextLabel", popup)
    ic.Size = UDim2.fromOffset(50, 50)
    ic.Position = UDim2.fromOffset(145, 15)
    ic.BackgroundTransparency = 1
    ic.Text = "⚠️"
    ic.Font = Enum.Font.GothamBold
    ic.TextSize = 34
    ic.ZIndex = 52

    local msg = Instance.new("TextLabel", popup)
    msg.Size = UDim2.new(1, -30, 0, 50)
    msg.Position = UDim2.fromOffset(15, 70)
    msg.BackgroundTransparency = 1
    msg.Text = "Tem certeza que deseja fechar o Zuni Hub?\nVocê terá que executar o script novamente."
    msg.Font = Enum.Font.Gotham
    msg.TextSize = 11
    msg.TextColor3 = Colors.TextDim
    msg.TextWrapped = true
    msg.ZIndex = 52

    local yes = Instance.new("TextButton", popup)
    yes.Size = UDim2.fromOffset(130, 36)
    yes.Position = UDim2.fromOffset(35, 130)
    yes.Text = "Sim, fechar"
    yes.Font = Enum.Font.GothamBold
    yes.TextSize = 11
    yes.TextColor3 = Colors.Text
    yes.BackgroundColor3 = Colors.Danger
    yes.BorderSizePixel = 0
    yes.AutoButtonColor = false
    yes.ZIndex = 52
    Instance.new("UICorner", yes).CornerRadius = UDim.new(0, 8)

    local no = Instance.new("TextButton", popup)
    no.Size = UDim2.fromOffset(130, 36)
    no.Position = UDim2.fromOffset(175, 130)
    no.Text = "Cancelar"
    no.Font = Enum.Font.GothamBold
    no.TextSize = 11
    no.TextColor3 = Colors.Text
    no.BackgroundColor3 = Colors.Card
    no.BorderSizePixel = 0
    no.AutoButtonColor = false
    no.ZIndex = 52
    Instance.new("UICorner", no).CornerRadius = UDim.new(0, 8)

    no.MouseEnter:Connect(function()
        TweenService:Create(no, TweenInfo.new(0.15), { BackgroundColor3 = Colors.Accent }):Play()
    end)
    no.MouseLeave:Connect(function()
        TweenService:Create(no, TweenInfo.new(0.15), { BackgroundColor3 = Colors.Card }):Play()
    end)

    local function closePopup()
        TweenService:Create(overlay, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
        local t = TweenService:Create(popup, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.fromOffset(0, 0)
        })
        t:Play()
        t.Completed:Connect(function() overlay:Destroy() end)
    end

    yes.MouseButton1Click:Connect(function()
        Z.Alive = false
        SaveConfig()
        overlay:Destroy()
        Hub:Destroy()
        NotifyGui:Destroy()
        print("[Zuni Hub] Fechado.")
    end)
    no.MouseButton1Click:Connect(closePopup)
end))

-- ═══════════════════════════════════════════════════════════════════════
-- INSERT TOGGLE
-- ═══════════════════════════════════════════════════════════════════════
Z.Track(UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        if isMini and Bubble then
            TweenService:Create(Bubble, TweenInfo.new(0.2), { Size = UDim2.fromOffset(0, 0) }):Play()
            task.delay(0.2, function()
                if Bubble then Bubble:Destroy(); Bubble = nil; isMini = false; ShowHub() end
            end)
        elseif not Main.Visible then
            ShowHub()
        elseif Main.Visible then
            isMini = true
            HideHub(function() MakeBubble() end)
        end
    end
end))

-- ═══════════════════════════════════════════════════════════════════════
-- HOME TAB DEFAULT
-- ═══════════════════════════════════════════════════════════════════════
local function LoadHome()
    Clear()
    TabTitle.Text = "🏠 Home"

    local card = Instance.new("Frame", Scroll)
    card.Size = UDim2.new(1, 0, 0, 180)
    card.BackgroundColor3 = Colors.Card
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
    local s = Instance.new("UIStroke", card)
    s.Color = Colors.Accent
    s.Transparency = 0.7

    local heroIcon = Instance.new("TextLabel", card)
    heroIcon.Size = UDim2.fromOffset(60, 60)
    heroIcon.Position = UDim2.fromOffset(20, 20)
    heroIcon.BackgroundColor3 = Colors.AccentDark
    heroIcon.Text = "⚡"
    heroIcon.Font = Enum.Font.GothamBold
    heroIcon.TextSize = 30
    heroIcon.TextColor3 = Colors.AccentLight
    Instance.new("UICorner", heroIcon).CornerRadius = UDim.new(0, 14)

    local title = Instance.new("TextLabel", card)
    title.Size = UDim2.new(1, -100, 0, 26)
    title.Position = UDim2.fromOffset(95, 22)
    title.BackgroundTransparency = 1
    title.Text = "Bem-vindo ao Zuni Hub"
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 18
    title.TextColor3 = Colors.Text
    title.TextXAlignment = Enum.TextXAlignment.Left

    local subtitle = Instance.new("TextLabel", card)
    subtitle.Size = UDim2.new(1, -100, 0, 16)
    subtitle.Position = UDim2.fromOffset(95, 50)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Premium multi-game hub • v2.0"
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 10
    subtitle.TextColor3 = Colors.TextDim
    subtitle.TextXAlignment = Enum.TextXAlignment.Left

    local divider = Instance.new("Frame", card)
    divider.Size = UDim2.new(1, -40, 0, 1)
    divider.Position = UDim2.fromOffset(20, 95)
    divider.BackgroundColor3 = Colors.Divider
    divider.BorderSizePixel = 0

    local desc = Instance.new("TextLabel", card)
    desc.Size = UDim2.new(1, -40, 0, 60)
    desc.Position = UDim2.fromOffset(20, 105)
    desc.BackgroundTransparency = 1
    desc.Text = "🔹 Interface fluida com animações\n🔹 Sistema de notificações toast\n🔹 Auto-configuração por jogo\n🔹 Keybinds customizáveis"
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 10
    desc.TextColor3 = Colors.TextDim
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextWrapped = true

    local statusCard = Instance.new("Frame", Scroll)
    statusCard.Size = UDim2.new(1, 0, 0, 50)
    statusCard.BackgroundColor3 = Colors.Card
    statusCard.BorderSizePixel = 0
    Instance.new("UICorner", statusCard).CornerRadius = UDim.new(0, 10)

    local dot = Instance.new("Frame", statusCard)
    dot.Size = UDim2.fromOffset(10, 10)
    dot.Position = UDim2.fromOffset(16, 20)
    dot.BackgroundColor3 = Colors.Success
    dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    task.spawn(function()
        while dot and dot.Parent and Z.Alive do
            TweenService:Create(dot, TweenInfo.new(0.8), { BackgroundTransparency = 0.5 }):Play()
            task.wait(0.8)
            if not dot.Parent then break end
            TweenService:Create(dot, TweenInfo.new(0.8), { BackgroundTransparency = 0 }):Play()
            task.wait(0.8)
        end
    end)

    local statusTxt = Instance.new("TextLabel", statusCard)
    statusTxt.Size = UDim2.new(1, -50, 1, 0)
    statusTxt.Position = UDim2.fromOffset(36, 0)
    statusTxt.BackgroundTransparency = 1
    statusTxt.Text = "Conectado • " .. Player.Name .. " (" .. Player.UserId .. ")"
    statusTxt.Font = Enum.Font.Gotham
    statusTxt.TextSize = 10
    statusTxt.TextColor3 = Colors.TextDim
    statusTxt.TextXAlignment = Enum.TextXAlignment.Left
end

-- ═══════════════════════════════════════════════════════════════════════
-- PLAYER TAB
-- ═══════════════════════════════════════════════════════════════════════
local function GetHum()
    local c = Player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

Z.SavedStates.walkSpeed = Z.SavedStates.walkSpeed or 16
Z.SavedStates.jumpPower = Z.SavedStates.jumpPower or 50

local function LoadPlayer()
    Clear()
    TabTitle.Text = "👤 Player"

    Sep("🏃 MOVIMENTO")
    Slider("Walk Speed", 1, 200, Z.SavedStates.walkSpeed, function(v)
        Z.SavedStates.walkSpeed = v
        local h = GetHum(); if h then h.WalkSpeed = v end
        SaveConfig()
    end)
    Slider("Jump Power", 1, 200, Z.SavedStates.jumpPower, function(v)
        Z.SavedStates.jumpPower = v
        local h = GetHum(); if h then h.JumpPower = v end
        SaveConfig()
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- REGISTER HOME & PLAYER TABS
-- ═══════════════════════════════════════════════════════════════════════
AddTab("Home",   "🏠", LoadHome)
AddTab("Player", "👤", LoadPlayer)

LoadHome()

-- ═══════════════════════════════════════════════════════════════════════
-- SPEED/JUMP LOOPS (globais)
-- ═══════════════════════════════════════════════════════════════════════
task.spawn(function()
    while Z.Alive do
        local h = GetHum()
        if h then
            if math.abs(h.WalkSpeed - Z.SavedStates.walkSpeed) > 0.1 then
                h.WalkSpeed = Z.SavedStates.walkSpeed
            end
            if math.abs(h.JumpPower - Z.SavedStates.jumpPower) > 0.1 then
                h.JumpPower = Z.SavedStates.jumpPower
            end
        end
        task.wait(0.3)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- START
-- ═══════════════════════════════════════════════════════════════════════
ShowHub()
Z.Ready = true

print("╔═══════════════════════════════════════════════════════╗")
print("║  ⚡ ZUNI HUB v2.0 CARREGADO                          ║")
print("║  Pressione INSERT para abrir/fechar                   ║")
print("╚═══════════════════════════════════════════════════════╝")
