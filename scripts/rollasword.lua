-- [RELEASE] Roll a Sword | PlaceId 127788924565169 | GameId 10771796704
-- scripts/rollasword.lua

if getgenv().RAS_UNLOAD then pcall(getgenv().RAS_UNLOAD) end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Remotes = RS:WaitForChild("Remotes")
local DataUpdate = Remotes:WaitForChild("DataUpdate")
local Collect = Remotes:WaitForChild("Collect")

local LIB_URL = "PUT_YOUR_RAW_igkii_lib.lua_LINK_HERE"

local State = {
    Boost = false,
    AutoCollect = false,
    Luck = 1000000,
    Damage = 1000000,
    Coins = 999999999,
    Diamonds = 999999,
    Magnet = 500,
    WalkSpeed = 50,
    Mult = 1000000,
    RollTime = 0.05,
}

local conns, seen = {}, {}
local firing = false

-------------------------------------------------------------------
-- DATA BOOST (client-side only, fires the game's own DataUpdate)
-------------------------------------------------------------------
-- seed table from your log, used until the first real server update arrives
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

local function applyBoost(data)
    data.Luck = State.Luck
    data.Damage = State.Damage
    data.Coins = State.Coins
    data.Diamonds = State.Diamonds
    data.Magnet = State.Magnet
    data.WalkSpeed = State.WalkSpeed
    data.CoinMult = State.Mult
    data.PassiveMult = State.Mult
    data.PotionMult = State.Mult
    data.Dps = State.Damage * 10
    data.RollTime = State.RollTime
    data.RollCost = 0
    data.MaxAlive = 50
    data.Slots = 10
    data.DiamondChance = 1
    data.ServerLuck = { EndsAt = 0, Level = 0, Multiplier = State.Luck, Busy = false }
    return data
end

local function fireBoost(data)
    firing = true
    pcall(function()
        firesignal(DataUpdate.OnClientEvent, applyBoost(data))
    end)
    firing = false
end

-- every time the server sends data, boost it again so it doesn't get overwritten
table.insert(conns, DataUpdate.OnClientEvent:Connect(function(data)
    if firing or type(data) ~= "table" then return end
    for k, v in pairs(data) do lastData[k] = v end
    if State.Boost then
        task.defer(fireBoost, table.clone(lastData))
    end
end))

local function setBoost(on)
    State.Boost = on
    if on then fireBoost(table.clone(lastData)) end
end

-------------------------------------------------------------------
-- AUTO COLLECT (fires Remotes.Collect for every drop)
-------------------------------------------------------------------
local function dropId(inst)
    local n = tonumber(inst.Name)
        or inst:GetAttribute("Id") or inst:GetAttribute("ID")
        or inst:GetAttribute("DropId") or inst:GetAttribute("Drop")
    return tonumber(n)
end

local function collect(inst)
    if not State.AutoCollect then return end
    local id = dropId(inst)
    if id and not seen[id] then
        seen[id] = true
        Collect:FireServer({ id })
        task.delay(5, function() seen[id] = nil end) -- allow id reuse
    end
end

table.insert(conns, workspace.DescendantAdded:Connect(function(inst)
    task.defer(collect, inst)
end))

task.spawn(function()
    while getgenv().RAS_RUN do
        if State.AutoCollect then
            for _, inst in ipairs(workspace:GetDescendants()) do
                collect(inst)
            end
        end
        task.wait(1)
    end
end)

-------------------------------------------------------------------
-- UNLOAD
-------------------------------------------------------------------
getgenv().RAS_RUN = true
getgenv().RAS_UNLOAD = function()
    getgenv().RAS_RUN = false
    State.Boost, State.AutoCollect = false, false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    if getgenv().RAS_WINDOW and getgenv().RAS_WINDOW.Destroy then
        pcall(function() getgenv().RAS_WINDOW:Destroy() end)
    end
end

-------------------------------------------------------------------
-- UI (igkii_lib, loaded separately)
-------------------------------------------------------------------
local Library = getgenv().igkii_lib or loadstring(game:HttpGet(LIB_URL))()
local Window = Library:CreateWindow({ Title = "Roll a Sword" })
getgenv().RAS_WINDOW = Window

local Main = Window:CreateTab("Main")

Main:CreateToggle({ Name = "OP Stats (client)", Default = false, Callback = setBoost })
Main:CreateToggle({ Name = "Auto Collect Drops", Default = false, Callback = function(v)
    State.AutoCollect = v
end })

local function slider(name, key, min, max)
    Main:CreateSlider({ Name = name, Min = min, Max = max, Default = State[key], Callback = function(v)
        State[key] = v
        if State.Boost then fireBoost(table.clone(lastData)) end
    end })
end

slider("Luck", "Luck", 1, 1000000000)
slider("Damage", "Damage", 1, 1000000000)
slider("Multiplier", "Mult", 1, 1000000000)
slider("Magnet", "Magnet", 12, 1000)
slider("WalkSpeed", "WalkSpeed", 16, 200)

Main:CreateButton({ Name = "Unload", Callback = getgenv().RAS_UNLOAD })
