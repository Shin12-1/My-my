-- igkii loader: one link, many games
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local env = (getgenv and getgenv()) or _G
local BASE = "https://igkii.kiantejero.workers.dev"

local routes = {
    [97617452700163] = { "Naruto Eye game", "scripts/autocast.lua" },
    [10770933473]    = { "Naruto Eye game", "scripts/autocast.lua" },
}

local http = request or http_request

local function get(url)
    -- CACHE BUSTER: Forces a fresh download every time
    local separator = url:find("%?") and "&" or "?"
    url = url .. separator .. "t=" .. tostring(os.time()) .. math.random(1000, 9999)

    if TOKEN ~= "" and http then
        local ok, res = pcall(http, { Url = url, Method = "GET", Headers = { Authorization = "token " .. TOKEN } })
        if ok and res and res.StatusCode == 200 then return res.Body end
        return nil, "HTTP Error"
    end
    
    local ok, body = pcall(game.HttpGet, game, url)
    if ok then return body end
    return nil, tostring(body)
end

local function fetch(path)
    local body = get(BASE .. "/" .. path)
    if body then return body end
    if path:sub(1, 8) ~= "scripts/" then
        local fallback = get(BASE .. "/scripts/" .. path)
        if fallback then return fallback end
    end
    return nil, "Not found"
end

local route = routes[game.PlaceId] or routes[game.GameId]
if not route then return warn("Game not supported") end

env.IGKII_FETCH = function(path)
    local body, err = fetch(path)
    assert(body, "could not download " .. path .. ": " .. tostring(err))
    return body
end

local source, err = fetch(route[2])
if not source then return warn("Could not download: " .. tostring(err)) end

local fn, compileErr = loadstring(source)
if not fn then return warn("Syntax error: " .. tostring(compileErr)) end

local ok, runErr = pcall(fn)
if not ok then warn("Error: " .. tostring(runErr)) end
