-- EventBannerGui: the announcement that hangs at the top of the screen for as long as an event is running.
--
-- One strip per live event, stacked: the event's icon on the left, the wording in the middle, and either a
-- countdown or a progress count on the right. It is deliberately not a toast -- a toast says something
-- happened, and this says something IS happening, so it stays until it is over.
--
-- The message was originally drawn one letter at a time, each riding a sine wave, which is what the first
-- spec asked for. The user asked for it to stop moving after seeing it, so it is one plain TextLabel now --
-- and a banner that has to be read while a town is going dark is better still than clever anyway. That also
-- took a RenderStepped connection and a per-grapheme text measurement out of the client for free.
local Players = game:GetService("Players")

local EventBannerGui = {}
EventBannerGui.__index = EventBannerGui

local BACK = Color3.fromRGB(20, 22, 28)
local TEXT_MUTED = Color3.fromRGB(180, 184, 196)

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

	self.banners = {} -- [eventId] = { frame, timer, spec }

	return self
end

--------------------------------------------------------------------------------
-- Building one
--------------------------------------------------------------------------------

function EventBannerGui:build(spec)
	local frame = Instance.new("Frame")
	frame.Name = spec.id
	-- Full width of the holder, capped rather than fixed: a fixed 520 is wider than a phone screen, and a
	-- banner that runs off both edges is worse than one that is merely narrow.
	frame.Size = UDim2.new(1, 0, 0, 44)
	frame.BackgroundColor3 = BACK
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = self.holder
	corner(frame, UDim.new(0, 10))

	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(560, 44)
	cap.Parent = frame

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

	-- The message, sitting between the icon and the timer. Left-aligned against the icon rather than centred
	-- in the strip: the eye goes icon -> words, and a centred line drifts away from its own icon as the
	-- wording changes length.
	local message = Instance.new("TextLabel")
	message.Name = "Message"
	message.AnchorPoint = Vector2.new(0, 0.5)
	message.Position = UDim2.new(0, 48, 0.5, 0)
	message.Size = UDim2.new(1, -148, 1, 0)
	message.BackgroundTransparency = 1
	message.Font = Enum.Font.GothamBold
	message.TextSize = 16
	message.TextColor3 = spec.colour or Color3.fromRGB(244, 197, 66)
	message.TextXAlignment = Enum.TextXAlignment.Left
	message.TextTruncate = Enum.TextTruncate.AtEnd
	message.Text = spec.message or ""
	message.Parent = frame

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

	return { frame = frame, message = message, timer = timer, spec = spec }
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
	self.gui:Destroy()
end

return EventBannerGui
