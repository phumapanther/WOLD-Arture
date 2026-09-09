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

local MapGui = {}
MapGui.__index = MapGui

local PARCHMENT = Color3.fromRGB(232, 216, 178)
local INK = Color3.fromRGB(58, 44, 28)
local FRAME = Color3.fromRGB(28, 22, 16)
local ACCENT = Color3.fromRGB(216, 172, 84)
local YOU = Color3.fromRGB(226, 96, 84)

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
	self.markers = {}
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
	title.Text = "แผนที่โลก"
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
	footer.Text = "ลากเพื่อเลื่อน · ล้อเมาส์เพื่อซูม"
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

	self:buildCanvas()
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

function MapGui:buildCanvas()
	local canvas = self.canvas
	-- Keep the UIScale: it is created once with the canvas and is what zooming drives, so clearing it here
	-- silently disabled zoom (the frames were rebuilt, the scale was not).
	for _, c in ipairs(canvas:GetChildren()) do
		if not c:IsA("UIScale") then c:Destroy() end
	end
	self.waypointPin = nil -- destroyed with the rest; the controller re-sets it if there is still one
	self.markers = {}

	local size = 600 -- drawn at a fixed size, then scaled: redrawing on every zoom would be wasteful
	self.baseSize = size
	canvas.Size = UDim2.fromOffset(size, size)

	-- The land, drawn cell by cell from the sampled terrain. A circle was a lie: the real coast has bays,
	-- headlands and an estuary, and the whole point of a map is to show them.
	local cells = MapTerrain.Size
	local cell = size / cells
	for gz = 1, cells do
		local row = MapTerrain.Heights[gz]
		local gx = 1
		while gx <= cells do
			local h = row[gx]
			if h ~= MapTerrain.Water then
				-- Merge neighbouring cells of the same GROUND TYPE into one frame: 14400 separate frames
				-- would cost far more than the map is worth, and a run of grass is one shape anyway.
				local code = MapTerrain.MaterialAt(gx, gz)
				local band = { color = MapConfig.ColorFor(code) }
				local run = gx
				while run < cells and row[run + 1] ~= MapTerrain.Water
					and MapTerrain.MaterialAt(run + 1, gz) == code do
					run += 1
				end
				local piece = Instance.new("Frame")
				piece.Position = UDim2.fromOffset((gx - 1) * cell, (gz - 1) * cell)
				piece.Size = UDim2.fromOffset((run - gx + 1) * cell + 1, cell + 1)
				piece.BackgroundColor3 = band.color
				piece.BorderSizePixel = 0
				piece.ZIndex = 1
				piece.Parent = canvas
				gx = run + 1
			else
				gx += 1
			end
		end
	end

	-- The grid, drawn in world units so a square means a known distance.
	local step = size * (MapConfig.GridStuds / MapConfig.HalfSize) / 2
	for i = 0, size, step do
		line(canvas, i, 0, i, size, 1, MapConfig.GridColor, 0.88)
		line(canvas, 0, i, size, i, 1, MapConfig.GridColor, 0.88)
	end

	-- The river.
	local prev
	for _, point in ipairs(MapConfig.River) do
		local x, y = place(size, point[1], point[2])
		if prev then line(canvas, prev[1], prev[2], x, y, 4, MapConfig.RiverColor) end
		prev = { x, y }
	end

	-- Roads, by looking each end up so they follow the places.
	for _, road in ipairs(MapConfig.Roads) do
		local a, b = MapConfig.Find(road[1]), MapConfig.Find(road[2])
		if a and b then
			local ax, ay = place(size, a.pos[1], a.pos[2])
			local bx, by = place(size, b.pos[1], b.pos[2])
			line(canvas, ax, ay, bx, by, 2, MapConfig.RoadColor, 0.25)
		end
	end

	-- Places.
	for _, p in ipairs(MapConfig.Places) do
		local kind = MapConfig.Kinds[p.kind] or MapConfig.Kinds.cave
		local x, y = place(size, p.pos[1], p.pos[2])

		local dot = Instance.new("TextLabel")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromOffset(x, y)
		dot.Size = UDim2.fromOffset(kind.size * 2, kind.size * 2)
		dot.BackgroundTransparency = 1
		dot.Font = Enum.Font.GothamBold
		dot.TextSize = kind.size * 1.8
		dot.TextColor3 = kind.color
		dot.Text = kind.glyph
		dot.ZIndex = 4
		dot.Parent = canvas

		local name = Instance.new("TextLabel")
		name.AnchorPoint = Vector2.new(0.5, 0)
		name.Position = UDim2.fromOffset(x, y + kind.size)
		name.Size = UDim2.fromOffset(120, 14)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextSize = 11
		name.TextColor3 = INK
		name.TextStrokeColor3 = PARCHMENT
		name.TextStrokeTransparency = 0.2
		name.Text = p.th or p.name
		name.ZIndex = 4
		name.Parent = canvas
		table.insert(self.markers, name)
	end

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

function MapGui:apply()
	-- The canvas keeps its drawn size; the UIScale does the zooming, so the contents grow with it and the
	-- centre stays the centre.
	local scale = (self:canvasSize() / self.baseSize) * self.zoom
	self.canvasScale.Scale = scale
	self.canvas.Position = UDim2.new(0.5, self.offset.X, 0.5, self.offset.Y)
	-- Labels would become unreadable smears at high zoom if they grew with everything else, so the scale is
	-- divided back out of their text size.
	for _, label in ipairs(self.markers) do
		label.TextSize = math.clamp(11 / self.zoom, 7, 14)
	end
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
	local local2d = Vector2.new(screenPosition.X, screenPosition.Y) - canvas.AbsolutePosition
	local nx = (local2d.X / drawn.X) * 2 - 1
	local nz = (local2d.Y / drawn.Y) * 2 - 1
	if nx < -1 or nx > 1 or nz < -1 or nz > 1 then return end

	local x, z = MapConfig.ToWorld(nx, nz)
	-- Height comes from the sampled terrain, so the pin lands on the ground rather than at sea level.
	local h = MapTerrain.At(x, z)
	if h == MapTerrain.Water then
		self:SetStatus("ปักหมุดกลางน้ำไม่ได้")
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
	local x, y = place(self.baseSize, nx, nz)
	self.youPin.Position = UDim2.fromOffset(x, y)
	if not self.footerOverride then
		self.footer.Text = ("ตำแหน่ง %.0f, %.0f · แตะเพื่อปักหมุด · ลากเพื่อเลื่อน"):format(
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
