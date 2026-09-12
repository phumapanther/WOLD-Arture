-- VaultGui: Madam Aurelia's counter -- the purse on top, the bag and the warehouse side by side underneath.
--
-- A pure builder like ShopGui and CraftGui: it draws the snapshot the server sends and reports what was
-- pressed. It never counts a stack, never decides whether something will fit, and keeps nothing between
-- snapshots -- every redraw is a fresh picture of what the server currently says is true.
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local ROW = Color3.fromRGB(44, 46, 56)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)
local GOOD = Color3.fromRGB(150, 200, 140)

local VaultGui = {}
VaultGui.__index = VaultGui

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

local function label(parent, text, size, colour, bold)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	l.TextSize = size
	l.TextColor3 = colour
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

local function button(parent, text, colour, textColour, onClick)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = colour
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = textColour
	b.Text = text
	b.Parent = parent
	corner(b, UDim.new(0, 5))
	b.Activated:Connect(function()
		UiSound.Play("Click")
		onClick()
	end)
	return b
end

--------------------------------------------------------------------------------

function VaultGui.new()
	local self = setmetatable({}, VaultGui)
	self.callbacks = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "VaultGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 17 -- alongside the shop and the forge; only one counter is ever open at a time
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local small = Responsive.IsSmallScreen()

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = small and UDim2.fromScale(0.95, 0.86) or UDim2.fromOffset(640, 470)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	stroke(panel, RUNE, 0.55, 2)
	Responsive.Scale(panel)
	self.panel = panel

	local title = label(panel, "ธนาคารและคลังสินค้า", 19, RUNE, true)
	title.Position = UDim2.fromOffset(12, 12)
	title.Size = UDim2.new(1, -60, 0, 30)

	local close = button(panel, "\195\151", Color3.fromRGB(70, 74, 84), TEXT_LIGHT, function()
		self:Hide()
	end)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(26, 26)
	close.TextSize = 15

	----------------------------------------------------------------------------
	-- The purse
	----------------------------------------------------------------------------

	-- On a phone the balances and the controls cannot share a line: two 68-pixel buttons and a 110-pixel box
	-- beside a "เงินในกระเป๋า 120,000" label overlap it outright at 380 points of width. So the panel is
	-- taller there and the controls sit on their own row underneath.
	local moneyHeight = small and 92 or 64
	local moneyTop = small and 56 or 0 -- where the box and buttons go; 0 means "on the balances' own line"

	local money = Instance.new("Frame")
	money.Position = UDim2.fromOffset(12, 48)
	money.Size = UDim2.new(1, -24, 0, moneyHeight)
	money.BackgroundColor3 = STONE_DEEP
	money.BorderSizePixel = 0
	money.Parent = panel
	corner(money, UDim.new(0, 10))

	self.purse = label(money, "เงินในกระเป๋า 0", 13, TEXT_LIGHT, true)
	self.purse.Position = UDim2.fromOffset(12, 8)
	self.purse.Size = UDim2.new(small and 1 or 0.5, -12, 0, 20)

	self.banked = label(money, "เงินในธนาคาร 0", 13, GOOD, true)
	self.banked.Position = UDim2.fromOffset(12, 30)
	self.banked.Size = UDim2.new(small and 1 or 0.5, -12, 0, 20)

	-- Typed rather than tapped, because the amounts are large: a player banking eighty thousand should not
	-- be asked to press "+100" eight hundred times.
	local box = Instance.new("TextBox")
	box.AnchorPoint = small and Vector2.new(0, 0) or Vector2.new(1, 0.5)
	box.Position = small and UDim2.fromOffset(12, moneyTop) or UDim2.new(1, -158, 0.5, 0)
	box.Size = UDim2.fromOffset(110, 30)
	box.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
	box.BorderSizePixel = 0
	box.Font = Enum.Font.GothamBold
	box.TextSize = 13
	box.TextColor3 = TEXT_LIGHT
	box.PlaceholderText = "จำนวนเงิน"
	box.PlaceholderColor3 = TEXT_MUTED
	box.ClearTextOnFocus = false
	box.Text = ""
	box.Parent = money
	corner(box, UDim.new(0, 6))
	box:GetPropertyChangedSignal("Text"):Connect(function()
		-- Digits only, filtered as it is typed rather than corrected on submit. Rewriting the box under
		-- someone's fingers is what makes a field impossible to clear, so only non-digits are removed.
		local digits = box.Text:gsub("%D", "")
		if digits ~= box.Text then box.Text = digits end
	end)
	self.amountBox = box

	local function money_action(name, text, colour, offset)
		local b = button(money, text, colour, Color3.fromRGB(24, 26, 32), function()
			local amount = tonumber(box.Text)
			if not amount or amount <= 0 then
				return self:SetStatus("ใส่จำนวนเงินก่อน")
			end
			if self.callbacks[name] then self.callbacks[name](amount) end
		end)
		if small then
			b.Position = UDim2.fromOffset(130 + (offset == 10 and 74 or 0), moneyTop)
		else
			b.AnchorPoint = Vector2.new(1, 0.5)
			b.Position = UDim2.new(1, -offset, 0.5, 0)
		end
		b.Size = UDim2.fromOffset(68, 30)
		return b
	end
	money_action("deposit", "ฝากเงิน", GOOD, 82)
	money_action("withdraw", "ถอนเงิน", RUNE, 10)

	----------------------------------------------------------------------------
	-- The two columns
	----------------------------------------------------------------------------

	-- Side by side on a monitor, stacked on a phone: two 46%-wide columns of item rows at 400px is unusable,
	-- and a warehouse you cannot read is a warehouse you do not use.
	--
	-- Both live inside one body frame whose height is whatever is left between the purse and the status line,
	-- so the two columns can be sized in pure SCALE (half each, or full each) and neither layout has to know
	-- how tall the panel happens to be on this screen.
	local stacked = small
	local topY = 48 + moneyHeight + 10

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(12, topY)
	body.Size = UDim2.new(1, -24, 1, -(topY + 34))
	body.BackgroundTransparency = 1
	body.Parent = panel

	local function column(titleText, position, size)
		local holder = Instance.new("Frame")
		holder.Position = position
		holder.Size = size
		holder.BackgroundColor3 = STONE_DEEP
		holder.BorderSizePixel = 0
		holder.Parent = body
		corner(holder, UDim.new(0, 10))

		local head = label(holder, titleText, 13, RUNE, true)
		head.Position = UDim2.fromOffset(10, 6)
		head.Size = UDim2.new(1, -20, 0, 18)

		local list = Instance.new("ScrollingFrame")
		list.Position = UDim2.fromOffset(6, 28)
		list.Size = UDim2.new(1, -12, 1, -34)
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 4
		list.CanvasSize = UDim2.new()
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.Parent = holder

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list

		return head, list
	end

	if stacked then
		self.bagHead, self.bagList = column("กระเป๋า",
			UDim2.fromScale(0, 0), UDim2.new(1, 0, 0.5, -4))
		self.vaultHead, self.vaultList = column("คลังสินค้า",
			UDim2.new(0, 0, 0.5, 4), UDim2.new(1, 0, 0.5, -4))
	else
		self.bagHead, self.bagList = column("กระเป๋า",
			UDim2.fromScale(0, 0), UDim2.new(0.5, -6, 1, 0))
		self.vaultHead, self.vaultList = column("คลังสินค้า",
			UDim2.new(0.5, 6, 0, 0), UDim2.new(0.5, -6, 1, 0))
	end

	self.status = label(panel, "ฝากของเข้าคลังแล้วของจะไม่หายตอนตาย", 11, TEXT_MUTED)
	self.status.AnchorPoint = Vector2.new(0, 1)
	self.status.Position = UDim2.new(0, 14, 1, -10)
	self.status.Size = UDim2.new(1, -28, 0, 20)

	return self
end

function VaultGui:On(name, fn)
	self.callbacks[name] = fn
end

function VaultGui:SetStatus(text)
	self.status.Text = text
	self.statusToken = (self.statusToken or 0) + 1
	local token = self.statusToken
	task.delay(3, function()
		if self.statusToken == token and self.status.Parent then
			self.status.Text = "ฝากของเข้าคลังแล้วของจะไม่หายตอนตาย"
		end
	end)
end

--------------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------------

-- One item, with two ways to move it: the whole stack, or a single one. Two buttons rather than a number box
-- because a row is 30 pixels tall in a half-width column -- there is no room to type in, and "all or one" is
-- what a warehouse is actually used for.
local function itemRow(parent, order, entry, mainText, onAll, onOne)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -4, 0, 30)
	frame.BackgroundColor3 = ROW
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, UDim.new(0, 6))

	local icon = Instance.new("ImageLabel")
	icon.Position = UDim2.fromOffset(5, 4)
	icon.Size = UDim2.fromOffset(22, 22)
	icon.BackgroundTransparency = 1
	icon.Image = entry.icon or ""
	icon.Parent = frame

	local name = label(frame, entry.count > 1 and ("%s x%d"):format(entry.name, entry.count) or entry.name,
		12, TEXT_LIGHT)
	name.Position = UDim2.fromOffset(32, 0)
	name.Size = UDim2.new(1, -110, 1, 0)
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local all = button(frame, mainText, Color3.fromRGB(70, 74, 84), TEXT_LIGHT, onAll)
	all.AnchorPoint = Vector2.new(1, 0.5)
	all.Position = UDim2.new(1, -5, 0.5, 0)
	all.Size = UDim2.fromOffset(44, 22)

	-- A keyed item is one indivisible thing -- a vehicle key carries its own plate -- so there is no "one of
	-- them" to move separately, and offering the button would be offering to split what cannot split.
	if not entry.unique and entry.count > 1 then
		local one = button(frame, "1", Color3.fromRGB(58, 62, 72), TEXT_LIGHT, onOne)
		one.AnchorPoint = Vector2.new(1, 0.5)
		one.Position = UDim2.new(1, -53, 0.5, 0)
		one.Size = UDim2.fromOffset(24, 22)
	end

	return frame
end

local function fill(list, entries, mainText, onAll, onOne, emptyText)
	for _, child in ipairs(list:GetChildren()) do
		if not child:IsA("UIListLayout") then child:Destroy() end
	end
	if #entries == 0 then
		local empty = label(list, emptyText, 11, TEXT_MUTED)
		empty.Size = UDim2.new(1, -4, 0, 26)
		empty.TextXAlignment = Enum.TextXAlignment.Center
		return
	end
	for order, entry in ipairs(entries) do
		itemRow(list, order, entry, mainText,
			function() onAll(entry) end,
			function() onOne(entry) end)
	end
end

function VaultGui:Show(snapshot)
	self.purse.Text = ("เงินในกระเป๋า %d"):format(snapshot.gold or 0)
	self.banked.Text = ("เงินในธนาคาร %d"):format(snapshot.banked or 0)
	self.vaultHead.Text = ("คลังสินค้า  %d/%d ช่อง"):format(snapshot.vaultUsed or 0, snapshot.vaultSlots or 0)

	fill(self.bagList, snapshot.bag or {}, "ฝาก",
		function(entry) if self.callbacks.store then self.callbacks.store(entry.slot, nil) end end,
		function(entry) if self.callbacks.store then self.callbacks.store(entry.slot, 1) end end,
		"กระเป๋าว่าง")

	fill(self.vaultList, snapshot.vault or {}, "เบิก",
		function(entry) if self.callbacks.take then self.callbacks.take(entry.slot, nil) end end,
		function(entry) if self.callbacks.take then self.callbacks.take(entry.slot, 1) end end,
		"คลังว่าง")

	self.gui.Enabled = true
end

function VaultGui:Hide()
	self.gui.Enabled = false
end

function VaultGui:IsOpen()
	return self.gui.Enabled
end

return VaultGui
