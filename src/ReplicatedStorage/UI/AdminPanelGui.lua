-- AdminPanelGui: the F3 roster. One row per player, with everything an admin can change about them.
--
-- Pure builder, like the other GUIs here: it draws the rows it is handed and reports button presses through
-- callbacks. Who may open it, and whether any of the buttons do anything, is the server's business.
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local ROW = Color3.fromRGB(44, 47, 58)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)
local TIKTOK = Color3.fromRGB(255, 62, 82)

local ROW_HEIGHT = 74

local AdminPanelGui = {}
AdminPanelGui.__index = AdminPanelGui

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

local function button(parent, text, colour, width, x)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width, 26)
	b.Position = UDim2.new(0, x, 0, 42)
	b.BackgroundColor3 = colour
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = TEXT_LIGHT
	b.Text = text
	b.Parent = parent
	corner(b, UDim.new(0, 6))
	return b
end

function AdminPanelGui.new()
	local self = setmetatable({}, AdminPanelGui)
	self.callbacks = {}
	self.classes = {}
	self.maxLevel = 100

	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminPanelGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- Above everything else an admin might have open.
	gui.DisplayOrder = 30
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
	backdrop.Activated:Connect(function() self:Hide() end)

	local small = Responsive.IsSmallScreen()
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = small and UDim2.fromScale(0.96, 0.9) or UDim2.fromOffset(760, 540)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	stroke(panel, RUNE, 0.5, 2)
	Responsive.Scale(panel)
	self.panel = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 30)
	title.Position = UDim2.new(0, 12, 0, 12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 19
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = RUNE
	title.Text = "แผงแอดมิน"
	title.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, -24, 0, 18)
	hint.Position = UDim2.new(0, 12, 0, 40)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 12
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = TEXT_MUTED
	hint.Text = "กด F3 เพื่อปิด · แก้เลเวล/อาชีพ · วาปไปหา/ดึงมาหา · ผูกชื่อ TikTok"
	hint.Parent = panel

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(30, 30)
	close.BackgroundColor3 = Color3.fromRGB(96, 62, 62)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBold
	close.TextSize = 15
	close.TextColor3 = TEXT_LIGHT
	close.Text = "✕"
	close.Parent = panel
	corner(close, UDim.new(0, 8))
	close.Activated:Connect(function()
		UiSound.Play("Click")
		self:Hide()
	end)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0, 12, 0, 66)
	list.Size = UDim2.new(1, -24, 1, -78)
	list.BackgroundColor3 = STONE_DEEP
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	corner(list, UDim.new(0, 10))
	self.list = list

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = list

	return self
end

function AdminPanelGui:On(name, fn)
	self.callbacks[name] = fn
end

function AdminPanelGui:fire(name, ...)
	local fn = self.callbacks[name]
	if fn then fn(...) end
end

-- Cycles to the next class in the list. A dropdown would be the obvious control, but Roblox has no native
-- one and a hand-built menu inside a scrolling list fights the scroll -- so the button shows the class and
-- advances, which needs no overlay and works the same on a phone.
function AdminPanelGui:nextClass(current)
	if #self.classes == 0 then return nil end
	for i, entry in ipairs(self.classes) do
		if entry.id == current then
			return self.classes[(i % #self.classes) + 1].id
		end
	end
	return self.classes[1].id
end

function AdminPanelGui:Render(data)
	for _, child in ipairs(self.list:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	self.classes = data and data.classes or {}
	self.maxLevel = data and data.maxLevel or 100

	for index, row in ipairs(data and data.rows or {}) do
		local card = Instance.new("Frame")
		card.Name = row.name
		card.LayoutOrder = index
		card.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		card.BackgroundColor3 = ROW
		card.BorderSizePixel = 0
		card.Parent = self.list
		corner(card, UDim.new(0, 8))
		if row.tiktok ~= "" then stroke(card, TIKTOK, 0.4, 2) end

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(0, 210, 0, 18)
		name.Position = UDim2.new(0, 10, 0, 8)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextSize = 13
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextColor3 = row.admin and RUNE or TEXT_LIGHT
		name.Text = row.admin and ("★ " .. row.name) or row.name
		name.Parent = card

		local info = Instance.new("TextLabel")
		info.Size = UDim2.new(0, 300, 0, 16)
		info.Position = UDim2.new(0, 10, 0, 24)
		info.BackgroundTransparency = 1
		info.Font = Enum.Font.Gotham
		info.TextSize = 11
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.TextTruncate = Enum.TextTruncate.AtEnd
		info.TextColor3 = TEXT_MUTED
		info.Text = ("เลเวล %d · %s%s"):format(row.level, row.className,
			row.tiktok ~= "" and ("  ·  🎮 @" .. row.tiktok) or "")
		info.Parent = card

		-- Level: a box you type into, applied on Enter or focus loss. Typing the number is the only control
		-- that works for "set them to 47" without forty clicks.
		local levelBox = Instance.new("TextBox")
		levelBox.Size = UDim2.fromOffset(56, 26)
		levelBox.Position = UDim2.new(0, 10, 0, 42)
		levelBox.BackgroundColor3 = STONE_DEEP
		levelBox.BorderSizePixel = 0
		levelBox.Font = Enum.Font.GothamBold
		levelBox.TextSize = 12
		levelBox.TextColor3 = TEXT_LIGHT
		levelBox.PlaceholderText = "lvl"
		levelBox.Text = tostring(row.level)
		levelBox.ClearTextOnFocus = false
		levelBox.Parent = card
		corner(levelBox, UDim.new(0, 6))
		levelBox.FocusLost:Connect(function(enter)
			if not enter then return end
			local wanted = tonumber(levelBox.Text)
			if not wanted then
				levelBox.Text = tostring(row.level)
				return
			end
			UiSound.Play("Click")
			self:fire("action", "level", row.userId, math.clamp(math.floor(wanted), 1, self.maxLevel))
		end)

		local classBtn = button(card, row.className, Color3.fromRGB(70, 62, 96), 108, 74)
		classBtn.Activated:Connect(function()
			UiSound.Play("Click")
			local nextId = self:nextClass(row.classId)
			if nextId then self:fire("action", "class", row.userId, nextId) end
		end)

		local goBtn = button(card, "ไปหา", Color3.fromRGB(58, 84, 108), 60, 188)
		goBtn.Activated:Connect(function()
			UiSound.Play("Click")
			self:fire("action", "tpto", row.userId)
		end)

		local bringBtn = button(card, "ดึงมา", Color3.fromRGB(58, 84, 108), 60, 254)
		bringBtn.Activated:Connect(function()
			UiSound.Play("Click")
			self:fire("action", "bring", row.userId)
		end)

		-- TikTok: typed in, applied on Enter. Empty clears the binding, which is how a stream is handed over.
		local tiktokBox = Instance.new("TextBox")
		tiktokBox.Size = UDim2.fromOffset(190, 26)
		tiktokBox.Position = UDim2.new(0, 320, 0, 42)
		tiktokBox.BackgroundColor3 = STONE_DEEP
		tiktokBox.BorderSizePixel = 0
		tiktokBox.Font = Enum.Font.Gotham
		tiktokBox.TextSize = 12
		tiktokBox.TextColor3 = row.tiktok ~= "" and TIKTOK or TEXT_LIGHT
		tiktokBox.PlaceholderText = "ชื่อ TikTok (ว่าง = ยกเลิก)"
		tiktokBox.Text = row.tiktok
		tiktokBox.ClearTextOnFocus = false
		tiktokBox.Parent = card
		corner(tiktokBox, UDim.new(0, 6))
		tiktokBox.FocusLost:Connect(function(enter)
			if not enter then return end
			UiSound.Play("Click")
			self:fire("action", "tiktok", row.userId, tiktokBox.Text)
		end)
	end
end

function AdminPanelGui:Show() self.gui.Enabled = true end
function AdminPanelGui:Hide() self.gui.Enabled = false end
function AdminPanelGui:IsOpen() return self.gui.Enabled end

return AdminPanelGui
