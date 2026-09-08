-- ChannelSelectGui: pure UI builder for the mode-tabs + channel-rows screen. No networking in this file.
local CAP = 30
local ROWS, COLS = 2, 15 -- 30 avatar slots per channel, matching the reference mockup

local Responsive = require(script.Parent.Responsive)

local ChannelSelectGui = {}
ChannelSelectGui.__index = ChannelSelectGui

local ACTIVE_MODES = { Roleplay = true }
local MODE_ORDER = { "Stories", "Roleplay", "Tanding" }

-- Fill this in from Studio once there's real art (Asset Manager -> Decal/Image -> copy its rbxassetid).
-- Left empty on purpose: an image ID we can't verify from here could point at nothing and silently show a
-- blank/white square, which is worse than the dark gradient fallback below. The fallback is not white either
-- way, so this is safe to leave blank until real art is picked.
local BACKGROUND_IMAGE_ID = ""

-- Dark "modern glass" palette: translucent panels over a background image/gradient instead of flat white/black.
local BG_TOP = Color3.fromRGB(15, 13, 26)
local BG_BOTTOM = Color3.fromRGB(36, 22, 46)
local ACCENT = Color3.fromRGB(216, 172, 84) -- gold, matches the medieval/fantasy theme
local TEXT_LIGHT = Color3.fromRGB(240, 240, 245)
local TEXT_MUTED = Color3.fromRGB(180, 180, 195)
local GLASS = Color3.fromRGB(255, 255, 255)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 8)
	c.Parent = parent
	return c
end

local function glassStroke(parent, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = GLASS
	s.Transparency = transparency or 0.75
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

function ChannelSelectGui.new()
	local self = setmetatable({}, ChannelSelectGui)
	self.onJoin = nil
	self._locked = false
	self.rows = {} -- rows["Roleplay"][1] = { frame, countLabel, joinButton, statusLabel, avatars = {ImageLabel,...} }

	local gui = Instance.new("ScreenGui")
	gui.Name = "ChannelSelectGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- covers the whole screen including under Roblox's own top bar; header content is pushed down below it instead
	local TOP_BAR = 56 -- Roblox's default top bar height (backpack/chat/mic icons)

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = BG_TOP
	root.BackgroundTransparency = 0.8
	root.BorderSizePixel = 0
	root.Parent = gui
	local rootGradient = Instance.new("UIGradient")
	rootGradient.Color = ColorSequence.new(BG_TOP, BG_BOTTOM)
	rootGradient.Rotation = 90
	rootGradient.Parent = root

	-- Background image slot: sits behind everything, only visible once BACKGROUND_IMAGE_ID is set. Until then
	-- the gradient above shows through (ImageTransparency 1 => fully invisible, not a black/white square).
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.fromScale(1, 1)
	bgImage.BackgroundTransparency = 1
	bgImage.ImageTransparency = (BACKGROUND_IMAGE_ID == "") and 1 or 0.35
	bgImage.ScaleType = Enum.ScaleType.Crop
	bgImage.Image = BACKGROUND_IMAGE_ID
	bgImage.ZIndex = 0
	bgImage.Parent = root

	-- header title, top-left, for a bit of branding on the menu
	local portrait = Responsive.IsPortrait()

	local title = Instance.new("TextLabel")
	-- Portrait has no room for a title and tabs side by side, so the title takes the full width and the tabs
	-- drop onto their own line below it (see tabBar's position).
	title.Size = portrait and UDim2.new(0.93, 0, 0, 34) or UDim2.new(0.42, 0, 0, 40)
	title.TextScaled = false
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Position = UDim2.new(0.035, 0, 0, TOP_BAR + 24)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = portrait and 20 or 26
	title.TextColor3 = ACCENT
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "WOLD Arture — เลือกเซิร์ฟเวอร์"
	title.Parent = root

	-- mode tab bar — anchored to the top-right corner (not a fixed negative offset) so it stays on-screen and
	-- keeps its spacing from the edge at any window size; a UISizeConstraint keeps the pills from stretching
	-- too wide on ultrawide windows or shrinking unreadably on small ones.
	local tabBar = Instance.new("Frame")
	tabBar.AnchorPoint = Vector2.new(1, 0)
	-- AutomaticSize + a right anchor: the bar is exactly as wide as its tabs and grows leftward from the edge,
	-- so it can never run past the screen. The old fixed 0.34-scale width clipped the third tab on a phone
	-- (measured: 410px of tabs inside a 309px bar, last tab ending 76px off-screen).
	tabBar.AutomaticSize = Enum.AutomaticSize.X
	tabBar.Size = UDim2.new(0, 0, 0, portrait and 40 or 50)
	if portrait then
		tabBar.AnchorPoint = Vector2.new(0.5, 0)
		tabBar.Position = UDim2.new(0.5, 0, 0, TOP_BAR + 62)
	else
		tabBar.Position = UDim2.new(1, -24, 0, TOP_BAR + 24)
	end
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = root
	Responsive.Scale(tabBar)
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tabLayout.Parent = tabBar

	self.tabs = {}
	for _, mode in ipairs(MODE_ORDER) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 130, 1, 0)
		btn.Text = mode == "Roleplay" and "Roleplay Mode" or (mode .. " Mode")
		btn.Font = Enum.Font.SourceSansBold
		btn.TextSize = 16
		btn.TextColor3 = mode == "Roleplay" and Color3.fromRGB(30, 24, 10) or TEXT_LIGHT
		btn.BackgroundColor3 = mode == "Roleplay" and ACCENT or GLASS
		btn.BackgroundTransparency = mode == "Roleplay" and 0 or 0.85
		btn.AutoButtonColor = ACTIVE_MODES[mode] == true
		btn.Parent = tabBar
		corner(btn, UDim.new(1, 0))
		glassStroke(btn, 0.7)
		self.tabs[mode] = btn
	end

	-- channel list — scale-based on every axis (including height) so it fills whatever's left below the header
	-- instead of a fixed 560px, and AutomaticCanvasSize means it never needs a manually-computed canvas height.
	local list = Instance.new("ScrollingFrame")
	list.AnchorPoint = Vector2.new(0.5, 0)
	-- On a phone the header eats proportionally more of a short screen, so the list starts higher and keeps a
	-- smaller bottom margin than on desktop.
	local headerDrop = portrait and 112 or (Responsive.IsSmallScreen() and 78 or 96)
	-- Portrait leaves room at the bottom for the touch controls, which sit over the lower corners.
	local bottomMargin = portrait and 150 or (Responsive.IsSmallScreen() and 96 or 140)
	list.Size = UDim2.new(0.94, 0, 1, -TOP_BAR - bottomMargin)
	list.Position = UDim2.new(0.5, 0, 0, TOP_BAR + headerDrop)
	-- Glass panel: background image/gradient shows through instead of flat black. The touch action buttons
	-- reuse these exact values (Responsive.Glass*) so the two surfaces read as one material.
	list.BackgroundColor3 = Responsive.GlassColor
	list.BackgroundTransparency = Responsive.GlassTransparency
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = ACCENT
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = root
	corner(list, UDim.new(0, 20))
	glassStroke(list, 0.8)
	local listSizeConstraint = Instance.new("UISizeConstraint")
	listSizeConstraint.MinSize = Vector2.new(480, 260)
	listSizeConstraint.Parent = list
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 20)
	pad.PaddingRight = UDim.new(0, 20)
	pad.PaddingTop = UDim.new(0, 20)
	pad.PaddingBottom = UDim.new(0, 20)
	pad.Parent = list

	-- Phone rows are shorter and give the avatar strip less room, because a landscape phone is short: five
	-- 130px rows plus the header do not fit, and the 44px avatar cells overflow the card.
	local small = Responsive.IsSmallScreen()
	local ROW_H = portrait and 96 or (small and 88 or 130)
	local NAME_W = portrait and 56 or (small and 62 or 100)
	-- Reserved for the count/status/JOIN cluster. In portrait this is a FRACTION of the row rather than a
	-- fixed pixel width: a 720px-wide phone cannot spare 190px, and a fixed reservation pushed JOIN off the
	-- right edge entirely (which is what the portrait screenshot showed).
	local RIGHT_W = portrait and 96 or (small and 128 or 190)
	local AVATAR_CELL = portrait and 22 or (small and 26 or 44)
	local AVATAR_H = portrait and 48 or (small and 56 or 90)
	local JOIN_W = portrait and 68 or (small and 74 or 90)
	local JOIN_H = portrait and 30 or (small and 32 or 40)

	self.rows.Roleplay = {}
	for channel = 1, 5 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, ROW_H)
		row.BackgroundColor3 = GLASS
		row.BackgroundTransparency = 0.9 -- frosted glass card, not a flat gray block
		row.BorderSizePixel = 0
		row.LayoutOrder = channel
		row.Parent = list
		corner(row)
		glassStroke(row, 0.75)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, NAME_W, 1, 0)
		nameLabel.Position = UDim2.new(0, small and 12 or 20, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.SourceSansBold
		nameLabel.TextSize = small and 16 or 22
		nameLabel.TextColor3 = TEXT_LIGHT
		nameLabel.Text = "เชิฟ " .. channel
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		-- avatar strip stretches with the row's own width (relative Size, not a fixed 700px) instead of
		-- overflowing past the card edge on a narrower window.
		local avatarGrid = Instance.new("Frame")
		avatarGrid.Size = UDim2.new(1, -(NAME_W + RIGHT_W + (small and 30 or 40)), 0, AVATAR_H)
		avatarGrid.Position = UDim2.new(0, NAME_W + (small and 18 or 24), 0.5, -AVATAR_H / 2)
		avatarGrid.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		avatarGrid.BackgroundTransparency = 0.55
		avatarGrid.BorderSizePixel = 0
		avatarGrid.Parent = row
		corner(avatarGrid, UDim.new(0, 6))
		local avatarGridConstraint = Instance.new("UISizeConstraint")
		avatarGridConstraint.MinSize = Vector2.new(small and 90 or 160, AVATAR_H)
		avatarGridConstraint.Parent = avatarGrid
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0, AVATAR_CELL, 0, small and 24 or 40)
		grid.CellPadding = UDim2.new(0, 2, 0, 2)
		grid.Parent = avatarGrid
		local gpad = Instance.new("UIPadding")
		gpad.PaddingLeft = UDim.new(0, 5)
		gpad.PaddingTop = UDim.new(0, 5)
		gpad.Parent = avatarGrid

		local avatars = {}
		for i = 1, CAP do
			local icon = Instance.new("ImageLabel")
			icon.Image = ""
			icon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			icon.LayoutOrder = i
			icon.Visible = false
			icon.Parent = avatarGrid
			corner(icon, UDim.new(1, 0))
			avatars[i] = icon
		end

		local countLabel = Instance.new("TextLabel")
		countLabel.Size = UDim2.new(0, small and 60 or 90, 0, small and 26 or 40)
		countLabel.Position = UDim2.new(1, -RIGHT_W, 0, small and 10 or 20)
		countLabel.BackgroundTransparency = 1
		countLabel.Font = Enum.Font.SourceSansBold
		countLabel.TextSize = small and 16 or 22
		countLabel.TextColor3 = TEXT_LIGHT
		countLabel.Text = "0/" .. CAP
		countLabel.Parent = row

		local statusLabel = Instance.new("TextLabel")
		statusLabel.Size = UDim2.new(0, RIGHT_W, 0, small and 16 or 20)
		statusLabel.Position = UDim2.new(1, -RIGHT_W, 0, small and 38 or 60)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Font = Enum.Font.SourceSans
		statusLabel.TextSize = small and 11 or 14
		statusLabel.TextColor3 = Color3.fromRGB(230, 110, 100)
		statusLabel.Text = ""
		statusLabel.Parent = row

		local joinButton = Instance.new("TextButton")
		joinButton.Size = UDim2.new(0, JOIN_W, 0, JOIN_H)
		joinButton.Position = UDim2.new(1, -JOIN_W - (small and 6 or 0), 1, -JOIN_H - (small and 8 or 20))
		joinButton.Font = Enum.Font.SourceSansBold
		joinButton.TextSize = small and 15 or 18
		joinButton.TextColor3 = Color3.new(1, 1, 1)
		joinButton.BackgroundColor3 = Color3.fromRGB(52, 178, 108)
		joinButton.Text = "JOIN"
		joinButton.Parent = row
		corner(joinButton, UDim.new(0, 10))
		local joinGradient = Instance.new("UIGradient")
		joinGradient.Color = ColorSequence.new(Color3.fromRGB(66, 196, 124), Color3.fromRGB(38, 150, 90))
		joinGradient.Rotation = 90
		joinGradient.Parent = joinButton
		joinButton.MouseButton1Click:Connect(function()
			if self.onJoin then self.onJoin("Roleplay", channel) end
		end)

		self.rows.Roleplay[channel] = {
			frame = row, countLabel = countLabel, joinButton = joinButton, statusLabel = statusLabel, avatars = avatars,
		}
	end

	-- Stories/Tanding: a single "coming soon" placeholder frame each, swapped in when that tab is selected
	for _, mode in ipairs({ "Stories", "Tanding" }) do
		local soon = Instance.new("TextLabel")
		soon.Size = UDim2.new(1, 0, 1, 0)
		soon.BackgroundTransparency = 1
		soon.Font = Enum.Font.SourceSansBold
		soon.TextSize = 28
		soon.TextColor3 = TEXT_MUTED
		soon.Text = "เร็วๆ นี้"
		soon.Visible = false
		soon.Parent = root
		self.rows[mode] = { comingSoon = soon }
	end

	-- Blackout: covers the entire screen (gui itself now ignores the inset, so this reaches under Roblox's top
	-- bar too) the instant a join is confirmed, so a second click on this screen is physically impossible
	-- (Active=true swallows all input) while the real teleport / next loading screen takes over.
	local blackout = Instance.new("Frame")
	blackout.Name = "Blackout"
	blackout.Size = UDim2.fromScale(1, 1)
	blackout.BackgroundColor3 = Color3.new(0, 0, 0)
	blackout.BackgroundTransparency = 0
	blackout.BorderSizePixel = 0
	blackout.ZIndex = 1000
	blackout.Visible = false
	blackout.Active = true
	blackout.Parent = gui
	self.blackout = blackout

	self.list = list
	self.gui = gui
	self:_selectMode("Roleplay")
	for mode, btn in pairs(self.tabs) do
		btn.MouseButton1Click:Connect(function()
			if not self._locked and ACTIVE_MODES[mode] then self:_selectMode(mode) end
		end)
	end
	return self
end

function ChannelSelectGui:_selectMode(mode)
	self.list.Visible = (mode == "Roleplay")
	for _, m in ipairs(MODE_ORDER) do
		if self.rows[m] and self.rows[m].comingSoon then
			self.rows[m].comingSoon.Visible = (m == mode)
		end
		self.tabs[m].BackgroundColor3 = (m == mode) and ACCENT or GLASS
		self.tabs[m].BackgroundTransparency = (m == mode) and 0 or 0.85
		self.tabs[m].TextColor3 = (m == mode) and Color3.fromRGB(30, 24, 10) or TEXT_LIGHT
	end
end

function ChannelSelectGui:OnJoin(callback)
	self.onJoin = callback
end

function ChannelSelectGui:SetChannelData(mode, channel, data)
	local row = self.rows[mode] and self.rows[mode][channel]
	if not row then return end
	row.countLabel.Text = data.count .. "/" .. CAP
	row.joinButton.Text = data.full and "FULL" or "JOIN"
	row.joinButton.BackgroundColor3 = data.full and Color3.fromRGB(200, 60, 50) or Color3.fromRGB(52, 178, 108)
	row.joinButton.Active = not data.full and not self._locked
	for i, icon in ipairs(row.avatars) do
		icon.Visible = i <= data.count
	end
	row._playerIds = data.playerIds
end

function ChannelSelectGui:SetRowAvatarImage(mode, channel, slotIndex, content)
	local row = self.rows[mode] and self.rows[mode][channel]
	if row and row.avatars[slotIndex] then
		row.avatars[slotIndex].Image = content or ""
	end
end

function ChannelSelectGui:SetRowStatus(mode, channel, status)
	local row = self.rows[mode] and self.rows[mode][channel]
	if not row then return end
	local text = { idle = "", connecting = "กำลังเชื่อมต่อ...", error = "เชื่อมต่อไม่สำเร็จ ลองอีกครั้ง" }
	row.statusLabel.Text = text[status] or ""
	row.joinButton.Active = (status ~= "connecting") and not self._locked
end

-- Lock: blacks out the whole screen instantly and disables every button, so a confirmed join can't be clicked
-- twice. Call this the moment a join is fired, not after the server answers.
function ChannelSelectGui:Lock()
	if self._locked then return end
	self._locked = true
	self.blackout.Visible = true
	for _, btn in pairs(self.tabs) do
		btn.Active = false
	end
	for _, row in pairs(self.rows.Roleplay) do
		row.joinButton.Active = false
	end
end

-- Unlock: only used to recover from a failed join (JoinFailed / timeout) so the player can try again.
function ChannelSelectGui:Unlock()
	if not self._locked then return end
	self._locked = false
	self.blackout.Visible = false
	for mode, btn in pairs(self.tabs) do
		btn.Active = ACTIVE_MODES[mode] == true
	end
	for _, row in pairs(self.rows.Roleplay) do
		row.joinButton.Active = true
	end
end

function ChannelSelectGui:Show()
	self.gui.Enabled = true
end

function ChannelSelectGui:Destroy()
	self.gui:Destroy()
end

return ChannelSelectGui
