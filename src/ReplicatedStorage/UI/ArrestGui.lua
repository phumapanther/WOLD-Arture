-- ArrestGui: the guard's confiscation window.
--
-- Shaped like the trade window, but one-sided. Left: the prisoner's bag and gold, which the guard picks
-- from. Right, top: the four confiscation slots. Right, bottom: the fine.
--
-- The prisoner sees the same window in read-only form -- being able to watch what is being taken is the
-- only power they have while held.
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)
local ItemIcon = require(script.Parent.ItemIcon)
local ClassActionConfig = require(script.Parent.Parent.ClassActionConfig)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local GUARD_BLUE = Color3.fromRGB(0, 120, 255)
local RUNE = Color3.fromRGB(244, 197, 66)
local DANGER = Color3.fromRGB(214, 84, 74)

local ArrestGui = {}
ArrestGui.__index = ArrestGui

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

local function label(parent, text, size, color, y, height)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -8, 0, height or 20)
	l.Position = UDim2.new(0, 4, 0, y or 0)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = size or 12
	l.TextColor3 = color or TEXT_LIGHT
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

local function makeGrid(parent)
	local frame = Instance.new("ScrollingFrame")
	frame.BackgroundColor3 = STONE_DEEP
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 4
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.Parent = parent
	corner(frame, UDim.new(0, 8))
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(52, 52)
	grid.CellPadding = UDim2.fromOffset(4, 4)
	grid.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.Parent = frame
	return frame
end

local function tile(parent, entry, onClick)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Color3.fromRGB(44, 46, 56)
	b.BorderSizePixel = 0
	b.Text = ""
	b.AutoButtonColor = onClick ~= nil
	b.Parent = parent
	corner(b, UDim.new(0, 6))

	-- มีรูป = รูป · ไม่มีรูป = ⌛ (ItemIcon) แล้วชื่อลงไปอยู่ครึ่งล่าง จะได้อ่านออกว่าเป็นของชิ้นไหน
	do
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(1, -6, 1, -6)
		icon.Position = UDim2.new(0, 3, 0, 3)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		ItemIcon.Apply(icon, entry.icon)
		icon.Parent = b
	end
	if not ItemIcon.Has(entry.icon) then
		local name = Instance.new("TextLabel")
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.new(0.5, 0, 1, -2)
		name.Size = UDim2.new(1, -4, 0.42, 0)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamMedium
		name.TextSize = 9
		name.TextWrapped = true
		name.TextColor3 = TEXT_LIGHT
		name.Text = entry.name or entry.id
		name.Parent = b
	end

	if (entry.count or 1) > 1 then
		local count = Instance.new("TextLabel")
		count.AnchorPoint = Vector2.new(1, 1)
		count.Position = UDim2.new(1, -3, 1, -1)
		count.Size = UDim2.fromOffset(24, 12)
		count.BackgroundTransparency = 1
		count.Font = Enum.Font.GothamBold
		count.TextSize = 11
		count.TextColor3 = RUNE
		count.Text = tostring(entry.count)
		count.Parent = b
	end

	if onClick then
		b.Activated:Connect(function()
			UiSound.Play("Click")
			onClick()
		end)
	end
	return b
end

--------------------------------------------------------------------------------

function ArrestGui.new()
	local self = setmetatable({}, ArrestGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "ArrestGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 21
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = Responsive.IsSmallScreen() and UDim2.fromScale(0.96, 0.86)
		or UDim2.fromOffset(680, 440)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	local s = Instance.new("UIStroke")
	s.Color = GUARD_BLUE
	s.Transparency = 0.45
	s.Thickness = 2
	s.Parent = panel
	Responsive.Scale(panel, Responsive.IsSmallScreen() and 0.95 or nil) -- มือถือ: แผงเต็มจออยู่แล้ว ห้ามย่อซ้ำ (QA 2026-09-26)
	self.panel = panel

	local title = label(panel, "จับกุม", 18, GUARD_BLUE, 12, 28)
	title.Position = UDim2.new(0, 14, 0, 12)
	self.title = title

	-- Left: everything the prisoner has.
	local left = Instance.new("Frame")
	left.Position = UDim2.new(0, 12, 0, 46)
	-- -150 ไม่ใช่ -104: เผื่อที่ให้แถวปุ่มคุมขังอีกแถว (38 สูง + 8 ช่องไฟ)
	-- ถ้าไม่ขยับ ปุ่มแถวใหม่จะทับตะแกรงของ ซึ่งเป็นบั๊กแบบเดียวกับที่แท็บคราฟเคยเจอตอนเพิ่มแท็บที่ 5
	left.Size = UDim2.new(0.5, -18, 1, -150)
	left.BackgroundTransparency = 1
	left.Parent = panel

	self.bagLabel = label(left, "กระเป๋าผู้ถูกจับ", 12, TEXT_MUTED, 0)
	self.bagGrid = makeGrid(left)
	self.bagGrid.Position = UDim2.new(0, 4, 0, 22)
	self.bagGrid.Size = UDim2.new(1, -8, 1, -50)
	self.theirGold = label(left, "เงิน: 0", 13, RUNE, 0)
	self.theirGold.AnchorPoint = Vector2.new(0, 1)
	self.theirGold.Position = UDim2.new(0, 4, 1, -4)

	-- Right: what is being taken, and the fine.
	local right = Instance.new("Frame")
	right.Position = UDim2.new(0.5, 6, 0, 46)
	right.Size = UDim2.new(0.5, -18, 1, -150)
	right.BackgroundTransparency = 1
	right.Parent = panel

	label(right, ("ยึดของ (สูงสุด %d ช่อง)"):format(ClassActionConfig.Arrest.confiscateSlots),
		12, DANGER, 0)
	self.takeGrid = makeGrid(right)
	self.takeGrid.Position = UDim2.new(0, 4, 0, 22)
	self.takeGrid.Size = UDim2.new(1, -8, 0.55, -34)

	self.fineLabel = label(right, "ค่าปรับ", 12, DANGER, 0)
	self.fineLabel.Position = UDim2.new(0, 4, 0.55, 0)

	local fineBox = Instance.new("TextBox")
	fineBox.Position = UDim2.new(0, 4, 0.55, 22)
	fineBox.Size = UDim2.new(1, -8, 0, 34)
	fineBox.BackgroundColor3 = STONE_DEEP
	fineBox.BorderSizePixel = 0
	fineBox.Font = Enum.Font.GothamBold
	fineBox.TextSize = 15
	fineBox.TextColor3 = TEXT_LIGHT
	fineBox.PlaceholderText = "จำนวนเงินค่าปรับ"
	fineBox.PlaceholderColor3 = TEXT_MUTED
	fineBox.Text = ""
	fineBox.ClearTextOnFocus = false
	fineBox.Parent = right
	corner(fineBox, UDim.new(0, 6))
	self.fineBox = fineBox

	self.summary = label(right, "", 12, TEXT_MUTED, 0)
	self.summary.AnchorPoint = Vector2.new(0, 1)
	self.summary.Position = UDim2.new(0, 4, 1, -2)
	self.summary.TextWrapped = true
	self.summary.Size = UDim2.new(1, -8, 0, 34)

	local confirm = Instance.new("TextButton")
	confirm.AnchorPoint = Vector2.new(0, 1)
	-- ยกขึ้นเหนือแถวคุมขัง
	confirm.Position = UDim2.new(0, 12, 1, -58)
	confirm.Size = UDim2.new(0.5, -18, 0, 38)
	confirm.BackgroundColor3 = Color3.fromRGB(58, 78, 56)
	confirm.BorderSizePixel = 0
	confirm.Font = Enum.Font.GothamBold
	confirm.TextSize = 14
	confirm.TextColor3 = TEXT_LIGHT
	confirm.Text = "ยืนยัน"
	confirm.Parent = panel
	corner(confirm, UDim.new(0, 8))
	self.confirmButton = confirm

	local release = Instance.new("TextButton")
	release.AnchorPoint = Vector2.new(1, 1)
	release.Position = UDim2.new(1, -12, 1, -58)
	release.Size = UDim2.new(0.5, -18, 0, 38)
	release.BackgroundColor3 = Color3.fromRGB(70, 74, 84)
	release.BorderSizePixel = 0
	release.Font = Enum.Font.GothamBold
	release.TextSize = 14
	release.TextColor3 = TEXT_LIGHT
	release.Text = "ปล่อยตัว"
	release.Parent = panel
	corner(release, UDim.new(0, 8))
	self.releaseButton = release

	-- แถวคุมขัง: ปุ่มหนึ่งปุ่มต่อหนึ่งระยะเวลา
	--
	-- **ปุ่มแยกตามเวลา ไม่ใช่ปุ่มเดียวกับช่องเลือกเวลา** การคุมขังเป็นการกระทำที่ย้อนไม่ได้ ถ้าเวลาเป็นค่า
	-- ที่ตั้งค้างไว้ในเมนู ทหารยามจะกด "คุมขัง" โดยไม่ทันดูว่าค่าที่ค้างอยู่คือ 30 นาที — ปุ่มที่เขียนเวลา
	-- อยู่บนตัวมันเองทำให้ไม่มีทางกดผิดโดยไม่รู้ตัว
	local terms = ClassActionConfig.Arrest.jailTerms
	self.jailButtons = {}
	local count = #terms
	for i, term in ipairs(terms) do
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(0, 1)
		-- แบ่งความกว้างเท่าๆ กัน หักขอบซ้ายขวา 12px และช่องไฟ 6px ระหว่างปุ่ม **แล้วหารด้วยจำนวนปุ่ม**
		--
		-- ที่ต้องหาร: ที่ที่หายไปทั้งหมด (ขอบ 2 ข้าง + ช่องไฟ n-1 ช่อง) ถูกแบ่งกันรับโดยปุ่มทุกตัว ถ้าหัก
		-- เต็มจำนวนจากปุ่มแต่ละตัว ปุ่มจะแคบเกินไป ถ้าหักน้อยไปปุ่มสุดท้ายจะล้นออกนอกขอบขวา — วัดแล้วว่า
		-- สูตรเดิม (หัก 18 ทุกตัว) ทำให้ปุ่มที่ 3 จบที่ 680 พอดีขอบ panel ไม่เหลือระยะขอบเลย
		local shrink = (12 * 2 + 6 * (count - 1)) / count
		b.Size = UDim2.new(1 / count, -shrink, 0, 38)
		-- ตำแหน่งไล่ทีละปุ่มจากซ้าย ไม่ใช่คำนวณจากสัดส่วน: ความกว้างจริงของปุ่มมีทั้งส่วน scale และ offset
		-- การบวกไปทีละตัวจึงเป็นวิธีเดียวที่ช่องไฟระหว่างปุ่มเท่ากันจริงทุกช่อง
		b.Position = UDim2.new((i - 1) / count, 12 + (i - 1) * (6 - shrink), 1, -12)
		b.BackgroundColor3 = Color3.fromRGB(96, 62, 58)
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 13
		b.TextColor3 = TEXT_LIGHT
		b.Text = "⛓ คุมขัง " .. term.label
		b.Parent = panel
		corner(b, UDim.new(0, 8))
		self.jailButtons[i] = { button = b, term = term }
	end

	self.taking = {}
	self.fine = 0
	self.callbacks = {}
	self.isGuard = false
	return self
end

function ArrestGui:On(name, fn)
	self.callbacks[name] = fn
end

local function fire(self, name, ...)
	local fn = self.callbacks[name]
	if fn then fn(...) end
end

-- `asGuard` decides whether this is a control panel or a window onto what is being done to you.
function ArrestGui:Open(other, asGuard)
	self.isGuard = asGuard
	self.taking = {}
	self.fine = 0
	self.fineBox.Text = ""
	self.title.Text = asGuard and ("จับกุม %s"):format(other and other.DisplayName or "")
		or ("คุณถูกจับกุมโดย %s"):format(other and other.DisplayName or "")
	self.bagLabel.Text = asGuard and "กระเป๋าผู้ถูกจับ" or "กระเป๋าของคุณ"

	-- A prisoner can look but not touch: the buttons and the box are the guard's alone.
	self.fineBox.TextEditable = asGuard
	self.confirmButton.Visible = asGuard
	self.releaseButton.Visible = asGuard
	for _, entry in ipairs(self.jailButtons) do
		entry.button.Visible = asGuard
	end
	self.summary.Text = asGuard and "" or "ขยับไม่ได้จนกว่าจะถูกปล่อยตัว"

	self.gui.Enabled = true

	if self.connections then
		for _, c in ipairs(self.connections) do c:Disconnect() end
	end
	self.connections = {}
	if not asGuard then return end

	table.insert(self.connections, self.confirmButton.Activated:Connect(function()
		UiSound.Play("Click")
		fire(self, "confirm")
	end))
	table.insert(self.connections, self.releaseButton.Activated:Connect(function()
		UiSound.Play("Click")
		fire(self, "release")
	end))
	for _, entry in ipairs(self.jailButtons) do
		table.insert(self.connections, entry.button.Activated:Connect(function()
			UiSound.Play("Click")
			-- ส่งแค่ id ของระยะเวลา ไม่ใช่จำนวนวินาที เซิร์ฟเวอร์เปิดตารางเอง
			fire(self, "jail", entry.term.id)
		end))
	end
	table.insert(self.connections, self.fineBox.FocusLost:Connect(function()
		self.fine = math.max(0, math.floor(tonumber(self.fineBox.Text) or 0))
		fire(self, "take", self.taking, self.fine)
	end))
end

function ArrestGui:Close()
	self.gui.Enabled = false
	if self.connections then
		for _, c in ipairs(self.connections) do c:Disconnect() end
		self.connections = nil
	end
end

function ArrestGui:IsOpen()
	return self.gui.Enabled
end

-- Drawn from the server's picture, never inferred. If the server says a slot is not being taken, it is not
-- drawn as taken, whatever this client just clicked.
function ArrestGui:Render(payload)
	local taking = {}
	for _, index in ipairs((payload and payload.taking) or {}) do taking[index] = true end
	self.taking = (payload and payload.taking) or {}
	self.fine = (payload and payload.fine) or 0

	for _, child in ipairs(self.bagGrid:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	for _, child in ipairs(self.takeGrid:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	local bySlot = {}
	for _, entry in ipairs((payload and payload.bag) or {}) do
		bySlot[entry.slot] = entry
		local b = tile(self.bagGrid, entry, self.isGuard and function()
			local list = {}
			local found = false
			for _, index in ipairs(self.taking) do
				if index == entry.slot then found = true else table.insert(list, index) end
			end
			if not found then table.insert(list, entry.slot) end
			fire(self, "take", list, self.fine)
		end or nil)
		b.BackgroundTransparency = taking[entry.slot] and 0.6 or 0
	end

	for _, index in ipairs(self.taking) do
		local entry = bySlot[index]
		if entry then tile(self.takeGrid, entry, nil) end
	end

	self.theirGold.Text = ("เงิน: %d"):format((payload and payload.gold) or 0)
	if not self.fineBox:IsFocused() then
		self.fineBox.Text = self.fine > 0 and tostring(self.fine) or ""
	end
	if self.isGuard then
		self.summary.Text = ("ยึด %d ชิ้น • ปรับ %d ทอง"):format(#self.taking, self.fine)
	end
end

return ArrestGui
