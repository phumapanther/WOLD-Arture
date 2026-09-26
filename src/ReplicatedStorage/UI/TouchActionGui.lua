-- TouchActionGui: the on-screen action buttons for touch devices — attack, and a roll button that becomes a
-- slide button while sprinting. Pure UI builder; the controller wires up what the presses do.
--
-- Layout, per the user's spec: the attack button sits to the RIGHT of Roblox's own jump button and is twice
-- its size; the jump button is nudged right to make room; the roll/slide button sits ABOVE the attack button
-- at the jump button's size.
--
-- The roll/slide button relabels itself to SLIDE while sprinting; both it and the Ctrl key resolve to the
-- same action, decided server-side from the player's current speed.
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)

local TouchActionGui = {}
TouchActionGui.__index = TouchActionGui

-- Roblox's own jump button is 90x90 at its smallest and sits a fixed distance from the bottom-right corner.
-- These are matched to it so the cluster reads as one set of controls rather than a separate overlay.
local JUMP_SIZE = 90
-- Both buttons were halved on request: the attack button is still twice the roll button, just a smaller pair
-- overall, so the cluster covers less of a phone screen.
local ATTACK_SIZE = JUMP_SIZE -- was JUMP_SIZE * 2
local ROLL_SIZE = JUMP_SIZE / 2 -- was JUMP_SIZE
local EDGE_MARGIN = 30
local GAP = 14

-- Black glass, exactly the lobby panel's colour and transparency (Responsive.Glass*), so the buttons look
-- like the same material as the rest of the UI rather than a separate grey overlay. No greys and no hues:
-- the two actions are told apart by size, position and glyph.
local ATTACK_COLOR = Responsive.GlassColor
local ROLL_COLOR = Responsive.GlassColor
local SLIDE_COLOR = Responsive.GlassColor
local BUTTON_TRANSPARENCY = Responsive.GlassTransparency
local TEXT_LIGHT = Color3.fromRGB(232, 232, 236)
local RIM = Color3.fromRGB(120, 122, 132)

-- A rounded rectangle inside a button, positioned in the button's own 0..1 space. Every icon below is
-- built from these, so an icon is a handful of lines rather than an asset to upload and keep track of.
local function bar(parent, x, y, w, h, rotation, radius, transparency)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.Rotation = rotation or 0
	f.BackgroundColor3 = TEXT_LIGHT
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	if radius then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(radius, 0)
		c.Parent = f
	end
	return f
end

-- Each icon draws into a square holder so it scales with the button.
local Icons = {}

-- Backpack: a body, a lid flap and a shoulder strap.
function Icons.bag(holder)
	bar(holder, 0.5, 0.58, 0.52, 0.46, 0, 0.18)          -- body
	bar(holder, 0.5, 0.34, 0.42, 0.16, 0, 0.3)           -- lid
	bar(holder, 0.5, 0.24, 0.22, 0.14, 0, 0.5, 0.35)     -- handle
	bar(holder, 0.5, 0.62, 0.16, 0.1, 0, 0.3, 0.55)      -- buckle
end

-- Speaking stone: a gem outline with a spark inside.
function Icons.stone(holder)
	local gem = bar(holder, 0.5, 0.5, 0.46, 0.46, 45, 0.16)
	gem.BackgroundTransparency = 0.15
	bar(holder, 0.5, 0.5, 0.16, 0.16, 45, 0.3, 0.55)
end

-- Roll: a curved arrow, suggested by three dashes around a circle.
function Icons.roll(holder)
	local ring = bar(holder, 0.5, 0.5, 0.5, 0.5, 0, 0.5)
	ring.BackgroundTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = TEXT_LIGHT
	stroke.Thickness = 2.5
	stroke.Parent = ring
	-- The arrow head, so it reads as rotation rather than a plain ring.
	bar(holder, 0.72, 0.28, 0.2, 0.09, 45, 0.3)
	bar(holder, 0.72, 0.28, 0.09, 0.2, 45, 0.3)
end

-- Slide: motion lines behind a leading edge, which reads as sliding low and fast.
function Icons.slide(holder)
	bar(holder, 0.62, 0.62, 0.34, 0.12, -18, 0.4)
	bar(holder, 0.36, 0.44, 0.3, 0.08, -18, 0.4, 0.3)
	bar(holder, 0.3, 0.3, 0.22, 0.07, -18, 0.4, 0.55)
end

-- Drop: an arrow pointing down out of a hand-sized bar.
function Icons.drop(holder)
	bar(holder, 0.5, 0.3, 0.1, 0.34, 0, 0.3)
	bar(holder, 0.42, 0.56, 0.1, 0.22, 45, 0.3)
	bar(holder, 0.58, 0.56, 0.1, 0.22, -45, 0.3)
	bar(holder, 0.5, 0.76, 0.44, 0.09, 0, 0.4, 0.3)
end

-- Skill: a four-pointed spark, which reads as "something magic happens" without committing to a particular
-- spell -- the skill a weapon casts depends on the weapon.
function Icons.skill(holder)
	bar(holder, 0.5, 0.5, 0.14, 0.62, 0, 0.4)
	bar(holder, 0.5, 0.5, 0.62, 0.14, 0, 0.4)
	bar(holder, 0.5, 0.5, 0.1, 0.4, 45, 0.3)
	bar(holder, 0.5, 0.5, 0.4, 0.1, 45, 0.3)
end

-- Attack: crossed blades.
function Icons.attack(holder)
	bar(holder, 0.5, 0.5, 0.12, 0.66, 42, 0.3)
	bar(holder, 0.5, 0.5, 0.12, 0.66, -42, 0.3)
	bar(holder, 0.5, 0.5, 0.2, 0.2, 45, 0.4, 0.4)
end

-- Replaces whatever an icon holder currently draws. Used when roll becomes slide.
local function setIcon(holder, name)
	for _, c in ipairs(holder:GetChildren()) do c:Destroy() end
	local draw = Icons[name]
	if draw then draw(holder) end
	holder:SetAttribute("Icon", name)
end

local function circle(parent, size, color, iconName)
	local btn = Instance.new("ImageButton")
	btn.Size = UDim2.fromOffset(size, size)
	btn.BackgroundColor3 = color
	btn.BackgroundTransparency = BUTTON_TRANSPARENCY
	btn.AutoButtonColor = true
	btn.Image = ""
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = btn

	-- No sheen gradient: any lift toward white would stop the fill from matching the lobby panel exactly,
	-- which is the whole point of sharing Responsive.Glass*. The rim alone gives the button its edge.

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Rim"
	stroke.Color = RIM
	stroke.Transparency = 0.45
	stroke.Thickness = 1.5
	stroke.Parent = btn

	-- A square holder centred in the circle, so the icon scales with the button.
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.58, 0.58)
	holder.BackgroundTransparency = 1
	holder.Parent = btn
	setIcon(holder, iconName)

	return btn, holder
end

-- ปุ่มวงกลมกระจกหน้าตาเดียวกับปุ่มมือถือในเกม ให้ที่อื่นใช้ (ปุ่มล็อบบี้ 🔮 🛠️) — คืน (ปุ่ม, กรอบไอคอน)
-- `iconName` = ชื่อไอคอนวาดด้วย Frame ในไฟล์นี้ ("stone" "bag" ...) หรือ nil แล้วใส่อะไรเองในกรอบ
function TouchActionGui.Circle(parent, size, iconName)
	return circle(parent, size, ROLL_COLOR, iconName)
end

function TouchActionGui.new()
	local self = setmetatable({}, TouchActionGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "TouchActionGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5 -- under the downed overlay (20), above the world
	gui.Enabled = false
	self.gui = gui

	-- Anchored to the bottom-right corner so it lands next to the jump button at any screen size.
	local cluster = Instance.new("Frame")
	cluster.Name = "Cluster"
	cluster.AnchorPoint = Vector2.new(1, 1)
	-- Shifted left to leave the corner for the bag/social column.
	cluster.Position = UDim2.new(1, -(EDGE_MARGIN + ROLL_SIZE + GAP), 1, -EDGE_MARGIN)
	-- Tall enough for all four: attack, roll, skill, and the drop button that appears above them while
	-- carrying. Sized for the full stack even though drop is usually hidden, because a Frame that grew when
	-- the button appeared would push the whole cluster off the bottom of the screen.
	cluster.Size = UDim2.fromOffset(ATTACK_SIZE,
		ATTACK_SIZE + GAP + ROLL_SIZE + GAP + ROLL_SIZE + GAP + ROLL_SIZE)
	cluster.BackgroundTransparency = 1
	cluster.Parent = gui
	self.cluster = cluster

	-- Attack: bottom of the cluster, the big one.
	local attack = circle(cluster, ATTACK_SIZE, ATTACK_COLOR, "attack")
	attack.Name = "AttackButton"
	attack.AnchorPoint = Vector2.new(1, 1)
	attack.Position = UDim2.new(1, 0, 1, 0)
	self.attackButton = attack

	-- Roll/slide: directly above the attack button, jump-button sized. Right-aligned with it.
	local roll, rollIcon = circle(cluster, ROLL_SIZE, ROLL_COLOR, "roll")
	roll.Name = "RollButton"
	roll.AnchorPoint = Vector2.new(1, 1)
	roll.Position = UDim2.new(1, 0, 1, -(ATTACK_SIZE + GAP))
	self.rollButton = roll
	self.rollIcon = rollIcon

	-- Skill: above the roll button, where the user asked for it. Always there, because a skill is keyboard-Q
	-- on desktop and touch had no way to reach it at all -- the same gap the drop button was added to close.
	local skill = circle(cluster, ROLL_SIZE, ROLL_COLOR, "skill")
	skill.Name = "SkillButton"
	skill.AnchorPoint = Vector2.new(1, 1)
	skill.Position = UDim2.new(1, 0, 1, -(ATTACK_SIZE + GAP + ROLL_SIZE + GAP))
	self.skillButton = skill

	-- Drop: only visible while carrying someone, so it sits at the TOP of the stack rather than in the
	-- middle. Putting it below the skill button would make the skill button jump up and down as a carry
	-- starts and ends, and a control that moves under the thumb is worse than one that is simply higher up.
	local drop, dropIcon = circle(cluster, ROLL_SIZE, ROLL_COLOR, "drop")
	drop.Name = "DropButton"
	drop.AnchorPoint = Vector2.new(1, 1)
	drop.Position = UDim2.new(1, 0, 1, -(ATTACK_SIZE + GAP + ROLL_SIZE + GAP + ROLL_SIZE + GAP))
	drop.Visible = false
	self.dropButton = drop
	self.dropIcon = dropIcon

	-- Bag: its own cluster hard against the bottom-right corner, to the RIGHT of the action cluster, so it
	-- never moves as the drop button appears and disappears above.
	local sideColumn = Instance.new("Frame")
	sideColumn.Name = "SideColumn"
	sideColumn.AnchorPoint = Vector2.new(1, 1)
	sideColumn.Position = UDim2.new(1, -6, 1, -EDGE_MARGIN)
	sideColumn.Size = UDim2.fromOffset(ROLL_SIZE, ROLL_SIZE * 2 + GAP)
	sideColumn.BackgroundTransparency = 1
	sideColumn.Parent = gui

	local bag = circle(sideColumn, ROLL_SIZE, ROLL_COLOR, "bag")
	bag.Name = "BagButton"
	bag.AnchorPoint = Vector2.new(1, 1)
	bag.Position = UDim2.new(1, 0, 1, 0)
	self.bagButton = bag

	-- The speaking stone, directly above the bag and the same size: the user asked for a small button in
	-- the bottom-right corner matching the bag button. Same column, so neither moves as the other appears.
	local social = circle(sideColumn, ROLL_SIZE, ROLL_COLOR, "stone")
	social.Name = "SocialButton"
	social.AnchorPoint = Vector2.new(1, 1)
	social.Position = UDim2.new(1, 0, 1, -(ROLL_SIZE + GAP))
	self.socialButton = social

	return self
end

-- สนาม PVP (ผู้ใช้สั่ง 2026-09-25): ไม่มีกระเป๋า/หินเวทให้เปิด → คอลัมน์ขวาเป็น ร้าน (B) · สถิติ (Tab) · แผนที่ (M)
-- และช่องบนสุดของกลุ่มปุ่มแอ็กชัน (ที่ของปุ่มวางคนที่อุ้ม ซึ่งสนามไม่มี) เป็นปุ่มใช้ยา (F)
-- `onAction(name)` รับ "shop" | "stats" | "map" | "potion" · ป้ายเป็นอีโมจิ ไม่ต้องอัปโหลดรูป
--
-- DisplayOrder 21: เหนือร้าน (18) กับแผนที่ (20) ให้ปุ่มเดียวกันกดปิดสิ่งที่เปิดไว้ได้ · ต่ำกว่าตารางจบเกม (22)
function TouchActionGui:SetArenaMode(onAction)
	self.gui.DisplayOrder = 21
	self.bagButton.Visible = false
	self.socialButton.Visible = false
	local column = self.bagButton.Parent
	column.Size = UDim2.fromOffset(ROLL_SIZE, ROLL_SIZE * 3 + GAP * 2)

	local function emojiButton(parent, emoji, action)
		local btn, holder = circle(parent, ROLL_SIZE, ROLL_COLOR, nil)
		btn.Name = action
		btn.AnchorPoint = Vector2.new(1, 1)
		local glyph = Instance.new("TextLabel")
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.BackgroundTransparency = 1
		glyph.TextScaled = true
		glyph.Text = emoji
		glyph.Parent = holder
		btn.MouseButton1Down:Connect(function() onAction(action) end)
		return btn
	end

	for i, spec in ipairs({ { "🛒", "shop" }, { "📊", "stats" }, { "🗺️", "map" } }) do
		emojiButton(column, spec[1], spec[2]).Position = UDim2.new(1, 0, 1, -((i - 1) * (ROLL_SIZE + GAP)))
	end
	emojiButton(self.cluster, "🧪", "potion").Position = self.dropButton.Position
end

function TouchActionGui:OnBag(callback)
	self.bagButton.MouseButton1Down:Connect(callback)
end

function TouchActionGui:OnSocial(callback)
	self.socialButton.MouseButton1Down:Connect(callback)
end

function TouchActionGui:OnDrop(callback)
	self.dropButton.MouseButton1Down:Connect(callback)
end

-- Shown only while actually carrying someone: a permanent "วาง" button with nothing to put down is noise.
function TouchActionGui:SetCarrying(carrying)
	self.dropButton.Visible = carrying and true or false
end

-- Nudges Roblox's own jump button left of our attack button, and matches its vertical centre. The jump button
-- is a CoreGui-owned instance that only exists once touch controls are built, so this retries until it shows
-- up and then keeps the offset applied across respawns.
function TouchActionGui:AnchorJumpButton()
	local player = Players.LocalPlayer

	-- Where the jump button belongs: left of the attack button, which itself sits left of the bag column, so
	-- the offset has to clear both or it lands underneath the attack button.
	local function place(jump)
		jump.AnchorPoint = Vector2.new(1, 1)
		jump.Position = UDim2.new(1, -(EDGE_MARGIN + ROLL_SIZE + GAP + ATTACK_SIZE + GAP), 1,
			-(EDGE_MARGIN + (ATTACK_SIZE - JUMP_SIZE) / 2))
	end

	-- Roblox REBUILDS or re-positions its touch controls on rotation, on every respawn (the arena respawns
	-- each round), and whenever ModalEnabled flips (the arena shop) — each resets the jump button to its own
	-- corner, under our buttons. Event-watching missed some of those (user report 2026-09-26: "next round the
	-- jump button moves under the other buttons"), so ONE loop re-places it twice a second instead: whatever
	-- moved it, it is back within half a second. Writing the same Position is free (no change event fires).
	if self._anchoring then return end
	self._anchoring = true
	task.spawn(function()
		while self.gui.Parent do
			local playerGui = player:FindFirstChildOfClass("PlayerGui")
			local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
			local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
			local jump = frame and frame:FindFirstChild("JumpButton")
			if jump and self.gui.Enabled then place(jump) end
			task.wait(0.5)
		end
		self._anchoring = false
	end)
end

function TouchActionGui:OnAttack(callback)
	self.attackButton.MouseButton1Down:Connect(callback)
end

function TouchActionGui:OnRoll(callback)
	self.rollButton.MouseButton1Down:Connect(callback)
end

-- ซ่อนปุ่มสกิลเมื่อของในมือไม่มีสกิล (มือเปล่า เครื่องมือ ปืน) — ปุ่มที่กดแล้วไม่มีวันเกิดอะไรคือเสียงรบกวน
-- ตำแหน่งปุ่มอื่นไม่ขยับ ช่องว่างไว้ ปุ่มที่เลื่อนไปมาใต้นิ้วแย่กว่าช่องว่าง (QA 2026-09-26)
function TouchActionGui:SetSkillAvailable(available)
	self.skillButton.Visible = available and true or false
end

function TouchActionGui:OnSkill(callback)
	self.skillButton.MouseButton1Down:Connect(callback)
end

-- Roll becomes Slide while the player is sprinting. Presses are not wired to anything yet.
-- Every button now shares one black, so the state change shows in the rim and label rather than the fill.
function TouchActionGui:SetSprinting(sprinting)
	setIcon(self.rollIcon, sprinting and "slide" or "roll")
	local rim = self.rollButton:FindFirstChild("Rim")
	if rim then rim.Transparency = sprinting and 0.1 or 0.45 end
end

function TouchActionGui:Show()
	self.gui.Enabled = true
end

function TouchActionGui:Hide()
	self.gui.Enabled = false
end

return TouchActionGui
