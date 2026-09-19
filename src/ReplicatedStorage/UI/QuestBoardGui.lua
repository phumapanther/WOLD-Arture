-- QuestBoardGui: กระดานไม้ที่มีใบประกาศติดอยู่
--
-- ตัววาดล้วน รายงานการกดออกไปทาง callback ไม่รู้จักระบบเกม
--
-- **ใบประกาศคือการ์ดหนึ่งใบต่อหนึ่งงาน** ไม่ใช่แถวในรายการ เพราะผู้ใช้ขอให้เป็นใบประกาศจริงๆ ที่มีรูป
-- มอน/ไอเทมอยู่กลางใบ ตัวนับอยู่ใต้รูป และปุ่มอยู่ล่างสุด
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)

local WOOD = Color3.fromRGB(74, 52, 34)       -- กระดานไม้
local WOOD_DARK = Color3.fromRGB(52, 36, 24)
local PAPER = Color3.fromRGB(232, 222, 198)
local INK = Color3.fromRGB(58, 46, 34)
local TEXT_LIGHT = Color3.fromRGB(236, 228, 210)
local TEXT_MUTED = Color3.fromRGB(122, 106, 88)
local RUNE = Color3.fromRGB(196, 150, 62)
local GREEN = Color3.fromRGB(78, 122, 64)
local GREY = Color3.fromRGB(110, 104, 96)

local QuestBoardGui = {}
QuestBoardGui.__index = QuestBoardGui

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

local function stroke(inst, colour, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Transparency = transparency or 0.5
	s.Thickness = thickness or 1
	s.Parent = inst
	return s
end

local function label(parent, text, size, colour, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = size or 13
	l.TextColor3 = colour or INK
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Text = text
	l.Parent = parent
	return l
end

function QuestBoardGui.new()
	local self = setmetatable({}, QuestBoardGui)
	self.callbacks = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "QuestBoardGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	-- ฉากหลังก่อน panel เสมอ: ScreenGui ใช้ ZIndexBehavior แบบ Sibling ซึ่งตัดสินการรับคลิกจากลำดับ
	-- การเป็นลูกด้วย สร้างทีหลังแล้วมันจะกินคลิกทุกครั้ง (บั๊กที่สมุดสอนเล่นเคยเจอ)
	local backdrop = Instance.new("TextButton")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.Parent = gui
	backdrop.Activated:Connect(function() self:Hide() end)

	-- กระดานไม้
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = Responsive.IsSmallScreen() and UDim2.fromScale(0.96, 0.82)
		or UDim2.fromOffset(700, 460)
	panel.BackgroundColor3 = WOOD
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 10))
	stroke(panel, WOOD_DARK, 0, 4)
	Responsive.Scale(panel)

	-- ลายไม้: เส้นแนวนอนจางๆ ให้ดูเป็นแผ่นไม้ประกบกัน ไม่ใช่สี่เหลี่ยมสีน้ำตาล
	for i = 1, 5 do
		local plank = Instance.new("Frame")
		plank.Size = UDim2.new(1, 0, 0, 2)
		plank.Position = UDim2.new(0, 0, i / 6, 0)
		plank.BackgroundColor3 = WOOD_DARK
		plank.BackgroundTransparency = 0.6
		plank.BorderSizePixel = 0
		plank.ZIndex = 0
		plank.Parent = panel
	end

	local title = label(panel, "กระดานงาน", 19, RUNE, Enum.TextXAlignment.Left)
	title.Size = UDim2.new(1, -60, 0, 26)
	title.Position = UDim2.new(0, 16, 0, 10)
	self.title = title

	local blurb = label(panel, "", 12, TEXT_MUTED, Enum.TextXAlignment.Left)
	blurb.Size = UDim2.new(1, -60, 0, 16)
	blurb.Position = UDim2.new(0, 16, 0, 34)
	self.blurb = blurb

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(30, 30)
	close.BackgroundColor3 = Color3.fromRGB(96, 56, 48)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBold
	close.TextSize = 15
	close.TextColor3 = TEXT_LIGHT
	close.Text = "\195\151"
	close.Parent = panel
	corner(close, UDim.new(0, 8))
	close.Activated:Connect(function()
		UiSound.Play("Click")
		self:Hide()
	end)

	-- ที่วางใบประกาศ
	local board = Instance.new("ScrollingFrame")
	board.Position = UDim2.new(0, 12, 0, 56)
	board.Size = UDim2.new(1, -24, 1, -68)
	board.BackgroundTransparency = 1
	board.BorderSizePixel = 0
	board.ScrollBarThickness = 5
	board.ScrollBarImageColor3 = RUNE
	board.CanvasSize = UDim2.new()
	board.AutomaticCanvasSize = Enum.AutomaticSize.Y
	board.Parent = panel
	self.board = board

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, Responsive.IsSmallScreen() and 150 or 200, 0, 250)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = board

	return self
end

function QuestBoardGui:On(name, fn)
	self.callbacks[name] = fn
end

function QuestBoardGui:fire(name, ...)
	local fn = self.callbacks[name]
	if fn then fn(...) end
end

--------------------------------------------------------------------------------
-- ใบประกาศหนึ่งใบ
--------------------------------------------------------------------------------

-- `accepted` = งานนี้รับไปแล้ว (ปุ่มเปลี่ยนเป็น "ส่งงาน")
local function notice(self, parent, order, quest, noticeImage, accepted, index, showFrom)
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.BackgroundColor3 = PAPER
	card.BorderSizePixel = 0
	card.Parent = parent
	corner(card, UDim.new(0, 4))
	-- เอียงนิดหน่อยคนละองศา ให้ดูเหมือนกระดาษที่ถูกตอกติดกระดานจริง ไม่ใช่ตารางที่จัดชิดกันเป๊ะ
	card.Rotation = (order % 2 == 0) and 1.2 or -1.2

	-- ใบประกาศเปล่าเป็นพื้นหลัง ถ้ามี
	if noticeImage and noticeImage ~= "" then
		local paper = Instance.new("ImageLabel")
		paper.Size = UDim2.fromScale(1, 1)
		paper.BackgroundTransparency = 1
		paper.Image = noticeImage
		paper.ScaleType = Enum.ScaleType.Stretch
		paper.ZIndex = 0
		paper.Parent = card
	end

	-- หมุดตอกกระดาษ
	local pin = Instance.new("Frame")
	pin.AnchorPoint = Vector2.new(0.5, 0)
	pin.Position = UDim2.new(0.5, 0, 0, 5)
	pin.Size = UDim2.fromOffset(9, 9)
	pin.BackgroundColor3 = Color3.fromRGB(150, 60, 50)
	pin.BorderSizePixel = 0
	pin.ZIndex = 3
	pin.Parent = card
	corner(pin, UDim.new(1, 0))

	local head = label(card, quest.title or "", 13, INK)
	head.Position = UDim2.new(0, 6, 0, 16)
	head.Size = UDim2.new(1, -12, 0, 16)
	head.TextTruncate = Enum.TextTruncate.AtEnd
	head.ZIndex = 2

	-- บอร์ดรวมบอกด้วยว่างานนี้ของเมืองไหน ไม่งั้นรับไปแล้วไม่รู้ว่าต้องไปส่งที่ไหน
	if showFrom and quest.from then
		local town = label(card, quest.from, 10, TEXT_MUTED)
		town.Position = UDim2.new(0, 6, 0, 32)
		town.Size = UDim2.new(1, -12, 0, 12)
		town.ZIndex = 2
	end

	-- รูปมอนหรือไอเทม
	local art = Instance.new("ImageLabel")
	art.AnchorPoint = Vector2.new(0.5, 0)
	-- เลื่อนลงให้พ้นบรรทัดชื่อเมือง และย่อให้จบก่อนตัวนับ — วัดแล้วว่าไม่ทับกัน
	art.Position = UDim2.new(0.5, 0, 0, 46)
	art.Size = UDim2.fromOffset(90, 90)
	art.BackgroundTransparency = 1
	art.Image = quest.icon or ""
	art.ScaleType = Enum.ScaleType.Fit
	art.ZIndex = 2
	art.Parent = card

	-- ไม่มีรูปก็ยังอ่านออก: ชื่อทำหน้าที่แทน เหมือนที่แคตตาล็อกเขียนไว้
	if not quest.icon or quest.icon == "" then
		local fallback = label(card, quest.text or "", 12, TEXT_MUTED)
		fallback.Position = UDim2.new(0, 8, 0, 76)
		fallback.Size = UDim2.new(1, -16, 0, 40)
		fallback.TextWrapped = true
		fallback.ZIndex = 2
	end

	-- ตัวนับ 0/10
	local done = (quest.got or 0) >= quest.need
	local counter = label(card, ("%d/%d"):format(quest.got or 0, quest.need), 17,
		done and GREEN or INK)
	counter.Position = UDim2.new(0, 6, 0, 140)
	counter.Size = UDim2.new(1, -12, 0, 22)
	counter.ZIndex = 2

	-- รางวัล
	local reward = label(card, ("%d ซิลเวอร์ · %d เหรียญ"):format(quest.silver or 0, quest.gold or 0),
		11, TEXT_MUTED)
	reward.Position = UDim2.new(0, 4, 0, 164)
	reward.Size = UDim2.new(1, -8, 0, 16)
	reward.ZIndex = 2

	local xp = label(card, ("+%d EXP"):format(quest.xp or 0), 11, TEXT_MUTED)
	xp.Position = UDim2.new(0, 4, 0, 180)
	xp.Size = UDim2.new(1, -8, 0, 14)
	xp.ZIndex = 2

	-- ปุ่มล่างสุด: รับงาน -> ส่งงาน
	--
	-- **ปุ่มเดียวที่เปลี่ยนความหมาย** ตามที่ผู้ใช้กำหนด ไม่ใช่สองปุ่มวางคู่กัน — การ์ดใบหนึ่งมีสถานะเดียว
	-- เสมอ และปุ่มที่กดไม่ได้ก็บอกเหตุผลด้วยสีกับข้อความแทนที่จะหายไป
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -8)
	button.Size = UDim2.new(1, -20, 0, 32)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = TEXT_LIGHT
	button.ZIndex = 2
	button.Parent = card
	corner(button, UDim.new(0, 6))

	if not accepted then
		button.Text = "รับงาน"
		button.BackgroundColor3 = RUNE
		button.TextColor3 = Color3.fromRGB(38, 28, 16)
		button.Activated:Connect(function()
			UiSound.Play("Click")
			self:fire("accept", index)
		end)
	elseif done then
		button.Text = "รับรางวัล"
		button.BackgroundColor3 = GREEN
		button.Activated:Connect(function()
			UiSound.Play("Click")
			self:fire("turnin", index)
		end)
	else
		-- รับแล้วแต่ยังไม่ครบ: บอกว่ายังขาดเท่าไหร่
		button.Text = ("ยังขาด %d"):format(quest.need - (quest.got or 0))
		button.BackgroundColor3 = GREY
		button.AutoButtonColor = false
	end

	-- งานที่รับไปแล้วยกเลิกได้ ปุ่มแยกของมันเอง กดสองครั้งยืนยัน
	--
	-- เวอร์ชันแรกใช้ "กดค้าง 1 วิ" บนปุ่มหลัก ซึ่งไม่มีอะไรบอกว่ากดได้ และบนมือถือ MouseLeave ไม่ยิง
	-- ผู้ใช้จึงหาทางยกเลิกไม่เจอ — ปุ่มที่เห็นแล้วต้องกดซ้ำเพื่อยืนยัน กันเผลอได้เท่ากันและเห็นชัดกว่า
	if accepted then
		button.Size = UDim2.new(1, -20, 0, 26)
		button.Position = UDim2.new(0.5, 0, 1, -6)

		local cancel = Instance.new("TextButton")
		cancel.AnchorPoint = Vector2.new(0.5, 1)
		cancel.Position = UDim2.new(0.5, 0, 1, -36)
		cancel.Size = UDim2.new(1, -20, 0, 18)
		cancel.BackgroundColor3 = Color3.fromRGB(96, 62, 62)
		cancel.BorderSizePixel = 0
		cancel.Font = Enum.Font.GothamBold
		cancel.TextSize = 10
		cancel.TextColor3 = TEXT_LIGHT
		cancel.Text = "ยกเลิกงาน"
		cancel.ZIndex = 2
		cancel.Parent = card
		corner(cancel, UDim.new(0, 5))

		local armed = false
		cancel.Activated:Connect(function()
			UiSound.Play("Click")
			if armed then
				self:fire("abandon", index)
				return
			end
			armed = true
			cancel.Text = "กดอีกครั้งเพื่อยืนยัน"
			cancel.BackgroundColor3 = Color3.fromRGB(150, 60, 50)
			task.delay(3, function()
				if cancel.Parent then
					armed = false
					cancel.Text = "ยกเลิกงาน"
					cancel.BackgroundColor3 = Color3.fromRGB(96, 62, 62)
				end
			end)
		end)
	end

	return card
end

--------------------------------------------------------------------------------
-- วาดทั้งกระดาน
--------------------------------------------------------------------------------

function QuestBoardGui:Render(data)
	self.data = data
	for _, child in ipairs(self.board:GetChildren()) do
		if not child:IsA("UIGridLayout") then child:Destroy() end
	end

	if not data then
		self.title.Text = "กระดานงาน"
		self.blurb.Text = "กำลังอ่านใบประกาศ..."
		return
	end

	self.title.Text = ("กระดานงาน — %s"):format(data.boardName or "")
	self.blurb.Text = ("%s · รับได้ %d/%d งาน"):format(
		data.blurb or "", #(data.active or {}), data.maxActive or 3)

	local order = 0

	-- งานที่รับไปแล้วขึ้นก่อน: มันคือสิ่งที่ผู้เล่นมาที่บอร์ดเพื่อจัดการ
	for i, quest in ipairs(data.active or {}) do
		order += 1
		-- งานที่รับแล้วบอกเมืองเสมอ ไม่ว่าจะยืนอยู่บอร์ดไหน — ต้องรู้ว่าไปทำที่ไหน
		notice(self, self.board, order, quest, data.notice, true, i, true)
	end

	-- งานที่ยังไม่ได้รับ
	for i, quest in ipairs(data.offered or {}) do
		order += 1
		notice(self, self.board, order, quest, data.notice, false, i, data.isMain)
	end

	if order == 0 then
		-- **กระดานว่างเพราะทำครบ ไม่เหมือนกระดานว่างเพราะไม่มีงาน** ใบที่ส่งไปแล้ววันนี้ถูกซ่อน (รับซ้ำไม่ได้
		-- เมืองละ 3 ใบต่อวัน) ถ้าไม่บอกเหตุผล ผู้เล่นที่เพิ่งส่งครบจะอ่านว่ากระดานพัง
		local text = (data.finishedToday or 0) > 0
			and "ส่งงานของกระดานนี้ครบแล้ววันนี้ — กลับมาใหม่พรุ่งนี้"
			or "ไม่มีใบประกาศบนกระดาน"
		local empty = label(self.board, text, 13, TEXT_LIGHT)
		empty.Size = UDim2.new(1, 0, 0, 60)
	end
end

function QuestBoardGui:Show(data)
	self:Render(data)
	self.gui.Enabled = true
end

function QuestBoardGui:Hide()
	if not self.gui.Enabled then return end
	self.gui.Enabled = false
	self:fire("close")
end

function QuestBoardGui:IsOpen()
	return self.gui.Enabled
end

return QuestBoardGui
