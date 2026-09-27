-- StoryGui: หน้าจอของเนื้อเรื่อง (ผู้มากับแสงวิบวับ) — วาดอย่างเดียว ไม่รู้จัก remote (StoryController ต่อสาย)
--
-- ชิ้นในจอเดียว `WOLD_Story` (อยู่ใน KEEP ของ PhotoMode — คัทซีนใช้ PhotoMode ซ่อน UI อื่นทั้งหมด):
--   tracker   ป้ายเควสมุมขวา (ใต้ปุ่มมุม) "📜 ชื่อบท 2/5" + เป้าหมาย · แตะเพื่อย่อ/ขยาย
--   dialogue  กล่องคุยล่างจอ: ชื่อคนพูด + ข้อความพิมพ์ทีละตัว · แตะ/คลิก/Space = ข้าม/ไปต่อ
--   cinema    แถบดำบน-ล่างของคัทซีน + คำบรรยาย + ปุ่มข้าม + จอดำ/แสงวาบ + ป้ายชื่อเกม
--   memory    จอขาวซีดกะพริบของภาพความทรงจำ
--   banner    ป้ายจบบท (รางวัล + ฉายา)
-- ⚠️ ไม่ใช้สัญลักษณ์ตัวอักษร ▶ ✦ (ฟอนต์ Roblox วาดเป็นกล่องเปล่า) — ใช้อีโมจิสีหรือ Frame
local TweenService = game:GetService("TweenService")
local Responsive = require(script.Parent.Responsive)
local StoryConfig = require(script.Parent.Parent.StoryConfig)

local StoryGui = {}
StoryGui.__index = StoryGui

local rgb = Color3.fromRGB
local PANEL = rgb(20, 22, 30)
local GOLD = rgb(232, 196, 110)
local RUNE = rgb(126, 214, 232)
local TEXT = rgb(240, 236, 226)
local MUTED = rgb(160, 162, 176)
local TYPE_SPEED = 45 -- ตัวอักษรต่อวินาที

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = p
end
local function stroke(p, color, t, thick)
	local s = Instance.new("UIStroke")
	s.Color, s.Transparency, s.Thickness = color, t or 0, thick or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
end
local function label(parent, text, size, color, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size
	l.TextColor3 = color or TEXT
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.RichText = false
	l.Text = text or ""
	l.Parent = parent
	return l
end
local function full(parent, name, color, transparency, z)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Visible = false
	f.Parent = parent
	return f
end

function StoryGui.new(parent)
	local self = setmetatable({ queue = {}, collapsed = false }, StoryGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "WOLD_Story"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 900
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui.Parent = parent
	self.gui = gui

	----------------------------------------------------------------- tracker
	local trackerHolder = Instance.new("Frame")
	trackerHolder.AnchorPoint = Vector2.new(1, 0)
	trackerHolder.Position = UDim2.new(1, -12, 0, 150)
	trackerHolder.Size = UDim2.fromOffset(260, 64)
	trackerHolder.BackgroundTransparency = 1
	trackerHolder.Visible = false
	trackerHolder.Parent = gui
	Responsive.Scale(trackerHolder, 0.7)
	local tracker = Instance.new("TextButton")
	tracker.AutoButtonColor = false
	tracker.Text = ""
	tracker.Size = UDim2.fromScale(1, 1)
	tracker.BackgroundColor3 = PANEL
	tracker.BackgroundTransparency = 0.2
	tracker.ZIndex = 2
	tracker.Parent = trackerHolder
	corner(tracker, 10)
	stroke(tracker, GOLD, 0.5, 1)
	self.trackerTitle = label(tracker, "", 14, GOLD)
	self.trackerTitle.Font = Enum.Font.GothamBold
	self.trackerTitle.Position = UDim2.fromOffset(10, 6)
	self.trackerTitle.Size = UDim2.new(1, -20, 0, 18)
	self.trackerTitle.TextWrapped = false
	self.trackerTitle.TextTruncate = Enum.TextTruncate.AtEnd
	self.trackerTitle.ZIndex = 3
	self.trackerGoal = label(tracker, "", 13, TEXT)
	self.trackerGoal.Position = UDim2.fromOffset(10, 26)
	self.trackerGoal.Size = UDim2.new(1, -20, 0, 34)
	self.trackerGoal.ZIndex = 3
	tracker.Activated:Connect(function()
		self.collapsed = not self.collapsed
		self.trackerGoal.Visible = not self.collapsed
		trackerHolder.Size = UDim2.fromOffset(260, self.collapsed and 30 or 64)
	end)
	self.tracker = trackerHolder

	----------------------------------------------------------------- dialogue
	local dialogue = Instance.new("TextButton")
	dialogue.Name = "Dialogue"
	dialogue.AutoButtonColor = false
	dialogue.Text = ""
	dialogue.AnchorPoint = Vector2.new(0.5, 1)
	dialogue.Position = UDim2.new(0.5, 0, 1, -28)
	dialogue.Size = UDim2.fromOffset(760, 150)
	dialogue.BackgroundColor3 = PANEL
	dialogue.BackgroundTransparency = 0.08
	dialogue.Visible = false
	dialogue.ZIndex = 20
	dialogue.Parent = gui
	corner(dialogue, 14)
	stroke(dialogue, RUNE, 0.35, 1.5)
	Responsive.Scale(dialogue, 0.55)
	local nameplate = Instance.new("Frame")
	nameplate.Position = UDim2.fromOffset(18, -16)
	nameplate.Size = UDim2.fromOffset(170, 32)
	nameplate.BackgroundColor3 = rgb(36, 40, 54)
	nameplate.ZIndex = 21
	nameplate.Parent = dialogue
	corner(nameplate, 8)
	stroke(nameplate, RUNE, 0.2, 1)
	self.speaker = label(nameplate, "", 16, RUNE, Enum.TextXAlignment.Center)
	self.speaker.Font = Enum.Font.GothamBold
	self.speaker.TextYAlignment = Enum.TextYAlignment.Center
	self.speaker.Size = UDim2.fromScale(1, 1)
	self.speaker.ZIndex = 22
	self.nameplate = nameplate
	self.line = label(dialogue, "", 20, TEXT)
	self.line.Position = UDim2.fromOffset(24, 26)
	self.line.Size = UDim2.new(1, -48, 1, -56)
	self.line.ZIndex = 21
	local hint = label(dialogue, "แตะ / คลิก เพื่อไปต่อ", 12, MUTED, Enum.TextXAlignment.Right)
	hint.AnchorPoint = Vector2.new(1, 1)
	hint.Position = UDim2.new(1, -16, 1, -8)
	hint.Size = UDim2.fromOffset(240, 16)
	hint.ZIndex = 21
	dialogue.Activated:Connect(function() self:Next() end)
	self.dialogue = dialogue

	----------------------------------------------------------------- cinema
	local cinema = Instance.new("Frame")
	cinema.Name = "Cinema"
	cinema.Size = UDim2.fromScale(1, 1)
	cinema.BackgroundTransparency = 1
	cinema.Visible = false
	cinema.ZIndex = 30
	cinema.Parent = gui
	self.cinema = cinema
	self.black = full(cinema, "Black", rgb(0, 0, 0), 0, 31)
	self.flash = full(cinema, "Flash", rgb(255, 255, 255), 0, 38)
	for _, top in ipairs({ true, false }) do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0, top and 0 or 1)
		bar.Position = UDim2.fromScale(0, top and 0 or 1)
		bar.Size = UDim2.new(1, 0, 0.11, 0)
		bar.BackgroundColor3 = rgb(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.ZIndex = 32
		bar.Parent = cinema
	end
	self.caption = label(cinema, "", 22, TEXT, Enum.TextXAlignment.Center)
	self.caption.AnchorPoint = Vector2.new(0.5, 1)
	self.caption.Position = UDim2.new(0.5, 0, 1, -18)
	self.caption.Size = UDim2.new(0.86, 0, 0.09, 0)
	self.caption.TextYAlignment = Enum.TextYAlignment.Center
	self.caption.TextScaled = true
	self.caption.ZIndex = 40
	local capLimit = Instance.new("UITextSizeConstraint")
	capLimit.MaxTextSize = 26
	capLimit.MinTextSize = 12
	capLimit.Parent = self.caption
	self.title = label(cinema, "", 64, GOLD, Enum.TextXAlignment.Center)
	self.title.Font = Enum.Font.GothamBlack
	self.title.AnchorPoint = Vector2.new(0.5, 0.5)
	self.title.Position = UDim2.fromScale(0.5, 0.44)
	self.title.Size = UDim2.new(0.9, 0, 0.14, 0)
	self.title.TextScaled = true
	self.title.TextYAlignment = Enum.TextYAlignment.Center
	self.title.ZIndex = 41
	self.title.Visible = false
	self.subtitle = label(cinema, "", 26, TEXT, Enum.TextXAlignment.Center)
	self.subtitle.AnchorPoint = Vector2.new(0.5, 0)
	self.subtitle.Position = UDim2.fromScale(0.5, 0.52)
	self.subtitle.Size = UDim2.new(0.8, 0, 0.06, 0)
	self.subtitle.TextScaled = true
	self.subtitle.ZIndex = 41
	self.subtitle.Visible = false
	local skip = Instance.new("TextButton")
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.new(1, -18, 0.11, 10)
	skip.Size = UDim2.fromOffset(96, 36)
	skip.BackgroundColor3 = rgb(30, 32, 40)
	skip.BackgroundTransparency = 0.2
	skip.Font = Enum.Font.GothamBold
	skip.TextSize = 16
	skip.TextColor3 = TEXT
	skip.Text = "ข้าม"
	skip.ZIndex = 45
	skip.Parent = cinema
	corner(skip, 18)
	stroke(skip, TEXT, 0.6, 1)
	self.skipButton = skip
	-- ประกายเล็กๆ บนจอดำ (Frame กลม ไม่ใช่ตัวอักษร)
	self.motes = {}
	for i = 1, 14 do
		local m = Instance.new("Frame")
		m.AnchorPoint = Vector2.new(0.5, 0.5)
		m.Size = UDim2.fromOffset(6, 6)
		m.BackgroundColor3 = i % 3 == 0 and GOLD or RUNE
		m.BorderSizePixel = 0
		m.ZIndex = 33
		m.Visible = false
		m.Parent = cinema
		corner(m, 3)
		self.motes[i] = m
	end

	----------------------------------------------------------------- memory
	local memory = full(gui, "Memory", rgb(236, 240, 246), 0.15, 50)
	self.memoryText = label(memory, "", 28, rgb(60, 66, 84), Enum.TextXAlignment.Center)
	self.memoryText.Font = Enum.Font.GothamMedium
	self.memoryText.AnchorPoint = Vector2.new(0.5, 0.5)
	self.memoryText.Position = UDim2.fromScale(0.5, 0.5)
	self.memoryText.Size = UDim2.new(0.8, 0, 0.2, 0)
	self.memoryText.TextYAlignment = Enum.TextYAlignment.Center
	self.memoryText.TextScaled = true
	self.memoryText.ZIndex = 52
	local memLimit = Instance.new("UITextSizeConstraint")
	memLimit.MaxTextSize = 32
	memLimit.Parent = self.memoryText
	self.memory = memory

	----------------------------------------------------------------- banner
	local banner = Instance.new("Frame")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 110)
	banner.Size = UDim2.fromOffset(520, 112)
	banner.BackgroundColor3 = PANEL
	banner.BackgroundTransparency = 0.05
	banner.Visible = false
	banner.ZIndex = 60
	banner.Parent = gui
	corner(banner, 14)
	stroke(banner, GOLD, 0.1, 2)
	Responsive.Scale(banner, 0.6)
	self.bannerTitle = label(banner, "", 22, GOLD, Enum.TextXAlignment.Center)
	self.bannerTitle.Font = Enum.Font.GothamBold
	self.bannerTitle.Position = UDim2.fromOffset(10, 12)
	self.bannerTitle.Size = UDim2.new(1, -20, 0, 28)
	self.bannerTitle.ZIndex = 61
	self.bannerBody = label(banner, "", 16, TEXT, Enum.TextXAlignment.Center)
	self.bannerBody.Position = UDim2.fromOffset(10, 46)
	self.bannerBody.Size = UDim2.new(1, -20, 0, 56)
	self.bannerBody.ZIndex = 61
	self.banner = banner

	return self
end

--------------------------------------------------------------------------------
-- tracker
--------------------------------------------------------------------------------
function StoryGui:SetTracker(state)
	if not state or state.done or not state.chapter then
		self.tracker.Visible = false
		return
	end
	self.tracker.Visible = true
	self.trackerTitle.Text = ("📜 %s  %d/%d"):format(state.name or "", state.step or 1, state.steps or 1)
	local goal = state.goal or ""
	if state.need and state.need > 0 then goal = ("%s (%d/%d)"):format(goal, math.min(state.got or 0, state.need), state.need) end
	self.trackerGoal.Text = goal
end

--------------------------------------------------------------------------------
-- dialogue (คิว: บทพูดที่มาติดกันเล่นต่อกัน)
--------------------------------------------------------------------------------
function StoryGui:Say(lines, onDone)
	table.insert(self.queue, { lines = lines, onDone = onDone })
	if not self.current then self:_nextDialogue() end
end

function StoryGui:_nextDialogue()
	self.current = table.remove(self.queue, 1)
	if not self.current then
		self.dialogue.Visible = false
		return
	end
	self.index = 0
	self.dialogue.Visible = true
	self:Next()
end

function StoryGui:_show(line)
	local npc = line.who and StoryConfig.Npcs[line.who]
	self.nameplate.Visible = npc ~= nil
	self.speaker.Text = npc and npc.name or ""
	self.speaker.TextColor3 = npc and npc.color or RUNE
	self.line.Font = npc and Enum.Font.GothamMedium or Enum.Font.GothamMedium
	self.line.TextColor3 = npc and TEXT or rgb(206, 214, 232)
	self.line.Text = line.text or ""
	self.line.MaxVisibleGraphemes = 0
	self.typing = os.clock()
	local token = self.typing
	task.spawn(function()
		local total = utf8.len(self.line.Text) or #self.line.Text
		local started = os.clock()
		while self.typing == token do
			local n = math.floor((os.clock() - started) * TYPE_SPEED)
			if n >= total then
				self.line.MaxVisibleGraphemes = -1
				self.typing = nil
				break
			end
			self.line.MaxVisibleGraphemes = n
			task.wait()
		end
	end)
end

-- แตะหนึ่งครั้ง: กำลังพิมพ์ = โชว์ทั้งบรรทัด · พิมพ์จบแล้ว = บรรทัดถัดไป · หมดบท = ปิด (แล้วเล่นบทที่ต่อคิว)
function StoryGui:Next()
	local current = self.current
	if not current then return end
	if self.typing then
		self.typing = nil
		self.line.MaxVisibleGraphemes = -1
		return
	end
	self.index += 1
	local line = current.lines[self.index]
	if line then
		self:_show(line)
	else
		if current.onDone then task.spawn(current.onDone) end
		self:_nextDialogue()
	end
end

function StoryGui:IsTalking()
	return self.current ~= nil
end

--------------------------------------------------------------------------------
-- cinema
--------------------------------------------------------------------------------
function StoryGui:SetCinema(on)
	self.cinema.Visible = on
	if not on then
		self.black.Visible, self.flash.Visible = false, false
		self.title.Visible, self.subtitle.Visible = false, false
		for _, m in ipairs(self.motes) do m.Visible = false end
		self.caption.Text = ""
	end
end

function StoryGui:Caption(text, who)
	local npc = who and StoryConfig.Npcs[who]
	self.caption.Text = npc and (npc.name .. ": " .. (text or "")) or (text or "")
	self.caption.TextColor3 = npc and npc.color or TEXT
end

function StoryGui:Black(on, fadeSeconds)
	self.black.Visible = true
	self.black.BackgroundTransparency = on and 1 or 0
	TweenService:Create(self.black, TweenInfo.new(fadeSeconds or 0.6), { BackgroundTransparency = on and 0 or 1 }):Play()
	if not on then task.delay(fadeSeconds or 0.6, function() self.black.Visible = false end) end
end

-- ประกายลอยขึ้นบนจอดำ (beat แรก)
function StoryGui:Motes(on)
	for i, m in ipairs(self.motes) do
		m.Visible = on
		if on then
			m.Position = UDim2.fromScale(0.3 + math.random() * 0.4, 0.75 + math.random() * 0.2)
			m.BackgroundTransparency = 1
			local rise = TweenInfo.new(2.4 + math.random() * 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			task.delay(i * 0.12, function()
				if not m.Visible then return end
				TweenService:Create(m, rise, { Position = m.Position - UDim2.fromScale(0, 0.35 + math.random() * 0.2),
					BackgroundTransparency = 0.1 }):Play()
			end)
		end
	end
end

function StoryGui:Flash(seconds)
	self.flash.Visible = true
	self.flash.BackgroundTransparency = 1
	local half = (seconds or 1) / 2
	TweenService:Create(self.flash, TweenInfo.new(half * 0.4), { BackgroundTransparency = 0 }):Play()
	task.delay(half, function()
		TweenService:Create(self.flash, TweenInfo.new(half), { BackgroundTransparency = 1 }):Play()
	end)
	task.delay(seconds or 1, function() self.flash.Visible = false end)
end

function StoryGui:TitleCard(title, subtitle)
	self.title.Text, self.subtitle.Text = title or "", subtitle or ""
	self.title.Visible, self.subtitle.Visible = true, true
	self.title.TextTransparency, self.subtitle.TextTransparency = 1, 1
	TweenService:Create(self.title, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
	TweenService:Create(self.subtitle, TweenInfo.new(1.2), { TextTransparency = 0 }):Play()
end

--------------------------------------------------------------------------------
-- memory flash
--------------------------------------------------------------------------------
function StoryGui:Memory(beats, onDone)
	self.memory.Visible = true
	self.memory.BackgroundTransparency = 1
	TweenService:Create(self.memory, TweenInfo.new(0.5), { BackgroundTransparency = 0.12 }):Play()
	task.spawn(function()
		for _, beat in ipairs(beats or {}) do
			self.memoryText.Text = beat.text or ""
			self.memoryText.TextTransparency = 1
			TweenService:Create(self.memoryText, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
			-- ภาพกะพริบ: จอหรี่วาบสั้นๆ กลางช่วง
			task.delay((beat.seconds or 2) * 0.5, function()
				self.memory.BackgroundTransparency = 0.45
				task.wait(0.08)
				self.memory.BackgroundTransparency = 0.12
			end)
			task.wait(beat.seconds or 2)
		end
		TweenService:Create(self.memory, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(self.memoryText, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.6)
		self.memory.Visible = false
		if onDone then onDone() end
	end)
end

--------------------------------------------------------------------------------
-- banner
--------------------------------------------------------------------------------
function StoryGui:Banner(title, body, seconds)
	self.bannerTitle.Text, self.bannerBody.Text = title or "", body or ""
	self.banner.Visible = true
	self.banner.BackgroundTransparency = 1
	TweenService:Create(self.banner, TweenInfo.new(0.4), { BackgroundTransparency = 0.05 }):Play()
	local token = os.clock()
	self.bannerToken = token
	task.delay(seconds or 6, function()
		if self.bannerToken == token then self.banner.Visible = false end
	end)
end

return StoryGui
