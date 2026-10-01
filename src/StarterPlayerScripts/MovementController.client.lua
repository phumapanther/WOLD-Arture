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
-- held before sprinting, and drop it as soon as the thumb eases off.
--
-- DISTANCE, not time: sprinting on touch is decided purely by how far the stick is dragged. Holding a
-- half-pushed stick must never build up into a sprint no matter how long it is held
-- ("ลากค้างไม่ต้องวิ่ง ต้องลากออกยาวเท่านั้น"), so the sustain window is zero here and the gate is the
-- deflection alone. The stick must be dragged essentially to the rim, and sprint drops the moment it eases
-- back inside TOUCH_SPRINT_OFF.
local TOUCH_SPRINT_ON = 0.98
local TOUCH_SPRINT_OFF = 0.90
local TOUCH_SUSTAIN = 0

local player = Players.LocalPlayer

local shiftHeld = false
local moving = false
local sprintIntent = false
local shiftPressedAt = 0

local gamepadMag = 0 -- left-stick deflection 0..1, straight from UserInputService (exact; no PlayerModule involved)
local analogSprint = false
local analogAboveSince = nil

-- Raw touch drag, used only when the DynamicThumbstick (which has no ring to measure) is the active control.
-- Pixels the stock control needs for full speed; it scales the thumbstick with screen size, so this is
-- expressed against the same 1280-wide baseline the GUIs use.
local DYNAMIC_THUMBSTICK_RADIUS = 70
local touchDragStart = nil
local touchDragCurrent = nil

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

	-- DynamicThumbstick draws no persistent ring, so measure the drag ourselves from the raw touch: how far the
	-- finger has travelled from where it first went down, over the same radius the stock control uses for full
	-- speed. Humanoid.MoveDirection is NOT usable as a fallback here — it is always a unit vector, so it reads
	-- 1.0 for any movement at all and every drag would sprint.
	if touchDragStart and touchDragCurrent then
		-- Not walking = not a thumbstick drag (a finger scrolling a left-side panel, say), so no sprint request.
		local humanoid = humanoidOf(player.Character)
		if not humanoid or humanoid.MoveDirection.Magnitude < 0.1 then return 0 end
		local delta = touchDragCurrent - touchDragStart
		-- InputObject.Position is a Vector3 whose Z is unused for touch; drop it or the magnitude is wrong.
		local pixels = Vector2.new(delta.X, delta.Y).Magnitude
		-- The stock control sizes itself against the screen, so scale the radius the same way the GUIs do.
		local camera = workspace.CurrentCamera
		local widthScale = camera and math.clamp(camera.ViewportSize.X / 1280, 0.5, 1) or 1
		return math.min(1, pixels / (DYNAMIC_THUMBSTICK_RADIUS * widthScale))
	end
	return 0
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

-- Touch: follow ONE finger's drag so the DynamicThumbstick path above has a real distance to measure.
--
-- ⚠️ gameProcessed is NOT a filter here (2026-09-25): the DynamicThumbstick takes its finger through
-- ContextActionService, so that touch arrives with gameProcessed = true every time -- the old guard threw away
-- the very drag it existed to measure, and touch could never sprint (so never slide) on that stick -- which
-- is what a phone gets by default (all three places are DevTouchMovementMode = UserChoice, checked 2026-09-25).
-- The left-half test below keeps our right-hand buttons out instead, and the finger is tracked by its own
-- InputObject so a right thumb turning the camera no longer moves the "drag" either.
local dragInput = nil
UserInputService.TouchStarted:Connect(function(input)
	if dragInput then return end
	-- Movement lives on the left half of the screen; a touch on the right is the camera or our action buttons.
	local camera = workspace.CurrentCamera
	if camera and input.Position.X > camera.ViewportSize.X / 2 then return end
	dragInput = input
	touchDragStart = input.Position
	touchDragCurrent = input.Position
end)

UserInputService.TouchMoved:Connect(function(input)
	if input ~= dragInput then return end
	touchDragCurrent = input.Position
end)

UserInputService.TouchEnded:Connect(function(input)
	if input ~= dragInput then return end
	dragInput, touchDragStart, touchDragCurrent = nil, nil, nil
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

-- **ถอยหลังในสนาม** (เดินช้าลง · PlayerMovement): ตัดสินในเครื่องนี้ แล้วบอกเซิร์ฟเฉพาะตอนเปลี่ยน (2026-10-01 ผู้ใช้แจ้งเดินกระตุก)
-- เดิมเซิร์ฟเทียบทิศเดินกับทิศตัวเอง ซึ่งสองค่านี้มาถึงเซิร์ฟคนละจังหวะ เดินข้างพลางหมุนกล้อง = ค่าแกว่งข้ามเส้น
-- ความเร็วสลับเร็ว↔ช้าทุกเฟรม · ที่นี่สองค่ามาจากเฟรมเดียวกัน + มีช่วงกันแกว่ง (เข้า < -0.45 · ออก > -0.15)
local backpedal = false
RunService.Heartbeat:Connect(function()
	if workspace:GetAttribute("ArenaMode") ~= true then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root then return end
	local move = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local dot = (move.Magnitude > 0.1 and look.Magnitude > 0.1) and move.Unit:Dot(look.Unit) or 0
	local want = if backpedal then dot < -0.15 else dot < -0.45
	if want ~= backpedal then
		backpedal = want
		Remotes.SetBackpedal:FireServer(want)
	end
end)
