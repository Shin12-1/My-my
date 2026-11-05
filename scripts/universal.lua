-- Universal v2  |  Home + Misc in any game  |  igkii UI
local env = (getgenv and getgenv()) or _G
local fetch = env.IGKII_FETCH
if not fetch then
    warn("[Universal] run this through the loader")
    return
end

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

----------------------------------------------------------------
-- Load the UI library
----------------------------------------------------------------
local okLoad, Library = pcall(function()
    local source = fetch("igkii_lib.lua")
    local fn, compileErr = loadstring(source)
    assert(fn, "syntax error in igkii_lib.lua: " .. tostring(compileErr))
    return fn()
end)

if not okLoad or type(Library) ~= "table" then
    warn("[Universal] could not load the UI library: " .. tostring(Library))
    return
end

for _, name in ipairs({ "Window", "MiscFeatures" }) do
    if type(Library[name]) ~= "function" then
        warn("[Universal] the UI library is missing Library." .. name)
        return
    end
end

----------------------------------------------------------------
-- Close the old window if the script is executed again
----------------------------------------------------------------
local previous = env.IGKII_WINDOW
if type(previous) == "table" then
    for _, method in ipairs({ "Unload", "Destroy" }) do
        if type(previous[method]) == "function" then
            pcall(previous[method], previous)
            break
        end
    end
end
env.IGKII_WINDOW = nil

----------------------------------------------------------------
-- Game info for the Home tab (each value is cached and safe to call)
----------------------------------------------------------------
local cachedName

local function gameName()
    if cachedName then
        return cachedName
    end
    local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, game.PlaceId)
    if ok and type(info) == "table" and info.Name then
        cachedName = tostring(info.Name)
    else
        cachedName = tostring(env.IGKII_GAME or "Unknown")
    end
    return cachedName
end

local function players()
    local ok, text = pcall(function()
        return #Players:GetPlayers() .. " / " .. Players.MaxPlayers
    end)
    return ok and text or "?"
end

local function executor()
    if identifyexecutor then
        local ok, name, version = pcall(identifyexecutor)
        if ok and name then
            return tostring(name) .. (version and (" " .. tostring(version)) or "")
        end
    end
    return "Unknown"
end

local info = {
    { Title = "Game",      Get = gameName },
    { Title = "Place ID",  Get = function() return tostring(game.PlaceId) end },
    { Title = "Game ID",   Get = function() return tostring(game.GameId) end },
    { Title = "Players",   Get = players },
    { Title = "Server ID", Get = function() return game.JobId ~= "" and game.JobId:sub(1, 8) or "Studio" end },
    { Title = "Executor",  Get = executor },
}

----------------------------------------------------------------
-- Build the window
----------------------------------------------------------------
local misc

local okWindow, Window = pcall(Library.Window, { Title = "igkii" })
if not okWindow or type(Window) ~= "table" then
    warn("[Universal] could not create the window: " .. tostring(Window))
    return
end
env.IGKII_WINDOW = Window

-- Home first (it shows the game it detected), then the Misc tab.
if type(Window.BuildHome) == "function" then
    local okHome, homeErr = pcall(function()
        Window:BuildHome(Library.MiscFeatures(function()
            return misc
        end), info, { Tier = "Universal" })
    end)
    if not okHome then
        warn("[Universal] Home tab failed: " .. tostring(homeErr))
    end
end

if type(Window.BuildMisc) == "function" then
    local okMisc, miscResult = pcall(function()
        return Window:BuildMisc()
    end)
    if okMisc then
        misc = miscResult
    else
        warn("[Universal] Misc tab failed: " .. tostring(miscResult))
    end
end

if type(Window.PlayIntro) == "function" then
    pcall(function()
        Window:PlayIntro()
    end)
end
