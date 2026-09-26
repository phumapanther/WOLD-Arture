-- IslandBuildGui: หน้าจอโหมดจัดเกาะมุมสูง (ผู้ใช้สั่ง 2026-09-25) — วาดอย่างเดียว ไม่รู้จัก remote
--
--   หัวบน    : ชื่อโหมด + วิธีใช้ + ปุ่มออก
--   แผงกลาง  : ชื่อของที่จับอยู่ · สถานะ (วางได้/เหตุผล) · ปุ่มตามสถานการณ์ (SetActions)
--   แถบล่าง  : ของวางได้ในกระเป๋า แตะหนึ่งชิ้น = หยิบขึ้นมาวาง
--
-- ปุ่มทุกปุ่มมีไว้ให้มือถือเป็นหลัก คีย์บอร์ดมีทางลัดเดียวกัน (คลิก ลาก R Esc F4)
local Responsive = require(script.Parent.Responsive)
local ItemIcon = require(script.Parent.ItemIcon)

local PANEL = Color3.fromRGB(24, 22, 28)
local CARD = Color3.fromRGB(40, 37, 46)
local TEXT = Color3.fromRGB(236, 232, 224)
local MUTED = Color3.fromRGB(170, 164, 156)
local OK_COLOR = Color3.fromRGB(111, 224, 122)
local BAD_COLOR = Color3.fromRGB(255, 107, 107)
local BRASS = Color3.fromRGB(196, 150, 60)

local IslandBuildGui = {}
IslandBuildGui.__index = IslandBuildGui
-- ⚠️ ต้องอยู่หลัง `local IslandBuildGui = {}` — เคยวางไว้ก่อนแล้วโมดูลพังตอนโหลด ทั้งโหมดจัดเกาะ/F4/การซ่อนปุ่ม F ตายหมด
-- จอสัมผัสล้วน: ไม่มีล้อเมาส์/R/Esc/F4 → มีปุ่มซูม และป้ายปุ่มไม่บอกคีย์ที่กดไม่ได้ (QA 2026-09-26)
IslandBuildGui.TouchOnly = game:GetService("UserInputService").TouchEnabled
	and not game:GetService("UserInputService").KeyboardEnabled

-- สีปุ่มตามหน้าที่ ให้คนเรียกพูดเป็นคำ ไม่ต้องจำ RGB
IslandBuildGui.Colors = {
	rotate = Color3.fromRGB(58, 86, 128),
	place = Color3.fromRGB(72, 104, 78),
	move = Color3.fromRGB(120, 96, 50),
	pickup = Color3.fromRGB(110, 70, 120),
	cancel = Color3.fromRGB(110, 50, 50),
}

local function corner(inst, px)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, px or 10); c.Parent = inst
end

local function text(parent, value, size, color, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.Gotham
	l.TextSize = size
	l.TextColor3 = color
	l.Text = value or ""
	l.Parent = parent
	return l
end

function IslandBuildGui.new(playerGui)
	local self = setmetatable({}, IslandBuildGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "IslandBuildGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.Enabled = false
	gui.Parent = playerGui

	-- หัวบน
	local head = Instance.new("Frame")
	head.AnchorPoint = Vector2.new(0.5, 0)
	head.Position = UDim2.new(0.5, 0, 0, 58)
	head.Size = UDim2.new(0, 560, 0, 40)
	head.BackgroundColor3 = PANEL
	head.BackgroundTransparency = 0.2
	head.BorderSizePixel = 0
	head.Parent = gui
	corner(head)
	Responsive.Scale(head, 0.55)
	local headText = text(head, "🏗️ จัดเกาะ · แตะของเพื่อเลือก · ลากเพื่อย้าย", 15, BRASS, Enum.Font.GothamBold)
	headText.Position = UDim2.new(0, 14, 0, 0)
	headText.Size = UDim2.new(1, -130, 1, 0)
	headText.TextXAlignment = Enum.TextXAlignment.Left
	local exit = Instance.new("TextButton")
	exit.AnchorPoint = Vector2.new(1, 0.5)
	exit.Position = UDim2.new(1, -6, 0.5, 0)
	exit.Size = UDim2.new(0, 108, 0, 30)
	exit.BackgroundColor3 = IslandBuildGui.Colors.cancel
	exit.BorderSizePixel = 0
	exit.Font = Enum.Font.GothamBold
	exit.TextSize = 14
	exit.TextColor3 = TEXT
	exit.Text = IslandBuildGui.TouchOnly and "ออก" or "ออก (F4)"
	exit.Parent = head
	corner(exit, 8)
	exit.MouseButton1Click:Connect(function() if self.OnExit then self.OnExit() end end)

	-- แผงกลาง: โผล่เฉพาะตอนจับของอยู่ (SetActions ว่าง = ซ่อน)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -128)
	panel.Size = UDim2.new(0, 480, 0, 74)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.2
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	corner(panel)
	Responsive.Scale(panel, 0.55)
	local title = text(panel, "", 16, BRASS, Enum.Font.GothamBold)
	title.Position = UDim2.new(0, 12, 0, 6)
	title.Size = UDim2.new(0.5, -12, 0, 20)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local status = text(panel, "", 14, OK_COLOR)
	status.Position = UDim2.new(0.5, 0, 0, 6)
	status.Size = UDim2.new(0.5, -12, 0, 20)
	status.TextXAlignment = Enum.TextXAlignment.Right
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.new(0, 12, 1, -38)
	row.Size = UDim2.new(1, -24, 0, 30)
	row.Parent = panel
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.Parent = row

	-- แถบล่าง: ของวางได้ในกระเป๋า
	local bar = Instance.new("ScrollingFrame")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -12)
	bar.Size = UDim2.new(0, 760, 0, 108)
	bar.BackgroundColor3 = PANEL
	bar.BackgroundTransparency = 0.2
	bar.BorderSizePixel = 0
	bar.ScrollingDirection = Enum.ScrollingDirection.X
	bar.AutomaticCanvasSize = Enum.AutomaticSize.X
	bar.CanvasSize = UDim2.new()
	bar.ScrollBarThickness = 4
	bar.Parent = gui
	corner(bar)
	Responsive.Scale(bar, 0.55)
	-- มือถือ: แถบล่างกว้าง 760 ทับปุ่มกระโดดกับกลุ่มปุ่มขวาล่าง → ขึ้นไปอยู่ใต้หัวบน (HUD ถูกซ่อนตอนจัดเกาะ ที่ว่าง)
	if IslandBuildGui.TouchOnly then
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.Position = UDim2.new(0.5, 0, 0, 104)
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingTop = UDim.new(0, 10), UDim.new(0, 8)
	pad.Parent = bar
	local barLayout = Instance.new("UIListLayout")
	barLayout.FillDirection = Enum.FillDirection.Horizontal
	barLayout.Padding = UDim.new(0, 8)
	barLayout.SortOrder = Enum.SortOrder.LayoutOrder
	barLayout.Parent = bar
	local empty = text(bar, "ไม่มีของวางได้ในกระเป๋า VIP — ซื้อที่ร้านบนเกาะ", 15, MUTED)
	empty.Size = UDim2.new(0, 740, 0, 90)

	-- ปุ่มซูม (มือถือ): ขวากลางจอ ห่างทั้งแถบล่างและกลุ่มปุ่มกระโดด · + / - เป็นตัวอักษร ASCII วาดได้ทุกฟอนต์
	if IslandBuildGui.TouchOnly then
		local zoomBox = Instance.new("Frame")
		zoomBox.AnchorPoint = Vector2.new(1, 0.5)
		zoomBox.Position = UDim2.new(1, -12, 0.42, 0)
		zoomBox.Size = UDim2.new(0, 56, 0, 124)
		zoomBox.BackgroundTransparency = 1
		zoomBox.Parent = gui
		Responsive.Scale(zoomBox, 0.8)
		for i, spec in ipairs({ { "+", -0.25 }, { "-", 0.25 } }) do
			local b = Instance.new("TextButton")
			b.Position = UDim2.new(0, 0, 0, (i - 1) * 68)
			b.Size = UDim2.new(0, 56, 0, 56)
			b.BackgroundColor3 = PANEL
			b.BackgroundTransparency = 0.2
			b.BorderSizePixel = 0
			b.Font = Enum.Font.GothamBold
			b.TextSize = 30
			b.TextColor3 = TEXT
			b.Text = spec[1]
			b.Parent = zoomBox
			corner(b, 28)
			b.Activated:Connect(function() if self.OnZoom then self.OnZoom(spec[2]) end end)
		end
	end

	self.gui, self.title, self.status, self.panel, self.row, self.bar, self.empty = gui, title, status, panel, row, bar, empty
	return self
end

function IslandBuildGui:Show()
	self.gui.Enabled = true
end

function IslandBuildGui:Hide()
	self.gui.Enabled = false
end

function IslandBuildGui:SetStatus(value, ok)
	self.status.Text = value or ""
	self.status.TextColor3 = ok and OK_COLOR or BAD_COLOR
end

-- actions = { { label, color = "rotate"|"place"|..., fn } } · ว่าง/nil = ซ่อนแผง
function IslandBuildGui:SetActions(titleText, actions)
	for _, child in ipairs(self.row:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	self.panel.Visible = actions ~= nil and #actions > 0
	self.title.Text = titleText or ""
	self.status.Text = ""
	for i, action in ipairs(actions or {}) do
		local b = Instance.new("TextButton")
		b.LayoutOrder = i
		b.Size = UDim2.new(0, 106, 1, 0)
		b.BackgroundColor3 = IslandBuildGui.Colors[action.color] or IslandBuildGui.Colors.place
		b.BackgroundTransparency = 0.15
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 14
		b.TextColor3 = TEXT
		b.Text = action.label
		b.Parent = self.row
		corner(b, 8)
		b.MouseButton1Click:Connect(action.fn)
	end
end

-- items = { { slot, id, name, icon, count } } · OnPick(slot, id)
function IslandBuildGui:SetItems(items)
	for _, child in ipairs(self.bar:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	self.empty.Visible = #items == 0
	for i, it in ipairs(items) do
		local card = Instance.new("TextButton")
		card.LayoutOrder = i
		card.Size = UDim2.new(0, 84, 0, 90)
		card.BackgroundColor3 = CARD
		card.BorderSizePixel = 0
		card.Text = ""
		card.AutoButtonColor = true
		card.Parent = self.bar
		corner(card, 8)
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Position = UDim2.new(0.5, -26, 0, 6)
		image.Size = UDim2.new(0, 52, 0, 52)
		image.Parent = card
		ItemIcon.Apply(image, it.icon)
		local name = text(card, it.name, 11, TEXT)
		name.Position = UDim2.new(0, 3, 1, -28)
		name.Size = UDim2.new(1, -6, 0, 26)
		name.TextWrapped = true
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local count = text(card, "x" .. it.count, 13, BRASS, Enum.Font.GothamBold)
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, -4, 0, 2)
		count.Size = UDim2.new(0, 40, 0, 16)
		count.TextXAlignment = Enum.TextXAlignment.Right
		card.MouseButton1Click:Connect(function()
			if self.OnPick then self.OnPick(it.slot, it.id) end
		end)
	end
end

return IslandBuildGui
