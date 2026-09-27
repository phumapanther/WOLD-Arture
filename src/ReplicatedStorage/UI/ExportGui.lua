-- ExportGui (เฟส 2c): หน้าต่างรถส่งออก — ใบสั่งซื้อ 3 ใบ + ตารางปลดเลเวลฟาร์ม
--
-- วาดจากภาพที่เซิร์ฟเวอร์ส่งมาอย่างเดียว (ทรงเดียวกับ ShopGui/CraftGui): ไม่นับของ ไม่คิดราคา ไม่ตัดสินว่าส่งได้ไหม
-- สิ่งเดียวที่คำนวณเองคือนาฬิกาถอยหลัง (จาก `ship.endAt` เทียบ `workspace:GetServerTimeNow()`) กับตารางปลด
-- ซึ่งเป็นข้อมูลล้วนใน FarmLevelConfig
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)
local ItemIcon = require(script.Parent.ItemIcon)
local FarmLevelConfig = require(ReplicatedStorage.FarmLevelConfig)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local CARD = Color3.fromRGB(46, 48, 58)
local CARD_GOLD = Color3.fromRGB(62, 52, 30)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)
local GOLD = Color3.fromRGB(238, 200, 96)
local GEM = Color3.fromRGB(128, 190, 240)
local EXP = Color3.fromRGB(150, 220, 130)
local ENOUGH = Color3.fromRGB(150, 200, 140)
local SHORT = Color3.fromRGB(214, 106, 96)
local BUTTON_OFF = Color3.fromRGB(70, 74, 84)
local INK = Color3.fromRGB(24, 26, 32)

local function commas(n)
	local s = tostring(math.floor(n or 0))
	repeat
		local k
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return s
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function corner(inst, px)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = inst
	return c
end

local function stroke(inst, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency or 0.5
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = props.font or Enum.Font.GothamBold
	l.TextSize = props.size or 13
	l.TextColor3 = props.color or TEXT_LIGHT
	l.TextXAlignment = props.align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.RichText = props.rich == true
	l.Text = props.text or ""
	l.Position = props.pos or UDim2.new()
	l.Size = props.dim or UDim2.new(1, 0, 0, 20)
	if props.anchor then l.AnchorPoint = props.anchor end
	l.Parent = parent
	return l
end

local function button(parent, props)
	local b = Instance.new("TextButton")
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextSize = props.size or 13
	b.TextColor3 = props.textColor or INK
	b.BackgroundColor3 = props.color or ENOUGH
	b.Text = props.text or ""
	b.Position = props.pos or UDim2.new()
	b.Size = props.dim or UDim2.fromOffset(80, 30)
	if props.anchor then b.AnchorPoint = props.anchor end
	b.Parent = parent
	corner(b, 6)
	return b
end

local ExportGui = {}
ExportGui.__index = ExportGui

function ExportGui.new()
	local self = setmetatable({}, ExportGui)
	self.page = "orders"

	local gui = Instance.new("ScreenGui")
	gui.Name = "ExportGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 17
	gui.Enabled = false
	if RunService:IsRunning() then gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
	self.gui = gui

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local small = Responsive.IsSmallScreen()
	self.compact = small
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = small and UDim2.fromScale(0.96, 0.94) or UDim2.fromOffset(700, 480)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, 14)
	stroke(panel, RUNE, 0.55, 2)
	Responsive.Scale(panel, small and 0.95 or nil) -- มือถือ: แผงเต็มจออยู่แล้ว ห้ามย่อซ้ำ
	self.panel = panel

	label(panel, { text = "🚚 รถส่งออก", size = 19, color = RUNE, pos = UDim2.fromOffset(14, 12),
		dim = UDim2.new(0, 170, 0, 30) })

	-- เลเวลฟาร์ม + แถบ EXP (หัวหน้าต่าง ขวามือ)
	local levelBox = Instance.new("Frame")
	levelBox.AnchorPoint = Vector2.new(1, 0)
	levelBox.Position = UDim2.new(1, -48, 0, 12)
	levelBox.Size = UDim2.fromOffset(300, 30)
	levelBox.BackgroundTransparency = 1
	levelBox.Parent = panel

	local levelPill = label(levelBox, { text = "🌾 Lv 1", size = 14, color = INK, align = Enum.TextXAlignment.Center,
		dim = UDim2.fromOffset(78, 26), pos = UDim2.fromOffset(0, 2) })
	levelPill.BackgroundTransparency = 0
	levelPill.BackgroundColor3 = RUNE
	corner(levelPill, 13)
	self.levelPill = levelPill

	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(86, 6)
	track.Size = UDim2.new(1, -86, 0, 18)
	track.BackgroundColor3 = STONE_DEEP
	track.BorderSizePixel = 0
	track.Parent = levelBox
	corner(track, 9)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = EXP
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, 9)
	self.expFill = fill
	self.expText = label(track, { text = "", size = 11, color = TEXT_LIGHT, align = Enum.TextXAlignment.Center,
		dim = UDim2.fromScale(1, 1) })
	self.expText.ZIndex = 2

	local close = button(panel, { text = "\195\151", size = 15, color = BUTTON_OFF, textColor = TEXT_LIGHT,
		anchor = Vector2.new(1, 0), pos = UDim2.new(1, -12, 0, 14), dim = UDim2.fromOffset(26, 26) })
	close.Activated:Connect(function()
		UiSound.Play("Click")
		self:Hide()
	end)

	-- แท็บ (ซ้าย) + เพชรวันนี้ (ขวา)
	local tabs = Instance.new("Frame")
	tabs.Position = UDim2.fromOffset(14, 50)
	tabs.Size = UDim2.fromOffset(250, 28)
	tabs.BackgroundTransparency = 1
	tabs.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.Parent = tabs
	self.tabButtons = {}
	for order, spec in ipairs({ { id = "orders", text = "📦 ใบสั่งซื้อ" }, { id = "unlocks", text = "🔓 ปลดล็อก" } }) do
		local b = button(tabs, { text = spec.text, size = 13, dim = UDim2.fromOffset(122, 28) })
		b.LayoutOrder = order
		b.Activated:Connect(function()
			if self.page == spec.id then return end
			UiSound.Play("Click")
			self.page = spec.id
			self:Render()
		end)
		self.tabButtons[spec.id] = b
	end
	self.gemsText = label(panel, { text = "", size = 12, color = GEM, align = Enum.TextXAlignment.Right,
		anchor = Vector2.new(1, 0), pos = UDim2.new(1, -14, 0, 50), dim = UDim2.new(0, 360, 0, 28) })

	-- แถบสถานะรถ
	local strip = Instance.new("Frame")
	strip.Position = UDim2.fromOffset(14, 84)
	strip.Size = UDim2.new(1, -28, 0, 30)
	strip.BackgroundColor3 = STONE_DEEP
	strip.BorderSizePixel = 0
	strip.Parent = panel
	corner(strip, 8)
	local stripFill = Instance.new("Frame")
	stripFill.Size = UDim2.fromScale(0, 1)
	stripFill.BackgroundColor3 = Color3.fromRGB(70, 104, 74)
	stripFill.BorderSizePixel = 0
	stripFill.Visible = false
	stripFill.Parent = strip
	corner(stripFill, 8)
	self.stripFill = stripFill
	self.stripText = label(strip, { text = "", size = 13, color = TEXT_LIGHT, pos = UDim2.fromOffset(10, 0),
		dim = UDim2.new(1, -20, 1, 0) })
	self.stripText.ZIndex = 2

	-- หน้า: ใบสั่ง (สามการ์ดเรียงแนวนอน) · ปลดล็อก (รายการเลื่อนได้)
	local body = Instance.new("Frame")
	body.Position = UDim2.fromOffset(14, 122)
	body.Size = UDim2.new(1, -28, 1, -136)
	body.BackgroundTransparency = 1
	body.Parent = panel

	local orders = Instance.new("Frame")
	orders.Size = UDim2.fromScale(1, 1)
	orders.BackgroundTransparency = 1
	orders.Parent = body
	local ordersLayout = Instance.new("UIListLayout")
	ordersLayout.FillDirection = Enum.FillDirection.Horizontal
	ordersLayout.Padding = UDim.new(0, 8)
	ordersLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ordersLayout.Parent = orders
	self.ordersPage = orders

	local unlocks = Instance.new("ScrollingFrame")
	unlocks.Size = UDim2.fromScale(1, 1)
	unlocks.BackgroundColor3 = STONE_DEEP
	unlocks.BorderSizePixel = 0
	unlocks.ScrollBarThickness = 8
	unlocks.ScrollBarImageColor3 = RUNE
	unlocks.ScrollBarImageTransparency = 0.3
	unlocks.CanvasSize = UDim2.new()
	unlocks.AutomaticCanvasSize = Enum.AutomaticSize.Y
	unlocks.Visible = false
	unlocks.Parent = body
	corner(unlocks, 10)
	local unlockLayout = Instance.new("UIListLayout")
	unlockLayout.Padding = UDim.new(0, 6)
	unlockLayout.SortOrder = Enum.SortOrder.LayoutOrder
	unlockLayout.Parent = unlocks
	local unlockPad = Instance.new("UIPadding")
	unlockPad.PaddingTop = UDim.new(0, 8)
	unlockPad.PaddingLeft = UDim.new(0, 8)
	unlockPad.PaddingRight = UDim.new(0, 14)
	unlockPad.PaddingBottom = UDim.new(0, 8)
	unlockPad.Parent = unlocks
	self.unlocksPage = unlocks

	self.cards = {}
	self.armed = nil -- ช่องที่กดสุ่มใหม่ไปหนึ่งครั้งแล้ว รอยืนยัน
	self.onShip, self.onReroll, self.onClose = nil, nil, nil

	-- นาฬิกา: ถอยหลังรถ + แถบในการ์ดที่กำลังส่ง (4 ครั้งต่อวิ ไม่ต้องทุกเฟรม)
	task.spawn(function()
		while true do
			if self.gui.Enabled then self:Tick() end
			task.wait(0.25)
		end
	end)
	return self
end

function ExportGui:OnShip(fn) self.onShip = fn end
function ExportGui:OnReroll(fn) self.onReroll = fn end
function ExportGui:OnClose(fn) self.onClose = fn end

local function serverNow()
	return workspace:GetServerTimeNow()
end

-- แถบสถานะรถ + แถบในการ์ดที่กำลังส่ง
function ExportGui:Tick()
	local snap = self.snap
	if not snap then return end
	local ship = snap.ship
	local text
	if ship then
		local total = math.max(1, ship.endAt - ship.startAt)
		local left = math.max(0, ship.endAt - serverNow())
		local progress = math.clamp(1 - left / total, 0, 1)
		self.stripFill.Visible = true
		self.stripFill.Size = UDim2.fromScale(progress, 1)
		text = left > 0 and ("🚚 กำลังส่งของ… รถกลับมาใน %s"):format(clock(left)) or "🚚 รถกำลังกลับเข้าฟาร์ม…"
		local card = self.cards[ship.slot]
		if card and card.bar then
			card.bar.Size = UDim2.fromScale(progress, 1)
			card.barText.Text = left > 0 and clock(left) or "กลับแล้ว"
		end
	else
		self.stripFill.Visible = false
		text = ("🚚 รถว่าง — เลือกใบที่ของครบแล้วกด “ส่งของ” (ทีละใบ ใบละ %d นาที)"):format(
			math.floor((snap.shipSeconds or 1800) / 60))
	end
	-- ข้อความสั้นจากปุ่ม (Flash) ขึ้นแทนชั่วคราว แถบยังเดินปกติ
	self.stripText.Text = self.flashText or text
end

-- การ์ดใบสั่งหนึ่งใบ
function ExportGui:DrawCard(order, snap)
	local shipping = order.shipping
	local busy = snap.ship ~= nil
	local frame = Instance.new("Frame")
	frame.Name = "Order" .. order.slot
	frame.LayoutOrder = order.slot
	frame.Size = UDim2.new(1 / 3, -6, 1, 0)
	frame.BackgroundColor3 = order.gold and CARD_GOLD or CARD
	frame.BorderSizePixel = 0
	frame.Parent = self.ordersPage
	corner(frame, 10)
	if order.gold then
		stroke(frame, GOLD, 0, 2)
	elseif order.ready and not busy then
		stroke(frame, ENOUGH, 0.35, 2) -- ของครบ ส่งได้เลย: ขอบเขียวให้เห็นแต่ไกล
	end
	local card = { frame = frame }

	-- ขนาดแถว: มือถือแนวนอนเตี้ยมาก ใบสั่งสามบรรทัดต้องพอดีการ์ดโดยไม่ต้องเลื่อน
	local compact = self.compact
	local expText = snap.max and "MAX" or commas(order.exp)
	local rowH, step, top = compact and 26 or 32, compact and 29 or 36, compact and 28 or 34

	local head = label(frame, {
		text = shipping and "🚚 กำลังส่ง" or (order.gold and "🌟 ใบขอบทอง" or ("📦 ใบสั่งซื้อ %d"):format(order.slot)),
		size = compact and 13 or 14, color = order.gold and GOLD or RUNE, pos = UDim2.fromOffset(10, compact and 5 or 8),
		dim = UDim2.new(1, -20, 0, 20),
	})
	head.Name = "Head"

	-- บรรทัดของ: ไอคอน · ชื่อ · มี/ต้องการ (เขียว = ครบ · แดง = ขาด) — แถวเดียว อ่านได้ทีเดียวทั้งใบ
	local y = top
	for _, line in ipairs(order.lines) do
		local row = Instance.new("Frame")
		row.Position = UDim2.fromOffset(8, y)
		row.Size = UDim2.new(1, -16, 0, rowH)
		row.BackgroundColor3 = STONE_DEEP
		row.BorderSizePixel = 0
		row.Parent = frame
		corner(row, 6)
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromOffset(rowH - 4, rowH - 4)
		icon.Position = UDim2.fromOffset(3, 2)
		ItemIcon.Apply(icon, line.icon)
		icon.Parent = row
		label(row, { text = line.name, size = 12, pos = UDim2.fromOffset(rowH + 2, 0), dim = UDim2.new(1, -(rowH + 64), 1, 0) })
		local enough = shipping or line.have >= line.qty
		label(row, {
			text = shipping and ("x%d"):format(line.qty) or ("%s/%s"):format(commas(line.have), commas(line.qty)),
			font = Enum.Font.GothamBold, size = 12, color = enough and ENOUGH or SHORT, align = Enum.TextXAlignment.Right,
			anchor = Vector2.new(1, 0), pos = UDim2.new(1, -6, 0, 0), dim = UDim2.new(0, 60, 1, 0),
		})
		y += step
	end

	-- รางวัล (ติดล่างเหนือปุ่ม) · สองบรรทัดบนคอม หนึ่งบรรทัดบนมือถือ
	local rewards = Instance.new("Frame")
	rewards.AnchorPoint = Vector2.new(0, 1)
	rewards.Position = UDim2.new(0, 8, 1, compact and -40 or -46)
	rewards.Size = UDim2.new(1, -16, 0, compact and 20 or 42)
	rewards.BackgroundTransparency = 1
	rewards.Parent = frame
	if compact then
		label(rewards, {
			text = ("<font color=\"#%s\">💰 %s</font>  <font color=\"#%s\">⭐ %s</font>  <font color=\"#%s\">%s</font>"):format(
				GOLD:ToHex(), commas(order.coins), EXP:ToHex(), expText, GEM:ToHex(), order.gems or ""),
			rich = true, size = 12, dim = UDim2.fromScale(1, 1),
		})
	else
		label(rewards, { text = "💰 " .. commas(order.coins), size = 14, color = GOLD, dim = UDim2.new(0.5, 0, 0, 20) })
		label(rewards, { text = snap.max and "⭐ เลเวลสูงสุด" or ("⭐ " .. expText .. " EXP"), size = 13, color = EXP,
			pos = UDim2.new(0.5, 0, 0, 0), dim = UDim2.new(0.5, 0, 0, 20), align = Enum.TextXAlignment.Right })
		label(rewards, { text = order.gems or "", size = 12, color = GEM, pos = UDim2.fromOffset(0, 22),
			dim = UDim2.new(1, 0, 0, 18) })
	end

	-- ปุ่ม: ส่งของ (ใหญ่) · สุ่มใหม่ (เล็ก ขวา)
	if shipping then
		local track = Instance.new("Frame")
		track.AnchorPoint = Vector2.new(0, 1)
		track.Position = UDim2.new(0, 8, 1, -8)
		track.Size = UDim2.new(1, -16, 0, 30)
		track.BackgroundColor3 = STONE_DEEP
		track.BorderSizePixel = 0
		track.Parent = frame
		corner(track, 6)
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(0, 1)
		bar.BackgroundColor3 = Color3.fromRGB(96, 150, 100)
		bar.BorderSizePixel = 0
		bar.Parent = track
		corner(bar, 6)
		card.bar = bar
		card.barText = label(track, { text = "", size = 13, align = Enum.TextXAlignment.Center, dim = UDim2.fromScale(1, 1) })
		card.barText.ZIndex = 2
	else
		local canShip = order.ready and not busy
		local ship = button(frame, {
			text = canShip and "🚚 ส่งของ" or (busy and "รถไม่ว่าง" or "ของยังไม่ครบ"),
			color = canShip and ENOUGH or BUTTON_OFF, textColor = canShip and INK or TEXT_MUTED, size = 14,
			anchor = Vector2.new(0, 1), pos = UDim2.new(0, 8, 1, -8), dim = UDim2.new(1, -60, 0, 32),
		})
		ship.Name = "Ship"
		ship.AutoButtonColor = canShip
		ship.Activated:Connect(function()
			if not canShip then return end
			UiSound.Play("Click")
			if self.onShip then self.onShip(order.slot) end
		end)

		local canReroll = (snap.rerollLeft or 0) > 0
		local reroll = button(frame, {
			text = "🔄", size = 16, color = canReroll and Color3.fromRGB(96, 110, 150) or BUTTON_OFF,
			textColor = canReroll and TEXT_LIGHT or TEXT_MUTED,
			anchor = Vector2.new(1, 1), pos = UDim2.new(1, -8, 1, -8), dim = UDim2.fromOffset(44, 32),
		})
		reroll.Name = "Reroll"
		reroll.AutoButtonColor = canReroll
		-- กดสองครั้งยืนยัน: สิทธิ์สุ่มฟรีมีวันละครั้ง พลาดนิ้วเดียวไม่ควรเสียไป
		reroll.Activated:Connect(function()
			if not canReroll then
				UiSound.Play("Click")
				self:Flash("🔄 สุ่มใบใหม่ฟรีได้วันละครั้ง — ใช้ไปแล้ววันนี้")
				return
			end
			UiSound.Play("Click")
			if self.armed ~= order.slot then
				self.armed = order.slot
				reroll.Text = "แน่ใจ?"
				reroll.TextSize = 12
				reroll.BackgroundColor3 = Color3.fromRGB(150, 96, 70)
				task.delay(3, function()
					if self.armed == order.slot and reroll.Parent then
						self.armed = nil
						reroll.Text = "🔄"
						reroll.TextSize = 16
						reroll.BackgroundColor3 = Color3.fromRGB(96, 110, 150)
					end
				end)
				self:Flash("กด “แน่ใจ?” อีกครั้งเพื่อสุ่มใบนี้ใหม่ (ฟรีวันละครั้ง)")
				return
			end
			self.armed = nil
			if self.onReroll then self.onReroll(order.slot) end
		end)
	end
	self.cards[order.slot] = card
end

-- ข้อความสั้นแทนที่แถบสถานะชั่วคราว (ไม่มีข้อความกลางจอ)
function ExportGui:Flash(text)
	self.flashText = text
	self.stripText.Text = text
	local token = os.clock()
	self.flashToken = token
	task.delay(2.5, function()
		if self.flashToken == token then
			self.flashText = nil
			self:Tick()
		end
	end)
end

-- ตารางปลด: ทุกเลเวลจนถึงเลเวลสุดท้ายที่มีของ · ผ่านแล้ว ✓ · ตอนนี้ ◀ · ยัง 🔒
function ExportGui:DrawUnlocks(snap)
	-- ตาราง 50 เลเวล = ~700 ชิ้น UI · วาดใหม่เฉพาะตอนเลเวล/EXP เปลี่ยน ไม่ใช่ทุกภาพที่เซิร์ฟส่งมา (มือถือกระตุก)
	local key = ("%s:%s:%s:%s"):format(tostring(snap.level), tostring(snap.into), tostring(snap.need), tostring(snap.max))
	if self.unlocksKey == key then return end -- ส่วนเลเวลถูกลบที่นี่ที่เดียว คีย์เดิม = ของบนหน้ายังครบ
	self.unlocksKey = key
	for _, child in ipairs(self.unlocksPage:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local current = snap.level or 1
	local last = math.min(FarmLevelConfig.MaxLevel, math.max(FarmLevelConfig.LastUnlockLevel(), current + 1))
	local focus
	for level = 1, last do
		local rows = FarmLevelConfig.UnlocksAt(level)
		if #rows > 0 or level == current then
			local done, now = level < current, level == current
			local section = Instance.new("Frame")
			section.LayoutOrder = level
			section.Size = UDim2.new(1, 0, 0, 0)
			section.AutomaticSize = Enum.AutomaticSize.Y
			section.BackgroundColor3 = now and Color3.fromRGB(58, 56, 40) or CARD
			section.BackgroundTransparency = done and 0.35 or 0
			section.BorderSizePixel = 0
			section.Parent = self.unlocksPage
			corner(section, 8)
			if now then stroke(section, RUNE, 0.1, 2) end
			local pad = Instance.new("UIPadding")
			pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 8)
			pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
			pad.Parent = section
			local list = Instance.new("UIListLayout")
			list.Padding = UDim.new(0, 4)
			list.SortOrder = Enum.SortOrder.LayoutOrder
			list.Parent = section

			local status = done and "✓ ปลดแล้ว" or (now and "◀ เลเวลตอนนี้" or "🔒")
			if level == current + 1 and not snap.max then
				status = ("🔒 อีก %s EXP"):format(commas(math.max(0, (snap.need or 0) - (snap.into or 0))))
			end
			local head = label(section, {
				text = ("เลเวล %d   <font color=\"#%s\">%s</font>"):format(level,
					(done and ENOUGH or (now and RUNE or TEXT_MUTED)):ToHex(), status),
				rich = true, size = 14, color = done and TEXT_MUTED or TEXT_LIGHT, dim = UDim2.new(1, 0, 0, 22),
			})
			head.LayoutOrder = 0

			local grid = Instance.new("Frame")
			grid.LayoutOrder = 1
			grid.BackgroundTransparency = 1
			grid.Size = UDim2.new(1, 0, 0, 0)
			grid.AutomaticSize = Enum.AutomaticSize.Y
			grid.Parent = section
			local gl = Instance.new("UIGridLayout")
			gl.CellSize = UDim2.new(0.5, -4, 0, 28)
			gl.CellPadding = UDim2.fromOffset(6, 4)
			gl.SortOrder = Enum.SortOrder.LayoutOrder
			gl.Parent = grid
			for i, row in ipairs(rows) do
				local chip = Instance.new("Frame")
				chip.LayoutOrder = i
				chip.BackgroundColor3 = STONE_DEEP
				chip.BackgroundTransparency = level > current and 0.4 or 0
				chip.BorderSizePixel = 0
				chip.Parent = grid
				corner(chip, 6)
				if row.emoji then
					label(chip, { text = row.emoji, size = 16, align = Enum.TextXAlignment.Center,
						pos = UDim2.fromOffset(2, 0), dim = UDim2.fromOffset(26, 28), font = Enum.Font.Gotham })
				else
					local icon = Instance.new("ImageLabel")
					icon.BackgroundTransparency = 1
					icon.Size = UDim2.fromOffset(22, 22)
					icon.Position = UDim2.fromOffset(4, 3)
					ItemIcon.Apply(icon, row.icon)
					icon.ImageTransparency = level > current and 0.4 or 0
					icon.Parent = chip
				end
				label(chip, { text = row.text, size = 12, font = Enum.Font.GothamMedium,
					color = level > current and TEXT_MUTED or TEXT_LIGHT,
					pos = UDim2.fromOffset(32, 0), dim = UDim2.new(1, -36, 1, 0) })
			end
			if now then focus = section end
		end
	end
	-- เลื่อนให้เลเวลปัจจุบันอยู่บนสุด (เฟรมหน้าเพราะขนาดอัตโนมัติยังไม่คำนวณ)
	if focus then
		task.defer(function()
			if focus.Parent then
				self.unlocksPage.CanvasPosition = Vector2.new(0,
					math.max(0, focus.AbsolutePosition.Y - self.unlocksPage.AbsolutePosition.Y + self.unlocksPage.CanvasPosition.Y - 8))
			end
		end)
	end
end

function ExportGui:Render()
	local snap = self.snap
	if not snap then return end
	for id, b in pairs(self.tabButtons) do
		local on = id == self.page
		b.BackgroundColor3 = on and RUNE or STONE_DEEP
		b.TextColor3 = on and INK or TEXT_MUTED
	end
	self.ordersPage.Visible = self.page == "orders"
	self.unlocksPage.Visible = self.page == "unlocks"
	if self.page == "unlocks" then self:DrawUnlocks(snap) end
end

-- ภาพใหม่จากเซิร์ฟ · `snap.open` = เปิดหน้าต่าง (กด E) · ภาพอัปเดตห้ามเปิดหน้าต่างเอง
function ExportGui:Show(snap)
	if not snap.open and not self.gui.Enabled then return end
	local firstOpen = snap.open and not self.gui.Enabled
	self.snap = snap
	if firstOpen then self.page = "orders" end

	self.levelPill.Text = ("🌾 Lv %d"):format(snap.level or 1)
	local need = math.max(1, snap.need or 1)
	TweenService:Create(self.expFill, TweenInfo.new(firstOpen and 0 or 0.4), {
		Size = UDim2.fromScale(math.clamp((snap.into or 0) / need, 0, 1), 1),
	}):Play()
	-- เพดานเลเวล (FarmLevelConfig.MaxLevel = 50) — หลอดเต็มสีทอง บอกว่ารอเปิดเพิ่ม ไม่โชว์ตัวเลขที่ไม่มีความหมาย
	self.expFill.BackgroundColor3 = snap.max and RUNE or EXP
	self.expText.Text = snap.max and "เลเวลสูงสุด · รอเปิดเพิ่มในอัปเดตหน้า"
		or ("%s / %s EXP ฟาร์ม"):format(commas(snap.into or 0), commas(need))
	self.gemsText.Text = ("💎 วันนี้ %d/%d   ·   🔄 สุ่มใหม่ฟรี %s"):format(snap.gemsToday or 0, snap.gemsDayCap or 5,
		(snap.rerollLeft or 0) > 0 and "เหลือ 1" or "ใช้แล้ว")

	for _, child in ipairs(self.ordersPage:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	self.cards = {}
	self.armed = nil
	for _, order in ipairs(snap.orders or {}) do self:DrawCard(order, snap) end

	self:Render()
	self:Tick()
	self.gui.Enabled = true
end

function ExportGui:Hide()
	local was = self.gui.Enabled
	self.gui.Enabled = false
	if was and self.onClose then self.onClose() end
end

function ExportGui:IsOpen()
	return self.gui.Enabled
end

return ExportGui
