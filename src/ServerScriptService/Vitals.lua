-- Vitals.lua: the single owner of every vital value — HP, hunger, stamina, armor — and of the downed state.
-- Server-authoritative: the client only renders what it is told and may ask to respawn, nothing more.
--
-- A module rather than a script because three systems need to reach it: PlayerVitals.server.lua drives the
-- per-frame tick, PlayerMovement reads/writes stamina, and PlayerCombat routes its damage through ApplyDamage.
--
-- Stamina lives here rather than in PlayerMovement because two systems now spend it (sprinting and swimming)
-- and a third depends on it (drowning), so there is exactly one owner and no double-draining.
--
-- See docs/superpowers/specs/2026-09-07-vitals-downed-design.md.
local Players = game:GetService("Players")
local VitalsConfig = require(game.ReplicatedStorage.VitalsConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local Vitals = {}

local States = {} -- [player] = state; see NewState() for the shape

-- Carrying suspends the prone pose without ending the downed state: a player riding on someone's back should
-- sit upright in the Carry_Held pose, not stay face-down. Set while carried, cleared when set down.
local ProneSuspended = {} -- [player] = true
-- Admin godmode. Separate from the respawn invulnerability because it must also stop hunger, drowning and
-- the void -- none of which go through ApplyDamage -- and because a respawn must not clear it.
local Godmode = {} -- [player] = true

-- [character] = the joint's upright C0, so the prone pose can always be set ABSOLUTELY rather than rotated
-- off whatever it currently is.
local UPRIGHT_C0 = {}

-- Injected by PlayerProgression.server.lua. Progression already calls back into Vitals (level-up refills the
-- bars), so requiring it here as well would be a cycle. When it is absent — the lobby, or before startup
-- finishes — the maximums fall back to the flat level-1 values.
local Progression = nil
function Vitals.BindProgression(progression)
	Progression = progression
end

-- Armor now comes from the equipped set rather than a fixed pool, so Vitals needs to read the player's gear.
-- Injected for the same reason as Progression: no cycle, and the lobby runs neither system.
local Inventory = nil
function Vitals.BindInventory(inventory)
	Inventory = inventory
end

-- Max HP and max hunger grow with level, so every read goes through these rather than VitalsConfig directly.
local function maxHP(player)
	return Progression and Progression.MaxHP(player) or VitalsConfig.MaxHP
end

local function maxHunger(player)
	return Progression and Progression.MaxHunger(player) or VitalsConfig.MaxHunger
end

local function humanoidOf(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function Vitals.Add(player)
	States[player] = {
		-- Level-scaled: a returning high-level player joins with their bigger bars already full. Progression
		-- is bound before any player is added, so this reads the real maximum.
		hp = maxHP(player),
		hunger = maxHunger(player),
		stamina = VitalsConfig.MaxStamina,
		mana = VitalsConfig.MaxMana,
		manaTimer = 0, -- seconds accumulated toward the next pip
		-- Everyone starts in the "bare" armor: it halves incoming combat damage but has so little capacity
		-- that roughly five punches destroy it. Better armor is a later sub-project.
		armor = VitalsConfig.StartingArmor,
		maxArmor = VitalsConfig.MaxArmor, -- raised by wearing real armor; see SyncArmorFromEquipment

		downed = false,
		downedUntil = 0,
		invulnUntil = 0,

		peakFallY = nil, -- highest Y of the current fall, nil when not falling
		lastSentAt = 0,
	}
	return States[player]
end

function Vitals.Remove(player)
	Godmode[player] = nil
	States[player] = nil
	ProneSuspended[player] = nil
end

function Vitals.Get(player)
	return States[player]
end

function Vitals.All()
	return States
end

--------------------------------------------------------------------------------
-- Values other systems read and write
--------------------------------------------------------------------------------

function Vitals.GetStamina(player)
	local state = States[player]
	return state and state.stamina or VitalsConfig.MaxStamina
end

function Vitals.SetStamina(player, value)
	local state = States[player]
	if not state then return end
	state.stamina = math.clamp(value, 0, VitalsConfig.MaxStamina)
end

-- Weapon skills call this: it either spends the pips and returns true, or refuses and returns false, so the
-- caller never has to check and subtract separately (which is how double-spends creep in).
function Vitals.TrySpendMana(player, cost)
	local state = States[player]
	if not state then return false end
	cost = cost or 1
	if state.mana < cost then return false end
	state.mana -= cost
	Vitals.Send(player, true)
	return true
end

function Vitals.AddMana(player, amount)
	local state = States[player]
	if not state then return end
	state.mana = math.clamp(state.mana + amount, 0, VitalsConfig.MaxMana)
	Vitals.Send(player, true)
end

-- Consumables. Both clamp to the player's level-scaled maximum rather than a flat 100.
function Vitals.Heal(player, amount)
	local state = States[player]
	if not state or state.downed then return end
	state.hp = math.min(maxHP(player), state.hp + amount)
	Vitals.Send(player, true)
end

function Vitals.Feed(player, amount)
	local state = States[player]
	if not state then return end
	state.hunger = math.min(maxHunger(player), state.hunger + amount)
	Vitals.Send(player, true)
end

-- Called whenever the equipped armor changes (worn, removed, repaired): the armor pool follows the gear.
function Vitals.SyncArmorFromEquipment(player)
	local state = States[player]
	if not state then return end
	if not Inventory then
		state.armor = VitalsConfig.StartingArmor
	else
		local armorItem, entry = Inventory.EquippedArmor(player)
		if armorItem and entry then
			state.armor = entry.durability or armorItem.armor
			state.maxArmor = armorItem.armor
		else
			-- Nothing worn: back to the fragile bare armor everyone has by default.
			state.armor = math.min(state.armor, VitalsConfig.StartingArmor)
			state.maxArmor = VitalsConfig.MaxArmor
		end
	end
	Vitals.Send(player, true)
end

function Vitals.IsDowned(player)
	local state = States[player]
	return state ~= nil and state.downed
end

-- Downed players take no damage at all (the countdown is the only exit), and so do players inside the
-- post-respawn blink window.
function Vitals.SetGodmode(player, on)
	Godmode[player] = on or nil
	if on then
		-- Turning it on should also undo the damage already taken, or "immortal" starts at 3 HP.
		local state = States[player]
		if state then
			if state.downed then Vitals.Recover(player, 1) end
			state.hp = maxHP(player)
			state.hunger = maxHunger(player)
			state.stamina = VitalsConfig.MaxStamina
			Vitals.Send(player, true)
		end
	end
	return Godmode[player] == true
end

function Vitals.IsGodmode(player)
	return Godmode[player] == true
end

function Vitals.IsInvulnerable(player)
	local state = States[player]
	if Godmode[player] then return true end
	return state ~= nil and (state.downed or os.clock() < state.invulnUntil)
end

function Vitals.Send(player, force)
	local state = States[player]
	if not state then return end
	local now = os.clock()
	if not force and now - state.lastSentAt < VitalsConfig.SendInterval then return end
	state.lastSentAt = now
	Remotes.VitalsUpdate:FireClient(player, {
		hp = state.hp / maxHP(player),
		hunger = state.hunger / maxHunger(player),
		stamina = state.stamina / VitalsConfig.MaxStamina,
		armor = state.armor / (state.maxArmor or VitalsConfig.MaxArmor),
		mana = state.mana, -- whole pips, not a fraction: the HUD lights that many gems
	})
end

--------------------------------------------------------------------------------
-- Damage
--------------------------------------------------------------------------------

-- Every damage source funnels through here, so armor, invulnerability and the downed transition are decided
-- in exactly one place.
--   kind: "combat" | "fall" | "drown" | "starve" | "void"
-- Only "combat" is reduced by armor — armor doesn't help you stop being hungry. Only combat/fall/starve can
-- down a player; drowning and the void kill outright, because you cannot crawl underwater or in the void.
function Vitals.ApplyDamage(player, amount, kind)
	local state = States[player]
	if not state or amount <= 0 then return end
	if Vitals.IsInvulnerable(player) then return end

	if kind == "combat" and state.armor > 0 then
		-- The worn armor decides how much of the hit it eats; bare skin falls back to the old flat rate.
		local armorItem, entry = Inventory and Inventory.EquippedArmor(player)
		local fraction = armorItem and armorItem.absorbFraction or VitalsConfig.ArmorAbsorbFraction
		local absorbed = math.min(state.armor, amount * fraction)
		state.armor -= absorbed
		amount -= absorbed
		-- Wear the piece itself down, so it can be repaired or replaced rather than silently regenerating.
		if entry then entry.durability = state.armor end
	end

	state.hp = math.max(0, state.hp - amount)
	if state.hp > 0 then return end

	if kind == "drown" or kind == "void" then
		Vitals.Kill(player)
	else
		Vitals.EnterDowned(player)
	end
end

--------------------------------------------------------------------------------
-- Downed state
--------------------------------------------------------------------------------

-- Laying the body down, server-side so EVERY player sees it.
--
-- Three approaches that do NOT work, all measured:
--   * Writing LowerTorso.Root.Transform on the owning client — the tilt is purely local, so other players see
--     the crawler standing upright. This is what the user's screenshot caught.
--   * Writing that Transform from the server — the client owns the character's physics and overwrites it.
--   * Rotating the HumanoidRootPart — replicates, but a walking humanoid immediately rights itself.
--
-- The Root joint's own C0/C1 are read-only, so what works is REPLACING that Motor6D with an identical one we
-- own, and pitching its C0. The humanoid stays upright underneath (so the engine's mover still drives
-- movement normally — measured 92 studs of crawling), while the visible body lies flat.
local PRONE_PITCH = math.rad(-90) -- negative is face-down; positive lays the character on its back

local function rootJointOf(character)
	local lowerTorso = character and character:FindFirstChild("LowerTorso")
	return lowerTorso and lowerTorso:FindFirstChild("Root")
end

-- Swaps in a Motor6D we control, once, and remembers the upright C0 to restore later.
local function ownedRootJoint(character)
	local joint = rootJointOf(character)
	if not joint then return nil end
	if joint:GetAttribute("WOLD_Owned") then return joint end

	local replacement = Instance.new("Motor6D")
	replacement.Name = "Root"
	replacement.Part0 = joint.Part0
	replacement.Part1 = joint.Part1
	replacement.C0 = joint.C0
	replacement.C1 = joint.C1
	replacement:SetAttribute("WOLD_Owned", true)
	replacement.Parent = joint.Parent
	joint:Destroy()
	return replacement
end

-- The upright C0, captured the first time we take the joint over — while it is still upright. Reading it
-- later can capture an already-tilted value, which then compounds every time the pose is re-applied (a carry
-- and set-down left the body upside down).
local function uprightC0(character)
	local joint = ownedRootJoint(character)
	if not joint then return nil, nil end
	if UPRIGHT_C0[character] == nil then
		UPRIGHT_C0[character] = joint.C0
	end
	return joint, UPRIGHT_C0[character]
end


-- A body lying flat has arms, legs, torso and head all scraping the floor (measured: eleven parts touching),
-- and their friction fights the humanoid's mover — crawling slowed to about 2 studs where 12 was expected.
-- The root capsule alone is enough to stand on, so the visible limbs stop colliding while prone.
local function setLimbCollision(character, collide)
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = collide
		end
	end
end

local function applyDownedPosture(player, downed)
	local humanoid = humanoidOf(player)
	local character = player.Character
	if not humanoid or not character then return end

	if downed and ProneSuspended[player] then
		-- Being carried: the carrier owns this body's pose entirely, so leave the joint alone and only keep
		-- the movement clamps that being downed implies.
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		return
	end

	if downed then
		humanoid.WalkSpeed = VitalsConfig.DownedWalkSpeed
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.HipHeight = VitalsConfig.DownedHipHeight
		local joint, upright = uprightC0(character)
		if joint and upright then
			joint.C0 = upright * CFrame.Angles(PRONE_PITCH, 0, 0)
		end
		setLimbCollision(character, false)
	else
		humanoid.JumpPower = 50
		humanoid.JumpHeight = 7.2
		humanoid.HipHeight = 2
		humanoid.WalkSpeed = 8
		local joint = rootJointOf(character)
		if joint and UPRIGHT_C0[character] then
			joint.C0 = UPRIGHT_C0[character]
		end
		setLimbCollision(character, true)
	end
end

-- Called by the rescue system when a downed player is picked up or set down. Lifting the prone pose while
-- carried and restoring it on release keeps the two systems from fighting over the same joint.
function Vitals.SetProneSuspended(player, suspended)
	if suspended then
		ProneSuspended[player] = true
		-- Stand the body back up before the carry joint takes over, or the carried player rides face-down.
		local character = player.Character
		local joint = character and rootJointOf(character)
		if joint and UPRIGHT_C0[character] then
			joint.C0 = UPRIGHT_C0[character] -- absolute, never a relative rotation off the current value
		end
		if character then setLimbCollision(character, true) end
	else
		ProneSuspended[player] = nil
		-- Put the prone pose back if they are still down after being set down. A dying or dead humanoid is
		-- being set down BY a respawn (the carried player pressed the button), and re-applying the pose there
		-- would lay the incoming rig back down on a player who is no longer downed at all.
		local humanoid = humanoidOf(player)
		if Vitals.IsDowned(player) and humanoid and humanoid.Health > 0 then
			applyDownedPosture(player, true)
		end
	end
end

function Vitals.EnterDowned(player)
	local state = States[player]
	if not state or state.downed then return end
	state.downed = true
	state.hp = 0
	state.downedUntil = os.clock() + VitalsConfig.DownedSeconds
	applyDownedPosture(player, true)
	-- Replicated so every client knows who to offer revive/carry prompts on; DownedStateChanged only reaches
	-- the downed player themselves.
	player:SetAttribute("WOLD_Downed", true)
	Remotes.DownedStateChanged:FireClient(player, true, VitalsConfig.DownedSeconds)
	Vitals.Send(player, true)
end

-- Clears the downed flag and tells the client. Shared by every exit: countdown expiry, the respawn button,
-- falling in water, and (later) being revived.
local function clearDowned(player, state)
	state.downed = false
	applyDownedPosture(player, false)
	player:SetAttribute("WOLD_Downed", false)
	Remotes.DownedStateChanged:FireClient(player, false)
end

-- Single recovery entry point that does NOT respawn — the revive and carry systems (next sub-project) call
-- this rather than reimplementing recovery. See the spec's revive hook.
function Vitals.Recover(player, hpFraction)
	local state = States[player]
	if not state or not state.downed then return end
	clearDowned(player, state)
	state.hp = VitalsConfig.MaxHP * (hpFraction or 1)
	Vitals.Send(player, true)
end

-- Level-up refills every bar INCLUDING armor. This is the one path that restores armor: a plain respawn
-- deliberately does not (see ResetForRespawn), so armor is otherwise a one-time pool.
function Vitals.RefillOnLevelUp(player)
	local state = States[player]
	if not state then return end
	state.hp = maxHP(player)
	state.hunger = maxHunger(player)
	state.stamina = VitalsConfig.MaxStamina
	state.mana = VitalsConfig.MaxMana
	state.armor = VitalsConfig.MaxArmor
	Vitals.Send(player, true)
end

-- Respawn at the spawn point. Vitals themselves reset on CharacterAdded (Vitals.ResetForRespawn).
function Vitals.Respawn(player)
	local state = States[player]
	if not state then return end
	if state.downed then clearDowned(player, state) end
	-- Bleeding out and pressing "respawn now" ARE deaths, so they must cost the level like any other. Killing
	-- the humanoid rather than calling LoadCharacter is what makes that automatic: LoadCharacter rebuilds the
	-- rig without the humanoid ever dying, so Humanoid.Died — the one hook every death path shares — would
	-- never fire and the level would survive.
	local humanoid = humanoidOf(player)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	else
		player:LoadCharacter() -- already dead (or no rig): nothing to kill, just bring them back
	end
end

-- Instant death: the character really dies and Roblox's own respawn cycle brings it back.
function Vitals.Kill(player)
	local state = States[player]
	if not state then return end
	-- Godmode outranks even a direct kill. /kill on an immortal player would otherwise be a silent
	-- exception to the one promise the mode makes, and the admin who typed /god is usually the same person
	-- testing with /kill.
	if Godmode[player] then return end
	if state.downed then clearDowned(player, state) end
	state.hp = 0
	-- The level wipe is NOT done here: PlayerProgression hooks Humanoid.Died instead, so deaths that never
	-- reach this function (the downed countdown expiring, the respawn button) cost the level too.
	local humanoid = humanoidOf(player)
	if humanoid then humanoid.Health = 0 end
end

-- Everything comes back full EXCEPT armor: a one-time pool that never refills, not even on respawn.
function Vitals.ResetForRespawn(player)
	-- The rig is rebuilt on respawn, so the old character's joint baseline is dead weight. Keyed by character,
	-- so this is the only place it can be released without losing the value mid-carry.
	local character = player.Character
	if character then UPRIGHT_C0[character] = nil end
	ProneSuspended[player] = nil

	local state = States[player]
	if not state then return end
	state.hp = maxHP(player)
	state.hunger = maxHunger(player)
	state.stamina = VitalsConfig.MaxStamina
	state.mana = VitalsConfig.MaxMana
	local wasDowned = state.downed
	state.downed = false
	-- Clear the replicated flag too, or other clients keep showing revive/carry prompts on a player who has
	-- already respawned (this path bypasses clearDowned).
	player:SetAttribute("WOLD_Downed", false)
	-- ...and tell the respawning player's own client, which is the ONLY thing that hides the dark screen.
	-- Vitals.Respawn normally fires this through clearDowned before killing the humanoid, but that is not
	-- enough on its own: while someone is carrying you, dropCarried runs a frame later and puts the downed
	-- posture back, leaving the state downed again by the time the new rig arrives. Respawning is the last
	-- word either way, so clear the screen here, where every respawn path converges.
	if wasDowned then
		Remotes.DownedStateChanged:FireClient(player, false)
	end
	state.peakFallY = nil
	state.invulnUntil = os.clock() + VitalsConfig.RespawnInvulnSeconds
end

--------------------------------------------------------------------------------
-- Per-frame tick, called by PlayerVitals.server.lua
--------------------------------------------------------------------------------

function Vitals.Tick(player, state, dt)
	local humanoid = humanoidOf(player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp or humanoid.Health <= 0 then return end

	-- The void kills wherever you are, downed or not: there is no floor left to crawl on, and respawn
	-- protection doesn't apply because nothing survives leaving the map.
	if hrp.Position.Y < VitalsConfig.VoidY then
		-- Godmode is the one thing the void respects: it deliberately clears the respawn timer, so without
		-- this an immortal admin who flies under the map still dies.
		if Godmode[player] then
			hrp.CFrame = CFrame.new(hrp.Position.X, 200, hrp.Position.Z)
			return
		end
		state.invulnUntil = 0
		Vitals.Kill(player)
		return
	end

	local swimming = humanoid:GetState() == Enum.HumanoidStateType.Swimming

	if state.downed then
		-- Downed in water = instant respawn: crawling only happens on land.
		if swimming or os.clock() >= state.downedUntil then
			Vitals.Respawn(player)
		end
		-- Everything else freezes while downed; only the countdown runs.
		return
	end

	-- Hunger drains continuously, and starves HP once empty.
	-- Mana trickles back a whole pip at a time.
	if state.mana < VitalsConfig.MaxMana then
		state.manaTimer += dt
		if state.manaTimer >= VitalsConfig.ManaRegenSeconds then
			state.manaTimer = 0
			state.mana += 1
			Vitals.Send(player, true)
		end
	else
		state.manaTimer = 0
	end

	-- Drain scales with the player's own maximum, so growing does not shorten the 30-minute hunger clock.
	local hungerScale = maxHunger(player) / VitalsConfig.MaxHunger
	-- Hunger and stamina drain here rather than through ApplyDamage, so godmode has to stop them too or an
	-- immortal player still starves and still drowns.
	if Godmode[player] then
		state.hunger = maxHunger(player)
		state.stamina = VitalsConfig.MaxStamina
		state.hp = maxHP(player)
		return
	end
	state.hunger = math.max(0, state.hunger - VitalsConfig.HungerDrainPerSec * hungerScale * dt)
	if state.hunger <= 0 then
		Vitals.ApplyDamage(player, VitalsConfig.StarvationDamagePerSec * (maxHP(player) / VitalsConfig.MaxHP) * dt, "starve")
		if state.downed then return end
	end

	if swimming then
		-- Only actual swimming costs stamina; floating still lets a player rest indefinitely.
		if humanoid.MoveDirection.Magnitude > 0 then
			state.stamina = math.max(0, state.stamina - VitalsConfig.SwimStaminaDrainPerSec * dt)
		end
		if state.stamina <= 0 then
			-- Ten seconds to drown regardless of size, for the same reason hunger scales.
			Vitals.ApplyDamage(player, VitalsConfig.DrowningDamagePerSec * (maxHP(player) / VitalsConfig.MaxHP) * dt, "drown")
		end
		state.peakFallY = nil -- water cancels any fall in progress
	else
		-- Fall tracking. Note we do NOT key off Freefall alone: mid-fall the humanoid flickers back to Running
		-- for a frame or two (measured: a 30-stud drop reported Running again 3 studs in), and treating that as
		-- a landing billed a 3-stud fall and lost the rest of the drop. So keep accumulating the peak whenever
		-- the character is off the ground, and only settle up once something is actually underfoot.
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		if not grounded then
			state.peakFallY = math.max(state.peakFallY or hrp.Position.Y, hrp.Position.Y)
		elseif state.peakFallY then
			-- Landed: bill the drop from the highest point reached.
			local drop = state.peakFallY - hrp.Position.Y
			state.peakFallY = nil
			if drop > VitalsConfig.SafeFallStuds then
				Vitals.ApplyDamage(player, (drop - VitalsConfig.SafeFallStuds) * VitalsConfig.FallDamagePerStud, "fall")
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Lending the prone pose to other systems
--------------------------------------------------------------------------------

-- Lays a character flat, or stands them back up. Published because being shot should look like being shot
-- rather than like a dropped puppet: PlatformStand alone leaves the rig limp and at whatever angle physics
-- happens to settle at, which is why a knockdown read as a glitch rather than a pose.
--
-- `onBack` chooses which way up. The pitch sign is the same one the downed crawl uses -- negative is
-- face-down, positive lays them on their back, which is what a shot to the front produces.
--
-- Deliberately NOT the downed state: this is cosmetic only. Nothing here touches health, the revive
-- prompts, or anything else that being downed means.
function Vitals.SetProne(player, prone, onBack)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	-- A genuinely downed player owns their own pose; a knockdown must not fight the crawl.
	if Vitals.IsDowned(player) then return end

	if prone then
		local joint, upright = uprightC0(character)
		if joint and upright then
			joint.C0 = upright * CFrame.Angles(onBack and -PRONE_PITCH or PRONE_PITCH, 0, 0)
		end
		humanoid.HipHeight = VitalsConfig.DownedHipHeight
	else
		humanoid.HipHeight = 2
		local joint = rootJointOf(character)
		if joint and UPRIGHT_C0[character] then
			joint.C0 = UPRIGHT_C0[character]
		end
	end
end

return Vitals
