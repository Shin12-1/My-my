-- +1 Sword Warrior Evolution | igkii
-- PlaceId 109057858722721 | GameId 10770511289
-- Auto Click (Remotes.Swing) + Auto Rebirth (Remotes.RebirthRequest)

if getgenv().SWE_UNLOAD then pcall(getgenv().SWE_UNLOAD) end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Swing = Remotes:WaitForChild("Swing")                    -- RemoteEvent, FireServer() no args
local RebirthRequest = Remotes:WaitForChild("RebirthRequest")  -- RemoteFunction, InvokeServer("Rebirth")

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local State = {
    Running = true,
    AutoClick = false,
    AutoRebirth = false,
    ClickDelay = 0.15,   -- game's own client swings about every 0.18s
    RebirthDelay = 2,
}

----------------------------------------------------------------
-- CORE LOOPS
----------------------------------------------------------------
task.spawn(function()
    while State.Running do
        if State.AutoClick then
            pcall(function()
                Swing:FireServer()
            end)
            task.wait(State.ClickDelay)
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while State.Running do
        if State.AutoRebirth then
            pcall(function()
                RebirthRequest:InvokeServer("Rebirth")
            end)
            task.wait(State.RebirthDelay)
        else
            task.wait(0.25)
        end
    end
end)

----------------------------------------------------------------
-- igkii LIB (loaded with loadstring)
----------------------------------------------------------------
local LIB_URL = "PUT_YOUR_WORKER_LINK_HERE/igkii_lib.lua" -- same base link your loader uses

local Lib = getgenv().igkii_lib
if not Lib then
    local ok, res = pcall(function()
        return loadstring(game:HttpGet(LIB_URL))()
    end)
    if ok then
        Lib = res
    else
        warn("[SwordWarrior] could not load igkii_lib: " .. tostring(res))
    end
end

-- tries each method name until one exists on the object
local function try(obj, names, ...)
    if not obj then return nil end
    for _, n in ipairs(names) do
        local f = obj[n]
        if type(f) == "function" then
            local ok, res = pcall(f, obj, ...)
            if ok and res ~= nil then return res end
        end
    end
    return nil
end

local Window, MainTab

if Lib then
    Window = try(Lib, { "CreateWindow", "Window", "new" }, {
        Title = "+1 Sword Warrior Evolution",
        Name = "+1 Sword Warrior Evolution",
        Subtitle = "igkii",
    })

    if Window then
        try(Window, { "BuildHome" })
        MainTab = try(Window, { "AddTab", "CreateTab", "Tab" }, "Main")
        try(Window, { "BuildMisc" })
    end
end

local function addToggle(name, default, cb)
    if not MainTab then return end
    try(MainTab, { "AddToggle", "CreateToggle", "Toggle" }, {
        Name = name, Text = name, Title = name,
        Default = default, Value = default, Flag = name,
        Callback = cb,
    })
end

local function addSlider(name, min, max, default, step, cb)
    if not MainTab then return end
    try(MainTab, { "AddSlider", "CreateSlider", "Slider" }, {
        Name = name, Text = name, Title = name,
        Min = min, Max = max, Default = default, Value = default,
        Increment = step, Step = step, Rounding = 2,
        Callback = cb,
    })
end

addToggle("Auto Click", false, function(v) State.AutoClick = v end)
addSlider("Click Delay (s)", 0.05, 0.5, State.ClickDelay, 0.01, function(v) State.ClickDelay = v end)
addToggle("Auto Rebirth", false, function(v) State.AutoRebirth = v end)
addSlider("Rebirth Delay (s)", 0.5, 10, State.RebirthDelay, 0.5, function(v) State.RebirthDelay = v end)

if not MainTab then
    warn("[SwordWarrior] UI did not build, the lib method names differ. Check igkii_lib.lua.")
end

----------------------------------------------------------------
-- UNLOAD
----------------------------------------------------------------
getgenv().SWE_UNLOAD = function()
    State.Running = false
    State.AutoClick = false
    State.AutoRebirth = false
    try(Window, { "Unload", "Destroy", "Close" })
    getgenv().SWE_UNLOAD = nil
end
