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
	SlotCount = 34,        -- your unlocked plots (max 40)
	PlotName  = "Plot4",   -- fallback if your own plot can't be detected
	TargetLevel = 25,
	MaxLevel = 25,

	AutoBuy     = false,
	AutoCollect = false,
	AutoPlace   = false,
	AutoOpen    = false,
	AutoLevel   = false,
	AutoCompass = false,
	AutoPumpkin = false,

	BuyDelay     = 0.3,
	CollectDelay = 5,
	PlaceDelay   = 1.5,
	OpenDelay    = 1,
	LevelDelay   = 2,
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
-- GAME STATE (Remotes.State: chestOffer, slots, storageOrder, hotbar, chests, slotsOwned)
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
	return math.min(n, 40)
end

local function slotEntry(slot)
	return type(S.slots) == "table" and S.slots[slot] or nil
end

----------------------------------------------------------------
-- OWN PLOT + CHEST READY CHECK (never opens a chest early)
----------------------------------------------------------------
local plotCache

local function plotCenter(p)
	if p:IsA("Model") then return p:GetPivot().Position end
	for _, d in ipairs(p:GetDescendants()) do
		if d:IsA("BasePart") then return d.Position end
	end
end

local function ownPlot()
	if plotCache and plotCache.Parent then return plotCache end
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return end

	for _, p in ipairs(plots:GetChildren()) do
		for _, v in pairs(p:GetAttributes()) do
			if v == lp.Name or v == lp.UserId or v == lp.DisplayName then
				plotCache = p return p
			end
		end
		for _, c in ipairs(p:GetChildren()) do
			if c.Name:lower():find("owner") then
				local ok, val = pcall(function() return c.Value end)
				if ok and (val == lp or val == lp.Name or val == lp.UserId) then
					plotCache = p return p
				end
			end
		end
	end

	local fixed = plots:FindFirstChild(Config.PlotName)
	if fixed then plotCache = fixed return fixed end
end

local function stripTags(s)
	return (tostring(s):gsub("<[^>]+>", ""))
end

local function slotTexts(slot)
	local plot = ownPlot()
	local objs = plot and plot:FindFirstChild("Objects")
	local obj = objs and objs:FindFirstChild("Slot" .. slot .. "Object")
	if not obj then return end
	local texts = {}
	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local t = stripTags(d.Text):gsub("^%s+", ""):gsub("%s+$", "")
			if t ~= "" then texts[#texts + 1] = t end
		end
	end
	return texts
end

local function readyFromState(entry)
	local now = workspace:GetServerTimeNow()
	local found
	local function scan(tbl)
		for k, v in pairs(tbl) do
			if type(v) == "number" and v > 1e9 and type(k) == "string"
				and k:lower():find("ready|open|end|until|finish|done") then
				found = (found == nil or found) and (v <= now)
			elseif type(v) == "table" and k ~= "char" then
				scan(v)
			end
		end
	end
	scan(entry)
	return found -- true / false / nil (unknown)
end

local function chestReady(slot, entry)
	-- 1) the label above the chest ("OPEN!" vs "38s")
	local texts = slotTexts(slot)
	if texts then
		local sawTimer = false
		for _, t in ipairs(texts) do
			if t:upper():find("OPEN") then return true end
			if t:match("^%d+%s*[smhd]") or t:match("%d+[smhd]%s*%d*[smhd]?$") then sawTimer = true end
		end
		if sawTimer then return false end
	end
	-- 2) a ready timestamp inside the state entry
	local st = readyFromState(entry)
	if st ~= nil then return st end
	-- unknown: do NOT open (an early open triggers the Robux prompt)
	return false
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
-- AUTO COLLECT (remote only, any plot)
----------------------------------------------------------------
loop("AutoCollect", "CollectDelay", function()
	act("Collect", "all")
end)

----------------------------------------------------------------
-- AUTO OPEN (only chests that are ready, each slot once per cooldown)
----------------------------------------------------------------
local openedAt = {}

loop("AutoOpen", "OpenDelay", function()
	local now = os.clock()
	for slot = 1, slotLimit() do
		local entry = slotEntry(slot)
		if entry and entry.kind == "chest"
			and (not openedAt[slot] or now - openedAt[slot] > 5)
			and chestReady(slot, entry) then
			openedAt[slot] = now
			task.spawn(act, "Open", slot)
		end
	end
end)

----------------------------------------------------------------
-- AUTO PLACE (chests from your storage, matching your picks, slots 1..SlotCount)
----------------------------------------------------------------
local function inventoryChestKeys()
	local keys, seen = {}, {}
	local function add(k)
		if type(k) == "string" and k:sub(1, 6) == "chest:" and not seen[k] then
			seen[k] = true
			keys[#keys + 1] = k
		end
	end
	if type(S.hotbar) == "table" then
		for _, it in ipairs(S.hotbar) do add(it.k) end
	end
	if type(S.storageOrder) == "table" then
		for _, k in ipairs(S.storageOrder) do add(k) end
	end
	if type(S.chests) == "table" then
		for k, v in pairs(S.chests) do
			if type(k) == "string" then
				add(k)
			elseif tonumber(k) and type(v) == "table" then
				for mut, n in pairs(v) do
					if type(n) == "number" and n > 0 then add(("chest:%d:%s"):format(k, mut)) end
				end
			end
		end
	end
	return keys
end

local function matchingChestKeys()
	local out = {}
	for _, k in ipairs(inventoryChestKeys()) do
		local island, mut = k:match("^chest:(%d+):(%w+)")
		if island and mutationOk(mut) and islandOk(island) then out[#out + 1] = k end
	end
	return out
end

local placeFail = {}   -- key -> os.clock of last failure on every slot

loop("AutoPlace", "PlaceDelay", function()
	local keys = matchingChestKeys()
	if #keys == 0 then return end

	for slot = 1, slotLimit() do
		if not (alive and Config.AutoPlace) then return end
		local entry = slotEntry(slot)
		if not (entry and entry.kind == "chest") then          -- skip slots that already hold a chest
			for _, key in ipairs(keys) do
				local ok, res = act("PlaceChest", key, slot)
				if not (ok and res == true) and entry and entry.kind == "char" then
					-- a unit is still there: take it out first, then place
					act("Collect", slot)
					task.wait(0.2)
					ok, res = act("PlaceChest", key, slot)
				end
				if ok and res == true then
					if type(S.slots) == "table" then S.slots[slot] = { kind = "chest" } end
					break
				end
				task.wait(0.03)
			end
		end
	end
end)

----------------------------------------------------------------
-- AUTO LEVEL UP (every unit on your plot -> TargetLevel, only the missing levels)
----------------------------------------------------------------
loop("AutoLevel", "LevelDelay", function()
	local target = math.clamp(tonumber(Config.TargetLevel) or 25, 1, Config.MaxLevel)
	for slot = 1, slotLimit() do
		if not (alive and Config.AutoLevel) then return end
		local entry = slotEntry(slot)
		local char = entry and entry.kind == "char" and entry.char
		if char then
			local level = tonumber(char.level) or 1
			while alive and Config.AutoLevel and level < target do
				local ok, res = act("LevelUp", slot, 1)
				if ok and res == true then
					level += 1
					char.level = level          -- keep local view in sync until State refreshes
					task.wait(0.02)
				else
					return                       -- out of cash / capped: retry next cycle
				end
			end
		end
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
-- DIAGNOSTICS: FAP.Dump(slot) prints what the script sees for a slot
----------------------------------------------------------------
local function ser(v, d)
	d = d or 0
	if type(v) ~= "table" then return tostring(v) end
	if d > 3 then return "{...}" end
	local parts = {}
	for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. ser(x, d + 1) end
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function Dump(slot)
	slot = slot or 1
	print("[FAP] slot", slot, ser(slotEntry(slot)))
	print("[FAP] labels", ser(slotTexts(slot)))
	print("[FAP] own plot", ownPlot() and ownPlot().Name or "not found")
	print("[FAP] matching chests", ser(matchingChestKeys()))
	print("[FAP] storage chests", ser(inventoryChestKeys()))
end

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
	{ Title = "Target Level", Get = function() return tostring(Config.TargetLevel) end },
}, { Tier = "Free" })

-- ===== Auto Buy tab =====
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
	Desc = "Collect, place, open, level up, compass and pumpkins.",
})

auto:Section("Plots")
auto:Toggle({ Name = "Auto Collect", Desc = "Collects every plot you own (no teleport)",
	Default = false, Callback = function(v) Config.AutoCollect = v end })
auto:Toggle({ Name = "Auto Place", Desc = "Places chests from your storage (uses the Auto Buy picks) on slots 1-34",
	Default = false, Callback = function(v) Config.AutoPlace = v end })
auto:Toggle({ Name = "Auto Open", Desc = "Opens a chest only when its timer is done (never the Robux open)",
	Default = false, Callback = function(v) Config.AutoOpen = v end })

auto:Section("Units")
local levelOptions = {}
for i = 1, Config.MaxLevel do levelOptions[#levelOptions + 1] = tostring(i) end
auto:Dropdown({
	Name = "Target Level", Desc = "Every unit on your plot is raised to this level",
	Options = levelOptions, Default = tostring(Config.TargetLevel),
	Callback = function(v) Config.TargetLevel = tonumber(v) or 25 end,
})
auto:Toggle({ Name = "Auto Level Up", Desc = "Upgrades each unit, only the levels it is missing",
	Default = false, Callback = function(v) Config.AutoLevel = v end })

auto:Section("Events")
auto:Toggle({ Name = "Auto Compass", Desc = "Teleports to the Lucky Compass, then returns you",
	Default = false, Callback = function(v) Config.AutoCompass = v end })
auto:Toggle({ Name = "Auto Pumpkin", Desc = "Teleports to each Halloween pumpkin and grabs it",
	Default = false, Callback = function(v) Config.AutoPumpkin = v end })

misc = Window:BuildMisc()
Window:OnDestroy(Unload)
Window:PlayIntro()

genv.FAP = {
	Config = Config, State = S, Dump = Dump,
	SetMutation = SetMutation, SetIsland = SetIsland, Unload = Unload,
}
