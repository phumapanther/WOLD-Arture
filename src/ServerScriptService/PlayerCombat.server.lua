-- PlayerCombat.server.lua: server-authoritative attack state machine. The client only reports "I clicked"
-- (RequestAttack); the server decides whether that's legal, what it hits, and what everyone should see.
-- See docs/superpowers/specs/2026-09-07-movement-stamina-design.md for the movement rules this cooperates with.
--
-- Two states per player:
--   idle     — nothing; the first click enters guard AND throws the first attack
--   guarding — the held stance; each click throws the next attack in the weapon's chain. Drops back to idle
--              after the weapon's idleTimeout with no clicks.
--
-- Attack timing is windup -> active (hitbox live) -> recovery. A click during windup/active is ignored;
-- a click during recovery is allowed so chains feel responsive.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local States = {} -- [player] = { weapon, guarding, lastAttackAt, chainIndex, busyUntil, activeUntil, hitThisSwing }

local function humanoidOf(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function weaponOf(state)
	return CombatConfig.Weapons[state.weapon] or CombatConfig.Weapons[CombatConfig.DefaultWeapon]
end

local function setGuard(player, state, guarding)
	if state.guarding == guarding then return end
	state.guarding = guarding
	local humanoid = humanoidOf(player)
	if humanoid then
		-- PlayerMovement owns WalkSpeed normally; while guarding we clamp it and it restores on guard drop.
		humanoid.WalkSpeed = guarding and weaponOf(state).guardWalkSpeed or 8
	end
	Remotes.CombatStateChanged:FireAllClients(player, guarding and "guard_start" or "guard_end")
end

-- Damage lands here from any source so future systems (falls, drowning) can reuse it.
local function applyDamage(target, amount)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	humanoid:TakeDamage(amount)
end

local function resolveHit(player, state, attack)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local origin = hrp.Position + hrp.CFrame.LookVector * (attack.range * 0.5)
		+ Vector3.new(0, CombatConfig.HitboxHeightOffset, 0)

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and not state.hitThisSwing[other] then
			local otherChar = other.Character
			local otherHrp = otherChar and otherChar:FindFirstChild("HumanoidRootPart")
			if otherHrp and (otherHrp.Position - origin).Magnitude <= attack.range then
				state.hitThisSwing[other] = true
				applyDamage(otherChar, attack.damage)
			end
		end
	end
end

Remotes.RequestAttack.OnServerEvent:Connect(function(player)
	local state = States[player]
	local humanoid = humanoidOf(player)
	if not state or not humanoid or humanoid.Health <= 0 then return end

	local now = os.clock()
	if now < state.busyUntil then return end -- still mid-swing; ignore the click rather than queueing it

	local weapon = weaponOf(state)

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
	state.pendingAttack = attack

	if not state.guarding then setGuard(player, state, true) end
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

		if state.guarding and now - state.lastAttackAt > weaponOf(state).idleTimeout and now >= state.busyUntil then
			setGuard(player, state, false)
		end
	end
end)
