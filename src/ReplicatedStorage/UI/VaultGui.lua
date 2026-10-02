-- VaultGui: Madam Aurelia's counter -- the purse on top, the bag and the warehouse side by side underneath.
--
-- A pure builder like ShopGui and CraftGui: it draws the snapshot the server sends and reports what was
-- pressed. It never counts a stack, never decides whether something will fit, and keeps nothing between
-- snapshots -- every redraw is a fresh picture of what the server currently says is true.
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local NumberBox = require(script.Parent.NumberBox) -- พิมพ์เกินที่มี = เด้งเป็นเลขสูงสุด (2026-10-02)
local UiSound = require(script.Parent.UiSound)
local ItemIcon = require(script.Parent.ItemIcon)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local ROW = Color3.fromRGB(44, 46, 56)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)
local GOOD = Color3.fromRGB(150, 200, 140)

-- One storage square. The same 74 the vehicle trunk uses, so the two windows that hold your things look like
-- the same window.
local TILE = 74

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
	Responsive.Scale(panel, Responsive.IsSmallScreen() and 0.95 or nil) -- มือถือ: แผงเต็มจออยู่แล้ว ห้ามย่อซ้ำ (QA 2026-09-26)
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
	-- ตัวเลขล้วน + เพดาน = เงินที่มากกว่าระหว่างในกระเป๋ากับในธนาคาร (ยังไม่รู้ว่าจะฝากหรือถอน) · ลบจนว่างได้เสมอ
	NumberBox.Bind(box, function() return math.max(self.goldNow or 0, self.bankedNow or 0) end)
	self.amountBox = box

	local function money_action(name, text, colour, offset)
		local b = button(money, text, colour, Color3.fromRGB(24, 26, 32), function()
			-- ฝาก = ไม่เกินเงินในกระเป๋า · ถอน = ไม่เกินเงินในธนาคาร (เด้งลงในช่องให้เห็น)
			local limit = (name == "deposit") and self.goldNow or (name == "withdraw") and self.bankedNow or nil
			if limit then box.Text = NumberBox.Clean(box.Text, limit) end
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

		-- A grid of squares rather than a list of rows, at the user's request, and the same TILE the vehicle
		-- trunk uses so the two storage windows read as the same idea. How many fit per row is left to the
		-- column's width: the panel narrows on a phone and the grid rewraps itself with nothing to recompute.
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(TILE, TILE)
		layout.CellPadding = UDim2.fromOffset(6, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		layout.Parent = list

		return head, list
	end

	-- The warehouse on the LEFT and the bag on the RIGHT, at the user's request. It reads as the direction the
	-- goods travel for the thing this counter is mostly used for: taking what you came for off the shelf.
	if stacked then
		self.vaultHead, self.vaultList = column("คลังสินค้า",
			UDim2.fromScale(0, 0), UDim2.new(1, 0, 0.5, -4))
		self.bagHead, self.bagList = column("กระเป๋า",
			UDim2.new(0, 0, 0.5, 4), UDim2.new(1, 0, 0.5, -4))
	else
		self.vaultHead, self.vaultList = column("คลังสินค้า",
			UDim2.fromScale(0, 0), UDim2.new(0.5, -6, 1, 0))
		self.bagHead, self.bagList = column("กระเป๋า",
			UDim2.new(0.5, 6, 0, 0), UDim2.new(0.5, -6, 1, 0))
	end

	self.status = label(panel, "ฝากของเข้าคลังแล้วของจะไม่หายตอนตาย · แตะช่อง = ย้าย 1 ชิ้น · ปุ่มมุมช่อง = ย้ายทั้งกอง", 11, TEXT_MUTED)
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
			self.status.Text = "ฝากของเข้าคลังแล้วของจะไม่หายตอนตาย · แตะช่อง = ย้าย 1 ชิ้น · ปุ่มมุมช่อง = ย้ายทั้งกอง"
		end
	end)
end

--------------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------------

-- One item, as a square tile: icon in the middle, name underneath, count over the icon's corner. Two ways to
-- move it, the same two a row used to offer -- tapping the tile moves ONE, and the small button in its
-- corner moves the whole stack. The arrow on that button points the way the goods are about to travel, which
-- is what stops the two columns needing to explain themselves.
local function itemTile(parent, order, entry, stackGlyph, onAll, onOne)
	local tile = Instance.new("TextButton")
	tile.LayoutOrder = order
	tile.Size = UDim2.fromOffset(TILE, TILE)
	tile.BackgroundColor3 = ROW
	tile.AutoButtonColor = true
	tile.BorderSizePixel = 0
	tile.Text = ""
	tile.Parent = parent
	corner(tile, UDim.new(0, 8))
	stroke(tile, RUNE, 0.8, 1)

	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	ItemIcon.Apply(icon, entry.icon)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 6)
	icon.Size = UDim2.fromOffset(34, 34)
	icon.Parent = tile

	-- ไม่มีรูปเป็นของตัวเอง = ⌛ (ItemIcon แขวนให้ในช่องรูปแล้ว) ชื่ออยู่ใต้ช่องอยู่แล้วจึงยังบอกได้ว่าชิ้นไหน
	-- เดิมเอาตัวอักษรหกตัวแรกของชื่อมาแทน ซึ่งซ้ำกับชื่อข้างล่างพอดี

	local name = label(tile, entry.name, 11, TEXT_LIGHT)
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -4)
	name.Size = UDim2.new(1, -6, 0, 14)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local count = label(tile, entry.count > 1 and ("x%d"):format(entry.count) or "", 12, RUNE, true)
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -6, 0, 30)
	count.Size = UDim2.fromOffset(30, 14)
	count.TextXAlignment = Enum.TextXAlignment.Right

	-- A keyed item is one indivisible thing -- a vehicle key carries its own plate -- so tapping it moves the
	-- whole of it and there is no stack button to offer.
	if entry.unique or entry.count <= 1 then
		tile.Activated:Connect(function()
			UiSound.Play("Click")
			onAll()
		end)
	else
		tile.Activated:Connect(function()
			UiSound.Play("Click")
			onOne()
		end)
		local all = button(tile, stackGlyph, STONE_DEEP, RUNE, onAll)
		all.AnchorPoint = Vector2.new(1, 0)
		all.Position = UDim2.new(1, -4, 0, 4)
		all.Size = UDim2.fromOffset(20, 16)
		all.TextSize = 11
	end

	return tile
end

local function fill(list, entries, stackGlyph, onAll, onOne, emptyText)
	for _, child in ipairs(list:GetChildren()) do
		if not child:IsA("UIGridLayout") then child:Destroy() end
	end
	if #entries == 0 then
		-- The grid gives this one cell like everything else and there is no arguing with it, so the line wraps
		-- inside the square rather than pretending it can be wider.
		local empty = label(list, emptyText, 11, TEXT_MUTED)
		empty.TextWrapped = true
		empty.TextXAlignment = Enum.TextXAlignment.Center
		empty.TextYAlignment = Enum.TextYAlignment.Center
		return
	end
	for order, entry in ipairs(entries) do
		itemTile(list, order, entry, stackGlyph,
			function() onAll(entry) end,
			function() onOne(entry) end)
	end
end

function VaultGui:Show(snapshot)
	self.goldNow, self.bankedNow = snapshot.gold or 0, snapshot.banked or 0
	self.purse.Text = ("เงินในกระเป๋า %d"):format(snapshot.gold or 0)
	self.banked.Text = ("เงินในธนาคาร %d"):format(snapshot.banked or 0)
	self.vaultHead.Text = ("คลังสินค้า  %d/%d ช่อง"):format(snapshot.vaultUsed or 0, snapshot.vaultSlots or 0)

	fill(self.bagList, snapshot.bag or {}, "≪",
		function(entry) if self.callbacks.store then self.callbacks.store(entry.slot, nil) end end,
		function(entry) if self.callbacks.store then self.callbacks.store(entry.slot, 1) end end,
		"กระเป๋าว่าง")

	fill(self.vaultList, snapshot.vault or {}, "≫",
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
