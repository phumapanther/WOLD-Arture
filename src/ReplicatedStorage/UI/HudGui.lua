-- HudGui: pure UI builder for the in-game HUD (bottom-left vitals cluster, hotbar, 3-dot menu). Stat bars show
-- static full values for now — sub-project 1 (player data & life cycle) will wire them to real values later.
local HudGui = {}
HudGui.__index = HudGui

-- Pill bars: rounded-end bar with a round icon badge overlapping its left edge. No text on the bar — icon only,
-- per the reference art. Icon glyphs are Unicode placeholders (no real icon art in the project yet) — swap
-- `glyph` for a real ImageLabel + rbxassetid later.
local PILL_BARS = {
	{ key = "hunger", color = Color3.fromRGB(60, 200, 100), glyph = "\226\152\129" }, -- cloud (☁)
	{ key = "hp", color = Color3.fromRGB(230, 60, 60), glyph = "\226\153\165" }, -- heart (♥)
}

local MANA_PIPS = 3
local MANA_LIT = Color3.fromRGB(90, 170, 235)
local MANA_DIM = Color3.fromRGB(50, 60, 75)

local ARMOR_FULL = Color3.fromRGB(190, 190, 198)
local ARMOR_EMPTY = Color3.fromRGB(70, 70, 76)

local HOTBAR_SLOTS = 6

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 8)
	c.Parent = parent
	return c
end

function HudGui.new()
	local self = setmetatable({}, HudGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "HudGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local TOP_BAR = 56

	-- Whole vitals cluster (armor / stamina / mana+hunger+hp) is anchored bottom-left, per the reference layout.
	-- No avatar circle in this HUD.
	local vitals = Instance.new("Frame")
	vitals.AnchorPoint = Vector2.new(0, 1)
	vitals.Size = UDim2.new(0, 230, 0, 148)
	vitals.Position = UDim2.new(0, 20, 1, -20)
	vitals.BackgroundTransparency = 1
	vitals.Parent = gui

	-- Armor: a square badge that IS its own bar — shaded bottom-up, not a separate pill (per reference: dark
	-- region = armor remaining, light region = armor used up; full = all-dark for now, no depletion yet).
	local armorBadge = Instance.new("Frame")
	armorBadge.Size = UDim2.new(0, 44, 0, 44)
	armorBadge.Position = UDim2.new(0, 0, 1, -44)
	armorBadge.BackgroundColor3 = ARMOR_EMPTY
	armorBadge.ClipsDescendants = true
	armorBadge.Parent = vitals
	corner(armorBadge, UDim.new(0, 10))
	local armorFill = Instance.new("Frame")
	armorFill.AnchorPoint = Vector2.new(0, 1)
	armorFill.Position = UDim2.new(0, 0, 1, 0)
	armorFill.Size = UDim2.fromScale(1, 1)
	armorFill.BackgroundColor3 = ARMOR_FULL
	armorFill.BorderSizePixel = 0
	armorFill.Parent = armorBadge
	-- No shield glyph here: SourceSansBold has no legible shield character, and this is placeholder art anyway —
	-- swap the badge for a real ImageLabel + rbxassetid shield icon later.
	self.armorFill = armorFill

	-- Stamina: thin, short vertical bar between armor and the mana/hunger/hp column, fills bottom-up. Much
	-- smaller than the armor badge, per the reference proportions.
	local staminaTrack = Instance.new("Frame")
	staminaTrack.Size = UDim2.new(0, 5, 0, 100)
	staminaTrack.Position = UDim2.new(0, 54, 1, -100)
	staminaTrack.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
	staminaTrack.BorderSizePixel = 0
	staminaTrack.ClipsDescendants = true
	staminaTrack.Parent = vitals
	corner(staminaTrack, UDim.new(1, 0))
	local staminaFill = Instance.new("Frame")
	staminaFill.AnchorPoint = Vector2.new(0, 1)
	staminaFill.Position = UDim2.new(0, 0, 1, 0)
	staminaFill.Size = UDim2.fromScale(1, 1)
	staminaFill.BackgroundColor3 = Color3.fromRGB(230, 190, 70)
	staminaFill.BorderSizePixel = 0
	staminaFill.Parent = staminaTrack
	corner(staminaFill, UDim.new(1, 0))
	self.staminaFill = staminaFill

	local columnX = 78

	-- Mana: pip row (MANA_PIPS discrete gems, lit vs dim — not a fill bar), at the top of the column. No label,
	-- per the reference art.
	local manaFrame = Instance.new("Frame")
	manaFrame.Size = UDim2.new(0, 34 * MANA_PIPS, 0, 28)
	manaFrame.Position = UDim2.new(0, columnX, 0, 0)
	manaFrame.BackgroundTransparency = 1
	manaFrame.Parent = vitals
	local manaLayout = Instance.new("UIListLayout")
	manaLayout.FillDirection = Enum.FillDirection.Horizontal
	manaLayout.Padding = UDim.new(0, 4)
	manaLayout.Parent = manaFrame

	self.manaPips = {}
	for i = 1, MANA_PIPS do
		local pip = Instance.new("TextLabel")
		pip.Size = UDim2.new(0, 28, 0, 28)
		pip.LayoutOrder = i
		pip.BackgroundTransparency = 1
		pip.Font = Enum.Font.SourceSansBold
		pip.TextSize = 24
		pip.TextColor3 = MANA_LIT
		pip.Text = "\226\153\166" -- gem/diamond (♦) placeholder for the mana potion icon
		pip.Parent = manaFrame
		self.manaPips[i] = pip
	end

	-- Pill bars: hunger, hp — rounded bar with a round icon badge overlapping its left edge, icon only.
	local pillsFrame = Instance.new("Frame")
	pillsFrame.Size = UDim2.new(1, -columnX, 0, 62)
	pillsFrame.Position = UDim2.new(0, columnX, 0, 36)
	pillsFrame.BackgroundTransparency = 1
	pillsFrame.Parent = vitals
	local pillsLayout = Instance.new("UIListLayout")
	pillsLayout.Padding = UDim.new(0, 8)
	pillsLayout.Parent = pillsFrame

	self.bars = {}
	for i, def in ipairs(PILL_BARS) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 26)
		row.BackgroundTransparency = 1
		row.LayoutOrder = i
		row.Parent = pillsFrame

		local track = Instance.new("Frame")
		track.Size = UDim2.new(1, -13, 1, 0)
		track.Position = UDim2.new(0, 13, 0, 0)
		track.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
		track.BorderSizePixel = 0
		track.ClipsDescendants = true
		track.Parent = row
		corner(track, UDim.new(1, 0))

		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = def.color
		fill.BorderSizePixel = 0
		fill.Parent = track
		corner(fill, UDim.new(1, 0))

		local badge = Instance.new("TextLabel")
		badge.Size = UDim2.new(0, 26, 0, 26)
		badge.Position = UDim2.new(0, 0, 0, 0)
		badge.BackgroundColor3 = def.color
		badge.Font = Enum.Font.SourceSansBold
		badge.TextSize = 15
		badge.TextColor3 = Color3.new(1, 1, 1)
		badge.Text = def.glyph
		badge.ZIndex = 2
		badge.Parent = row
		corner(badge, UDim.new(1, 0))

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

-- SetArmorFraction: 0..1, fills the armor badge bottom-up (dark region remaining, per the reference art).
function HudGui:SetArmorFraction(fraction)
	self.armorFill.Size = UDim2.new(1, 0, math.clamp(fraction, 0, 1), 0)
end

-- SetStaminaFraction: 0..1, fills the thin vertical stamina bar bottom-up.
function HudGui:SetStaminaFraction(fraction)
	self.staminaFill.Size = UDim2.new(1, 0, math.clamp(fraction, 0, 1), 0)
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
