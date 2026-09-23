-- ArenaHudGui: แถบบนของสนาม PVP — สกอร์รอบ เวลาที่เหลือของเฟส ซิลเวอร์ และใครยังยืนอยู่บ้าง
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
	local bar = Instance.new("Frame")
	bar.Name = "ScoreBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 8)
	bar.Size = UDim2.fromOffset(420, 64)
	bar.BackgroundColor3 = DIM
	bar.BackgroundTransparency = 0.25
	bar.BorderSizePixel = 0
	bar.Parent = gui
	corner(bar, UDim.new(0, 10))

	local function scoreBox(side, anchorX, x)
		local box = Instance.new("TextLabel")
		box.AnchorPoint = Vector2.new(anchorX, 0.5)
		box.Position = UDim2.new(anchorX, x, 0.5, 0)
		box.Size = UDim2.fromOffset(86, 48)
		box.BackgroundColor3 = ArenaConfig.Teams[side].colour
		box.BorderSizePixel = 0
		box.Font = Enum.Font.GothamBold
		box.TextSize = 30
		box.TextColor3 = Color3.fromRGB(20, 20, 20)
		box.Text = "0"
		box.Parent = bar
		corner(box, UDim.new(0, 8))
		return box
	end
	self.scoreA = scoreBox("A", 0, 10)
	self.scoreB = scoreBox("B", 1, -10)

	local middle = Instance.new("TextLabel")
	middle.AnchorPoint = Vector2.new(0.5, 0.5)
	middle.Position = UDim2.fromScale(0.5, 0.5)
	middle.Size = UDim2.fromOffset(220, 56)
	middle.BackgroundTransparency = 1
	middle.Font = Enum.Font.GothamBold
	middle.TextSize = 26
	middle.TextColor3 = TEXT
	middle.Text = "0:00"
	middle.Parent = bar
	self.timer = middle

	local phase = Instance.new("TextLabel")
	phase.AnchorPoint = Vector2.new(0.5, 0)
	phase.Position = UDim2.new(0.5, 0, 1, 2)
	phase.Size = UDim2.fromOffset(420, 22)
	phase.BackgroundTransparency = 1
	phase.Font = Enum.Font.SourceSansBold
	phase.TextSize = 18
	phase.TextColor3 = MUTED
	phase.Text = ""
	phase.Parent = bar
	self.phase = phase

	--------------------------------------------------------------------------
	-- ซิลเวอร์ (มุมซ้ายล่าง เหนือหลอดเลือดของ HUD เกมหลัก)
	--------------------------------------------------------------------------
	local silver = Instance.new("TextLabel")
	silver.Name = "Silver"
	silver.AnchorPoint = Vector2.new(0, 1)
	silver.Position = UDim2.new(0, 16, 1, -150)
	silver.Size = UDim2.fromOffset(190, 40)
	silver.BackgroundColor3 = DIM
	silver.BackgroundTransparency = 0.25
	silver.BorderSizePixel = 0
	silver.Font = Enum.Font.GothamBold
	silver.TextSize = 20
	silver.TextColor3 = Color3.fromRGB(226, 184, 78)
	silver.Text = "0"
	silver.Parent = gui
	corner(silver, UDim.new(0, 8))
	self.silver = silver

	--------------------------------------------------------------------------
	-- ใครยังยืนอยู่ — จุดต่อหนึ่งคน สองแถวซ้าย/ขวาใต้แถบสกอร์
	--------------------------------------------------------------------------
	self.dots = {}
	for _, side in ipairs(ArenaConfig.TeamOrder) do
		local holder = Instance.new("Frame")
		holder.Name = "Alive" .. side
		holder.AnchorPoint = Vector2.new(side == "A" and 1 or 0, 0)
		holder.Position = UDim2.new(0.5, side == "A" and -224 or 224, 0, 20)
		holder.Size = UDim2.fromOffset(160, 30)
		holder.BackgroundTransparency = 1
		holder.Parent = gui

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = side == "A" and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
		layout.Padding = UDim.new(0, 6)
		layout.Parent = holder
		self.dots[side] = holder
	end

	--------------------------------------------------------------------------
	-- ป้ายประกาศกลางจอ (ผลของรอบ)
	--------------------------------------------------------------------------
	local banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.3)
	banner.Size = UDim2.fromOffset(620, 64)
	banner.BackgroundTransparency = 1
	banner.Font = Enum.Font.GothamBold
	banner.TextSize = 40
	banner.TextStrokeTransparency = 0.4
	banner.TextColor3 = TEXT
	banner.Text = ""
	banner.Visible = false
	banner.Parent = gui
	self.banner = banner

	return self
end

function ArenaHudGui:SetVisible(visible)
	self.gui.Enabled = visible and true or false
end

function ArenaHudGui:SetBanner(text, colour)
	self.banner.Text = text or ""
	self.banner.TextColor3 = colour or TEXT
	self.banner.Visible = (text ~= nil and text ~= "")
end

function ArenaHudGui:Render(snap)
	self.scoreA.Text = tostring((snap.wins and snap.wins.A) or 0)
	self.scoreB.Text = tostring((snap.wins and snap.wins.B) or 0)

	local secs = snap.secondsLeft or 0
	self.timer.Text = ("%d:%02d"):format(math.floor(secs / 60), secs % 60)
	self.phase.Text = ("รอบ %d · %s · %s"):format(snap.round or 0,
		PHASE_TEXT[snap.phase] or snap.phase or "", snap.mapName or "")
	self.silver.Text = ("ซิลเวอร์  %d"):format(snap.silver or 0)

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
				dot.Size = UDim2.fromOffset(20, 20)
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
