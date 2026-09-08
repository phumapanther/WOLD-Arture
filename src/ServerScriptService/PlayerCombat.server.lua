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

-- Every swing wears the weapon down; at zero it breaks and is gone.
local function wearWeapon(player)
	local item, entry = Inventory.EquippedWeapon(player)
	if not item or not entry or not entry.durability then return end
	entry.durability -= CombatConfig.DurabilityPerSwing
	if entry.durability <= 0 then
		local state = Inventory.Get(player)
		if state then state.equipped.weapon = nil end
		Remotes.EquipmentChanged:FireAllClients(player, nil,
			state and state.equipped.armor and state.equipped.armor.id or nil)
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

-- Impact feedback: a short sound parented to the victim so everyone nearby hears it positionally. Works for
-- training dummies too: their body part is deliberately named HumanoidRootPart.
local function playHitSound(character)
	if VitalsConfig.HitSoundId == "" then return end -- no sound configured; combat is simply silent
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local sound = Instance.new("Sound")
	sound.SoundId = VitalsConfig.HitSoundId
	sound.Volume = VitalsConfig.HitSoundVolume
	sound.RollOffMaxDistance = 60
	sound.Parent = hrp
	sound:Play()
	-- Punches land about once a second but the clip is longer than that, so cut it short rather than letting
	-- consecutive hits stack into a drone.
	game:GetService("Debris"):AddItem(sound, VitalsConfig.HitSoundMaxSeconds)
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
					playHitSound(otherChar)
					if not wasDowned and Vitals.IsDowned(other) then
						Progression.AwardExp(player, ProgressionConfig.ExpPerPlayerKill)
					end
				end
			end
		end
		for _, dummy in ipairs(CollectionService:GetTagged("WOLD_Dummy")) do
			local root = dummy.PrimaryPart
			if root and (root.Position - position).Magnitude <= 6 then
				Progression.AwardExp(player, ProgressionConfig.ExpPerDummyHit)
				playHitSound(dummy)
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
			playHitSound(dummy)
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
					playHitSound(otherChar)
					-- The blow that puts someone down is the "kill" for EXP purposes: combat downs players
					-- rather than killing them outright, so there is no later death to hook.
					if not wasDowned and Vitals.IsDowned(other) then
						Progression.AwardExp(player, ProgressionConfig.ExpPerPlayerKill)
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
