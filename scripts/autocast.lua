-- Auto Cast toggle  |  ReplicatedStorage.Remotes.Cast  |  igkii UI
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local env = (getgenv and getgenv()) or _G

-- The loader provides IGKII_FETCH.
local fetch = env.IGKII_FETCH
if not fetch then
    warn("[Cast] run this through the loader")
    return
end

local CONFIG = {
    Args = {},            -- arguments for Cast, copy them from Cobalt
    CastsPerFrame = 1,
}

local okLoad, Library = pcall(function()
    return loadstring(fetch("igkii_lib.lua"))()
end)
if not okLoad or type(Library) ~= "table" then
    warn("[Cast] could not load the UI library: " .. tostring(Library))
    return
end

local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local remote = remotes and remotes:WaitForChild("Cast", 10)
if not remote then
    warn("[Cast] ReplicatedStorage.Remotes.Cast was not found")
    return
end

local enabled = false
local castsPerFrame = CONFIG.CastsPerFrame

local function cast()
    if remote:IsA("RemoteEvent") then
        remote:FireServer(table.unpack(CONFIG.Args))
    elseif remote:IsA("RemoteFunction") then
        task.spawn(function()
            remote:InvokeServer(table.unpack(CONFIG.Args))
        end)
    end
end

local connection = RunService.Heartbeat:Connect(function()
    if not enabled then
        return
    end
    for _ = 1, castsPerFrame do
        pcall(cast)
    end
end)

local misc

local Window = Library.Window({ Title = "Auto Cast" })

-- Home first, then the game's own tab, then the universal Misc tab.
local features = { { Name = "Auto Cast", Get = function() return enabled end } }
for _, feature in ipairs(Library.MiscFeatures(function() return misc end)) do
    table.insert(features, feature)
end
Window:BuildHome(features, {
    { Title = "Place ID", Get = function() return tostring(game.PlaceId) end },
    { Title = "Game ID", Get = function() return tostring(game.GameId) end },
}, { Tier = "Cast" })

local main = Window:Tab({ Name = "Main", Icon = "star", PageTitle = "Main", Desc = "Auto clicker" })
local box = main:Groupbox({ Name = "Auto Cast", Side = "Left" })

box:Toggle({
    Name = "Auto Cast",
    Desc = "Fires Remotes.Cast every frame",
    Flag = "AutoCast",
    Callback = function(value)
        enabled = value
    end,
})

box:Slider({
    Name = "Casts per frame",
    Min = 1,
    Max = 10,
    Step = 1,
    Default = castsPerFrame,
    Flag = "CastsPerFrame",
    Callback = function(value)
        castsPerFrame = value
    end,
})

misc = Window:BuildMisc()

Window:OnDestroy(function()
    enabled = false
    connection:Disconnect()
end)

Window:PlayIntro()
