-- ChestGui: what was inside the chest you just opened, and the two ways to take it.
--
-- Built like AdminChestGui -- same stone, same grid, same corner radii -- because it is the same gesture:
-- a pile of things, and a tap to move one into your bag. The differences are the ones that matter: this
-- pile is finite, it was rolled a second ago, and closing this window destroys whatever is left.
--
-- Pure builder. It draws the loot it is handed and reports taps through callbacks; the server owns the list
-- and every decision about it.
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)
local ItemCatalog = require(script.Parent.Parent.ItemCatalog)
local ItemIcon = require(script.Parent.ItemIcon)
local ChestConfig = require(script.Parent.Parent.ChestConfig)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local GOLD = Color3.fromRGB(226, 184, 78)

local TILE = 84

local ChestGui = {}
ChestGui.__index = ChestGui

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

local function stroke(inst, colour, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Transparency = transparency or 0.5
	s.Thickness = thickness or 1
	s.Parent = inst
	return s
end

function ChestGui.new()
	local self = setmetatable({}, ChestGui)
	self.callbacks = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "ChestGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 19
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	-- Tapping the backdrop closes, which DESTROYS the chest. That is the user's rule, so the button says so
	-- rather than the window closing quietly and the loot being gone without explanation.
	local backdrop = Instance.new("TextButton")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.Parent = gui
	backdrop.Activated:Connect(function() self:fire("close") end)

	local small = Responsive.IsSmallScreen()
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = small and UDim2.fromScale(0.95, 0.8) or UDim2.fromOffset(600, 440)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	stroke(panel, GOLD, 0.5, 2)
	Responsive.Scale(panel)
	self.panel = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -24, 0, 30)
	title.Position = UDim2.new(0, 12, 0, 12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 19
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = GOLD
	title.Text = "หีบสมบัติ"
	title.Parent = panel
	self.title = title

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, -24, 0, 18)
	hint.Position = UDim2.new(0, 12, 0, 40)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 12
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = TEXT_MUTED
	hint.Text = "แตะของเพื่อเก็บทีละชิ้น · ปิดหน้านี้แล้วหีบจะหายถาวร"
	hint.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Name = "Loot"
	list.Position = UDim2.new(0, 12, 0, 66)
	list.Size = UDim2.new(1, -24, 1, -122)
	list.BackgroundColor3 = STONE_DEEP
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	corner(list, UDim.new(0, 10))
	self.list = list

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.Parent = list

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(TILE, TILE)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.Parent = list

	-- Nothing left in the chest. Kept as its own label rather than an empty grid, because an empty box with
	-- no explanation reads as a bug.
	local empty = Instance.new("TextLabel")
	empty.Size = UDim2.fromScale(1, 1)
	empty.BackgroundTransparency = 1
	empty.Font = Enum.Font.Gotham
	empty.TextSize = 14
	empty.TextColor3 = TEXT_MUTED
	empty.Text = "หีบว่างเปล่า"
	empty.Visible = false
	empty.Parent = list
	self.empty = empty

	local takeAll = Instance.new("TextButton")
	takeAll.Name = "TakeAll"
	takeAll.AnchorPoint = Vector2.new(0, 1)
	takeAll.Position = UDim2.new(0, 12, 1, -12)
	takeAll.Size = UDim2.new(0.5, -16, 0, 38)
	takeAll.BackgroundColor3 = Color3.fromRGB(62, 96, 70)
	takeAll.BorderSizePixel = 0
	takeAll.Font = Enum.Font.GothamBold
	takeAll.TextSize = 14
	takeAll.TextColor3 = TEXT_LIGHT
	takeAll.Text = "เก็บทั้งหมด"
	takeAll.Parent = panel
	corner(takeAll, UDim.new(0, 8))
	takeAll.Activated:Connect(function()
		UiSound.Play("Click")
		self:fire("takeAll")
	end)

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 1)
	close.Position = UDim2.new(1, -12, 1, -12)
	close.Size = UDim2.new(0.5, -16, 0, 38)
	close.BackgroundColor3 = Color3.fromRGB(96, 62, 62)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBold
	close.TextSize = 14
	close.TextColor3 = TEXT_LIGHT
	close.Text = "ปิด (หีบหายถาวร)"
	close.Parent = panel
	corner(close, UDim.new(0, 8))
	close.Activated:Connect(function()
		UiSound.Play("Click")
		self:fire("close")
	end)

	return self
end

function ChestGui:On(name, fn)
	self.callbacks[name] = fn
end

function ChestGui:fire(name, ...)
	local fn = self.callbacks[name]
	if fn then fn(...) end
end

-- Draws the chest's contents. Rebuilt from scratch each time rather than patched: a chest holds at most
-- three rows, so there is nothing to save by being clever, and a stale tile would hand over the wrong thing.
function ChestGui:Show(tier, loot)
	for _, child in ipairs(self.list:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	local spec = ChestConfig.Chests[tier]
	self.title.Text = spec and spec.name or "หีบสมบัติ"
	if spec and spec.colour then
		self.title.TextColor3 = spec.colour
	end

	loot = loot or {}
	self.empty.Visible = #loot == 0

	for index, row in ipairs(loot) do
		local item = ItemCatalog.Get(row.id)
		local tile = Instance.new("TextButton")
		tile.Name = row.id
		tile.LayoutOrder = index
		tile.BackgroundColor3 = STONE
		tile.BorderSizePixel = 0
		tile.Text = ""
		tile.AutoButtonColor = true
		tile.Parent = self.list
		corner(tile, UDim.new(0, 8))
		stroke(tile, GOLD, 0.75)

		do
			-- วาดช่องรูปเสมอ ไม่มีรูปก็ได้ ⌛ (ItemIcon) แทนช่องว่างที่อ่านไม่ออกว่าตั้งใจหรือพัง
			local icon = Instance.new("ImageLabel")
			icon.Size = UDim2.fromOffset(40, 40)
			icon.Position = UDim2.new(0.5, -20, 0, 8)
			icon.BackgroundTransparency = 1
			ItemIcon.Apply(icon, item and item.icon)
			icon.Parent = tile
		end

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -8, 0, 16)
		name.Position = UDim2.new(0, 4, 0, 50)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.Gotham
		name.TextSize = 10
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextColor3 = TEXT_LIGHT
		name.Text = item and item.name or row.id
		name.Parent = tile

		local count = Instance.new("TextLabel")
		count.Size = UDim2.new(1, -8, 0, 14)
		count.Position = UDim2.new(0, 4, 0, 66)
		count.BackgroundTransparency = 1
		count.Font = Enum.Font.GothamBold
		count.TextSize = 12
		count.TextColor3 = GOLD
		count.Text = ("x%d"):format(row.count or 1)
		count.Parent = tile

		tile.Activated:Connect(function()
			UiSound.Play("Click")
			self:fire("take", index)
		end)
	end

	self.gui.Enabled = true
end

function ChestGui:Hide()
	self.gui.Enabled = false
end

function ChestGui:IsOpen()
	return self.gui.Enabled
end

return ChestGui
