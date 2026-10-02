-- InventoryGui: the bag screen — a centred glass panel with the slot grid, the two equipment slots, the gold
-- and weight readouts, an auto-sort button and a close cross.
--
-- Pure UI builder, like HudGui: it draws what it is handed and reports clicks through callbacks. The
-- controller owns every decision and the server owns the data.
local ItemCatalog = require(script.Parent.Parent.ItemCatalog)
local NumberBox = require(script.Parent.NumberBox) -- พิมพ์เกินที่มี = เด้งเป็นเลขสูงสุด (2026-10-02)
local ItemIcon = require(script.Parent.ItemIcon)
local UiSound = require(script.Parent.UiSound)
local InventoryConfig = require(script.Parent.Parent.InventoryConfig)
local Responsive = require(script.Parent.Responsive)
local FishingConfig = require(script.Parent.Parent.FishingConfig)

local InventoryGui = {}
InventoryGui.__index = InventoryGui

-- Same palette as the lobby, so the two screens read as one game.
local ACCENT = Color3.fromRGB(216, 172, 84)
local TEXT_LIGHT = Color3.fromRGB(240, 240, 245)
local TEXT_MUTED = Color3.fromRGB(180, 180, 195)
local GLASS = Color3.fromRGB(255, 255, 255)
local SLOT_BG = Color3.fromRGB(26, 25, 32)
local PANEL_BG = Color3.fromRGB(14, 13, 18)

local COLS = 6
-- Rows follow the bag size rather than being written down twice: change SlotCount and the grid follows.
-- **กริดใหญ่พอสำหรับฝั่งที่ช่องเยอะที่สุด** ไม่ใช่ผลรวม — สองแท็บไม่เคยแสดงพร้อมกัน
local ROWS = math.ceil(math.max(InventoryConfig.SlotCount, InventoryConfig.VipSlotCount) / COLS)

-- Colour-codes the slot border by what is in it, so a bag reads at a glance without icon art.
local KIND_TINT = {
	weapon = Color3.fromRGB(198, 96, 84),
	armor = Color3.fromRGB(110, 146, 196),
	consumable = Color3.fromRGB(104, 184, 118),
	junk = Color3.fromRGB(130, 126, 120),
}

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 8)
	c.Parent = parent
	return c
end

local GOLD_BORDER = Color3.fromRGB(255, 200, 60) -- กรอบของขอบทอง (เฟส 2b)

-- **ของขอบทองในช่องกระเป๋า** (ผู้ใช้เลือก 2026-09-27 "แสงวิ่งรอบกรอบ + ประกาย")
-- กรอบทองหนา + แสงขาววิ่งวนรอบกรอบ + พื้นช่องเรืองแสงทอง (หายใจเข้าออก) + ประกายระยิบสองจุดที่มุม
-- ⚠️ วาดด้วยกรอบ/Frame ล้วน ห้ามใช้ตัวอักษรสัญลักษณ์ — ✦ ที่เคยใส่ขึ้นเป็นกล่องเปล่าในเกม (ฟอนต์ Roblox วาดไม่ได้)
-- สร้างครั้งเดียวต่อช่องที่เป็นทอง แล้ว Render รอบถัดไปปล่อยไว้ (แอนิเมชันเดินต่อ ไม่กระตุกทุกครั้งที่กระเป๋าอัปเดต)
-- ช่องที่เลิกเป็นทอง (ย้าย/ขาย) = ล้างทิ้งพร้อมหยุด tween
local TweenService = game:GetService("TweenService")
local GOLD_SWEEP = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(214, 146, 28)),
	ColorSequenceKeypoint.new(0.40, Color3.fromRGB(255, 200, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 252, 226)),
	ColorSequenceKeypoint.new(0.60, Color3.fromRGB(255, 200, 60)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(214, 146, 28)),
})
local SPARKLE = Color3.fromRGB(255, 246, 204)
local GOLD_BG_DIM = Color3.fromRGB(64, 46, 14)
local GOLD_BG_BRIGHT = Color3.fromRGB(122, 90, 26)

-- แถบความคงทนในช่อง (ผู้ใช้สั่ง 2026-09-29): เขียว · ต่ำกว่าครึ่ง = เหลือง · ไม่ถึง 5% = แดง
local DUR_TRACK = Color3.fromRGB(16, 14, 12)
InventoryGui.DurabilityColours = {
	good = Color3.fromRGB(88, 204, 104),
	low = Color3.fromRGB(240, 200, 64),
	critical = Color3.fromRGB(232, 72, 60),
}
-- เพดาน = maxDurability (อาวุธ/เครื่องมือ) หรือ armor (เกราะ) แบบเดียวกับแผงของที่สวม · ไม่มีวันพัง = ไม่มีแถบ
local function setDurBar(bar, item, durability)
	local max = item and not item.unbreakable and (item.maxDurability or item.armor)
	if not max or type(durability) ~= "number" or max <= 0 then
		bar.Visible = false
		return
	end
	local fraction = math.clamp(durability / max, 0, 1)
	local C = InventoryGui.DurabilityColours
	bar.Fill.Size = UDim2.fromScale(fraction, 1)
	bar.Fill.BackgroundColor3 = fraction < 0.05 and C.critical or fraction < 0.5 and C.low or C.good
	-- 0 = พังค้าง (ของติดสกินไม่หาย) แถบว่างทั้งเส้น จึงแดงที่พื้นแถบแทน
	bar.BackgroundColor3 = fraction <= 0 and C.critical or DUR_TRACK
	bar.Visible = true
end

local function removeGoldFx(entry)
	local fx = entry.goldFx
	if not fx then return end
	for _, t in ipairs(fx.tweens) do t:Cancel() end
	for _, obj in ipairs(fx.objects) do obj:Destroy() end
	-- คืนพื้นช่องเป็นแบบปกติ (ค่าเดียวกับตอนสร้างช่อง)
	entry.button.BackgroundColor3 = SLOT_BG
	entry.button.BackgroundTransparency = 0.25
	entry.goldFx = nil
end

local function addGoldFx(entry)
	if entry.goldFx then return end
	local fx = { objects = {}, tweens = {} }
	entry.goldFx = fx
	local function loop(obj, props, info)
		local t = TweenService:Create(obj, info, props)
		t:Play()
		table.insert(fx.tweens, t)
	end

	-- แสงวิ่งรอบกรอบ: ไล่สีบนตัวกรอบแล้วหมุนไม่หยุด (สีกรอบต้องเป็นขาว ไล่สีจึงออกมาตามจริง)
	local sweep = Instance.new("UIGradient")
	sweep.Color = GOLD_SWEEP
	sweep.Parent = entry.stroke
	table.insert(fx.objects, sweep)
	loop(sweep, { Rotation = 360 }, TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1))

	-- พื้นช่องเรืองแสงทอง หายใจเข้าออกช้าๆ — ใช้พื้นของปุ่มเอง เพราะ ScreenGui นี้เป็น ZIndex แบบ Global
	-- (ค่าเริ่มต้น) Frame แสงแยกที่ตั้ง ZIndex ต่ำจะไปจมใต้ช่อง ส่วนพื้นปุ่มอยู่หลังไอคอนเสมอ
	entry.button.BackgroundColor3 = GOLD_BG_DIM
	entry.button.BackgroundTransparency = 0.1
	loop(entry.button, { BackgroundColor3 = GOLD_BG_BRIGHT },
		TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true))

	-- ประกายระยิบ: สี่เหลี่ยมเล็กหมุน 45° (เพชร) โผล่-หายสลับกันที่สองมุม · ZIndex 3 = เหนือไอคอน (Global)
	for i, spot in ipairs({ Vector2.new(0.2, 0.22), Vector2.new(0.8, 0.78) }) do
		local star = Instance.new("Frame")
		star.Name = "GoldSparkle"
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(spot.X, spot.Y)
		star.Size = UDim2.fromOffset(2, 2)
		star.Rotation = 45
		star.BackgroundColor3 = SPARKLE
		star.BackgroundTransparency = 1
		star.BorderSizePixel = 0
		star.ZIndex = 3
		star.Parent = entry.button
		table.insert(fx.objects, star)
		loop(star, { BackgroundTransparency = 0, Size = UDim2.fromOffset(7, 7) },
			TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, (i - 1) * 0.9))
	end
end

local function stroke(parent, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or GLASS
	s.Transparency = transparency or 0.75
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

local function label(parent, text, size, color, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size
	l.TextColor3 = color or TEXT_LIGHT
	l.Text = text
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

--------------------------------------------------------------------------------
-- แท็บกระเป๋า
--------------------------------------------------------------------------------

-- **"ของใช้ในฟาร์ม" = ของที่เอาไปวางบนเกาะได้เท่านั้น** (kind = "placeable")
--
-- ผู้ใช้กำหนด (2026-09-22): "พวกวัตถุดิบที่ได้จากฟาร์มเป็นของเกมหลักทั้งหมด" — ข้าว ผัก นม ไข่ ไม้
-- แร่ ปลา ที่หาได้บนเกาะ **ไม่ใช่ของฟาร์ม** มันคือวัตถุดิบของเกมหลักที่บังเอิญหาได้บนเกาะ และเอาไป
-- ขาย/คราฟ/ส่งเควสในเกมหลักได้ทั้งหมด · สิ่งที่แยกจริงๆ คือบ้าน รั้ว แปลงผัก คอกสัตว์ โซนแร่ ต้นไม้
-- ซึ่งใช้ได้ที่เดียวคือบนเกาะ
--
-- แยกด้วย `kind` ไม่ใช่รายชื่อไอเทม — เพิ่มของวางใหม่ใน ItemCatalog แล้วมันเข้าแท็บถูกเอง
-- **แยกขาดจากกัน ไม่มีแท็บ "ทั้งหมด"** (ผู้ใช้สั่ง 2026-09-22): กดแท็บไหนเห็นแต่ของแท็บนั้น
-- ช่องนอกแท็บ**ว่างเปล่าและกดไม่ได้** ไม่ใช่หรี่ลง
--
-- ชื่อแท็บคือ "กระเป๋าหลัก" / "กระเป๋า VIP" (ผู้ใช้ตั้ง) — `id` ยังเป็น main/farm เหมือนเดิม
-- เพราะมันคือกุญแจที่โค้ดใช้ ไม่ใช่สิ่งที่คนอ่าน · เปลี่ยนป้ายไม่ต้องแตะตรรกะที่ไหนเลย
InventoryGui.Tabs = {
	{ id = "main", label = "กระเป๋าหลัก" },
	{ id = "farm", label = "กระเป๋า VIP" },
}

-- ของที่นับเป็น "กระเป๋า VIP" = ของวางบนเกาะ (`placeable`) **และของที่ใช้ได้เฉพาะบนเกาะ**
--
-- `vip = true` ในแคตตาล็อกเป็นตัวบังคับด้วยมือสำหรับของที่ไม่ใช่ `placeable` แต่ควรอยู่ฝั่งฟาร์ม —
-- เมล็ดพันธุ์เป็นเคสแรก (ผู้ใช้แจ้ง 2026-09-22: มันใช้ได้แค่กับแปลงผักบนเกาะ ไม่มีความหมายในเกมหลัก)
local FARM_KINDS = { placeable = true }

function InventoryGui.IsFarmItem(itemId)
	local item = ItemCatalog.Get(itemId)
	if not item then return false end
	return item.vip == true or FARM_KINDS[item.kind] == true
end

-- ของชิ้นนี้อยู่ในแท็บที่เลือกไหม
function InventoryGui.InTab(itemId, tab)
	if tab == nil then return true end
	local isFarm = InventoryGui.IsFarmItem(itemId)
	if tab == "farm" then return isFarm end
	return not isFarm
end

function InventoryGui.new()
	local self = setmetatable({}, InventoryGui)
	self.slotButtons = {}
	self.onSlotClicked = nil
	self.onEquipSlotClicked = nil

	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 15 -- under the downed overlay (20), above the HUD
	gui.Enabled = false
	self.gui = gui

	-- Click-catcher behind the panel: clicking outside closes the bag.
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.55
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Parent = gui
	self.backdrop = backdrop

	-- The panel itself. Sized in SCALE so it can never exceed a phone screen, with a max size so it does not
	-- become a billboard on a desktop monitor.
	-- A phone gets nearly the whole screen: at 0.72x0.78 of an 844x390 landscape phone the grid's square
	-- cells came out 20px a side, which is smaller than a fingertip. Desktop keeps the smaller panel, since
	-- there a full-screen bag would be a billboard.
	local small = Responsive.IsSmallScreen()
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = small and UDim2.fromScale(0.94, 0.94) or UDim2.fromScale(0.72, 0.78)
	panel.BackgroundColor3 = PANEL_BG
	panel.BackgroundTransparency = 0.18 -- "โปร่งใสเล็กน้อย"
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	stroke(panel, ACCENT, 0.55, 1.5)
	local panelSize = Instance.new("UISizeConstraint")
	panelSize.MaxSize = Vector2.new(760, 560)
	-- No MinSize on a phone: a floor taller than the screen is what pushed the panel off the bottom edge.
	panelSize.MinSize = small and Vector2.new(240, 180) or Vector2.new(280, 220)
	panelSize.Parent = panel
	self.panel = panel

	-- Header: title, gold, weight, close cross.
	local title = label(panel, "กระเป๋า", 20, ACCENT)
	title.Size = UDim2.new(0.4, 0, 0, 30)
	title.Position = UDim2.new(0, 18, 0, 12)
	title.Font = Enum.Font.GothamBold

	-- ⚠️ แถบแท็บกระเป๋าหลัก/VIP เคยทับป้ายน้ำหนัก (y 33-49 ใต้เงิน) ทั้งคอมและมือถือ และบนมือถือทับเงินด้วย
	-- (ผู้ใช้แจ้ง 2026-09-26) · เงินอยู่แถวบนสุด จบก่อนปุ่มปิด · น้ำหนักย้ายลงไปมุมขวาล่าง แถวเดียวกับปุ่มจัดกระเป๋า
	local goldLabel = label(panel, "0", 15, ACCENT, Enum.TextXAlignment.Right)
	goldLabel.Size = UDim2.new(0.6, -56, 0, 18)
	goldLabel.Position = UDim2.new(0.4, 0, 0, small and 3 or 12)
	self.goldLabel = goldLabel

	local weightLabel = label(panel, "0 / 0", 13, TEXT_MUTED, Enum.TextXAlignment.Right)
	weightLabel.AnchorPoint = Vector2.new(1, 1)
	weightLabel.Size = UDim2.new(0.4, 0, 0, 18)
	weightLabel.Position = UDim2.new(1, -18, 1, small and -6 or -20) -- มือถือ: ช่องจบที่ 28px จากขอบล่าง
	self.weightLabel = weightLabel

	local close = Instance.new("TextButton")
	close.Name = "CloseButton"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(30, 30)
	close.BackgroundColor3 = Color3.fromRGB(52, 48, 56)
	close.BackgroundTransparency = 0.25
	close.Font = Enum.Font.GothamBold
	close.TextSize = 18
	close.TextColor3 = TEXT_LIGHT
	close.Text = "\195\151" -- multiplication sign, a cleaner cross than "x"
	close.Parent = panel
	corner(close, UDim.new(1, 0))
	stroke(close, GLASS, 0.6)
	self.closeButton = close

	--------------------------------------------------------------------------
	-- Equipment column (left): weapon and armor.
	--------------------------------------------------------------------------
	local equipColumn = Instance.new("Frame")
	equipColumn.Name = "Equipment"
	equipColumn.Position = UDim2.new(0, 18, 0, 62)
	equipColumn.Size = UDim2.new(0.26, 0, 1, -110)
	equipColumn.BackgroundTransparency = 1
	equipColumn.Parent = panel

	self.equipSlots = {}
	local EQUIP_ORDER = { { key = "weapon", text = "อาวุธ" }, { key = "armor", text = "เกราะ" } }
	for i, entry in ipairs(EQUIP_ORDER) do
		local holder = Instance.new("TextButton")
		holder.Name = entry.key
		-- Square, like the bag slots. The height is a SCALE of the column (which is tall enough for two of
		-- them plus a gap) and the aspect constraint then matches the width to it; sizing the height to zero
		-- and hoping the constraint would fill it in collapsed the slot to nothing.
		holder.Size = UDim2.new(1, 0, 0.42, 0)
		holder.Position = UDim2.new(0, 0, (i - 1) * 0.52, 0)
		holder.BackgroundColor3 = SLOT_BG
		holder.BackgroundTransparency = 0.15
		holder.Text = ""
		holder.AutoButtonColor = true
		holder.Parent = equipColumn
		corner(holder, UDim.new(0, 10))
		local holderAspect = Instance.new("UIAspectRatioConstraint")
		holderAspect.AspectRatio = 1
		holderAspect.DominantAxis = Enum.DominantAxis.Height
		holderAspect.Parent = holder
		local holderStroke = stroke(holder, ACCENT, 0.7)

		local caption = label(holder, entry.text, 11, TEXT_MUTED)
		caption.Size = UDim2.new(1, -12, 0, 14)
		caption.Position = UDim2.new(0, 8, 0, 6)

		local name = label(holder, "ว่าง", 14, TEXT_LIGHT)
		name.Size = UDim2.new(1, -12, 0, 20)
		name.Position = UDim2.new(0, 8, 0, 24)
		name.TextTruncate = Enum.TextTruncate.AtEnd

		local durability = label(holder, "", 10, TEXT_MUTED)
		durability.Size = UDim2.new(1, -12, 0, 14)
		durability.Position = UDim2.new(0, 8, 0, 48)

		-- The slot is square and the text only fills its top, so the artwork goes in the space below it.
		-- Reading what you are wearing off a picture is quicker than reading a name, and the room was
		-- already there.
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.AnchorPoint = Vector2.new(0.5, 1)
		icon.Position = UDim2.new(0.5, 0, 1, -6)
		icon.Size = UDim2.new(0.62, 0, 0.5, 0)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Visible = false
		icon.Parent = holder

		holder.Activated:Connect(function()
			if self.onEquipSlotClicked then self.onEquipSlotClicked(entry.key) end
		end)

		self.equipSlots[entry.key] = { button = holder, name = name, durability = durability,
			stroke = holderStroke, icon = icon }
	end

	--------------------------------------------------------------------------
	-- แท็บกรองของ: ทั้งหมด / ของเกมหลัก / ของใช้ในฟาร์ม
	--------------------------------------------------------------------------
	--
	-- **เป็นตัวกรองการมองเห็น ไม่ใช่การจัดเรียงใหม่** ช่องที่เท่าไหร่ยังเป็นช่องนั้น — เลขช่องคือสิ่งเดียว
	-- ที่ทุกคำสั่ง (ใส่/ใช้/ทิ้ง/ให้/ฝาก) ใช้อ้างถึงของชิ้นหนึ่ง ถ้าแท็บขยับเลขช่อง คนกดของชิ้นแรกจะได้
	-- ของอีกชิ้นโดยไม่มี error ให้เห็น (บทเรียนเดียวกับบอร์ดเควสที่กรองคนละแบบสองที่)
	-- ช่องที่ไม่เข้าแท็บจึงถูกหรี่ลง ไม่ใช่ถูกเอาออก
	-- **หน้าตาแบบ segmented control** (ผู้ใช้ทัก 2026-09-25 "สีแปลก ไม่โมเดิร์น มองไม่ชัด" — เดิมแท็บที่เลือก
	-- เป็นพื้นขาวทึบตัวหนังสือทอง อ่านไม่ออก) รางมืดขอบทองบาง · แท็บที่เลือกเป็นทองทึบตัวหนังสือเข้ม
	local tabBar = Instance.new("Frame")
	tabBar.Name = "Tabs"
	tabBar.Position = UDim2.new(0.3, 0, 0, small and 22 or 32)
	tabBar.Size = UDim2.new(0.68, -58, 0, small and 24 or 28) -- จบก่อนปุ่มปิด (เดิมทับปุ่ม ✕ ด้วย)
	tabBar.BackgroundColor3 = SLOT_BG
	tabBar.BackgroundTransparency = 0.1
	tabBar.BorderSizePixel = 0
	tabBar.Parent = panel
	corner(tabBar, UDim.new(0, 8))
	local tabEdge = Instance.new("UIStroke")
	tabEdge.Color = ACCENT
	tabEdge.Transparency = 0.65
	tabEdge.Thickness = 1
	tabEdge.Parent = tabBar
	local tabPad = Instance.new("UIPadding")
	tabPad.PaddingLeft, tabPad.PaddingRight = UDim.new(0, 3), UDim.new(0, 3)
	tabPad.PaddingTop, tabPad.PaddingBottom = UDim.new(0, 3), UDim.new(0, 3)
	tabPad.Parent = tabBar

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 3)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	self.bagTab = "main"
	self.bagTabs = {}
	for order, spec in ipairs(InventoryGui.Tabs) do
		local b = Instance.new("TextButton")
		b.LayoutOrder = order
		b.Size = UDim2.new(1 / #InventoryGui.Tabs, -3, 1, 0)
		b.BackgroundColor3 = ACCENT
		b.BackgroundTransparency = 1
		b.AutoButtonColor = false
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = small and 11 or 12
		b.TextColor3 = TEXT_MUTED
		b.Text = spec.label
		b.AutoLocalize = false
		b.Parent = tabBar
		corner(b, UDim.new(0, 6))
		b.Activated:Connect(function()
			self.bagTab = spec.id
			self:RefreshTabs()
			if self.lastData then self:Render(self.lastData) end
		end)
		self.bagTabs[spec.id] = b
	end

	--------------------------------------------------------------------------
	-- Slot grid (right).
	--------------------------------------------------------------------------
	local grid = Instance.new("Frame")
	grid.Name = "Slots"
	-- Chrome above and below the grid is fixed pixels, which eats half of a short phone panel; trim it there
	-- so the square cells keep a usable size.
	local chromeTop = small and 46 or 62
	local chromeTotal = small and 74 or 110
	grid.Position = UDim2.new(0.3, 0, 0, chromeTop)
	grid.Size = UDim2.new(0.68, -18, 1, -chromeTotal)
	grid.BackgroundTransparency = 1
	grid.Parent = panel

	-- The grid box is pinned to the COLS:ROWS aspect, which is what keeps square cells fitting. Sizing cells
	-- off the WIDTH alone was fine at 4 rows (they could never be too tall) but overflows at 6: a 280x268 box
	-- gives 46.7px cells, and six of those plus padding need 310px. Constraining the box instead means the
	-- cells stay square AND the last row is always inside it, whatever shape the panel takes.
	local gridAspect = Instance.new("UIAspectRatioConstraint")
	gridAspect.AspectRatio = COLS / ROWS
	gridAspect.DominantAxis = Enum.DominantAxis.Height
	gridAspect.Parent = grid

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / COLS, -6, 1 / ROWS, -6)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for i = 1, COLS * ROWS do
		local slot = Instance.new("TextButton")
		slot.Name = "Slot" .. i
		slot.LayoutOrder = i
		slot.BackgroundColor3 = SLOT_BG
		slot.BackgroundTransparency = 0.25
		slot.Text = ""
		slot.AutoButtonColor = true
		slot.Parent = grid
		corner(slot, UDim.new(0, 8))
		local slotStroke = stroke(slot, GLASS, 0.85)

		-- Icon first, name as the fallback: an item with artwork hides its label, one without shows text.
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(1, -8, 1, -8)
		icon.Position = UDim2.new(0, 4, 0, 4)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Image = ""
		icon.Visible = false
		icon.Parent = slot

		local name = label(slot, "", 11, TEXT_LIGHT, Enum.TextXAlignment.Center)
		name.Size = UDim2.new(1, -6, 1, -18)
		name.Position = UDim2.new(0, 3, 0, 3)
		name.TextWrapped = true

		local count = label(slot, "", 11, ACCENT, Enum.TextXAlignment.Right)
		count.Size = UDim2.new(1, -6, 0, 14)
		count.Position = UDim2.new(0, 3, 1, -16)
		count.Font = Enum.Font.GothamBold

		-- แถบความคงทนชิดขอบล่างใต้รูป (ผู้ใช้สั่ง 2026-09-29) · Render ตั้งสี/ความยาว · ZIndex 3 = เหนือไอคอน (Global)
		local durBar = Instance.new("Frame")
		durBar.Name = "DurBar"
		durBar.Size = UDim2.new(1, -12, 0, 4)
		durBar.Position = UDim2.new(0, 6, 1, -6)
		durBar.BackgroundColor3 = DUR_TRACK
		durBar.BackgroundTransparency = 0.25
		durBar.BorderSizePixel = 0
		durBar.ZIndex = 3
		durBar.Visible = false
		durBar.Parent = slot
		corner(durBar, UDim.new(1, 0))
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BorderSizePixel = 0
		fill.ZIndex = 3
		fill.Parent = durBar
		corner(fill, UDim.new(1, 0))

		-- Dragging this slot out to the hotbar. Begun here and finished by the controller, which is the only
		-- part that knows where the hotbar is on screen. Mouse and touch arrive through the same events, so
		-- dragging works on a phone without a second implementation.
		slot.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				-- เลขช่องจริง ไม่ใช่เลขปุ่ม (แท็บอัดของชิดหน้า) — เดิมส่ง i แล้วลากได้ของผิดชิ้น (QA 2026-09-26)
				local index = self.slotIndex and self.slotIndex[i]
				if index and self.onDragStarted then self.onDragStarted(index, input) end
			end
		end)

		slot.Activated:Connect(function()
			-- **ส่งเลขช่องจริง ไม่ใช่เลขปุ่ม** แท็บอัดของมาชิดหน้า ปุ่มที่ i จึงเป็นช่องอื่น
			-- ช่องว่างในแท็บไม่มีของให้กด (slotIndex เป็น nil) จึงเงียบไปเฉยๆ
			local index = self.slotIndex and self.slotIndex[i]
			if not index then return end
			-- Bag slots click; the equipment slots above deliberately do not, since putting something on
			-- already has its own heavier sound and the two together sounded like a stutter.
			UiSound.Play("Click")
			if self.onSlotClicked then self.onSlotClicked(index) end
		end)

		self.slotButtons[i] = { button = slot, name = name, count = count, stroke = slotStroke, icon = icon, durBar = durBar }
	end

	--------------------------------------------------------------------------
	-- Footer: auto-sort.
	--------------------------------------------------------------------------
	local sort = Instance.new("TextButton")
	sort.Name = "AutoSortButton"
	sort.AnchorPoint = Vector2.new(0, 1)
	sort.Position = UDim2.new(0, 18, 1, -14)
	sort.Size = UDim2.new(0.26, 0, 0, 32)
	sort.BackgroundColor3 = ACCENT
	sort.BackgroundTransparency = 0.15
	sort.Font = Enum.Font.GothamBold
	sort.TextSize = 14
	sort.TextColor3 = Color3.fromRGB(30, 24, 10)
	sort.Text = "จัดกระเป๋า"
	sort.Parent = panel
	corner(sort, UDim.new(0, 8))
	self.sortButton = sort
	-- ตั้งป้ายครั้งแรกให้ตรงกับแท็บที่เปิดอยู่ (RefreshTabs ตัวก่อนหน้านี้ถูกเรียกก่อนปุ่มจะถูกสร้าง)
	self:RefreshTabs()

	local hint = label(panel, "แตะช่องเพื่อใช้ / สวมใส่", 11, TEXT_MUTED)
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0.3, 0, 1, -18)
	hint.Size = UDim2.new(0.3, 0, 0, 16) -- ครึ่งขวาของแถวนี้เป็นของป้ายน้ำหนัก

	-- On a phone the panel is already sized as a fraction of the viewport, so the width-driven scale would
	-- shrink it a second time; keep it near 1 there and let the layout do the adapting.
	Responsive.Scale(panel, small and 0.95 or 0.75)

	return self
end

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

-- ไฮไลต์แท็บที่เลือกอยู่
function InventoryGui:RefreshTabs()
	if not self.bagTabs then return end
	local label
	for id, button in pairs(self.bagTabs) do
		local on = (id == self.bagTab)
		-- ที่เลือก = ทองทึบ ตัวหนังสือเข้ม · ที่ไม่ได้เลือก = ใส ตัวหนังสือเทาอ่อนบนรางมืด (อ่านชัดทั้งคู่)
		button.BackgroundTransparency = on and 0 or 1
		button.TextColor3 = on and PANEL_BG or TEXT_MUTED
		if on then label = button.Text end
	end
	-- **ปุ่มบอกว่ากำลังจะจัดใบไหน** กระเป๋าสองใบแยกกันแล้ว ปุ่มที่เขียนแค่ "จัดกระเป๋า" ทำให้ไม่รู้ว่า
	-- ของอีกใบจะขยับด้วยหรือเปล่า — ซึ่งเป็นที่มาของความรู้สึก "ของหายไปรวมที่ไหนก็ไม่รู้"
	if self.sortButton and label then
		self.sortButton.Text = "จัด" .. label
	end
end

function InventoryGui:Render(data)
	-- เก็บไว้ให้ปุ่มแท็บวาดใหม่ได้โดยไม่ต้องรอข้อมูลรอบถัดไปจากเซิร์ฟเวอร์
	self.lastData = data
	self:RefreshTabs()
	self.goldLabel.Text = ("%d เหรียญ"):format(data.gold or 0)

	local weight = data.weight or 0
	local maxWeight = data.maxWeight or 1
	self.weightLabel.Text = ("น้ำหนัก %.1f / %d"):format(weight, maxWeight)
	-- Turn the readout red once the player is actually being slowed, so the penalty is never a mystery.
	self.weightLabel.TextColor3 = (weight > maxWeight) and Color3.fromRGB(224, 96, 84) or TEXT_MUTED

	-- **แท็บที่เลือกถูกอัดไปชิดหน้าเสมอ** (ผู้ใช้แจ้ง 2026-09-22: จัดกระเป๋าแล้วยังเห็นช่องว่าง)
	--
	-- ของแท็บ VIP อยู่ท้ายกระเป๋าจริงๆ (AutoSort เรียงของเกมหลักก่อน) ถ้าวาดตามเลขช่องตรงๆ แท็บ VIP
	-- จะขึ้นช่องว่างยาวเหยียดก่อนถึงของชิ้นแรก — ซึ่งดูเหมือนปุ่มจัดกระเป๋าไม่ทำงาน
	--
	-- ⚠️ **ปุ่มที่ i จึงไม่ใช่ช่องที่ i อีกต่อไป** `self.slotIndex[i]` เก็บเลขช่องจริงไว้ และทุกที่ที่
	-- อ้างถึงของ (คลิก / เมนูกดค้าง / ลากใส่แถบไอเทม) ต้องอ่านจากตารางนั้น ไม่ใช่จากเลขปุ่ม —
	-- เลขช่องคือชื่อเดียวที่เซิร์ฟเวอร์รู้จักของชิ้นหนึ่ง
	-- **เดินช่วงดัชนีของแท็บนั้นจริงๆ** ของ VIP อยู่ช่อง 37-72 ไม่ใช่ 1-36 — เดินแค่ `#slotButtons`
	-- จะมองไม่เห็นมันเลย (ช่องปุ่มมีน้อยกว่าเลขช่องจริง)
	local from, to = 1, InventoryConfig.SlotCount
	if self.bagTab == "farm" then
		from, to = InventoryConfig.VipSlotStart, InventoryConfig.VipSlotEnd
	end
	local view = {}
	for index = from, to do
		local slot = data.slots and data.slots[index]
		if slot then view[#view + 1] = { slot = slot, index = index } end
	end
	self.slotIndex = {}

	for i, entry in ipairs(self.slotButtons) do
		local shown = view[i]
		local slot = shown and shown.slot or nil
		self.slotIndex[i] = shown and shown.index or nil
		if slot then
			local item = ItemCatalog.Get(slot.id)
			local art = item and item.icon or ""
			-- ไม่มีรูปของตัวเอง = ⌛ เกาะขอบบนของช่อง แล้วชื่อยังขึ้นใต้มันเหมือนเดิม (ItemIcon)
			ItemIcon.Apply(entry.icon, art)
			-- ติดสกินอยู่ = รูปสกินเล็กๆ มุมล่างซ้าย (ผู้ใช้สั่ง 2026-09-28)
			ItemIcon.SetBadge(entry.icon, InventoryGui.SkinIconOf(slot.meta))
			-- 🍽️ อาหารที่ตั้งให้กินอัตโนมัติ (2026-10-02) · ชิ้นขอบทองไม่ถูกกิน (FindSlotById ข้าม) จึงไม่ติดป้าย
			ItemIcon.SetAutoEat(entry.icon, data.autoEat == slot.id and not ItemCatalog.IsGoldBorder(slot.meta))
			entry.icon.Visible = true
			-- The name only shows when there is no artwork, so an icon is never covered by its own label.
			entry.name.Text = (art == "") and ItemCatalog.DisplayName(slot.id, slot.meta) or ""
			-- A fish carries its own kilograms in `meta`, and it is never stacked, so the corner that would
			-- have read "x12" shows the size instead. Without this the weight would only ever be visible for
			-- the three seconds the card is up, and a prize catch would be indistinguishable in the bag.
			local kg = slot.meta and slot.meta.kg
			if kg then
				entry.count.Text = ("%.1f"):format(kg)
				entry.count.TextColor3 = FishingConfig.TierFor(kg).color
			else
				entry.count.Text = (slot.count or 1) > 1 and ("x%d"):format(slot.count) or ""
				entry.count.TextColor3 = ACCENT
			end
			entry.stroke.Color = kg and FishingConfig.TierFor(kg).color
				or (item and KIND_TINT[item.kind] or GLASS)
			entry.stroke.Transparency = 0.35
			entry.stroke.Thickness = 1
			-- ของขอบทอง (เฟส 2b): แสงวิ่งรอบกรอบ + พื้นเรืองทอง + ประกาย (addGoldFx) — ไม่มีตัวอักษรที่มุม
			if ItemCatalog.IsGoldBorder(slot.meta) then
				entry.stroke.Color = Color3.new(1, 1, 1) -- ขาว: สีจริงมาจากไล่สีที่วิ่งรอบกรอบ
				entry.stroke.Thickness = 2.5
				entry.stroke.Transparency = 0
				addGoldFx(entry)
			else
				removeGoldFx(entry)
			end
			setDurBar(entry.durBar, item, slot.durability)
		else
			entry.durBar.Visible = false
			entry.icon.Image = ""
			ItemIcon.SetBadge(entry.icon, nil)
			ItemIcon.SetAutoEat(entry.icon, false)
			entry.icon.Visible = false
			entry.icon.ImageTransparency = 0
			entry.name.Text = ""
			entry.name.TextTransparency = 0
			entry.count.Text = ""
			entry.count.TextTransparency = 0
			entry.stroke.Color = GLASS
			entry.stroke.Transparency = 0.85
			entry.stroke.Thickness = 1
			removeGoldFx(entry) -- ของขอบทองย้ายออก/ขายไปแล้ว ช่องว่างต้องไม่มีแสงค้าง
		end
	end

	for key, entry in pairs(self.equipSlots) do
		local worn = data.equipped and data.equipped[key]
		if worn then
			local item = ItemCatalog.Get(worn.id)
			entry.name.Text = item and item.name or worn.id
			entry.name.TextColor3 = TEXT_LIGHT
			local maxDurability = item and (item.maxDurability or item.armor)
			if maxDurability and worn.durability then
				entry.durability.Text = ("ความทนทาน %d/%d"):format(math.floor(worn.durability), maxDurability)
			else
				entry.durability.Text = ""
			end
			entry.stroke.Transparency = 0.3
			-- Show the artwork when there is any; an item with no icon keeps just its name, the way the bag
			-- slots do.
			local art = item and item.icon or ""
			ItemIcon.Apply(entry.icon, art)
			ItemIcon.SetBadge(entry.icon, InventoryGui.SkinIconOf(worn.meta))
			entry.icon.Visible = true
		else
			entry.name.Text = "ว่าง"
			entry.name.TextColor3 = TEXT_MUTED
			entry.durability.Text = ""
			entry.stroke.Transparency = 0.8
			entry.icon.Image = ""
			ItemIcon.SetBadge(entry.icon, nil)
			entry.icon.Visible = false
		end
	end
end

-- รูปของสกินที่ติดอยู่บนของชิ้นนี้ (`meta.skin` อาวุธ/ชุดแฟชั่นบนเกราะ) · nil = ไม่มีสกิน · "" = สกินยังไม่มีรูป (ItemIcon ขึ้น 🎨)
function InventoryGui.SkinIconOf(meta)
	local skinId = type(meta) == "table" and meta.skin
	if not skinId then return nil end
	local skin = ItemCatalog.Get(skinId)
	return skin and skin.icon or ""
end

function InventoryGui:OnSlotClicked(callback) self.onSlotClicked = callback end
function InventoryGui:OnDragStarted(callback) self.onDragStarted = callback end

-- The item picture that follows the finger or cursor during a drag. Parented to the bag's ScreenGui so it
-- draws above the grid, and destroyed the moment the drag ends.
function InventoryGui:BeginDragGhost(icon, name)
	self:EndDragGhost()
	local ghost = Instance.new("ImageLabel")
	ghost.Name = "DragGhost"
	ghost.Size = UDim2.fromOffset(48, 48)
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.BackgroundTransparency = 0.3
	ghost.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	ItemIcon.Apply(ghost, icon)
	ghost.ScaleType = Enum.ScaleType.Fit
	ghost.ZIndex = 50
	ghost.Parent = self.gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = ghost
	if (not icon or icon == "") and name then
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 10
		label.TextWrapped = true
		label.TextColor3 = Color3.fromRGB(226, 226, 232)
		label.Text = name
		label.ZIndex = 51
		label.Parent = ghost
	end
	self.dragGhost = ghost
	return ghost
end

function InventoryGui:MoveDragGhost(position)
	if self.dragGhost then
		self.dragGhost.Position = UDim2.fromOffset(position.X, position.Y)
	end
end

function InventoryGui:EndDragGhost()
	if self.dragGhost then
		self.dragGhost:Destroy()
		self.dragGhost = nil
	end
end
function InventoryGui:OnEquipSlotClicked(callback) self.onEquipSlotClicked = callback end
-- **ส่งแท็บที่เปิดอยู่ไปด้วย** ปุ่มจัดกระเป๋าควรจัด "กระเป๋าใบที่กำลังดูอยู่" ไม่ใช่ทั้งสองใบพร้อมกัน
-- (ผู้ใช้แจ้ง 2026-09-22: กดแล้วของอีกใบก็ขยับตามไปด้วย ทั้งที่มองไม่เห็น เลยดูเหมือนของหาย)
function InventoryGui:OnSortRequested(callback)
	self.sortButton.Activated:Connect(function()
		callback(self.bagTab)
	end)
end

-- แท็บที่เปิดอยู่ตอนนี้ ("main" | "farm")
function InventoryGui:CurrentTab() return self.bagTab end
function InventoryGui:OnCloseRequested(callback)
	self.closeButton.Activated:Connect(callback)
	-- The backdrop ignores any release that belongs to the tap which opened the panel. Without this a single
	-- mobile tap opened the bag on press (the BAG button fires on MouseButton1Down) and closed it again on
	-- release, so the panel appeared to do nothing at all.
	self.backdrop.Activated:Connect(function()
		if os.clock() < (self._ignoreBackdropUntil or 0) then return end
		callback()
	end)
end

-- Called by the controller when it opens the panel, so the opening tap's own release cannot close it.
function InventoryGui:GuardAgainstOpeningTap()
	self._ignoreBackdropUntil = os.clock() + 0.35
end

--------------------------------------------------------------------------------
-- The little menu beside a tapped item
--------------------------------------------------------------------------------

-- Built fresh each time rather than kept and re-filled: which entries it has depends on the item (only some
-- can be used) and on who is standing nearby, and rebuilding three buttons is cheaper than reasoning about
-- which of them should be visible this time.
--
-- `entries` is a list of { label, color?, onClick }. It closes on any choice, and on a tap elsewhere.
-- `title` names the item the menu belongs to: with three identically-worded menus on screen over a grid of
-- small icons, "ทิ้ง" alone does not say what is about to be destroyed.
function InventoryGui:ShowItemMenu(slotButton, entries, title)
	self:CloseItemMenu()
	if not slotButton or #entries == 0 then return end

	local menu = Instance.new("Frame")
	menu.Name = "ItemMenu"
	menu.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
	menu.BorderSizePixel = 0
	menu.ZIndex = 60
	-- The extra 26 is the close strip along the top; without it the X would sit over the first button. The
	-- title sits inside that same strip, to the left of the X, so naming the item costs no extra height.
	local CLOSE_STRIP = 26
	-- Wider than it was: an item name has to fit beside the close button without being cut to two letters.
	menu.Size = UDim2.fromOffset(168, #entries * 30 + 8 + CLOSE_STRIP)
	-- Beside the slot, not over it: the player needs to still see what they tapped.
	local p = slotButton.AbsolutePosition
	local sz = slotButton.AbsoluteSize
	menu.Position = UDim2.fromOffset(p.X + sz.X + 6, p.Y)
	menu.Parent = self.gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = menu
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(244, 197, 66)
	st.Transparency = 0.5
	st.Parent = menu

	-- A way out that is not a choice. Every entry in this menu DOES something -- one of them destroys the
	-- item -- so opening it by accident needed an exit that costs nothing.
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -4, 0, 4)
	close.Size = UDim2.fromOffset(20, 18)
	close.BackgroundColor3 = Color3.fromRGB(70, 74, 84)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBold
	close.TextSize = 13
	close.TextColor3 = Color3.fromRGB(232, 232, 238)
	close.Text = "\195\151" -- multiplication sign, the escape the bag close button uses
	close.ZIndex = 61
	close.AutoButtonColor = true
	close.Parent = menu
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 5)
	closeCorner.Parent = close
	close.Activated:Connect(function()
		self:CloseItemMenu()
	end)

	-- The item's name, filling the strip left of the X. Truncated with an ellipsis rather than wrapped: the
	-- strip is one line tall, and a wrapped name would push into the first button.
	if title then
		local heading = Instance.new("TextLabel")
		heading.Name = "Title"
		heading.Position = UDim2.fromOffset(8, 4)
		heading.Size = UDim2.new(1, -36, 0, 18)
		heading.BackgroundTransparency = 1
		heading.Font = Enum.Font.GothamBold
		heading.TextSize = 12
		heading.TextColor3 = Color3.fromRGB(244, 197, 66)
		heading.TextXAlignment = Enum.TextXAlignment.Left
		heading.TextTruncate = Enum.TextTruncate.AtEnd
		heading.Text = title
		heading.ZIndex = 61
		heading.Parent = menu
	end

	for i, entry in ipairs(entries) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, -8, 0, 26)
		b.Position = UDim2.new(0, 4, 0, 4 + CLOSE_STRIP + (i - 1) * 30)
		b.BackgroundColor3 = Color3.fromRGB(44, 46, 56)
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 13
		b.TextColor3 = entry.color or Color3.fromRGB(232, 232, 238)
		b.Text = entry.label
		b.ZIndex = 61
		b.AutoButtonColor = true
		b.Parent = menu
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 6)
		bc.Parent = b
		b.Activated:Connect(function()
			self:CloseItemMenu()
			entry.onClick()
		end)
	end

	-- Nudged back on screen if it would hang off the right or bottom edge.
	local viewport = self.gui.AbsoluteSize
	local over = (menu.AbsolutePosition.X + menu.AbsoluteSize.X) - viewport.X
	if over > 0 then
		menu.Position = UDim2.fromOffset(p.X - menu.AbsoluteSize.X - 6, p.Y)
	end
	local under = (menu.AbsolutePosition.Y + menu.AbsoluteSize.Y) - viewport.Y
	if under > 0 then
		menu.Position = UDim2.fromOffset(menu.Position.X.Offset, p.Y - under - 4)
	end

	self.itemMenu = menu
end

-- ถามจำนวนก่อนทำ สำหรับของที่มีหลายชิ้นในช่องเดียว
--
-- วางทับที่เดิมของเมนูและหน้าตาเหมือนกัน เพราะมันคือขั้นตอนถัดไปของ flow เดิม ("ให้ → ใคร → กี่ชิ้น")
-- ไม่ใช่หน้าต่างใหม่ที่โผล่มาจากที่อื่น
--
-- `onConfirm(count)` ถูกเรียกเมื่อกดตกลงเท่านั้น ปิดเมนูทิ้ง = ไม่มีอะไรเกิดขึ้น
function InventoryGui:ShowCountPrompt(slotButton, title, maxCount, onConfirm)
	self:CloseItemMenu()
	if not slotButton then return end

	local menu = Instance.new("Frame")
	menu.Name = "ItemMenu"
	menu.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
	menu.BorderSizePixel = 0
	menu.ZIndex = 60
	menu.Size = UDim2.fromOffset(168, 108)
	local p = slotButton.AbsolutePosition
	local sz = slotButton.AbsoluteSize
	menu.Position = UDim2.fromOffset(p.X + sz.X + 6, p.Y)
	menu.Parent = self.gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = menu
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(244, 197, 66)
	st.Transparency = 0.5
	st.Parent = menu
	self.itemMenu = menu

	local heading = Instance.new("TextLabel")
	heading.Position = UDim2.fromOffset(8, 4)
	heading.Size = UDim2.new(1, -36, 0, 18)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBold
	heading.TextSize = 12
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextTruncate = Enum.TextTruncate.AtEnd
	heading.TextColor3 = Color3.fromRGB(244, 197, 66)
	heading.Text = title or "กี่ชิ้น"
	heading.ZIndex = 61
	heading.Parent = menu

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -4, 0, 4)
	close.Size = UDim2.fromOffset(20, 18)
	close.BackgroundColor3 = Color3.fromRGB(70, 74, 84)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBold
	close.TextSize = 13
	close.TextColor3 = Color3.fromRGB(232, 232, 238)
	close.Text = "\195\151" -- multiplication sign, same escape the other menus use
	close.ZIndex = 61
	close.Parent = menu
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 5)
	cc.Parent = close
	close.Activated:Connect(function() self:CloseItemMenu() end)

	-- ขึ้นมาพร้อมจำนวนเต็มกองและเลือกข้อความไว้ให้แล้ว: ให้ทั้งกองคือสิ่งที่ทำบ่อยที่สุด กด Enter ทันทีก็จบ
	local box = Instance.new("TextBox")
	box.Position = UDim2.fromOffset(8, 28)
	box.Size = UDim2.new(1, -16, 0, 30)
	box.BackgroundColor3 = Color3.fromRGB(38, 40, 48)
	box.BorderSizePixel = 0
	box.Font = Enum.Font.GothamBold
	box.TextSize = 15
	box.TextColor3 = Color3.fromRGB(232, 232, 238)
	box.Text = tostring(maxCount)
	box.ClearTextOnFocus = false
	box.ZIndex = 61
	NumberBox.Bind(box, function() return maxCount end)
	box.Parent = menu
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 6)
	bc.Parent = box

	local hint = Instance.new("TextLabel")
	hint.Position = UDim2.fromOffset(8, 58)
	hint.Size = UDim2.new(1, -16, 0, 14)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 10
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = Color3.fromRGB(150, 152, 162)
	hint.Text = ("มีทั้งหมด %d ชิ้น"):format(maxCount)
	hint.ZIndex = 61
	hint.Parent = menu

	local confirm = Instance.new("TextButton")
	confirm.Position = UDim2.fromOffset(8, 74)
	confirm.Size = UDim2.new(1, -16, 0, 26)
	confirm.BackgroundColor3 = Color3.fromRGB(62, 96, 70)
	confirm.BorderSizePixel = 0
	confirm.Font = Enum.Font.GothamBold
	confirm.TextSize = 13
	confirm.TextColor3 = Color3.fromRGB(232, 232, 238)
	confirm.Text = "ตกลง"
	confirm.ZIndex = 61
	confirm.Parent = menu
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 6)
	fc.Parent = confirm

	-- หนีบให้อยู่ในช่วง 1..maxCount ที่นี่ด้วย ถึงเซิร์ฟเวอร์จะหนีบซ้ำอยู่แล้ว เพราะคนพิมพ์ควรเห็นทันทีว่า
	-- เลขที่ใส่ไปถูกปรับ ไม่ใช่กดตกลงแล้วได้จำนวนอื่นโดยไม่มีคำอธิบาย
	local function submit()
		local wanted = math.floor(tonumber(box.Text) or 0)
		if wanted < 1 then wanted = 1 end
		if wanted > maxCount then wanted = maxCount end
		self:CloseItemMenu()
		onConfirm(wanted)
	end
	confirm.Activated:Connect(submit)
	box.FocusLost:Connect(function(enter) if enter then submit() end end)
	box:CaptureFocus()
end

function InventoryGui:CloseItemMenu()
	if self.itemMenu then
		self.itemMenu:Destroy()
		self.itemMenu = nil
	end
end

-- The button for a bag slot, so the menu can be placed beside the right one.
--
-- ⚠️ **รับเลขช่องจริง ไม่ใช่เลขปุ่ม** แท็บอัดของมาชิดหน้า ช่องที่ 30 จึงอาจเป็นปุ่มที่ 2 —
-- ถ้าไล่หาจาก `slotButtons[index]` ตรงๆ เมนูกดค้างจะไปโผล่ข้างช่องอื่น (หรือหาไม่เจอแล้วไม่โผล่เลย)
function InventoryGui:SlotButton(index)
	if self.slotIndex then
		for i, real in pairs(self.slotIndex) do
			if real == index then
				local entry = self.slotButtons[i]
				return entry and entry.button or nil
			end
		end
		return nil -- ของชิ้นนั้นอยู่คนละแท็บ จึงไม่มีปุ่มบนจอให้แขวนเมนู
	end
	local entry = self.slotButtons and self.slotButtons[index]
	return entry and entry.button or nil
end

-- ปุ่มช่องสวม ("weapon" | "armor") ให้เมนูสกินแขวนได้เหมือนช่องกระเป๋า
function InventoryGui:EquipSlotButton(key)
	local entry = self.equipSlots and self.equipSlots[key]
	return entry and entry.button or nil
end

function InventoryGui:IsOpen() return self.gui.Enabled end
function InventoryGui:Show() self.gui.Enabled = true end
function InventoryGui:Hide()
	self:CloseItemMenu()
	self.gui.Enabled = false
end

return InventoryGui
