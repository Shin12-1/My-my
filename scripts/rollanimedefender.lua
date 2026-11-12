-- Roll an Anime Defender | PlaceId 125943787415271 | GameId 10767655620
-- scripts/rollanimedefender.lua  (loaded by loader.lua, UI from igkii_lib.lua)

local env = (getgenv and getgenv()) or _G
local fetch = env.IGKII_FETCH

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local StartStage = Remotes:WaitForChild("StartStage")
local BuyUpgrade = Remotes:WaitForChild("BuyUpgrade")

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------
local CONFIG = {
    StageId       = "W6S5", -- stage used by Auto Replay
    ReplayDelay   = 5,      -- seconds between StartStage calls
    UpgradeDelay  = 0.4,    -- seconds between upgrade rounds
    MaxBatch      = 100,    -- amount sent per call while doing MAX
    MaxCallsPerRound = 25,  -- safety cap for MAX (calls per upgrade per round)
}

local UPGRADES = {
    { Id = "luckFlat",            Name = "Luck (Flat)" },
    { Id = "rollSpeedPercent",    Name = "Roll Speed %" },
    { Id = "luckPercent",         Name = "Luck %" },
    { Id = "borderChancePercent", Name = "Border Chance %" },
    { Id = "potionDuration",      Name = "Potion Duration" },
}

local AMOUNTS = { "x1", "x10", "x100", "MAX" }

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------
local state = {
    replay   = false,
    upgrade  = false,
    amount   = "x1",
    selected = {},       -- [upgradeId] = true
    alive    = true,
}
for _, u in ipairs(UPGRADES) do
    state.selected[u.Id] = false
end

---------------------------------------------------------------------
-- FUNCTIONS
---------------------------------------------------------------------
local function buyOnce(id, amount)
    local ok, res = pcall(function()
        return BuyUpgrade:InvokeServer(id, amount)
    end)
    return ok and res
end

local function buyUpgrade(id)
    if state.amount == "x1" then
        buyOnce(id, 1)
    elseif state.amount == "x10" then
        buyOnce(id, 10)
    elseif state.amount == "x100" then
        buyOnce(id, 100)
    else
        -- MAX: keep buying in big batches until the server refuses
        for _ = 1, CONFIG.MaxCallsPerRound do
            if not state.alive or not state.upgrade then break end
            if not buyOnce(id, CONFIG.MaxBatch) then
                -- batch refused, finish with smaller steps
                local progressed = false
                for _, step in ipairs({ 10, 1 }) do
                    while state.alive and state.upgrade and buyOnce(id, step) do
                        progressed = true
                        task.wait()
                    end
                end
                break
            end
            task.wait()
        end
    end
end

task.spawn(function()
    while state.alive do
        if state.upgrade then
            for _, u in ipairs(UPGRADES) do
                if not state.alive or not state.upgrade then break end
                if state.selected[u.Id] then
                    buyUpgrade(u.Id)
                    task.wait(0.05)
                end
            end
        end
        task.wait(CONFIG.UpgradeDelay)
    end
end)

task.spawn(function()
    while state.alive do
        if state.replay then
            pcall(function()
                StartStage:InvokeServer(CONFIG.StageId)
            end)
            task.wait(CONFIG.ReplayDelay)
        else
            task.wait(0.25)
        end
    end
end)

-- anti AFK (always on)
local VirtualUser = game:GetService("VirtualUser")
local afkConn = Players.LocalPlayer.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

---------------------------------------------------------------------
-- UI (igkii lib)
---------------------------------------------------------------------
local Library = loadstring(fetch("igkii_lib.lua"))()

local misc = {}
Library.MiscFeatures(function() return misc end)

local Window = Library.Window({ Title = "Roll an Anime Defender" })

local features = {
    { Name = "Auto Replay",  Get = function() return state.replay end },
    { Name = "Auto Upgrade", Get = function() return state.upgrade end },
}
Window:BuildHome(features, {
    { Title = "Stage",  Get = function() return CONFIG.StageId end },
    { Title = "Amount", Get = function() return state.amount end },
}, { Tier = "Free" })

-- Main tab
local main = Window:Tab({
    Name = "Main",
    Icon = "home",
    PageTitle = "Main",
    Desc = "Auto replay stage",
})
main:Section("Stage")
main:Toggle({
    Name = "Auto Replay (" .. CONFIG.StageId .. ")",
    Desc = "Calls StartStage again and again",
    Default = false,
    Callback = function(v) state.replay = v end,
})

-- Upgrade tab
local up = Window:Tab({
    Name = "Upgrades",
    Icon = "arrow-up",
    PageTitle = "Auto Upgrade",
    Desc = "x1 / x10 / x100 / MAX",
})

up:Section("Amount")
local okDrop = pcall(function()
    up:Dropdown({
        Name = "Buy Amount",
        Desc = "x1, x10, x100 or MAX",
        Options = AMOUNTS,
        Default = "x1",
        Callback = function(v)
            if type(v) == "table" then v = v[1] end
            if v then state.amount = v end
        end,
    })
end)
if not okDrop then
    -- fallback if the lib Dropdown signature differs: one toggle per amount
    for _, a in ipairs(AMOUNTS) do
        up:Toggle({
            Name = "Amount " .. a,
            Default = (a == state.amount),
            Callback = function(v) if v then state.amount = a end end,
        })
    end
end

up:Section("Upgrades")
for _, u in ipairs(UPGRADES) do
    up:Toggle({
        Name = u.Name,
        Desc = "Buy " .. u.Id,
        Default = false,
        Callback = function(v) state.selected[u.Id] = v end,
    })
end

up:Section("Auto")
up:Toggle({
    Name = "Auto Upgrade",
    Desc = "Buys every selected upgrade with the chosen amount",
    Default = false,
    Callback = function(v) state.upgrade = v end,
})

misc = Window:BuildMisc()

Window:OnDestroy(function()
    state.alive   = false
    state.replay  = false
    state.upgrade = false
    if afkConn then afkConn:Disconnect() end
end)

Window:PlayIntro()
