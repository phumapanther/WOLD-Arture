-- PlayerMovement.server.lua: server-authoritative walk/normal/run state machine driven by client intent, tied
-- to stamina. Replaces PlayerSpeed.server.lua's flat WalkSpeed. Runs in every server (lobby included — no
-- DataStore/position concerns here, unlike PlayerProfile.server.lua). See
-- docs/superpowers/specs/2026-09-07-movement-stamina-design.md for the full state machine.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Vitals = require(game.ServerScriptService.Vitals)
local Remotes = require(game.ReplicatedStorage.Remotes)

-- Stamina VALUES now live in Vitals.lua (swimming spends it too, and drowning depends on it), and the HUD gets
-- them through VitalsUpdate. This file still owns the walk/normal/run state machine that spends it, and reads
-- the value back through Vitals.GetStamina. The lobby has no vitals at all, so the machine idles there.
local ACTIVE = not ServerConfig.IsLobby

local SPEED = { Normal = 8, Walk = 4, Run = 16 }
local STAMINA_DRAIN_PER_SEC = 20 -- empties in ~5s from full
local STAMINA_REGEN_PER_SEC = 100 / 3 -- fills in ~3s from empty
local FORCED_WALK_SECONDS = 2

local States = {} -- [player] = { state, sprintIntent, forcedWalkUntil }

local function humanoidOf(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setState(state, player, newState)
	if state.state == newState then return end
	state.state = newState
	local humanoid = humanoidOf(player)
	-- Vitals owns WalkSpeed while downed (crawling pace); don't fight it.
	if humanoid and not Vitals.IsDowned(player) then
		humanoid.WalkSpeed = SPEED[newState == "ForcedWalk" and "Walk" or newState]
	end
end

Players.PlayerAdded:Connect(function(player)
	local state = { state = "Normal", sprintIntent = false, forcedWalkUntil = 0 }
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
	if Vitals.IsDowned(player) then return end -- no sprinting while crawling
	state.sprintIntent = intent
	if intent and state.state ~= "ForcedWalk" and Vitals.GetStamina(player) > 0 then
		setState(state, player, "Run")
	elseif not intent and state.state == "Run" then
		setState(state, player, "Normal")
	end
end)

Remotes.ToggleWalk.OnServerEvent:Connect(function(player)
	local state = States[player]
	local humanoid = humanoidOf(player)
	if not state or not humanoid then return end
	if Vitals.IsDowned(player) then return end -- the walk toggle is meaningless while crawling
	if humanoid.MoveDirection.Magnitude > 0 then return end -- server re-verifies "standing still", doesn't trust the client
	if state.state == "Normal" then
		setState(state, player, "Walk")
	end
end)

if ACTIVE then
	RunService.Heartbeat:Connect(function(dt)
		for player, state in pairs(States) do
			local humanoid = humanoidOf(player)
			local swimming = humanoid and humanoid:GetState() == Enum.HumanoidStateType.Swimming

			-- While downed or swimming, Vitals owns stamina entirely: it drains for swimming and must not
			-- regenerate here, or drowning could never start.
			if Vitals.IsDowned(player) or swimming then
				if state.state ~= "Normal" then setState(state, player, "Normal") end
			elseif state.state == "Run" then
				local stamina = Vitals.GetStamina(player) - STAMINA_DRAIN_PER_SEC * dt
				Vitals.SetStamina(player, stamina)
				if stamina <= 0 then
					state.forcedWalkUntil = os.clock() + FORCED_WALK_SECONDS
					setState(state, player, "ForcedWalk")
				end
			else
				Vitals.SetStamina(player, Vitals.GetStamina(player) + STAMINA_REGEN_PER_SEC * dt)
			end

			if state.state == "ForcedWalk" and os.clock() >= state.forcedWalkUntil then
				setState(state, player, (state.sprintIntent and Vitals.GetStamina(player) > 0) and "Run" or "Normal")
			end
		end
	end)
end
