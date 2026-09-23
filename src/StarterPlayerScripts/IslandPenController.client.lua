-- IslandPenController: หน้าต่างเลือกสัตว์ของคอก — เปิดเมื่อเซิร์ฟเวอร์ส่ง IslandPenOpen (กด E ที่คอก)
--
-- ทรงเดียวกับร้าน: เซิร์ฟเวอร์ส่งภาพรวมทั้งก้อนมาวาด ไคลเอนต์ตอบแค่ "ซื้อชนิดนี้ n ตัว" ไม่เคยส่งราคา
-- หน้าต่างสร้างเองในไฟล์นี้ (ไม่มี Gui module แยก — แถวสัตว์แปดแถว ไม่ซับซ้อนพอจะต้องแยกไฟล์)
while workspace:GetAttribute("IsLobby") == nil do task.wait() end
if workspace:GetAttribute("IslandMode") ~= true then return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Remotes)
local Responsive = require(ReplicatedStorage.UI.Responsive)

local player = Players.LocalPlayer
local PANEL = Color3.fromRGB(26, 24, 30)
local TEXT = Color3.fromRGB(236, 232, 224)
local MUTED = Color3.fromRGB(158, 152, 146)
local BRASS = Color3.fromRGB(196, 150, 60)

local gui = Instance.new("ScreenGui")
gui.Name = "IslandPenGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 45
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 420, 0, 460)
panel.BackgroundColor3 = PANEL
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Parent = gui
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 12); corner.Parent = panel
Responsive.Scale(panel, 0.55)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 16, 0, 10)
title.Size = UDim2.new(1, -32, 0, 26)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = BRASS
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "คอกสัตว์"
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0, 16, 0, 36)
subtitle.Size = UDim2.new(1, -32, 0, 18)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 14
subtitle.TextColor3 = MUTED
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Text = ""
subtitle.Parent = panel

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -12, 0, 10)
close.Size = UDim2.new(0, 30, 0, 30)
close.BackgroundColor3 = Color3.fromRGB(110, 50, 50)
close.BorderSizePixel = 0
close.Font = Enum.Font.GothamBold
close.TextSize = 18
close.TextColor3 = TEXT
close.Text = "X"
close.Parent = panel
local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 8); cc.Parent = close
local function shut()
	gui.Enabled = false
	Remotes.IslandPenClose:FireServer() -- ไม่บอก เซิร์ฟเวอร์ก็ยิงภาพใหม่ใส่ทุก 3 วิต่อไป
end
close.MouseButton1Click:Connect(shut)

-- ⚠️ ประกาศก่อนปุ่มปล่อยสัตว์ข้างล่าง — closure ที่อ่านมันต้องเห็น local ตัวนี้ ไม่ใช่ global ที่เป็น nil
local currentUid = nil

-- **ปุ่มปล่อยสัตว์** (ผู้ใช้สั่ง 2026-09-23) — ทางเดียวที่จะเปลี่ยนชนิดสัตว์ที่เลี้ยง เพราะสัตว์ไม่หาย
-- ตอนถูกเก็บเกี่ยวแล้ว และคอกที่ยังมีสัตว์อยู่ก็เก็บคืนกระเป๋าไม่ได้
-- **ต้องกดสองครั้ง** ปล่อยแล้วสัตว์หายหมดและไม่คืนเงิน — ทรงเดียวกับปุ่มยุบแคลน
local release = Instance.new("TextButton")
release.AnchorPoint = Vector2.new(1, 0)
release.Position = UDim2.new(1, -50, 0, 10)
release.Size = UDim2.new(0, 104, 0, 30)
release.BackgroundColor3 = Color3.fromRGB(92, 70, 48)
release.BorderSizePixel = 0
release.Font = Enum.Font.GothamMedium
release.TextSize = 14
release.TextColor3 = TEXT
release.Text = "ปล่อยสัตว์"
release.Visible = false -- โผล่เฉพาะตอนมีสัตว์ให้ปล่อย
release.Parent = panel
local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 8); rc.Parent = release

local armed = false
local function disarm()
	armed = false
	release.Text = "ปล่อยสัตว์"
	release.BackgroundColor3 = Color3.fromRGB(92, 70, 48)
end
release.MouseButton1Click:Connect(function()
	if not currentUid then return end
	if not armed then
		armed = true
		release.Text = "แน่ใจ?"
		release.BackgroundColor3 = Color3.fromRGB(132, 62, 48)
		task.delay(4, function() if armed then disarm() end end)
		return
	end
	disarm()
	Remotes.IslandPenRelease:FireServer(currentUid)
end)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.new(0, 12, 0, 62)
list.Size = UDim2.new(1, -24, 1, -74)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list


local function row(index, animal, snap)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = index
	frame.Size = UDim2.new(1, -6, 0, 46)
	frame.BackgroundColor3 = Color3.fromRGB(36, 34, 40)
	frame.BorderSizePixel = 0
	frame.Parent = list
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = frame

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.new(0, 12, 0, 4)
	name.Size = UDim2.new(0.5, 0, 1, -8)
	name.Font = Enum.Font.GothamMedium
	name.TextSize = 16
	name.TextColor3 = TEXT
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = ("%s  ·  %d เหรียญ"):format(animal.name, animal.price)
	name.Parent = frame

	-- ซื้อทีละ 1 หรือเต็มคอก — เพดานแค่ห้าตัว ปุ่มสองปุ่มพอ ไม่ต้องมีช่องพิมพ์เลข
	-- (เซิร์ฟเวอร์ตัดจำนวนให้พอดีที่ว่างอยู่แล้ว กด "เต็มคอก" ตอนมีอยู่ 3 จึงซื้อแค่ 2)
	local x = 0
	for _, n in ipairs({ 1, snap.max }) do
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -10 - x, 0.5, 0)
		b.Size = UDim2.new(0, 56, 0, 30)
		b.BackgroundColor3 = Color3.fromRGB(72, 104, 78)
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 15
		b.TextColor3 = TEXT
		b.Text = n == 1 and "+1" or "เต็มคอก"
		b.Parent = frame
		local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 7); bc.Parent = b
		-- คอกที่มีสัตว์ชนิดอื่นอยู่แล้ว: ปิดปุ่มไว้เลย ดีกว่ากดแล้วโดนปฏิเสธ
		local blocked = snap.kind ~= nil and snap.kind ~= animal.kind and snap.count > 0
		if blocked then
			b.BackgroundColor3 = Color3.fromRGB(58, 56, 62)
			b.AutoButtonColor = false
		end
		b.MouseButton1Click:Connect(function()
			if blocked or not currentUid then return end
			Remotes.IslandPenBuy:FireServer(currentUid, animal.kind, n)
		end)
		x += 62
	end
end

local function draw(snap)
	if not snap.open and not gui.Enabled then return end -- ปิดอยู่ ไม่ต้องวาดอะไรเลย
	currentUid = snap.uid
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	local growing = snap.growing or {}
	local waiting = 0
	for _, g in ipairs(growing) do
		if g.state ~= "ready" then waiting += 1 end
	end
	local tail = waiting > 0 and (" · รออยู่ %d"):format(waiting) or ""
	subtitle.Text = ("ในคอก %d/%d ตัว · เก็บได้ %d%s"):format(snap.count, snap.max, snap.ready or 0, tail)

	-- **แถบความคืบหน้าของตัวที่ยังโตไม่เสร็จ** (ผู้ใช้สั่ง 2026-09-22)
	-- วาดก่อนรายการสัตว์ที่ซื้อได้ เพราะมันคือ "สถานะตอนนี้" ส่วนรายการข้างล่างคือ "จะซื้ออะไรต่อ"
	for gi, g in ipairs(growing) do
		local bar = Instance.new("Frame")
		bar.LayoutOrder = -100 + gi
		bar.Size = UDim2.new(1, -6, 0, 30)
		bar.BackgroundColor3 = Color3.fromRGB(30, 28, 34)
		bar.BorderSizePixel = 0
		bar.Parent = list
		local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 7); bc.Parent = bar

		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(math.clamp(g.progress or 0, 0, 1), 0, 1, 0)
		-- สีบอกสถานะ: เขียวสด = เก็บได้เลย · เขียวเข้ม = กำลังโต · ฟ้าเทา = รอคูลดาวน์หลังเพิ่งเก็บ
		fill.BackgroundColor3 = (g.state == "ready" and Color3.fromRGB(118, 176, 92))
			or (g.state == "cool" and Color3.fromRGB(74, 106, 132))
			or Color3.fromRGB(86, 132, 74)
		fill.BorderSizePixel = 0
		fill.Parent = bar
		local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 7); fc.Parent = fill

		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.new(1, -16, 1, 0)
		text.Position = UDim2.new(0, 10, 0, 0)
		text.Font = Enum.Font.GothamMedium
		text.TextSize = 13
		text.TextColor3 = TEXT
		text.TextXAlignment = Enum.TextXAlignment.Left
		-- **บอกเป็นนาที:วินาที เมื่อเหลือน้อยกว่าหนึ่งนาที** ไม่งั้น "อีก 1 นาที" ค้างอยู่ตั้งนาน
		local left = math.max(0, g.secondsLeft or 0)
		local when = left >= 60 and ("%d นาที"):format(math.ceil(left / 60)) or ("%d วินาที"):format(left)
		if g.state == "ready" then
			text.Text = ("%s · เก็บได้แล้ว"):format(g.name or "สัตว์")
		elseif g.state == "cool" then
			text.Text = ("%s · เก็บได้อีกใน %s"):format(g.name or "สัตว์", when)
		else
			text.Text = ("%s · โตอีก %s (%d%%)"):format(g.name or "สัตว์", when, math.floor((g.progress or 0) * 100))
		end
		text.ZIndex = 2
		text.Parent = bar
	end

	-- ปุ่มปล่อยสัตว์โผล่เฉพาะตอนมีอะไรให้ปล่อย · เปลี่ยนภาพใหม่ = ยกเลิกการยืนยันที่ค้างอยู่
	release.Visible = (snap.count or 0) > 0
	if not release.Visible then disarm() end

	for i, animal in ipairs(snap.animals) do row(i, animal, snap) end
	-- **ภาพที่ส่งมาอัปเดตแถบความคืบหน้าไม่มีสิทธิ์เปิดหน้าต่าง** มีแต่การกด E กับการซื้อ (`snap.open`)
	-- ไม่งั้นปิดแล้วมันเด้งกลับมาเองทุก 3 วินาที
	if snap.open then gui.Enabled = true end
end

Remotes.IslandPenOpen.OnClientEvent:Connect(draw)
player.CharacterRemoving:Connect(shut)
