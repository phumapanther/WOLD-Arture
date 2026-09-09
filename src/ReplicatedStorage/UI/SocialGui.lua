-- SocialGui: the speaking stone — a rune-carved slab that behaves like a phone.
--
-- Pure builder, like HudGui and InventoryGui: it draws what it is handed and reports taps through
-- callbacks. Every decision belongs to the controller, and every fact to the server.
--
-- Structure: one home screen of eight icons, and one sub-screen per feature. Only one sub-screen is visible
-- at a time, so adding a ninth feature later means adding a page, not rearranging the layout.
local Players = game:GetService("Players")
local SocialConfig = require(script.Parent.Parent.SocialConfig)
local AvatarThumbnails = require(script.Parent.AvatarThumbnails)
local Responsive = require(script.Parent.Responsive)

local SocialGui = {}
SocialGui.__index = SocialGui

-- The stone's palette: cold grey rock, warm rune light. Deliberately close to the lobby's gold-on-black so
-- the two screens read as one game, but colder — this is stone, not parchment.
local STONE = Color3.fromRGB(28, 30, 38)
local STONE_DEEP = Color3.fromRGB(18, 19, 25)
local RUNE = Color3.fromRGB(126, 214, 232)
local ACCENT = Color3.fromRGB(216, 172, 84)
local TEXT_LIGHT = Color3.fromRGB(238, 240, 246)
local TEXT_MUTED = Color3.fromRGB(150, 156, 172)
local OK_GREEN = Color3.fromRGB(104, 196, 118)
local BAD_RED = Color3.fromRGB(224, 96, 84)

local function corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 10)
	c.Parent = instance
	return c
end

local function stroke(instance, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or RUNE
	s.Transparency = transparency or 0.6
	s.Thickness = thickness or 1
	s.Parent = instance
	return s
end

local function label(parent, text, size, color, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size or 14
	l.TextColor3 = color or TEXT_LIGHT
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Text = text or ""
	l.Parent = parent
	return l
end

local function button(parent, text, size, color)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color or Color3.fromRGB(44, 48, 60)
	b.BackgroundTransparency = 0.1
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextSize = size or 14
	b.TextColor3 = TEXT_LIGHT
	b.Text = text or ""
	b.Parent = parent
	corner(b, UDim.new(0, 8))
	return b
end

local function textBox(parent, placeholder)
	local box = Instance.new("TextBox")
	box.BackgroundColor3 = STONE_DEEP
	box.BackgroundTransparency = 0.15
	box.BorderSizePixel = 0
	box.Font = Enum.Font.Gotham
	box.TextSize = 14
	box.TextColor3 = TEXT_LIGHT
	box.PlaceholderText = placeholder or ""
	box.PlaceholderColor3 = TEXT_MUTED
	box.ClearTextOnFocus = false
	box.Text = ""
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Parent = parent
	corner(box, UDim.new(0, 8))
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = box
	return box
end

-- A scrolling column that grows with its contents, used by every list on the stone.
local function scrollList(parent, padding)
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = RUNE
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding or 6)
	layout.Parent = list
	return list, layout
end

-- Pages whose contents are positioned in fixed pixels can be taller than the stone on a short screen, so
-- they scroll. AutomaticCanvasSize means the canvas is exactly as tall as the content, which makes this a
-- no-op wherever the whole page already fits.
local function scrollPage(parent, name, contentHeight)
	local page = Instance.new("ScrollingFrame")
	page.Name = name
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 4
	page.ScrollBarImageColor3 = RUNE
	page.ScrollingDirection = Enum.ScrollingDirection.Y
	page.Visible = false
	-- These pages position children absolutely rather than with a layout, so AutomaticCanvasSize has
	-- nothing to measure; the height is stated instead.
	page.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
	page.Parent = parent
	return page
end

--------------------------------------------------------------------------------

function SocialGui.new()
	local self = setmetatable({}, SocialGui)
	self.callbacks = {}
	self.screens = {}
	self.current = "home"

	local gui = Instance.new("ScreenGui")
	gui.Name = "SocialGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Enabled = false
	self.gui = gui

	local small = Responsive.IsSmallScreen()

	-- The slab. Tall and narrow like a phone, but capped so it never becomes a billboard on a monitor.
	local panel = Instance.new("Frame")
	panel.Name = "Stone"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	-- 0.9 of the height plus the UIScale below pushed the slab past the top edge on a short screen
	-- (measured: y = -19 on an 908x542 viewport). 0.82 leaves room for the scale and the phone notch.
	panel.Size = small and UDim2.fromScale(0.92, 0.82) or UDim2.fromScale(0.5, 0.82)
	panel.BackgroundColor3 = STONE
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui
	self.panel = panel

	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(560, 660)
	-- No tall floor on a phone: a minimum bigger than the screen is what forces the slab off the edge.
	size.MinSize = small and Vector2.new(260, 260) or Vector2.new(280, 320)
	size.Parent = panel

	corner(panel, UDim.new(0, 18))
	stroke(panel, RUNE, 0.45, 2)

	-- A faint vertical gradient gives the slab depth without any artwork.
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(38, 41, 52), Color3.fromRGB(16, 17, 22))
	grad.Rotation = 90
	grad.Parent = panel

	--------------------------------------------------------------------------
	-- Header: back arrow, title, close cross.
	--------------------------------------------------------------------------
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 48)
	header.BackgroundTransparency = 1
	header.Parent = panel

	local back = Instance.new("TextButton")
	back.Name = "Back"
	back.Position = UDim2.new(0, 12, 0, 10)
	back.Size = UDim2.fromOffset(30, 28)
	back.BackgroundTransparency = 1
	back.Font = Enum.Font.GothamBold
	back.TextSize = 20
	back.TextColor3 = RUNE
	back.Text = "\226\128\185" -- ‹
	back.Visible = false
	back.Parent = header
	self.backButton = back

	local title = label(header, "หินเวทสื่อสาร", 17, ACCENT, Enum.TextXAlignment.Center)
	title.Size = UDim2.new(1, -100, 0, 28)
	title.Position = UDim2.new(0, 50, 0, 10)
	title.Font = Enum.Font.GothamBold
	self.title = title

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Size = UDim2.fromOffset(28, 28)
	close.BackgroundColor3 = Color3.fromRGB(52, 48, 56)
	close.BackgroundTransparency = 0.3
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBold
	close.TextSize = 16
	close.TextColor3 = TEXT_LIGHT
	close.Text = "\195\151" -- ×
	close.Parent = header
	corner(close, UDim.new(1, 0))
	self.closeButton = close

	-- A rune line under the header, purely so the slab reads as carved rather than as a plain box.
	local divider = Instance.new("Frame")
	divider.Position = UDim2.new(0, 16, 0, 47)
	divider.Size = UDim2.new(1, -32, 0, 1)
	divider.BackgroundColor3 = RUNE
	divider.BackgroundTransparency = 0.7
	divider.BorderSizePixel = 0
	divider.Parent = panel

	self:buildStatusBar(panel)

	-- Everything between the status bar and the nav bar. Screens swap inside it.
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.new(0, 14, 0, 76)
	body.Size = UDim2.new(1, -28, 1, -76 - 62)
	body.BackgroundTransparency = 1
	body.Parent = panel
	self.body = body

	self:buildNavBar(panel)

	-- A status line along the bottom: every reply from the server lands here.
	local status = label(panel, "", 12, TEXT_MUTED, Enum.TextXAlignment.Center)
	status.AnchorPoint = Vector2.new(0.5, 1)
	status.Position = UDim2.new(0.5, 0, 1, -12)
	status.Size = UDim2.new(1, -28, 0, 30)
	status.TextWrapped = true
	self.status = status

	self:buildHome()
	self:buildBoard()
	self:buildFriends()
	self:buildBank()
	self:buildProfile()
	self:buildSettings()
	self:buildNotice()

	back.Activated:Connect(function() self:ShowScreen("home") end)
	close.Activated:Connect(function() self:Hide() end)

	Responsive.Scale(panel, small and 0.95 or 0.75)
	self:ShowScreen("home")
	return self
end

--------------------------------------------------------------------------------
-- Home: the eight icons
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- The handset chrome: a status bar across the top, a nav bar along the bottom
--------------------------------------------------------------------------------

-- Signal bars, battery and clock. None of it is real -- there is no power system and a rune stone has no
-- cell -- but a handset without them does not read as a handset, and the clock at least tells the truth.
function SocialGui:buildStatusBar(panel)
	local bar = Instance.new("Frame")
	bar.Name = "StatusBar"
	bar.Position = UDim2.new(0, 14, 0, 52)
	bar.Size = UDim2.new(1, -28, 0, 20)
	bar.BackgroundTransparency = 1
	bar.Parent = panel

	-- Left: the date and time, from the player's own clock.
	local clock = label(bar, "", 11, TEXT_MUTED)
	clock.Size = UDim2.new(0.55, 0, 1, 0)
	self.clockLabel = clock

	-- Right: signal bars, then the battery.
	local right = Instance.new("Frame")
	right.AnchorPoint = Vector2.new(1, 0.5)
	right.Position = UDim2.new(1, 0, 0.5, 0)
	right.Size = UDim2.fromOffset(74, 14)
	right.BackgroundTransparency = 1
	right.Parent = bar

	-- Four rising bars, the usual shorthand for signal.
	self.signalBars = {}
	for i = 1, 4 do
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0, 1)
		b.Position = UDim2.new(0, (i - 1) * 5, 1, 0)
		b.Size = UDim2.fromOffset(3, 3 + i * 2.5)
		b.BackgroundColor3 = RUNE
		b.BorderSizePixel = 0
		b.Parent = right
		self.signalBars[i] = b
	end

	-- The battery: a shell, a tip, and a fill that shrinks.
	local shell = Instance.new("Frame")
	shell.AnchorPoint = Vector2.new(1, 0.5)
	shell.Position = UDim2.new(1, -3, 0.5, 0)
	shell.Size = UDim2.fromOffset(24, 12)
	shell.BackgroundTransparency = 1
	shell.Parent = right
	corner(shell, UDim.new(0, 3))
	local shellStroke = Instance.new("UIStroke")
	shellStroke.Color = TEXT_MUTED
	shellStroke.Thickness = 1
	shellStroke.Parent = shell

	local tip = Instance.new("Frame")
	tip.AnchorPoint = Vector2.new(0, 0.5)
	tip.Position = UDim2.new(1, 1, 0.5, 0)
	tip.Size = UDim2.fromOffset(2, 5)
	tip.BackgroundColor3 = TEXT_MUTED
	tip.BorderSizePixel = 0
	tip.Parent = shell

	local fill = Instance.new("Frame")
	fill.Position = UDim2.fromOffset(2, 2)
	fill.Size = UDim2.new(1, -4, 1, -4)
	fill.BackgroundColor3 = OK_GREEN
	fill.BorderSizePixel = 0
	fill.Parent = shell
	corner(fill, UDim.new(0, 2))
	self.batteryFill = fill

	self.battery = 1
	self.batteryStartedAt = os.clock()
	self:refreshStatusBar()
end

function SocialGui:refreshStatusBar()
	if not self.clockLabel then return end

	local now = os.date("*t")
	self.clockLabel.Text = ("%02d/%02d/%d  %02d:%02d"):format(
		now.day, now.month, now.year, now.hour, now.min)

	-- The battery drains slowly and settles at a floor rather than reaching zero: it is decoration, and a
	-- dead battery would imply the stone stops working, which it never does.
	local minutes = (os.clock() - (self.batteryStartedAt or os.clock())) / 60
	local level = math.max(SocialConfig.BatteryMin,
		1 - minutes * (SocialConfig.BatteryDrainPerMinute / 100))
	self.battery = level
	self.batteryFill.Size = UDim2.new(level, -4, 1, -4)
	self.batteryFill.BackgroundColor3 = level > 0.5 and OK_GREEN
		or level > 0.25 and Color3.fromRGB(216, 172, 84)
		or BAD_RED

	-- Signal wanders a little so it does not look painted on, but never drops below two bars: nothing in
	-- the game depends on it, and a player watching it fall would reasonably expect it to matter.
	local strength = 3 + math.floor(math.abs(math.sin(os.clock() / 11)) * 1.99)
	for i, b in ipairs(self.signalBars) do
		b.BackgroundTransparency = i <= strength and 0 or 0.75
	end
end

-- Home, call and settings, the way a handset puts them.
function SocialGui:buildNavBar(panel)
	local bar = Instance.new("Frame")
	bar.Name = "NavBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -10)
	bar.Size = UDim2.new(1, -28, 0, 44)
	bar.BackgroundColor3 = STONE_DEEP
	bar.BackgroundTransparency = 0.35
	bar.BorderSizePixel = 0
	bar.Parent = panel
	corner(bar, UDim.new(0, 12))

	local function navButton(order, name, draw)
		local b = Instance.new("TextButton")
		b.Name = name
		b.Position = UDim2.new(order / 3, 0, 0, 0)
		b.Size = UDim2.new(1 / 3, 0, 1, 0)
		b.BackgroundTransparency = 1
		b.Text = ""
		b.Parent = bar

		local holder = Instance.new("Frame")
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.Size = UDim2.fromOffset(22, 22)
		holder.BackgroundTransparency = 1
		holder.Parent = b
		draw(holder)
		return b
	end

	-- Icons drawn from frames, like the touch buttons: nothing to upload and nothing an encoding step can
	-- corrupt.
	local function shape(parent, x, y, w, h, rotation, radius, transparency)
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

	local call = navButton(0, "Call", function(h)
		-- A handset: a bar rotated with two ends, which is the shape everyone reads as "phone".
		shape(h, 0.5, 0.5, 0.24, 0.7, -40, 0.4)
		shape(h, 0.28, 0.28, 0.34, 0.3, -40, 0.5)
		shape(h, 0.72, 0.72, 0.34, 0.3, -40, 0.5)
	end)
	call.Activated:Connect(function() self:ShowScreen("friends") end)

	local home = navButton(1, "Home", function(h)
		-- A house: roof over a body.
		shape(h, 0.5, 0.3, 0.62, 0.34, 45, 0.12)
		shape(h, 0.5, 0.66, 0.62, 0.44, 0, 0.12)
	end)
	home.Activated:Connect(function() self:ShowScreen("home") end)

	local settings = navButton(2, "Settings", function(h)
		-- A gear, suggested by a ring and four teeth.
		local ring = shape(h, 0.5, 0.5, 0.5, 0.5, 0, 0.5)
		ring.BackgroundTransparency = 1
		local s = Instance.new("UIStroke")
		s.Color = TEXT_LIGHT
		s.Thickness = 2.5
		s.Parent = ring
		for i = 0, 3 do
			shape(h, 0.5 + math.cos(i * math.pi / 2) * 0.36, 0.5 + math.sin(i * math.pi / 2) * 0.36,
				0.2, 0.2, i * 45, 0.3)
		end
	end)
	settings.Activated:Connect(function() self:ShowScreen("settings") end)

	self.navBar = bar
end

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

-- Mute calls, mute chat notices, and pick the wallpaper. Kept on the client: none of it changes what the
-- server does, only what this player hears and sees.
function SocialGui:buildSettings()
	local page = scrollPage(self.body, "settings", 300)
	self.screens.settings = page

	self.settings = self.settings or { muteCalls = false, muteChat = false, wallpaper = "rune" }

	local y = 0
	local function toggleRow(caption, key)
		local row = Instance.new("Frame")
		row.Position = UDim2.new(0, 0, 0, y)
		row.Size = UDim2.new(1, 0, 0, 40)
		row.BackgroundColor3 = STONE_DEEP
		row.BackgroundTransparency = 0.4
		row.BorderSizePixel = 0
		row.Parent = page
		corner(row, UDim.new(0, 8))

		local name = label(row, caption, 13, TEXT_LIGHT)
		name.Position = UDim2.new(0, 12, 0, 0)
		name.Size = UDim2.new(1, -80, 1, 0)

		-- A switch rather than a checkbox: the state has to be readable at a glance on a small screen.
		local track = Instance.new("TextButton")
		track.AnchorPoint = Vector2.new(1, 0.5)
		track.Position = UDim2.new(1, -12, 0.5, 0)
		track.Size = UDim2.fromOffset(44, 22)
		track.BackgroundColor3 = Color3.fromRGB(52, 56, 68)
		track.BorderSizePixel = 0
		track.Text = ""
		track.Parent = row
		corner(track, UDim.new(1, 0))

		local knob = Instance.new("Frame")
		knob.AnchorPoint = Vector2.new(0, 0.5)
		knob.Size = UDim2.fromOffset(18, 18)
		knob.BackgroundColor3 = TEXT_LIGHT
		knob.BorderSizePixel = 0
		knob.Parent = track
		corner(knob, UDim.new(1, 0))

		local function paint()
			local on = self.settings[key]
			knob.Position = UDim2.new(0, on and 24 or 2, 0.5, 0)
			track.BackgroundColor3 = on and OK_GREEN or Color3.fromRGB(52, 56, 68)
		end
		paint()

		track.Activated:Connect(function()
			self.settings[key] = not self.settings[key]
			paint()
			if self.callbacks.settingsChanged then
				self.callbacks.settingsChanged(self.settings)
			end
		end)

		y = y + 48
		return row
	end

	toggleRow("ปิดเสียงโทรเข้า", "muteCalls")
	toggleRow("ปิดแจ้งเตือนแชท", "muteChat")

	local head = label(page, "พื้นหลังหน้าจอ", 12, TEXT_MUTED)
	head.Position = UDim2.new(0, 0, 0, y + 6)
	head.Size = UDim2.new(1, 0, 0, 18)
	y = y + 28

	-- The wallpapers, as swatches. Tapping one applies it immediately, so the choice is its own preview.
	local strip = Instance.new("Frame")
	strip.Position = UDim2.new(0, 0, 0, y)
	strip.Size = UDim2.new(1, 0, 0, 56)
	strip.BackgroundTransparency = 1
	strip.Parent = page

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.Parent = strip

	self.wallpaperSwatches = {}
	for _, paper in ipairs(SocialConfig.Wallpapers) do
		local swatch = Instance.new("TextButton")
		swatch.Size = UDim2.fromOffset(46, 56)
		swatch.BackgroundColor3 = paper.from
		swatch.BorderSizePixel = 0
		swatch.Text = ""
		swatch.Parent = strip
		corner(swatch, UDim.new(0, 8))

		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(paper.from, paper.to)
		g.Rotation = 90
		g.Parent = swatch

		local ring = Instance.new("UIStroke")
		ring.Color = ACCENT
		ring.Thickness = 2
		ring.Transparency = 1
		ring.Parent = swatch

		self.wallpaperSwatches[paper.id] = ring
		swatch.Activated:Connect(function()
			self.settings.wallpaper = paper.id
			self:ApplyWallpaper(paper.id)
			if self.callbacks.settingsChanged then
				self.callbacks.settingsChanged(self.settings)
			end
		end)
	end
	y = y + 68

	local note = label(page, "การตั้งค่าเก็บเฉพาะเครื่องนี้", 11, TEXT_MUTED,
		Enum.TextXAlignment.Center)
	note.Position = UDim2.new(0, 0, 0, y)
	note.Size = UDim2.new(1, 0, 0, 18)
end

-- Repaints the home screen behind the icons, and marks which swatch is chosen.
function SocialGui:ApplyWallpaper(id)
	local paper = SocialConfig.WallpaperFor(id)
	if self.wallpaper then
		self.wallpaper.Color = ColorSequence.new(paper.from, paper.to)
	end
	for swatchId, ring in pairs(self.wallpaperSwatches or {}) do
		ring.Transparency = swatchId == paper.id and 0 or 1
	end
end

function SocialGui:SetSettings(settings)
	self.settings = settings
	self:ApplyWallpaper(settings.wallpaper)
end

function SocialGui:buildHome()
	-- A ScrollingFrame, not a plain one: nine tiles need three rows, and a landscape phone is short enough
	-- that the last row falls off the bottom of the stone. Scrolling costs nothing on a screen tall enough
	-- to show them all, because the canvas only grows to fit what is there.
	local page = Instance.new("ScrollingFrame")
	page.Name = "home"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 4
	page.ScrollBarImageColor3 = RUNE
	page.ScrollingDirection = Enum.ScrollingDirection.Y
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new()
	page.Parent = self.body
	self.screens.home = page

	-- The wallpaper, behind the icons. A gradient on a frame rather than an image: nothing to upload, and
	-- one more thing that cannot go missing.
	--
	-- Parented to the BODY, not to the scrolling page: UIGridLayout lays out every child it is given, so a
	-- wallpaper inside the page was counted as a cell and appeared as an empty tile in the first slot. It
	-- also should not scroll with the icons.
	local paper = Instance.new("Frame")
	paper.Name = "Wallpaper"
	paper.Size = UDim2.fromScale(1, 1)
	paper.BackgroundColor3 = Color3.fromRGB(26, 38, 54)
	paper.BorderSizePixel = 0
	paper.ZIndex = 0
	paper.Visible = false -- shown only while the home screen is
	paper.Parent = self.body
	corner(paper, UDim.new(0, 10))
	local paperGradient = Instance.new("UIGradient")
	paperGradient.Rotation = 90
	paperGradient.Parent = paper
	self.wallpaper = paperGradient
	self.wallpaperFrame = paper

	local grid = Instance.new("UIGridLayout")
	-- Tiles shrink a little on a small screen so three fit across without the scroll bar clipping one.
	grid.CellSize = UDim2.new(0.33, -10, 0, Responsive.IsSmallScreen() and 82 or 92)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = page

	-- Without padding the last row sits flush against the bottom edge and reads as cut off even when it
	-- has scrolled fully into view.
	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = page

	for i, screen in ipairs(SocialConfig.Screens) do
		local tile = Instance.new("TextButton")
		tile.Name = screen.id
		tile.LayoutOrder = i
		tile.BackgroundColor3 = STONE_DEEP
		tile.BackgroundTransparency = 0.25
		tile.BorderSizePixel = 0
		tile.Text = ""
		tile.Parent = page
		corner(tile, UDim.new(0, 12))
		-- Buttons that do not work yet are dimmer, so the difference is visible before tapping.
		stroke(tile, screen.ready and RUNE or TEXT_MUTED, screen.ready and 0.55 or 0.8, 1)

		local glyph = label(tile, screen.glyph, 30, screen.ready and RUNE or TEXT_MUTED,
			Enum.TextXAlignment.Center)
		glyph.Size = UDim2.new(1, 0, 0, 42)
		glyph.Position = UDim2.new(0, 0, 0, 14)

		local name = label(tile, screen.name, 12, screen.ready and TEXT_LIGHT or TEXT_MUTED,
			Enum.TextXAlignment.Center)
		name.Size = UDim2.new(1, -8, 0, 30)
		name.Position = UDim2.new(0, 4, 0, 56)
		name.TextWrapped = true

		tile.Activated:Connect(function()
			-- The map is not a page inside the stone; it is its own screen, so the tile hands it off.
			if screen.id == "map" then
				self:Hide()
				if self.callbacks.openMap then self.callbacks.openMap() end
			elseif screen.ready then
				self:ShowScreen(screen.id)
			else
				-- Not a dead button: say why, or the player will think the game froze.
				self:ShowNotice(screen.name, screen.notice or "ยังไม่เปิดใช้งาน")
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- Board
--------------------------------------------------------------------------------

function SocialGui:buildBoard()
	local page = Instance.new("Frame")
	page.Name = "board"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = self.body
	self.screens.board = page

	local list = scrollList(page, 8)
	list.Size = UDim2.new(1, 0, 1, -46)
	self.boardList = list

	local box = textBox(page, "เขียนประกาศ...")
	box.AnchorPoint = Vector2.new(0, 1)
	box.Position = UDim2.new(0, 0, 1, 0)
	box.Size = UDim2.new(1, -86, 0, 34)
	self.boardBox = box

	local post = button(page, "ส่ง", 14, Color3.fromRGB(58, 96, 78))
	post.AnchorPoint = Vector2.new(1, 1)
	post.Position = UDim2.new(1, 0, 1, 0)
	post.Size = UDim2.fromOffset(78, 34)

	local function submit()
		local text = box.Text
		if text == "" then return end
		box.Text = ""
		if self.callbacks.post then self.callbacks.post(text) end
	end
	post.Activated:Connect(submit)
	box.FocusLost:Connect(function(enter) if enter then submit() end end)
end

-- One post row: headshot, name, text, and how long ago.
local function agoText(at)
	local seconds = os.time() - (at or 0)
	if seconds < 60 then return "เมื่อสักครู่" end
	if seconds < 3600 then return ("%d นาทีที่แล้ว"):format(seconds // 60) end
	return ("%d ชั่วโมงที่แล้ว"):format(seconds // 3600)
end

function SocialGui:RenderBoard(posts)
	local list = self.boardList
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	if #posts == 0 then
		local empty = label(list, "ยังไม่มีประกาศ — เขียนอันแรกได้เลย", 13, TEXT_MUTED,
			Enum.TextXAlignment.Center)
		empty.Size = UDim2.new(1, 0, 0, 60)
		empty.Name = "Empty"
		return
	end

	for i, post in ipairs(posts) do
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, -6, 0, 62)
		row.BackgroundColor3 = STONE_DEEP
		row.BackgroundTransparency = 0.35
		row.BorderSizePixel = 0
		row.Parent = list
		corner(row, UDim.new(0, 8))

		local face = Instance.new("ImageLabel")
		face.Position = UDim2.new(0, 8, 0, 8)
		face.Size = UDim2.fromOffset(44, 44)
		face.BackgroundColor3 = STONE
		face.BorderSizePixel = 0
		face.Parent = row
		corner(face, UDim.new(1, 0))
		-- Cached and paced by AvatarThumbnails, so a busy board does not hammer the thumbnail API.
		AvatarThumbnails.Get(post.userId, function(image)
			-- nil until the fetch lands, false if it failed; only a string is a valid Image.
			if face.Parent and type(image) == "string" then face.Image = image end
		end)

		local name = label(row, post.name, 13, ACCENT)
		name.Position = UDim2.new(0, 62, 0, 7)
		name.Size = UDim2.new(1, -150, 0, 16)
		name.Font = Enum.Font.GothamBold

		local when = label(row, agoText(post.at), 11, TEXT_MUTED, Enum.TextXAlignment.Right)
		when.AnchorPoint = Vector2.new(1, 0)
		when.Position = UDim2.new(1, -10, 0, 8)
		when.Size = UDim2.fromOffset(90, 14)

		local text = label(row, post.text, 13, TEXT_LIGHT)
		text.Position = UDim2.new(0, 62, 0, 25)
		text.Size = UDim2.new(1, -72, 0, 32)
		text.TextWrapped = true
		text.TextYAlignment = Enum.TextYAlignment.Top
	end
end

--------------------------------------------------------------------------------
-- Friends
--------------------------------------------------------------------------------

function SocialGui:buildFriends()
	local page = Instance.new("Frame")
	page.Name = "friends"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = self.body
	self.screens.friends = page

	-- Add-a-friend row along the top.
	local box = textBox(page, "ชื่อผู้เล่นในเซิร์ฟเวอร์นี้")
	box.Size = UDim2.new(1, -92, 0, 32)
	self.friendBox = box

	local add = button(page, "เพิ่ม", 13, Color3.fromRGB(58, 84, 110))
	add.AnchorPoint = Vector2.new(1, 0)
	add.Position = UDim2.new(1, 0, 0, 0)
	add.Size = UDim2.fromOffset(84, 32)
	add.Activated:Connect(function()
		local name = box.Text
		if name == "" then return end
		box.Text = ""
		if self.callbacks.friendAction then self.callbacks.friendAction("request", name) end
	end)

	local list = scrollList(page, 6)
	list.Position = UDim2.new(0, 0, 0, 40)
	list.Size = UDim2.new(1, 0, 1, -40)
	self.friendList = list

	-- The conversation view, hidden until a friend is chosen.
	local chat = Instance.new("Frame")
	chat.Name = "Chat"
	chat.Size = UDim2.fromScale(1, 1)
	chat.BackgroundTransparency = 1
	chat.Visible = false
	chat.Parent = page
	self.chatPage = chat

	local who = label(chat, "", 14, ACCENT)
	who.Size = UDim2.new(1, -70, 0, 22)
	who.Font = Enum.Font.GothamBold
	self.chatWho = who

	local back = button(chat, "ย้อนกลับ", 12, Color3.fromRGB(46, 48, 58))
	back.AnchorPoint = Vector2.new(1, 0)
	back.Position = UDim2.new(1, 0, 0, 0)
	back.Size = UDim2.fromOffset(66, 24)
	back.Activated:Connect(function()
		chat.Visible = false
		list.Visible = true
		box.Visible = true
		add.Visible = true
		self.chatWith = nil
	end)
	self.chatBackButton = back
	self.friendAddBox, self.friendAddButton = box, add

	local messages = scrollList(chat, 5)
	messages.Position = UDim2.new(0, 0, 0, 30)
	messages.Size = UDim2.new(1, 0, 1, -76)
	self.chatList = messages

	local msgBox = textBox(chat, "พิมพ์ข้อความ...")
	msgBox.AnchorPoint = Vector2.new(0, 1)
	msgBox.Position = UDim2.new(0, 0, 1, 0)
	msgBox.Size = UDim2.new(1, -150, 0, 32)
	self.chatBox = msgBox

	local send = button(chat, "ส่ง", 13, Color3.fromRGB(58, 96, 78))
	send.AnchorPoint = Vector2.new(1, 1)
	send.Position = UDim2.new(1, -76, 1, 0)
	send.Size = UDim2.fromOffset(68, 32)

	local function submit()
		local text = msgBox.Text
		if text == "" or not self.chatWith then return end
		msgBox.Text = ""
		if self.callbacks.pigeon then self.callbacks.pigeon(self.chatWith, text) end
	end
	send.Activated:Connect(submit)
	msgBox.FocusLost:Connect(function(enter) if enter then submit() end end)

	-- Voice lives on the conversation rather than as its own icon, because that is what it is: a call to
	-- one person. It is not wired up yet; the notice explains why.
	local voice = button(chat, "โทรจิต", 13, Color3.fromRGB(72, 58, 96))
	voice.AnchorPoint = Vector2.new(1, 1)
	voice.Position = UDim2.new(1, 0, 1, 0)
	voice.Size = UDim2.fromOffset(70, 32)
	voice.Activated:Connect(function()
		if not self.chatWith then return end
		if self.callbacks.call then self.callbacks.call(self.chatWith) end
	end)
end

function SocialGui:RenderFriends(friends, pending)
	local list = self.friendList
	for _, child in ipairs(list:GetChildren()) do
		if not child:IsA("UIListLayout") then child:Destroy() end
	end

	local order = 0
	local function row(height)
		order += 1
		local f = Instance.new("Frame")
		f.LayoutOrder = order
		f.Size = UDim2.new(1, -6, 0, height)
		f.BackgroundColor3 = STONE_DEEP
		f.BackgroundTransparency = 0.35
		f.BorderSizePixel = 0
		f.Parent = list
		corner(f, UDim.new(0, 8))
		return f
	end

	-- Requests first: they need an answer, so they should not be scrolled past.
	if #pending > 0 then
		local head = label(list, "คำขอเป็นเพื่อน", 12, ACCENT)
		head.LayoutOrder = 0
		head.Size = UDim2.new(1, 0, 0, 20)
		for _, req in ipairs(pending) do
			local f = row(42)
			local name = label(f, req.name, 13, TEXT_LIGHT)
			name.Position = UDim2.new(0, 12, 0, 0)
			name.Size = UDim2.new(1, -150, 1, 0)

			local yes = button(f, "รับ", 12, Color3.fromRGB(58, 96, 78))
			yes.AnchorPoint = Vector2.new(1, 0.5)
			yes.Position = UDim2.new(1, -74, 0.5, 0)
			yes.Size = UDim2.fromOffset(60, 26)
			yes.Activated:Connect(function()
				if self.callbacks.friendAction then self.callbacks.friendAction("accept", req.userId) end
			end)

			local no = button(f, "ปฏิเสธ", 12, Color3.fromRGB(96, 56, 52))
			no.AnchorPoint = Vector2.new(1, 0.5)
			no.Position = UDim2.new(1, -8, 0.5, 0)
			no.Size = UDim2.fromOffset(62, 26)
			no.Activated:Connect(function()
				if self.callbacks.friendAction then self.callbacks.friendAction("decline", req.userId) end
			end)
		end
	end

	if #friends == 0 then
		local empty = label(list, "ยังไม่มีสหาย — พิมพ์ชื่อคนในเซิร์ฟเวอร์เพื่อขอเป็นเพื่อน", 12,
			TEXT_MUTED, Enum.TextXAlignment.Center)
		empty.LayoutOrder = 99
		empty.Size = UDim2.new(1, 0, 0, 50)
		empty.TextWrapped = true
		return
	end

	for _, friend in ipairs(friends) do
		local f = row(50)

		local dot = Instance.new("Frame")
		dot.Position = UDim2.new(0, 12, 0.5, -4)
		dot.Size = UDim2.fromOffset(8, 8)
		dot.BackgroundColor3 = friend.online and OK_GREEN or TEXT_MUTED
		dot.BorderSizePixel = 0
		dot.Parent = f
		corner(dot, UDim.new(1, 0))

		local name = label(f, friend.name, 13, TEXT_LIGHT)
		name.Position = UDim2.new(0, 28, 0, 0)
		name.Size = UDim2.new(1, -230, 1, 0)
		name.TextTruncate = Enum.TextTruncate.AtEnd

		-- Only an online friend can be messaged, and the button says so rather than failing on tap.
		local talk = button(f, friend.online and "คุย" or "ไม่อยู่", 12,
			friend.online and Color3.fromRGB(58, 84, 110) or Color3.fromRGB(46, 48, 58))
		talk.AnchorPoint = Vector2.new(1, 0.5)
		talk.Position = UDim2.new(1, -136, 0.5, 0)
		talk.Size = UDim2.fromOffset(54, 26)

		-- Telepathy sits next to the chat button because it is the same act aimed at the same person.
		local call = button(f, "โทร", 12,
			friend.online and Color3.fromRGB(72, 58, 96) or Color3.fromRGB(46, 48, 58))
		call.AnchorPoint = Vector2.new(1, 0.5)
		call.Position = UDim2.new(1, -78, 0.5, 0)
		call.Size = UDim2.fromOffset(52, 26)
		call.Activated:Connect(function()
			if not friend.online then
				self:SetStatus("เพื่อนคนนี้ไม่ได้อยู่ในเซิร์ฟเวอร์นี้", "error")
				return
			end
			if self.callbacks.call then self.callbacks.call(friend.userId) end
		end)
		talk.Activated:Connect(function()
			if not friend.online then
				self:SetStatus("เพื่อนคนนี้ไม่ได้อยู่ในเซิร์ฟเวอร์นี้", "error")
				return
			end
			self:OpenChat(friend.userId, friend.name)
		end)

		local drop = button(f, "ลบ", 12, Color3.fromRGB(96, 56, 52))
		drop.AnchorPoint = Vector2.new(1, 0.5)
		drop.Position = UDim2.new(1, -8, 0.5, 0)
		drop.Size = UDim2.fromOffset(62, 26)
		drop.Activated:Connect(function()
			if self.callbacks.friendAction then self.callbacks.friendAction("remove", friend.userId) end
		end)
	end
end

function SocialGui:OpenChat(userId, name)
	self.chatWith = userId
	self.chatWho.Text = name
	self.chatPage.Visible = true
	self.friendList.Visible = false
	self.friendAddBox.Visible = false
	self.friendAddButton.Visible = false
	if self.callbacks.openChat then self.callbacks.openChat(userId) end
end

function SocialGui:RenderChat(messages, selfUserId)
	local list = self.chatList
	for _, child in ipairs(list:GetChildren()) do
		if not child:IsA("UIListLayout") then child:Destroy() end
	end
	for i, m in ipairs(messages) do
		local mine = m.from == selfUserId
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, -6, 0, 34)
		row.BackgroundColor3 = mine and Color3.fromRGB(46, 68, 88) or STONE_DEEP
		row.BackgroundTransparency = 0.3
		row.BorderSizePixel = 0
		row.Parent = list
		corner(row, UDim.new(0, 8))

		local text = label(row, m.text, 13, TEXT_LIGHT, mine and Enum.TextXAlignment.Right
			or Enum.TextXAlignment.Left)
		text.Position = UDim2.new(0, 10, 0, 0)
		text.Size = UDim2.new(1, -20, 1, 0)
		text.TextWrapped = true
	end
	task.defer(function()
		list.CanvasPosition = Vector2.new(0, math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y))
	end)
end

--------------------------------------------------------------------------------
-- Bank
--------------------------------------------------------------------------------

function SocialGui:buildBank()
	local page = scrollPage(self.body, "bank", 260)
	self.screens.bank = page

	-- The two balances, side by side, because the whole point is the difference between them.
	local function balanceCard(x, caption, color)
		local card = Instance.new("Frame")
		card.Position = UDim2.new(x, x > 0 and 5 or 0, 0, 0)
		card.Size = UDim2.new(0.5, -5, 0, 68)
		card.BackgroundColor3 = STONE_DEEP
		card.BackgroundTransparency = 0.3
		card.BorderSizePixel = 0
		card.Parent = page
		corner(card, UDim.new(0, 10))
		local head = label(card, caption, 12, TEXT_MUTED, Enum.TextXAlignment.Center)
		head.Size = UDim2.new(1, 0, 0, 18)
		head.Position = UDim2.new(0, 0, 0, 10)
		local value = label(card, "0", 22, color, Enum.TextXAlignment.Center)
		value.Size = UDim2.new(1, 0, 0, 28)
		value.Position = UDim2.new(0, 0, 0, 30)
		value.Font = Enum.Font.GothamBold
		return value
	end

	self.pocketLabel = balanceCard(0, "ในกระเป๋า (หายเมื่อตาย)", ACCENT)
	self.bankLabel = balanceCard(0.5, "ในธนาคาร (ปลอดภัย)", OK_GREEN)

	-- Depositing and withdrawing are done at the banker NPC, not from here. Saying so is the difference
	-- between a screen that looks unfinished and one that is telling you where to go.
	local hint = label(page, "ฝาก-ถอน ทำที่ NPC ธนาคารในเมือง", 12, TEXT_MUTED, Enum.TextXAlignment.Center)
	hint.Position = UDim2.new(0, 0, 0, 78)
	hint.Size = UDim2.new(1, 0, 0, 18)

	local head = label(page, "โอนเงิน (ผู้รับต้องอยู่ในเซิร์ฟเวอร์นี้)", 12, TEXT_MUTED)
	head.Position = UDim2.new(0, 0, 0, 106)
	head.Size = UDim2.new(1, 0, 0, 18)

	local target = textBox(page, "@ชื่อผู้รับ")
	target.Position = UDim2.new(0, 0, 0, 128)
	target.Size = UDim2.new(1, 0, 0, 32)
	self.bankTarget = target

	local amount = textBox(page, "จำนวนเงิน")
	amount.Position = UDim2.new(0, 0, 0, 168)
	amount.Size = UDim2.new(1, 0, 0, 32)
	self.bankAmount = amount

	local transfer = button(page, "โอน", 13, Color3.fromRGB(58, 84, 110))
	transfer.Position = UDim2.new(0, 0, 0, 208)
	transfer.Size = UDim2.new(1, 0, 0, 34)
	transfer.Activated:Connect(function()
		if self.callbacks.bank then self.callbacks.bank("transfer", amount.Text, target.Text) end
	end)
end

function SocialGui:RenderBank(gold, bank)
	self.pocketLabel.Text = ("%d"):format(gold or 0)
	self.bankLabel.Text = ("%d"):format(bank or 0)
end

--------------------------------------------------------------------------------
-- Profile
--------------------------------------------------------------------------------

function SocialGui:buildProfile()
	local page = scrollPage(self.body, "profile", 380)
	self.screens.profile = page

	local face = Instance.new("ImageLabel")
	face.AnchorPoint = Vector2.new(0.5, 0)
	face.Position = UDim2.new(0.5, 0, 0, 6)
	face.Size = UDim2.fromOffset(96, 96)
	face.BackgroundColor3 = STONE_DEEP
	face.BorderSizePixel = 0
	face.Parent = page
	corner(face, UDim.new(1, 0))
	stroke(face, RUNE, 0.5, 2)
	self.profileFace = face

	local name = label(page, "", 18, TEXT_LIGHT, Enum.TextXAlignment.Center)
	name.Position = UDim2.new(0, 0, 0, 110)
	name.Size = UDim2.new(1, 0, 0, 24)
	name.Font = Enum.Font.GothamBold
	self.profileName = name

	-- The rank badge: a big letter, coloured by band. The whole point of a rank is being seen at a glance.
	local badge = Instance.new("Frame")
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.new(0.5, 0, 0, 140)
	badge.Size = UDim2.fromOffset(64, 64)
	badge.BackgroundColor3 = STONE_DEEP
	badge.BackgroundTransparency = 0.2
	badge.BorderSizePixel = 0
	badge.Parent = page
	corner(badge, UDim.new(0, 14))
	self.rankBadge = badge
	self.rankStroke = stroke(badge, RUNE, 0.4, 2)

	local rank = label(badge, "F", 34, TEXT_LIGHT, Enum.TextXAlignment.Center)
	rank.Size = UDim2.fromScale(1, 1)
	rank.Font = Enum.Font.GothamBold
	self.rankLabel = rank

	local levelText = label(page, "", 13, TEXT_MUTED, Enum.TextXAlignment.Center)
	levelText.Position = UDim2.new(0, 0, 0, 210)
	levelText.Size = UDim2.new(1, 0, 0, 20)
	self.profileLevel = levelText

	-- The three fields the player will be able to set later. Shown now so the screen is not half-empty,
	-- and so it is obvious where they will appear.
	local rows = { { "วันเกิด", "birthday" }, { "เพศ", "gender" } }
	self.profileFields = {}
	for i, entry in ipairs(rows) do
		local row = Instance.new("Frame")
		row.Position = UDim2.new(0, 0, 0, 240 + (i - 1) * 36)
		row.Size = UDim2.new(1, 0, 0, 30)
		row.BackgroundColor3 = STONE_DEEP
		row.BackgroundTransparency = 0.45
		row.BorderSizePixel = 0
		row.Parent = page
		corner(row, UDim.new(0, 8))

		local caption = label(row, entry[1], 12, TEXT_MUTED)
		caption.Position = UDim2.new(0, 12, 0, 0)
		caption.Size = UDim2.new(0.4, 0, 1, 0)

		local value = label(row, "ยังไม่ระบุ", 12, TEXT_LIGHT, Enum.TextXAlignment.Right)
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.new(1, -12, 0, 0)
		value.Size = UDim2.new(0.55, 0, 1, 0)
		self.profileFields[entry[2]] = value
	end

	-- Raising the card is the point of the screen: it puts your profile over your head for everyone nearby.
	-- It toggles, because the only way to take a sign down is the same button that put it up.
	local show = button(page, "แสดงการ์ดโปรไฟล์", 13, Color3.fromRGB(58, 84, 110))
	show.Position = UDim2.new(0, 0, 0, 314)
	show.Size = UDim2.new(1, 0, 0, 34)
	self.showCardButton = show
	self.cardShowing = false
	show.Activated:Connect(function()
		self.cardShowing = not self.cardShowing
		self:SetCardButton(self.cardShowing)
		if self.callbacks.showCard then self.callbacks.showCard(self.cardShowing) end
	end)

	local note = label(page, "แก้ไขโปรไฟล์จะเปิดให้ใช้ในภายหลัง", 11, TEXT_MUTED,
		Enum.TextXAlignment.Center)
	note.Position = UDim2.new(0, 0, 0, 352)
	note.Size = UDim2.new(1, 0, 0, 18)
end

-- Kept in step with the real state rather than assumed: a respawn drops the card, and the button has to
-- stop claiming it is up.
function SocialGui:SetCardButton(showing)
	self.cardShowing = showing
	self.showCardButton.Text = showing and "ซ่อนการ์ดโปรไฟล์" or "แสดงการ์ดโปรไฟล์"
	self.showCardButton.BackgroundColor3 = showing and Color3.fromRGB(96, 80, 52)
		or Color3.fromRGB(58, 84, 110)
end

function SocialGui:RenderProfile(data)
	local player = Players.LocalPlayer
	AvatarThumbnails.Get(player.UserId, function(image)
		if self.profileFace.Parent and type(image) == "string" then self.profileFace.Image = image end
	end)
	self.profileName.Text = player.DisplayName ~= "" and player.DisplayName or player.Name

	local level = data.level or 1
	local rank = SocialConfig.RankFor(level)
	self.rankLabel.Text = rank.id
	self.rankLabel.TextColor3 = rank.color
	self.rankStroke.Color = rank.color
	self.rankStroke.Transparency = rank.glow and 0.05 or 0.4
	self.profileLevel.Text = ("เลเวล %d"):format(level)

	self.profileFields.birthday.Text = data.birthday or "ยังไม่ระบุ"
	self.profileFields.gender.Text = data.gender or "ยังไม่ระบุ"
end

--------------------------------------------------------------------------------
-- Notice (for the buttons that are not built yet)
--------------------------------------------------------------------------------

function SocialGui:buildNotice()
	local page = Instance.new("Frame")
	page.Name = "notice"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = self.body
	self.screens.notice = page

	local text = label(page, "", 14, TEXT_MUTED, Enum.TextXAlignment.Center)
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.45)
	text.Size = UDim2.new(1, -40, 0, 90)
	text.TextWrapped = true
	self.noticeText = text
end

function SocialGui:ShowNotice(title, message)
	self.noticeText.Text = message
	self:ShowScreen("notice", title)
end

--------------------------------------------------------------------------------
-- Screen switching and state
--------------------------------------------------------------------------------

local TITLES = {
	home = "หินเวทสื่อสาร",
	settings = "ตั้งค่า",
	board = "บอร์ดกิลด์",
	friends = "รายชื่อสหาย",
	bank = "ธนาคาร",
	profile = "โปรไฟล์",
}

function SocialGui:ShowScreen(id, titleOverride)
	for name, page in pairs(self.screens) do
		page.Visible = (name == id)
	end
	self.current = id
	-- The wallpaper belongs to the home screen; every other page draws on the stone itself.
	if self.wallpaperFrame then
		self.wallpaperFrame.Visible = (id == "home")
	end
	self.title.Text = titleOverride or TITLES[id] or "หินเวทสื่อสาร"
	self.backButton.Visible = (id ~= "home")
	self:SetStatus("")

	-- Leaving the friends screen closes any open conversation, so returning starts from the list.
	if id ~= "friends" and self.chatPage then
		self.chatPage.Visible = false
		self.friendList.Visible = true
		self.friendAddBox.Visible = true
		self.friendAddButton.Visible = true
		self.chatWith = nil
	end

	if self.callbacks.screenChanged then self.callbacks.screenChanged(id) end
end

function SocialGui:SetStatus(text, kind)
	self.status.Text = text or ""
	self.status.TextColor3 = (kind == "error") and BAD_RED or (kind == "ok") and OK_GREEN or TEXT_MUTED
end

function SocialGui:On(name, fn)
	self.callbacks[name] = fn
end

function SocialGui:IsOpen()
	return self.gui.Enabled
end

function SocialGui:Show()
	self.gui.Enabled = true
	self:ApplyWallpaper(self.settings and self.settings.wallpaper or "rune")
	-- The status bar is only worth updating while it can be seen.
	if not self.statusThread then
		self.statusThread = task.spawn(function()
			while self.gui.Enabled do
				self:refreshStatusBar()
				task.wait(5)
			end
			self.statusThread = nil
		end)
	end
end

function SocialGui:Hide()
	self.gui.Enabled = false
	self:ShowScreen("home")
end

return SocialGui
