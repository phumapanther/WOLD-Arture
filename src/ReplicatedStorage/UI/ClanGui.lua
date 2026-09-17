-- ClanGui: หน้าต่างสมาคมแคลน — รายการแคลน อันดับ และแคลนของฉัน
--
-- ตัววาดล้วน รายงานการกดออกไปทาง callback ไม่รู้จักระบบเกม
--
-- สองแท็บ ไม่ใช่สองหน้าจอแยก: คนที่ยังไม่มีแคลนจะสลับไปมาระหว่าง "ดูว่ามีแคลนอะไรบ้าง" กับ "สร้างเอง"
-- บ่อยมาก การต้องกดย้อนกลับทุกครั้งจะน่ารำคาญเร็ว
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)
local ClanConfig = require(script.Parent.Parent.ClanConfig)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local ROW = Color3.fromRGB(44, 47, 58)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)
local GREEN = Color3.fromRGB(78, 122, 64)

local ClanGui = {}
ClanGui.__index = ClanGui

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

local function button(parent, text, colour, onClick)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = colour
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = TEXT_LIGHT
	b.Text = text
	b.Parent = parent
	corner(b, UDim.new(0, 6))
	if onClick then
		b.Activated:Connect(function()
			UiSound.Play("Click")
			onClick()
		end)
	end
	return b
end

local function scrollList(parent)
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 5
	s.ScrollBarImageColor3 = RUNE
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = s
	return s
end

local function clear(list)
	for _, c in ipairs(list:GetChildren()) do
		if not c:IsA("UIListLayout") then c:Destroy() end
	end
end

function ClanGui.new()
	local self = setmetatable({}, ClanGui)
	self.callbacks = {}
	self.tab = "mine"

	local gui = Instance.new("ScreenGui")
	gui.Name = "ClanGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	-- ฉากหลังก่อน panel เสมอ (ZIndexBehavior แบบ Sibling ตัดสินการรับคลิกจากลำดับลูกด้วย)
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
	panel.Size = Responsive.IsSmallScreen() and UDim2.fromScale(0.96, 0.85)
		or UDim2.fromOffset(660, 460)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 12))
	Responsive.Scale(panel)

	local title = label(panel, "สมาคมแคลน", 18, RUNE)
	title.Position = UDim2.new(0, 16, 0, 10)
	title.Size = UDim2.new(1, -60, 0, 26)

	local close = button(panel, "\195\151", Color3.fromRGB(96, 62, 62), function() self:Hide() end)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(30, 30)
	close.TextSize = 15

	-- แท็บ
	local tabs = Instance.new("Frame")
	tabs.Position = UDim2.new(0, 12, 0, 44)
	tabs.Size = UDim2.new(1, -24, 0, 28)
	tabs.BackgroundTransparency = 1
	tabs.Parent = panel

	self.tabButtons = {}
	local specs = { { id = "mine", name = "แคลนของฉัน" }, { id = "list", name = "แคลนทั้งหมด" } }
	for i, spec in ipairs(specs) do
		local b = button(tabs, spec.name, STONE_DEEP, function()
			self.tab = spec.id
			self:Render(self.data)
		end)
		b.Position = UDim2.new((i - 1) / 2, i > 1 and 4 or 0, 0, 0)
		b.Size = UDim2.new(0.5, -4, 1, 0)
		b.TextSize = 13
		self.tabButtons[spec.id] = b
	end

	local body = Instance.new("Frame")
	body.Position = UDim2.new(0, 12, 0, 78)
	body.Size = UDim2.new(1, -24, 1, -90)
	body.BackgroundTransparency = 1
	body.Parent = panel
	self.body = body

	return self
end

function ClanGui:On(name, fn) self.callbacks[name] = fn end
function ClanGui:fire(name, ...)
	local fn = self.callbacks[name]
	if fn then fn(...) end
end

--------------------------------------------------------------------------------
-- กล่องกรอกข้อความ
--------------------------------------------------------------------------------

function ClanGui:prompt(titleText, placeholder, onConfirm)
	local shade = Instance.new("TextButton")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.4
	shade.BorderSizePixel = 0
	shade.Text = ""
	shade.ZIndex = 10
	shade.Parent = self.gui

	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(320, 150)
	box.BackgroundColor3 = STONE
	box.BorderSizePixel = 0
	box.ZIndex = 11
	box.Parent = shade
	corner(box, UDim.new(0, 10))

	local head = label(box, titleText, 14, RUNE, Enum.TextXAlignment.Center)
	head.Position = UDim2.new(0, 10, 0, 10)
	head.Size = UDim2.new(1, -20, 0, 22)
	head.ZIndex = 11

	local input = Instance.new("TextBox")
	input.Position = UDim2.new(0, 14, 0, 44)
	input.Size = UDim2.new(1, -28, 0, 34)
	input.BackgroundColor3 = STONE_DEEP
	input.BorderSizePixel = 0
	input.Font = Enum.Font.Gotham
	input.TextSize = 13
	input.TextColor3 = TEXT_LIGHT
	input.PlaceholderText = placeholder or ""
	input.Text = ""
	input.ClearTextOnFocus = false
	input.ZIndex = 11
	input.Parent = box
	corner(input, UDim.new(0, 6))

	local ok = button(box, "ตกลง", GREEN, function()
		local value = input.Text
		shade:Destroy()
		onConfirm(value)
	end)
	ok.Position = UDim2.new(0, 14, 1, -46)
	ok.Size = UDim2.new(0.5, -18, 0, 34)
	ok.ZIndex = 11

	local cancel = button(box, "ยกเลิก", Color3.fromRGB(70, 74, 84), function()
		shade:Destroy()
	end)
	cancel.AnchorPoint = Vector2.new(1, 0)
	cancel.Position = UDim2.new(1, -14, 1, -46)
	cancel.Size = UDim2.new(0.5, -18, 0, 34)
	cancel.ZIndex = 11

	shade.Activated:Connect(function() shade:Destroy() end)
end

--------------------------------------------------------------------------------
-- วาด
--------------------------------------------------------------------------------

function ClanGui:Render(data)
	self.data = data
	for _, c in ipairs(self.body:GetChildren()) do c:Destroy() end

	for id, b in pairs(self.tabButtons) do
		b.BackgroundTransparency = (id == self.tab) and 0 or 0.45
		b.TextColor3 = (id == self.tab) and RUNE or TEXT_MUTED
	end

	if not data then
		local wait = label(self.body, "กำลังติดต่อสมาคม...", 13, TEXT_MUTED, Enum.TextXAlignment.Center)
		wait.Size = UDim2.new(1, 0, 0, 60)
		return
	end

	if self.tab == "list" then
		self:renderList(data)
	else
		self:renderMine(data)
	end
end

function ClanGui:renderList(data)
	local hint = label(self.body, "อันดับจากยอดเหรียญซิลเวอร์ในคลังแคลน", 11, TEXT_MUTED)
	hint.Size = UDim2.new(1, 0, 0, 16)

	local list = scrollList(self.body)
	list.Position = UDim2.new(0, 0, 0, 20)
	list.Size = UDim2.new(1, 0, 1, -20)

	if #(data.list or {}) == 0 then
		local empty = label(list, "ยังไม่มีแคลนในโลกนี้", 13, TEXT_MUTED, Enum.TextXAlignment.Center)
		empty.Size = UDim2.new(1, 0, 0, 60)
		return
	end

	for order, clan in ipairs(data.list) do
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -6, 0, 52)
		row.BackgroundColor3 = ROW
		row.BorderSizePixel = 0
		row.Parent = list
		corner(row, UDim.new(0, 8))

		local rank = label(row, tostring(order), 15, order <= 3 and RUNE or TEXT_MUTED,
			Enum.TextXAlignment.Center)
		rank.Position = UDim2.new(0, 4, 0, 0)
		rank.Size = UDim2.new(0, 30, 1, 0)

		local name = label(row, clan.name, 14, TEXT_LIGHT)
		name.Position = UDim2.new(0, 40, 0, 6)
		name.Size = UDim2.new(1, -170, 0, 20)

		local sub = label(row, ("%d ซิลเวอร์ · %d คน · ยึด %d เมือง")
			:format(clan.silver or 0, clan.members or 0, clan.towns or 0), 11, TEXT_MUTED)
		sub.Position = UDim2.new(0, 40, 0, 26)
		sub.Size = UDim2.new(1, -170, 0, 18)

		-- สมัครเข้าได้เฉพาะคนที่ยังไม่มีแคลน
		if not data.mine then
			local join = button(row, "สมัครเข้า", RUNE, function()
				self:fire("join", clan.id)
			end)
			join.AnchorPoint = Vector2.new(1, 0.5)
			join.Position = UDim2.new(1, -8, 0.5, 0)
			join.Size = UDim2.fromOffset(76, 30)
			join.TextColor3 = Color3.fromRGB(38, 28, 16)
		end
	end
end

function ClanGui:renderMine(data)
	if not data.mine then
		-- ยังไม่มีแคลน
		local msg = label(self.body, "คุณยังไม่ได้สังกัดแคลนใด", 14, TEXT_LIGHT, Enum.TextXAlignment.Center)
		msg.Position = UDim2.new(0, 0, 0, 40)
		msg.Size = UDim2.new(1, 0, 0, 24)

		local cost = label(self.body, ("สร้างแคลนของตัวเอง ใช้เหรียญซิลเวอร์ %d เหรียญ (มี %d)")
			:format(data.createCost or 0, data.silverHeld or 0), 12, TEXT_MUTED, Enum.TextXAlignment.Center)
		cost.Position = UDim2.new(0, 0, 0, 68)
		cost.Size = UDim2.new(1, 0, 0, 20)

		local make = button(self.body, "สร้างแคลน", RUNE, function()
			self:prompt("ตั้งชื่อแคลน", "ชื่อแคลน", function(name)
				if name == "" then return end
				self:prompt("รายละเอียดแคลน", "คำอธิบายสั้นๆ", function(blurb)
					self:fire("create", name, blurb)
				end)
			end)
		end)
		make.AnchorPoint = Vector2.new(0.5, 0)
		make.Position = UDim2.new(0.5, 0, 0, 100)
		make.Size = UDim2.fromOffset(180, 38)
		make.TextSize = 14
		make.TextColor3 = Color3.fromRGB(38, 28, 16)

		local note = label(self.body, "หรือไปที่แท็บ 'แคลนทั้งหมด' เพื่อสมัครเข้าแคลนที่มีอยู่",
			11, TEXT_MUTED, Enum.TextXAlignment.Center)
		note.Position = UDim2.new(0, 0, 0, 148)
		note.Size = UDim2.new(1, 0, 0, 18)
		return
	end

	local clan = data.mine

	-- หัวเรื่อง: รูปแคลน ชื่อ เมืองที่ยึด
	local head = Instance.new("Frame")
	head.Size = UDim2.new(1, 0, 0, 68)
	head.BackgroundColor3 = STONE_DEEP
	head.BorderSizePixel = 0
	head.Parent = self.body
	corner(head, UDim.new(0, 8))

	-- รูปแคลน: วางโครงไว้ก่อน ยังไม่มีระบบอัปโหลด
	local crest = Instance.new("ImageLabel")
	crest.Position = UDim2.new(0, 8, 0, 8)
	crest.Size = UDim2.fromOffset(52, 52)
	crest.BackgroundColor3 = ROW
	crest.BorderSizePixel = 0
	crest.Image = clan.image or ""
	crest.ScaleType = Enum.ScaleType.Fit
	crest.Parent = head
	corner(crest, UDim.new(0, 6))
	if not clan.image or clan.image == "" then
		local initial = label(crest, clan.name:sub(1, 1), 22, TEXT_MUTED, Enum.TextXAlignment.Center)
		initial.Size = UDim2.fromScale(1, 1)
	end

	local name = label(head, clan.name, 16, RUNE)
	name.Position = UDim2.new(0, 68, 0, 8)
	name.Size = UDim2.new(1, -80, 0, 22)

	local towns = (#clan.towns > 0) and ("ยึดเมือง: " .. table.concat(clan.towns, ", "))
		or "ยังไม่ได้ยึดเมืองใด"
	local townLabel = label(head, towns, 11, TEXT_MUTED)
	townLabel.Position = UDim2.new(0, 68, 0, 30)
	townLabel.Size = UDim2.new(1, -80, 0, 16)

	local blurb = label(head, clan.blurb ~= "" and clan.blurb or "ไม่มีรายละเอียด", 11, TEXT_MUTED)
	blurb.Position = UDim2.new(0, 68, 0, 46)
	blurb.Size = UDim2.new(1, -80, 0, 16)
	blurb.TextTruncate = Enum.TextTruncate.AtEnd

	-- เงินแคลน + ปุ่ม
	local money = Instance.new("Frame")
	money.Position = UDim2.new(0, 0, 0, 74)
	money.Size = UDim2.new(1, 0, 0, 40)
	money.BackgroundColor3 = STONE_DEEP
	money.BorderSizePixel = 0
	money.Parent = self.body
	corner(money, UDim.new(0, 8))

	local silver = label(money, ("คลังแคลน: %d ซิลเวอร์"):format(clan.silver or 0), 14, RUNE)
	silver.Position = UDim2.new(0, 12, 0, 0)
	silver.Size = UDim2.new(0.4, 0, 1, 0)

	local donate = button(money, "บริจาค", GREEN, function()
		self:prompt("บริจาคเหรียญซิลเวอร์", ("มีอยู่ %d"):format(data.silverHeld or 0), function(text)
			local n = tonumber(text)
			if n and n > 0 then self:fire("donate", math.floor(n)) end
		end)
	end)
	donate.AnchorPoint = Vector2.new(1, 0.5)
	donate.Position = UDim2.new(1, -8, 0.5, 0)
	donate.Size = UDim2.fromOffset(76, 28)

	local isLeader = clan.myRole == "leader"
	if isLeader then
		local give = button(money, "แจกจ่าย", Color3.fromRGB(70, 90, 120), function()
			self:prompt("แจกให้ทุกคนคนละกี่ซิลเวอร์", "จำนวนรวม", function(text)
				local n = tonumber(text)
				if n and n > 0 then self:fire("distribute", math.floor(n), nil) end
			end)
		end)
		give.AnchorPoint = Vector2.new(1, 0.5)
		give.Position = UDim2.new(1, -92, 0.5, 0)
		give.Size = UDim2.fromOffset(76, 28)
	end

	-- สมาชิก
	local list = scrollList(self.body)
	list.Position = UDim2.new(0, 0, 0, 122)
	list.Size = UDim2.new(1, 0, 1, -160)

	for order, member in ipairs(clan.members or {}) do
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -6, 0, 34)
		row.BackgroundColor3 = ROW
		row.BorderSizePixel = 0
		row.Parent = list
		corner(row, UDim.new(0, 6))

		local who = label(row, member.name, 13, member.online and TEXT_LIGHT or TEXT_MUTED)
		who.Position = UDim2.new(0, 10, 0, 0)
		who.Size = UDim2.new(1, -200, 1, 0)

		local role = label(row, member.roleName, 11,
			member.rank == 1 and RUNE or TEXT_MUTED, Enum.TextXAlignment.Right)
		role.AnchorPoint = Vector2.new(1, 0)
		role.Position = UDim2.new(1, isLeader and -84 or -10, 0, 0)
		role.Size = UDim2.new(0, 70, 1, 0)

		-- หัวแคลนแจกให้รายคนได้
		if isLeader and member.rank ~= 1 then
			local one = button(row, "ให้", Color3.fromRGB(70, 90, 120), function()
				self:prompt(("ให้ %s กี่ซิลเวอร์"):format(member.name), "จำนวน", function(text)
					local n = tonumber(text)
					if n and n > 0 then self:fire("distribute", math.floor(n), member.userId) end
				end)
			end)
			one.AnchorPoint = Vector2.new(1, 0.5)
			one.Position = UDim2.new(1, -8, 0.5, 0)
			one.Size = UDim2.fromOffset(46, 24)
		end
	end

	-- แถวล่าง: คลังแคลน + ออกจากแคลน
	local vault = button(self.body, ("เปิดคลังแคลน (%d/%d)")
		:format(#(clan.vault or {}), clan.vaultSlots or ClanConfig.VaultSlots),
		Color3.fromRGB(84, 70, 48), function()
			self:fire("openvault")
		end)
	vault.AnchorPoint = Vector2.new(0, 1)
	vault.Position = UDim2.new(0, 0, 1, 0)
	vault.Size = UDim2.new(0.6, -4, 0, 32)
	vault.TextSize = 13

	local out = button(self.body, "ออกจากแคลน", Color3.fromRGB(96, 62, 62), function()
		self:fire("leave")
	end)
	out.AnchorPoint = Vector2.new(1, 1)
	out.Position = UDim2.new(1, 0, 1, 0)
	out.Size = UDim2.new(0.4, -4, 0, 32)
	out.TextSize = 13
end

function ClanGui:Show(data)
	self:Render(data)
	self.gui.Enabled = true
end

function ClanGui:Hide()
	if not self.gui.Enabled then return end
	self.gui.Enabled = false
end

function ClanGui:IsOpen() return self.gui.Enabled end

return ClanGui
