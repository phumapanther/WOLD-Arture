-- FarmLevelController (เฟส 2c): ป้ายเลเวลฟาร์มมุมจอ + แบนเนอร์ฉลองเลเวลขึ้น (เกาะเท่านั้น · เจ้าของเกาะเท่านั้น)
--
--   ป้ายมุมซ้ายบน: `🌾 Lv5 ▓▓▓░ · 🚚 23:10` อ่านแอตทริบิวต์ที่เซิร์ฟตั้งบนตัวผู้เล่น (FarmLevel/FarmExpInto/
--   FarmExpNeed/FarmShipEnd) — แขกไม่มีแอตทริบิวต์พวกนี้ ป้ายจึงไม่ขึ้นเอง
--
--   แบนเนอร์: เซิร์ฟส่ง FarmCelebrate { from, to } → รอจอโหลดจบ (แอตทริบิวต์ท้องถิ่น `WOLD_Loaded`) → โชว์
--   เลเวลใหม่ + ไอคอนของที่ปลดทุกขั้นรวมกัน (ขึ้นรวดหลายเลเวล = แบนเนอร์เดียว) → ตอบ "seen" ให้เซิร์ฟจด + ยิงพลุ
--   ไม่ตอบ (ออกเกมก่อนเห็น) = เซิร์ฟส่งใหม่ครั้งหน้า ไม่หาย ไม่ซ้ำ · ไม่มีข้อความกลางจอ นอกจากแบนเนอร์นี้เอง
while workspace:GetAttribute("IsLobby") == nil do task.wait() end
if workspace:GetAttribute("IslandMode") ~= true then return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Remotes = require(ReplicatedStorage.Remotes)
local Responsive = require(ReplicatedStorage.UI.Responsive)
local UiSound = require(ReplicatedStorage.UI.UiSound)
local ItemIcon = require(ReplicatedStorage.UI.ItemIcon)
local FarmLevelConfig = require(ReplicatedStorage.FarmLevelConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RUNE = Color3.fromRGB(244, 197, 66)
local EXP = Color3.fromRGB(150, 220, 130)
local TEXT = Color3.fromRGB(236, 236, 240)
local MUTED = Color3.fromRGB(160, 162, 172)

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
end

--------------------------------------------------------------------------------
-- ป้ายมุมจอ
--------------------------------------------------------------------------------

local chipGui = Instance.new("ScreenGui")
chipGui.Name = "FarmLevelChip"
chipGui.ResetOnSpawn = false
chipGui.IgnoreGuiInset = true
chipGui.DisplayOrder = 6
chipGui.Enabled = false
chipGui.Parent = playerGui

-- กล่องมุมซ้ายบน ข้างปุ่มเมนู Roblox · **ขนาดคงที่ ไม่ย่อตามจอ** — UIScale ย่อจากมุมซ้ายบน ตำแหน่งจะหดเข้าไป
-- ทับปุ่มเมนูของ Roblox (ซึ่งไม่ย่อตาม) · ป้ายกว้าง 214 px พอดีทุกจอตั้งแต่มือถือ
local group = Instance.new("Frame")
group.BackgroundTransparency = 1
group.Position = UDim2.fromOffset(0, 0)
group.Size = UDim2.fromOffset(300, 60)
group.Parent = chipGui

local chip = Instance.new("Frame")
chip.Position = UDim2.fromOffset(62, 10)
chip.Size = UDim2.fromOffset(214, 34)
chip.BackgroundColor3 = Responsive.GlassColor
chip.BackgroundTransparency = Responsive.GlassTransparency
chip.BorderSizePixel = 0
chip.Parent = group
corner(chip, UDim.new(0, 17))
local chipStroke = Instance.new("UIStroke")
chipStroke.Color = RUNE
chipStroke.Transparency = 0.55
chipStroke.Thickness = 1.5
chipStroke.Parent = chip

local levelText = Instance.new("TextLabel")
levelText.BackgroundTransparency = 1
levelText.Position = UDim2.fromOffset(10, 0)
levelText.Size = UDim2.fromOffset(70, 34)
levelText.Font = Enum.Font.GothamBold
levelText.TextSize = 14
levelText.TextColor3 = RUNE
levelText.TextXAlignment = Enum.TextXAlignment.Left
levelText.Parent = chip

local bar = Instance.new("Frame")
bar.Position = UDim2.fromOffset(80, 13)
bar.Size = UDim2.fromOffset(52, 8)
bar.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
bar.BorderSizePixel = 0
bar.Parent = chip
corner(bar, UDim.new(0.5, 0))
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = EXP
barFill.BorderSizePixel = 0
barFill.Parent = bar
corner(barFill, UDim.new(0.5, 0))

local truckText = Instance.new("TextLabel")
truckText.BackgroundTransparency = 1
truckText.AnchorPoint = Vector2.new(1, 0)
truckText.Position = UDim2.new(1, -10, 0, 0)
truckText.Size = UDim2.fromOffset(78, 34)
truckText.Font = Enum.Font.GothamBold
truckText.TextSize = 13
truckText.TextColor3 = TEXT
truckText.TextXAlignment = Enum.TextXAlignment.Right
truckText.Parent = chip

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then return ("%dชม."):format(seconds // 3600) end
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local lastShipEnd = nil
local flashUntil = 0
local function drawChip()
	local level = player:GetAttribute("FarmLevel")
	chipGui.Enabled = type(level) == "number"
	if not chipGui.Enabled then return end
	levelText.Text = ("🌾 Lv %d"):format(level)
	local into, need = player:GetAttribute("FarmExpInto") or 0, math.max(1, player:GetAttribute("FarmExpNeed") or 1)
	barFill.Size = UDim2.fromScale(math.clamp(into / need, 0, 1), 1)
	local shipEnd = player:GetAttribute("FarmShipEnd")
	if type(shipEnd) == "number" then
		local left = shipEnd - workspace:GetServerTimeNow()
		truckText.Text = left > 0 and ("🚚 " .. clock(left)) or "🚚 …"
		truckText.TextColor3 = TEXT
	else
		-- รถเพิ่งกลับ (มีเวลาแล้วหายไป) = กะพริบเขียวแป๊บหนึ่งให้รู้ว่าไปรับรางวัลแล้ว
		if lastShipEnd ~= nil then flashUntil = os.clock() + 6 end
		truckText.Text = os.clock() < flashUntil and "🚚 กลับแล้ว!" or "🚚 ว่าง"
		truckText.TextColor3 = os.clock() < flashUntil and EXP or MUTED
	end
	lastShipEnd = type(shipEnd) == "number" and shipEnd or nil
end

task.spawn(function()
	while true do
		drawChip()
		task.wait(0.5)
	end
end)

--------------------------------------------------------------------------------
-- แบนเนอร์ฉลอง
--------------------------------------------------------------------------------

local pending = nil -- { from, to } ล่าสุดที่เซิร์ฟส่งมา (ขึ้นหลายครั้งก่อนโหลดจบ = เอาช่วงกว้างสุด)
local showing = false

local function unlockRows(from, to)
	local rows = {}
	for level = from + 1, to do
		for _, row in ipairs(FarmLevelConfig.UnlocksAt(level)) do rows[#rows + 1] = row end
	end
	return rows
end

local function showBanner(from, to)
	showing = true
	local gui = Instance.new("ScreenGui")
	gui.Name = "FarmLevelBanner"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Parent = playerGui

	local dim = Instance.new("TextButton") -- แตะตรงไหนก็ได้ = ปิด
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Parent = gui

	-- สองชั้น: กรอบนอกย่อตามจอ (Responsive) · การ์ดข้างในเด้งเข้า (UIScale ของตัวเอง)
	-- GuiObject หนึ่งตัวใช้ UIScale ได้ตัวเดียว ใส่สองตัวที่ชิ้นเดียวกันแล้วตัวไหนชนะก็ไม่รู้
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.45)
	holder.Size = UDim2.fromOffset(520, 250)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	Responsive.Scale(holder, 0.6)

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(34, 32, 26)
	card.BorderSizePixel = 0
	card.Parent = holder
	corner(card, UDim.new(0, 18))
	local stroke = Instance.new("UIStroke")
	stroke.Color = RUNE
	stroke.Thickness = 3
	stroke.Parent = card
	local grad = Instance.new("UIGradient") -- แสงวิ่งผ่านขอบ
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 250, 210)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 180, 60)),
	})
	grad.Parent = stroke
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = card

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(0, 18)
	title.Size = UDim2.new(1, 0, 0, 48)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 40
	title.TextColor3 = RUNE
	title.Text = ("🎉 เลเวลฟาร์ม %d!"):format(to)
	title.Parent = card
	local ts = Instance.new("UIStroke")
	ts.Color = Color3.fromRGB(90, 50, 10)
	ts.Thickness = 2
	ts.Parent = title

	local rows = unlockRows(from, to)
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(0, 70)
	sub.Size = UDim2.new(1, 0, 0, 22)
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 16
	sub.TextColor3 = TEXT
	sub.Text = #rows > 0 and "ปลดล็อกใหม่" or "ฟาร์มของคุณเติบโตขึ้นแล้ว"
	sub.Parent = card

	-- แถวไอคอนของที่ปลด สูงสุด 8 + "+N"
	local strip = Instance.new("Frame")
	strip.AnchorPoint = Vector2.new(0.5, 0)
	strip.Position = UDim2.new(0.5, 0, 0, 100)
	strip.Size = UDim2.new(1, -40, 0, 104)
	strip.BackgroundTransparency = 1
	strip.Parent = card
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(112, 48)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = strip
	local shown = math.min(#rows, #rows > 8 and 7 or 8)
	for i = 1, shown do
		local row = rows[i]
		local tile = Instance.new("Frame")
		tile.LayoutOrder = i
		tile.BackgroundColor3 = Color3.fromRGB(52, 48, 36)
		tile.BorderSizePixel = 0
		tile.Parent = strip
		corner(tile, UDim.new(0, 8))
		if row.emoji then
			local e = Instance.new("TextLabel")
			e.BackgroundTransparency = 1
			e.Size = UDim2.fromOffset(40, 48)
			e.Font = Enum.Font.Gotham
			e.TextSize = 24
			e.Text = row.emoji
			e.Parent = tile
		else
			local icon = Instance.new("ImageLabel")
			icon.BackgroundTransparency = 1
			icon.Position = UDim2.fromOffset(4, 6)
			icon.Size = UDim2.fromOffset(36, 36)
			ItemIcon.Apply(icon, row.icon)
			icon.Parent = tile
		end
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromOffset(42, 0)
		t.Size = UDim2.new(1, -46, 1, 0)
		t.Font = Enum.Font.GothamMedium
		t.TextSize = 11
		t.TextWrapped = true
		t.TextColor3 = TEXT
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = row.text
		t.Parent = tile
	end
	if #rows > shown then
		local more = Instance.new("TextLabel")
		more.LayoutOrder = 99
		more.BackgroundColor3 = Color3.fromRGB(52, 48, 36)
		more.Font = Enum.Font.GothamBold
		more.TextSize = 15
		more.TextColor3 = RUNE
		more.Text = ("+%d อย่าง"):format(#rows - shown)
		more.Parent = strip
		corner(more, UDim.new(0, 8))
	end

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -10)
	hint.Size = UDim2.new(1, 0, 0, 16)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 12
	hint.TextColor3 = MUTED
	hint.Text = "ดูทั้งหมดได้ที่รถส่งออก · แตะเพื่อปิด"
	hint.Parent = card

	-- ขนาดการ์ดตามจำนวนแถวไอคอน (หนึ่งแถว = เตี้ยลง)
	local lines = math.max(1, math.ceil(math.max(1, #rows > shown and shown + 1 or shown) / 4))
	holder.Size = UDim2.fromOffset(520, 134 + lines * 54 + 24)

	UiSound.Play("FarmLevelUp")
	TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 0.55 }):Play()
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- แสงวิ่งรอบขอบ
	task.spawn(function()
		while gui.Parent do
			grad.Rotation = (grad.Rotation + 4) % 360
			task.wait(1 / 30)
		end
	end)

	-- บอกเซิร์ฟตอนการ์ดขึ้นจริง (จดว่าฉลองแล้ว + พลุรอบตัวที่ทุกคนเห็น)
	Remotes.FarmCelebrate:FireServer("seen", to)

	local closed = false
	local function close()
		if closed then return end
		closed = true
		TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		local out = TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 })
		out:Play()
		out.Completed:Wait()
		gui:Destroy()
		showing = false
	end
	-- เปิดให้กดปิดหลังครึ่งวิ (กันกดทะลุจากการกดปุ่มส่งของที่เพิ่งกด)
	task.delay(0.6, function()
		dim.Activated:Connect(close)
	end)
	task.delay(8, close)
end

local function loaded()
	return player:GetAttribute("WOLD_Loaded") == true
end

Remotes.FarmCelebrate.OnClientEvent:Connect(function(info)
	if type(info) ~= "table" or type(info.to) ~= "number" then return end
	local from = tonumber(info.from) or (info.to - 1)
	if pending then from = math.min(from, pending.from) end
	pending = { from = from, to = math.max(info.to, pending and pending.to or 0) }
end)

-- รอจอโหลดจบแล้วค่อยบอกเซิร์ฟว่าพร้อม (เซิร์ฟส่งแบนเนอร์ที่ค้างมา) · กันจอโหลดไม่ตั้งธง = 60 วิแล้วพร้อมเอง
task.spawn(function()
	local started = os.clock()
	while not loaded() and os.clock() - started < 60 do task.wait(0.25) end
	task.wait(1) -- ให้จอเกมโผล่ครบก่อน แบนเนอร์จะไม่ทับฉากเปลี่ยนจอ
	Remotes.FarmCelebrate:FireServer("ready")
	while true do
		if pending and not showing then
			local p = pending
			pending = nil
			showBanner(p.from, p.to)
		end
		task.wait(0.3)
	end
end)
