-- ArenaScoreboardGui: ตารางคะแนนของสนาม PVP — ใช้สองที่: ตารางจบแมตช์ และตาราง Tab ระหว่างเล่น
-- รื้อดีไซน์ใหม่ 2026-09-24 (ผู้ใช้สั่ง "ให้ดูโมเดิร์นและทันสมัยกว่านี้") โทนเดียวกับร้าน (ArenaShopGui)
--
--   ┌ ชัยชนะ!            [ทอง 3] : [1 เหล็ก]              [กลับสู่ล็อบบี้] ┐
--   │ ปราสาทเฟืองทอง · จบแมตช์                                      │
--   │ ▌ทีมทอง · ชนะ                                                  │
--   │   #  ผู้เล่น        K   D   A   ดาเมจ  คะแนน   EXP  รางวัล  เงิน │
--   │ ▌ 1  phumapanther MVP (คุณ)   ...                              │
--   │ ▌ทีมเหล็ก · แพ้                                                 │
--   └────────────── หีบ เงิน และ EXP เข้าตัวละครเมื่อกลับเกมหลัก ────────┘
--
-- ⚠️ "เงินรางวัล" = **เงินในเกมหลัก** ไม่ใช่ซิลเวอร์ของแมตช์ (ซึ่งหายไปพร้อมเซิร์ฟ)
-- ตัววาดล้วน · ตัวคุม (ArenaController) ส่งผลจากเซิร์ฟมาให้
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local ArenaConfig = require(script.Parent.Parent.ArenaConfig)
local ItemCatalog = require(script.Parent.Parent.ItemCatalog)
local ItemIcon = require(script.Parent.ItemIcon)
local Locale = require(script.Parent.Parent.Locale)
local L, Show = Locale.L, Locale.Show

local ArenaScoreboardGui = {}
ArenaScoreboardGui.__index = ArenaScoreboardGui

local rgb = Color3.fromRGB
local BG = rgb(16, 17, 22)
local ROW = rgb(30, 32, 40)
local ROW_ME = rgb(46, 42, 30)
local STROKE = rgb(64, 68, 82)
local GOLD = rgb(232, 190, 90)
local TEXT = rgb(238, 236, 230)
local MUTED = rgb(150, 150, 160)
local RED = rgb(226, 110, 100)
local GREEN = rgb(96, 214, 140)

local PANEL_W = 960
local ROW_H = 40

-- คอลัมน์: x/w ในแถว (กว้าง PANEL_W - 64) · reward = โชว์เฉพาะตารางจบแมตช์
local COLUMNS = {
	{ key = "rank",   title = "#",        x = 16,  w = 30,  align = Enum.TextXAlignment.Center },
	{ key = "name",   title = "ผู้เล่น",    x = 56,  w = 250, align = Enum.TextXAlignment.Left }, -- locale: skip (แปลตอนใช้)
	{ key = "kills",  title = "K",        x = 314, w = 44,  align = Enum.TextXAlignment.Center },
	{ key = "deaths", title = "D",        x = 360, w = 44,  align = Enum.TextXAlignment.Center },
	{ key = "assists",title = "A",        x = 406, w = 44,  align = Enum.TextXAlignment.Center },
	{ key = "damage", title = "ดาเมจ",     x = 456, w = 80,  align = Enum.TextXAlignment.Center }, -- locale: skip (แปลตอนใช้)
	{ key = "score",  title = "คะแนน",     x = 540, w = 80,  align = Enum.TextXAlignment.Center }, -- locale: skip (แปลตอนใช้)
	{ key = "exp",    title = "EXP",      x = 628, w = 80,  align = Enum.TextXAlignment.Center, reward = true },
	{ key = "chest",  title = "รางวัล",     x = 712, w = 70,  align = Enum.TextXAlignment.Center, reward = true }, -- locale: skip (แปลตอนใช้)
	{ key = "gold",   title = "เงิน",       x = 786, w = 100, align = Enum.TextXAlignment.Right, reward = true }, -- locale: skip (แปลตอนใช้)
}

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = p
end
local function stroke(p, colour, t, thick)
	local s = Instance.new("UIStroke")
	s.Color, s.Transparency, s.Thickness = colour, t or 0, thick or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end
local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = props.font or Enum.Font.SourceSansBold
	l.TextSize = props.size or 17
	l.TextColor3 = props.colour or TEXT
	l.TextXAlignment = props.align or Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = props.text or ""
	l.Position = props.pos or UDim2.new()
	l.Size = props.dim or UDim2.fromScale(1, 1)
	l.ZIndex = props.z or 2
	l.Parent = parent
	return l
end
local function pill(parent, label, bg, fg, x, w)
	local p = Instance.new("TextLabel")
	p.AnchorPoint = Vector2.new(0, 0.5)
	p.Position = UDim2.new(0, x, 0.5, 0)
	p.Size = UDim2.fromOffset(w, 18)
	p.BackgroundColor3 = bg
	p.Font = Enum.Font.GothamBold
	p.TextSize = 11
	p.TextColor3 = fg
	p.Text = label
	p.ZIndex = 3
	p.Parent = parent
	corner(p, 9)
	return p
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

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = rgb(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.Parent = gui
	self.dim = dim

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(PANEL_W, 600)
	panel.BackgroundColor3 = BG
	panel.BackgroundTransparency = 0.04
	panel.Parent = gui
	corner(panel, 18)
	stroke(panel, GOLD, 0.7, 1.5)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(rgb(255, 255, 255), rgb(190, 190, 200))
	grad.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function rescale()
		local cam = workspace.CurrentCamera
		local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(v.X / (PANEL_W + 60), v.Y / 660), 0.5, 1)
	end
	rescale()
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end
	self.panel = panel

	-- หัว: ผลใหญ่ซ้าย · สกอร์ทีมกลาง · ปุ่มกลับขวา
	self.title = text(panel, { text = L("จบเกม"), font = Enum.Font.GothamBold, size = 34, pos = UDim2.fromOffset(32, 18), dim = UDim2.fromOffset(300, 42) })
	self.subtitle = text(panel, { text = "", size = 16, colour = MUTED, pos = UDim2.fromOffset(32, 60), dim = UDim2.fromOffset(360, 20) })

	local score = Instance.new("Frame")
	score.AnchorPoint = Vector2.new(0.5, 0)
	score.Position = UDim2.new(0.5, 0, 0, 22)
	score.Size = UDim2.fromOffset(220, 52)
	score.BackgroundTransparency = 1
	score.Parent = panel
	local function chip(side, anchorX)
		local c = Instance.new("TextLabel")
		c.AnchorPoint = Vector2.new(anchorX, 0)
		c.Position = UDim2.fromScale(anchorX, 0)
		c.Size = UDim2.fromOffset(92, 52)
		c.BackgroundColor3 = ArenaConfig.Teams[side].colour
		c.Font = Enum.Font.GothamBold
		c.TextSize = 30
		c.TextColor3 = rgb(20, 20, 22)
		c.Text = "0"
		c.Parent = score
		corner(c, 12)
		return c
	end
	self.chipA = chip("A", 0)
	self.chipB = chip("B", 1)
	text(score, { text = ":", font = Enum.Font.GothamBold, size = 28, align = Enum.TextXAlignment.Center })

	local back = Instance.new("TextButton")
	back.AnchorPoint = Vector2.new(1, 0)
	back.Position = UDim2.new(1, -28, 0, 26)
	back.Size = UDim2.fromOffset(170, 44)
	back.BackgroundColor3 = GOLD
	back.Font = Enum.Font.GothamBold
	back.TextSize = 17
	back.TextColor3 = rgb(28, 24, 16)
	back.Text = L("กลับสู่ล็อบบี้")
	back.Parent = panel
	corner(back, 22)
	self.backButton = back

	-- หัวคอลัมน์
	local header = Instance.new("Frame")
	header.Position = UDim2.fromOffset(32, 96)
	header.Size = UDim2.fromOffset(PANEL_W - 64, 22)
	header.BackgroundTransparency = 1
	header.Parent = panel
	self.headerCells = {}
	for _, column in ipairs(COLUMNS) do
		self.headerCells[column.key] = text(header, { text = L(column.title), size = 14, colour = MUTED, align = column.align,
			pos = UDim2.fromOffset(column.x, 0), dim = UDim2.new(0, column.w, 1, 0) })
	end

	local rows = Instance.new("Frame")
	rows.Position = UDim2.fromOffset(32, 122)
	rows.Size = UDim2.fromOffset(PANEL_W - 64, 420)
	rows.BackgroundTransparency = 1
	rows.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows
	self.rows = rows

	self.note = text(panel, { text = L("หีบ เงิน และ EXP เข้าตัวละครของคุณเมื่อกลับเข้าเกมหลัก"), size = 15, colour = MUTED,
		align = Enum.TextXAlignment.Center, pos = UDim2.new(0, 0, 1, -34), dim = UDim2.new(1, 0, 0, 22) })

	-- เล่นต่อทันที (ผู้ใช้สั่ง 2026-10-01): ทั้งตี้กลับล็อบบี้พร้อมกัน รวมตี้เดิมให้เอง แล้วหาห้องต่อเลย ·
	-- มุมขวาล่าง เพราะแถวบนเต็มแล้ว (ผล · สกอร์กลาง · ปุ่มกลับ) · โน้ตกลางล่างกว้าง ~400 ไม่ถึงตรงนี้
	local again = Instance.new("TextButton")
	again.AnchorPoint = Vector2.new(1, 1)
	again.Position = UDim2.new(1, -28, 1, -12)
	again.Size = UDim2.fromOffset(190, 40)
	again.BackgroundColor3 = rgb(96, 196, 120)
	again.Font = Enum.Font.GothamBold
	again.TextSize = 17
	again.TextColor3 = rgb(16, 32, 20)
	again.Text = L("เล่นต่อทันที")
	again.Parent = panel
	corner(again, 20)
	self.againButton = again
	return self
end

function ArenaScoreboardGui:OnBack(callback)
	self.backButton.MouseButton1Click:Connect(callback)
end

function ArenaScoreboardGui:OnAgain(callback)
	self.againButton.MouseButton1Click:Connect(callback)
end

function ArenaScoreboardGui:SetVisible(visible)
	self.gui.Enabled = visible and true or false
end

-- โหมด "ตาราง Tab" (ผู้ใช้สั่ง 2026-09-24): หน้าตาเดียวกับตารางจบเกม แต่ไม่มีปุ่มกลับ/รางวัล และพื้นหลังจางกว่า
function ArenaScoreboardGui:SetLive(live)
	self.live = live
	self.backButton.Visible = not live
	self.againButton.Visible = not live
	self.note.Visible = not live
	self.dim.BackgroundTransparency = live and 0.75 or 0.45
	for _, column in ipairs(COLUMNS) do
		if column.reward then self.headerCells[column.key].Visible = not live end
	end
end

-- `snap` = ภาพแมตช์จาก ArenaState · อันดับเรียงตามคะแนนผลงาน ตัวเดียวกับตารางจบเกม
function ArenaScoreboardGui:RenderLive(snap)
	local rows = {}
	for _, member in ipairs(snap.roster or {}) do
		local row = table.clone(member)
		row.won = member.side == snap.mySide -- "ก้อนบน" = ทีมเรา
		table.insert(rows, row)
	end
	table.sort(rows, function(a, b) return (a.score or 0) > (b.score or 0) end)
	for rank, row in ipairs(rows) do row.rank = rank end
	self.title.Text, self.title.TextColor3 = L("สถิติ"), TEXT
	self.subtitle.Text = L("รอบ %d · %s", snap.round or 0, snap.mapName or "")
	self:Render({ rows = rows, wins = snap.wins, titles = { L("ทีมเรา"), L("ทีมศัตรู") } })
end

-- `result` = { rows = {…}, winner = "A"|"B"|nil, wins = {A=,B=} }
-- แต่ละแถวมี rank, name, side, bot, kills, deaths, assists, damage, score, gold, exp, chest, won, userId|me
function ArenaScoreboardGui:Render(result)
	for _, child in ipairs(self.rows:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local wins = result.wins or { A = 0, B = 0 }
	self.chipA.Text, self.chipB.Text = tostring(wins.A or 0), tostring(wins.B or 0)

	local myId = Players.LocalPlayer and Players.LocalPlayer.UserId
	local function isMe(row) return row.me or (row.userId ~= nil and row.userId == myId) end

	if not self.live then
		-- ผลของ "เรา" เป็นหัวใหญ่: ชนะ / แพ้ / เสมอ
		local mine
		for _, row in ipairs(result.rows or {}) do if isMe(row) then mine = row end end
		if not result.winner then
			self.title.Text, self.title.TextColor3 = L("เสมอ"), TEXT
		elseif mine and mine.won then
			self.title.Text, self.title.TextColor3 = L("ชัยชนะ!"), GOLD
		elseif mine then
			self.title.Text, self.title.TextColor3 = L("พ่ายแพ้"), RED
		else
			self.title.Text, self.title.TextColor3 = L("จบเกม"), TEXT
		end
		self.subtitle.Text = L("จบแมตช์ · ตารางอันดับ")
	end

	-- MVP = คะแนนสูงสุดทั้งห้อง
	local best = nil
	for _, row in ipairs(result.rows or {}) do
		if not best or (row.score or 0) > (best.score or 0) then best = row end
	end

	local order = 0
	local titles = result.titles or { L("ทีมชนะ"), L("ทีมแพ้") }
	local function section(title, winning)
		local members = {}
		for _, row in ipairs(result.rows or {}) do
			if (row.won and true or false) == winning then table.insert(members, row) end
		end
		if #members == 0 then return end
		local side = members[1].side
		local team = ArenaConfig.Teams[side] or { name = "", colour = STROKE }

		order += 1
		local head = Instance.new("Frame")
		head.LayoutOrder = order
		head.Size = UDim2.new(1, 0, 0, 26)
		head.BackgroundTransparency = 1
		head.Parent = self.rows
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromOffset(4, 18)
		bar.Position = UDim2.fromOffset(0, 4)
		bar.BackgroundColor3 = team.colour
		bar.Parent = head
		corner(bar, 2)
		text(head, { text = ("%s  ·  %s"):format(L(team.name), title), font = Enum.Font.GothamBold, size = 16,
			colour = winning and (self.live and TEXT or GREEN) or (self.live and MUTED or RED), pos = UDim2.fromOffset(14, 0) })

		for _, row in ipairs(members) do
			order += 1
			local me = isMe(row)
			local frame = Instance.new("Frame")
			frame.LayoutOrder = order
			frame.Size = UDim2.new(1, 0, 0, ROW_H)
			frame.BackgroundColor3 = me and ROW_ME or ROW
			frame.BackgroundTransparency = (self.live and row.alive == false) and 0.5 or 0
			frame.Parent = self.rows
			corner(frame, 10)
			if me then stroke(frame, GOLD, 0.2, 1.5) end
			local accent = Instance.new("Frame")
			accent.Size = UDim2.new(0, 4, 1, -12)
			accent.Position = UDim2.fromOffset(6, 6)
			accent.BackgroundColor3 = team.colour
			accent.Parent = frame
			corner(accent, 2)

			local dead = self.live and row.alive == false
			local dimText = dead and MUTED or TEXT
			local values = {
				rank = tostring(row.rank or "-"),
				-- ชื่อบอท ("หุ่นไอน้ำ-01") แปลได้ · ชื่อคนไม่แปล
				name = me and L("%s  (คุณ)"):format(row.name) or (row.bot and Show(row.name) or row.name),
				kills = tostring(row.kills or 0), deaths = tostring(row.deaths or 0), assists = tostring(row.assists or 0),
				damage = tostring(math.floor(row.damage or 0)),
				score = tostring(math.floor((row.score or 0) + 0.5)),
				exp = row.bot and "—" or ("✨ %d"):format(row.exp or 0),
				gold = row.bot and "—" or ("💰 %d"):format(row.gold or 0),
				chest = row.bot and "—" or "",
			}
			local nameLabel
			for _, column in ipairs(COLUMNS) do
				if not (column.reward and self.live) then
					local l = text(frame, { text = values[column.key] or "", size = column.key == "name" and 18 or 17,
						font = (column.key == "score" or column.key == "rank") and Enum.Font.GothamBold or Enum.Font.SourceSansBold,
						colour = column.key == "score" and GOLD or dimText, align = column.align,
						pos = UDim2.fromOffset(column.x, 0), dim = UDim2.new(0, column.w, 1, 0) })
					if column.key == "name" then nameLabel = l end
				end
			end
			-- ป้ายท้ายชื่อ: MVP / บอท / ตายแล้ว
			-- วัดความกว้างชื่อด้วย TextService (TextBounds เป็น 0 ตอน ScreenGui ยังปิดอยู่)
			local nameWidth = nameLabel and TextService:GetTextSize(nameLabel.Text, 18, Enum.Font.SourceSansBold, Vector2.new(250, ROW_H)).X or 0
			local tagX = 56 + math.min(250, nameWidth) + 8
			if row == best and (row.score or 0) > 0 then
				pill(frame, "MVP", GOLD, rgb(28, 24, 16), tagX, 38)
				tagX += 44
			end
			if row.bot then pill(frame, L("บอท"), rgb(70, 72, 84), TEXT, tagX, 36); tagX += 42 end
			if dead then pill(frame, L("ตาย"), rgb(110, 50, 48), TEXT, tagX, 34) end
			-- แต้มแร็งก์ของแมตช์นี้ (ตารางจบเท่านั้น · แมตช์ที่ไม่นับแร็งก์ไม่มีป้าย) เฟส 3
			if type(row.pvp) == "number" and not self.live then
				local up = row.pvp >= 0
				pill(frame, L("แร็งก์ %s%d", up and "+" or "−", math.abs(row.pvp)),
					up and rgb(52, 110, 64) or rgb(120, 52, 50), TEXT, tagX, 74)
			end

			-- รูปหีบรางวัล (ตารางจบแมตช์เท่านั้น) — ไม่มีรูปก็ขึ้น ⌛ ตามกติกาเดิม
			local chestItem = row.chest and ItemCatalog.Items[row.chest]
			if chestItem and not row.bot and not self.live then
				local column = COLUMNS[9]
				local image = Instance.new("ImageLabel")
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.Position = UDim2.new(0, column.x + column.w / 2, 0.5, 0)
				image.Size = UDim2.fromOffset(30, 30)
				image.BackgroundTransparency = 1
				image.ScaleType = Enum.ScaleType.Fit
				image.ZIndex = 3
				image.Parent = frame
				ItemIcon.Apply(image, chestItem.icon)
			end
		end
	end

	section(titles[1], true)
	section(titles[2], false)
end

return ArenaScoreboardGui
