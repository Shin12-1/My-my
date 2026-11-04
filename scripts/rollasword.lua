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

local State = { AutoCollect = true }
local conns, seen, queue = {}, {}, {}
local cleaned = false
local Window, misc
env.RAS_RUN = true -- set before the sender loop starts

-------------------------------------------------------------------
-- AUTO COLLECT (every drop automatically, each id once, max 8/second)
-------------------------------------------------------------------
local function dropId(inst)
    local n = tonumber(inst.Name)
        or inst:GetAttribute("Id") or inst:GetAttribute("ID")
        or inst:GetAttribute("DropId") or inst:GetAttribute("Drop")
    n = tonumber(n)
    if n and n >= 1 and n < 10000000 and n % 1 == 0 then
        return n
    end
end

local function consider(inst)
    if not State.AutoCollect then return end
    local id = dropId(inst)
    if id and not seen[id] then
        seen[id] = true
        queue[#queue + 1] = id
        task.delay(30, function() seen[id] = nil end) -- allow id reuse after 30s
    end
end

local function setCollect(on)
    State.AutoCollect = on and true or false
    if State.AutoCollect then
        -- pick up what is already lying around, once
        for _, inst in ipairs(workspace:GetDescendants()) do
            consider(inst)
        end
    else
        table.clear(queue)
    end
end

-- every new drop is picked up the moment it appears
table.insert(conns, workspace.DescendantAdded:Connect(function(inst)
    task.defer(consider, inst)
end))

-- sender: max 8 collects per second so the server never rate limits you
task.spawn(function()
    while env.RAS_RUN do
        local id = table.remove(queue, 1)
        if id and State.AutoCollect then
            pcall(function() Collect:FireServer({ id }) end)
            task.wait(0.125)
        else
            task.wait(0.2)
        end
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
    Desc = "Collects every drop automatically the moment it appears",
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
