-- CraftGui: the blacksmith's forge. Three pages of recipes, each showing what it makes and what it eats.
--
-- Pure builder, like ShopGui: it draws the snapshot the server sends and reports taps. It never counts a
-- material, never decides what is craftable, and holds no state between snapshots beyond which tab is open --
-- every redraw is a fresh picture of what the server currently says.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)
local ItemIcon = require(script.Parent.ItemIcon)
local NumberBox = require(script.Parent.NumberBox)
local CraftFuel = require(script.Parent.Parent.CraftFuel) -- เชื้อเพลิงเครื่องบนเกาะ (2026-10-02)
local CraftConfig = require(script.Parent.Parent.CraftConfig) -- ราคา 💎 เสร็จทันที (InstantGems)
local Locale = require(script.Parent.Parent.Locale)
local L, Show = Locale.L, Locale.Show

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)
-- Green for a material the player already has enough of, red for one they are short on. The whole point of
-- the row is answering "can I make this yet", so the answer is a colour rather than a number to read.
local ENOUGH = Color3.fromRGB(150, 200, 140)
local SHORT = Color3.fromRGB(214, 106, 96)
-- The two endings, deliberately far apart. A player who just burned 25,000 gold and a bag of ore on a failed
-- pistol should never have to squint at the row to work out which of the two it was.
local WIN = Color3.fromRGB(120, 206, 128)
local LOSE = Color3.fromRGB(206, 72, 62)
-- How long the outcome sits on the row before the window goes back to normal. Long enough to read a short
-- sentence, short enough that it is gone before the player finishes deciding what to make next.
local OUTCOME_SECONDS = 1.6

local CraftGui = {}
CraftGui.__index = CraftGui

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

function CraftGui.new()
	local self = setmetatable({}, CraftGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "CraftGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 17
	gui.Enabled = false
	-- นอกเกม (เทสใน Edit) ไม่มี PlayerGui — สร้างไว้เฉยๆ ไม่ต้องแขวน (ทรงเดียวกับ ShopGui)
	if game:GetService("RunService"):IsRunning() then
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	self.gui = gui

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	-- Taller than it was. The misc page now holds six recipes -- bullets, potions and the four chests --
	-- which is 638px of rows in what used to be a 332px window: most of the page sat below the fold behind a
	-- 4px scrollbar, and it read as "the chests have no details" rather than as something to scroll to.
	panel.Size = Responsive.IsSmallScreen() and UDim2.fromScale(0.95, 0.9)
		or UDim2.fromOffset(560, 600)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	stroke(panel, RUNE, 0.55, 2)
	Responsive.Scale(panel, Responsive.IsSmallScreen() and 0.95 or nil) -- มือถือ: แผงเต็มจออยู่แล้ว ห้ามย่อซ้ำ (QA 2026-09-26)
	self.panel = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 30)
	title.Position = UDim2.new(0, 12, 0, 12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 19
	title.TextColor3 = RUNE
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = L("โรงตีเหล็ก")
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Parent = panel
	self.title = title

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(26, 26)
	close.BackgroundColor3 = Color3.fromRGB(70, 74, 84)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBold
	close.TextSize = 15
	close.TextColor3 = TEXT_LIGHT
	close.Text = "\195\151"
	close.Parent = panel
	corner(close, UDim.new(0, 6))
	close.Activated:Connect(function()
		UiSound.Play("Click")
		self:Hide()
	end)

	-- 💎 เสร็จทันที (ผู้ใช้เลือก 2026-10-02): ทุกเครื่องที่กำลังทำงาน (เกมหลัก + เกาะ) · หัวหน้าต่างข้าง × ·
	-- แตะสองครั้งยืนยัน (ใช้เพชร) · ราคาเดินลงตามเวลาที่เหลือ (RefreshInstant · ลูปข้างล่าง)
	local instant = Instance.new("TextButton")
	instant.AnchorPoint = Vector2.new(1, 0)
	instant.Position = UDim2.new(1, -44, 0, 12)
	instant.Size = UDim2.fromOffset(150, 26)
	instant.BackgroundColor3 = Color3.fromRGB(170, 130, 240)
	instant.BorderSizePixel = 0
	instant.Font = Enum.Font.GothamBold
	instant.TextSize = 12
	instant.TextColor3 = Color3.fromRGB(24, 26, 32)
	instant.Visible = false
	instant.Parent = panel
	corner(instant, UDim.new(0, 6))
	instant.Activated:Connect(function()
		UiSound.Play("Click")
		if instant:GetAttribute("Armed") then
			instant:SetAttribute("Armed", nil)
			if self.onInstant then self.onInstant() end
		else
			instant:SetAttribute("Armed", true)
			task.delay(3, function()
				instant:SetAttribute("Armed", nil)
				self:RefreshInstant()
			end)
		end
		self:RefreshInstant()
	end)
	self.instantButton = instant
	if game:GetService("RunService"):IsRunning() then
		task.spawn(function()
			while gui.Parent do
				if gui.Enabled then self:RefreshInstant() end
				task.wait(1)
			end
		end)
	end

	-- The row of tabs. Built once and refilled on every snapshot, since the tab list comes down with it.
	local tabBar = Instance.new("Frame")
	tabBar.Name = "Tabs"
	tabBar.Position = UDim2.fromOffset(12, 48)
	tabBar.Size = UDim2.new(1, -24, 0, 28)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = panel
	self.tabBar = tabBar

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	local body = Instance.new("Frame")
	body.Position = UDim2.fromOffset(12, 84)
	body.Size = UDim2.new(1, -24, 1, -96)
	body.BackgroundColor3 = STONE_DEEP
	body.BorderSizePixel = 0
	body.Parent = panel
	corner(body, UDim.new(0, 10))
	self.body = body

	-- แถบเชื้อเพลิง (เครื่องคราฟบนเกาะ · ผู้ใช้สั่ง 2026-10-02) — โผล่เฉพาะตอนสแนปช็อตมี `fuel` แล้วดันรายการสูตรลง
	-- ซ้าย: หลอด + % + เวลาที่ทำงานได้ · ขวา: ถ่านที่มี · +1 · ช่องจำนวน (เด้งเป็นที่เติมได้จริง) · เติม
	local strip = Instance.new("Frame")
	strip.Name = "Fuel"
	strip.Position = UDim2.fromOffset(12, 84)
	strip.Size = UDim2.new(1, -24, 0, 34)
	strip.BackgroundColor3 = STONE_DEEP
	strip.BorderSizePixel = 0
	strip.Visible = false
	strip.Parent = panel
	corner(strip, UDim.new(0, 8))
	self.fuelStrip = strip

	local RIGHT = 272 -- ความกว้างกลุ่มปุ่มขวา (เร่ง · ถ่าน · +1 · จำนวน · เติม)
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 8, 0.5, 0)
	track.Size = UDim2.new(1, -(RIGHT + 12), 0, 20)
	track.BackgroundColor3 = Color3.fromRGB(44, 46, 56)
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = strip
	corner(track, UDim.new(0, 6))
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(226, 128, 52)
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, UDim.new(0, 6))
	self.fuelFill = fill
	local fuelText = Instance.new("TextLabel")
	fuelText.Size = UDim2.new(1, -8, 1, 0)
	fuelText.Position = UDim2.fromOffset(6, 0)
	fuelText.BackgroundTransparency = 1
	fuelText.Font = Enum.Font.GothamBold
	fuelText.TextSize = 12
	fuelText.TextColor3 = TEXT_LIGHT
	fuelText.TextStrokeTransparency = 0.4
	fuelText.TextXAlignment = Enum.TextXAlignment.Left
	fuelText.TextTruncate = Enum.TextTruncate.AtEnd
	fuelText.Parent = track
	self.fuelText = fuelText

	local function fuelButton(text, width, right, colour, onClick)
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -right, 0.5, 0)
		b.Size = UDim2.fromOffset(width, 26)
		b.BackgroundColor3 = colour
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 12
		b.TextColor3 = Color3.fromRGB(24, 26, 32)
		b.Text = text
		b.Parent = strip
		corner(b, UDim.new(0, 5))
		b.Activated:Connect(function()
			UiSound.Play("Click")
			onClick()
		end)
		return b
	end
	local box = Instance.new("TextBox")
	box.AnchorPoint = Vector2.new(1, 0.5)
	box.Position = UDim2.new(1, -64, 0.5, 0)
	box.Size = UDim2.fromOffset(44, 26)
	box.BackgroundColor3 = Color3.fromRGB(44, 46, 56)
	box.BorderSizePixel = 0
	box.Font = Enum.Font.GothamBold
	box.TextSize = 12
	box.TextColor3 = TEXT_LIGHT
	box.PlaceholderText = L("จำนวน")
	box.PlaceholderColor3 = TEXT_MUTED
	box.ClearTextOnFocus = false
	box.Text = ""
	box.Parent = strip
	corner(box, UDim.new(0, 5))
	NumberBox.Bind(box, function() return self.fuelMax end)
	self.fuelBox = box
	fuelButton(L("เติม"), 52, 8, RUNE, function()
		local n = NumberBox.Value(box.Text)
		if n and n > 0 and self.onFuel then self.onFuel(n) end
		box.Text = ""
	end)
	fuelButton("+1", 36, 112, ENOUGH, function()
		if self.onFuel then self.onFuel(1) end
	end)
	local coal = Instance.new("TextLabel")
	coal.AnchorPoint = Vector2.new(1, 0.5)
	coal.Position = UDim2.new(1, -152, 0.5, 0)
	coal.Size = UDim2.fromOffset(58, 26)
	coal.BackgroundTransparency = 1
	coal.Font = Enum.Font.Gotham
	coal.TextSize = 12
	coal.TextColor3 = TEXT_MUTED
	coal.TextXAlignment = Enum.TextXAlignment.Right
	coal.Parent = strip
	self.fuelCoal = coal
	-- ปุ่มเร่ง (ผู้ใช้เลือก 2026-10-02): ระหว่างเครื่องทำงาน · เผาเชื้อเพลิงทั้งถัง ลดเวลา 1:1 · แตะสองครั้งยืนยัน
	-- (แตะพลาดครั้งเดียว = ถ่านทั้งถังหาย) · โผล่เฉพาะตอนเครื่องนี้ทำงานอยู่และมีเชื้อเพลิง (Render ตั้ง)
	local boost
	boost = fuelButton(L("⚡ เร่ง"), 56, 214, Color3.fromRGB(120, 180, 240), function()
		if boost:GetAttribute("Armed") then
			boost:SetAttribute("Armed", nil)
			boost.Text = L("⚡ เร่ง")
			if self.onBoost then self.onBoost() end
			return
		end
		boost:SetAttribute("Armed", true)
		boost.Text = L("ยืนยัน?")
		task.delay(3, function()
			if boost:GetAttribute("Armed") then
				boost:SetAttribute("Armed", nil)
				boost.Text = L("⚡ เร่ง")
			end
		end)
	end)
	boost.Visible = false
	self.boostButton = boost

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(6, 6)
	list.Size = UDim2.new(1, -12, 1, -12)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	-- Wide enough to see. At 4px the bar was invisible against the panel, so a page that needed scrolling
	-- looked like a page that was missing its bottom half.
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = RUNE
	list.ScrollBarImageTransparency = 0.3
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = body
	self.list = list

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- Which page is open. The only thing this window remembers between snapshots: redrawing after a craft
	-- should leave the player looking at the page they were on, not throw them back to the first one.
	self.activeTab = nil
	self.snapshot = nil
	self.onCraft = nil
	-- จำนวนรอบที่เลือกไว้ต่อสูตร (เฟส 2c) อยู่ข้ามการวาดใหม่ · ล้างตอนปิดหน้าต่าง
	self.times = {}
	return self
end

function CraftGui:OnCraft(callback) self.onCraft = callback end
function CraftGui:OnEnhance(callback) self.onEnhance = callback end
function CraftGui:OnFuel(callback) self.onFuel = callback end -- (จำนวนถ่าน) เติมเชื้อเพลิงเครื่องที่เปิดอยู่
function CraftGui:OnBoost(callback) self.onBoost = callback end -- () เผาเชื้อเพลิงทั้งถัง เร่งงานที่ทำอยู่
function CraftGui:OnInstant(callback) self.onInstant = callback end -- () จ่ายเพชร งานที่ทำอยู่เสร็จทันที

-- ปุ่ม 💎: เครื่องนี้ทำงานอยู่และเหลือ ≥ InstantMinSeconds · ราคาคิดจากเวลาที่เหลือ (เซิร์ฟคิดจากของตัวเองซึ่งไม่มากกว่านี้)
function CraftGui:RefreshInstant()
	local remaining = self.busyActive and (self.busyUntil or 0) - os.clock() or 0
	local show = self.busyActive == true and remaining >= CraftConfig.InstantMinSeconds
	local button = self.instantButton
	button.Visible = show
	if show then
		local gems = CraftConfig.InstantGems(remaining)
		button.Text = button:GetAttribute("Armed") and L("ยืนยัน 💎 %d ?", gems) or L("💎 เสร็จทันที %d", gems)
	else
		button:SetAttribute("Armed", nil)
	end
	-- ชื่อหน้าต่างหลบปุ่ม
	self.title.Size = UDim2.new(1, show and -210 or -24, 0, 30)
end

-- Puts every button to sleep and runs the bar on the one row that is being made. Split out from Begin because
-- a redraw arriving mid-swing has to re-apply exactly the same thing to a brand new set of rows, and the bar
-- has to pick up where the old one left off rather than starting over -- so the finish TIME is what is
-- remembered, not how far along it was.
function CraftGui:ApplyBusy()
	local remaining = math.max(0, self.busyUntil - os.clock())
	-- ครบเวลาแล้วปลดเอง: งานที่คืนมาหลังเข้าเกมใหม่ไม่มี CraftFinished ส่งมา (เซิร์ฟแค่แจ้งข้อความ) ไม่งั้นค้าง "รอสักครู่"
	-- เผื่อ 1 วิให้ CraftFinished ของงานปกติมาถึงก่อน · ปลดเฉพาะงานเดิม (busyUntil เดิม) ไม่ทับงานใหม่
	local untilAt = self.busyUntil
	task.delay(remaining + 1, function()
		if self.busyActive and self.busyUntil == untilAt then
			self.busyActive = false
			self.busyIndex = nil
			self:Render()
		end
	end)
	for index, row in pairs(self.rows or {}) do
		if index == self.busyIndex then
			row.odds.Visible = false
			row.track.Visible = true
			row.fill.Size = UDim2.new(1 - remaining / math.max(self.busySeconds, 0.001), 0, 1, 0)
			-- Linear, because this bar is a clock: the server finishes at a fixed time and an eased bar would
			-- crawl at the end while the hammer had plainly already stopped.
			TweenService:Create(row.fill, TweenInfo.new(remaining, Enum.EasingStyle.Linear), {
				Size = UDim2.fromScale(1, 1),
			}):Play()
			-- เตาไม่ได้ตีเหล็ก: คำว่า "กำลังตี" ที่หน้าครัวอ่านแล้วสะดุด
			row.button.Text = (self.snapshot and self.snapshot.station) and L("กำลังทำ...") or L("กำลังตี...")
		else
			-- ผู้ใช้สั่ง 2026-10-02 · งานที่คืนมาหลังเข้าเกมใหม่ไม่รู้ว่าสูตรไหน (busyIndex nil) = ทุกแถวขึ้นแบบนี้
			row.button.Text = L("รอสักครู่")
		end
		-- Every button, not just the busy row's: the server refuses a second craft anyway, and a window that
		-- lets the player press and then tells them off is worse than one that simply does not offer. Greyed
		-- AND flagged -- the colour is for the player, the attribute is what the tap handler actually reads.
		row.button:SetAttribute("Busy", true)
		row.button.AutoButtonColor = false
		row.button.BackgroundColor3 = Color3.fromRGB(70, 74, 84)
		row.button.TextColor3 = TEXT_MUTED
	end
end

-- The hammer has started on `index` and will take `seconds`.
function CraftGui:Begin(index, seconds)
	-- A new swing ends the last one's outcome early, whichever row it was on: the player has moved on.
	self.outcomeIndex = nil
	self.busyActive = true
	self.busyIndex = index
	self.busySeconds = seconds
	self.busyUntil = os.clock() + seconds
	self:ApplyBusy()
end

-- Paints the outcome onto the row that was being made: green and a word for a sword that exists now, red and
-- a word for a pile of materials that does not. Split out for the same reason ApplyBusy is -- the server
-- sends a snapshot immediately after a craft, and without re-applying it the redraw would wipe the answer off
-- the screen in the same frame it appeared.
function CraftGui:ApplyOutcome()
	local row = self.rows and self.rows[self.outcomeIndex]
	if not row then return end

	row.track.Visible = false
	row.odds.Visible = true
	row.odds.Font = Enum.Font.GothamBold
	-- The colour carries it rather than the wording, because the one thing a player must not have to read
	-- twice is whether the 25,000 they just spent bought anything.
	-- แถวตีบวกมีข้อความผลของตัวเอง (winText/failText จากสแนปช็อต)
	row.odds.Text = self.outcomeOk and (Show(row.winText) or L("สำเร็จ!")) or (Show(row.failText) or L("ล้มเหลว! เสียวัสดุและค่าจ้างไปแล้ว"))
	row.odds.TextColor3 = self.outcomeOk and WIN or LOSE
	row.frame.BackgroundColor3 = self.outcomeOk and Color3.fromRGB(40, 66, 44) or Color3.fromRGB(72, 38, 36)
	-- Fading back to the row's normal colour is what ends the moment, so the outcome does not need clearing by
	-- hand and a row left on screen never stays stained.
	TweenService:Create(row.frame, TweenInfo.new(OUTCOME_SECONDS), {
		BackgroundColor3 = row.baseColor,
	}):Play()
end

-- The answer. Unlocks the buttons, shows the outcome, and puts the row back to normal a moment later.
function CraftGui:Finish(index, success)
	self.busyActive = false
	self.busyIndex = nil
	self:RefreshInstant()
	self.outcomeIndex = index
	self.outcomeOk = success
	self:ApplyOutcome()

	-- Redrawn rather than undone by hand, so the row comes back holding the server's current counts. Guarded
	-- on the outcome still being THIS one: by the time it fires the player may have started another craft, and
	-- a stale timer must not redraw over a bar that is filling.
	task.delay(OUTCOME_SECONDS, function()
		if self.outcomeIndex ~= index then return end
		self.outcomeIndex = nil
		if self.gui.Enabled then self:Render() end
	end)
end

-- One recipe: what it makes on the left, the materials it eats underneath, and the button on the right.
-- Sized by the material count rather than fixed, so a five-material recipe is not squeezed into the same
-- height as a two-material one. The odds-and-fee line and the progress bar each add their own fixed strip on
-- the bottom, so a row is as tall as what it actually has to show.
-- "3 นาที" / "1 ชม. 30 นาที" / "45 วินาที" — เวลาของเครื่องบนเกาะยาวเป็นชั่วโมง
local function duration(seconds)
	seconds = math.floor(seconds or 0)
	if seconds < 60 then return L("%d วินาที", seconds) end
	local h, m = seconds // 3600, (seconds % 3600) // 60
	if h > 0 then return m > 0 and L("%d ชม. %d นาที", h, m) or L("%d ชม.", h) end
	return L("%d นาที", m)
end

-- `times` = จำนวนรอบที่เลือกไว้ (เครื่องบนเกาะทำได้ 1-10 รอบต่องาน · เฟส 2c) · `onTimes(n)` เปลี่ยนจำนวน
local function recipeRow(parent, order, entry, onClick, times, onTimes, fuel)
	times = times or 1
	local materialsBottom = 26 + #entry.materials * 16
	local height = materialsBottom + 22

	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -4, 0, height)
	frame.BackgroundColor3 = Color3.fromRGB(44, 46, 56)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, UDim.new(0, 6))

	local image = Instance.new("ImageLabel")
	image.Size = UDim2.fromOffset(28, 28)
	image.Position = UDim2.fromOffset(6, 5)
	image.BackgroundTransparency = 1
	ItemIcon.Apply(image, entry.icon)
	image.Parent = frame

	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(40, 6)
	label.Size = UDim2.new(1, -120, 0, 18)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = TEXT_LIGHT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	-- A batch says so on the row. Without it the only clue that one press makes eight bullets is counting
	-- them in the bag afterwards.
	local made = (entry.yields or 1) * times
	label.Text = made > 1 and ("%s  x%d"):format(Show(entry.name), made) or Show(entry.name)
	label.Parent = frame

	-- ของที่ต้องใช้ตามจำนวนรอบ (หน้าต่างคิดเพื่อวาดเท่านั้น เซิร์ฟตรวจเองตอนกด)
	local affordable = entry.affordable
	for _, material in ipairs(entry.materials) do
		if material.have < material.need * times then affordable = false end
	end
	-- เชื้อเพลิง (เครื่องบนเกาะ · 2026-10-02): ใช้ตามเวลาทั้งงาน ไม่พอ = กดไม่ได้ (เซิร์ฟตรวจซ้ำตอนกด)
	local fuelPct, fuelShort
	if fuel and (entry.seconds or 0) > 0 and not entry.enhance and not entry.closed and not entry.lockLevel then
		local seconds = entry.seconds * times
		fuelPct = CraftFuel.CostPercent(seconds)
		fuelShort = not CraftFuel.Enough(fuel.amount, CraftFuel.Cost(seconds))
		if fuelShort then affordable = false end
	end

	for i, material in ipairs(entry.materials) do
		local y = 26 + (i - 1) * 16

		-- The material's own icon, small, in front of its name. Six recipes now share the same handful of
		-- greyish steam-age materials, and "แบบแปลน 2/5" next to "เฟืองอะไหล่ 5/10" is a line to read where a
		-- picture is a thing to recognise. The id comes down in the snapshot, so the window still decides
		-- nothing -- it draws what the server sent.
		local pip = Instance.new("ImageLabel")
		pip.Name = "Pip"
		pip.Position = UDim2.fromOffset(40, y + 1)
		pip.Size = UDim2.fromOffset(13, 13)
		pip.BackgroundTransparency = 1
		ItemIcon.Apply(pip, material.icon)
		-- Faded with the text when the player is short, so the whole line reads as one state rather than a
		-- bright picture next to a red number.
		local need = material.need * times
		pip.ImageTransparency = material.have >= need and 0 or 0.45
		pip.Parent = frame

		local line = Instance.new("TextLabel")
		line.Position = UDim2.fromOffset(57, y)
		line.Size = UDim2.new(1, -137, 0, 15)
		line.BackgroundTransparency = 1
		line.Font = Enum.Font.Gotham
		line.TextSize = 11
		-- Coloured per material, not per recipe: when a craft is refused, this says WHICH ingredient is the
		-- one still missing rather than only that something is.
		line.TextColor3 = material.have >= need and ENOUGH or SHORT
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextTruncate = Enum.TextTruncate.AtEnd
		line.Text = ("%s %d/%d"):format(Show(material.name), material.have, need)
		line.Parent = frame
	end

	-- What the attempt is worth risking, on one line: the odds it works and what the smith charges either
	-- way. Both come from the snapshot, never from CraftConfig -- the client is told the price, it does not
	-- decide it. The fee is coloured like a material, red when the purse is short, for the same reason: the
	-- row should say WHICH part of the cost is the one stopping you.
	local odds = Instance.new("TextLabel")
	odds.Name = "Odds"
	odds.Position = UDim2.fromOffset(40, materialsBottom)
	odds.Size = UDim2.new(1, -120, 0, 15)
	odds.BackgroundTransparency = 1
	odds.Font = Enum.Font.Gotham
	odds.TextSize = 11
	odds.TextColor3 = TEXT_MUTED
	odds.TextXAlignment = Enum.TextXAlignment.Left
	odds.RichText = true
	local fee = entry.gold or 0
	local feeColor = (entry.goldHave or 0) >= fee and ENOUGH or SHORT
	if entry.closed then
		-- ของที่ยังไม่เปิดให้คราฟ (ผู้ใช้สั่ง 2026-09-28 · CraftConfig.Closed)
		odds.Text = L("<font color=\"#%s\">🔒 ยังไม่เปิด — เร็วๆ นี้</font>", Color3.fromRGB(214, 170, 120):ToHex())
	elseif entry.lockLevel then
		-- เฟส 2c: สูตรเครื่องบนเกาะที่ยังไม่ปลด
		odds.Text = L("<font color=\"#%s\">🔒 ปลดที่เลเวลฟาร์ม %d — ส่งของกับรถส่งออกเพื่อเก็บ EXP</font>", 
			Color3.fromRGB(214, 170, 120):ToHex(), entry.lockLevel)
	elseif entry.note then
		-- แถวตีบวก: เซิร์ฟเวอร์เขียนบรรทัดนี้มาเอง (โอกาส · ดาเมจก่อน→หลัง · ผลของการแตก)
		odds.Text = Show(entry.note)
	elseif (entry.chance or 1) >= 1 and fee <= 0 and (entry.seconds or 0) >= 10 then
		-- เครื่องที่ใช้เวลาจริง (ครัว · เครื่องบนเกาะ): บอกเวลารวมตามจำนวนรอบ แทน "แลกได้แน่นอน"
		local total = (entry.seconds or 0) * times
		odds.Text = times > 1
			and L("⏱ %s × %d = <font color=\"#%s\">%s</font> · สำเร็จแน่นอน", duration(entry.seconds), times,
				ENOUGH:ToHex(), duration(total))
			or L("⏱ %s · สำเร็จแน่นอน · เดินไปทำอย่างอื่นได้", duration(total))
	elseif (entry.chance or 1) >= 1 and fee <= 0 then
		-- A straight exchange, which is what the unlucky page is. Printing "100% · 0 เหรียญ" would dress a
		-- certainty up as a bet and invite the player to read odds that are not there.
		odds.Text = L("<font color=\"#%s\">แลกได้แน่นอน ไม่มีค่าจ้าง</font>", ENOUGH:ToHex())
	else
		odds.Text = (L("โอกาสสำเร็จ %d%%  ·  ค่าจ้าง <font color=\"#%s\">%d</font> เหรียญ"))
			:format(math.floor((entry.chance or 1) * 100 + 0.5), feeColor:ToHex(), fee)
	end
	-- เชื้อเพลิงขึ้นหน้าสุด (บรรทัดยาวแล้วถูกตัดท้าย ⛽ ต้องไม่หาย)
	if fuelPct then
		odds.Text = ("<font color=\"#%s\">⛽ %d%%</font> · "):format((fuelShort and SHORT or ENOUGH):ToHex(), fuelPct) .. odds.Text
	end
	odds.Parent = frame

	-- The bar sits where the odds line is and is only shown while the hammer swings, so a row at rest is no
	-- taller and no busier than it was before. An empty rail rather than a hidden one would be five pieces of
	-- furniture that mean nothing until something happens.
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(40, materialsBottom + 2)
	track.Size = UDim2.new(1, -120, 0, 10)
	track.BackgroundColor3 = STONE_DEEP
	track.BorderSizePixel = 0
	track.Visible = false
	track.Parent = frame
	corner(track, UDim.new(1, 0))

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = RUNE
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, UDim.new(1, 0))

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -6, 0.5, 0)
	button.Size = UDim2.fromOffset(64, 28)
	-- A button the player cannot use yet is greyed rather than hidden: the recipe is still worth seeing, and
	-- a row that only appears once you can afford it never tells you what to go and gather.
	button.BackgroundColor3 = affordable and ENOUGH or Color3.fromRGB(70, 74, 84)
	button.AutoButtonColor = affordable
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextColor3 = affordable and Color3.fromRGB(24, 26, 32) or TEXT_MUTED
	button.Text = entry.closed and "🔒" or entry.lockLevel and ("🔒 Lv%d"):format(entry.lockLevel)
		or Show(entry.action) or (((entry.chance or 1) >= 1 and (entry.gold or 0) <= 0)
			and ((entry.seconds or 0) >= 10 and L("ทำ") or L("แลก")) or L("สร้าง"))
	button.Parent = frame
	corner(button, UDim.new(0, 5))
	button.Activated:Connect(function()
		-- Silent when it is not craftable rather than firing a request the server would only refuse. The
		-- server still checks: this is presentation, not the rule.
		--
		-- The busy test is read off the button itself rather than passed in, because greying it out happens
		-- long after this closure was made -- the lock has to be a thing the row can be PUT INTO, not a value
		-- captured when it was drawn.
		-- แถวที่ยังไม่เปิด: แตะไอคอนล็อกแล้วบอกว่ายังไม่เปิด (ข้อความเด้งในเครื่อง ไม่ต้องถามเซิร์ฟ)
		if entry.closed then
			local toast = game.ReplicatedStorage:FindFirstChild("WOLD_Toast")
			if toast then toast:Fire(L("🔒 ยังไม่เปิด")) end
			return
		end
		if not affordable or button:GetAttribute("Busy") then return end
		UiSound.Play("Click")
		onClick()
	end)

	-- **ปุ่ม −/+ จำนวนรอบ** (เฟส 2c ผู้ใช้เลือก 2026-09-27) — เฉพาะสูตรที่เซิร์ฟบอกว่าทำหลายรอบได้ (`entry.batch`
	-- = รอบสูงสุดที่ของในกระเป๋าพอ) · ซ่อนตอนล็อกเลเวล
	if entry.batch and not entry.lockLevel and not entry.closed and onTimes then
		local box = Instance.new("Frame")
		box.Name = "Times"
		box.AnchorPoint = Vector2.new(1, 0.5)
		box.Position = UDim2.new(1, -76, 0.5, 0)
		box.Size = UDim2.fromOffset(92, 28)
		box.BackgroundColor3 = STONE_DEEP
		box.BorderSizePixel = 0
		box.Parent = frame
		corner(box, UDim.new(0, 5))
		local function stepper(text, x, delta)
			local b = Instance.new("TextButton")
			b.Position = UDim2.fromOffset(x, 0)
			b.Size = UDim2.fromOffset(28, 28)
			b.BackgroundColor3 = Color3.fromRGB(70, 74, 84)
			b.BorderSizePixel = 0
			b.Font = Enum.Font.GothamBold
			b.TextSize = 16
			b.TextColor3 = TEXT_LIGHT
			b.Text = text
			b.Parent = box
			corner(b, UDim.new(0, 5))
			b.Activated:Connect(function()
				if button:GetAttribute("Busy") then return end
				local nextTimes = math.clamp(times + delta, 1, math.max(1, entry.batch))
				if nextTimes == times then return end
				UiSound.Play("Click")
				onTimes(nextTimes)
			end)
		end
		stepper("−", 0, -1)
		stepper("+", 64, 1)
		local count = Instance.new("TextLabel")
		count.BackgroundTransparency = 1
		count.Position = UDim2.fromOffset(28, 0)
		count.Size = UDim2.fromOffset(36, 28)
		count.Font = Enum.Font.GothamBold
		count.TextSize = 13
		count.TextColor3 = RUNE
		count.Text = ("x%d"):format(times)
		count.Parent = box
		-- ชื่อ/บรรทัดโอกาสหดให้พ้นกล่องปุ่ม
		label.Size = UDim2.new(1, -212, 0, 18)
		odds.Size = UDim2.new(1, -212, 0, 15)
	end

	-- The pieces the window has to reach back into once the row is drawn: the bar to fill, the button to put
	-- to sleep while another row is busy, and the odds line to swap for the outcome and back. The row's own
	-- colour is kept so the outcome flash has something to fade home to.
	return { frame = frame, track = track, fill = fill, button = button, odds = odds,
		baseColor = frame.BackgroundColor3, winText = entry.winText, failText = entry.failText }
end

-- Redraws the recipe list for whichever tab is open. Separate from Show because switching tabs must not need
-- another round trip to the server -- the snapshot already holds every recipe on every page.
function CraftGui:Render()
	for _, child in ipairs(self.list:GetChildren()) do
		if not child:IsA("UIListLayout") then child:Destroy() end
	end
	if not self.snapshot then return end

	self.rows = {}
	local shown = 0
	for _, entry in ipairs(self.snapshot.recipes or {}) do
		if entry.tab == self.activeTab then
			shown += 1
			-- จำนวนรอบ: หนีบกับที่ของพอในภาพล่าสุด (ของหมดไประหว่างนั้น = ลดลงเอง)
			local times = 1
			if entry.batch then
				times = math.clamp(self.times[entry.index] or 1, 1, math.max(1, entry.batch))
				self.times[entry.index] = times
			end
			self.rows[entry.index] = recipeRow(self.list, shown, entry, function()
				-- แถวตีบวกขอ "ตีอาวุธช่องนี้" ไม่ใช่ "ทำสูตรลำดับนี้"
				if entry.enhance then
					if self.onEnhance then self.onEnhance(entry.enhance.slot) end
				elseif self.onCraft then
					self.onCraft(entry.index, times)
				end
			end, times, function(n)
				self.times[entry.index] = n
				self:Render()
			end, self.fuel)
		end
	end

	-- ปุ่มเร่ง: เครื่องนี้ทำงานอยู่ + มีเชื้อเพลิง
	self.boostButton.Visible = self.fuel ~= nil and self.busyActive == true and (self.fuel.amount or 0) > 0
	self:RefreshInstant()

	-- A craft in flight survives a redraw. The server sends a fresh snapshot the moment the hammer starts --
	-- that is what makes the materials visibly leave the bag -- and it destroys every row, so without this the
	-- bar would appear and vanish in the same frame and every button would come back live mid-swing.
	if self.busyActive then
		self:ApplyBusy()
	elseif self.outcomeIndex then
		self:ApplyOutcome()
	end

	if shown == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -4, 0, 30)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 12
		empty.TextColor3 = TEXT_MUTED
		empty.Text = L("ยังไม่มีสูตรในหมวดนี้")
		empty.Parent = self.list
	end

	-- The open tab is lit; the rest are flat. Redone on every render rather than only on a tab press, since
	-- the bar is rebuilt whenever a snapshot arrives.
	for _, button in ipairs(self.tabBar:GetChildren()) do
		if button:IsA("TextButton") then
			local active = button:GetAttribute("TabId") == self.activeTab
			button.BackgroundColor3 = active and RUNE or Color3.fromRGB(52, 55, 66)
			button.TextColor3 = active and Color3.fromRGB(24, 26, 32) or TEXT_MUTED
		end
	end
end

function CraftGui:Show(snapshot)
	self.snapshot = snapshot
	-- เชื้อเพลิง: มีเฉพาะเครื่องบนเกาะ · แถบอยู่ใต้แท็บ แล้วรายการสูตรเลื่อนลง
	local fuel = snapshot.fuel
	self.fuel = fuel
	self.fuelStrip.Visible = fuel ~= nil
	local top = fuel and 124 or 84
	self.body.Position = UDim2.fromOffset(12, top)
	self.body.Size = UDim2.new(1, -24, 1, -(top + 12))
	if fuel then
		local pct = CraftFuel.Percent(fuel.amount)
		self.fuelFill.Size = UDim2.fromScale(pct / 100, 1)
		self.fuelText.Text = (fuel.amount or 0) > 0
			and L("⛽ เชื้อเพลิง %d%% · ทำงานได้อีก %s", math.floor(pct), duration(fuel.amount))
			or L("⛽ เชื้อเพลิงหมด — เติมถ่านหิน (16 ก้อน = เต็ม)")
		self.fuelCoal.Text = L("ถ่าน %d", fuel.coal or 0)
		self.fuelMax = math.min(fuel.coal or 0, CraftFuel.Room(fuel.amount))
		self.fuelBox.Text = NumberBox.Clean(self.fuelBox.Text, self.fuelMax)
	end
	-- ชื่อหน้าต่างตามเครื่องที่เปิด (เตาอบ/โต๊ะช่าง/กี่ทอ/ครัว) ไม่มี = โรงตีเหล็ก
	self.title.Text = Show(snapshot.title) or L("โรงตีเหล็ก")
	if snapshot.farmLevel then self.title.Text ..= L("   ·   🌾 เลเวลฟาร์ม %d", snapshot.farmLevel) end

	-- งานที่ค้างอยู่มาจาก **สแนปช็อต** ไม่ใช่ความจำของหน้าต่าง
	--
	-- สองเหตุผล: เดินกลับมาที่เตาที่ตุ๋นสเต็กค้างไว้ต้องเห็นแถบเดินต่อจากเดิม (ไม่งั้นหน้าว่างชวนให้กดซ้ำ
	-- แล้วเสียวัตถุดิบอีกชุด) และเดินจากเตาที่กำลังทำงานไปเครื่องต้มยาต้องไม่เห็นทุกปุ่มขึ้น "รอ..." ทั้งที่
	-- เครื่องต้มยาว่างอยู่ — ล็อกเป็นของเครื่อง ไม่ใช่ของคน
	local busy = snapshot.busy
	-- `busyActive` แยกจาก index: งานที่คืนมาหลังเข้าเกมใหม่อาจไม่มี index แต่เครื่องยังทำงานอยู่ ต้องล็อกทุกแถว
	self.busyActive = busy ~= nil and (busy.remaining or 0) > 0
	if self.busyActive then
		self.busyIndex = busy.index
		self.busySeconds = busy.seconds or busy.remaining
		self.busyUntil = os.clock() + busy.remaining
	else
		self.busyIndex = nil
	end

	for _, child in ipairs(self.tabBar:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	local tabs = snapshot.tabs or {}
	-- Falls back to the first page only when the remembered one is gone, so a craft redraw keeps the player
	-- where they were.
	local stillThere = false
	for _, tab in ipairs(tabs) do
		if tab.id == self.activeTab then stillThere = true end
	end
	if not stillThere then self.activeTab = tabs[1] and tabs[1].id end

	-- The tabs SHARE the row rather than each taking a fixed width.
	--
	-- They used to be 118px each, chosen to fit the four pages V0.5 ended with (4 x 118 + 3 x 6 = 490 of the
	-- panel's 536). The fifth page took that to 602: the row does not wrap, so the overflow pushed the later
	-- tabs off the right edge and left the middle ones unreachable -- which read as "the misc tab does not
	-- respond" rather than as a layout fault.
	--
	-- Scaled by count, so a sixth page costs nothing and cannot do this again.
	local gap = 6
	local slice = 1 / math.max(1, #tabs)
	for order, tab in ipairs(tabs) do
		local button = Instance.new("TextButton")
		button.LayoutOrder = order
		-- Each takes its share of the row minus its share of the gaps between them.
		button.Size = UDim2.new(slice, -gap * (#tabs - 1) * slice, 0, 28)
		button.TextScaled = false
		button.TextTruncate = Enum.TextTruncate.AtEnd
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.TextSize = 12
		button.Text = Show(tab.name)
		button:SetAttribute("TabId", tab.id)
		button.Parent = self.tabBar
		corner(button, UDim.new(0, 6))
		button.Activated:Connect(function()
			UiSound.Play("Click")
			self.activeTab = tab.id
			self:Render()
		end)
	end

	self:Render()
	self.gui.Enabled = true
end

function CraftGui:Hide()
	local wasOpen = self.gui.Enabled
	self.gui.Enabled = false
	if wasOpen and self.onHide then self.onHide() end
	-- Forgotten on close. The craft itself carries on at the smith's end -- the server took the materials
	-- before the first swing -- but a bar and an outcome are things being SHOWN, and there is nobody left to
	-- show them to. Reopening draws whatever the server says by then.
	self.busyActive = false
	self.busyIndex = nil
	self.outcomeIndex = nil
	self.times = {}
end

function CraftGui:IsOpen()
	return self.gui.Enabled
end

return CraftGui
