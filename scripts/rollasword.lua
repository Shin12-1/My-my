-- [RELEASE] Roll a Sword | PlaceId 127788924565169 | GameId 10771796704
-- scripts/rollasword.lua  |  Home + Main (auto collect) + Misc  |  igkii UI

local env = (getgenv and getgenv()) or _G

if env.RAS_UNLOAD then pcall(env.RAS_UNLOAD) end

local fetch = env.IGKII_FETCH
if not fetch then
    warn("[RollASword] run this through the loader")
    return
end

local RS = game:GetService("ReplicatedStorage")
local Remotes = RS:WaitForChild("Remotes")
local Collect = Remotes:WaitForChild("Collect")
local BattleTick = Remotes:WaitForChild("BattleTick")

local State = { AutoCollect = true }
local conns, seen, queue = {}, {}, {}
local cleaned = false
local Window, misc
env.RAS_RUN = true -- set before the sender loop starts

local COLLECT_DELAY = 0.35 -- wait a moment after a kill, like the game does
local BATCH_SIZE = 10      -- ids per Collect call
local SEND_EVERY = 0.25    -- seconds between Collect calls

-------------------------------------------------------------------
-- AUTO COLLECT (drops arrive in Remotes.BattleTick, killed.drops / kills[].drops)
-------------------------------------------------------------------
local function addDrop(id)
    id = tonumber(id)
    if not id or id < 1 or id % 1 ~= 0 or seen[id] then return end
    seen[id] = true
    queue[#queue + 1] = { id = id, at = os.clock() + COLLECT_DELAY }
    task.delay(60, function() seen[id] = nil end) -- ids are never reused that fast
end

-- find every "drops" list inside the tick, however deep it is nested
local function scan(tbl, depth)
    if depth > 6 or type(tbl) ~= "table" then return end
    for key, value in pairs(tbl) do
        if key == "drops" and type(value) == "table" then
            for _, drop in pairs(value) do
                if type(drop) == "table" then
                    addDrop(drop.id)
                end
            end
        elseif type(value) == "table" then
            scan(value, depth + 1)
        end
    end
end

table.insert(conns, BattleTick.OnClientEvent:Connect(function(tick)
    if not State.AutoCollect then return end
    scan(tick, 0)
end))

local function setCollect(on)
    State.AutoCollect = on and true or false
    if not State.AutoCollect then
        table.clear(queue)
    end
end

-- sender: small batches, one call every 0.25s, never too fast
task.spawn(function()
    while env.RAS_RUN do
        if State.AutoCollect and #queue > 0 then
            local ids, now = {}, os.clock()
            while #queue > 0 and #ids < BATCH_SIZE and queue[1].at <= now do
                ids[#ids + 1] = table.remove(queue, 1).id
            end
            if #ids > 0 then
                pcall(function() Collect:FireServer(ids) end)
            end
        end
        task.wait(SEND_EVERY)
    end
end)

-------------------------------------------------------------------
-- UNLOAD
-------------------------------------------------------------------
local function cleanup()
    if cleaned then return end
    cleaned = true
    env.RAS_RUN = false
    State.AutoCollect = false
    table.clear(queue)
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
end

env.RAS_UNLOAD = function()
    cleanup()
    if Window then pcall(function() Window:Destroy() end) end
end

-------------------------------------------------------------------
-- UI (igkii_lib): Home, Main, Misc
-------------------------------------------------------------------
local okLoad, Library = pcall(function()
    return loadstring(fetch("igkii_lib.lua"))()
end)
if not okLoad or type(Library) ~= "table" then
    warn("[RollASword] could not load the UI library: " .. tostring(Library))
    cleanup()
    return
end

Window = Library.Window({ Title = "igkii" })
Window:OnDestroy(cleanup) -- closing the window from anywhere stops the script

-- Home first (shows the game it detected)
Window:BuildHome(Library.MiscFeatures(function()
    return misc
end), {
    { Title = "Place ID", Get = function() return tostring(game.PlaceId) end },
    { Title = "Game ID", Get = function() return tostring(game.GameId) end },
}, { Tier = "Roll a Sword" })

-- Game tab
local Main = Window:Tab({ Name = "Main", PageTitle = "Roll a Sword", Desc = "[RELEASE] Roll a Sword" })

Main:Section("Features")

Main:Toggle({
    Name = "Auto Collect Drops",
    Desc = "Collects every drop automatically the moment an enemy dies",
    Default = true,
    Flag = "RAS.AutoCollect",
    Callback = setCollect,
})

Main:Section("Script")

Main:Button({
    Name = "Unload",
    Desc = "Stops everything and closes the UI",
    Callback = function() env.RAS_UNLOAD() end,
})

-- Misc last
misc = Window:BuildMisc()

Window:PlayIntro()
