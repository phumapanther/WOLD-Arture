-- StorageChestGui: หน้าต่างหีบเก็บของ — ของในหีบซ้าย กระเป๋าเราขวา
--
-- ตัววาดล้วน เหมือน GUI อื่นในโฟลเดอร์นี้: รายงานการกดออกไปทาง callback ไม่รู้จักระบบเกมเลย
--
-- **ของในหีบเป็นสถานะร่วม** คนอื่นหยิบของออกไปตอนไหนก็ได้ หน้าต่างนี้จึงวาดใหม่ทั้งฝั่งทุกครั้งที่
-- เซิร์ฟเวอร์ส่งภาพมา แทนที่จะจำว่าช่องไหนมีอะไรแล้วแก้ทีละจุด
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)
local ItemCatalog = require(script.Parent.Parent.ItemCatalog)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local SLOT_BG = Color3.fromRGB(44, 47, 58)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)

local StorageChestGui = {}
StorageChestGui.__index = StorageChestGui

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

local function label(parent, text, size, colour)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = size or 14
	l.TextColor3 = colour or TEXT_LIGHT
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

function StorageChestGui.new()
	local self = setmetatable({}, StorageChestGui)
	self.callbacks = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "StorageChestGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 19
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	-- ฉากหลังก่อน panel เสมอ — ScreenGui ใช้ ZIndexBehavior แบบ Sibling ซึ่งตัดสินการรับคลิกจากลำดับ
	-- การเป็นลูกด้วย ถ้าสร้างทีหลังมันจะอยู่บนสุดและกินคลิกทุกครั้ง (บั๊กที่สมุดสอนเล่นเคยเจอ)
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
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
	panel.Size = Responsive.IsSmallScreen() and UDim2.fromScale(0.94, 0.7)
		or UDim2.fromOffset(620, 380)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 12))
	Responsive.Scale(panel)

	local title = label(panel, "หีบเก็บของ", 18, RUNE)
	title.Size = UDim2.new(1, -60, 0, 28)
	title.Position = UDim2.new(0, 14, 0, 10)

	local hint = label(panel, "ของในหีบทุกคนหยิบได้ · หายเมื่อเซิร์ฟเวอร์ปิด", 12, TEXT_MUTED)
	hint.Size = UDim2.new(1, -28, 0, 16)
	hint.Position = UDim2.new(0, 14, 0, 34)

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(30, 30)
	close.BackgroundColor3 = Color3.fromRGB(96, 62, 62)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBold
	close.TextSize = 15
	close.TextColor3 = TEXT_LIGHT
	close.Text = "\195\151"
	close.Parent = panel
	corner(close, UDim.new(0, 8))
	close.Activated:Connect(function()
		UiSound.Play("Click")
		self:Hide()
	end)

	----------------------------------------------------------------------------
	-- สองฝั่ง
	----------------------------------------------------------------------------

	local function column(x, heading)
		local frame = Instance.new("Frame")
		frame.Position = UDim2.new(x, x == 0 and 12 or 6, 0, 60)
		frame.Size = UDim2.new(0.5, -18, 1, -74)
		frame.BackgroundColor3 = STONE_DEEP
		frame.BorderSizePixel = 0
		frame.Parent = panel
		corner(frame, UDim.new(0, 10))

		local head = label(frame, heading, 13, TEXT_MUTED)
		head.Size = UDim2.new(1, -16, 0, 20)
		head.Position = UDim2.new(0, 10, 0, 6)

		local scroll = Instance.new("ScrollingFrame")
		scroll.Position = UDim2.new(0, 8, 0, 30)
		scroll.Size = UDim2.new(1, -16, 1, -38)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 5
		scroll.CanvasSize = UDim2.new()
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.Parent = frame

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 5)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = scroll

		return scroll
	end

	self.chestList = column(0, "ในหีบ")
	self.bagList = column(0.5, "กระเป๋าของคุณ")

	return self
end

function StorageChestGui:On(name, fn)
	self.callbacks[name] = fn
end

function StorageChestGui:fire(name, ...)
	local fn = self.callbacks[name]
	if fn then fn(...) end
end

--------------------------------------------------------------------------------
-- แถวหนึ่งแถว
--------------------------------------------------------------------------------

local function row(parent, order, text, buttonText, onClick)
	local holder = Instance.new("Frame")
	holder.LayoutOrder = order
	holder.Size = UDim2.new(1, -4, 0, 34)
	holder.BackgroundColor3 = SLOT_BG
	holder.BorderSizePixel = 0
	holder.Parent = parent
	corner(holder, UDim.new(0, 7))

	local name = label(holder, text, 13, TEXT_LIGHT)
	name.Size = UDim2.new(1, -62, 1, 0)
	name.Position = UDim2.new(0, 9, 0, 0)
	name.TextTruncate = Enum.TextTruncate.AtEnd

	if onClick then
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -6, 0.5, 0)
		b.Size = UDim2.fromOffset(46, 24)
		b.BackgroundColor3 = Color3.fromRGB(58, 78, 56)
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 12
		b.TextColor3 = TEXT_LIGHT
		b.Text = buttonText
		b.Parent = holder
		corner(b, UDim.new(0, 6))
		b.Activated:Connect(function()
			UiSound.Play("Click")
			onClick()
		end)
	end
	return holder
end

local function clear(list)
	for _, c in ipairs(list:GetChildren()) do
		if not c:IsA("UIListLayout") then c:Destroy() end
	end
end

--------------------------------------------------------------------------------
-- วาด
--------------------------------------------------------------------------------

-- `contents` คือภาพของหีบทั้งใบ ช่องว่างเป็น false
function StorageChestGui:SetChest(contents, slotCount)
	clear(self.chestList)
	for i = 1, (slotCount or #contents) do
		local slot = contents[i]
		if slot then
			local name = ItemCatalog.DisplayName(slot.id, slot.meta) or slot.id
			local text = (slot.count or 1) > 1 and ("%s x%d"):format(name, slot.count) or name
			row(self.chestList, i, text, "หยิบ", function()
				self:fire("take", i, slot.count or 1)
			end)
		else
			local empty = row(self.chestList, i, "— ว่าง —", nil, nil)
			empty.BackgroundTransparency = 0.6
		end
	end
end

-- `slots` คือช่องกระเป๋าจริงของผู้เล่น { [index] = slot }
function StorageChestGui:SetBag(slots)
	clear(self.bagList)
	local order = 0
	for index = 1, 36 do
		local slot = slots and slots[index]
		if slot then
			order += 1
			local name = ItemCatalog.DisplayName(slot.id, slot.meta) or slot.id
			local text = (slot.count or 1) > 1 and ("%s x%d"):format(name, slot.count) or name
			row(self.bagList, order, text, "ใส่", function()
				self:fire("put", index, slot.count or 1)
			end)
		end
	end
	if order == 0 then
		local empty = row(self.bagList, 1, "กระเป๋าว่าง", nil, nil)
		empty.BackgroundTransparency = 0.6
	end
end

function StorageChestGui:Show()
	self.gui.Enabled = true
end

function StorageChestGui:Hide()
	if not self.gui.Enabled then return end
	self.gui.Enabled = false
	self:fire("close")
end

function StorageChestGui:IsOpen()
	return self.gui.Enabled
end

return StorageChestGui
