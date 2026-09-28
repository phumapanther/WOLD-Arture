-- HudGui: pure UI builder for the in-game HUD (bottom-left vitals cluster, hotbar, 3-dot menu). Stat bars show
-- static full values for now — sub-project 1 (player data & life cycle) will wire them to real values later.
local HudGui = {}
HudGui.__index = HudGui

local ItemIcon = require(script.Parent.ItemIcon)

-- Pill bars: rounded-end bar with a round icon badge overlapping its left edge. No text on the bar — icon only.
-- Colors and gradient stops match the approved HTML reference (docs/superpowers, Main.dc.html) exactly. Icon
-- glyphs are Unicode placeholders (no real icon art in the project yet) — swap `glyph` for a real ImageLabel +
-- rbxassetid later.
local PILL_BARS = {
	{ key = "hunger", top = Color3.fromRGB(111, 224, 122), bottom = Color3.fromRGB(47, 169, 61), glyph = "\226\152\129" }, -- cloud (☁)
	{ key = "hp", top = Color3.fromRGB(255, 107, 107), bottom = Color3.fromRGB(224, 47, 47), glyph = "\226\153\165" }, -- heart (♥)
}

local MANA_PIPS = 3
local MANA_LIT = Color3.fromRGB(127, 212, 242)
local MANA_DIM = Color3.fromRGB(50, 60, 75)

local ACCENT = Color3.fromRGB(244, 197, 66)

local HOTBAR_SLOTS = 6

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 8)
	c.Parent = parent
	return c
end

local function gradient(parent, topColor, bottomColor)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(topColor, bottomColor)
	g.Rotation = 90
	g.Parent = parent
	return g
end

-- Responsive scaling: every element below is built at fixed pixel sizes tuned for a ~1280px-wide viewport (the
-- vitals cluster especially — its internal layout is a dense, carefully-balanced percentage+pixel grid that's
-- not safe to convert piecemeal to Scale units without redoing that tuning). A UIScale per top-level group lets
-- the whole HUD shrink/grow together on smaller/larger screens while keeping every internal ratio exactly as
-- designed. 1280px is the baseline (scale 1); clamped to [0.55, 1] so it only shrinks, never grows past the
-- tuned size on huge screens.
local BASELINE_WIDTH = 1280
local MIN_UI_SCALE = 0.55

local function responsiveScale(parent, minScale)
	local scale = Instance.new("UIScale")
	scale.Parent = parent
	local camera = workspace.CurrentCamera
	local function update()
		local width = camera and camera.ViewportSize.X or BASELINE_WIDTH
		scale.Scale = math.clamp(width / BASELINE_WIDTH, minScale or MIN_UI_SCALE, 1)
	end
	update()
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(update) end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		camera = workspace.CurrentCamera
		update()
		if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(update) end
	end)
	return scale
end

function HudGui.new()
	local self = setmetatable({}, HudGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "HudGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local TOP_BAR = 56

	-- Whole vitals cluster (armor / stamina / mana+hunger+hp) is anchored bottom-left. Internally a strict
	-- 3-column % grid matching the approved HTML reference exactly: left 20% (armor), middle 5% (stamina),
	-- right 75% (mana/hunger/hp) — see each section's comment for its own internal split.
	local vitals = Instance.new("Frame")
	vitals.AnchorPoint = Vector2.new(0, 1)
	-- Taller than the reference's 3.73:1 box: the mana crystals sit in the top fifth, and at 75px tall that
	-- row was only 11px, which squashed them to unreadable specks whatever width they were given.
	vitals.Size = UDim2.new(0, 280, 0, 100)
	vitals.Position = UDim2.new(0, 20, 1, -20)
	vitals.BackgroundTransparency = 1
	vitals.Parent = gui
	responsiveScale(vitals)

	-- Left 20%: armor badge, bottom-anchored, occupying the bottom 80% of the column height (HTML: height:80%,
	-- justify-content:flex-end). Rounded corners, accent-colored border, gray gradient fill, shield icon centered
	-- at 55% opacity.
	local armorBadge = Instance.new("Frame")
	armorBadge.AnchorPoint = Vector2.new(0, 1)
	armorBadge.Size = UDim2.new(0.2, 0, 0.8, 0)
	armorBadge.Position = UDim2.new(0, 0, 1, 0)
	armorBadge.BackgroundColor3 = Color3.fromRGB(215, 218, 222)
	armorBadge.BorderSizePixel = 0
	armorBadge.Parent = vitals
	corner(armorBadge, UDim.new(0, 16))
	local armorGradient = gradient(armorBadge, Color3.fromRGB(244, 245, 247), Color3.fromRGB(185, 189, 196))
	local armorStroke = Instance.new("UIStroke")
	armorStroke.Color = ACCENT
	armorStroke.Thickness = 4
	armorStroke.Parent = armorBadge
	-- Kept so SetArmorFraction can dim the badge as the armor wears down; the gradient sits on top of
	-- BackgroundColor3, so it is the thing that actually has to change.
	self.armorBadge = armorBadge
	self.armorGradient = armorGradient
	self.armorStroke = armorStroke
	local armorIcon = Instance.new("TextLabel")
	armorIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	armorIcon.Position = UDim2.fromScale(0.5, 0.5)
	armorIcon.Size = UDim2.fromScale(0.46, 0.46)
	armorIcon.BackgroundTransparency = 1
	armorIcon.TextTransparency = 0.1
	armorIcon.Font = Enum.Font.SourceSansBold
	armorIcon.TextScaled = true
	armorIcon.TextColor3 = Color3.new(1, 1, 1)
	-- อีโมจิโล่ (ผู้ใช้กำหนด) ของเดิมเป็น ⚠ ซึ่งอ่านเป็น "ไอคอนพัง" ไม่ใช่เกราะ
	armorIcon.Text = "🛡️"
	armorIcon.Parent = armorBadge
	-- แต้มเกราะที่เหลือ โชว์เฉพาะสนาม PVP (SetArenaMode) — สีจางอย่างเดียวบอกไม่ได้ว่าโดนตีแล้วลดไปเท่าไหร่
	local armorPoints = Instance.new("TextLabel")
	armorPoints.AnchorPoint = Vector2.new(0.5, 1)
	armorPoints.Position = UDim2.fromScale(0.5, 0.98)
	armorPoints.Size = UDim2.fromScale(0.9, 0.34)
	armorPoints.BackgroundTransparency = 1
	armorPoints.Font = Enum.Font.GothamBold
	armorPoints.TextScaled = true
	armorPoints.TextColor3 = Color3.new(1, 1, 1)
	armorPoints.TextStrokeTransparency = 0.3
	armorPoints.Text = ""
	armorPoints.Visible = false
	armorPoints.Parent = armorBadge
	self.armorPoints = armorPoints
	self.armorIcon = armorIcon

	-- Middle: stamina, a thin vertical bar filling the middle 35% band of the column height (40/35/25
	-- top/mid/bottom split). Centered in the actual gap between the armor badge's right edge (0.2) and the
	-- right column's left edge (0.28 + 10px), not just offset from the armor badge — armor ends at x=56 and the
	-- right column starts at x=88.4 (on a 280px-wide cluster), so the bar sits at their midpoint, x≈72.
	local staminaBand = Instance.new("Frame")
	staminaBand.AnchorPoint = Vector2.new(0.5, 0)
	staminaBand.Position = UDim2.new(0.24, 6.2, 0.4, 0)
	staminaBand.Size = UDim2.new(0, 4, 0.35, 0)
	staminaBand.BackgroundTransparency = 1
	staminaBand.Parent = vitals
	local staminaTrack = Instance.new("Frame")
	staminaTrack.AnchorPoint = Vector2.new(0, 1)
	staminaTrack.Position = UDim2.new(0, 0, 1, 0)
	staminaTrack.Size = UDim2.fromScale(1, 1)
	staminaTrack.BackgroundColor3 = ACCENT
	staminaTrack.BorderSizePixel = 0
	staminaTrack.Parent = staminaBand
	corner(staminaTrack, UDim.new(0, 2))
	gradient(staminaTrack, ACCENT, Color3.fromRGB(244, 197, 66))
	self.staminaTrack = staminaTrack

	-- Right 75%: top 30% mana pips, middle 35% hunger bar, bottom 35% hp bar. Inset from the stamina bar by
	-- extra padding so the pill badges (which sit at this column's own left edge) never crowd it.
	local rightColumn = Instance.new("Frame")
	rightColumn.Size = UDim2.new(0.72, -10, 1, 0)
	rightColumn.Position = UDim2.new(0.28, 10, 0, 0)
	rightColumn.BackgroundTransparency = 1
	rightColumn.Parent = vitals

	local manaFrame = Instance.new("Frame")
	manaFrame.Size = UDim2.new(1, 0, 0.3, 0)
	manaFrame.Position = UDim2.new(0, 0, 0, 0)
	manaFrame.BackgroundTransparency = 1
	manaFrame.Parent = rightColumn
	local manaLayout = Instance.new("UIListLayout")
	manaLayout.FillDirection = Enum.FillDirection.Horizontal
	manaLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	manaLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	manaLayout.Padding = UDim.new(0, 20)
	manaLayout.Parent = manaFrame

	self.manaPips = {}
	for i = 1, MANA_PIPS do
		local pip = Instance.new("TextLabel")
		pip.Size = UDim2.new(0, 34, 0.95, 0)
		pip.LayoutOrder = i
		pip.BackgroundTransparency = 1
		pip.Font = Enum.Font.SourceSansBold
		pip.TextScaled = true
		pip.TextColor3 = MANA_LIT
		pip.Text = "\226\153\166" -- gem/diamond (♦) placeholder for the mana potion icon
		pip.Parent = manaFrame
		self.manaPips[i] = pip
	end

	-- Pill bars: hunger (middle 35%), hp (bottom 35%). Track is 52% of its row's height (HTML: height:52%),
	-- black background, fully pill-rounded, gradient fill. Badge is a circle positioned absolutely at the row's
	-- left edge (overlapping the track, which is indented by the badge's own radius), white border, drop shadow.
	self.bars = {}
	self.barRows = {}
	for i, def in ipairs(PILL_BARS) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0.35, 0)
		row.Position = UDim2.new(0, 0, 0.3 + (i - 1) * 0.35, 0)
		row.BackgroundTransparency = 1
		row.Parent = rightColumn

		local track = Instance.new("Frame")
		track.AnchorPoint = Vector2.new(0, 0.5)
		track.Position = UDim2.new(0, 14, 0.5, 0)
		track.Size = UDim2.new(1, -14, 0.52, 0)
		track.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
		track.BorderSizePixel = 0
		track.ClipsDescendants = true
		track.Parent = row
		corner(track, UDim.new(1, 0))

		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = def.top
		fill.BorderSizePixel = 0
		fill.Parent = track
		corner(fill, UDim.new(1, 0))
		gradient(fill, def.top, def.bottom)

		local badge = Instance.new("Frame")
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.new(0, 0, 0.5, 0)
		badge.Size = UDim2.new(0, 28, 0, 28) -- smaller than before (was 40x40) so it clears the stamina bar
		badge.BackgroundColor3 = def.top
		badge.BorderSizePixel = 0
		badge.Parent = row
		corner(badge, UDim.new(1, 0))
		gradient(badge, def.top, def.bottom)
		local badgeStroke = Instance.new("UIStroke")
		badgeStroke.Color = Color3.new(1, 1, 1)
		badgeStroke.Thickness = 2
		badgeStroke.Parent = badge
		local badgeIcon = Instance.new("TextLabel")
		badgeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		badgeIcon.Position = UDim2.fromScale(0.5, 0.5)
		badgeIcon.Size = UDim2.fromScale(0.55, 0.55)
		badgeIcon.BackgroundTransparency = 1
		badgeIcon.Font = Enum.Font.SourceSansBold
		badgeIcon.TextScaled = true
		badgeIcon.TextColor3 = Color3.new(1, 1, 1)
		badgeIcon.Text = def.glyph
		badgeIcon.Parent = badge

		self.bars[def.key] = fill
		self.barRows[def.key] = row
	end

	-- 3-dot menu, flush to the very top-right corner of the screen (past Roblox's own top bar on purpose — the
	-- user wants it right at the corner, not clear of that bar). Wrapped in its own group so one UIScale scales
	-- the button and its dropdown panel together.
	local menuGroup = Instance.new("Frame")
	menuGroup.AnchorPoint = Vector2.new(1, 0)
	menuGroup.Size = UDim2.new(0, 220, 0, 140)
	menuGroup.Position = UDim2.new(1, 0, 0, 0)
	menuGroup.BackgroundTransparency = 1
	menuGroup.Parent = gui
	responsiveScale(menuGroup, require(script.Parent.Responsive).CornerMinScale())

	local menuButton = Instance.new("TextButton")
	menuButton.AnchorPoint = Vector2.new(1, 0)
	menuButton.Size = UDim2.new(0, 44, 0, 44)
	menuButton.Position = UDim2.new(1, -4, 0, 4)
	menuButton.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	menuButton.Text = "\226\128\162\226\128\162\226\128\162" -- three bullet characters; a vertical-ellipsis glyph didn't render in SourceSansBold
	menuButton.TextColor3 = Color3.new(1, 1, 1)
	menuButton.TextSize = 18
	menuButton.Font = Enum.Font.SourceSansBold
	menuButton.Parent = menuGroup
	corner(menuButton, UDim.new(1, 0))

	local menuPanel = Instance.new("Frame")
	menuPanel.AnchorPoint = Vector2.new(1, 0)
	menuPanel.Size = UDim2.new(0, 200, 0, 56)
	menuPanel.Position = UDim2.new(1, -4, 0, 56)
	menuPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	menuPanel.Visible = false
	menuPanel.Parent = menuGroup
	corner(menuPanel, UDim.new(0, 10))

	local lobbyButton = Instance.new("TextButton")
	lobbyButton.Size = UDim2.new(1, -16, 1, -16)
	lobbyButton.Position = UDim2.new(0, 8, 0, 8)
	lobbyButton.BackgroundColor3 = Color3.fromRGB(200, 60, 50)
	lobbyButton.Text = "กลับหน้า Lobby"
	lobbyButton.TextColor3 = Color3.new(1, 1, 1)
	lobbyButton.Font = Enum.Font.SourceSansBold
	lobbyButton.TextSize = 16
	lobbyButton.Parent = menuPanel
	corner(lobbyButton, UDim.new(0, 8))
	self.lobbyButton = lobbyButton

	menuButton.MouseButton1Click:Connect(function()
		menuPanel.Visible = not menuPanel.Visible
	end)
	self.menuGroup = menuGroup
	self.menuPanel = menuPanel
	self.menuItems = 1 -- ปุ่ม Lobby อยู่แล้วหนึ่ง

	-- hotbar, bottom-center
	local hotbar = Instance.new("Frame")
	hotbar.AnchorPoint = Vector2.new(0.5, 1)
	hotbar.Size = UDim2.new(0, HOTBAR_SLOTS * 64 + (HOTBAR_SLOTS - 1) * 8, 0, 64)
	hotbar.Position = UDim2.new(0.5, 0, 1, -20)
	hotbar.BackgroundTransparency = 1
	hotbar.Parent = gui
	responsiveScale(hotbar)
	-- มือถือ: กลางล่างไม่มีที่ — ซ้าย 40% ล่างคือโซนจอยเดิน (แตะช่องแรกแล้วได้กินของแทนเดิน) และบนจอ 667-740 px
	-- ช่อง 5-6 อยู่ใต้ปุ่มกระโดด → ย้ายไปซ้ายบนใต้แถบของ Roblox ห่างทั้งจอยและกลุ่มปุ่มขวาล่าง (QA 2026-09-26)
	-- ตำแหน่งนี้ VehicleController วางแถบขับไว้ใต้มัน (y 132) — ขยับที่นี่ต้องขยับที่นั่นด้วย
	if require(script.Parent.Responsive).IsTouchOnly() then
		hotbar.AnchorPoint = Vector2.new(0, 0)
		hotbar.Position = UDim2.new(0, 12, 0, 60)
	end
	self.hotbarFrame = hotbar
	local hotbarLayout = Instance.new("UIListLayout")
	hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
	hotbarLayout.Padding = UDim.new(0, 8)
	hotbarLayout.Parent = hotbar

	-- Hotbar slots hold consumables: the number key (or a tap) uses whatever is in them. Buttons rather than
	-- frames so touch players can use an item without opening the bag.
	self.slots = {}
	self.hotbarEntries = {}
	self.onHotbarUsed = nil
	for i = 1, HOTBAR_SLOTS do
		local slot = Instance.new("TextButton")
		slot.Size = UDim2.new(0, 64, 0, 64)
		slot.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
		slot.LayoutOrder = i
		slot.Text = ""
		slot.AutoButtonColor = true
		slot.Parent = hotbar
		corner(slot, UDim.new(0, 10))

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(1, -8, 1, -8)
		icon.Position = UDim2.new(0, 4, 0, 4)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Image = ""
		icon.Visible = false
		icon.Parent = slot

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -6, 1, -16)
		nameLabel.Position = UDim2.new(0, 3, 0, 3)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.TextSize = 10
		nameLabel.TextColor3 = Color3.fromRGB(226, 226, 232)
		nameLabel.TextWrapped = true
		nameLabel.Text = ""
		nameLabel.Parent = slot

		local countLabel = Instance.new("TextLabel")
		countLabel.AnchorPoint = Vector2.new(1, 1)
		countLabel.Position = UDim2.new(1, -4, 1, -2)
		countLabel.Size = UDim2.new(0, 24, 0, 14)
		countLabel.BackgroundTransparency = 1
		countLabel.Font = Enum.Font.GothamBold
		countLabel.TextSize = 11
		countLabel.TextColor3 = ACCENT
		countLabel.TextXAlignment = Enum.TextXAlignment.Right
		countLabel.Text = ""
		countLabel.Parent = slot

		-- The slot number, so the keyboard shortcut is discoverable.
		local keyLabel = Instance.new("TextLabel")
		keyLabel.Position = UDim2.new(0, 4, 0, 1)
		keyLabel.Size = UDim2.new(0, 12, 0, 12)
		keyLabel.BackgroundTransparency = 1
		keyLabel.Font = Enum.Font.GothamBold
		keyLabel.TextSize = 10
		keyLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
		keyLabel.Text = tostring(i)
		keyLabel.Parent = slot

		slot.Activated:Connect(function()
			if self.onHotbarUsed then self.onHotbarUsed(i) end
		end)

		self.slots[i] = slot
		self.hotbarEntries[i] = { button = slot, icon = icon, name = nameLabel, count = countLabel }
	end

	-- EXP bar, centred under the hotbar. A thin strip rather than a pill: it is progress, not a vital, and
	-- should not compete with the health cluster for attention.
	local expGroup = Instance.new("Frame")
	expGroup.Name = "ExpGroup"
	expGroup.AnchorPoint = Vector2.new(0.5, 1)
	expGroup.Size = UDim2.new(0, 420, 0, 18)
	expGroup.Position = UDim2.new(0.5, 0, 1, -92)
	expGroup.BackgroundTransparency = 1
	expGroup.Parent = gui
	responsiveScale(expGroup)
	self.expGroup = expGroup

	local expTrack = Instance.new("Frame")
	expTrack.Size = UDim2.fromScale(1, 1)
	expTrack.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	expTrack.BackgroundTransparency = 0.35
	expTrack.BorderSizePixel = 0
	expTrack.Parent = expGroup
	corner(expTrack, UDim.new(1, 0))

	local expFill = Instance.new("Frame")
	expFill.Name = "Fill"
	expFill.Size = UDim2.new(0, 0, 1, 0)
	expFill.BackgroundColor3 = ACCENT
	expFill.BorderSizePixel = 0
	expFill.Parent = expTrack
	corner(expFill, UDim.new(1, 0))
	gradient(expFill, Color3.fromRGB(255, 224, 130), ACCENT)
	self.expFill = expFill

	local expLabel = Instance.new("TextLabel")
	expLabel.Name = "ExpLabel"
	expLabel.Size = UDim2.fromScale(1, 1)
	expLabel.BackgroundTransparency = 1
	expLabel.Font = Enum.Font.GothamBold
	expLabel.TextSize = 11
	expLabel.TextColor3 = Color3.fromRGB(240, 238, 232)
	expLabel.Text = "Lv. 1"
	expLabel.Parent = expTrack
	local expStroke = Instance.new("UIStroke")
	expStroke.Color = Color3.fromRGB(0, 0, 0)
	expStroke.Transparency = 0.5
	expStroke.Thickness = 2
	expStroke.Parent = expLabel
	self.expLabel = expLabel

	self.gui = gui
	return self
end

-- SetHotbar: `entries` is a list of { id, count, icon, name } or nil per slot.
function HudGui:SetHotbar(entries)
	for i, ui in ipairs(self.hotbarEntries) do
		local entry = entries and entries[i]
		if entry then
			local art = entry.icon or ""
			-- ไม่มีรูป = ⌛ (ItemIcon) ชื่อยังขึ้นใต้มันเหมือนเดิม
			ItemIcon.Apply(ui.icon, art)
			ItemIcon.SetBadge(ui.icon, entry.skinIcon) -- สกินที่ติดอยู่ มุมล่างซ้าย
			ui.icon.Visible = true
			ui.name.Text = (art == "") and (entry.name or entry.id) or ""
			ui.count.Text = (entry.count or 1) > 1 and tostring(entry.count) or ""
			-- An assigned item you have run out of stays in its slot, dimmed. Clearing it would lose the
			-- arrangement every time the last potion was drunk, and it fills back in when you carry one again.
			local out = entry.count == 0
			ItemIcon.SetFade(ui.icon, out and 0.6 or 0)
			ui.name.TextTransparency = out and 0.6 or 0
		else
			ui.icon.Image = ""
			ItemIcon.SetBadge(ui.icon, nil)
			ui.icon.Visible = false
			ui.name.Text = ""
			ui.count.Text = ""
		end
	end
end

function HudGui:OnHotbarUsed(callback)
	self.onHotbarUsed = callback
end

-- Which hotbar slot is under this screen point, or nil. Used to decide where a drag from the bag landed.
-- AbsolutePosition and AbsoluteSize already have every scale applied, so this stays correct on a phone and
-- at any window size -- the same reason the map's pin maths reads them rather than doing its own scaling.
function HudGui:SlotAt(position)
	for i, ui in ipairs(self.hotbarEntries) do
		local b = ui.button
		if b then
			local p, sz = b.AbsolutePosition, b.AbsoluteSize
			if position.X >= p.X and position.X <= p.X + sz.X
				and position.Y >= p.Y and position.Y <= p.Y + sz.Y then
				return i
			end
		end
	end
	return nil
end

-- Lights the slot a drag is currently over, so it is obvious where the item will land before letting go.
function HudGui:HighlightSlot(index)
	for i, ui in ipairs(self.hotbarEntries) do
		if ui.button then
			ui.button.BackgroundColor3 = (i == index)
				and Color3.fromRGB(70, 92, 68) or Color3.fromRGB(35, 35, 40)
		end
	end
end

-- SetExp: level plus progress 0..1 toward the next one.
-- แถวอีโมจิบัพเหนือหลอด EXP: [ชื่อ] = วินาทีที่เหลือ | -1 = ไม่มีวันหมด (อาชีพ/อมตะ) จิ้มอีโมจิ = ป้ายบอกเวลา
local BUFF_ORDER = { "noHunger", "noStamina", "noMana", "noArmor", "noHp" }
local BUFF_LOOK = {
	noHunger = { emoji = "💚", text = "ความหิวไม่ลด" },
	noStamina = { emoji = "💛", text = "สตามินาไม่ลด" },
	noMana = { emoji = "💙", text = "มานาไม่ลด" },
	noArmor = { emoji = "🖤", text = "เกราะไม่ลด" },
	-- หัวใจแดงล้วน (ผู้ใช้สั่ง 2026-09-20) — ของเดิมเป็นหัวใจมีผ้าพันแผล ซึ่งฟอนต์บางเครื่องวาดแยกเป็น
	-- สองตัวอักษรเพราะมันเป็น emoji ประสม (❤️ + ZWJ + 🩹)
	noHp = { emoji = "❤️", text = "เลือดไม่ลด" },
}

local function buffLeftText(seconds)
	if seconds == -1 then return "ไม่มีวันหมด" end
	if seconds >= 3600 then return ("เหลือ %d ชม. %d นาที"):format(math.floor(seconds / 3600), math.floor((seconds % 3600) / 60)) end
	if seconds >= 60 then return ("เหลือ %d นาที"):format(math.ceil(seconds / 60)) end
	return ("เหลือ %d วินาที"):format(math.floor(seconds))
end

function HudGui:ensureBuffRow()
	if self.buffRow then return end
	local row = Instance.new("Frame")
	row.Name = "BuffRow"
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Size = UDim2.new(0, 420, 0, 30)
	row.Position = UDim2.new(0.5, 0, 1, -114) -- เหนือหลอด EXP (ที่ 1,-92 สูง 18)
	row.BackgroundTransparency = 1
	row.Parent = self.gui
	responsiveScale(row)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row

	local tip = Instance.new("TextLabel")
	tip.Name = "BuffTip"
	tip.AnchorPoint = Vector2.new(0.5, 1)
	tip.Position = UDim2.new(0.5, 0, 1, -148)
	tip.Size = UDim2.new(0, 260, 0, 24)
	tip.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	tip.BackgroundTransparency = 0.2
	tip.BorderSizePixel = 0
	tip.Font = Enum.Font.GothamBold
	tip.TextSize = 12
	tip.TextColor3 = Color3.fromRGB(240, 238, 232)
	tip.Text = ""
	tip.Visible = false
	tip.Parent = self.gui
	corner(tip, UDim.new(0, 8))
	responsiveScale(tip)

	self.buffRow = row
	self.buffTip = tip
	self.buffButtons = {}
	self.buffState = {}
end

function HudGui:SetBuffs(buffs)
	self:ensureBuffRow()
	buffs = buffs or {}
	self.buffState = buffs
	for _, name in ipairs(BUFF_ORDER) do
		local left = buffs[name]
		local button = self.buffButtons[name]
		if left and not button then
			button = Instance.new("TextButton")
			button.Name = name
			button.Size = UDim2.new(0, 30, 0, 30)
			button.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
			button.BackgroundTransparency = 0.25
			button.BorderSizePixel = 0
			button.Font = Enum.Font.GothamBold
			button.TextSize = 16
			button.Text = BUFF_LOOK[name].emoji
			button.LayoutOrder = table.find(BUFF_ORDER, name)
			button.Parent = self.buffRow
			corner(button, UDim.new(1, 0))
			button.Activated:Connect(function()
				local now = self.buffState[name]
				if now == nil then return end
				self.buffTip.Text = ("%s %s — %s"):format(BUFF_LOOK[name].emoji, BUFF_LOOK[name].text, buffLeftText(now))
				self.buffTip.Visible = true
				local token = os.clock()
				self.buffTipToken = token
				task.delay(2.5, function()
					if self.buffTipToken == token then self.buffTip.Visible = false end
				end)
			end)
			self.buffButtons[name] = button
		elseif not left and button then
			button:Destroy()
			self.buffButtons[name] = nil
		end
	end
end

-- สนาม PVP (ผู้ใช้สั่ง 2026-09-24): ไม่มีเลเวลกับความหิวให้ดู — ซ่อนแถบ EXP กับหลอดหิว
-- แล้วเลื่อนหลอดเลือดขึ้นมากลางช่องว่าง ไม่ให้เหลือรูโหว่ตรงกลางกลุ่มหลอด
function HudGui:SetArenaMode()
	self.expGroup.Visible = false
	self.hotbarFrame.Visible = false -- ช่องของใช้ 1-6 ก็ไม่มีในสนาม (ผู้ใช้สั่ง) ยาใช้ปุ่ม F
	local hunger, hp = self.barRows.hunger, self.barRows.hp
	if hunger then hunger.Visible = false end
	if hp then hp.Position = UDim2.new(0, 0, 0.475, 0) end
	self.armorPoints.Visible = true
	-- โล่ขยับขึ้นหลบตัวเลข
	self.armorIcon.Position = UDim2.fromScale(0.5, 0.36)
	self.armorIcon.Size = UDim2.fromScale(0.4, 0.4)
end

-- แต้มเกราะเป็นตัวเลข (เห็นเฉพาะสนาม — ดู SetArenaMode)
function HudGui:SetArmorPoints(points)
	self.armorPoints.Text = points and tostring(points) or ""
end

function HudGui:SetExp(level, fraction)
	self.expFill.Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0)
	self.expLabel.Text = ("Lv. %d"):format(level)
end

-- SetBarFraction: 0..1, for the "hunger" | "hp" pill bars. Stub for sub-project 1; call with 1 for every bar
-- until real vitals exist.
function HudGui:SetBarFraction(key, fraction)
	local fill = self.bars[key]
	if fill then fill.Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0) end
end

-- SetArmorFraction: 0..1. Armor is a real, spendable pool now, so the badge dims and desaturates as it wears
-- down and goes fully grey when it breaks — the reference's static badge gave no warning at all.
function HudGui:SetArmorFraction(fraction)
	if not self.armorGradient then return end
	fraction = math.clamp(fraction, 0, 1)
	local worn = 1 - fraction
	-- Bright steel when intact, dull grey when broken.
	local top = Color3.fromRGB(244, 245, 247):Lerp(Color3.fromRGB(96, 96, 104), worn)
	local bottom = Color3.fromRGB(185, 189, 196):Lerp(Color3.fromRGB(62, 62, 70), worn)
	self.armorGradient.Color = ColorSequence.new(top, bottom)
	if self.armorStroke then
		-- The gold rim fades out entirely once the armor is gone, so a broken set is obvious at a glance.
		self.armorStroke.Transparency = worn
	end
end

-- SetStaminaFraction: 0..1, shrinks the stamina bar's own height bottom-up (no separate fill/track distinction
-- in the reference — the bar itself is the fill).
function HudGui:SetStaminaFraction(fraction)
	self.staminaTrack.Size = UDim2.new(1, 0, math.clamp(fraction, 0, 1), 0)
end

-- SetManaPips: how many of the MANA_PIPS gems are lit (0..#self.manaPips).
function HudGui:SetManaPips(lit)
	for i, pip in ipairs(self.manaPips) do
		pip.TextColor3 = (i <= lit) and MANA_LIT or MANA_DIM
	end
end

function HudGui:OnLobbyRequested(callback)
	self.lobbyButton.MouseButton1Click:Connect(callback)
end

-- เพิ่มปุ่มในเมนูสามจุด (ร้านพรีเมียม กาชา แบทเทิลพาส …) ปุ่มเรียงลงมาใต้ปุ่มเดิม แผงยืดตาม
local MENU_ROW = 40
function HudGui:AddMenuItem(text, colour, callback)
	self.menuItems += 1
	local panel = self.menuPanel
	local index = self.menuItems
	panel.Size = UDim2.new(0, 200, 0, 16 + index * MENU_ROW)
	self.menuGroup.Size = UDim2.new(0, 220, 0, 60 + 16 + index * MENU_ROW)
	-- ปุ่ม Lobby ถูกวางแบบยืดเต็มแผง ต้องตรึงเป็นแถวแรกก่อนเพิ่มแถวอื่น
	self.lobbyButton.Size = UDim2.new(1, -16, 0, MENU_ROW - 8)
	self.lobbyButton.Position = UDim2.new(0, 8, 0, 8)

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -16, 0, MENU_ROW - 8)
	button.Position = UDim2.new(0, 8, 0, 8 + (index - 1) * MENU_ROW)
	button.BackgroundColor3 = colour or Color3.fromRGB(60, 64, 80)
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.SourceSansBold
	button.TextSize = 16
	button.Parent = panel
	corner(button, UDim.new(0, 8))
	button.MouseButton1Click:Connect(function()
		panel.Visible = false
		callback()
	end)
	return button
end

function HudGui:Show()
	self.gui.Enabled = true
end

function HudGui:Destroy()
	self.gui:Destroy()
end

return HudGui
