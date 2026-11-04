-- +1 Hacker Evolve | igkii
-- PlaceId 75821372602076 | GameId 10772139684
-- Auto Click (ClickToEarn) | Auto Pops (TrainingPops, skips paid pops) | Auto Rebirth | Auto Evolve

if getgenv().HE_UNLOAD then pcall(getgenv().HE_UNLOAD) end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local ClickToEarn = Remotes and Remotes:WaitForChild("ClickToEarn", 10)     -- RemoteEvent, FireServer() (fired by PlayerScripts.StepToEarn)
local TrainingPops = Remotes and Remotes:WaitForChild("TrainingPops", 10)   -- RemoteEvent, FireServer(popId)
local RebirthRemote = ReplicatedStorage:WaitForChild("RebirthRemote", 10)   -- RemoteEvent, FireServer() (ReplicatedStorage root)
local EvolveRemote = ReplicatedStorage:WaitForChild("EvolveRemote", 10)     -- RemoteEvent, FireServer() (ReplicatedStorage root)

if not (ClickToEarn and TrainingPops and RebirthRemote and EvolveRemote) then
    warn("[HackerEvolve] a remote was not found, the game may have changed.")
end

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local State = {
    Running = true,
    Debug = true,
    AutoClick = false,
    WalkWhileClick = true, -- ClickToEarn comes from the StepToEarn script, so we also walk
    AutoPops = false,
    AutoRebirth = false,
    AutoEvolve = false,
    ClickDelay = 0.47,     -- the game's own client clicks every ~0.47s; faster may be ignored
    PopDelay = 0.8,        -- the game's own client never clicked a pop sooner than about 0.57s
    MaxPopMult = 3,        -- free pops seen: x1.5, x2, x3. x20 opens a Robux prompt
    RebirthDelay = 3,      -- the game's own client rebirths every ~3s
    EvolveDelay = 3,
}

local function dbg(...)
    if State.Debug then
        print("[HackerEvolve]", ...)
    end
end

-- UI callbacks may pass (value) or (self, value), so scan the args
local function asBool(...)
    for _, a in ipairs({ ... }) do
        if type(a) == "boolean" then return a end
    end
    return false
end

local function asNum(default, ...)
    for _, a in ipairs({ ... }) do
        if type(a) == "number" then return a end
    end
    return default
end

----------------------------------------------------------------
-- AUTO CLICK (+ small walk, because the click is tied to StepToEarn)
----------------------------------------------------------------
local home, stepDir, lastStep = nil, 1, 0

local function stepWalk()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (hum and root) then return end

    if not home or (root.Position - home).Magnitude > 40 then
        home = root.Position
    end
    stepDir = -stepDir
    hum:MoveTo(home + Vector3.new(6 * stepDir, 0, 0))
end

task.spawn(function()
    while State.Running do
        if State.AutoClick and ClickToEarn then
            if State.WalkWhileClick and os.clock() - lastStep > 0.6 then
                lastStep = os.clock()
                pcall(stepWalk)
            end
            pcall(function()
                ClickToEarn:FireServer()
            end)
            task.wait(State.ClickDelay)
        else
            home = nil
            task.wait(0.1)
        end
    end
end)

----------------------------------------------------------------
-- AUTO REBIRTH
----------------------------------------------------------------
task.spawn(function()
    while State.Running do
        if State.AutoRebirth and RebirthRemote then
            pcall(function()
                RebirthRemote:FireServer()
            end)
            task.wait(State.RebirthDelay)
        else
            task.wait(0.25)
        end
    end
end)

----------------------------------------------------------------
-- AUTO EVOLVE
-- EvolveRemote:FireServer() with no args; the server answers with the
-- new evolution number through OnClientEvent. If you are not ready to
-- evolve yet the server just ignores the call.
----------------------------------------------------------------
local evolveConn

if EvolveRemote then
    evolveConn = EvolveRemote.OnClientEvent:Connect(function(tier)
        dbg("evolved, new tier:", tier)
    end)
end

task.spawn(function()
    while State.Running do
        if State.AutoEvolve and EvolveRemote then
            pcall(function()
                EvolveRemote:FireServer()
            end)
            task.wait(State.EvolveDelay)
        else
            task.wait(0.25)
        end
    end
end)

----------------------------------------------------------------
-- AUTO POPS (never clicks paid pops)
-- Server sends:  TrainingPops.OnClientEvent("show", id, "x1.5", 3.5)
-- Client replies: TrainingPops:FireServer(id)
-- The x20 pop opened a Robux purchase prompt, so only labels that
-- are a plain "xNUMBER" and <= MaxPopMult are ever clicked.
----------------------------------------------------------------
local popConn

local function parseMult(label)
    local s = tostring(label or ""):lower():gsub("%s", "")
    local n = s:match("^x(%d+%.?%d*)$")
    return n and tonumber(n) or nil
end

if TrainingPops then
    popConn = TrainingPops.OnClientEvent:Connect(function(kind, id, label)
        if kind ~= "show" then return end
        dbg("pop shown", id, label)
        if not (State.Running and State.AutoPops) then return end

        local mult = parseMult(label)
        if not mult then
            dbg("pop skipped (unknown label)", label)
            return
        end
        if mult > State.MaxPopMult then
            dbg("pop skipped (paid / above limit)", label)
            return
        end

        task.delay(State.PopDelay, function()
            if State.Running and State.AutoPops then
                pcall(function()
                    TrainingPops:FireServer(id)
                end)
                dbg("pop clicked", id, label)
            end
        end)
    end)
end

----------------------------------------------------------------
-- igkii LIB (loaded with loadstring)
----------------------------------------------------------------
local BASE = "https://igkii.kiantejero.workers.dev"
local LIB_URLS = {
    BASE .. "/scripts/igkii_lib.lua",
    BASE .. "/igkii_lib.lua",
}

local Lib = getgenv().igkii_lib
if not Lib then
    for _, url in ipairs(LIB_URLS) do
        local ok, res = pcall(function()
            return loadstring(game:HttpGet(url))()
        end)
        if ok and res then
            Lib = res
            break
        else
            warn("[HackerEvolve] lib failed at " .. url .. ": " .. tostring(res))
        end
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
        Title = "+1 Hacker Evolve",
        Name = "+1 Hacker Evolve",
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

-- Auto Click
addToggle("Auto Click", false, function(...) State.AutoClick = asBool(...) end)
addToggle("Walk While Clicking", true, function(...) State.WalkWhileClick = asBool(...) end)
addSlider("Click Delay (s)", 0.2, 1, State.ClickDelay, 0.01, function(...)
    State.ClickDelay = asNum(State.ClickDelay, ...)
end)

-- Auto Pops
addToggle("Auto Pops", false, function(...) State.AutoPops = asBool(...) end)
addSlider("Pop Delay (s)", 0.6, 2, State.PopDelay, 0.05, function(...)
    State.PopDelay = asNum(State.PopDelay, ...)
end)
addSlider("Max Pop Multiplier", 1.5, 10, State.MaxPopMult, 0.5, function(...)
    State.MaxPopMult = asNum(State.MaxPopMult, ...)
end)

-- Auto Rebirth
addToggle("Auto Rebirth", false, function(...) State.AutoRebirth = asBool(...) end)
addSlider("Rebirth Delay (s)", 0.5, 10, State.RebirthDelay, 0.5, function(...)
    State.RebirthDelay = asNum(State.RebirthDelay, ...)
end)

-- Auto Evolve
addToggle("Auto Evolve", false, function(...) State.AutoEvolve = asBool(...) end)
addSlider("Evolve Delay (s)", 1, 30, State.EvolveDelay, 0.5, function(...)
    State.EvolveDelay = asNum(State.EvolveDelay, ...)
end)

if not Lib then
    warn("[HackerEvolve] igkii_lib did not load from any link, check the file path on your Worker.")
elseif not MainTab then
    warn("[HackerEvolve] lib loaded but the UI did not build, the lib method names differ. Check igkii_lib.lua.")
end

-- failsafe: with no UI there are no toggles, so run with everything on
if not MainTab then
    State.AutoClick = true
    State.AutoPops = true
    State.AutoRebirth = true
    State.AutoEvolve = true
    warn("[HackerEvolve] no UI, running with Auto Click, Auto Pops, Auto Rebirth and Auto Evolve ON.")
end

----------------------------------------------------------------
-- UNLOAD
----------------------------------------------------------------
getgenv().HE_UNLOAD = function()
    State.Running = false
    State.AutoClick = false
    State.AutoPops = false
    State.AutoRebirth = false
    State.AutoEvolve = false
    if popConn then popConn:Disconnect() end
    if evolveConn then evolveConn:Disconnect() end
    try(Window, { "Unload", "Destroy", "Close" })
    getgenv().HE_UNLOAD = nil
end
