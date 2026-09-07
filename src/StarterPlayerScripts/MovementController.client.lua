-- MovementController: sends movement intent to the server, never sets WalkSpeed itself — the server is the
-- only source of truth for speed/stamina (a modified client could otherwise just set WalkSpeed to anything).
-- See docs/superpowers/specs/2026-09-07-movement-stamina-design.md.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Remotes = require(game.ReplicatedStorage.Remotes)

local WALK_TAP_WINDOW = 0.3 -- seconds; Shift held shorter than this while idle counts as a tap (walk-toggle)

local player = Players.LocalPlayer

local shiftHeld = false
local moving = false
local sprintIntent = false
local shiftPressedAt = 0

local function humanoidOf(character)
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function updateSprintIntent()
	local next = shiftHeld and moving
	if next ~= sprintIntent then
		sprintIntent = next
		Remotes.SetSprintIntent:FireServer(sprintIntent)
	end
end

local function onCharacterAdded(character)
	local humanoid = humanoidOf(character)
	if not humanoid then return end
	moving = humanoid.MoveDirection.Magnitude > 0
	humanoid.Running:Connect(function(speed)
		moving = speed > 0
		updateSprintIntent()
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		shiftHeld = true
		shiftPressedAt = os.clock()
		updateSprintIntent()
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		shiftHeld = false
		updateSprintIntent()
		-- A short tap while standing still is the walk-toggle gesture (server re-verifies "standing still" —
		-- this client-side check just decides whether to fire the event at all).
		if not moving and os.clock() - shiftPressedAt < WALK_TAP_WINDOW then
			Remotes.ToggleWalk:FireServer()
		end
	end
end)
