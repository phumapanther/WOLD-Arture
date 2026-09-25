-- ChannelSelectGui: pure UI builder for the mode-tabs + channel-rows screen. No networking in this file.
local CAP = 30
local ROWS, COLS = 2, 15 -- 30 avatar slots per channel, matching the reference mockup

local Responsive = require(script.Parent.Responsive)

local PvpPartyGui = require(script.Parent.PvpPartyGui)

local ChannelSelectGui = {}
ChannelSelectGui.__index = ChannelSelectGui

-- โหมดที่กดได้จริง — **เปิดเมื่อเพลสปลายทางมีจริงเท่านั้น**
-- Farming เปิดแล้ว 2026-09-20 (เพลส `WOLD Farming` = `ServerConfig.FarmingPlaceId`)
-- PVP เปิดให้กดได้แล้ว (ผู้ใช้สั่ง 2026-09-23) — แท็บนี้พาไปหน้าปาร์ตี้ ไม่ได้พาไปเซิร์ฟไหน
-- จึงไม่ผิดกฎ "เปิดเมื่อเพลสปลายทางมีจริง" · ตัวที่พาไปสนามคือปุ่ม "เล่น" ข้างใน ซึ่งเข้าคิวจับคู่จริงแล้ว
-- (`Lobby/ArenaQueue`) และจะบอกตรงๆ ว่า "สนามยังไม่เปิด" ตราบใดที่ `ServerConfig.ArenaPlaceId` ยังเป็น 0
local ACTIVE_MODES = { Roleplay = true, Farming = true, PVP = true }
-- ชื่อโหมดเป็นชื่อของ "เพลสปลายทาง" ไม่ใช่ป้ายเฉยๆ (ผู้ใช้เปลี่ยน 2026-09-19: Stories → Farming,
-- Tanding → PVP) ดูแผนของสองโหมดนี้ใน `docs/design/05-future-modes.md`
--
-- **เปิดให้กดได้เมื่อเพลสปลายทางมีจริงเท่านั้น** — เพิ่มชื่อลง `ACTIVE_MODES` วันที่เพลสนั้นพร้อม
-- ไม่ใช่วันที่ตั้งชื่อปุ่ม ไม่งั้นปุ่มพาไปที่ว่างเปล่า และ **ล็อบบี้เป็นทางแยกเดียวของทั้งเกม**:
-- หนึ่งไอดีอยู่ได้แมพเดียว การเปลี่ยนโหมดจึงต้องกลับมาที่หน้านี้เสมอ
local MODE_ORDER = { "Farming", "Roleplay", "PVP" }

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

-- **หน้าจอตอนกดเข้าเซิร์ฟ** (ผู้ใช้สั่ง 2026-09-25) — ทรงเดียวกับจอ "กำลังพาไปหน้าล็อบบี้" ของ LobbyTravelController
-- แทนจอดำเฉยๆ · ใช้สองที่: บนแผ่นดำของ Lock() (จุดไข่ปลาขยับ) และสำเนานิ่งที่ส่งให้ SetTeleportGui
local JOIN_TITLE = "กำลังเข้าสู่โลก"
local JOIN_SUB = "กำลังค้นหาโลก รอสักครู่"
local JOIN_GOLD = Color3.fromRGB(244, 197, 66) -- สีเดียวกับจอไปล็อบบี้

local function addJoinText(sheet)
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.5)
	title.Size = UDim2.new(1, -40, 0, 30)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = JOIN_GOLD
	title.Text = JOIN_TITLE
	title.ZIndex = sheet.ZIndex + 1
	title.Parent = sheet

	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.new(0.5, 0, 0.5, 22)
	sub.Size = UDim2.new(1, -40, 0, 20)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 13
	sub.TextColor3 = Color3.fromRGB(176, 178, 188)
	sub.Text = JOIN_SUB
	sub.ZIndex = sheet.ZIndex + 1
	sub.Parent = sheet
	return title
end

-- สำเนานิ่งสำหรับ TeleportService:SetTeleportGui — หน้าโหลดของปลายทางไม่มีสคริปต์รัน จุดไข่ปลาจึงขยับไม่ได้
function ChannelSelectGui.BuildJoinVeil()
	local veil = Instance.new("ScreenGui")
	veil.Name = "JoinWorldVeil"
	veil.ResetOnSpawn = false
	veil.IgnoreGuiInset = true
	veil.DisplayOrder = 1000
	local sheet = Instance.new("Frame")
	sheet.Size = UDim2.fromScale(1, 1)
	sheet.BackgroundColor3 = Color3.new(0, 0, 0)
	sheet.BorderSizePixel = 0
	sheet.Parent = veil
	addJoinText(sheet)
	return veil
end

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
		-- เว้นที่มุมขวาบนให้ปุ่มพับ UI (ผู้ใช้สั่ง 2026-09-23) — ถอยซ้ายเท่าความกว้างปุ่ม + ช่องไฟ
		tabBar.Position = UDim2.new(1, -24 - 46 - 10, 0, TOP_BAR + 24)
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

	-- Manual refresh. The list also rebroadcasts every few seconds on its own; this is for when you want to
	-- know right now whether a server just freed up.
	--
	-- It lives INSIDE the tab bar, as one more item in its horizontal layout. Positioned independently it
	-- kept colliding with something: first the channel list below, then the mode tabs, because both the bar
	-- and the button anchored to the same right edge. As a layout child it simply cannot overlap either.
	local refreshButton = Instance.new("TextButton")
	refreshButton.Name = "RefreshButton"
	refreshButton.LayoutOrder = 99 -- after the mode tabs
	refreshButton.Size = UDim2.new(0, portrait and 84 or 96, 1, 0)
	refreshButton.BackgroundColor3 = GLASS
	refreshButton.BackgroundTransparency = 0.82
	refreshButton.Font = Enum.Font.SourceSansBold
	refreshButton.TextSize = portrait and 14 or 15
	refreshButton.TextColor3 = TEXT_LIGHT
	refreshButton.Text = "รีเฟรช"
	refreshButton.Parent = tabBar
	corner(refreshButton, UDim.new(1, 0))
	glassStroke(refreshButton, 0.7)
	self.refreshButton = refreshButton

	-- channel list — scale-based on every axis (including height) so it fills whatever's left below the header
	-- instead of a fixed 560px, and AutomaticCanvasSize means it never needs a manually-computed canvas height.
	local headerDrop = portrait and 112 or (Responsive.IsSmallScreen() and 78 or 96)
	local list = Instance.new("ScrollingFrame")
	list.AnchorPoint = Vector2.new(0.5, 0)
	-- On a phone the header eats proportionally more of a short screen, so the list starts higher and keeps a
	-- smaller bottom margin than on desktop.
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
		-- Held so SetChannelData can recolour it: the gradient paints over BackgroundColor3, so setting the
		-- background red for a FULL server left the button looking green.
		local joinGradient = Instance.new("UIGradient")
		joinGradient.Color = ColorSequence.new(Color3.fromRGB(66, 196, 124), Color3.fromRGB(38, 150, 90))
		joinGradient.Rotation = 90
		joinGradient.Parent = joinButton
		joinButton.MouseButton1Click:Connect(function()
			if self.onJoin then self.onJoin("Roleplay", channel) end
		end)

		self.rows.Roleplay[channel] = {
			joinGradient = joinGradient,
			frame = row, countLabel = countLabel, joinButton = joinButton, statusLabel = statusLabel, avatars = avatars,
		}
	end

	-- **โหมดฟาร์มมิ่งมีรายการจริงแล้ว** (2026-09-20): กล่องเปล่าที่ `RenderFarms` เติมแถวลงไป
	-- แถวของโหมดนี้ไม่เหมือนกันสักคน (เกาะของตัวเอง + เกาะที่ถูกชวน) จึงสร้างตอนได้ข้อมูล ไม่ใช่สร้างล่วงหน้า
	-- **ขนาด/ตำแหน่ง/วัสดุ ลอกจากรายการช่อง Roleplay ทุกค่า** (บรรทัดเดียวกับ `list` ข้างบน)
	-- ผู้ใช้ทักว่ากล่องสองโหมดไม่เท่ากัน — มันคือแผงเดียวกันในสายตาคนเล่น แค่สลับเนื้อข้างใน
	-- ค่าพวกนี้คิดมาจากความสูงหัวจอและขอบล่างของมือถือ/จอแนวตั้งแล้ว การตั้งเลขเองใหม่จึงเพี้ยนแน่นอน
	local farmList = Instance.new("ScrollingFrame")
	farmList.AnchorPoint = Vector2.new(0.5, 0)
	farmList.Size = UDim2.new(0.94, 0, 1, -TOP_BAR - bottomMargin)
	farmList.Position = UDim2.new(0.5, 0, 0, TOP_BAR + headerDrop)
	farmList.BackgroundColor3 = Responsive.GlassColor
	farmList.BackgroundTransparency = Responsive.GlassTransparency
	farmList.BorderSizePixel = 0
	farmList.ScrollBarThickness = 6
	farmList.ScrollBarImageColor3 = ACCENT
	farmList.CanvasSize = UDim2.new(0, 0, 0, 0)
	farmList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	farmList.Visible = false
	farmList.Parent = root
	corner(farmList, UDim.new(0, 20))
	glassStroke(farmList, 0.8)
	local farmSizeConstraint = Instance.new("UISizeConstraint")
	farmSizeConstraint.MinSize = Vector2.new(480, 260)
	farmSizeConstraint.Parent = farmList
	local farmLayout = Instance.new("UIListLayout")
	farmLayout.Padding = UDim.new(0, 8)
	farmLayout.Parent = farmList
	local farmPad = Instance.new("UIPadding")
	farmPad.PaddingLeft = UDim.new(0, 20)
	farmPad.PaddingRight = UDim.new(0, 20)
	farmPad.PaddingTop = UDim.new(0, 20)
	farmPad.PaddingBottom = UDim.new(0, 20)
	farmPad.Parent = farmList
	-- บรรทัดบอกเหตุผลตอนเข้าเกาะไม่ได้ — แถวของโหมดนี้ไม่มีช่องสถานะของตัวเองเหมือนแถวช่อง Roleplay
	-- และ "กดแล้วจอกลับมาเฉยๆ ไม่บอกอะไร" คือสิ่งที่อ่านว่าเกมพัง
	local farmStatus = Instance.new("TextLabel")
	farmStatus.LayoutOrder = -1
	farmStatus.Size = UDim2.new(1, 0, 0, small and 20 or 24)
	farmStatus.BackgroundTransparency = 1
	farmStatus.Font = Enum.Font.SourceSansBold
	farmStatus.TextSize = small and 14 or 17
	farmStatus.TextColor3 = Color3.fromRGB(230, 170, 90)
	farmStatus.TextXAlignment = Enum.TextXAlignment.Left
	farmStatus.Text = ""
	farmStatus.Visible = false
	farmStatus.Parent = farmList
	self.farmStatus = farmStatus

	self.farmList = farmList
	self.farmSmall = small
	-- ความสูงแถวเดียวกับแถวช่อง Roleplay ด้วยเหตุผลเดียวกับขนาดกล่อง: สองโหมดต้องอ่านเป็นแผงเดียวกัน
	self.farmRowH = ROW_H
	self.rows.Farming = { list = farmList }

	-- PVP: หน้าปาร์ตี้ (ผู้ใช้ส่งภาพร่างมา 2026-09-23) — วางในกรอบกระจกเดียวกับรายการเซิร์ฟเวอร์
	-- เพื่อให้สามแท็บอยู่ในกล่องเดียวกันทั้งหมด ไม่ใช่แท็บนี้ลอยอยู่คนละที่
	local pvpPanel = Instance.new("Frame")
	pvpPanel.Name = "PvpPanel"
	pvpPanel.AnchorPoint = list.AnchorPoint
	pvpPanel.Position = list.Position
	pvpPanel.Size = list.Size
	pvpPanel.BackgroundColor3 = Responsive.GlassColor
	pvpPanel.BackgroundTransparency = Responsive.GlassTransparency
	pvpPanel.BorderSizePixel = 0
	pvpPanel.Visible = false
	pvpPanel.Parent = root
	corner(pvpPanel, UDim.new(0, 20))
	glassStroke(pvpPanel, 0.8)
	self.pvpPanel = pvpPanel
	self.pvp = PvpPartyGui.new(pvpPanel)
	self.pvp:SetVisible(true) -- ตัวแผงข้างนอกเป็นคนคุมการซ่อน/แสดงตามแท็บ
	-- **หน้าต่างประกาศตัวเอง ฝั่งที่ต้องใช้ไปหยิบเอา** — `PvpPartyController` เป็นคนละ LocalScript
	-- จึงแชร์ตารางลัวกันตรงๆ ไม่ได้ · กฎเดิมของโปรเจ็ค (บทเรียนปุ่มร้านพรีเมียมที่รอแล้วเงียบ):
	-- อย่าให้ฝั่งที่รอเป็นคนนัดเวลา ให้ฝ่ายที่สร้างวางของไว้แล้วอีกฝ่ายวนถามเอง
	_G.WOLD_PvpPartyGui = self.pvp
	self.rows.PVP = {}

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
	self.joinTitle = addJoinText(blackout)

	--------------------------------------------------------------------------------
	-- ปุ่มพับ UI (ผู้ใช้สั่ง 2026-09-23: "ปุ่มลูกศรลง-ลูกศรขึ้นที่มุมขวาบน ใช้ปิด-เปิด UI หน้าล็อบบี้")
	--------------------------------------------------------------------------------
	--
	-- **อยู่นอก `root`** — มันคือสิ่งเดียวที่ต้องเหลืออยู่บนจอตอนทุกอย่างถูกซ่อน ถ้าเป็นลูกของ root
	-- มันจะหายไปพร้อมกัน แล้วก็ไม่มีทางเปิดกลับ
	local toggle = Instance.new("TextButton")
	toggle.Name = "ToggleUi"
	toggle.AnchorPoint = Vector2.new(1, 0)
	toggle.Size = UDim2.fromOffset(portrait and 40 or 46, portrait and 40 or 46)
	toggle.Position = UDim2.new(1, -24, 0, TOP_BAR + (portrait and 8 or 26))
	toggle.BackgroundColor3 = GLASS
	toggle.BackgroundTransparency = 0.82
	toggle.Text = ""
	toggle.AutoButtonColor = true
	toggle.ZIndex = 20
	toggle.Parent = gui
	corner(toggle, UDim.new(1, 0))
	glassStroke(toggle, 0.7)

	-- ⚠️ **ลูกศรวาดจาก Frame หมุน ไม่ใช่ตัวอักษร** — ฟอนต์ของ Roblox วาด ▲ ▼ เป็นกล่องเปล่า
	-- (บทเรียนเดิมจากลูกศรในมินิเกม จดไว้ใน CLAUDE.md แล้ว) · สองขีดไขว้กันเป็นเชฟรอน "⌄"
	-- แล้วหมุนทั้งกล่อง 180° เวลาจะให้ชี้ขึ้น
	local chevron = Instance.new("Frame")
	chevron.Name = "Chevron"
	chevron.AnchorPoint = Vector2.new(0.5, 0.5)
	chevron.Position = UDim2.fromScale(0.5, 0.5)
	chevron.Size = UDim2.fromOffset(22, 12)
	chevron.BackgroundTransparency = 1
	chevron.ZIndex = 21
	chevron.Parent = toggle
	for _, bar in ipairs({ { -5, -30 }, { 5, 30 } }) do
		local stroke = Instance.new("Frame")
		stroke.AnchorPoint = Vector2.new(0.5, 0.5)
		stroke.Position = UDim2.new(0.5, bar[1], 0.5, 0)
		stroke.Size = UDim2.fromOffset(14, 3)
		stroke.Rotation = bar[2]
		stroke.BackgroundColor3 = ACCENT
		stroke.BorderSizePixel = 0
		stroke.ZIndex = 21
		stroke.Parent = chevron
		corner(stroke, UDim.new(1, 0))
	end

	self.toggle = toggle
	self.chevron = chevron
	self.root = root
	self._collapsed = false
	toggle.MouseButton1Click:Connect(function()
		self:SetCollapsed(not self._collapsed)
	end)

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
	if self.farmList then self.farmList.Visible = (mode == "Farming") end
	if self.pvpPanel then self.pvpPanel.Visible = (mode == "PVP") end
	for _, m in ipairs(MODE_ORDER) do
		if self.rows[m] and self.rows[m].comingSoon then
			self.rows[m].comingSoon.Visible = (m == mode)
		end
		self.tabs[m].BackgroundColor3 = (m == mode) and ACCENT or GLASS
		self.tabs[m].BackgroundTransparency = (m == mode) and 0 or 0.85
		self.tabs[m].TextColor3 = (m == mode) and Color3.fromRGB(30, 24, 10) or TEXT_LIGHT
	end
end

-- `rows` = { { ownerId, ownerName, mine, locked = "vip" | nil }, ... } · nil/ว่าง = ยังไม่ได้ข้อมูล
--
-- วาดใหม่ทั้งกล่องทุกครั้ง ไม่ได้ไล่แก้ทีละแถว: รายการนี้สั้น (ตัวเอง + คนที่ชวนเรา) และเปลี่ยนได้ทั้งชุด
-- เมื่อ VIP หมดอายุหรือมีคนชวนเพิ่ม — การไล่ patch ทีละแถวคือที่มาของแถวค้างที่ไม่ตรงกับความจริง
function ChannelSelectGui:RenderFarms(rows)
	local list = self.farmList
	if not list then return end
	for _, child in ipairs(list:GetChildren()) do
		-- บรรทัดสถานะอยู่ต่อ (LayoutOrder -1) ไม่งั้นข้อความ "ต้องมี VIP" จะหายไปพร้อมการวาดรอบถัดไป
		-- ซึ่งมาถึงทุก 5 วินาทีอยู่แล้ว = คนอ่านไม่ทัน
		if child ~= self.farmStatus and (child:IsA("Frame") or child:IsA("TextLabel")) then child:Destroy() end
	end

	local small = self.farmSmall
	local ROW_H = self.farmRowH or (small and 72 or 96)

	if not rows or #rows == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 60)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.SourceSans
		empty.TextSize = small and 16 or 20
		empty.TextColor3 = TEXT_MUTED
		empty.Text = "กำลังโหลด..."
		empty.Parent = list
		return
	end

	for order, farm in ipairs(rows) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, ROW_H)
		row.BackgroundColor3 = GLASS
		row.BackgroundTransparency = 0.9
		row.BorderSizePixel = 0
		row.LayoutOrder = order
		row.Parent = list
		corner(row)
		glassStroke(row, 0.75)

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -180, 0, small and 24 or 30)
		-- วางจากกึ่งกลางแถว ไม่ใช่นับลงมาจากขอบบน — แถวสูงเท่าไหร่ข้อความก็ยังอยู่กลางเสมอ
		title.AnchorPoint = Vector2.new(0, 1)
		title.Position = UDim2.new(0, small and 14 or 20, 0.5, small and 2 or 2)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.SourceSansBold
		title.TextSize = small and 17 or 22
		title.TextColor3 = TEXT_LIGHT
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.Text = ("เกาะของ %s"):format(farm.ownerName or "?")
		title.Parent = row

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, -180, 0, small and 18 or 22)
		sub.Position = UDim2.new(0, small and 14 or 20, 0.5, small and 4 or 4)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.SourceSans
		sub.TextSize = small and 12 or 15
		sub.TextColor3 = farm.locked and Color3.fromRGB(230, 170, 90) or TEXT_MUTED
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.Text = farm.locked == "vip" and "ต้องมี VIP — ซื้อได้ที่ร้านเพชรในเกม"
			or (farm.mine and "เกาะส่วนตัวของคุณ" or "คุณถูกชวนเข้าเกาะนี้")
		sub.Parent = row

		local JOIN_W = small and 84 or 110
		local JOIN_H = small and 32 or 40
		local join = Instance.new("TextButton")
		join.AnchorPoint = Vector2.new(1, 0.5)
		join.Position = UDim2.new(1, small and -12 or -20, 0.5, 0)
		join.Size = UDim2.fromOffset(JOIN_W, JOIN_H)
		join.Font = Enum.Font.SourceSansBold
		join.TextSize = small and 15 or 18
		join.TextColor3 = Color3.new(1, 1, 1)
		join.BackgroundColor3 = farm.locked and Color3.fromRGB(70, 72, 86) or Color3.fromRGB(52, 178, 108)
		join.AutoButtonColor = farm.locked == nil
		join.Text = farm.locked and "ล็อก" or "เข้า"
		join.Parent = row
		corner(join, UDim.new(0, 10))
		join.MouseButton1Click:Connect(function()
			if self._locked or farm.locked then return end
			if self.onJoin then self.onJoin("Farming", farm.ownerId) end
		end)
	end
end

-- ข้อความเหตุผลเหนือรายการเกาะ · nil/"" = ซ่อน
function ChannelSelectGui:SetFarmStatus(text)
	if not self.farmStatus then return end
	self.farmStatus.Text = text or ""
	self.farmStatus.Visible = (text ~= nil and text ~= "")
end

function ChannelSelectGui:OnJoin(callback)
	self.onJoin = callback
end

function ChannelSelectGui:OnRefreshRequested(callback)
	self.refreshButton.Activated:Connect(callback)
end

-- Brief feedback so a press that finds no change still looks like it did something.
function ChannelSelectGui:FlashRefresh()
	local button = self.refreshButton
	button.Text = "กำลังรีเฟรช..."
	task.delay(0.6, function()
		if button.Parent then button.Text = "รีเฟรช" end
	end)
end

function ChannelSelectGui:SetChannelData(mode, channel, data)
	local row = self.rows[mode] and self.rows[mode][channel]
	if not row then return end
	row.countLabel.Text = data.count .. "/" .. CAP
	row.joinButton.Text = data.full and "FULL" or "JOIN"
	row.joinButton.BackgroundColor3 = data.full and Color3.fromRGB(200, 60, 50) or Color3.fromRGB(52, 178, 108)
	if row.joinGradient then
		row.joinGradient.Color = data.full
			and ColorSequence.new(Color3.fromRGB(224, 82, 70), Color3.fromRGB(168, 44, 36))
			or ColorSequence.new(Color3.fromRGB(66, 196, 124), Color3.fromRGB(38, 150, 90))
	end
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
	-- "error" is for a refusal the server actually reported. "slow" is for the timeout, which is a different
	-- thing and must not claim the join failed: a teleport that outruns the clock is usually still on its
	-- way, and telling the player it failed a moment before dropping them into the game is a lie the screen
	-- then contradicts.
	local text = {
		idle = "",
		connecting = "กำลังเชื่อมต่อ...",
		slow = "ใช้เวลานานกว่าปกติ กดใหม่ได้",
		error = "เชื่อมต่อไม่สำเร็จ ลองอีกครั้ง",
	}
	row.statusLabel.Text = text[status] or ""
	row.joinButton.Active = (status ~= "connecting") and not self._locked
end

-- Lock: blacks out the whole screen instantly and disables every button, so a confirmed join can't be clicked
-- twice. Call this the moment a join is fired, not after the server answers.
function ChannelSelectGui:Lock()
	if self._locked then return end
	self._locked = true
	self.blackout.Visible = true
	-- จุดไข่ปลาขยับ ให้อ่านว่า "กำลังโหลด" ไม่ใช่ "ค้าง" (ทรงเดียวกับจอไปล็อบบี้)
	task.spawn(function()
		local dots = 0
		while self._locked and self.joinTitle.Parent do
			dots = (dots + 1) % 4
			self.joinTitle.Text = JOIN_TITLE .. string.rep(".", dots)
			task.wait(0.4)
		end
	end)
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

-- พับ/กาง UI ทั้งหน้า เหลือแต่ปุ่มมุมขวาบน
--
-- ซ่อน `root` ตัวเดียวพอ — ทุกอย่างของหน้านี้เป็นลูกของมันหมด ยกเว้นปุ่มนี้กับจอดำตอนกด JOIN
-- (จอดำต้องอยู่นอกการพับ ไม่งั้นพับไว้แล้วกดเข้าเกมจะไม่มีอะไรบังจอ)
function ChannelSelectGui:SetCollapsed(collapsed)
	self._collapsed = collapsed and true or false
	self.root.Visible = not self._collapsed
	-- ชี้ลง = กดเพื่อพับ · ชี้ขึ้น = กดเพื่อกาง
	self.chevron.Rotation = self._collapsed and 180 or 0
end

function ChannelSelectGui:Show()
	self.gui.Enabled = true
end

function ChannelSelectGui:Destroy()
	self.gui:Destroy()
end

return ChannelSelectGui
