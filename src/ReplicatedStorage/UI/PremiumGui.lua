-- PremiumGui: หน้ารวม ร้านค้าพรีเมียม / กาชา / แบทเทิลพาส — ตัววาดล้วน รายงานการกดผ่าน callback
--
-- ราคา สระกาชา และตารางรางวัลอ่านจาก PremiumConfig โดยตรง (ไคลเอนต์อ่านได้) ส่วนที่ต้องมาจากเซิร์ฟเวอร์คือ
-- เพชรที่มี สถานะพาส และผลสุ่ม — `Render(data)` รับก้อนนั้น
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)
local PremiumConfig = require(script.Parent.Parent.PremiumConfig)
local ItemCatalog = require(script.Parent.Parent.ItemCatalog)
local ItemIcon = require(script.Parent.ItemIcon)

local STONE = Color3.fromRGB(30, 32, 40)
local PANEL = Color3.fromRGB(38, 40, 48)
local ROW = Color3.fromRGB(46, 49, 60)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local GEM = Color3.fromRGB(110, 200, 255)
local RUNE = Color3.fromRGB(244, 197, 66)
local GREEN = Color3.fromRGB(78, 122, 64)
local GREY = Color3.fromRGB(70, 74, 84)

local PremiumGui = {}
PremiumGui.__index = PremiumGui

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

local function label(parent, text, size, colour, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = size or 13
	l.TextColor3 = colour or TEXT_LIGHT
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Parent = parent
	return l
end

local function button(parent, text, colour, onClick)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = colour
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = TEXT_LIGHT
	b.Text = text
	b.Parent = parent
	corner(b, UDim.new(0, 6))
	b.Activated:Connect(function()
		UiSound.Play("Click")
		onClick()
	end)
	return b
end

local function scrollList(parent, padding)
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = RUNE
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, padding or 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return list
end

local function clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if not c:IsA("UIListLayout") then c:Destroy() end
	end
end

local function rarityColour(rarity)
	local r = PremiumConfig.Rarity[rarity or "common"]
	return r and r.colour or TEXT_MUTED
end

--------------------------------------------------------------------------------
-- โครง
--------------------------------------------------------------------------------

function PremiumGui.new()
	local self = setmetatable({}, PremiumGui)
	self.callbacks = {}
	self.data = { gems = 0 }
	self.tab = "shop"

	local gui = Instance.new("ScreenGui")
	gui.Name = "PremiumGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 22
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	-- ฉากหลังก่อน panel เสมอ (ZIndexBehavior แบบ Sibling ตัดสินการรับคลิกจากลำดับลูก)
	local backdrop = Instance.new("TextButton")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.Parent = gui
	backdrop.Activated:Connect(function() self:Hide() end)

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = Responsive.IsSmallScreen() and UDim2.fromScale(0.96, 0.9) or UDim2.fromOffset(700, 520)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 12))
	Responsive.Scale(panel)
	self.panel = panel

	-- หัว: ชื่อแท็บ + เพชร + ปิด
	self.title = label(panel, "ร้านค้าพรีเมียม", 17, RUNE)
	self.title.Position = UDim2.new(0, 16, 0, 10)
	self.title.Size = UDim2.new(0.5, 0, 0, 24)

	self.gems = label(panel, "💎 0", 15, GEM, Enum.TextXAlignment.Right)
	self.gems.AnchorPoint = Vector2.new(1, 0)
	self.gems.Position = UDim2.new(1, -52, 0, 12)
	self.gems.Size = UDim2.new(0, 160, 0, 22)

	local close = button(panel, "\195\151", Color3.fromRGB(96, 62, 62), function() self:Hide() end)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Size = UDim2.fromOffset(30, 30)
	close.TextSize = 15

	-- แท็บ
	local tabs = Instance.new("Frame")
	tabs.Position = UDim2.new(0, 12, 0, 44)
	tabs.Size = UDim2.new(1, -24, 0, 30)
	tabs.BackgroundTransparency = 1
	tabs.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.Parent = tabs
	self.tabButtons = {}
	for _, t in ipairs({ { id = "shop", text = "💎 ร้านค้า" }, { id = "gacha", text = "🎰 กาชา" }, { id = "pass", text = "🎫 แบทเทิลพาส" } }) do
		local b = button(tabs, t.text, GREY, function() self:SetTab(t.id) end)
		b.Size = UDim2.new(0, 150, 1, 0)
		self.tabButtons[t.id] = b
	end

	-- เนื้อหา
	local body = Instance.new("Frame")
	body.Position = UDim2.new(0, 12, 0, 82)
	body.Size = UDim2.new(1, -24, 1, -94)
	body.BackgroundTransparency = 1
	body.Parent = panel
	self.body = body

	return self
end

function PremiumGui:On(name, fn) self.callbacks[name] = fn end
function PremiumGui:fire(name, ...)
	local fn = self.callbacks[name]
	if fn then fn(...) end
end

function PremiumGui:SetTab(tab)
	self.tab = tab
	for id, b in pairs(self.tabButtons) do
		b.BackgroundColor3 = id == tab and RUNE or GREY
		b.TextColor3 = id == tab and Color3.fromRGB(38, 28, 16) or TEXT_LIGHT
	end
	self.title.Text = tab == "shop" and "ร้านค้าพรีเมียม" or tab == "gacha" and "กาชา" or PremiumConfig.Pass.name
	self:Render(self.data)
end

--------------------------------------------------------------------------------
-- ร้านค้า
--------------------------------------------------------------------------------

function PremiumGui:renderShop()
	local list = scrollList(self.body)
	local gems = self.data.gems or 0

	-- แพ็กเพชร (โรบัค) — ปิดจนกว่าจะเปิดขาย
	local head = label(list, self.data.robuxEnabled and "ซื้อเพชร" or "ซื้อเพชรด้วยโรบัค — ยังไม่เปิด (ตอนนี้แอดมินแจกให้เทส)", 12, TEXT_MUTED)
	head.LayoutOrder = 0
	head.Size = UDim2.new(1, 0, 0, 18)
	local packs = Instance.new("Frame")
	packs.LayoutOrder = 1
	packs.Size = UDim2.new(1, -6, 0, 54)
	packs.BackgroundTransparency = 1
	packs.Parent = list
	local packLayout = Instance.new("UIListLayout")
	packLayout.FillDirection = Enum.FillDirection.Horizontal
	packLayout.Padding = UDim.new(0, 6)
	packLayout.Parent = packs
	for i, pack in ipairs(PremiumConfig.GemPacks) do
		local enabled = self.data.robuxEnabled and pack.productId ~= nil
		local b = button(packs, ("💎 %d\nR$ %d"):format(pack.gems, pack.robux), enabled and Color3.fromRGB(60, 110, 160) or GREY, function()
			if enabled then self:fire("buygems", i) end
		end)
		b.Size = UDim2.new(0.25, -5, 1, 0)
		b.TextSize = 11
		if not enabled then b.TextColor3 = TEXT_MUTED end
	end

	-- VIP — ผู้ใช้สั่งให้ขายด้วยเพชรในหน้านี้ (2026-09-20) วางไว้เหนือของในร้าน เพราะมันไม่ใช่ไอเทม
	-- แต่เป็นสิทธิ์ที่มีวันหมดอายุ และเป็นกุญแจของทั้งโหมดฟาร์มมิ่ง
	do
		local vip = PremiumConfig.Vip
		local left = self.data.vipLeft or 0
		local days = math.floor(left / 86400 + 0.5)
		local frame = Instance.new("Frame")
		frame.LayoutOrder = 5
		frame.Size = UDim2.new(1, -6, 0, 54)
		frame.BackgroundColor3 = ROW
		frame.BorderSizePixel = 0
		frame.Parent = list
		corner(frame, UDim.new(0, 8))
		-- ขอบทองตอนเป็น VIP อยู่: ของที่จ่ายเงินไปแล้วต้องเห็นได้ทันทีว่ายังใช้ได้อยู่
		if left > 0 then
			local edge = Instance.new("UIStroke")
			edge.Color = RUNE
			edge.Transparency = 0.35
			edge.Thickness = 1
			edge.Parent = frame
		end

		local crown = label(frame, "👑", 22)
		crown.Position = UDim2.new(0, 12, 0.5, -16)
		crown.Size = UDim2.fromOffset(34, 32)

		local name = label(frame, ("%s — %d วัน"):format(vip.name, vip.days), 13, left > 0 and RUNE or nil)
		name.Position = UDim2.new(0, 56, 0, 6)
		name.Size = UDim2.new(1, -190, 0, 18)

		local blurb = label(frame,
			left > 0 and ("เหลืออีก %d วัน · ซื้อซ้ำ = ต่ออายุทบจากของเดิม"):format(days) or vip.blurb,
			11, TEXT_MUTED)
		blurb.Position = UDim2.new(0, 56, 0, 26)
		blurb.Size = UDim2.new(1, -190, 0, 22)

		local afford = gems >= vip.price
		local buy = button(frame, ("💎 %d"):format(vip.price), afford and GREEN or GREY, function()
			self:fire("buyvip")
		end)
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -8, 0.5, 0)
		buy.Size = UDim2.fromOffset(110, 32)
	end

	for order, row in ipairs(PremiumConfig.Shop) do
		local item = ItemCatalog.Get(row.item)
		local frame = Instance.new("Frame")
		frame.LayoutOrder = 10 + order
		frame.Size = UDim2.new(1, -6, 0, 54)
		frame.BackgroundColor3 = ROW
		frame.BorderSizePixel = 0
		frame.Parent = list
		corner(frame, UDim.new(0, 8))

		do
			-- ช่องรูปมีเสมอ ของที่ยังไม่มีรูปของตัวเอง (สกิน ออร่า ชุดแฟชั่น) ได้ ⌛ แทน — ซึ่งคือเกือบทั้งร้านนี้
			local art = Instance.new("ImageLabel")
			art.Position = UDim2.new(0, 8, 0.5, -20)
			art.Size = UDim2.fromOffset(40, 40)
			art.BackgroundTransparency = 1
			ItemIcon.Apply(art, row.icon or (item and item.icon))
			art.ScaleType = Enum.ScaleType.Fit
			art.Parent = frame
		end

		-- แถวที่ไม่ใช่ไอเทม (เงินในเกม) ไม่มีชื่อให้หยิบจากแคตตาล็อก จึงพกชื่อ/รูปมาเองในคอนฟิก
		local title = row.name
			or ("%s%s"):format(item and item.name or row.item, (row.count or 1) > 1 and (" x" .. row.count) or "")
		local name = label(frame, title, 13)
		name.Position = UDim2.new(0, 56, 0, 6)
		name.Size = UDim2.new(1, -190, 0, 18)
		local blurb = label(frame, row.blurb or "", 11, TEXT_MUTED)
		blurb.Position = UDim2.new(0, 56, 0, 26)
		blurb.Size = UDim2.new(1, -190, 0, 22)

		local afford = gems >= row.price
		local buy = button(frame, ("💎 %d"):format(row.price), afford and GREEN or GREY, function()
			self:fire("buy", row.id)
		end)
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -8, 0.5, 0)
		buy.Size = UDim2.fromOffset(110, 32)
	end
end

--------------------------------------------------------------------------------
-- กาชา
--------------------------------------------------------------------------------

function PremiumGui:renderGacha()
	local list = scrollList(self.body, 8)
	local gems = self.data.gems or 0

	for order, banner in ipairs(PremiumConfig.Gacha) do
		local frame = Instance.new("Frame")
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, -6, 0, 96)
		frame.BackgroundColor3 = ROW
		frame.BorderSizePixel = 0
		frame.Parent = list
		corner(frame, UDim.new(0, 8))

		local name = label(frame, ("%s %s"):format(banner.icon or "", banner.name), 15, RUNE)
		name.Position = UDim2.new(0, 12, 0, 8)
		name.Size = UDim2.new(1, -24, 0, 20)
		local blurb = label(frame, banner.blurb or "", 11, TEXT_MUTED)
		blurb.Position = UDim2.new(0, 12, 0, 28)
		blurb.Size = UDim2.new(1, -240, 0, 30)

		-- ของในตู้ เรียงตามความหายาก
		local names = {}
		for _, id in ipairs(banner.pool) do
			local item = ItemCatalog.Get(id)
			if item then names[#names + 1] = item.name end
		end
		local pool = label(frame, #names > 0 and table.concat(names, " · ") or "เร็วๆ นี้", 10, TEXT_MUTED)
		pool.Position = UDim2.new(0, 12, 0, 60)
		pool.Size = UDim2.new(1, -240, 0, 30)
		pool.TextTruncate = Enum.TextTruncate.AtEnd

		local open = #banner.pool > 0
		local one = button(frame, open and ("สุ่ม 1  💎 %d"):format(banner.cost) or "เร็วๆ นี้", (open and gems >= banner.cost) and GREEN or GREY, function()
			if open then self:fire("pull", banner.id, 1) end
		end)
		one.AnchorPoint = Vector2.new(1, 0)
		one.Position = UDim2.new(1, -8, 0, 12)
		one.Size = UDim2.fromOffset(200, 32)
		local ten = button(frame, open and ("สุ่ม 10  💎 %d"):format(banner.cost10) or "เร็วๆ นี้", (open and gems >= banner.cost10) and Color3.fromRGB(150, 110, 40) or GREY, function()
			if open then self:fire("pull", banner.id, 10) end
		end)
		ten.AnchorPoint = Vector2.new(1, 0)
		ten.Position = UDim2.new(1, -8, 0, 52)
		ten.Size = UDim2.fromOffset(200, 32)
	end
end

-- ผลสุ่ม: หน้าต่างซ้อน รายการชิ้นที่ได้พร้อมสีตามความหายาก
function PremiumGui:ShowResults(results)
	local overlay = Instance.new("TextButton")
	overlay.Name = "GachaResults"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.Text = ""
	overlay.ZIndex = 5
	overlay.Parent = self.panel

	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.new(0.8, 0, 0, 90 + math.ceil(#results / 5) * 96)
	box.BackgroundColor3 = PANEL
	box.BorderSizePixel = 0
	box.ZIndex = 6
	box.Parent = overlay
	corner(box, UDim.new(0, 10))

	local head = label(box, "ได้รับ!", 18, RUNE, Enum.TextXAlignment.Center)
	head.Position = UDim2.new(0, 0, 0, 10)
	head.Size = UDim2.new(1, 0, 0, 26)
	head.ZIndex = 7

	local grid = Instance.new("Frame")
	grid.Position = UDim2.new(0, 12, 0, 44)
	grid.Size = UDim2.new(1, -24, 1, -90)
	grid.BackgroundTransparency = 1
	grid.ZIndex = 7
	grid.Parent = box
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.new(0.2, -6, 0, 90)
	gl.CellPadding = UDim2.new(0, 6, 0, 6)
	gl.Parent = grid

	for order, r in ipairs(results) do
		local card = Instance.new("Frame")
		card.LayoutOrder = order
		card.BackgroundColor3 = ROW
		card.BorderSizePixel = 0
		card.ZIndex = 8
		card.Parent = grid
		corner(card, UDim.new(0, 8))
		local stroke = Instance.new("UIStroke")
		stroke.Color = rarityColour(r.rarity)
		stroke.Thickness = 2
		stroke.Parent = card
		do
			local art = Instance.new("ImageLabel")
			art.AnchorPoint = Vector2.new(0.5, 0)
			art.Position = UDim2.new(0.5, 0, 0, 6)
			art.Size = UDim2.fromOffset(44, 44)
			art.BackgroundTransparency = 1
			art.ZIndex = 9
			ItemIcon.Apply(art, r.icon)
			art.ScaleType = Enum.ScaleType.Fit
			art.Parent = card
		end
		local n = label(card, r.name, 10, rarityColour(r.rarity), Enum.TextXAlignment.Center)
		n.Position = UDim2.new(0, 2, 0, 52)
		n.Size = UDim2.new(1, -4, 0, 34)
		n.ZIndex = 9
	end

	local ok = button(box, "ตกลง", GREEN, function() overlay:Destroy() end)
	ok.AnchorPoint = Vector2.new(0.5, 1)
	ok.Position = UDim2.new(0.5, 0, 1, -10)
	ok.Size = UDim2.fromOffset(120, 30)
	ok.ZIndex = 7
	overlay.Activated:Connect(function() overlay:Destroy() end)
end

--------------------------------------------------------------------------------
-- แบทเทิลพาส
--------------------------------------------------------------------------------

local function rewardText(reward)
	if not reward then return "—" end
	if reward.gold then return ("เงิน %d"):format(reward.gold) end
	if reward.gems then return ("💎 %d"):format(reward.gems) end
	local item = ItemCatalog.Get(reward.item)
	return ("%s x%d"):format(item and item.name or reward.item, reward.count or 1)
end

function PremiumGui:renderPass()
	local pass = self.data.pass or { xp = 0, tier = 0, premium = false, claimedFree = {}, claimedPremium = {} }
	local cfg = PremiumConfig.Pass

	-- แถบความคืบหน้า + ปุ่มปลดพรีเมียม
	local top = Instance.new("Frame")
	top.Size = UDim2.new(1, 0, 0, 52)
	top.BackgroundTransparency = 1
	top.Parent = self.body

	local tierLabel = label(top, ("ขั้น %d / %d"):format(pass.tier, cfg.tiers), 14, RUNE)
	tierLabel.Position = UDim2.new(0, 0, 0, 0)
	tierLabel.Size = UDim2.new(0.5, 0, 0, 20)

	local into = pass.tier >= cfg.tiers and cfg.xpPerTier or (pass.xp % cfg.xpPerTier)
	local xpLabel = label(top, ("%d / %d XP"):format(into, cfg.xpPerTier), 11, TEXT_MUTED, Enum.TextXAlignment.Right)
	xpLabel.Position = UDim2.new(0.5, 0, 0, 2)
	xpLabel.Size = UDim2.new(0.5, -230, 0, 18)

	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, 0, 0, 24)
	bar.Size = UDim2.new(1, -230, 0, 12)
	bar.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	bar.BorderSizePixel = 0
	bar.Parent = top
	corner(bar, UDim.new(1, 0))
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(math.clamp(into / cfg.xpPerTier, 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = RUNE
	fill.BorderSizePixel = 0
	fill.Parent = bar
	corner(fill, UDim.new(1, 0))

	local unlock = button(top, pass.premium and "พรีเมียม ✓" or ("ปลดพรีเมียม 💎 %d"):format(cfg.premiumCost),
		pass.premium and GREY or Color3.fromRGB(150, 110, 40), function()
			if not pass.premium then self:fire("unlockpass") end
		end)
	unlock.AnchorPoint = Vector2.new(1, 0)
	unlock.Position = UDim2.new(1, 0, 0, 4)
	unlock.Size = UDim2.fromOffset(220, 32)

	-- ตารางขั้น: ขั้น | สายฟรี | สายพรีเมียม
	local holder = Instance.new("Frame")
	holder.Position = UDim2.new(0, 0, 0, 58)
	holder.Size = UDim2.new(1, 0, 1, -58)
	holder.BackgroundTransparency = 1
	holder.Parent = self.body
	local list = scrollList(holder, 4)

	local function cell(parent, tier, track, claimed)
		local reward = (track == "premium" and cfg.Premium or cfg.Free)[tier]
		local reached = tier <= pass.tier
		local locked = track == "premium" and not pass.premium
		local f = Instance.new("Frame")
		f.BackgroundColor3 = claimed and Color3.fromRGB(40, 60, 42) or ROW
		f.BorderSizePixel = 0
		f.Parent = parent
		corner(f, UDim.new(0, 6))
		local t = label(f, rewardText(reward), 11, (reward and not locked) and TEXT_LIGHT or TEXT_MUTED)
		t.Position = UDim2.new(0, 8, 0, 0)
		t.Size = UDim2.new(1, -90, 1, 0)
		if reward and not claimed then
			local can = reached and not locked
			local b = button(f, locked and "🔒" or (reached and "รับ" or "…"), can and GREEN or GREY, function()
				if can then self:fire("claim", tier, track) end
			end)
			b.AnchorPoint = Vector2.new(1, 0.5)
			b.Position = UDim2.new(1, -6, 0.5, 0)
			b.Size = UDim2.fromOffset(64, 24)
		elseif claimed then
			local done = label(f, "รับแล้ว", 10, TEXT_MUTED, Enum.TextXAlignment.Right)
			done.AnchorPoint = Vector2.new(1, 0.5)
			done.Position = UDim2.new(1, -8, 0.5, 0)
			done.Size = UDim2.fromOffset(70, 20)
		end
		return f
	end

	local header = Instance.new("Frame")
	header.LayoutOrder = 0
	header.Size = UDim2.new(1, -6, 0, 18)
	header.BackgroundTransparency = 1
	header.Parent = list
	local h1 = label(header, "ขั้น", 10, TEXT_MUTED) h1.Size = UDim2.new(0, 40, 1, 0)
	local h2 = label(header, "สายฟรี", 10, TEXT_MUTED) h2.Position = UDim2.new(0, 46, 0, 0) h2.Size = UDim2.new(0.5, -50, 1, 0)
	local h3 = label(header, "สายพรีเมียม", 10, RUNE) h3.Position = UDim2.new(0.5, 4, 0, 0) h3.Size = UDim2.new(0.5, -4, 1, 0)

	for tier = 1, cfg.tiers do
		local row = Instance.new("Frame")
		row.LayoutOrder = tier
		row.Size = UDim2.new(1, -6, 0, 34)
		row.BackgroundTransparency = 1
		row.Parent = list
		local n = label(row, tostring(tier), 13, tier <= pass.tier and RUNE or TEXT_MUTED, Enum.TextXAlignment.Center)
		n.Size = UDim2.new(0, 40, 1, 0)
		local free = cell(row, tier, "free", pass.claimedFree[tostring(tier)] == true)
		free.Position = UDim2.new(0, 46, 0, 0)
		free.Size = UDim2.new(0.5, -50, 1, 0)
		local prem = cell(row, tier, "premium", pass.claimedPremium[tostring(tier)] == true)
		prem.Position = UDim2.new(0.5, 4, 0, 0)
		prem.Size = UDim2.new(0.5, -4, 1, 0)
	end
end

--------------------------------------------------------------------------------

function PremiumGui:Render(data)
	self.data = data or self.data
	self.gems.Text = ("💎 %d"):format(self.data.gems or 0)
	clear(self.body)
	if self.tab == "shop" then self:renderShop()
	elseif self.tab == "gacha" then self:renderGacha()
	else self:renderPass() end
end

function PremiumGui:Show(tab, data)
	if tab then self.tab = tab end
	self.gui.Enabled = true
	self:SetTab(self.tab)
	if data then self:Render(data) end
end

function PremiumGui:Hide()
	if not self.gui.Enabled then return end
	self.gui.Enabled = false
	self:fire("close")
end

function PremiumGui:IsOpen() return self.gui.Enabled end

return PremiumGui
