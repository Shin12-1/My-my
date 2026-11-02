-- igkii loader: one link, many games (served through the Worker)
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local env = (getgenv and getgenv()) or _G

local BASE = "https://igkii.kiantejero.workers.dev/"   -- your real Worker link, no slash at the end

-- [PlaceId or GameId] = { "Display name", "path inside the repo" }
local routes = {
    [97617452700163]  = { "Naruto Eye game", "scripts/autocast.lua" },  -- PlaceId
    [10770933473]     = { "Naruto Eye game", "scripts/autocast.lua" },  -- GameId
    [123331132687572] = { "Game 2 (Misc)",    "scripts/misc.lua" },     -- PlaceId
    [10340746117]     = { "Game 2 (Misc)",    "scripts/misc.lua" },     -- GameId
}

if BASE:find("YOUR%-NAME") then
    warn("[igkii] BASE still has the placeholder. Put your real Worker link in loader.lua")
    return
end

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
        return body, BASE .. "/" .. path
    end
    local fallback = get(BASE .. "/scripts/" .. path)
    if fallback then
        return fallback, BASE .. "/scripts/" .. path
    end
    return nil, err
end

local route = routes[game.PlaceId] or routes[game.GameId]
if not route then
    warn("[igkii] no script for this game (PlaceId " .. game.PlaceId .. ", GameId " .. game.GameId .. ")")
    return
end

env.IGKII_FETCH = function(path)
    local body, where = fetch(path)
    assert(body, "could not download " .. path .. ": " .. tostring(where))
    if body:sub(1, 1) == "<" then
        error("got a web page instead of Lua from " .. tostring(where) .. " : " .. body:sub(1, 150))
    end
    return body
end

local source, where = fetch(route[2])
if not source then
    warn("[igkii] could not download " .. route[1] .. ": " .. tostring(where))
    return
end

if source:sub(1, 1) == "<" then
    warn("[igkii] " .. route[1] .. " came back as a web page, not Lua")
    warn("[igkii] link used: " .. tostring(where))
    warn("[igkii] it starts with: " .. source:sub(1, 150))
    return
end

local fn, compileErr = loadstring(source)
if not fn then
    warn("[igkii] " .. route[1] .. " has a syntax error: " .. tostring(compileErr))
    warn("[igkii] it starts with: " .. source:sub(1, 150))
    return
end

local ok, runErr = pcall(fn)
if not ok then
    warn("[igkii] " .. route[1] .. " errored: " .. tostring(runErr))
end
