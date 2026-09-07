-- LoadingGui: pure UI builder for the logo + "Loading..." + segmented progress bar screen.
local SEGMENTS = 18

local LoadingGui = {}
LoadingGui.__index = LoadingGui

function LoadingGui.new()
	local self = setmetatable({}, LoadingGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadingGui"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(0, 188, 196)
	root.BorderSizePixel = 0
	root.Parent = gui

	local logo = Instance.new("Frame")
	logo.Size = UDim2.new(0, 220, 0, 220)
	logo.Position = UDim2.new(0.5, -110, 0.5, -220)
	logo.BackgroundColor3 = Color3.fromRGB(10, 90, 210)
	logo.Parent = root
	local logoCorner = Instance.new("UICorner")
	logoCorner.CornerRadius = UDim.new(1, 0)
	logoCorner.Parent = logo
	local logoLabel = Instance.new("TextLabel")
	logoLabel.Size = UDim2.fromScale(1, 1)
	logoLabel.BackgroundTransparency = 1
	logoLabel.Font = Enum.Font.SourceSansBold
	logoLabel.TextSize = 22
	logoLabel.TextColor3 = Color3.new(1, 1, 1)
	logoLabel.Text = "LOGO"
	logoLabel.Parent = logo

	local loadingLabel = Instance.new("TextLabel")
	loadingLabel.Size = UDim2.new(0, 400, 0, 60)
	loadingLabel.Position = UDim2.new(0.5, -200, 0.5, 40)
	loadingLabel.BackgroundTransparency = 1
	loadingLabel.Font = Enum.Font.SourceSansBold
	loadingLabel.TextSize = 40
	loadingLabel.TextColor3 = Color3.new(1, 1, 1)
	loadingLabel.TextXAlignment = Enum.TextXAlignment.Left
	loadingLabel.Text = "Loading..."
	loadingLabel.Parent = root

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(0, 860, 0, 60)
	barBg.Position = UDim2.new(0.5, -430, 0.5, 110)
	barBg.BackgroundColor3 = Color3.fromRGB(0, 188, 196)
	barBg.Parent = root
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = barBg
	local barStroke = Instance.new("UIStroke")
	barStroke.Color = Color3.new(0, 0.4, 0.85)
	barStroke.Thickness = 4
	barStroke.Parent = barBg

	local segmentsFrame = Instance.new("Frame")
	segmentsFrame.Size = UDim2.new(1, -16, 1, -16)
	segmentsFrame.Position = UDim2.new(0, 8, 0, 8)
	segmentsFrame.BackgroundTransparency = 1
	segmentsFrame.Parent = barBg
	local segLayout = Instance.new("UIListLayout")
	segLayout.FillDirection = Enum.FillDirection.Horizontal
	segLayout.Padding = UDim.new(0, 4)
	segLayout.Parent = segmentsFrame

	self.segments = {}
	for i = 1, SEGMENTS do
		local seg = Instance.new("Frame")
		seg.Size = UDim2.new(1 / SEGMENTS, -4, 1, 0)
		seg.BackgroundColor3 = Color3.new(1, 1, 1)
		seg.BackgroundTransparency = 1
		seg.LayoutOrder = i
		seg.Parent = segmentsFrame
		self.segments[i] = seg
	end

	self.gui = gui
	return self
end

function LoadingGui:SetProgress(fraction)
	local filled = math.floor(math.clamp(fraction, 0, 1) * #self.segments + 0.5)
	for i, seg in ipairs(self.segments) do
		seg.BackgroundTransparency = (i <= filled) and 0 or 1
	end
end

function LoadingGui:Show()
	self.gui.Enabled = true
end

function LoadingGui:Destroy()
	self.gui:Destroy()
end

return LoadingGui
