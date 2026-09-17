-- TownBuyerGui: พ่อค้าประจำเมือง — รับซื้อเฉพาะของถิ่นนั้น
--
-- ตัววาดล้วน รายงานการกดออกไปทาง callback ไม่รู้จักระบบเกม
--
-- โชว์เฉพาะของในกระเป๋าที่เมืองนี้รับซื้อ — ของที่เขาไม่รับไม่ต้องขึ้นมาให้สับสน เซิร์ฟเวอร์กรองมาแล้ว
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)

local STONE = Color3.fromRGB(38, 40, 48)
local ROW = Color3.fromRGB(44, 47, 58)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)
local GREEN = Color3.fromRGB(78, 122, 64)

local TownBuyerGui = {}
TownBuyerGui.__index = TownBuyerGui

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

local function label(parent, text, size, colour, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = size or 13
	l.TextColor3 = colour or TEXT_LIGHT
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

local function pill(parent, text, colour, width, rightOffset, onClick)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, rightOffset, 0.5, 0)
	b.Size = UDim2.fromOffset(width, 28)
	b.BackgroundColor3 = colour
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = TEXT_LIGHT
	b.Text = text
	b.Parent = parent
	corner(b, UDim.new(0, 6))
	b.Activated:Connect(function()
		UiSound.Play("Click")
		onClick()
	end)
	return b
end

function TownBuyerGui.new()
	local self = setmetatable({}, TownBuyerGui)
	self.callbacks = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "TownBuyerGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	-- ฉากหลังก่อน panel เสมอ (ZIndexBehavior แบบ Sibling ตัดสินการรับคลิกจากลำดับลูก)
	local backdrop = Instance.new("TextButton")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.Parent = gui
	backdrop.Activated:Connect(function() self:Hide() end)

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = Responsive.IsSmallScreen() and UDim2.fromScale(0.95, 0.8)
		or UDim2.fromOffset(560, 440)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 12))
	Responsive.Scale(panel)

	local title = label(panel, "พ่อค้าประจำเมือง", 17, RUNE)
	title.Position = UDim2.new(0, 16, 0, 10)
	title.Size = UDim2.new(1, -60, 0, 24)
	self.title = title

	local sub = label(panel, "", 11, TEXT_MUTED)
	sub.Position = UDim2.new(0, 16, 0, 34)
	sub.Size = UDim2.new(1, -60, 0, 16)
	sub.TextTruncate = Enum.TextTruncate.AtEnd
	self.sub = sub

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
	close.Parent = panel
	corner(close, UDim.new(0, 8))
	close.Activated:Connect(function()
		UiSound.Play("Click")
		self:Hide()
	end)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0, 12, 0, 56)
	list.Size = UDim2.new(1, -24, 1, -68)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = RUNE
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	self.list = list

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	return self
end

function TownBuyerGui:On(name, fn) self.callbacks[name] = fn end
function TownBuyerGui:fire(name, ...)
	local fn = self.callbacks[name]
	if fn then fn(...) end
end

function TownBuyerGui:Render(data)
	for _, c in ipairs(self.list:GetChildren()) do
		if not c:IsA("UIListLayout") then c:Destroy() end
	end

	if not data then
		self.title.Text = "พ่อค้าประจำเมือง"
		self.sub.Text = ""
		return
	end

	self.title.Text = ("พ่อค้า%s"):format(data.townName or "")

	local bits = {}
	if data.owner then
		bits[#bits + 1] = ("เมืองของแคลน %s"):format(data.owner)
		bits[#bits + 1] = ("ภาษี %d%%"):format(math.floor((data.tax or 0) * 100))
	else
		bits[#bits + 1] = "ยังไม่มีแคลนยึดเมืองนี้"
	end
	if data.isHome then
		bits[#bits + 1] = ("คนในแคลน +%d%%"):format(math.floor((data.bonus or 0) * 100))
	end
	self.sub.Text = table.concat(bits, " · ")

	if #(data.rows or {}) == 0 then
		local empty = label(self.list, "ไม่มีของที่พ่อค้าเมืองนี้รับซื้อ", 13, TEXT_MUTED,
			Enum.TextXAlignment.Center)
		empty.Size = UDim2.new(1, 0, 0, 60)
		return
	end

	for order, entry in ipairs(data.rows) do
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -6, 0, 44)
		row.BackgroundColor3 = ROW
		row.BorderSizePixel = 0
		row.Parent = self.list
		corner(row, UDim.new(0, 8))

		local hasIcon = entry.icon and entry.icon ~= ""
		if hasIcon then
			local art = Instance.new("ImageLabel")
			art.Position = UDim2.new(0, 6, 0.5, -16)
			art.Size = UDim2.fromOffset(32, 32)
			art.BackgroundTransparency = 1
			art.Image = entry.icon
			art.ScaleType = Enum.ScaleType.Fit
			art.Parent = row
		end

		-- ปุ่มสองปุ่มกินที่ 8 + 78 + 6 + 46 = 138 จากขอบขวา เผื่อไว้ 146
		local leftPad = hasIcon and 44 or 10
		local textWidth = -(leftPad + 146)

		local name = label(row, ("%s x%d"):format(entry.name, entry.count), 13, TEXT_LIGHT)
		name.Position = UDim2.new(0, leftPad, 0, 4)
		name.Size = UDim2.new(1, textWidth, 0, 18)
		name.TextTruncate = Enum.TextTruncate.AtEnd

		local price = label(row, ("%d เหรียญ/ชิ้น"):format(entry.price), 11, TEXT_MUTED)
		price.Position = UDim2.new(0, leftPad, 0, 22)
		price.Size = UDim2.new(1, textWidth, 0, 16)

		pill(row, "ขาย 1", Color3.fromRGB(70, 74, 84), 46, -92, function()
			self:fire("sell", entry.index, 1)
		end)
		pill(row, ("ทั้งหมด %d"):format(entry.price * entry.count), GREEN, 78, -8, function()
			self:fire("sell", entry.index, entry.count)
		end)
	end
end

function TownBuyerGui:Show(data)
	self:Render(data)
	self.gui.Enabled = true
end

function TownBuyerGui:Hide()
	if not self.gui.Enabled then return end
	self.gui.Enabled = false
	self:fire("close")
end

function TownBuyerGui:IsOpen() return self.gui.Enabled end

return TownBuyerGui
