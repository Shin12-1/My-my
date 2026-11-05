-- igkii loader v2  |  one link, many games (served through the Worker)
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local env = (getgenv and getgenv()) or _G

----------------------------------------------------------------
-- Settings
----------------------------------------------------------------
local BASE        = "https://igkii.kiantejero.workers.dev" -- your Worker link, no slash at the end
local VERSION     = "2.0"
local ATTEMPTS    = 3      -- download tries before giving up
local RETRY_DELAY = 0.75   -- seconds, grows with every try
local NOCACHE     = env.IGKII_NOCACHE == true -- set getgenv().IGKII_NOCACHE = true to skip the Worker cache

-- Auto Rejoin queues this line to run again after it rejoins the game.
env.IGKII_LOADER  = 'loadstring(game:HttpGet("' .. BASE .. '/scripts/loader.lua"))()'
env.IGKII_VERSION = VERSION

----------------------------------------------------------------
-- Games  (add a new game = add one block here)
-- ids: every PlaceId and GameId of that game
-- Games that are not listed get the universal script (Home + Misc).
----------------------------------------------------------------
local GAMES = {
    {
        name = "Naruto Eye game",
        path = "scripts/autocast.lua",
        ids  = { 97617452700163, 10770933473 },      -- PlaceId, GameId
    },
    {
        name = "Shovel Snow For Eggs",
        path = "scripts/autoboost.lua",
        ids  = { 103675241402197, 10772277337 },     -- PlaceId, GameId
    },
    {
        name = "[RELEASE] Roll a Sword",
        path = "scripts/rollasword.lua",
        ids  = { 127788924565169, 10771796704 },     -- PlaceId, GameId
    },
    {
        name = "+1 Sword Warrior Evolution",
        path = "scripts/swordwarrior.lua",
        ids  = { 109057858722721, 10770511289 },     -- PlaceId, GameId
    },
    {
        name = "+1 Hacker Evolve",
        path = "scripts/hackerevolve.lua",
        ids  = { 75821372602076, 10772139684 },      -- PlaceId, GameId
    },
}

local FALLBACK = { "Universal", "scripts/universal.lua" }

-- Every route is a table { "Display name", "path" } for both the PlaceId and the GameId.
local routes = {}
for _, game_ in ipairs(GAMES) do
    for _, id in ipairs(game_.ids) do
        routes[id] = { game_.name, game_.path }
    end
end

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function pause(seconds)
    if task and task.wait then
        task.wait(seconds)
    else
        wait(seconds)
    end
end

-- Normal HttpGet first, then the executor's request function as a backup.
local function httpGet(url)
    local ok, body = pcall(game.HttpGet, game, url)
    if ok and type(body) == "string" then
        return body
    end
    local firstErr = tostring(body)

    local requestFn = request or http_request or (syn and syn.request) or (http and http.request)
    if requestFn then
        local okReq, res = pcall(requestFn, { Url = url, Method = "GET" })
        if okReq and type(res) == "table" and res.StatusCode == 200 and type(res.Body) == "string" then
            return res.Body
        end
        if okReq and type(res) == "table" then
            return nil, "HTTP " .. tostring(res.StatusCode)
        end
    end
    return nil, firstErr
end

-- Rejects empty answers, web pages and Worker/CDN error text.
local function looksLikeLua(body)
    if type(body) ~= "string" or #body == 0 then
        return false, "empty response"
    end
    local head = body:sub(1, 200)
    if head:match("^%s*<") then
        return false, "got a web page instead of Lua (starts with: " .. head:sub(1, 80) .. ")"
    end
    if head:match("^%s*[Ee]rror code") or head:match("^%s*404") then
        return false, "server error text: " .. head:sub(1, 80)
    end
    return true
end

local cache = {}

local function candidates(path)
    local list = { BASE .. "/" .. path }
    -- Looks in the repo root first, then in the scripts folder.
    if path:sub(1, 8) ~= "scripts/" then
        list[#list + 1] = BASE .. "/scripts/" .. path
    end
    return list
end

local function fetch(path)
    local hit = cache[path]
    if hit then
        return hit.body, hit.url
    end

    local lastErr = "no attempt was made"
    for attempt = 1, ATTEMPTS do
        for _, url in ipairs(candidates(path)) do
            local requestUrl = NOCACHE and (url .. "?v=" .. tostring(os.time())) or url
            local body, err = httpGet(requestUrl)
            if body then
                local valid, why = looksLikeLua(body)
                if valid then
                    cache[path] = { body = body, url = url }
                    return body, url
                end
                lastErr = url .. " -> " .. why
            else
                lastErr = url .. " -> " .. tostring(err)
            end
        end
        if attempt < ATTEMPTS then
            pause(RETRY_DELAY * attempt)
        end
    end
    return nil, lastErr
end

-- Game scripts and universal.lua use this to download igkii_lib.lua and anything else.
env.IGKII_FETCH = function(path)
    local body, where = fetch(path)
    assert(body, "could not download " .. tostring(path) .. ": " .. tostring(where))
    return body
end

-- Returns: ok, stage ("download" | "syntax" | "runtime"), detail
local function launch(route)
    local source, where = fetch(route[2])
    if not source then
        return false, "download", where
    end

    local fn, compileErr = loadstring(source)
    if not fn then
        return false, "syntax", compileErr
    end

    local ok, runErr = xpcall(fn, function(e)
        return debug.traceback(tostring(e), 2)
    end)
    if not ok then
        return false, "runtime", runErr
    end
    return true
end

----------------------------------------------------------------
-- Run
----------------------------------------------------------------
if env.IGKII_BUSY then
    warn("[igkii] the loader is already running, ignoring this second execute")
    return
end
env.IGKII_BUSY = true

local route = routes[game.PlaceId] or routes[game.GameId] or FALLBACK
env.IGKII_GAME = route[1]

print(string.format("[igkii] v%s | PlaceId %s, GameId %s -> %s",
    VERSION, tostring(game.PlaceId), tostring(game.GameId), tostring(route[1])))

local ok, stage, detail = launch(route)
if not ok then
    warn(string.format("[igkii] %s failed at %s: %s", tostring(route[1]), tostring(stage), tostring(detail)))

    -- A broken download or syntax error should not leave you with nothing:
    -- load the universal script (Home + Misc) instead.
    -- Runtime errors are not retried, the UI may already be on screen.
    if stage ~= "runtime" and route ~= FALLBACK then
        warn("[igkii] loading the Universal script instead")
        env.IGKII_GAME = FALLBACK[1]
        local okFallback, stageFallback, detailFallback = launch(FALLBACK)
        if not okFallback then
            warn(string.format("[igkii] Universal failed at %s: %s", tostring(stageFallback), tostring(detailFallback)))
        end
    end
end

env.IGKII_BUSY = nil
