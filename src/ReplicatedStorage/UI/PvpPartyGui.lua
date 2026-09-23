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
		stroke(card, 0.85)

		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.AnchorPoint = Vector2.new(0.5, 0)
		avatar.Position = UDim2.new(0.5, 0, 0, 22)
		avatar.Size = UDim2.fromOffset(120, 120)
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

		local plus = plusSign(card)
		self.slots[i] = { card = card, avatar = avatar, name = name, plus = plus }
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
	for i = 2, SLOTS do
		self.slots[i].card.MouseButton1Click:Connect(function()
			-- ช่องที่มีคนอยู่แล้วไม่ใช่ปุ่ม — กดได้เฉพาะช่องว่าง
			if self.slots[i].name.Visible then return end
			friends.Visible = true
			fire("friends")
		end)
	end

	return self
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

function PvpPartyGui:Render(snap)
	local members = snap.members or {}
	for i = 1, SLOTS do
		local slot = self.slots[i]
		local member = members[i]
		slot.name.Visible = member ~= nil
		slot.plus.Visible = member == nil
		slot.card.BackgroundColor3 = member and SLOT_BG or SLOT_EMPTY
		if member then
			slot.name.Text = member.name .. (member.me and " (คุณ)" or "")
		else
			slot.name.Text = ""
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
		-- ปุ่มเล่นถอยไปทางซ้ายเมื่อมีปุ่มแอดมินอยู่ข้างๆ ไม่งั้นสองปุ่มทับกันกลางจอ
		self.playButton.Position = self.soloButton.Visible
			and UDim2.new(0.5, -100, 1, -34) or UDim2.new(0.5, 0, 1, -34)
		self.playButton.AnchorPoint = self.soloButton.Visible and Vector2.new(1, 1) or Vector2.new(0.5, 1)
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
