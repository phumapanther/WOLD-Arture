-- ArenaHudGui: แถบบนของสนาม PVP — สกอร์รอบ เวลาที่เหลือของเฟส และใครยังยืนอยู่บ้าง (ซิลเวอร์อยู่ในร้าน)
--
-- ตัววาดล้วน ตัวคุม (`ArenaController`) เป็นคนส่งภาพจากเซิร์ฟเวอร์มาให้
--
-- **สกอร์อยู่กลางจอบนสุด** เพราะมันคือตัวเลขที่ต้องอ่านได้โดยไม่ละสายตาจากศัตรู — ต่างจาก HUD ของ
-- เกมหลักที่ทุกอย่างเกาะมุม (ที่นั่นไม่มีอะไรต้องรีบอ่าน)
local ArenaConfig = require(script.Parent.Parent.ArenaConfig)

local ArenaHudGui = {}
ArenaHudGui.__index = ArenaHudGui

local DIM = Color3.fromRGB(24, 24, 28)
local TEXT = Color3.fromRGB(238, 234, 226)
local MUTED = Color3.fromRGB(176, 172, 164)

local PHASE_TEXT = {
	warmup = "กำลังรอผู้เล่น",
	buy = "เตรียมตัว — ซื้อของ",
	live = "สู้!",
	roundEnd = "จบรอบ",
	matchEnd = "จบแมตช์",
}

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 8)
	c.Parent = parent
	return c
end

function ArenaHudGui.new()
	local self = setmetatable({}, ArenaHudGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "ArenaHudGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 14
	gui.Enabled = false
	self.gui = gui

	--------------------------------------------------------------------------
	-- แถบสกอร์กลางบน
	--------------------------------------------------------------------------
	-- กะทัดรัด (ผู้ใช้สั่ง 2026-09-26 เฟส 1): เดิม 420x64 กินกลางจอบนเยอะเกินบนมือถือ
	local bar = Instance.new("Frame")
	bar.Name = "ScoreBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 6)
	bar.Size = UDim2.fromOffset(260, 40)
	bar.BackgroundColor3 = DIM
	bar.BackgroundTransparency = 0.25
	bar.BorderSizePixel = 0
	bar.Parent = gui
	corner(bar, UDim.new(0, 10))

	local function scoreBox(side, anchorX, x)
		local box = Instance.new("TextLabel")
		box.AnchorPoint = Vector2.new(anchorX, 0.5)
		box.Position = UDim2.new(anchorX, x, 0.5, 0)
		box.Size = UDim2.fromOffset(52, 30)
		box.BackgroundColor3 = ArenaConfig.Teams[side].colour
		box.BorderSizePixel = 0
		box.Font = Enum.Font.GothamBold
		box.TextSize = 20
		box.TextColor3 = Color3.fromRGB(20, 20, 20)
		box.Text = "0"
		box.Parent = bar
		corner(box, UDim.new(0, 8))
		return box
	end
	self.scoreA = scoreBox("A", 0, 6)
	self.scoreB = scoreBox("B", 1, -6)

	local middle = Instance.new("TextLabel")
	middle.AnchorPoint = Vector2.new(0.5, 0.5)
	middle.Position = UDim2.fromScale(0.5, 0.5)
	middle.Size = UDim2.fromOffset(120, 34)
	middle.BackgroundTransparency = 1
	middle.Font = Enum.Font.GothamBold
	middle.TextSize = 20
	middle.TextColor3 = TEXT
	middle.Text = "0:00"
	middle.Parent = bar
	self.timer = middle

	local phase = Instance.new("TextLabel")
	phase.AnchorPoint = Vector2.new(0.5, 0)
	phase.Position = UDim2.new(0.5, 0, 1, 2)
	phase.Size = UDim2.fromOffset(260, 18)
	phase.BackgroundTransparency = 1
	phase.Font = Enum.Font.SourceSansBold
	phase.TextSize = 14
	phase.TextColor3 = MUTED
	phase.Text = ""
	phase.Parent = bar
	self.phase = phase

	-- ซิลเวอร์: ไม่มีกล่องบนจอแล้ว (ผู้ใช้สั่ง 2026-09-26 เฟส 1) ดูได้ในร้าน (B / 🛒)

	--------------------------------------------------------------------------
	-- ใครยังยืนอยู่ — จุดต่อหนึ่งคน สองแถวซ้าย/ขวาใต้แถบสกอร์
	--------------------------------------------------------------------------
	self.dots = {}
	for _, side in ipairs(ArenaConfig.TeamOrder) do
		local holder = Instance.new("Frame")
		holder.Name = "Alive" .. side
		holder.AnchorPoint = Vector2.new(side == "A" and 1 or 0, 0)
		holder.Position = UDim2.new(0.5, side == "A" and -140 or 140, 0, 16)
		holder.Size = UDim2.fromOffset(110, 20)
		holder.BackgroundTransparency = 1
		holder.Parent = gui

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = side == "A" and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
		layout.Padding = UDim.new(0, 6)
		layout.Parent = holder
		self.dots[side] = holder
	end

	-- ป้ายประกาศกลางจอ (ผลรอบ/เตรียมตัว/คุณตายแล้ว) ถูกถอดออก (ผู้ใช้สั่ง 2026-09-26 เฟส 1) —
	-- ผลรอบดูจากแถบคะแนน · ป้ายคิล FIRST BLOOD/ACE อยู่ที่ KillBannerGui ไม่เกี่ยวกับตรงนี้

	--------------------------------------------------------------------------
	-- ตอนตายแล้วดูเพื่อน (ผู้ใช้สั่ง 2026-09-24)
	--------------------------------------------------------------------------
	-- แถบล่างกลาง: กำลังดูใคร + ปุ่มสลับ (ปุ่มกดได้ด้วย มือถือไม่มีคีย์ Q/E)
	-- ลูกศรใช้ "<" ">" ตัวอักษร ASCII ธรรมดา — ฟอนต์ Roblox วาดได้ (ที่วาดไม่ได้คือสัญลักษณ์อย่าง ◀ ▶)
	local spec = Instance.new("Frame")
	spec.Name = "Spectate"
	spec.AnchorPoint = Vector2.new(0.5, 1)
	spec.Position = UDim2.new(0.5, 0, 1, -110)
	spec.Size = UDim2.fromOffset(420, 46)
	spec.BackgroundColor3 = DIM
	spec.BackgroundTransparency = 0.2
	spec.BorderSizePixel = 0
	spec.Visible = false
	spec.Parent = gui
	corner(spec, UDim.new(0, 10))
	self.spectate = spec

	local function arrow(text, anchorX, x)
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(anchorX, 0.5)
		b.Position = UDim2.new(anchorX, x, 0.5, 0)
		b.Size = UDim2.fromOffset(40, 36)
		b.BackgroundColor3 = Color3.fromRGB(60, 60, 66)
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 24
		b.TextColor3 = TEXT
		b.Text = text
		b.Parent = spec
		corner(b, UDim.new(0, 8))
		return b
	end
	self.specPrev = arrow("<", 0, 5)
	self.specNext = arrow(">", 1, -5)

	local who = Instance.new("TextLabel")
	who.AnchorPoint = Vector2.new(0.5, 0.5)
	who.Position = UDim2.fromScale(0.5, 0.5)
	who.Size = UDim2.new(1, -110, 1, 0)
	who.BackgroundTransparency = 1
	who.Font = Enum.Font.SourceSansBold
	who.TextSize = 20
	who.TextColor3 = TEXT
	who.TextTruncate = Enum.TextTruncate.AtEnd
	who.Parent = spec
	self.specName = who

	-- การ์ดขวาจอ: ดาเมจที่เราทำใส่ศัตรูแต่ละคนในรอบนี้
	local cards = Instance.new("Frame")
	cards.Name = "DamageCards"
	cards.AnchorPoint = Vector2.new(1, 0.5)
	cards.Position = UDim2.new(1, -16, 0.5, 0)
	cards.Size = UDim2.fromOffset(230, 260)
	cards.BackgroundTransparency = 1
	cards.Visible = false
	cards.Parent = gui
	-- มือถือ: ขวากลางคือกองปุ่มสนาม (DisplayOrder 21 อยู่เหนือการ์ด) → ย้ายไปซ้าย (ตายอยู่ ไม่ได้ใช้จอยเดิน)
	-- และย่อตามจอ — 260 px เต็มๆ คือ 70% ความสูงจอมือถือแนวนอน (QA 2026-09-26)
	local Responsive = require(script.Parent.Responsive)
	Responsive.Scale(cards, 0.55)
	if Responsive.IsTouchOnly() then
		cards.AnchorPoint = Vector2.new(0, 0.5)
		cards.Position = UDim2.new(0, 16, 0.5, 0)
	end
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = cards
	self.cards = cards

	return self
end

function ArenaHudGui:OnSpectateStep(callback)
	self.specPrev.MouseButton1Click:Connect(function() callback(-1) end)
	self.specNext.MouseButton1Click:Connect(function() callback(1) end)
end

-- name = nil → ซ่อนแถบ
function ArenaHudGui:SetSpectating(name, count)
	self.spectate.Visible = name ~= nil
	if name then
		self.specName.Text = ("กำลังดู: %s"):format(name)
		self.specPrev.Visible = (count or 0) > 1
		self.specNext.Visible = (count or 0) > 1
	end
end

-- `dealt` = { { name, damage, alive } } จาก snapshot · nil = ซ่อน
function ArenaHudGui:SetDamageCards(dealt)
	for _, child in ipairs(self.cards:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	self.cards.Visible = dealt ~= nil
	if not dealt then return end

	local header = Instance.new("Frame")
	header.LayoutOrder = 0
	header.Size = UDim2.new(1, 0, 0, 26)
	header.BackgroundTransparency = 1
	header.Parent = self.cards
	local h = Instance.new("TextLabel")
	h.Size = UDim2.fromScale(1, 1)
	h.BackgroundTransparency = 1
	h.Font = Enum.Font.GothamBold
	h.TextSize = 16
	h.TextColor3 = MUTED
	h.TextXAlignment = Enum.TextXAlignment.Right
	h.Text = "ดาเมจของคุณรอบนี้"
	h.Parent = header

	for i, row in ipairs(dealt) do
		local card = Instance.new("Frame")
		card.LayoutOrder = i
		card.Size = UDim2.new(1, 0, 0, 52)
		card.BackgroundColor3 = DIM
		card.BackgroundTransparency = row.alive and 0.2 or 0.5
		card.BorderSizePixel = 0
		card.Parent = self.cards
		corner(card, UDim.new(0, 8))
		-- แถบสีซ้าย = ทำดาเมจใส่คนนี้ไปแล้วหรือยัง
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(0, 5, 1, 0)
		stripe.BackgroundColor3 = row.damage > 0 and Color3.fromRGB(230, 120, 112) or Color3.fromRGB(90, 90, 96)
		stripe.BorderSizePixel = 0
		stripe.Parent = card

		local name = Instance.new("TextLabel")
		name.Position = UDim2.fromOffset(14, 4)
		name.Size = UDim2.new(1, -24, 0, 22)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.SourceSansBold
		name.TextSize = 18
		name.TextColor3 = row.alive and TEXT or MUTED
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = row.name .. (row.alive and "" or "  · ตายแล้ว")
		name.Parent = card

		local amount = Instance.new("TextLabel")
		amount.Position = UDim2.fromOffset(14, 26)
		amount.Size = UDim2.new(1, -24, 0, 22)
		amount.BackgroundTransparency = 1
		amount.Font = Enum.Font.GothamBold
		amount.TextSize = 18
		amount.TextColor3 = row.damage > 0 and Color3.fromRGB(240, 150, 140) or MUTED
		amount.TextXAlignment = Enum.TextXAlignment.Left
		amount.Text = ("ดาเมจ %d"):format(row.damage)
		amount.Parent = card
	end
end

function ArenaHudGui:SetVisible(visible)
	self.gui.Enabled = visible and true or false
end

function ArenaHudGui:Render(snap)
	self.scoreA.Text = tostring((snap.wins and snap.wins.A) or 0)
	self.scoreB.Text = tostring((snap.wins and snap.wins.B) or 0)

	local secs = snap.secondsLeft or 0
	self.timer.Text = ("%d:%02d"):format(math.floor(secs / 60), secs % 60)
	self.phase.Text = ("รอบ %d · %s · %s"):format(snap.round or 0,
		PHASE_TEXT[snap.phase] or snap.phase or "", snap.mapName or "")

	-- จุดคนเป็น/คนตาย: วาดใหม่ทั้งแถวทุกครั้ง (หกจุด ไม่ใช่หกร้อย)
	for _, side in ipairs(ArenaConfig.TeamOrder) do
		local holder = self.dots[side]
		for _, child in ipairs(holder:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		local order = 0
		for _, member in ipairs(snap.roster or {}) do
			if member.side == side then
				order += 1
				local dot = Instance.new("Frame")
				dot.LayoutOrder = order
				dot.Size = UDim2.fromOffset(14, 14)
				dot.BackgroundColor3 = member.alive and ArenaConfig.Teams[side].colour
					or Color3.fromRGB(70, 70, 74)
				dot.BackgroundTransparency = member.alive and 0 or 0.25
				dot.BorderSizePixel = 0
				dot.Parent = holder
				corner(dot, UDim.new(1, 0))
				-- คนที่เป็นเรา มีขอบให้รู้ว่าอันไหนคือตัวเอง · บอทมีจุดเล็กกว่าตรงกลาง
				if member.me then
					local ring = Instance.new("UIStroke")
					ring.Thickness = 2
					ring.Color = Color3.fromRGB(255, 255, 255)
					ring.Parent = dot
				end
				if member.bot then
					local pip = Instance.new("Frame")
					pip.AnchorPoint = Vector2.new(0.5, 0.5)
					pip.Position = UDim2.fromScale(0.5, 0.5)
					pip.Size = UDim2.fromOffset(8, 8)
					pip.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
					pip.BorderSizePixel = 0
					pip.Parent = dot
					corner(pip, UDim.new(1, 0))
				end
			end
		end
	end
end

return ArenaHudGui
