-- InventoryGui: the bag screen — a centred glass panel with the slot grid, the two equipment slots, the gold
-- and weight readouts, an auto-sort button and a close cross.
--
-- Pure UI builder, like HudGui: it draws what it is handed and reports clicks through callbacks. The
-- controller owns every decision and the server owns the data.
local ItemCatalog = require(script.Parent.Parent.ItemCatalog)
local InventoryConfig = require(script.Parent.Parent.InventoryConfig)
local Responsive = require(script.Parent.Responsive)

local InventoryGui = {}
InventoryGui.__index = InventoryGui

-- Same palette as the lobby, so the two screens read as one game.
local ACCENT = Color3.fromRGB(216, 172, 84)
local TEXT_LIGHT = Color3.fromRGB(240, 240, 245)
local TEXT_MUTED = Color3.fromRGB(180, 180, 195)
local GLASS = Color3.fromRGB(255, 255, 255)
local SLOT_BG = Color3.fromRGB(26, 25, 32)
local PANEL_BG = Color3.fromRGB(14, 13, 18)

local COLS = 6
-- Rows follow the bag size rather than being written down twice: change SlotCount and the grid follows.
local ROWS = math.ceil(InventoryConfig.SlotCount / COLS)

-- Colour-codes the slot border by what is in it, so a bag reads at a glance without icon art.
local KIND_TINT = {
	weapon = Color3.fromRGB(198, 96, 84),
	armor = Color3.fromRGB(110, 146, 196),
	consumable = Color3.fromRGB(104, 184, 118),
	junk = Color3.fromRGB(130, 126, 120),
}

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 8)
	c.Parent = parent
	return c
end

local function stroke(parent, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or GLASS
	s.Transparency = transparency or 0.75
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

local function label(parent, text, size, color, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size
	l.TextColor3 = color or TEXT_LIGHT
	l.Text = text
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

function InventoryGui.new()
	local self = setmetatable({}, InventoryGui)
	self.slotButtons = {}
	self.onSlotClicked = nil
	self.onEquipSlotClicked = nil

	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 15 -- under the downed overlay (20), above the HUD
	gui.Enabled = false
	self.gui = gui

	-- Click-catcher behind the panel: clicking outside closes the bag.
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.55
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Parent = gui
	self.backdrop = backdrop

	-- The panel itself. Sized in SCALE so it can never exceed a phone screen, with a max size so it does not
	-- become a billboard on a desktop monitor.
	-- A phone gets nearly the whole screen: at 0.72x0.78 of an 844x390 landscape phone the grid's square
	-- cells came out 20px a side, which is smaller than a fingertip. Desktop keeps the smaller panel, since
	-- there a full-screen bag would be a billboard.
	local small = Responsive.IsSmallScreen()
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = small and UDim2.fromScale(0.94, 0.94) or UDim2.fromScale(0.72, 0.78)
	panel.BackgroundColor3 = PANEL_BG
	panel.BackgroundTransparency = 0.18 -- "โปร่งใสเล็กน้อย"
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	stroke(panel, ACCENT, 0.55, 1.5)
	local panelSize = Instance.new("UISizeConstraint")
	panelSize.MaxSize = Vector2.new(760, 560)
	-- No MinSize on a phone: a floor taller than the screen is what pushed the panel off the bottom edge.
	panelSize.MinSize = small and Vector2.new(240, 180) or Vector2.new(280, 220)
	panelSize.Parent = panel
	self.panel = panel

	-- Header: title, gold, weight, close cross.
	local title = label(panel, "กระเป๋า", 20, ACCENT)
	title.Size = UDim2.new(0.4, 0, 0, 30)
	title.Position = UDim2.new(0, 18, 0, 12)
	title.Font = Enum.Font.GothamBold

	local goldLabel = label(panel, "0", 15, ACCENT, Enum.TextXAlignment.Right)
	goldLabel.Size = UDim2.new(0.3, 0, 0, 18)
	goldLabel.Position = UDim2.new(0.66, 0, 0, 14)
	self.goldLabel = goldLabel

	local weightLabel = label(panel, "0 / 0", 13, TEXT_MUTED, Enum.TextXAlignment.Right)
	weightLabel.Size = UDim2.new(0.3, 0, 0, 16)
	weightLabel.Position = UDim2.new(0.66, 0, 0, 33)
	self.weightLabel = weightLabel

	local close = Instance.new("TextButton")
	close.Name = "CloseButton"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(30, 30)
	close.BackgroundColor3 = Color3.fromRGB(52, 48, 56)
	close.BackgroundTransparency = 0.25
	close.Font = Enum.Font.GothamBold
	close.TextSize = 18
	close.TextColor3 = TEXT_LIGHT
	close.Text = "\195\151" -- multiplication sign, a cleaner cross than "x"
	close.Parent = panel
	corner(close, UDim.new(1, 0))
	stroke(close, GLASS, 0.6)
	self.closeButton = close

	--------------------------------------------------------------------------
	-- Equipment column (left): weapon and armor.
	--------------------------------------------------------------------------
	local equipColumn = Instance.new("Frame")
	equipColumn.Name = "Equipment"
	equipColumn.Position = UDim2.new(0, 18, 0, 62)
	equipColumn.Size = UDim2.new(0.26, 0, 1, -110)
	equipColumn.BackgroundTransparency = 1
	equipColumn.Parent = panel

	self.equipSlots = {}
	local EQUIP_ORDER = { { key = "weapon", text = "อาวุธ" }, { key = "armor", text = "เกราะ" } }
	for i, entry in ipairs(EQUIP_ORDER) do
		local holder = Instance.new("TextButton")
		holder.Name = entry.key
		-- Square, like the bag slots. The height is a SCALE of the column (which is tall enough for two of
		-- them plus a gap) and the aspect constraint then matches the width to it; sizing the height to zero
		-- and hoping the constraint would fill it in collapsed the slot to nothing.
		holder.Size = UDim2.new(1, 0, 0.42, 0)
		holder.Position = UDim2.new(0, 0, (i - 1) * 0.52, 0)
		holder.BackgroundColor3 = SLOT_BG
		holder.BackgroundTransparency = 0.15
		holder.Text = ""
		holder.AutoButtonColor = true
		holder.Parent = equipColumn
		corner(holder, UDim.new(0, 10))
		local holderAspect = Instance.new("UIAspectRatioConstraint")
		holderAspect.AspectRatio = 1
		holderAspect.DominantAxis = Enum.DominantAxis.Height
		holderAspect.Parent = holder
		local holderStroke = stroke(holder, ACCENT, 0.7)

		local caption = label(holder, entry.text, 11, TEXT_MUTED)
		caption.Size = UDim2.new(1, -12, 0, 14)
		caption.Position = UDim2.new(0, 8, 0, 6)

		local name = label(holder, "ว่าง", 14, TEXT_LIGHT)
		name.Size = UDim2.new(1, -12, 0, 20)
		name.Position = UDim2.new(0, 8, 0, 24)
		name.TextTruncate = Enum.TextTruncate.AtEnd

		local durability = label(holder, "", 10, TEXT_MUTED)
		durability.Size = UDim2.new(1, -12, 0, 14)
		durability.Position = UDim2.new(0, 8, 0, 48)

		-- The slot is square and the text only fills its top, so the artwork goes in the space below it.
		-- Reading what you are wearing off a picture is quicker than reading a name, and the room was
		-- already there.
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.AnchorPoint = Vector2.new(0.5, 1)
		icon.Position = UDim2.new(0.5, 0, 1, -6)
		icon.Size = UDim2.new(0.62, 0, 0.5, 0)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Visible = false
		icon.Parent = holder

		holder.Activated:Connect(function()
			if self.onEquipSlotClicked then self.onEquipSlotClicked(entry.key) end
		end)

		self.equipSlots[entry.key] = { button = holder, name = name, durability = durability,
			stroke = holderStroke, icon = icon }
	end

	--------------------------------------------------------------------------
	-- Slot grid (right).
	--------------------------------------------------------------------------
	local grid = Instance.new("Frame")
	grid.Name = "Slots"
	-- Chrome above and below the grid is fixed pixels, which eats half of a short phone panel; trim it there
	-- so the square cells keep a usable size.
	local chromeTop = small and 46 or 62
	local chromeTotal = small and 74 or 110
	grid.Position = UDim2.new(0.3, 0, 0, chromeTop)
	grid.Size = UDim2.new(0.68, -18, 1, -chromeTotal)
	grid.BackgroundTransparency = 1
	grid.Parent = panel

	-- The grid box is pinned to the COLS:ROWS aspect, which is what keeps square cells fitting. Sizing cells
	-- off the WIDTH alone was fine at 4 rows (they could never be too tall) but overflows at 6: a 280x268 box
	-- gives 46.7px cells, and six of those plus padding need 310px. Constraining the box instead means the
	-- cells stay square AND the last row is always inside it, whatever shape the panel takes.
	local gridAspect = Instance.new("UIAspectRatioConstraint")
	gridAspect.AspectRatio = COLS / ROWS
	gridAspect.DominantAxis = Enum.DominantAxis.Height
	gridAspect.Parent = grid

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / COLS, -6, 1 / ROWS, -6)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for i = 1, COLS * ROWS do
		local slot = Instance.new("TextButton")
		slot.Name = "Slot" .. i
		slot.LayoutOrder = i
		slot.BackgroundColor3 = SLOT_BG
		slot.BackgroundTransparency = 0.25
		slot.Text = ""
		slot.AutoButtonColor = true
		slot.Parent = grid
		corner(slot, UDim.new(0, 8))
		local slotStroke = stroke(slot, GLASS, 0.85)

		-- Icon first, name as the fallback: an item with artwork hides its label, one without shows text.
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(1, -8, 1, -8)
		icon.Position = UDim2.new(0, 4, 0, 4)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Image = ""
		icon.Visible = false
		icon.Parent = slot

		local name = label(slot, "", 11, TEXT_LIGHT, Enum.TextXAlignment.Center)
		name.Size = UDim2.new(1, -6, 1, -18)
		name.Position = UDim2.new(0, 3, 0, 3)
		name.TextWrapped = true

		local count = label(slot, "", 11, ACCENT, Enum.TextXAlignment.Right)
		count.Size = UDim2.new(1, -6, 0, 14)
		count.Position = UDim2.new(0, 3, 1, -16)
		count.Font = Enum.Font.GothamBold

		slot.Activated:Connect(function()
			if self.onSlotClicked then self.onSlotClicked(i) end
		end)

		self.slotButtons[i] = { button = slot, name = name, count = count, stroke = slotStroke, icon = icon }
	end

	--------------------------------------------------------------------------
	-- Footer: auto-sort.
	--------------------------------------------------------------------------
	local sort = Instance.new("TextButton")
	sort.Name = "AutoSortButton"
	sort.AnchorPoint = Vector2.new(0, 1)
	sort.Position = UDim2.new(0, 18, 1, -14)
	sort.Size = UDim2.new(0.26, 0, 0, 32)
	sort.BackgroundColor3 = ACCENT
	sort.BackgroundTransparency = 0.15
	sort.Font = Enum.Font.GothamBold
	sort.TextSize = 14
	sort.TextColor3 = Color3.fromRGB(30, 24, 10)
	sort.Text = "จัดกระเป๋า"
	sort.Parent = panel
	corner(sort, UDim.new(0, 8))
	self.sortButton = sort

	local hint = label(panel, "แตะช่องเพื่อใช้ / สวมใส่", 11, TEXT_MUTED)
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0.3, 0, 1, -18)
	hint.Size = UDim2.new(0.6, 0, 0, 16)

	-- On a phone the panel is already sized as a fraction of the viewport, so the width-driven scale would
	-- shrink it a second time; keep it near 1 there and let the layout do the adapting.
	Responsive.Scale(panel, small and 0.95 or 0.75)

	return self
end

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

function InventoryGui:Render(data)
	self.goldLabel.Text = ("%d เหรียญ"):format(data.gold or 0)

	local weight = data.weight or 0
	local maxWeight = data.maxWeight or 1
	self.weightLabel.Text = ("น้ำหนัก %.1f / %d"):format(weight, maxWeight)
	-- Turn the readout red once the player is actually being slowed, so the penalty is never a mystery.
	self.weightLabel.TextColor3 = (weight > maxWeight) and Color3.fromRGB(224, 96, 84) or TEXT_MUTED

	for i, entry in ipairs(self.slotButtons) do
		local slot = data.slots and data.slots[i]
		if slot then
			local item = ItemCatalog.Get(slot.id)
			local art = item and item.icon or ""
			entry.icon.Image = art
			entry.icon.Visible = art ~= ""
			-- The name only shows when there is no artwork, so an icon is never covered by its own label.
			entry.name.Text = (art == "") and (item and item.name or slot.id) or ""
			entry.count.Text = (slot.count or 1) > 1 and ("x%d"):format(slot.count) or ""
			entry.stroke.Color = item and KIND_TINT[item.kind] or GLASS
			entry.stroke.Transparency = 0.35
		else
			entry.icon.Image = ""
			entry.icon.Visible = false
			entry.name.Text = ""
			entry.count.Text = ""
			entry.stroke.Color = GLASS
			entry.stroke.Transparency = 0.85
		end
	end

	for key, entry in pairs(self.equipSlots) do
		local worn = data.equipped and data.equipped[key]
		if worn then
			local item = ItemCatalog.Get(worn.id)
			entry.name.Text = item and item.name or worn.id
			entry.name.TextColor3 = TEXT_LIGHT
			local maxDurability = item and (item.maxDurability or item.armor)
			if maxDurability and worn.durability then
				entry.durability.Text = ("ความทนทาน %d/%d"):format(math.floor(worn.durability), maxDurability)
			else
				entry.durability.Text = ""
			end
			entry.stroke.Transparency = 0.3
			-- Show the artwork when there is any; an item with no icon keeps just its name, the way the bag
			-- slots do.
			local art = item and item.icon or ""
			entry.icon.Image = art
			entry.icon.Visible = art ~= ""
		else
			entry.name.Text = "ว่าง"
			entry.name.TextColor3 = TEXT_MUTED
			entry.durability.Text = ""
			entry.stroke.Transparency = 0.8
			entry.icon.Image = ""
			entry.icon.Visible = false
		end
	end
end

function InventoryGui:OnSlotClicked(callback) self.onSlotClicked = callback end
function InventoryGui:OnEquipSlotClicked(callback) self.onEquipSlotClicked = callback end
function InventoryGui:OnSortRequested(callback) self.sortButton.Activated:Connect(callback) end
function InventoryGui:OnCloseRequested(callback)
	self.closeButton.Activated:Connect(callback)
	-- The backdrop ignores any release that belongs to the tap which opened the panel. Without this a single
	-- mobile tap opened the bag on press (the BAG button fires on MouseButton1Down) and closed it again on
	-- release, so the panel appeared to do nothing at all.
	self.backdrop.Activated:Connect(function()
		if os.clock() < (self._ignoreBackdropUntil or 0) then return end
		callback()
	end)
end

-- Called by the controller when it opens the panel, so the opening tap's own release cannot close it.
function InventoryGui:GuardAgainstOpeningTap()
	self._ignoreBackdropUntil = os.clock() + 0.35
end

function InventoryGui:IsOpen() return self.gui.Enabled end
function InventoryGui:Show() self.gui.Enabled = true end
function InventoryGui:Hide() self.gui.Enabled = false end

return InventoryGui
