-- Auto Boost  |  clicks the Boost button when it shows  |  igkii UI
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
local Train = ReplicatedStorage:WaitForChild("Game")
    :WaitForChild("Remotes")
    :WaitForChild("Train")

-- ============== CONFIG ==============
local CLICK_DELAY = 0.02 -- time between clicks
-- ====================================

local state = { AutoBoost = false, Alive = true, Count = 0 }

------------------------------------------------------------------
-- Clicker logic
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

local function getButton()
    local tc = pg:FindFirstChild("TrainClick")
    return tc and tc:FindFirstChild("Click")
end

task.spawn(function()
    while state.Alive do
        if state.AutoBoost then
            local btn = getButton()
            if btn and isShown(btn) then
                local pos = btn.AbsolutePosition
                local size = btn.AbsoluteSize
                local x, y = pos.X + (size.X / 2), pos.Y + (size.Y / 2)

                -- real mouse click on the boost button
                pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
                    task.wait(0.005)
                    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
                end)

                -- remote backup
                pcall(function()
                    Train:FireServer("Boost")
                end)

                state.Count += 1
                task.wait(CLICK_DELAY)
            else
                task.wait(0.1)
            end
        else
            task.wait(0.1)
        end
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
    { Title = "Boost clicks", Get = function() return tostring(state.Count) end },
}, { Tier = "Boost game" })

local tab = Window:Tab({ Name = "Main", Icon = "star", PageTitle = "Main", Desc = "Auto boost" })
tab:Section("Boost")
tab:Toggle({
    Name = "Auto Boost",
    Desc = "Clicks the boost button as soon as it shows on screen",
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
