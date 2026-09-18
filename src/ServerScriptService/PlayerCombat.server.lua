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
local MobAccess = require(game.ServerScriptService.MobAccess)
local FishingAccess = require(game.ServerScriptService.FishingAccess)
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local VitalsConfig = require(game.ReplicatedStorage.VitalsConfig)
local ProgressionConfig = require(game.ReplicatedStorage.ProgressionConfig)
local Progression = require(game.ServerScriptService.Progression)
local Inventory = require(game.ServerScriptService.Inventory)
local ClassPerks = require(game.ServerScriptService.ClassPerks)
-- Classes requires only ClassConfig and ProfileAccess, so there is no cycle back here -- and ClassPerks
-- above already pulls it in anyway.
local Classes = require(game.ServerScriptService.Classes)
local ClassConfig = require(game.ReplicatedStorage.ClassConfig)
local WeaponVisualsAccess = require(game.ServerScriptService.WeaponVisualsAccess)
local Vitals = require(game.ServerScriptService.Vitals)
local Consuming = require(game.ServerScriptService.Consuming)
local StatusEffects = require(game.ServerScriptService.StatusEffects)
local Remotes = require(game.ReplicatedStorage.Remotes)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)

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
-- One rider, applied by name. Split out from applyEffect so an attack can carry TWO of them -- the spellbook
-- both stuns and slows, and an if/elseif chain can only ever deliver the first.
local function applyOneEffect(name, victim, seconds, factor)
	if name == "knockdown" then
		StatusEffects.Knockdown(victim, seconds)
	elseif name == "slow" then
		StatusEffects.Slow(victim, seconds, factor)
	elseif name == "dizzy" then
		StatusEffects.Dizzy(victim, seconds)
	end
end

-- How long this attack stuns, whichever rider carries it. Monsters have no Humanoid state to knock down or
-- slow, so a stun is the only rider they can take -- and it has to be found in either slot, or the spellbook
-- would stun players and leave monsters untouched.
local function stunSeconds(attack)
	if attack.effect == "dizzy" then return attack.effectSeconds end
	if attack.effect2 == "dizzy" then return attack.effect2Seconds end
	return nil
end

local function applyEffect(attack, victim)
	if Vitals.IsDowned(victim) then return end
	if attack.effect then
		applyOneEffect(attack.effect, victim, attack.effectSeconds, attack.effectFactor)
	end
	-- A second, optional rider with its own timing. `effect2` rather than a list because exactly one attack
	-- needs two and a list would make every other weapon's config a table of one.
	if attack.effect2 then
		applyOneEffect(attack.effect2, victim, attack.effect2Seconds, attack.effect2Factor)
	end
end

-- Every swing wears the weapon down; at zero it breaks and is gone.
local function wearWeapon(player)
	-- The inventor's weapons do not wear. Returning before the subtraction rather than healing it afterwards
	-- means the durability the player sees never moves, instead of flickering down and back on every swing.
	if ClassPerks.Has(player, "weaponNeverBreaks") then return end
	Inventory.WearEquipped(player, CombatConfig.DurabilityPerSwing)
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
	-- หัวแดง 5 นาทีเมื่อฆ่าคน ตามที่ผู้ใช้สั่ง
	--
	-- อยู่ตรงนี้เพราะเป็นจุดเดียวที่ "ผู้เล่นทำให้ผู้เล่นอีกคนล้ม" ผ่าน ทั้งระยะประชิดและระยะไกลเรียกผ่าน
	-- ฟังก์ชันนี้ทั้งคู่ ไม่ต้องไปเติมสองที่
	Classes.Mark(killer, ClassConfig.MarkedSecondsKill)
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
-- Returns cast, hit, hitVolume, hitSeconds, castSeconds.
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
		set and set.hitSeconds or nil,
		-- How long the CAST sound is allowed to run. The pistol's clip is six seconds and a gunshot is a
		-- crack, so it says half a second here rather than every weapon being cut to the shortest one.
		set and set.castSeconds or nil
end

-- Tells the two people in a fight that a blow just landed, so their music can react. Only the pair: a
-- fight across the square is not everyone's fight, and music swelling for a scrap you cannot see would be
-- confusing rather than exciting.
local function reportHit(attacker, victim)
	-- Checked rather than assumed: FireClient throws on anything that is not a Player, and a hit can land on
	-- a training dummy, which is a plain Model.
	if attacker and attacker:IsA("Player") then Remotes.CombatHit:FireClient(attacker) end
	if victim and victim ~= attacker and victim:IsA("Player") then Remotes.CombatHit:FireClient(victim) end
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
	local cast, _, _, _, castSeconds = soundsFor(player)
	playAt(player.Character, cast, CombatConfig.CastSoundDistance, nil,
		castSeconds or CombatConfig.CastSoundMaxSeconds)
end

-- Ranged attacks: the bow's arrow and the spellbook's orb travel and hit the first thing they reach; the
-- staff's beam appears at full length at once. All three are stepped by hand rather than thrown with physics,
-- so nothing can shove them off course and a laggy client cannot outrun them.
-- How far a hit at `origin` is from actually touching `character`.
--
-- Measured to the nearest point of the target's BODY rather than to the centre of its root. Body scale
-- reaches 10x at level 100, which puts a big player's root thirty studs off the ground while a level-1
-- player's is at three -- so a root-to-root sphere of range 7 could not reach at all (measured: from level
-- 50 a sword literally could not hit a level-1 player from any position). Measuring to the body means a
-- swing connects with whatever part of them is actually in front of you, at any pair of sizes.
--
-- The root's own bounding box is used as the body: it is the one part every rig has, it scales with the
-- rig, and it spans the torso, which is what a swing is aimed at.
local function distanceToBody(origin, character)
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return math.huge end
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	-- The rig standing on the ground, from its feet to the top of its head, as a box around the root.
	local half = hrp.Size * 0.5
	-- Vertically the root covers only the torso, so the box is grown to the whole standing height: down to
	-- the feet (HipHeight below the root) and up over the head.
	local down = (humanoid and humanoid.HipHeight or 2) + half.Y
	local up = half.Y * 2.2 -- torso above the root plus the head, in the same proportion the rig has

	local delta = origin - hrp.Position
	local dx = math.max(0, math.abs(delta.X) - half.X)
	local dz = math.max(0, math.abs(delta.Z) - half.Z)
	local dy = 0
	if delta.Y > up then
		dy = delta.Y - up
	elseif delta.Y < -down then
		dy = -down - delta.Y
	end
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Where a shot is headed. `aim` is the world point under the client's crosshair; only that client knows
-- where its own camera looks, so it has to come from there.
--
-- It is checked, not trusted. A shot always leaves the shooter's own hands and the direction is only ever a
-- unit vector, so the worst a lie can do is aim somewhere strange -- it cannot reach further, fire faster,
-- or hit around a corner, because the projectile still travels and still has to arrive. Nonsense (nil, a
-- non-Vector3, an infinite value, or a point on top of the shooter) falls back to facing.
local function aimDirection(hrp, origin, aim)
	if typeof(aim) ~= "Vector3" then
		return hrp.CFrame.LookVector
	end
	-- NaN and infinity would poison every position computed from them.
	if aim.Magnitude ~= aim.Magnitude or aim.Magnitude == math.huge then
		return hrp.CFrame.LookVector
	end
	local delta = aim - origin
	if delta.Magnitude < 0.5 then
		return hrp.CFrame.LookVector
	end
	return delta.Unit
end

local function fireProjectile(player, attack, aim)
	local spec = attack.projectile
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not spec or not hrp then return end

	-- Leaves from chest height, which is where a bow is held, but offset along the AIM rather than the
	-- character's facing -- otherwise a shot aimed sharply up or down starts beside the shooter instead of
	-- in front of them.
	-- Chest height by default, which is where a bow is held. A weapon may raise it: the pistol sights just
	-- above the head, as the user asked, so the shot clears a crowd rather than hitting the first shoulder
	-- between shooter and target.
	local muzzle = hrp.Position + Vector3.new(0, spec.muzzleHeight or 1.2, 0)
	local forward = aimDirection(hrp, muzzle, aim)
	local origin = muzzle + forward * 2.5

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

	-- The rogue's doubling is applied ONCE here rather than at each of the places the number is used, so a
	-- player, a training dummy and a monster all take the same blow. Working it out per target would mean
	-- four copies of the same condition and a fifth the next time something becomes hittable.
	local dealt = ClassPerks.DamageFor(player, attack.damage)

	local function damageAt(position)
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				local otherChar = other.Character
				if otherChar and distanceToBody(position, otherChar) <= CombatConfig.ProjectileHitRadius
					and not Vitals.IsInvulnerable(other) then
					local wasDowned = Vitals.IsDowned(other)
					Vitals.ApplyDamage(other, dealt, "combat")
					reportHit(player, other)
					applyEffect(attack, other)
					playHitSound(otherChar, player)
					if not wasDowned and Vitals.IsDowned(other) then
						awardKill(player, other)
						-- 💤 เฉพาะคนที่ถูก "ยิง" ล้ม ตามที่ผู้ใช้สั่ง — บล็อกนี้เป็นทางของกระสุนกับลูกธนู
						-- เท่านั้น (ระยะประชิดอยู่คนละบล็อก) จึงไม่ต้องถามว่าอาวุธอะไร
						StatusEffects.SetAsleep(other, true)
					end
				end
			end
		end
		for _, dummy in ipairs(CollectionService:GetTagged("WOLD_Dummy")) do
			local root = dummy.PrimaryPart
			if root and distanceToBody(position, dummy) <= CombatConfig.ProjectileHitRadius then
				Progression.AwardExp(player, ProgressionConfig.ExpPerDummyHit)
				playHitSound(dummy, player)
			end
		end
		for _, mob in ipairs(CollectionService:GetTagged("WOLD_Mob")) do
			if distanceToBody(position, mob) <= CombatConfig.ProjectileHitRadius then
				if MobAccess.Damage and MobAccess.Damage(mob, dealt, player) then
					playHitSound(mob, player)
					local stun = stunSeconds(attack)
					if stun and MobAccess.Stun then
						MobAccess.Stun(mob, stun)
					end
				end
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
	-- Swung from the middle of the body, which is where a swing comes from.
	--
	-- It was dropped to the feet for a while, to let a ten-times-scaled player reach someone standing at
	-- their ankles. Growth is off now (ProgressionConfig.MaxScale = 1), everyone is the same height, and
	-- aiming at the floor made every swing look and feel low for no benefit. distanceToBody below still
	-- measures to the whole body rather than the root, so this stays correct if growth is ever turned back
	-- on at a sane number.
	local origin = hrp.Position + hrp.CFrame.LookVector * (attack.range * 0.5)
		+ Vector3.new(0, CombatConfig.HitboxHeightOffset, 0)

	-- Worked out once per swing, for the same reason as the projectile path above: a monster and a player
	-- struck by the same blow must take the same number.
	local dealt = ClassPerks.DamageFor(player, attack.damage)

	-- Training dummies: static targets that pay a little EXP per punch. Checked before players because they
	-- are not Players at all, so the loop below would never see them.
	for _, dummy in ipairs(CollectionService:GetTagged("WOLD_Dummy")) do
		local root = dummy.PrimaryPart
		if root and not state.hitThisSwing[dummy] and distanceToBody(origin, dummy) <= attack.range then
			state.hitThisSwing[dummy] = true
			Progression.AwardExp(player, ProgressionConfig.ExpPerDummyHit)
			playHitSound(dummy, player)
		end
	end

	-- Monsters. Checked alongside the dummies and for the same reason -- they are not Players, so the loop
	-- below never sees them -- but unlike a dummy they have hit points and die.
	for _, mob in ipairs(CollectionService:GetTagged("WOLD_Mob")) do
		if not state.hitThisSwing[mob] and distanceToBody(origin, mob) <= attack.range then
			state.hitThisSwing[mob] = true
			if MobAccess.Damage and MobAccess.Damage(mob, dealt, player) then
				playHitSound(mob, player)
				-- The greatsword's rider. A monster has no Humanoid state to knock down, so a stun is the
				-- monster-shaped version of the stars a player sees.
				local stun = stunSeconds(attack)
				if stun and MobAccess.Stun then
					MobAccess.Stun(mob, stun)
				end
			end
		end
	end

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and not state.hitThisSwing[other] then
			local otherChar = other.Character
			if otherChar and distanceToBody(origin, otherChar) <= attack.range then
				state.hitThisSwing[other] = true
				-- Vitals decides what the hit actually does: armor absorbs half, downed and freshly-respawned
				-- players take nothing, and HP reaching 0 downs them rather than killing.
				if not Vitals.IsInvulnerable(other) then
					local wasDowned = Vitals.IsDowned(other)
					Vitals.ApplyDamage(other, dealt, "combat")
					reportHit(player, other)
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

Remotes.RequestAttack.OnServerEvent:Connect(function(player, aim)
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

	-- A fishing rod casts rather than fights. The swing still plays -- the cast IS a swing, which is what
	-- the user asked for -- but the hitbox never opens, so a cast beside someone does not hit them.
	--
	-- Checked after the guard, so the first click still raises the rod into the two-handed hold and the
	-- second one casts. That falls out of the existing guard rule rather than needing its own.
	if FishingAccess.TryCast and FishingAccess.TryCast(player) then
		local rodWeapon = weaponOf(player)
		local rodAttack = rodWeapon.attacks[1]
		state.lastAttackAt = now
		state.chainIndex = 1
		state.busyUntil = now + rodAttack.windup + rodAttack.active + rodAttack.recovery
		-- activeUntil left in the past: the swing animates, the hitbox never opens.
		state.activeUntil = 0
		state.hitThisSwing = {}
		-- Same shape as the real attack broadcast below: the client looks the animation up from the
		-- chain index and the weapon it knows the player is holding.
		Remotes.CombatStateChanged:FireAllClients(player, "attack", state.chainIndex)
		return
	end

	local weapon = weaponOf(player)

	-- A weapon that eats ammunition spends one per shot, and refuses when the bag is empty. Checked before
	-- anything else is committed, so a dry click costs no cooldown and plays no animation.
	if weapon.ammo then
		local spent = false
		local invState = Inventory.Get(player)
		if invState then
			for index, slot in pairs(invState.slots) do
				if slot.id == weapon.ammo then
					Inventory.RemoveFromSlot(player, index, 1)
					spent = true
					break
				end
			end
		end
		if not spent then
			local ammoItem = ItemCatalog.Get(weapon.ammo)
			Remotes.SocialNotify:FireClient(player, "error",
				("ไม่มี%s"):format(ammoItem and ammoItem.name or weapon.ammo))
			return
		end
	end

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
	-- The greatsword buries itself in the ground at the end of its arc. That sound belongs to the swing, not
	-- to a victim, so it fires on a timer whether or not anything was standing there -- the earth is hit
	-- every time. Only weapons that declare a `slam` time have one.
	if attack.slam then
		task.delay(attack.slam, function()
			if not player.Parent then return end
			local _, hit, volume, seconds = soundsFor(player)
			playAt(player.Character, hit, CombatConfig.HitSoundDistance,
				volume or VitalsConfig.HitSoundVolume,
				seconds or CombatConfig.HitSoundMaxSeconds)
		end)
	end
	-- A ranged attack fires a single shot after its windup; only melee keeps a live hitbox.
	if attack.projectile then
		state.pendingAttack = nil
		-- Turn to face the shot as it is loosed, not as it lands. Firing sideways while the body stayed put
		-- read as a bug: the arrow left from somewhere the character was plainly not pointing.
		--
		-- Flattened, so aiming at the sky does not tip the character over backwards -- only the heading
		-- changes, and only around Y.
		local turnChar = player.Character
		local hrp = turnChar and turnChar:FindFirstChild("HumanoidRootPart")
		if hrp and typeof(aim) == "Vector3" then
			local flat = (aim - hrp.Position) * Vector3.new(1, 0, 1)
			if flat.Magnitude > 0.5 then
				hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flat.Unit)
			end
		end

		-- The aim is captured at the click and carried through the windup, so the shot goes where the player
		-- was pointing when they fired rather than wherever the camera has swung to by the time it leaves.
		task.delay(attack.windup, function()
			if player.Parent then fireProjectile(player, attack, aim) end
		end)
	else
		state.pendingAttack = attack
	end
	wearWeapon(player)

	-- The windup rides along so the client can show how long the aim takes.
	--
	-- Sent only for a ranged attack, because only those have a delay worth drawing: a sword lands on the
	-- click and a bar that appeared and vanished in a frame would be noise. Sent to EVERYONE rather than
	-- just the shooter, so a player can also see that someone else is lining a shot up on them.
	Remotes.CombatStateChanged:FireAllClients(player, "attack", state.chainIndex,
		attack.projectile and attack.windup or nil)

	-- The spellbook and the staff move from the hand to the chest for the duration of their attack pose;
	-- WeaponVisuals owns that and needs telling, since CombatStateChanged is fired at clients and cannot be
	-- listened to here. Guarded because the hand-off is nil until WeaponVisuals has published itself.
	if WeaponVisualsAccess.OnAttack then
		WeaponVisualsAccess.OnAttack(player)
	end
end)

PlayerJoin.Each(function(player)
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
