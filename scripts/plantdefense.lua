-- [NEW] Plant Defense RNG
-- PlaceId 88986563263928 | GameId 10772529417
-- Auto Start: fires Enemies "start" again whenever the round finishes (idle / cleared)
-- Auto Delete: deletes Common / Uncommon / Rare / Epic / Legendary plants (every mutation) every 10 seconds
-- Auto Roll: Keeps the in-game Auto Roll turned ON
-- Loaded by loader.lua (env.IGKII_FETCH is set by the loader)

local env = (getgenv and getgenv()) or _G

-- unload a previous run
if env.PDR_UNLOAD then
    pcall(env.PDR_UNLOAD)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local fetch = env.IGKII_FETCH
assert(fetch, "IGKII_FETCH missing - run this through loader.lua")

local Library = loadstring(fetch("igkii_lib.lua"))()

----------------------------------------------------------------------
-- Remotes
----------------------------------------------------------------------
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlantAction = Remotes:WaitForChild("PlantAction") -- RemoteFunction
local PlantSync = Remotes:WaitForChild("PlantSync")     -- RemoteEvent
local Enemies = Remotes:WaitForChild("Enemies")         -- RemoteEvent (FireServer("start") starts a round)

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local INTERVAL = 10
local CHUNK = 40

local running = true
local autoDelete = false
local autoRoll = false -- ADDED: Auto Roll state
local lastRun = 0
local deletedTotal = 0
local connections = {}

local selected = {
    common = true,
    uncommon = true,
    rare = true,
    epic = true,
    legendary = true,
}

local inventory = {} -- list of { id, mutation, count }

----------------------------------------------------------------------
-- Inventory tracking
-- Full PlantSync payloads carry the whole `plants` list; partial ones only carry money.
----------------------------------------------------------------------
table.insert(connections, PlantSync.OnClientEvent:Connect(function(data)
    if type(data) == "table" and type(data.plants) == "table" then
        inventory = data.plants
    end
end))

local function findPlants(t, depth, seen)
    if type(t) ~= "table" or depth > 3 or seen[t] then return nil end
    seen[t] = true
    local p = rawget(t, "plants")
    if type(p) == "table" and type(p[1]) == "table" and p[1].id then
        return p
    end
    for _, v in pairs(t) do
        if type(v) == "table" then
            local r = findPlants(v, depth + 1, seen)
            if r then return r end
        end
    end
    return nil
end

-- grab the current inventory from the game's own client state (in case the last full sync was before we loaded)
task.spawn(function()
    pcall(function()
        local gameUI = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("GameUI")
        local mock = gameUI:FindFirstChild("MockState")
        if mock and mock:IsA("ModuleScript") then
            local state = require(mock)
            local plants = findPlants(state, 0, {})
            if plants and #inventory == 0 then
                inventory = plants
            end
        end
    end)
end)

----------------------------------------------------------------------
-- Rarity lookup (read from the game at runtime)
----------------------------------------------------------------------
local rarityMap = {}
local lastScan = 0

local function harvest(t, depth, seen)
    if type(t) ~= "table" or depth > 4 or seen[t] then return end
    seen[t] = true
    for k, v in pairs(t) do
        if type(v) == "table" then
            local r = rawget(v, "rarity") or rawget(v, "Rarity")
            if type(r) == "string" then
                local pid = (type(k) == "string" and k) or rawget(v, "id") or rawget(v, "Id") or rawget(v, "name")
                if type(pid) == "string" then
                    rarityMap[pid] = r:lower()
                end
            end
            harvest(v, depth + 1, seen)
        end
    end
end

local function scanRarities()
    lastScan = os.clock()

    -- 1) ModuleScripts that hold plant data
    for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
        if inst:IsA("ModuleScript") then
            task.spawn(function()
                local ok, result = pcall(require, inst)
                if ok and type(result) == "table" then
                    pcall(harvest, result, 0, {})
                end
            end)
        end
    end

    -- 2) instances carrying a Rarity attribute / value
    for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
        local attr = inst:GetAttribute("Rarity") or inst:GetAttribute("rarity")
        if type(attr) == "string" then
            rarityMap[inst.Name] = attr:lower()
        else
            local val = inst:FindFirstChild("Rarity")
            if val and val:IsA("StringValue") and inst.Parent then
                rarityMap[inst.Name] = val.Value:lower()
            end
        end
    end

    task.wait(2) -- let the require threads finish
end

----------------------------------------------------------------------
-- Auto delete
----------------------------------------------------------------------
local function runDelete()
    if #inventory == 0 then return end

    -- (re)scan when we meet plants we can't place yet (at most once per minute)
    local unknown = false
    for _, e in ipairs(inventory) do
        if e.count and e.count > 0 and not rarityMap[e.id] then
            unknown = true
            break
        end
    end
    if unknown and os.clock() - lastScan > 60 then
        scanRarities()
    end

    local list, entries, missing = {}, {}, {}
    for _, e in ipairs(inventory) do
        if e.count and e.count > 0 then
            local r = rarityMap[e.id]
            if r then
                if selected[r] then
                    list[#list + 1] = { id = e.id, mutation = e.mutation }
                    entries[#entries + 1] = e
                end
            else
                missing[e.id] = true
            end
        end
    end

    local missingNames = {}
    for id in pairs(missing) do missingNames[#missingNames + 1] = id end
    if #missingNames > 0 then
        warn("[PlantDefense] rarity not found for: " .. table.concat(missingNames, ", ") .. " (left untouched)")
    end

    for i = 1, #list, CHUNK do
        local chunk, chunkEntries = {}, {}
        for j = i, math.min(i + CHUNK - 1, #list) do
            chunk[#chunk + 1] = list[j]
            chunkEntries[#chunkEntries + 1] = entries[j]
        end
        local ok, success, amount = pcall(function()
            return PlantAction:InvokeServer("deleteMany", chunk)
        end)
        if ok and success == true then
            if type(amount) == "number" then
                deletedTotal = deletedTotal + amount
            end
            for _, e in ipairs(chunkEntries) do
                e.count = 0
            end
        end
        task.wait(0.25)
    end
end

task.spawn(function()
    scanRarities()
    while running do
        if autoDelete and os.clock() - lastRun >= INTERVAL then
            lastRun = os.clock()
            pcall(runDelete)
        end
        task.wait(0.5)
    end
end)

----------------------------------------------------------------------
-- Auto Start / Restart
-- Enemies:FireServer("start") starts a round.
-- A finished round shows up as an Enemies "wave" update with phase = "idle"
-- (or result = "cleared"), and sometimes a "clear" event right before it.
----------------------------------------------------------------------
local autoStart = false
local START_COOLDOWN = 3

local myPlot = nil          -- e.g. "Plot4"
local myPhase = "unknown"   -- next / active / idle / unknown
local lastStart = 0
local startsSent = 0

local learnFrom = 0         -- os.clock() of the start we fired while learning the plot
local learnHits = {}
local learnTries = 0

local function plotFromValue(v)
    if type(v) == "number" then return "Plot" .. v end
    if type(v) == "string" and v:match("^Plot%d+$") then return v end
    return nil
end

local function findMyPlot()
    local p = plotFromValue(LocalPlayer:GetAttribute("Plot") or LocalPlayer:GetAttribute("plot"))
    if p then return p end

    local function isMe(v)
        return v == LocalPlayer
            or v == LocalPlayer.Name
            or v == LocalPlayer.DisplayName
            or v == LocalPlayer.UserId
            or v == tostring(LocalPlayer.UserId)
    end

    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst.Name:match("^Plot%d+$") then
            for _, v in pairs(inst:GetAttributes()) do
                if isMe(v) then return inst.Name end
            end
            for _, c in ipairs(inst:GetChildren()) do
                if c:IsA("ValueBase") and isMe(c.Value) then return inst.Name end
            end
        end
    end
    return nil
end

myPlot = findMyPlot()

local function fireStart()
    lastStart = os.clock()
    startsSent = startsSent + 1
    if not myPlot then
        -- plot unknown: the plot that answers our start with a "next" wave within a moment is ours
        learnFrom = os.clock()
        learnHits = {}
    end
    pcall(function()
        Enemies:FireServer("start")
    end)
end

table.insert(connections, Enemies.OnClientEvent:Connect(function(action, plot, data)
    if action ~= "wave" and action ~= "clear" then return end

    -- learning our plot from the reply to our own start
    if not myPlot then
        if action == "wave" and type(data) == "table" and data.phase == "next"
            and learnFrom > 0 and os.clock() - learnFrom < 1 then
            learnHits[plot] = true
            local count, only = 0, nil
            for p in pairs(learnHits) do count = count + 1; only = p end
            if count == 1 then
                task.delay(0.5, function()
                    local c2, o2 = 0, nil
                    for p in pairs(learnHits) do c2 = c2 + 1; o2 = p end
                    if not myPlot and c2 == 1 then myPlot = o2 end
                end)
            end
        end
        return
    end

    if plot ~= myPlot then return end

    if action == "clear" then
        myPhase = "idle"
    elseif type(data) == "table" then
        if data.phase == "idle" or data.result == "cleared" then
            myPhase = "idle"
        elseif data.phase then
            myPhase = data.phase
        end
    end
end))

task.spawn(function()
    local lastPlotLookup = 0
    while running do
        if autoStart then
            if not myPlot and os.clock() - lastPlotLookup > 5 then
                lastPlotLookup = os.clock()
                myPlot = findMyPlot()
            end
            if os.clock() - lastStart >= START_COOLDOWN then
                if myPhase == "idle" then
                    fireStart()
                elseif myPhase == "unknown" and not myPlot and learnTries < 3 then
                    learnTries = learnTries + 1
                    fireStart() -- also lets us learn our plot
                end
            end
        end
        task.wait(0.5)
    end
end)

----------------------------------------------------------------------
-- Auto Roll (ADDED FEATURE)
----------------------------------------------------------------------
local function forceAutoRoll()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    for _, v in ipairs(pg:GetDescendants()) do
        if (v:IsA("TextLabel") or v:IsA("TextButton")) and v.Text:upper() == "OFF" then
            local isAutoRoll = false
            local button = v
            
            for i = 1, 3 do
                if button then
                    if string.find(button.Name:upper(), "AUTO") or string.find(button.Name:upper(), "ROLL") then
                        isAutoRoll = true
                    end
                    button = button.Parent
                end
            end
            
            if not isAutoRoll and v.Parent then
                for _, sib in ipairs(v.Parent:GetChildren()) do
                    if sib:IsA("TextLabel") and string.find(sib.Text:upper(), "AUTO ROLL") then
                        isAutoRoll = true
                        break
                    end
                end
            end

            if isAutoRoll and v.Parent then
                local clickable = v
                if not v:IsA("GuiButton") then
                    clickable = v.Parent
                end
                
                if clickable and clickable:IsA("GuiButton") then
                    print("[PlantDefense] Auto Roll is OFF. Turning it ON.")
                    if firesignal then
                        pcall(firesignal, clickable.MouseButton1Click)
                    else
                        local vim = game:GetService("VirtualInputManager")
                        local pos = clickable.AbsolutePosition + (clickable.AbsoluteSize / 2)
                        vim:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
                        vim:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while running do
        if autoRoll then
            pcall(forceAutoRoll)
        end
        task.wait(1)
    end
end)
----------------------------------------------------------------------

----------------------------------------------------------------------
-- UI (igkii lib)
----------------------------------------------------------------------
local Window = Library.Window({ Title = "Plant Defense RNG" })

local misc
local features = Library.MiscFeatures(function() return misc end)
table.insert(features, { Name = "Auto Delete", Get = function() return autoDelete end })
table.insert(features, { Name = "Auto Start", Get = function() return autoStart end })
table.insert(features, { Name = "Auto Roll", Get = function() return autoRoll end }) -- ADDED

Window:BuildHome(features, {
    { Title = "Auto Delete", Get = function() return autoDelete and "ON" or "OFF" end },
    { Title = "Auto Start", Get = function() return autoStart and "ON" or "OFF" end },
    { Title = "Auto Roll", Get = function() return autoRoll and "ON" or "OFF" end }, -- ADDED
    { Title = "Plants Deleted", Get = function() return tostring(deletedTotal) end },
}, { Tier = "Free" })

local tab = Window:Tab({
    Name = "Plants",
    Icon = "trash",
    PageTitle = "Plants",
    Desc = "Auto delete plants by rarity",
})

tab:Section("Auto Start")
tab:Toggle({
    Name = "Auto Start / Restart",
    Desc = "Starts the round again as soon as it finishes (after round 30)",
    Default = false,
    Callback = function(value)
        autoStart = value
        if value then
            learnTries = 0
            if myPhase ~= "next" and myPhase ~= "active" then
                fireStart()
            end
        end
    end,
})

-- ADDED AUTO ROLL UI
tab:Section("Auto Roll")
tab:Toggle({
    Name = "Auto Roll ON",
    Desc = "If the in-game Auto Roll button turns OFF, this clicks it to turn it back ON.",
    Default = false,
    Callback = function(value)
        autoRoll = value
    end,
})

tab:Section("Auto Delete")
tab:Toggle({
    Name = "Auto Delete (every 10s)",
    Desc = "Deletes the selected rarities, including every mutation",
    Default = false,
    Callback = function(value)
        autoDelete = value
        if value then
            lastRun = 0 -- run right away
        end
    end,
})

tab:Section("Rarities to delete")
for _, rarity in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary" }) do
    tab:Toggle({
        Name = rarity,
        Desc = "Delete " .. rarity .. " plants (all mutations)",
        Default = true,
        Callback = function(value)
            selected[rarity:lower()] = value
        end,
    })
end

misc = Window:BuildMisc()

Window:OnDestroy(function()
    running = false
    autoDelete = false
    autoStart = false
    autoRoll = false -- ADDED
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    env.PDR_UNLOAD = nil
end)

env.PDR_UNLOAD = function()
    running = false
    autoDelete = false
    autoStart = false
    autoRoll = false -- ADDED
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    pcall(function() Window:Destroy() end)
end)

Window:PlayIntro()
