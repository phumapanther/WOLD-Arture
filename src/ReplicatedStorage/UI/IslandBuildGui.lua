-- IslandBuildGui: แถบล่างตอนอยู่ในโหมดวางของ — ชื่อของ · สถานะ (วางได้/เหตุผลที่ไม่ได้) · ปุ่ม หมุน/วาง/ยกเลิก
-- ปุ่มมีไว้ให้มือถือเป็นหลัก (คีย์บอร์ดใช้ R / คลิก / Esc ได้เหมือนกัน) จึงเป็นชุดเดียวทุกอุปกรณ์
local Responsive = require(script.Parent.Responsive)

local WIDTH, HEIGHT = 380, 74
local PANEL = Color3.fromRGB(24, 22, 28)
local TEXT = Color3.fromRGB(236, 232, 224)
local OK_COLOR = Color3.fromRGB(111, 224, 122)
local BAD_COLOR = Color3.fromRGB(255, 107, 107)
local BRASS = Color3.fromRGB(196, 150, 60)

local IslandBuildGui = {}
IslandBuildGui.__index = IslandBuildGui

local function corner(inst, px)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, px or 10); c.Parent = inst
end

local function button(parent, x, label, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 108, 0, 30)
	b.Position = UDim2.new(0, x, 1, -38)
	b.BackgroundColor3 = color
	b.BackgroundTransparency = 0.15
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = TEXT
	b.Text = label
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 8)
	return b
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

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -150) -- เหนือช่องของใช้ 6 ช่องของ HUD
	bar.Size = UDim2.new(0, WIDTH, 0, HEIGHT)
	bar.BackgroundColor3 = PANEL
	bar.BackgroundTransparency = 0.2
	bar.BorderSizePixel = 0
	bar.Parent = gui
	corner(bar)
	Responsive.Scale(bar, 0.55)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 12, 0, 6)
	title.Size = UDim2.new(0.5, -12, 0, 20)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = BRASS
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = ""
	title.Parent = bar

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Position = UDim2.new(0.5, 0, 0, 6)
	status.Size = UDim2.new(0.5, -12, 0, 20)
	status.Font = Enum.Font.Gotham
	status.TextSize = 14
	status.TextColor3 = OK_COLOR
	status.TextXAlignment = Enum.TextXAlignment.Right
	status.Text = ""
	status.Parent = bar

	local rotate = button(bar, 12, "หมุน (R)", Color3.fromRGB(58, 86, 128))
	local place = button(bar, 136, "วาง", Color3.fromRGB(72, 104, 78))
	local cancel = button(bar, 260, "ยกเลิก (Esc)", Color3.fromRGB(110, 50, 50))
	rotate.MouseButton1Click:Connect(function() if self.OnRotate then self.OnRotate() end end)
	place.MouseButton1Click:Connect(function() if self.OnPlace then self.OnPlace() end end)
	cancel.MouseButton1Click:Connect(function() if self.OnCancel then self.OnCancel() end end)

	self.gui, self.title, self.status = gui, title, status
	return self
end

function IslandBuildGui:Show(titleText)
	self.title.Text = titleText or ""
	self.status.Text = ""
	self.gui.Enabled = true
end

function IslandBuildGui:Hide()
	self.gui.Enabled = false
end

function IslandBuildGui:SetStatus(text, ok)
	self.status.Text = text or ""
	self.status.TextColor3 = ok and OK_COLOR or BAD_COLOR
end

return IslandBuildGui
