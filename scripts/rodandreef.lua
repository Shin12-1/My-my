--// Rod And Reef : Fishing  |  Auto Fish (perfect cast + needle minigame)  |  igkii lib
--// PlaceId 113515915341334  |  GameId 9388304346

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local ENV = (getgenv and getgenv()) or _G
if ENV.RR_UNLOAD then pcall(ENV.RR_UNLOAD) end

----------------------------------------------------------------------
-- SETTINGS / STATE
----------------------------------------------------------------------
local S = {
	Fish = false,      -- master: cast + minigame
	Mini = false,      -- minigame only (you cast by hand)
	Perfect = true,    -- perfect cast (release at the top of the bar)
	Thresh = 94,       -- release when the bar is >= this % full
	CastHold = 1.6,    -- fallback hold time (s) if the bar can't be read
	Lead = 60,         -- ms the click is sent ahead of the needle
	Width = 30,        -- zone width in degrees (hit window)
	ZoneOff = 0,       -- zone angle offset
	NeedleOff = 0,     -- needle angle offset
	Space = false,     -- press with Space instead of mouse click
	Bite = 35,         -- seconds to wait for a bite before re-casting
	After = 1.2,       -- seconds to wait after a minigame ends
}
local stats = { casts = 0, rounds = 0, presses = 0 }
local running = true
local conns = {}

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------
local function angdiff(a, b) return ((a - b + 540) % 360) - 180 end

local function shown(o)
	local p = o
	while p and p ~= game do
		if p:IsA("GuiObject") and not p.Visible then return false end
		if p:IsA("LayerCollector") and not p.Enabled then return false end
		p = p.Parent
	end
	return p == game
end

local function viewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

local function mouse(down)
	local v = viewport()
	pcall(function() VIM:SendMouseButtonEvent(v.X * 0.62, v.Y * 0.45, 0, down, game, 0) end)
end

local function key(down)
	pcall(function() VIM:SendKeyEvent(down, Enum.KeyCode.Space, false, game) end)
end

local function press()
	if S.Space then key(true) task.wait(0.03) key(false)
	else mouse(true) task.wait(0.03) mouse(false) end
end

local function nm(o, list)
	local n = o.Name:lower()
	for _, k in ipairs(list) do if n:find(k, 1, true) then return true end end
	return false
end
local NEEDLE_N = { "needle", "pointer", "hand", "arrow", "indicator", "pin" }
local ZONE_N = { "zone", "target", "sweet", "safe", "hit", "arc", "goal", "area", "success", "perfect" }

local function equipRod()
	local ch = LP.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	for _, t in ipairs(ch:GetChildren()) do
		if t:IsA("Tool") then return end
	end
	local first
	for _, t in ipairs(LP.Backpack:GetChildren()) do
		if t:IsA("Tool") then
			first = first or t
			if t.Name:lower():find("rod") then hum:EquipTool(t) return end
		end
	end
	if first then hum:EquipTool(first) end
end

----------------------------------------------------------------------
-- MINIGAME (needle) DETECTION
----------------------------------------------------------------------
local promptLbl, needle, zone
local lastScan, lastActive = 0, 0

local function isPromptText(d)
	if not d:IsA("TextLabel") then return false end
	local t = d.Text:lower()
	if not (t:find("reaches the zone", 1, true) or t:find("press when the needle", 1, true)) then return false end
	if d:FindFirstAncestor("Tutorial") then return false end
	return true
end

local function findPrompt(force)
	if promptLbl and promptLbl.Parent and shown(promptLbl) then return promptLbl end
	if not force and tick() - lastScan < 0.4 then return nil end
	lastScan = tick()
	for _, d in ipairs(PG:GetDescendants()) do
		if isPromptText(d) and shown(d) then
			if promptLbl ~= d then needle, zone, lastN = nil, nil, nil end
			promptLbl = d
			return d
		end
	end
end

local function mini()
	return promptLbl ~= nil and promptLbl.Parent ~= nil and shown(promptLbl)
end

local function zoneAngle()
	local a = zone.Rotation
	local g = zone:FindFirstChildOfClass("UIGradient")
	if g and a == 0 then a = g.Rotation end
	return a
end

local scanning, armed, armedAt, lastN = false, true, 0, nil

local function acquire()
	local root = promptLbl and promptLbl:FindFirstAncestorOfClass("ScreenGui")
	if not root then return end
	local cands, base = {}, {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") and d ~= promptLbl and not d:IsA("TextLabel") and shown(d) then
			cands[#cands + 1] = d
			base[d] = d.Rotation
		end
	end
	task.wait(0.12)
	local nBest, nScore, zBest, zScore
	for _, d in ipairs(cands) do
		if d.Parent then
			local delta = math.abs(angdiff(d.Rotation, base[d]))
			local isN, isZ = nm(d, NEEDLE_N), nm(d, ZONE_N)
			if delta > 1.5 then
				local sc = delta + (isN and 1000 or 0) - (isZ and 500 or 0)
				if not nScore or sc > nScore then nBest, nScore = d, sc end
			else
				local g = d:FindFirstChildOfClass("UIGradient")
				local r = math.abs(d.Rotation) + (g and math.abs(g.Rotation) or 0)
				local sc = (isZ and 1000 or 0) - (isN and 500 or 0) + (r > 0.5 and 100 or 0) + (d:IsA("ImageLabel") and 10 or 0)
				if sc > 0 and (not zScore or sc > zScore) then zBest, zScore = d, sc end
			end
		end
	end
	needle, zone = nBest, zBest
	armed, lastN = true, nil
	if not (needle and zone) then
		warn("[RodReef] needle/zone not found - press 'Dump Minigame GUI' during a minigame and send me the output")
	end
end

table.insert(conns, RunService.Heartbeat:Connect(function(dt)
	if not (S.Fish or S.Mini) then return end
	if not (promptLbl and promptLbl.Parent and shown(promptLbl)) then
		needle, zone, lastN = nil, nil, nil
		findPrompt()
		if not (promptLbl and promptLbl.Parent and shown(promptLbl)) then return end
	end
	lastActive = tick()
	if not needle or not needle.Parent or not zone or not zone.Parent then
		if not scanning then
			scanning = true
			task.spawn(function() pcall(acquire) scanning = false end)
		end
		return
	end
	local n = needle.Rotation + S.NeedleOff
	local z = zoneAngle() + S.ZoneOff
	local diff = angdiff(n, z)
	local v = 0
	if lastN then v = angdiff(n, lastN) / math.max(dt, 1e-3) end
	lastN = n
	local pd = diff + v * (S.Lead / 1000)
	local win = math.max(S.Width * 0.25, math.abs(v) * dt * 1.5)
	if armed then
		if math.abs(pd) <= win then
			armed, armedAt = false, tick()
			stats.presses += 1
			task.spawn(press)
		end
	elseif math.abs(diff) > S.Width * 0.5 + 8 or tick() - armedAt > 0.9 then
		armed = true
	end
end))

----------------------------------------------------------------------
-- PERFECT CAST (vertical bar)
----------------------------------------------------------------------
local function tallSet()
	local set = {}
	local function scan(r)
		for _, d in ipairs(r:GetDescendants()) do
			if d:IsA("GuiObject") then
				local s = d.AbsoluteSize
				if s.Y >= 20 and s.Y >= s.X * 4 and shown(d) then set[d] = true end
			end
		end
	end
	scan(PG)
	if LP.Character then scan(LP.Character) end
	return set
end

local function castPerfect()
	local base = S.Perfect and tallSet() or {}
	mouse(true)
	local t0 = tick()
	local cont, fill, tries, nextTry = nil, nil, 0, 0.15
	local prevR, prevT
	while running and (S.Fish) and tick() - t0 < 5 do
		task.wait()
		local el = tick() - t0
		if not S.Perfect then
			if el >= 0.35 then break end
		else
			if not cont and tries < 3 and el >= nextTry then
				tries += 1
				nextTry = el + 0.3
				local best
				for d in pairs(tallSet()) do
					if not base[d] and (not best or d.AbsoluteSize.Y > best.AbsoluteSize.Y) then best = d end
				end
				if best then
					cont = best
					local ys = { [best] = best.AbsoluteSize.Y }
					for _, d in ipairs(best:GetDescendants()) do
						if d:IsA("GuiObject") then ys[d] = d.AbsoluteSize.Y end
					end
					task.wait(0.08)
					local bd, bg
					for d, y in pairs(ys) do
						local g = math.abs(d.AbsoluteSize.Y - y)
						if d ~= best and g > 2 and (not bg or g > bg) then bd, bg = d, g end
					end
					fill = bd
				end
			end
			if cont and fill and fill.Parent and cont.Parent then
				local r = math.clamp(fill.AbsoluteSize.Y / math.max(cont.AbsoluteSize.Y, 1), 0, 1.2)
				local vel = 0
				if prevR then vel = (r - prevR) / math.max(tick() - prevT, 1e-3) end
				prevR, prevT = r, tick()
				if r + vel * 0.05 >= S.Thresh / 100 then break end
			elseif el >= 0.9 or (tries >= 3 and el >= S.CastHold) then
				if el >= S.CastHold then break end
			end
		end
	end
	mouse(false)
end

----------------------------------------------------------------------
-- MAIN LOOP
----------------------------------------------------------------------
task.spawn(function()
	while running do
		task.wait(0.2)
		if S.Fish then
			findPrompt()
			if not mini() and tick() - lastActive > 1.5 then
				equipRod()
				pcall(castPerfect)
				stats.casts += 1
				local t0 = tick()
				while running and S.Fish and tick() - t0 < S.Bite and not mini() do
					findPrompt()
					task.wait(0.1)
				end
				if mini() then
					repeat task.wait(0.15)
					until not running or not S.Fish or (not mini() and tick() - lastActive > 1.5)
					stats.rounds += 1
					task.wait(S.After)
				elseif running and S.Fish then
					press()
					task.wait(1.5)
				end
			end
		elseif S.Mini then
			findPrompt()
		end
	end
end)

----------------------------------------------------------------------
-- DEBUG DUMPS
----------------------------------------------------------------------
local function dumpMini()
	print("===== ROD&REEF MINIGAME DUMP =====")
	findPrompt(true)
	if not (promptLbl and shown(promptLbl)) then
		print("minigame prompt is not on screen - press this button while the needle minigame is showing")
		for _, d in ipairs(PG:GetDescendants()) do
			if d:IsA("TextLabel") and d.Text:lower():find("needle", 1, true) then
				print("text match:", d:GetFullName(), "shown:", shown(d))
			end
		end
		return
	end
	local root = promptLbl:FindFirstAncestorOfClass("ScreenGui")
	print("prompt:", promptLbl:GetFullName())
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") then
			local g = d:FindFirstChildOfClass("UIGradient")
			print(("%s | %s | rot=%.1f | grad=%s | vis=%s | %dx%d"):format(
				d:GetFullName(), d.ClassName, d.Rotation, g and string.format("%.1f", g.Rotation) or "-",
				tostring(shown(d)), d.AbsoluteSize.X, d.AbsoluteSize.Y))
		end
	end
	print("needle:", needle and needle:GetFullName(), "zone:", zone and zone:GetFullName())
end

local function dumpCast()
	print("===== ROD&REEF CAST BAR DUMP (hold the cast now) =====")
	task.delay(4, function()
		for d in pairs(tallSet()) do
			print(("%s | %s | %dx%d"):format(d:GetFullName(), d.ClassName, d.AbsoluteSize.X, d.AbsoluteSize.Y))
		end
		print("===== END =====")
	end)
end

----------------------------------------------------------------------
-- UI (igkii lib)
----------------------------------------------------------------------
local function fetch(p)
	local f = (ENV.IGKII_FETCH) or (rawget and rawget(_G, "IGKII_FETCH"))
	if f then return f(p) end
	return game:HttpGet("https://igkii.kiantejero.workers.dev/scripts/" .. p)
end

local Library = loadstring(fetch("igkii_lib.lua"))()
local misc
local features = Library.MiscFeatures(function() return misc end)
table.insert(features, { Name = "Auto Fish", Get = function() return S.Fish end })
table.insert(features, { Name = "Auto Minigame", Get = function() return S.Mini end })

local Window = Library.Window({ Title = "Rod And Reef" })

Window:BuildHome(features, {
	{ Title = "Casts", Get = function() return tostring(stats.casts) end },
	{ Title = "Rounds", Get = function() return tostring(stats.rounds) end },
	{ Title = "Clicks", Get = function() return tostring(stats.presses) end },
}, { Tier = "Free" })

local function ui(label, f)
	local ok, e = pcall(f)
	if not ok then warn("[RodReef] UI '" .. label .. "' failed: " .. tostring(e)) end
end

local Fish = Window:Tab({ Name = "Fishing", Icon = "fish", PageTitle = "Auto Fishing", Desc = "Perfect cast + needle minigame" })

Fish:Section("Auto")
ui("Auto Fish", function()
	Fish:Toggle({ Name = "Auto Fish", Desc = "Perfect cast, waits for the bite, clicks every needle attempt", Default = false,
		Callback = function(v) S.Fish = v end })
end)
ui("Auto Minigame", function()
	Fish:Toggle({ Name = "Auto Minigame Only", Desc = "You cast, it clicks the needle attempts", Default = false,
		Callback = function(v) S.Mini = v end })
end)
ui("Perfect Cast", function()
	Fish:Toggle({ Name = "Perfect Cast", Desc = "Release at the top (green) of the cast bar", Default = true,
		Callback = function(v) S.Perfect = v end })
end)

Fish:Section("Cast")
ui("Release %", function()
	Fish:Slider({ Name = "Release At %", Desc = "Bar fill % where the cast is released", Min = 70, Max = 100, Default = 94,
		Callback = function(v) S.Thresh = v end })
end)
ui("Fallback hold", function()
	Fish:Slider({ Name = "Fallback Hold (s)", Desc = "Hold time if the bar can't be read", Min = 0.3, Max = 4, Default = 1.6,
		Callback = function(v) S.CastHold = v end })
end)
ui("Bite timeout", function()
	Fish:Slider({ Name = "Bite Timeout (s)", Desc = "Wait this long for a bite before re-casting", Min = 10, Max = 90, Default = 35,
		Callback = function(v) S.Bite = v end })
end)

Fish:Section("Needle")
ui("Lead", function()
	Fish:Slider({ Name = "Click Lead (ms)", Desc = "Click earlier if you hit late, lower if early", Min = 0, Max = 250, Default = 60,
		Callback = function(v) S.Lead = v end })
end)
ui("Width", function()
	Fish:Slider({ Name = "Zone Width", Desc = "Hit window in degrees", Min = 10, Max = 90, Default = 30,
		Callback = function(v) S.Width = v end })
end)
ui("Zone offset", function()
	Fish:Slider({ Name = "Zone Offset", Desc = "Shifts the zone angle", Min = -180, Max = 180, Default = 0,
		Callback = function(v) S.ZoneOff = v end })
end)
ui("Needle offset", function()
	Fish:Slider({ Name = "Needle Offset", Desc = "Shifts the needle angle (180 if it uses the tail)", Min = -180, Max = 180, Default = 0,
		Callback = function(v) S.NeedleOff = v end })
end)
ui("Space", function()
	Fish:Toggle({ Name = "Click With Space", Desc = "Use the Space key instead of a mouse click", Default = false,
		Callback = function(v) S.Space = v end })
end)

Fish:Section("Debug")
ui("Dump minigame", function()
	Fish:Button({ Name = "Dump Minigame GUI", Desc = "Run during a needle minigame, then check the console (F9)",
		Callback = dumpMini })
end)
ui("Dump cast", function()
	Fish:Button({ Name = "Dump Cast Bar", Desc = "Press, then hold your cast for 4 seconds",
		Callback = dumpCast })
end)

misc = Window:BuildMisc()

local function unload()
	running = false
	S.Fish, S.Mini = false, false
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	mouse(false)
	ENV.RR_UNLOAD = nil
end
ENV.RR_UNLOAD = unload
Window:OnDestroy(unload)
Window:PlayIntro()
