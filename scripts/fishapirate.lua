-- Fish A Pirate | PlaceId 77762780479259 | GameId 10770113648
-- scripts/fishapirate.lua  (UI = igkii_lib.lua, loaded with loadstring)

if game.PlaceId ~= 77762780479259 and game.GameId ~= 10770113648 then return end

local genv = (getgenv and getgenv()) or _G
if genv.FAP_UNLOAD then pcall(genv.FAP_UNLOAD) end

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local lp      = Players.LocalPlayer

local Remotes   = RS:WaitForChild("Remotes")
local Action    = Remotes:WaitForChild("Action")
local Notify    = Remotes:WaitForChild("Notify")
local State     = Remotes:WaitForChild("State")
local Halloween = Remotes:WaitForChild("Halloween", 5)

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Config = {
	Mutations = {
		Normal = false, Gold = false, Diamond = false, Aura = false,
		Storm = false, Thunder = false, Abyss = false, Rainbow = false,
		Shadow = false, Awakened = false, Conqueror = false, Celestial = false,
	},
	Islands = {},
	MaxIsland = 22,
	SlotCount = 34,        -- your unlocked plots (max 40); raise it when you unlock more

	AutoBuy     = false,
	AutoCollect = false,
	AutoPlace   = false,
	AutoOpen    = false,
	AutoCompass = false,
	AutoPumpkin = false,

	BuyDelay     = 0.3,
	CollectDelay = 5,
	PlaceDelay   = 1.5,
	OpenDelay    = 1,
}
for i = 1, Config.MaxIsland do Config.Islands[i] = false end

local MutationOrder = { "Normal","Gold","Diamond","Aura","Storm","Thunder",
	"Abyss","Rainbow","Shadow","Awakened","Conqueror","Celestial" }

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------
local alive = true
local conns = {}

local function act(...)
	local ok, res = pcall(Action.InvokeServer, Action, ...)
	return ok, res
end

local function anyOn(map)
	for _, v in pairs(map) do if v then return true end end
	return false
end

local function mutationOk(m)
	if not anyOn(Config.Mutations) then return true end
	return Config.Mutations[m] == true
end

local function islandOk(i)
	if not anyOn(Config.Islands) then return true end
	return Config.Islands[tonumber(i)] == true
end

local function selectedMutations()
	local t = {}
	for _, m in ipairs(MutationOrder) do
		if Config.Mutations[m] then t[#t + 1] = m end
	end
	return t
end

local function selectedIslands()
	local t = {}
	for i = 1, Config.MaxIsland do
		if Config.Islands[i] then t[#t + 1] = i end
	end
	return t
end

local function SetMutation(name, state)
	if Config.Mutations[name] ~= nil then Config.Mutations[name] = state and true or false end
end
local function SetIsland(n, state)
	n = tonumber(n)
	if n and Config.Islands[n] ~= nil then Config.Islands[n] = state and true or false end
end
local function SetAllMutations(state)
	for m in pairs(Config.Mutations) do Config.Mutations[m] = state end
end
local function SetAllIslands(state)
	for i = 1, Config.MaxIsland do Config.Islands[i] = state end
end

local function loop(flag, delay, fn)
	task.spawn(function()
		while alive do
			if Config[flag] then pcall(fn) end
			task.wait(Config[delay] or delay)
		end
	end)
end

local function touch(hrp, target)
	local parts = target:IsA("Model") and target:GetDescendants() or { target }
	for _, p in ipairs(parts) do
		if p:IsA("BasePart") and firetouchinterest then
			pcall(firetouchinterest, hrp, p, 0)
			pcall(firetouchinterest, hrp, p, 1)
		elseif p:IsA("ProximityPrompt") and fireproximityprompt then
			pcall(fireproximityprompt, p)
		end
	end
end

-- one teleport at a time (compass / pumpkin): go, do the job, return
local tpBusy = false
local function runTp(fn)
	while tpBusy and alive do task.wait(0.1) end
	if not alive then return end
	local char = lp.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	tpBusy = true
	local origin = hrp.CFrame
	pcall(fn, hrp)
	hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.CFrame = origin end
	tpBusy = false
end

local function tpTo(hrp, pos)
	hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
end

----------------------------------------------------------------
-- GAME STATE (from Remotes.State: chestOffer, slots, hotbar, slotsOwned)
----------------------------------------------------------------
local S = {}
conns[#conns + 1] = State.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" then
		for k, v in pairs(payload) do S[k] = v end
	end
end)

local function slotLimit()
	local owned = tonumber(S.slotsOwned)
	local n = Config.SlotCount
	if owned and owned < n then n = owned end
	return n
end

----------------------------------------------------------------
-- AUTO BUY (remote only, buys the chest on offer if it matches your picks)
----------------------------------------------------------------
local lastBought

task.spawn(function()
	while alive do
		if Config.AutoBuy then
			local offer = S.chestOffer
			if type(offer) == "table" and offer.uid and offer.uid ~= lastBought
				and mutationOk(offer.mutation) and islandOk(offer.island) then
				lastBought = offer.uid
				act("Buy", offer.uid)
			end
		end
		task.wait(Config.BuyDelay)
	end
end)

----------------------------------------------------------------
-- AUTO COLLECT (remote only, works for whatever plot you have)
----------------------------------------------------------------
loop("AutoCollect", "CollectDelay", function()
	act("Collect", "all")
end)

----------------------------------------------------------------
-- AUTO OPEN (all slots at once; server only accepts ones whose timer ended)
----------------------------------------------------------------
loop("AutoOpen", "OpenDelay", function()
	for slot = 1, slotLimit() do
		local entry = type(S.slots) == "table" and S.slots[slot]
		if not (entry and entry.kind == "char") then
			task.spawn(act, "Open", slot)
		end
	end
end)

----------------------------------------------------------------
-- AUTO PLACE (uses the matching chests in your hotbar, slots 1..SlotCount)
----------------------------------------------------------------
local function pickChestKey()
	if type(S.hotbar) ~= "table" then return end
	for _, item in ipairs(S.hotbar) do
		local k = item.k
		if type(k) == "string" and k:sub(1, 6) == "chest:" and (item.n or 1) > 0 then
			local island, mut = k:match("^chest:(%d+):(%w+)")
			if island and mutationOk(mut) and islandOk(island) then
				return k, item
			end
		end
	end
end

loop("AutoPlace", "PlaceDelay", function()
	for slot = 1, slotLimit() do
		if not (alive and Config.AutoPlace) then return end
		local key, item = pickChestKey()
		if not key then return end

		local ok, res = act("PlaceChest", key, slot)
		if not (ok and res == true) then
			-- slot still holds a unit: take it out first, then place
			act("Collect", slot)
			task.wait(0.2)
			ok, res = act("PlaceChest", key, slot)
		end
		if ok and res == true then
			item.n = (item.n or 1) - 1   -- local count until State refreshes
		end
		task.wait(0.05)
	end
end)

----------------------------------------------------------------
-- AUTO COMPASS (teleport)
----------------------------------------------------------------
local compassToken = 0

local function posOf(o)
	if o:IsA("Model") then return o:GetPivot().Position end
	return o.Position
end

local function findCompass()
	local char = lp.Character
	for _, d in ipairs(workspace:GetDescendants()) do
		if (d:IsA("BasePart") or d:IsA("Model"))
			and d.Name:lower():find("compass")
			and not (char and d:IsDescendantOf(char)) then
			return d
		end
	end
end

local function grabCompass()
	compassToken += 1
	local token = compassToken
	local deadline = os.clock() + 60

	local target
	while alive and Config.AutoCompass and token == compassToken and os.clock() < deadline do
		target = findCompass()
		if target then break end
		task.wait(0.5)
	end
	if not target or token ~= compassToken then return end

	runTp(function(hrp)
		local stayUntil = os.clock() + 4
		while alive and Config.AutoCompass and token == compassToken
			and target.Parent and os.clock() < stayUntil do
			hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			tpTo(hrp, posOf(target))
			touch(hrp, target)
			task.wait(0.25)
		end
	end)
end

conns[#conns + 1] = Notify.OnClientEvent:Connect(function(msg, _, kind)
	if kind == "compass" and Config.AutoCompass then
		task.spawn(grabCompass)
	elseif kind == "compassGone" or (kind == "compassGrab" and tostring(msg):find(lp.Name, 1, true)) then
		compassToken += 1
	end
end)

----------------------------------------------------------------
-- AUTO PUMPKIN (Halloween spawn -> teleport -> PumpkinGrab)
----------------------------------------------------------------
local pumpkins = {}

if Halloween then
	conns[#conns + 1] = Halloween.OnClientEvent:Connect(function(kind, data)
		if type(data) ~= "table" or not data.id then return end
		if kind == "spawn" and data.at then
			pumpkins[data.id] = data
		elseif kind == "gone" then
			pumpkins[data.id] = nil
		end
	end)
end

task.spawn(function()
	while alive do
		if Config.AutoPumpkin then
			local pick
			local now = workspace:GetServerTimeNow()
			for id, d in pairs(pumpkins) do
				if d.expires and d.expires < now then
					pumpkins[id] = nil
				elseif not pick or (d.kind == "Big" and pick.kind ~= "Big") then
					pick = d
				end
			end
			if pick then
				pumpkins[pick.id] = nil
				runTp(function(hrp)
					tpTo(hrp, pick.at)
					task.wait(0.1)
					act("PumpkinGrab", pick.id)
				end)
				task.wait(0.1)
			else
				task.wait(0.3)
			end
		else
			task.wait(0.5)
		end
	end
end)

----------------------------------------------------------------
-- UNLOAD
----------------------------------------------------------------
local function Unload()
	alive = false
	for k, v in pairs(Config) do
		if type(v) == "boolean" then Config[k] = false end
	end
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	genv.FAP_UNLOAD = nil
	genv.FAP = nil
end
genv.FAP_UNLOAD = Unload

----------------------------------------------------------------
-- UI (igkii lib, loaded with loadstring)
----------------------------------------------------------------
local fetch = genv.IGKII_FETCH or function(path)
	return game:HttpGet("https://igkii.kiantejero.workers.dev/scripts/" .. path)
end

local Library = loadstring(fetch("igkii_lib.lua"))()
local Window  = Library.Window({ Title = "Fish A Pirate" })

local misc
local features = Library.MiscFeatures(function() return misc end)

local function summary(list, empty)
	if #list == 0 then return empty end
	return table.concat(list, ", ")
end

local function islandText()
	local t = {}
	for _, i in ipairs(selectedIslands()) do t[#t + 1] = tostring(i) end
	return summary(t, "any")
end

local function tell(text)
	if Window.Notify then pcall(function() Window:Notify(text) end) end
end

Window:BuildHome(features, {
	{ Title = "Rarity",  Get = function() return summary(selectedMutations(), "any") end },
	{ Title = "Islands", Get = islandText },
}, { Tier = "Free" })

-- ===== Auto Buy tab: dropdowns + toggle together =====
local buy = Window:Tab({
	Name = "Auto Buy", Icon = "shopping-cart", PageTitle = "Auto Buy",
	Desc = "Pick rarity and island, then turn Auto Buy on. Nothing picked = buy any.",
})

buy:Section("Auto Buy")

local mutOptions = { "All", "None" }
for _, m in ipairs(MutationOrder) do mutOptions[#mutOptions + 1] = m end
buy:Dropdown({
	Name = "Rarity", Desc = "Pick an entry to toggle it (All / None are shortcuts)",
	Options = mutOptions, Default = "None",
	Callback = function(v)
		if v == "All" then SetAllMutations(true)
		elseif v == "None" then SetAllMutations(false)
		else SetMutation(v, not Config.Mutations[v]) end
		tell("Rarity: " .. summary(selectedMutations(), "any"))
	end,
})

local islOptions = { "All", "None" }
for i = 1, Config.MaxIsland do islOptions[#islOptions + 1] = tostring(i) end
buy:Dropdown({
	Name = "Island", Desc = "Pick an entry to toggle it (All / None are shortcuts)",
	Options = islOptions, Default = "None",
	Callback = function(v)
		if v == "All" then SetAllIslands(true)
		elseif v == "None" then SetAllIslands(false)
		else SetIsland(v, not Config.Islands[tonumber(v)]) end
		tell("Islands: " .. islandText())
	end,
})

buy:Toggle({
	Name = "Auto Buy", Desc = "Buys the chest on offer when it matches your rarity and island",
	Default = false, Callback = function(v) Config.AutoBuy = v end,
})

-- ===== Auto tab =====
local auto = Window:Tab({
	Name = "Auto", Icon = "zap", PageTitle = "Automation",
	Desc = "Collect, place, open, compass and pumpkins.",
})

auto:Section("Plots")
auto:Toggle({ Name = "Auto Collect", Desc = "Collects every plot you own (no teleport)",
	Default = false, Callback = function(v) Config.AutoCollect = v end })
auto:Toggle({ Name = "Auto Place", Desc = "Places your picked chests on slots 1-34, clearing units first",
	Default = false, Callback = function(v) Config.AutoPlace = v end })
auto:Toggle({ Name = "Auto Open", Desc = "Opens every chest whose timer has ended, all at once",
	Default = false, Callback = function(v) Config.AutoOpen = v end })

auto:Section("Events")
auto:Toggle({ Name = "Auto Compass", Desc = "Teleports to the Lucky Compass, then returns you",
	Default = false, Callback = function(v) Config.AutoCompass = v end })
auto:Toggle({ Name = "Auto Pumpkin", Desc = "Teleports to each Halloween pumpkin and grabs it",
	Default = false, Callback = function(v) Config.AutoPumpkin = v end })

misc = Window:BuildMisc()
Window:OnDestroy(Unload)
Window:PlayIntro()

genv.FAP = {
	Config = Config, State = S, SetMutation = SetMutation, SetIsland = SetIsland, Unload = Unload,
}
