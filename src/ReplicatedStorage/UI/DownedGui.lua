-- DownedGui: the screen shown while a player is downed — the world darkens, a large countdown sits in the
-- centre, and a respawn button below it skips the wait. Pure UI builder like HudGui; the controller owns all
-- the state and calls SetRemaining/Show/Hide.
--
-- See docs/superpowers/specs/2026-09-07-vitals-downed-design.md.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local DownedGui = {}
DownedGui.__index = DownedGui

local ACCENT = Color3.fromRGB(244, 197, 66)

-- "นับถอยหลังเกิดใหม่" reads best large and thin; the vignette keeps the world faintly visible so the player
-- can still see enough to crawl.
local COUNTDOWN_COLOR = Color3.fromRGB(238, 232, 220)
local FADE_TIME = 0.6

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 8)
	c.Parent = parent
	return c
end

function DownedGui.new()
	local self = setmetatable({}, DownedGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "DownedGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20 -- above the HUD
	gui.Enabled = false
	self.gui = gui

	-- Dark overlay. Not fully opaque: the spec calls for the surroundings faintly visible, and a fully black
	-- screen would make crawling impossible.
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shade.BackgroundTransparency = 0.18
	shade.BorderSizePixel = 0
	shade.Parent = gui
	self.shade = shade

	local countdown = Instance.new("TextLabel")
	countdown.Name = "Countdown"
	countdown.AnchorPoint = Vector2.new(0.5, 0.5)
	countdown.Position = UDim2.fromScale(0.5, 0.44)
	countdown.Size = UDim2.fromScale(0.6, 0.18)
	countdown.BackgroundTransparency = 1
	countdown.Font = Enum.Font.GothamBold
	countdown.TextScaled = true
	countdown.TextColor3 = COUNTDOWN_COLOR
	countdown.Text = "10:00"
	countdown.Parent = gui
	self.countdown = countdown

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 3
	stroke.Transparency = 0.4
	stroke.Parent = countdown

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.AnchorPoint = Vector2.new(0.5, 0.5)
	caption.Position = UDim2.fromScale(0.5, 0.565)
	caption.Size = UDim2.fromScale(0.6, 0.04)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.Gotham
	caption.TextScaled = true
	caption.TextColor3 = Color3.fromRGB(190, 182, 170)
	caption.Text = "คุณล้มลงแล้ว — รอเวลาเกิดใหม่ หรือให้เพื่อนมาชุบ"
	caption.Parent = gui

	local button = Instance.new("TextButton")
	button.Name = "RespawnButton"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.66)
	button.Size = UDim2.fromScale(0.22, 0.065)
	button.BackgroundColor3 = Color3.fromRGB(28, 26, 24)
	button.BackgroundTransparency = 0.15
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.TextColor3 = ACCENT
	button.Text = "เกิดใหม่ทันที"
	button.AutoButtonColor = true
	button.Parent = gui
	corner(button, UDim.new(0, 10))
	self.button = button

	local border = Instance.new("UIStroke")
	border.Color = ACCENT
	border.Thickness = 1.5
	border.Transparency = 0.35
	border.Parent = button

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = button

	-- The world itself darkens too, so it isn't just a flat panel over a bright scene.
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "WOLD_DownedEffect"
	effect.Brightness = 0
	effect.Contrast = 0
	effect.Saturation = 0
	effect.Enabled = false
	effect.Parent = Lighting
	self.effect = effect

	return self
end

function DownedGui:SetRemaining(seconds)
	seconds = math.max(0, math.floor(seconds))
	self.countdown.Text = ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

function DownedGui:OnRespawnRequested(callback)
	self.button.Activated:Connect(callback)
end

function DownedGui:Show()
	self.gui.Enabled = true
	self.effect.Enabled = true
	-- Tween rather than snap: an instant blackout reads as a bug/disconnect.
	TweenService:Create(self.effect, TweenInfo.new(FADE_TIME), {
		Brightness = -0.45,
		Contrast = -0.15,
		Saturation = -0.75,
	}):Play()
end

function DownedGui:Hide()
	self.gui.Enabled = false
	local tween = TweenService:Create(self.effect, TweenInfo.new(FADE_TIME * 0.5), {
		Brightness = 0, Contrast = 0, Saturation = 0,
	})
	tween.Completed:Once(function()
		self.effect.Enabled = false
	end)
	tween:Play()
end

return DownedGui
