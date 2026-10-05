-- PartyGui: แถบเพื่อนร่วมตี้ — ชื่อ เลือด และความหิว ของอีกสองคนในตี้
--
-- วางไว้ **เหนือกลุ่มหลอดของตัวเอง** ที่มุมซ้ายล่าง (ผู้ใช้สั่งให้อยู่ "ถัดจากบราของผู้เล่น") กลุ่มหลอดของ
-- HudGui สูง 100 px ยืนที่ 20 px จากขอบล่าง แถบนี้จึงเริ่มที่ 128 แล้วโตขึ้นข้างบน — ไม่ทับกันแม้ตี้เต็ม
-- และไม่ไปแย่งที่ของแถบไอเทมกับแถบ EXP ซึ่งอยู่กลางจอ
--
-- **หลอดเป็นเส้นบาง ไม่ใช่หลอดเต็มรูปแบบ** (ผู้ใช้กำหนด): ของคนอื่นต้อง "เหลือบแล้วรู้" ไม่ใช่ของที่จ้อง
-- ถ้าทำหนาเท่าของตัวเอง สายตาจะเริ่มอ่านผิดว่าอันไหนของใครในจังหวะที่กำลังสู้อยู่
--
-- เป็นตัววาดล้วน ไม่รู้จัก remote — `PartyController` ป้อนข้อมูลและรับปุ่ม "ออกจากตี้" ไปยิงเอง
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local L = require(script.Parent.Parent.Locale).L

local PANEL_WIDTH = 190
local ROW_HEIGHT = 34
local HEADER_HEIGHT = 18

local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local TRACK = Color3.fromRGB(18, 18, 22)
local HP_TOP, HP_BOTTOM = Color3.fromRGB(255, 107, 107), Color3.fromRGB(224, 47, 47)
local HUNGER_TOP, HUNGER_BOTTOM = Color3.fromRGB(111, 224, 122), Color3.fromRGB(47, 169, 61)
local DOWNED = Color3.fromRGB(120, 120, 130)

local PartyGui = {}
PartyGui.__index = PartyGui

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(1, 0)
	c.Parent = inst
	return c
end

local function gradient(parent, top, bottom)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = parent
	return g
end

-- หลอดเส้นบางหนึ่งเส้น คืนชิ้นที่ต้องขยับตอนค่าเปลี่ยน
local function bar(parent, y, height, top, bottom)
	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 0, 0, y)
	track.Size = UDim2.new(1, 0, 0, height)
	track.BackgroundColor3 = TRACK
	track.BackgroundTransparency = 0.25
	track.BorderSizePixel = 0
	track.Parent = parent
	corner(track)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = top
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill)
	gradient(fill, top, bottom)
	return fill
end

function PartyGui.new()
	local self = setmetatable({}, PartyGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "PartyGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8 -- ใต้หน้าต่างทุกบาน เหนือฉากเกม: มันเป็นส่วนหนึ่งของ HUD ไม่ใช่หน้าต่าง
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 20, 1, -128)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, HEADER_HEIGHT)
	panel.BackgroundTransparency = 1
	panel.Parent = gui
	Responsive.Scale(panel)
	self.panel = panel

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -44, 0, HEADER_HEIGHT)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextSize = 11
	header.TextColor3 = TEXT_MUTED
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = L("ตี้")
	header.Parent = panel
	self.header = header

	-- ทางออกอยู่ตรงนี้ที่เดียว: ตี้ที่เข้าแล้วออกไม่ได้คือกับดัก ไม่ใช่ฟีเจอร์
	local leave = Instance.new("TextButton")
	-- มือถือ: ปุ่มนี้อยู่ในโซนจอยเดิน (ซ้ายล่าง) และหลัง UIScale เหลือราว 24x11 px → ใหญ่ขึ้นบนจอสัมผัส
	-- (ยื่นขึ้นด้านบนหัวข้อ ที่ว่าง) และทุกเครื่องต้องแตะสองครั้งยืนยัน ไม่งั้นนิ้วที่จะเดินพาออกจากตี้ (QA 2026-09-26)
	local touchOnly = Responsive.IsTouchOnly()
	local LEAVE_COLOR, ARMED_COLOR = Color3.fromRGB(96, 56, 52), Color3.fromRGB(176, 62, 52)
	leave.AnchorPoint = Vector2.new(1, 1)
	leave.Position = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	leave.Size = touchOnly and UDim2.fromOffset(64, 34) or UDim2.fromOffset(44, HEADER_HEIGHT)
	leave.BackgroundColor3 = LEAVE_COLOR
	leave.BackgroundTransparency = 0.15
	leave.BorderSizePixel = 0
	leave.AutoButtonColor = true
	leave.Font = Enum.Font.GothamBold
	leave.TextSize = touchOnly and 14 or 11
	leave.TextColor3 = TEXT_LIGHT
	leave.Text = L("ออก")
	leave.Parent = panel
	corner(leave, UDim.new(0, 6))
	local armedUntil = 0
	leave.Activated:Connect(function()
		if os.clock() > armedUntil then
			armedUntil = os.clock() + 3
			leave.Text, leave.BackgroundColor3 = L("ยืนยัน?"), ARMED_COLOR
			task.delay(3, function()
				if os.clock() >= armedUntil then leave.Text, leave.BackgroundColor3 = L("ออก"), LEAVE_COLOR end
			end)
			return
		end
		armedUntil = 0
		leave.Text, leave.BackgroundColor3 = L("ออก"), LEAVE_COLOR
		if self.onLeave then self.onLeave() end
	end)

	self.rows = {}
	return self
end

function PartyGui:OnLeave(callback)
	self.onLeave = callback
end

-- สร้างแถวเท่าที่ต้องใช้ แล้วเก็บไว้ใช้ซ้ำ — คนในตี้เปลี่ยนบ่อยกว่าจำนวนแถว
function PartyGui:rowAt(index)
	local existing = self.rows[index]
	if existing then return existing end

	local frame = Instance.new("Frame")
	frame.Name = "Member" .. index
	-- แผงยึดขอบล่าง (AnchorPoint 0,1) พอสูงขึ้นมันจึงโตขึ้นข้างบนทั้งก้อน ข้างในเลยเรียงบนลงล่างตามปกติได้:
	-- หัวตารางอยู่บนสุด แล้วสมาชิกไล่ลงมา — แถวสุดท้ายจบพอดีที่ขอบล่างของแผง เหนือหลอดของตัวเอง 8 px
	frame.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT + (index - 1) * ROW_HEIGHT)
	frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT - 4)
	frame.BackgroundTransparency = 1
	frame.Parent = self.panel

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 13)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamMedium
	name.TextSize = 11
	name.TextColor3 = TEXT_LIGHT
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = ""
	name.Parent = frame
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = Color3.new(0, 0, 0)
	nameStroke.Transparency = 0.45
	nameStroke.Thickness = 2
	nameStroke.Parent = name

	local row = {
		frame = frame,
		name = name,
		hp = bar(frame, 15, 6, HP_TOP, HP_BOTTOM),
		hunger = bar(frame, 23, 5, HUNGER_TOP, HUNGER_BOTTOM),
	}
	self.rows[index] = row
	return row
end

-- `members` = { { name, hp, hunger, downed }, ... } · รายการว่าง = ไม่มีตี้ ซ่อนทั้งแถบ
function PartyGui:SetMembers(members)
	members = members or {}
	local count = #members

	self.gui.Enabled = count > 0
	if count == 0 then
		for _, row in ipairs(self.rows) do row.frame.Visible = false end
		return
	end

	self.panel.Size = UDim2.fromOffset(PANEL_WIDTH, HEADER_HEIGHT + count * ROW_HEIGHT)
	self.header.Text = L("ตี้ · %d คน", count + 1) -- +1 คือตัวเอง ซึ่งไม่มีแถวของตัวเองที่นี่

	for index, member in ipairs(members) do
		local row = self:rowAt(index)
		row.frame.Visible = true
		row.name.Text = member.downed and L("%s (ล้ม)", member.name) or member.name
		row.name.TextColor3 = member.downed and DOWNED or TEXT_LIGHT
		row.hp.Size = UDim2.new(math.clamp(member.hp or 0, 0, 1), 0, 1, 0)
		row.hunger.Size = UDim2.new(math.clamp(member.hunger or 0, 0, 1), 0, 1, 0)
	end

	for index = count + 1, #self.rows do
		self.rows[index].frame.Visible = false
	end
end

return PartyGui
