-- ArenaShopGui: ร้านในสนาม PVP — รื้อดีไซน์ใหม่ 2026-09-24 (ผู้ใช้สั่ง "ดูโมเดลสวยงามและทันสมัยขึ้น")
--
-- ตัววาดล้วน ไม่รู้จัก remote ไม่ตัดสินอะไร · ราคา/หมวดมาจาก `ArenaConfig.Shop` ตารางเดียวกับที่เซิร์ฟเวอร์ตัดเงิน
--
--   ┌ คลังอาวุธ ─────────────────────────── [◆ 2,300]  [x] ┐
--   │ อาวุธระยะใกล้   [การ์ด 3D][การ์ด][การ์ด]   │ ┌ รายละเอียด ┐ │
--   │ อาวุธระยะไกล   [การ์ด][การ์ด][การ์ด][การ์ด]  │ │ โมเดลหมุน   │ │
--   │ เกราะ          [การ์ด][การ์ด][การ์ด]        │ │ ชื่อ/ค่าพลัง │ │
--   │ ของใช้          [การ์ด][การ์ด][การ์ด][การ์ด]  │ │ [ ซื้อ ]    │ │
--   └──────────────────────────── เวลาที่เหลือ / สถานะ ─────┘
--
-- อาวุธโชว์เป็น **โมเดล 3D หมุน** (ViewportFrame โคลนจาก `ReplicatedStorage.WOLD_Weapons` ที่ WeaponPrefabs
-- สร้างตอนเซิร์ฟบูต) · เกราะกับของใช้ยังเป็นรูปไอคอน (โมเดลชุดเกราะอยู่ ServerStorage ไคลเอนต์มองไม่เห็น)
-- ⚠️ ปุ่มกากบาทวาดจาก Frame หมุน ไม่ใช่ตัวอักษร ✕ (ฟอนต์ Roblox วาดสัญลักษณ์หนาเป็นกล่องเปล่า)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaConfig = require(script.Parent.Parent.ArenaConfig)
local CombatConfig = require(script.Parent.Parent.CombatConfig)
local ItemCatalog = require(script.Parent.Parent.ItemCatalog)
local ItemIcon = require(script.Parent.ItemIcon)

local ArenaShopGui = {}
ArenaShopGui.__index = ArenaShopGui

local rgb = Color3.fromRGB
local BG = rgb(16, 17, 22)
local CARD = rgb(30, 32, 40)
local CARD_HOVER = rgb(40, 43, 54)
local STROKE = rgb(64, 68, 82)
local GOLD = rgb(232, 190, 90)
local TEXT = rgb(238, 236, 230)
local MUTED = rgb(150, 150, 160)
local RED = rgb(226, 110, 100)

local SECTIONS = {
	{ row = "melee", title = "อาวุธระยะใกล้" },
	{ row = "ranged", title = "อาวุธระยะไกล" },
	{ row = "armor", title = "เกราะ" },
	{ row = "use", title = "ของใช้" },
}

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = p
end
local function stroke(p, colour, t, thick)
	local s = Instance.new("UIStroke")
	s.Color, s.Transparency, s.Thickness = colour, t or 0, thick or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end
local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = props.font or Enum.Font.SourceSansBold
	l.TextSize = props.size or 16
	l.TextColor3 = props.colour or TEXT
	l.TextXAlignment = props.align or Enum.TextXAlignment.Left
	l.TextWrapped = props.wrap or false
	l.Text = props.text or ""
	l.Position = props.pos or UDim2.new()
	l.Size = props.dim or UDim2.fromScale(1, 1)
	l.ZIndex = props.z or 2
	l.Parent = parent
	return l
end
-- เหรียญซิลเวอร์: วงกลมวาดเอง ไม่พึ่งอีโมจิ
local function coin(parent, px, pos)
	local c = Instance.new("Frame")
	c.Size = UDim2.fromOffset(px, px)
	c.Position = pos
	c.AnchorPoint = Vector2.new(0, 0.5)
	c.BackgroundColor3 = rgb(200, 206, 216)
	c.ZIndex = 3
	c.Parent = parent
	corner(c, px)
	stroke(c, rgb(120, 126, 140), 0, 2)
	return c
end

local function damageOf(id)
	local override = ArenaConfig.CombatOverrides[id]
	if override and override.damage then return override.damage end
	local spec = CombatConfig.Weapons[id]
	local attack = spec and spec.attacks and spec.attacks[1]
	local item = ItemCatalog.Items[id]
	return (attack and attack.damage ~= 0 and attack.damage) or (item and item.damage)
end

-- บรรทัดค่าพลังของไอเทมหนึ่งชิ้น (โชว์ในแผงรายละเอียด)
local function statsOf(entry)
	local item = ItemCatalog.Items[entry.id] or {}
	local lines = {}
	if entry.slot == "weapon" then
		local dmg = damageOf(entry.id)
		if dmg then lines[#lines + 1] = ("ดาเมจต่อครั้ง  %d"):format(dmg) end
		if entry.ammo then lines[#lines + 1] = ("กระสุน  %d นัด (หมดแล้วต้องซื้อปืนใหม่)"):format(entry.ammo) end
	elseif entry.slot == "armor" then
		lines[#lines + 1] = ("เกราะ  %d"):format(item.armor or 0)
		lines[#lines + 1] = ("กันดาเมจ  %d%%"):format(math.floor((item.absorbFraction or 0) * 100 + 0.5))
	elseif entry.mana then
		lines[#lines + 1] = ("มานา +%d เม็ดทันที"):format(entry.mana)
		lines[#lines + 1] = ("ซื้อได้ %d ขวดต่อรอบ"):format(ArenaConfig.PerRound(entry))
	else
		local use = item.use or {}
		if use.stat == "hp" then lines[#lines + 1] = ("ฟื้นเลือด %d"):format(use.amount or 0)
		elseif use.stat == "healfull" then lines[#lines + 1] = "ฟื้นเลือดเต็มหลอด"
		elseif use.stat == "firstaid" then lines[#lines + 1] = ("พันแผล %d วิ · เลือดไม่ลด %d วิ"):format(use.holdSeconds or 0, use.seconds or 0) end
		lines[#lines + 1] = "กด F เพื่อใช้"
	end
	lines[#lines + 1] = entry.slot == "mana" and "" or "ซื้อทับ = ของเก่าหาย · ตายแล้วต้องซื้อใหม่"
	return lines
end

--------------------------------------------------------------------------------
-- พรีวิว: โมเดลหมุนใน ViewportFrame (อาวุธ) หรือไอคอน (อย่างอื่น)
--------------------------------------------------------------------------------
local function fitCamera(vpf, model)
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local cam = vpf.CurrentCamera or Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, radius * 0.25, radius / math.tan(math.rad(15)) * 1.05), cf.Position)
	cam.Parent = vpf
	vpf.CurrentCamera = cam
end

-- คืน ViewportFrame ที่มีโมเดลแล้ว หรือ nil ถ้าโมเดลยังไม่มา (WeaponPrefabs สร้างตอนเซิร์ฟบูต — ถามใหม่ทีหลังได้)
local function makeViewport(parent, id)
	local folder = ReplicatedStorage:FindFirstChild("WOLD_Weapons")
	local source = folder and folder:FindFirstChild(id)
	if not source then return nil end
	local vpf = Instance.new("ViewportFrame")
	vpf.BackgroundTransparency = 1
	vpf.Size = UDim2.fromScale(1, 1)
	vpf.Ambient = rgb(170, 170, 180)
	vpf.LightColor = rgb(255, 244, 220)
	vpf.LightDirection = Vector3.new(-1, -1, -1)
	vpf.ZIndex = 2
	vpf.Parent = parent
	local model = source:Clone()
	-- ตั้งตรง: อาวุธทุกชิ้นปลายอยู่ที่จุดกำเนิด ด้ามยื่น +Y · หมุนรอบแกนตั้งของตัวเอง
	local centre = model:GetBoundingBox().Position
	model:PivotTo(model:GetPivot() - centre)
	model.Parent = vpf
	fitCamera(vpf, model)
	return vpf, model
end

--------------------------------------------------------------------------------
function ArenaShopGui.new()
	local self = setmetatable({ cards = {}, spinners = {}, snap = nil }, ArenaShopGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "ArenaShopGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 18
	gui.Enabled = false
	self.gui = gui

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = rgb(0, 0, 0)
	dim.BackgroundTransparency = 0.5
	dim.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(1000, 690)
	panel.BackgroundColor3 = BG
	panel.BackgroundTransparency = 0.04
	panel.Parent = gui
	corner(panel, 18)
	stroke(panel, GOLD, 0.7, 1.5)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(rgb(255, 255, 255), rgb(190, 190, 200))
	grad.Parent = panel
	-- ย่อตามจอ (มือถือ/จอเล็ก) — ไม่เกินขนาดจริง
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function rescale()
		local cam = workspace.CurrentCamera
		local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(v.X / 1060, v.Y / 740), 0.5, 1)
	end
	rescale()
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end
	self.panel = panel

	-- หัว
	label(panel, { text = "คลังอาวุธ", font = Enum.Font.GothamBold, size = 28, pos = UDim2.fromOffset(28, 16), dim = UDim2.fromOffset(300, 34) })
	self.subtitle = label(panel, { text = "", size = 16, colour = MUTED, pos = UDim2.fromOffset(28, 50), dim = UDim2.fromOffset(560, 20) })

	local wallet = Instance.new("Frame")
	wallet.AnchorPoint = Vector2.new(1, 0)
	wallet.Position = UDim2.new(1, -76, 0, 20)
	wallet.Size = UDim2.fromOffset(170, 42)
	wallet.BackgroundColor3 = rgb(34, 36, 46)
	wallet.Parent = panel
	corner(wallet, 21)
	stroke(wallet, STROKE, 0, 1)
	coin(wallet, 20, UDim2.new(0, 14, 0.5, 0))
	self.silverLabel = label(wallet, { text = "0", font = Enum.Font.GothamBold, size = 20, align = Enum.TextXAlignment.Right,
		pos = UDim2.fromOffset(40, 0), dim = UDim2.new(1, -56, 1, 0) })

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -20, 0, 20)
	close.Size = UDim2.fromOffset(42, 42)
	close.BackgroundColor3 = rgb(34, 36, 46)
	close.Text = ""
	close.Parent = panel
	corner(close, 21)
	for _, angle in ipairs({ 45, -45 }) do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromOffset(18, 3)
		bar.Rotation = angle
		bar.BackgroundColor3 = TEXT
		bar.BorderSizePixel = 0
		bar.Parent = close
	end
	self.closeButton = close

	-- รายการการ์ด (ซ้าย)
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(24, 84)
	list.Size = UDim2.fromOffset(640, 590)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = STROKE
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for order, section in ipairs(SECTIONS) do
		label(list, { text = section.title, font = Enum.Font.GothamBold, size = 15, colour = GOLD, dim = UDim2.new(1, 0, 0, 20) }).LayoutOrder = order * 2 - 1
		local row = Instance.new("Frame")
		row.LayoutOrder = order * 2
		row.Size = UDim2.new(1, -8, 0, 132)
		row.BackgroundTransparency = 1
		row.Parent = list
		local grid = Instance.new("UIListLayout")
		grid.FillDirection = Enum.FillDirection.Horizontal
		grid.Padding = UDim.new(0, 10)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = row

		for _, entry in ipairs(ArenaConfig.Shop) do
			if entry.row == section.row then
				self:_card(row, entry)
			end
		end
	end

	-- แผงรายละเอียด (ขวา)
	local detail = Instance.new("Frame")
	detail.Position = UDim2.fromOffset(680, 84)
	detail.Size = UDim2.fromOffset(296, 586)
	detail.BackgroundColor3 = rgb(24, 26, 33)
	detail.Parent = panel
	corner(detail, 14)
	stroke(detail, STROKE, 0.3, 1)
	self.detail = detail

	local stage = Instance.new("Frame")
	stage.Position = UDim2.fromOffset(12, 12)
	stage.Size = UDim2.fromOffset(272, 260)
	stage.BackgroundColor3 = rgb(34, 37, 48)
	stage.ClipsDescendants = true
	stage.Parent = detail
	corner(stage, 12)
	local glow = Instance.new("UIGradient")
	glow.Rotation = 90
	glow.Color = ColorSequence.new(rgb(70, 64, 48), rgb(28, 30, 38))
	glow.Parent = stage
	self.stage = stage

	self.detailName = label(detail, { text = "เลือกไอเทม", font = Enum.Font.GothamBold, size = 22, pos = UDim2.fromOffset(16, 284), dim = UDim2.fromOffset(264, 28) })
	self.detailKind = label(detail, { text = "ชี้ที่การ์ดเพื่อดูรายละเอียด", size = 15, colour = MUTED, pos = UDim2.fromOffset(16, 314), dim = UDim2.fromOffset(264, 20) })
	self.detailStats = label(detail, { text = "", size = 16, colour = TEXT, wrap = true, pos = UDim2.fromOffset(16, 346), dim = UDim2.fromOffset(264, 150) })
	self.detailStats.TextYAlignment = Enum.TextYAlignment.Top
	self.detailStats.LineHeight = 1.15

	local buy = Instance.new("TextButton")
	buy.AnchorPoint = Vector2.new(0.5, 1)
	buy.Position = UDim2.new(0.5, 0, 1, -14)
	buy.Size = UDim2.new(1, -28, 0, 50)
	buy.BackgroundColor3 = GOLD
	buy.Font = Enum.Font.GothamBold
	buy.TextSize = 20
	buy.TextColor3 = rgb(28, 24, 16)
	buy.Text = "ซื้อ"
	buy.AutoButtonColor = true
	buy.Parent = detail
	corner(buy, 12)
	buy.MouseButton1Click:Connect(function()
		if self.selected and self.onBuy then self.onBuy(self.selected) end
	end)
	self.buyButton = buy

	-- หมุนโมเดลเฉพาะตอนเปิดร้าน
	RunService.RenderStepped:Connect(function(dt)
		if not gui.Enabled then return end
		for _, s in ipairs(self.spinners) do
			if s.model.Parent then s.model:PivotTo(s.model:GetPivot() * CFrame.Angles(0, dt * 0.9, 0)) end
		end
	end)
	return self
end

function ArenaShopGui:_card(parent, entry)
	local item = ItemCatalog.Items[entry.id] or {}
	local card = Instance.new("TextButton")
	card.Name = entry.id
	card.Size = UDim2.fromOffset(142, 132)
	card.BackgroundColor3 = CARD
	card.AutoButtonColor = false
	card.Text = ""
	card.Parent = parent
	corner(card, 12)
	local outline = stroke(card, STROKE, 0, 1.5)

	local art = Instance.new("Frame")
	art.Position = UDim2.fromOffset(8, 8)
	art.Size = UDim2.fromOffset(126, 74)
	art.BackgroundColor3 = rgb(38, 41, 52)
	art.ClipsDescendants = true
	art.Parent = card
	corner(art, 9)

	local icon = Instance.new("ImageLabel")
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(62, 62)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 2
	icon.Parent = art
	ItemIcon.Apply(icon, item.icon)

	label(card, { text = item.name or entry.id, size = 17, pos = UDim2.fromOffset(10, 84), dim = UDim2.fromOffset(122, 22) })

	local pricePill = Instance.new("Frame")
	pricePill.Position = UDim2.fromOffset(10, 106)
	pricePill.Size = UDim2.fromOffset(122, 22)
	pricePill.BackgroundTransparency = 1
	pricePill.Parent = card
	coin(pricePill, 14, UDim2.new(0, 0, 0.5, 0))
	local price = label(pricePill, { text = tostring(entry.price), font = Enum.Font.GothamBold, size = 15, colour = GOLD,
		pos = UDim2.fromOffset(20, 0), dim = UDim2.new(1, -20, 1, 0) })

	-- ป้ายมุมบน: "ติดตัว" (ทอง) / "ซื้อแล้ว" / "เงินไม่พอ"
	local badge = Instance.new("TextLabel")
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -12, 0, 12)
	badge.Size = UDim2.fromOffset(62, 20)
	badge.BackgroundColor3 = GOLD
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 12
	badge.TextColor3 = rgb(28, 24, 16)
	badge.Visible = false
	badge.ZIndex = 4
	badge.Parent = card
	corner(badge, 10)

	local row = { card = card, art = art, icon = icon, price = price, badge = badge, outline = outline, entry = entry }
	self.cards[entry.id] = row

	card.MouseEnter:Connect(function()
		card.BackgroundColor3 = CARD_HOVER
		self:_select(entry.id)
	end)
	card.MouseLeave:Connect(function() card.BackgroundColor3 = CARD end)
	card.MouseButton1Click:Connect(function()
		self:_select(entry.id)
		if self.onBuy then self.onBuy(entry.id) end
	end)
end

-- อาวุธ: เปลี่ยนไอคอนเป็นโมเดล 3D ถ้าโมเดลมาถึงแล้ว (ถามซ้ำได้ทุกครั้งที่วาด จนกว่าจะได้)
function ArenaShopGui:_ensureModels()
	for id, row in pairs(self.cards) do
		if row.entry.slot == "weapon" and not row.model then
			local vpf, model = makeViewport(row.art, id)
			if vpf then
				row.model = model
				row.icon.Visible = false
				table.insert(self.spinners, { model = model })
			end
		end
	end
end

function ArenaShopGui:_select(id)
	local row = self.cards[id]
	if not row then return end
	self.selected = id
	local entry = row.entry
	local item = ItemCatalog.Items[id] or {}
	self.detailName.Text = item.name or id
	self.detailKind.Text = ArenaConfig.SlotLabel[entry.slot] or ""
	self.detailStats.Text = table.concat(statsOf(entry), "\n")

	for _, child in ipairs(self.stage:GetChildren()) do
		if child:IsA("ViewportFrame") or child:IsA("ImageLabel") then child:Destroy() end
	end
	for i = #self.spinners, 1, -1 do
		if self.spinners[i].big then table.remove(self.spinners, i) end
	end
	local vpf, model = entry.slot == "weapon" and makeViewport(self.stage, id)
	if vpf then
		table.insert(self.spinners, { model = model, big = true })
	else
		local img = Instance.new("ImageLabel")
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromOffset(150, 150)
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Fit
		img.ZIndex = 2
		img.Parent = self.stage
		ItemIcon.Apply(img, item.icon)
	end
	if self.snap then self:Render(self.snap) end
end

function ArenaShopGui:OnBuy(callback) self.onBuy = callback end
function ArenaShopGui:OnClose(callback) self.closeButton.MouseButton1Click:Connect(callback) end
function ArenaShopGui:SetVisible(visible) self.gui.Enabled = visible and true or false end
function ArenaShopGui:IsVisible() return self.gui.Enabled end

-- `snap` = ภาพแมตช์จากเซิร์ฟเวอร์ — ใช้ silver, loadout, bought, phase, secondsLeft, canShop
function ArenaShopGui:Render(snap)
	self.snap = snap
	self:_ensureModels()
	local silver = snap.silver or 0
	self.silverLabel.Text = tostring(silver)
	local secs = snap.secondsLeft or 0
	if snap.phase == "buy" then
		self.subtitle.Text = ("เตรียมตัว — ร้านปิดใน %d:%02d · ซื้อได้ช่องละ 1 ชิ้นต่อรอบ"):format(math.floor(secs / 60), secs % 60)
	else
		self.subtitle.Text = "อยู่ในฐาน — ซื้อได้ (ออกจากฐานแล้วร้านปิด)"
	end

	local function stateOf(entry)
		local count = (snap.bought and snap.bought[entry.slot]) or 0
		local limit = ArenaConfig.PerRound(entry)
		local owned = snap.loadout and snap.loadout[entry.slot] == entry.id
		return owned, count, limit, count >= limit, silver >= entry.price
	end

	for _, row in pairs(self.cards) do
		local entry = row.entry
		local owned, count, limit, used, afford = stateOf(entry)
		row.price.Text = limit > 1 and ("%d  ·  %d/%d"):format(entry.price, count, limit) or tostring(entry.price)
		row.price.TextColor3 = afford and GOLD or RED
		row.outline.Color = owned and GOLD or STROKE
		row.outline.Thickness = owned and 2.5 or 1.5
		row.badge.Visible = owned or used or not afford
		if owned then
			row.badge.Text, row.badge.BackgroundColor3 = "ติดตัว", GOLD
		elseif used then
			row.badge.Text, row.badge.BackgroundColor3 = "ครบแล้ว", rgb(90, 92, 104)
		else
			row.badge.Text, row.badge.BackgroundColor3 = "เงินไม่พอ", rgb(120, 58, 54)
		end
		local dimmed = used or not afford
		row.card.AutoButtonColor = not dimmed
		ItemIcon.SetFade(row.icon, dimmed and 0.5 or 0)
		row.art.BackgroundTransparency = dimmed and 0.5 or 0
	end

	-- ปุ่มซื้อในแผงรายละเอียด
	local row = self.selected and self.cards[self.selected]
	if not row then
		self.buyButton.Text, self.buyButton.BackgroundColor3 = "ชี้ที่การ์ดเพื่อเลือก", rgb(60, 62, 72)
		return
	end
	local owned, _, _, used, afford = stateOf(row.entry)
	if used then
		self.buyButton.Text, self.buyButton.BackgroundColor3 = "รอบนี้ซื้อครบแล้ว", rgb(60, 62, 72)
	elseif not afford then
		self.buyButton.Text, self.buyButton.BackgroundColor3 = "ซิลเวอร์ไม่พอ", rgb(120, 58, 54)
	else
		self.buyButton.Text = (owned and "ซื้อซ้ำ  —  %d" or "ซื้อ  —  %d"):format(row.entry.price)
		self.buyButton.BackgroundColor3 = GOLD
	end
end

return ArenaShopGui
