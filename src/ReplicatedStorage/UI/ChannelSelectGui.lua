-- ChannelSelectGui: pure UI builder for the mode-tabs + channel-rows screen. No networking in this file.
local CAP = 30
local ROWS, COLS = 2, 15 -- 30 avatar slots per channel, matching the reference mockup

local ChannelSelectGui = {}
ChannelSelectGui.__index = ChannelSelectGui

local ACTIVE_MODES = { Roleplay = true }
local MODE_ORDER = { "Stories", "Roleplay", "Tanding" }

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 8)
	c.Parent = parent
	return c
end

function ChannelSelectGui.new()
	local self = setmetatable({}, ChannelSelectGui)
	self.onJoin = nil
	self.rows = {} -- rows["Roleplay"][1] = { frame, countLabel, joinButton, statusLabel, avatars = {ImageLabel,...} }

	local gui = Instance.new("ScreenGui")
	gui.Name = "ChannelSelectGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
	root.BorderSizePixel = 0
	root.Parent = gui

	-- mode tab bar
	local tabBar = Instance.new("Frame")
	tabBar.Size = UDim2.new(0, 420, 0, 50)
	tabBar.Position = UDim2.new(1, -440, 0, 20)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = root
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.Parent = tabBar

	self.tabs = {}
	for _, mode in ipairs(MODE_ORDER) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 130, 1, 0)
		btn.Text = mode == "Roleplay" and "Roleplay Mode" or (mode .. " Mode")
		btn.Font = Enum.Font.SourceSansBold
		btn.TextSize = 16
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.BackgroundColor3 = mode == "Roleplay" and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(150, 150, 150)
		btn.AutoButtonColor = ACTIVE_MODES[mode] == true
		btn.Parent = tabBar
		corner(btn, UDim.new(1, 0))
		self.tabs[mode] = btn
	end

	-- channel list — scale-based, not fixed-pixel: a fixed 1100px width centered via "50% - 550px" goes negative
	-- (pushes content off-screen to the left) on any viewport narrower than ~1100px, which real Studio/player
	-- windows routinely are. Scale keeps this correct at any PC window size; full mobile layout is a later pass.
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(0.85, 0, 0, 560)
	list.Position = UDim2.new(0.075, 0, 0, 100)
	list.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	list.CanvasSize = UDim2.new(0, 0, 0, 5 * 150)
	list.Parent = root
	corner(list, UDim.new(0, 20))
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 20)
	pad.PaddingRight = UDim.new(0, 20)
	pad.PaddingTop = UDim.new(0, 20)
	pad.Parent = list

	self.rows.Roleplay = {}
	for channel = 1, 5 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 130)
		row.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
		row.LayoutOrder = channel
		row.Parent = list
		corner(row)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, 100, 1, 0)
		nameLabel.Position = UDim2.new(0, 20, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.SourceSansBold
		nameLabel.TextSize = 22
		nameLabel.Text = "เชิฟ " .. channel
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		local avatarGrid = Instance.new("Frame")
		avatarGrid.Size = UDim2.new(0, 700, 0, 90)
		avatarGrid.Position = UDim2.new(0, 130, 0.5, -45)
		avatarGrid.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		avatarGrid.Parent = row
		corner(avatarGrid, UDim.new(0, 6))
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0, 44, 0, 40)
		grid.CellPadding = UDim2.new(0, 2, 0, 2)
		grid.Parent = avatarGrid
		local gpad = Instance.new("UIPadding")
		gpad.PaddingLeft = UDim.new(0, 5)
		gpad.PaddingTop = UDim.new(0, 5)
		gpad.Parent = avatarGrid

		local avatars = {}
		for i = 1, CAP do
			local icon = Instance.new("ImageLabel")
			icon.Image = ""
			icon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			icon.LayoutOrder = i
			icon.Visible = false
			icon.Parent = avatarGrid
			corner(icon, UDim.new(1, 0))
			avatars[i] = icon
		end

		local countLabel = Instance.new("TextLabel")
		countLabel.Size = UDim2.new(0, 90, 0, 40)
		countLabel.Position = UDim2.new(1, -190, 0, 20)
		countLabel.BackgroundTransparency = 1
		countLabel.Font = Enum.Font.SourceSansBold
		countLabel.TextSize = 22
		countLabel.Text = "0/" .. CAP
		countLabel.Parent = row

		local statusLabel = Instance.new("TextLabel")
		statusLabel.Size = UDim2.new(0, 190, 0, 20)
		statusLabel.Position = UDim2.new(1, -190, 0, 60)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Font = Enum.Font.SourceSans
		statusLabel.TextSize = 14
		statusLabel.TextColor3 = Color3.fromRGB(200, 60, 50)
		statusLabel.Text = ""
		statusLabel.Parent = row

		local joinButton = Instance.new("TextButton")
		joinButton.Size = UDim2.new(0, 90, 0, 40)
		joinButton.Position = UDim2.new(1, -90, 0, 70)
		joinButton.Font = Enum.Font.SourceSansBold
		joinButton.TextSize = 18
		joinButton.TextColor3 = Color3.new(1, 1, 1)
		joinButton.BackgroundColor3 = Color3.fromRGB(60, 175, 90)
		joinButton.Text = "JOIN"
		joinButton.Parent = row
		corner(joinButton, UDim.new(0, 10))
		joinButton.MouseButton1Click:Connect(function()
			if self.onJoin then self.onJoin("Roleplay", channel) end
		end)

		self.rows.Roleplay[channel] = {
			frame = row, countLabel = countLabel, joinButton = joinButton, statusLabel = statusLabel, avatars = avatars,
		}
	end

	-- Stories/Tanding: a single "coming soon" placeholder frame each, swapped in when that tab is selected
	for _, mode in ipairs({ "Stories", "Tanding" }) do
		local soon = Instance.new("TextLabel")
		soon.Size = UDim2.new(1, 0, 1, 0)
		soon.BackgroundTransparency = 1
		soon.Font = Enum.Font.SourceSansBold
		soon.TextSize = 28
		soon.TextColor3 = Color3.fromRGB(120, 120, 120)
		soon.Text = "เร็วๆ นี้"
		soon.Visible = false
		soon.Parent = root
		self.rows[mode] = { comingSoon = soon }
	end

	self.list = list
	self.gui = gui
	self:_selectMode("Roleplay")
	for mode, btn in pairs(self.tabs) do
		btn.MouseButton1Click:Connect(function()
			if ACTIVE_MODES[mode] then self:_selectMode(mode) end
		end)
	end
	return self
end

function ChannelSelectGui:_selectMode(mode)
	self.list.Visible = (mode == "Roleplay")
	for _, m in ipairs(MODE_ORDER) do
		if self.rows[m] and self.rows[m].comingSoon then
			self.rows[m].comingSoon.Visible = (m == mode)
		end
		self.tabs[m].BackgroundColor3 = (m == mode) and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(150, 150, 150)
	end
end

function ChannelSelectGui:OnJoin(callback)
	self.onJoin = callback
end

function ChannelSelectGui:SetChannelData(mode, channel, data)
	local row = self.rows[mode] and self.rows[mode][channel]
	if not row then return end
	row.countLabel.Text = data.count .. "/" .. CAP
	row.joinButton.Text = data.full and "FULL" or "JOIN"
	row.joinButton.BackgroundColor3 = data.full and Color3.fromRGB(200, 60, 50) or Color3.fromRGB(60, 175, 90)
	row.joinButton.Active = not data.full
	for i, icon in ipairs(row.avatars) do
		icon.Visible = i <= data.count
	end
	row._playerIds = data.playerIds
end

function ChannelSelectGui:SetRowAvatarImage(mode, channel, slotIndex, content)
	local row = self.rows[mode] and self.rows[mode][channel]
	if row and row.avatars[slotIndex] then
		row.avatars[slotIndex].Image = content or ""
	end
end

function ChannelSelectGui:SetRowStatus(mode, channel, status)
	local row = self.rows[mode] and self.rows[mode][channel]
	if not row then return end
	local text = { idle = "", connecting = "กำลังเชื่อมต่อ...", error = "เชื่อมต่อไม่สำเร็จ ลองอีกครั้ง" }
	row.statusLabel.Text = text[status] or ""
	row.joinButton.Active = (status ~= "connecting")
end

function ChannelSelectGui:Show()
	self.gui.Enabled = true
end

function ChannelSelectGui:Destroy()
	self.gui:Destroy()
end

return ChannelSelectGui
