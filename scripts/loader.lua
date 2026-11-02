-- igkii loader: one link, many games (served through the Worker)
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local env = (getgenv and getgenv()) or _G

local BASE = "https://igkii.YOUR-NAME.workers.dev"   -- your Worker link, no slash at the end

-- [PlaceId or GameId] = { "Display name", "path inside the repo" }
local routes = {
    [97617452700163]  = { "Naruto Eye game", "scripts/autocast.lua" },  -- PlaceId
    [10770933473]     = { "Naruto Eye game", "scripts/autocast.lua" },  -- GameId
    [123331132687572] = { "Game 2 (Misc)",    "scripts/misc.lua" },     -- PlaceId
    [10340746117]     = { "Game 2 (Misc)",    "scripts/misc.lua" },     -- GameId
}

local function get(url)
    local ok, body = pcall(game.HttpGet, game, url)
    if ok then
        return body
    end
    return nil, tostring(body)
end

-- Looks in the repo root first, then in the scripts folder.
local function fetch(path)
    local body, err = get(BASE .. "/" .. path)
    if body then
        return body
    end
    local fallback = get(BASE .. "/scripts/" .. path)
    if fallback then
        return fallback
    end
    return nil, err
end

local route = routes[game.PlaceId] or routes[game.GameId]
if not route then
    warn("[igkii] no script for this game (PlaceId " .. game.PlaceId .. ", GameId " .. game.GameId .. ")")
    return
end

env.IGKII_FETCH = function(path)
    local body, err = fetch(path)
    assert(body, "could not download " .. path .. ": " .. tostring(err))
    return body
end

local source, err = fetch(route[2])
if not source then
    warn("[igkii] could not download " .. route[1] .. ": " .. tostring(err))
    return
end

local fn, compileErr = loadstring(source)
if not fn then
    warn("[igkii] " .. route[1] .. " has a syntax error: " .. tostring(compileErr))
    return
end

local ok, runErr = pcall(fn)
if not ok then
    warn("[igkii] " .. route[1] .. " errored: " .. tostring(runErr))
end
