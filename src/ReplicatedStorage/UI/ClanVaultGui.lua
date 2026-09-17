-- ClanVaultGui: คลังแคลน ตาราง 9x9 — ของแคลนซ้าย กระเป๋าเราขวา
--
-- **ตารางแบบเดียวกับกระเป๋า** ตามที่ผู้ใช้สั่ง: ช่องสี่เหลี่ยมมีไอคอนกลางช่องและจำนวนมุมล่างขวา
-- ไม่ใช่รายการแถวยาว — ของในคลังอยู่กับที่ ช่องที่ 5 วันนี้ยังเป็นช่องที่ 5 พรุ่งนี้
--
-- ตัววาดล้วน รายงานการกดออกไปทาง callback ไม่รู้จักระบบเกม
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)
local ItemCatalog = require(script.Parent.Parent.ItemCatalog)
local ClanConfig = require(script.Parent.Parent.ClanConfig)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local SLOT_BG = Color3.fromRGB(26, 25, 32)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)
local GLASS = Color3.fromRGB(120, 124, 140)

local ClanVaultGui = {}
ClanVaultGui.__index = ClanVaultGui

local BAG_COLS = 6
local BAG_SLOTS = 36

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

local function stroke(inst, colour, transparency)
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Transparency = transparency or 0.85
	s.Thickness = 1
	s.Parent = inst
	return s
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

-- ช่องหนึ่งช่อง รูปเดียวกับช่องกระเป๋า
local function makeSlot(parent, order, onClick)
	local slot = Instance.new("TextButton")
	slot.LayoutOrder = order
	slot.BackgroundColor3 = SLOT_BG
	slot.BackgroundTransparency = 0.25
	slot.Text = ""
	slot.AutoButtonColor = true
	slot.Parent = parent
	corner(slot, UDim.new(0, 6))
	local edge = stroke(slot, GLASS, 0.85)

	-- ไอคอนก่อน ชื่อเป็นตัวสำรอง: ของที่มีรูปซ่อนชื่อ ของที่ไม่มีรูปโชว์ชื่อแทน (กฎเดียวกับกระเป๋า)
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(1, -6, 1, -6)
	icon.Position = UDim2.new(0, 3, 0, 3)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = ""
	icon.Visible = false
	icon.Parent = slot

	local name = label(slot, "", 9, TEXT_LIGHT, Enum.TextXAlignment.Center)
	name.Size = UDim2.new(1, -4, 1, -14)
	name.Position = UDim2.new(0, 2, 0, 2)
	name.TextWrapped = true

	local count = label(slot, "", 10, RUNE, Enum.TextXAlignment.Right)
	count.Size = UDim2.new(1, -4, 0, 12)
	count.Position = UDim2.new(0, 2, 1, -13)

	slot.Activated:Connect(function()
		UiSound.Play("Click")
		onClick()
	end)

	return { button = slot, icon = icon, name = name, count = count, stroke = edge }
end

local function fillSlot(cell, entry)
	if not entry then
		cell.icon.Visible = false
		cell.name.Text = ""
		cell.count.Text = ""
		cell.stroke.Transparency = 0.9
		return
	end
	local hasIcon = entry.icon and entry.icon ~= ""
	cell.icon.Image = hasIcon and entry.icon or ""
	cell.icon.Visible = hasIcon
	cell.name.Text = hasIcon and "" or (entry.name or entry.id or "")
	cell.count.Text = (entry.count or 1) > 1 and ("x%d"):format(entry.count) or ""
	cell.stroke.Transparency = 0.5
end

function ClanVaultGui.new()
	local self = setmetatable({}, ClanVaultGui)
	self.callbacks = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "ClanVaultGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 21
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
	panel.Size = Responsive.IsSmallScreen() and UDim2.fromScale(0.97, 0.9)
		or UDim2.fromOffset(780, 500)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 12))
	Responsive.Scale(panel)

	local title = label(panel, "คลังแคลน", 17, RUNE)
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
	-- ฝั่งซ้าย: คลังแคลน 9x9
	----------------------------------------------------------------------------

	local left = Instance.new("Frame")
	left.Position = UDim2.new(0, 12, 0, 42)
	left.Size = UDim2.new(0.58, -16, 1, -54)
	left.BackgroundColor3 = STONE_DEEP
	left.BorderSizePixel = 0
	left.Parent = panel
	corner(left, UDim.new(0, 10))

	local leftHead = label(left, "ของในคลัง", 12, TEXT_MUTED)
	leftHead.Position = UDim2.new(0, 10, 0, 6)
	leftHead.Size = UDim2.new(1, -20, 0, 18)
	self.leftHead = leftHead

	local vaultGrid = Instance.new("Frame")
	vaultGrid.Position = UDim2.new(0, 8, 0, 28)
	vaultGrid.Size = UDim2.new(1, -16, 1, -36)
	vaultGrid.BackgroundTransparency = 1
	vaultGrid.Parent = left

	local vLayout = Instance.new("UIGridLayout")
	-- ขนาดช่องคิดจากจำนวนแถว/คอลัมน์ในคอนฟิก ไม่ได้ฝัง 9 ไว้ — แก้คอนฟิกแล้วตารางตามเอง
	vLayout.CellSize = UDim2.new(1 / ClanConfig.VaultCols, -4, 1 / ClanConfig.VaultRows, -4)
	vLayout.CellPadding = UDim2.fromOffset(4, 4)
	vLayout.SortOrder = Enum.SortOrder.LayoutOrder
	vLayout.Parent = vaultGrid

	self.vaultCells = {}
	for i = 1, ClanConfig.VaultSlots do
		self.vaultCells[i] = makeSlot(vaultGrid, i, function()
			self:fire("take", i)
		end)
	end

	----------------------------------------------------------------------------
	-- ฝั่งขวา: กระเป๋าเรา
	----------------------------------------------------------------------------

	local right = Instance.new("Frame")
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.new(1, -12, 0, 42)
	right.Size = UDim2.new(0.42, -8, 1, -54)
	right.BackgroundColor3 = STONE_DEEP
	right.BorderSizePixel = 0
	right.Parent = panel
	corner(right, UDim.new(0, 10))

	local rightHead = label(right, "กระเป๋าของคุณ", 12, TEXT_MUTED)
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

	return self
end

function ClanVaultGui:On(name, fn) self.callbacks[name] = fn end
function ClanVaultGui:fire(name, ...)
	local fn = self.callbacks[name]
	if fn then fn(...) end
end

--------------------------------------------------------------------------------
-- วาด
--------------------------------------------------------------------------------

function ClanVaultGui:SetVault(clan)
	local used = 0
	for i = 1, ClanConfig.VaultSlots do
		local entry = clan and clan.vault and clan.vault[i]
		-- เซิร์ฟเวอร์ส่ง false สำหรับช่องว่าง ไม่ใช่ nil
		if entry == false then entry = nil end
		if entry then used += 1 end
		fillSlot(self.vaultCells[i], entry)
	end
	self.title.Text = clan and ("คลังแคลน — %s"):format(clan.name) or "คลังแคลน"
	self.leftHead.Text = ("ของในคลัง %d/%d ช่อง"):format(used, ClanConfig.VaultSlots)
end

function ClanVaultGui:SetBag(slots)
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

function ClanVaultGui:Show(clan, bag)
	self:SetVault(clan)
	self:SetBag(bag)
	self.gui.Enabled = true
end

function ClanVaultGui:Hide()
	if not self.gui.Enabled then return end
	self.gui.Enabled = false
	self:fire("close")
end

function ClanVaultGui:IsOpen() return self.gui.Enabled end

return ClanVaultGui
