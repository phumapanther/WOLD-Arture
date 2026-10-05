-- TownVaultGui: คลังเมือง — ของในคลังซ้าย · กระเป๋าเราขวาบน · **บันทึกเข้า-ออก 10 รายการล่าสุด** ขวาล่าง
--
-- หน้าตาเป็นญาติกับคลังแคลน (ตารางช่องแบบเดียวกับกระเป๋า) แต่เป็นคนละหน้าต่าง เพราะมันคือของคนละกอง
-- ที่เปิดคนละที่ และอันนี้มีบันทึกซึ่งคลังแคลนไม่มี — **บันทึกคือเหตุผลที่คลังนี้ปล่อยให้ทุกคนหยิบออกได้**
-- ถ้าเอามันออกไป สิ่งที่เหลือคือคลังรวมที่ใครก็กวาดของหายได้เงียบๆ
--
-- ตัววาดล้วน รายงานการกดออกทาง callback ไม่รู้จักระบบเกม
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)
local ItemIcon = require(script.Parent.ItemIcon)
local ItemCatalog = require(script.Parent.Parent.ItemCatalog)
local ClanConfig = require(script.Parent.Parent.ClanConfig)
local Locale = require(script.Parent.Parent.Locale)
local L, Show = Locale.L, Locale.Show

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local SLOT_BG = Color3.fromRGB(26, 25, 32)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)
local IN_COLOUR = Color3.fromRGB(120, 190, 120)
local OUT_COLOUR = Color3.fromRGB(214, 120, 110)

local BAG_COLS = 6
local BAG_SLOTS = 36

local TownVaultGui = {}
TownVaultGui.__index = TownVaultGui

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
	l.TextSize = size or 12
	l.TextColor3 = colour or TEXT_LIGHT
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

local function makeSlot(parent, order, onClick)
	local slot = Instance.new("TextButton")
	slot.LayoutOrder = order
	slot.BackgroundColor3 = SLOT_BG
	slot.BackgroundTransparency = 0.25
	slot.BorderSizePixel = 0
	slot.AutoButtonColor = true
	slot.Text = ""
	slot.Parent = parent
	corner(slot, UDim.new(0, 6))

	local slotStroke = Instance.new("UIStroke")
	slotStroke.Color = Color3.fromRGB(120, 124, 140)
	slotStroke.Transparency = 0.9
	slotStroke.Thickness = 1
	slotStroke.Parent = slot

	local icon = Instance.new("ImageLabel")
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.45)
	icon.Size = UDim2.fromScale(0.7, 0.7)
	icon.BackgroundTransparency = 1
	icon.Visible = false
	icon.Parent = slot

	local name = label(slot, "", 9, TEXT_MUTED, Enum.TextXAlignment.Center)
	name.Position = UDim2.fromScale(0, 0.1)
	name.Size = UDim2.fromScale(1, 0.55)
	name.TextWrapped = true

	local count = label(slot, "", 10, RUNE, Enum.TextXAlignment.Right)
	count.AnchorPoint = Vector2.new(1, 1)
	count.Position = UDim2.new(1, -3, 1, -1)
	count.Size = UDim2.fromOffset(30, 12)

	slot.Activated:Connect(function()
		UiSound.Play("Click")
		onClick()
	end)
	return { button = slot, icon = icon, name = name, count = count, stroke = slotStroke }
end

local function fillSlot(cell, entry)
	if not entry then
		cell.icon.Visible = false
		cell.name.Text = ""
		cell.count.Text = ""
		cell.stroke.Transparency = 0.9
		return
	end
	local hasIcon = ItemIcon.Has(entry.icon)
	ItemIcon.Apply(cell.icon, entry.icon)
	cell.icon.Visible = true
	cell.name.Text = hasIcon and "" or Show(entry.name or entry.id or "") -- ชื่อจากเซิร์ฟเป็นไทย
	cell.count.Text = (entry.count or 1) > 1 and ("x%d"):format(entry.count) or ""
	cell.stroke.Transparency = 0.5
end

-- "เมื่อสักครู่" / "12 นาทีที่แล้ว" / "3 ชม.ที่แล้ว" — เวลาของบันทึกเป็น os.time() ของเซิร์ฟเวอร์
-- ซึ่งเป็นเวลาจริง ใช้ข้ามเซิร์ฟเวอร์ได้ (ของในคลังก็ถูกฝากมาจากเซิร์ฟเวอร์อื่นได้เหมือนกัน)
local function agoText(at)
	if not at then return "" end
	local seconds = math.max(0, os.time() - at)
	if seconds < 60 then return L("เมื่อสักครู่") end
	if seconds < 3600 then return L("%d นาทีที่แล้ว", math.floor(seconds / 60)) end
	if seconds < 86400 then return L("%d ชม.ที่แล้ว", math.floor(seconds / 3600)) end
	return L("%d วันที่แล้ว", math.floor(seconds / 86400))
end

function TownVaultGui.new()
	local self = setmetatable({}, TownVaultGui)
	self.callbacks = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "TownVaultGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 21
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

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
	panel.Size = Responsive.IsSmallScreen() and UDim2.fromScale(0.97, 0.9)
		or UDim2.fromOffset(820, 500)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 12))
	Responsive.Scale(panel, Responsive.IsSmallScreen() and 0.95 or nil) -- มือถือ: แผงเต็มจออยู่แล้ว ห้ามย่อซ้ำ (QA 2026-09-26)

	local title = label(panel, L("คลังเมือง"), 17, RUNE)
	title.Position = UDim2.new(0, 16, 0, 10)
	title.Size = UDim2.new(1, -60, 0, 24)
	self.title = title

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
	-- ซ้าย: ของในคลัง
	----------------------------------------------------------------------------

	local left = Instance.new("Frame")
	left.Position = UDim2.new(0, 12, 0, 42)
	left.Size = UDim2.new(0.56, -16, 1, -54)
	left.BackgroundColor3 = STONE_DEEP
	left.BorderSizePixel = 0
	left.Parent = panel
	corner(left, UDim.new(0, 10))

	local leftHead = label(left, L("ของในคลัง"), 12, TEXT_MUTED)
	leftHead.Position = UDim2.new(0, 10, 0, 6)
	leftHead.Size = UDim2.new(1, -20, 0, 18)
	self.leftHead = leftHead

	local grid = Instance.new("Frame")
	grid.Position = UDim2.new(0, 8, 0, 28)
	grid.Size = UDim2.new(1, -16, 1, -36)
	grid.BackgroundTransparency = 1
	grid.Parent = left

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / ClanConfig.TownVaultCols, -4, 1 / ClanConfig.TownVaultRows, -4)
	layout.CellPadding = UDim2.fromOffset(4, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	self.cells = {}
	for i = 1, ClanConfig.TownVaultSlots do
		self.cells[i] = makeSlot(grid, i, function()
			self:fire("take", i)
		end)
	end

	----------------------------------------------------------------------------
	-- ขวาบน: กระเป๋าเรา
	----------------------------------------------------------------------------

	local right = Instance.new("Frame")
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.new(1, -12, 0, 42)
	right.Size = UDim2.new(0.44, -8, 0.62, -40)
	right.BackgroundColor3 = STONE_DEEP
	right.BorderSizePixel = 0
	right.Parent = panel
	corner(right, UDim.new(0, 10))

	local rightHead = label(right, L("กระเป๋าของคุณ"), 12, TEXT_MUTED)
	rightHead.Position = UDim2.new(0, 10, 0, 6)
	rightHead.Size = UDim2.new(1, -20, 0, 18)

	local bagGrid = Instance.new("Frame")
	bagGrid.Position = UDim2.new(0, 8, 0, 28)
	bagGrid.Size = UDim2.new(1, -16, 1, -36)
	bagGrid.BackgroundTransparency = 1
	bagGrid.Parent = right

	local bLayout = Instance.new("UIGridLayout")
	bLayout.CellSize = UDim2.new(1 / BAG_COLS, -4, 0, 44)
	bLayout.CellPadding = UDim2.fromOffset(4, 4)
	bLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bLayout.Parent = bagGrid

	self.bagCells = {}
	for i = 1, BAG_SLOTS do
		self.bagCells[i] = makeSlot(bagGrid, i, function()
			self:fire("put", i)
		end)
	end

	----------------------------------------------------------------------------
	-- ขวาล่าง: บันทึกเข้า-ออก
	----------------------------------------------------------------------------

	local logPane = Instance.new("Frame")
	logPane.AnchorPoint = Vector2.new(1, 1)
	logPane.Position = UDim2.new(1, -12, 1, -12)
	logPane.Size = UDim2.new(0.44, -8, 0.38, -8)
	logPane.BackgroundColor3 = STONE_DEEP
	logPane.BorderSizePixel = 0
	logPane.Parent = panel
	corner(logPane, UDim.new(0, 10))

	local logHead = label(logPane, L("บันทึกล่าสุด %d ครั้ง", ClanConfig.TownVaultLogSize), 12, TEXT_MUTED)
	logHead.Position = UDim2.new(0, 10, 0, 6)
	logHead.Size = UDim2.new(1, -20, 0, 18)

	local logList = Instance.new("ScrollingFrame")
	logList.Position = UDim2.new(0, 8, 0, 26)
	logList.Size = UDim2.new(1, -16, 1, -34)
	logList.BackgroundTransparency = 1
	logList.BorderSizePixel = 0
	logList.ScrollBarThickness = 4
	logList.CanvasSize = UDim2.new()
	logList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	logList.Parent = logPane

	local logLayout = Instance.new("UIListLayout")
	logLayout.Padding = UDim.new(0, 2)
	logLayout.SortOrder = Enum.SortOrder.LayoutOrder
	logLayout.Parent = logList
	self.logList = logList

	return self
end

function TownVaultGui:On(name, fn) self.callbacks[name] = fn end
function TownVaultGui:fire(name, ...)
	local fn = self.callbacks[name]
	if fn then fn(...) end
end

--------------------------------------------------------------------------------
-- วาด
--------------------------------------------------------------------------------

function TownVaultGui:SetVault(data)
	for i = 1, ClanConfig.TownVaultSlots do
		local entry = data and data.slots and data.slots[i]
		if entry == false then entry = nil end
		fillSlot(self.cells[i], entry)
	end

	-- ชื่อเมือง (ไทยจากเซิร์ฟ) แปลเป็นอาร์กิวเมนต์ของ L · ชื่อแคลนผู้เล่นตั้งเอง
	if not data then
		self.title.Text = L("คลังเมือง")
	elseif data.clanName then
		self.title.Text = L("คลังเมือง — %s · แคลน %s", data.townName or "", data.clanName)
	else
		self.title.Text = L("คลังเมือง — %s", data.townName or "")
	end
	self.leftHead.Text = data
		and L("ของในคลัง %d/%d ช่อง", data.used or 0, data.total or ClanConfig.TownVaultSlots)
		or L("ของในคลัง")

	for _, child in ipairs(self.logList:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end
	local rows = data and data.log or {}
	if #rows == 0 then
		local empty = label(self.logList, L("ยังไม่มีใครเอาของเข้าหรือออก"), 11, TEXT_MUTED)
		empty.LayoutOrder = 1
		empty.Size = UDim2.new(1, 0, 0, 18)
		return
	end
	for index, row in ipairs(rows) do
		-- ลูกศรบอกทิศทางแทนคำว่า "ฝาก/ถอน": อ่านเร็วกว่าและแยกสีได้ชัดในรายการที่ยาวเท่ากันหมด
		local arrow = row.action == "out" and "\226\172\134" or "\226\172\135"
		local line = label(self.logList,
			("%s %s — %s x%d · %s"):format(arrow, row.name or "?", Show(row.itemName or "?"), row.count or 1,
				agoText(row.at)),
			11, row.action == "out" and OUT_COLOUR or IN_COLOUR)
		line.LayoutOrder = index
		line.Size = UDim2.new(1, 0, 0, 18)
		line.TextTruncate = Enum.TextTruncate.AtEnd
	end
end

function TownVaultGui:SetBag(slots)
	for i = 1, BAG_SLOTS do
		local slot = slots and slots[i]
		local entry = nil
		if slot then
			local item = ItemCatalog.Get(slot.id)
			entry = {
				id = slot.id,
				count = slot.count or 1,
				name = ItemCatalog.DisplayName(slot.id, slot.meta) or slot.id,
				icon = item and item.icon or "",
			}
		end
		fillSlot(self.bagCells[i], entry)
	end
end

function TownVaultGui:Show(data, bag)
	self:SetVault(data)
	self:SetBag(bag)
	self.gui.Enabled = true
end

function TownVaultGui:Hide()
	if not self.gui.Enabled then return end
	self.gui.Enabled = false
	self:fire("close")
end

function TownVaultGui:IsOpen() return self.gui.Enabled end

return TownVaultGui
