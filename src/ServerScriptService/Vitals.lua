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

local function humanoidOf(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function Vitals.Add(player)
	States[player] = {
		hp = VitalsConfig.MaxHP,
		hunger = VitalsConfig.MaxHunger,
		stamina = VitalsConfig.MaxStamina,
		armor = 0, -- no armor items exist yet; the absorb path is live for when they do

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
		hp = state.hp / VitalsConfig.MaxHP,
		hunger = state.hunger / VitalsConfig.MaxHunger,
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

-- The prone look is cosmetic only, applied client-side: the humanoid stays upright so the engine's mover
-- still works. Physically rotating the character does look right but stops movement almost entirely
-- (measured: 2.88 studs of travel -> 0.01). Here we only slow the player, ground the capsule, stop jumping.
local function applyDownedPosture(player, downed)
	local humanoid = humanoidOf(player)
	if not humanoid then return end
	if downed then
		humanoid.WalkSpeed = VitalsConfig.DownedWalkSpeed
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.HipHeight = VitalsConfig.DownedHipHeight
	else
		humanoid.JumpPower = 50
		humanoid.JumpHeight = 7.2
		humanoid.HipHeight = 2
		humanoid.WalkSpeed = 8
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
	local humanoid = humanoidOf(player)
	if humanoid then humanoid.Health = 0 end
end

-- Everything comes back full EXCEPT armor: a one-time pool that never refills, not even on respawn.
function Vitals.ResetForRespawn(player)
	local state = States[player]
	if not state then return end
	state.hp = VitalsConfig.MaxHP
	state.hunger = VitalsConfig.MaxHunger
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
	state.hunger = math.max(0, state.hunger - VitalsConfig.HungerDrainPerSec * dt)
	if state.hunger <= 0 then
		Vitals.ApplyDamage(player, VitalsConfig.StarvationDamagePerSec * dt, "starve")
		if state.downed then return end
	end

	if swimming then
		-- Only actual swimming costs stamina; floating still lets a player rest indefinitely.
		if humanoid.MoveDirection.Magnitude > 0 then
			state.stamina = math.max(0, state.stamina - VitalsConfig.SwimStaminaDrainPerSec * dt)
		end
		if state.stamina <= 0 then
			Vitals.ApplyDamage(player, VitalsConfig.DrowningDamagePerSec * dt, "drown")
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
