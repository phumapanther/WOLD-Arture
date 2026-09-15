-- AdminChestGui: every item in the game, in a grid, with a button that hands one over.
--
-- The chest this opens from used to give one of everything, once a day. The user asked for the opposite
-- shape: the whole catalogue laid out, and any of it taken as often as wanted. So the list is not a reward
-- to be claimed, it is a shelf to be picked from, and the interface that fits that is a search box and a
-- grid rather than one button.
--
-- Built from ItemCatalog, so an item added tomorrow is on the shelf tomorrow with nothing else to change.
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)
local ItemCatalog = require(script.Parent.Parent.ItemCatalog)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local ROW = Color3.fromRGB(46, 42, 62)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(198, 166, 255) -- the chest's own violet, so it does not read as the shop

local TILE = 84

local AdminChestGui = {}
AdminChestGui.__index = AdminChestGui

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

local function stroke(inst, colour, transparency)
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Transparency = transparency or 0.6
	s.Parent = inst
	return s
end

local function label(parent, text, size, colour, bold)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	l.TextSize = size
	l.TextColor3 = colour
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
	corner(b, UDim.new(0, 6))
	b.Activated:Connect(function()
		UiSound.Play("Click")
		onClick()
	end)
	return b
end

-- Every item, sorted by kind and then by name, so weapons sit with weapons rather than the catalogue's own
-- hash order scattering them.
local function catalogue()
	local out = {}
	for id, item in pairs(ItemCatalog.Items) do
		table.insert(out, { id = id, item = item })
	end
	table.sort(out, function(a, b)
		if a.item.kind ~= b.item.kind then return (a.item.kind or "") < (b.item.kind or "") end
		return (a.item.name or a.id) < (b.item.name or b.id)
	end)
	return out
end

function AdminChestGui.new()
	local self = setmetatable({}, AdminChestGui)
	self.callbacks = {}
	self.tiles = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminChestGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 19
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

	local small = Responsive.IsSmallScreen()
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = small and UDim2.fromScale(0.95, 0.88) or UDim2.fromOffset(640, 500)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	stroke(panel, RUNE, 0.5)
	Responsive.Scale(panel)
	self.panel = panel

	local title = label(panel, "หีบแอดมิน", 19, RUNE, true)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(14, 12)
	title.Size = UDim2.new(1, -120, 0, 28)

	local close = button(panel, "\195\151", Color3.fromRGB(70, 74, 84), TEXT_LIGHT, function() self:Hide() end)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(28, 28)
	close.TextSize = 16

	-- Typed, not scrolled: the catalogue is over fifty items and hunting for one is slower than naming it.
	-- Filters on the id AND the Thai name, because an admin knows an item by either.
	local search = Instance.new("TextBox")
	search.Position = UDim2.fromOffset(14, 46)
	search.Size = UDim2.new(1, -180, 0, 30)
	search.BackgroundColor3 = STONE_DEEP
	search.BorderSizePixel = 0
	search.Font = Enum.Font.Gotham
	search.TextSize = 13
	search.TextColor3 = TEXT_LIGHT
	search.PlaceholderText = "ค้นหาไอเทม..."
	search.PlaceholderColor3 = TEXT_MUTED
	search.ClearTextOnFocus = false
	search.Text = ""
	search.Parent = panel
	corner(search, UDim.new(0, 6))
	search:GetPropertyChangedSignal("Text"):Connect(function() self:filter(search.Text) end)

	-- Money, which is not in the catalogue and is the thing most often wanted.
	local gold = button(panel, "+1,000 เหรียญ", Color3.fromRGB(150, 120, 60), Color3.fromRGB(24, 22, 16),
		function()
			if self.callbacks.gold then self.callbacks.gold(1000) end
		end)
	gold.AnchorPoint = Vector2.new(1, 0)
	gold.Position = UDim2.new(1, -14, 0, 46)
	gold.Size = UDim2.fromOffset(150, 30)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 86)
	list.Size = UDim2.new(1, -24, 1, -120)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	self.list = list

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(TILE, TILE)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.Parent = list

	self.hint = "แตะ = 1 ชิ้น · ปุ่มมุมขวาบน = เต็มกอง · เอาได้ไม่จำกัด"
	self.status = label(panel, self.hint, 11, TEXT_MUTED)
	self.status.TextXAlignment = Enum.TextXAlignment.Left
	self.status.AnchorPoint = Vector2.new(0, 1)
	self.status.Position = UDim2.new(0, 14, 1, -10)
	self.status.Size = UDim2.new(1, -28, 0, 20)

	self:build()
	return self
end

function AdminChestGui:build()
	for order, row in ipairs(catalogue()) do
		local id, item = row.id, row.item
		local stack = ItemCatalog.StackSize(id)

		local tile = Instance.new("TextButton")
		tile.Name = id
		tile.LayoutOrder = order
		tile.BackgroundColor3 = ROW
		tile.AutoButtonColor = true
		tile.BorderSizePixel = 0
		tile.Text = ""
		tile.Parent = self.list
		corner(tile, UDim.new(0, 8))
		stroke(tile, RUNE, 0.8)

		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Image = item.icon or ""
		icon.ScaleType = Enum.ScaleType.Fit
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 8)
		icon.Size = UDim2.fromOffset(34, 34)
		icon.Parent = tile

		-- An item with no icon uploaded yet would be a blank square with a name under it, which reads as a
		-- broken tile rather than a new one. Its first letters stand in until the art arrives -- and a new
		-- item is exactly the case that hits this, since icons are uploaded by hand well after the item
		-- itself exists.
		if (item.icon or "") == "" then
			local glyph = label(icon, (item.name or id):sub(1, 6), 12, TEXT_MUTED, true)
			glyph.Size = UDim2.fromScale(1, 1)
			glyph.TextXAlignment = Enum.TextXAlignment.Center
			glyph.TextTruncate = Enum.TextTruncate.AtEnd
		end

		local name = label(tile, item.name or id, 11, TEXT_LIGHT)
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.new(0.5, 0, 1, -4)
		name.Size = UDim2.new(1, -6, 0, 26)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextWrapped = true

		tile.Activated:Connect(function()
			UiSound.Play("Click")
			if self.callbacks.take then self.callbacks.take(id, 1) end
		end)

		-- A full stack in one press, for the things taken by the handful. Weapons and armour do not stack,
		-- so there is nothing for the button to mean and it is left off.
		if stack > 1 then
			local all = button(tile, "x" .. stack, STONE_DEEP, RUNE, function()
				if self.callbacks.take then self.callbacks.take(id, stack) end
			end)
			all.AnchorPoint = Vector2.new(1, 0)
			all.Position = UDim2.new(1, -4, 0, 4)
			all.Size = UDim2.fromOffset(30, 16)
			all.TextSize = 10
		end

		self.tiles[#self.tiles + 1] = { tile = tile, hay = (id .. " " .. (item.name or "")):lower() }
	end
end

-- Hiding rather than rebuilding: the grid is over fifty buttons, and destroying and remaking them on every
-- keystroke is visible as a stutter.
function AdminChestGui:filter(text)
	local needle = (text or ""):lower()
	local shown = 0
	for _, row in ipairs(self.tiles) do
		local match = needle == "" or row.hay:find(needle, 1, true) ~= nil
		row.tile.Visible = match
		if match then shown += 1 end
	end
	self.status.Text = needle == "" and self.hint or ("พบ %d ไอเทม"):format(shown)
end

function AdminChestGui:On(name, fn)
	self.callbacks[name] = fn
end

function AdminChestGui:Show() self.gui.Enabled = true end
function AdminChestGui:Hide() self.gui.Enabled = false end
function AdminChestGui:IsOpen() return self.gui.Enabled end

return AdminChestGui
