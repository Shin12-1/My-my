-- Blue Lock RNG | PlaceId 88691256512156 | GameId 10771345944
-- Auto Claim: every random weather drop (Medals and any other Kind)
-- Remote: ReplicatedStorage.Remotes.WeatherDrop
--   server -> client: "Spawn", {Id, Kind, Label, Pos, Ends} | "Got", id, "+8 Medals" | "Remove", id
--   client -> server: "Claim", id

local env = (getgenv and getgenv()) or _G
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- ================= UI LIB (separate file, loaded via loader) =================
local fetch = env.IGKII_FETCH
local Library = loadstring(fetch("igkii_lib.lua"))()

local misc
local features = Library.MiscFeatures(function() return misc end)

-- ================= STATE =================
local State = {
	AutoClaim = false,
	Fallback = true, -- move to the drop only if the direct claim was not confirmed
	Running = true,
}

local drops = {}   -- [id] = spawn data
local done = {}    -- [id] = true when claimed / confirmed
local stats = { Claimed = 0, Last = "-" }
local connections = {}

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WeatherDrop")

local function getRoot()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function fireClaim(id)
	pcall(function()
		remote:FireServer("Claim", id)
	end)
end

local function claim(id)
	if done[id] or not drops[id] then return end
	local data = drops[id]
	done[id] = "trying"

	-- 1) direct claim, no movement
	fireClaim(id)
	local t = os.clock()
	while os.clock() - t < 0.6 do
		if done[id] == true or not drops[id] then return end
		task.wait(0.05)
	end

	-- 2) fallback: go to the drop, claim, go back (only if not confirmed)
	if State.Fallback and State.Running and drops[id] and done[id] ~= true then
		local root = getRoot()
		if root and data.Pos then
			local back = root.CFrame
			root.CFrame = CFrame.new(data.Pos + Vector3.new(0, 3, 0))
			task.wait(0.15)
			fireClaim(id)
			local t2 = os.clock()
			while os.clock() - t2 < 0.6 do
				if done[id] == true or not drops[id] then break end
				task.wait(0.05)
			end
			root = getRoot()
			if root then root.CFrame = back end
		end
	end
end

-- ================= REMOTE LISTENER =================
table.insert(connections, remote.OnClientEvent:Connect(function(action, a, b)
	if action == "Spawn" and typeof(a) == "table" and a.Id then
		drops[a.Id] = a
		if State.AutoClaim then
			task.spawn(claim, a.Id)
		end
	elseif action == "Got" then
		done[a] = true
		stats.Claimed += 1
		stats.Last = tostring(b or "-")
	elseif action == "Remove" then
		drops[a] = nil
		done[a] = nil
	end
end))

-- sweep: claim anything still waiting when the toggle is turned on
task.spawn(function()
	while State.Running do
		if State.AutoClaim then
			for id in pairs(drops) do
				if not done[id] then
					task.spawn(claim, id)
				end
			end
		end
		task.wait(0.5)
	end
end)

-- ================= UI =================
table.insert(features, { Name = "Auto Claim Drops", Get = function() return State.AutoClaim end })

local Window = Library.Window({ Title = "Blue Lock RNG" })

Window:BuildHome(features, {
	{ Title = "Claimed", Get = function() return tostring(stats.Claimed) end },
	{ Title = "Last Reward", Get = function() return stats.Last end },
}, { Tier = "Free" })

local main = Window:Tab({
	Name = "Main",
	Icon = "home",
	PageTitle = "Weather Drops",
	Desc = "Randomly spawned drops (Medals and other items)",
})

main:Section("Auto Claim")

main:Toggle({
	Name = "Auto Claim Drops",
	Desc = "Claims every random drop the moment it spawns",
	Default = false,
	Callback = function(v)
		State.AutoClaim = v
	end,
})

main:Toggle({
	Name = "Move To Drop If Needed",
	Desc = "Only used when the direct claim is not confirmed",
	Default = true,
	Callback = function(v)
		State.Fallback = v
	end,
})

misc = Window:BuildMisc()

Window:OnDestroy(function()
	State.Running = false
	State.AutoClaim = false
	for _, c in ipairs(connections) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(drops)
	table.clear(done)
end)

Window:PlayIntro()
