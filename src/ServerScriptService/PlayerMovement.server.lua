-- PlayerMovement.server.lua: server-authoritative walk/normal/run state machine driven by client intent, tied
-- to stamina. Replaces PlayerSpeed.server.lua's flat WalkSpeed. Runs in every server (lobby included — no
-- DataStore/position concerns here, unlike PlayerProfile.server.lua). See
-- docs/superpowers/specs/2026-09-07-movement-stamina-design.md for the full state machine.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

-- The HUD is StaminaUpdate's only consumer and it only exists in channel servers. Firing it in the lobby
-- (where nothing listens) fills Roblox's unhandled-remote queue and spams "invocation queue exhausted" warnings.
local SEND_STAMINA = not ServerConfig.IsLobby
local STAMINA_SEND_INTERVAL = 0.1 -- the HUD bar can't show finer than 10/s anyway; caps remote traffic per player

local SPEED = { Normal = 8, Walk = 4, Run = 16 }
local STAMINA_DRAIN_PER_SEC = 20 -- empties in ~5s from full
local STAMINA_REGEN_PER_SEC = 100 / 3 -- fills in ~3s from empty
local FORCED_WALK_SECONDS = 2

local States = {} -- [player] = { state, stamina, sprintIntent, forcedWalkUntil, lastSentStaminaPercent }

local function humanoidOf(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setState(state, player, newState)
	if state.state == newState then return end
	state.state = newState
	local humanoid = humanoidOf(player)
	if humanoid then humanoid.WalkSpeed = SPEED[newState == "ForcedWalk" and "Walk" or newState] end
end

local function sendStamina(state, player)
	local percent = math.floor(state.stamina + 0.5)
	if percent == state.lastSentStaminaPercent then return end
	-- lastSentStaminaPercent only updates on an actual send, so a change skipped by the interval is retried
	-- next tick until it goes out — the final resting value is never lost.
	if os.clock() - state.lastSentAt < STAMINA_SEND_INTERVAL then return end
	state.lastSentStaminaPercent = percent
	state.lastSentAt = os.clock()
	Remotes.StaminaUpdate:FireClient(player, state.stamina / 100)
end

Players.PlayerAdded:Connect(function(player)
	local state = { state = "Normal", stamina = 100, sprintIntent = false, forcedWalkUntil = 0, lastSentStaminaPercent = 100, lastSentAt = 0 }
	States[player] = state

	player.CharacterAdded:Connect(function()
		-- WalkSpeed doesn't persist across respawns; re-apply the current state directly (setState no-ops
		-- when the state name is unchanged, which it always is here).
		local humanoid = humanoidOf(player)
		if humanoid then humanoid.WalkSpeed = SPEED[state.state == "ForcedWalk" and "Walk" or state.state] end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	States[player] = nil
end)

Remotes.SetSprintIntent.OnServerEvent:Connect(function(player, intent)
	local state = States[player]
	if not state or type(intent) ~= "boolean" then return end
	state.sprintIntent = intent
	if intent and state.state ~= "ForcedWalk" and state.stamina > 0 then
		setState(state, player, "Run")
	elseif not intent and state.state == "Run" then
		setState(state, player, "Normal")
	end
end)

Remotes.ToggleWalk.OnServerEvent:Connect(function(player)
	local state = States[player]
	local humanoid = humanoidOf(player)
	if not state or not humanoid then return end
	if humanoid.MoveDirection.Magnitude > 0 then return end -- server re-verifies "standing still", doesn't trust the client
	if state.state == "Normal" then
		setState(state, player, "Walk")
	end
end)

RunService.Heartbeat:Connect(function(dt)
	for player, state in pairs(States) do
		if state.state == "Run" then
			state.stamina = math.max(0, state.stamina - STAMINA_DRAIN_PER_SEC * dt)
			if state.stamina <= 0 then
				state.forcedWalkUntil = os.clock() + FORCED_WALK_SECONDS
				setState(state, player, "ForcedWalk")
			end
		else
			state.stamina = math.min(100, state.stamina + STAMINA_REGEN_PER_SEC * dt)
		end

		if state.state == "ForcedWalk" and os.clock() >= state.forcedWalkUntil then
			setState(state, player, (state.sprintIntent and state.stamina > 0) and "Run" or "Normal")
		end

		if SEND_STAMINA then sendStamina(state, player) end
	end
end)
