-- EmoteGui: the panel of poses, opened from the speaking stone.
--
-- Its own screen rather than a page inside the stone, for the same reason the map is: it wants room, and the
-- stone's grid is built for eight fixed buttons. Drawn from EmoteConfig, so a pose added there appears here
-- with nothing else to change.
--
-- Only poses that can actually play are offered. An unpublished one is left out entirely rather than drawn
-- and refused -- the speaking stone's "not open yet" buttons already taught that a button which explains
-- itself is still a button that disappointed someone.
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)
local EmoteConfig = require(script.Parent.Parent.EmoteConfig)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)

local EmoteGui = {}
EmoteGui.__index = EmoteGui

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

local function stroke(inst, colour, transparency)
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Transparency = transparency or 0.5
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

function EmoteGui.new()
	local self = setmetatable({}, EmoteGui)
	self.callbacks = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "EmoteGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 18 -- just above the stone it is opened from
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	local backdrop = Instance.new("TextButton")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.Parent = gui
	-- Tapping away closes it. A pose panel is something you dip into, not a window you manage.
	backdrop.Activated:Connect(function() self:Hide() end)

	local small = Responsive.IsSmallScreen()
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = small and UDim2.fromScale(0.94, 0.8) or UDim2.fromOffset(560, 430)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	stroke(panel, RUNE, 0.55)
	Responsive.Scale(panel)
	self.panel = panel

	local title = label(panel, "ท่าทาง", 19, RUNE, true)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(14, 12)
	title.Size = UDim2.new(1, -100, 0, 28)

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(28, 28)
	close.BackgroundColor3 = Color3.fromRGB(70, 74, 84)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBold
	close.TextSize = 16
	close.TextColor3 = TEXT_LIGHT
	close.Text = "\195\151"
	close.Parent = panel
	corner(close, UDim.new(0, 6))
	close.Activated:Connect(function()
		UiSound.Play("Click")
		self:Hide()
	end)

	-- Stopping whatever is running, without having to remember which button started it.
	local stop = Instance.new("TextButton")
	stop.AnchorPoint = Vector2.new(1, 0)
	stop.Position = UDim2.new(1, -48, 0, 12)
	stop.Size = UDim2.fromOffset(74, 28)
	stop.BackgroundColor3 = Color3.fromRGB(96, 58, 54)
	stop.BorderSizePixel = 0
	stop.Font = Enum.Font.GothamBold
	stop.TextSize = 12
	stop.TextColor3 = TEXT_LIGHT
	stop.Text = "เลิกท่า"
	stop.Parent = panel
	corner(stop, UDim.new(0, 6))
	stop.Activated:Connect(function()
		UiSound.Play("Click")
		if self.callbacks.stop then self.callbacks.stop() end
		self:SetStatus("กลับมายืนปกติแล้ว")
	end)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 48)
	list.Size = UDim2.new(1, -24, 1, -84)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	self.list = list

	self.status = label(panel, "เลือกท่าเพื่อแสดง · เดินเพื่อยกเลิก", 11, TEXT_MUTED)
	self.status.TextXAlignment = Enum.TextXAlignment.Left
	self.status.AnchorPoint = Vector2.new(0, 1)
	self.status.Position = UDim2.new(0, 14, 1, -10)
	self.status.Size = UDim2.new(1, -28, 0, 20)

	self:build()
	return self
end

-- One row per group, each a heading and a wrap of square buttons.
function EmoteGui:build()
	local order = 0
	for _, group in ipairs(EmoteConfig.Groups) do
		local entries = EmoteConfig.Available(group.id)
		if #entries > 0 then
			order += 1
			local heading = label(self.list, group.name, 12, RUNE, true)
			heading.LayoutOrder = order
			heading.Size = UDim2.new(1, 0, 0, 18)
			heading.TextXAlignment = Enum.TextXAlignment.Left

			order += 1
			local row = Instance.new("Frame")
			row.LayoutOrder = order
			row.Size = UDim2.new(1, 0, 0, 0)
			row.AutomaticSize = Enum.AutomaticSize.Y
			row.BackgroundTransparency = 1
			row.Parent = self.list

			local grid = Instance.new("UIGridLayout")
			grid.CellSize = UDim2.fromOffset(82, 82)
			grid.CellPadding = UDim2.fromOffset(8, 8)
			grid.SortOrder = Enum.SortOrder.LayoutOrder
			grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
			grid.Parent = row

			for i, entry in ipairs(entries) do
				local tile = Instance.new("TextButton")
				tile.LayoutOrder = i
				tile.BackgroundColor3 = STONE_DEEP
				tile.BorderSizePixel = 0
				tile.Text = ""
				tile.Parent = row
				corner(tile, UDim.new(0, 10))
				stroke(tile, RUNE, 0.7)

				local glyph = label(tile, entry.glyph, 26, RUNE)
				glyph.Size = UDim2.new(1, 0, 0, 36)
				glyph.Position = UDim2.fromOffset(0, 10)
				glyph.TextXAlignment = Enum.TextXAlignment.Center

				local name = label(tile, entry.label, 11, TEXT_LIGHT)
				name.Size = UDim2.new(1, -6, 0, 26)
				name.Position = UDim2.fromOffset(3, 48)
				name.TextXAlignment = Enum.TextXAlignment.Center
				name.TextWrapped = true

				-- A pose that holds you still is worth flagging before it is pressed, not after. A pose you can
				-- walk around in gets no pin: that is the ordinary case now, not the exception.
				if entry.locks then
					local pin = label(tile, "\226\143\184", 10, TEXT_MUTED)
					pin.AnchorPoint = Vector2.new(1, 0)
					pin.Position = UDim2.new(1, -6, 0, 4)
					pin.Size = UDim2.fromOffset(12, 12)
				end

				tile.Activated:Connect(function()
					UiSound.Play("Click")
					if self.callbacks.play then self.callbacks.play(entry.id) end
				end)
			end
		end
	end
end

function EmoteGui:On(name, fn)
	self.callbacks[name] = fn
end

function EmoteGui:SetStatus(text)
	self.status.Text = text
	self.statusToken = (self.statusToken or 0) + 1
	local token = self.statusToken
	task.delay(3, function()
		if self.statusToken == token and self.status.Parent then
			self.status.Text = "เลือกท่าเพื่อแสดง · เดินเพื่อยกเลิก"
		end
	end)
end

function EmoteGui:Show() self.gui.Enabled = true end
function EmoteGui:Hide() self.gui.Enabled = false end
function EmoteGui:IsOpen() return self.gui.Enabled end

return EmoteGui
