-- Auto Boost  |  clicks the Boost popup when it shows  |  igkii UI
local env = (getgenv and getgenv()) or _G
local fetch = env.IGKII_FETCH
if not fetch then
    warn("[AutoBoost] run this through the loader")
    return
end

local okLoad, Library = pcall(function()
    return loadstring(fetch("igkii_lib.lua"))()
end)
if not okLoad or type(Library) ~= "table" then
    warn("[AutoBoost] could not load the UI library: " .. tostring(Library))
    return
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
local Train = RS:WaitForChild("Game"):WaitForChild("Remotes"):WaitForChild("Train")

local state = { AutoBoost = false, Alive = true, Count = 0 }
local lastFire = 0

------------------------------------------------------------------
-- Boost popup detection + click
------------------------------------------------------------------
local function onScreen(obj)
    local cur = obj
    while cur and cur ~= pg do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("LayerCollector") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return true
end

local function textOf(obj)
    local t = ""
    if obj:IsA("TextButton") then t = obj.Text end
    for _, c in ipairs(obj:GetDescendants()) do
        if c:IsA("TextLabel") or c:IsA("TextButton") then t = t .. " " .. c.Text end
    end
    return t:lower()
end

local function findBoostPopup()
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") and textOf(d):find("boost") and onScreen(d) then
            return d
        end
    end
end

local function fireBoost(btn)
    if tick() - lastFire < 1 then return end
    lastFire = tick()
    state.Count += 1
    Train:FireServer("Boost")
    if firesignal then
        pcall(function() firesignal(btn.Activated) end)
        pcall(function() firesignal(btn.MouseButton1Click) end)
    end
end

task.spawn(function()
    while state.Alive do
        if state.AutoBoost then
            local btn = findBoostPopup()
            if btn then fireBoost(btn) end
        end
        task.wait(0.2)
    end
end)

------------------------------------------------------------------
-- UI
------------------------------------------------------------------
local misc

local Window = Library.Window({ Title = "igkii" })

local features = Library.MiscFeatures(function()
    return misc
end)
table.insert(features, 1, {
    Name = "Auto Boost",
    Get = function() return state.AutoBoost end,
})

Window:BuildHome(features, {
    { Title = "Place ID", Get = function() return tostring(game.PlaceId) end },
    { Title = "Game ID", Get = function() return tostring(game.GameId) end },
    { Title = "Boosts clicked", Get = function() return tostring(state.Count) end },
}, { Tier = "Boost game" })

local tab = Window:Tab({ Name = "Main", Icon = "star", PageTitle = "Main", Desc = "Auto boost" })
tab:Section("Boost")
tab:Toggle({
    Name = "Auto Boost",
    Desc = "Clicks the boost the moment it pops up on screen",
    Default = false,
    Callback = function(value)
        state.AutoBoost = value
    end,
})

misc = Window:BuildMisc()

Window:OnDestroy(function()
    state.Alive = false
    state.AutoBoost = false
    if misc and misc.Unload then pcall(misc.Unload) end
end)

Window:PlayIntro()
