-- +1 Hacker Evolve | igkii UI
-- PlaceId 75821372602076 | GameId 10772139684
-- Auto Click | Auto Pops (real mouse click + remote, skips paid pops) | Auto Rebirth (stays in place) | Auto Evolve

local env = (getgenv and getgenv()) or _G
local fetch = env.IGKII_FETCH
if not fetch then
    warn("[HackerEvolve] run this through the loader")
    return
end

if env.HE_UNLOAD then pcall(env.HE_UNLOAD) end

local okLoad, Library = pcall(function()
    return loadstring(fetch("igkii_lib.lua"))()
end)
if not okLoad or type(Library) ~= "table" then
    warn("[HackerEvolve] could not load the UI library: " .. tostring(Library))
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local pg = LocalPlayer:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local ClickToEarn = Remotes and Remotes:WaitForChild("ClickToEarn", 10)     -- RemoteEvent, FireServer() (fired by PlayerScripts.StepToEarn)
local TrainingPops = Remotes and Remotes:WaitForChild("TrainingPops", 10)   -- RemoteEvent, FireServer(popId)
local RebirthRemote = ReplicatedStorage:WaitForChild("RebirthRemote", 10)   -- RemoteEvent, FireServer() (ReplicatedStorage root)
local EvolveRemote = ReplicatedStorage:WaitForChild("EvolveRemote", 10)     -- RemoteEvent, FireServer() (ReplicatedStorage root)

if not (ClickToEarn and TrainingPops and RebirthRemote and EvolveRemote) then
    warn("[HackerEvolve] a remote was not found, the game may have changed.")
end

-- ============== CONFIG ==============
local CLICK_DELAY = 0.47      -- the game's own client clicks every ~0.47s
local POP_DELAY = 0.6         -- the game's own client never clicked a pop sooner than ~0.57s
local MAX_POP_MULT = 3        -- free pops seen: x1.5, x2, x3. x20 opens a Robux prompt, so never go above ~10
local REBIRTH_DELAY = 3       -- the game's own client rebirths every ~3s
local EVOLVE_DELAY = 3
local HOLD_TIME = 2.5         -- seconds after a rebirth that we keep putting you back (keep it below REBIRTH_DELAY)
local USE_POP_REMOTE = true   -- also fire the remote after the mouse click (backup)
local DEBUG = true
-- ====================================

local state = {
    Alive = true,
    AutoClick = false,
    WalkWhileClick = true,
    AutoPops = false,
    AutoRebirth = false,
    StayOnRebirth = true,
    AutoEvolve = false,
    PopsClicked = 0,
}

local function dbg(...)
    if DEBUG then print("[HackerEvolve]", ...) end
end

local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

------------------------------------------------------------------
-- GUI helpers
------------------------------------------------------------------
local function isShown(obj)
    local p = obj
    while p and p ~= pg do
        if p:IsA("ScreenGui") and not p.Enabled then return false end
        if p:IsA("GuiObject") and not p.Visible then return false end
        p = p.Parent
    end
    return true
end

local function cleanText(s)
    s = tostring(s or ""):gsub("<[^>]->", "")
    s = s:lower():gsub("%s", "")
    return s
end

-- real mouse click at the center of a GUI object
local function clickGui(obj)
    local pos, size = obj.AbsolutePosition, obj.AbsoluteSize
    local x = pos.X + (size.X / 2)
    local y = pos.Y + (size.Y / 2)
    local sg = obj:FindFirstAncestorOfClass("ScreenGui")
    if sg and not sg.IgnoreGuiInset then
        y += GuiService:GetGuiInset().Y -- AbsolutePosition starts below the top bar
    end
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
        task.wait(0.005)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
    end)
end

-- finds the on-screen pop whose text matches the label (like "x2")
local function findPopButton(label)
    local want = cleanText(label)
    for _, d in ipairs(pg:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and cleanText(d.Text) == want and isShown(d) then
            local cur = d
            while cur and cur ~= pg do
                if cur:IsA("TextButton") or cur:IsA("ImageButton") then
                    return cur
                end
                cur = cur.Parent
            end
            return d
        end
    end
    return nil
end

local function dumpCandidates()
    local n = 0
    for _, d in ipairs(pg:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and cleanText(d.Text):match("^x%d") and isShown(d) then
            n += 1
            dbg("candidate:", d:GetFullName(), "text =", d.Text)
            if n >= 8 then break end
        end
    end
    if n == 0 then dbg("no visible 'xNUMBER' text found in PlayerGui") end
end

------------------------------------------------------------------
-- AUTO CLICK (+ small walk, because the click comes from StepToEarn)
------------------------------------------------------------------
local home, stepDir, lastStep = nil, 1, 0

local function stepWalk()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = getRoot()
    if not (hum and root) then return end
    if not home or (root.Position - home).Magnitude > 40 then
        home = root.Position
    end
    stepDir = -stepDir
    hum:MoveTo(home + Vector3.new(6 * stepDir, 0, 0))
end

task.spawn(function()
    while state.Alive do
        if state.AutoClick and ClickToEarn then
            if state.WalkWhileClick and os.clock() - lastStep > 0.6 then
                lastStep = os.clock()
                pcall(stepWalk)
            end
            pcall(function() ClickToEarn:FireServer() end)
            task.wait(CLICK_DELAY)
        else
            home = nil
            task.wait(0.1)
        end
    end
end)

------------------------------------------------------------------
-- STAY IN PLACE ON REBIRTH
-- The game moves you to the spawnpoint after a rebirth. We save your
-- position right before firing it, then for HOLD_TIME seconds put you
-- back whenever you are far from that spot (works for a teleport and
-- for a respawn, because the new HumanoidRootPart is picked up each tick).
------------------------------------------------------------------
local savedCFrame = nil
local holdUntil = 0

task.spawn(function()
    while state.Alive do
        if savedCFrame and os.clock() < holdUntil then
            local root = getRoot()
            if root and (root.Position - savedCFrame.Position).Magnitude > 8 then
                root.CFrame = savedCFrame
                root.AssemblyLinearVelocity = Vector3.zero
                dbg("put you back where you were")
            end
        end
        task.wait(0.05)
    end
end)

------------------------------------------------------------------
-- AUTO REBIRTH
------------------------------------------------------------------
local rebirthConn
if RebirthRemote then
    -- the server answers a rebirth with OnClientEvent, so extend the hold window
    rebirthConn = RebirthRemote.OnClientEvent:Connect(function()
        if state.StayOnRebirth and savedCFrame then
            holdUntil = os.clock() + HOLD_TIME
        end
    end)
end

task.spawn(function()
    while state.Alive do
        if state.AutoRebirth and RebirthRemote then
            if state.StayOnRebirth and os.clock() >= holdUntil then
                -- only save when we are not in the middle of a hold, so we never save the spawnpoint
                local root = getRoot()
                if root then
                    savedCFrame = root.CFrame
                    holdUntil = os.clock() + HOLD_TIME
                end
            end
            pcall(function() RebirthRemote:FireServer() end)
            task.wait(REBIRTH_DELAY)
        else
            task.wait(0.25)
        end
    end
end)

------------------------------------------------------------------
-- AUTO EVOLVE
------------------------------------------------------------------
local evolveConn
if EvolveRemote then
    evolveConn = EvolveRemote.OnClientEvent:Connect(function(tier)
        dbg("evolved, new tier:", tier)
    end)
end

task.spawn(function()
    while state.Alive do
        if state.AutoEvolve and EvolveRemote then
            pcall(function() EvolveRemote:FireServer() end)
            task.wait(EVOLVE_DELAY)
        else
            task.wait(0.25)
        end
    end
end)

------------------------------------------------------------------
-- AUTO POPS (never clicks paid pops)
-- Server sends:  TrainingPops.OnClientEvent("show", id, "x1.5", 3.5)
-- Only labels that are a plain "xNUMBER" and <= MAX_POP_MULT are clicked.
------------------------------------------------------------------
local function parseMult(label)
    local s = cleanText(label)
    local n = s:match("^x(%d+%.?%d*)$")
    return n and tonumber(n) or nil
end

local popConn
if TrainingPops then
    popConn = TrainingPops.OnClientEvent:Connect(function(kind, id, label)
        if kind ~= "show" then return end
        dbg("pop shown", id, label)
        if not (state.Alive and state.AutoPops) then return end

        local mult = parseMult(label)
        if not mult then
            dbg("pop skipped (unknown label)", label)
            return
        end
        if mult > MAX_POP_MULT then
            dbg("pop skipped (paid / above limit)", label)
            return
        end

        task.spawn(function()
            task.wait(POP_DELAY)
            if not (state.Alive and state.AutoPops) then return end

            -- the pop UI can show up a moment after the event, so retry a few times
            local btn
            for _ = 1, 8 do
                btn = findPopButton(label)
                if btn then break end
                task.wait(0.1)
            end

            if btn then
                dbg("clicking", btn:GetFullName())
                clickGui(btn)
            else
                dbg("pop button not found on screen")
                dumpCandidates()
            end

            if USE_POP_REMOTE and TrainingPops then
                pcall(function() TrainingPops:FireServer(id) end)
            end
            state.PopsClicked += 1
        end)
    end)
end

------------------------------------------------------------------
-- UI
------------------------------------------------------------------
local misc

local Window = Library.Window({ Title = "igkii" })

local features = Library.MiscFeatures(function()
    return misc
end)
table.insert(features, 1, { Name = "Auto Click",   Get = function() return state.AutoClick end })
table.insert(features, 2, { Name = "Auto Pops",    Get = function() return state.AutoPops end })
table.insert(features, 3, { Name = "Auto Rebirth", Get = function() return state.AutoRebirth end })
table.insert(features, 4, { Name = "Auto Evolve",  Get = function() return state.AutoEvolve end })

Window:BuildHome(features, {
    { Title = "Place ID", Get = function() return tostring(game.PlaceId) end },
    { Title = "Game ID", Get = function() return tostring(game.GameId) end },
    { Title = "Pops handled", Get = function() return tostring(state.PopsClicked) end },
}, { Tier = "Hacker Evolve" })

local tab = Window:Tab({ Name = "Main", Icon = "star", PageTitle = "Main", Desc = "Auto farm" })

tab:Section("Click")
tab:Toggle({
    Name = "Auto Click",
    Desc = "Fires the click remote about every 0.47s",
    Default = false,
    Callback = function(value) state.AutoClick = value end,
})
tab:Toggle({
    Name = "Walk While Clicking",
    Desc = "Steps back and forth, because the click is tied to walking",
    Default = true,
    Callback = function(value) state.WalkWhileClick = value end,
})

tab:Section("Pops")
tab:Toggle({
    Name = "Auto Pops",
    Desc = "Clicks free pops (x1.5, x2, x3). Skips paid pops like x20",
    Default = false,
    Callback = function(value) state.AutoPops = value end,
})

tab:Section("Progress")
tab:Toggle({
    Name = "Auto Rebirth",
    Desc = "Rebirths every 3 seconds",
    Default = false,
    Callback = function(value) state.AutoRebirth = value end,
})
tab:Toggle({
    Name = "Stay In Place On Rebirth",
    Desc = "Puts you back where you were after the game sends you to spawn",
    Default = true,
    Callback = function(value) state.StayOnRebirth = value end,
})
tab:Toggle({
    Name = "Auto Evolve",
    Desc = "Tries to evolve every 3 seconds",
    Default = false,
    Callback = function(value) state.AutoEvolve = value end,
})

misc = Window:BuildMisc()

local function unload()
    state.Alive = false
    state.AutoClick = false
    state.AutoPops = false
    state.AutoRebirth = false
    state.AutoEvolve = false
    if popConn then popConn:Disconnect() end
    if evolveConn then evolveConn:Disconnect() end
    if rebirthConn then rebirthConn:Disconnect() end
    env.HE_UNLOAD = nil
end

env.HE_UNLOAD = unload

Window:OnDestroy(function()
    unload()
    if misc and misc.Unload then pcall(misc.Unload) end
end)

Window:PlayIntro()
