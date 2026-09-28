-- PvpPartyGui: หน้าปาร์ตี้ของแท็บ PVP ในล็อบบี้ — วาดตามภาพร่างที่ผู้ใช้ส่งมา 2026-09-23
--
-- ห้าสถานะที่ภาพครอบคลุม (ดู `docs/design/07-pvp-lobby-ui.md`):
--   1. ปาร์ตี้ว่าง — ช่องเรา + ช่องว่างสองช่องมีเครื่องหมายบวก
--   2. ได้รับคำเชิญ — กล่องเล็กลอยขึ้นมา พร้อมปุ่มตกลง/ยกเลิก
--   3. มีเพื่อนแล้ว — ช่องที่สองเป็นอวตารเพื่อน
--   4. รายชื่อเพื่อน — แผงทึบซ้อนทับ มีปุ่มชวนรายคน
--   5. กำลังจับคู่ — นาฬิกาเดินขึ้น แทนที่ปุ่มเล่น พร้อมปุ่มยกเลิก
--
-- ไฟล์นี้**ไม่รู้จัก remote และไม่ตัดสินอะไร** มันรับภาพมาวาด แล้วบอกออกไปว่าผู้เล่นกดอะไร
-- (`PvpPartyController` เป็นคนคุยกับเซิร์ฟเวอร์) — ทรงเดียวกับหน้าต่างอื่นของโปรเจ็ค
local PvpPartyGui = {}
PvpPartyGui.__index = PvpPartyGui

local ACCENT = Color3.fromRGB(216, 172, 84)
local TEXT_LIGHT = Color3.fromRGB(240, 240, 245)
local ClassConfig = require(script.Parent.Parent.ClassConfig)
local TEXT_MUTED = Color3.fromRGB(180, 180, 195)
local GLASS = Color3.fromRGB(255, 255, 255)
local SLOT_BG = Color3.fromRGB(78, 78, 82)
local SLOT_EMPTY = Color3.fromRGB(64, 64, 68)
local GREEN = Color3.fromRGB(64, 184, 110)
local RED = Color3.fromRGB(214, 68, 62)

local SLOTS = 3
local SLOT_W, SLOT_H, SLOT_GAP = 168, 288, 26

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 8)
	c.Parent = parent
	return c
end

local function stroke(parent, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = GLASS
	s.Transparency = transparency or 0.75
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

-- ⚠️ **เครื่องหมายบวกวาดจาก Frame สองอัน ไม่ใช่ตัวอักษร** — ฟอนต์ของ Roblox วาดสัญลักษณ์หนาๆ
-- (✚ ▲ ▼) เป็นกล่องเปล่า บทเรียนเดิมจากลูกศรในมินิเกมและปุ่มพับ UI
local function plusSign(parent)
	local holder = Instance.new("Frame")
	holder.Name = "Plus"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(74, 74)
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	for _, size in ipairs({ UDim2.fromOffset(74, 20), UDim2.fromOffset(20, 74) }) do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = size
		bar.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
		bar.BorderSizePixel = 0
		bar.Parent = holder
	end
	return holder
end

local function pill(parent, text, colour, width)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width or 92, 34)
	b.BackgroundColor3 = colour
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = 17
	b.TextColor3 = TEXT_LIGHT
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, UDim.new(0, 8))
	return b
end

--------------------------------------------------------------------------------
function PvpPartyGui.new(parent)
	local self = setmetatable({}, PvpPartyGui)
	self.onAction = nil
	self.slots = {}

	local panel = Instance.new("Frame")
	panel.Name = "PvpParty"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundTransparency = 1
	panel.Visible = false
	panel.Parent = parent
	self.panel = panel

	-- **ย่อ/ขยายทั้งหน้าตามขนาดจอ** (ผู้ใช้แจ้ง 2026-09-24 "ขยายจอแล้ว UI ไม่ปรับ") — ของทุกชิ้นในหน้านี้
	-- วางด้วยพิกเซลเทียบขนาดออกแบบ 800x480 แล้วให้ UIScale ตัวเดียวขยายทั้งก้อน · กล่อง content หดด้วย 1/s
	-- เพื่อให้หลังขยายแล้วเต็มแผงพอดี ตำแหน่งที่ยึดขอบล่าง/กลางจึงยังอยู่ที่เดิม
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.Position = UDim2.fromScale(0.5, 0.5)
	content.Size = UDim2.fromScale(1, 1) -- ก่อนวัดขนาดได้ (หน้ายังซ่อนอยู่) ให้เต็มแผงไว้ก่อน
	content.BackgroundTransparency = 1
	content.Parent = panel
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = content
	-- สามทรง (QA 2026-09-26 — มือถือเคยใช้ทรงคอมย่อลงที่เพดาน 0.6 การ์ดสูง 288 ล้นแผงสูง 140 ทั้งบนและล่าง
	-- ปุ่มเล่นไปทับป้ายเลเวล) · wide = คอม ออกแบบ 800x480 ปุ่มใต้การ์ด (เหมือนเดิมทุกค่า) ·
	-- short = มือถือแนวนอน แผงเตี้ย ออกแบบ 800x300 ปุ่มเป็นคอลัมน์ขวาของการ์ด (ห่างปุ่มกระโดดมุมขวาล่าง) ·
	-- tall = แนวตั้ง ออกแบบ 520x480 เรียงลงล่าง · ตัวแปร `panel` ถูกเปลี่ยนเป็นกล่อง content ข้างล่าง จึงจับตัวนอกไว้แยก
	local outer = panel
	local function rescale()
		local size = outer.AbsoluteSize
		if size.X < 1 or size.Y < 1 then return end
		local mode = size.X < size.Y and "tall" or (size.Y < 320 and "short" or "wide")
		local dw, dh = 800, 480
		if mode == "short" then dw, dh = 800, 300 elseif mode == "tall" then dw, dh = 520, 480 end
		local s = math.clamp(math.min(size.X / dw, size.Y / dh), 0.4, 1.8)
		uiScale.Scale = s
		content.Size = UDim2.fromScale(1 / s, 1 / s)
		if self.mode ~= mode then
			self.mode = mode
			if self.playButton then self:_layout() end
		end
	end
	outer:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
	rescale()
	panel = content -- ของทุกชิ้นข้างล่างไปอยู่ในกล่องที่ขยายได้

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 260, 0, 40)
	title.Position = UDim2.new(0, 26, 0, 18)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = 30
	title.TextColor3 = TEXT_LIGHT
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "ปาร์ตี้"
	title.Parent = panel
	self.title = title

	-- แร็งก์ของเรา (เฟส 3) ใต้หัวข้อ: ขั้น + แต้ม + ระยะถึงขั้นถัดไป · บรรทัดเล็กบอกผลแมตช์ล่าสุด/ตกขั้น (ไม่มีเอฟเฟกต์)
	local rankLine = Instance.new("TextLabel")
	rankLine.Size = UDim2.new(0, 520, 0, 22)
	rankLine.BackgroundTransparency = 1
	rankLine.Font = Enum.Font.GothamBold
	rankLine.TextSize = 16
	rankLine.TextColor3 = TEXT_LIGHT
	rankLine.TextXAlignment = Enum.TextXAlignment.Left
	rankLine.RichText = true
	rankLine.Text = ""
	rankLine.Parent = panel
	self.rankLine = rankLine
	local rankNote = rankLine:Clone()
	rankNote.Font = Enum.Font.Gotham
	rankNote.TextSize = 13
	rankNote.TextColor3 = Color3.fromRGB(180, 176, 166)
	rankNote.Parent = panel
	self.rankNote = rankNote

	-- แถวช่องสามช่อง กลางจอ
	local row = Instance.new("Frame")
	row.Name = "Slots"
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.46)
	row.Size = UDim2.fromOffset(SLOTS * SLOT_W + (SLOTS - 1) * SLOT_GAP, SLOT_H)
	row.BackgroundTransparency = 1
	row.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, SLOT_GAP)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = row
	self.row, self.rowLayout = row, layout

	for i = 1, SLOTS do
		local card = Instance.new("TextButton")
		card.Name = "Slot" .. i
		card.LayoutOrder = i
		card.Size = UDim2.fromOffset(SLOT_W, SLOT_H)
		card.BackgroundColor3 = SLOT_EMPTY
		card.Text = ""
		card.AutoButtonColor = false
		card.Parent = row
		corner(card, UDim.new(0, 16))
		local cardStroke = stroke(card, 0.85)

		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.AnchorPoint = Vector2.new(0.5, 0)
		-- **รูปเต็มตัว** (ผู้ใช้แจ้ง 2026-09-24 "รูปโปรไฟล์มาไม่ครบ ตัวขาด") — เดิมเป็นรูปหัว 120x120
		-- รูปเต็มตัวของ Roblox เป็นสี่เหลี่ยมจัตุรัสที่ตัวอยู่กลาง ขอบซ้ายขวาว่าง → Crop ตัดขอบว่างทิ้ง
		-- ให้ตัวสูงเต็มการ์ดตั้งแต่หัวถึงเท้า เหลือที่ให้ชื่อด้านล่าง
		avatar.Position = UDim2.new(0.5, 0, 0, 10)
		avatar.Size = UDim2.fromOffset(SLOT_W - 12, SLOT_H - 86)
		avatar.ScaleType = Enum.ScaleType.Crop
		avatar.BackgroundTransparency = 1
		avatar.Image = ""
		avatar.Visible = false
		avatar.Parent = card

		local name = Instance.new("TextLabel")
		name.Name = "PlayerName"
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.new(0.5, 0, 1, -14)
		name.Size = UDim2.new(1, -16, 0, 26)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.SourceSansBold
		name.TextSize = 18
		name.TextColor3 = TEXT_LIGHT
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = ""
		name.Visible = false
		name.Parent = card

		-- เลเวลเป็นป้ายทองอยู่ **เหนือชื่อ** (ผู้ใช้สั่ง 2026-09-24 "ไว้อวด") — เดิมต่อท้ายชื่อแล้วโดนตัดหาย
		local level = Instance.new("TextLabel")
		level.Name = "Level"
		level.AnchorPoint = Vector2.new(0.5, 1)
		level.Position = UDim2.new(0.5, 0, 1, -44)
		level.Size = UDim2.fromOffset(70, 24)
		level.BackgroundColor3 = Color3.fromRGB(226, 184, 78)
		level.Font = Enum.Font.GothamBold
		level.TextSize = 14
		level.TextColor3 = Color3.fromRGB(28, 24, 16)
		level.Text = ""
		level.Visible = false
		level.ZIndex = 3
		level.Parent = card
		local levelCorner = Instance.new("UICorner")
		levelCorner.CornerRadius = UDim.new(0, 12)
		levelCorner.Parent = level

		-- ตราแร็งก์มุมขวาบนของการ์ดทุกคน (ผู้ใช้สั่ง 2026-09-28) · แร็งก์ยังล็อก = ตราจาง + 🔒 · แตะ = บอกว่ายังไม่เปิด
		local rankBadge = Instance.new("TextButton")
		rankBadge.Name = "RankBadge"
		rankBadge.AnchorPoint = Vector2.new(1, 0)
		rankBadge.Position = UDim2.new(1, -8, 0, 8)
		rankBadge.Size = UDim2.fromOffset(40, 40)
		rankBadge.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
		rankBadge.BackgroundTransparency = 0.15
		rankBadge.AutoButtonColor = true
		rankBadge.TextScaled = true
		rankBadge.Text = "🔩"
		rankBadge.TextTransparency = 0.45
		rankBadge.Visible = false
		rankBadge.ZIndex = 4
		rankBadge.Parent = card
		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(1, 0)
		badgeCorner.Parent = rankBadge
		local badgeLock = Instance.new("TextLabel")
		badgeLock.Name = "Lock"
		badgeLock.AnchorPoint = Vector2.new(1, 1)
		badgeLock.Position = UDim2.new(1, 4, 1, 4)
		badgeLock.Size = UDim2.fromOffset(20, 20)
		badgeLock.BackgroundTransparency = 1
		badgeLock.TextScaled = true
		badgeLock.Text = "🔒"
		badgeLock.ZIndex = 5
		badgeLock.Parent = rankBadge

		local plus = plusSign(card)
		self.slots[i] = { card = card, avatar = avatar, name = name, plus = plus, level = level, stroke = cardStroke,
			rankBadge = rankBadge }
	end

	--------------------------------------------------------------------------------
	-- ปุ่มเล่น / สถานะค้นหาห้อง
	--------------------------------------------------------------------------------
	local playButton = pill(panel, "เล่น", GREEN, 170)
	playButton.Name = "PlayButton"
	playButton.AnchorPoint = Vector2.new(0.5, 1)
	playButton.Position = UDim2.new(0.5, 0, 1, -34)
	playButton.Size = UDim2.fromOffset(170, 52)
	playButton.TextSize = 22
	corner(playButton, UDim.new(1, 0))
	self.playButton = playButton

	local searchLabel = Instance.new("TextLabel")
	searchLabel.Name = "SearchLabel"
	searchLabel.AnchorPoint = Vector2.new(0.5, 1)
	searchLabel.Position = UDim2.new(0.5, 0, 1, -94)
	searchLabel.Size = UDim2.new(0, 420, 0, 26)
	searchLabel.BackgroundTransparency = 1
	searchLabel.Font = Enum.Font.SourceSans
	searchLabel.TextSize = 19
	searchLabel.TextColor3 = TEXT_MUTED
	searchLabel.Text = ""
	searchLabel.Visible = false
	searchLabel.Parent = panel
	self.searchLabel = searchLabel

	local cancelButton = pill(panel, "ยกเลิก", RED, 150)
	cancelButton.Name = "CancelButton"
	cancelButton.AnchorPoint = Vector2.new(0.5, 1)
	cancelButton.Position = UDim2.new(0.5, 0, 1, -34)
	cancelButton.Size = UDim2.fromOffset(150, 52)
	cancelButton.TextSize = 20
	cancelButton.Visible = false
	corner(cancelButton, UDim.new(1, 0))
	self.cancelButton = cancelButton

	-- **ปุ่มของแอดมิน: เริ่มแมตช์คนเดียวได้เลย ที่เหลือเป็นบอท** (ผู้ใช้สั่ง)
	-- นั่งข้างปุ่มเล่น ไม่ใช่แทนที่มัน — แอดมินต้องเทสทางปกติได้ด้วยโดยไม่ต้องถอดสิทธิ์ตัวเอง
	local soloButton = pill(panel, "เริ่มเลย (แอดมิน)", Color3.fromRGB(86, 96, 130), 170)
	soloButton.Name = "SoloButton"
	soloButton.AnchorPoint = Vector2.new(0, 1)
	soloButton.Position = UDim2.new(0.5, 100, 1, -34)
	soloButton.Size = UDim2.fromOffset(170, 52)
	soloButton.TextSize = 18
	soloButton.Visible = false
	corner(soloButton, UDim.new(1, 0))
	self.soloButton = soloButton

	--------------------------------------------------------------------------------
	-- กล่องคำเชิญ (ลอยเหนือช่องที่สอง ตามภาพ)
	--------------------------------------------------------------------------------
	local invite = Instance.new("Frame")
	invite.Name = "Invite"
	invite.AnchorPoint = Vector2.new(0.5, 1)
	invite.Position = UDim2.new(0.5, 0, 0.46, -SLOT_H / 2 - 12)
	invite.Size = UDim2.fromOffset(300, 78)
	invite.BackgroundColor3 = Color3.fromRGB(226, 232, 238)
	invite.Visible = false
	invite.ZIndex = 5
	invite.Parent = panel
	corner(invite, UDim.new(0, 8))

	local inviteText = Instance.new("TextLabel")
	inviteText.Size = UDim2.new(1, -16, 0, 34)
	inviteText.Position = UDim2.new(0, 8, 0, 6)
	inviteText.BackgroundTransparency = 1
	inviteText.Font = Enum.Font.SourceSansBold
	inviteText.TextSize = 18
	inviteText.TextColor3 = Color3.fromRGB(28, 28, 32)
	inviteText.TextTruncate = Enum.TextTruncate.AtEnd
	inviteText.ZIndex = 6
	inviteText.Parent = invite
	self.inviteText = inviteText

	local accept = pill(invite, "ตกลง", GREEN, 140)
	accept.AnchorPoint = Vector2.new(1, 1)
	accept.Position = UDim2.new(0.5, -4, 1, -8)
	accept.ZIndex = 6
	local decline = pill(invite, "ยกเลิก", RED, 140)
	decline.AnchorPoint = Vector2.new(0, 1)
	decline.Position = UDim2.new(0.5, 4, 1, -8)
	decline.ZIndex = 6
	self.invite = invite

	--------------------------------------------------------------------------------
	-- แผงรายชื่อเพื่อน
	--------------------------------------------------------------------------------
	local friends = Instance.new("Frame")
	friends.Name = "FriendList"
	friends.AnchorPoint = Vector2.new(0.5, 0.5)
	friends.Position = UDim2.fromScale(0.5, 0.5)
	friends.Size = UDim2.fromOffset(460, 400)
	friends.BackgroundColor3 = Color3.fromRGB(28, 26, 34)
	friends.BackgroundTransparency = 0.05
	friends.Visible = false
	friends.ZIndex = 10
	friends.Parent = panel
	corner(friends, UDim.new(0, 16))
	stroke(friends, 0.7)

	local friendsTitle = Instance.new("TextLabel")
	friendsTitle.Size = UDim2.new(1, 0, 0, 44)
	friendsTitle.Position = UDim2.new(0, 0, 0, 12)
	friendsTitle.BackgroundTransparency = 1
	friendsTitle.Font = Enum.Font.SourceSansBold
	friendsTitle.TextSize = 24
	friendsTitle.TextColor3 = TEXT_LIGHT
	friendsTitle.Text = "รายชื่อเพื่อน"
	friendsTitle.ZIndex = 11
	friendsTitle.Parent = friends

	local closeFriends = pill(friends, "ปิด", Color3.fromRGB(70, 68, 78), 70)
	closeFriends.AnchorPoint = Vector2.new(1, 0)
	closeFriends.Position = UDim2.new(1, -12, 0, 12)
	closeFriends.Size = UDim2.fromOffset(70, 30)
	closeFriends.ZIndex = 11

	local friendRows = Instance.new("ScrollingFrame")
	friendRows.Position = UDim2.new(0, 14, 0, 62)
	friendRows.Size = UDim2.new(1, -28, 1, -78)
	friendRows.BackgroundTransparency = 1
	friendRows.BorderSizePixel = 0
	friendRows.ScrollBarThickness = 5
	friendRows.ScrollBarImageColor3 = ACCENT
	friendRows.CanvasSize = UDim2.new()
	friendRows.AutomaticCanvasSize = Enum.AutomaticSize.Y
	friendRows.ZIndex = 11
	friendRows.Parent = friends
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.Parent = friendRows
	self.friends = friends
	self.friendRows = friendRows

	local empty = Instance.new("TextLabel")
	empty.Name = "Empty"
	empty.Size = UDim2.new(1, 0, 0, 40)
	empty.BackgroundTransparency = 1
	empty.Font = Enum.Font.SourceSans
	empty.TextSize = 18
	empty.TextColor3 = TEXT_MUTED
	empty.Text = "ยังไม่มีเพื่อนในรายชื่อ"
	empty.Visible = false
	empty.ZIndex = 11
	empty.Parent = friendRows
	self.friendsEmpty = empty

	--------------------------------------------------------------------------------
	-- สายไฟ
	--------------------------------------------------------------------------------
	local function fire(action, arg)
		if self.onAction then self.onAction(action, arg) end
	end
	playButton.MouseButton1Click:Connect(function() fire("play") end)
	cancelButton.MouseButton1Click:Connect(function() fire("cancel") end)
	soloButton.MouseButton1Click:Connect(function() fire("solo") end)
	accept.MouseButton1Click:Connect(function()
		if self._inviteFrom then fire("accept", self._inviteFrom) end
	end)
	decline.MouseButton1Click:Connect(function()
		if self._inviteFrom then fire("decline", self._inviteFrom) end
	end)
	closeFriends.MouseButton1Click:Connect(function() friends.Visible = false end)
	-- แตะตราแร็งก์ = บอกสถานะ (ตอนนี้ล็อก) · ตัวคุมแสดงเป็นข้อความเด้ง
	for i = 1, SLOTS do
		self.slots[i].rankBadge.MouseButton1Click:Connect(function() fire("ranklocked") end)
	end
	for i = 2, SLOTS do
		self.slots[i].card.MouseButton1Click:Connect(function()
			-- ช่องที่มีคนอยู่แล้วไม่ใช่ปุ่ม — กดได้เฉพาะช่องว่าง
			if self.slots[i].name.Visible then return end
			friends.Visible = true
			fire("friends")
		end)
	end

	-- ของครบแล้ว จัดทรงตามจอ (rescale ตอนต้นรู้ทรงแล้วแต่ยังไม่มีของให้จัด) · แผงยังซ่อน = ได้ทรงตอนมันโผล่
	rescale()
	if self.mode then self:_layout() end
	return self
end

-- ข้อมูลแร็งก์จาก LobbyRank.server (PvpRankInfo) · nil = ยังไม่รู้ (ว่างไว้)
function PvpPartyGui:SetRankInfo(info)
	if not info then
		self.rankLine.Text, self.rankNote.Text = "", ""
		return
	end
	local PvpRankConfig = require(script.Parent.Parent.PvpRankConfig)
	if info.locked then
		self.rankLine.Text = "🔒 " .. PvpRankConfig.LockedText
		self.rankNote.Text = "แมตช์ตอนนี้ยังไม่นับแต้มแร็งก์"
		return
	end
	if not info.played then
		self.rankLine.Text = "🔩 ยังไม่มีแร็งก์"
		self.rankNote.Text = "ชนะแมตช์ที่ไม่มีบอทเพื่อเก็บแต้ม (+25 · แพ้ −18)"
		return
	end
	local tier = PvpRankConfig.Tier(info.tier)
	local nextTier = PvpRankConfig.Tiers[(info.tier or 1) + 1]
	local line = ('%s <font color="#%s">%s</font> · %d แต้ม'):format(tier.emoji, tier.color:ToHex(), tier.name, info.points or 0)
	if nextTier and info.next then line ..= (" · อีก %d ถึง%s"):format(info.next - (info.points or 0), nextTier.name) end
	self.rankLine.Text = line
	local notes = {}
	local last = info.last
	if last and last.kind == "season" then
		notes[#notes + 1] = ("จบซีซัน: แร็งก์ลดลง 2 ขั้น (%d แต้ม)"):format(last.d or 0)
	elseif last and last.d then
		notes[#notes + 1] = ("แมตช์ล่าสุด %s%d"):format((last.d or 0) >= 0 and "+" or "−", math.abs(last.d or 0))
	end
	if info.endsAt then
		local days = math.max(0, math.floor((info.endsAt - workspace:GetServerTimeNow()) / 86400))
		notes[#notes + 1] = ("ซีซัน %d เหลือ %d วัน"):format(info.season or 1, days)
	end
	self.rankNote.Text = table.concat(notes, " · ")
end

function PvpPartyGui:OnAction(callback)
	self.onAction = callback
end

function PvpPartyGui:SetVisible(visible)
	self.panel.Visible = visible and true or false
	if not visible then self.friends.Visible = false end
end

-- รูปอวตารมาทีหลัง (ต้องยิง `GetUserThumbnailAsync` ซึ่ง yield) — ตัวคุมเป็นคนหามาให้
function PvpPartyGui:SetSlotAvatar(index, content)
	local slot = self.slots[index]
	if not slot then return end
	slot.avatar.Image = content or ""
	slot.avatar.Visible = (content ~= nil and content ~= "")
end

-- จัดตำแหน่ง/ขนาดตามทรงของจอ (`self.mode` จาก rescale) — ค่าทรง wide คือค่าเดิมของคอมทุกค่า
function PvpPartyGui:_layout()
	local mode = self.mode or "wide"
	local sw, sh, gap = SLOT_W, SLOT_H, SLOT_GAP
	if mode ~= "wide" then sw, sh, gap = 150, 220, 16 end
	local rowW = SLOTS * sw + (SLOTS - 1) * gap
	self.row.Size = UDim2.fromOffset(rowW, sh)
	self.rowLayout.Padding = UDim.new(0, gap)
	for _, slot in ipairs(self.slots) do
		slot.card.Size = UDim2.fromOffset(sw, sh)
		slot.avatar.Size = UDim2.fromOffset(sw - 12, sh - 86)
	end
	self.title.Position = mode == "wide" and UDim2.new(0, 26, 0, 18) or UDim2.new(0, 20, 0, 8)
	-- คอม: สองบรรทัดใต้หัวข้อ · มือถือ (แผงเตี้ย/แนวตั้ง): บรรทัดเดียวข้างหัวข้อ ไม่งั้นทับแถวการ์ด · บรรทัดเล็กซ่อน
	if mode == "wide" then
		self.rankLine.Position = UDim2.new(0, 26, 0, 58)
		self.rankLine.TextSize = 16
		self.rankNote.Position = UDim2.new(0, 26, 0, 80)
		self.rankNote.Visible = true
	else
		self.rankLine.Position = UDim2.new(0, 120, 0, 17)
		self.rankLine.TextSize = 13
		self.rankNote.Visible = false
	end
	self.searchLabel.Size = UDim2.new(0, mode == "short" and 240 or 420, 0, 26)
	if mode == "wide" then
		self.row.AnchorPoint, self.row.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.46)
		self.invite.AnchorPoint, self.invite.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 0.46, -sh / 2 - 12)
		self.searchLabel.AnchorPoint, self.searchLabel.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -94)
		self.cancelButton.AnchorPoint, self.cancelButton.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -34)
		self.friends.Size = UDim2.fromOffset(460, 400)
	elseif mode == "short" then
		-- การ์ดเยื้องซ้าย คอลัมน์ปุ่มขวามือการ์ด · คำเชิญลอยทับกลางแถวการ์ด (ข้างบนไม่มีที่แล้ว)
		local colX = rowW / 2 + 24
		self.row.AnchorPoint, self.row.Position = Vector2.new(0.5, 0.5), UDim2.new(0.44, 0, 0.5, 14)
		self.invite.AnchorPoint, self.invite.Position = Vector2.new(0.5, 0.5), UDim2.new(0.44, 0, 0.5, 14)
		self.searchLabel.AnchorPoint, self.searchLabel.Position = Vector2.new(0, 0.5), UDim2.new(0.44, colX, 0.5, -38)
		self.cancelButton.AnchorPoint, self.cancelButton.Position = Vector2.new(0, 0.5), UDim2.new(0.44, colX, 0.5, 20)
		self.friends.Size = UDim2.fromOffset(460, 280)
	else -- tall
		self.row.AnchorPoint, self.row.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 60)
		self.invite.AnchorPoint, self.invite.Position = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0, 60 + sh / 2)
		self.searchLabel.AnchorPoint, self.searchLabel.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 60 + sh + 16)
		self.cancelButton.AnchorPoint, self.cancelButton.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 60 + sh + 52)
		self.friends.Size = UDim2.fromOffset(480, 420)
	end
	self:_placeButtons()
end

-- ปุ่มเล่น + ปุ่มแอดมิน (ขึ้นกับว่าปุ่มแอดมินโชว์อยู่ไหม) — ป้ายค้นหา/ปุ่มแอดมินไม่เคยโชว์พร้อมกัน จึงใช้ที่เดียวกันได้
function PvpPartyGui:_placeButtons()
	local mode = self.mode or "wide"
	local solo = self.soloButton and self.soloButton.Visible
	local rowW = self.row.Size.X.Offset
	if mode == "wide" then
		-- ปุ่มเล่นถอยไปทางซ้ายเมื่อมีปุ่มแอดมินอยู่ข้างๆ ไม่งั้นสองปุ่มทับกันกลางจอ
		self.playButton.AnchorPoint = solo and Vector2.new(1, 1) or Vector2.new(0.5, 1)
		self.playButton.Position = solo and UDim2.new(0.5, -100, 1, -34) or UDim2.new(0.5, 0, 1, -34)
		self.soloButton.AnchorPoint, self.soloButton.Position = Vector2.new(0, 1), UDim2.new(0.5, 100, 1, -34)
	elseif mode == "short" then
		self.playButton.AnchorPoint, self.playButton.Position = Vector2.new(0, 0.5), UDim2.new(0.44, rowW / 2 + 24, 0.5, 20)
		self.soloButton.AnchorPoint, self.soloButton.Position = Vector2.new(0, 0.5), UDim2.new(0.44, rowW / 2 + 24, 0.5, -42)
	else
		local below = 60 + self.row.Size.Y.Offset
		self.playButton.AnchorPoint, self.playButton.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, below + 52)
		self.soloButton.AnchorPoint, self.soloButton.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, below + 114)
	end
end

function PvpPartyGui:Render(snap)
	local members = snap.members or {}
	for i = 1, SLOTS do
		local slot = self.slots[i]
		local member = members[i]
		slot.name.Visible = member ~= nil
		slot.plus.Visible = member == nil
		slot.rankBadge.Visible = member ~= nil
		slot.card.BackgroundColor3 = member and SLOT_BG or SLOT_EMPTY
		if member then
			slot.name.Text = member.name .. (member.me and " (คุณ)" or "")
			slot.level.Text = member.level and ("Lv. %d"):format(member.level) or ""
			slot.level.Visible = member.level ~= nil
			-- กรอบการ์ดเป็นสีอาชีพ (ถ้ามีอาชีพ) ไม่มีอาชีพ = กรอบกระจกจางเหมือนเดิม
			local class = member.class and ClassConfig.Classes[member.class]
			slot.stroke.Color = class and class.color or GLASS
			slot.stroke.Transparency = class and 0 or 0.85
			slot.stroke.Thickness = class and 3 or 1
		else
			slot.name.Text = ""
			slot.level.Visible = false
			slot.stroke.Color, slot.stroke.Transparency, slot.stroke.Thickness = GLASS, 0.85, 1
			slot.avatar.Visible = false
			slot.avatar.Image = ""
		end
	end

	-- คำเชิญ
	self._inviteFrom = snap.invite and snap.invite.userId or nil
	self.invite.Visible = snap.invite ~= nil
	if snap.invite then
		self.inviteText.Text = ("%s ชวนเข้าปาร์ตี้"):format(snap.invite.name)
	end

	-- ค้นหาห้อง
	local searching = snap.searching == true
	self.playButton.Visible = not searching
	self.cancelButton.Visible = searching and not snap.launching
	self.searchLabel.Visible = searching or snap.notReady == true
	-- ปุ่มแอดมินโผล่เฉพาะตอนยังไม่ได้เข้าคิว และเฉพาะกับแอดมินจริงๆ (เซิร์ฟเวอร์เป็นคนบอก)
	if self.soloButton then
		self.soloButton.Visible = (snap.admin == true) and not searching and snap.notReady ~= true
		self:_placeButtons()
	end

	if snap.notReady == true and not searching then
		-- **บอกความจริงตั้งแต่ก่อนกด** ไม่ใช่ให้หมุนแล้วค่อยเฉลยตอนหมดเวลา
		self.searchLabel.Text = "สนาม PVP ยังไม่เปิด — ยังไม่ได้สร้างเพลสสนาม"
		self.searchLabel.TextColor3 = ACCENT
	elseif searching then
		local secs = snap.searchSeconds or 0
		if snap.launching then
			self.searchLabel.Text = "เจอห้องแล้ว — กำลังพาเข้าสนาม…"
			self.searchLabel.TextColor3 = GREEN
		else
			local line = ("กำลังค้นหาห้อง  %d:%02d   (%d/%d คน)")
				:format(math.floor(secs / 60), secs % 60, snap.queued or 1, snap.needed or 6)
			-- นับถอยหลังบอทเติม: การรอที่บอกว่าจะจบเมื่อไหร่ ต่างจากการรอที่ไม่บอกอะไรเลย
			if snap.botsIn and snap.botsIn > 0 then
				line ..= ("   · บอทมาเติมใน %d:%02d"):format(math.floor(snap.botsIn / 60), snap.botsIn % 60)
			end
			self.searchLabel.Text = line
			self.searchLabel.TextColor3 = TEXT_MUTED
		end
	end
end

function PvpPartyGui:RenderFriends(rows)
	for _, c in ipairs(self.friendRows:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	self.friendsEmpty.Visible = #rows == 0

	for i, friend in ipairs(rows) do
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, -6, 0, 46)
		row.BackgroundColor3 = Color3.fromRGB(48, 46, 56)
		row.BorderSizePixel = 0
		row.ZIndex = 11
		row.Parent = self.friendRows
		corner(row, UDim.new(0, 10))

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -120, 1, 0)
		name.Position = UDim2.new(0, 14, 0, 0)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.SourceSansBold
		name.TextSize = 18
		name.TextColor3 = friend.here and TEXT_LIGHT or TEXT_MUTED
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		-- **บอกด้วยว่าใครอยู่ในล็อบบี้นี้** — คำเชิญยังส่งข้ามเซิร์ฟไม่ได้ ปุ่มที่กดแล้วโดนปฏิเสธ
		-- ทุกครั้งโดยไม่บอกเหตุผลล่วงหน้าคือปุ่มที่อ่านเหมือนพัง
		name.Text = friend.name .. (friend.here and "" or "  · ไม่ได้อยู่ในล็อบบี้")
		name.ZIndex = 12
		name.Parent = row

		local invite = pill(row, "ชวน", friend.here and GREEN or Color3.fromRGB(70, 68, 78), 88)
		invite.AnchorPoint = Vector2.new(1, 0.5)
		invite.Position = UDim2.new(1, -12, 0.5, 0)
		invite.Size = UDim2.fromOffset(88, 32)
		invite.ZIndex = 12
		invite.MouseButton1Click:Connect(function()
			if self.onAction then self.onAction("invite", friend.userId) end
		end)
	end
end

return PvpPartyGui
