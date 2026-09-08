-- BoardFeedGui: the guild board's floating feed, down the left of the game screen.
--
-- New posts appear here without the stone being open, hold for a few seconds, then fade. It is a notice,
-- not a reader: the full board still lives inside the stone.
--
-- Nothing here is clickable. The feed sits over gameplay, so a stray tap must reach the game, not the feed.
local SocialConfig = require(script.Parent.Parent.SocialConfig)
local AvatarThumbnails = require(script.Parent.AvatarThumbnails)
local Responsive = require(script.Parent.Responsive)

local BoardFeedGui = {}
BoardFeedGui.__index = BoardFeedGui

local STONE_DEEP = Color3.fromRGB(18, 19, 25)
local ACCENT = Color3.fromRGB(216, 172, 84)
local TEXT_LIGHT = Color3.fromRGB(238, 240, 246)

local ROW_HEIGHT = 46
local ROW_WIDTH = 300

function BoardFeedGui.new()
	local self = setmetatable({}, BoardFeedGui)
	self.rows = {} -- newest last

	local gui = Instance.new("ScreenGui")
	gui.Name = "BoardFeedGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5 -- under the stone and the bag, over the world
	self.gui = gui

	-- Anchored to the UPPER left. The lower left belongs to the vitals cluster, and the feed must not
	-- cover the health bar.
	local holder = Instance.new("Frame")
	holder.Name = "Feed"
	holder.Position = UDim2.new(0, 16, 0, 90)
	holder.Size = UDim2.fromOffset(ROW_WIDTH, ROW_HEIGHT * SocialConfig.FeedCount + 30)
	holder.BackgroundTransparency = 1
	-- The feed never takes input: taps go through to the game underneath.
	holder.Active = false
	holder.Parent = gui
	self.holder = holder

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 5)
	layout.Parent = holder

	Responsive.Scale(holder, 0.7)
	return self
end

-- Fades a row out and removes it. Kept separate so both the timer and being pushed out can use it.
local function fadeOut(row, seconds)
	if row:GetAttribute("WOLD_Fading") then return end
	row:SetAttribute("WOLD_Fading", true)

	local TweenService = game:GetService("TweenService")
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(row, info, { BackgroundTransparency = 1 }):Play()
	for _, d in ipairs(row:GetDescendants()) do
		if d:IsA("TextLabel") then
			TweenService:Create(d, info, { TextTransparency = 1 }):Play()
		elseif d:IsA("ImageLabel") then
			TweenService:Create(d, info, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		end
	end
	task.delay(seconds, function()
		if row.Parent then row:Destroy() end
	end)
end

function BoardFeedGui:Add(post)
	local row = Instance.new("Frame")
	row.Size = UDim2.fromOffset(ROW_WIDTH, ROW_HEIGHT)
	row.BackgroundColor3 = STONE_DEEP
	row.BackgroundTransparency = 0.25
	row.BorderSizePixel = 0
	row.Active = false
	-- Newest at the bottom, so the eye follows one direction as posts arrive.
	row.LayoutOrder = post.id or os.time()
	row.Parent = self.holder

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = row

	local s = Instance.new("UIStroke")
	s.Color = ACCENT
	s.Transparency = 0.75
	s.Thickness = 1
	s.Parent = row

	local face = Instance.new("ImageLabel")
	face.Position = UDim2.new(0, 6, 0, 6)
	face.Size = UDim2.fromOffset(34, 34)
	face.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
	face.BorderSizePixel = 0
	face.Parent = row
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = face
	AvatarThumbnails.Get(post.userId, function(image)
		if face.Parent then face.Image = image end
	end)

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.new(0, 46, 0, 4)
	name.Size = UDim2.new(1, -52, 0, 16)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 12
	name.TextColor3 = ACCENT
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = post.name
	name.Parent = row

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.new(0, 46, 0, 20)
	text.Size = UDim2.new(1, -52, 0, 22)
	text.Font = Enum.Font.Gotham
	text.TextSize = 12
	text.TextColor3 = TEXT_LIGHT
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.Text = post.text
	text.Parent = row

	table.insert(self.rows, row)

	-- A sixth post pushes the oldest out immediately rather than waiting for its timer.
	while #self.rows > SocialConfig.FeedCount do
		local oldest = table.remove(self.rows, 1)
		if oldest.Parent then fadeOut(oldest, 0.25) end
	end

	task.delay(SocialConfig.FeedSeconds, function()
		if not row.Parent then return end
		for i, r in ipairs(self.rows) do
			if r == row then
				table.remove(self.rows, i)
				break
			end
		end
		fadeOut(row, SocialConfig.FeedFadeSeconds)
	end)
end

return BoardFeedGui
