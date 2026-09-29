-- QuestTrackerGui: แถบเควสรวมมุมขวาบน (วาดอย่างเดียว · QuestTrackerController ต่อสาย · สเปก 2026-09-29-quest-log-oforian)
-- ทอง = เควสหลัก · ฟ้า = เควสรองของออฟาเรียน · ขาว = งานบอร์ด · 🔒 = ล็อก/รอ · 🧭 = กำลังนำทาง
-- DisplayOrder 4 = ใต้ปุ่มมือถือ (5) และทุกหน้าต่าง (12+) — ของเดิมอยู่ 900 ทับปุ่ม Q กับหน้าต่างฝั่งขวา (QA U1)
local Responsive = require(script.Parent.Responsive)
local QuestLogRules = require(script.Parent.Parent.QuestLogRules)

local QuestTrackerGui = {}
QuestTrackerGui.__index = QuestTrackerGui

local rgb = Color3.fromRGB
local PANEL = rgb(20, 22, 30)
local TEXT = rgb(240, 236, 226)
local MUTED = rgb(160, 162, 176)
local DONE = rgb(120, 220, 120)
local WIDTH, HEADER_H, ROW_H, GAP, MAX_LIST = 270, 28, 48, 4, 300

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

local function label(parent, name, text, size, color, align)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = text
	l.Parent = parent
	return l
end

function QuestTrackerGui.new(parent)
	local self = setmetatable({ rows = {}, buttons = {}, collapsed = Responsive.IsTouchOnly(), onTap = nil }, QuestTrackerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "WOLD_QuestLog"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4
	gui.Parent = parent
	self.gui = gui

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -12, 0, 150)
	holder.Size = UDim2.fromOffset(WIDTH, HEADER_H)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	Responsive.Scale(holder, 0.7)
	self.holder = holder

	local header = Instance.new("TextButton")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, HEADER_H)
	header.BackgroundColor3 = PANEL
	header.BackgroundTransparency = 0.2
	header.AutoButtonColor = true
	header.Font = Enum.Font.GothamBold
	header.TextSize = 14
	header.TextColor3 = QuestLogRules.Colors.main
	header.Text = ""
	header.Parent = holder
	corner(header, 8)
	header.Activated:Connect(function() self:SetCollapsed(not self.collapsed) end)
	self.header = header

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, HEADER_H + 4)
	list.Size = UDim2.new(1, 0, 0, 0)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = holder
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	self.list = list
	return self
end

function QuestTrackerGui:_layout()
	local n = #self.rows
	self.holder.Visible = n > 0
	self.header.Text = ("📜 เควส (%d)%s"):format(n, self.collapsed and "  · แตะเพื่อดู" or "")
	local listH = self.collapsed and 0 or math.min(n * (ROW_H + GAP), MAX_LIST)
	self.list.Visible = not self.collapsed
	self.list.Size = UDim2.new(1, 0, 0, listH)
	self.holder.Size = UDim2.fromOffset(WIDTH, HEADER_H + (self.collapsed and 0 or listH + 4))
end

function QuestTrackerGui:SetCollapsed(on)
	self.collapsed = on
	self:_layout()
end

function QuestTrackerGui:_row(row, order, navigating)
	local dim = QuestLogRules.Dim(row)
	local color = QuestLogRules.Colors[row.color] or TEXT
	local b = Instance.new("TextButton")
	b.Name = "Row_" .. order
	b.LayoutOrder = order
	b.AutoButtonColor = true
	b.Text = ""
	b.Size = UDim2.new(1, -6, 0, ROW_H)
	b.BackgroundColor3 = PANEL
	b.BackgroundTransparency = dim and 0.55 or 0.2
	b.Parent = self.list
	corner(b, 8)
	local stripe = Instance.new("Frame")
	stripe.Name = "Stripe"
	stripe.Position = UDim2.fromOffset(4, 5)
	stripe.Size = UDim2.new(0, 4, 1, -10)
	stripe.BackgroundColor3 = color
	stripe.BackgroundTransparency = dim and 0.6 or 0
	stripe.BorderSizePixel = 0
	stripe.Parent = b
	if navigating then
		local s = Instance.new("UIStroke")
		s.Color, s.Thickness = color, 1.5
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = b
	end
	local prefix = dim and "🔒 " or (navigating and "🧭 " or "")
	local title = label(b, "Title", prefix .. (row.title or ""), 14, color)
	title.Font = Enum.Font.GothamBold
	title.Position = UDim2.fromOffset(14, 4)
	title.Size = UDim2.new(1, -72, 0, 18)
	title.TextTransparency = dim and 0.35 or 0
	local goal = label(b, "Goal", row.goal or "", 12, dim and MUTED or TEXT)
	goal.Position = UDim2.fromOffset(14, 24)
	goal.Size = UDim2.new(1, -20, 0, 20)
	local progress = QuestLogRules.Progress(row)
	if progress then
		local p = label(b, "Progress", progress, 13, row.state == "done" and DONE or color, Enum.TextXAlignment.Right)
		p.Font = Enum.Font.GothamBold
		p.Position = UDim2.new(1, -60, 0, 4)
		p.Size = UDim2.fromOffset(52, 18)
	end
	b.Activated:Connect(function()
		if self.onTap then self.onTap(row) end
	end)
	return b
end

function QuestTrackerGui:SetRows(rows, navKey)
	self.rows = rows or {}
	for _, b in ipairs(self.buttons) do b:Destroy() end
	self.buttons = {}
	for i, row in ipairs(self.rows) do
		self.buttons[i] = self:_row(row, i, row.key == navKey)
	end
	self:_layout()
end

return QuestTrackerGui
