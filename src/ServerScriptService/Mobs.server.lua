-- Mobs.server.lua: the monsters that wander the world, chase people, and drop things when killed.
--
-- Spawners are found by TAG, like gathering nodes: anything tagged WOLD_Spawner with a MobKind attribute
-- keeps that many monsters alive within a radius, respawning them as they die. The user places spawners
-- (or a mapgen phase scatters them) and this file never needs to know where they are.
--
-- Monsters are built from parts here rather than loaded from a model, for the same reason WeaponPrefabs
-- builds weapons in code: a model that lives only in the place file is one accident away from being gone
-- with no way to rebuild it. When the user's own slime model arrives it can replace buildSlime alone.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local Progression = require(game.ServerScriptService.Progression)
local Vitals = require(game.ServerScriptService.Vitals)
local MobAccess = require(game.ServerScriptService.MobAccess)
local EventState = require(game.ServerScriptService.EventState)
local VitalsConfig = require(game.ReplicatedStorage.VitalsConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local SPAWNER_TAG = "WOLD_Spawner"
local MOB_TAG = "WOLD_Mob"

-- [model] = { config, hp, spawner, home, nextAttackAt, target }
local Live = {}

local folder = Instance.new("Folder")
folder.Name = "WOLD_Mobs"
folder.Parent = workspace

--------------------------------------------------------------------------------
-- Building one
--------------------------------------------------------------------------------

-- A blob with eyes: two spheres and a wobble. Deliberately simple -- it is a placeholder for the user's
-- own model, and a complicated one would only be harder to throw away.
local function buildSlime(config)
	local model = Instance.new("Model")
	model.Name = "GreenSlime"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(3.4, 3.0, 3.4)
	body.Color = config.colour
	body.Material = Enum.Material.SmoothPlastic
	body.Transparency = 0.25
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model
	model.PrimaryPart = body

	for _, side in ipairs({ -0.7, 0.7 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.5, 0.5, 0.5)
		eye.Color = Color3.fromRGB(20, 24, 28)
		eye.Material = Enum.Material.SmoothPlastic
		eye.CanCollide = false
		eye.Massless = true
		eye.CFrame = body.CFrame * CFrame.new(side, 0.5, -1.35)
		eye.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = body
	end

	-- A Humanoid so it can walk with MoveTo and be steered like anything else. HP is tracked in Live
	-- rather than on the Humanoid so nothing outside this file can quietly kill one.
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = config.hp
	humanoid.Health = config.hp
	humanoid.WalkSpeed = config.walkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	-- Roblox wants a HumanoidRootPart to drive a Humanoid; the body doubles as one.
	body.Name = "HumanoidRootPart"

	local health = Instance.new("BillboardGui")
	health.Name = "Health"
	health.Size = UDim2.fromOffset(70, 8)
	health.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	health.MaxDistance = 60
	health.Parent = body
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
	back.BorderSizePixel = 0
	back.Parent = health
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(212, 84, 74)
	bar.BorderSizePixel = 0
	bar.Parent = back

	CollectionService:AddTag(model, MOB_TAG)
	return model
end

--------------------------------------------------------------------------------
-- Building one from the user's own model
--------------------------------------------------------------------------------

-- Where the hand-placed monster models live. The user arranged one of each in this folder; they are the
-- PROTOTYPES, not monsters -- each is cloned to make the real thing, and the original never moves or fights.
local PROTOTYPE_FOLDER = "Model_moster"

local function prototypeFor(config)
    if not config.model then return nil end

    -- ServerStorage FIRST. V1 moved the prototype folder out of the world: those display models carried the
    -- kit's own [E] prompts and name tags, so a player walking up to the spot where a rare slime spawns found
    -- a second, fake slime standing there offering a button that did nothing. They are still needed -- every
    -- monster is a clone of one -- so they moved rather than being deleted, and this looks in the new home
    -- first and the old one after, which means a place that has not run the phase yet still works.
    local stored = game:GetService("ServerStorage"):FindFirstChild(PROTOTYPE_FOLDER)
    local found = stored and stored:FindFirstChild(config.model)
    if found then return found end

    local root = workspace:FindFirstChild("WOLD")
    local folderInstance = root and root:FindFirstChild(PROTOTYPE_FOLDER, true)
    found = folderInstance and folderInstance:FindFirstChild(config.model)
    -- Searched by name across the whole world as a fallback, because the user is free to move the folder.
    if not found and root then found = root:FindFirstChild(config.model, true) end
    return found
end

-- A monster built by CLONING what the user modelled, rather than the placeholder ball.
--
-- Returns nil if the prototype is missing or unusable, and the caller falls back to buildSlime -- a missing
-- model should cost you the artwork, not the monster.
local function buildFromModel(config)
    local prototype = prototypeFor(config)
    if not prototype or not prototype:IsA("Model") then return nil end

    local model = prototype:Clone()
    model.Name = config.model

    -- A monster has to be driveable, and a display model is not. It needs a part the Humanoid can steer
    -- from, and that part has to be called HumanoidRootPart -- the kit names its pivot handle "Root", which
    -- Roblox does not recognise.
    local rootPart = model:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        local candidate = model.PrimaryPart or model:FindFirstChild("Root")
            or model:FindFirstChildWhichIsA("BasePart", true)
        if not candidate then model:Destroy(); return nil end
        candidate.Name = "HumanoidRootPart"
        rootPart = candidate
    end
    model.PrimaryPart = rootPart

    -- The kit's pivot handle is a transparent 1x1 marker that does not collide, which is exactly wrong for
    -- the part a Humanoid stands on: without collision it sinks through the floor.
    rootPart.Transparency = 1
    rootPart.CanCollide = true
    rootPart.Anchored = false

    -- Everything else rides along rather than fighting the physics: an anchored limb would pin the monster
    -- in place, and a colliding one would trip it over its own body.
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and d ~= rootPart then
            d.Anchored = false
            d.CanCollide = false
            d.Massless = true
            if not d:FindFirstChildWhichIsA("WeldConstraint") then
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = rootPart
                weld.Part1 = d
                weld.Parent = rootPart
            end
        end
        -- A prompt or a name tag belongs to the display model, not to something you are meant to fight.
        if d:IsA("ProximityPrompt") or (d:IsA("BillboardGui") and d.Name == "NameTag") then
            d:Destroy()
        end
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        humanoid = Instance.new("Humanoid")
        humanoid.Parent = model
    end
    humanoid.MaxHealth = config.hp
    humanoid.Health = config.hp
    humanoid.WalkSpeed = config.walkSpeed
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

    -- The same health bar the placeholder carries, so every monster reads the same way in a fight.
    local health = Instance.new("BillboardGui")
    health.Name = "Health"
    health.Size = UDim2.fromOffset(70, 8)
    local _, size = model:GetBoundingBox()
    health.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.6 + 1.5, 0)
    health.MaxDistance = 60
    health.Parent = rootPart
    local back = Instance.new("Frame")
    back.Size = UDim2.fromScale(1, 1)
    back.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
    back.BorderSizePixel = 0
    back.Parent = health
    local bar = Instance.new("Frame")
    bar.Name = "Bar"
    bar.Size = UDim2.fromScale(1, 1)
    bar.BackgroundColor3 = Color3.fromRGB(212, 84, 74)
    bar.BorderSizePixel = 0
    bar.Parent = back

    CollectionService:AddTag(model, MOB_TAG)
    return model
end

-- The monster for a config: the user's model where there is one, the placeholder ball otherwise.
local function buildMonster(config)
    return buildFromModel(config) or buildSlime(config)
end

--------------------------------------------------------------------------------
-- Living and dying
--------------------------------------------------------------------------------

local function setHealthBar(model, fraction)
	local root = model.PrimaryPart
	local gui = root and root:FindFirstChild("Health")
	local back = gui and gui:FindFirstChildWhichIsA("Frame")
	local bar = back and back:FindFirstChild("Bar")
	if bar then bar.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) end
end

local function drop(model, config, killer)
	if not killer or not killer.Parent then return end
	for _, entry in ipairs(config.drops or {}) do
		-- `chance` is optional: without one a drop is certain, which is what every material drop is. With
		-- one it is rolled per kill, which is what makes a weapon worth hunting for rather than a reward
		-- for showing up.
		if not entry.chance or math.random() < entry.chance then
			-- `oneOf` picks a single item from a list, so a rare roll gives ONE weapon rather than all of
			-- them at once. `item` names a specific thing; the two are alternatives.
			local id = entry.item
			if entry.oneOf and #entry.oneOf > 0 then
				id = entry.oneOf[math.random(1, #entry.oneOf)]
			end
			local count = math.random(entry.min or 1, entry.max or 1)
			if Inventory.AddItem(killer, id, count) then
				local item = ItemCatalog.Get(id)
				local name = item and item.name or id
				-- A rare drop says so. ToastController only distinguishes "error" from everything else, so
				-- the difference has to live in the words rather than in the colour.
				Remotes.SocialNotify:FireClient(killer, "info", entry.chance
					and ("หายาก! ได้ %s x%d"):format(name, count)
					or ("ได้ %s x%d"):format(name, count))
			else
				Remotes.SocialNotify:FireClient(killer, "error", "กระเป๋าเต็ม ของหล่นหาย")
			end
		end
	end
	if config.xp and config.xp > 0 then
		Progression.AwardExp(killer, config.xp)
	end
end

local function despawn(model)
	local state = Live[model]
	Live[model] = nil
	if state and state.spawner then
		local alive = state.spawner:GetAttribute("Alive") or 0
		state.spawner:SetAttribute("Alive", math.max(0, alive - 1))
		-- The respawn clock starts HERE, at the death, rather than at the next spawn: "back in thirty
		-- minutes" has to mean thirty minutes after it died, which is the only moment a player can see.
		local seconds = state.config and state.config.respawnSeconds or 0
		if seconds > 0 then
			state.spawner:SetAttribute("ReadyAt", os.clock() + seconds)
		end
	end
	if model.Parent then model:Destroy() end
end

-- Played at the monster, so a fight sounds like it is happening where it is rather than in the attacker's
-- ear. One helper for both the hit and the death, since they differ only in which id and how loud.
local function playAt(model, soundId, volume)
	local root = model.PrimaryPart
	if not root or not soundId then return end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.RollOffMaxDistance = GatherConfig.MobSoundDistance
	sound.PlaybackSpeed = 1 + (math.random() - 0.5) * 0.1
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, 4)
end

-- Public through MobAccess so PlayerCombat can call it without requiring this file.
local function damage(model, amount, attacker)
	local state = Live[model]
	if not state then return false end

	state.hp -= amount
	playAt(model, state.config.hitSound, GatherConfig.MobHitVolume)
	setHealthBar(model, state.hp / state.config.hp)
	-- Being hit makes it care about whoever hit it, even from outside its notice range: a monster that
	-- ignored an archer shooting it from a hill would look broken.
	if attacker and attacker.Character then
		state.target = attacker
	end

	if state.hp <= 0 then
		-- The death sound has to outlive the model, so it plays from a bare part left behind rather than
		-- from the monster that is about to be destroyed underneath it.
		local root = model.PrimaryPart
		if root and state.config.dieSound then
			local marker = Instance.new("Part")
			marker.Anchored = true
			marker.CanCollide = false
			marker.CanQuery = false
			marker.Transparency = 1
			marker.Size = Vector3.new(1, 1, 1)
			marker.Position = root.Position
			marker.Parent = workspace
			local sound = Instance.new("Sound")
			sound.SoundId = state.config.dieSound
			sound.Volume = GatherConfig.MobDieVolume
			sound.RollOffMaxDistance = GatherConfig.MobSoundDistance
			sound.Parent = marker
			sound:Play()
			Debris:AddItem(marker, 5)
		end
		drop(model, state.config, attacker)
		despawn(model)
	end
	return true
end

MobAccess.Damage = damage

--------------------------------------------------------------------------------
-- Spawning
--------------------------------------------------------------------------------

local function groundAt(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -1200, 0), params)
	return hit and hit.Position.Y or nil
end

local function spawnOne(spawner, kind, config)
	local radius = spawner:GetAttribute("Radius") or 60
	local origin = spawner:IsA("BasePart") and spawner.Position or spawner:GetPivot().Position

	-- A few attempts at a spot with ground under it, then give up for this tick rather than dropping a
	-- monster into the sea or inside a rock.
	for _ = 1, 8 do
		local angle = math.random() * math.pi * 2
		local distance = math.sqrt(math.random()) * radius -- sqrt keeps them evenly spread, not clumped at the middle
		local x = origin.X + math.cos(angle) * distance
		local z = origin.Z + math.sin(angle) * distance
		local y = groundAt(x, z)
		if y then
			local model = buildMonster(config)
			model:PivotTo(CFrame.new(x, y + 2, z))
			model.Parent = folder
			Live[model] = {
				config = config,
				hp = config.hp,
				spawner = spawner,
				home = Vector3.new(x, y, z),
				nextAttackAt = 0,
				target = nil,
			}
			spawner:SetAttribute("Alive", (spawner:GetAttribute("Alive") or 0) + 1)
			return true
		end
	end
	return false
end

local function serviceSpawner(spawner)
	local kind = spawner:GetAttribute("MobKind")
	local config = kind and GatherConfig.Mobs[kind]
	if not config then
		warn(("[Mobs] %s is tagged %s but MobKind (%s) is unknown")
			:format(spawner:GetFullName(), SPAWNER_TAG, tostring(kind)))
		return
	end

	-- A spawner that belongs to an event stands empty between events. Before V1 the three named slimes were
	-- permanently in the world and came back half an hour after dying, which made them a PLACE you visited;
	-- as an event they are a THING THAT HAPPENS, and the difference is entirely this check.
	local eventId = spawner:GetAttribute("EventOnly")
	if eventId and not EventState.IsActive(eventId) then return end

	local wanted = spawner:GetAttribute("Count") or 5
	local alive = spawner:GetAttribute("Alive") or 0
	if alive >= wanted then return end

	-- respawnSeconds was declared in the config from the start and never actually read, so every monster
	-- came back on the next two-second service tick no matter what its config said. That is survivable for
	-- a green slime worth one lump of goo; for a named slime with a weapon in its drop table it would mean
	-- standing in one spot and emptying the table.
	--
	-- The clock lives on the SPAWNER as an attribute rather than in a local, so it survives this file being
	-- reloaded and can be read from outside when something wants to show a timer.
	local readyAt = spawner:GetAttribute("ReadyAt")
	if readyAt and os.clock() < readyAt then return end

	spawnOne(spawner, kind, config)
end

--------------------------------------------------------------------------------
-- The AI, one loop for every monster
--------------------------------------------------------------------------------

local function nearestPlayer(position, within)
	local best, bestDistance
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		-- The dead and the downed are not targets: a monster chewing on someone who is already crawling
		-- makes them impossible to rescue.
		if root and humanoid and humanoid.Health > 0 and not player:GetAttribute("WOLD_Downed") then
			local d = (root.Position - position).Magnitude
			if d <= within and (not bestDistance or d < bestDistance) then
				best, bestDistance = player, d
			end
		end
	end
	return best, bestDistance
end

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	-- Four times a second is plenty for a walking blob, and keeps a field of fifty slimes off the frame
	-- budget. MoveTo keeps steering between ticks on its own.
	if accumulator < 0.25 then return end
	accumulator = 0

	for model, state in pairs(Live) do
		local root = model.PrimaryPart
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or not model.Parent then
			Live[model] = nil
		else
			local position = root.Position
			local config = state.config

			-- Too far from home: stop chasing and walk back, so a chase cannot drag monsters into town.
			if (position - state.home).Magnitude > config.leashRange then
				state.target = nil
				humanoid:MoveTo(state.home)
			else
				local target = state.target
				local targetRoot = target and target.Character
					and target.Character:FindFirstChild("HumanoidRootPart")

				-- Lost them (left, died, went down, or outran the leash): look for someone else.
				if not targetRoot or (targetRoot.Position - position).Magnitude > config.leashRange then
					state.target = nearestPlayer(position, config.aggroRange)
					targetRoot = state.target and state.target.Character
						and state.target.Character:FindFirstChild("HumanoidRootPart")
				end

				if targetRoot then
					local distance = (targetRoot.Position - position).Magnitude
					if distance <= config.attackRange then
						local now = os.clock()
						if now >= state.nextAttackAt then
							state.nextAttackAt = now + config.attackCooldown
							-- Through Vitals, the one door every kind of damage goes through: armor,
							-- invulnerability and the downed state are all decided there.
							Vitals.ApplyDamage(state.target, config.damage, "combat")
							-- And it should be HEARD. A monster landing a blow used to be silent, which made
							-- being chewed on across a field something you noticed only by watching the health
							-- bar. The sound is the game's existing generic impact -- the same thud a punch
							-- makes -- played at the person being hit rather than at the monster, because it
							-- is their body making the noise.
							local victim = state.target.Character
							if victim then
								playAt(victim, VitalsConfig.HitSoundId, VitalsConfig.HitSoundVolume)
							end
						end
					else
						humanoid:MoveTo(targetRoot.Position)
						-- The wet slap of something large moving. Only a mob that declares a hop sound makes
						-- one, and only while it is actually going somewhere: a slime sitting in a field
						-- should be silent.
						if config.hopSound then
							local hopNow = os.clock()
							if hopNow >= (state.nextHopAt or 0) then
								state.nextHopAt = hopNow + (config.hopInterval or 1)
								playAt(model, config.hopSound, config.hopVolume or 0.3)
							end
						end
					end
				else
					-- Nobody about: drift slowly around home so the field is not a still life.
					if math.random() < 0.06 then
						local angle = math.random() * math.pi * 2
						humanoid:MoveTo(state.home + Vector3.new(
							math.cos(angle) * 12, 0, math.sin(angle) * 12))
					end
				end
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Keeping the spawners stocked
--------------------------------------------------------------------------------

task.spawn(function()
	while true do
		for _, spawner in ipairs(CollectionService:GetTagged(SPAWNER_TAG)) do
			serviceSpawner(spawner)
		end
		-- One monster per spawner per tick, which fills an empty field over a few seconds rather than
		-- materialising a crowd all at once.
		task.wait(2)
	end
end)

CollectionService:GetInstanceRemovedSignal(SPAWNER_TAG):Connect(function(spawner)
	for model, state in pairs(Live) do
		if state.spawner == spawner then despawn(model) end
	end
end)

--------------------------------------------------------------------------------
-- The mutant slime event
--------------------------------------------------------------------------------

-- Which spawners belong to an event, and what to do to them when it starts and stops. The event system knows
-- nothing about monsters; it calls these and this file does the rest.
local function eventSpawners(id)
	local out = {}
	for _, spawner in ipairs(CollectionService:GetTagged(SPAWNER_TAG)) do
		if spawner:GetAttribute("EventOnly") == id then table.insert(out, spawner) end
	end
	return out
end

EventState.Register("slime", {
	start = function()
		for _, spawner in ipairs(eventSpawners("slime")) do
			-- The respawn clock is cleared rather than waited out. It was set by whatever killed the last one,
			-- possibly during the previous event, and an announcement that produced nothing for twenty-nine
			-- minutes would be a lie.
			spawner:SetAttribute("ReadyAt", nil)
			spawner:SetAttribute("Alive", 0)
		end
		-- Nothing else to do: the stocking loop runs every two seconds and its EventOnly check now passes, so
		-- the three of them walk into the world on the next tick.
	end,

	stop = function()
		-- Gone when the half hour is up, killed or not. A mutant left standing after the event would be a
		-- free weapon roll for whoever wandered past afterwards.
		for _, spawner in ipairs(eventSpawners("slime")) do
			for model, state in pairs(Live) do
				if state.spawner == spawner then despawn(model) end
			end
			spawner:SetAttribute("ReadyAt", nil)
			spawner:SetAttribute("Alive", 0)
		end
	end,
})
