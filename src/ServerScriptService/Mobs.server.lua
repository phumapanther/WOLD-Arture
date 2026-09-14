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
-- Every folder a monster prototype might live in, searched in order. V2 arrived as a second folder rather
-- than more models in the first, so the lookup takes a list: a third batch is one more string here.
local PROTOTYPE_FOLDERS = { "Model_moster", "Model_mosterV2" }

local function prototypeFor(config)
    if not config.model then return nil end

    -- ServerStorage FIRST. V1 moved the prototype folder out of the world: those display models carried the
    -- kit's own [E] prompts and name tags, so a player walking up to the spot where a rare slime spawns found
    -- a second, fake slime standing there offering a button that did nothing. They are still needed -- every
    -- monster is a clone of one -- so they moved rather than being deleted, and this looks in the new home
    -- first and the old one after, which means a place that has not run the phase yet still works.
    local serverStorage = game:GetService("ServerStorage")
    local root = workspace:FindFirstChild("WOLD")
    local found
    for _, folderName in ipairs(PROTOTYPE_FOLDERS) do
        local stored = serverStorage:FindFirstChild(folderName)
        found = stored and stored:FindFirstChild(config.model)
        if found then return found end
    end

    for _, folderName in ipairs(PROTOTYPE_FOLDERS) do
        local folderInstance = root and root:FindFirstChild(folderName, true)
        found = folderInstance and folderInstance:FindFirstChild(config.model)
        if found then break end
    end
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

    -- ...and a 1x1 cube is still wrong even once it collides, in two ways that look like different bugs.
    --
    -- A Humanoid holds its HumanoidRootPart HipHeight studs off the floor and balances the whole assembly on
    -- that one colliding part. The kit's handle sits half a stud from the BOTTOM of the model, so with a
    -- default HipHeight the body hangs in the air (measured: root 0.50 above the model's underside, on a
    -- body 4.7-6.2 tall), and a 5-stud slime balanced on a 1-stud peg tips and re-corrects every frame --
    -- which reads as constant shaking.
    --
    -- So the root is grown to the body's own footprint and told exactly how high to stand. The spider's
    -- model already ships a real 3.5x2.2x4.0 root and its own HipHeight, and is left alone.
    -- Only a MARKER gets replaced. A model that ships a real root -- the spider's is 3.5x2.2x4.0 with its
    -- own HipHeight -- is left exactly as its author built it. Measured against a fixed size rather than a
    -- fraction of the body, because the spider's own root is small next to its 19-stud leg span and a
    -- proportional test throws it away too.
    local modelCF, modelSize = model:GetBoundingBox()
    local isMarker = rootPart.Size.X <= 1.5 and rootPart.Size.Y <= 1.5 and rootPart.Size.Z <= 1.5
    if isMarker then
        -- Footprint of the body, and short: a tall root would make the monster stand on its own chin.
        rootPart.Size = Vector3.new(modelSize.X * 0.8, math.max(1, modelSize.Y * 0.5), modelSize.Z * 0.8)
        -- Re-centre it in the body. Welds are made below, after this, so nothing is dragged out of place.
        rootPart.CFrame = CFrame.new(modelCF.Position)
        -- The Humanoid holds the root's CENTRE this far off the floor. The body is centred on the root, so
        -- to rest the body's underside on the ground the centre has to sit half the BODY's height up --
        -- half the ROOT's height leaves it buried (measured: the body's underside ended up 1.2-1.6 studs
        -- below the floor). A little extra keeps it from scraping on uneven terrain.
        rootPart:SetAttribute("WOLD_HipHeight", modelSize.Y * 0.5 + 0.2)
    end

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
    -- Stand it at the height the root above was sized for. A model that shipped its own root keeps whatever
    -- HipHeight it came with.
    local wanted = rootPart:GetAttribute("WOLD_HipHeight")
    if wanted then
        humanoid.HipHeight = wanted
        -- Legless bodies do not walk on legs. Without this the Humanoid tries to step the assembly up and
        -- down and the slime bobs as it moves.
        humanoid.UseJumpPower = true
        humanoid.JumpPower = 0
    end

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
	setHealthBar(model, state.hp / (state.maxHp or state.config.hp))
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

-- Held still by the greatsword. Stored as a deadline rather than a timer so overlapping hits simply extend
-- it, and so the AI loop -- which already runs four times a second -- is the only thing that has to know
-- about it. A stunned monster stops where it is: it does not walk, chase or swing.
local function stun(model, seconds)
	local state = Live[model]
	if not state or not seconds or seconds <= 0 then return false end
	local until_ = os.clock() + seconds
	if not state.stunnedUntil or until_ > state.stunnedUntil then
		state.stunnedUntil = until_
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	-- Stop the walk it is already in the middle of; MoveTo keeps steering on its own otherwise.
	if humanoid and root then humanoid:MoveTo(root.Position) end
	return true
end

MobAccess.Stun = stun

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

-- After dark everything in the world hits twice as hard and takes twice as much killing.
--
-- Stamped onto each monster when it SPAWNS rather than read live, for two reasons: a monster must not
-- double its health bar halfway through a fight because the sun went down, and `config` is the shared table
-- every monster of that kind points at -- scaling it in place would buff the species, permanently, every
-- time night fell.
local NIGHT_MULTIPLIER = 2

local function nightScale()
	return workspace:GetAttribute("WOLD_IsNight") and NIGHT_MULTIPLIER or 1
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
			local scale = nightScale()
			local maxHp = config.hp * scale
			-- buildMonster already sized the Humanoid from the unscaled config; correct it here so the bar
			-- and the real pool agree.
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and scale ~= 1 then
				humanoid.MaxHealth = maxHp
				humanoid.Health = maxHp
			end
			Live[model] = {
				config = config,
				hp = maxHp,
				maxHp = maxHp,
				damageScale = scale,
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

-- Conjures one monster that exists only to chase `victim`, with no spawner behind it.
--
-- Deliberately NOT spawnOne: that function belongs to a spawner -- it counts against its Alive attribute and
-- sets its respawn clock -- and a monster called up by an admin has neither. When this one dies it is simply
-- gone, which is what despawn already does for a state with no spawner.
local function spawnHunter(kind, config, victim, origin, distance, boss)
	-- Ringed around them rather than dropped on top: a monster spawned inside someone's body shoves them.
	for attempt = 1, 12 do
		local angle = math.random() * math.pi * 2
		-- Widen the ring a little on each retry, so a wall on one side does not mean no monster at all.
		local reach = distance + (attempt - 1) * 4
			local x = origin.X + math.cos(angle) * reach
			local z = origin.Z + math.sin(angle) * reach
		local y = groundAt(x, z)
		if y then
			local model = buildMonster(config)
			-- A boss is the same monster, made bigger and meaner. ScaleTo BEFORE the pivot, and lift it by
			-- the scale as well: a model scaled about its own pivot grows downward too, so a tripled
			-- monster placed at the usual two studs starts with its knees in the ground.
			local size = boss and boss.scale or 1
			if size ~= 1 then model:ScaleTo(size) end
			model:PivotTo(CFrame.new(x, y + 2 * size, z))
			model.Parent = folder

			local scale = nightScale() * (boss and boss.power or 1)
			local maxHp = config.hp * scale
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and scale ~= 1 then
				humanoid.MaxHealth = maxHp
				humanoid.Health = maxHp
			end
			if boss and boss.title and humanoid then
				humanoid.DisplayName = boss.title
				model.Name = boss.modelName or model.Name
			end

			Live[model] = {
				config = config,
				hp = maxHp,
				maxHp = maxHp,
				damageScale = scale,
				-- No spawner: nothing counts it, and nothing brings it back.
				spawner = nil,
				home = Vector3.new(x, y, z),
				nextAttackAt = 0,
				target = victim,
				-- The whole point of it.
				hunt = victim,
			}
			return model
		end
	end
	return nil
end

-- Published for the admin command. Takes (victim, distance, count) and returns how many actually landed,
-- picking a random kind from EVERY monster in the game -- both batches, since GatherConfig.Mobs holds them
-- all in one table.
MobAccess.SpawnHunters = function(victim, distance, count)
	local character = victim and victim.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return 0, {} end

	local kinds = {}
	for kind in pairs(GatherConfig.Mobs) do kinds[#kinds + 1] = kind end
	-- Sorted before picking so the choice is reproducible from the seed rather than from hash order.
	table.sort(kinds)
	if #kinds == 0 then return 0, {} end

	local spawned, names = 0, {}
	for _ = 1, math.max(1, count or 1) do
		local kind = kinds[math.random(#kinds)]
		local config = GatherConfig.Mobs[kind]
		if config and spawnHunter(kind, config, victim, root.Position, distance or 15) then
			spawned += 1
			names[#names + 1] = config.name or kind
		end
	end
	return spawned, names
end

-- One hunter, but a named boss: bigger, tougher, and carrying somebody's name over its head.
--
-- Published for the TikTok link, where a subscriber buys one. Kept here rather than done to the model from
-- outside because everything that makes a monster dangerous lives in Live[model] -- hp, maxHp and the
-- damage multiplier -- and that table is private to this file. Reaching in from another script to triple a
-- health bar would leave the damage alone and make the boss a punching bag.
--
-- opts: { scale, power, title, kind }. Returns the model and the kind's display name, or nil.
MobAccess.SpawnBoss = function(victim, distance, opts)
	opts = opts or {}
	local character = victim and victim.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local kinds = {}
	for kind in pairs(GatherConfig.Mobs) do kinds[#kinds + 1] = kind end
	table.sort(kinds)
	if #kinds == 0 then return nil end

	local kind = opts.kind or kinds[math.random(#kinds)]
	local config = GatherConfig.Mobs[kind]
	if not config then return nil end

	local model = spawnHunter(kind, config, victim, root.Position, distance or 20, {
		scale = math.clamp(tonumber(opts.scale) or 1, 1, 6),
		power = math.clamp(tonumber(opts.power) or 1, 1, 20),
		title = opts.title,
		modelName = opts.modelName,
	})
	if not model then return nil end
	return model, config.name or kind
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

			-- Stunned: nothing else this tick. Checked before the leash and the chase so a monster caught
			-- mid-walk stands still rather than finishing its step.
			if state.stunnedUntil and os.clock() < state.stunnedUntil then
				humanoid:MoveTo(position)
				continue
			end

			-- A HUNTED monster has no home and no leash: it was conjured to chase one person and it does not stop.
			-- Checked before the leash so it never walks back, and before the retarget so it never picks
			-- someone closer -- "ตามไม่เลิก" means this one player and no other.
			local hunted = state.hunt
			local huntRoot = hunted and hunted.Character
				and hunted.Character:FindFirstChild("HumanoidRootPart")

			-- Once they are down, stop. Vitals already refuses the damage, but a monster standing over a
			-- crawling player still blocks the rescue -- which is exactly why nearestPlayer skips the downed,
			-- and a hunter must not be the exception that undoes it. It waits where it is and resumes when
			-- they are back up.
			if hunted and huntRoot and hunted:GetAttribute("WOLD_Downed") then
				humanoid:MoveTo(position)
				continue
			end

			if hunted and not huntRoot then
				-- Their character is gone for the moment (dead, respawning, streamed out). Stand still and
				-- wait rather than falling back to ordinary behaviour, which would re-home a monster that
				-- has no home.
				humanoid:MoveTo(position)
				continue
			end

			-- Too far from home: stop chasing and walk back, so a chase cannot drag monsters into town.
			if not hunted and (position - state.home).Magnitude > config.leashRange then
				state.target = nil
				humanoid:MoveTo(state.home)
			else
				local target = state.target
				local targetRoot = target and target.Character
					and target.Character:FindFirstChild("HumanoidRootPart")

				if hunted then
					-- One target, forever. No aggro range to enter and no leash to escape.
					state.target, targetRoot = hunted, huntRoot
				elseif not targetRoot or (targetRoot.Position - position).Magnitude > config.leashRange then
					-- Lost them (left, died, went down, or outran the leash): look for someone else.
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
							local hurt = Vitals.ApplyDamage(state.target, config.damage * (state.damageScale or 1), "combat")
							-- And it should be HEARD -- but only by the person it happened to, and only when it
							-- cost them something. Built here on the server, the Sound went into the world and
							-- replicated, so everyone within sixty studs heard every bite taken out of everyone
							-- else and a field with a few slimes in it sounded like a battlefield. Now the one
							-- player it happened to is told, and their own client makes the noise
							-- (HurtSoundController), where it goes no further.
							--
							-- ApplyDamage answering false is what silences a monster standing over somebody who
							-- is already crawling: it keeps biting a body with no blood left, and that should be
							-- as quiet as it is harmless.
							--
							-- Player-on-player blows are deliberately NOT routed this way: PlayerCombat still
							-- plays those into the world, because a fight is worth overhearing.
							if hurt then Remotes.HurtSound:FireClient(state.target) end
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
