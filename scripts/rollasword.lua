-- [RELEASE] Roll a Sword | PlaceId 127788924565169 | GameId 10771796704
-- scripts/rollasword.lua

if getgenv().RAS_UNLOAD then pcall(getgenv().RAS_UNLOAD) end

local RS = game:GetService("ReplicatedStorage")

local Remotes = RS:WaitForChild("Remotes")
local DataUpdate = Remotes:WaitForChild("DataUpdate")
local Collect = Remotes:WaitForChild("Collect")

-- values follow the game's passes (x256 coins, 2x damage, fast roll, ...)
local State = {
    Boost = false,
    AutoCollect = false,
    CoinX = 256,      -- biggest coin pass is x256
    DamageX = 2,      -- 2x Damage pass
    LuckX = 1,        -- no luck pass, keep real luck unless you raise it
    RollSpeed = 2,    -- Fast Roll: roll time divided by this
    Magnet = 40,
    WalkSpeed = 32,
}

local conns, seen = {}, {}
local cleaned = false
local Window
getgenv().RAS_RUN = true

-------------------------------------------------------------------
-- DATA BOOST (client-side only, based on your REAL data)
-------------------------------------------------------------------
local lastData = {
    PassiveTree = { vstart = 1 }, PotionLeft = 0, Coins = 251, TotalRolls = 6,
    WalkSpeed = 16, Damage = 1.25, Potions = {}, PendingPrice = 239,
    Guide = { Swords = true, AutoRollConfig = true }, LikeInGroup = true,
    PotionMult = 1, Magnet = 12, Slots = 2, Enchants = {}, AbilityPlaytest = false,
    Vault2 = "", LastPackOpen = {}, DiamondChance = 0.03,
    MutBonus = { MutGold = 0, MutRadioactive = 0, MutRainbow = 0 },
    Tree = { magnet1 = 1, dmg1 = 1, start = 1 }, OfflinePct = 0.1,
    PlayerTree = { pstart = 1 }, Passes = { x2Coins = true }, BestWave = 10,
    ExtraPending = {}, MaxAlive = 3, VaultSlots = 1, Vault3 = "", Tutorial = 5,
    ServerLuck = { EndsAt = 0, Level = 0, Multiplier = 1, Busy = false },
    PendingId = "BronzeGladius", UnopenedPacks = {},
    Settings = { AutoRollSkipThrough = 0 }, CoinMult = 2, Expanded = false,
    PassiveRate = 2.3, LikeReward = 2300, GoldenCharge = 0, RainbowSlot = false,
    RollTime = 2.6,
    Index = { RustySword = true, BentBlade = true, BronzeGladius = true, StoneSword = true, CopperShortsword = true },
    Upgrades = { Magnet = 0, Luck = 0, Speed = 0, Damage = 0, Slots = 0, Coins = 0 },
    Podiums = 1, GemTree = { gstart = 1 }, PaidSwords = {}, Diamonds = 3,
    PassiveMult = 1, Expanded2 = false, Luck = 1,
    Equipped = { "StoneSword", "BentBlade" },
    Daily = { Streak = 1, Last = 1793765705, Now = 1793765913 },
    Plot = 1, OfflineHours = 2, RollCost = 0, LikeClaimed = false, Rebirths = 0,
    StarterClaimed = false, Vault = "", Wave = 10,
    Swords = { CopperShortsword = 1, BentBlade = 1, StoneSword = 1 },
    Dps = 13.75, RainbowCharge = 0, LikePlayLeft = 148.2, AutoEquip = true,
    PaidRandomAllowed = true,
}

-- pass flags from the Passes screenshot (only x2Coins is a confirmed key name)
local PASS_KEYS = {
    "x2Coins", "x4Coins", "x8Coins", "x16Coins", "x32Coins", "x64Coins", "x128Coins", "x256Coins",
    "FastRoll", "VIP", "AutoCollect", "AutoRoll", "x2Diamonds", "2xDiamonds", "x2Damage", "2xDamage",
}

local firedByUs = setmetatable({}, { __mode = "k" })
local pending = false

local function applyBoost(data)
    -- real values stay the base, passes only multiply them
    local passes = {}
    if type(data.Passes) == "table" then
        for k, v in pairs(data.Passes) do passes[k] = v end
    end
    for _, key in ipairs(PASS_KEYS) do passes[key] = true end
    data.Passes = passes

    data.CoinMult = State.CoinX
    data.Damage = (tonumber(data.Damage) or 1) * State.DamageX
    data.Dps = (tonumber(data.Dps) or 1) * State.DamageX
    data.Luck = (tonumber(data.Luck) or 1) * State.LuckX
    data.RollTime = math.max((tonumber(data.RollTime) or 2.6) / State.RollSpeed, 0.2)
    data.Magnet = State.Magnet
    data.WalkSpeed = State.WalkSpeed
    return data
end

local function fireBoost()
    local data = applyBoost(table.clone(lastData))
    firedByUs[data] = true
    pcall(function()
        firesignal(DataUpdate.OnClientEvent, data)
    end)
end

-- at most one boost every 0.5s
local function scheduleBoost()
    if pending or not State.Boost then return end
    pending = true
    task.delay(0.5, function()
        pending = false
        if State.Boost and getgenv().RAS_RUN then
            fireBoost()
        end
    end)
end

table.insert(conns, DataUpdate.OnClientEvent:Connect(function(data)
    if type(data) ~= "table" or firedByUs[data] then return end
    for k, v in pairs(data) do lastData[k] = v end
    scheduleBoost()
end))

local function setBoost(on)
    State.Boost = on and true or false
    if State.Boost then scheduleBoost() end
end

local function setStat(key, value)
    State[key] = value
    scheduleBoost()
end

-------------------------------------------------------------------
-- AUTO COLLECT (each drop once, rate limited, sane ids only)
-------------------------------------------------------------------
local queue = {}

local function dropId(inst)
    local n = tonumber(inst.Name)
        or inst:GetAttribute("Id") or inst:GetAttribute("ID")
        or inst:GetAttribute("DropId") or inst:GetAttribute("Drop")
    n = tonumber(n)
    if n and n >= 1 and n < 10000000 and n % 1 == 0 then
        return n
    end
end

local function consider(inst)
    if not State.AutoCollect then return end
    local id = dropId(inst)
    if id and not seen[id] then
        seen[id] = true
        queue[#queue + 1] = id
        task.delay(30, function() seen[id] = nil end) -- allow id reuse after 30s
    end
end

local function setCollect(on)
    State.AutoCollect = on and true or false
    if State.AutoCollect then
        -- pick up what is already lying around, once
        for _, inst in ipairs(workspace:GetDescendants()) do
            consider(inst)
        end
    else
        table.clear(queue)
    end
end

table.insert(conns, workspace.DescendantAdded:Connect(function(inst)
    task.defer(consider, inst)
end))

-- sender: max 8 collects per second
task.spawn(function()
    while getgenv().RAS_RUN do
        local id = table.remove(queue, 1)
        if id and State.AutoCollect then
            pcall(function() Collect:FireServer({ id }) end)
            task.wait(0.125)
        else
            task.wait(0.2)
        end
    end
end)

-------------------------------------------------------------------
-- UNLOAD
-------------------------------------------------------------------
local function cleanup()
    if cleaned then return end
    cleaned = true
    getgenv().RAS_RUN = false
    State.Boost, State.AutoCollect = false, false
    table.clear(queue)
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
end

getgenv().RAS_UNLOAD = function()
    cleanup()
    if Window then pcall(function() Window:Destroy() end) end
end

-------------------------------------------------------------------
-- UI (igkii_lib)
-------------------------------------------------------------------
local Library = getgenv().igkii_lib or loadstring(getgenv().IGKII_FETCH("igkii_lib.lua"))()

Window = Library.Window({ Title = "Roll a Sword" })
Window:OnDestroy(cleanup)

local Main = Window:Tab({ Name = "Main", PageTitle = "Roll a Sword", Desc = "Stats follow the game's passes (client side)" })

Main:Section("Features")

Main:Toggle({
    Name = "OP Stats",
    Desc = "Turns on every pass client-side and multiplies your real stats",
    Default = false,
    Flag = "RAS.Boost",
    Callback = setBoost,
})

Main:Toggle({
    Name = "Auto Collect Drops",
    Desc = "Collects each drop once, max 8 per second",
    Default = false,
    Flag = "RAS.AutoCollect",
    Callback = setCollect,
})

Main:Section("Stats")

Main:Slider({
    Name = "Luck", Min = 1, Max = 100, Step = 1, Suffix = "x",
    Default = State.LuckX, Flag = "RAS.Luck",
    Callback = function(v) setStat("LuckX", v) end,
})

Main:Slider({
    Name = "Damage", Min = 1, Max = 100, Step = 1, Suffix = "x",
    Default = State.DamageX, Flag = "RAS.Damage",
    Desc = "2x is the Damage pass",
    Callback = function(v) setStat("DamageX", v) end,
})

Main:Slider({
    Name = "Multiplier", Min = 1, Max = 1024, Step = 1, Suffix = "x",
    Default = State.CoinX, Flag = "RAS.Mult",
    Desc = "Coin multiplier, 256 is the biggest coin pass",
    Callback = function(v) setStat("CoinX", v) end,
})

Main:Slider({
    Name = "Magnet", Min = 12, Max = 200, Step = 1,
    Default = State.Magnet, Flag = "RAS.Magnet",
    Callback = function(v) setStat("Magnet", v) end,
})

Main:Slider({
    Name = "WalkSpeed", Min = 16, Max = 100, Step = 1,
    Default = State.WalkSpeed, Flag = "RAS.WalkSpeed",
    Callback = function(v) setStat("WalkSpeed", v) end,
})

Main:Section("Script")

Main:Button({
    Name = "Unload",
    Desc = "Stops everything and closes the UI",
    Callback = function() getgenv().RAS_UNLOAD() end,
})
