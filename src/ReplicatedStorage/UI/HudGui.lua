-- HudGui: pure UI builder for the in-game HUD (avatar, vitals bars, hotbar, 3-dot menu). Stat bars show static
-- full values for now — sub-project 1 (player data & life cycle) will wire them to real values later.
local HudGui = {}
HudGui.__index = HudGui

local BARS = {
	{ key = "hp", label = "เลือด", color = Color3.fromRGB(220, 60, 60) },
	{ key = "stamina", label = "สตามิน่า", color = Color3.fromRGB(60, 200, 100) },
	{ key = "mana", label = "มานา", color = Color3.fromRGB(70, 140, 230) },
	{ key = "hunger", label = "ความหิว", color = Color3.fromRGB(210, 160, 60) },
	{ key = "armor", label = "เกราะ", color = Color3.fromRGB(160, 160, 170) },
}

local HOTBAR_SLOTS = 6

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 8)
	c.Parent = parent
	return c
end

function HudGui.new()
	local self = setmetatable({}, HudGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "HudGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local TOP_BAR = 56

	-- avatar + vitals, top-left
	local avatar = Instance.new("ImageLabel")
	avatar.Size = UDim2.new(0, 64, 0, 64)
	avatar.Position = UDim2.new(0, 20, 0, TOP_BAR + 20)
	avatar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	avatar.Image = ""
	avatar.Parent = gui
	corner(avatar, UDim.new(1, 0))
	self.avatar = avatar

	local barsFrame = Instance.new("Frame")
	barsFrame.Size = UDim2.new(0, 220, 0, 64)
	barsFrame.Position = UDim2.new(0, 96, 0, TOP_BAR + 20)
	barsFrame.BackgroundTransparency = 1
	barsFrame.Parent = gui
	local barsLayout = Instance.new("UIListLayout")
	barsLayout.Padding = UDim.new(0, 4)
	barsLayout.Parent = barsFrame

	self.bars = {}
	for i, def in ipairs(BARS) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 10)
		row.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Parent = barsFrame
		corner(row, UDim.new(0, 5))

		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = def.color
		fill.BorderSizePixel = 0
		fill.Parent = row
		corner(fill, UDim.new(0, 5))

		self.bars[def.key] = fill
	end

	-- 3-dot menu, top-right
	local menuButton = Instance.new("TextButton")
	menuButton.Size = UDim2.new(0, 44, 0, 44)
	menuButton.Position = UDim2.new(1, -64, 0, TOP_BAR + 20)
	menuButton.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	menuButton.Text = "\226\128\162\226\128\162\226\128\162" -- three bullet characters; a vertical-ellipsis glyph didn't render in SourceSansBold
	menuButton.TextColor3 = Color3.new(1, 1, 1)
	menuButton.TextSize = 18
	menuButton.Font = Enum.Font.SourceSansBold
	menuButton.Parent = gui
	corner(menuButton, UDim.new(1, 0))

	local menuPanel = Instance.new("Frame")
	menuPanel.Size = UDim2.new(0, 200, 0, 56)
	menuPanel.Position = UDim2.new(1, -220, 0, TOP_BAR + 72)
	menuPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	menuPanel.Visible = false
	menuPanel.Parent = gui
	corner(menuPanel, UDim.new(0, 10))

	local lobbyButton = Instance.new("TextButton")
	lobbyButton.Size = UDim2.new(1, -16, 1, -16)
	lobbyButton.Position = UDim2.new(0, 8, 0, 8)
	lobbyButton.BackgroundColor3 = Color3.fromRGB(200, 60, 50)
	lobbyButton.Text = "กลับหน้า Lobby"
	lobbyButton.TextColor3 = Color3.new(1, 1, 1)
	lobbyButton.Font = Enum.Font.SourceSansBold
	lobbyButton.TextSize = 16
	lobbyButton.Parent = menuPanel
	corner(lobbyButton, UDim.new(0, 8))
	self.lobbyButton = lobbyButton

	menuButton.MouseButton1Click:Connect(function()
		menuPanel.Visible = not menuPanel.Visible
	end)

	-- hotbar, bottom-center
	local hotbar = Instance.new("Frame")
	hotbar.AnchorPoint = Vector2.new(0.5, 1)
	hotbar.Size = UDim2.new(0, HOTBAR_SLOTS * 64 + (HOTBAR_SLOTS - 1) * 8, 0, 64)
	hotbar.Position = UDim2.new(0.5, 0, 1, -20)
	hotbar.BackgroundTransparency = 1
	hotbar.Parent = gui
	local hotbarLayout = Instance.new("UIListLayout")
	hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
	hotbarLayout.Padding = UDim.new(0, 8)
	hotbarLayout.Parent = hotbar

	self.slots = {}
	for i = 1, HOTBAR_SLOTS do
		local slot = Instance.new("Frame")
		slot.Size = UDim2.new(0, 64, 0, 64)
		slot.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
		slot.LayoutOrder = i
		slot.Parent = hotbar
		corner(slot, UDim.new(0, 10))
		self.slots[i] = slot
	end

	self.gui = gui
	return self
end

-- SetBarFraction: 0..1. Stub for sub-project 1; call with 1 for every bar until real vitals exist.
function HudGui:SetBarFraction(key, fraction)
	local fill = self.bars[key]
	if fill then fill.Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0) end
end

function HudGui:SetAvatarImage(content)
	self.avatar.Image = content or ""
end

function HudGui:OnLobbyRequested(callback)
	self.lobbyButton.MouseButton1Click:Connect(callback)
end

function HudGui:Show()
	self.gui.Enabled = true
end

function HudGui:Destroy()
	self.gui:Destroy()
end

return HudGui
