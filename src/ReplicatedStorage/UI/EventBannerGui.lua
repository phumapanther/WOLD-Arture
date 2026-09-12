-- EventBannerGui: the announcement that hangs at the top of the screen for as long as an event is running.
--
-- One strip per live event, stacked: icon on the left, the wording in the middle with the letters riding a
-- wave, and either a countdown or a progress count on the right. It is deliberately not a toast -- a toast
-- says something happened, and this says something IS happening, so it stays until it is over.
--
-- The wave is per-LETTER, which is the whole reason the message is not one TextLabel: each character is its
-- own label offset by a sine of its own index, so the sentence ripples along instead of the whole line
-- bobbing up and down as a block.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local EventBannerGui = {}
EventBannerGui.__index = EventBannerGui

local BACK = Color3.fromRGB(20, 22, 28)
local TEXT_MUTED = Color3.fromRGB(180, 184, 196)

-- How far the letters ride, and how fast the wave travels along the sentence. Small enough to read through:
-- four pixels of sway is a shimmer, and twelve would be a headache on a line you have to read.
local WAVE_HEIGHT = 4
local WAVE_SPEED = 5.5
local WAVE_SPREAD = 0.55 -- radians of phase between neighbouring letters

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

--------------------------------------------------------------------------------

function EventBannerGui.new()
	local self = setmetatable({}, EventBannerGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "EventBannerGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- Above the HUD, below a minigame: an announcement should never sit on top of something being played.
	gui.DisplayOrder = 30
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	local holder = Instance.new("Frame")
	holder.Name = "Banners"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 8)
	holder.Size = UDim2.new(1, -24, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	self.holder = holder

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	self.banners = {} -- [eventId] = { frame, letters, timer, spec }

	-- One connection for every banner on screen, rather than one each: the wave is the same clock for all of
	-- them, and a dozen RenderStepped connections doing trigonometry would be a dozen times the cost for the
	-- same picture.
	self.wave = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, banner in pairs(self.banners) do
			for index, letter in ipairs(banner.letters) do
				letter.Position = UDim2.new(0, letter:GetAttribute("BaseX") or 0,
					0.5, math.sin(now * WAVE_SPEED - index * WAVE_SPREAD) * WAVE_HEIGHT)
			end
		end
	end)

	return self
end

--------------------------------------------------------------------------------
-- Building one
--------------------------------------------------------------------------------

-- Laid out by hand rather than with a UIListLayout, because the wave moves each letter every frame and a
-- layout would fight it for the same Position property. Each letter remembers the x it belongs at and only
-- its y is ever touched.
local function writeLetters(parent, text, colour)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end

	local letters = {}
	-- utf8.graphemes, not a byte loop: Thai is three bytes a character, and splitting it by byte would draw
	-- a line of broken squares. Combining marks ride with the letter they belong to, which is what a
	-- grapheme is.
	local x = 0
	local pieces = {}
	for first, last in utf8.graphemes(text) do
		table.insert(pieces, text:sub(first, last))
	end

	-- Measured first so the whole sentence can be centred: the labels are positioned absolutely, so nothing
	-- else is going to centre them.
	--
	-- Measured for real rather than guessed at a flat width per character. Thai mixes wide consonants with
	-- combining vowels that take almost no room of their own, so a fixed 13 pixels per grapheme spread the
	-- word out into something that read as a ransom note.
	local widths = {}
	local total = 0
	for index, piece in ipairs(pieces) do
		local width
		local ok, bounds = pcall(function()
			return TextService:GetTextSize(piece, 16, Enum.Font.GothamBold, Vector2.new(1000, 100))
		end)
		if ok and bounds and bounds.X > 0 then
			width = bounds.X
		else
			-- A space carries no glyph but still has to take room, or the words run together.
			width = piece == " " and 5 or 11
		end
		widths[index] = width
		total += width
	end

	x = -total / 2
	for index, piece in ipairs(pieces) do
		local letter = Instance.new("TextLabel")
		letter.BackgroundTransparency = 1
		letter.AnchorPoint = Vector2.new(0, 0.5)
		letter.Size = UDim2.fromOffset(widths[index] + 6, 22)
		letter.Font = Enum.Font.GothamBold
		letter.TextSize = 16
		letter.TextColor3 = colour
		letter.TextXAlignment = Enum.TextXAlignment.Center
		letter.Text = piece
		letter:SetAttribute("BaseX", x)
		letter.Position = UDim2.new(0, x, 0.5, 0)
		letter.Parent = parent
		table.insert(letters, letter)
		x += widths[index]
	end
	return letters
end

function EventBannerGui:build(spec)
	local frame = Instance.new("Frame")
	frame.Name = spec.id
	frame.Size = UDim2.fromOffset(520, 44)
	frame.BackgroundColor3 = BACK
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = self.holder
	corner(frame, UDim.new(0, 10))

	local edge = Instance.new("UIStroke")
	edge.Color = spec.colour or Color3.fromRGB(244, 197, 66)
	edge.Transparency = 0.35
	edge.Thickness = 2
	edge.Parent = frame

	local icon = Instance.new("ImageLabel")
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 8, 0.5, 0)
	icon.Size = UDim2.fromOffset(32, 32)
	icon.BackgroundTransparency = 1
	icon.Image = spec.icon or ""
	icon.Parent = frame

	-- The middle, where the wave lives. Its own frame so the letters' x positions are measured from its
	-- centre rather than from the banner's left edge.
	local middle = Instance.new("Frame")
	middle.Name = "Message"
	middle.AnchorPoint = Vector2.new(0.5, 0.5)
	middle.Position = UDim2.fromScale(0.5, 0.5)
	middle.Size = UDim2.new(1, -200, 1, 0)
	middle.BackgroundTransparency = 1
	middle.Parent = frame

	local letters = writeLetters(middle, spec.message or "", spec.colour or Color3.fromRGB(244, 197, 66))

	local timer = Instance.new("TextLabel")
	timer.AnchorPoint = Vector2.new(1, 0.5)
	timer.Position = UDim2.new(1, -10, 0.5, 0)
	timer.Size = UDim2.fromOffset(86, 24)
	timer.BackgroundTransparency = 1
	timer.Font = Enum.Font.GothamBold
	timer.TextSize = 15
	timer.TextColor3 = Color3.fromRGB(255, 120, 110)
	timer.TextXAlignment = Enum.TextXAlignment.Right
	timer.Text = ""
	timer.Parent = frame

	return { frame = frame, letters = letters, timer = timer, spec = spec }
end

--------------------------------------------------------------------------------
-- The live list
--------------------------------------------------------------------------------

-- `events` is the whole set of what is running, keyed by id. Anything missing from it has ended, which is
-- what makes this safe to call with a fresh picture every time -- there is no "remove" message to lose.
function EventBannerGui:Set(events)
	events = events or {}

	for id, banner in pairs(self.banners) do
		if not events[id] then
			banner.frame:Destroy()
			self.banners[id] = nil
		end
	end

	for id, spec in pairs(events) do
		local banner = self.banners[id]
		if not banner then
			spec.id = id
			banner = self:build(spec)
			self.banners[id] = banner
		else
			banner.spec = spec
		end
	end

	self:refresh()
end

-- Draws the right-hand side: a countdown when the event has an end, a progress count when it does not.
function EventBannerGui:refresh()
	local now = workspace:GetServerTimeNow()
	for _, banner in pairs(self.banners) do
		local spec = banner.spec
		if spec.detail then
			banner.timer.TextColor3 = Color3.fromRGB(255, 196, 92)
			banner.timer.Text = spec.detail
		elseif spec.endsAt then
			local left = math.max(0, spec.endsAt - now)
			banner.timer.TextColor3 = left < 60 and Color3.fromRGB(255, 120, 110) or TEXT_MUTED
			banner.timer.Text = ("%02d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
		else
			banner.timer.Text = ""
		end
	end
end

function EventBannerGui:Destroy()
	if self.wave then self.wave:Disconnect() end
	self.gui:Destroy()
end

return EventBannerGui
