-- Fish A Pirate | PlaceId 77762780479259 | GameId 10770113648
-- scripts/fishapirate.lua  (UI = igkii_lib.lua, loaded with loadstring)

if game.PlaceId ~= 77762780479259 and game.GameId ~= 10770113648 then return end

local genv = (getgenv and getgenv()) or _G
if genv.FAP_UNLOAD then pcall(genv.FAP_UNLOAD) end

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local VIM     = game:GetService("VirtualInputManager")
local lp      = Players.LocalPlayer

local Remotes = RS:WaitForChild("Remotes")
local Action  = Remotes:WaitForChild("Action")
local Notify  = Remotes:WaitForChild("Notify")
local State   = Remotes:WaitForChild("State")

----------------------------------------------------------------
-- DATA
----------------------------------------------------------------
local MutationOrder = { "Normal","Gold","Diamond","Aura","Storm","Thunder",
	"Abyss","Rainbow","Shadow","Awakened","Conqueror","Celestial" }

-- island number -> name (the name is also what the chest shows). 15-26 not unlocked yet.
local IslandNames = {
	"Windmill Cove", "Clown Harbor", "Floating Restaurant", "Sawshark Park",
	"Town of Beginnings", "Oasis Town", "Royal Capital", "Sky Island",
	"Water City", "Justice Tower", "Ghost Ship", "Bubble Archipelago",
	"Prison Archipelago", "Summit Forest",
}

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Config = {
	Mutations = {},
	Islands = {},
	SlotCount = 34,        -- your unlocked plots (max 40)
	PlotName  = "Plot4",   -- fallback if your own plot can't be detected
	TargetLevel = 25,
	MaxLevel = 50,

	AutoBuy     = false,
	AutoCollect = false,
	AutoPlace   = false,
	AutoOpen    = false,
	AutoLevel   = false,
	AutoRewards = false,
	AutoDaily   = false,
	AutoCompass = false,

	BuyDelay     = 0.5,
	CollectDelay = 3,
	PlaceDelay   = 1.5,
	OpenDelay    = 1,
	LevelDelay   = 2,
	RewardDelay  = 20,
	DailyDelay   = 60,
}
for _, m in ipairs(MutationOrder) do Config.Mutations[m] = false end
for i = 1, #IslandNames do Config.Islands[i] = false end

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------
local alive = true
local conns = {}

local function act(...)
	local ok, res = pcall(Action.InvokeServer, Action, ...)
	return ok, res
end

-- a filter is "active" only when some, but not all, entries are picked
local function mutationFilter()
	local n = 0
	for _, m in ipairs(MutationOrder) do if Config.Mutations[m] then n += 1 end end
	return n > 0 and n < #MutationOrder
end

local function islandFilter()
	local n = 0
	for i = 1, #IslandNames do if Config.Islands[i] then n += 1 end end
	return n > 0 and n < #IslandNames
end

local function mutationOk(m)
	if not mutationFilter() then return true end
	return Config.Mutations[m] == true
end

local function islandOk(i)
	if not islandFilter() then return true end
	return Config.Islands[tonumber(i)] == true
end

local function selectedMutations()
	local t = {}
	for _, m in ipairs(MutationOrder) do
		if Config.Mutations[m] then t[#t + 1] = m end
	end
	return t
end

local function selectedIslandNames()
	local t = {}
	for i, name in ipairs(IslandNames) do
		if Config.Islands[i] then t[#t + 1] = name end
	end
	return t
end

local function SetMutation(name, state)
	if Config.Mutations[name] ~= nil then Config.Mutations[name] = state and true or false end
end
local function SetIslandByName(name, state)
	for i, n in ipairs(IslandNames) do
		if n == name then Config.Islands[i] = state and true or false return end
	end
end
local function SetAllMutations(state)
	for _, m in ipairs(MutationOrder) do Config.Mutations[m] = state end
end
local function SetAllIslands(state)
	for i = 1, #IslandNames do Config.Islands[i] = state end
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

-- one teleport at a time: go, do the job, return
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

local function stripTags(s)
	return (tostring(s):gsub("<[^>]+>", ""))
end

----------------------------------------------------------------
-- GAME STATE (Remotes.State: slots, storageOrder, hotbar, chests, slotsOwned)
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
-- AUTO BUY (chests in the world: press the Buy / E prompt, get close only if needed)
----------------------------------------------------------------
local buyPrompts = {}

local function trackPrompt(inst)
	if inst:IsA("ProximityPrompt") then
		buyPrompts[inst] = true
		inst.Destroying:Connect(function() buyPrompts[inst] = nil end)
	end
end

task.spawn(function()
	local n = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		trackPrompt(d)
		n += 1
		if n % 4000 == 0 then task.wait() end
	end
end)
conns[#conns + 1] = workspace.DescendantAdded:Connect(trackPrompt)

local function promptLabels(prompt)
	local set = {}
	local function add(t)
		t = stripTags(t):lower():gsub("^%s+", ""):gsub("%s+$", "")
		if t ~= "" then set[t] = true end
	end
	add(prompt.ObjectText)
	local root = prompt:FindFirstAncestorOfClass("Model") or prompt.Parent
	if root and #root:GetDescendants() > 300 then root = prompt.Parent end
	if root then
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("TextLabel") then add(d.Text) end
		end
	end
	return set
end

local function promptPos(prompt)
	local p = prompt.Parent
	if p and p:IsA("BasePart") then return p.Position end
	if p and p:IsA("Attachment") then return p.WorldPosition end
	local m = prompt:FindFirstAncestorOfClass("Model")
	if m then return m:GetPivot().Position end
end

-- returns true when this prompt is a chest Buy prompt matching your picks
local function wantedChest(prompt)
	local ok, action = pcall(function() return prompt.ActionText:lower() end)
	if not ok or action ~= "buy" or not prompt.Enabled then return false end

	local labels = promptLabels(prompt)

	local mutName
	for _, m in ipairs(MutationOrder) do
		if labels[m:lower()] then mutName = m break end
	end
	if not mutName then return false end          -- not a chest
	if not mutationOk(mutName) then return false end

	if islandFilter() then
		local hit = false
		for _, name in ipairs(selectedIslandNames()) do
			if labels[name:lower()] then hit = true break end
		end
		if not hit then return false end
	end
	return true
end

local function press(prompt)
	pcall(function() prompt.HoldDuration = 0 end)
	if fireproximityprompt then pcall(fireproximityprompt, prompt) end
end

local pressedAt, giveUpUntil = {}, {}
local buyBusy = false

local function tryBuy(prompt)
	buyBusy = true
	pressedAt[prompt] = os.clock()
	press(prompt)                     -- 1) from where you stand
	task.wait(0.5)

	if alive and prompt.Parent and prompt.Enabled then
		local pos = promptPos(prompt) -- 2) still there: get close, press E, come back
		if pos then
			runTp(function(hrp)
				tpTo(hrp, pos)
				task.wait(0.15)
				press(prompt)
				pcall(function()
					VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
					task.wait(0.1)
					VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
				end)
				task.wait(0.4)
			end)
		end
		if prompt.Parent and prompt.Enabled then
			giveUpUntil[prompt] = os.clock() + 30   -- e.g. not enough cash: don't spam teleports
		end
	end
	buyBusy = false
end

task.spawn(function()
	while alive do
		if Config.AutoBuy and not buyBusy then
			local now = os.clock()
			for prompt in pairs(buyPrompts) do
				if prompt.Parent
					and (not pressedAt[prompt] or now - pressedAt[prompt] > 3)
					and (not giveUpUntil[prompt] or now > giveUpUntil[prompt])
					and wantedChest(prompt) then
					task.spawn(tryBuy, prompt)
					break
				end
			end
		end
		task.wait(Config.BuyDelay)
	end
end)

----------------------------------------------------------------
-- AUTO COLLECT (remote only, no teleport)
----------------------------------------------------------------
loop("AutoCollect", "CollectDelay", function()
	act("Collect", "all")
end)

----------------------------------------------------------------
-- AUTO REWARDS / DAILY
----------------------------------------------------------------
loop("AutoRewards", "RewardDelay", function()
	for i = 1, 12 do
		if not (alive and Config.AutoRewards) then return end
		act("ClaimReward", i)
		task.wait(0.15)
	end
end)

loop("AutoDaily", "DailyDelay", function()
	act("DailyClaim")
end)

----------------------------------------------------------------
-- OWN PLOT + CHEST READY CHECK (never opens a chest early)
----------------------------------------------------------------
local plotCache

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
			if type(v) == "number" and v > 1e9 and type(k) == "string" then
				local key = k:lower()
				if key:find("ready") or key:find("open") or key:find("end") or key:find("until") then
					found = (found == nil or found) and (v <= now)
				end
			elseif type(v) == "table" and k ~= "char" then
				scan(v)
			end
		end
	end
	scan(entry)
	return found
end

local function chestReady(slot, entry)
	local texts = slotTexts(slot)
	if texts then
		local sawTimer = false
		for _, t in ipairs(texts) do
			if t:upper():find("OPEN") then return true end
			if t:match("^%d+%s*[smhd]") then sawTimer = true end
		end
		if sawTimer then return false end
	end
	local st = readyFromState(entry)
	if st ~= nil then return st end
	return false -- unknown: never open (an early open triggers the Robux prompt)
end

----------------------------------------------------------------
-- AUTO OPEN (only ready chests, each slot once per cooldown)
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
-- AUTO PLACE (storage chests matching your picks, slots 1..SlotCount)
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

loop("AutoPlace", "PlaceDelay", function()
	local keys = matchingChestKeys()
	if #keys == 0 then return end

	for slot = 1, slotLimit() do
		if not (alive and Config.AutoPlace) then return end
		local entry = slotEntry(slot)
		if not (entry and entry.kind == "chest") then
			for _, key in ipairs(keys) do
				local ok, res = act("PlaceChest", key, slot)
				if not (ok and res == true) and entry and entry.kind == "char" then
					act("Collect", slot)          -- take the unit out first, then place
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
-- AUTO LEVEL UP (every unit -> TargetLevel, only the missing levels, max 50)
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
					char.level = level
					task.wait(0.02)
				else
					return
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
-- DIAGNOSTICS
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
end

local function DumpBuy()   -- prints every Buy prompt it can see and what it read from it
	local n = 0
	for prompt in pairs(buyPrompts) do
		local ok, action = pcall(function() return prompt.ActionText end)
		if ok and tostring(action):lower() == "buy" then
			n += 1
			local labels = {}
			for t in pairs(promptLabels(prompt)) do labels[#labels + 1] = t end
			print("[FAP] buy prompt", prompt:GetFullName(), "| labels:", table.concat(labels, " / "),
				"| wanted:", tostring(wantedChest(prompt)))
		end
	end
	print("[FAP] buy prompts found:", n)
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

local function tell(text)
	if Window.Notify then pcall(function() Window:Notify(text) end) end
end

Window:BuildHome(features, {
	{ Title = "Rarity",  Get = function() return summary(selectedMutations(), "any") end },
	{ Title = "Islands", Get = function() return summary(selectedIslandNames(), "any") end },
	{ Title = "Target Level", Get = function() return tostring(Config.TargetLevel) end },
}, { Tier = "Free" })

-- ===== Auto Buy tab =====
local buy = Window:Tab({
	Name = "Auto Buy", Icon = "shopping-cart", PageTitle = "Auto Buy",
	Desc = "Click entries to add or remove them. Nothing picked (or All) = buy any chest.",
})

buy:Section("Auto Buy")

local mutOptions = { "All", "None" }
for _, m in ipairs(MutationOrder) do mutOptions[#mutOptions + 1] = m end
buy:Dropdown({
	Name = "Rarity", Desc = "Click as many as you want (click again to remove)",
	Options = mutOptions, Default = "All",
	Callback = function(v)
		if v == "All" then SetAllMutations(true)
		elseif v == "None" then SetAllMutations(false)
		else SetMutation(v, not Config.Mutations[v]) end
		tell("Rarity: " .. summary(selectedMutations(), "any"))
	end,
})

local islOptions = { "All", "None" }
for _, name in ipairs(IslandNames) do islOptions[#islOptions + 1] = name end
buy:Dropdown({
	Name = "Island", Desc = "Click as many as you want (click again to remove)",
	Options = islOptions, Default = "All",
	Callback = function(v)
		if v == "All" then SetAllIslands(true)
		elseif v == "None" then SetAllIslands(false)
		else SetIslandByName(v, not Config.Islands[table.find(IslandNames, v) or 0]) end
		tell("Islands: " .. summary(selectedIslandNames(), "any"))
	end,
})

buy:Toggle({
	Name = "Auto Buy", Desc = "Buys matching chests (presses E; gets close only if needed)",
	Default = false, Callback = function(v) Config.AutoBuy = v end,
})

-- ===== Auto tab =====
local auto = Window:Tab({
	Name = "Auto", Icon = "zap", PageTitle = "Automation",
	Desc = "Collect, place, open, level up, rewards and compass.",
})

auto:Section("Plots")
auto:Toggle({ Name = "Auto Collect", Desc = "Collect all, no teleport",
	Default = false, Callback = function(v) Config.AutoCollect = v end })
auto:Toggle({ Name = "Auto Place", Desc = "Places storage chests that match the Auto Buy picks",
	Default = false, Callback = function(v) Config.AutoPlace = v end })
auto:Toggle({ Name = "Auto Open", Desc = "Opens a chest only when its timer is done (never the Robux open)",
	Default = false, Callback = function(v) Config.AutoOpen = v end })

auto:Section("Units")
local levelOptions = {}
for i = 1, Config.MaxLevel do levelOptions[#levelOptions + 1] = tostring(i) end
auto:Dropdown({
	Name = "Target Level", Desc = "Every unit on your plot is raised to this level (max 50)",
	Options = levelOptions, Default = tostring(Config.TargetLevel),
	Callback = function(v) Config.TargetLevel = tonumber(v) or 25 end,
})
auto:Toggle({ Name = "Auto Level Up", Desc = "Upgrades each unit, only the levels it is missing",
	Default = false, Callback = function(v) Config.AutoLevel = v end })

auto:Section("Rewards")
auto:Toggle({ Name = "Auto Claim Rewards", Desc = "Keeps trying rewards 1-12 (already claimed ones are skipped by the server)",
	Default = false, Callback = function(v) Config.AutoRewards = v end })
auto:Toggle({ Name = "Auto Daily Reward", Desc = "Claims the daily reward",
	Default = false, Callback = function(v) Config.AutoDaily = v end })

auto:Section("Events")
auto:Toggle({ Name = "Auto Compass", Desc = "Teleports to the Lucky Compass, then returns you",
	Default = false, Callback = function(v) Config.AutoCompass = v end })

misc = Window:BuildMisc()
Window:OnDestroy(Unload)
Window:PlayIntro()

genv.FAP = {
	Config = Config, State = S, Dump = Dump, DumpBuy = DumpBuy,
	SetMutation = SetMutation, SetIslandByName = SetIslandByName, Unload = Unload,
}
