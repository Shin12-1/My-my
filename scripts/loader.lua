-- igkii loader v3  |  one link, many games (served through the Worker)
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local env = (getgenv and getgenv()) or _G

--==================================================================
-- 1. CONFIG  -  the only part you edit. The loader below only reads it.
--==================================================================
local Config = {
    Version = "3.0",

    -- Trusted source: scripts are only ever downloaded from this origin.
    Origin       = "https://igkii.kiantejero.workers.dev", -- no slash at the end
    TrustedHosts = { "igkii.kiantejero.workers.dev" },

    -- Where a module is looked up, in this order ("" = repo root).
    SearchRoots = { "", "scripts/" },

    -- Integrity pinning. Put the SHA-256 of a reviewed file here and the loader
    -- refuses to run it if the downloaded content differs by even one byte.
    -- Strict = true also refuses every file that is NOT pinned.
    -- To get the hashes: getgenv().IGKII_PRINT_HASHES = true, run the loader, copy from the output.
    Strict = false,
    Hashes = {
        -- ["scripts/universal.lua"] = "64 hex characters",
        -- ["scripts/igkii_lib.lua"] = "64 hex characters",
    },

    -- Networking
    Attempts   = 3,                 -- download tries per file
    RetryDelay = 0.75,              -- seconds, grows with every try
    MaxBytes   = 2 * 1024 * 1024,   -- refuse anything bigger than this

    -- Debug switches (set before running the loader: getgenv().IGKII_DEBUG = true)
    Debug       = env.IGKII_DEBUG == true,
    NoCache     = env.IGKII_NOCACHE == true,       -- adds ?v=<time> to skip the Worker cache
    PrintHashes = env.IGKII_PRINT_HASHES == true,

    -- Loaded when the game is not listed, or when a game script cannot be downloaded.
    Fallback = { name = "Universal", path = "scripts/universal.lua" },

    -- One block per game. ids = every PlaceId and GameId of that game.
    Games = {
        { name = "Naruto Eye game",             path = "scripts/autocast.lua",     ids = { 97617452700163, 10770933473 } },
        { name = "Shovel Snow For Eggs",        path = "scripts/autoboost.lua",    ids = { 103675241402197, 10772277337 } },
        { name = "[RELEASE] Roll a Sword",      path = "scripts/rollasword.lua",   ids = { 127788924565169, 10771796704 } },
        { name = "+1 Sword Warrior Evolution",  path = "scripts/swordwarrior.lua", ids = { 109057858722721, 10770511289 } },
        { name = "+1 Hacker Evolve",            path = "scripts/hackerevolve.lua", ids = { 75821372602076, 10772139684 } },
    },
}

local function deepFreeze(t)
    if type(t) ~= "table" then return t end
    for _, v in pairs(t) do deepFreeze(v) end
    if table.freeze and not table.isfrozen(t) then table.freeze(t) end
    return t
end
pcall(deepFreeze, Config)

--==================================================================
-- 2. SMALL UTILITIES
--==================================================================
local function log(...)
    print("[igkii]", ...)
end

local function debugLog(...)
    if Config.Debug then
        print("[igkii:debug]", ...)
    end
end

local function pause(seconds)
    if task and task.wait then task.wait(seconds) else wait(seconds) end
end

local function trace(e)
    return debug.traceback(tostring(e), 2)
end

--==================================================================
-- 3. SECURITY  (trusted origin, safe paths, body checks, SHA-256)
--==================================================================

-- 3.1 The origin must be https and its host must be on the allow-list.
local function checkOrigin()
    local host = Config.Origin:match("^https://([%w%.%-]+)$")
    if not host then
        return false, "Origin must look like https://host (no path, no slash at the end)"
    end
    for _, trusted in ipairs(Config.TrustedHosts) do
        if host == trusted then
            return true
        end
    end
    return false, "host '" .. host .. "' is not in Config.TrustedHosts"
end

-- 3.2 A module path must be a plain relative path to a .lua file inside the repo.
--     This stops "../", full URLs, query strings and anything pointing at another host.
local function normalizePath(path)
    if type(path) ~= "string" or path == "" then
        return nil, "path must be a non-empty string"
    end
    if #path > 120 then
        return nil, "path is too long"
    end
    if path:find("[^%w_%-%./]") then
        return nil, "path has illegal characters (only letters, digits, _ - . / are allowed)"
    end
    if path:sub(1, 1) == "/" or path:find("%.%.") or path:find("//") then
        return nil, "path must be relative and cannot contain '..' or '//'"
    end
    if not path:match("%.lua$") then
        return nil, "path must end with .lua"
    end
    return path
end

-- 3.3 Checks the downloaded text before it ever reaches loadstring.
local function validateBody(body)
    if type(body) ~= "string" or #body == 0 then
        return false, "empty response"
    end
    if #body > Config.MaxBytes then
        return false, "response is larger than " .. Config.MaxBytes .. " bytes"
    end
    if body:byte(1) == 27 then
        return false, "precompiled bytecode is refused, only Lua source is allowed"
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

-- 3.4 SHA-256 in pure Luau (works on any executor, no crypt library needed).
local sha256
do
    local K = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    }

    local band, bxor, bnot = bit32.band, bit32.bxor, bit32.bnot
    local rrotate, rshift = bit32.rrotate, bit32.rshift
    local MOD = 4294967296

    local function be32(n)
        return string.char(rshift(n, 24) % 256, rshift(n, 16) % 256, rshift(n, 8) % 256, n % 256)
    end

    sha256 = function(msg)
        local len = #msg
        local bits = len * 8
        msg = msg .. "\128" .. string.rep("\0", (55 - len) % 64)
            .. be32(math.floor(bits / MOD)) .. be32(bits % MOD)

        local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
        local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
        local w = {}

        for i = 1, #msg, 64 do
            for j = 0, 15 do
                local a, b, c, d = msg:byte(i + j * 4, i + j * 4 + 3)
                w[j] = ((a * 256 + b) * 256 + c) * 256 + d
            end
            for j = 16, 63 do
                local x, y = w[j - 15], w[j - 2]
                local s0 = bxor(rrotate(x, 7), rrotate(x, 18), rshift(x, 3))
                local s1 = bxor(rrotate(y, 17), rrotate(y, 19), rshift(y, 10))
                w[j] = (w[j - 16] + s0 + w[j - 7] + s1) % MOD
            end

            local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
            for j = 0, 63 do
                local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
                local ch = bxor(band(e, f), band(bnot(e), g))
                local t1 = (h + S1 + ch + K[j + 1] + w[j]) % MOD
                local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
                local maj = bxor(band(a, b), band(a, c), band(b, c))
                local t2 = (S0 + maj) % MOD
                h, g, f, e, d, c, b, a = g, f, e, (d + t1) % MOD, c, b, a, (t1 + t2) % MOD
            end

            h0, h1, h2, h3 = (h0 + a) % MOD, (h1 + b) % MOD, (h2 + c) % MOD, (h3 + d) % MOD
            h4, h5, h6, h7 = (h4 + e) % MOD, (h5 + f) % MOD, (h6 + g) % MOD, (h7 + h) % MOD
        end

        return string.format("%08x%08x%08x%08x%08x%08x%08x%08x", h0, h1, h2, h3, h4, h5, h6, h7)
    end
end

-- 3.5 Compares the download with the pinned hash (if any).
--     Returns ok, detail.  A failure here is final, it is never retried.
local function verifyIntegrity(relPath, body)
    local pinned = Config.Hashes[relPath]

    if not pinned then
        if Config.Strict then
            return false, relPath .. " is not pinned in Config.Hashes (Strict mode is on)"
        end
        if Config.PrintHashes then
            log("sha256 " .. relPath .. " = " .. sha256(body) .. "  (not pinned)")
        end
        return true, "unpinned"
    end

    local actual = sha256(body)
    if Config.PrintHashes then
        log("sha256 " .. relPath .. " = " .. actual)
    end
    if actual ~= tostring(pinned):lower() then
        return false, string.format(
            "%s does not match its pinned hash (expected %s..., got %s...). Refusing to run it.",
            relPath, tostring(pinned):sub(1, 12), actual:sub(1, 12))
    end
    return true, "verified"
end

--==================================================================
-- 4. DOWNLOADING  (the only place that builds URLs)
--==================================================================

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
        if okReq and type(res) == "table" then
            if res.StatusCode == 200 and type(res.Body) == "string" then
                return res.Body
            end
            return nil, "HTTP " .. tostring(res.StatusCode)
        end
    end
    return nil, firstErr
end

-- "igkii_lib.lua" -> { root/igkii_lib.lua, scripts/igkii_lib.lua }
-- "scripts/x.lua" -> { scripts/x.lua }   (never scripts/scripts/x.lua)
local function buildCandidates(path)
    local list, seen = {}, {}
    for _, root in ipairs(Config.SearchRoots) do
        local alreadyInside = root ~= "" and path:sub(1, #root) == root
        local rel = alreadyInside and path or (root .. path)
        if not seen[rel] then
            seen[rel] = true
            list[#list + 1] = { rel = rel, url = Config.Origin .. "/" .. rel }
        end
    end
    return list
end

local sourceCache = {}

-- Returns body, url        on success
--         nil, message, kind   on failure   (kind = "path" | "download" | "integrity")
local function fetchModule(path)
    local clean, pathErr = normalizePath(path)
    if not clean then
        return nil, "bad path '" .. tostring(path) .. "': " .. pathErr, "path"
    end

    local hit = sourceCache[clean]
    if hit then
        return hit.body, hit.url
    end

    local candidates = buildCandidates(clean)
    local reasons = {}

    for attempt = 1, Config.Attempts do
        reasons = {}
        for _, c in ipairs(candidates) do
            local requestUrl = Config.NoCache and (c.url .. "?v=" .. tostring(os.time())) or c.url
            debugLog("try " .. attempt .. "/" .. Config.Attempts .. "  " .. requestUrl)

            local body, err = httpGet(requestUrl)
            if not body then
                reasons[#reasons + 1] = c.url .. " -> " .. tostring(err)
            else
                local valid, why = validateBody(body)
                if not valid then
                    reasons[#reasons + 1] = c.url .. " -> " .. why
                else
                    local verified, detail = verifyIntegrity(c.rel, body)
                    if not verified then
                        return nil, detail, "integrity"
                    end
                    sourceCache[clean] = { body = body, url = c.url }
                    return body, c.url
                end
            end
        end
        if attempt < Config.Attempts then
            pause(Config.RetryDelay * attempt)
        end
    end

    return nil, string.format("download failed after %d attempts: %s",
        Config.Attempts, table.concat(reasons, "  |  ")), "download"
end

--==================================================================
-- 5. PUBLIC API for the other scripts (same checks for everyone)
--==================================================================

-- Returns the Lua source text of a module.
env.IGKII_FETCH = function(path)
    local body, info, kind = fetchModule(path)
    assert(body, "[" .. tostring(kind) .. "] " .. tostring(info))
    return body
end

-- Downloads, verifies, compiles and runs a module, returns what it returns.
-- Example:  local Library = IGKII_REQUIRE("igkii_lib.lua")
env.IGKII_REQUIRE = function(path)
    local body, info, kind = fetchModule(path)
    assert(body, "[" .. tostring(kind) .. "] " .. tostring(info))
    local fn, compileErr = loadstring(body)
    assert(fn, "[syntax] " .. tostring(path) .. ": " .. tostring(compileErr))
    return fn()
end

env.IGKII_VERSION = Config.Version
-- Auto Rejoin queues this line to run again after it rejoins the game.
env.IGKII_LOADER  = 'loadstring(game:HttpGet("' .. Config.Origin .. '/scripts/loader.lua"))()'

--==================================================================
-- 6. ROUTES  (built and checked once)
--==================================================================
local function makeRoute(name, path)
    return { name, path }   -- always a table: { "Display name", "path" }
end

local routes = {}
for index, entry in ipairs(Config.Games) do
    local label = "Config.Games[" .. index .. "]"
    local _, pathErr = normalizePath(entry.path)
    if type(entry.name) ~= "string" or entry.name == "" then
        warn("[igkii] " .. label .. " skipped: missing name")
    elseif pathErr then
        warn("[igkii] " .. label .. " (" .. entry.name .. ") skipped: " .. pathErr)
    elseif type(entry.ids) ~= "table" or #entry.ids == 0 then
        warn("[igkii] " .. label .. " (" .. entry.name .. ") skipped: no ids")
    else
        for _, id in ipairs(entry.ids) do
            if type(id) ~= "number" then
                warn("[igkii] " .. label .. " (" .. entry.name .. ") has a non-number id: " .. tostring(id))
            elseif routes[id] then
                warn("[igkii] id " .. id .. " is listed twice (" .. routes[id][1] .. " and " .. entry.name .. "), keeping the first")
            else
                routes[id] = makeRoute(entry.name, entry.path)
            end
        end
    end
end

local FALLBACK = makeRoute(Config.Fallback.name, Config.Fallback.path)

--==================================================================
-- 7. LAUNCH
--==================================================================

-- Returns ok, stage ("path" | "download" | "integrity" | "syntax" | "runtime"), detail
local function launch(route)
    local source, info, kind = fetchModule(route[2])
    if not source then
        return false, kind, info
    end

    local fn, compileErr = loadstring(source)
    if not fn then
        return false, "syntax", compileErr
    end

    local ok, runErr = xpcall(fn, trace)
    if not ok then
        return false, "runtime", runErr
    end
    return true
end

local function main()
    local originOk, originErr = checkOrigin()
    if not originOk then
        warn("[igkii] untrusted source, nothing was loaded: " .. originErr)
        return
    end

    local route = routes[game.PlaceId] or routes[game.GameId] or FALLBACK
    env.IGKII_GAME = route[1]

    log(string.format("v%s | PlaceId %s, GameId %s -> %s%s",
        Config.Version, tostring(game.PlaceId), tostring(game.GameId), route[1],
        Config.Strict and " | strict" or ""))

    local ok, stage, detail = launch(route)
    if ok then
        return
    end

    warn(string.format("[igkii] %s failed (%s): %s", route[1], stage, tostring(detail)))

    -- Only a missing or broken download falls back to Universal.
    -- "integrity" is never bypassed, "runtime" is not retried (the UI may already be on screen).
    if (stage == "download" or stage == "syntax") and route ~= FALLBACK then
        warn("[igkii] loading the Universal script instead")
        env.IGKII_GAME = FALLBACK[1]
        local okFb, stageFb, detailFb = launch(FALLBACK)
        if not okFb then
            warn(string.format("[igkii] %s failed (%s): %s", FALLBACK[1], stageFb, tostring(detailFb)))
        end
    end
end

if env.IGKII_BUSY then
    warn("[igkii] the loader is already running, ignoring this second execute")
    return
end

env.IGKII_BUSY = true
local okMain, mainErr = xpcall(main, trace)
env.IGKII_BUSY = nil
if not okMain then
    warn("[igkii] loader error: " .. tostring(mainErr))
end
