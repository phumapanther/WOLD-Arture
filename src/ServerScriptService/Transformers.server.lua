-- Transformers.server.lua: the blackout, and the machines that end it.
--
-- This file implements the blackout event: it registers a start/stop pair with EventState, and WorldEvents
-- calls them without knowing what is in here. Everything the event does to the world lives on this side --
-- the lamps, the broken machines, and the thirty seconds of work it takes to fix one.
--
-- Transformers are found by TAG, like everything else in the world worth pressing E at: WOLD_Transformer.
-- The models come from the kit's Substation (three to a station); mapgen/64_transformers.lua tags whatever
-- the user has actually placed.
--
-- A repair, end to end:
--   1. E, but only while the lights are out. Outside a blackout there is no prompt at all, which is the
--      user's rule -- a working machine should have nothing to press.
--   2. Thirty seconds of standing still, with the engine sound looping and the character working.
--   3. Two to four skill checks interrupt it. Missing one ends the repair and leaves you dizzy; the thirty
--      seconds are lost, not paused.
--   4. WALKING ends it too. The server measures the distance from where the repair started rather than
--      trusting the client to admit it moved.
--   5. A finished repair pays out and marks the machine mended. When the last one is mended the event is
--      over, and WorldEvents is told.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local EventConfig = require(game.ReplicatedStorage.EventConfig)
local FarmConfig = require(game.ReplicatedStorage.FarmConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local Progression = require(game.ServerScriptService.Progression)
local Vitals = require(game.ServerScriptService.Vitals)
local StatusEffects = require(game.ServerScriptService.StatusEffects)
local Minigames = require(game.ServerScriptService.Minigames)
local EventState = require(game.ServerScriptService.EventState)
local Remotes = require(game.ReplicatedStorage.Remotes)

local TAG = "WOLD_Transformer"
local Repair = EventConfig.Repair

--------------------------------------------------------------------------------
-- Finding the machines
--------------------------------------------------------------------------------

local function anchorOf(machine)
	if machine:IsA("BasePart") then return machine end
	if not machine:IsA("Model") then return nil end

	local existing = machine:FindFirstChild("RepairAnchor")
	if existing then return existing end

	-- The same reasoning the farm nodes use: a prompt measures its range from the PART it hangs on, and a
	-- transformer tank is eight studs tall with its origin in the middle. A marker at the base is the only
	-- way the range means what it says.
	local low, minX, maxX, minZ, maxZ = math.huge, math.huge, -math.huge, math.huge, -math.huge
	for _, d in ipairs(machine:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.9 then
			low = math.min(low, d.Position.Y - d.Size.Y / 2)
			minX, maxX = math.min(minX, d.Position.X), math.max(maxX, d.Position.X)
			minZ, maxZ = math.min(minZ, d.Position.Z), math.max(maxZ, d.Position.Z)
		end
	end
	if low == math.huge then
		return machine.PrimaryPart or machine:FindFirstChildWhichIsA("BasePart", true)
	end

	local anchor = Instance.new("Part")
	anchor.Name = "RepairAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = Vector3.new((minX + maxX) / 2, low + 2, (minZ + maxZ) / 2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Parent = machine
	return anchor
end

local function machines()
	return CollectionService:GetTagged(TAG)
end

local function isBroken(machine)
	return machine:GetAttribute("Broken") == true
end

local function setPrompt(machine, enabled)
	local anchor = anchorOf(machine)
	local prompt = anchor and anchor:FindFirstChild("RepairPrompt")
	if prompt then prompt.Enabled = enabled end
end

-- How many are still broken, and how many there are. Drives the banner's right-hand side and the decision to
-- end the event.
local function tally()
	local broken, total = 0, 0
	for _, machine in ipairs(machines()) do
		total += 1
		if isBroken(machine) then broken += 1 end
	end
	return broken, total
end

local function publishTally()
	local broken, total = tally()
	EventState.SetDetail("blackout", ("ซ่อมแล้ว %d/%d"):format(total - broken, total))
	return broken, total
end

--------------------------------------------------------------------------------
-- The lamps
--------------------------------------------------------------------------------

-- Every light the map placed, remembered so it can be put back exactly as it was. A lantern that was already
-- switched off before the blackout must not come back on when the power does.
local Doused = {}

-- Bumped every time the lights are asked to change. The douse walks the world in batches with a yield
-- between them, so an event that ends while that walk is still running would otherwise have its restore
-- happen FIRST and the rest of the town go dark behind it, with nothing left to turn them back on.
local lightGeneration = 0

local function setLights(on)
	lightGeneration += 1
	local generation = lightGeneration

	if on then
		for light in pairs(Doused) do
			if light.Parent then light.Enabled = true end
		end
		Doused = {}
		return
	end

	-- Walked in batches with a yield between them. A built-out town holds thousands of lanterns, and touching
	-- them all in one frame is a visible hitch on the very frame the announcement lands.
	local scanned = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if lightGeneration ~= generation then return end -- the power came back mid-scan
		if d:IsA("Light") and d.Enabled then
			d.Enabled = false
			Doused[d] = true
		end
		scanned += 1
		if scanned % 2000 == 0 then task.wait() end
	end
end

--------------------------------------------------------------------------------
-- One repair
--------------------------------------------------------------------------------

-- [player] = { machine, startedAt, endsAt, origin, cancelled }
local Working = {}

local function stopWork(player, reason)
	local work = Working[player]
	if not work then return end
	Working[player] = nil
	work.cancelled = true

	if work.sound then work.sound:Destroy() end
	if work.stopAnimation then work.stopAnimation() end
	-- A check still on screen belongs to a repair that no longer exists.
	Minigames.Cancel(player)

	if player.Parent then
		Remotes.RepairStateChanged:FireClient(player, "stopped", reason)
	end
end

-- The looping engine sound, played AT the machine so everyone nearby hears the work rather than only the
-- person doing it.
local function startSound(anchor)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://126212750200158" -- assets/sounds/metallic, the engine being worked on
	sound.Volume = 0.4
	sound.RollOffMaxDistance = 60
	sound.Looped = true
	sound.Parent = anchor
	sound:Play()
	return sound
end

-- The same rummaging pose the illegal farms use. One animation for "a person working on a thing with their
-- hands", rather than two that would have to be built and published separately.
local function playWorkAnimation(player)
	local id = FarmConfig.SearchAnimation
	if type(id) ~= "string" or id == "" then return function() end end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return function() end end

	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	if not ok or not track then
		animation:Destroy()
		return function() end
	end
	track.Looped = true
	track:Play(0.2)
	return function()
		track:Stop(0.2)
		animation:Destroy()
	end
end

local function reward(player)
	local entry = Repair.Rewards[math.random(1, #Repair.Rewards)]
	local count = math.random(entry.min or 1, entry.max or 1)
	local item = ItemCatalog.Get(entry.item)
	if Inventory.AddItem(player, entry.item, count) then
		Remotes.SocialNotify:FireClient(player, "info",
			("ซ่อมสำเร็จ ได้ %s x%d"):format(item and item.name or entry.item, count))
	else
		Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม ของที่ได้หล่นหาย")
	end

	local gold = math.random(Repair.GoldMin, Repair.GoldMax)
	Inventory.AddGold(player, gold)
	Remotes.SocialNotify:FireClient(player, "info", ("ค่าแรงซ่อม %d เหรียญ"):format(gold))
	if Repair.Xp and Repair.Xp > 0 then Progression.AwardExp(player, Repair.Xp) end
end

local function finishRepair(player, machine)
	stopWork(player, "done")
	if not isBroken(machine) then return end -- somebody else got there first

	machine:SetAttribute("Broken", nil)
	setPrompt(machine, false)
	reward(player)

	local broken = publishTally()
	if broken <= 0 then
		-- The last one. The event has no clock on it, so this is the only thing that ends it.
		if EventState.Stop then EventState.Stop("blackout") end
	end
end

-- The skill checks, scheduled up front so they are spread across the repair rather than clustered by luck.
local function scheduleChecks(player, machine, work)
	local count = math.random(Repair.MinChecks, Repair.MaxChecks)
	local times = {}
	local at = Repair.FirstCheckAfter
	for _ = 1, count do
		if at >= Repair.Seconds - 2 then break end
		table.insert(times, at)
		at += Repair.MinCheckGap + math.random() * 3
	end

	for _, when in ipairs(times) do
		task.delay(when, function()
			-- Everything may have moved on during the wait: the repair cancelled, the player left, somebody
			-- else finished this machine.
			if Working[player] ~= work or work.cancelled then return end
			if not player.Parent then return end

			Minigames.Run(player, { kind = "skillcheck", title = "ตีให้ตรงจังหวะ" }, function(success)
				if Working[player] ~= work or work.cancelled then return end
				if success then return end
				StatusEffects.Dizzy(player, Repair.DizzySeconds)
				Remotes.SocialNotify:FireClient(player, "error", "ตีพลาด การซ่อมล้มเหลว")
				stopWork(player, "failed")
			end)
		end)
	end
end

local function beginRepair(machine, player)
	if not EventState.IsBlackout() then return end
	if not isBroken(machine) then return end
	if Vitals.IsDowned(player) then return end
	if StatusEffects.IsDizzy(player) then
		return Remotes.SocialNotify:FireClient(player, "error", "ยังมึนอยู่ รอสักครู่")
	end
	if Working[player] then return end
	if Minigames.IsBusy(player) then return end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local anchor = anchorOf(machine)
	if not anchor then return end

	local work = {
		machine = machine,
		origin = root.Position,
		endsAt = os.clock() + Repair.Seconds,
	}
	work.sound = startSound(anchor)
	work.stopAnimation = playWorkAnimation(player)
	Working[player] = work

	Remotes.RepairStateChanged:FireClient(player, "started", Repair.Seconds)
	scheduleChecks(player, machine, work)

	-- The repair's own clock, and the thing that notices a player walking away. Measured on the SERVER from
	-- the position the repair started at: a client asked to report its own movement would have every reason
	-- not to.
	task.spawn(function()
		while Working[player] == work and not work.cancelled do
			task.wait(0.25)
			if Working[player] ~= work then return end
			if not player.Parent then return stopWork(player, "left") end

			local live = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not live or Vitals.IsDowned(player) then
				return stopWork(player, "interrupted")
			end
			-- Moving is the one thing that ends a repair without a mistake having been made. Measured against
			-- where the repair began rather than against the machine, so being nudged off the spot by someone
			-- running past costs the same as walking away -- which is the honest reading of "อย่าขยับ".
			--
			-- FLAT distance. The straight-line version counted a jump as leaving: a jump lifts the character
			-- about seven studs, past this six-stud limit, so pressing space dropped a repair that was going
			-- perfectly. Walking away is a thing you do along the ground.
			local away = live.Position - work.origin
			if Vector3.new(away.X, 0, away.Z).Magnitude > Repair.LeaveDistance then
				Remotes.SocialNotify:FireClient(player, "error", "เดินออกจากเครื่อง การซ่อมหลุด")
				return stopWork(player, "moved")
			end
			-- The machine may have been finished by somebody else standing on the other side of it.
			if not isBroken(machine) then
				return stopWork(player, "taken")
			end
			if os.clock() >= work.endsAt then
				return finishRepair(player, machine)
			end
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	stopWork(player, "left")
end)

--------------------------------------------------------------------------------
-- Wiring the machines up
--------------------------------------------------------------------------------

local function register(machine)
	local anchor = anchorOf(machine)
	if not anchor then return end
	if anchor:FindFirstChild("RepairPrompt") then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RepairPrompt"
	prompt.ActionText = "ซ่อมไฟ"
	prompt.ObjectText = "หม้อแปลงไฟ"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = Repair.Range
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	-- Off until the lights go out. A working machine has nothing to press, which is the user's rule.
	prompt.Enabled = EventState.IsBlackout() and isBroken(machine)
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player)
		beginRepair(machine, player)
	end)
end

for _, machine in ipairs(machines()) do
	task.spawn(register, machine)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(machine)
	task.spawn(register, machine)
	-- A machine tagged during a blackout joins it broken, rather than being the one working lamp in a dark
	-- town that nobody can switch off.
	if EventState.IsBlackout() then
		machine:SetAttribute("Broken", true)
		setPrompt(machine, true)
		publishTally()
	end
end)

--------------------------------------------------------------------------------
-- The event itself
--------------------------------------------------------------------------------

EventState.Register("blackout", {
	start = function()
		local found = machines()
		if #found == 0 then
			-- No machines means no way to end it, and an event that can never end would lock every NPC in
			-- the game forever. Refusing is what the pcall in WorldEvents is for.
			error("no WOLD_Transformer models in this place -- run mapgen/64_transformers.lua first")
		end
		for _, machine in ipairs(found) do
			machine:SetAttribute("Broken", true)
			setPrompt(machine, true)
		end
		publishTally()
		task.spawn(setLights, false)
	end,

	stop = function()
		for _, machine in ipairs(machines()) do
			machine:SetAttribute("Broken", nil)
			setPrompt(machine, false)
		end
		-- Anyone mid-repair when the last machine was fixed by someone else is let go rather than left
		-- standing there working on a machine that is already mended.
		for player in pairs(Working) do
			stopWork(player, "over")
		end
		setLights(true)
	end,
})
