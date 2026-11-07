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
	SlotCount = 30,
	PlotName  = "Plot4",   -- fallback if your own plot can't be detected

	AutoBuy     = false,
	AutoCollect = false,
	AutoPlace   = false,
	AutoOpen    = false,
	AutoCompass = false,
	AutoPumpkin = false,

	BuyDelay     = 0.35,
	CollectDelay = 5,
	PlaceDelay   = 1,
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

local function selectedIslands()
	local t = {}
	for i = 1, Config.MaxIsland do
		if Config.Islands[i] then t[#t + 1] = i end
	end
	return t
end

local function selectedMutations()
	local t = {}
	for _, m in ipairs(MutationOrder) do
		if Config.Mutations[m] then t[#t + 1] = m end
	end
	return t
end

-- same payload the game's own "Auto Stop" sends
local function pushStopOn()
	local islands, muts = {}, {}
	for _, i in ipairs(selectedIslands()) do islands[tostring(i)] = true end
	for _, m in ipairs(selectedMutations()) do
		if m ~= "Celestial" then muts[m] = true end
	end
	act("CurrentSettings", "stopOn", {
		islands   = islands,
		on        = true,
		celestial = Config.Mutations.Celestial == true,
		muts      = muts,
	})
end

local pending = false
local function syncSettings()
	if pending then return end
	pending = true
	task.delay(0.4, function()
		pending = false
		if alive then pushStopOn() end
	end)
end

local function SetMutation(name, state)
	if Config.Mutations[name] == nil then return end
	Config.Mutations[name] = state and true or false
	syncSettings()
end

local function SetIsland(n, state)
	n = tonumber(n)
	if not n or Config.Islands[n] == nil then return end
	Config.Islands[n] = state and true or false
	syncSettings()
end

local function SetAllMutations(state)
	for m in pairs(Config.Mutations) do Config.Mutations[m] = state end
	syncSettings()
end

local function SetAllIslands(state)
	for i = 1, Config.MaxIsland do Config.Islands[i] = state end
	syncSettings()
end

local function loop(flag, delay, fn)
	task.spawn(function()
		while alive do
			if Config[flag] then pcall(fn) end
			task.wait(Config[delay] or delay)
		end
	end)
end

-- touch a part / model with the character
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

-- one teleport at a time: go, do the job, return to where you were
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
-- AUTO BUY
----------------------------------------------------------------
task.spawn(function()
	while alive do
		if Config.AutoBuy then
			local islands = selectedIslands()
			if #islands == 0 then
				task.wait(1)
			else
				for _, i in ipairs(islands) do
					if not (alive and Config.AutoBuy) then break end
					act("Buy", i, nil)
					task.wait(Config.BuyDelay)
				end
			end
		else
			task.wait(0.5)
		end
	end
end)

----------------------------------------------------------------
-- AUTO COLLECT (teleports to Plots.<yourplot>.CollectPads.PadAll.Top)
----------------------------------------------------------------
local function ownPlot()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return end
	for _, p in ipairs(plots:GetChildren()) do
		for _, v in pairs(p:GetAttributes()) do
			if v == lp.Name or v == lp.UserId or v == lp.DisplayName then return p end
		end
	end
	return plots:FindFirstChild(Config.PlotName)
end

local function collectTop()
	local plot = ownPlot()
	local pads = plot and plot:FindFirstChild("CollectPads")
	local pad  = pads and pads:FindFirstChild("PadAll")
	return pad and pad:FindFirstChild("Top")
end

loop("AutoCollect", "CollectDelay", function()
	local top = collectTop()
	if not top then
		act("Collect", "all")
		return
	end
	runTp(function(hrp)
		tpTo(hrp, top.Position)
		task.wait(0.15)
		touch(hrp, top)
		task.wait(0.15)
		act("Collect", "all")
		task.wait(0.1)
	end)
end)

----------------------------------------------------------------
-- AUTO OPEN
----------------------------------------------------------------
loop("AutoOpen", "OpenDelay", function()
	for slot = 1, Config.SlotCount do
		if not (alive and Config.AutoOpen) then break end
		act("Open", slot, nil)
		task.wait(0.05)
	end
end)

----------------------------------------------------------------
-- AUTO PLACE
----------------------------------------------------------------
loop("AutoPlace", "PlaceDelay", function()
	local islands, muts = selectedIslands(), selectedMutations()
	if #islands == 0 or #muts == 0 then return end
	for slot = 1, Config.SlotCount do
		local placed = false
		for _, i in ipairs(islands) do
			for _, m in ipairs(muts) do
				if not (alive and Config.AutoPlace) then return end
				local ok, res = act("PlaceChest", ("chest:%d:%s"):format(i, m), slot)
				task.wait(0.03)
				if ok and res == true then placed = true break end
			end
			if placed then break end
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
	return summary(t, "none")
end

local function tell(text)
	if Window.Notify then pcall(function() Window:Notify(text) end) end
end

Window:BuildHome(features, {
	{ Title = "Mutations", Get = function() return summary(selectedMutations(), "none") end },
	{ Title = "Islands",   Get = islandText },
}, { Tier = "Free" })

-- ===== Mutations & Islands tab (Auto Buy lives here) =====
local pick = Window:Tab({
	Name = "Pick", Icon = "target", PageTitle = "Mutations & Islands",
	Desc = "Pick an entry to toggle it on/off. All / None are shortcuts.",
})

pick:Section("Mutation")
local mutOptions = { "All", "None" }
for _, m in ipairs(MutationOrder) do mutOptions[#mutOptions + 1] = m end
pick:Dropdown({
	Name = "Mutation", Desc = "Toggle which mutations to keep / buy",
	Options = mutOptions, Default = "All",
	Callback = function(v)
		if v == "All" then SetAllMutations(true)
		elseif v == "None" then SetAllMutations(false)
		else SetMutation(v, not Config.Mutations[v]) end
		tell("Mutations: " .. summary(selectedMutations(), "none"))
	end,
})

pick:Section("Islands")
local islOptions = { "All", "None" }
for i = 1, Config.MaxIsland do islOptions[#islOptions + 1] = tostring(i) end
pick:Dropdown({
	Name = "Islands", Desc = "Toggle which islands to buy from",
	Options = islOptions, Default = "All",
	Callback = function(v)
		if v == "All" then SetAllIslands(true)
		elseif v == "None" then SetAllIslands(false)
		else SetIsland(v, not Config.Islands[tonumber(v)]) end
		tell("Islands: " .. islandText())
	end,
})

pick:Section("Buy")
pick:Toggle({
	Name = "Auto Buy", Desc = "Buys the picked islands, keeps the picked mutations",
	Default = false,
	Callback = function(v)
		Config.AutoBuy = v
		if v then pushStopOn() end
	end,
})

-- ===== Auto tab =====
local auto = Window:Tab({
	Name = "Auto", Icon = "zap", PageTitle = "Automation",
	Desc = "Place, open, collect, compass and pumpkins.",
})

auto:Section("Chests")
auto:Toggle({ Name = "Auto Place", Desc = "Places picked island/mutation chests",
	Default = false, Callback = function(v) Config.AutoPlace = v end })
auto:Toggle({ Name = "Auto Open", Desc = "Opens your placed chests",
	Default = false, Callback = function(v) Config.AutoOpen = v end })
auto:Toggle({ Name = "Auto Collect", Desc = "Teleports to your collect pad, collects, comes back",
	Default = false, Callback = function(v) Config.AutoCollect = v end })

auto:Section("Events")
auto:Toggle({ Name = "Auto Compass", Desc = "Teleports to the Lucky Compass, then returns you",
	Default = false, Callback = function(v) Config.AutoCompass = v end })
auto:Toggle({ Name = "Auto Pumpkin", Desc = "Teleports to each Halloween pumpkin and grabs it",
	Default = false, Callback = function(v) Config.AutoPumpkin = v end })

misc = Window:BuildMisc()
Window:OnDestroy(Unload)
Window:PlayIntro()

genv.FAP = {
	Config = Config, SetMutation = SetMutation, SetIsland = SetIsland, Unload = Unload,
}
