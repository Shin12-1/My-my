-- Misc only  |  igkii UI
local env = (getgenv and getgenv()) or _G
local fetch = env.IGKII_FETCH
if not fetch then
    warn("[Misc] run this through the loader")
    return
end

local ok, Library = pcall(function()
    return loadstring(fetch("igkii_lib.lua"))()
end)
if not ok or type(Library) ~= "table" then
    warn("[Misc] could not load the UI library: " .. tostring(Library))
    return
end

local Window = Library.Window({ Title = "Misc" })
Window:BuildMisc()
Window:PlayIntro()
