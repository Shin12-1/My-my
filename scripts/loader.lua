-- igkii loader: one link, many games (served through the Worker)
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local env = (getgenv and getgenv()) or _G

local BASE = "https://igkii.kiantejero.workers.dev"   -- your Worker link, no slash at the end

-- Auto Rejoin queues this line to run again after it rejoins the game.
env.IGKII_LOADER = 'loadstring(game:HttpGet("' .. BASE .. '/scripts/loader.lua"))()'

-- [PlaceId or GameId] = { "Display name", "path inside the repo" }
-- Games that are not listed here get the universal script (Home + Misc).
local routes = {
    [97617452700163]  = { "Naruto Eye game", "scripts/autocast.lua" },        -- PlaceId
    [10770933473]     = { "Naruto Eye game", "scripts/autocast.lua" },        -- GameId
    [103675241402197] = { "Shovel Snow For Eggs", "scripts/autoboost.lua" },  -- PlaceId
    [10772277337]     = { "Shovel Snow For Eggs", "scripts/autoboost.lua" },  -- GameId
    [127788924565169] = { "[RELEASE] Roll a Sword", "scripts/rollasword.lua" }, -- PlaceId
    [10771796704]     = { "[RELEASE] Roll a Sword", "scripts/rollasword.lua" }, -- GameId
    [109057858722721] = { "+1 Sword Warrior Evolution", "scripts/swordwarrior.lua" },
    [10770511289]     = { "+1 Sword Warrior Evolution", "scripts/swordwarrior.lua" },
}
local FALLBACK = { "Universal", "scripts/universal.lua" }

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

local route = routes[game.PlaceId] or routes[game.GameId] or FALLBACK
-- safety: if a route is written as just a path string, turn it into { name, path }
if type(route) == "string" then
    route = { route, route }
end
print("[igkii] PlaceId " .. game.PlaceId .. ", GameId " .. game.GameId .. " -> " .. tostring(route[1]))

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
    warn("[igkii] could not download " .. tostring(route[1]) .. ": " .. tostring(where))
    return
end

if source:sub(1, 1) == "<" then
    warn("[igkii] " .. tostring(route[1]) .. " came back as a web page, not Lua")
    warn("[igkii] link used: " .. tostring(where))
    warn("[igkii] it starts with: " .. source:sub(1, 150))
    return
end

local fn, compileErr = loadstring(source)
if not fn then
    warn("[igkii] " .. tostring(route[1]) .. " has a syntax error: " .. tostring(compileErr))
    warn("[igkii] it starts with: " .. source:sub(1, 150))
    return
end

local ok, runErr = pcall(fn)
if not ok then
    warn("[igkii] " .. tostring(route[1]) .. " errored: " .. tostring(runErr))
end
