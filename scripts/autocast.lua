-- Auto Cast toggle  |  ReplicatedStorage.Remotes.Cast  |  igkii UI
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local env = (getgenv and getgenv()) or _G

-- The loader provides IGKII_FETCH. This fallback lets the file also run on its own.
local fetch = env.IGKII_FETCH or function(path)
    return game:HttpGet("https://igkii.kiantejero.workers.dev/scripts/" .. path)
end

local CONFIG = {
    Args = {},            -- arguments for Cast, copy them from Cobalt
    CastsPerFrame = 1,
}

-- SAFE LOAD (This prevents Line 18 from crashing)
local okLoad, Library = pcall(function()
    local loadFn = loadstring or (getgenv and getgenv().loadstring)
    assert(type(loadFn) == "function", "loadstring missing")

    local source = fetch("igkii_lib.lua")
    assert(type(source) == "string" and source ~= "", "Library download was empty (404)")

    local chunk, compileErr = loadFn(source, "igkii_lib")
    assert(chunk, "Compile error: " .. tostring(compileErr))
    return chunk()
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
    if not enabled then return end
    for _ = 1, castsPerFrame do pcall(cast) end
end)

local Window = Library.Window({ Title = "Auto Cast" })
Window:BuildHome({ { Name = "Auto Cast", Get = function() return enabled end } }, nil, { Tier = "Cast" })

local main = Window:Tab({ Name = "Main", Icon = "star", PageTitle = "Main", Desc = "Auto clicker" })
local box = main:Groupbox({ Name = "Auto Cast", Side = "Left" })

box:Toggle({
    Name = "Auto Cast",
    Desc = "Fires Remotes.Cast every frame",
    Flag = "AutoCast",
    Callback = function(value) enabled = value end,
})

box:Slider({
    Name = "Casts per frame",
    Min = 1, Max = 10, Step = 1,
    Default = castsPerFrame,
    Flag = "CastsPerFrame",
    Callback = function(value) castsPerFrame = value end,
})

Window:BuildMisc()

Window:OnDestroy(function()
    enabled = false
    connection:Disconnect()
end)

Window:PlayIntro()
