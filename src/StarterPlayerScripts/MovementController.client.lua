-- MovementController: sends movement intent to the server, never sets WalkSpeed itself — the server is the
-- only source of truth for speed/stamina (a modified client could otherwise just set WalkSpeed to anything).
-- See docs/superpowers/specs/2026-09-07-movement-stamina-design.md.
--
-- Two intent sources:
--  * Keyboard: hold Shift + move = sprint; tap Shift while idle = walk-toggle.
--  * Analog sticks (gamepad thumbstick, mobile touch thumbstick) — "option B": push to the edge = sprint,
--    light push = walk. "Walk" needs no code here: the engine already scales speed by stick deflection
--    (verified: Humanoid:Move at 0.5 magnitude moves at exactly half WalkSpeed). No walk-toggle on sticks.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Remotes = require(game.ReplicatedStorage.Remotes)

local WALK_TAP_WINDOW = 0.3 -- seconds; Shift held shorter than this while idle counts as a tap (walk-toggle)

-- Analog stick thresholds (tune here). Hysteresis so a stick hovering near the edge doesn't flicker sprint
-- on/off; the sustain window so a quick flick to the edge just to start moving isn't read as a sprint request.
local ANALOG_SPRINT_ON = 0.9
local ANALOG_SPRINT_OFF = 0.7
local ANALOG_SUSTAIN = 0.25

local player = Players.LocalPlayer

local shiftHeld = false
local moving = false
local sprintIntent = false
local shiftPressedAt = 0

local gamepadMag = 0 -- left-stick deflection 0..1, straight from UserInputService (exact; no PlayerModule involved)
local analogSprint = false
local analogAboveSince = nil

local function humanoidOf(character)
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function updateSprintIntent()
	local next = (shiftHeld and moving) or analogSprint
	if next ~= sprintIntent then
		sprintIntent = next
		Remotes.SetSprintIntent:FireServer(sprintIntent)
	end
end

-- Touch thumbstick deflection isn't exposed by the engine: Humanoid.MoveDirection is always a unit vector, and
-- the modern PlayerModule (StarterPlayer.PlayerModule, driven from the CoreScript VM) no longer offers
-- GetControls()/GetMoveVector() — requiring its ControlModule from here builds a dead duplicate and appears to
-- break the real controls (see CLAUDE.md). ponytail: infer deflection as horizontal speed / WalkSpeed instead.
-- Exact on flat ground; reads low uphill / in water and can read high while airborne. Upgrade path if that
-- bites: read the DynamicThumbstick's own GUI (ThumbstickEnd offset from ThumbstickStart under
-- PlayerGui.TouchGui), or fork the PlayerModule into StarterPlayerScripts so its ControlModule lives in this VM.
local function touchInferredMag()
	if UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch then return 0 end
	local character = player.Character
	local humanoid = humanoidOf(character)
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp or humanoid.WalkSpeed <= 0 then return 0 end
	local v = hrp.AssemblyLinearVelocity
	return math.min(1, Vector3.new(v.X, 0, v.Z).Magnitude / humanoid.WalkSpeed)
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

-- Keyboard: Shift hold / tap
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

-- Gamepad: raw left-stick deflection (Position.X/Y are each -1..1)
UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Thumbstick1 then
		gamepadMag = Vector2.new(input.Position.X, input.Position.Y).Magnitude
	end
end)
UserInputService.GamepadDisconnected:Connect(function()
	gamepadMag = 0
end)

-- Analog sprint decision, evaluated every frame from whichever stick source is active. The server still owns
-- the state machine — this only decides what intent to report.
RunService.Heartbeat:Connect(function()
	local mag = math.max(gamepadMag, touchInferredMag())
	if analogSprint then
		if mag < ANALOG_SPRINT_OFF then
			analogSprint = false
			analogAboveSince = nil
		end
	elseif mag >= ANALOG_SPRINT_ON then
		analogAboveSince = analogAboveSince or os.clock()
		if os.clock() - analogAboveSince >= ANALOG_SUSTAIN then analogSprint = true end
	else
		analogAboveSince = nil
	end
	updateSprintIntent()
end)
