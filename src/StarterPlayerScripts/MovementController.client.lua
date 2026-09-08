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

-- Touch needs a much harder push than a gamepad: a thumb resting anywhere past the middle of the ring was
-- tripping the gamepad thresholds constantly ("ลากไปนิดเดียวก็วิ่งแล้ว"). These demand a near-pinned stick
-- held for twice as long before sprinting, and drop it as soon as the thumb eases off.
local TOUCH_SPRINT_ON = 0.97
local TOUCH_SPRINT_OFF = 0.85
local TOUCH_SUSTAIN = 0.5

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
-- break the real controls (see CLAUDE.md).
--
-- So read the thumbstick's own GUI instead: the stock touch controls draw ThumbstickEnd (the knob) offset from
-- ThumbstickStart (the ring) inside PlayerGui.TouchGui, and that offset in pixels over the ring's radius IS
-- the deflection. This replaced an earlier "horizontal speed / WalkSpeed" estimate, which saturated at 1.0
-- the moment the player reached full speed — so ANY sustained push read as a full-edge push and sprinted.
local function touchThumbstickMag()
	if UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch then return 0 end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	if not frame then return 0 end

	-- Classic thumbstick: an explicit start ring and end knob.
	local startRing = frame:FindFirstChild("ThumbstickFrame", true)
	local knob = startRing and startRing:FindFirstChild("ThumbstickEnd")
	if startRing and knob then
		local radius = startRing.AbsoluteSize.X / 2
		if radius <= 0 then return 0 end
		local centre = startRing.AbsolutePosition + startRing.AbsoluteSize / 2
		local knobCentre = knob.AbsolutePosition + knob.AbsoluteSize / 2
		return math.min(1, (knobCentre - centre).Magnitude / radius)
	end

	-- DynamicThumbstick: no persistent ring, so fall back to the engine's own move vector magnitude, which for
	-- touch IS the deflection (deflection / radiusOfMaxSpeed, clamped to 1 — verified in Play).
	local humanoid = humanoidOf(player.Character)
	if not humanoid then return 0 end
	return math.min(1, humanoid.MoveDirection.Magnitude)
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
	local touchMag = touchThumbstickMag()
	local usingTouch = touchMag > 0 and gamepadMag <= 0
	local mag = math.max(gamepadMag, touchMag)
	local on = usingTouch and TOUCH_SPRINT_ON or ANALOG_SPRINT_ON
	local off = usingTouch and TOUCH_SPRINT_OFF or ANALOG_SPRINT_OFF
	local sustain = usingTouch and TOUCH_SUSTAIN or ANALOG_SUSTAIN

	if analogSprint then
		if mag < off then
			analogSprint = false
			analogAboveSince = nil
		end
	elseif mag >= on then
		analogAboveSince = analogAboveSince or os.clock()
		if os.clock() - analogAboveSince >= sustain then analogSprint = true end
	else
		analogAboveSince = nil
	end
	updateSprintIntent()
end)
