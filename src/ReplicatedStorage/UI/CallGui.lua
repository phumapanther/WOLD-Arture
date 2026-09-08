-- CallGui: the telepathy call panel — ringing out, ringing in, and connected.
--
-- A small panel at the top of the screen rather than a page inside the stone: a call has to be answerable
-- with the stone closed, and visible while you keep playing.
--
-- No audio. The buttons and states are real; the voice arrives in a later phase.
local SocialConfig = require(script.Parent.Parent.SocialConfig)
local AvatarThumbnails = require(script.Parent.AvatarThumbnails)
local Responsive = require(script.Parent.Responsive)

local CallGui = {}
CallGui.__index = CallGui

local STONE_DEEP = Color3.fromRGB(18, 19, 25)
local RUNE = Color3.fromRGB(126, 214, 232)
local TEXT_LIGHT = Color3.fromRGB(238, 240, 246)
local TEXT_MUTED = Color3.fromRGB(150, 156, 172)
local ANSWER = Color3.fromRGB(58, 120, 78)
local HANGUP = Color3.fromRGB(120, 56, 52)

function CallGui.new()
	local self = setmetatable({}, CallGui)
	self.callbacks = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "CallGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30 -- above the stone: a call must be answerable whatever else is open
	gui.Enabled = false
	self.gui = gui

	local panel = Instance.new("Frame")
	panel.Name = "Call"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 18)
	panel.Size = UDim2.fromOffset(300, 96)
	panel.BackgroundColor3 = STONE_DEEP
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = gui
	self.panel = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = RUNE
	stroke.Transparency = 0.4
	stroke.Thickness = 2
	stroke.Parent = panel
	self.stroke = stroke

	local face = Instance.new("ImageLabel")
	face.Position = UDim2.new(0, 10, 0, 10)
	face.Size = UDim2.fromOffset(44, 44)
	face.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
	face.BorderSizePixel = 0
	face.Parent = panel
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = face
	self.face = face

	local function label(text, size, color, y, height)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.new(0, 62, 0, y)
		l.Size = UDim2.new(1, -72, 0, height)
		l.Font = Enum.Font.GothamMedium
		l.TextSize = size
		l.TextColor3 = color
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = text
		l.Parent = panel
		return l
	end

	self.nameLabel = label("", 14, TEXT_LIGHT, 10, 18)
	self.nameLabel.Font = Enum.Font.GothamBold
	self.stateLabel = label("", 12, TEXT_MUTED, 30, 16)

	local function actionButton(text, color, x, width)
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(0, 1)
		b.Position = UDim2.new(x, x > 0 and 5 or 10, 1, -10)
		b.Size = UDim2.new(width, -15, 0, 30)
		b.BackgroundColor3 = color
		b.BackgroundTransparency = 0.05
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 13
		b.TextColor3 = TEXT_LIGHT
		b.Text = text
		b.Parent = panel
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = b
		return b
	end

	self.answerButton = actionButton("รับสาย", ANSWER, 0, 0.5)
	self.endButton = actionButton("วางสาย", HANGUP, 0.5, 0.5)

	self.answerButton.Activated:Connect(function()
		if self.callbacks.answer then self.callbacks.answer() end
	end)
	self.endButton.Activated:Connect(function()
		if self.callbacks.hangUp then self.callbacks.hangUp() end
	end)

	Responsive.Scale(panel, 0.8)
	return self
end

function CallGui:On(name, fn)
	self.callbacks[name] = fn
end

-- state: "calling" (we rang them) | "incoming" (they rang us) | "active"
function CallGui:Show(state, userId, name)
	self.nameLabel.Text = name or ""
	AvatarThumbnails.Get(userId, function(image)
		if self.face.Parent and type(image) == "string" then self.face.Image = image end
	end)

	if state == "calling" then
		self.stateLabel.Text = "กำลังโทร..."
		-- Nothing to answer on our own outgoing call; only hanging up makes sense.
		self.answerButton.Visible = false
		self.endButton.Size = UDim2.new(1, -20, 0, 30)
		self.endButton.Position = UDim2.new(0, 10, 1, -10)
		self.endButton.Text = "ยกเลิก"
	elseif state == "incoming" then
		self.stateLabel.Text = "สายเรียกเข้า"
		self.answerButton.Visible = true
		self.endButton.Size = UDim2.new(0.5, -15, 0, 30)
		self.endButton.Position = UDim2.new(0.5, 5, 1, -10)
		self.endButton.Text = "ไม่รับ"
	else
		self.stateLabel.Text = "กำลังคุยสาย (ยังไม่มีเสียง)"
		self.answerButton.Visible = false
		self.endButton.Size = UDim2.new(1, -20, 0, 30)
		self.endButton.Position = UDim2.new(0, 10, 1, -10)
		self.endButton.Text = "วางสาย"
	end

	self.gui.Enabled = true
end

function CallGui:Hide()
	self.gui.Enabled = false
end

function CallGui:IsOpen()
	return self.gui.Enabled
end

return CallGui
