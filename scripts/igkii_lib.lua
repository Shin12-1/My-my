-- ============================================================================
-- IGKII UI LIBRARY  |  design ported from BloxStrike (AirFlow)
-- Load it with:  local Library = loadstring(game:HttpGet(URL))()
-- Returns the Library table: Library.Window({...}) -> window
--   window:Tab / :BuildHome / :BuildMisc / :Notify / :Confirm / :OnDestroy / :Destroy
--   tab:Groupbox -> :Toggle :Slider :Input :Dropdown :Keybind :Button :Status :Label :Section
--   window:BuildMisc() adds a ready-made, universal Misc tab: God Mode, Movement Speed,
--     Infinite Jump, Fly, No Clip, Hide Username (any fake name), Anti AFK, Instant Prompts
--     and a Config box with auto load (all undone on Destroy)
--   Library:SaveConfig(name) / :LoadConfig(name) store every element that has a Flag as a
--     Lua file (igkii/configs/name.lua); :SetAutoLoad(name, "account"|"all") picks auto load
--   Library:DestroyAll() closes every window (running the same cleanup as window:Destroy)
-- The window opens by itself after the script finishes adding tabs (Window:PlayIntro()).
-- Re-running a script that loads this library closes the previous window first, unless
-- getgenv().IGKII_ALLOW_MULTI = true.
-- Accessibility: Library:SetReducedMotion(true) or Library:SetMotionScale(0..1)
-- ============================================================================
local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local GuiService         = game:GetService("GuiService")
local TeleportService    = game:GetService("TeleportService")
local CoreGui            = game:GetService("CoreGui")

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end

-- ============================================================================
-- UI LIBRARY  (port of the BloxStrike "AirFlow" window design)
-- ============================================================================
local Library = {}
Library.Version = "2.0"
Library.Flags = {}
Library.Windows = {}

-- A second execution would otherwise stack a second window (and a second copy of every
-- loop) on top of the first, so the previous library instance is closed cleanly.
do
    local okEnv, env = pcall(function()
        return getgenv()
    end)
    env = (okEnv and type(env) == "table") and env or _G
    local previous = env.__igkiiLibrary
    if type(previous) == "table" and type(previous.Windows) == "table" and not env.IGKII_ALLOW_MULTI then
        for _, oldWindow in ipairs(table.clone(previous.Windows)) do
            pcall(function()
                oldWindow:Destroy()
            end)
        end
    end
    env.__igkiiLibrary = Library
end
-- One motion multiplier keeps the visual language consistent and lets callers
-- honour a player's reduced-motion preference without maintaining a second UI.
Library.MotionScale = 1

Library.Theme = {
    -- Premium graphite base with a restrained mint accent. The brighter
    -- surfaces create clearer hierarchy without turning the UI into neon.
    Background  = Color3.fromRGB(10, 13, 16),
    Surface     = Color3.fromRGB(14, 19, 23),
    Surface2    = Color3.fromRGB(20, 27, 32),
    Surface3    = Color3.fromRGB(29, 39, 45),
    Stroke      = Color3.fromRGB(39, 52, 58),
    StrokeHover = Color3.fromRGB(57, 139, 108),
    Accent      = Color3.fromRGB(93, 232, 174),
    AccentDark  = Color3.fromRGB(10, 35, 26),
    Text        = Color3.fromRGB(237, 245, 241),
    Muted       = Color3.fromRGB(145, 162, 158),
    Warning     = Color3.fromRGB(245, 190, 92),
    Success     = Color3.fromRGB(74, 216, 145),
    Error       = Color3.fromRGB(246, 104, 112),
}
local Theme = Library.Theme

-- Order decides which key wins when two theme colours are identical.
local THEME_KEYS = {
    "Accent", "AccentDark", "Background", "Surface", "Surface2", "Surface3",
    "Stroke", "StrokeHover", "Text", "Muted", "Warning", "Success", "Error",
}

local function rgb(r, g, b)
    return Color3.fromRGB(r, g, b)
end

local function preset(background, surface, surface2, surface3, strokeColor, strokeHover, accent, accentDark, text, muted)
    return {
        Background = rgb(table.unpack(background)),
        Surface = rgb(table.unpack(surface)),
        Surface2 = rgb(table.unpack(surface2)),
        Surface3 = rgb(table.unpack(surface3)),
        Stroke = rgb(table.unpack(strokeColor)),
        StrokeHover = rgb(table.unpack(strokeHover)),
        Accent = rgb(table.unpack(accent)),
        AccentDark = rgb(table.unpack(accentDark)),
        Text = rgb(table.unpack(text)),
        Muted = rgb(table.unpack(muted)),
    }
end

Library.ThemeOrder = {
    "Cybrion", "Nebula", "Midnight", "Ocean", "Rose", "Emerald", "Amber", "Mono",
    "Synthwave", "Crimson", "Sunset", "Dracula", "Aurora", "Frost", "Halloween", "Gold",
}
Library.ThemePresets = {
    Cybrion   = preset({ 10, 13, 16 }, { 14, 19, 23 }, { 20, 27, 32 }, { 29, 39, 45 }, { 39, 52, 58 }, { 57, 139, 108 }, { 93, 232, 174 }, { 10, 35, 26 }, { 237, 245, 241 }, { 145, 162, 158 }),
    Nebula    = preset({ 14, 12, 28 }, { 18, 15, 35 }, { 23, 19, 43 }, { 39, 32, 68 }, { 35, 29, 62 }, { 84, 68, 140 }, { 199, 125, 255 }, { 22, 10, 40 }, { 236, 230, 252 }, { 124, 114, 160 }),
    Midnight  = preset({ 15, 18, 26 }, { 18, 22, 31 }, { 22, 26, 37 }, { 37, 44, 60 }, { 34, 40, 55 }, { 70, 84, 112 }, { 128, 160, 246 }, { 14, 18, 30 }, { 228, 232, 242 }, { 116, 126, 148 }),
    Ocean     = preset({ 12, 20, 24 }, { 15, 24, 29 }, { 18, 29, 35 }, { 31, 48, 56 }, { 29, 44, 52 }, { 58, 92, 104 }, { 110, 214, 222 }, { 10, 24, 28 }, { 226, 238, 240 }, { 108, 134, 140 }),
    Rose      = preset({ 22, 15, 18 }, { 27, 18, 22 }, { 32, 21, 26 }, { 48, 34, 40 }, { 45, 30, 37 }, { 98, 64, 78 }, { 246, 160, 186 }, { 30, 14, 20 }, { 240, 228, 232 }, { 138, 112, 120 }),
    Emerald   = preset({ 13, 20, 17 }, { 16, 24, 20 }, { 20, 29, 24 }, { 33, 47, 40 }, { 30, 44, 37 }, { 62, 96, 78 }, { 132, 226, 170 }, { 12, 26, 18 }, { 228, 240, 233 }, { 110, 136, 122 }),
    Amber     = preset({ 22, 18, 13 }, { 27, 22, 16 }, { 32, 26, 19 }, { 49, 41, 31 }, { 46, 38, 28 }, { 100, 82, 58 }, { 246, 196, 120 }, { 30, 22, 10 }, { 242, 236, 226 }, { 140, 126, 106 }),
    Mono      = preset({ 16, 16, 17 }, { 20, 20, 21 }, { 25, 25, 26 }, { 40, 40, 42 }, { 38, 38, 40 }, { 84, 84, 88 }, { 236, 236, 240 }, { 20, 20, 22 }, { 234, 234, 236 }, { 122, 122, 128 }),
    Synthwave = preset({ 20, 12, 30 }, { 25, 15, 37 }, { 31, 18, 45 }, { 52, 30, 72 }, { 47, 27, 66 }, { 110, 58, 150 }, { 255, 94, 198 }, { 38, 8, 30 }, { 250, 232, 246 }, { 150, 118, 160 }),
    Crimson   = preset({ 18, 10, 12 }, { 23, 12, 15 }, { 28, 14, 18 }, { 46, 24, 29 }, { 42, 22, 27 }, { 104, 46, 56 }, { 244, 74, 94 }, { 32, 8, 12 }, { 244, 230, 232 }, { 142, 106, 112 }),
    Sunset    = preset({ 22, 13, 14 }, { 27, 16, 17 }, { 33, 19, 21 }, { 52, 31, 32 }, { 48, 28, 30 }, { 112, 62, 58 }, { 255, 138, 92 }, { 34, 14, 8 }, { 248, 234, 228 }, { 150, 118, 110 }),
    Dracula   = preset({ 24, 25, 33 }, { 29, 30, 40 }, { 34, 36, 47 }, { 52, 55, 70 }, { 48, 50, 64 }, { 98, 114, 164 }, { 189, 147, 249 }, { 26, 18, 44 }, { 246, 246, 238 }, { 126, 132, 168 }),
    Aurora    = preset({ 10, 20, 22 }, { 12, 25, 27 }, { 15, 30, 33 }, { 26, 50, 53 }, { 24, 45, 48 }, { 50, 104, 104 }, { 94, 240, 180 }, { 6, 30, 22 }, { 224, 246, 240 }, { 102, 142, 134 }),
    Frost     = preset({ 13, 17, 23 }, { 16, 21, 28 }, { 20, 26, 34 }, { 34, 43, 56 }, { 31, 40, 52 }, { 72, 92, 118 }, { 164, 214, 255 }, { 12, 22, 34 }, { 230, 238, 246 }, { 114, 128, 146 }),
    Halloween = preset({ 18, 12, 20 }, { 23, 15, 25 }, { 28, 18, 30 }, { 46, 30, 48 }, { 43, 28, 44 }, { 104, 62, 40 }, { 255, 138, 36 }, { 36, 16, 4 }, { 246, 234, 224 }, { 146, 120, 128 }),
    Gold      = preset({ 14, 13, 11 }, { 18, 17, 14 }, { 23, 21, 17 }, { 38, 35, 28 }, { 35, 32, 26 }, { 92, 80, 54 }, { 232, 196, 122 }, { 30, 22, 8 }, { 240, 234, 222 }, { 136, 126, 106 }),
}
Library.ThemeName = "Cybrion"

Library.Assets = {
    Shadow = "rbxassetid://6014261993",
    Glow   = "rbxassetid://8992230677",
}
local Assets = Library.Assets

-- Icons: BloxStrike pulls the Lucide set through loadstring, which this executor
-- does not have. These few are plain asset ids; anything missing falls back to a
-- text glyph or simply hides, so nothing ever shows a broken image.
local ICONS = {
    house    = "rbxassetid://6031075931",
    home     = "rbxassetid://6031075931",
    settings = "rbxassetid://6031280882",
    search   = "rbxassetid://6031090996",
    star     = "rbxassetid://6031091004",
}

local function resolveIcon(icon)
    if type(icon) ~= "string" or icon == "" then
        return nil
    end
    if icon:find("^rbxassetid://") or icon:find("^rbxthumb://") or icon:find("^rbxasset://") then
        return icon
    end
    return ICONS[icon]
end

local FONT_FAMILY = "rbxasset://fonts/families/BuilderSans.json"
local Fonts = {
    Regular = Font.new(FONT_FAMILY, Enum.FontWeight.Regular),
    Medium  = Font.new(FONT_FAMILY, Enum.FontWeight.Medium),
    Bold    = Font.new(FONT_FAMILY, Enum.FontWeight.SemiBold),
}

local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Design tokens. Keep all geometry in one place so the layout stays consistent.
local WINDOW_WIDTH = 780
local WINDOW_HEIGHT = 540
local SIDEBAR_WIDTH = 196
local HEADER_HEIGHT = 70
local TAB_TILE_HEIGHT = 38
local CARD_HEIGHT = TOUCH and 58 or 52
local CARD_HEIGHT_DESC = TOUCH and 76 or 70
local PROFILE_HEIGHT = 72
local SEARCH_WIDTH = 196
local STACK_BELOW = 520

local METRICS = {
    Card = {
        Compact = false, Height = CARD_HEIGHT, DescHeight = CARD_HEIGHT_DESC,
        Chip = TOUCH and 36 or 30, Option = TOUCH and 42 or 36,
        TextSize = 14, DescSize = 12, TitleHeight = 18, DescGap = 21, DescLine = 16,
        Slider = CARD_HEIGHT_DESC,
    },
    Row = {
        Compact = true, Height = TOUCH and 44 or 36, DescHeight = TOUCH and 58 or 52,
        Chip = TOUCH and 32 or 26, Option = TOUCH and 36 or 30,
        TextSize = 13, DescSize = 12, TitleHeight = 16, DescGap = 18, DescLine = 16,
        Slider = TOUCH and 58 or 52,
    },
}

-- ---------------------------------------------------------------------------
-- Theme bindings: every property painted with a theme colour is remembered by
-- key, so SetTheme repaints the whole UI live.
-- ---------------------------------------------------------------------------
local tweenInfoCache = {}
local themeBindings, themeHooks, themeLookup, orphanMarks = {}, {}, {}, {}
local bindingCount, sweepAt = 0, 4000

local function pruneTable(map, counted)
    for object in pairs(map) do
        if object.Parent == nil then
            if orphanMarks[object] then
                map[object] = nil
                orphanMarks[object] = nil
                if counted then
                    bindingCount -= 1
                end
            else
                orphanMarks[object] = true
            end
        else
            orphanMarks[object] = nil
        end
    end
end

local function sweepBindings()
    pruneTable(themeBindings, true)
    pruneTable(themeHooks, false)
    sweepAt = math.max(4000, bindingCount * 2)
end

local function colorKey(color)
    return math.floor(color.R * 255 + 0.5) .. "," .. math.floor(color.G * 255 + 0.5) .. "," .. math.floor(color.B * 255 + 0.5)
end

local function rebuildThemeLookup()
    table.clear(themeLookup)
    for index = #THEME_KEYS, 1, -1 do
        local name = THEME_KEYS[index]
        themeLookup[colorKey(Theme[name])] = name
    end
end
rebuildThemeLookup()

local function bindColors(object, props)
    for property, value in pairs(props) do
        if typeof(value) == "Color3" then
            local name = themeLookup[colorKey(value)]
            local bound = themeBindings[object]
            if name then
                if not bound then
                    bound = {}
                    themeBindings[object] = bound
                    bindingCount += 1
                    if bindingCount >= sweepAt then
                        sweepBindings()
                    end
                end
                bound[property] = name
            elseif bound then
                bound[property] = nil
            end
        end
    end
end

local shownTheme = table.clone(Theme)
local themeDriver = nil

local function paintBindings(colors)
    for object, bound in pairs(themeBindings) do
        pcall(function()
            for property, name in pairs(bound) do
                local color = colors[name]
                if color then
                    object[property] = color
                end
            end
        end)
    end
end

local function driveTheme(duration)
    duration = duration * Library.MotionScale
    if themeDriver then
        themeDriver:Disconnect()
        themeDriver = nil
    end
    local from, colors = {}, {}
    for _, name in ipairs(THEME_KEYS) do
        local target = Theme[name]
        local current = shownTheme[name] or target
        if current ~= target then
            from[name] = current
            colors[name] = current
        end
    end
    local function finish()
        for _, name in ipairs(THEME_KEYS) do
            colors[name] = Theme[name]
            shownTheme[name] = Theme[name]
        end
        paintBindings(colors)
    end
    if duration <= 0 or next(from) == nil then
        finish()
        return
    end
    local elapsed = 0
    themeDriver = RunService.Heartbeat:Connect(function(deltaTime)
        elapsed += deltaTime
        if elapsed >= duration then
            themeDriver:Disconnect()
            themeDriver = nil
            finish()
            return
        end
        local alpha = 1 - (1 - elapsed / duration) ^ 5
        for name, start in pairs(from) do
            local color = start:Lerp(Theme[name], alpha)
            colors[name] = color
            shownTheme[name] = color
        end
        paintBindings(colors)
    end)
end

local function onTheme(owner, fn)
    themeHooks[owner] = fn
    fn()
end

-- ---------------------------------------------------------------------------
-- Core helpers
-- ---------------------------------------------------------------------------
local function tween(object, props, duration, style, direction, raw)
    duration = (duration or 0.2) * Library.MotionScale
    if not raw then
        bindColors(object, props)
    end
    if duration <= 0 then
        for key, value in pairs(props) do
            object[key] = value
        end
        return nil
    end
    style = style or Enum.EasingStyle.Quart
    direction = direction or Enum.EasingDirection.Out
    local key = duration .. style.Name .. direction.Name
    local info = tweenInfoCache[key]
    if not info then
        info = TweenInfo.new(duration, style, direction)
        tweenInfoCache[key] = info
    end
    local t = TweenService:Create(object, info, props)
    t:Play()
    return t
end

function Library:DestroyAll()
    for _, window in ipairs(table.clone(Library.Windows)) do
        pcall(function()
            window:Destroy()
        end)
    end
end
Library.Unload = Library.DestroyAll

function Library:SetMotionScale(value)
    Library.MotionScale = math.clamp(tonumber(value) or 1, 0, 1)
    return Library.MotionScale
end

function Library:SetReducedMotion(enabled)
    return self:SetMotionScale(enabled and 0 or 1)
end

local function create(className, props, children)
    local inst = Instance.new(className)
    for key, value in pairs(props) do
        if key ~= "Parent" then
            inst[key] = value
        end
    end
    bindColors(inst, props)
    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end
    if props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

-- Corners in pixels follow the corner-radius setting.
Library.Roundness = 1
Library._cornerBases = {}

local function corner(parent, radius)
    radius = radius or UDim.new(0, 8)
    local object = create("UICorner", {
        CornerRadius = radius.Scale == 0 and UDim.new(0, math.floor(radius.Offset * Library.Roundness + 0.5)) or radius,
        Parent = parent,
    })
    if radius.Scale == 0 then
        Library._cornerBases[object] = radius.Offset
    end
    return object
end

local function stroke(parent, color, transparency, thickness)
    return create("UIStroke", {
        Color = color or Theme.Stroke,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function padding(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        Parent = parent,
    })
end

local function label(props)
    local defaults = {
        BackgroundTransparency = 1,
        TextColor3 = Theme.Text,
        TextSize = 14,
        FontFace = Fonts.Medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }
    for key, value in pairs(props) do
        defaults[key] = value
    end
    return create("TextLabel", defaults)
end

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return
    end
    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[igkii] callback error: " .. tostring(err))
    end
end

-- An icon image, or nil when the name has no asset (callers then skip the slot).
local function iconImage(parent, name, color, size, props)
    local asset = resolveIcon(name)
    if not asset then
        return nil
    end
    local data = {
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        Image = asset,
        ImageColor3 = color,
        ScaleType = Enum.ScaleType.Fit,
        Parent = parent,
    }
    for key, value in pairs(props or {}) do
        data[key] = value
    end
    return create("ImageLabel", data)
end

local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function usingTouch()
    return UserInputService:GetLastInputType() == Enum.UserInputType.Touch
end

-- The mouse position in the window's own coordinate space. The offset between
-- the two spaces differs between clients, so it is measured when the pointer
-- crosses the window edge (where the right answer is known to be near the rect).
local pointerShift = Vector2.zero
local function rectDistance(point, object)
    local pos, size = object.AbsolutePosition, object.AbsoluteSize
    local dx = math.max(pos.X - point.X, 0, point.X - (pos.X + size.X))
    local dy = math.max(pos.Y - point.Y, 0, point.Y - (pos.Y + size.Y))
    return math.sqrt(dx * dx + dy * dy)
end

local function calibratePointer(object)
    local raw = UserInputService:GetMouseLocation()
    local ok, inset = pcall(function()
        return GuiService:GetGuiInset()
    end)
    inset = ok and inset or Vector2.zero
    local best, bestShift = math.huge, pointerShift
    for _, shift in ipairs({ Vector2.zero, -inset, inset }) do
        local distance = rectDistance(raw + shift, object)
        if distance < best - 0.5 then
            best, bestShift = distance, shift
        end
    end
    pointerShift = bestShift
end

local function pointerPosition()
    return UserInputService:GetMouseLocation() + pointerShift
end

local function pointInside(point, object)
    local position, size = object.AbsolutePosition, object.AbsoluteSize
    return point.X >= position.X and point.X <= position.X + size.X
        and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

-- A press that turned into a scroll is not a tap.
local function tapGuard(button, getScroller)
    local startCanvas
    button.InputBegan:Connect(function(input)
        if isPress(input) then
            local frame = getScroller()
            startCanvas = frame and frame.CanvasPosition
        end
    end)
    return function()
        local frame = getScroller()
        return not (startCanvas and frame and (frame.CanvasPosition - startCanvas).Magnitude > 4)
    end
end

local function flashStroke(strokeObject)
    if not strokeObject or strokeObject:GetAttribute("Hidden") then
        return
    end
    tween(strokeObject, { Color = Theme.Accent, Transparency = 0.2 }, 0.08)
    task.delay(0.12, function()
        tween(strokeObject, { Color = Theme.Stroke, Transparency = 0 }, 0.35)
    end)
end

local function hoverStroke(target, strokeObject)
    target.MouseEnter:Connect(function()
        tween(strokeObject, { Color = Theme.StrokeHover }, 0.12)
    end)
    target.MouseLeave:Connect(function()
        tween(strokeObject, { Color = Theme.Stroke }, 0.25)
    end)
end

local ripplePool = {}
local function ripple(button)
    local mouse = pointerPosition()
    local diameter = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2.2
    local circle = table.remove(ripplePool)
    if circle and not pcall(function()
        circle.Parent = nil
    end) then
        circle = nil
    end
    if not circle then
        circle = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
        })
        corner(circle, UDim.new(1, 0))
    end
    local scale = 1
    local root = button:FindFirstAncestorOfClass("ScreenGui")
    local scaler = root and root:FindFirstChild("Window") and root.Window:FindFirstChildOfClass("UIScale")
    if scaler then
        scale = math.max(scaler.Scale, 0.05)
    end
    circle.Position = UDim2.fromOffset((mouse.X - button.AbsolutePosition.X) / scale, (mouse.Y - button.AbsolutePosition.Y) / scale)
    circle.Size = UDim2.fromOffset(0, 0)
    circle.BackgroundColor3 = Theme.Accent
    circle.BackgroundTransparency = 0.82
    circle.ZIndex = button.ZIndex + 1
    circle.Parent = button
    tween(circle, { Size = UDim2.fromOffset(diameter / scale, diameter / scale), BackgroundTransparency = 1 }, 0.55)
    task.delay(0.55, function()
        if circle.Parent ~= button or not button.Parent then
            pcall(circle.Destroy, circle)
            return
        end
        circle.Parent = nil
        if #ripplePool < 4 then
            table.insert(ripplePool, circle)
        else
            circle:Destroy()
        end
    end)
end

local function numberFormat(min, max, step)
    local decimals = 0
    local text = tostring(step)
    local dot = text:find("%.")
    if dot then
        decimals = #text - dot
    end
    local pattern = "%." .. decimals .. "f"
    return {
        snap = function(value)
            value = math.floor(value / step + 0.5) * step
            return math.clamp(value, min, max)
        end,
        format = function(value)
            return string.format(pattern, value)
        end,
    }
end

local function formatDuration(seconds)
    seconds = math.max(math.floor(seconds), 0)
    local days = math.floor(seconds / 86400)
    local hours = math.floor(seconds / 3600) % 24
    local minutes = math.floor(seconds / 60) % 60
    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    elseif minutes > 0 then
        return string.format("%dm %02ds", minutes, seconds % 60)
    end
    return string.format("%ds", seconds)
end

function Library._healthColor(value, good, bad, lowerIsBetter)
    if type(value) ~= "number" then
        return Theme.Text
    end
    if lowerIsBetter then
        return value <= good and Theme.Success or value <= bad and Theme.Warning or Theme.Error
    end
    return value >= good and Theme.Success or value >= bad and Theme.Warning or Theme.Error
end

local function mountParent()
    local ok, hui = pcall(function()
        return typeof(gethui) == "function" and gethui() or nil
    end)
    if ok and typeof(hui) == "Instance" then
        return hui
    end
    local core
    pcall(function()
        local probe = Instance.new("Folder")
        probe.Parent = CoreGui
        probe:Destroy()
        core = CoreGui
    end)
    return core or player:WaitForChild("PlayerGui")
end

local function notificationColor(kind)
    if kind == "Success" then
        return Theme.Success
    elseif kind == "Warning" then
        return Theme.Warning
    elseif kind == "Error" then
        return Theme.Error
    end
    return Theme.Text
end

function Library:SetCornerRadius(pixels, instant)
    pixels = math.clamp(math.floor((tonumber(pixels) or 10) + 0.5), 0, 20)
    Library.Roundness = pixels / 10
    for object, base in pairs(Library._cornerBases) do
        if not object.Parent then
            Library._cornerBases[object] = nil
        else
            local radius = UDim.new(0, math.floor(base * Library.Roundness + 0.5))
            if instant then
                object.CornerRadius = radius
            else
                tween(object, { CornerRadius = radius }, 0.25, Enum.EasingStyle.Quint)
            end
        end
    end
    return pixels
end

function Library:SetTheme(name, instant)
    local found = Library.ThemePresets[name]
    if not found then
        return false
    end
    Library.ThemeName = name
    local changed = false
    for _, key in ipairs(THEME_KEYS) do
        local color = found[key]
        if color and color ~= Theme[key] then
            Theme[key] = color
            changed = true
        end
    end
    if not changed then
        return true
    end
    rebuildThemeLookup()
    sweepBindings()
    driveTheme(instant and 0 or 0.3)
    for owner, fn in pairs(themeHooks) do
        if owner.Parent then
            pcall(fn)
        end
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Configs: every element created with a Flag can be saved and restored.
-- A config is a Lua file (igkii/configs/<name>.lua) that returns a table.
-- Auto load lives in igkii/autoload.lua, for one account or for every account.
-- ---------------------------------------------------------------------------
local SAVEABLE = { Toggle = true, Slider = true, Input = true, Dropdown = true, Keybind = true }
local CONFIG_DIR = "igkii/configs"
local AUTOLOAD_PATH = "igkii/autoload.lua"

local function safeName(name)
    name = tostring(name or ""):gsub("[^%w_%- ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        return nil
    end
    return name
end

local function ensureFolders()
    if type(makefolder) ~= "function" or type(isfolder) ~= "function" then
        return
    end
    for _, folder in ipairs({ "igkii", CONFIG_DIR }) do
        if not isfolder(folder) then
            pcall(makefolder, folder)
        end
    end
end

-- Turns a value into Lua source, or nil when it cannot be stored.
local function toLua(value)
    local kind = typeof(value)
    if kind == "boolean" then
        return tostring(value)
    elseif kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return nil
        end
        return tostring(value)
    elseif kind == "string" then
        return string.format("%q", value)
    elseif kind == "EnumItem" then
        return tostring(value)
    end
    return nil
end

-- Reads a Lua file that returns a table, in a sandbox with nothing but Enum.
local function readLuaTable(path)
    if type(readfile) ~= "function" or type(loadstring) ~= "function" then
        return nil, "readfile or loadstring is not available in this executor"
    end
    local okRead, source = pcall(readfile, path)
    if not okRead or type(source) ~= "string" then
        return nil, "the file could not be read"
    end
    local chunk = loadstring(source)
    if not chunk then
        return nil, "the file has a syntax error"
    end
    pcall(setfenv, chunk, { Enum = Enum })
    local okRun, data = pcall(chunk)
    if not okRun or type(data) ~= "table" then
        return nil, "the file is not a valid table"
    end
    return data
end

function Library:SaveConfig(name)
    name = safeName(name)
    if not name then
        return false, "type a config name first"
    end
    if type(writefile) ~= "function" then
        return false, "writefile is not available in this executor"
    end
    local flags = {}
    for flag, element in pairs(Library.Flags) do
        if SAVEABLE[element.Kind] and type(element.Get) == "function" then
            table.insert(flags, flag)
        end
    end
    table.sort(flags)
    local lines = { "-- igkii config: " .. name, "return {" }
    for _, flag in ipairs(flags) do
        local ok, value = pcall(function()
            return Library.Flags[flag]:Get()
        end)
        local text = ok and toLua(value) or nil
        if text then
            table.insert(lines, string.format("    [%q] = %s,", flag, text))
        end
    end
    table.insert(lines, "}")
    return pcall(function()
        ensureFolders()
        writefile(CONFIG_DIR .. "/" .. name .. ".lua", table.concat(lines, "\n") .. "\n")
    end)
end

function Library:LoadConfig(name)
    name = safeName(name)
    if not name then
        return false, "type a config name first"
    end
    local path = CONFIG_DIR .. "/" .. name .. ".lua"
    if type(isfile) == "function" and not isfile(path) then
        return false, "no config named " .. name
    end
    local data, err = readLuaTable(path)
    if not data then
        return false, err
    end
    -- Values first, toggles last, so a toggle sees the final slider and text values.
    for pass = 1, 2 do
        for flag, value in pairs(data) do
            local element = Library.Flags[flag]
            if element and type(element.Set) == "function" and ((element.Kind == "Toggle") == (pass == 2)) then
                pcall(function()
                    element:Set(value)
                end)
            end
        end
    end
    return true
end

function Library:ListConfigs()
    local names = {}
    if type(listfiles) == "function" then
        local ok, files = pcall(listfiles, CONFIG_DIR)
        if ok and type(files) == "table" then
            for _, path in ipairs(files) do
                local name = tostring(path):match("([^/\\]+)%.lua$")
                if name then
                    table.insert(names, name)
                end
            end
        end
    end
    table.sort(names)
    return names
end

function Library:DeleteConfig(name)
    name = safeName(name)
    if not name then
        return false, "type a config name first"
    end
    if type(delfile) ~= "function" then
        return false, "delfile is not available in this executor"
    end
    local path = CONFIG_DIR .. "/" .. name .. ".lua"
    if type(isfile) == "function" and not isfile(path) then
        return false, "no config named " .. name
    end
    return pcall(delfile, path)
end

local function readAutoLoad()
    local data = { accounts = {} }
    if type(isfile) == "function" and isfile(AUTOLOAD_PATH) then
        local result = readLuaTable(AUTOLOAD_PATH)
        if result then
            if type(result.all) == "string" then
                data.all = result.all
            end
            if type(result.accounts) == "table" then
                for id, config in pairs(result.accounts) do
                    if type(config) == "string" then
                        data.accounts[tostring(id)] = config
                    end
                end
            end
        end
    end
    return data
end

local function writeAutoLoad(data)
    if type(writefile) ~= "function" then
        return false, "writefile is not available in this executor"
    end
    local lines = { "-- igkii auto load: the config that loads by itself", "return {" }
    if data.all then
        table.insert(lines, string.format("    all = %q,", data.all))
    end
    table.insert(lines, "    accounts = {")
    local ids = {}
    for id in pairs(data.accounts) do
        table.insert(ids, id)
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        table.insert(lines, string.format("        [%q] = %q,", id, data.accounts[id]))
    end
    table.insert(lines, "    },")
    table.insert(lines, "}")
    return pcall(function()
        ensureFolders()
        writefile(AUTOLOAD_PATH, table.concat(lines, "\n") .. "\n")
    end)
end

-- scope "account" = this account only, "all" = every account. name nil turns it off.
function Library:SetAutoLoad(name, scope)
    if name ~= nil then
        name = safeName(name)
        if not name then
            return false, "type a config name first"
        end
    end
    local data = readAutoLoad()
    if scope == "all" then
        data.all = name
    else
        data.accounts[tostring(player.UserId)] = name
    end
    return writeAutoLoad(data)
end

-- Returns the config name and its scope for this account (this account wins over all).
function Library:GetAutoLoad()
    local data = readAutoLoad()
    local own = data.accounts[tostring(player.UserId)]
    if own then
        return own, "account"
    end
    if data.all then
        return data.all, "all"
    end
    return nil
end

function Library:RunAutoLoad()
    local name, scope = Library:GetAutoLoad()
    if not name then
        return false
    end
    local ok, err = Library:LoadConfig(name)
    return ok, ok and name or err, scope
end

-- ---------------------------------------------------------------------------
-- Elements (Tab = a page, or a groupbox when _groupbox is set)
-- ---------------------------------------------------------------------------
local Tab = {}
Tab.__index = Tab

local ALIASES = {
    Title = "Name", Description = "Desc", CurrentValue = "Default", Value = "Default",
    Increment = "Step", PlaceholderText = "Placeholder", CurrentOption = "Default",
    CurrentKeybind = "Default",
}

local function normalize(source)
    local opts = {}
    if type(source) == "string" then
        opts.Name = source
    elseif type(source) == "table" then
        for key, value in pairs(source) do
            opts[key] = value
        end
        for alias, target in pairs(ALIASES) do
            if opts[alias] ~= nil and opts[target] == nil then
                opts[target] = opts[alias]
            end
        end
    end
    return opts
end

local function metricsOf(tab)
    return tab._metrics or METRICS.Card
end

local function rootTab(tab)
    while tab._groupbox do
        tab = tab.Parent
    end
    return tab
end

local function rowControlWidth(frame, window)
    local width = frame.AbsoluteSize.X / window.Scale.Scale
    return math.clamp(math.floor(width * 0.48), 90, 220)
end

function Tab:_nextOrder()
    self._order = self._order + 1
    return self._order
end

local function card(tab, className, height)
    local compact = metricsOf(tab).Compact
    local props = {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = Theme.Surface2,
        BackgroundTransparency = compact and 1 or 0,
        BorderSizePixel = 0,
        LayoutOrder = tab:_nextOrder(),
        Parent = tab.List,
    }
    if className == "TextButton" then
        props.AutoButtonColor = false
        props.Text = ""
    end
    local frame = create(className, props)
    frame:SetAttribute("NoDrag", true)
    corner(frame, UDim.new(0, 9))
    local frameStroke = stroke(frame, Theme.Stroke, compact and 1 or 0.3)
    if compact then
        frameStroke:SetAttribute("Hidden", true)
    end
    return frame, frameStroke
end

local function titleDesc(parent, name, desc, rightReserve, metrics)
    metrics = metrics or METRICS.Card
    local title, descLabel
    if desc then
        local top = math.floor((metrics.DescHeight - (metrics.DescGap + metrics.DescLine)) / 2)
        title = label({
            Position = UDim2.fromOffset(14, top),
            Size = UDim2.new(1, -(14 + rightReserve), 0, metrics.TitleHeight),
            Text = name,
            TextSize = metrics.TextSize,
            Parent = parent,
        })
        descLabel = label({
            Position = UDim2.fromOffset(14, top + metrics.DescGap),
            Size = UDim2.new(1, -(14 + rightReserve), 0, metrics.DescLine),
            Text = desc,
            TextSize = metrics.DescSize,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            Parent = parent,
        })
    else
        title = label({
            Position = UDim2.fromOffset(14, 0),
            Size = UDim2.new(1, -(14 + rightReserve), 1, 0),
            Text = name,
            TextSize = metrics.TextSize,
            Parent = parent,
        })
    end
    return title, descLabel
end

local function beginElement(tab, opts, className, rightReserve, fallbackName)
    opts = normalize(opts)
    local metrics = metricsOf(tab)
    local height = opts.Desc and metrics.DescHeight or metrics.Height
    local frame, frameStroke = card(tab, className or "Frame", height)
    hoverStroke(frame, frameStroke)
    local title, descLabel
    if rightReserve then
        title, descLabel = titleDesc(frame, opts.Name or fallbackName, opts.Desc, rightReserve, metrics)
    end
    return opts, frame, frameStroke, title, descLabel
end

local function reserveRight(title, descLabel, width)
    if title then
        title.Size = UDim2.new(1, -(14 + width), title.Size.Y.Scale, title.Size.Y.Offset)
    end
    if descLabel then
        descLabel.Size = UDim2.new(1, -(14 + width), 0, descLabel.Size.Y.Offset)
    end
end

local function finishElement(tab, opts, element, frame, kind)
    element.Frame = frame
    element.Kind = kind
    function element:SetVisible(value)
        frame.Visible = value == true
    end
    function element:Destroy()
        frame:Destroy()
    end
    if opts.Flag then
        Library.Flags[opts.Flag] = element
    end
    table.insert(tab._items, element)
    local window = tab.Window
    if opts.Name and kind ~= "Section" and kind ~= "Label" and window._searchIndex then
        table.insert(window._searchIndex, {
            Name = opts.Name,
            Desc = opts.Desc,
            Tab = rootTab(tab),
            Frame = frame,
            Group = tab._groupbox and tab.Name or nil,
        })
    end
    if opts.Visible == false then
        frame.Visible = false
    end
    return element
end

-- A caps heading with a hairline running out to the edge.
function Tab:Section(text)
    if type(text) == "table" then
        text = text.Name or text.Title or ""
    end
    local inset = metricsOf(self).Compact and 14 or 4
    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        LayoutOrder = self:_nextOrder(),
        Parent = self.List,
    })
    local text_ = label({
        Position = UDim2.fromOffset(inset, 9),
        Size = UDim2.new(0, 0, 0, 15),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = string.upper(text),
        TextSize = 11,
        FontFace = Fonts.Bold,
        TextColor3 = Theme.Muted,
        TextTruncate = Enum.TextTruncate.None,
        Parent = holder,
    })
    local ruleInset = inset == 2 and 0 or inset
    local rule = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -ruleInset, 0, 16),
        Size = UDim2.new(1, -12, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Parent = holder,
    })
    local function fitRule()
        rule.Size = UDim2.new(1, -(text_.AbsoluteSize.X / self.Window.Scale.Scale + inset + 12 + ruleInset), 0, 1)
    end
    text_:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitRule)
    task.defer(fitRule)
    return finishElement(self, {}, {
        Set = function(_, value)
            text_.Text = string.upper(value)
        end,
    }, holder, "Section")
end

function Tab:Label(opts)
    opts = normalize(opts)
    local compact = metricsOf(self).Compact
    local frame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = self:_nextOrder(),
        Parent = self.List,
    })
    padding(frame, 14, 14, 6, 6)
    local text_ = label({
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = opts.Name or opts.Text or "",
        TextSize = compact and 12 or 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = frame,
    })
    return finishElement(self, opts, {
        Set = function(_, value)
            text_.Text = tostring(value)
        end,
    }, frame, "Label")
end

-- A read-only row: name on the left, a live value on the right.
function Tab:Status(opts)
    opts = normalize(opts)
    local metrics = metricsOf(self)
    local frame, frameStroke = card(self, "Frame", metrics.Height)
    hoverStroke(frame, frameStroke)
    local value = label({
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 0),
        Size = UDim2.new(0.55, 0, 1, 0),
        Text = tostring(opts.Default or "-"),
        TextSize = metrics.TextSize,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = frame,
    })
    label({
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(0.45, -14, 1, 0),
        Text = opts.Name or "Status",
        TextSize = metrics.TextSize,
        Parent = frame,
    })
    return finishElement(self, opts, {
        Set = function(_, text, color)
            value.Text = tostring(text)
            if color then
                tween(value, { TextColor3 = color }, 0.25)
            end
        end,
    }, frame, "Status")
end

-- Rows with a button box inside a groupbox, a full card button on a page.
local function rowButton(tab, opts)
    local primary = opts.Style == "Primary"
    local boxHeight = TOUCH and 34 or 28
    local height = boxHeight + 8 + (opts.Desc and 16 or 0)
    local button = card(tab, "TextButton", height)

    local box = create("Frame", {
        Position = UDim2.fromOffset(14, 4),
        Size = UDim2.new(1, -28, 0, boxHeight),
        BackgroundColor3 = primary and Theme.Accent or Theme.Surface3,
        BackgroundTransparency = primary and 0.12 or 0.45,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = button,
    })
    corner(box, UDim.new(0, 8))
    local boxStroke = stroke(box, primary and Theme.Accent or Theme.Stroke, primary and 0.35 or 0.25)

    local row = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Parent = box,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = row,
    })
    if opts.Icon then
        iconImage(row, opts.Icon, primary and Theme.AccentDark or Theme.Accent, 14, { LayoutOrder = 1 })
    end
    local title = label({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = opts.Name or "Button",
        TextSize = 13,
        TextColor3 = primary and Theme.AccentDark or Theme.Text,
        TextTruncate = Enum.TextTruncate.None,
        LayoutOrder = 2,
        Parent = row,
    })
    if opts.Desc then
        label({
            Position = UDim2.fromOffset(14, boxHeight + 6),
            Size = UDim2.new(1, -28, 0, 14),
            Text = opts.Desc,
            TextSize = 12,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            Parent = button,
        })
    end

    local restBg = primary and 0.12 or 0.45
    button.MouseEnter:Connect(function()
        tween(box, { BackgroundTransparency = primary and 0 or 0.2 }, 0.12)
        tween(boxStroke, primary and { Transparency = 0 } or { Color = Theme.StrokeHover }, 0.12)
    end)
    button.MouseLeave:Connect(function()
        tween(box, { BackgroundTransparency = restBg }, 0.25)
        tween(boxStroke, primary and { Transparency = 0.4 } or { Color = Theme.Stroke }, 0.25)
    end)
    button.MouseButton1Click:Connect(function()
        ripple(box)
        safeCall(opts.Callback)
    end)

    return finishElement(tab, opts, {
        SetText = function(_, value)
            title.Text = value
        end,
    }, button, "Button")
end

function Tab:Button(opts)
    opts = normalize(opts)
    if metricsOf(self).Compact then
        return rowButton(self, opts)
    end
    local primary = opts.Style == "Primary"
    local height = opts.Desc and CARD_HEIGHT_DESC or CARD_HEIGHT
    local button, buttonStroke = card(self, "TextButton", height)
    button.ClipsDescendants = true

    if primary then
        tween(button, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.12 }, 0)
        tween(buttonStroke, { Color = Theme.Accent }, 0)
        buttonStroke.Transparency = 0.4
        button.MouseEnter:Connect(function()
            tween(button, { BackgroundTransparency = 0 }, 0.12)
            tween(buttonStroke, { Transparency = 0 }, 0.12)
        end)
        button.MouseLeave:Connect(function()
            tween(button, { BackgroundTransparency = 0.12 }, 0.25)
            tween(buttonStroke, { Transparency = 0.4 }, 0.25)
        end)
    else
        hoverStroke(button, buttonStroke)
    end

    local textColor = primary and Theme.AccentDark or Theme.Text
    local title = titleDesc(button, opts.Name or "Button", opts.Desc, 30)
    if primary then
        for _, child in ipairs(button:GetChildren()) do
            if child:IsA("TextLabel") then
                tween(child, { TextColor3 = textColor }, 0)
            end
        end
    end
    label({
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(16, 20),
        Text = "›",
        TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextColor3 = primary and Theme.AccentDark or Theme.Muted,
        TextTruncate = Enum.TextTruncate.None,
        Parent = button,
    })

    button.MouseButton1Click:Connect(function()
        ripple(button)
        safeCall(opts.Callback)
    end)

    return finishElement(self, opts, {
        SetText = function(_, value)
            title.Text = value
        end,
    }, button, "Button")
end

function Tab:Toggle(opts)
    local button, buttonStroke
    opts, button, buttonStroke = beginElement(self, opts, "TextButton", 56, "Toggle")

    local pillW = TOUCH and 46 or 40
    local knobSize = TOUCH and 18 or 16
    local pill = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(pillW, TOUCH and 24 or 20),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = button,
    })
    corner(pill, UDim.new(1, 0))
    stroke(pill, Theme.Stroke)

    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(knobSize, knobSize),
        BackgroundColor3 = Theme.Muted,
        BorderSizePixel = 0,
        Parent = pill,
    })
    corner(knob, UDim.new(1, 0))
    local pillGlow = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 24, 1, 24),
        BackgroundTransparency = 1,
        Image = Assets.Glow,
        ImageColor3 = Theme.Accent,
        ImageTransparency = 1,
        ZIndex = 0,
        Parent = pill,
    })

    local self_: any = { Value = opts.Default == true }

    local function render(animate)
        local on = self_.Value
        local duration = animate and 0.25 or 0
        tween(pill, { BackgroundColor3 = on and Theme.Accent or Theme.Surface3 }, duration)
        tween(pillGlow, { ImageTransparency = on and 0.75 or 1 }, duration)
        tween(knob, {
            Position = on and UDim2.new(0, pillW - 3 - knobSize, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
            BackgroundColor3 = on and Theme.AccentDark or Theme.Muted,
        }, duration, Enum.EasingStyle.Back)
        if animate then
            tween(knob, { Size = UDim2.fromOffset(knobSize + 4, knobSize - 2) }, 0.08)
            task.delay(0.08, function()
                tween(knob, { Size = UDim2.fromOffset(knobSize, knobSize) }, 0.2, Enum.EasingStyle.Back)
            end)
        end
    end

    local fromClick = false
    function self_:Set(value, silent)
        value = value == true
        if value == self_.Value then
            return
        end
        self_.Value = value
        render(true)
        if not fromClick then
            flashStroke(buttonStroke)
        end
        if not silent then
            safeCall(opts.Callback, value)
        end
    end

    function self_:Get()
        return self_.Value
    end

    render(false)
    button.MouseButton1Click:Connect(function()
        fromClick = true
        self_:Set(not self_.Value)
        fromClick = false
    end)

    local handle = finishElement(self, opts, self_, button, "Toggle")
    if self_.Value then
        safeCall(opts.Callback, true)
    end
    return handle
end

function Tab:Slider(opts)
    opts = normalize(opts)
    local min = opts.Min or 0
    local max = opts.Max or 100
    local step = opts.Step or 1
    local suffix = opts.Suffix or ""
    local numbers = numberFormat(min, max, step)

    local metrics = metricsOf(self)
    local compact = metrics.Compact
    local height = metrics.Slider
    local frame, frameStroke = card(self, "Frame", height)
    hoverStroke(frame, frameStroke)
    if opts.Desc then
        self.Window:_attachTooltip(frame, opts.Desc)
    end

    label({
        Position = UDim2.fromOffset(14, compact and 5 or 12),
        Size = UDim2.new(1, -120, 0, 18),
        Text = opts.Name or "Slider",
        TextSize = metrics.TextSize,
        Parent = frame,
    })

    local valueChip = create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, compact and -14 or -10, 0, compact and 2 or 9),
        Size = UDim2.fromOffset(40, 24),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = frame,
    })
    corner(valueChip, UDim.new(0, 6))
    local chipStroke = stroke(valueChip)
    local valueLabel = label({
        Size = UDim2.new(1, 0, 1, 0),
        TextSize = 13,
        TextColor3 = Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
        Parent = valueChip,
    })
    local valueBox = create("TextBox", {
        Position = UDim2.fromOffset(9, 0),
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = Fonts.Medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Visible = false,
        Parent = valueChip,
    })
    create("UISizeConstraint", { MinSize = Vector2.new(14, 0), Parent = valueBox })
    local suffixLabel = label({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = suffix,
        TextSize = 13,
        TextColor3 = Theme.Accent,
        TextTruncate = Enum.TextTruncate.None,
        Visible = false,
        Parent = valueChip,
    })
    local chipButton = create("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 2,
        Parent = valueChip,
    })
    local editing = false
    local function fitChip(instant)
        local width
        if editing then
            width = 9 + valueBox.AbsoluteSize.X / self.Window.Scale.Scale + suffixLabel.TextBounds.X + 9
            suffixLabel.Position = UDim2.fromOffset(9 + valueBox.AbsoluteSize.X / self.Window.Scale.Scale, 0)
        else
            width = valueLabel.TextBounds.X + 18
        end
        width = math.max(width, 36)
        if instant then
            valueChip.Size = UDim2.fromOffset(width, 24)
        else
            tween(valueChip, { Size = UDim2.fromOffset(width, 24) }, 0.2)
        end
    end
    valueLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
        if not editing then
            fitChip(false)
        end
    end)
    valueBox:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if editing then
            fitChip(false)
        end
    end)

    local track = create("Frame", {
        Position = UDim2.new(0, 14, 0, height - (compact and 13 or 18)),
        Size = UDim2.new(1, -28, 0, 6),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(track, UDim.new(1, 0))
    local fill = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(fill, UDim.new(1, 0))

    local knobGlow = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(28, 28),
        BackgroundTransparency = 1,
        Image = Assets.Glow,
        ImageColor3 = Theme.Accent,
        ImageTransparency = 0.85,
        ZIndex = 2,
        Parent = track,
    })
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(13, 13),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = track,
    })
    corner(knob, UDim.new(1, 0))

    local hit = create("TextButton", {
        Position = UDim2.new(0, 8, 0, height - (compact and 13 or 18) - (TOUCH and 19 or 13)),
        Size = UDim2.new(1, -16, 0, TOUCH and 40 or 28),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 4,
        Parent = frame,
    })

    local self_: any = { Value = math.clamp(opts.Default or min, min, max) }
    local dragging = false
    chipButton.MouseEnter:Connect(function()
        tween(chipStroke, { Color = Theme.StrokeHover }, 0.12)
    end)
    chipButton.MouseLeave:Connect(function()
        if not valueBox:IsFocused() then
            tween(chipStroke, { Color = Theme.Stroke }, 0.2)
        end
    end)
    chipButton.MouseButton1Click:Connect(function()
        editing = true
        valueBox.Text = numbers.format(self_.Value)
        valueLabel.Visible = false
        valueBox.Visible = true
        suffixLabel.Visible = suffix ~= ""
        chipButton.Visible = false
        tween(chipStroke, { Color = Theme.StrokeHover }, 0.12)
        valueBox:CaptureFocus()
        task.defer(fitChip, false)
    end)
    valueBox.FocusLost:Connect(function()
        local typed = tonumber(valueBox.Text)
        editing = false
        valueBox.Visible = false
        suffixLabel.Visible = false
        valueLabel.Visible = true
        chipButton.Visible = true
        tween(chipStroke, { Color = Theme.Stroke }, 0.2)
        if typed then
            self_:Set(typed)
        end
        fitChip(false)
    end)
    hit.MouseEnter:Connect(function()
        if not dragging then
            tween(knobGlow, { ImageTransparency = 0.78, Size = UDim2.fromOffset(34, 34) }, 0.15)
        end
    end)
    hit.MouseLeave:Connect(function()
        if not dragging then
            tween(knobGlow, { ImageTransparency = 0.85, Size = UDim2.fromOffset(28, 28) }, 0.2)
        end
    end)

    local snap = numbers.snap

    local function fraction()
        return (max - min) == 0 and 0 or (self_.Value - min) / (max - min)
    end

    local function moveTo(frac, duration, style)
        style = style or Enum.EasingStyle.Linear
        tween(fill, { Size = UDim2.new(frac, 0, 1, 0) }, duration, style)
        tween(knob, { Position = UDim2.new(frac, 0, 0.5, 0) }, duration, style)
        tween(knobGlow, { Position = UDim2.new(frac, 0, 0.5, 0) }, duration, style)
    end

    local function render(duration, style)
        moveTo(fraction(), duration, style)
        valueLabel.Text = numbers.format(self_.Value) .. suffix
    end

    local function settleTo(previousFrac)
        local target = fraction()
        local width = math.max(track.AbsoluteSize.X, 1)
        local overshoot = (target >= previousFrac and 1 or -1) * (5 / width)
        moveTo(math.clamp(target + overshoot, 0, 1), 0.22, Enum.EasingStyle.Quint)
        task.delay(0.22, function()
            if not dragging then
                moveTo(fraction(), 0.18, Enum.EasingStyle.Quint)
            end
        end)
        valueLabel.Text = numbers.format(self_.Value) .. suffix
    end

    local function bounceKnob()
        tween(knob, { Size = UDim2.fromOffset(14, 12) }, 0.08)
        tween(knobGlow, { Size = UDim2.fromOffset(32, 32), ImageTransparency = 0.78 }, 0.12)
        task.delay(0.1, function()
            tween(knob, { Size = UDim2.fromOffset(12, 12) }, 0.25, Enum.EasingStyle.Quint)
            tween(knobGlow, { Size = UDim2.fromOffset(28, 28), ImageTransparency = 0.85 }, 0.25)
        end)
    end

    function self_:Set(value, silent)
        value = snap(tonumber(value) or min)
        if value == self_.Value then
            return
        end
        local previousFrac = fraction()
        self_.Value = value
        if dragging then
            render(0.05)
        else
            settleTo(previousFrac)
            bounceKnob()
            flashStroke(frameStroke)
        end
        if not silent then
            safeCall(opts.Callback, value)
        end
    end

    function self_:Get()
        return self_.Value
    end

    local function updateFromX(x)
        local frac = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        self_:Set(min + (max - min) * frac)
    end

    hit.InputBegan:Connect(function(input)
        if isPress(input) then
            dragging = true
            tween(knob, { Size = UDim2.fromOffset(16, 16) }, 0.15, Enum.EasingStyle.Back)
            tween(knobGlow, { Size = UDim2.fromOffset(44, 44), ImageTransparency = 0.7 }, 0.15)
            updateFromX(pointerPosition().X)
        end
    end)

    self.Window:_listen("Changed", function(input)
        if dragging and isMove(input) then
            updateFromX(pointerPosition().X)
        end
    end)
    self.Window:_listen("Ended", function(input)
        if dragging and isPress(input) then
            dragging = false
            tween(knob, { Size = UDim2.fromOffset(12, 12) }, 0.2)
            tween(knobGlow, { Size = UDim2.fromOffset(28, 28), ImageTransparency = 0.85 }, 0.2)
            safeCall(opts.OnRelease, self_.Value)
        end
    end)

    self_.Value = snap(self_.Value)
    render(0)
    task.defer(fitChip, true)
    local handle = finishElement(self, opts, self_, frame, "Slider")
    safeCall(opts.OnInit, self_.Value)
    return handle
end

function Tab:Input(opts)
    local frame, frameStroke, titleLabel, descLabel
    opts, frame, frameStroke, titleLabel, descLabel = beginElement(self, opts, "Frame", 184, "Input")
    local metrics = metricsOf(self)
    local compact = metrics.Compact
    local boxHeight = compact and metrics.Chip + 2 or 30

    local boxHolder = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, compact and -14 or -10, 0.5, 0),
        Size = UDim2.fromOffset(120, boxHeight),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = frame,
    })
    corner(boxHolder, UDim.new(0, 6))
    local boxStroke = stroke(boxHolder)
    local box = create("TextBox", {
        Position = UDim2.fromOffset(8, 0),
        Size = UDim2.new(1, -16, 1, 0),
        BackgroundTransparency = 1,
        Text = tostring(opts.Default or ""),
        PlaceholderText = opts.Placeholder or "",
        PlaceholderColor3 = Theme.Muted,
        TextColor3 = Theme.Text,
        TextSize = compact and 13 or 14,
        FontFace = Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        TextTruncate = Enum.TextTruncate.None,
        ClipsDescendants = true,
        Parent = boxHolder,
    })

    local lastText = box.Text
    local focused = false
    local function fitBox(instant)
        local width
        if compact then
            width = rowControlWidth(frame, self.Window) * 0.75
        else
            width = 130
        end
        width = math.max(math.floor(width), 90) + (focused and 8 or 0)
        reserveRight(titleLabel, descLabel, width + (compact and 24 or 20))
        if instant then
            boxHolder.Size = UDim2.fromOffset(width, boxHeight)
        else
            tween(boxHolder, { Size = UDim2.fromOffset(width, boxHeight) }, 0.18)
        end
    end
    local lastWidth = 0
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if frame.AbsoluteSize.X ~= lastWidth then
            lastWidth = frame.AbsoluteSize.X
            fitBox(true)
        end
    end)
    task.defer(fitBox, true)

    box.Focused:Connect(function()
        focused = true
        tween(boxStroke, { Color = Theme.StrokeHover }, 0.15)
        fitBox(false)
    end)
    box.FocusLost:Connect(function(enterPressed)
        focused = false
        tween(boxStroke, { Color = Theme.Stroke }, 0.15)
        fitBox(false)
        if opts.Numeric then
            local number = tonumber(box.Text)
            if not number then
                box.Text = lastText
                return
            end
            lastText = box.Text
            safeCall(opts.Callback, number, enterPressed)
            return
        end
        lastText = box.Text
        safeCall(opts.Callback, box.Text, enterPressed)
    end)

    return finishElement(self, opts, {
        Set = function(_, newValue)
            box.Text = tostring(newValue)
            lastText = box.Text
            flashStroke(frameStroke)
        end,
        Get = function()
            if opts.Numeric then
                return tonumber(box.Text)
            end
            return box.Text
        end,
    }, frame, "Input")
end

-- Dropdown: a value chip that opens a floating list over the window.
function Tab:Dropdown(opts)
    local frame, frameStroke, titleLabel, descLabel
    opts, frame, frameStroke, titleLabel, descLabel = beginElement(self, opts, "TextButton", 170, "Dropdown")
    local window = self.Window
    local metrics = metricsOf(self)
    local compact = metrics.Compact
    local options = opts.Options or {}
    local current = opts.Default or options[1]

    local chip = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, compact and -14 or -10, 0.5, 0),
        Size = UDim2.fromOffset(130, metrics.Chip + 2),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(chip, UDim.new(0, 6))
    local chipStroke = stroke(chip)
    local valueLabel = label({
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -32, 1, 0),
        Text = tostring(current or ""),
        TextSize = compact and 13 or 14,
        FontFace = Fonts.Regular,
        Parent = chip,
    })
    local arrow = label({
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        Text = "›",
        TextSize = 20,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
        Rotation = 90,
        Parent = chip,
    })

    local function fitChip()
        local width = math.clamp(math.floor(frame.AbsoluteSize.X / window.Scale.Scale * 0.46), 110, 200)
        chip.Size = UDim2.fromOffset(width, metrics.Chip + 2)
        reserveRight(titleLabel, descLabel, width + 24)
    end
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitChip)
    task.defer(fitChip)

    local self_: any = { Value = current, Open = false }
    local popupClose: any = nil

    local function setValue(value, silent)
        self_.Value = value
        valueLabel.Text = tostring(value)
        if not silent then
            safeCall(opts.Callback, value)
        end
    end

    function self_:Set(value, silent)
        if value == self_.Value then
            return
        end
        setValue(value, silent)
        flashStroke(frameStroke)
    end
    function self_:Get()
        return self_.Value
    end
    function self_:SetOpen(state)
        if not state and popupClose then
            popupClose()
        end
    end

    local function open()
        if window._dropdown then
            window._dropdown()
        end
        local body = window.Body
        local scale = window.Scale.Scale
        local overlay = create("TextButton", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 60,
            Parent = body,
        })
        local optionH = metrics.Option
        local rows = math.min(#options, 7)
        local height = rows * optionH + math.max(rows - 1, 0) * 2 + 12
        local width = math.max(chip.AbsoluteSize.X / scale, 130)
        local abs = (chip.AbsolutePosition - body.AbsolutePosition) / scale
        local x = math.clamp(abs.X + chip.AbsoluteSize.X / scale - width, 8, body.AbsoluteSize.X / scale - width - 8)
        local y = abs.Y + chip.AbsoluteSize.Y / scale + 6
        local bodyH = body.AbsoluteSize.Y / scale
        if y + height > bodyH - 8 then
            y = math.max(abs.Y - height - 6, 8)
        end
        local popup = create("Frame", {
            Position = UDim2.fromOffset(x, y - 4),
            Size = UDim2.fromOffset(width, height),
            BackgroundTransparency = 1,
            ZIndex = 61,
            Parent = overlay,
        })
        local shadow = create("ImageLabel", {
            Position = UDim2.fromOffset(-18, -12),
            Size = UDim2.new(1, 36, 1, 36),
            BackgroundTransparency = 1,
            Image = Assets.Shadow,
            ImageColor3 = Color3.new(0, 0, 0),
            ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Slice,
            SliceCenter = Rect.new(49, 49, 450, 450),
            ZIndex = 61,
            Parent = popup,
        })
        local panel = create("CanvasGroup", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Theme.Background,
            BorderSizePixel = 0,
            GroupTransparency = 1,
            ZIndex = 62,
            Parent = popup,
        })
        corner(panel, UDim.new(0, 10))
        stroke(panel, Theme.Stroke)
        local list = create("ScrollingFrame", {
            Position = UDim2.fromOffset(6, 6),
            Size = UDim2.new(1, -12, 1, -12),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Accent,
            ScrollBarImageTransparency = 0.4,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(),
            ZIndex = 63,
            Parent = panel,
        })
        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = list })
        for index, option in ipairs(options) do
            local selected = option == self_.Value
            local row = create("TextButton", {
                Size = UDim2.new(1, 0, 0, optionH),
                BackgroundColor3 = Theme.Surface3,
                BackgroundTransparency = selected and 0.6 or 1,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = index,
                ZIndex = 64,
                Parent = list,
            })
            corner(row, UDim.new(0, 6))
            label({
                Position = UDim2.fromOffset(10, 0),
                Size = UDim2.new(1, -30, 1, 0),
                Text = tostring(option),
                TextSize = 13,
                TextColor3 = selected and Theme.Accent or Theme.Text,
                ZIndex = 65,
                Parent = row,
            })
            if selected then
                local dot = create("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -10, 0.5, 0),
                    Size = UDim2.fromOffset(6, 6),
                    BackgroundColor3 = Theme.Accent,
                    BorderSizePixel = 0,
                    ZIndex = 65,
                    Parent = row,
                })
                corner(dot, UDim.new(1, 0))
            end
            row.MouseEnter:Connect(function()
                if not selected then
                    tween(row, { BackgroundTransparency = 0.7 }, 0.1)
                end
            end)
            row.MouseLeave:Connect(function()
                if not selected then
                    tween(row, { BackgroundTransparency = 1 }, 0.15)
                end
            end)
            row.MouseButton1Click:Connect(function()
                if popupClose then
                    popupClose()
                end
                if option ~= self_.Value then
                    setValue(option)
                    flashStroke(frameStroke)
                end
            end)
        end

        local closed = false
        popupClose = function()
            if closed then
                return
            end
            closed = true
            self_.Open = false
            popupClose = nil
            window._dropdown = nil
            tween(arrow, { Rotation = 90, TextColor3 = Theme.Muted }, 0.25, Enum.EasingStyle.Quint)
            tween(chipStroke, { Color = Theme.Stroke }, 0.2)
            tween(panel, { GroupTransparency = 1 }, 0.15)
            tween(popup, { Position = UDim2.fromOffset(x, y - 4) }, 0.15)
            tween(shadow, { ImageTransparency = 1 }, 0.15)
            task.delay(0.17, function()
                overlay:Destroy()
            end)
        end
        window._dropdown = popupClose
        overlay.MouseButton1Click:Connect(function()
            if popupClose then
                popupClose()
            end
        end)
        self_.Open = true
        tween(arrow, { Rotation = 270, TextColor3 = Theme.Accent }, 0.3, Enum.EasingStyle.Quint)
        tween(chipStroke, { Color = Theme.StrokeHover }, 0.12)
        tween(panel, { GroupTransparency = 0 }, 0.18)
        tween(popup, { Position = UDim2.fromOffset(x, y) }, 0.25, Enum.EasingStyle.Quint)
        tween(shadow, { ImageTransparency = 0.6 }, 0.25)
    end

    frame.MouseButton1Click:Connect(function()
        if self_.Open then
            if popupClose then
                popupClose()
            end
        else
            open()
        end
    end)

    local handle = finishElement(self, opts, self_, frame, "Dropdown")
    safeCall(opts.OnInit, self_.Value)
    return handle
end

local KEY_NAMES = {
    [Enum.KeyCode.LeftControl] = "LCtrl", [Enum.KeyCode.RightControl] = "RCtrl",
    [Enum.KeyCode.LeftShift] = "LShift", [Enum.KeyCode.RightShift] = "RShift",
    [Enum.KeyCode.LeftAlt] = "LAlt", [Enum.KeyCode.RightAlt] = "RAlt",
    [Enum.KeyCode.Return] = "Enter", [Enum.KeyCode.Escape] = "Esc",
    [Enum.KeyCode.Backspace] = "Backspace",
}
local function keyName(keyCode)
    if keyCode == nil then
        return "None"
    end
    return KEY_NAMES[keyCode] or keyCode.Name
end

function Tab:Keybind(opts)
    local frame, frameStroke
    opts, frame, frameStroke = beginElement(self, opts, "TextButton", 110, "Keybind")
    local window = self.Window
    local metrics = metricsOf(self)
    local key = opts.Default
    if type(key) == "string" then
        key = Enum.KeyCode[key]
    end

    local chip = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, metrics.Compact and -14 or -10, 0.5, 0),
        Size = UDim2.fromOffset(0, metrics.Chip),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(chip, UDim.new(0, 6))
    local chipStroke = stroke(chip)
    padding(chip, 10, 10)
    local text_ = label({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = keyName(key),
        TextSize = 13,
        TextColor3 = Theme.Accent,
        TextTruncate = Enum.TextTruncate.None,
        Parent = chip,
    })

    local self_: any = { Value = key }
    local listening, connection = false, nil
    local function stop()
        listening = false
        if connection then
            connection:Disconnect()
            connection = nil
        end
        tween(chipStroke, { Color = Theme.Stroke }, 0.2)
        text_.Text = keyName(self_.Value)
    end
    function self_:Set(value, silent)
        if type(value) == "string" then
            value = Enum.KeyCode[value]
        end
        self_.Value = value
        text_.Text = keyName(value)
        if not silent then
            safeCall(opts.OnChanged or opts.Callback, value)
        end
    end
    function self_:Get()
        return self_.Value
    end
    frame.MouseButton1Click:Connect(function()
        if listening then
            stop()
            return
        end
        listening = true
        text_.Text = "..."
        tween(chipStroke, { Color = Theme.Accent }, 0.12)
        connection = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Keyboard then
                return
            end
            window._consumedKey = input.KeyCode
            window._consumedAt = os.clock()
            if input.KeyCode ~= Enum.KeyCode.Escape then
                self_:Set(input.KeyCode)
            end
            stop()
        end)
    end)
    return finishElement(self, opts, self_, frame, "Keybind")
end

-- ---------------------------------------------------------------------------
-- Containers
-- ---------------------------------------------------------------------------
local function buildContainer(owner, parent, top)
    local list = create("ScrollingFrame", {
        Position = UDim2.fromOffset(0, top),
        Size = UDim2.new(1, 0, 1, -top),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.32,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        Parent = parent,
    })
    padding(list, 22, 22, 8, 28)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 11),
        Parent = list,
    })
    owner.List = list
    owner._items = {}
    owner._groupboxes = {}
    return list
end

function Tab:_columns()
    if self._columnSet then
        return self._columnSet
    end
    local holder = create("Frame", {
        Name = "Columns",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 100000,
        Parent = self.List,
    })
    local layout = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        Parent = holder,
    })
    local function column(order)
        local frame = create("Frame", {
            Size = UDim2.new(0.5, -5, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = order,
            Parent = holder,
        })
        create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 10),
            Parent = frame,
        })
        return frame
    end
    local set = { Holder = holder, Left = column(1), Right = column(2), Counts = { 0, 0 }, Stacked = false }
    local window = self.Window
    local function relayout()
        local width = holder.AbsoluteSize.X / window.Scale.Scale
        if width <= 0 then
            return
        end
        local stacked = width < STACK_BELOW
        if stacked == set.Stacked then
            return
        end
        set.Stacked = stacked
        layout.FillDirection = stacked and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
        local size = stacked and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -5, 0, 0)
        set.Left.Size = size
        set.Right.Size = size
    end
    holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
    task.defer(relayout)
    self._columnSet = set
    return set
end

function Tab:Groupbox(opts)
    if self._groupbox then
        return self.Parent:Groupbox(opts)
    end
    opts = normalize(opts)
    local window = self.Window
    local set = self:_columns()
    local side = opts.Side
    if side == "Left" or side == 1 then
        side = 1
    elseif side == "Right" or side == 2 then
        side = 2
    else
        side = set.Counts[1] <= set.Counts[2] and 1 or 2
    end
    set.Counts[side] += 1

    local box = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        LayoutOrder = set.Counts[side],
        Parent = side == 1 and set.Left or set.Right,
    })
    box:SetAttribute("NoDrag", true)
    corner(box, UDim.new(0, 12))
    stroke(box, Theme.Stroke, 0.22)
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = box })

    local header = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 1,
        Parent = box,
    })
    corner(header, UDim.new(0, 10))
    local headerFill = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 10),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = header,
    })
    local titleX = 14
    if opts.Icon and resolveIcon(opts.Icon) then
        iconImage(header, opts.Icon, Theme.Accent, 14, {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), ZIndex = 2,
        })
        titleX = 37
    end
    local chevron = label({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, -21, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        Text = "›",
        TextSize = 22,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
        Rotation = 90,
        ZIndex = 2,
        Parent = header,
    })
    label({
        Position = UDim2.fromOffset(titleX, 0),
        Size = UDim2.new(1, -(titleX + 40), 1, 0),
        Text = opts.Name or "Groupbox",
        TextSize = 13,
        FontFace = Fonts.Bold,
        ZIndex = 2,
        Parent = header,
    })

    local rule = create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        Parent = box,
    })
    local body = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        LayoutOrder = 3,
        Parent = box,
    })
    local inner = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = body,
    })
    padding(inner, 0, 0, 8, 10)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        Parent = inner,
    })

    local group = setmetatable({
        Name = opts.Name or "Groupbox",
        Window = window,
        Parent = self,
        List = inner,
        Frame = box,
        _order = 0,
        _groupbox = true,
        _metrics = METRICS.Row,
        _items = {},
    }, Tab)
    table.insert(self._groupboxes, group)

    local collapsed = false
    local generation = 0
    local function setCollapsed(value, instant)
        value = value == true
        if value == collapsed then
            return
        end
        collapsed = value
        generation += 1
        local current = generation
        local duration = instant and 0 or 0.32
        if value then
            for _, element in ipairs(group._items) do
                if element.Open and type(element.SetOpen) == "function" then
                    element:SetOpen(false)
                end
            end
        end
        local scale = window.Scale.Scale
        if value then
            body.AutomaticSize = Enum.AutomaticSize.None
            body.Size = UDim2.new(1, 0, 0, body.AbsoluteSize.Y / scale)
            tween(body, { Size = UDim2.new(1, 0, 0, 0) }, duration, Enum.EasingStyle.Quint)
            task.delay(duration, function()
                if generation == current and collapsed then
                    rule.Visible = false
                    headerFill.Visible = false
                end
            end)
        else
            rule.Visible = true
            headerFill.Visible = true
            tween(body, { Size = UDim2.new(1, 0, 0, inner.AbsoluteSize.Y / scale) }, duration, Enum.EasingStyle.Quint)
            task.delay(duration, function()
                if generation == current and not collapsed then
                    body.AutomaticSize = Enum.AutomaticSize.Y
                    body.Size = UDim2.new(1, 0, 0, 0)
                end
            end)
        end
        tween(chevron, { Rotation = value and 0 or 90 }, instant and 0 or 0.3, Enum.EasingStyle.Quint)
    end

    header.MouseEnter:Connect(function()
        tween(chevron, { TextColor3 = Theme.Text }, 0.15)
    end)
    header.MouseLeave:Connect(function()
        tween(chevron, { TextColor3 = Theme.Muted }, 0.25)
    end)
    local isTap = tapGuard(header, function()
        return box:FindFirstAncestorWhichIsA("ScrollingFrame")
    end)
    header.MouseButton1Click:Connect(function()
        if isTap() then
            setCollapsed(not collapsed)
        end
    end)

    function group:SetCollapsed(value, instant)
        setCollapsed(value, instant)
    end
    return group
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------
local Window = {}
Window.__index = Window

local function fadeSlideIn(group)
    group.GroupTransparency = 1
    group.Position = UDim2.fromOffset(0, 14)
    group.Visible = true
    tween(group, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.32, Enum.EasingStyle.Quint)
end

local function popIn(object, delay)
    object.Visible = false
    task.delay(delay, function()
        if not object.Parent then
            return
        end
        local scaleObject = create("UIScale", { Scale = 0.94, Parent = object })
        object.Visible = true
        tween(scaleObject, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
        task.delay(0.4, function()
            scaleObject:Destroy()
        end)
    end)
end

function Window:_syncRenderConnection()
    local active = not self._destroyed and self.Open and not self.Minimized
        and self.Root and self.Root.Visible and self.Home and self.CurrentTab == self.Home
    if active and not self._renderConnection then
        self._renderConnection = RunService.RenderStepped:Connect(function(...)
            for _, listener in ipairs(self._inputListeners.Render) do
                listener(...)
            end
        end)
    elseif not active and self._renderConnection then
        self._renderConnection:Disconnect()
        self._renderConnection = nil
    end
end

function Window:_listen(kind, handler)
    table.insert(self._inputListeners[kind], handler)
    -- The optional live dashboard only needs frame sampling while visible.
    if kind == "Render" then
        self:_syncRenderConnection()
    end
end

function Window:_fitToScreen()
    local view = self.Gui.AbsoluteSize
    local fit = math.min(1, (view.X * 0.96) / WINDOW_WIDTH, (view.Y * 0.94) / WINDOW_HEIGHT)
    -- Permit a little more down-scaling on narrow mobile screens instead of
    -- forcing the window past the viewport edges.
    self._fitScale = math.max(fit, 0.35)
    self.Scale.Scale = self._fitScale * self._userScale
    task.defer(function()
        if not self._destroyed then
            self:_clampToViewport()
            self:_clampIslandToViewport()
        end
    end)
end

function Window:SetUIScale(value)
    self._userScale = math.clamp(tonumber(value) or 1, 0.6, 1.4)
    self.Scale.Scale = self._fitScale * self._userScale
    task.defer(function()
        if not self._destroyed then
            self:_clampToViewport()
        end
    end)
end

function Window:_clampToViewport()
    local root, gui = self.Root, self.Gui
    if root.AnchorPoint ~= Vector2.zero then
        return
    end
    local view, size = gui.AbsoluteSize, root.AbsoluteSize
    local position = root.Position
    root.Position = UDim2.fromOffset(
        math.clamp(position.X.Offset, 0, math.max(view.X - size.X, 0)),
        math.clamp(position.Y.Offset, 0, math.max(view.Y - size.Y, 0))
    )
end

function Window:_setIslandPosition(position)
    local island = self.Island
    if not island then
        return
    end
    local view, size = self.Gui.AbsoluteSize, island.AbsoluteSize
    local x = math.clamp(position.X, 0, math.max(view.X - size.X, 0))
    local y = math.clamp(position.Y, 0, math.max(view.Y - size.Y, 0))
    self._islandPosition = Vector2.new(x, y)
    if self.Minimized then
        island.AnchorPoint = Vector2.zero
        island.Position = UDim2.fromOffset(x, y)
    end
end

function Window:_clampIslandToViewport()
    if self._islandPosition then
        self:_setIslandPosition(self._islandPosition)
    end
end

function Window:Center()
    if self._destroyed then
        return
    end
    self.Root.AnchorPoint = Vector2.new(0.5, 0.5)
    self.Root.Position = UDim2.fromScale(0.5, 0.5)
end

function Window:SetKeybind(keyCode)
    self.Keybind = keyCode
end

-- Tooltip: shown after a short hover, holds an element's description.
function Window:_attachTooltip(frame, text)
    local hoverId = 0
    frame.MouseEnter:Connect(function()
        hoverId += 1
        local id = hoverId
        task.delay(0.5, function()
            if id ~= hoverId or self._destroyed or not self.Open then
                return
            end
            self:_hideTooltip()
            local scale = self.Scale.Scale
            local tip = create("Frame", {
                Size = UDim2.new(0, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                ZIndex = 70,
                Parent = self.Body,
            })
            corner(tip, UDim.new(0, 8))
            stroke(tip, Theme.Stroke)
            padding(tip, 10, 10, 7, 7)
            create("UISizeConstraint", { MaxSize = Vector2.new(240, math.huge), Parent = tip })
            label({
                Size = UDim2.new(0, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.XY,
                Text = text,
                TextSize = 12,
                FontFace = Fonts.Regular,
                TextColor3 = Theme.Muted,
                TextWrapped = true,
                TextTruncate = Enum.TextTruncate.None,
                ZIndex = 71,
                Parent = tip,
            })
            local p = (pointerPosition() - self.Body.AbsolutePosition) / scale
            tip.Position = UDim2.fromOffset(math.clamp(p.X + 12, 8, self.Body.AbsoluteSize.X / scale - 250), p.Y + 16)
            self._tooltip = tip
        end)
    end)
    frame.MouseLeave:Connect(function()
        hoverId += 1
        self:_hideTooltip()
    end)
end

function Window:_hideTooltip()
    if self._tooltip then
        self._tooltip:Destroy()
        self._tooltip = nil
    end
end

function Library.Window(opts)
    opts = opts or {}
    local self = setmetatable({
        Tabs = {},
        CurrentTab = nil,
        Open = true,
        Minimized = false,
        Keybind = opts.Keybind or Enum.KeyCode.RightControl,
        _connections = {},
        _destroyHooks = {},
        _inputListeners = { Began = {}, Changed = {}, Ended = {}, Render = {} },
        _searchIndex = {},
        _destroyed = false,
        Title = opts.Title or "igkii",
        _userScale = 1,
        _fitScale = 1,
    }, Window)

    local function dispatch(kind)
        return function(...)
            for _, handler in ipairs(self._inputListeners[kind]) do
                handler(...)
            end
        end
    end
    table.insert(self._connections, UserInputService.InputBegan:Connect(dispatch("Began")))
    table.insert(self._connections, UserInputService.InputChanged:Connect(dispatch("Changed")))
    table.insert(self._connections, UserInputService.InputEnded:Connect(dispatch("Ended")))

    local gui = create("ScreenGui", {
        Name = opts.Name or "igkiiUI",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    self.Gui = gui

    local root = create("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(WINDOW_WIDTH, WINDOW_HEIGHT),
        BackgroundTransparency = 1,
        Parent = gui,
    })
    self.Root = root
    self.Scale = create("UIScale", { Parent = root })

    local shadow = create("ImageLabel", {
        Position = UDim2.fromOffset(-25, -25),
        Size = UDim2.new(1, 50, 1, 50),
        BackgroundTransparency = 1,
        Image = Assets.Shadow,
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.6,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        Parent = root,
    })
    self.Shadow = shadow

    local body = create("Frame", {
        Name = "Body",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 2,
        Parent = root,
    })
    self.Body = body
    corner(body, UDim.new(0, 12))
    self.BodyStroke = stroke(body, Theme.Stroke, 0.18, 1)
    body.MouseEnter:Connect(function()
        calibratePointer(root)
    end)

    -- Sidebar: a flush rail with one hairline against the content.
    local sidebar = create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = body,
    })
    local sidebarFill = create("Frame", {
        Name = "Fill",
        Size = UDim2.new(1, 24, 1, 0),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = sidebar,
    })
    corner(sidebarFill, UDim.new(0, 10))
    create("Frame", {
        Name = "Divider",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = sidebar,
    })

    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
        BackgroundTransparency = 1,
        Parent = sidebar,
    })
    -- The header logo is the player's own avatar (headshot) instead of a fixed letter.
    local function logoMark(parent, size, position)
        local mark = create("ImageLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = position,
            Size = UDim2.fromOffset(size, size),
            BackgroundColor3 = Theme.Surface3,
            BorderSizePixel = 0,
            Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150",
            ScaleType = Enum.ScaleType.Crop,
            Parent = parent,
        })
        corner(mark, UDim.new(0, math.floor(size * 0.3)))
        stroke(mark, Theme.Accent, 0.35)
        return mark
    end
    logoMark(header, 32, UDim2.new(0, 14, 0.5, 0))
    self._logoMark = logoMark
    local subtitle = opts.Subtitle
    label({
        Position = UDim2.new(0, 56, 0.5, subtitle and -15 or -9),
        Size = UDim2.new(1, -68, 0, 18),
        Text = self.Title,
        TextSize = 14,
        FontFace = Fonts.Bold,
        Parent = header,
    })
    if subtitle then
        label({
            Position = UDim2.new(0, 56, 0.5, 3),
            Size = UDim2.new(1, -68, 0, 14),
            Text = tostring(subtitle),
            TextSize = 11,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            Parent = header,
        })
    end

    local tabList = create("ScrollingFrame", {
        Name = "Tabs",
        Position = UDim2.fromOffset(0, HEADER_HEIGHT),
        Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + PROFILE_HEIGHT + 4)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        Parent = sidebar,
    })
    self.TabList = tabList
    local indicator = create("Frame", {
        Position = UDim2.fromOffset(8, 2),
        Size = UDim2.new(1, -16, 0, TAB_TILE_HEIGHT),
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        Visible = false,
        Parent = tabList,
    })
    corner(indicator, UDim.new(0, 9))
    local indicatorRail = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(3, 20),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = indicator,
    })
    corner(indicatorRail, UDim.new(1, 0))
    self.Indicator = indicator
    self.IndicatorRail = indicatorRail
    local stack = create("Frame", {
        Name = "Stack",
        Position = UDim2.fromOffset(8, 2),
        Size = UDim2.new(1, -16, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = tabList,
    })
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = stack })
    self._tabStack = stack

    self:_buildProfile(sidebar)

    local content = create("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(SIDEBAR_WIDTH + 1, 0),
        Size = UDim2.new(1, -(SIDEBAR_WIDTH + 1), 1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = body,
    })
    self.Content = content
    self._outLayer = create("CanvasGroup", {
        Name = "TransitionOut", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Visible = false, ZIndex = 2, Parent = content,
    })
    self._inLayer = create("CanvasGroup", {
        Name = "TransitionIn", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Visible = false, ZIndex = 3, Parent = content,
    })

    -- Minimize: a bare glyph, muted at rest, full colour and slightly smaller on hover.
    local minimizeButton = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 14),
        Size = UDim2.fromOffset(34, 34),
        BackgroundColor3 = Theme.Surface2,
        BackgroundTransparency = 0.3,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 5,
        Parent = content,
    })
    corner(minimizeButton, UDim.new(0, 9))
    local minimizeStroke = stroke(minimizeButton, Theme.Stroke, 0.35)
    minimizeButton:SetAttribute("NoDrag", true)
    local glyph = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(14, 2),
        BackgroundColor3 = Theme.Muted,
        BorderSizePixel = 0,
        Parent = minimizeButton,
    })
    corner(glyph, UDim.new(1, 0))
    minimizeButton.MouseEnter:Connect(function()
        tween(minimizeButton, { BackgroundTransparency = 0.05 }, 0.16, Enum.EasingStyle.Quint)
        tween(minimizeStroke, { Color = Theme.StrokeHover, Transparency = 0 }, 0.16)
        tween(glyph, { BackgroundColor3 = Theme.Accent, Size = UDim2.fromOffset(12, 2) }, 0.2, Enum.EasingStyle.Quint)
    end)
    minimizeButton.MouseLeave:Connect(function()
        tween(minimizeButton, { BackgroundTransparency = 0.3 }, 0.22, Enum.EasingStyle.Quint)
        tween(minimizeStroke, { Color = Theme.Stroke, Transparency = 0.35 }, 0.22)
        tween(glyph, { BackgroundColor3 = Theme.Muted, Size = UDim2.fromOffset(14, 2) }, 0.25, Enum.EasingStyle.Quint)
    end)
    minimizeButton.MouseButton1Click:Connect(function()
        self:Minimize()
    end)

    self:_buildSearch(content)
    -- Familiar search access without adding a permanent keyboard-help control.
    self:_listen("Began", function(input, processed)
        if processed or not self.Open or input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end
        local commandHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
            or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta)
            or UserInputService:IsKeyDown(Enum.KeyCode.RightMeta)
        if input.KeyCode == Enum.KeyCode.F and commandHeld and self.SearchBox then
            self.SearchBox:CaptureFocus()
        end
    end)

    local notifyHolder = create("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -22, 1, -22),
        Size = UDim2.new(0, 300, 1, -44),
        BackgroundTransparency = 1,
        Parent = gui,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 4),
        Parent = notifyHolder,
    })
    self.NotifyHolder = notifyHolder
    self._notifyOrder = 0
    self._toasts = {}

    self:_enableDrag()

    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, processed)
        if processed or input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode ~= self.Keybind then
            return
        end
        task.defer(function()
            local consumed = self._consumedKey == input.KeyCode and os.clock() - (self._consumedAt or 0) < 0.2
            self._consumedKey = nil
            if not consumed and not self._destroyed then
                if self.Minimized then
                    self:Restore()
                else
                    self:Toggle(not self.Open)
                end
            end
        end)
    end))

    gui.Parent = mountParent()
    self:_fitToScreen()
    table.insert(self._connections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:_fitToScreen()
    end))
    self:_createToggleButton()
    table.insert(Library.Windows, self)

    self._introDone = false
    root.Visible = false
    -- The window stays hidden until PlayIntro runs. Scripts used to have to call it
    -- by hand; it now runs by itself once the script has finished adding its tabs
    -- (PlayIntro only ever plays once, so a manual call is still harmless).
    task.defer(function()
        if self._destroyed then
            return
        end
        local loaded, detail
        if self._autoLoad then
            loaded, detail = Library:RunAutoLoad()
        end
        self:PlayIntro()
        if loaded then
            self:Notify({ Title = "Config loaded", Content = tostring(detail) .. " was loaded automatically", Type = "Success", Duration = 3 })
        end
    end)
    return self
end

-- Dragging: press anywhere on the window that is not a control.
function Window:_enableDrag()
    local dragging, dragStart, startPos = false, nil, nil
    local root, gui = self.Root, self.Gui
    local function overControl(point)
        for _, object in ipairs(gui:GetGuiObjectsAtPosition(point.X, point.Y)) do
            local node = object
            while node and node ~= root do
                if node:GetAttribute("NoDrag") or node:IsA("TextBox") then
                    return true
                end
                node = node.Parent
            end
        end
        return false
    end
    self:_listen("Began", function(input)
        if not self.Open or self.Minimized or not isPress(input) or UserInputService:GetFocusedTextBox() then
            return
        end
        if self._dropdown or self._dialog then
            return
        end
        local point = pointerPosition()
        if not pointInside(point, root) or overControl(point) then
            return
        end
        dragging = true
        dragStart = point
        local abs = root.AbsolutePosition - gui.AbsolutePosition
        local scale = self.Scale.Scale
        root.AnchorPoint = Vector2.zero
        root.Position = UDim2.fromOffset(abs.X, abs.Y)
        startPos = abs
        self._dragScale = scale
    end)
    self:_listen("Changed", function(input)
        if not dragging or not isMove(input) then
            return
        end
        local delta = pointerPosition() - dragStart
        local view = gui.AbsoluteSize
        local size = root.AbsoluteSize
        root.Position = UDim2.fromOffset(
            math.clamp(startPos.X + delta.X, 0, math.max(view.X - size.X, 0)),
            math.clamp(startPos.Y + delta.Y, 0, math.max(view.Y - size.Y, 0))
        )
    end)
    self:_listen("Ended", function(input)
        if isPress(input) then
            dragging = false
        end
    end)
end

-- Profile card at the foot of the sidebar.
function Window:_setGameTitle(title)
    if type(title) == "string" and title ~= "" then
        self._gameTitle = title
    elseif type(self._gameTitle) ~= "string" or self._gameTitle == "" then
        self._gameTitle = game.Name
    end
    if self._islandTitle then
        self._islandTitle.Text = self._gameTitle
        if self._islandPosition then
            task.defer(function()
                if not self._destroyed then
                    self:_clampIslandToViewport()
                end
            end)
        end
    end
end

function Window:_buildProfile(sidebar)
    create("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -PROFILE_HEIGHT),
        Size = UDim2.new(1, -20, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Parent = sidebar,
    })
    local cardFrame = create("TextButton", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -8),
        Size = UDim2.new(1, -16, 0, PROFILE_HEIGHT - 16),
        BackgroundColor3 = Theme.Surface2,
        Text = "",
        AutoButtonColor = false,
        Parent = sidebar,
    })
    corner(cardFrame, UDim.new(0, 10))
    local cardStroke = stroke(cardFrame, Theme.Stroke, 0.22)
    local head = create("ImageLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 8, 0.5, 0),
        Size = UDim2.fromOffset(36, 36),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150",
        Parent = cardFrame,
    })
    corner(head, UDim.new(1, 0))
    self._avatarImages = { head }
    local online = create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, 1, 1, 1),
        Size = UDim2.fromOffset(9, 9),
        BackgroundColor3 = Theme.Success,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = head,
    })
    corner(online, UDim.new(1, 0))
    stroke(online, Theme.Surface2, 0, 2)
    self._nameLabels = {}
    local name = label({
        Position = UDim2.new(0, 52, 0.5, -16),
        Size = UDim2.new(1, -78, 0, 17),
        Text = player.DisplayName,
        TextSize = 13,
        FontFace = Fonts.Bold,
        Parent = cardFrame,
    })
    table.insert(self._nameLabels, { name, player.DisplayName })
    local gameLabel = label({
        Position = UDim2.new(0, 52, 0.5, 2),
        Size = UDim2.new(1, -78, 0, 14),
        Text = "…",
        TextSize = 11,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = cardFrame,
    })
    local chevron = label({
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(14, 20),
        Text = "›",
        TextSize = 22,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
        Parent = cardFrame,
    })
    task.spawn(function()
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfo(game.PlaceId)
        end)
        self:_setGameTitle(ok and info and info.Name)
        gameLabel.Text = self._gameTitle
    end)
    cardFrame.MouseEnter:Connect(function()
        if usingTouch() then
            return
        end
        tween(cardStroke, { Color = Theme.StrokeHover }, 0.12)
        tween(chevron, { TextColor3 = Theme.Text, Position = UDim2.new(1, -6, 0.5, 0) }, 0.15)
    end)
    cardFrame.MouseLeave:Connect(function()
        tween(cardStroke, { Color = Theme.Stroke }, 0.2)
        tween(chevron, { TextColor3 = Theme.Muted, Position = UDim2.new(1, -8, 0.5, 0) }, 0.2)
    end)
    cardFrame.MouseButton1Click:Connect(function()
        if self.Home then
            self:SelectTab(self.Home)
        end
    end)
    cardFrame:SetAttribute("NoDrag", true)
end

-- Search: icon and text on a thin baseline; results float under it.
function Window:_buildSearch(content)
    local holder = create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -56, 0, 14),
        Size = UDim2.fromOffset(SEARCH_WIDTH, 36),
        BackgroundColor3 = Theme.Surface2,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = content,
    })
    corner(holder, UDim.new(0, 9))
    local holderStroke = stroke(holder, Theme.Stroke, 0.25)
    holder:SetAttribute("NoDrag", true)
    local baseline = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 10, 1, -1),
        Size = UDim2.new(1, -20, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = holder,
    })
    local focusLine = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -1),
        Size = UDim2.new(0, 0, 0, 2),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = holder,
    })
    corner(focusLine, UDim.new(1, 0))
    local icon = iconImage(holder, "search", Theme.Muted, 15, {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, -1),
    })
    local box = create("TextBox", {
        Position = UDim2.fromOffset(icon and 26 or 2, 0),
        Size = UDim2.new(1, icon and -28 or -4, 1, -2),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = TOUCH and "Search controls..." or "Search controls · Ctrl+F",
        PlaceholderColor3 = Theme.Muted,
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClearTextOnFocus = false,
        Parent = holder,
    })
    holder.MouseEnter:Connect(function()
        if not box:IsFocused() then
            tween(holderStroke, { Color = Theme.StrokeHover, Transparency = 0.05 }, 0.15)
        end
    end)
    holder.MouseLeave:Connect(function()
        if not box:IsFocused() then
            tween(holderStroke, { Color = Theme.Stroke, Transparency = 0.25 }, 0.25)
        end
    end)
    self.SearchBox = box

    local rowHeight = TOUCH and 40 or 34
    local popup = create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Size = UDim2.fromOffset(300, 0),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 45,
        Parent = self.Body,
    })
    popup:SetAttribute("NoDrag", true)
    local panel = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 45,
        Parent = popup,
    })
    corner(panel, UDim.new(0, 10))
    stroke(panel, Theme.Stroke)
    local list = create("ScrollingFrame", {
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.new(1, -12, 1, -12),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.4,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        ZIndex = 46,
        Parent = panel,
    })
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = list })

    local function hidePopup()
        popup.Visible = false
    end
    local function jump(entry)
        hidePopup()
        box.Text = ""
        self:SelectTab(entry.Tab)
        task.delay(0.4, function()
            local frame = entry.Frame
            if not frame.Parent then
                return
            end
            local scroller = entry.Tab.List
            local target = frame.AbsolutePosition.Y - scroller.AbsolutePosition.Y + scroller.CanvasPosition.Y - 24
            scroller.CanvasPosition = Vector2.new(0, math.max(target, 0))
            local flash = create("Frame", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = Theme.Accent,
                BackgroundTransparency = 0.8,
                BorderSizePixel = 0,
                ZIndex = frame.ZIndex + 5,
                Parent = frame,
            })
            corner(flash)
            tween(flash, { BackgroundTransparency = 1 }, 0.9)
            task.delay(0.95, function()
                flash:Destroy()
            end)
        end)
    end
    local function refresh()
        local query = string.lower(box.Text)
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        if query == "" then
            hidePopup()
            return
        end
        local shown = 0
        for _, entry in ipairs(self._searchIndex) do
            local hay = string.lower(entry.Name .. " " .. (entry.Desc or "") .. " " .. entry.Tab.Name)
            if string.find(hay, query, 1, true) and entry.Frame.Parent then
                shown += 1
                if shown > 8 then
                    break
                end
                local row = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, rowHeight),
                    BackgroundColor3 = Theme.Surface3,
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    Text = "",
                    AutoButtonColor = false,
                    LayoutOrder = shown,
                    ZIndex = 47,
                    Parent = list,
                })
                corner(row, UDim.new(0, 6))
                label({
                    Position = UDim2.fromOffset(10, 0),
                    Size = UDim2.new(1, -110, 1, 0),
                    Text = entry.Name,
                    TextSize = 13,
                    ZIndex = 48,
                    Parent = row,
                })
                label({
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -10, 0, 0),
                    Size = UDim2.new(0, 90, 1, 0),
                    Text = entry.Tab.Name,
                    TextSize = 11,
                    FontFace = Fonts.Regular,
                    TextColor3 = Theme.Muted,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 48,
                    Parent = row,
                })
                row.MouseEnter:Connect(function()
                    tween(row, { BackgroundTransparency = 0.6 }, 0.1)
                end)
                row.MouseLeave:Connect(function()
                    tween(row, { BackgroundTransparency = 1 }, 0.15)
                end)
                row.MouseButton1Click:Connect(function()
                    jump(entry)
                end)
            end
        end
        if shown == 0 then
            hidePopup()
            return
        end
        shown = math.min(shown, 8)
        local scale = self.Scale.Scale
        local abs = (holder.AbsolutePosition - self.Body.AbsolutePosition) / scale
        popup.Position = UDim2.fromOffset(abs.X + SEARCH_WIDTH, abs.Y + 40)
        popup.Size = UDim2.fromOffset(300, shown * rowHeight + (shown - 1) * 2 + 12)
        popup.Visible = true
    end
    box:GetPropertyChangedSignal("Text"):Connect(refresh)
    box.Focused:Connect(function()
        tween(focusLine, { Size = UDim2.new(1, -20, 0, 2) }, 0.25, Enum.EasingStyle.Quint)
        tween(holderStroke, { Color = Theme.Accent, Transparency = 0 }, 0.16)
        tween(baseline, { BackgroundTransparency = 1 }, 0.12)
        if icon then
            tween(icon, { ImageColor3 = Theme.Accent }, 0.16)
        end
    end)
    box.FocusLost:Connect(function()
        tween(focusLine, { Size = UDim2.new(0, 0, 0, 2) }, 0.2, Enum.EasingStyle.Quint)
        tween(holderStroke, { Color = Theme.Stroke, Transparency = 0.25 }, 0.2)
        tween(baseline, { BackgroundTransparency = 0.55 }, 0.2)
        if icon then
            tween(icon, { ImageColor3 = Theme.Muted }, 0.2)
        end
        task.delay(0.2, hidePopup)
    end)
    self._resetSearch = function()
        box.Text = ""
        hidePopup()
    end
end

-- Tabs ----------------------------------------------------------------------
function Window:_indicatorY(tab)
    local stack = self._tabStack
    return (tab._button.AbsolutePosition.Y - stack.AbsolutePosition.Y) / self.Scale.Scale + stack.Position.Y.Offset
end

function Window:_placeIndicator(tab)
    local indicator = self.Indicator
    local targetY = self:_indicatorY(tab)
    if not indicator.Visible then
        indicator.Visible = true
        indicator.Position = UDim2.fromOffset(8, targetY)
        indicator.BackgroundTransparency = 1
        tween(indicator, { BackgroundTransparency = 0.18 }, 0.3)
    end
    tween(indicator, { Position = UDim2.fromOffset(8, targetY) }, 0.45, Enum.EasingStyle.Quint)
end

function Window:Tab(opts)
    opts = normalize(opts)
    local tab = setmetatable({
        Name = opts.Name or "Tab",
        Window = self,
        _order = 0,
    }, Tab)

    local button = create("TextButton", {
        Size = UDim2.new(1, 0, 0, TAB_TILE_HEIGHT),
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = #self.Tabs + 1,
        Parent = self._tabStack,
    })
    button:SetAttribute("NoDrag", true)
    corner(button, UDim.new(0, 9))
    tab._button = button

    local tabIcon = opts.Icon and iconImage(button, opts.Icon, Theme.Muted, 16, {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 20, 0.5, 0),
    })
    tab._icon = tabIcon
    tab._label = label({
        Position = UDim2.fromOffset(tabIcon and 38 or 14, 0),
        Size = UDim2.new(1, tabIcon and -46 or -22, 1, 0),
        Text = tab.Name,
        TextSize = 13,
        TextColor3 = Theme.Muted,
        Parent = button,
    })

    local page = create("Frame", {
        Name = tab.Name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = self.Content,
    })
    tab._page = page
    local titleX = 24
    if tabIcon and opts.Icon then
        iconImage(page, opts.Icon, Theme.Accent, 20, {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 24, 0, 32),
        })
        titleX = 54
    end
    label({
        Position = UDim2.fromOffset(titleX, 20),
        Size = UDim2.new(1, -(titleX + 270), 0, 24),
        Text = opts.PageTitle or tab.Name,
        TextSize = 23,
        FontFace = Fonts.Bold,
        Parent = page,
    })
    if opts.Desc then
        local descLabel = label({
            Position = UDim2.fromOffset(titleX, 44),
            Size = UDim2.new(1, -(titleX + 270), 0, 16),
            Text = opts.Desc,
            TextSize = 12,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            Parent = page,
        })
        -- opts.NamePrefix marks a description that ends with the player's name, so a
        -- fake name replaces it as well.
        if opts.NamePrefix and self._nameLabels then
            table.insert(self._nameLabels, { descLabel, opts.NamePrefix .. player.DisplayName, opts.NamePrefix })
            if self._fakeName then
                descLabel.Text = opts.NamePrefix .. self._fakeName
            end
        end
    end
    local contentTop = opts.Desc and 82 or 68
    create("Frame", {
        Name = "HeaderDivider",
        Position = UDim2.fromOffset(22, contentTop - 1),
        Size = UDim2.new(1, -44, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Parent = page,
    })
    buildContainer(tab, page, contentTop)

    local pressScale = create("UIScale", { Parent = button })
    local function release()
        tween(pressScale, { Scale = 1 }, 0.3, Enum.EasingStyle.Quint)
    end
    button.MouseEnter:Connect(function()
        if self.CurrentTab ~= tab and not usingTouch() then
            tween(button, { BackgroundTransparency = 0.55 }, 0.2, Enum.EasingStyle.Quint)
            tween(tab._label, { TextColor3 = Theme.Text }, 0.2)
            if tab._icon then
                tween(tab._icon, { ImageColor3 = Theme.Text }, 0.2)
            end
        end
    end)
    button.MouseLeave:Connect(function()
        release()
        if self.CurrentTab ~= tab then
            tween(button, { BackgroundTransparency = 1 }, 0.3, Enum.EasingStyle.Quint)
            tween(tab._label, { TextColor3 = Theme.Muted }, 0.3)
            if tab._icon then
                tween(tab._icon, { ImageColor3 = Theme.Muted }, 0.3)
            end
        end
    end)
    button.MouseButton1Down:Connect(function()
        tween(pressScale, { Scale = 0.97 }, 0.15, Enum.EasingStyle.Quint)
    end)
    button.MouseButton1Up:Connect(release)
    local isTap = tapGuard(button, function()
        return self.TabList
    end)
    button.MouseButton1Click:Connect(function()
        release()
        if isTap() then
            self:SelectTab(tab)
        end
    end)

    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then
        task.defer(function()
            if not self.CurrentTab then
                self:SelectTab(tab)
            end
        end)
    end
    return tab
end

function Window:_settleOut()
    local page = self._outPage
    if page then
        page.Parent = self.Content
        page.Visible = false
        self._outPage = nil
    end
    self._outLayer.Visible = false
end

function Window:_settleIn()
    local page = self._inPage
    if page then
        page.Parent = self.Content
        page.Position = UDim2.fromOffset(0, 0)
        self._inPage = nil
    end
    self._inLayer.Visible = false
end

function Window:SelectTab(tab)
    if self.CurrentTab == tab then
        return
    end
    local previous = self.CurrentTab
    if self._resetSearch then
        self._resetSearch()
    end
    if self._dropdown then
        self._dropdown()
    end
    self.CurrentTab = tab
    self:_settleOut()
    self:_settleIn()
    local generation = (self._transitionGeneration or 0) + 1
    self._transitionGeneration = generation

    if previous then
        tween(previous._label, { TextColor3 = Theme.Muted }, 0.3)
        if previous._icon then
            tween(previous._icon, { ImageColor3 = Theme.Muted }, 0.3)
        end
        local outLayer = self._outLayer
        previous._page.Parent = outLayer
        self._outPage = previous._page
        outLayer.GroupTransparency = 0
        outLayer.Position = UDim2.fromOffset(0, 0)
        outLayer.Visible = true
        tween(outLayer, { GroupTransparency = 1, Position = UDim2.fromOffset(0, -6) }, 0.2, Enum.EasingStyle.Quint)
        task.delay(0.18, function()
            if self._transitionGeneration == generation then
                self:_settleOut()
            end
        end)
    end

    self:_syncRenderConnection()

    tween(tab._button, { BackgroundTransparency = 1 }, 0.2)
    tween(tab._label, { TextColor3 = Theme.Accent }, 0.3)
    if tab._icon then
        tween(tab._icon, { ImageColor3 = Theme.Accent }, 0.3)
    end
    self:_placeIndicator(tab)

    local page = tab._page
    page.Position = UDim2.fromOffset(0, 0)
    page.Visible = true
    page.Parent = self._inLayer
    self._inPage = page
    fadeSlideIn(self._inLayer)
    task.delay(0.32, function()
        if self._transitionGeneration == generation then
            self:_settleIn()
        end
    end)
end

-- Notifications ---------------------------------------------------------------
function Window:Notify(opts)
    opts = normalize(opts)
    opts.Content = opts.Content or opts.Text
    local duration = opts.Duration or 4
    -- Resolve this at display time so notifications follow live theme changes.
    local titleColor = notificationColor(opts.Type)

    self._notifyOrder += 1
    local outer = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        LayoutOrder = self._notifyOrder,
        Parent = self.NotifyHolder,
    })
    local slide = create("Frame", {
        Position = UDim2.fromOffset(320, 0),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = outer,
    })
    local shadow = create("ImageLabel", {
        Position = UDim2.fromOffset(-20, -20),
        Size = UDim2.new(1, 40, 1, 40),
        BackgroundTransparency = 1,
        Image = Assets.Shadow,
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 0,
        Parent = slide,
    })
    local toast = create("CanvasGroup", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Parent = slide,
    })
    corner(toast, UDim.new(0, 10))
    local toastStroke = stroke(toast, Theme.Stroke)
    local inner = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = toast,
    })
    padding(inner, 16, 16, 14, 24)
    label({
        Size = UDim2.new(1, -28, 0, 16),
        Text = opts.Title or "Notification",
        TextSize = 14,
        TextColor3 = titleColor,
        Parent = inner,
    })
    local closeButton = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 6, 0, -5),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        Text = "×",
        TextColor3 = Theme.Muted,
        TextSize = 22,
        FontFace = Fonts.Bold,
        AutoButtonColor = false,
        Parent = inner,
    })
    closeButton.MouseEnter:Connect(function()
        tween(closeButton, { TextColor3 = Theme.Text }, 0.15)
    end)
    closeButton.MouseLeave:Connect(function()
        tween(closeButton, { TextColor3 = Theme.Muted }, 0.2)
    end)
    if opts.Content then
        label({
            Position = UDim2.fromOffset(0, 21),
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = opts.Content,
            TextSize = 13,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = inner,
        })
    end
    local track = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 16, 1, -8),
        Size = UDim2.new(1, -32, 0, 3),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = toast,
    })
    corner(track, UDim.new(1, 0))
    local progress = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(progress, UDim.new(1, 0))

    task.defer(function()
        if outer.Parent then
            tween(outer, { Size = UDim2.new(1, 0, 0, toast.AbsoluteSize.Y) }, 0.3, Enum.EasingStyle.Quint)
        end
    end)
    tween(slide, { Position = UDim2.fromOffset(0, 0) }, 0.5, Enum.EasingStyle.Back)
    tween(toast, { GroupTransparency = 0 }, 0.3)
    tween(shadow, { ImageTransparency = 0.6 }, 0.4)
    tween(progress, { Size = UDim2.fromScale(0, 1) }, duration, Enum.EasingStyle.Linear)

    local dismissed = false
    local function dismiss()
        if dismissed then
            return
        end
        dismissed = true
        for index, entry in ipairs(self._toasts) do
            if entry == dismiss then
                table.remove(self._toasts, index)
                break
            end
        end
        tween(slide, { Position = UDim2.fromOffset(320, 0) }, 0.3, Enum.EasingStyle.Quint)
        tween(toast, { GroupTransparency = 1 }, 0.2)
        tween(toastStroke, { Transparency = 1 }, 0.15)
        tween(shadow, { ImageTransparency = 1 }, 0.2)
        task.delay(0.22, function()
            outer.ClipsDescendants = true
            tween(outer, { Size = UDim2.new(1, 0, 0, -4) }, 0.22, Enum.EasingStyle.Quint)
            task.delay(0.24, function()
                outer:Destroy()
            end)
        end)
    end
    task.delay(duration, dismiss)
    closeButton.MouseButton1Click:Connect(dismiss)
    table.insert(self._toasts, dismiss)
    while #self._toasts > 4 do
        local oldest = table.remove(self._toasts, 1)
        if oldest then
            oldest()
        end
    end
    return { Dismiss = dismiss }
end

-- Dialog / Confirm --------------------------------------------------------------
function Window:Dialog(opts)
    opts = normalize(opts)
    if self._dialog then
        self._dialog.Close()
    end
    local WIDTH, PAD = 300, 18
    local overlay = create("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 80,
        Parent = self.Body,
    })
    local cardFrame = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 10),
        Size = UDim2.fromOffset(WIDTH, 120),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 81,
        Parent = overlay,
    })
    corner(cardFrame, UDim.new(0, 10))
    local cardStroke = stroke(cardFrame, Theme.Stroke, 1)
    local cardScale = create("UIScale", { Scale = 0.94, Parent = cardFrame })
    local fading = {}

    local title = label({
        Position = UDim2.fromOffset(PAD, PAD),
        Size = UDim2.new(1, -PAD * 2, 0, 18),
        Text = opts.Title or "Are you sure?",
        TextSize = 15,
        TextTransparency = 1,
        ZIndex = 82,
        Parent = cardFrame,
    })
    table.insert(fading, { title, "TextTransparency", 0 })

    local contentHeight = 0
    if opts.Content then
        local content = label({
            Position = UDim2.fromOffset(PAD, PAD + 24),
            Size = UDim2.new(1, -PAD * 2, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = opts.Content,
            TextSize = 13,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            TextWrapped = true,
            TextTransparency = 1,
            TextTruncate = Enum.TextTruncate.None,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 82,
            Parent = cardFrame,
        })
        table.insert(fading, { content, "TextTransparency", 0 })
        contentHeight = 34
        content:GetPropertyChangedSignal("TextBounds"):Connect(function()
            contentHeight = math.max(content.TextBounds.Y, 16) + 6
            cardFrame.Size = UDim2.fromOffset(WIDTH, PAD + 24 + contentHeight + 12 + 34 + PAD)
            local rowFrame = cardFrame:FindFirstChild("ButtonRow")
            if rowFrame then
                rowFrame.Position = UDim2.fromOffset(PAD, PAD + 24 + contentHeight + 12)
            end
        end)
    end

    local row = create("Frame", {
        Name = "ButtonRow",
        Position = UDim2.fromOffset(PAD, PAD + 24 + contentHeight + 12),
        Size = UDim2.new(1, -PAD * 2, 0, 34),
        BackgroundTransparency = 1,
        ZIndex = 82,
        Parent = cardFrame,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = row,
    })
    cardFrame.Size = UDim2.fromOffset(WIDTH, PAD + 24 + contentHeight + 12 + 34 + PAD)

    local dialog = {}
    local closed = false
    function dialog.Close()
        if closed then
            return
        end
        closed = true
        if self._dialog == dialog then
            self._dialog = nil
        end
        tween(overlay, { BackgroundTransparency = 1 }, 0.18)
        tween(cardFrame, { BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 8) }, 0.18, Enum.EasingStyle.Quint)
        tween(cardScale, { Scale = 0.96 }, 0.18, Enum.EasingStyle.Quint)
        tween(cardStroke, { Transparency = 1 }, 0.12)
        for _, entry in ipairs(fading) do
            tween(entry[1], { [entry[2]] = 1 }, 0.12)
        end
        task.delay(0.2, function()
            overlay:Destroy()
        end)
    end

    for index, spec in ipairs(opts.Buttons or {}) do
        local primary = spec.Variant == "Primary"
        local buttonFrame = create("TextButton", {
            Size = UDim2.fromOffset(0, 34),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = primary and Theme.Accent or Theme.Surface2,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            LayoutOrder = index,
            ZIndex = 83,
            Parent = row,
        })
        corner(buttonFrame, UDim.new(0, 7))
        local buttonStroke = stroke(buttonFrame, primary and Theme.Accent or Theme.Stroke, 1)
        padding(buttonFrame, 14, 14)
        local text = label({
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = spec.Title or "OK",
            TextSize = 13,
            TextColor3 = primary and Theme.AccentDark or Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTransparency = 1,
            ZIndex = 84,
            Parent = buttonFrame,
        })
        local restBg = primary and 0.12 or 0
        local restStroke = primary and 0.4 or 0
        table.insert(fading, { buttonFrame, "BackgroundTransparency", restBg })
        table.insert(fading, { buttonStroke, "Transparency", restStroke })
        table.insert(fading, { text, "TextTransparency", 0 })
        buttonFrame.MouseEnter:Connect(function()
            if closed then
                return
            end
            if primary then
                tween(buttonFrame, { BackgroundTransparency = 0 }, 0.12)
                tween(buttonStroke, { Transparency = 0 }, 0.12)
            else
                tween(buttonStroke, { Color = Theme.StrokeHover }, 0.12)
            end
        end)
        buttonFrame.MouseLeave:Connect(function()
            if closed then
                return
            end
            if primary then
                tween(buttonFrame, { BackgroundTransparency = restBg }, 0.2)
                tween(buttonStroke, { Transparency = restStroke }, 0.2)
            else
                tween(buttonStroke, { Color = Theme.Stroke }, 0.2)
            end
        end)
        buttonFrame.MouseButton1Click:Connect(function()
            dialog.Close()
            safeCall(spec.Callback)
        end)
    end

    overlay.MouseButton1Click:Connect(function()
        dialog.Close()
        safeCall(opts.OnCancel)
    end)

    self._dialog = dialog
    tween(overlay, { BackgroundTransparency = 0.45 }, 0.25)
    tween(cardFrame, { BackgroundTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }, 0.3, Enum.EasingStyle.Quint)
    tween(cardStroke, { Transparency = 0 }, 0.25)
    tween(cardScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
    for _, entry in ipairs(fading) do
        tween(entry[1], { [entry[2]] = entry[3] }, 0.25)
    end
    return dialog
end

function Window:Confirm(opts)
    opts = normalize(opts)
    return self:Dialog({
        Title = opts.Title or "Are you sure?",
        Content = opts.Content,
        OnCancel = opts.OnCancel,
        Buttons = {
            { Title = opts.CancelText or "Cancel", Callback = opts.OnCancel },
            { Title = opts.ConfirmText or "Confirm", Variant = "Primary", Callback = opts.Callback },
        },
    })
end

-- Show / hide / minimize -------------------------------------------------------
function Window:Toggle(open)
    if self._destroyed then
        return
    end
    self.Open = open == true
    self._hideToken = (self._hideToken or 0) + 1
    self:_hideTooltip()
    local root = self.Root
    if self.Open then
        root.Visible = true
        self.Scale.Scale = self._fitScale * self._userScale * 0.94
        tween(self.Scale, { Scale = self._fitScale * self._userScale }, 0.35, Enum.EasingStyle.Back)
        tween(self.Shadow, { ImageTransparency = 0.6 }, 0.3)
        tween(self.BodyStroke, { Transparency = 0 }, 0.3)
    else
        tween(self.Scale, { Scale = self._fitScale * self._userScale * 0.94 }, 0.2, Enum.EasingStyle.Quint)
        tween(self.Shadow, { ImageTransparency = 1 }, 0.2)
        local token = self._hideToken
        task.delay(0.2, function()
            if token == self._hideToken and (not self.Open or self.Minimized) then
                root.Visible = false
            end
        end)
    end
    self:_syncRenderConnection()
    self:_refreshToggleButton()
end

function Window:_buildIsland()
    local island = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, -50),
        Size = UDim2.fromOffset(0, 40),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 20,
        Parent = self.Gui,
    })
    corner(island, UDim.new(1, 0))
    local islandStroke = stroke(island, Theme.Stroke)
    padding(island, 8, 18)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = island,
    })
    local restoreButton = create("TextButton", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 1,
        ZIndex = 21,
        Parent = island,
    })
    local row = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Parent = restoreButton,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        Parent = row,
    })
    local gameIcon = create("ImageLabel", {
        Size = UDim2.fromOffset(30, 30),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Image = "rbxthumb://type=GameIcon&id=" .. game.GameId .. "&w=150&h=150",
        ScaleType = Enum.ScaleType.Fit,
        LayoutOrder = 1,
        Parent = row,
    })
    corner(gameIcon, UDim.new(0, 7))
    stroke(gameIcon)
    self._islandTitle = label({
        Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Text = self._gameTitle or game.Name,
        TextSize = 13, FontFace = Fonts.Bold, TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2, Parent = row,
    })
    island.MouseEnter:Connect(function()
        tween(islandStroke, { Color = Theme.StrokeHover }, 0.12)
    end)
    island.MouseLeave:Connect(function()
        tween(islandStroke, { Color = Theme.Stroke }, 0.25)
    end)

    local moveHandle = create("TextButton", {
        Name = "Move island handle",
        Size = UDim2.fromOffset(32, 32),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "Move island",
        TextTransparency = 1,
        AutoButtonColor = false,
        LayoutOrder = 2,
        ZIndex = 21,
        Parent = island,
    })
    local moveIconParts = {}
    local function addMoveIconPart(size, x, y, rotation)
        local part = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, x, 0.5, y),
            Size = UDim2.fromOffset(size.X, size.Y),
            Rotation = rotation or 0,
            BackgroundColor3 = Theme.Muted,
            BorderSizePixel = 0,
            ZIndex = 22,
            Parent = moveHandle,
        })
        corner(part, UDim.new(1, 0))
        table.insert(moveIconParts, part)
    end
    addMoveIconPart(Vector2.new(14, 3), 0, 0, 0)
    addMoveIconPart(Vector2.new(3, 14), 0, 0, 0)
    addMoveIconPart(Vector2.new(7, 3), -2.5, -7.5, -45)
    addMoveIconPart(Vector2.new(7, 3), 2.5, -7.5, 45)
    addMoveIconPart(Vector2.new(7, 3), -2.5, 7.5, 45)
    addMoveIconPart(Vector2.new(7, 3), 2.5, 7.5, -45)
    addMoveIconPart(Vector2.new(7, 3), -7.5, -2.5, -45)
    addMoveIconPart(Vector2.new(7, 3), -7.5, 2.5, 45)
    addMoveIconPart(Vector2.new(7, 3), 7.5, -2.5, 45)
    addMoveIconPart(Vector2.new(7, 3), 7.5, 2.5, -45)
    moveHandle.MouseEnter:Connect(function()
        for _, part in ipairs(moveIconParts) do
            tween(part, { BackgroundColor3 = Theme.Text }, 0.12)
        end
    end)
    moveHandle.MouseLeave:Connect(function()
        for _, part in ipairs(moveIconParts) do
            tween(part, { BackgroundColor3 = Theme.Muted }, 0.2)
        end
    end)

    local function pointerForInput(input)
        if input and input.UserInputType == Enum.UserInputType.Touch then
            return Vector2.new(input.Position.X, input.Position.Y) + pointerShift
        end
        return pointerPosition()
    end

    local dragging, dragged = false, false
    local dragPointer, dragOrigin
    local function beginIslandDrag(input)
        if not isPress(input) then
            return
        end
        dragging, dragged = true, false
        dragPointer = pointerForInput(input)
        dragOrigin = island.AbsolutePosition - self.Gui.AbsolutePosition
    end
    restoreButton.InputBegan:Connect(beginIslandDrag)
    moveHandle.InputBegan:Connect(beginIslandDrag)
    restoreButton.Activated:Connect(function()
        if not dragged then
            self:Restore()
        end
    end)
    self:_listen("Changed", function(input)
        if not dragging or not isMove(input) then
            return
        end
        local point = pointerForInput(input)
        local delta = point - dragPointer
        if delta.Magnitude <= 4 then
            return
        end
        dragged = true
        self:_setIslandPosition(dragOrigin + delta)
    end)
    self:_listen("Ended", function(input)
        if dragging and isPress(input) then
            dragging = false
        end
    end)

    self.Island = island
end

function Window:Minimize()
    if self.Minimized or self._destroyed then
        return
    end
    if not self.Island then
        self:_buildIsland()
    end
    self.Minimized = true
    self:Toggle(false)
    self.Open = true
    local island = self.Island
    island.Visible = true
    local targetPosition
    if self._islandPosition then
        self:_setIslandPosition(self._islandPosition)
        targetPosition = island.Position
        island.Position = UDim2.fromOffset(self._islandPosition.X, self._islandPosition.Y - 50)
    else
        island.AnchorPoint = Vector2.new(0.5, 0)
        island.Position = UDim2.new(0.5, 0, 0, -50)
        targetPosition = UDim2.new(0.5, 0, 0, 14)
    end
    tween(island, { Position = targetPosition }, 0.5, Enum.EasingStyle.Back)
end

function Window:Restore()
    if not self.Minimized then
        return
    end
    self.Minimized = false
    self.Island.Visible = false
    self:Toggle(true)
end

-- Floating button for touch devices.
function Window:_createToggleButton()
    local size = 50
    local button = create("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 18 + size / 2, 0.5, 0),
        Size = UDim2.fromOffset(size, size),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 30,
        Parent = self.Gui,
    })
    corner(button, UDim.new(0, 12))
    stroke(button, Theme.Stroke)
    self._logoMark(button, 24, UDim2.new(0.5, -12, 0.5, 0))
    self.ToggleButton = button
    local dragging, moved, grab = false, false, Vector2.zero
    button.InputBegan:Connect(function(input)
        if isPress(input) then
            dragging, moved = true, false
            grab = pointerPosition() - button.AbsolutePosition
        end
    end)
    self:_listen("Changed", function(input)
        if not dragging or not isMove(input) then
            return
        end
        local point = pointerPosition() - grab - self.Gui.AbsolutePosition
        if (point - (button.AbsolutePosition - self.Gui.AbsolutePosition)).Magnitude > 3 then
            moved = true
        end
        if moved then
            button.AnchorPoint = Vector2.zero
            button.Position = UDim2.fromOffset(
                math.clamp(point.X, 0, math.max(self.Gui.AbsoluteSize.X - size, 0)),
                math.clamp(point.Y, 0, math.max(self.Gui.AbsoluteSize.Y - size, 0))
            )
        end
    end)
    self:_listen("Ended", function(input)
        if not dragging or not isPress(input) then
            return
        end
        dragging = false
        if moved then
            return
        end
        ripple(button)
        if not self.Open then
            self:Toggle(true)
        elseif self.Minimized then
            self:Restore()
        else
            self:Minimize()
        end
    end)
end

function Window:_refreshToggleButton()
    if self.ToggleButton then
        self.ToggleButton.Visible = TOUCH
    end
end

function Window:PlayIntro()
    if self._introDone or self._destroyed then
        return
    end
    self._introDone = true
    local root = self.Root
    root.Visible = true
    self:_syncRenderConnection()
    self.Scale.Scale = self._fitScale * self._userScale * 0.9
    root.Position = UDim2.new(0.5, 0, 0.5, 24)
    self.Shadow.ImageTransparency = 1
    self.BodyStroke.Transparency = 1
    tween(self.Scale, { Scale = self._fitScale * self._userScale }, 0.5, Enum.EasingStyle.Back)
    tween(root, { Position = UDim2.fromScale(0.5, 0.5) }, 0.5, Enum.EasingStyle.Quint)
    tween(self.BodyStroke, { Transparency = 0 }, 0.35)
    tween(self.Shadow, { ImageTransparency = 0.6 }, 0.5)
    for index, tab in ipairs(self.Tabs) do
        popIn(tab._button, 0.1 + index * 0.05)
    end
    self.Indicator.Visible = false
    task.delay(0.15 + #self.Tabs * 0.05, function()
        if self.CurrentTab then
            self:_placeIndicator(self.CurrentTab)
        end
    end)
    local current = self.CurrentTab
    if current then
        local index = 0
        local function reveal(child)
            popIn(child, 0.25 + index * 0.035)
            index += 1
        end
        local columns = current._columnSet
        for _, child in ipairs(current.List:GetChildren()) do
            if child:IsA("GuiObject") then
                if columns and child == columns.Holder then
                    for _, column in ipairs({ columns.Left, columns.Right }) do
                        for _, boxFrame in ipairs(column:GetChildren()) do
                            if boxFrame:IsA("GuiObject") then
                                reveal(boxFrame)
                            end
                        end
                    end
                else
                    reveal(child)
                end
            end
        end
    end
end

-- Registers a cleanup that runs once when the window is destroyed (feature loops,
-- connections, anything a script started on the window's behalf).
function Window:OnDestroy(callback)
    if type(callback) == "function" then
        table.insert(self._destroyHooks, callback)
    end
end

function Window:Destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true
    for index = #self._destroyHooks, 1, -1 do
        safeCall(self._destroyHooks[index])
    end
    table.clear(self._destroyHooks)
    self:_syncRenderConnection()
    for _, connection in ipairs(self._connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    pcall(function()
        self.Gui:Destroy()
    end)
    for index, window in ipairs(Library.Windows) do
        if window == self then
            table.remove(Library.Windows, index)
            break
        end
    end
end

-- ---------------------------------------------------------------------------
-- Home tab (banner, live performance card, server card, feature status)
-- ---------------------------------------------------------------------------
local function panelCard(parent, height, order)
    local frame = create("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        LayoutOrder = order,
        Parent = parent,
    })
    frame:SetAttribute("NoDrag", true)
    corner(frame, UDim.new(0, 12))
    stroke(frame, Theme.Stroke, 0.22)
    return frame
end

local function homeCard(parent, order)
    local frame = panelCard(parent, 0, order)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    padding(frame, 18, 18, 16, 16)
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
    return frame
end

local function homeCaption(parent, text, order)
    return label({
        Size = UDim2.new(1, 0, 0, 24),
        Text = string.upper(text),
        TextSize = 10,
        FontFace = Fonts.Bold,
        TextColor3 = Theme.Muted,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = order,
        Parent = parent,
    })
end

local function homeChip(parent, order, text, color)
    local chip = create("TextButton", {
        Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = order,
        Parent = parent,
    })
    corner(chip, UDim.new(0, 6))
    local chipStroke = stroke(chip)
    padding(chip, 9, 9)
    local text_ = label({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = text,
        TextSize = 12,
        TextColor3 = color or Theme.Muted,
        TextTruncate = Enum.TextTruncate.None,
        Parent = chip,
    })
    return chip, text_, chipStroke
end

local function homeToggleChip(parent, order, text, initial, callback)
    local chip, text_, chipStroke = homeChip(parent, order, text)
    local on = initial == true
    local function paint(duration)
        tween(chip, { BackgroundColor3 = on and Theme.Accent or Theme.Surface3, BackgroundTransparency = on and 0.85 or 0.2 }, duration)
        tween(chipStroke, { Color = on and Theme.Accent or Theme.Stroke, Transparency = on and 0.6 or 0 }, duration)
        tween(text_, { TextColor3 = on and Theme.Accent or Theme.Muted }, duration)
    end
    paint(0)
    chip.MouseButton1Click:Connect(function()
        on = not on
        paint(0.2)
        safeCall(callback, on)
    end)
    -- The second return repaints the chip without firing the callback, so other
    -- code (the Misc tab) can keep it in sync.
    return chip, function(value)
        value = value == true
        if value ~= on then
            on = value
            paint(0.2)
        end
    end
end

-- Replaces the player's name in every label the window shows it in with any text.
-- nil or an empty string restores the real name. Only this UI is changed.
function Window:SetFakeName(fake)
    if type(fake) ~= "string" or (fake:gsub("%s", "")) == "" then
        fake = nil
    end
    self._fakeName = fake
    for _, entry in ipairs(self._nameLabels or {}) do
        local target = entry[1]
        if target and target.Parent then
            if fake then
                local prefix = entry[3] or (entry[2]:sub(1, 1) == "@" and "@") or ""
                target.Text = prefix .. fake
            else
                target.Text = entry[2]
            end
        end
    end
    if self._nameChipSync then
        self._nameChipSync(fake ~= nil)
    end
end

function Window:SetNameHidden(hidden)
    self:SetFakeName(hidden and (self._fakeNameChoice or "Hidden") or nil)
end

local function homeGraph(parent, order, title, ceiling)
    local cell = create("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
    label({
        Size = UDim2.new(1, 0, 0, 14),
        Text = string.upper(title),
        TextSize = 10,
        TextColor3 = Theme.Muted,
        Parent = cell,
    })
    local value = label({
        Position = UDim2.fromOffset(0, 16),
        Size = UDim2.new(1, 0, 0, 28),
        Text = "…",
        TextSize = 24,
        FontFace = Fonts.Bold,
        Parent = cell,
    })
    local track = create("Frame", {
        Position = UDim2.fromOffset(0, 50),
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        Parent = cell,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = track,
    })
    local COUNT = 24
    local bars, samples = {}, {}
    for index = 1, COUNT do
        local bar = create("Frame", {
            Size = UDim2.new(1 / COUNT, -2, 0, 2),
            BackgroundColor3 = Theme.Surface3,
            BorderSizePixel = 0,
            LayoutOrder = index,
            Parent = track,
        })
        corner(bar, UDim.new(0, 2))
        bars[index] = bar
    end
    local function push(sample, color)
        table.insert(samples, sample)
        if #samples > COUNT then
            table.remove(samples, 1)
        end
        local top = ceiling or 1
        for _, s in ipairs(samples) do
            top = math.max(top, s)
        end
        local offset = COUNT - #samples
        for index, bar in ipairs(bars) do
            local s = samples[index - offset]
            local latest = index == COUNT
            tween(bar, {
                Size = UDim2.new(1 / COUNT, -2, s and math.max(s / top, 0.08) or 0, s and 0 or 2),
                BackgroundColor3 = (latest and color) or (s and Theme.Muted or Theme.Surface3),
                BackgroundTransparency = latest and 0 or (s and 0.6 or 0),
            }, 0.35, Enum.EasingStyle.Quint)
        end
    end
    return value, push
end

local function homeFigure(parent, order, title)
    local cell = create("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
    local value = label({
        Size = UDim2.new(1, -8, 0, 20),
        Text = "…",
        TextSize = 15,
        FontFace = Fonts.Bold,
        Parent = cell,
    })
    label({
        Position = UDim2.fromOffset(0, 21),
        Size = UDim2.new(1, -8, 0, 14),
        Text = string.upper(title),
        TextSize = 10,
        TextColor3 = Theme.Muted,
        Parent = cell,
    })
    return value
end

local function homeAction(parent, order, text, callback)
    local button = create("TextButton", {
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        LayoutOrder = order,
        Parent = parent,
    })
    corner(button, UDim.new(0, 9))
    local buttonStroke = stroke(button, Theme.Stroke, 0.2)
    local text_ = label({
        Size = UDim2.new(1, -8, 1, 0),
        Position = UDim2.fromOffset(4, 0),
        Text = text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = button,
    })
    button.MouseEnter:Connect(function()
        tween(button, { BackgroundTransparency = 0 }, 0.15, Enum.EasingStyle.Quint)
        tween(buttonStroke, { Color = Theme.StrokeHover }, 0.15)
        tween(text_, { TextColor3 = Theme.Accent }, 0.15)
    end)
    button.MouseLeave:Connect(function()
        tween(button, { BackgroundTransparency = 0.5 }, 0.25, Enum.EasingStyle.Quint)
        tween(buttonStroke, { Color = Theme.Stroke }, 0.25)
        tween(text_, { TextColor3 = Theme.Text }, 0.25)
    end)
    button.MouseButton1Click:Connect(function()
        ripple(button)
        safeCall(callback)
    end)
    return button
end

local function copyText(text)
    local env: any = (getgenv and getgenv()) or {}
    local fn = env.setclipboard or env.toclipboard or (env.syn and env.syn.write_clipboard) or (env.Clipboard and env.Clipboard.set)
    if type(fn) ~= "function" then
        return false
    end
    return pcall(fn, tostring(text))
end

local function fetchServers(order)
    local HttpService = game:GetService("HttpService")
    local ok, result = pcall(function()
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100"):format(game.PlaceId, order)
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if ok and type(result) == "table" and type(result.data) == "table" then
        return result.data
    end
    return nil
end

function Window:Rejoin()
    self:Notify({ Title = "Rejoining", Content = "Teleporting back into this server", Duration = 3 })
    task.spawn(function()
        local ok, err = pcall(function()
            if #Players:GetPlayers() <= 1 or game.JobId == "" then
                TeleportService:Teleport(game.PlaceId, player)
            else
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
            end
        end)
        if not ok then
            self:Notify({ Title = "Rejoin failed", Content = tostring(err), Type = "Error", Duration = 4 })
        end
    end)
end

function Window:Hop(order, pick, title)
    task.spawn(function()
        local servers = fetchServers(order)
        if not servers then
            self:Notify({ Title = title .. " failed", Content = "Could not load the server list", Type = "Error", Duration = 4 })
            return
        end
        local candidates = {}
        for _, server in ipairs(servers) do
            if type(server) == "table" and server.id ~= game.JobId and tonumber(server.playing) and tonumber(server.maxPlayers) and server.playing < server.maxPlayers then
                table.insert(candidates, server)
            end
        end
        local target = #candidates > 0 and pick(candidates) or nil
        if not target then
            self:Notify({ Title = title .. " failed", Content = "No other open server found", Type = "Warning", Duration = 4 })
            return
        end
        self:Notify({ Title = title, Content = string.format("Joining a server with %d/%d players", target.playing, target.maxPlayers), Duration = 3 })
        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, target.id, player)
        end)
        if not ok then
            self:Notify({ Title = title .. " failed", Content = tostring(err), Type = "Error", Duration = 4 })
        end
    end)
end

-- features: list of { Name, Get = function() -> bool }, figures: { { Title, Get } }
-- info (optional): { Tier = "text for the banner chip" }
function Window:BuildHome(features, figures, info)
    local tab = self:Tab({
        Name = "Home",
        Icon = "house",
        PageTitle = "Home",
        Desc = "Welcome back, " .. (self._fakeName or player.DisplayName),
        NamePrefix = "Welcome back, ",
    })
    self.Home = tab
    local list = tab.List

    -- Banner ---------------------------------------------------------------
    local banner = panelCard(list, 152, tab:_nextOrder())
    banner.ClipsDescendants = true
    local bannerAccent = create("Frame", {
        Position = UDim2.fromOffset(0, 14),
        Size = UDim2.fromOffset(3, 44),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = banner,
    })
    corner(bannerAccent, UDim.new(1, 0))
    local bust = create("ImageLabel", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, 0),
        Size = UDim2.fromOffset(152, 152),
        BackgroundTransparency = 1,
        Image = "rbxthumb://type=AvatarBust&id=" .. player.UserId .. "&w=420&h=420",
        ScaleType = Enum.ScaleType.Fit,
        Parent = banner,
    })
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.45, 0),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Parent = bust,
    })
    label({
        Position = UDim2.fromOffset(24, 22),
        Size = UDim2.new(1, -200, 0, 14),
        Text = "WELCOME BACK",
        TextSize = 10,
        TextColor3 = Theme.Muted,
        Parent = banner,
    })
    local nameLabel = label({
        Position = UDim2.fromOffset(24, 39),
        Size = UDim2.new(1, -200, 0, 34),
        Text = player.DisplayName,
        TextSize = 26,
        FontFace = Fonts.Bold,
        Parent = banner,
    })
    local userLabel = label({
        Position = UDim2.fromOffset(24, 74),
        Size = UDim2.new(1, -200, 0, 17),
        Text = "@" .. player.Name,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = banner,
    })
    table.insert(self._nameLabels, { nameLabel, player.DisplayName })
    table.insert(self._nameLabels, { userLabel, "@" .. player.Name })
    if self._fakeName then
        self:SetFakeName(self._fakeName)
    end
    local chips = create("Frame", {
        Position = UDim2.new(0, 24, 1, -42),
        Size = UDim2.new(1, -48, 0, 26),
        BackgroundTransparency = 1,
        Parent = banner,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = chips,
    })
    local tierChip, tierText = homeChip(chips, 1, tostring((info and info.Tier) or self.Title), Theme.Accent)
    tierChip.Active = false
    tierText.FontFace = Fonts.Bold
    local _, syncNameChip = homeToggleChip(chips, 2, "Name", self._fakeName ~= nil, function(on)
        self:SetNameHidden(on)
    end)
    self._nameChipSync = syncNameChip
    homeToggleChip(chips, 3, "Avatar", false, function(on)
        tween(bust, { ImageTransparency = on and 1 or 0 }, 0.25)
        for _, image in ipairs(self._avatarImages or {}) do
            tween(image, { ImageTransparency = on and 1 or 0 }, 0.25)
        end
    end)

    -- Performance card -----------------------------------------------------------
    local stats = homeCard(list, tab:_nextOrder())
    homeCaption(stats, "Live performance", 0)
    local graphs = create("Frame", { Size = UDim2.new(1, 0, 0, 76), BackgroundTransparency = 1, LayoutOrder = 1, Parent = stats })
    create("UIGridLayout", {
        CellPadding = UDim2.fromOffset(28, 0),
        CellSize = UDim2.new(0.5, -14, 0, 76),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = graphs,
    })
    create("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, LayoutOrder = 2, Parent = stats })
    local figureHolder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        Parent = stats,
    })
    padding(figureHolder, 0, 0, 12, 0)
    create("UIGridLayout", {
        CellPadding = UDim2.fromOffset(0, 8),
        CellSize = UDim2.new(0.25, 0, 0, 36),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = figureHolder,
    })
    local fpsValue, fpsPush = homeGraph(graphs, 1, "FPS", 60)
    local pingValue, pingPush = homeGraph(graphs, 2, "Ping", 100)
    local playersValue = homeFigure(figureHolder, 1, "Players")
    local sessionValue = homeFigure(figureHolder, 2, "Session")
    local extraValues = {}
    for index, figure in ipairs(figures or {}) do
        extraValues[index] = { Value = homeFigure(figureHolder, 2 + index, figure.Title), Get = figure.Get }
    end

    -- Server + features (stacked at the default width, side by side when wide) ---
    local split = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = tab:_nextOrder(),
        Parent = list,
    })
    local splitLayout = create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12), Parent = split })
    local function column(order)
        local frame = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = order,
            Parent = split,
        })
        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
        return frame
    end
    local leftColumn, rightColumn = column(1), column(2)

    local gameCard = homeCard(leftColumn, 1)
    local head = create("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, LayoutOrder = 1, Parent = gameCard })
    local gameIcon = create("ImageLabel", {
        Size = UDim2.fromOffset(44, 44),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Image = "rbxthumb://type=GameIcon&id=" .. game.GameId .. "&w=150&h=150",
        Parent = head,
    })
    corner(gameIcon, UDim.new(0, 10))
    stroke(gameIcon)
    local gameName = label({
        Position = UDim2.fromOffset(56, 3),
        Size = UDim2.new(1, -56, 0, 20),
        Text = "Loading",
        TextSize = 15,
        FontFace = Fonts.Bold,
        Parent = head,
    })
    local detail = label({
        Position = UDim2.fromOffset(56, 24),
        Size = UDim2.new(1, -56, 0, 16),
        Text = "",
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = head,
    })
    local owner
    task.spawn(function()
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfo(game.PlaceId)
        end)
        self:_setGameTitle(ok and info and info.Name)
        gameName.Text = self._gameTitle
        owner = ok and info and type(info.Creator) == "table" and info.Creator.Name or nil
    end)
    local actions = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = gameCard,
    })
    padding(actions, 0, 0, 12, 0)
    create("UIGridLayout", {
        CellPadding = UDim2.fromOffset(6, 6),
        CellSize = UDim2.new(0.25, -5, 0, 40),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = actions,
    })
    homeAction(actions, 1, "Rejoin", function() self:Rejoin() end)
    homeAction(actions, 2, "Hop", function()
        self:Hop("Desc", function(l) return l[math.random(1, #l)] end, "Server hop")
    end)
    homeAction(actions, 3, "Lowest", function()
        self:Hop("Asc", function(l)
            table.sort(l, function(a, b) return a.playing < b.playing end)
            return l[1]
        end, "Lowest server")
    end)
    homeAction(actions, 4, "Job ID", function()
        local ok = copyText(game.JobId)
        self:Notify({
            Title = ok and "Copied" or "Clipboard unavailable",
            Content = ok and "Job ID" or "Your executor has no setclipboard",
            Type = ok and "Success" or "Error",
            Duration = 2.5,
        })
    end)
    label({
        Size = UDim2.new(1, 0, 0, 26),
        Text = "Job " .. string.sub(game.JobId, 1, 8) .. "  ·  Place " .. game.PlaceId,
        TextSize = 11,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextYAlignment = Enum.TextYAlignment.Bottom,
        LayoutOrder = 3,
        Parent = gameCard,
    })

    local featureCard = homeCard(rightColumn, 1)
    homeCaption(featureCard, "Features", 0)
    local featureStates = {}
    for index, feature in ipairs(features or {}) do
        local row = create("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, LayoutOrder = index, Parent = featureCard })
        if index > 1 then
            create("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, Parent = row })
        end
        label({ Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -70, 1, 0), Text = feature.Name, TextSize = 13, Parent = row })
        local state = label({
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.fromOffset(60, 38),
            Text = "Off",
            TextSize = 12,
            TextColor3 = Theme.Muted,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = row,
        })
        featureStates[index] = { Label = state, Get = feature.Get, Last = nil }
    end

    local function fitSplit()
        local wide = split.AbsoluteSize.X / self.Scale.Scale >= 540
        splitLayout.FillDirection = wide and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
        local size = wide and UDim2.new(0.5, -5, 0, 0) or UDim2.new(1, 0, 0, 0)
        leftColumn.Size = size
        rightColumn.Size = size
    end
    split:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitSplit)
    task.defer(fitSplit)

    -- Live refresh -----------------------------------------------------------
    local frames = 0
    self:_listen("Render", function()
        frames += 1
    end)
    local started = os.clock()
    local function refresh()
        fpsValue.Text = tostring(frames)
        local fpsColor = Library._healthColor(frames, 50, 30)
        tween(fpsValue, { TextColor3 = fpsColor }, 0.3)
        fpsPush(frames, fpsColor)
        frames = 0
        local ok, ping = pcall(function()
            return math.floor(player:GetNetworkPing() * 1000)
        end)
        ping = ok and ping or 0
        pingValue.Text = ping .. "ms"
        local pingColor = Library._healthColor(ping, 90, 180, true)
        tween(pingValue, { TextColor3 = pingColor }, 0.3)
        pingPush(ping, pingColor)
        playersValue.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
        sessionValue.Text = formatDuration(os.clock() - started)
        for _, extra in ipairs(extraValues) do
            local good, text = pcall(extra.Get)
            extra.Value.Text = good and tostring(text) or "-"
        end
        local count = #Players:GetPlayers() .. "/" .. Players.MaxPlayers .. " players"
        detail.Text = owner and ("by " .. owner .. "  ·  " .. count) or count
        for _, entry in ipairs(featureStates) do
            local good, on = pcall(entry.Get)
            on = good and on == true
            if entry.Last ~= on then
                entry.Last = on
                entry.Label.Text = on and "On" or "Off"
                tween(entry.Label, { TextColor3 = on and Theme.Accent or Theme.Muted }, 0.25)
            end
        end
    end
    refresh()
    task.spawn(function()
        while not self._destroyed do
            task.wait(1)
            if self.Open and self.Root.Visible and self.CurrentTab == tab then
                refresh()
            else
                frames = 0
            end
        end
    end)
    return tab
end


-- ---------------------------------------------------------------------------
-- Misc tab: universal character tools (works in any game)
--   local misc = window:BuildMisc()
--   misc.Set("Fly", true)    -- names: GodMode Speed InfiniteJump NoClip Fly HideUsername AntiAFK InstantPrompts
--   misc.Active.Fly          -- true while a feature is on
--   misc.Unload()            -- turn everything off (also runs when the window is destroyed)
--   window:BuildHome(Library.MiscFeatures(function() return misc end))  -- Home list of Misc states
-- ---------------------------------------------------------------------------
Library.MiscFeatureList = {
    { "GodMode", "God Mode" },
    { "Speed", "Movement Speed" },
    { "InfiniteJump", "Infinite Jump" },
    { "NoClip", "No Clip" },
    { "Fly", "Fly" },
    { "HideUsername", "Hide Username" },
    { "AntiAFK", "Anti AFK" },
    { "InstantPrompts", "Instant Prompts" },
}

-- Builds the features list that window:BuildHome expects. getMisc is called lazily,
-- so Home can be created before the Misc tab exists (Home stays the first tab).
function Library.MiscFeatures(getMisc)
    local list = {}
    for _, entry in ipairs(Library.MiscFeatureList) do
        local key = entry[1]
        table.insert(list, {
            Name = entry[2],
            Get = function()
                local misc = getMisc()
                return misc ~= nil and misc.Active[key] == true
            end,
        })
    end
    return list
end

function Window:BuildMisc(opts)
    opts = opts or {}
    local Workspace = game:GetService("Workspace")
    local StarterGui = game:GetService("StarterGui")
    local VirtualUser = game:GetService("VirtualUser")
    local ProximityPromptService = game:GetService("ProximityPromptService")
    local window = self

    local tab = self:Tab({
        Name = opts.Name or "Misc",
        Icon = opts.Icon or "settings",
        PageTitle = opts.Name or "Misc",
        Desc = "Works in every game",
    })

    local active = {}
    local saved = {}
    local bags = {}
    local appliers = {}
    local toggles = {}
    local controls = {}
    local weakKeys = { __mode = "k" }

    -- A bag holds everything one feature started (connections, instances, undo
    -- functions) so it can be torn down in a single call.
    local function hold(name, item)
        local list = bags[name]
        if not list then
            list = {}
            bags[name] = list
        end
        table.insert(list, item)
        return item
    end

    local function clearBag(name)
        local list = bags[name]
        bags[name] = nil
        if not list then
            return
        end
        for _, item in ipairs(list) do
            local kind = typeof(item)
            if kind == "RBXScriptConnection" then
                item:Disconnect()
            elseif kind == "Instance" then
                pcall(item.Destroy, item)
            elseif kind == "function" then
                pcall(item)
            end
        end
    end

    local function humanoid()
        local char = player.Character
        return char and char:FindFirstChildOfClass("Humanoid")
    end

    local function rootPart()
        local char = player.Character
        return char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    end

    local function trimmed(value)
        local text = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
        return text
    end

    local function sliderValue(name, fallback)
        local slider = controls[name]
        local value = slider and slider:Get()
        return tonumber(value) or fallback
    end

    -- God mode ---------------------------------------------------------------
    -- Client side: keeps Humanoid health pinned. It protects against damage the
    -- game applies through the client, not against a server that sets health itself.
    appliers.GodMode = function()
        clearBag("god")
        local hum = humanoid()
        if not active.GodMode then
            local record = saved.health
            if record and hum and record.humanoid == hum and hum.Health > 0 then
                hum.MaxHealth = record.max
                hum.Health = math.min(hum.Health, record.max)
            end
            saved.health = nil
            return
        end
        if not hum then
            return
        end
        if not saved.health or saved.health.humanoid ~= hum then
            saved.health = { humanoid = hum, max = hum.MaxHealth }
        end
        hum.MaxHealth = math.huge
        hum.Health = math.huge
        hold("god", hum.HealthChanged:Connect(function()
            if active.GodMode and hum.Parent and hum.Health > 0 and hum.Health < hum.MaxHealth then
                hum.Health = hum.MaxHealth
            end
        end))
        hold("god", hum:GetPropertyChangedSignal("MaxHealth"):Connect(function()
            if active.GodMode and hum.MaxHealth ~= math.huge then
                hum.MaxHealth = math.huge
                hum.Health = math.huge
            end
        end))
    end

    -- Movement speed ---------------------------------------------------------
    appliers.Speed = function()
        clearBag("speed")
        local hum = humanoid()
        if not active.Speed then
            if hum and saved.walkSpeed then
                hum.WalkSpeed = saved.walkSpeed
            end
            saved.walkSpeed = nil
            return
        end
        if not hum then
            return
        end
        saved.walkSpeed = saved.walkSpeed or hum.WalkSpeed
        hum.WalkSpeed = sliderValue("SpeedSlider", 50)
        hold("speed", hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            local target = sliderValue("SpeedSlider", 50)
            if active.Speed and hum.WalkSpeed ~= target then
                hum.WalkSpeed = target
            end
        end))
    end

    -- Infinite jump ----------------------------------------------------------
    appliers.InfiniteJump = function()
        clearBag("jump")
        if not active.InfiniteJump then
            return
        end
        hold("jump", UserInputService.JumpRequest:Connect(function()
            local hum = humanoid()
            if hum and hum:GetState() ~= Enum.HumanoidStateType.Dead then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end))
    end

    -- No clip ----------------------------------------------------------------
    local clipped = setmetatable({}, weakKeys)
    appliers.NoClip = function()
        clearBag("noclip")
        if not active.NoClip then
            for part in pairs(clipped) do
                if part.Parent then
                    part.CanCollide = true
                end
                clipped[part] = nil
            end
            return
        end
        hold("noclip", RunService.Stepped:Connect(function()
            local char = player.Character
            if not char then
                return
            end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    clipped[part] = true
                    part.CanCollide = false
                end
            end
        end))
    end

    -- Fly --------------------------------------------------------------------
    -- Move with your normal controls; the camera direction decides up and down.
    -- Space rises and Ctrl or Q descends (the jump button rises on mobile).
    local flyJumpUntil = 0
    appliers.Fly = function()
        clearBag("fly")
        local hum = humanoid()
        if hum and saved.platformStand ~= nil then
            hum.PlatformStand = saved.platformStand
        end
        saved.platformStand = nil
        if not active.Fly then
            return
        end
        local root = rootPart()
        if not hum or not root then
            return
        end
        local velocity = Instance.new("BodyVelocity")
        velocity.Name = "igkiiFlyVelocity"
        velocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        velocity.Velocity = Vector3.zero
        velocity.Parent = root
        local gyro = Instance.new("BodyGyro")
        gyro.Name = "igkiiFlyGyro"
        gyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        gyro.P = 9e4
        gyro.D = 500
        gyro.CFrame = root.CFrame
        gyro.Parent = root
        hold("fly", velocity)
        hold("fly", gyro)
        saved.platformStand = hum.PlatformStand
        hum.PlatformStand = true
        hold("fly", UserInputService.JumpRequest:Connect(function()
            flyJumpUntil = os.clock() + 0.2
        end))
        hold("fly", RunService.RenderStepped:Connect(function()
            local cam = Workspace.CurrentCamera
            if not cam or not velocity.Parent then
                return
            end
            local move = hum.MoveDirection
            local direction = Vector3.zero
            if move.Magnitude > 0 then
                local relative = cam.CFrame:VectorToObjectSpace(move)
                direction = cam.CFrame.RightVector * relative.X + cam.CFrame.LookVector * -relative.Z
                if direction.Magnitude > 0 then
                    direction = direction.Unit * math.min(move.Magnitude, 1)
                end
            end
            local vertical = 0
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) or os.clock() < flyJumpUntil then
                vertical += 1
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
                vertical -= 1
            end
            velocity.Velocity = (direction + Vector3.new(0, vertical, 0)) * sliderValue("FlySlider", 60)
            local look = cam.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 0.001 then
                gyro.CFrame = CFrame.lookAt(Vector3.zero, flat)
            end
        end))
    end

    -- Hide username ----------------------------------------------------------
    -- Swaps your name for any text you type: in this UI, on your own overhead name
    -- tag and (by hiding the player list) everywhere else on your screen. Other
    -- players still see your real name, because that cannot be changed from here.
    local function fakeName()
        local text = trimmed(controls.FakeName and controls.FakeName:Get())
        if text == "" then
            text = "Player"
        end
        return text
    end

    appliers.HideUsername = function()
        local hum = humanoid()
        if active.HideUsername then
            local fake = fakeName()
            window._fakeNameChoice = fake
            window:SetFakeName(fake)
            if hum then
                if saved.humanoidName == nil then
                    saved.humanoidName = hum.DisplayName
                end
                hum.DisplayName = fake
            end
            pcall(function()
                if saved.playerList == nil then
                    saved.playerList = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
                end
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
            end)
        else
            window:SetFakeName(nil)
            if hum and saved.humanoidName ~= nil then
                hum.DisplayName = saved.humanoidName
            end
            saved.humanoidName = nil
            if saved.playerList ~= nil then
                local wasEnabled = saved.playerList
                saved.playerList = nil
                pcall(function()
                    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, wasEnabled)
                end)
            end
        end
    end

    -- Anti AFK ---------------------------------------------------------------
    appliers.AntiAFK = function()
        clearBag("afk")
        if not active.AntiAFK then
            return
        end
        -- Silence the game's own idle handlers when the executor can see them.
        local silenced = {}
        if type(getconnections) == "function" then
            pcall(function()
                for _, connection in ipairs(getconnections(player.Idled)) do
                    if connection.Disable then
                        connection:Disable()
                        table.insert(silenced, connection)
                    end
                end
            end)
        end
        hold("afk", function()
            for _, connection in ipairs(silenced) do
                pcall(function()
                    connection:Enable()
                end)
            end
        end)
        hold("afk", player.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end))
    end

    -- Instant prompts --------------------------------------------------------
    local promptHold = setmetatable({}, weakKeys)
    local function makeInstant(prompt)
        if prompt:IsA("ProximityPrompt") and prompt.HoldDuration ~= 0 then
            if promptHold[prompt] == nil then
                promptHold[prompt] = prompt.HoldDuration
            end
            prompt.HoldDuration = 0
        end
    end

    local promptSweep = 0
    appliers.InstantPrompts = function()
        clearBag("prompts")
        promptSweep += 1
        local sweep = promptSweep
        if not active.InstantPrompts then
            for prompt, original in pairs(promptHold) do
                if prompt.Parent then
                    prompt.HoldDuration = original
                end
                promptHold[prompt] = nil
            end
            return
        end
        hold("prompts", Workspace.DescendantAdded:Connect(makeInstant))
        hold("prompts", ProximityPromptService.PromptShown:Connect(makeInstant))
        task.spawn(function()
            local count = 0
            for _, descendant in ipairs(Workspace:GetDescendants()) do
                if sweep ~= promptSweep then
                    return
                end
                makeInstant(descendant)
                count += 1
                if count % 4000 == 0 then
                    task.wait()
                end
            end
        end)
    end

    -- UI ---------------------------------------------------------------------
    local function setActive(name, value)
        active[name] = value == true
        local ok, err = pcall(appliers[name])
        if not ok then
            warn("[igkii] " .. name .. " failed: " .. tostring(err))
            window:Notify({ Title = name, Content = "Could not apply this in this game", Type = "Warning", Duration = 3 })
        end
    end

    local character = tab:Groupbox({ Name = "Character", Side = "Left" })
    toggles.GodMode = character:Toggle({
        Name = "God Mode",
        Desc = "Keeps your health full (client side)",
        Flag = "Misc.GodMode",
        Callback = function(value)
            setActive("GodMode", value)
        end,
    })
    toggles.Speed = character:Toggle({
        Name = "Movement Speed",
        Flag = "Misc.Speed",
        Callback = function(value)
            setActive("Speed", value)
        end,
    })
    controls.SpeedSlider = character:Slider({
        Name = "Speed",
        Min = 16,
        Max = 300,
        Step = 1,
        Default = 50,
        Flag = "Misc.SpeedValue",
        Callback = function()
            if active.Speed then
                setActive("Speed", true)
            end
        end,
    })
    toggles.InfiniteJump = character:Toggle({
        Name = "Infinite Jump",
        Flag = "Misc.InfiniteJump",
        Callback = function(value)
            setActive("InfiniteJump", value)
        end,
    })
    toggles.Fly = character:Toggle({
        Name = "Fly",
        Desc = "Space up, Ctrl or Q down",
        Flag = "Misc.Fly",
        Callback = function(value)
            setActive("Fly", value)
        end,
    })
    controls.FlySlider = character:Slider({
        Name = "Fly Speed",
        Min = 10,
        Max = 300,
        Step = 1,
        Default = 60,
        Flag = "Misc.FlySpeed",
    })
    controls.FlyKey = character:Keybind({
        Name = "Fly Toggle Key",
        Desc = "Optional: click to bind a key",
        Flag = "Misc.FlyKey",
    })
    toggles.NoClip = character:Toggle({
        Name = "No Clip",
        Flag = "Misc.NoClip",
        Callback = function(value)
            setActive("NoClip", value)
        end,
    })
    controls.NoClipKey = character:Keybind({
        Name = "No Clip Toggle Key",
        Desc = "Optional: click to bind a key",
        Flag = "Misc.NoClipKey",
    })

    local utility = tab:Groupbox({ Name = "Utility", Side = "Right" })
    toggles.HideUsername = utility:Toggle({
        Name = "Hide Username",
        Desc = "Shows the fake name below instead",
        Flag = "Misc.HideUsername",
        Callback = function(value)
            setActive("HideUsername", value)
        end,
    })
    controls.FakeName = utility:Input({
        Name = "Fake Name",
        Placeholder = "Type any name...",
        Default = "",
        Flag = "Misc.FakeName",
        Callback = function()
            if active.HideUsername then
                setActive("HideUsername", true)
            end
        end,
    })
    toggles.AntiAFK = utility:Toggle({
        Name = "Anti AFK",
        Desc = "No idle kick after 20 minutes",
        Flag = "Misc.AntiAFK",
        Callback = function(value)
            setActive("AntiAFK", value)
        end,
    })
    toggles.InstantPrompts = utility:Toggle({
        Name = "Instant Prompts",
        Desc = "Hold prompts trigger at once",
        Flag = "Misc.InstantPrompts",
        Callback = function(value)
            setActive("InstantPrompts", value)
        end,
    })

    -- Config ---------------------------------------------------------------
    -- Configs are Lua files (igkii/configs/<name>.lua). Auto load can be set for
    -- this account only or for every account.
    local configBox = tab:Groupbox({ Name = "Config", Side = "Right" })
    local configNames = Library:ListConfigs()   -- the dropdown reads this table, so it is refreshed in place
    local function refreshConfigs()
        local fresh = Library:ListConfigs()
        table.clear(configNames)
        for _, name in ipairs(fresh) do
            table.insert(configNames, name)
        end
    end
    local function configName()
        local typed = trimmed(controls.ConfigName and controls.ConfigName:Get())
        if typed ~= "" then
            return typed
        end
        local picked = controls.ConfigList and controls.ConfigList:Get()
        if picked and trimmed(picked) ~= "" then
            return trimmed(picked)
        end
        return nil
    end
    local function report(ok, title, detail)
        window:Notify({
            Title = ok and title or (title .. " failed"),
            Content = tostring(detail or ""),
            Type = ok and "Success" or "Error",
            Duration = 3,
        })
    end

    controls.ConfigName = configBox:Input({
        Name = "Config Name",
        Placeholder = "Type a config name...",
        Default = "",
    })
    controls.ConfigList = configBox:Dropdown({
        Name = "Saved Configs",
        Options = configNames,
        Default = configNames[1],
        Callback = function(value)
            if value then
                controls.ConfigName:Set(value)
            end
        end,
    })
    configBox:Button({
        Name = "Save Config",
        Callback = function()
            local name = configName()
            if not name then
                report(false, "Save", "Type a config name first")
                return
            end
            local ok, err = Library:SaveConfig(name)
            refreshConfigs()
            report(ok, "Config saved", ok and ("Saved as " .. name) or err)
        end,
    })
    configBox:Button({
        Name = "Load Config",
        Callback = function()
            local name = configName()
            if not name then
                report(false, "Load", "Type or pick a config name first")
                return
            end
            local ok, err = Library:LoadConfig(name)
            report(ok, "Config loaded", ok and ("Loaded " .. name) or err)
        end,
    })
    configBox:Button({
        Name = "Delete Config",
        Callback = function()
            local name = configName()
            if not name then
                report(false, "Delete", "Type or pick a config name first")
                return
            end
            local ok, err = Library:DeleteConfig(name)
            refreshConfigs()
            report(ok, "Config deleted", ok and ("Deleted " .. name) or err)
        end,
    })

    local SCOPE_ACCOUNT, SCOPE_ALL = "This account only", "All accounts"
    local startName, startScope = Library:GetAutoLoad()
    local lastScope = startScope or "account"
    local function chosenScope()
        return controls.AutoScope:Get() == SCOPE_ALL and "all" or "account"
    end
    controls.AutoScope = configBox:Dropdown({
        Name = "Auto Load For",
        Options = { SCOPE_ACCOUNT, SCOPE_ALL },
        Default = SCOPE_ACCOUNT,
        Callback = function(value)
            local scope = value == SCOPE_ALL and "all" or "account"
            if controls.AutoLoad:Get() then
                local name = configName()
                if name then
                    Library:SetAutoLoad(nil, lastScope)
                    Library:SetAutoLoad(name, scope)
                end
            end
            lastScope = scope
        end,
    })
    controls.AutoLoad = configBox:Toggle({
        Name = "Auto Load",
        Desc = "Loads the config when the script starts",
        Callback = function(value)
            if value then
                local name = configName()
                if not name then
                    report(false, "Auto load", "Type or pick a config name first")
                    controls.AutoLoad:Set(false, true)
                    return
                end
                if not table.find(configNames, name) then
                    report(false, "Auto load", "Save the config first")
                    controls.AutoLoad:Set(false, true)
                    return
                end
                local ok, err = Library:SetAutoLoad(name, chosenScope())
                lastScope = chosenScope()
                report(ok, "Auto load on", ok and (name .. " · " .. (lastScope == "all" and SCOPE_ALL or SCOPE_ACCOUNT)) or err)
            else
                Library:SetAutoLoad(nil, lastScope)
                report(true, "Auto load off", "Nothing loads by itself now")
            end
        end,
    })
    if startName then
        controls.ConfigName:Set(startName)
        controls.AutoScope:Set(startScope == "all" and SCOPE_ALL or SCOPE_ACCOUNT, true)
        controls.AutoLoad:Set(true, true)
    end
    if opts.AutoLoad ~= false then
        self._autoLoad = true
    end

    -- Hotkeys. Ignored only while a text box is being typed in; a key that was just
    -- used to rebind a Keybind is skipped so the rebind press does not flip the feature.
    hold("core", UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end
        if UserInputService:GetFocusedTextBox() then
            return
        end
        local code = input.KeyCode
        task.defer(function()
            if window._destroyed then
                return
            end
            if window._consumedKey == code and os.clock() - (window._consumedAt or 0) < 0.25 then
                return
            end
            if code == controls.FlyKey:Get() then
                toggles.Fly:Set(not toggles.Fly:Get())
            elseif code == controls.NoClipKey:Get() then
                toggles.NoClip:Set(not toggles.NoClip:Get())
            end
        end)
    end))

    -- After a respawn the character-bound features are applied to the new body.
    local CHARACTER_FEATURES = { "GodMode", "Speed", "Fly", "HideUsername" }
    hold("core", player.CharacterAdded:Connect(function(char)
        saved.health, saved.walkSpeed, saved.platformStand, saved.humanoidName = nil, nil, nil, nil
        char:WaitForChild("Humanoid", 10)
        char:WaitForChild("HumanoidRootPart", 10)
        task.wait(0.1)
        if window._destroyed then
            return
        end
        for _, name in ipairs(CHARACTER_FEATURES) do
            if active[name] then
                setActive(name, true)
            end
        end
    end))

    local ORDER = { "Fly", "NoClip", "Speed", "GodMode", "InfiniteJump", "HideUsername", "AntiAFK", "InstantPrompts" }
    local function unload(final)
        for _, name in ipairs(ORDER) do
            if active[name] then
                active[name] = false
                pcall(appliers[name])
            end
            if toggles[name] and toggles[name].Get and toggles[name]:Get() then
                pcall(function()
                    toggles[name]:Set(false, true)
                end)
            end
        end
        -- The hotkey and respawn listeners stay until the window itself is destroyed.
        for name in pairs(table.clone(bags)) do
            if final == true or name ~= "core" then
                clearBag(name)
            end
        end
    end
    self:OnDestroy(function()
        unload(true)
    end)

    local result
    result = {
        Tab = tab,
        Toggles = toggles,
        Controls = controls,
        Active = active,
        Set = function(name, value)
            local toggle = toggles[name]
            if toggle then
                toggle:Set(value == true)
            end
        end,
        Unload = function()
            unload(false)
        end,
    }
    result.Features = Library.MiscFeatures(function()
        return result
    end)
    return result
end


return Library
