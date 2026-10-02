-- TradeGui: the two-sided trade window.
--
-- Left: your own bag and gold, which is what you pick from. Right, top: what you are putting up. Right,
-- bottom: what they are putting up. Both people see the same layout from their own side, so "left is mine,
-- right-bottom is theirs" is true for both of them at once.
--
-- Pure builder: it draws the picture the server sends and reports taps. It never decides what is in a
-- trade -- the server owns the offer, and this window is only ever showing the last thing it was told.
local Players = game:GetService("Players")
local ItemCatalog = require(script.Parent.Parent.ItemCatalog)
local NumberBox = require(script.Parent.NumberBox) -- พิมพ์เกินที่มี = เด้งเป็นเลขสูงสุด (2026-10-02)
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)
local ItemIcon = require(script.Parent.ItemIcon)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)
local GOOD = Color3.fromRGB(120, 190, 120)

local TradeGui = {}
TradeGui.__index = TradeGui

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

local function stroke(inst, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency or 0.55
	s.Thickness = thickness or 1
	s.Parent = inst
	return s
end

local function label(parent, text, size, color, y, height)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -8, 0, height or 20)
	l.Position = UDim2.new(0, 4, 0, y or 0)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = size or 12
	l.TextColor3 = color or TEXT_LIGHT
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

-- A scrolling grid of item tiles, used for all three panes.
local function makeGrid(parent, y, height)
	local frame = Instance.new("ScrollingFrame")
	frame.Position = UDim2.new(0, 4, 0, y)
	frame.Size = UDim2.new(1, -8, 0, height)
	frame.BackgroundColor3 = STONE_DEEP
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 4
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.Parent = parent
	corner(frame, UDim.new(0, 8))
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(52, 52)
	grid.CellPadding = UDim2.fromOffset(4, 4)
	grid.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.Parent = frame
	return frame
end

local function tile(parent, entry, onClick)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Color3.fromRGB(44, 46, 56)
	b.BorderSizePixel = 0
	b.Text = ""
	b.AutoButtonColor = onClick ~= nil
	b.Parent = parent
	corner(b, UDim.new(0, 6))

	-- มีรูป = รูป · ไม่มีรูป = ⌛ (ItemIcon) ทับด้วยชื่อข้างล่างเหมือนเดิม จะได้รู้ว่าเป็นสกิน/ออร่าชิ้นไหน
	do
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(1, -6, 1, -6)
		icon.Position = UDim2.new(0, 3, 0, 3)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		ItemIcon.Apply(icon, entry.icon)
		icon.Parent = b
	end
	if not ItemIcon.Has(entry.icon) then
		local name = Instance.new("TextLabel")
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.new(0.5, 0, 1, -2)
		name.Size = UDim2.new(1, -4, 0.42, 0)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamMedium
		name.TextSize = 9
		name.TextWrapped = true
		name.TextColor3 = TEXT_LIGHT
		name.Text = entry.name or entry.id
		name.Parent = b
	end

	if (entry.count or 1) > 1 then
		local count = Instance.new("TextLabel")
		count.AnchorPoint = Vector2.new(1, 1)
		count.Position = UDim2.new(1, -3, 1, -1)
		count.Size = UDim2.fromOffset(24, 12)
		count.BackgroundTransparency = 1
		count.Font = Enum.Font.GothamBold
		count.TextSize = 11
		count.TextColor3 = RUNE
		count.Text = tostring(entry.count)
		count.Parent = b
	end

	if onClick then
		b.Activated:Connect(function()
			UiSound.Play("Click")
			onClick()
		end)
	end
	return b
end

--------------------------------------------------------------------------------

function TradeGui.new()
	local self = setmetatable({}, TradeGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "TradeGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 21 -- above the bag and the action popups; a trade is a modal moment
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
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = Responsive.IsSmallScreen() and UDim2.fromScale(0.96, 0.86)
		or UDim2.fromOffset(680, 440)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	stroke(panel, RUNE, 0.55, 2)
	Responsive.Scale(panel, Responsive.IsSmallScreen() and 0.95 or nil) -- มือถือ: แผงเต็มจออยู่แล้ว ห้ามย่อซ้ำ (QA 2026-09-26)
	self.panel = panel

	local title = label(panel, "เทรด", 18, RUNE, 12, 28)
	title.Position = UDim2.new(0, 14, 0, 12)
	self.title = title

	----------------------------------------------------------------------------
	-- Left: my bag
	----------------------------------------------------------------------------
	local left = Instance.new("Frame")
	left.Position = UDim2.new(0, 12, 0, 46)
	left.Size = UDim2.new(0.5, -18, 1, -104)
	left.BackgroundTransparency = 1
	left.Parent = panel

	label(left, "กระเป๋าของฉัน", 12, TEXT_MUTED, 0)
	self.bagGrid = makeGrid(left, 22, 0)
	self.bagGrid.Size = UDim2.new(1, -8, 1, -50)
	self.myGold = label(left, "เงิน: 0", 13, RUNE, 0)
	self.myGold.AnchorPoint = Vector2.new(0, 1)
	self.myGold.Position = UDim2.new(0, 4, 1, -4)

	----------------------------------------------------------------------------
	-- Right, top: what I am putting up. Right, bottom: what they are.
	----------------------------------------------------------------------------
	local right = Instance.new("Frame")
	right.Position = UDim2.new(0.5, 6, 0, 46)
	right.Size = UDim2.new(0.5, -18, 1, -104)
	right.BackgroundTransparency = 1
	right.Parent = panel

	label(right, "ฉันจะให้", 12, GOOD, 0)
	self.mineGrid = makeGrid(right, 22, 0)
	self.mineGrid.Size = UDim2.new(1, -8, 0.5, -46)

	self.mineGold = label(right, "เงิน: 0", 12, RUNE, 0)
	self.mineGold.Size = UDim2.new(0.55, 0, 0, 20)
	self.mineGold.Position = UDim2.new(0, 4, 0.5, -22)

	local goldBox = Instance.new("TextBox")
	goldBox.AnchorPoint = Vector2.new(1, 0)
	goldBox.Position = UDim2.new(1, -4, 0.5, -24)
	goldBox.Size = UDim2.new(0.4, 0, 0, 24)
	goldBox.BackgroundColor3 = STONE_DEEP
	goldBox.BorderSizePixel = 0
	goldBox.Font = Enum.Font.GothamBold
	goldBox.TextSize = 12
	goldBox.TextColor3 = TEXT_LIGHT
	goldBox.PlaceholderText = "ใส่เงิน"
	goldBox.PlaceholderColor3 = TEXT_MUTED
	goldBox.Text = ""
	goldBox.ClearTextOnFocus = false
	NumberBox.Bind(goldBox, function() return self.goldHave or 0 end)
	goldBox.Parent = right
	corner(goldBox, UDim.new(0, 6))
	self.goldBox = goldBox

	self.theirsLabel = label(right, "เขาจะให้", 12, TEXT_MUTED, 0)
	self.theirsLabel.Position = UDim2.new(0, 4, 0.5, 2)
	self.theirsGrid = makeGrid(right, 0, 0)
	self.theirsGrid.Position = UDim2.new(0, 4, 0.5, 24)
	self.theirsGrid.Size = UDim2.new(1, -8, 0.5, -46)
	self.theirsGold = label(right, "เงิน: 0", 12, RUNE, 0)
	self.theirsGold.AnchorPoint = Vector2.new(0, 1)
	self.theirsGold.Position = UDim2.new(0, 4, 1, -2)

	----------------------------------------------------------------------------
	local confirm = Instance.new("TextButton")
	confirm.AnchorPoint = Vector2.new(0, 1)
	confirm.Position = UDim2.new(0, 12, 1, -12)
	confirm.Size = UDim2.new(0.5, -18, 0, 38)
	confirm.BackgroundColor3 = Color3.fromRGB(58, 78, 56)
	confirm.BorderSizePixel = 0
	confirm.Font = Enum.Font.GothamBold
	confirm.TextSize = 14
	confirm.TextColor3 = TEXT_LIGHT
	confirm.Text = "ตกลง"
	confirm.Parent = panel
	corner(confirm, UDim.new(0, 8))
	self.confirmButton = confirm

	local cancel = Instance.new("TextButton")
	cancel.AnchorPoint = Vector2.new(1, 1)
	cancel.Position = UDim2.new(1, -12, 1, -12)
	cancel.Size = UDim2.new(0.5, -18, 0, 38)
	cancel.BackgroundColor3 = Color3.fromRGB(96, 52, 48)
	cancel.BorderSizePixel = 0
	cancel.Font = Enum.Font.GothamBold
	cancel.TextSize = 14
	cancel.TextColor3 = TEXT_LIGHT
	cancel.Text = "ยกเลิก"
	cancel.Parent = panel
	corner(cancel, UDim.new(0, 8))
	self.cancelButton = cancel

	self.offeredSlots = {} -- bag slot indexes I am currently offering
	self.offeredGold = 0
	self.callbacks = {}
	return self
end

function TradeGui:On(name, fn)
	self.callbacks[name] = fn
end

local function fire(self, name, ...)
	local fn = self.callbacks[name]
	if fn then fn(...) end
end

function TradeGui:Open(partner)
	self.title.Text = ("เทรดกับ %s"):format(partner and partner.DisplayName or "")
	self.offeredSlots = {}
	self.offeredGold = 0
	self.goldBox.Text = ""
	self.gui.Enabled = true

	-- Wired here rather than in new(), so each trade gets fresh handlers and a stale one cannot fire into
	-- a session that has closed.
	if self.connections then
		for _, c in ipairs(self.connections) do c:Disconnect() end
	end
	self.connections = {
		self.confirmButton.Activated:Connect(function()
			UiSound.Play("Click")
			fire(self, "confirm")
		end),
		self.cancelButton.Activated:Connect(function()
			UiSound.Play("Click")
			fire(self, "cancel")
		end),
		self.goldBox.FocusLost:Connect(function()
			self.offeredGold = math.max(0, math.floor(tonumber(self.goldBox.Text) or 0))
			self:sendOffer()
		end),
	}
end

function TradeGui:Close()
	self.gui.Enabled = false
	if self.connections then
		for _, c in ipairs(self.connections) do c:Disconnect() end
		self.connections = nil
	end
end

function TradeGui:IsOpen()
	return self.gui.Enabled
end

function TradeGui:sendOffer()
	fire(self, "offer", self.offeredSlots, self.offeredGold)
end

-- The bag, drawn from the ordinary inventory payload. Tapping a slot puts it up or takes it back.
function TradeGui:RenderBag(inventory)
	for _, child in ipairs(self.bagGrid:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	self.goldHave = inventory and inventory.gold or 0
	self.myGold.Text = ("เงิน: %d"):format(self.goldHave)

	local offered = {}
	for _, index in ipairs(self.offeredSlots) do offered[index] = true end

	for index, slot in pairs((inventory and inventory.slots) or {}) do
		-- ช่องว่างมาเป็น `false` (Inventory.Send เติมรูให้ข้าม RemoteEvent ได้) · ไม่ข้าม = error ตั้งแต่ช่องว่างแรก
		-- แล้วหน้าต่างเทรดไม่เคยวาดข้อเสนอของอีกฝ่ายเลย (QA 2026-09-26)
		if not slot then continue end
		local item = ItemCatalog.Get(slot.id)
		local b = tile(self.bagGrid, {
			id = slot.id,
			name = ItemCatalog.DisplayName(slot.id, slot.meta),
			icon = item and item.icon or "",
			count = slot.count,
		}, function()
			if offered[index] then
				for i, v in ipairs(self.offeredSlots) do
					if v == index then table.remove(self.offeredSlots, i) break end
				end
			else
				table.insert(self.offeredSlots, index)
			end
			self:sendOffer()
		end)
		-- An offered item is dimmed in the bag, so it is obvious where it went.
		b.BackgroundTransparency = offered[index] and 0.6 or 0
	end
end

-- The two offers, exactly as the server describes them. Nothing here is inferred: if the server says the
-- offer is empty, it is drawn empty, even if this client thinks it just added something.
function TradeGui:RenderOffers(mine, theirs)
	for _, pane in ipairs({ { self.mineGrid, mine }, { self.theirsGrid, theirs } }) do
		for _, child in ipairs(pane[1]:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		for _, entry in ipairs((pane[2] and pane[2].items) or {}) do
			tile(pane[1], entry, nil)
		end
	end
	self.mineGold.Text = ("เงิน: %d"):format((mine and mine.gold) or 0)
	self.theirsGold.Text = ("เงิน: %d"):format((theirs and theirs.gold) or 0)

	-- Whose agreement stands. Both must be green before anything moves.
	self.confirmButton.Text = (mine and mine.confirmed) and "รออีกฝ่าย..." or "ตกลง"
	self.confirmButton.BackgroundColor3 = (mine and mine.confirmed)
		and Color3.fromRGB(70, 74, 84) or Color3.fromRGB(58, 78, 56)
	self.theirsLabel.Text = (theirs and theirs.confirmed) and "เขาจะให้ (ตกลงแล้ว)" or "เขาจะให้"
	self.theirsLabel.TextColor3 = (theirs and theirs.confirmed) and GOOD or TEXT_MUTED
end

return TradeGui
