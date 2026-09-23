-- ArenaScoreboardGui: ตารางอันดับตอนจบแมตช์ — วาดตามภาพม็อกอัพที่ผู้ใช้ส่งมา 2026-09-23
--
--   จบเกมส์            ตารางอันดับ                         [กลับสู่ lobby]
--   อันดับ ชื่อ k/d/a damage money            รางวัล   เงินรางวัล
--   ───────────────────── ทีมชนะ (แถบเขียว) ─────────────────────
--   ───────────────────── ทีมแพ้ (แถบแดง) ──────────────────────
--
-- ⚠️ ช่อง "เงินรางวัล" คือ **เงินในเกมหลัก** ที่ได้ติดตัวกลับไป ไม่ใช่ซิลเวอร์ของแมตช์ (ซึ่งหายไป
-- พร้อมเซิร์ฟ) — สองอย่างนี้ใช้ไอคอนคล้ายกันและอยู่หน้าจอเดียวกัน จึงต้องเขียนหัวคอลัมน์ให้ต่างกันชัด
local ItemCatalog = require(script.Parent.Parent.ItemCatalog)

local ArenaScoreboardGui = {}
ArenaScoreboardGui.__index = ArenaScoreboardGui

local PANEL = Color3.fromRGB(150, 150, 150)
local WIN_HEAD = Color3.fromRGB(58, 196, 108)
local WIN_ROW = Color3.fromRGB(122, 190, 148)
local LOSE_HEAD = Color3.fromRGB(226, 62, 54)
local LOSE_ROW = Color3.fromRGB(202, 132, 128)
local TEXT_DARK = Color3.fromRGB(26, 26, 30)
local ACCENT = Color3.fromRGB(226, 184, 78)

local COLUMNS = {
	{ key = "rank",   title = "อันดับ", x = 14,  w = 56,  align = Enum.TextXAlignment.Center },
	{ key = "name",   title = "ชื่อ",    x = 74,  w = 190, align = Enum.TextXAlignment.Left },
	{ key = "kda",    title = "k/d/a",  x = 268, w = 90,  align = Enum.TextXAlignment.Center },
	{ key = "damage", title = "damage", x = 362, w = 90,  align = Enum.TextXAlignment.Center },
	{ key = "score",  title = "คะแนน",  x = 456, w = 90,  align = Enum.TextXAlignment.Center },
	{ key = "chest",  title = "รางวัล",  x = 556, w = 140, align = Enum.TextXAlignment.Right },
	{ key = "gold",   title = "เงินรางวัล", x = 702, w = 90, align = Enum.TextXAlignment.Right },
}

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 6)
	c.Parent = parent
	return c
end

local function cell(parent, column, text, size, bold)
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(column.x, 0)
	label.Size = UDim2.new(0, column.w, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
	label.TextSize = size or 18
	label.TextColor3 = TEXT_DARK
	label.TextXAlignment = column.align
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = text
	label.Parent = parent
	return label
end

function ArenaScoreboardGui.new()
	local self = setmetatable({}, ArenaScoreboardGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "ArenaScoreboardGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 22 -- เหนือทุกอย่าง: มันคือหน้าสุดท้ายของแมตช์
	gui.Enabled = false
	self.gui = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.46)
	panel.Size = UDim2.fromOffset(820, 470)
	panel.BackgroundColor3 = PANEL
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	self.panel = panel

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.fromOffset(220, 44)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 30
	title.TextColor3 = TEXT_DARK
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "จบเกม"
	title.Parent = panel

	local subtitle = Instance.new("TextLabel")
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.new(0.5, 0, 0, 14)
	subtitle.Size = UDim2.fromOffset(300, 44)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamBold
	subtitle.TextSize = 28
	subtitle.TextColor3 = TEXT_DARK
	subtitle.Text = "ตารางอันดับ"
	subtitle.Parent = panel

	local back = Instance.new("TextButton")
	back.AnchorPoint = Vector2.new(1, 0)
	back.Position = UDim2.new(1, -18, 0, 18)
	back.Size = UDim2.fromOffset(150, 40)
	back.BackgroundColor3 = ACCENT
	back.BorderSizePixel = 0
	back.Font = Enum.Font.SourceSansBold
	back.TextSize = 19
	back.TextColor3 = TEXT_DARK
	back.Text = "กลับสู่ล็อบบี้"
	back.Parent = panel
	corner(back, UDim.new(1, 0))
	self.backButton = back

	-- หัวคอลัมน์
	local header = Instance.new("Frame")
	header.Position = UDim2.fromOffset(20, 70)
	header.Size = UDim2.fromOffset(796, 26)
	header.BackgroundTransparency = 1
	header.Parent = panel
	for _, column in ipairs(COLUMNS) do
		cell(header, column, column.title, 16, true)
	end

	local rows = Instance.new("Frame")
	rows.Position = UDim2.fromOffset(20, 100)
	rows.Size = UDim2.fromOffset(796, 300)
	rows.BackgroundTransparency = 1
	rows.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.Parent = rows
	self.rows = rows

	local note = Instance.new("TextLabel")
	note.AnchorPoint = Vector2.new(0.5, 1)
	note.Position = UDim2.new(0.5, 0, 1, -12)
	note.Size = UDim2.new(1, -40, 0, 26)
	note.BackgroundTransparency = 1
	note.Font = Enum.Font.SourceSans
	note.TextSize = 17
	note.TextColor3 = Color3.fromRGB(46, 46, 50)
	note.Text = "หีบกับเงินรางวัลจะอยู่ในกระเป๋าของคุณเมื่อกลับเข้าเกมหลัก"
	note.Parent = panel
	self.note = note

	return self
end

function ArenaScoreboardGui:OnBack(callback)
	self.backButton.MouseButton1Click:Connect(callback)
end

function ArenaScoreboardGui:SetVisible(visible)
	self.gui.Enabled = visible and true or false
end

-- `result` = { rows = {…}, winner = "A"|"B"|nil, wins = {A=,B=} }
-- แต่ละแถวมี rank, name, side, bot, kills, deaths, assists, damage, score, gold, chest, won
function ArenaScoreboardGui:Render(result)
	for _, child in ipairs(self.rows:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	-- **แบ่งเป็นสองก้อนตามทีมชนะ/แพ้เหมือนในภาพ** ไม่ใช่เรียงอันดับปนกัน — คนอ่านอยากรู้ก่อนว่า
	-- ฝั่งไหนชนะ แล้วค่อยดูว่าใครทำอะไรได้บ้าง
	local order = 0
	local function section(title, headColour, rowColour, predicate)
		local head = Instance.new("Frame")
		order += 1
		head.LayoutOrder = order
		head.Size = UDim2.new(1, 0, 0, 24)
		head.BackgroundColor3 = headColour
		head.BorderSizePixel = 0
		head.Parent = self.rows
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.SourceSansBold
		label.TextSize = 17
		label.TextColor3 = Color3.fromRGB(250, 250, 250)
		label.Text = title
		label.Parent = head

		for _, row in ipairs(result.rows or {}) do
			if predicate(row) then
				order += 1
				local frame = Instance.new("Frame")
				frame.LayoutOrder = order
				frame.Size = UDim2.new(1, 0, 0, 26)
				frame.BackgroundColor3 = rowColour
				frame.BorderSizePixel = 0
				frame.Parent = self.rows

				local chestItem = row.chest and ItemCatalog.Items[row.chest]
				local values = {
					rank = tostring(row.rank or "-"),
					name = row.name .. (row.bot and "  (บอท)" or ""),
					kda = ("%d/%d/%d"):format(row.kills or 0, row.deaths or 0, row.assists or 0),
					damage = tostring(row.damage or 0),
					score = tostring(math.floor((row.score or 0) + 0.5)),
					chest = row.bot and "—" or (chestItem and chestItem.name or row.chest or "—"),
					gold = row.bot and "—" or tostring(row.gold or 0),
				}
				for _, column in ipairs(COLUMNS) do
					cell(frame, column, values[column.key] or "", 17, column.key == "rank")
				end
			end
		end
	end

	section("ทีมชนะ", WIN_HEAD, WIN_ROW, function(row) return row.won end)
	section("ทีมแพ้", LOSE_HEAD, LOSE_ROW, function(row) return not row.won end)
end

return ArenaScoreboardGui
