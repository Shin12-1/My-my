-- +1 Hacker Evolve | igkii
-- PlaceId 75821372602076 | GameId 10772139684
-- Auto Click (ClickToEarn) | Auto Pops (TrainingPops, skips paid pops) | Auto Rebirth (RebirthRemote)

if getgenv().HE_UNLOAD then pcall(getgenv().HE_UNLOAD) end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local ClickToEarn = Remotes and Remotes:WaitForChild("ClickToEarn", 10)     -- RemoteEvent, FireServer()
local TrainingPops = Remotes and Remotes:WaitForChild("TrainingPops", 10)   -- RemoteEvent, FireServer(popId)
local RebirthRemote = ReplicatedStorage:WaitForChild("RebirthRemote", 10)   -- RemoteEvent, FireServer() (lives in ReplicatedStorage, not Remotes)

if not (ClickToEarn and TrainingPops and RebirthRemote) then
    warn("[HackerEvolve] a remote was not found, the game may have changed.")
end

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local State = {
    Running = true,
    AutoClick = false,
    AutoPops = false,
    AutoRebirth = false,
    ClickDelay = 0.1,
    PopDelay = 0.3,      -- a pop stays on screen about 3.5s
    MaxPopMult = 3,      -- free pops seen: x1.5, x2, x3. x20 opens a Robux prompt
    RebirthDelay = 3,
}

----------------------------------------------------------------
-- AUTO CLICK
----------------------------------------------------------------
task.spawn(function()
    while State.Running do
        if State.AutoClick and ClickToEarn then
            pcall(function()
                ClickToEarn:FireServer()
            end)
            task.wait(State.ClickDelay)
        else
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
        if not (State.Running and State.AutoPops) then return end

        local mult = parseMult(label)
        if not mult then return end                 -- unknown label, skip
        if mult > State.MaxPopMult then return end  -- paid / Robux pop, skip

        task.delay(State.PopDelay, function()
            if State.Running and State.AutoPops then
                pcall(function()
                    TrainingPops:FireServer(id)
                end)
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
addToggle("Auto Click", false, function(v) State.AutoClick = v end)
addSlider("Click Delay (s)", 0.02, 1, State.ClickDelay, 0.01, function(v) State.ClickDelay = v end)

-- Auto Pops
addToggle("Auto Pops", false, function(v) State.AutoPops = v end)
addSlider("Pop Delay (s)", 0.1, 2, State.PopDelay, 0.05, function(v) State.PopDelay = v end)
addSlider("Max Pop Multiplier", 1.5, 10, State.MaxPopMult, 0.5, function(v) State.MaxPopMult = v end)

-- Auto Rebirth
addToggle("Auto Rebirth", false, function(v) State.AutoRebirth = v end)
addSlider("Rebirth Delay (s)", 0.5, 10, State.RebirthDelay, 0.5, function(v) State.RebirthDelay = v end)

if not Lib then
    warn("[HackerEvolve] igkii_lib did not load from any link, check the file path on your Worker.")
elseif not MainTab then
    warn("[HackerEvolve] lib loaded but the UI did not build, the lib method names differ. Check igkii_lib.lua.")
end

----------------------------------------------------------------
-- UNLOAD
----------------------------------------------------------------
getgenv().HE_UNLOAD = function()
    State.Running = false
    State.AutoClick = false
    State.AutoPops = false
    State.AutoRebirth = false
    if popConn then popConn:Disconnect() end
    try(Window, { "Unload", "Destroy", "Close" })
    getgenv().HE_UNLOAD = nil
end
