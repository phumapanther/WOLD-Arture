-- MinigameGui: the two quick-time games, drawn and played.
--
-- Unlike ShopGui and CraftGui, this one is NOT a pure builder, and deliberately so: in a rhythm game the
-- drawing and the input are the same thing. A version that drew arrows here and timed presses in the
-- controller would need the two halves to agree, to the frame, on which arrow is current -- so the whole
-- widget owns its own play loop and reports one bit when it is over.
--
-- Two games live here:
--   Arrows     — press the directions in order, in time. Keyboard arrows, or the on-screen pad.
--   SkillCheck — stop the sweeping pointer inside the green zone. Click or space, or the big button.
--
-- The arrows are drawn as CHEVRONS BUILT FROM FRAMES rather than as text. Roblox's fonts render emoji but
-- turn geometric symbols (◼ ▸ ✕) into empty boxes, so an arrow glyph would have been four blank squares on
-- most machines. Two rotated bars in a container that is itself rotated gives all four directions from one
-- shape, with nothing to render but rectangles.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)
local Locale = require(script.Parent.Parent.Locale)
local L, Show = Locale.L, Locale.Show

local STONE = Color3.fromRGB(30, 32, 40)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)
local DONE = Color3.fromRGB(120, 206, 128)
local WAITING = Color3.fromRGB(92, 96, 110)
local MISS = Color3.fromRGB(206, 72, 62)

-- The keys the arrow game answers to, and the rotation that turns the one chevron shape into that direction.
local DIRECTIONS = {
	Up = { rotation = 0, keys = { Enum.KeyCode.Up, Enum.KeyCode.W } },
	Right = { rotation = 90, keys = { Enum.KeyCode.Right, Enum.KeyCode.D } },
	Down = { rotation = 180, keys = { Enum.KeyCode.Down, Enum.KeyCode.S } },
	Left = { rotation = 270, keys = { Enum.KeyCode.Left, Enum.KeyCode.A } },
}

-- WASD is offered alongside the arrow keys because a player already has their left hand there for walking,
-- and reaching across for the arrow cluster mid-rhythm is its own small punishment. Looked up once, into a
-- flat table, so a keypress is one index rather than a search.
local KEY_TO_DIRECTION = {}
for name, spec in pairs(DIRECTIONS) do
	for _, key in ipairs(spec.keys) do KEY_TO_DIRECTION[key] = name end
end

local MinigameGui = {}
MinigameGui.__index = MinigameGui

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

--------------------------------------------------------------------------------
-- The chevron
--------------------------------------------------------------------------------

-- One arrow: two bars meeting at a point, in a square container. The container's Rotation is what aims it, so
-- "down" is the same shape turned half a turn rather than a second set of coordinates to get wrong.
local function chevron(parent, size, colour)
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromOffset(size, size)
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Parent = parent

	local length = size * 0.53
	local thickness = math.max(4, size * 0.15)
	local bars = {}
	for i, spec in ipairs({ { x = 0.325, angle = -49 }, { x = 0.675, angle = 49 } }) do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(spec.x, 0.5)
		bar.Size = UDim2.fromOffset(length, thickness)
		bar.Rotation = spec.angle
		bar.BackgroundColor3 = colour
		bar.BorderSizePixel = 0
		bar.Parent = box
		corner(bar, UDim.new(1, 0))
		bars[i] = bar
	end

	return box, bars
end

local function paint(bars, colour)
	for _, bar in ipairs(bars) do bar.BackgroundColor3 = colour end
end

--------------------------------------------------------------------------------

function MinigameGui.new()
	local self = setmetatable({}, MinigameGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "MinigameGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- Above every counter and the map: a minigame is the only thing happening while it is up.
	gui.DisplayOrder = 40
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	-- A transparent button over the whole screen, for one reason: a GuiObject consumes the click, which makes
	-- UserInputService report gameProcessed, which is what stops the same click ALSO swinging the player's
	-- weapon while they are stopping the pointer. It is the catch, not the decoration.
	local swallow = Instance.new("TextButton")
	swallow.Name = "Swallow"
	swallow.Size = UDim2.fromScale(1, 1)
	swallow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	swallow.BackgroundTransparency = 0.72
	swallow.BorderSizePixel = 0
	swallow.Text = ""
	swallow.AutoButtonColor = false
	swallow.Parent = gui
	self.swallow = swallow

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.42)
	panel.Size = UDim2.fromOffset(420, 168)
	panel.BackgroundColor3 = STONE
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	Responsive.Scale(panel)
	self.panel = panel

	local edge = Instance.new("UIStroke")
	edge.Color = RUNE
	edge.Transparency = 0.5
	edge.Thickness = 2
	edge.Parent = panel
	self.edge = edge

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(0, 10)
	title.Size = UDim2.new(1, 0, 0, 20)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextColor3 = RUNE
	title.Text = ""
	title.Parent = panel
	self.title = title

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -8)
	hint.Size = UDim2.new(1, -20, 0, 16)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 11
	hint.TextColor3 = TEXT_MUTED
	hint.Text = ""
	hint.Parent = panel
	self.hint = hint

	-- Where each game builds its own pieces. Cleared between attempts rather than hidden, because the two
	-- games share nothing but the frame around them.
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundTransparency = 1
	stage.Position = UDim2.fromOffset(0, 34)
	stage.Size = UDim2.new(1, 0, 1, -58)
	stage.Parent = panel
	self.stage = stage

	-- The on-screen controls, outside the panel and lower down, where a thumb actually is.
	local pad = Instance.new("Frame")
	pad.Name = "TouchPad"
	pad.AnchorPoint = Vector2.new(0.5, 1)
	pad.Position = UDim2.new(0.5, 0, 1, -28)
	pad.Size = UDim2.fromOffset(190, 132)
	pad.BackgroundTransparency = 1
	pad.Visible = false
	pad.Parent = gui
	self.pad = pad

	self.touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	self.connections = {}
	self.active = nil
	return self
end

--------------------------------------------------------------------------------
-- Housekeeping
--------------------------------------------------------------------------------

function MinigameGui:clear()
	for _, connection in ipairs(self.connections) do
		if typeof(connection) == "RBXScriptConnection" then connection:Disconnect() end
	end
	self.connections = {}
	-- Unbound whatever the attempt sank. Arrow keys WALK the character by default, so the arrow game has to
	-- take them off the movement system for its duration -- and must give them back however it ends.
	ContextActionService:UnbindAction("WOLD_MinigameArrows")

	for _, child in ipairs(self.stage:GetChildren()) do child:Destroy() end
	for _, child in ipairs(self.pad:GetChildren()) do child:Destroy() end
	self.pad.Visible = false
end

-- The one way out. Plays the ending sound, shows the result for a beat, then hands the bit to whoever asked.
function MinigameGui:finish(success)
	local attempt = self.active
	if not attempt then return end
	self.active = nil
	self:clear()

	UiSound.Play(success and "Ding" or "Fail")
	self.edge.Color = success and DONE or MISS
	self.title.Text = success and L("สำเร็จ!") or L("พลาด!")
	self.title.TextColor3 = success and DONE or MISS
	self.hint.Text = ""

	-- The panel stays up for a moment on the answer rather than vanishing on the keypress: a window that
	-- disappears in the same frame as the press leaves the player unsure which of the two things happened.
	task.delay(0.55, function()
		if self.active then return end -- another attempt started in the meantime; it owns the panel now
		self.gui.Enabled = false
		self.edge.Color = RUNE
		self.title.TextColor3 = RUNE
	end)

	if attempt.onFinish then
		local ok, err = pcall(attempt.onFinish, success)
		if not ok then warn("[MinigameGui] finish handler failed:", err) end
	end
end

function MinigameGui:Cancel()
	if not self.active then return end
	local attempt = self.active
	self.active = nil
	self:clear()
	self.gui.Enabled = false
	if attempt.onFinish then pcall(attempt.onFinish, false) end
end

function MinigameGui:IsActive()
	return self.active ~= nil
end

--------------------------------------------------------------------------------
-- A touch button
--------------------------------------------------------------------------------

function MinigameGui:touchButton(position, size, direction, text, onPress)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = position
	b.Size = size
	b.BackgroundColor3 = Color3.fromRGB(52, 56, 68)
	b.BackgroundTransparency = 0.15
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextColor3 = TEXT_LIGHT
	b.Text = text or ""
	b.Parent = self.pad
	corner(b, UDim.new(0, 10))

	if direction then
		local box = chevron(b, size.X.Offset * 0.6, TEXT_LIGHT)
		box.Rotation = DIRECTIONS[direction].rotation
	end

	b.Activated:Connect(onPress)
	return b
end

--------------------------------------------------------------------------------
-- Arrows
--------------------------------------------------------------------------------

function MinigameGui:StartArrows(spec, onFinish)
	if self.active then self:Cancel() end
	self:clear()

	local sequence = spec.sequence or {}
	if #sequence == 0 then
		if onFinish then onFinish(false) end
		return
	end

	self.active = { onFinish = onFinish }
	self.edge.Color = RUNE
	self.title.TextColor3 = RUNE
	self.title.Text = spec.title and Show(spec.title) or L("กดตามจังหวะ")
	self.hint.Text = self.touch and L("แตะปุ่มให้ตรงลูกศรที่สว่าง")
		or L("กดลูกศร (หรือ WASD) ให้ตรงกับตัวที่สว่าง")
	self.gui.Enabled = true

	----------------------------------------------------------------------------
	-- The row
	----------------------------------------------------------------------------

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, 4)
	row.Size = UDim2.new(1, -24, 0, 48)
	row.Parent = self.stage

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row

	-- Sized to fit however many arrows there are, so an eight-arrow sequence is smaller rather than clipped.
	local cell = math.clamp(math.floor(380 / #sequence) - 8, 26, 46)

	local marks = {}
	for i, direction in ipairs(sequence) do
		local holder = Instance.new("Frame")
		holder.LayoutOrder = i
		holder.Size = UDim2.fromOffset(cell, cell)
		holder.BackgroundTransparency = 1
		holder.Parent = row

		local box, bars = chevron(holder, cell, WAITING)
		box.Rotation = DIRECTIONS[direction].rotation
		marks[i] = { box = box, bars = bars }
	end

	----------------------------------------------------------------------------
	-- The beat
	----------------------------------------------------------------------------

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 0, 60)
	track.Size = UDim2.new(1, -60, 0, 8)
	track.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	track.BorderSizePixel = 0
	track.Parent = self.stage
	corner(track, UDim.new(1, 0))

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = RUNE
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, UDim.new(1, 0))

	local index = 1
	local perStep = spec.secondsPerStep or 1.1
	local stepEndsAt = os.clock() + (spec.leadIn or 0.8) + perStep

	local function highlight()
		for i, mark in ipairs(marks) do
			if i < index then
				paint(mark.bars, DONE)
				mark.box.Size = UDim2.fromOffset(cell * 0.8, cell * 0.8)
			elseif i == index then
				paint(mark.bars, RUNE)
				mark.box.Size = UDim2.fromOffset(cell, cell)
			else
				paint(mark.bars, WAITING)
				mark.box.Size = UDim2.fromOffset(cell * 0.8, cell * 0.8)
			end
		end
	end
	highlight()

	local function press(direction)
		if not self.active then return end
		if direction ~= sequence[index] then
			paint(marks[index].bars, MISS)
			return self:finish(false)
		end
		UiSound.Play("Ding")
		index += 1
		if index > #sequence then
			return self:finish(true)
		end
		stepEndsAt = os.clock() + perStep
		highlight()
	end

	-- The clock. Running out on the current arrow is a miss, exactly like pressing the wrong one -- that is
	-- what makes it a rhythm game rather than a sequence to type at leisure.
	table.insert(self.connections, RunService.RenderStepped:Connect(function()
		if not self.active then return end
		local remaining = stepEndsAt - os.clock()
		if remaining <= 0 then
			paint(marks[index].bars, MISS)
			return self:finish(false)
		end
		fill.Size = UDim2.fromScale(math.clamp(remaining / perStep, 0, 1), 1)
	end))

	----------------------------------------------------------------------------
	-- Input
	----------------------------------------------------------------------------

	-- Bound through ContextActionService at a high priority rather than read from UserInputService, because
	-- the arrow keys WALK the character by default. Sinking them here takes them off the movement system for
	-- exactly as long as the game lasts, and `clear` always gives them back.
	ContextActionService:BindActionAtPriority("WOLD_MinigameArrows", function(_, state, input)
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
		local direction = KEY_TO_DIRECTION[input.KeyCode]
		if direction then press(direction) end
		return Enum.ContextActionResult.Sink
	end, false, 5000,
		Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
		Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D)

	if self.touch then
		self.pad.Visible = true
		local size = UDim2.fromOffset(56, 56)
		self:touchButton(UDim2.fromOffset(95, 30), size, "Up", nil, function() press("Up") end)
		self:touchButton(UDim2.fromOffset(95, 100), size, "Down", nil, function() press("Down") end)
		self:touchButton(UDim2.fromOffset(30, 66), size, "Left", nil, function() press("Left") end)
		self:touchButton(UDim2.fromOffset(160, 66), size, "Right", nil, function() press("Right") end)
	end
end

--------------------------------------------------------------------------------
-- Skill check
--------------------------------------------------------------------------------

function MinigameGui:StartSkillCheck(spec, onFinish)
	if self.active then self:Cancel() end
	self:clear()

	self.active = { onFinish = onFinish }
	self.edge.Color = RUNE
	self.title.TextColor3 = RUNE
	self.title.Text = spec.title and Show(spec.title) or L("ตีให้ตรงจังหวะ")
	self.hint.Text = self.touch and L("แตะปุ่ม ตี ตอนเข็มอยู่ในแถบเขียว")
		or L("คลิกซ้าย (หรือเว้นวรรค) ตอนเข็มอยู่ในแถบเขียว")
	self.gui.Enabled = true

	-- The warning that a check has appeared. Loud on purpose: it pops up in the middle of a repair the player
	-- was not looking at, and there is no other cue that the next second matters.
	UiSound.Play("SkillCheck")

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.fromScale(0.5, 0.45)
	track.Size = UDim2.new(1, -60, 0, 30)
	track.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	track.BorderSizePixel = 0
	track.Parent = self.stage
	corner(track, UDim.new(0, 8))

	local zone = Instance.new("Frame")
	zone.Position = UDim2.fromScale(spec.zoneStart or 0.6, 0)
	zone.Size = UDim2.fromScale((spec.zoneEnd or 0.8) - (spec.zoneStart or 0.6), 1)
	zone.BackgroundColor3 = DONE
	zone.BackgroundTransparency = 0.25
	zone.BorderSizePixel = 0
	zone.Parent = track
	corner(zone, UDim.new(0, 6))

	local pointer = Instance.new("Frame")
	pointer.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.Position = UDim2.fromScale(0, 0.5)
	pointer.Size = UDim2.new(0, 6, 1, 8)
	pointer.BackgroundColor3 = TEXT_LIGHT
	pointer.BorderSizePixel = 0
	pointer.ZIndex = 3
	pointer.Parent = track
	corner(pointer, UDim.new(1, 0))

	local position, direction = 0, 1
	local speed = spec.speed or 0.8
	local deadline = os.clock() + (spec.timeout or 6)

	table.insert(self.connections, RunService.RenderStepped:Connect(function(delta)
		if not self.active then return end
		if os.clock() >= deadline then
			return self:finish(false)
		end
		-- Bounced rather than wrapped: a pointer that jumps back to the left edge gives the player a free
		-- half-track of warning, while one that turns round is the same problem from both sides.
		position += delta * speed * 2 * direction
		if position >= 1 then
			position, direction = 1, -1
		elseif position <= 0 then
			position, direction = 0, 1
		end
		pointer.Position = UDim2.fromScale(position, 0.5)
	end))

	local function strike()
		if not self.active then return end
		local hit = position >= (spec.zoneStart or 0.6) and position <= (spec.zoneEnd or 0.8)
		-- Frozen where it was struck, so the player can see how close they were. The connection is dropped by
		-- `clear` a moment later.
		self:finish(hit)
	end

	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, processed)
		if not self.active then return end
		-- `processed` is ignored for the mouse on purpose: the swallow button under the panel consumes every
		-- click, which is exactly what stops the same click swinging a weapon -- but it also means every click
		-- arrives here already "processed". The key is checked normally.
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			strike()
		elseif not processed and input.KeyCode == Enum.KeyCode.Space then
			strike()
		end
	end))

	if self.touch then
		self.pad.Visible = true
		-- "ตี" มีคำแปลเดิมแล้ว = "Enhance" (ปุ่มตีบวกที่ช่างตีเหล็ก) · ปุ่มนี้คือตีจังหวะ จึงแปลจากกุญแจแยก
		-- ไทยยังขึ้น "ตี" เหมือนเดิมทุกไบต์
		local strikeLabel = L("ตี (ปุ่มมินิเกม)")
		if Locale.Current() == "th" then strikeLabel = "ตี" end -- locale: skip (กุญแจแปลแยก ไทยไม่เปลี่ยน)
		self:touchButton(UDim2.fromOffset(95, 66), UDim2.fromOffset(120, 60), nil, strikeLabel, strike)
	end
end

return MinigameGui
