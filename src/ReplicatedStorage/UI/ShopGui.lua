-- ShopGui: the shopkeeper's counter. Left is what they sell, right is what they will buy off you.
--
-- Pure builder, like the other GUIs here: it draws the snapshot the server sends and reports taps. It never
-- computes a price, never decides what is affordable, and holds no state between snapshots -- every redraw
-- is a fresh picture of what the server currently says.
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)
local ItemIcon = require(script.Parent.ItemIcon)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)
local GOLD = Color3.fromRGB(238, 200, 96)

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
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
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
	Responsive.Scale(panel)
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

-- One row: icon, name, price, and the button that acts on it.
local function row(parent, order, icon, name, priceText, buttonText, buttonColor, onClick)
	local frame = Instance.new("Frame")
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

	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(40, 4)
	label.Size = UDim2.new(1, -142, 0, 16)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = TEXT_LIGHT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = name
	label.Parent = frame

	local price = Instance.new("TextLabel")
	price.Position = UDim2.fromOffset(40, 20)
	price.Size = UDim2.new(1, -142, 0, 14)
	price.BackgroundTransparency = 1
	price.Font = Enum.Font.Gotham
	price.TextSize = 11
	price.TextColor3 = GOLD
	price.TextXAlignment = Enum.TextXAlignment.Left
	price.Text = priceText
	price.Parent = frame

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -6, 0.5, 0)
	button.Size = UDim2.fromOffset(58, 26)
	button.BackgroundColor3 = buttonColor
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextColor3 = Color3.fromRGB(24, 26, 32)
	button.Text = buttonText
	button.Parent = frame
	corner(button, UDim.new(0, 5))
	button.Activated:Connect(function()
		UiSound.Play("Click")
		onClick()
	end)
	return frame
end

-- A box to type a quantity into, in the same slot on the row that the small button uses on the sell side.
--
-- Empty means one, which is what the row did before this existed: a player who never touches the box gets
-- the old behaviour. Anything that is not a number is ignored rather than corrected mid-typing, because
-- rewriting the box under someone's fingers makes it impossible to clear.
local function amountBox(frame, onChanged)
	local b = Instance.new("TextBox")
	b.Name = "Amount"
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -68, 0.5, 0)
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

-- A second, smaller button on a row, to the left of the main one. Used for "sell just one" beside "sell
-- the stack", so a player can part with three of a hundred without emptying the slot.
local function smallButton(frame, text, onClick)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -68, 0.5, 0)
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

function ShopGui:Show(snapshot)
	for _, list in ipairs({ self.sellList, self.buyList }) do
		for _, child in ipairs(list:GetChildren()) do
			if not child:IsA("UIListLayout") then child:Destroy() end
		end
	end

	self.purse.Text = ("เงิน %d"):format(snapshot.gold or 0)

	for _, entry in ipairs(snapshot.sells or {}) do
		-- The quantity lives in the closure rather than being read off the box at press time, so the row
		-- keeps working the same way whether the number was typed or left alone.
		local want = nil
		local frame = row(self.sellList, entry.index, entry.icon, entry.name,
			("ราคา %d"):format(entry.price), "ซื้อ", Color3.fromRGB(150, 200, 140),
			function()
				if self.onBuy then self.onBuy(entry.index, want) end
			end)
		amountBox(frame, function(n) want = n end)
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
		local frame = row(self.buyList, order, entry.icon,
			("%s x%d"):format(entry.name, entry.count),
			("ชิ้นละ %d — รวม %d"):format(entry.each, entry.total),
			"ขายหมด", GOLD,
			function()
				-- nil amount means the whole stack.
				if self.onSell then self.onSell(entry.slot, nil) end
			end)
		-- Only worth offering on a stack: on a single item "sell 1" and "sell all" are the same press.
		if entry.count > 1 then
			smallButton(frame, "x1", function()
				if self.onSell then self.onSell(entry.slot, 1) end
			end)
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
