-- ArenaShopGui: หน้าร้านซื้อของช่วงเตรียมตัวก่อนเริ่มรอบ — วาดตามภาพม็อกอัพที่ผู้ใช้ส่งมา 2026-09-23
--
-- ตัววาดล้วน ไม่รู้จัก remote และไม่ตัดสินอะไรเลย (แบบเดียวกับ `HudGui` กับ `PvpPartyGui`)
-- ราคาและการจัดหมวดมาจาก `ArenaConfig.Shop` ที่เดียว ซึ่งเป็นตารางเดียวกับที่เซิร์ฟเวอร์ใช้ตัดเงิน
--
-- ผังตามภาพ:
--   [ระยะใกล้]  ดาบ · ดาบใหญ่ · โล่            │ [เกราะ] หนัง
--   [ระยะไกล]  ปืน · ธนู · คทา · สมุดเวท       │         โซ่
--                                              │         เหล็ก
--   [เงิน ###]  [ของใช้]  ยาเล็ก · ยาใหญ่ · กล่องพยาบาล · น้ำ
local ArenaConfig = require(script.Parent.Parent.ArenaConfig)
local ItemCatalog = require(script.Parent.Parent.ItemCatalog)
local ItemIcon = require(script.Parent.ItemIcon)

local ArenaShopGui = {}
ArenaShopGui.__index = ArenaShopGui

local PANEL = Color3.fromRGB(150, 150, 150)
local CARD = Color3.fromRGB(232, 232, 232)
local CARD_OWNED = Color3.fromRGB(226, 184, 78)   -- ทองแบบในภาพ = ถืออยู่ตอนนี้
local CARD_LOCKED = Color3.fromRGB(120, 120, 120) -- ซื้อไม่ได้แล้วในรอบนี้ หรือเงินไม่พอ
local LABEL_BG = Color3.fromRGB(196, 200, 210)
local TEXT_DARK = Color3.fromRGB(30, 30, 34)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 8)
	c.Parent = parent
	return c
end

-- ป้ายหัวแถว/หัวคอลัมน์ทรงเดียวกับในภาพ (กล่องเทาอ่อนมุมมน ตัวหนังสือดำ)
local function tag(parent, text, position, size)
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = LABEL_BG
	label.BorderSizePixel = 0
	label.Position = position
	label.Size = size or UDim2.fromOffset(88, 34)
	label.Font = Enum.Font.SourceSansBold
	label.TextSize = 18
	label.TextColor3 = TEXT_DARK
	label.Text = text
	label.Parent = parent
	corner(label, UDim.new(0, 6))
	return label
end

--------------------------------------------------------------------------------
function ArenaShopGui.new()
	local self = setmetatable({}, ArenaShopGui)
	self.onBuy = nil
	self.cards = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "ArenaShopGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 18
	gui.Enabled = false
	self.gui = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(900, 500)
	panel.BackgroundColor3 = PANEL
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	self.panel = panel

	-- ปุ่มปิด — กากบาทวาดจาก Frame สองอันหมุน 45° **ไม่ใช่ตัวอักษร ✕**
	-- (บทเรียนเดิมของโปรเจ็ค: ฟอนต์ Roblox วาดสัญลักษณ์หนาเป็นกล่องเปล่า เหมือนลูกศรกับเครื่องหมายบวก)
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(36, 36)
	close.BackgroundTransparency = 1
	close.Text = ""
	close.Parent = panel
	for _, angle in ipairs({ 45, -45 }) do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromOffset(26, 4)
		bar.Rotation = angle
		bar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		bar.BorderSizePixel = 0
		bar.Parent = close
	end
	self.closeButton = close

	--------------------------------------------------------------------------
	-- หัวข้อ
	--------------------------------------------------------------------------
	tag(panel, "อาวุธเล็ก", UDim2.fromOffset(120, 18), UDim2.fromOffset(96, 34))
	tag(panel, "อาวุธใหญ่", UDim2.fromOffset(228, 18), UDim2.fromOffset(96, 34))
	tag(panel, "เกราะ", UDim2.fromOffset(700, 18), UDim2.fromOffset(96, 34))
	tag(panel, "ระยะใกล้", UDim2.fromOffset(20, 76), UDim2.fromOffset(92, 34))
	tag(panel, "ระยะไกล", UDim2.fromOffset(20, 186), UDim2.fromOffset(92, 34))
	tag(panel, "ของใช้", UDim2.fromOffset(150, 372), UDim2.fromOffset(560, 32))

	-- กล่องเงิน: **ซิลเวอร์ของแมตช์ ไม่ใช่เหรียญในกระเป๋า** (คนละจำนวนกันคนละเรื่องกัน)
	local silver = Instance.new("TextLabel")
	silver.Name = "Silver"
	silver.Position = UDim2.fromOffset(20, 372)
	silver.Size = UDim2.fromOffset(112, 74)
	silver.BackgroundColor3 = LABEL_BG
	silver.BorderSizePixel = 0
	silver.Font = Enum.Font.SourceSansBold
	silver.TextSize = 22
	silver.TextColor3 = TEXT_DARK
	silver.Text = "0"
	silver.Parent = panel
	corner(silver, UDim.new(0, 6))
	self.silverLabel = silver

	--------------------------------------------------------------------------
	-- การ์ดไอเทม
	--------------------------------------------------------------------------
	local ROW_Y = { melee = 84, ranged = 194, armor = 66, use = 408 }
	local function positionFor(entry)
		if entry.row == "armor" then
			return UDim2.fromOffset(700, ROW_Y.armor + (entry.col - 1) * 100), UDim2.fromOffset(88, 88)
		elseif entry.row == "use" then
			return UDim2.fromOffset(150 + (entry.col - 1) * 142, ROW_Y.use), UDim2.fromOffset(134, 62)
		end
		return UDim2.fromOffset(120 + (entry.col - 1) * 108, ROW_Y[entry.row]), UDim2.fromOffset(96, 86)
	end

	for _, entry in ipairs(ArenaConfig.Shop) do
		local item = ItemCatalog.Items[entry.id]
		local position, size = positionFor(entry)

		local card = Instance.new("TextButton")
		card.Name = entry.id
		card.Position = position
		card.Size = size
		card.BackgroundColor3 = CARD
		card.BorderSizePixel = 0
		card.AutoButtonColor = true
		card.Text = ""
		card.Parent = panel
		corner(card, UDim.new(0, 6))

		local icon = Instance.new("ImageLabel")
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 4)
		icon.Size = UDim2.fromOffset(size.Y.Offset - 26, size.Y.Offset - 26)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = card
		ItemIcon.Apply(icon, item and item.icon)

		-- ราคาอยู่ใต้รูปตามภาพ · ชื่อไอเทมอยู่ใน tooltip ไม่ได้อยู่บนการ์ด (การ์ดเล็กเกินกว่าจะใส่ทั้งสอง)
		local price = Instance.new("TextLabel")
		price.AnchorPoint = Vector2.new(0.5, 1)
		price.Position = UDim2.new(0.5, 0, 1, -2)
		price.Size = UDim2.new(1, -6, 0, 20)
		price.BackgroundTransparency = 1
		price.Font = Enum.Font.SourceSansBold
		price.TextSize = 17
		price.TextColor3 = TEXT_DARK
		price.Text = tostring(entry.price)
		price.Parent = card

		card.MouseButton1Click:Connect(function()
			if self.onBuy then self.onBuy(entry.id) end
		end)

		self.cards[entry.id] = { card = card, icon = icon, price = price, entry = entry }
	end

	--------------------------------------------------------------------------
	-- แถบล่าง: ชื่อของที่เมาส์ชี้อยู่ + เวลาที่เหลือของช่วงซื้อ
	--------------------------------------------------------------------------
	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -6)
	hint.Size = UDim2.new(1, -40, 0, 24)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.SourceSans
	hint.TextSize = 18
	hint.TextColor3 = Color3.fromRGB(40, 40, 44)
	hint.Text = ""
	hint.Parent = panel
	self.hint = hint

	for id, row in pairs(self.cards) do
		local item = ItemCatalog.Items[id]
		row.card.MouseEnter:Connect(function()
			hint.Text = ("%s — %d ซิลเวอร์"):format(item and item.name or id, row.entry.price)
		end)
		row.card.MouseLeave:Connect(function() hint.Text = "" end)
	end

	return self
end

function ArenaShopGui:OnBuy(callback)
	self.onBuy = callback
end

function ArenaShopGui:OnClose(callback)
	self.closeButton.MouseButton1Click:Connect(callback)
end

function ArenaShopGui:SetVisible(visible)
	self.gui.Enabled = visible and true or false
end

function ArenaShopGui:IsVisible()
	return self.gui.Enabled
end

-- `snap` คือภาพของแมตช์จากเซิร์ฟเวอร์ — ใช้ `silver`, `loadout` และ `bought` เท่านั้น
function ArenaShopGui:Render(snap)
	self.silverLabel.Text = tostring(snap.silver or 0)

	for id, row in pairs(self.cards) do
		local slot = row.entry.slot
		local owned = snap.loadout and snap.loadout[slot] == id
		local slotUsed = snap.bought and snap.bought[slot] ~= nil
		local afford = (snap.silver or 0) >= row.entry.price

		local colour = CARD
		if owned then
			colour = CARD_OWNED
		elseif slotUsed or not afford then
			colour = CARD_LOCKED
		end
		row.card.BackgroundColor3 = colour
		-- **ปุ่มที่กดไม่ได้ต้องดูกดไม่ได้** ไม่ใช่กดแล้วเงียบ — คนจะคิดว่าหน้าจอค้าง
		row.card.AutoButtonColor = not slotUsed and afford
		ItemIcon.SetFade(row.icon, (slotUsed or not afford) and 0.45 or 0)
	end
end

return ArenaShopGui
