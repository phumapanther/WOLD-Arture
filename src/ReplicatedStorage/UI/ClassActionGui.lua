-- ClassActionGui: the small windows the class actions need.
--
-- Three of them: a box to type an amount into, a choice of heal size, and the countdown a robbery victim
-- gets to defend themselves. Plus a one-line notice for every result.
--
-- Pure builder, like the rest: it collects an answer and hands it back through a callback. What the answer
-- means is the server's business.
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local NumberBox = require(script.Parent.NumberBox) -- พิมพ์เกินที่มี = เด้งเป็นเลขสูงสุด (2026-10-02)
local UiSound = require(script.Parent.UiSound)
local Locale = require(script.Parent.Parent.Locale)
local L, Show = Locale.L, Locale.Show -- ข้อความผลลัพธ์/คำถามมาจากเซิร์ฟเป็นไทย แปลตอนวาด

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
local RUNE = Color3.fromRGB(244, 197, 66)
local DANGER = Color3.fromRGB(214, 84, 74)
local GOOD = Color3.fromRGB(120, 190, 120)

local ClassActionGui = {}
ClassActionGui.__index = ClassActionGui

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

local function stroke(inst, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency or 0.5
	s.Thickness = thickness or 1
	s.Parent = inst
	return s
end

local function button(parent, text, color)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color or STONE_DEEP
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = TEXT_LIGHT
	b.Text = text
	b.Parent = parent
	corner(b, UDim.new(0, 8))
	b.Activated:Connect(function() UiSound.Play("Click") end)
	return b
end

function ClassActionGui.new()
	local self = setmetatable({}, ClassActionGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "ClassActionGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 19 -- above the bag, below the downed overlay
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	-- A single panel reused by all three dialogs: only one can be open at a time anyway, and rebuilding its
	-- contents is cheaper than keeping three around.
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.42)
	panel.Size = UDim2.fromOffset(300, 180)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	corner(panel, UDim.new(0, 12))
	stroke(panel, RUNE, 0.55, 2)
	Responsive.Scale(panel)
	self.panel = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 28)
	title.Position = UDim2.new(0, 10, 0, 12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = RUNE
	title.Text = ""
	title.Parent = panel
	self.title = title

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.new(0, 10, 0, 46)
	body.Size = UDim2.new(1, -20, 1, -58)
	body.BackgroundTransparency = 1
	body.Parent = panel
	self.body = body

	-- The result line, bottom-centre and self-clearing. Separate from the panel so a notice can appear while
	-- nothing is open.
	local notice = Instance.new("TextLabel")
	notice.AnchorPoint = Vector2.new(0.5, 1)
	notice.Position = UDim2.new(0.5, 0, 1, -140)
	notice.Size = UDim2.fromOffset(340, 28)
	notice.BackgroundColor3 = STONE_DEEP
	notice.BackgroundTransparency = 0.15
	notice.Font = Enum.Font.GothamMedium
	notice.TextSize = 13
	notice.TextColor3 = TEXT_LIGHT
	notice.Text = ""
	notice.Visible = false
	notice.Parent = gui
	corner(notice, UDim.new(0, 8))
	Responsive.Scale(notice)
	self.notice = notice
	self.noticeToken = 0

	return self
end

function ClassActionGui:clearBody()
	for _, child in ipairs(self.body:GetChildren()) do
		child:Destroy()
	end
end

function ClassActionGui:Close()
	self.panel.Visible = false
	self:clearBody()
end

--------------------------------------------------------------------------------
-- Type an amount
--------------------------------------------------------------------------------

function ClassActionGui:AskAmount(target, onSend, max)
	self:clearBody()
	self.title.Text = L("ให้เงิน %s"):format(target.DisplayName)
	self.panel.Size = UDim2.fromOffset(300, 180)

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 40)
	box.BackgroundColor3 = STONE_DEEP
	box.BorderSizePixel = 0
	box.Font = Enum.Font.GothamBold
	box.TextSize = 18
	box.TextColor3 = TEXT_LIGHT
	box.PlaceholderText = L("จำนวนเงิน")
	box.PlaceholderColor3 = TEXT_MUTED
	box.Text = ""
	box.ClearTextOnFocus = false
	box.Parent = self.body
	NumberBox.Bind(box, function() return max end)
	corner(box, UDim.new(0, 8))

	local send = button(self.body, L("ส่ง"), Color3.fromRGB(58, 78, 56))
	send.Size = UDim2.new(0.5, -4, 0, 36)
	send.Position = UDim2.new(0, 0, 1, -44)

	local cancel = button(self.body, L("ยกเลิก"))
	cancel.Size = UDim2.new(0.5, -4, 0, 36)
	cancel.Position = UDim2.new(0.5, 4, 1, -44)

	send.Activated:Connect(function()
		-- Parsed here only to avoid sending obvious nonsense; the server checks it properly.
		local amount = tonumber(box.Text)
		self:Close()
		if amount then onSend(math.floor(amount)) end
	end)
	cancel.Activated:Connect(function() self:Close() end)

	self.panel.Visible = true
	box:CaptureFocus()
end

--------------------------------------------------------------------------------
-- Choose a heal
--------------------------------------------------------------------------------

function ClassActionGui:AskHealSize(target, onChoose)
	self:clearBody()
	self.title.Text = L("ฮีล %s"):format(target.DisplayName)
	self.panel.Size = UDim2.fromOffset(300, 190)

	local ClassActionConfig = require(script.Parent.Parent.ClassActionConfig)
	local order = { "small", "large" }
	for i, size in ipairs(order) do
		local option = ClassActionConfig.Heal[size]
		local b = button(self.body, L("%s — %d ทอง", option.label, option.cost))
		b.Size = UDim2.new(1, 0, 0, 40)
		b.Position = UDim2.new(0, 0, 0, (i - 1) * 48)
		b.Activated:Connect(function()
			self:Close()
			onChoose(size)
		end)
	end

	local cancel = button(self.body, L("ยกเลิก"))
	cancel.Size = UDim2.new(1, 0, 0, 34)
	cancel.Position = UDim2.new(0, 0, 1, -34)
	cancel.Activated:Connect(function() self:Close() end)

	self.panel.Visible = true
end

--------------------------------------------------------------------------------
-- Defend against a robbery
--------------------------------------------------------------------------------

function ClassActionGui:ShowRobDefence(thief, seconds, onDefend)
	self:clearBody()
	self.title.Text = L("โดนปล้น!")
	self.panel.Size = UDim2.fromOffset(320, 180)

	local who = Instance.new("TextLabel")
	who.Size = UDim2.new(1, 0, 0, 22)
	who.BackgroundTransparency = 1
	who.Font = Enum.Font.Gotham
	who.TextSize = 13
	who.TextColor3 = TEXT_LIGHT
	who.Text = L("%s กำลังปล้นคุณ"):format(thief and thief.DisplayName or L("ใครบางคน"))
	who.Parent = self.body

	local count = Instance.new("TextLabel")
	count.Size = UDim2.new(1, 0, 0, 40)
	count.Position = UDim2.new(0, 0, 0, 26)
	count.BackgroundTransparency = 1
	count.Font = Enum.Font.GothamBold
	count.TextSize = 30
	count.TextColor3 = DANGER
	count.Text = tostring(seconds)
	count.Parent = self.body

	local defend = button(self.body, L("ป้องกัน!"), Color3.fromRGB(96, 52, 48))
	defend.Size = UDim2.new(1, 0, 0, 40)
	defend.Position = UDim2.new(0, 0, 1, -44)

	-- A token so a second robbery cannot be answered by the first one's countdown.
	self.robToken = (self.robToken or 0) + 1
	local token = self.robToken
	local answered = false

	defend.Activated:Connect(function()
		if answered then return end
		answered = true
		self:Close()
		onDefend()
	end)

	self.panel.Visible = true
	task.spawn(function()
		for remaining = seconds, 1, -1 do
			if self.robToken ~= token or answered then return end
			count.Text = tostring(remaining)
			task.wait(1)
		end
		-- Ran out: the server has already decided, so this only takes the window away.
		if self.robToken == token and not answered then self:Close() end
	end)
end

--------------------------------------------------------------------------------
-- Agree or refuse
--------------------------------------------------------------------------------

-- Someone is asking to do something TO you that needs your say-so: being picked up, and later a trade.
-- Written generally rather than as a carry window, since the shape is the same either way -- a question,
-- two buttons, and a clock that answers "no" for you if you ignore it.
function ClassActionGui:AskConsent(fromPlayer, seconds, question, onAnswer)
	self:clearBody()
	self.title.Text = L("คำขอ")
	self.panel.Size = UDim2.fromOffset(320, 190)

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 0, 46)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Gotham
	text.TextSize = 14
	text.TextWrapped = true
	text.TextColor3 = TEXT_LIGHT
	text.Text = Show(question) -- คำถามฮีล/ซ่อมเขียนมาจากเซิร์ฟ · ที่ไคลเอนต์แปลแล้ว Show คืนเดิม
	text.Parent = self.body

	local clock = Instance.new("TextLabel")
	clock.Size = UDim2.new(1, 0, 0, 26)
	clock.Position = UDim2.new(0, 0, 0, 50)
	clock.BackgroundTransparency = 1
	clock.Font = Enum.Font.GothamBold
	clock.TextSize = 18
	clock.TextColor3 = TEXT_MUTED
	clock.Text = tostring(seconds)
	clock.Parent = self.body

	local yes = button(self.body, L("ยินยอม"), Color3.fromRGB(58, 78, 56))
	yes.Size = UDim2.new(0.5, -4, 0, 40)
	yes.Position = UDim2.new(0, 0, 1, -44)

	local no = button(self.body, L("ปฏิเสธ"), Color3.fromRGB(96, 52, 48))
	no.Size = UDim2.new(0.5, -4, 0, 40)
	no.Position = UDim2.new(0.5, 4, 1, -44)

	-- A token so a second request cannot be answered by the first ones countdown, and so answering twice
	-- sends only one reply.
	self.consentToken = (self.consentToken or 0) + 1
	local token = self.consentToken
	local answered = false
	local function answer(accepted)
		if answered or self.consentToken ~= token then return end
		answered = true
		self:Close()
		onAnswer(accepted)
	end

	yes.Activated:Connect(function() answer(true) end)
	no.Activated:Connect(function() answer(false) end)

	self.panel.Visible = true
	task.spawn(function()
		for remaining = seconds, 1, -1 do
			if self.consentToken ~= token or answered then return end
			clock.Text = tostring(remaining)
			task.wait(1)
		end
		-- Ignoring the question is a refusal: the server has already given up on it by now, and leaving the
		-- window open would let a stale yes arrive after the fact.
		answer(false)
	end)
end

--------------------------------------------------------------------------------
-- Result line
--------------------------------------------------------------------------------

function ClassActionGui:Notify(ok, message, other)
	if not message or message == "" then return end
	self.noticeToken += 1
	local token = self.noticeToken

	local text = Show(message) -- ข้อความผลลัพธ์เป็นไทยจากเซิร์ฟ (ClassActions/เทรด/จับกุม)
	self.notice.Text = other and ("%s — %s"):format(text, other.DisplayName) or text
	self.notice.TextColor3 = ok and GOOD or DANGER
	self.notice.Visible = true

	task.delay(4, function()
		if self.noticeToken == token then self.notice.Visible = false end
	end)
end

return ClassActionGui
