-- TutorialGui: ปุ่มเครื่องหมายตกใจ และสมุดสอนเล่นที่มันเปิด
--
-- ตัววาดล้วน เหมือน GUI อื่นในโฟลเดอร์นี้: มันวาดสิ่งที่ TutorialConfig บอก และรายงานการกดออกไปทาง
-- callback ไม่มีความรู้เรื่องระบบเกมเลยสักอย่าง
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)
local TutorialConfig = require(script.Parent.Parent.TutorialConfig)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local PAPER = Color3.fromRGB(232, 222, 198)   -- หน้ากระดาษ
local INK = Color3.fromRGB(46, 40, 32)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)

local TutorialGui = {}
TutorialGui.__index = TutorialGui

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

function TutorialGui.new()
	local self = setmetatable({}, TutorialGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 21
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	----------------------------------------------------------------------------
	-- ปุ่มกลมเครื่องหมายตกใจ
	--
	-- **อยู่ในกล่องทรงเดียวกับ `menuGroup` ของ HUD (220x140 ชิดขวาบน) และย่อด้วยสเกลตัวเดียวกัน**
	-- (baseline 1280 พื้น 0.55) ปุ่มสามจุดย่อ/ขยับตามขนาดจอ ส่วนปุ่มนี้เคยตรึงพิกเซลตายตัวจากขอบขวา
	-- พอจอเปลี่ยนขนาด สองปุ่มจึงเดินคนละทางแล้วซ้อนกัน (ผู้ใช้แจ้ง 2026-09-19) — อยู่กล่องเดียวกันแล้ว
	-- ระยะห่างจะคงที่ทุกขนาดจอโดยไม่ต้องคำนวณอะไรเพิ่ม
	--
	-- วางไว้ **ซ้ายมือของปุ่มสามจุด แถวเดียวกัน** ไม่ใช่ใต้ปุ่มอีกต่อไป เพราะใต้ปุ่มคือที่ของแผงเมนูที่
	-- กางลงมา (y 56 ลงไป สูงขึ้นทุกครั้งที่เพิ่มเมนู) ปุ่มที่อยู่ตรงนั้นจะถูกแผงทับทุกครั้งที่เปิดเมนู
	----------------------------------------------------------------------------
	local corner_group = Instance.new("Frame")
	corner_group.Name = "TopRight"
	corner_group.AnchorPoint = Vector2.new(1, 0)
	corner_group.Position = UDim2.new(1, 0, 0, 0)
	corner_group.Size = UDim2.fromOffset(220, 140)
	corner_group.BackgroundTransparency = 1
	corner_group.Parent = gui
	Responsive.Scale(corner_group, Responsive.CornerMinScale()) -- ค่าเดียวกับกลุ่มเมนู ⋯ ของ HudGui

	local button = Instance.new("TextButton")
	button.Name = "TutorialButton"
	button.AnchorPoint = Vector2.new(1, 0)
	-- ปุ่มสามจุด: ขอบขวาที่ 216 กว้าง 44 สูงจากบน 4 (กึ่งกลางที่ y=26) → ตัวนี้จบที่ 164 เว้นช่องไฟ 8
	button.Position = UDim2.new(1, -56, 0, 7)
	button.Size = UDim2.fromOffset(38, 38)
	-- โปร่งใสตามที่สั่ง: เห็นโลกข้างหลังได้ แต่ยังอ่านออก
	button.BackgroundColor3 = STONE
	button.BackgroundTransparency = 0.35
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 20
	button.TextColor3 = RUNE
	button.Text = "!"
	button.AutoButtonColor = false
	button.Parent = corner_group
	corner(button, UDim.new(1, 0))
	local glow = stroke(button, RUNE, 0.2, 2)
	self.button = button

	-- เรืองแสง: ขอบกับตัวอักษรหายใจเข้าออกช้าๆ
	--
	-- ใช้ TweenService วนซ้ำแทนลูปต่อเฟรม เพราะมันคือค่าสองค่าวิ่งกลับไปกลับมาตลอดกาล การเขียนลูปเองจะ
	-- เสียเฟรมไปฟรีๆ ทั้งที่เอนจิ้นทำให้ได้อยู่แล้ว
	local pulseIn = TweenService:Create(glow, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut,
		-1, true), { Transparency = 0.65 })
	pulseIn:Play()

	local tip = Instance.new("TextLabel")
	tip.Name = "Tip"
	tip.AnchorPoint = Vector2.new(1, 0.5)
	tip.Position = UDim2.new(0, -6, 0.5, 0)
	tip.Size = UDim2.fromOffset(64, 20)
	tip.BackgroundTransparency = 1
	tip.Font = Enum.Font.GothamBold
	tip.TextSize = 12
	tip.TextXAlignment = Enum.TextXAlignment.Right
	tip.TextColor3 = TEXT_MUTED
	tip.Text = TutorialConfig.ButtonTooltip
	tip.Visible = false
	tip.Parent = button

	button.MouseEnter:Connect(function() tip.Visible = true end)
	button.MouseLeave:Connect(function() tip.Visible = false end)

	-- **ฉากหลังต้องถูกสร้างก่อนสมุด** ไม่ใช่หลัง
	--
	-- ScreenGui นี้ใช้ ZIndexBehavior แบบ Sibling (ค่าเริ่มต้น) ซึ่งตัดสินทั้งการวาดและ **การรับคลิก**
	-- จากลำดับการเป็นลูกด้วย ไม่ใช่จาก ZIndex อย่างเดียว ของเดิมสร้างฉากหลังทีหลังสมุด มันจึงอยู่บนสุด
	-- และกินคลิกทุกครั้งที่กดอะไรในสมุด แล้วปิดตัวเองทิ้ง — ตั้ง ZIndex = 0 ก็ไม่ช่วย
	--
	-- ArrestGui ที่ใช้งานได้ปกติสร้างฉากหลังก่อน panel เสมอ ไฟล์นี้เรียงกลับกัน
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.ZIndex = 0
	backdrop.Visible = false
	backdrop.Parent = gui
	backdrop.Activated:Connect(function() self:Hide() end)
	self.backdrop = backdrop

	----------------------------------------------------------------------------
	-- สมุด
	----------------------------------------------------------------------------
	local book = Instance.new("Frame")
	book.Name = "Book"
	book.AnchorPoint = Vector2.new(0.5, 0.5)
	book.Position = UDim2.fromScale(0.5, 0.5)
	book.Size = Responsive.IsSmallScreen() and UDim2.fromScale(0.95, 0.88)
		or UDim2.fromOffset(720, 520)
	book.BackgroundColor3 = STONE
	book.BorderSizePixel = 0
	book.Visible = false
	book.Parent = gui
	corner(book, UDim.new(0, 14))
	stroke(book, RUNE, 0.45, 2)
	Responsive.Scale(book, Responsive.IsSmallScreen() and 0.95 or nil) -- มือถือ: แผงเต็มจออยู่แล้ว ห้ามย่อซ้ำ (QA 2026-09-26)
	self.book = book


	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 30)
	title.Position = UDim2.new(0, 14, 0, 12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 19
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = RUNE
	title.Text = TutorialConfig.Title
	title.Parent = book

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(30, 30)
	close.BackgroundColor3 = Color3.fromRGB(96, 62, 62)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBold
	close.TextSize = 15
	close.TextColor3 = TEXT_LIGHT
	close.Text = "\195\151"
	close.Parent = book
	corner(close, UDim.new(0, 8))
	close.Activated:Connect(function()
		UiSound.Play("Click")
		self:Hide()
	end)

	-- สันสมุด: รายชื่อหัวข้อฝั่งซ้าย เนื้อหาฝั่งขวา
	local spine = Instance.new("ScrollingFrame")
	spine.Name = "Spine"
	spine.Position = UDim2.new(0, 12, 0, 50)
	spine.Size = UDim2.new(0, 190, 1, -62)
	spine.BackgroundColor3 = STONE_DEEP
	spine.BorderSizePixel = 0
	spine.ScrollBarThickness = 5
	spine.CanvasSize = UDim2.new()
	spine.AutomaticCanvasSize = Enum.AutomaticSize.Y
	spine.Parent = book
	corner(spine, UDim.new(0, 10))

	local spineLayout = Instance.new("UIListLayout")
	spineLayout.Padding = UDim.new(0, 4)
	spineLayout.SortOrder = Enum.SortOrder.LayoutOrder
	spineLayout.Parent = spine

	local spinePad = Instance.new("UIPadding")
	spinePad.PaddingTop = UDim.new(0, 6)
	spinePad.PaddingLeft = UDim.new(0, 6)
	spinePad.PaddingRight = UDim.new(0, 6)
	spinePad.PaddingBottom = UDim.new(0, 6)
	spinePad.Parent = spine

	-- หน้ากระดาษ สีต่างจากตัวสมุดเพราะมันคือ "กระดาษ" ไม่ใช่ "แผงอีกแผง"
	local page = Instance.new("ScrollingFrame")
	page.Name = "Page"
	page.Position = UDim2.new(0, 210, 0, 50)
	page.Size = UDim2.new(1, -222, 1, -62)
	page.BackgroundColor3 = PAPER
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 6
	page.CanvasSize = UDim2.new()
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Parent = book
	corner(page, UDim.new(0, 10))
	self.page = page

	local pageLayout = Instance.new("UIListLayout")
	pageLayout.Padding = UDim.new(0, 6)
	pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pageLayout.Parent = page

	local pagePad = Instance.new("UIPadding")
	pagePad.PaddingTop = UDim.new(0, 12)
	pagePad.PaddingLeft = UDim.new(0, 14)
	pagePad.PaddingRight = UDim.new(0, 14)
	pagePad.PaddingBottom = UDim.new(0, 14)
	pagePad.Parent = page

	-- ปุ่มหัวข้อ สร้างครั้งเดียว เนื้อหาถึงเปลี่ยนทุกครั้งที่กด
	self.tabs = {}
	-- หน้าที่ผูกกับอุปกรณ์ (`device`) โชว์เฉพาะเครื่องที่ตรง: หน้าคีย์บอร์ดบนมือถือคือรายการปุ่มที่กดไม่ได้
	local touchOnly = game:GetService("UserInputService").TouchEnabled
		and not game:GetService("UserInputService").KeyboardEnabled
	local firstShown = nil
	for order, section in ipairs(TutorialConfig.Sections) do
		if section.device == "touch" and not touchOnly then continue end
		if section.device == "keyboard" and touchOnly then continue end
		firstShown = firstShown or section.id
		local tab = Instance.new("TextButton")
		tab.Name = section.id
		tab.LayoutOrder = order
		tab.Size = UDim2.new(1, 0, 0, 30)
		tab.BackgroundColor3 = Color3.fromRGB(44, 47, 58)
		tab.BorderSizePixel = 0
		tab.Font = Enum.Font.GothamBold
		tab.TextSize = 12
		tab.TextXAlignment = Enum.TextXAlignment.Left
		tab.TextTruncate = Enum.TextTruncate.AtEnd
		tab.TextColor3 = TEXT_LIGHT
		tab.Text = ("  %s %s"):format(section.icon or "", section.title)
		tab.Parent = spine
		corner(tab, UDim.new(0, 6))
		tab.Activated:Connect(function()
			UiSound.Play("Click")
			self:ShowSection(section.id)
		end)
		self.tabs[section.id] = tab
	end

	button.Activated:Connect(function()
		UiSound.Play("Click")
		if book.Visible then self:Hide() else self:Show() end
	end)

	self:ShowSection(touchOnly and "controls_touch" or firstShown) -- มือถือเปิดมาเจอหน้าปุ่มก่อน
	return self
end

-- วาดหัวข้อหนึ่งลงหน้ากระดาษ
function TutorialGui:ShowSection(id)
	if not id then return end
	self.current = id

	for tabId, tab in pairs(self.tabs) do
		local on = tabId == id
		tab.BackgroundColor3 = on and Color3.fromRGB(70, 62, 96) or Color3.fromRGB(44, 47, 58)
		tab.TextColor3 = on and RUNE or TEXT_LIGHT
	end

	for _, child in ipairs(self.page:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end

	local section
	for _, entry in ipairs(TutorialConfig.Sections) do
		if entry.id == id then section = entry break end
	end
	if not section then return end

	local heading = Instance.new("TextLabel")
	heading.LayoutOrder = 0
	heading.Size = UDim2.new(1, 0, 0, 26)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBold
	heading.TextSize = 17
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextColor3 = Color3.fromRGB(120, 72, 32)
	heading.Text = ("%s  %s"):format(section.icon or "", section.title)
	heading.Parent = self.page

	for order, line in ipairs(section.body) do
		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.Size = UDim2.new(1, 0, 0, line == "" and 8 or 0)
		-- บรรทัดยาวห่อเองและสูงตามเนื้อหา ไม่ต้องเดาความสูงไว้ล่วงหน้า
		label.AutomaticSize = line == "" and Enum.AutomaticSize.None or Enum.AutomaticSize.Y
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Gotham
		label.TextSize = 13
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.RichText = true
		label.TextColor3 = INK
		-- `**ข้อความ**` เป็นตัวหนา เขียนในคอนฟิกได้โดยไม่ต้องรู้จัก RichText
		label.Text = (line:gsub("%*%*(.-)%*%*", "<b>%1</b>"))
		label.Parent = self.page
	end
end

function TutorialGui:Show()
	self.backdrop.Visible = true
	self.book.Visible = true
end

function TutorialGui:Hide()
	self.backdrop.Visible = false
	self.book.Visible = false
end

function TutorialGui:IsOpen() return self.book.Visible end

return TutorialGui
