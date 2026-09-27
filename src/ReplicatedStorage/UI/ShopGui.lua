-- ShopGui: the shopkeeper's counter. Left is what they sell, right is what they will buy off you.
--
-- Pure builder, like the other GUIs here: it draws the snapshot the server sends and reports taps. It never
-- computes a price, never decides what is affordable, and holds no state between snapshots -- every redraw
-- is a fresh picture of what the server currently says.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)
local ItemIcon = require(script.Parent.ItemIcon)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)
local GOLD = Color3.fromRGB(238, 200, 96)
local GEM = Color3.fromRGB(128, 190, 240) -- ปุ่มจ่ายเพชร: ฟ้า แยกจากปุ่มเหรียญสีทองได้ทันที
local INK = Color3.fromRGB(24, 26, 32)

-- 62500 -> "62,500" · ราคาบ้าน/ของผิดกฎหมายเป็นหลักหมื่น-แสน อ่านไม่ออกถ้าไม่มีจุลภาค
local function commas(n)
	local s = tostring(math.floor(n))
	repeat
		local k
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return s
end

local ShopGui = {}
ShopGui.__index = ShopGui

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

local function stroke(inst, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency or 0.5
	s.Thickness = thickness or 1
	s.Parent = inst
	return s
end

function ShopGui.new()
	local self = setmetatable({}, ShopGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 17
	gui.Enabled = false
	-- นอกเกม (เทสใน Edit) ไม่มี PlayerGui ให้รอ WaitForChild จะค้างตลอดกาล — สร้างหน้าร้านไว้เฉยๆ ไม่ต้องแขวน
	if RunService:IsRunning() then
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	self.gui = gui

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = Responsive.IsSmallScreen() and UDim2.fromScale(0.95, 0.8)
		or UDim2.fromOffset(720, 440)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	stroke(panel, RUNE, 0.55, 2)
	Responsive.Scale(panel, Responsive.IsSmallScreen() and 0.95 or nil) -- มือถือ: แผงเต็มจออยู่แล้ว ห้ามย่อซ้ำ (QA 2026-09-26)
	self.panel = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 30)
	title.Position = UDim2.new(0, 12, 0, 12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 19
	title.TextColor3 = RUNE
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "ร้านขายของ"
	title.Parent = panel

	local purse = Instance.new("TextLabel")
	purse.Name = "Purse"
	purse.AnchorPoint = Vector2.new(1, 0)
	purse.Size = UDim2.fromOffset(220, 24)
	purse.Position = UDim2.new(1, -46, 0, 15)
	purse.BackgroundTransparency = 1
	purse.Font = Enum.Font.GothamBold
	purse.TextSize = 14
	purse.TextColor3 = GOLD
	purse.TextXAlignment = Enum.TextXAlignment.Right
	purse.Text = ""
	purse.Parent = panel
	self.purse = purse

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(26, 26)
	close.BackgroundColor3 = Color3.fromRGB(70, 74, 84)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBold
	close.TextSize = 15
	close.TextColor3 = TEXT_LIGHT
	close.Text = "\195\151"
	close.Parent = panel
	corner(close, UDim.new(0, 6))
	close.Activated:Connect(function()
		UiSound.Play("Click")
		self:Hide()
	end)

	-- Two columns: buying from them on the left, selling to them on the right.
	local function column(x, heading)
		local frame = Instance.new("Frame")
		frame.Position = UDim2.new(x, x == 0 and 12 or 6, 0, 74)
		frame.Size = UDim2.new(0.5, -18, 1, -88)
		frame.BackgroundColor3 = STONE_DEEP
		frame.BorderSizePixel = 0
		frame.Parent = panel
		corner(frame, UDim.new(0, 10))

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -16, 0, 22)
		label.Position = UDim2.new(0, 8, 0, 6)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextColor3 = TEXT_MUTED
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = heading
		label.Parent = frame

		local list = Instance.new("ScrollingFrame")
		list.Position = UDim2.new(0, 6, 0, 32)
		list.Size = UDim2.new(1, -12, 1, -40)
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 4
		list.CanvasSize = UDim2.new()
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.Parent = frame

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list

		return list
	end

	-- แท็บหมวดของร้านเกาะ (เฟส 2a) · สร้างปุ่มใน Show จากหมวดที่เซิร์ฟเวอร์ส่งมา · ร้านเกมหลักไม่มีหมวด แถบนี้จึงซ่อน
	-- อยู่ในช่องว่างระหว่างหัวร้าน (y 12-42) กับสองคอลัมน์ (เริ่ม y 74) พอดี
	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.Position = UDim2.new(0, 12, 0, 44)
	tabs.Size = UDim2.new(1, -24, 0, 26)
	tabs.BackgroundTransparency = 1
	tabs.Visible = false
	tabs.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 4)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs
	self.tabs = tabs
	self.tab = nil -- หมวดที่เลือกอยู่ อยู่ข้ามการวาดใหม่ (เซิร์ฟเวอร์ส่งภาพใหม่หลังทุกการซื้อ)

	self.sellList = column(0, "ของขาย")
	self.buyList = column(0.5, "ร้านรับซื้อ")

	-- Sell everything the shop will take, in one press. Sitting in the heading rather than at the bottom of
	-- the list so it does not move as the list grows and shrinks.
	local sellAll = Instance.new("TextButton")
	sellAll.Name = "SellAll"
	sellAll.AnchorPoint = Vector2.new(1, 0)
	sellAll.Position = UDim2.new(1, -10, 0, 5)
	sellAll.Size = UDim2.fromOffset(84, 22)
	sellAll.BackgroundColor3 = GOLD
	sellAll.BorderSizePixel = 0
	sellAll.Font = Enum.Font.GothamBold
	sellAll.TextSize = 12
	sellAll.TextColor3 = Color3.fromRGB(24, 26, 32)
	sellAll.Text = "ขายทั้งหมด"
	sellAll.Parent = self.buyList.Parent
	corner(sellAll, UDim.new(0, 5))
	sellAll.Activated:Connect(function()
		UiSound.Play("Click")
		if self.onSellAll then self.onSellAll() end
	end)

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -4)
	hint.Size = UDim2.new(1, -24, 0, 14)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 11
	hint.TextColor3 = TEXT_MUTED
	hint.Text = ""
	hint.Parent = panel
	self.hint = hint

	self.onBuy, self.onSell, self.onSellAll = nil, nil, nil
	return self
end

function ShopGui:OnBuy(callback) self.onBuy = callback end
function ShopGui:OnSell(callback) self.onSell = callback end
function ShopGui:OnSellAll(callback) self.onSellAll = callback end

-- One row: icon, name, price, and the buttons that act on it.
--
-- `buttons` go right to left from the edge: { name, text, color, width, onClick }. Returns the frame and how
-- many pixels the buttons took from the right edge, so the caller can put the amount box or the "x1" button
-- just left of them. `extra` is the width the caller will put there, so the name shrinks to make room.
-- `priceText` nil = no price line: a two-price row already carries both prices on its buttons, and the name
-- gets both lines instead -- on a phone the name area is narrow and a second line keeps it readable.
local function row(parent, order, icon, name, priceText, buttons, extra)
	local frame = Instance.new("Frame")
	frame.Name = "Row"
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -4, 0, 38)
	frame.BackgroundColor3 = Color3.fromRGB(44, 46, 56)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, UDim.new(0, 6))

	local image = Instance.new("ImageLabel")
	image.Size = UDim2.fromOffset(28, 28)
	image.Position = UDim2.fromOffset(6, 5)
	image.BackgroundTransparency = 1
	ItemIcon.Apply(image, icon)
	image.Parent = frame

	local x = 6
	for _, spec in ipairs(buttons) do
		local button = Instance.new("TextButton")
		button.Name = spec.name
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -x, 0.5, 0)
		button.Size = UDim2.fromOffset(spec.width, 26)
		button.BackgroundColor3 = spec.color
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.TextSize = 12
		button.TextColor3 = INK
		button.Text = spec.text
		button.Parent = frame
		corner(button, UDim.new(0, 5))
		button.Activated:Connect(function()
			UiSound.Play("Click")
			spec.onClick()
		end)
		x += spec.width + 4
	end
	local reserve = 40 + x + (extra or 0)

	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(40, 4)
	label.Size = UDim2.new(1, -reserve, 0, priceText and 16 or 30)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = TEXT_LIGHT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = priceText == nil
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = name
	label.Parent = frame

	if priceText then
		local price = Instance.new("TextLabel")
		price.Position = UDim2.fromOffset(40, 20)
		price.Size = UDim2.new(1, -reserve, 0, 14)
		price.BackgroundTransparency = 1
		price.Font = Enum.Font.Gotham
		price.TextSize = 11
		price.TextColor3 = GOLD
		price.TextXAlignment = Enum.TextXAlignment.Left
		price.Text = priceText
		price.Parent = frame
	end
	return frame, x
end

-- A box to type a quantity into, just left of the row's buttons (`right` = pixels they took).
--
-- Empty means one, which is what the row did before this existed: a player who never touches the box gets
-- the old behaviour. Anything that is not a number is ignored rather than corrected mid-typing, because
-- rewriting the box under someone's fingers makes it impossible to clear.
local function amountBox(frame, onChanged, right)
	local b = Instance.new("TextBox")
	b.Name = "Amount"
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -right, 0.5, 0)
	b.Size = UDim2.fromOffset(38, 26)
	b.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = Color3.fromRGB(232, 232, 238)
	b.PlaceholderText = "1"
	b.PlaceholderColor3 = Color3.fromRGB(120, 124, 134)
	b.ClearTextOnFocus = false
	b.Text = ""
	b.Parent = frame
	corner(b, UDim.new(0, 5))

	b:GetPropertyChangedSignal("Text"):Connect(function()
		-- Digits only. Typed rather than pasted is the normal case, so this mostly stops a stray letter.
		local digits = b.Text:gsub("%D", "")
		if digits ~= b.Text then b.Text = digits end
		if onChanged then onChanged(tonumber(digits)) end
	end)
	return b
end

-- A second, smaller button on a row, just left of the main one. Used for "sell just one" beside "sell
-- the stack", so a player can part with three of a hundred without emptying the slot.
local function smallButton(frame, text, onClick, right)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -right, 0.5, 0)
	b.Size = UDim2.fromOffset(30, 26)
	b.BackgroundColor3 = Color3.fromRGB(70, 74, 84)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = Color3.fromRGB(232, 232, 238)
	b.Text = text
	b.Parent = frame
	corner(b, UDim.new(0, 5))
	b.Activated:Connect(function()
		UiSound.Play("Click")
		onClick()
	end)
	return b
end

-- Switch the island shop's category tab and redraw from the last snapshot. The tab survives every redraw,
-- because the server sends a fresh snapshot after each purchase and jumping back to the first tab each time
-- would make buying several things from one tab a chore.
function ShopGui:SelectTab(id)
	self.tab = id
	if self.last then self:Show(self.last) end
end

-- The tab bar. Only the island shop sends categories; without them the bar hides and every row shows, which
-- is exactly how the main-game shop looked before tabs existed. Returns the category to filter by, or nil.
function ShopGui:drawTabs(categories)
	for _, child in ipairs(self.tabs:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	if not categories or #categories == 0 then
		self.tabs.Visible = false
		return nil
	end
	local known = false
	for _, c in ipairs(categories) do
		if c.id == self.tab then known = true end
	end
	if not known then self.tab = categories[1].id end
	for order, c in ipairs(categories) do
		local on = c.id == self.tab
		local b = Instance.new("TextButton")
		b.Name = "Tab_" .. c.id
		b.LayoutOrder = order
		b.Size = UDim2.new(1 / #categories, -4, 1, 0)
		b.BackgroundColor3 = on and RUNE or STONE_DEEP
		b.AutoButtonColor = not on
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 13
		b.TextColor3 = on and INK or TEXT_MUTED
		b.Text = c.label
		b.Parent = self.tabs
		corner(b, UDim.new(0, 6))
		b.Activated:Connect(function()
			if self.tab == c.id then return end
			UiSound.Play("Click")
			self:SelectTab(c.id)
		end)
	end
	self.tabs.Visible = true
	return self.tab
end

function ShopGui:Show(snapshot)
	self.last = snapshot
	for _, list in ipairs({ self.sellList, self.buyList }) do
		for _, child in ipairs(list:GetChildren()) do
			if not child:IsA("UIListLayout") then child:Destroy() end
		end
	end

	-- The island shop pays in two currencies, so both purses show. The main-game shop stays as it was.
	if snapshot.gems ~= nil then
		self.purse.Text = ("💰 %s · 💎 %s"):format(commas(snapshot.gold or 0), commas(snapshot.gems))
	else
		self.purse.Text = ("เงิน %d"):format(snapshot.gold or 0)
	end

	local filter = self:drawTabs(snapshot.categories)
	for _, entry in ipairs(snapshot.sells or {}) do
		if not filter or entry.category == filter then
			-- The quantity lives in the closure rather than being read off the box at press time, so the row
			-- keeps working the same way whether the number was typed or left alone.
			local want = nil
			local function buy(currency)
				return function()
					if self.onBuy then self.onBuy(entry.index, want, currency) end
				end
			end
			-- แถวที่ได้หลายชิ้นต่อการกดหนึ่งครั้งต้องบอกไว้ในชื่อ ไม่งั้น "เมล็ดพันธุ์ 250" อ่านเหมือนแพงขึ้น
			local label = entry.count and ("%s x%d"):format(entry.name, entry.count) or entry.name
			-- เฟส 2a: สองปุ่มทุกแถวที่มีสองราคา (ผู้ใช้เลือก 2026-09-27) · ปุ่มบอกราคาในตัว ไม่ต้องมีบรรทัดราคา
			-- เพชรฟ้า/เหรียญทอง แยกกันด้วยสีและไอคอน ไม่งั้น "250" ของสัตว์เลี้ยงดูถูกกว่าบ้าน 20,000
			local buttons, priceText
			if entry.gems and entry.coins then
				buttons = {
					{ name = "BuyCoins", text = "💰 " .. commas(entry.coins), color = GOLD, width = 74, onClick = buy("coins") },
					{ name = "BuyGems", text = "💎 " .. commas(entry.gems), color = GEM, width = 52, onClick = buy("gems") },
				}
			elseif entry.gems then
				buttons = { { name = "BuyGems", text = "💎 " .. commas(entry.gems), color = GEM, width = 58, onClick = buy("gems") } }
			else
				priceText = ("ราคา %d"):format(entry.coins or 0)
				buttons = { { name = "Buy", text = "ซื้อ", color = Color3.fromRGB(150, 200, 140), width = 58, onClick = buy(nil) } }
			end
			local frame, used = row(self.sellList, entry.index, entry.icon, label, priceText, buttons, 38 + 4)
			amountBox(frame, function(n) want = n end, used)
		end
	end

	if #(snapshot.buys or {}) == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -4, 0, 30)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 12
		empty.TextColor3 = TEXT_MUTED
		empty.Text = "ไม่มีของที่ร้านรับซื้อ"
		empty.Parent = self.buyList
	end
	for order, entry in ipairs(snapshot.buys or {}) do
		local stack = entry.count > 1
		local frame, used = row(self.buyList, order, entry.icon,
			("%s x%d"):format(entry.name, entry.count),
			("ชิ้นละ %d — รวม %d"):format(entry.each, entry.total),
			{ { name = "Sell", text = "ขายหมด", color = GOLD, width = 58, onClick = function()
				-- nil amount means the whole stack.
				if self.onSell then self.onSell(entry.slot, nil) end
			end } },
			stack and 34 or 0)
		-- Only worth offering on a stack: on a single item "sell 1" and "sell all" are the same press.
		if stack then
			smallButton(frame, "x1", function()
				if self.onSell then self.onSell(entry.slot, 1) end
			end, used)
		end
	end

	-- Prices drift on a server-wide timer, and saying when makes a low price feel like a reason to come
	-- back rather than a reason to stop playing.
	local left = snapshot.rerollIn or 0
	self.hint.Text = ("ราคารับซื้อเปลี่ยนใหม่ใน %d นาที"):format(math.max(0, left // 60))

	self.gui.Enabled = true
end

function ShopGui:Hide()
	self.gui.Enabled = false
end

function ShopGui:IsOpen()
	return self.gui.Enabled
end

return ShopGui
