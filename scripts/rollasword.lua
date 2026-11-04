-- [RELEASE] Roll a Sword | PlaceId 127788924565169 | GameId 10771796704
-- scripts/rollasword.lua

if getgenv().RAS_UNLOAD then pcall(getgenv().RAS_UNLOAD) end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local Remotes = RS:WaitForChild("Remotes")
local DataUpdate = Remotes:WaitForChild("DataUpdate")
local Collect = Remotes:WaitForChild("Collect")

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

local conns, seen, destroyers = {}, {}, {}
local firing = false
getgenv().RAS_RUN = true -- must be set before the loop below starts

-------------------------------------------------------------------
-- DATA BOOST (client-side only, fires the game's own DataUpdate)
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
    State.Boost = on and true or false
    if State.Boost then fireBoost(table.clone(lastData)) end
end

local function setCollect(on)
    State.AutoCollect = on and true or false
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
getgenv().RAS_UNLOAD = function()
    getgenv().RAS_RUN = false
    State.Boost, State.AutoCollect = false, false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    for _, d in ipairs(destroyers) do pcall(d) end
end

-------------------------------------------------------------------
-- UI: tries igkii_lib first, falls back to a built-in UI
-------------------------------------------------------------------
local function tryCall(obj, names, argSets)
    for _, name in ipairs(names) do
        local f = obj[name]
        if type(f) == "function" then
            for _, args in ipairs(argSets) do
                local ok, res = pcall(function()
                    return f(obj, table.unpack(args))
                end)
                if ok and res ~= nil then return true, res end
            end
        end
    end
    return false
end

local function tryLibUI()
    local okLib, Library = pcall(function()
        return getgenv().igkii_lib or loadstring(getgenv().IGKII_FETCH("igkii_lib.lua"))()
    end)
    if not okLib or type(Library) ~= "table" then
        warn("[RAS] could not load igkii_lib: " .. tostring(Library))
        return false
    end

    -- prints the real method names of your lib, send me this line
    local keys = {}
    for k, v in pairs(Library) do keys[#keys + 1] = tostring(k) .. ":" .. typeof(v) end
    table.sort(keys)
    warn("[RAS] igkii_lib API -> " .. table.concat(keys, ", "))

    local okW, Window = tryCall(Library,
        { "CreateWindow", "Window", "MakeWindow", "NewWindow", "CreateLib", "Create", "New", "Init", "Load" },
        { { { Title = "Roll a Sword", Name = "Roll a Sword" } }, { "Roll a Sword" } })
    if not okW or type(Window) ~= "table" then return false end

    local okT, Tab = tryCall(Window,
        { "CreateTab", "AddTab", "NewTab", "MakeTab", "Tab" },
        { { { Name = "Main", Title = "Main" } }, { "Main" } })
    if not okT or type(Tab) ~= "table" then Tab = Window end

    local okA = tryCall(Tab,
        { "CreateToggle", "AddToggle", "NewToggle", "Toggle" },
        { { { Name = "OP Stats (client)", Default = false, Callback = setBoost } },
          { "OP Stats (client)", false, setBoost } })
    if not okA then return false end

    tryCall(Tab,
        { "CreateToggle", "AddToggle", "NewToggle", "Toggle" },
        { { { Name = "Auto Collect Drops", Default = false, Callback = setCollect } },
          { "Auto Collect Drops", false, setCollect } })

    tryCall(Tab,
        { "CreateButton", "AddButton", "NewButton", "Button" },
        { { { Name = "Unload", Callback = getgenv().RAS_UNLOAD } },
          { "Unload", getgenv().RAS_UNLOAD } })

    table.insert(destroyers, function()
        for _, n in ipairs({ "Destroy", "Unload", "Close" }) do
            if type(Window[n]) == "function" then Window[n](Window) return end
        end
    end)
    return true
end

local function builtInUI()
    local parent = (gethui and gethui()) or game:GetService("CoreGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "RAS_UI"
    gui.ResetOnSpawn = false
    gui.Parent = parent
    table.insert(destroyers, function() gui:Destroy() end)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(220, 190)
    frame.Position = UDim2.new(0, 30, 0.4, 0)
    frame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 32)
    title.BackgroundTransparency = 1
    title.Text = "Roll a Sword  (RightShift hide)"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.Parent = frame

    local function button(text, y, callback, isToggle)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -20, 0, 34)
        b.Position = UDim2.new(0, 10, 0, y)
        b.BackgroundColor3 = Color3.fromRGB(45, 45, 56)
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.Gotham
        b.TextSize = 13
        b.Text = text .. (isToggle and ": OFF" or "")
        b.BorderSizePixel = 0
        b.Parent = frame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        local on = false
        b.MouseButton1Click:Connect(function()
            if isToggle then
                on = not on
                b.Text = text .. (on and ": ON" or ": OFF")
                b.BackgroundColor3 = on and Color3.fromRGB(60, 140, 90) or Color3.fromRGB(45, 45, 56)
            end
            callback(on)
        end)
    end

    button("OP Stats", 40, setBoost, true)
    button("Auto Collect", 82, setCollect, true)
    button("Unload", 134, function() getgenv().RAS_UNLOAD() end, false)

    table.insert(conns, UIS.InputBegan:Connect(function(input, gp)
        if not gp and input.KeyCode == Enum.KeyCode.RightShift then
            frame.Visible = not frame.Visible
        end
    end))
end

local okCall, libWorked = pcall(tryLibUI)
if not (okCall and libWorked) then
    warn("[RAS] igkii_lib methods did not match, using built-in UI")
    builtInUI()
end
