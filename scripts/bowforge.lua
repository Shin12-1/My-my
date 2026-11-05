-- +1 Bow Forge | PlaceId 85664262792712 | GameId 10770433673
-- Features: Auto Click (ms / seconds), Auto Rebirth, Gamepasses (client-side FireClient signal)
-- Loaded by loader.lua (env.IGKII_FETCH) and uses igkii_lib.lua

local env = (getgenv and getgenv()) or _G
local fetch = env.IGKII_FETCH
if not fetch then
    fetch = function(path)
        return game:HttpGet("https://igkii.kiantejero.workers.dev/scripts/" .. path)
    end
end

if env.BOWFORGE_UNLOAD then
    pcall(env.BOWFORGE_UNLOAD)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Cmd = Remotes:WaitForChild("Cmd") -- RemoteEvent (Train / Sell / Shop...)
local Evt = Remotes:WaitForChild("Evt") -- RemoteEvent (server -> client: "Bought", "Profile", ...)

local Library = loadstring(fetch("igkii_lib.lua"))()

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local alive = true
local state = {
    click = false,
    rebirth = false,
    passes = false,
    delay = 100,       -- number shown in the slider
    useSeconds = false, -- false = milliseconds, true = seconds
    rebirthDelay = 2,  -- seconds between rebirth attempts
    target = nil,      -- Train second arg (nil = default, the game also sends "Hay")
}

local function getDelaySeconds()
    local d = tonumber(state.delay) or 100
    if state.useSeconds then
        return math.max(d, 0.001)
    end
    return math.max(d / 1000, 0.001)
end

----------------------------------------------------------------
-- Auto Click (Cmd:FireServer("Train", nil))
-- Heartbeat accumulator so millisecond delays below one frame still work
----------------------------------------------------------------
local acc = 0
local clickConn = RunService.Heartbeat:Connect(function(dt)
    if not alive or not state.click then
        acc = 0
        return
    end
    local delay = getDelaySeconds()
    acc = acc + dt
    local fired = 0
    while acc >= delay and fired < 40 do
        acc = acc - delay
        fired = fired + 1
        pcall(function()
            Cmd:FireServer("Train", state.target)
        end)
    end
    if fired >= 40 then
        acc = 0 -- cap burst so the game does not get flooded
    end
end)

----------------------------------------------------------------
-- Auto Rebirth
-- NOTE: no rebirth call was captured in the log. "Rebirth" on Cmd is the
-- most likely name (the HUD has a Rebirth button). Replace if it does nothing.
----------------------------------------------------------------
task.spawn(function()
    while alive do
        if state.rebirth then
            pcall(function()
                Cmd:FireServer("Rebirth")
            end)
            task.wait(math.max(tonumber(state.rebirthDelay) or 2, 0.2))
        else
            task.wait(0.25)
        end
    end
end)

----------------------------------------------------------------
-- Gamepasses (client-side)
-- Fires the same incoming Evt "Bought" event the server sends after a real
-- purchase, so the client treats every pass as owned. Server-side effects
-- (real damage, luck, drops) are NOT granted, only what the client handles.
----------------------------------------------------------------
local PASSES = {
    { key = "DoubleArrows", name = "2x Damage" },
    { key = "VIP", name = "VIP" },
    { key = "SecondSkill", name = "Extra Skill" },
    { key = "DoubleLuck", name = "2x Luck" },
    { key = "BiggerBag", name = "Bigger Bag" },
    { key = "AutoCollect", name = "Auto-Collect" },
    { key = "InstantCraft", name = "Skip Forge Animation" },
}

local function unlockPasses()
    if not firesignal then
        return false
    end
    for _, p in ipairs(PASSES) do
        pcall(function()
            firesignal(Evt.OnClientEvent, "Bought", {
                result = {},
                kind = "pass",
                key = p.key,
                name = p.name,
            })
        end)
        task.wait(0.15)
    end
    return true
end

----------------------------------------------------------------
-- UI (igkii lib)
----------------------------------------------------------------
local Window = Library.Window({ Title = "+1 Bow Forge" })
local misc

local main = Window:Tab({
    Name = "Main",
    Icon = "target",
    PageTitle = "Main",
    Desc = "Auto click, auto rebirth and gamepasses",
})

main:Section("Auto Click")

main:Toggle({
    Name = "Auto Click",
    Desc = "Fires Train as fast as your delay allows",
    Default = false,
    Callback = function(v)
        state.click = v
        acc = 0
    end,
})

main:Toggle({
    Name = "Delay in Seconds",
    Desc = "Off = milliseconds, On = seconds",
    Default = false,
    Callback = function(v)
        state.useSeconds = v
    end,
})

local okSlider = pcall(function()
    main:Slider({
        Name = "Click Delay",
        Desc = "Number of ms or seconds (see toggle above)",
        Min = 1,
        Max = 1000,
        Default = 100,
        Callback = function(v)
            state.delay = v
        end,
    })
end)
if not okSlider then
    state.delay = 50
    warn("[BowForge] Slider not available in lib, using 50 ms")
end

main:Section("Rebirth")

main:Toggle({
    Name = "Auto Rebirth",
    Desc = "Tries to rebirth every 2 seconds",
    Default = false,
    Callback = function(v)
        state.rebirth = v
    end,
})

main:Section("Gamepasses")

main:Toggle({
    Name = "Unlock Gamepasses",
    Desc = "Client-side: fires the Bought event for every pass",
    Default = false,
    Callback = function(v)
        state.passes = v
        if v then
            task.spawn(unlockPasses)
        end
    end,
})

local features = Library.MiscFeatures(function()
    return misc
end)
table.insert(features, { Name = "Auto Click", Get = function() return state.click end })
table.insert(features, { Name = "Auto Rebirth", Get = function() return state.rebirth end })
table.insert(features, { Name = "Gamepasses", Get = function() return state.passes end })

Window:BuildHome(features, {
    { Title = "Game", Get = function() return "+1 Bow Forge" end },
    { Title = "Delay", Get = function()
        return tostring(state.delay) .. (state.useSeconds and " s" or " ms")
    end },
}, { Tier = "Free" })

misc = Window:BuildMisc()

----------------------------------------------------------------
-- Unload
----------------------------------------------------------------
local function unload()
    alive = false
    state.click = false
    state.rebirth = false
    pcall(function() clickConn:Disconnect() end)
    env.BOWFORGE_UNLOAD = nil
end

env.BOWFORGE_UNLOAD = unload
Window:OnDestroy(unload)
Window:PlayIntro()
