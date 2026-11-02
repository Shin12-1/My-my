-- Universal  |  Home + Misc in any game  |  igkii UI
local env = (getgenv and getgenv()) or _G
local fetch = env.IGKII_FETCH
if not fetch then
    warn("[Universal] run this through the loader")
    return
end

local okLoad, Library = pcall(function()
    return loadstring(fetch("igkii_lib.lua"))()
end)
if not okLoad or type(Library) ~= "table" then
    warn("[Universal] could not load the UI library: " .. tostring(Library))
    return
end

local misc

local Window = Library.Window({ Title = "igkii" })

-- Home first (it shows the game it detected), then the Misc tab.
Window:BuildHome(Library.MiscFeatures(function()
    return misc
end), {
    { Title = "Place ID", Get = function() return tostring(game.PlaceId) end },
    { Title = "Game ID", Get = function() return tostring(game.GameId) end },
}, { Tier = "Universal" })

misc = Window:BuildMisc()

Window:PlayIntro()
