-- MovementController: sends movement intent to the server, never sets WalkSpeed itself — the server is the
-- only source of truth for speed/stamina (a modified client could otherwise just set WalkSpeed to anything).
-- See docs/superpowers/specs/2026-09-07-movement-stamina-design.md.
--
-- Two intent sources:
--  * Keyboard: hold Shift + move = sprint; tap Shift while idle = walk-toggle.
--  * Gamepad thumbstick — "option B": push to the edge = sprint, light push = walk. "Walk" needs no code here:
--    the engine already scales speed by stick deflection (verified: Humanoid:Move at 0.5 magnitude moves at
--    exactly half WalkSpeed). No walk-toggle on sticks.
--  * Touch (มือถือ): **ปุ่มวิ่ง 🏃 กดค้าง** (TouchActionGui · ผู้ใช้สั่ง 2026-10-02 แทนการลากจอยสุดขอบ) —
--    TouchActionController ตั้งแอตทริบิวต์ท้องถิ่น `WOLD_SprintButton` ที่นี่อ่านทุกเฟรม · จอยมือถือเดินอย่างเดียวแล้ว
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
	local button = player:GetAttribute("WOLD_SprintButton") == true
	local next = (shiftHeld and moving) or analogSprint or (button and moving)
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
	local mag = gamepadMag
	local on, off, sustain = ANALOG_SPRINT_ON, ANALOG_SPRINT_OFF, ANALOG_SUSTAIN

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
