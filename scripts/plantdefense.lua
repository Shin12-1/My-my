-- [NEW] Plant Defense RNG
-- PlaceId 88986563263928 | GameId 10772529417
-- Auto Start: fires Enemies "start" again whenever the round finishes (idle / cleared)
-- Auto Buy Potions: PlantAction shopBuy on the potion slots every restock (5 min) until sold out
-- Auto Roll: clicks the Auto Roll button when it shows OFF
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
local Enemies = Remotes:WaitForChild("Enemies")         -- RemoteEvent (FireServer("start") starts a round)

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
-- GUI helpers (round end popup + Auto Roll button)
-- Your screenshots: after wave 30 a "VICTORY!" popup with a Continue button shows up,
-- and the Auto Roll button shows "ON" (green) or "OFF" (red).
----------------------------------------------------------------------
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local autoRoll = false
local lastEnd = 0
local lastRollClick = 0
local rollClicks = 0

local function norm(t)
    t = t:gsub("<[^>]+>", "")
    t = t:gsub("%s+", " ")
    return t:match("^%s*(.-)%s*$"):upper()
end

local function isShown(obj)
    local cur = obj
    while cur and cur ~= PlayerGui do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return cur == PlayerGui
end

-- real mouse click on the middle of a GUI object
local function clickGui(obj)
    local inset = Vector2.new(0, 0)
    local sg = obj:FindFirstAncestorWhichIsA("ScreenGui")
    if not sg or not sg.IgnoreGuiInset then
        inset = GuiService:GetGuiInset()
    end
    local pos, size = obj.AbsolutePosition, obj.AbsoluteSize
    local x = pos.X + size.X / 2 + inset.X
    local y = pos.Y + size.Y / 2 + inset.Y
    VirtualInputManager:SendMouseMoveEvent(x, y, game)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

local function autoRollState(title)
    local cur = title.Parent
    for _ = 1, 4 do
        if not cur or cur == PlayerGui then break end
        for _, d in ipairs(cur:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and isShown(d) then
                local t = norm(d.Text)
                if t == "ON" or t == "OFF" then
                    return t, d
                end
            end
        end
        cur = cur.Parent
    end
    return nil, nil
end

local ENDED = { ["VICTORY!"] = true, ["VICTORY"] = true, ["DEFEAT"] = true, ["DEFEAT!"] = true, ["GAME OVER"] = true }
local START_LABELS = { ["START"] = true, ["START WAVE"] = true, ["START WAVES"] = true, ["START ROUND"] = true, ["START GAME"] = true }

-- nearest clickable button: the object itself or one of its ancestors
local function buttonOf(obj)
    local cur = obj
    for _ = 1, 5 do
        if not cur or cur == PlayerGui then break end
        if cur:IsA("GuiButton") then return cur end
        cur = cur.Parent
    end
    return nil
end

-- press a GUI element, trying several methods until it disappears:
-- 1) real mouse click  2) fire the button's connections  3) select it and press Enter
local function pressGui(obj)
    pcall(clickGui, obj)
    task.wait(0.5)
    if not isShown(obj) then return true end

    local btn = buttonOf(obj)
    if btn and getconnections then
        for _, sig in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" }) do
            pcall(function()
                for _, c in ipairs(getconnections(btn[sig])) do
                    pcall(function() c:Fire() end)
                end
            end)
        end
        task.wait(0.5)
        if not isShown(obj) then return true end
    end

    if btn then
        pcall(function()
            GuiService.SelectedObject = btn
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
            task.wait(0.1)
            GuiService.SelectedObject = nil
        end)
        task.wait(0.5)
    end
    return not isShown(obj)
end

-- after a finished round: close the popup (Continue), then start again (a few tries, stops once a wave arrives)
local roundBusy = false
local function restartRound(continueLbl)
    if roundBusy then return end
    roundBusy = true
    task.spawn(function()
        if continueLbl and isShown(continueLbl) then
            pressGui(continueLbl)
            task.wait(1)
        end
        myPhase = "idle"
        for i = 1, 3 do
            if not running or not autoStart then break end
            if i > 1 then
                task.wait(3)
                if myPlot and myPhase ~= "idle" then break end -- a new wave started
            end
            if os.clock() - lastStart >= 2 then
                fireStart()
            end
        end
        roundBusy = false
    end)
end

task.spawn(function()
    while running do
        if autoStart or autoRoll then
            local ended, continueLbl, rollTitle, startLbl
            for _, d in ipairs(PlayerGui:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    local raw = d.Text
                    if raw ~= "" and #raw < 40 then
                        local n = norm(raw)
                        if ENDED[n] then
                            if isShown(d) then ended = d end
                        elseif n == "CONTINUE" then
                            if isShown(d) then continueLbl = d end
                        elseif n == "AUTO ROLL" then
                            if isShown(d) then rollTitle = d end
                        elseif START_LABELS[n] then
                            if isShown(d) then startLbl = d end
                        end
                    end
                end
            end

            -- round finished (VICTORY / DEFEAT popup, or just its Continue button is on screen)
            if autoStart and (ended or continueLbl) and not roundBusy and os.clock() - lastEnd > 4 then
                lastEnd = os.clock()
                restartRound(continueLbl)
            elseif autoStart and startLbl and not roundBusy and os.clock() - lastStart >= START_COOLDOWN then
                -- a Start button is showing: the round is not running
                myPhase = "idle"
                lastStart = os.clock()
                pcall(pressGui, startLbl)
                fireStart()
            end

            -- auto roll: click the button when it shows OFF
            if autoRoll and rollTitle and os.clock() - lastRollClick > 2 then
                local state, lbl = autoRollState(rollTitle)
                if state == "OFF" and lbl then
                    lastRollClick = os.clock()
                    rollClicks = rollClicks + 1
                    pcall(clickGui, lbl)
                end
            end
        end
        task.wait(1)
    end
end)

----------------------------------------------------------------------
-- Auto Buy Potions
-- PlantAction:InvokeServer("shopBuy", slot, cycle, 0)
-- Gus's Market has 3 slots: 1 = plant, 2 and 3 = potions (Money / Speed / Lucky).
-- cycle = the shop restock number (server time / 300, a new one every 5 minutes).
-- Each potion slot has limited stock ("2 LEFT", "LAST ONE"), so every restock we keep
-- buying a slot until the server refuses (SOLD OUT).
----------------------------------------------------------------------
local POTION_SLOTS = { 2, 3 }  -- potion slots only (slot 1 is the plant)
local MAX_PER_SLOT = 10        -- safety cap per slot per restock

local autoPotion = false
local potionsBought = 0
local potionOffset = 0         -- learned difference between our cycle number and the server's (0, -1 or 1)
local potionState = {}         -- [cycle:slot] = { done, fails, nextTry }

local function shopBuy(slot, cycle)
    local ok, a = pcall(function()
        return PlantAction:InvokeServer("shopBuy", slot, cycle, 0)
    end)
    if not ok or a == nil or a == false or type(a) == "string" then
        return false
    end
    if type(a) == "table" and (a.ok == false or a.success == false or a[1] == false) then
        return false
    end
    return true
end

local function buySlot(slot, base)
    local key = base .. ":" .. slot
    local st = potionState[key]
    if not st then
        st = { done = false, fails = 0, nextTry = 0 }
        potionState[key] = st
    end
    if st.done or st.fails >= 4 or os.clock() < st.nextTry then return end

    -- first buy: find the cycle number the server accepts (learned offset first)
    local offsets, seen = {}, {}
    for _, off in ipairs({ potionOffset, 0, -1, 1 }) do
        if not seen[off] then
            seen[off] = true
            offsets[#offsets + 1] = off
        end
    end

    local cycle, bought = nil, 0
    for _, off in ipairs(offsets) do
        if shopBuy(slot, base + off) then
            potionOffset = off
            cycle = base + off
            bought = 1
            break
        end
        task.wait(0.25)
    end

    if cycle then
        -- keep buying until the server refuses (sold out)
        while bought < MAX_PER_SLOT and running and autoPotion do
            task.wait(0.3)
            if not shopBuy(slot, cycle) then break end
            bought = bought + 1
        end
        st.done = true
        potionsBought = potionsBought + bought
    else
        -- nothing bought: sold out already, not enough money, or wrong cycle -> try again in 30s (max 4 times)
        st.fails = st.fails + 1
        st.nextTry = os.clock() + 30
    end
end

task.spawn(function()
    while running do
        if autoPotion then
            local base = math.floor(workspace:GetServerTimeNow() / 300)
            for _, slot in ipairs(POTION_SLOTS) do
                if not (running and autoPotion) then break end
                pcall(buySlot, slot, base)
            end
        end
        task.wait(3)
    end
end)

----------------------------------------------------------------------
-- UI (igkii lib)
----------------------------------------------------------------------
local Window = Library.Window({ Title = "Plant Defense RNG" })

local misc
local features = Library.MiscFeatures(function() return misc end)
table.insert(features, { Name = "Auto Delete", Get = function() return autoDelete end })
table.insert(features, { Name = "Auto Start", Get = function() return autoStart end })
table.insert(features, { Name = "Auto Roll", Get = function() return autoRoll end })
table.insert(features, { Name = "Auto Buy Potions", Get = function() return autoPotion end })

Window:BuildHome(features, {
    { Title = "Auto Delete", Get = function() return autoDelete and "ON" or "OFF" end },
    { Title = "Auto Start", Get = function() return autoStart and "ON" or "OFF" end },
    { Title = "Auto Roll", Get = function() return autoRoll and "ON" or "OFF" end },
    { Title = "Auto Buy Potions", Get = function() return autoPotion and "ON" or "OFF" end },
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

tab:Section("Auto Roll")
tab:Toggle({
    Name = "Auto Roll",
    Desc = "Clicks the Auto Roll button whenever it is OFF",
    Default = false,
    Callback = function(value)
        autoRoll = value
        if value then
            lastRollClick = 0
        end
    end,
})

tab:Section("Shop")
tab:Toggle({
    Name = "Auto Buy Potions",
    Desc = "Buys the potions (slots 2 and 3) every restock until they are sold out",
    Default = false,
    Callback = function(value)
        autoPotion = value
        if value then
            potionState = {}
        end
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
    autoRoll = false
    autoPotion = false
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    env.PDR_UNLOAD = nil
end)

env.PDR_UNLOAD = function()
    running = false
    autoDelete = false
    autoStart = false
    autoRoll = false
    autoPotion = false
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    pcall(function() Window:Destroy() end)
end

Window:PlayIntro()
