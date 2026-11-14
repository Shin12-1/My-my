-- Anime Ashura | Auto Next / Auto Replay + Auto Buy until sold out (igkii lib)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

-- single-instance guard
local env = (getgenv and getgenv()) or _G
if env.ANIMEASHURA_UNLOAD then pcall(env.ANIMEASHURA_UNLOAD) end

-- lib (loader sets IGKII_FETCH)
local function fetch(path)
	if env.IGKII_FETCH then return env.IGKII_FETCH(path) end
	return game:HttpGet("https://igkii.kiantejero.workers.dev/scripts/" .. path)
end
local Library = loadstring(fetch("igkii_lib.lua"))()

-- remotes
local ShopRemote = RS:WaitForChild("Kingdom"):WaitForChild("Remotes"):WaitForChild("Request")
local BattleRemote = RS:WaitForChild("Battle"):WaitForChild("Remotes"):WaitForChild("Request")

-- state
local state = {
	autoNext = false,
	autoReplay = false,
	capSwitch = true, -- Replay -> Next when replay soft cap is reached
	buyGems = false,
	buyCoins = false,
}
local alive = true
local wins = 0
local lastAction = "-"
local conns = {}

-- shop data: { remote id, name shown in the shop card, max stock (only used if shop UI can't be read) }
local GEM_ITEMS = {
	{ "g_trait", "Trait Crystal", 5 },
	{ "g_scroll", "Skill Scroll", 1 },
	{ "g_expL", "Royal EXP Dango", 3 },
	{ "g_yellow", "Yellow Shard", 2 },
	{ "g_purple", "Purple Shard", 2 },
}
local COIN_ITEMS = {
	{ "c_runeBuff", "Buff Rune", 15 },
	{ "c_runeBomber", "Bomber Rune", 15 },
	{ "c_runeDefense", "Defense Rune", 15 },
	{ "c_runeRange", "Range Rune", 15 },
	{ "c_runeHealer", "Healer Rune", 15 },
	{ "c_runeMagic", "Magic Rune", 15 },
	{ "c_runePierce", "Pierce Rune", 15 },
	{ "c_runeCharge", "Charge Rune", 15 },
	{ "c_dust", "Forge Dust", 10 },
}

-- label tracking (cached, no full GUI scan per frame)
local victoryLabels, capLabels, qtyLabels = {}, {}, {}

local function classify(inst)
	local t = inst.Text:gsub("%s", ""):upper()
	victoryLabels[inst] = (t == "VICTORY!" or t == "VICTORY") or nil
	capLabels[inst] = t:find("SOFTCAPREACHED", 1, true) and true or nil
	qtyLabels[inst] = t:match("^QUANTITY:%d+/%d+$") and true or nil
end

local function watch(inst)
	if not inst:IsA("TextLabel") then return end
	classify(inst)
	local c = inst:GetPropertyChangedSignal("Text"):Connect(function()
		classify(inst)
	end)
	inst.Destroying:Connect(function()
		c:Disconnect()
		victoryLabels[inst] = nil
		capLabels[inst] = nil
		qtyLabels[inst] = nil
	end)
end

for _, d in ipairs(PlayerGui:GetDescendants()) do watch(d) end
table.insert(conns, PlayerGui.DescendantAdded:Connect(watch))

local function isShown(label)
	if not label:IsDescendantOf(PlayerGui) then return false end
	local o = label
	while o and o ~= PlayerGui do
		if o:IsA("GuiObject") and not o.Visible then return false end
		if o:IsA("ScreenGui") and not o.Enabled then return false end
		o = o.Parent
	end
	return label.TextTransparency < 1
end

local function anyShown(set)
	for l in pairs(set) do
		if isShown(l) then return true end
	end
	return false
end

-- auto next / replay
local function pickAction()
	if state.autoNext then return "Next" end -- Next wins if both are on
	if state.autoReplay then
		if state.capSwitch then
			task.wait(0.15) -- let the soft cap text appear
			if anyShown(capLabels) then return "Next" end
		end
		return "Replay"
	end
end

local function fire(action)
	return pcall(function()
		return BattleRemote:InvokeServer(action)
	end)
end

local function waitHidden(maxTime)
	local t = 0
	while t < maxTime and alive and anyShown(victoryLabels) do
		task.wait(0.05)
		t += 0.05
	end
	return not anyShown(victoryLabels)
end

local wasShown, busy = false, false

local function handleVictory()
	local action = pickAction()
	if action then
		fire(action)
		-- one retry only if the victory screen is still up after 1.5s
		if not waitHidden(1.5) and alive then
			fire(action)
			waitHidden(5)
		end
		wins += 1
		lastAction = action
	end
	busy = false
end

table.insert(conns, RunService.Heartbeat:Connect(function()
	if not alive or busy then return end
	local shown = anyShown(victoryLabels)
	if shown and not wasShown and (state.autoNext or state.autoReplay) then
		wasShown = true
		busy = true
		task.spawn(handleVictory)
	elseif not shown then
		wasShown = false
	end
end))

-- shop: read stock from the shop cards ("Quantity: remaining/max")
local nameCache, cardCache = {}, {}

local function norm(s)
	return ((s:gsub("%s+", " ")):lower():match("^%s*(.-)%s*$"))
end

-- the card = highest parent of a quantity label that contains only that one quantity label
local function cardOf(q)
	local cached = cardCache[q]
	if cached and cached:IsDescendantOf(PlayerGui) then return cached end
	local card = q.Parent
	while card and card.Parent and card.Parent ~= PlayerGui do
		local n = 0
		for _, d in ipairs(card.Parent:GetDescendants()) do
			if qtyLabels[d] then
				n += 1
				if n > 1 then break end
			end
		end
		if n > 1 then break end
		card = card.Parent
	end
	cardCache[q] = card
	return card
end

local function findQty(name)
	local c = nameCache[name]
	if c and c:IsDescendantOf(PlayerGui) then return c end
	local target = norm(name)
	for q in pairs(qtyLabels) do
		local card = cardOf(q)
		if card then
			for _, d in ipairs(card:GetDescendants()) do
				if d:IsA("TextLabel") and norm(d.Text) == target then
					nameCache[name] = q
					return q
				end
			end
		end
	end
end

local function stockOf(q)
	if not q or not q:IsDescendantOf(PlayerGui) then return nil end
	return tonumber(q.Text:match("^%s*Quantity:%s*(%d+)"))
end

local function invokeBuy(id, amt)
	return pcall(function()
		return ShopRemote:InvokeServer("ShopBuy", id, amt, nil)
	end)
end

-- buy one item until its stock reads 0. returns false if the shop card wasn't found
local function buyItem(flag, item)
	local id, name = item[1], item[2]
	local q = findQty(name)
	if not q then return false end
	local remaining = stockOf(q)
	local guard = 0
	while alive and state[flag] and remaining and remaining > 0 and guard < 80 do
		guard += 1
		local before = remaining
		-- try 1 at a time first, then the whole remaining stock in one call
		for _, amt in ipairs({ 1, remaining }) do
			invokeBuy(id, amt)
			task.wait(0.2)
			remaining = stockOf(q) or before
			if remaining < before then break end
		end
		if remaining >= before then break end -- nothing changed (can't afford / locked)
	end
	return true
end

-- fallback when the shop UI can't be read (blind buy up to the known max)
local lastBlind = 0
local function blindBuy(flag, item)
	for _ = 1, item[3] do
		if not (alive and state[flag]) then return end
		local ok, res = invokeBuy(item[1], 1)
		if not ok or res == false then break end
		task.wait(0.1)
	end
end

local function runShop(flag, items)
	local blindDue = (os.clock() - lastBlind) > 30
	local usedBlind = false
	for _, item in ipairs(items) do
		if not (alive and state[flag]) then return end
		if not buyItem(flag, item) and blindDue then
			blindBuy(flag, item)
			usedBlind = true
		end
	end
	if usedBlind then lastBlind = os.clock() end
end

local running = {}
local function startLoop(key, fn, interval)
	if running[key] then return end
	running[key] = true
	task.spawn(function()
		while alive and state[key] do
			pcall(fn)
			task.wait(interval)
		end
		running[key] = false
	end)
end

-- UI
local Window = Library.Window({ Title = "Anime Ashura" })

local misc
local features = Library.MiscFeatures(function() return misc end)
table.insert(features, { Name = "Auto Next", Get = function() return state.autoNext end })
table.insert(features, { Name = "Auto Replay", Get = function() return state.autoReplay end })
table.insert(features, { Name = "Auto Buy Gems", Get = function() return state.buyGems end })
table.insert(features, { Name = "Auto Buy Coins", Get = function() return state.buyCoins end })

Window:BuildHome(features, {
	{ Title = "Victories", Get = function() return tostring(wins) end },
	{ Title = "Last Action", Get = function() return lastAction end },
}, { Tier = "Free" })

local battle = Window:Tab({
	Name = "Battle",
	PageTitle = "Battle",
	Desc = "Auto continue after every victory",
})

battle:Section("Victory")
battle:Toggle({
	Name = "Auto Next",
	Desc = "Fires Next the instant VICTORY shows (wins over Auto Replay)",
	Default = false,
	Callback = function(v) state.autoNext = v end,
})
battle:Toggle({
	Name = "Auto Replay",
	Desc = "Fires Replay the instant VICTORY shows",
	Default = false,
	Callback = function(v) state.autoReplay = v end,
})
battle:Toggle({
	Name = "Switch to Next at Soft Cap",
	Desc = "Replay only gives 25% gems after the daily cap, so use Next then",
	Default = true,
	Callback = function(v) state.capSwitch = v end,
})

local shop = Window:Tab({
	Name = "Shop",
	PageTitle = "Shop",
	Desc = "Buys each item until it is sold out",
})

shop:Section("Gems")
shop:Toggle({
	Name = "Auto Buy (Gems)",
	Desc = "Trait Crystal, Skill Scroll, Royal EXP Dango, Yellow Shard, Purple Shard",
	Default = false,
	Callback = function(v)
		state.buyGems = v
		if v then startLoop("buyGems", function() runShop("buyGems", GEM_ITEMS) end, 5) end
	end,
})

shop:Section("Coins")
shop:Toggle({
	Name = "Auto Buy (Coins)",
	Desc = "All runes and Forge Dust",
	Default = false,
	Callback = function(v)
		state.buyCoins = v
		if v then startLoop("buyCoins", function() runShop("buyCoins", COIN_ITEMS) end, 5) end
	end,
})

misc = Window:BuildMisc()

local function unload()
	alive = false
	for k in pairs(state) do state[k] = false end
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	env.ANIMEASHURA_UNLOAD = nil
end
env.ANIMEASHURA_UNLOAD = unload
Window:OnDestroy(unload)

Window:PlayIntro()
