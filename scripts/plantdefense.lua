-- [NEW] Plant Defense RNG
-- PlaceId 88986563263928 | GameId 10772529417
-- Auto Delete: deletes Common / Uncommon / Rare / Epic / Legendary plants (every mutation) every 10 seconds
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

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local INTERVAL = 10
local CHUNK = 40

local running = true
local autoDelete = false
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
-- UI (igkii lib)
----------------------------------------------------------------------
local Window = Library.Window({ Title = "Plant Defense RNG" })

local misc
local features = Library.MiscFeatures(function() return misc end)
table.insert(features, { Name = "Auto Delete", Get = function() return autoDelete end })

Window:BuildHome(features, {
    { Title = "Auto Delete", Get = function() return autoDelete and "ON" or "OFF" end },
    { Title = "Plants Deleted", Get = function() return tostring(deletedTotal) end },
}, { Tier = "Free" })

local tab = Window:Tab({
    Name = "Plants",
    Icon = "trash",
    PageTitle = "Plants",
    Desc = "Auto delete plants by rarity",
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
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    env.PDR_UNLOAD = nil
end)

env.PDR_UNLOAD = function()
    running = false
    autoDelete = false
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    pcall(function() Window:Destroy() end)
end

Window:PlayIntro()
