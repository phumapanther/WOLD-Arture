-- CraftGui: the blacksmith's forge. Three pages of recipes, each showing what it makes and what it eats.
--
-- Pure builder, like ShopGui: it draws the snapshot the server sends and reports taps. It never counts a
-- material, never decides what is craftable, and holds no state between snapshots beyond which tab is open --
-- every redraw is a fresh picture of what the server currently says.
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)
-- Green for a material the player already has enough of, red for one they are short on. The whole point of
-- the row is answering "can I make this yet", so the answer is a colour rather than a number to read.
local ENOUGH = Color3.fromRGB(150, 200, 140)
local SHORT = Color3.fromRGB(214, 106, 96)

local CraftGui = {}
CraftGui.__index = CraftGui

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

local function stroke(inst, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency or 0.5
	s.Thickness = thickness or 1
	s.Parent = inst
	return s
end

function CraftGui.new()
	local self = setmetatable({}, CraftGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "CraftGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 17
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
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = Responsive.IsSmallScreen() and UDim2.fromScale(0.95, 0.8)
		or UDim2.fromOffset(560, 440)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	stroke(panel, RUNE, 0.55, 2)
	Responsive.Scale(panel)
	self.panel = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 30)
	title.Position = UDim2.new(0, 12, 0, 12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 19
	title.TextColor3 = RUNE
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "โรงตีเหล็ก"
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(26, 26)
	close.BackgroundColor3 = Color3.fromRGB(70, 74, 84)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBold
	close.TextSize = 15
	close.TextColor3 = TEXT_LIGHT
	close.Text = "\195\151"
	close.Parent = panel
	corner(close, UDim.new(0, 6))
	close.Activated:Connect(function()
		UiSound.Play("Click")
		self:Hide()
	end)

	-- The row of tabs. Built once and refilled on every snapshot, since the tab list comes down with it.
	local tabBar = Instance.new("Frame")
	tabBar.Name = "Tabs"
	tabBar.Position = UDim2.fromOffset(12, 48)
	tabBar.Size = UDim2.new(1, -24, 0, 28)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = panel
	self.tabBar = tabBar

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	local body = Instance.new("Frame")
	body.Position = UDim2.fromOffset(12, 84)
	body.Size = UDim2.new(1, -24, 1, -96)
	body.BackgroundColor3 = STONE_DEEP
	body.BorderSizePixel = 0
	body.Parent = panel
	corner(body, UDim.new(0, 10))

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(6, 6)
	list.Size = UDim2.new(1, -12, 1, -12)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = body
	self.list = list

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- Which page is open. The only thing this window remembers between snapshots: redrawing after a craft
	-- should leave the player looking at the page they were on, not throw them back to the first one.
	self.activeTab = nil
	self.snapshot = nil
	self.onCraft = nil
	return self
end

function CraftGui:OnCraft(callback) self.onCraft = callback end

-- One recipe: what it makes on the left, the materials it eats underneath, and the button on the right.
-- Sized by the material count rather than fixed, so a five-material recipe is not squeezed into the same
-- height as a two-material one.
local function recipeRow(parent, order, entry, onClick)
	local height = 34 + #entry.materials * 16

	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -4, 0, height)
	frame.BackgroundColor3 = Color3.fromRGB(44, 46, 56)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, UDim.new(0, 6))

	local image = Instance.new("ImageLabel")
	image.Size = UDim2.fromOffset(28, 28)
	image.Position = UDim2.fromOffset(6, 5)
	image.BackgroundTransparency = 1
	image.Image = entry.icon or ""
	image.Parent = frame

	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(40, 6)
	label.Size = UDim2.new(1, -120, 0, 18)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = TEXT_LIGHT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = entry.name
	label.Parent = frame

	for i, material in ipairs(entry.materials) do
		local line = Instance.new("TextLabel")
		line.Position = UDim2.fromOffset(40, 26 + (i - 1) * 16)
		line.Size = UDim2.new(1, -120, 0, 15)
		line.BackgroundTransparency = 1
		line.Font = Enum.Font.Gotham
		line.TextSize = 11
		-- Coloured per material, not per recipe: when a craft is refused, this says WHICH ingredient is the
		-- one still missing rather than only that something is.
		line.TextColor3 = material.have >= material.need and ENOUGH or SHORT
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.Text = ("%s %d/%d"):format(material.name, material.have, material.need)
		line.Parent = frame
	end

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -6, 0.5, 0)
	button.Size = UDim2.fromOffset(64, 28)
	-- A button the player cannot use yet is greyed rather than hidden: the recipe is still worth seeing, and
	-- a row that only appears once you can afford it never tells you what to go and gather.
	button.BackgroundColor3 = entry.affordable and ENOUGH or Color3.fromRGB(70, 74, 84)
	button.AutoButtonColor = entry.affordable
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextColor3 = entry.affordable and Color3.fromRGB(24, 26, 32) or TEXT_MUTED
	button.Text = "สร้าง"
	button.Parent = frame
	corner(button, UDim.new(0, 5))
	button.Activated:Connect(function()
		-- Silent when it is not craftable rather than firing a request the server would only refuse. The
		-- server still checks: this is presentation, not the rule.
		if not entry.affordable then return end
		UiSound.Play("Click")
		onClick()
	end)
	return frame
end

-- Redraws the recipe list for whichever tab is open. Separate from Show because switching tabs must not need
-- another round trip to the server -- the snapshot already holds every recipe on every page.
function CraftGui:Render()
	for _, child in ipairs(self.list:GetChildren()) do
		if not child:IsA("UIListLayout") then child:Destroy() end
	end
	if not self.snapshot then return end

	local shown = 0
	for _, entry in ipairs(self.snapshot.recipes or {}) do
		if entry.tab == self.activeTab then
			shown += 1
			recipeRow(self.list, shown, entry, function()
				if self.onCraft then self.onCraft(entry.index) end
			end)
		end
	end

	if shown == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -4, 0, 30)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 12
		empty.TextColor3 = TEXT_MUTED
		empty.Text = "ยังไม่มีสูตรในหมวดนี้"
		empty.Parent = self.list
	end

	-- The open tab is lit; the rest are flat. Redone on every render rather than only on a tab press, since
	-- the bar is rebuilt whenever a snapshot arrives.
	for _, button in ipairs(self.tabBar:GetChildren()) do
		if button:IsA("TextButton") then
			local active = button:GetAttribute("TabId") == self.activeTab
			button.BackgroundColor3 = active and RUNE or Color3.fromRGB(52, 55, 66)
			button.TextColor3 = active and Color3.fromRGB(24, 26, 32) or TEXT_MUTED
		end
	end
end

function CraftGui:Show(snapshot)
	self.snapshot = snapshot

	for _, child in ipairs(self.tabBar:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	local tabs = snapshot.tabs or {}
	-- Falls back to the first page only when the remembered one is gone, so a craft redraw keeps the player
	-- where they were.
	local stillThere = false
	for _, tab in ipairs(tabs) do
		if tab.id == self.activeTab then stillThere = true end
	end
	if not stillThere then self.activeTab = tabs[1] and tabs[1].id end

	for order, tab in ipairs(tabs) do
		local button = Instance.new("TextButton")
		button.LayoutOrder = order
		button.Size = UDim2.fromOffset(120, 28)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.TextSize = 12
		button.Text = tab.name
		button:SetAttribute("TabId", tab.id)
		button.Parent = self.tabBar
		corner(button, UDim.new(0, 6))
		button.Activated:Connect(function()
			UiSound.Play("Click")
			self.activeTab = tab.id
			self:Render()
		end)
	end

	self:Render()
	self.gui.Enabled = true
end

function CraftGui:Hide()
	self.gui.Enabled = false
end

function CraftGui:IsOpen()
	return self.gui.Enabled
end

return CraftGui
