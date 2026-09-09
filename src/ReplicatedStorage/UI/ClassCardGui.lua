-- ClassCardGui: the card that asks a player to choose a class.
--
-- Pure builder, like the other GUIs here: it draws the choices it is handed and reports the tap through a
-- callback. Which classes exist, whether the player has earned them, and what happens next all belong to
-- the server.
local Players = game:GetService("Players")
local ClassConfig = require(script.Parent.Parent.ClassConfig)
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)

local ClassCardGui = {}
ClassCardGui.__index = ClassCardGui

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

function ClassCardGui.new()
	local self = setmetatable({}, ClassCardGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "ClassCardGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- Above the HUD and the bag, below the downed overlay: choosing a class can wait until you are up.
	gui.DisplayOrder = 18
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	-- A dimmed backdrop rather than a modal lock: the choice matters, but freezing someone mid-fight to ask
	-- it would be worse than letting them answer when they are ready.
	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = Responsive.IsSmallScreen() and UDim2.fromScale(0.94, 0.6)
		or UDim2.fromOffset(720, 380)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	stroke(panel, RUNE, 0.55, 2)
	Responsive.Scale(panel)
	self.panel = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -24, 0, 34)
	title.Position = UDim2.new(0, 12, 0, 14)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = RUNE
	title.Text = "เลือกอาชีพ"
	title.Parent = panel
	self.title = title

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, -24, 0, 20)
	subtitle.Position = UDim2.new(0, 12, 0, 46)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 12
	subtitle.TextColor3 = TEXT_MUTED
	subtitle.Text = ""
	subtitle.Parent = panel
	self.subtitle = subtitle

	-- The cards themselves, laid out in a row that wraps on a narrow screen.
	local row = Instance.new("Frame")
	row.Name = "Cards"
	row.Position = UDim2.new(0, 12, 0, 76)
	row.Size = UDim2.new(1, -24, 1, -92)
	row.BackgroundTransparency = 1
	row.Parent = panel
	self.row = row

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(128, 168)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = row

	self.onChosen = nil
	return self
end

function ClassCardGui:OnChosen(callback)
	self.onChosen = callback
end

-- Draws one card per class id. `tier` only changes the wording: the server decides what may be offered.
function ClassCardGui:Show(tier, classIds)
	for _, child in ipairs(self.row:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	local level = ClassConfig.LevelFor(tier)
	local heading = "เลือกอาชีพ"
	if tier == "advanced" then heading = "เลือกอาชีพขั้นสูง"
	elseif tier == "elite" then heading = "เลือกยศสูงสุด" end
	self.title.Text = heading
	self.subtitle.Text = ("ถึงเลเวล %d แล้ว — ไม่เลือกตอนนี้ก็ได้ ถึงเลเวลนี้อีกครั้งจะถามใหม่")
		:format(level or 0)

	for i, id in ipairs(classIds or {}) do
		local class = ClassConfig.Get(id)
		if class then
			local card = Instance.new("TextButton")
			card.Name = id
			card.LayoutOrder = i
			card.BackgroundColor3 = STONE_DEEP
			card.BorderSizePixel = 0
			card.Text = ""
			card.AutoButtonColor = true
			card.Parent = self.row
			corner(card, UDim.new(0, 10))
			-- The class's own colour edges its card, so the choice and the name it will paint are obviously
			-- the same thing.
			stroke(card, class.color, 0.35, 2)

			local name = Instance.new("TextLabel")
			name.Size = UDim2.new(1, -12, 0, 46)
			name.Position = UDim2.new(0, 6, 0, 14)
			name.BackgroundTransparency = 1
			name.Font = Enum.Font.GothamBold
			name.TextSize = 16
			name.TextWrapped = true
			name.TextColor3 = class.color
			name.Text = class.name
			name.Parent = card

			local blurb = Instance.new("TextLabel")
			blurb.Size = UDim2.new(1, -16, 1, -76)
			blurb.Position = UDim2.new(0, 8, 0, 64)
			blurb.BackgroundTransparency = 1
			blurb.Font = Enum.Font.Gotham
			blurb.TextSize = 12
			blurb.TextWrapped = true
			blurb.TextYAlignment = Enum.TextYAlignment.Top
			blurb.TextColor3 = TEXT_LIGHT
			blurb.Text = class.blurb or ""
			blurb.Parent = card

			card.Activated:Connect(function()
				UiSound.Play("Click")
				if self.onChosen then self.onChosen(id) end
			end)
		end
	end

	-- Rebuilt only if it is missing: Show runs every time the card appears, and a fresh button each time
	-- would stack them on top of each other.
	if self.skipButton then
		self.gui.Enabled = true
		return
	end

	-- A way to say no. Keeping the class you already have is a real choice -- an advanced class is not
	-- automatically better than staying what you are -- and a card with no exit forces a decision that the
	-- player may not want to make yet. The card comes back on reaching the level again.
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(0.5, 1)
	skip.Position = UDim2.new(0.5, 0, 1, -8)
	skip.Size = UDim2.fromOffset(180, 30)
	skip.BackgroundColor3 = Color3.fromRGB(70, 74, 84)
	skip.BorderSizePixel = 0
	skip.Font = Enum.Font.GothamBold
	skip.TextSize = 13
	skip.TextColor3 = TEXT_MUTED
	skip.Text = "ยังไม่เลือกตอนนี้"
	skip.Parent = self.panel
	corner(skip, UDim.new(0, 8))
	skip.Activated:Connect(function()
		UiSound.Play("Click")
		self:Hide()
	end)
	self.skipButton = skip

	self.gui.Enabled = true
end

function ClassCardGui:Hide()
	self.gui.Enabled = false
end

function ClassCardGui:IsOpen()
	return self.gui.Enabled
end

return ClassCardGui
