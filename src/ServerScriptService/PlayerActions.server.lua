-- PlayerActions.server.lua: roll and slide. Server-authoritative like every other system here — the client
-- reports "I pressed Ctrl", the server decides whether that is legal, spends the stamina, and moves the
-- character. See docs/superpowers/specs/2026-09-08-roll-slide-revive-carry-design.md.
--
-- Roblox animations carry no root motion: a KeyframeSequence only poses the rig. The travel is therefore
-- driven here with a LinearVelocity on the root part, and the animation only makes it look like a roll.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Vitals = require(game.ServerScriptService.Vitals)
local Inventory = require(game.ServerScriptService.Inventory)
local InventoryConfig = require(game.ReplicatedStorage.InventoryConfig)
local ActionConfig = require(game.ReplicatedStorage.ActionConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

if ServerConfig.IsLobby then return end

local States = {} -- [player] = { action, endsAt, nextAllowedAt, mover, attachment, speed }

local function humanoidOf(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- One mover per action, destroyed when it ends. LinearVelocity rather than setting AssemblyLinearVelocity
-- every frame: the engine keeps applying it between frames, so the motion stays smooth at any framerate.
local function startMover(character, direction, speed)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil, nil end
	local attachment = Instance.new("Attachment")
	attachment.Parent = hrp
	local mover = Instance.new("LinearVelocity")
	mover.Attachment0 = attachment
	mover.MaxForce = math.huge
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	-- Vertical velocity is left to gravity: forcing Y would make the player float over dips and stick to slopes.
	mover.VectorVelocity = direction * speed
	mover.Parent = hrp
	return mover, attachment
end

local function stopAction(player, state)
	if state.mover then state.mover:Destroy() end
	if state.attachment then state.attachment:Destroy() end
	state.mover, state.attachment = nil, nil

	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.AutoRotate = true
		-- PlayerMovement owns WalkSpeed; putting back the normal value is enough, its state machine will
		-- correct it on the next intent change.
		if humanoid.WalkSpeed == 0 then humanoid.WalkSpeed = 8 end
	end

	local finished = state.action
	state.action = nil
	if finished then
		Remotes.MoveStateChanged:FireAllClients(player, finished .. "_end")
	end
end

-- Both actions share the same guards: alive, not downed, not already mid-action, off cooldown.
local function canAct(player, state)
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 then return false end
	if Vitals.IsDowned(player) then return false end
	if state.action then return false end
	if os.clock() < state.nextAllowedAt then return false end
	-- Only from solid ground. A roll drives the character with a LinearVelocity that overrides gravity for its
	-- duration, so rolling in mid-air held the player up — and because the next roll could start before they
	-- landed, they could stay airborne indefinitely.
	if humanoid.FloorMaterial == Enum.Material.Air then return false end
	return true
end

Remotes.RequestRoll.OnServerEvent:Connect(function(player, direction)
	local state = States[player]
	if not state or not canAct(player, state) then return end
	if typeof(direction) ~= "Vector3" then return end

	local cfg = ActionConfig.Roll
	if Vitals.GetStamina(player) < cfg.staminaCost then return end

	local character = player.Character
	local humanoid = humanoidOf(player)
	-- Never trust the client's vector: flatten it, and fall back to the character's own facing if it is junk.
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.1 then
		flat = character.HumanoidRootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	if flat.Magnitude < 0.1 then return end
	flat = flat.Unit

	Vitals.SetStamina(player, Vitals.GetStamina(player) - cfg.staminaCost)
	Vitals.Send(player, true)

	local now = os.clock()
	state.action = "roll"
	state.endsAt = now + cfg.duration
	state.nextAllowedAt = now + cfg.cooldown
	-- Face the roll and hold that facing: turning mid-roll would fight the animation.
	character.HumanoidRootPart.CFrame = CFrame.lookAt(character.HumanoidRootPart.Position,
		character.HumanoidRootPart.Position + flat)
	humanoid.AutoRotate = false
	-- A heavily loaded player rolls half as far: carrying a plate armor and a full bag should cost agility.
	local penalty = Inventory.IsHeavilyLoaded(player) and InventoryConfig.HeavyActionPenalty or 1
	state.mover, state.attachment = startMover(character, flat, cfg.speed * penalty)

	Remotes.MoveStateChanged:FireAllClients(player, "roll")
end)

Remotes.RequestSlide.OnServerEvent:Connect(function(player)
	local state = States[player]
	if not state or not canAct(player, state) then return end

	local cfg = ActionConfig.Slide
	local humanoid = humanoidOf(player)
	local stamina = Vitals.GetStamina(player)
	if stamina < cfg.minStaminaToStart then return end
	-- Sliding is only reachable out of a sprint, which the server can verify from the speed it set itself
	-- rather than trusting a client flag.
	if humanoid.WalkSpeed < 12 then return end

	local character = player.Character
	local hrp = character.HumanoidRootPart
	local flat = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.1 then return end
	flat = flat.Unit

	-- Distance scales with the stamina left, then the slide spends all of it.
	local fraction = stamina / 100
	local duration = cfg.minDuration + (cfg.maxDuration - cfg.minDuration) * fraction
	Vitals.SetStamina(player, 0)
	Vitals.Send(player, true)

	local now = os.clock()
	state.action = "slide"
	state.endsAt = now + duration
	state.nextAllowedAt = now + duration + cfg.cooldown
	local penalty = Inventory.IsHeavilyLoaded(player) and InventoryConfig.HeavyActionPenalty or 1
	state.speed = cfg.startSpeed * penalty
	humanoid.AutoRotate = false
	state.mover, state.attachment = startMover(character, flat, state.speed)

	Remotes.MoveStateChanged:FireAllClients(player, "slide")
end)

Players.PlayerAdded:Connect(function(player)
	States[player] = { action = nil, endsAt = 0, nextAllowedAt = 0, speed = 0 }
	player.CharacterAdded:Connect(function()
		local state = States[player]
		-- The old character's mover died with it; just clear the flags so the new one can act immediately.
		if state then
			state.action, state.mover, state.attachment = nil, nil, nil
			state.endsAt, state.nextAllowedAt = 0, 0
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	States[player] = nil
end)

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for player, state in pairs(States) do
		if state.action then
			if now >= state.endsAt or not player.Character then
				stopAction(player, state)
			elseif state.action == "slide" and state.mover then
				-- Decelerate so the slide eases out instead of stopping dead at the timer.
				state.speed *= ActionConfig.Slide.friction ^ dt
				local dir = state.mover.VectorVelocity
				if dir.Magnitude > 0.01 then
					state.mover.VectorVelocity = dir.Unit * state.speed
				end
			end
		end
	end
end)
