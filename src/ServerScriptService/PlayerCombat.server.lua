-- PlayerCombat.server.lua: server-authoritative attack state machine. The client only reports "I clicked"
-- (RequestAttack); the server decides whether that's legal, what it hits, and what everyone should see.
-- See docs/superpowers/specs/2026-09-07-movement-stamina-design.md for the movement rules this cooperates with.
--
-- Two states per player:
--   idle     — nothing; the first click only raises the guard, it does not punch
--   guarding — the held stance; each click throws the next attack in the weapon's chain. Drops back to idle
--              after the weapon's idleTimeout with no clicks.
--
-- Attack timing is windup -> active (hitbox live) -> recovery. A click during windup/active is ignored;
-- a click during recovery is allowed so chains feel responsive.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)
local VitalsConfig = require(game.ReplicatedStorage.VitalsConfig)
local ProgressionConfig = require(game.ReplicatedStorage.ProgressionConfig)
local Progression = require(game.ServerScriptService.Progression)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
local Consuming = require(game.ServerScriptService.Consuming)
local StatusEffects = require(game.ServerScriptService.StatusEffects)
local Remotes = require(game.ReplicatedStorage.Remotes)

local States = {} -- [player] = { weapon, guarding, lastAttackAt, chainIndex, busyUntil, activeUntil, hitThisSwing }

local function humanoidOf(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- The weapon in hand comes from the inventory, so equipping a sword changes damage, reach, timing and the
-- animations without combat holding any state of its own. Bare hands are the fallback.
local function weaponOf(player)
	local item, entry = Inventory.EquippedWeapon(player)
	if item and entry and CombatConfig.Weapons[entry.id] then
		return CombatConfig.Weapons[entry.id], entry
	end
	return CombatConfig.Weapons[CombatConfig.DefaultWeapon], nil
end

-- Some attacks carry a rider beyond damage: an arrow floors whoever it hits, dark magic slows them. The
-- rider lives on the attack in CombatConfig so every hit path resolves it the same way. A hit that puts
-- someone down skips it -- they are already on the floor, and a knockdown would fight the crawl for the body.
local function applyEffect(attack, victim)
	if not attack.effect or Vitals.IsDowned(victim) then return end
	if attack.effect == "knockdown" then
		StatusEffects.Knockdown(victim, attack.effectSeconds)
	elseif attack.effect == "slow" then
		StatusEffects.Slow(victim, attack.effectSeconds, attack.effectFactor)
	end
end

-- Every swing wears the weapon down; at zero it breaks and is gone.
local function wearWeapon(player)
	local item, entry = Inventory.EquippedWeapon(player)
	if not item or not entry or not entry.durability then return end
	entry.durability -= CombatConfig.DurabilityPerSwing
	if entry.durability <= 0 then
		-- Through Inventory rather than clearing the slot here: doing it by hand skipped OnWeaponChanged, so
		-- the broken weapon's model stayed in the player's hand while the animations fell back to fists.
		Inventory.BreakEquipped(player, "weapon")
	end
	Inventory.Send(player)
end

local function setGuard(player, state, guarding)
	if state.guarding == guarding then return end
	state.guarding = guarding
	local humanoid = humanoidOf(player)
	if humanoid then
		-- PlayerMovement owns WalkSpeed normally; while guarding we clamp it and it restores on guard drop.
		humanoid.WalkSpeed = guarding and weaponOf(player).guardWalkSpeed or 8
	end
	Remotes.CombatStateChanged:FireAllClients(player, guarding and "guard_start" or "guard_end")
end

-- The blow that downs someone is the kill, and it pays by how far above the killer the victim was: a big
-- upset is worth several ordinary kills, while farming someone far below is worth a fraction. Only the
-- finishing hit calls this, so the reward goes to whoever actually took them down.
local function awardKill(killer, victim)
	local multiplier = ProgressionConfig.KillMultiplier(
		Progression.GetLevel(killer), Progression.GetLevel(victim))
	Progression.AwardExp(killer, math.floor(ProgressionConfig.ExpPerPlayerKill * multiplier + 0.5))
end

-- Impact feedback: a short sound parented to the victim so everyone nearby hears it positionally. Works for
-- training dummies too: their body part is deliberately named HumanoidRootPart.
-- Plays a one-shot sound at a character and cleans it up afterwards. Every combat sound goes through here
-- so volume, falloff and cleanup are decided once.
local function playAt(character, soundId, distance, volume, maxSeconds)
	if not character or soundId == "" then return end -- unconfigured sounds are simply silent
	local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not hrp then return end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or CombatConfig.AttackSoundVolume
	sound.RollOffMaxDistance = distance or CombatConfig.HitSoundDistance
	sound.Parent = hrp
	sound:Play()
	-- Blows land faster than the clips are long, so cut them short rather than letting consecutive hits
	-- stack into a drone.
	game:GetService("Debris"):AddItem(sound, maxSeconds or VitalsConfig.HitSoundMaxSeconds)
end

-- The sound pair for whatever the player is wielding. Falls back to the punch sound for the impact so an
-- unconfigured weapon still thumps rather than landing in silence.
local function soundsFor(player)
	local _, entry = Inventory.EquippedWeapon(player)
	-- Bare hands have no inventory entry, so they fall back to the default weapon key the same way weaponOf
	-- resolves them. Without this the Fists sound entry could never be reached and punches took the generic
	-- fallback volume instead of their own.
	local set = CombatConfig.Sounds[entry and entry.id or CombatConfig.DefaultWeapon]
	local hit = (set and set.hit ~= "" and set.hit) or VitalsConfig.HitSoundId
	-- A weapon may override how loud and how long its impact is; the sword is much louder and longer than
	-- the rest, so it says so here rather than every weapon being tuned to the noisiest one.
	return (set and set.cast) or "", hit,
		set and set.hitVolume or nil,
		set and set.hitSeconds or nil
end

local function playHitSound(character, attacker)
	local hit, volume, seconds = VitalsConfig.HitSoundId, nil, nil
	if attacker then
		local _, weaponHit, weaponVolume, weaponSeconds = soundsFor(attacker)
		hit, volume, seconds = weaponHit, weaponVolume, weaponSeconds
	end
	playAt(character, hit, CombatConfig.HitSoundDistance,
		volume or VitalsConfig.HitSoundVolume,
		seconds or CombatConfig.HitSoundMaxSeconds)
end

-- Published for WeaponSkills: a skill landing should sound like the weapon that cast it, and the rules for
-- which sound that is -- and how loud, and how long -- already live here. Sharing the function keeps the
-- two paths from drifting apart the way two copies would. Assigned AFTER the definition: a local is nil
-- until its statement runs, so publishing it earlier would have shared nothing.
CombatConfig.PlayWeaponHitSound = playHitSound

-- The attacker's own sound: the swing, the bowstring, the spell leaving the book.
local function playCastSound(player)
	local cast = select(1, soundsFor(player))
	playAt(player.Character, cast, CombatConfig.CastSoundDistance, nil,
		CombatConfig.CastSoundMaxSeconds)
end

-- Ranged attacks: the bow's arrow and the spellbook's orb travel and hit the first thing they reach; the
-- staff's beam appears at full length at once. All three are stepped by hand rather than thrown with physics,
-- so nothing can shove them off course and a laggy client cannot outrun them.
local function fireProjectile(player, attack)
	local spec = attack.projectile
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not spec or not hrp then return end

	local forward = hrp.CFrame.LookVector
	local origin = hrp.Position + forward * 2.5 + Vector3.new(0, 1.2, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local part = Instance.new("Part")
	part.Name = "WOLD_Projectile"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Size = spec.size
	part.Color = spec.color
	part.Material = spec.material
	part.Parent = workspace
	Debris:AddItem(part, spec.life)

	if spec.kind == "orb" then
		part.Shape = Enum.PartType.Ball
		local light = Instance.new("PointLight")
		light.Color = spec.color
		light.Range = 12
		light.Brightness = 2
		light.Parent = part
	end

	local function damageAt(position)
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				local otherChar = other.Character
				local otherHrp = otherChar and otherChar:FindFirstChild("HumanoidRootPart")
				if otherHrp and (otherHrp.Position - position).Magnitude <= 6
					and not Vitals.IsInvulnerable(other) then
					local wasDowned = Vitals.IsDowned(other)
					Vitals.ApplyDamage(other, attack.damage, "combat")
					applyEffect(attack, other)
					playHitSound(otherChar, player)
					if not wasDowned and Vitals.IsDowned(other) then
						awardKill(player, other)
					end
				end
			end
		end
		for _, dummy in ipairs(CollectionService:GetTagged("WOLD_Dummy")) do
			local root = dummy.PrimaryPart
			if root and (root.Position - position).Magnitude <= 6 then
				Progression.AwardExp(player, ProgressionConfig.ExpPerDummyHit)
				playHitSound(dummy, player)
			end
		end
	end

	if spec.kind == "beam" then
		-- Instant: stretch the part from the caster to whatever it first hits.
		local result = workspace:Raycast(origin, forward * spec.length, params)
		local endPoint = result and result.Position or (origin + forward * spec.length)
		local distance = (endPoint - origin).Magnitude
		part.Size = Vector3.new(spec.size.X, spec.size.Y, distance)
		part.CFrame = CFrame.lookAt(origin + (endPoint - origin) / 2, endPoint)
		damageAt(endPoint)
		-- Damage everything along the beam, not only at its end.
		for step = 8, distance, 8 do
			damageAt(origin + forward * step)
		end
		return
	end

	-- Travelling shot.
	part.CFrame = CFrame.lookAt(origin, origin + forward)
	task.spawn(function()
		local travelled = 0
		local maxDistance = spec.speed * spec.life
		while part.Parent and travelled < maxDistance do
			local dt = task.wait()
			local step = forward * (spec.speed * dt)
			local result = workspace:Raycast(part.Position, step, params)
			if result then
				damageAt(result.Position)
				part:Destroy()
				return
			end
			part.CFrame = part.CFrame + step
			travelled += step.Magnitude
		end
		if part.Parent then part:Destroy() end
	end)
end

local function resolveHit(player, state, attack)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local origin = hrp.Position + hrp.CFrame.LookVector * (attack.range * 0.5)
		+ Vector3.new(0, CombatConfig.HitboxHeightOffset, 0)

	-- Training dummies: static targets that pay a little EXP per punch. Checked before players because they
	-- are not Players at all, so the loop below would never see them.
	for _, dummy in ipairs(CollectionService:GetTagged("WOLD_Dummy")) do
		local root = dummy.PrimaryPart
		if root and not state.hitThisSwing[dummy] and (root.Position - origin).Magnitude <= attack.range then
			state.hitThisSwing[dummy] = true
			Progression.AwardExp(player, ProgressionConfig.ExpPerDummyHit)
			playHitSound(dummy, player)
		end
	end

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and not state.hitThisSwing[other] then
			local otherChar = other.Character
			local otherHrp = otherChar and otherChar:FindFirstChild("HumanoidRootPart")
			if otherHrp and (otherHrp.Position - origin).Magnitude <= attack.range then
				state.hitThisSwing[other] = true
				-- Vitals decides what the hit actually does: armor absorbs half, downed and freshly-respawned
				-- players take nothing, and HP reaching 0 downs them rather than killing.
				if not Vitals.IsInvulnerable(other) then
					local wasDowned = Vitals.IsDowned(other)
					Vitals.ApplyDamage(other, attack.damage, "combat")
					applyEffect(attack, other)
					playHitSound(otherChar, player)
					-- The blow that puts someone down is the "kill" for EXP purposes: combat downs players
					-- rather than killing them outright, so there is no later death to hook.
					if not wasDowned and Vitals.IsDowned(other) then
						awardKill(player, other)
					end
				end
			end
		end
	end
end

Remotes.RequestAttack.OnServerEvent:Connect(function(player)
	local state = States[player]
	local humanoid = humanoidOf(player)
	if not state or not humanoid or humanoid.Health <= 0 then return end
	if Vitals.IsDowned(player) then return end -- can't throw punches while crawling
	-- Hands are full: raising a potion to your mouth and swinging a sword are the same two hands. Movement
	-- is deliberately still allowed -- walking, running, rolling and sliding all stay available.
	if Consuming.IsConsuming(player) then return end

	local now = os.clock()
	if now < state.busyUntil then return end -- still mid-swing; ignore the click rather than queueing it

	-- First click only draws the guard — it does not throw a punch. Punches start from the second click,
	-- alternating sides, and each returns to guard. This is also what keeps the two animations from fighting:
	-- the guard is never playing underneath a swing.
	if not state.guarding then
		state.lastAttackAt = now
		state.chainIndex = 0
		setGuard(player, state, true)
		return
	end

	local weapon = weaponOf(player)

	-- Continue the chain only if this click is soon enough after the last one, otherwise restart at attack 1.
	if now - state.lastAttackAt > weapon.chainWindow then
		state.chainIndex = 0
	end
	state.chainIndex = (state.chainIndex % #weapon.attacks) + 1
	local attack = weapon.attacks[state.chainIndex]

	state.lastAttackAt = now
	state.busyUntil = now + attack.windup + attack.active + attack.recovery
	state.activeUntil = now + attack.windup + attack.active
	state.activeFrom = now + attack.windup
	state.hitThisSwing = {}
	-- The attacker's own sound fires on the windup, not on the hit: a swing that misses should still be
	-- heard, and a bowstring should sound as the arrow leaves rather than when it lands.
	playCastSound(player)
	-- A ranged attack fires a single shot after its windup; only melee keeps a live hitbox.
	if attack.projectile then
		state.pendingAttack = nil
		task.delay(attack.windup, function()
			if player.Parent then fireProjectile(player, attack) end
		end)
	else
		state.pendingAttack = attack
	end
	wearWeapon(player)

	Remotes.CombatStateChanged:FireAllClients(player, "attack", state.chainIndex)
end)

Players.PlayerAdded:Connect(function(player)
	States[player] = {
		weapon = CombatConfig.DefaultWeapon,
		guarding = false,
		lastAttackAt = 0,
		chainIndex = 0,
		busyUntil = 0,
		activeFrom = 0,
		activeUntil = 0,
		hitThisSwing = {},
	}
	player.CharacterAdded:Connect(function()
		local state = States[player]
		if state then
			state.guarding = false
			state.chainIndex = 0
			state.busyUntil = 0
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	States[player] = nil
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for player, state in pairs(States) do
		-- Hitbox is live only during the active window, checked every frame so a target walking into it still gets hit.
		if state.pendingAttack and now >= state.activeFrom and now <= state.activeUntil then
			resolveHit(player, state, state.pendingAttack)
		elseif state.pendingAttack and now > state.activeUntil then
			state.pendingAttack = nil
		end

		if state.guarding and now - state.lastAttackAt > weaponOf(player).idleTimeout and now >= state.busyUntil then
			setGuard(player, state, false)
		end
	end
end)
