-- LoadingGui: the steampunk loading screen — the painted skyline behind, the game's name, a brass progress
-- bar and a rotating status line.
--
-- The artwork lives at assets/ui/loading-background.jpg and has to be uploaded by hand (create.roblox.com ->
-- Creations -> Images), because image upload is a website action. Paste the returned id into BACKGROUND_IMAGE
-- below. An empty id is safe: the painted gradient underneath stands in for it, in the same brass and teal.
local BACKGROUND_IMAGE = "" -- assets/ui/loading-background.jpg
local L = require(script.Parent.Parent.Locale).L

local LoadingGui = {}
LoadingGui.__index = LoadingGui

-- Palette lifted from the artwork, so the fallback and the real image agree.
local SKY = Color3.fromRGB(224, 196, 148)
local SKY_DEEP = Color3.fromRGB(168, 134, 92)
local BRASS = Color3.fromRGB(198, 138, 58)
local BRASS_LIGHT = Color3.fromRGB(240, 190, 104)
local TEAL = Color3.fromRGB(64, 214, 220)
local TEAL_DEEP = Color3.fromRGB(28, 148, 168)
local INK = Color3.fromRGB(58, 36, 18)
local CREAM = Color3.fromRGB(248, 234, 200)

-- Cycled under the bar while loading, so a slow join still looks like it is doing something.
local STATUS_LINES = {
	L("กำลังโหลดทรัพยากรเกม..."),
	L("กำลังเตรียมโลก Arthue..."),
	L("กำลังจุดเตาไอน้ำ..."),
	L("กำลังปรับเฟืองและวาล์ว..."),
}

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 8)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 2
	s.Transparency = transparency or 0
	s.Parent = parent
	return s
end

function LoadingGui.new()
	local self = setmetatable({}, LoadingGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadingGui"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	self.gui = gui

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = SKY
	root.BorderSizePixel = 0
	root.Parent = gui
	-- Warm sky above, dusty ground below — the artwork's own vertical fade, so the screen reads the same
	-- whether or not the image has been uploaded yet.
	local skyGradient = Instance.new("UIGradient")
	skyGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 206, 214)),
		ColorSequenceKeypoint.new(0.45, SKY),
		ColorSequenceKeypoint.new(1, SKY_DEEP),
	})
	skyGradient.Rotation = 90
	skyGradient.Parent = root

	local art = Instance.new("ImageLabel")
	art.Name = "Artwork"
	art.Size = UDim2.fromScale(1, 1)
	art.BackgroundTransparency = 1
	art.Image = BACKGROUND_IMAGE
	art.ImageTransparency = (BACKGROUND_IMAGE == "") and 1 or 0
	-- Crop rather than stretch: the art is a wide banner and a phone in portrait is anything but.
	art.ScaleType = Enum.ScaleType.Crop
	art.Parent = root

	--------------------------------------------------------------------------
	-- Title
	--------------------------------------------------------------------------
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 1)
	title.Position = UDim2.new(0.5, 0, 0.5, -24)
	title.Size = UDim2.new(0.8, 0, 0, 76)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = BRASS_LIGHT
	title.Text = "ARTHUE WORLD"
	title.Parent = root
	stroke(title, INK, 4, 0.15)

	local titleGradient = Instance.new("UIGradient")
	titleGradient.Color = ColorSequence.new(Color3.fromRGB(255, 224, 150), BRASS)
	titleGradient.Rotation = 90
	titleGradient.Parent = title

	--------------------------------------------------------------------------
	-- Progress bar: a brass rail with a glowing teal fill, matching the artwork.
	--------------------------------------------------------------------------
	local barHolder = Instance.new("Frame")
	barHolder.Name = "BarHolder"
	barHolder.AnchorPoint = Vector2.new(0.5, 0)
	barHolder.Position = UDim2.new(0.5, 0, 0.5, 8)
	barHolder.Size = UDim2.new(0.62, 0, 0, 34)
	barHolder.BackgroundColor3 = Color3.fromRGB(92, 62, 32)
	barHolder.BorderSizePixel = 0
	barHolder.Parent = root
	corner(barHolder, UDim.new(1, 0))
	stroke(barHolder, BRASS, 3)
	local barSize = Instance.new("UISizeConstraint")
	barSize.MaxSize = Vector2.new(760, 40)
	barSize.MinSize = Vector2.new(200, 22)
	barSize.Parent = barHolder

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, -8)
	fill.Position = UDim2.new(0, 4, 0, 4)
	fill.BackgroundColor3 = TEAL
	fill.BorderSizePixel = 0
	fill.Parent = barHolder
	corner(fill, UDim.new(1, 0))
	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new(TEAL, TEAL_DEEP)
	fillGradient.Rotation = 90
	fillGradient.Parent = fill
	self.fill = fill

	local percent = Instance.new("TextLabel")
	percent.Name = "Percent"
	percent.AnchorPoint = Vector2.new(0, 0.5)
	percent.Position = UDim2.new(1, 12, 0.5, 0)
	percent.Size = UDim2.fromOffset(90, 30)
	percent.BackgroundTransparency = 1
	percent.Font = Enum.Font.GothamBlack
	percent.TextSize = 22
	percent.TextColor3 = CREAM
	percent.TextXAlignment = Enum.TextXAlignment.Left
	percent.Text = "0%"
	percent.Parent = barHolder
	stroke(percent, INK, 3, 0.2)
	self.percent = percent

	--------------------------------------------------------------------------
	-- Status line
	--------------------------------------------------------------------------
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0.5, 58)
	status.Size = UDim2.new(0.8, 0, 0, 26)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBold
	status.TextScaled = true
	status.TextColor3 = CREAM
	status.Text = STATUS_LINES[1]
	status.Parent = root
	stroke(status, INK, 3, 0.25)
	local statusSize = Instance.new("UITextSizeConstraint")
	statusSize.MaxTextSize = 20
	statusSize.Parent = status
	self.status = status

	-- Rotate the status text while the screen is up.
	self.statusIndex = 1
	task.spawn(function()
		while self.gui.Parent do
			task.wait(2.2)
			if not self.gui.Parent then return end
			self.statusIndex = (self.statusIndex % #STATUS_LINES) + 1
			self.status.Text = STATUS_LINES[self.statusIndex]
		end
	end)

	return self
end

function LoadingGui:SetProgress(fraction)
	fraction = math.clamp(fraction, 0, 1)
	self.fill.Size = UDim2.new(fraction, -8, 1, -8)
	self.percent.Text = ("%d%%"):format(math.floor(fraction * 100 + 0.5))
end

function LoadingGui:Show()
	self.gui.Enabled = true
end

function LoadingGui:Destroy()
	self.gui:Destroy()
end

return LoadingGui
