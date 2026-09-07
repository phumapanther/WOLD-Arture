-- HudGui: pure UI builder for the in-game HUD (bottom-left vitals cluster, hotbar, 3-dot menu). Stat bars show
-- static full values for now — sub-project 1 (player data & life cycle) will wire them to real values later.
local HudGui = {}
HudGui.__index = HudGui

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
	vitals.Size = UDim2.new(0, 280, 0, 75) -- 560x150 content box in the reference (280x75 keeps the same ~3.73:1 ratio)
	vitals.Position = UDim2.new(0, 20, 1, -20)
	vitals.BackgroundTransparency = 1
	vitals.Parent = gui

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
	gradient(armorBadge, Color3.fromRGB(244, 245, 247), Color3.fromRGB(185, 189, 196))
	local armorStroke = Instance.new("UIStroke")
	armorStroke.Color = ACCENT
	armorStroke.Thickness = 4
	armorStroke.Parent = armorBadge
	local armorIcon = Instance.new("TextLabel")
	armorIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	armorIcon.Position = UDim2.fromScale(0.5, 0.5)
	armorIcon.Size = UDim2.fromScale(0.46, 0.46)
	armorIcon.BackgroundTransparency = 1
	armorIcon.TextTransparency = 0.45
	armorIcon.Font = Enum.Font.SourceSansBold
	armorIcon.TextScaled = true
	armorIcon.TextColor3 = Color3.new(1, 1, 1)
	armorIcon.Text = "\226\154\160" -- placeholder glyph (no real icon art yet) — swap for an ImageLabel + rbxassetid shield icon later
	armorIcon.Parent = armorBadge

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

	-- Right 75%: top 10% mana pips, middle 45% hunger bar, bottom 45% hp bar. Inset from the stamina bar by
	-- extra padding so the pill badges (which sit at this column's own left edge) never crowd it.
	local rightColumn = Instance.new("Frame")
	rightColumn.Size = UDim2.new(0.72, -10, 1, 0)
	rightColumn.Position = UDim2.new(0.28, 10, 0, 0)
	rightColumn.BackgroundTransparency = 1
	rightColumn.Parent = vitals

	local manaFrame = Instance.new("Frame")
	manaFrame.Size = UDim2.new(1, 0, 0.1, 0)
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
		pip.Size = UDim2.new(0, 22, 0.9, 0)
		pip.LayoutOrder = i
		pip.BackgroundTransparency = 1
		pip.Font = Enum.Font.SourceSansBold
		pip.TextScaled = true
		pip.TextColor3 = MANA_LIT
		pip.Text = "\226\153\166" -- gem/diamond (♦) placeholder for the mana potion icon
		pip.Parent = manaFrame
		self.manaPips[i] = pip
	end

	-- Pill bars: hunger (middle 45%), hp (bottom 45%). Track is 52% of its row's height (HTML: height:52%),
	-- black background, fully pill-rounded, gradient fill. Badge is a circle positioned absolutely at the row's
	-- left edge (overlapping the track, which is indented by the badge's own radius), white border, drop shadow.
	self.bars = {}
	for i, def in ipairs(PILL_BARS) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0.45, 0)
		row.Position = UDim2.new(0, 0, 0.1 + (i - 1) * 0.45, 0)
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
	end

	-- 3-dot menu, top-right
	local menuButton = Instance.new("TextButton")
	menuButton.Size = UDim2.new(0, 44, 0, 44)
	menuButton.Position = UDim2.new(1, -64, 0, TOP_BAR + 20)
	menuButton.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	menuButton.Text = "\226\128\162\226\128\162\226\128\162" -- three bullet characters; a vertical-ellipsis glyph didn't render in SourceSansBold
	menuButton.TextColor3 = Color3.new(1, 1, 1)
	menuButton.TextSize = 18
	menuButton.Font = Enum.Font.SourceSansBold
	menuButton.Parent = gui
	corner(menuButton, UDim.new(1, 0))

	local menuPanel = Instance.new("Frame")
	menuPanel.Size = UDim2.new(0, 200, 0, 56)
	menuPanel.Position = UDim2.new(1, -220, 0, TOP_BAR + 72)
	menuPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	menuPanel.Visible = false
	menuPanel.Parent = gui
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

	-- hotbar, bottom-center
	local hotbar = Instance.new("Frame")
	hotbar.AnchorPoint = Vector2.new(0.5, 1)
	hotbar.Size = UDim2.new(0, HOTBAR_SLOTS * 64 + (HOTBAR_SLOTS - 1) * 8, 0, 64)
	hotbar.Position = UDim2.new(0.5, 0, 1, -20)
	hotbar.BackgroundTransparency = 1
	hotbar.Parent = gui
	local hotbarLayout = Instance.new("UIListLayout")
	hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
	hotbarLayout.Padding = UDim.new(0, 8)
	hotbarLayout.Parent = hotbar

	self.slots = {}
	for i = 1, HOTBAR_SLOTS do
		local slot = Instance.new("Frame")
		slot.Size = UDim2.new(0, 64, 0, 64)
		slot.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
		slot.LayoutOrder = i
		slot.Parent = hotbar
		corner(slot, UDim.new(0, 10))
		self.slots[i] = slot
	end

	self.gui = gui
	return self
end

-- SetBarFraction: 0..1, for the "hunger" | "hp" pill bars. Stub for sub-project 1; call with 1 for every bar
-- until real vitals exist.
function HudGui:SetBarFraction(key, fraction)
	local fill = self.bars[key]
	if fill then fill.Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0) end
end

-- SetArmorFraction: 0..1. No-op for now — the approved reference draws armor as a static badge with no
-- depletion visual. Kept as a stable call site so HudController doesn't need to change if/when armor gets one.
function HudGui:SetArmorFraction(_fraction) end

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

function HudGui:Show()
	self.gui.Enabled = true
end

function HudGui:Destroy()
	self.gui:Destroy()
end

return HudGui
