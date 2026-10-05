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
local Show = require(script.Parent.Parent.Locale).Show

local EventBannerGui = {}
EventBannerGui.__index = EventBannerGui

local BACK = Color3.fromRGB(20, 22, 28)
local TEXT_MUTED = Color3.fromRGB(180, 184, 196)

-- หลอดเลือดใต้ประกาศ (ผู้ใช้สั่ง 2026-09-21) — ใช้กับบอสโลก
--
-- **อยู่ในป้ายเดียวกัน ไม่ใช่ป้ายใหม่** ผู้ใช้สั่งว่า "ใต้ประกาศอีเวนต์" และมันเป็นเลือดของสิ่งที่ประกาศนั้น
-- พูดถึง การแยกเป็นอีกกล่องจะทำให้สองอย่างนี้เลื่อนหนีกันเวลามีอีเวนต์อื่นแทรกกลาง
local STRIP_HEIGHT = 44 -- ความสูงของแถวประกาศ
local BAR_HEIGHT = 20   -- ความสูงของแถวหลอดเลือดที่ต่อท้าย
local BAR_FILL = Color3.fromRGB(198, 54, 48)
local BAR_TRACK = Color3.fromRGB(42, 26, 26)

-- 12000 -> "12,000" · เลือดบอสเป็นหลักหมื่น ซึ่งอ่านเป็นก้อนเดียวไม่ออกถ้าไม่มีตัวคั่น
local function comma(n)
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

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
	-- ความสูงถูกตั้งทีหลังใน `:layout()` เพราะมันขึ้นกับว่ามีหลอดเลือดหรือยัง ซึ่งเปลี่ยนได้ระหว่างอีเวนต์
	-- (บอสยังไม่โผล่ = ยังไม่มีหลอด) · `UISizeConstraint` ก็ต้องขยับตาม ไม่งั้นมันหนีบกลับเป็น 44
	local frame = Instance.new("Frame")
	frame.Name = spec.id
	-- Full width of the holder, capped rather than fixed: a fixed 520 is wider than a phone screen, and a
	-- banner that runs off both edges is worse than one that is merely narrow.
	frame.Size = UDim2.new(1, 0, 0, STRIP_HEIGHT)
	frame.BackgroundColor3 = BACK
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = self.holder
	corner(frame, UDim.new(0, 10))

	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(560, STRIP_HEIGHT)
	cap.Parent = frame

	local edge = Instance.new("UIStroke")
	edge.Color = spec.colour or Color3.fromRGB(244, 197, 66)
	edge.Transparency = 0.35
	edge.Thickness = 2
	edge.Parent = frame

	-- ⚠️ **ทุกชิ้นในแถวประกาศวางเทียบกับ `STRIP_HEIGHT` ไม่ใช่ `0.5` ของเฟรม** เฟรมสูงขึ้นเมื่อมีหลอด
	-- เลือด ถ้าใช้กึ่งกลางเฟรม ไอคอนกับข้อความจะเลื่อนลงไปทับหลอดทันทีที่บอสโผล่
	local icon = Instance.new("ImageLabel")
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 8, 0, STRIP_HEIGHT / 2)
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
	message.Position = UDim2.new(0, 48, 0, STRIP_HEIGHT / 2)
	message.Size = UDim2.new(1, -148, 0, STRIP_HEIGHT)
	message.BackgroundTransparency = 1
	message.Font = Enum.Font.GothamBold
	message.TextSize = 16
	message.TextColor3 = spec.colour or Color3.fromRGB(244, 197, 66)
	message.TextXAlignment = Enum.TextXAlignment.Left
	message.TextTruncate = Enum.TextTruncate.AtEnd
	message.Text = Show(spec.message) or ""
	message.Parent = frame

	local timer = Instance.new("TextLabel")
	timer.AnchorPoint = Vector2.new(1, 0.5)
	timer.Position = UDim2.new(1, -10, 0, STRIP_HEIGHT / 2)
	timer.Size = UDim2.fromOffset(86, 24)
	timer.BackgroundTransparency = 1
	timer.Font = Enum.Font.GothamBold
	timer.TextSize = 15
	timer.TextColor3 = Color3.fromRGB(255, 120, 110)
	timer.TextXAlignment = Enum.TextXAlignment.Right
	timer.Text = ""
	timer.Parent = frame

	----------------------------------------------------------------------------
	-- หลอดเลือด สร้างไว้เลยแต่ซ่อนไว้ก่อน
	--
	-- สร้างตั้งแต่ตอนนี้ ไม่ใช่ตอนที่เลือดมาถึง: อีเวนต์ที่ไม่มีเลือดจ่ายค่าแค่ Frame ที่ `Visible = false`
	-- สามชิ้น ส่วนการสร้างของกลางคันแปลว่าเฟรมแรกที่เลือดมาถึงจะกระพริบ
	----------------------------------------------------------------------------
	local track = Instance.new("Frame")
	track.Name = "HpTrack"
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0.5, 0, 1, -6)
	track.Size = UDim2.new(1, -20, 0, BAR_HEIGHT - 8)
	track.BackgroundColor3 = BAR_TRACK
	track.BorderSizePixel = 0
	track.Visible = false
	track.Parent = frame
	corner(track, UDim.new(1, 0))

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = BAR_FILL
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, UDim.new(1, 0))

	-- ตัวเลขวางทับหลอด ไม่ใช่ข้างๆ: หลอดกว้างเต็มป้ายอยู่แล้ว การเบียดที่ให้ตัวเลขจะทำให้หลอดสั้นลง
	-- จนอ่านสัดส่วนไม่ออก ซึ่งเป็นงานเดียวที่หลอดมี
	local hpText = Instance.new("TextLabel")
	hpText.Name = "HpText"
	hpText.Size = UDim2.new(1, 0, 1, 0)
	hpText.BackgroundTransparency = 1
	hpText.Font = Enum.Font.GothamBold
	hpText.TextSize = 12
	hpText.TextColor3 = Color3.fromRGB(255, 236, 232)
	hpText.TextStrokeTransparency = 0.6
	hpText.Text = ""
	hpText.Parent = track

	return { frame = frame, cap = cap, message = message, timer = timer,
		track = track, fill = fill, hpText = hpText, spec = spec }
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
--
-- ...และหลอดเลือดข้างล่าง ถ้าอีเวนต์นั้นส่ง `hp` มา
function EventBannerGui:refresh()
	local now = workspace:GetServerTimeNow()
	for _, banner in pairs(self.banners) do
		local spec = banner.spec
		self:drawHealth(banner, spec.hp)
		if spec.detail then
			banner.timer.TextColor3 = Color3.fromRGB(255, 196, 92)
			banner.timer.Text = Show(spec.detail)
		elseif spec.endsAt then
			local left = math.max(0, spec.endsAt - now)
			banner.timer.TextColor3 = left < 60 and Color3.fromRGB(255, 120, 110) or TEXT_MUTED
			banner.timer.Text = ("%02d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
		else
			banner.timer.Text = ""
		end
	end
end

-- หลอดเลือดของป้ายหนึ่งใบ · `hp = nil` = ไม่มีเป้าหมายที่มีเลือด ป้ายกลับไปสูงเท่าเดิม
function EventBannerGui:drawHealth(banner, hp)
	local wanted = hp ~= nil and hp.maximum ~= nil and hp.maximum > 0
	if banner.track.Visible ~= wanted then
		banner.track.Visible = wanted
		local height = wanted and (STRIP_HEIGHT + BAR_HEIGHT) or STRIP_HEIGHT
		banner.frame.Size = UDim2.new(1, 0, 0, height)
		banner.cap.MaxSize = Vector2.new(560, height)
	end
	if not wanted then return end

	local fraction = math.clamp(hp.current / hp.maximum, 0, 1)
	banner.fill.Size = UDim2.new(fraction, 0, 1, 0)
	-- ซ่อนหลอดที่ว่างสนิทแทนการวาดขอบมนของความกว้างศูนย์ ซึ่งออกมาเป็นจุดกลมค้างอยู่ต้นหลอด
	banner.fill.Visible = fraction > 0
	banner.hpText.Text = ("%s / %s  (%d%%)")
		:format(comma(hp.current), comma(hp.maximum), math.floor(fraction * 100 + 0.5))
end

function EventBannerGui:Destroy()
	self.gui:Destroy()
end

return EventBannerGui
