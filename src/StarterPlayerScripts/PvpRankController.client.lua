-- PvpRankController: ฉลองเลื่อนแร็งก์ PVP ที่หน้าล็อบบี้ (เฟส 3 · ผู้ใช้เพิ่ม 2026-09-27)
--
-- กลับจากแมตช์ถึงล็อบบี้ → **ตราใหญ่กลางจอ** จอมืดลงนิด · ตราเก่าแตกเป็นเศษ → ตราใหม่เด้งขึ้นพร้อมแสงสีแร่ของขั้นนั้น + เสียง
-- ~4 วิ · **แตะ/คลิกตรงไหนก็ข้าม** · เห็นคนเดียว (ไม่ประกาศ) · ตกขั้นไม่มีเอฟเฟกต์ (บรรทัดในหน้าปาร์ตี้แทน)
--
-- ⚠️ ScreenGui ของตัวเอง **ห้ามแขวนกับหน้าจอล็อบบี้** (หน้าจอนั้นถูกสร้างใหม่ทุกครั้งที่มือถือหมุนจอ) · ResetOnSpawn = false
-- จบ/ข้ามแล้วตอบเซิร์ฟ "เห็นแล้ว" (PvpRankSeen) → เซิร์ฟจดขั้นที่เห็น ไม่ฉลองซ้ำครั้งหน้า
while workspace:GetAttribute("IsLobby") == nil do task.wait(0.2) end
if not workspace:GetAttribute("IsLobby") then return end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(game.ReplicatedStorage.Remotes)
local PvpRankConfig = require(game.ReplicatedStorage.PvpRankConfig)
local UiSound = require(game.ReplicatedStorage.UI.UiSound)

local player = Players.LocalPlayer
local playing = false
local finishCurrent = nil -- ข้ามฉากที่กำลังเล่น (คีย์บอร์ดใช้)

local function emblem(parent, tier, size)
	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.45)
	disc.Size = UDim2.fromOffset(size, size)
	disc.BackgroundColor3 = Color3.fromRGB(28, 26, 30)
	disc.BorderSizePixel = 0
	disc.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = disc
	local ring = Instance.new("UIStroke")
	ring.Color = tier.color
	ring.Thickness = 6
	ring.Parent = disc
	local glyph = Instance.new("TextLabel")
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromScale(0.62, 0.62)
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.TextScaled = true
	glyph.Text = tier.emoji
	glyph.Parent = disc
	local scale = Instance.new("UIScale")
	scale.Parent = disc
	return disc, scale, ring, glyph
end

local function celebrate(data)
	if playing then return end
	playing = true
	local from, to = PvpRankConfig.Tier(data.from), PvpRankConfig.Tier(data.to)

	local gui = Instance.new("ScreenGui")
	gui.Name = "PvpRankUp"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 950 -- เหนือหน้าจอล็อบบี้ ใต้จอดำตอนเทเลพอร์ต (1000)
	gui.Parent = player:WaitForChild("PlayerGui")

	-- แตะตรงไหนก็ข้าม (ปุ่มเต็มจอโปร่งใส) — กดข้ามแล้วปุ่มนี้หายไปทันที ไม่ค้างบังปุ่ม JOIN
	local skip = Instance.new("TextButton")
	skip.Size = UDim2.fromScale(1, 1)
	skip.BackgroundColor3 = Color3.new(0, 0, 0)
	skip.BackgroundTransparency = 1
	skip.Text = ""
	skip.AutoButtonColor = false
	skip.Parent = gui
	TweenService:Create(skip, TweenInfo.new(0.35), { BackgroundTransparency = 0.45 }):Play()

	local finished = false
	local function finish()
		if finished then return end
		finished = true
		Remotes.PvpRankSeen:FireServer()
		TweenService:Create(skip, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		for _, d in ipairs(gui:GetDescendants()) do
			if d:IsA("GuiObject") and d ~= skip then d.Visible = false end
		end
		task.delay(0.32, function() gui:Destroy() playing = false finishCurrent = nil end)
	end
	skip.Activated:Connect(finish)
	finishCurrent = finish

	-- 1) ตราเก่าสั่น แล้วแตกเป็นเศษ
	local old, oldScale = emblem(gui, from, 220)
	for i = 1, 8 do
		task.delay(0.05 * i, function()
			if finished then return end
			old.Rotation = (i % 2 == 0 and 1 or -1) * (2 + i)
		end)
	end
	task.delay(0.6, function()
		if finished then return end
		local centre = old.AbsolutePosition + old.AbsoluteSize / 2
		old.Visible = false
		for i = 1, 14 do
			local a = (i / 14) * math.pi * 2 + math.random() * 0.4
			local shard = Instance.new("Frame")
			shard.AnchorPoint = Vector2.new(0.5, 0.5)
			shard.Position = UDim2.fromOffset(centre.X, centre.Y)
			shard.Size = UDim2.fromOffset(math.random(14, 30), math.random(8, 18))
			shard.Rotation = math.deg(a)
			shard.BackgroundColor3 = from.color
			shard.BorderSizePixel = 0
			shard.Parent = gui
			local dist = math.random(160, 320)
			TweenService:Create(shard, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromOffset(centre.X + math.cos(a) * dist, centre.Y + math.sin(a) * dist),
				BackgroundTransparency = 1, Rotation = shard.Rotation + math.random(-120, 120),
			}):Play()
		end
	end)

	-- 2) ตราใหม่เด้งขึ้น + แสงสีแร่ + ป้ายชื่อขั้น + เสียง
	task.delay(0.75, function()
		if finished then return end
		UiSound.Play("FarmLevelUp")
		local rays = Instance.new("Frame")
		rays.AnchorPoint = Vector2.new(0.5, 0.5)
		rays.Position = UDim2.fromScale(0.5, 0.45)
		rays.Size = UDim2.fromOffset(420, 420)
		rays.BackgroundTransparency = 1
		rays.Parent = gui
		for i = 0, 11 do
			local ray = Instance.new("Frame")
			ray.AnchorPoint = Vector2.new(0.5, 1)
			ray.Position = UDim2.fromScale(0.5, 0.5)
			ray.Size = UDim2.fromOffset(18, 210)
			ray.Rotation = i * 30
			ray.BackgroundColor3 = to.color
			ray.BackgroundTransparency = 0.55
			ray.BorderSizePixel = 0
			ray.Parent = rays
			local grad = Instance.new("UIGradient")
			grad.Transparency = NumberSequence.new(1, 0)
			grad.Rotation = 90
			grad.Parent = ray
		end
		TweenService:Create(rays, TweenInfo.new(4, Enum.EasingStyle.Linear), { Rotation = 90 }):Play()
		local _, newScale, ring = emblem(gui, to, 240)
		newScale.Scale = 0.2
		TweenService:Create(newScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 12 }):Play()

		local title = Instance.new("TextLabel")
		title.AnchorPoint = Vector2.new(0.5, 0)
		title.Position = UDim2.new(0.5, 0, 0.45, 140)
		title.Size = UDim2.fromOffset(520, 56)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.TextSize = 40
		title.TextColor3 = to.color
		title.TextStrokeTransparency = 0.3
		title.Text = ("เลื่อนแร็งก์เป็น %s!"):format(to.name)
		title.Parent = gui
		local sub = title:Clone()
		sub.Position = UDim2.new(0.5, 0, 0.45, 196)
		sub.Font = Enum.Font.GothamBold
		sub.TextSize = 18
		sub.TextColor3 = Color3.fromRGB(230, 226, 214)
		sub.Text = ("%d แต้ม · แตะเพื่อไปต่อ"):format(data.points or 0)
		sub.Parent = gui
	end)

	task.delay(4.4, finish)
end

Remotes.PvpRankUp.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	-- จอโหลด/จอเลือกโหมดยังขึ้นอยู่ก็ฉลองได้ (อยู่เหนือหน้าจอล็อบบี้) · รอตัวละครไม่จำเป็น
	task.spawn(celebrate, data)
end)

-- คีย์บอร์ด: เว้นวรรค/Enter ก็ข้ามได้
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not playing then return end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return then
		if finishCurrent then finishCurrent() end
	end
end)
