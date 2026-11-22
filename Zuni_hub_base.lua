-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ZUNI HUB - BASE v6.0                                              ║
-- ║  UI premium, legível, widgets estáveis + PlayerDropdown            ║
-- ╚══════════════════════════════════════════════════════════════════════╝

local Players            = game:GetService("Players")
local UIS                = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local RunService         = game:GetService("RunService")
local TeleportService    = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════════════════════════════
-- PALETA / FONTES
-- ═══════════════════════════════════════════════════════════════════════
local Colors = {
    Bg          = Color3.fromRGB(12, 13, 18),
    Sidebar     = Color3.fromRGB(17, 18, 26),
    Card        = Color3.fromRGB(25, 26, 37),
    CardHover   = Color3.fromRGB(35, 37, 52),
    CardSoft    = Color3.fromRGB(30, 32, 45),
    Accent      = Color3.fromRGB(99, 142, 255),
    AccentLight = Color3.fromRGB(160, 190, 255),
    AccentDark  = Color3.fromRGB(55, 88, 180),
    Purple      = Color3.fromRGB(170, 120, 255),
    Success     = Color3.fromRGB(70, 210, 125),
    Warning     = Color3.fromRGB(255, 195, 70),
    Danger      = Color3.fromRGB(240, 75, 90),
    Text        = Color3.fromRGB(245, 246, 255),
    TextDim     = Color3.fromRGB(180, 184, 205),
    TextMuted   = Color3.fromRGB(120, 124, 148),
    Border      = Color3.fromRGB(52, 54, 76),
    BorderSoft  = Color3.fromRGB(40, 42, 58),
    Divider     = Color3.fromRGB(38, 40, 56),
}

local F_REG, F_MED, F_BOLD, F_BLACK =
    Enum.Font.Gotham, Enum.Font.GothamMedium, Enum.Font.GothamBold, Enum.Font.GothamBlack

-- ═══════════════════════════════════════════════════════════════════════
-- LIMPEZA + ONDE CRIAR A GUI
-- ═══════════════════════════════════════════════════════════════════════
local function SafeParent()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and typeof(h) == "Instance" then return h end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then
        local t = Instance.new("Folder")
        local ok3 = pcall(function() t.Parent = cg end)
        pcall(function() t:Destroy() end)
        if ok3 then return cg end
    end
    return PlayerGui
end
local GuiParent = SafeParent()

do
    if _G.ZuniHub then
        pcall(function()
            if _G.ZuniHub.Destroy then _G.ZuniHub.Destroy() else _G.ZuniHub.Alive = false end
        end)
        _G.ZuniHub = nil
    end
    local roots = { PlayerGui, GuiParent }
    pcall(function() table.insert(roots, game:GetService("CoreGui")) end)
    for _, root in ipairs(roots) do
        pcall(function()
            for _, n in ipairs({ "ZuniHub", "ZuniNotify" }) do
                local g = root:FindFirstChild(n)
                if g then g:Destroy() end
            end
        end)
    end
end

local Z = {
    Version = "6.0", Alive = true, Ready = false,
    Colors = Colors, SavedStates = {}, UI = {}, Connections = {},
    Tabs = {}, TabOrder = {}, CurrentTab = nil,
    ModuleName = "Nenhum", PageGen = 0, IsVisible = false,
    FPS = 60, StartTime = tick(),
}
_G.ZuniHub = Z
local S = Z.SavedStates

function Z.Track(conn)
    if conn then table.insert(Z.Connections, conn) end
    return conn
end
function Z.DisconnectAll()
    for _, c in ipairs(Z.Connections) do pcall(function() c:Disconnect() end) end
    table.clear(Z.Connections)
end

-- ═══════════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════════
local function New(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function Corner(o, r) return New("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function Stroke(o, color, thick, transp)
    return New("UIStroke", {
        Color = color, Thickness = thick or 1, Transparency = transp or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, o)
end
local function Tween(o, t, props, style, dir)
    local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end
local function Label(parent, text, size, color, font, pos, sz, align)
    return New("TextLabel", {
        BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color,
        Font = font or F_REG, Position = pos or UDim2.new(), Size = sz or UDim2.fromScale(1, 1),
        TextXAlignment = align or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
end
local function Safe(cb, ...)
    if not cb then return end
    local ok, err = pcall(cb, ...)
    if not ok then warn("[Zuni] " .. tostring(err)) end
end
local function IsPointer(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end
local function Luma(c) return c.R * 0.299 + c.G * 0.587 + c.B * 0.114 end

Z.Util = { New = New, Corner = Corner, Stroke = Stroke, Tween = Tween, Label = Label }

-- ═══════════════════════════════════════════════════════════════════════
-- SCREEN GUIS
-- ═══════════════════════════════════════════════════════════════════════
local Hub = New("ScreenGui", {
    Name = "ZuniHub", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
}, GuiParent)
local NotifyGui = New("ScreenGui", {
    Name = "ZuniNotify", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000,
}, GuiParent)

-- ═══════════════════════════════════════════════════════════════════════
-- NOTIFICAÇÕES
-- ═══════════════════════════════════════════════════════════════════════
local NotifyHolder = New("Frame", {
    BackgroundTransparency = 1, Size = UDim2.new(0, 340, 1, -24), Position = UDim2.new(1, -356, 0, 18),
}, NotifyGui)
New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, NotifyHolder)
local notifyN = 0

function Z.Notify(title, text, color, duration)
    if not Z.Alive or not NotifyHolder.Parent then return end
    color, duration = color or Colors.Accent, duration or 4
    notifyN += 1
    local toast = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Colors.Card, BorderSizePixel = 0,
        ClipsDescendants = true, LayoutOrder = notifyN,
    }, NotifyHolder)
    Corner(toast, 12)
    Stroke(toast, color, 1, 0.45)
    Corner(New("Frame", {
        Size = UDim2.new(0, 4, 1, -24), Position = UDim2.fromOffset(10, 12),
        BackgroundColor3 = color, BorderSizePixel = 0,
    }, toast), 2)
    Label(toast, title, 14, Colors.Text, F_BOLD, UDim2.fromOffset(24, 10), UDim2.new(1, -36, 0, 20))
    New("TextLabel", {
        BackgroundTransparency = 1, Text = text or "", Font = F_REG, TextSize = 12, TextColor3 = Colors.TextDim,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.fromOffset(24, 32), Size = UDim2.new(1, -36, 0, 30),
    }, toast)
    local bar = New("Frame", {
        Size = UDim2.new(1, -28, 0, 3), Position = UDim2.new(0, 14, 1, -9),
        BackgroundColor3 = color, BorderSizePixel = 0,
    }, toast)
    Corner(bar, 2)

    Tween(toast, 0.3, { Size = UDim2.new(1, 0, 0, 76) }, Enum.EasingStyle.Back)
    Tween(bar, duration, { Size = UDim2.new(0, 0, 0, 3) }, Enum.EasingStyle.Linear)
    task.delay(duration, function()
        if not toast.Parent then return end
        local tw = Tween(toast, 0.25, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        tw.Completed:Connect(function() pcall(function() toast:Destroy() end) end)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- JANELA PRINCIPAL
-- ═══════════════════════════════════════════════════════════════════════
local WIN_W, WIN_H = 760, 540

local Main = New("Frame", {
    Name = "Main", Size = UDim2.fromOffset(WIN_W, WIN_H), Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Colors.Bg, BorderSizePixel = 0,
    Visible = false, Active = true,
}, Hub)
Corner(Main, 18)
Stroke(Main, Colors.Border, 1.5, 0.25)
local WinScale = New("UIScale", { Scale = 1 }, Main)

local function Viewport()
    local cam = workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1280, 720)
end
local function TargetScale()
    local vp = Viewport()
    return math.clamp(math.min((vp.X - 24) / WIN_W, (vp.Y - 24) / WIN_H), 0.5, 1)
end

-- Sidebar ---------------------------------------------------------------
local Sidebar = New("Frame", {
    Size = UDim2.new(0, 200, 1, 0), BackgroundColor3 = Colors.Sidebar, BorderSizePixel = 0,
}, Main)
Corner(Sidebar, 18)
New("Frame", {
    Size = UDim2.new(0, 22, 1, 0), Position = UDim2.new(1, -22, 0, 0),
    BackgroundColor3 = Colors.Sidebar, BorderSizePixel = 0,
}, Sidebar)

local LogoCard = New("Frame", {
    Size = UDim2.new(1, -28, 0, 62), Position = UDim2.fromOffset(14, 16),
    BackgroundColor3 = Colors.Card, BorderSizePixel = 0, Active = true,
}, Sidebar)
Corner(LogoCard, 14)
Stroke(LogoCard, Colors.Accent, 1, 0.6)
Label(LogoCard, "⚡ ZUNI", 22, Colors.Text, F_BLACK, UDim2.fromOffset(16, 8), UDim2.new(1, -24, 0, 28))
Label(LogoCard, "HUB  v" .. Z.Version, 11, Colors.AccentLight, F_MED, UDim2.fromOffset(17, 36), UDim2.new(1, -24, 0, 16))

local TabsScroll = New("ScrollingFrame", {
    Size = UDim2.new(1, -20, 1, -170), Position = UDim2.fromOffset(10, 94),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
    ScrollBarImageColor3 = Colors.Accent, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, Sidebar)
New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, TabsScroll)

New("TextLabel", {
    BackgroundTransparency = 1, Text = "INSERT ou R-CTRL\nmostra / esconde o hub",
    Font = F_REG, TextSize = 11, TextColor3 = Colors.TextMuted, TextWrapped = true,
    Position = UDim2.new(0, 14, 1, -56), Size = UDim2.new(1, -28, 0, 42),
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, Sidebar)

-- Conteúdo --------------------------------------------------------------
local Content = New("Frame", {
    Size = UDim2.new(1, -200, 1, 0), Position = UDim2.fromOffset(200, 0), BackgroundTransparency = 1,
}, Main)

local Header = New("Frame", {
    Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, Active = true,
}, Content)
local TabTitle = Label(Header, "Home", 22, Colors.Text, F_BOLD, UDim2.fromOffset(24, 0), UDim2.new(1, -130, 1, 0))
local hLine = New("Frame", {
    Size = UDim2.new(1, -40, 0, 2), Position = UDim2.fromOffset(20, 64), BackgroundColor3 = Colors.Accent, BorderSizePixel = 0,
}, Content)
Corner(hLine, 1)
New("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Colors.Accent), ColorSequenceKeypoint.new(0.5, Colors.Purple), ColorSequenceKeypoint.new(1, Colors.Accent),
    }),
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.9),
    }),
}, hLine)

local Scroll = New("ScrollingFrame", {
    Size = UDim2.new(1, -40, 1, -92), Position = UDim2.fromOffset(20, 78),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
    ScrollBarImageColor3 = Colors.Accent, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, Content)
New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, Scroll)
New("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 14) }, Scroll)

-- ═══════════════════════════════════════════════════════════════════════
-- PÁGINAS
-- ═══════════════════════════════════════════════════════════════════════
local PageConns = {}
local order = 0
local function NextOrder() order += 1 return order end

Z.GUI = { Hub = Hub, Main = Main, Sidebar = Sidebar, Scroll = Scroll, Content = Content, TabTitle = TabTitle }

function Z.GUI.Clear()
    Z.PageGen += 1
    for _, c in ipairs(PageConns) do pcall(function() c:Disconnect() end) end
    table.clear(PageConns)
    for k in pairs(Z.UI) do Z.UI[k] = nil end
    for _, v in ipairs(Scroll:GetChildren()) do
        if not (v:IsA("UIListLayout") or v:IsA("UIPadding")) then v:Destroy() end
    end
    Scroll.CanvasPosition = Vector2.zero
    Scroll.ScrollingEnabled = true
    order = 0
end
function Z.PageTrack(conn) table.insert(PageConns, conn) return conn end
function Z.PageLoop(interval, fn)
    local gen = Z.PageGen
    task.spawn(function()
        while Z.Alive and Z.PageGen == gen do
            local ok, err = pcall(fn)
            if not ok then warn("[Zuni] PageLoop: " .. tostring(err)) end
            task.wait(interval)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- WIDGETS
-- ═══════════════════════════════════════════════════════════════════════
local function Card(height)
    local f = New("Frame", {
        Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = Colors.Card, BorderSizePixel = 0, LayoutOrder = NextOrder(),
    }, Scroll)
    Corner(f, 12)
    local st = Stroke(f, Colors.BorderSoft, 1, 0.35)
    return f, st
end
Z.Card = Card

function Z.Sep(text)
    local f = New("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = NextOrder() }, Scroll)
    Corner(New("Frame", {
        Size = UDim2.fromOffset(3, 18), Position = UDim2.fromOffset(2, 13),
        BackgroundColor3 = Colors.Accent, BorderSizePixel = 0,
    }, f), 2)
    Label(f, text, 13, Colors.AccentLight, F_BOLD, UDim2.fromOffset(16, 10), UDim2.new(1, -16, 0, 24))
    return f
end

function Z.Info(text)
    local l = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        Text = text, Font = F_REG, TextSize = 13, TextColor3 = Colors.TextDim, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = NextOrder(),
        LineHeight = 1.25,
    }, Scroll)
    New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 4) }, l)
    return l
end

function Z.Stat(name, value)
    local card = Card(46)
    Label(card, name, 13, Colors.TextDim, F_MED, UDim2.fromOffset(18, 0), UDim2.new(0.5, -18, 1, 0))
    local v = Label(card, tostring(value), 14, Colors.Text, F_BOLD, UDim2.fromScale(0.5, 0), UDim2.new(0.5, -18, 1, 0), Enum.TextXAlignment.Right)
    return {
        Frame = card,
        Set = function(text, color)
            if not v.Parent then return end
            v.Text = tostring(text)
            if color then v.TextColor3 = color end
        end,
    }
end

function Z.Toggle(name, default, callback, desc)
    local card, st = Card(desc and 66 or 54)
    local state = not not default
    Label(card, name, 14, Colors.Text, F_BOLD, UDim2.fromOffset(18, desc and 11 or 0), UDim2.new(1, -104, 0, desc and 20 or 54))
    if desc then Label(card, desc, 12, Colors.TextDim, F_REG, UDim2.fromOffset(18, 35), UDim2.new(1, -104, 0, 20)) end

    local track = New("Frame", {
        Size = UDim2.fromOffset(48, 26), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0),
        BackgroundColor3 = Colors.CardHover, BorderSizePixel = 0,
    }, card)
    Corner(track, 13)
    local knob = New("Frame", {
        Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
        BackgroundColor3 = Colors.Text, BorderSizePixel = 0,
    }, track)
    Corner(knob, 10)

    local function render(v, animate)
        if not card.Parent then return end
        local t = animate and 0.15 or 0
        Tween(track, t, { BackgroundColor3 = v and Colors.Accent or Colors.CardHover })
        Tween(knob, t, { Position = UDim2.new(0, v and 25 or 3, 0.5, 0) }, Enum.EasingStyle.Back)
        Tween(st, t, { Color = v and Colors.Accent or Colors.BorderSoft, Transparency = v and 0.3 or 0.35 })
    end
    render(state, false)

    local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, card)
    hit.MouseEnter:Connect(function() Tween(card, 0.12, { BackgroundColor3 = Colors.CardHover }) end)
    hit.MouseLeave:Connect(function() Tween(card, 0.12, { BackgroundColor3 = Colors.Card }) end)
    hit.MouseButton1Click:Connect(function()
        state = not state
        render(state, true)
        Safe(callback, state)
    end)

    local obj = { Frame = card }
    function obj.Set(v, silent)
        v = not not v
        if v == state then return end
        state = v
        render(v, true)
        if not silent then Safe(callback, v) end
    end
    function obj.Get() return state end
    obj.SetState = obj.Set
    return obj
end

function Z.Slider(name, min, max, default, callback, opts)
    opts = opts or {}
    local step, suffix = opts.step or 1, opts.suffix or ""
    local range = math.max(1e-6, max - min)
    local card = Card(74)

    local function snap(v)
        v = min + math.floor((v - min) / step + 0.5) * step
        return math.clamp(v, min, max)
    end
    local function fmt(v)
        if v == math.floor(v) then return tostring(v) end
        return string.format("%.2f", v)
    end
    local value = snap(default or min)

    Label(card, name, 14, Colors.Text, F_BOLD, UDim2.fromOffset(18, 12), UDim2.new(1, -148, 0, 20))
    local valLbl = Label(card, "", 14, Colors.Accent, F_BOLD, UDim2.new(1, -134, 0, 12), UDim2.fromOffset(116, 20), Enum.TextXAlignment.Right)

    local track = New("Frame", {
        Size = UDim2.new(1, -36, 0, 8), Position = UDim2.fromOffset(18, 50),
        BackgroundColor3 = Colors.CardHover, BorderSizePixel = 0,
    }, card)
    Corner(track, 4)
    local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Accent, BorderSizePixel = 0 }, track)
    Corner(fill, 4)
    New("UIGradient", { Color = ColorSequence.new(Colors.AccentDark, Colors.Accent) }, fill)
    local knob = New("Frame", {
        Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
        BackgroundColor3 = Colors.Text, BorderSizePixel = 0, ZIndex = 2,
    }, track)
    Corner(knob, 10)
    Stroke(knob, Colors.Accent, 2)

    local function render()
        local a = (value - min) / range
        fill.Size = UDim2.fromScale(a, 1)
        knob.Position = UDim2.fromScale(a, 0.5)
        valLbl.Text = fmt(value) .. suffix
    end
    render()

    local dragging = false
    local function fromX(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
        local v = snap(min + range * a)
        if v ~= value then
            value = v
            render()
            Safe(callback, v)
        end
    end
    local hit = New("TextButton", {
        Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 38),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
    }, card)
    hit.InputBegan:Connect(function(i)
        if IsPointer(i) then
            dragging = true
            Scroll.ScrollingEnabled = false
            fromX(i.Position.X)
        end
    end)
    Z.PageTrack(UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            fromX(i.Position.X)
        end
    end))
    Z.PageTrack(UIS.InputEnded:Connect(function(i)
        if dragging and IsPointer(i) then
            dragging = false
            Scroll.ScrollingEnabled = true
        end
    end))

    local obj = { Frame = card }
    function obj.Set(v, silent)
        v = snap(v)
        if v == value then return end
        value = v
        render()
        if not silent then Safe(callback, v) end
    end
    function obj.Get() return value end
    return obj
end

function Z.Button(name, color, callback)
    color = color or Colors.Accent
    local b = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = color, Text = name, Font = F_BOLD, TextSize = 14,
        TextColor3 = Luma(color) > 0.62 and Color3.fromRGB(15, 16, 24) or Colors.Text,
        BorderSizePixel = 0, AutoButtonColor = false, LayoutOrder = NextOrder(),
    }, Scroll)
    Corner(b, 12)
    b.MouseEnter:Connect(function() Tween(b, 0.12, { BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.15) }) end)
    b.MouseLeave:Connect(function() Tween(b, 0.12, { BackgroundColor3 = color }) end)
    b.MouseButton1Down:Connect(function() Tween(b, 0.08, { BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.2) }) end)
    b.MouseButton1Up:Connect(function() Tween(b, 0.08, { BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.15) }) end)
    b.MouseButton1Click:Connect(function() Safe(callback) end)
    return b
end

function Z.Dropdown(name, options, default, callback, desc)
    options = options or {}
    local baseH = desc and 66 or 54
    local card = Card(baseH)
    
    -- Removemos o ClipsDescendants para a lista não ser cortada
    card.ClipsDescendants = false 
    card.ZIndex = 5

    Label(card, name, 14, Colors.Text, F_BOLD, UDim2.fromOffset(18, desc and 11 or 0), UDim2.new(1, -36, 0, desc and 20 or 54))
    if desc then Label(card, desc, 12, Colors.TextDim, F_REG, UDim2.fromOffset(18, 35), UDim2.new(1, -36, 0, 20)) end

    local selY = desc and 50 or 16
    local selectBtn = New("TextButton", {
        Size = UDim2.new(1, -36, 0, 32), Position = UDim2.fromOffset(18, selY),
        BackgroundColor3 = Colors.CardHover, Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 6,
    }, card)
    Corner(selectBtn, 8)
    Stroke(selectBtn, Colors.Border, 1, 0.5)
    local valLbl = Label(selectBtn, default and tostring(default) or "Selecionar...", 13,
        default and Colors.Text or Colors.TextMuted, F_MED, UDim2.fromOffset(12, 0), UDim2.new(1, -34, 1, 0))
    valLbl.ZIndex = 7
    local arrow = Label(selectBtn, "▾", 14, Colors.TextDim, F_BOLD, UDim2.new(1, -26, 0, 0), UDim2.fromOffset(20, 32), Enum.TextXAlignment.Center)
    arrow.ZIndex = 7

    -- A lista flutua sobre os outros elementos em vez de esticar o card
    local listHolder = New("ScrollingFrame", {
        Size = UDim2.new(1, -36, 0, 0), Position = UDim2.fromOffset(18, selY + 36),
        BackgroundColor3 = Colors.Bg, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Colors.Accent, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 10,
    }, card)
    Corner(listHolder, 8)
    Stroke(listHolder, Colors.Border, 1, 0)
    New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, listHolder)

    local selected, isOpen, itemButtons = default, false, {}

    local function CloseList()
        if not isOpen then return end
        isOpen = false
        Tween(arrow, 0.15, { Rotation = 0 })
        task.delay(0.15, function() if not isOpen and listHolder.Parent then listHolder.Visible = false end end)
    end

    local function RenderItems()
        for _, b in ipairs(itemButtons) do b:Destroy() end
        table.clear(itemButtons)
        for i, opt in ipairs(options) do
            local item = New("TextButton", {
                Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Colors.Accent, BackgroundTransparency = 1,
                Text = "  " .. tostring(opt), Font = F_MED, TextSize = 13, TextColor3 = Colors.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i, ZIndex = 11,
            }, listHolder)
            item.MouseEnter:Connect(function() Tween(item, 0.1, { BackgroundTransparency = 0.45 }) end)
            item.MouseLeave:Connect(function() Tween(item, 0.1, { BackgroundTransparency = 1 }) end)
            item.MouseButton1Click:Connect(function()
                selected = opt
                valLbl.Text, valLbl.TextColor3 = tostring(opt), Colors.Text
                CloseList()
                Safe(callback, opt)
            end)
            table.insert(itemButtons, item)
        end
    end
    RenderItems()

    local function OpenList()
        if isOpen or #options == 0 then return end
        isOpen = true
        listHolder.Visible = true
        local h = math.min(160, #options * 30 + 4)
        listHolder.Size = UDim2.new(1, -36, 0, h)
        Tween(arrow, 0.15, { Rotation = 180 })
    end

    selectBtn.MouseButton1Click:Connect(function() if isOpen then CloseList() else OpenList() end end)

    local obj = { Frame = card }
    function obj.SetOptions(newOptions)
        local wasOpen = isOpen
        options = newOptions or {}
        RenderItems()
        if selected ~= nil and not table.find(options, selected) then
            selected = nil
            valLbl.Text, valLbl.TextColor3 = "Selecionar...", Colors.TextMuted
        end
        if wasOpen then isOpen = false; OpenList() end
    end
    function obj.Get() return selected end
    function obj.Set(v, silent)
        selected = v
        valLbl.Text = v and tostring(v) or "Selecionar..."
        valLbl.TextColor3 = v and Colors.Text or Colors.TextMuted
        if not silent then Safe(callback, v) end
    end
    return obj
end

function Z.PlayerDropdown(name, callback, desc)
    local baseH = desc and 66 or 54
    local card = Card(baseH)
    card.ClipsDescendants = false
    card.ZIndex = 5

    Label(card, name, 14, Colors.Text, F_BOLD, UDim2.fromOffset(18, desc and 11 or 0), UDim2.new(1, -36, 0, desc and 20 or 54))
    if desc then Label(card, desc, 12, Colors.TextDim, F_REG, UDim2.fromOffset(18, 35), UDim2.new(1, -36, 0, 20)) end

    local selY = desc and 50 or 16
    local selectBtn = New("TextButton", {
        Size = UDim2.new(1, -36, 0, 32), Position = UDim2.fromOffset(18, selY),
        BackgroundColor3 = Colors.CardHover, Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 6,
    }, card)
    Corner(selectBtn, 8)
    Stroke(selectBtn, Colors.Border, 1, 0.5)
    local valLbl = Label(selectBtn, "Selecionar jogador...", 13, Colors.TextMuted, F_MED, UDim2.fromOffset(12, 0), UDim2.new(1, -34, 1, 0))
    valLbl.ZIndex = 7
    local arrow = Label(selectBtn, "▾", 14, Colors.TextDim, F_BOLD, UDim2.new(1, -26, 0, 0), UDim2.fromOffset(20, 32), Enum.TextXAlignment.Center)
    arrow.ZIndex = 7

    local listHolder = New("ScrollingFrame", {
        Size = UDim2.new(1, -36, 0, 0), Position = UDim2.fromOffset(18, selY + 36),
        BackgroundColor3 = Colors.Bg, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Colors.Accent, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 10,
    }, card)
    Corner(listHolder, 8)
    Stroke(listHolder, Colors.Border, 1, 0)
    New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, listHolder)

    local selected, isOpen, itemButtons = nil, false, {}

    local function CloseList()
        if not isOpen then return end
        isOpen = false
        Tween(arrow, 0.15, { Rotation = 0 })
        task.delay(0.15, function() if not isOpen and listHolder.Parent then listHolder.Visible = false end end)
    end

    local function RenderItems()
        for _, b in ipairs(itemButtons) do b:Destroy() end
        table.clear(itemButtons)
        local players = Players:GetPlayers()
        for i, p in ipairs(players) do
            if p ~= Player then
                local item = New("TextButton", {
                    Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Colors.Accent, BackgroundTransparency = 1,
                    Text = "  " .. p.Name, Font = F_MED, TextSize = 13, TextColor3 = Colors.TextDim,
                    TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i, ZIndex = 11,
                }, listHolder)
                item.MouseEnter:Connect(function() Tween(item, 0.1, { BackgroundTransparency = 0.45 }) end)
                item.MouseLeave:Connect(function() Tween(item, 0.1, { BackgroundTransparency = 1 }) end)
                item.MouseButton1Click:Connect(function()
                    selected = p
                    valLbl.Text, valLbl.TextColor3 = p.Name, Colors.Text
                    CloseList()
                    Safe(callback, p)
                end)
                table.insert(itemButtons, item)
            end
        end
    end

    local function OpenList()
        if isOpen then return end
        RenderItems()
        if #itemButtons == 0 then
            Z.Notify("Players", "Nenhum outro jogador no servidor.", Colors.Warning, 2)
            return
        end
        isOpen = true
        listHolder.Visible = true
        local h = math.min(160, #itemButtons * 30 + 4)
        listHolder.Size = UDim2.new(1, -36, 0, h)
        Tween(arrow, 0.15, { Rotation = 180 })
    end

    selectBtn.MouseButton1Click:Connect(function() if isOpen then CloseList() else OpenList() end end)

    Z.PageTrack(Players.PlayerAdded:Connect(function() if isOpen then RenderItems() end end))
    Z.PageTrack(Players.PlayerRemoving:Connect(function(p)
        if selected == p then
            selected = nil
            valLbl.Text, valLbl.TextColor3 = "Selecionar jogador...", Colors.TextMuted
        end
        if isOpen then RenderItems() end
    end))

    local obj = { Frame = card }
    function obj.Get() return selected end
    function obj.Set(p, silent)
        selected = p
        valLbl.Text = p and p.Name or "Selecionar jogador..."
        valLbl.TextColor3 = p and Colors.Text or Colors.TextMuted
        if not silent then Safe(callback, p) end
    end
    return obj
end

-- ═══════════════════════════════════════════════════════════════════════
-- PLAYER DROPDOWN (nativo da base — lista jogadores atualizada sozinha)
-- ═══════════════════════════════════════════════════════════════════════
function Z.PlayerDropdown(name, callback, desc)
    local baseH = desc and 66 or 54
    local card = Card(baseH)
    card.ClipsDescendants = true

    Label(card, name, 14, Colors.Text, F_BOLD, UDim2.fromOffset(18, desc and 11 or 0), UDim2.new(1, -36, 0, desc and 20 or 54))
    if desc then Label(card, desc, 12, Colors.TextDim, F_REG, UDim2.fromOffset(18, 35), UDim2.new(1, -36, 0, 20)) end

    local selY = desc and 50 or 16
    local selectBtn = New("TextButton", {
        Size = UDim2.new(1, -36, 0, 32), Position = UDim2.fromOffset(18, selY),
        BackgroundColor3 = Colors.CardHover, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
    }, card)
    Corner(selectBtn, 8)
    Stroke(selectBtn, Colors.Border, 1, 0.5)
    local valLbl = Label(selectBtn, "Selecionar jogador...", 13, Colors.TextMuted, F_MED, UDim2.fromOffset(12, 0), UDim2.new(1, -34, 1, 0))
    local arrow = Label(selectBtn, "▾", 14, Colors.TextDim, F_BOLD, UDim2.new(1, -26, 0, 0), UDim2.fromOffset(20, 32), Enum.TextXAlignment.Center)

    local listHolder = New("ScrollingFrame", {
        Size = UDim2.new(1, -36, 0, 0), Position = UDim2.fromOffset(18, selY + 40),
        BackgroundColor3 = Colors.Bg, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Colors.Accent, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
    }, card)
    Corner(listHolder, 8)
    New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, listHolder)

    local selected, isOpen, itemButtons = nil, false, {}

    local function CloseList()
        if not isOpen then return end
        isOpen = false
        Tween(card, 0.15, { Size = UDim2.new(1, 0, 0, baseH) })
        Tween(arrow, 0.15, { Rotation = 0 })
        task.delay(0.15, function() if not isOpen and listHolder.Parent then listHolder.Visible = false end end)
    end

    local function RenderItems()
        for _, b in ipairs(itemButtons) do b:Destroy() end
        table.clear(itemButtons)
        local players = Players:GetPlayers()
        for i, p in ipairs(players) do
            if p ~= Player then
                local item = New("TextButton", {
                    Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Colors.Accent, BackgroundTransparency = 1,
                    Text = "  " .. p.Name, Font = F_MED, TextSize = 13, TextColor3 = Colors.TextDim,
                    TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i,
                }, listHolder)
                item.MouseEnter:Connect(function() Tween(item, 0.1, { BackgroundTransparency = 0.45 }) end)
                item.MouseLeave:Connect(function() Tween(item, 0.1, { BackgroundTransparency = 1 }) end)
                item.MouseButton1Click:Connect(function()
                    selected = p
                    valLbl.Text, valLbl.TextColor3 = p.Name, Colors.Text
                    CloseList()
                    Safe(callback, p)
                end)
                table.insert(itemButtons, item)
            end
        end
    end

    local function OpenList()
        if isOpen then return end
        RenderItems()
        if #itemButtons == 0 then
            Z.Notify("Players", "Nenhum outro jogador no servidor.", Colors.Warning, 2)
            return
        end
        isOpen = true
        listHolder.Visible = true
        local h = math.min(160, #itemButtons * 30 + 4)
        listHolder.Size = UDim2.new(1, -36, 0, h)
        Tween(card, 0.15, { Size = UDim2.new(1, 0, 0, baseH + h + 8) })
        Tween(arrow, 0.15, { Rotation = 180 })
    end

    selectBtn.MouseButton1Click:Connect(function() if isOpen then CloseList() else OpenList() end end)

    Z.PageTrack(Players.PlayerAdded:Connect(function() if isOpen then RenderItems() end end))
    Z.PageTrack(Players.PlayerRemoving:Connect(function(p)
        if selected == p then
            selected = nil
            valLbl.Text, valLbl.TextColor3 = "Selecionar jogador...", Colors.TextMuted
        end
        if isOpen then RenderItems() end
    end))

    local obj = { Frame = card }
    function obj.Get() return selected end
    function obj.Set(p, silent)
        selected = p
        valLbl.Text = p and p.Name or "Selecionar jogador..."
        valLbl.TextColor3 = p and Colors.Text or Colors.TextMuted
        if not silent then Safe(callback, p) end
    end
    return obj
end

-- ═══════════════════════════════════════════════════════════════════════
-- ARRASTAR
-- ═══════════════════════════════════════════════════════════════════════
local function MakeDraggable(handle, target, onClick, clampFn)
    local dragging, moved, origin, startPos = false, false, nil, nil
    handle.InputBegan:Connect(function(i)
        if IsPointer(i) then
            dragging, moved = true, false
            origin, startPos = i.Position, target.Position
        end
    end)
    Z.Track(UIS.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            local d = i.Position - origin
            if not moved and d.Magnitude > 6 then moved = true end
            if moved then
                local x, y = startPos.X.Offset + d.X, startPos.Y.Offset + d.Y
                if clampFn then x, y = clampFn(x, y) end
                target.Position = UDim2.new(startPos.X.Scale, x, startPos.Y.Scale, y)
            end
        end
    end))
    Z.Track(UIS.InputEnded:Connect(function(i)
        if dragging and IsPointer(i) then
            dragging = false
            if not moved and onClick then Safe(onClick) end
        end
    end))
end

local function ClampMain(x, y)
    local vp = Viewport()
    local mx, my = vp.X / 2 - 80, vp.Y / 2 - 40
    return math.clamp(x, -mx, mx), math.clamp(y, -my, my)
end
MakeDraggable(Header, Main, nil, ClampMain)
MakeDraggable(LogoCard, Main, nil, ClampMain)

-- ═══════════════════════════════════════════════════════════════════════
-- BOLHA + MOSTRAR / ESCONDER
-- ═══════════════════════════════════════════════════════════════════════
local Bubble = New("TextButton", {
    Size = UDim2.fromOffset(58, 58), Position = UDim2.new(1, -94, 1, -136), Text = "Z",
    Font = F_BLACK, TextSize = 24, TextColor3 = Colors.Text, BackgroundColor3 = Colors.Accent,
    AutoButtonColor = false, BorderSizePixel = 0, Visible = false, ZIndex = 50,
}, Hub)
Corner(Bubble, 29)
Stroke(Bubble, Colors.AccentLight, 2, 0.2)
New("UIGradient", { Color = ColorSequence.new(Colors.Accent, Colors.Purple), Rotation = 45 }, Bubble)

local animToken = 0
function Z.SetVisible(v)
    if not Z.Alive then return end
    v = not not v
    if v == Z.IsVisible then return end
    Z.IsVisible = v
    animToken += 1
    local my = animToken
    if v then
        Bubble.Visible = false
        WinScale.Scale = 0.6
        Main.Visible = true
        Tween(WinScale, 0.3, { Scale = TargetScale() }, Enum.EasingStyle.Back)
    else
        Tween(WinScale, 0.2, { Scale = 0.01 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(0.21, function()
            if animToken == my and Z.Alive then
                Main.Visible = false
                Bubble.Visible = true
            end
        end)
    end
end
function Z.ToggleVisible() Z.SetVisible(not Z.IsVisible) end
MakeDraggable(Bubble, Bubble, function() Z.SetVisible(true) end)

-- Botões do cabeçalho
local function HeaderBtn(text, color, xOff, cb)
    local b = New("TextButton", {
        Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, xOff, 0, 15), BackgroundColor3 = color, Text = text,
        Font = F_BOLD, TextSize = 16, TextColor3 = Colors.Text, AutoButtonColor = false, BorderSizePixel = 0,
    }, Header)
    Corner(b, 9)
    b.MouseEnter:Connect(function() Tween(b, 0.12, { BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.2) }) end)
    b.MouseLeave:Connect(function() Tween(b, 0.12, { BackgroundColor3 = color }) end)
    b.MouseButton1Click:Connect(function() Safe(cb) end)
    return b
end
HeaderBtn("–", Colors.CardHover, -90, function() Z.SetVisible(false) end)
HeaderBtn("✕", Colors.Danger, -50, function() Z.Destroy() end)

-- Atalhos de teclado
Z.Track(UIS.InputBegan:Connect(function(input, gpe)
    if gpe or not Z.Alive then return end
    if input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.RightControl then
        Z.ToggleVisible()
    end
end))
Z.Track(RunService.Heartbeat:Connect(function(dt)
    if dt > 0 then Z.FPS = Z.FPS * 0.92 + (1 / dt) * 0.08 end
end))

-- ═══════════════════════════════════════════════════════════════════════
-- ABAS
-- ═══════════════════════════════════════════════════════════════════════
local function StyleTab(tab, active)
    Tween(tab.Button, 0.18, { BackgroundTransparency = active and 0 or 1, BackgroundColor3 = active and Colors.AccentDark or Colors.Card })
    Tween(tab.Bar, 0.18, { BackgroundTransparency = active and 0 or 1 })
    Tween(tab.Icon, 0.18, { TextColor3 = active and Colors.Text or Colors.TextDim })
    Tween(tab.Label, 0.18, { TextColor3 = active and Colors.Text or Colors.TextDim })
end

function Z.AddTab(name, icon, callback)
    local existing = Z.Tabs[name]
    if existing then existing.Callback = callback return existing end

    local btn = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Colors.Card, BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Text = "", LayoutOrder = #Z.TabOrder + 1,
    }, TabsScroll)
    Corner(btn, 11)
    local bar = New("Frame", {
        Size = UDim2.fromOffset(4, 22), Position = UDim2.new(0, 0, 0.5, -11), BackgroundColor3 = Colors.Accent,
        BackgroundTransparency = 1, BorderSizePixel = 0,
    }, btn)
    Corner(bar, 2)
    local ic = Label(btn, icon, 18, Colors.TextDim, F_REG, UDim2.fromOffset(16, 0), UDim2.fromOffset(30, 44), Enum.TextXAlignment.Center)
    local nm = Label(btn, name, 14, Colors.TextDim, F_BOLD, UDim2.fromOffset(54, 0), UDim2.new(1, -60, 1, 0))

    local tab = { Name = name, Icon = ic, Label = nm, Button = btn, Bar = bar, Callback = callback, IconText = icon }
    Z.Tabs[name] = tab
    table.insert(Z.TabOrder, name)

    btn.MouseEnter:Connect(function()
        if Z.CurrentTab ~= name then Tween(btn, 0.12, { BackgroundTransparency = 0.5 }) end
    end)
    btn.MouseLeave:Connect(function()
        if Z.CurrentTab ~= name then Tween(btn, 0.12, { BackgroundTransparency = 1 }) end
    end)
    btn.MouseButton1Click:Connect(function() Z.SelectTab(name) end)
    return tab
end

function Z.SelectTab(name)
    local tab = Z.Tabs[name]
    if not tab then return end
    local old = Z.Tabs[Z.CurrentTab]
    if old and old ~= tab then StyleTab(old, false) end
    Z.CurrentTab = name
    StyleTab(tab, true)
    TabTitle.Text = tab.IconText .. "  " .. name

    Z.GUI.Clear()
    if tab.Callback then
        local ok, err = xpcall(tab.Callback, function(e)
            warn("[Zuni] Erro na aba '" .. name .. "': " .. tostring(e) .. "\n" .. debug.traceback())
            return tostring(e)
        end)
        if not ok then
            Z.Info("⚠ Erro ao carregar esta aba:")
            Z.Info(tostring(err))
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════
-- ENCERRAR
-- ═══════════════════════════════════════════════════════════════════════
function Z.Destroy()
    if not Z.Alive then return end
    Z.Alive = false
    pcall(function()
        local c = Player.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if hum then
            if S.speedOn then hum.WalkSpeed = 16 end
            if S.jumpOn then hum.JumpPower = 50 end
        end
    end)
    Z.DisconnectAll()
    for _, c in ipairs(PageConns) do pcall(function() c:Disconnect() end) end
    pcall(function() Hub:Destroy() end)
    pcall(function() NotifyGui:Destroy() end)
    if _G.ZuniHub == Z then _G.ZuniHub = nil end
end

-- ═══════════════════════════════════════════════════════════════════════
-- FUNÇÕES DO PLAYER
-- ═══════════════════════════════════════════════════════════════════════
local function Def(k, v) if S[k] == nil then S[k] = v end end
Def("speedOn", false) Def("walkSpeed", 16)
Def("jumpOn", false)  Def("jumpPower", 50)
Def("infJump", false) Def("antiAfk", true)

local function GetHum()
    local c = Player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

Z.Track(RunService.Heartbeat:Connect(function()
    local hum = GetHum()
    if not hum then return end
    if S.speedOn and hum.WalkSpeed ~= S.walkSpeed then hum.WalkSpeed = S.walkSpeed end
    if S.jumpOn then
        if not hum.UseJumpPower then hum.UseJumpPower = true end
        if hum.JumpPower ~= S.jumpPower then hum.JumpPower = S.jumpPower end
    end
end))
Z.Track(UIS.JumpRequest:Connect(function()
    if not S.infJump then return end
    local hum = GetHum()
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end))
Z.Track(Player.Idled:Connect(function()
    if not S.antiAfk then return end
    pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end)
end))

-- ═══════════════════════════════════════════════════════════════════════
-- ABA HOME
-- ═══════════════════════════════════════════════════════════════════════
local function FmtTime(sec)
    sec = math.floor(sec)
    return string.format("%02d:%02d:%02d", sec // 3600, (sec % 3600) // 60, sec % 60)
end

local function LoadHome()
    local hero = Card(102)
    local stripe = New("Frame", {
        Size = UDim2.new(0, 4, 1, -28), Position = UDim2.fromOffset(12, 14), BackgroundColor3 = Colors.Accent, BorderSizePixel = 0,
    }, hero)
    Corner(stripe, 2)
    New("UIGradient", { Color = ColorSequence.new(Colors.Accent, Colors.Purple), Rotation = 90 }, stripe)
    Label(hero, "Bem-vindo, " .. Player.DisplayName, 20, Colors.Text, F_BOLD, UDim2.fromOffset(28, 14), UDim2.new(1, -44, 0, 28))
    New("TextLabel", {
        BackgroundTransparency = 1, Font = F_REG, TextSize = 13, TextColor3 = Colors.TextDim, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.25,
        Text = "Escolha uma aba ao lado para começar. Minimize com – para virar uma bolha arrastável.",
        Position = UDim2.fromOffset(28, 46), Size = UDim2.new(1, -44, 0, 44),
    }, hero)

    Z.Sep("📊  INFORMAÇÕES")
    Z.Stat("Jogador", Player.Name)
    local stGame = Z.Stat("Jogo", tostring(game.PlaceId))
    Z.Stat("Módulo carregado", Z.ModuleName)
    local stFps  = Z.Stat("FPS", "—")
    local stPing = Z.Stat("Ping", "—")
    local stTime = Z.Stat("Tempo de uso", "00:00:00")

    task.spawn(function()
        local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
        if ok and info and info.Name then stGame.Set(info.Name) end
    end)
    Z.PageLoop(0.5, function()
        local fps = math.floor(Z.FPS + 0.5)
        stFps.Set(fps, fps >= 50 and Colors.Success or (fps >= 30 and Colors.Warning or Colors.Danger))
        local okp, ping = pcall(function() return Player:GetNetworkPing() * 1000 end)
        if okp then
            ping = math.floor(ping)
            stPing.Set(ping .. " ms", ping <= 100 and Colors.Success or (ping <= 200 and Colors.Warning or Colors.Danger))
        end
        stTime.Set(FmtTime(tick() - Z.StartTime))
    end)

    Z.Sep("⌨️  ATALHOS")
    Z.Info("INSERT ou RIGHT CTRL: mostrar / esconder o hub.\nArraste o topo da janela para mover. Use – para minimizar.")
end

-- ═══════════════════════════════════════════════════════════════════════
-- ABA PLAYER
-- ═══════════════════════════════════════════════════════════════════════
local function LoadPlayer()
    Z.Sep("🏃  MOVIMENTO")
    Z.Toggle("Velocidade personalizada", S.speedOn, function(v)
        S.speedOn = v
        if not v then local h = GetHum() if h then h.WalkSpeed = 16 end end
    end, "Aplica o valor do controle abaixo")
    Z.Slider("Velocidade (WalkSpeed)", 16, 250, S.walkSpeed, function(v) S.walkSpeed = v end)

    Z.Toggle("Pulo personalizado", S.jumpOn, function(v)
        S.jumpOn = v
        if not v then local h = GetHum() if h then h.JumpPower = 50 end end
    end, "Aplica o valor do controle abaixo")
    Z.Slider("Força do pulo (JumpPower)", 50, 300, S.jumpPower, function(v) S.jumpPower = v end)

    Z.Toggle("Pulo infinito", S.infJump, function(v) S.infJump = v end, "Pule no ar quantas vezes quiser")

    Z.Sep("🛡️  UTILIDADES")
    Z.Toggle("Anti-AFK", S.antiAfk, function(v) S.antiAfk = v end, "Evita ser kickado por ficar parado")

    Z.Sep("🔧  AÇÕES")
    Z.Button("↺  Resetar valores de movimento", Colors.AccentDark, function()
        S.speedOn, S.jumpOn, S.infJump = false, false, false
        S.walkSpeed, S.jumpPower = 16, 50
        local h = GetHum()
        if h then h.WalkSpeed, h.JumpPower = 16, 50 end
        Z.Notify("Player", "Valores resetados.", Colors.Success, 2)
        Z.SelectTab("Player")
    end)
    Z.Button("💀  Resetar personagem", Colors.Warning, function()
        local h = GetHum()
        if h then h.Health = 0 end
    end)
    Z.Button("🔁  Rejoin (reentrar no servidor)", Colors.Danger, function()
        Z.Notify("Rejoin", "Reconectando...", Colors.Warning, 3)
        pcall(function() TeleportService:Teleport(game.PlaceId, Player) end)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- INICIAR
-- ═══════════════════════════════════════════════════════════════════════
Z.AddTab("Home", "🏠", LoadHome)
Z.AddTab("Player", "👤", LoadPlayer)
Z.SelectTab("Home")
Z.SetVisible(true)
Z.Ready = true
print("✅ Zuni Hub Base v" .. Z.Version .. " carregada.")
