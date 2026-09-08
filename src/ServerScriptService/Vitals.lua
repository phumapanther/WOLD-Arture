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

-- Injected by PlayerProgression.server.lua. Progression already calls back into Vitals (level-up refills the
-- bars), so requiring it here as well would be a cycle. When it is absent — the lobby, or before startup
-- finishes — the maximums fall back to the flat level-1 values.
local Progression = nil
function Vitals.BindProgression(progression)
	Progression = progression
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
		-- Everyone starts in the "bare" armor: it halves incoming combat damage but has so little capacity
		-- that roughly five punches destroy it. Better armor is a later sub-project.
		armor = VitalsConfig.StartingArmor,

		downed = false,
		downedUntil = 0,
		invulnUntil = 0,

		peakFallY = nil, -- highest Y of the current fall, nil when not falling
		lastSentAt = 0,
	}
	return States[player]
end

function Vitals.Remove(player)
	States[player] = nil
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

function Vitals.IsDowned(player)
	local state = States[player]
	return state ~= nil and state.downed
end

-- Downed players take no damage at all (the countdown is the only exit), and so do players inside the
-- post-respawn blink window.
function Vitals.IsInvulnerable(player)
	local state = States[player]
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
		armor = state.armor / VitalsConfig.MaxArmor,
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
		local absorbed = math.min(state.armor, amount * VitalsConfig.ArmorAbsorbFraction)
		state.armor -= absorbed
		amount -= absorbed
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
	replacement:SetAttribute("WOLD_UprightC0", true)
	replacement.Parent = joint.Parent
	joint:Destroy()
	return replacement
end

local UPRIGHT_C0 = {} -- [character] = the C0 to put back when standing up

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

	if downed then
		humanoid.WalkSpeed = VitalsConfig.DownedWalkSpeed
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.HipHeight = VitalsConfig.DownedHipHeight
		local joint = ownedRootJoint(character)
		if joint then
			UPRIGHT_C0[character] = UPRIGHT_C0[character] or joint.C0
			joint.C0 = UPRIGHT_C0[character] * CFrame.Angles(PRONE_PITCH, 0, 0)
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
		UPRIGHT_C0[character] = nil
		setLimbCollision(character, true)
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
	state.armor = VitalsConfig.MaxArmor
	Vitals.Send(player, true)
end

-- Respawn at the spawn point. Vitals themselves reset on CharacterAdded (Vitals.ResetForRespawn).
function Vitals.Respawn(player)
	local state = States[player]
	if not state then return end
	if state.downed then clearDowned(player, state) end
	player:LoadCharacter()
end

-- Instant death: the character really dies and Roblox's own respawn cycle brings it back.
function Vitals.Kill(player)
	local state = States[player]
	if not state then return end
	if state.downed then clearDowned(player, state) end
	state.hp = 0
	-- Dying wipes every level and the body size with it — the risk that pays for growing. Being downed and
	-- revived does not come through here, so a rescue costs nothing.
	if Progression then Progression.ResetOnDeath(player) end
	local humanoid = humanoidOf(player)
	if humanoid then humanoid.Health = 0 end
end

-- Everything comes back full EXCEPT armor: a one-time pool that never refills, not even on respawn.
function Vitals.ResetForRespawn(player)
	local state = States[player]
	if not state then return end
	state.hp = maxHP(player)
	state.hunger = maxHunger(player)
	state.stamina = VitalsConfig.MaxStamina
	state.downed = false
	-- Clear the replicated flag too, or other clients keep showing revive/carry prompts on a player who has
	-- already respawned (this path bypasses clearDowned).
	player:SetAttribute("WOLD_Downed", false)
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
	-- Drain scales with the player's own maximum, so growing does not shorten the 30-minute hunger clock.
	local hungerScale = maxHunger(player) / VitalsConfig.MaxHunger
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

return Vitals
