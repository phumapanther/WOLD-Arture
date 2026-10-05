-- MapGui: the world map — M, or the map button on the speaking stone.
--
-- Drawn from MapConfig, which holds the same normalized coordinates the terrain generator uses, so the map
-- cannot drift away from the world it describes.
--
-- Pan by dragging, zoom with the wheel or the +/- buttons. Everything inside the canvas is positioned in
-- normalized space and scaled by one zoom factor, so panning and zooming never need per-marker maths.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local MapConfig = require(script.Parent.Parent.MapConfig)
local MapTerrain = require(script.Parent.Parent.MapTerrain)
local Responsive = require(script.Parent.Responsive)
local MapPoiRules = require(script.Parent.Parent.MapPoiRules)
local ItemCatalog = require(script.Parent.Parent.ItemCatalog)
local Locale = require(script.Parent.Parent.Locale)
local L, Show = Locale.L, Locale.Show

-- ชื่อหมุด (ไทยจาก MapConfig/MapPoi.server) แปลตอนวาด · ป้ายเหมือง "เหมือง: เหล็ก · เงิน" ใช้ชื่อแร่สั้นที่ชนกุญแจอื่น
-- ("เงิน" = เงินตรา) จึงแปลชื่อแร่ผ่านชื่อไอเทมของแร่นั้นแทน · ไทยขึ้นป้ายเดิมทุกไบต์
local ORE_ITEM = {}
for kind, short in pairs(MapPoiRules.OreNames) do
	local item = ItemCatalog.Get(kind == "DiamondOre" and "Diamond" or kind) -- locale: skip (id ไอเทม)
	ORE_ITEM[short] = item and item.name or short
end
local function labelOf(data)
	local ores = Locale.Current() ~= "th" and data.label:match("^เหมือง: (.+)$") -- locale: skip (จับป้ายไทย)
	if ores then
		local names = {}
		for short in (ores .. " · "):gmatch("(.-) · ") do names[#names + 1] = L(ORE_ITEM[short] or short) end
		return L("เหมือง: %s", table.concat(names, " · "))
	end
	return Show(data.label)
end

local MapGui = {}
MapGui.__index = MapGui

local PARCHMENT = Color3.fromRGB(232, 216, 178)
local INK = Color3.fromRGB(58, 44, 28)
local FRAME = Color3.fromRGB(28, 22, 16)
local ACCENT = Color3.fromRGB(216, 172, 84)
local YOU = Color3.fromRGB(226, 96, 84)

-- How far from the waypoint diamond a tap still counts as a tap ON it, in screen pixels on top of the pin's
-- own 14. Generous on purpose: the pin is small and a finger is not, and the cost of being wrong is one
-- cancelled waypoint rather than a misplaced one.
local UNPIN_REACH = 16

local function corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 10)
	c.Parent = instance
	return c
end

-- A line between two points in the canvas's own pixel space. Rotation puts a thin frame along the segment.
local function line(parent, x1, y1, x2, y2, thickness, color, transparency)
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 0.5 then return nil end
	local seg = Instance.new("Frame")
	seg.AnchorPoint = Vector2.new(0.5, 0.5)
	seg.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
	seg.Size = UDim2.fromOffset(length, thickness)
	seg.Rotation = math.deg(math.atan2(dy, dx))
	seg.BackgroundColor3 = color
	seg.BackgroundTransparency = transparency or 0
	seg.BorderSizePixel = 0
	seg.ZIndex = 2
	seg.Parent = parent
	return seg
end

function MapGui.new()
	local self = setmetatable({}, MapGui)
	self.zoom = 1
	self.offset = Vector2.new(0, 0) -- pan, in canvas pixels
	self.pins = {} -- { data = { id, cat, emoji, label, x, y, z }, frame, nx, nz, static }
	self.filters = {} -- [หมวด] = false เมื่อผู้เล่นปิด · จำตลอดเซสชัน (MapGui สร้างครั้งเดียว)
	self.callbacks = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "MapGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 22 -- above the stone, below a call
	gui.Enabled = false
	self.gui = gui

	local small = Responsive.IsSmallScreen()

	local panel = Instance.new("Frame")
	panel.Name = "MapPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = small and UDim2.fromScale(0.94, 0.86) or UDim2.fromScale(0.72, 0.84)
	panel.BackgroundColor3 = FRAME
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Parent = gui
	self.panel = panel
	corner(panel, UDim.new(0, 14))

	local stroke = Instance.new("UIStroke")
	stroke.Color = ACCENT
	stroke.Transparency = 0.4
	stroke.Thickness = 2
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 16, 0, 10)
	title.Size = UDim2.new(1, -120, 0, 26)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 17
	title.TextColor3 = ACCENT
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = L("แผนที่โลก")
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Size = UDim2.fromOffset(28, 28)
	close.BackgroundColor3 = Color3.fromRGB(52, 48, 56)
	close.BackgroundTransparency = 0.25
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBold
	close.TextSize = 16
	close.TextColor3 = Color3.fromRGB(240, 240, 245)
	close.Text = "\195\151"
	close.Parent = panel
	corner(close, UDim.new(1, 0))
	close.Activated:Connect(function() self:Hide() end)
	self.closeButton = close

	-- The window the map is seen through. ClipsDescendants is what makes panning look like moving a map
	-- rather than moving a picture around a page.
	local viewport = Instance.new("Frame")
	viewport.Name = "Viewport"
	viewport.Position = UDim2.new(0, 12, 0, 46)
	viewport.Size = UDim2.new(1, -24, 1, -92)
	viewport.BackgroundColor3 = MapConfig.SeaColor
	viewport.BorderSizePixel = 0
	viewport.ClipsDescendants = true
	viewport.Parent = panel
	self.viewport = viewport
	corner(viewport, UDim.new(0, 8))

	-- Everything drawn lives on this square canvas, which is moved and resized as one.
	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.BackgroundTransparency = 1
	canvas.Parent = viewport
	self.canvas = canvas

	-- Zoom scales the canvas CONTENTS through this. Growing the frame instead only moved the drawing into
	-- a corner, because every terrain piece and marker is positioned in fixed pixels inside it.
	local canvasScale = Instance.new("UIScale")
	canvasScale.Scale = 1
	canvasScale.Parent = canvas
	self.canvasScale = canvasScale

	local footer = Instance.new("TextLabel")
	footer.BackgroundTransparency = 1
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 16, 1, -12)
	footer.Size = UDim2.new(1, -140, 0, 28)
	footer.Font = Enum.Font.Gotham
	footer.TextSize = 12
	footer.TextColor3 = Color3.fromRGB(150, 156, 172)
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.Text = Responsive.IsTouchOnly() and L("ลากเพื่อเลื่อน · ปุ่ม + / - เพื่อซูม") or L("ลากเพื่อเลื่อน · ล้อเมาส์เพื่อซูม")
	footer.Parent = panel
	self.footer = footer

	local function zoomButton(text, dx, order)
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.new(1, -12 - order * 40, 1, -12)
		b.Size = UDim2.fromOffset(34, 28)
		b.BackgroundColor3 = Color3.fromRGB(52, 48, 56)
		b.BackgroundTransparency = 0.25
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 18
		b.TextColor3 = Color3.fromRGB(240, 240, 245)
		b.Text = text
		b.Parent = panel
		corner(b, UDim.new(0, 8))
		b.Activated:Connect(function() self:Zoom(dx) end)
		return b
	end
	zoomButton("+", MapConfig.ZoomStep, 0)
	zoomButton("\226\136\146", -MapConfig.ZoomStep, 1) -- minus sign

	-- The blackout's button: find me a machine that still needs fixing.
	--
	-- Hidden unless the lights are actually out, which is the user's rule -- during ordinary play there is
	-- nothing to repair and a permanent button would be a promise the map cannot keep. Pressing it again
	-- picks a DIFFERENT machine, so a player who does not fancy the walk to the one they were given can ask
	-- for another.
	local repairButton = Instance.new("ImageButton")
	repairButton.Name = "RepairRoute"
	repairButton.AnchorPoint = Vector2.new(1, 1)
	repairButton.Position = UDim2.new(1, -12 - 2 * 40, 1, -12)
	repairButton.Size = UDim2.fromOffset(34, 28)
	repairButton.BackgroundColor3 = Color3.fromRGB(74, 56, 30)
	repairButton.BackgroundTransparency = 0.1
	repairButton.BorderSizePixel = 0
	repairButton.Image = "rbxassetid://135773985386159" -- assets/item-icons/event_electric
	repairButton.ScaleType = Enum.ScaleType.Fit
	repairButton.Visible = false
	repairButton.Parent = panel
	corner(repairButton, UDim.new(0, 8))
	local repairEdge = Instance.new("UIStroke")
	repairEdge.Color = Color3.fromRGB(255, 196, 92)
	repairEdge.Transparency = 0.3
	repairEdge.Thickness = 1
	repairEdge.Parent = repairButton
	repairButton.Activated:Connect(function()
		if self.callbacks.repairRoute then self.callbacks.repairRoute() end
	end)
	self.repairButton = repairButton

	self:buildCanvas()
	self:buildPinLayer()
	self:bindInput()
	Responsive.Scale(panel, small and 0.95 or 0.8)
	return self
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

-- The canvas is square and sized to fit the viewport, so the world is never stretched.
function MapGui:canvasSize()
	local v = self.viewport.AbsoluteSize
	return math.max(120, math.min(v.X, v.Y))
end

-- normalized [-1..1] -> canvas pixels
local function place(size, nx, nz)
	return (nx + 1) / 2 * size, (nz + 1) / 2 * size
end

-- The ground, drawn cell by cell from the sampled terrain. A circle was a lie: the real coast has bays,
-- headlands and an estuary, and the whole point of a map is to show them.
--
-- `step` is how many sampled cells one drawn square covers, and it is the whole of the level-of-detail
-- scheme. The terrain is now sampled far more finely than the old 120 grid, which is more squares than the
-- zoomed-out map has pixels to put them in -- so far out it draws every third cell, and close in every one.
-- Redrawn only when that number changes, not on every notch of the wheel.
--
-- Runs of the same material merge into one frame. Without that a fine grid is over a hundred thousand
-- Frames, which no amount of detail is worth.
function MapGui:buildTerrain(step)
	local canvas = self.canvas
	-- แผนที่ v2: มีรูปพื้นโลก (MapConfig.Tiles) = ใช้รูป ไม่ต้องสลับความละเอียดตามซูม
	-- รูปยังไม่โหลด/โหลดไม่ขึ้น = เห็นทะเลพื้นหลัง + ตาราง + หมุดครบ ไม่ใช่จอดำ
	local tiles = MapConfig.Tiles
	if tiles and #tiles > 0 then
		self.terrainStep = step
		if canvas:FindFirstChild("LandTile") then return end
		self.landTiles = {}
		for r, row in ipairs(tiles) do
			for c, image in ipairs(row) do
				local tile = Instance.new("ImageLabel")
				tile.Name = "LandTile"
				tile.BackgroundTransparency = 1
				tile.BorderSizePixel = 0
				tile.Image = image
				tile.Position = UDim2.fromScale((c - 1) / #row, (r - 1) / #tiles)
				tile.Size = UDim2.fromScale(1 / #row, 1 / #tiles) -- ส่วนซ้อนกันรอยต่อตั้งใน apply (1 px บนจอทุกซูม)
				tile.ZIndex = 1
				tile.Parent = canvas
				table.insert(self.landTiles, tile)
			end
		end
		return
	end
	for _, c in ipairs(canvas:GetChildren()) do
		if c.Name == "Land" then c:Destroy() end
	end
	self.terrainStep = step

	local size = self.baseSize
	local cells = MapTerrain.Size
	local cell = size / cells

	for gz = 1, cells, step do
		local row = MapTerrain.Heights[gz]
		local gx = 1
		while gx <= cells do
			if row[gx] ~= MapTerrain.Water then
				local code = MapTerrain.MaterialAt(gx, gz)
				local run = gx
				while run + step <= cells and row[run + step] ~= MapTerrain.Water
					and MapTerrain.MaterialAt(run + step, gz) == code do
					run += step
				end
				local piece = Instance.new("Frame")
				piece.Name = "Land"
				piece.Position = UDim2.fromOffset((gx - 1) * cell, (gz - 1) * cell)
				-- The +1 closes the hairline seams that rounding leaves between neighbouring squares.
				piece.Size = UDim2.fromOffset((run - gx + step) * cell + 1, cell * step + 1)
				piece.BackgroundColor3 = MapConfig.ColorFor(code)
				piece.BorderSizePixel = 0
				piece.ZIndex = 1
				piece.Parent = canvas
				gx = run + step
			else
				gx += step
			end
		end
	end
end

-- Which step the current zoom wants. Two levels only: another one between them would be a third redraw for
-- a difference nobody would be able to point at.
function MapGui:detailStep()
	return self.zoom >= MapConfig.DetailZoom and 1 or MapConfig.CoarseStep
end

function MapGui:buildCanvas()
	local canvas = self.canvas
	-- Keep the UIScale: it is created once with the canvas and is what zooming drives, so clearing it here
	-- silently disabled zoom (the frames were rebuilt, the scale was not).
	for _, c in ipairs(canvas:GetChildren()) do
		if not c:IsA("UIScale") then c:Destroy() end
	end
	self.waypointPin = nil -- destroyed with the rest; the controller re-sets it if there is still one

	local size = 600 -- drawn at a fixed size, then scaled: redrawing on every zoom would be wasteful
	self.baseSize = size
	canvas.Size = UDim2.fromOffset(size, size)

	self:buildTerrain(self:detailStep())

	-- The grid, drawn in world units so a square means a known distance.
	local step = size * (MapConfig.GridStuds / MapConfig.HalfSize) / 2
	for i = 0, size, step do
		line(canvas, i, 0, i, size, 1, MapConfig.GridColor, 0.88)
		line(canvas, 0, i, size, i, 1, MapConfig.GridColor, 0.88)
	end

	-- The river and the roads used to be drawn here. Removed with their data: see the note in MapConfig.

	-- สถานที่ (เมือง หมู่บ้าน แลนด์มาร์ก ถ้ำ) เป็นหมุดอีโมจิในชั้นหมุด ไม่ได้วาดบน canvas — ดู buildPinLayer

	-- The "you are here" pin, moved every frame while the map is open.
	local you = Instance.new("Frame")
	you.Name = "You"
	you.AnchorPoint = Vector2.new(0.5, 0.5)
	you.Size = UDim2.fromOffset(12, 12)
	you.BackgroundColor3 = YOU
	you.BorderSizePixel = 0
	you.ZIndex = 6
	you.Parent = canvas
	corner(you, UDim.new(1, 0))
	local youStroke = Instance.new("UIStroke")
	youStroke.Color = Color3.fromRGB(255, 255, 255)
	youStroke.Thickness = 2
	youStroke.Parent = you
	self.youPin = you
end

--------------------------------------------------------------------------------
-- Pan, zoom, and the player pin
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- หมุดอีโมจิ + แถบกรองหมวด (แผนที่ v2 · 2026-10-02) — กติกาหมวด/ซูม/กรอง = MapPoiRules
--------------------------------------------------------------------------------

local PIN_SIZE = 28 -- สถานที่ (เมือง หมู่บ้าน แลนด์มาร์ก ถ้ำ)
local SUB_PIN_SIZE = 22 -- หมุดย่อยจากเซิร์ฟ (NPC เหมือง มอน ...) เล็กกว่า กันรกเมื่อกองอยู่ในเมือง
local NAMES_FROM = 600 -- ชื่อหมู่บ้าน/แลนด์มาร์กขึ้นเมื่อแผนที่วาดกว้างเท่านี้ (px) ขึ้นไป · ชื่อเมืองขึ้นเสมอ
local PIN_REACH = 8 -- ระยะเผื่อรอบหมุดที่ยังนับว่าแตะโดน (นิ้วใหญ่กว่าหมุด)
local NAMED = { city = true, village = true, landmark = true } -- ชื่อขึ้นใต้หมุดเสมอ ที่เหลือขึ้นเมื่อชี้เมาส์/แตะ
local LIGHT = Color3.fromRGB(250, 244, 226)

-- ชั้นหมุดอยู่ใน viewport นอก canvas: ไม่โดน UIScale ของการซูม หมุดจึงขนาดคงที่บนจอ (apply วางตำแหน่ง)
function MapGui:buildPinLayer()
	local layer = Instance.new("Frame")
	layer.Name = "Pins"
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.ZIndex = 8
	layer.Parent = self.viewport
	self.pinLayer = layer
	self.youPin.Parent = layer -- เหนือหมุด ใต้ชื่อลอย (12) · ขนาดคงที่บนจอเหมือนหมุด
	self.youPin.ZIndex = 11

	local tip = Instance.new("TextLabel")
	tip.Name = "Tooltip"
	tip.AnchorPoint = Vector2.new(0.5, 1)
	tip.AutomaticSize = Enum.AutomaticSize.X
	tip.Size = UDim2.fromOffset(0, 22)
	tip.BackgroundColor3 = FRAME
	tip.BackgroundTransparency = 0.15
	tip.Font = Enum.Font.GothamBold
	tip.TextSize = 13
	tip.TextColor3 = LIGHT
	tip.ZIndex = 12
	tip.Visible = false
	tip.Parent = layer
	corner(tip, UDim.new(0, 6))
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = tip
	self.tooltip = tip

	-- แถบกรอง: ปุ่มอีโมจิเรียงตั้งขอบซ้าย เลื่อนได้เมื่อจอเตี้ย (มือถือแนวนอน)
	local bar = Instance.new("ScrollingFrame")
	bar.Name = "Filters"
	bar.Position = UDim2.fromOffset(6, 6)
	bar.Size = UDim2.new(0, 40, 1, -12)
	bar.BackgroundTransparency = 1
	bar.BorderSizePixel = 0
	bar.ScrollBarThickness = 0
	bar.ScrollingDirection = Enum.ScrollingDirection.Y
	bar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	bar.CanvasSize = UDim2.new()
	bar.ZIndex = 10
	bar.Parent = self.viewport
	self.filterBar = bar
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = bar
	self.filterButtons = {}
	for i, cat in ipairs(MapPoiRules.Categories) do
		local b = Instance.new("TextButton")
		b.Name = cat.id
		b.LayoutOrder = i
		b.Size = UDim2.fromOffset(36, 36)
		b.BackgroundColor3 = FRAME
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 18
		b.Text = cat.emoji
		b.ZIndex = 11
		b.Parent = bar
		corner(b, UDim.new(0, 8))
		local edge = Instance.new("UIStroke")
		edge.Color = ACCENT
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Parent = b
		self.filterButtons[cat.id] = { button = b, stroke = edge }
		self.lastFilterButton = b
		b.Activated:Connect(function()
			local show = self.filters[cat.id] == false
			self.filters[cat.id] = (not show) and false or nil
			self:paintFilters()
			self:apply()
			if show then self:SetStatus(L("แสดง: %s", cat.label)) else self:SetStatus(L("ซ่อน: %s", cat.label)) end
		end)
	end
	self:paintFilters()

	-- หมุดคงที่: สถานที่ใน MapConfig (เมือง หมู่บ้าน แลนด์มาร์ก ถ้ำ) · หมุดจากเซิร์ฟมาทาง SetPois
	for _, p in ipairs(MapConfig.Places) do
		local cat, emoji = MapPoiRules.ForPlace(p)
		local x, z = MapConfig.ToWorld(p.pos[1], p.pos[2])
		local h = MapTerrain.At(x, z)
		self:addPin({ id = "place:" .. p.name, cat = cat, emoji = emoji, label = p.th or p.name,
			x = x, y = h == MapTerrain.Water and 0 or h, z = z }, true)
	end
end

function MapGui:paintFilters()
	for id, f in pairs(self.filterButtons) do
		local on = self.filters[id] ~= false
		f.button.BackgroundTransparency = on and 0.15 or 0.55
		f.button.TextTransparency = on and 0 or 0.65
		f.stroke.Transparency = on and 0.2 or 1
	end
end

function MapGui:addPin(data, static)
	local frame = Instance.new("Frame")
	frame.Name = "Pin"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	local size = static and PIN_SIZE or SUB_PIN_SIZE
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = FRAME
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.ZIndex = static and 9 or 8 -- เมือง/แลนด์มาร์กอยู่บนหมุดย่อยเมื่อทับกัน
	frame.Visible = false
	frame.Parent = self.pinLayer
	corner(frame, UDim.new(1, 0))
	local edge = Instance.new("UIStroke")
	edge.Parent = frame
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = static and 17 or 13
	icon.Text = data.emoji
	icon.ZIndex = frame.ZIndex + 1
	icon.Parent = frame
	local name
	if NAMED[data.cat] then
		name = Instance.new("TextLabel")
		name.AnchorPoint = Vector2.new(0.5, 0)
		name.Position = UDim2.new(0.5, 0, 1, 1)
		name.Size = UDim2.fromOffset(160, 15)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextSize = 12
		name.TextColor3 = LIGHT
		name.TextStrokeColor3 = FRAME
		name.TextStrokeTransparency = 0.15
		name.Text = labelOf(data)
		name.ZIndex = frame.ZIndex + 1
		name.Parent = frame
	end
	local nx, nz = MapConfig.ToNormalized(data.x, data.z)
	local pin = { data = data, frame = frame, stroke = edge, static = static, name = name,
		nx = math.clamp(nx, -1, 1), nz = math.clamp(nz, -1, 1) }
	table.insert(self.pins, pin)
	self:paintPin(pin)
	return pin
end

-- หมุดที่เป็นจุดนำทางอยู่ = ขอบทองหนา (เพชรจุดหมายบน canvas ซ่อนอยู่ใต้หมุด)
function MapGui:isSelected(pin)
	local w = self.waypoint
	return w ~= nil and (Vector2.new(pin.data.x, pin.data.z) - Vector2.new(w.X, w.Z)).Magnitude < 2
end

function MapGui:paintPin(pin)
	local selected = self:isSelected(pin)
	pin.stroke.Color = selected and ACCENT or LIGHT
	pin.stroke.Thickness = selected and 3 or 1
	pin.stroke.Transparency = selected and 0 or 0.5
end

-- หมุดจากเซิร์ฟ (MapPoi.server) แทนชุดเดิมทั้งชุด · หมุดคงที่อยู่ต่อ
function MapGui:SetPois(list)
	local keep = {}
	for _, pin in ipairs(self.pins) do
		if pin.static then table.insert(keep, pin) else pin.frame:Destroy() end
	end
	self.pins = keep
	for _, data in ipairs(type(list) == "table" and list or {}) do
		if type(data) == "table" and MapPoiRules.Category(data.cat) and type(data.x) == "number"
			and type(data.z) == "number" and type(data.label) == "string" then
			self:addPin(data, false)
		end
	end
	if self.gui.Enabled then self:apply() end
end

-- หมุดที่จุดบนจอนี้แตะโดน (ใกล้สุด) · วัดจากกรอบที่วาดจริง จึงถูกทุกซูมทุกขนาดจอ
function MapGui:pinUnder(screenPosition)
	local at = Vector2.new(screenPosition.X, screenPosition.Y)
	local best, bestDistance
	for _, pin in ipairs(self.pins) do
		if pin.frame.Visible then
			local size = pin.frame.AbsoluteSize
			local d = (at - (pin.frame.AbsolutePosition + size / 2)).Magnitude
			if d <= size.X / 2 + PIN_REACH and (not bestDistance or d < bestDistance) then
				best, bestDistance = pin, d
			end
		end
	end
	return best
end

-- จุดนี้อยู่บนปุ่มกรองไหม (นับถึงปุ่มสุดท้าย ไม่ใช่ทั้งความสูงของแถบ — ใต้ปุ่มยังแตะแผนที่ได้)
function MapGui:overFilters(screenPosition)
	local bar, last = self.filterBar, self.lastFilterButton
	if not bar or not last then return false end
	local p, s = bar.AbsolutePosition, bar.AbsoluteSize
	local bottom = math.min(p.Y + s.Y, last.AbsolutePosition.Y + last.AbsoluteSize.Y)
	return screenPosition.X >= p.X and screenPosition.X <= p.X + s.X and screenPosition.Y >= p.Y and screenPosition.Y <= bottom
end

-- คอม: ชี้เมาส์ที่หมุดย่อย = ชื่อลอยเหนือหมุด (เมือง/หมู่บ้าน/แลนด์มาร์กมีชื่อใต้หมุดอยู่แล้ว)
function MapGui:hover(screenPosition)
	local pin = not self:overFilters(screenPosition) and self:pinUnder(screenPosition)
	if not pin or (pin.name and pin.name.Visible) then
		self.tooltip.Visible = false
		return
	end
	self.tooltip.Text = labelOf(pin.data)
	self.tooltip.Position = pin.frame.Position - UDim2.fromOffset(0, pin.frame.Size.Y.Offset / 2 + 2)
	self.tooltip.Visible = true
end

function MapGui:apply()
	-- The canvas keeps its drawn size; the UIScale does the zooming, so the contents grow with it and the
	-- centre stays the centre.
	local scale = (self:canvasSize() / self.baseSize) * self.zoom
	self.canvasScale.Scale = scale
	self.canvas.Position = UDim2.new(0.5, self.offset.X, 0.5, self.offset.Y)
	-- หมุดอยู่นอก canvas (ไม่โดน UIScale ของการซูม) จึงขนาดคงที่บนจอทุกซูม · ตำแหน่ง = จุดเดียวกับที่ canvas วาด
	-- แผ่นรูปซ้อนกัน 1 px บนจอ กันรอยต่อเส้นผม · เป็นหน่วย canvas ที่ถูกซูมขยาย จึงหารด้วย scale (ไม่งั้นรูปยืดเลื่อนจากหมุด)
	for _, tile in ipairs(self.landTiles or {}) do
		tile.Size = UDim2.new(tile.Size.X.Scale, 1 / scale, tile.Size.Y.Scale, 1 / scale)
	end
	local half = self.baseSize / 2
	local roomy = self:canvasSize() * self.zoom >= NAMES_FROM
	for _, pin in ipairs(self.pins) do
		local visible = MapPoiRules.Visible(pin.data.cat, self.zoom, self.filters)
		pin.frame.Visible = visible
		if pin.name then pin.name.Visible = roomy or pin.data.cat == "city" end
		if visible then
			pin.frame.Position = UDim2.new(0.5, self.offset.X + pin.nx * half * scale, 0.5, self.offset.Y + pin.nz * half * scale)
		end
	end
	if self.tooltip then self.tooltip.Visible = false end
	self:placeYou()
end

-- จุด "คุณอยู่ที่นี่" อยู่ในชั้นหมุดเหนือทุกหมุด (บน canvas มันจมใต้หมุดเมือง) · ตำแหน่งคณิตเดียวกับหมุด
function MapGui:placeYou()
	local you, at = self.youPin, self.youAt
	if not you or not at then return end
	local scale = (self:canvasSize() / self.baseSize) * self.zoom
	local half = self.baseSize / 2
	you.Position = UDim2.new(0.5, self.offset.X + at.X * half * scale, 0.5, self.offset.Y + at.Y * half * scale)
end

function MapGui:Zoom(delta, focus)
	local before = self.zoom
	self.zoom = math.clamp(self.zoom + delta, MapConfig.MinZoom, MapConfig.MaxZoom)
	if self.zoom == before then return end
	-- Zoom about the middle of the view: the offset has to grow with the map or the centre drifts.
	local ratio = self.zoom / before
	self.offset = self.offset * ratio
	self:clampOffset()
	self:apply()

	-- Crossing the detail threshold redraws the ground at the other resolution. Compared rather than
	-- rebuilt every time, because the rebuild is thousands of frames and the wheel sends many small steps.
	local want = self:detailStep()
	if want ~= self.terrainStep then
		self:buildTerrain(want)
	end
end

-- Keeps the map from being dragged entirely out of its own window.
function MapGui:clampOffset()
	-- How far the map may be pushed before its edge leaves the window: half the DRAWN size, less a quarter
	-- of the window so some map is always in view.
	local drawn = self.baseSize * (self:canvasSize() / self.baseSize) * self.zoom
	local limit = math.max(0, drawn / 2 - self:canvasSize() / 4)
	self.offset = Vector2.new(
		math.clamp(self.offset.X, -limit, limit),
		math.clamp(self.offset.Y, -limit, limit))
end

function MapGui:bindInput()
	local dragging, lastPos = false, nil
	local pressedAt, pressedPos = 0, nil

	self.viewport.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			if self:overFilters(input.Position) then return end -- เลื่อนแถบกรองไม่ใช่การลากแผนที่
			dragging = true
			lastPos = input.Position
			pressedAt = os.clock()
			pressedPos = input.Position
		end
	end)

	self.viewport.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			-- A tap places a waypoint; a drag pans. Both start the same way, so the difference is measured
			-- rather than guessed: short, and it barely moved.
			if pressedPos then
				local moved = (input.Position - pressedPos).Magnitude
				if moved < 8 and os.clock() - pressedAt < 0.4 then
					self:pinAt(input.Position)
				end
			end
			pressedPos = nil
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not self.gui.Enabled then return end
		if dragging and lastPos
			and (input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - lastPos
			lastPos = input.Position
			self.offset = self.offset + Vector2.new(delta.X, delta.Y)
			self:clampOffset()
			self:apply()
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			self:Zoom(input.Position.Z > 0 and MapConfig.ZoomStep or -MapConfig.ZoomStep)
		elseif input.UserInputType == Enum.UserInputType.MouseMovement and not dragging then
			self:hover(input.Position)
		end
	end)
end

-- Turns a tap on the map into a world position and reports it. The maths is the exact inverse of place():
-- canvas pixels back to normalized, then normalized back to studs.
function MapGui:pinAt(screenPosition)
	local canvas = self.canvas
	-- Measured from what is actually on screen, not from the scale factors. The canvas sits under TWO
	-- UIScales: its own zoom, and the responsive scale on the panel, which is 1.0 on a wide window and
	-- less on a narrow one. Dividing by the zoom alone was therefore correct at full size and increasingly
	-- wrong as the window shrank. AbsoluteSize already has both applied.
	local drawn = canvas.AbsoluteSize
	if drawn.X <= 0 or drawn.Y <= 0 then return end
	if self:overFilters(screenPosition) then return end
	local local2d = Vector2.new(screenPosition.X, screenPosition.Y) - canvas.AbsolutePosition

	-- แตะหมุดอีโมจิ = นำทางไปหมุดนั้นทันที · แตะหมุดที่นำทางอยู่ซ้ำ = ยกเลิก · ตัดสินที่นี่ที่เดียวกับการแตะพื้น
	-- (ไม่ผูก Activated แยก) จึงไม่ปักหมุดพื้นซ้อน · เช็คหมุดก่อนระยะยกเลิกของเพชรจุดหมาย ไม่งั้นแตะหมุดข้างๆ = ยกเลิก
	local poi = self:pinUnder(screenPosition)
	if poi then
		if self:isSelected(poi) then
			if self.callbacks.unpin then self.callbacks.unpin() end
		elseif self.callbacks.poi then
			-- ป้ายแปลแล้ว (labelOf) ให้แถบนำทางขึ้นตรงกับชื่อหมุด · Show ป้ายเหมืองไทยตรงๆ ได้ "เงิน" = Coins
			local data = table.clone(poi.data)
			data.label = labelOf(poi.data)
			self.callbacks.poi(data)
		end
		return
	end

	-- Tapping the diamond that is already there takes it back -- what the footer has been promising all
	-- along. Tested against the pin's drawn rectangle rather than against a distance in studs: the map
	-- zooms, so a fixed number of studs would be an unmissable target zoomed in and an unhittable one
	-- zoomed out, while "you hit the pin" means the same thing at every zoom and on every screen size.
	-- Checked before the tap becomes a world position, so a pin sitting somewhere a tap could not have placed
	-- one -- the blackout router picks the transformer, not the player -- can still be taken back.
	if self.waypointPin and self.waypointPin.Parent then
		local pin = self.waypointPin
		local centre = pin.AbsolutePosition + pin.AbsoluteSize / 2
		local reach = math.max(pin.AbsoluteSize.X, pin.AbsoluteSize.Y) / 2 + UNPIN_REACH
		if (Vector2.new(screenPosition.X, screenPosition.Y) - centre).Magnitude <= reach then
			if self.callbacks.unpin then self.callbacks.unpin() end
			return
		end
	end

	local nx = (local2d.X / drawn.X) * 2 - 1
	local nz = (local2d.Y / drawn.Y) * 2 - 1
	if nx < -1 or nx > 1 or nz < -1 or nz > 1 then return end

	local x, z = MapConfig.ToWorld(nx, nz)
	-- Height comes from the sampled terrain, so the pin lands on the ground rather than at sea level.
	local h = MapTerrain.At(x, z)
	if h == MapTerrain.Water then
		self:SetStatus(L("ปักหมุดกลางน้ำไม่ได้"))
		return
	end
	if self.callbacks.pin then self.callbacks.pin(Vector3.new(x, h, z)) end
end

function MapGui:SetStatus(text)
	self.footerOverride = text
	if text then
		self.footer.Text = text
		task.delay(3, function()
			if self.footerOverride == text then self.footerOverride = nil end
		end)
	end
end

function MapGui:On(name, fn)
	self.callbacks[name] = fn
end

-- Shown only while the city's engines are down. Driven from the event banner's own state, so the button and
-- the announcement appear and disappear together.
function MapGui:SetRepairVisible(visible)
	self.repairButton.Visible = visible and true or false
end

-- Moves the pin to wherever the player is. Called on a loop while the map is open.
function MapGui:UpdatePin()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		self.youPin.Visible = false
		return
	end
	self.youPin.Visible = true
	local nx, nz = MapConfig.ToNormalized(root.Position.X, root.Position.Z)
	-- Off the edge of the map is still worth showing, at the edge, rather than hidden.
	nx = math.clamp(nx, -1, 1)
	nz = math.clamp(nz, -1, 1)
	self.youAt = Vector2.new(nx, nz)
	self:placeYou()
	if not self.footerOverride then
		self.footer.Text = L("ตำแหน่ง %.0f, %.0f · แตะหมุดเพื่อนำทาง · ลากเพื่อเลื่อน",
			root.Position.X, root.Position.Z)
	end
end

-- Shows (or clears) the waypoint marker on the map itself, so the destination is visible alongside the
-- player pin rather than only out in the world.
function MapGui:SetWaypoint(position)
	if self.waypointPin then
		self.waypointPin:Destroy()
		self.waypointPin = nil
	end
	self.waypoint = position
	for _, p in ipairs(self.pins) do self:paintPin(p) end
	if not position then return end

	local pin = Instance.new("Frame")
	pin.Name = "Waypoint"
	pin.AnchorPoint = Vector2.new(0.5, 0.5)
	pin.Size = UDim2.fromOffset(14, 14)
	pin.Rotation = 45 -- a diamond, so it never reads as the round "you are here" dot
	pin.BackgroundColor3 = Color3.fromRGB(232, 190, 84)
	pin.BorderSizePixel = 0
	pin.ZIndex = 7
	pin.Parent = self.canvas
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(28, 22, 16)
	stroke.Thickness = 2
	stroke.Parent = pin

	local nx, nz = MapConfig.ToNormalized(position.X, position.Z)
	local x, y = place(self.baseSize, math.clamp(nx, -1, 1), math.clamp(nz, -1, 1))
	pin.Position = UDim2.fromOffset(x, y)
	self.waypointPin = pin
end

function MapGui:IsOpen()
	return self.gui.Enabled
end

function MapGui:Show()
	self.gui.Enabled = true
	self:apply()
	self:UpdatePin()
end

function MapGui:Hide()
	self.gui.Enabled = false
end

return MapGui
