-- LevelUpController: ฉลองเลเวลตัวละครขึ้น (QA 2026-09-28 · ผู้ใช้เลือก "แบนเนอร์ + แสงทุกคนเห็น")
--
-- เดิมเลเวลขึ้นเงียบสนิท มีแค่ตัวเลขในหลอด EXP เปลี่ยน · ตอนนี้:
--   เจ้าตัว — แบนเนอร์ "LEVEL UP!" กลางจอ ~2.5 วิ + เสียง `LevelUp`
--   ทุกคน   — แสงทองพุ่งรอบตัวคนที่ขึ้นเลเวล (วงแหวนที่เท้า + ประกายลอยขึ้น + แสง) · คนอื่นได้ยินเสียงตามระยะ
-- ขึ้นหลายเลเวลในครั้งเดียว = ฉลองครั้งเดียวที่เลเวลสุดท้าย (เซิร์ฟยิงครั้งเดียวต่อการได้ EXP อยู่แล้ว)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

while workspace:GetAttribute("IsLobby") == nil do task.wait(0.2) end
if workspace:GetAttribute("IsLobby") then return end

local Remotes = require(game.ReplicatedStorage.Remotes)
local UiSound = require(game.ReplicatedStorage.UI.UiSound)
local Responsive = require(game.ReplicatedStorage.UI.Responsive)
local L = require(game.ReplicatedStorage.Locale).L

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 214, 110)

--------------------------------------------------------------------------------
-- แบนเนอร์ของเจ้าตัว
--------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "WOLD_LevelUp"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")

local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(0.5, 0.5)
holder.Position = UDim2.fromScale(0.5, 0.3)
holder.Size = UDim2.fromOffset(460, 120)
holder.BackgroundTransparency = 1
holder.Visible = false
holder.Parent = gui
Responsive.Scale(holder, 0.6)
local popScale = Instance.new("UIScale")
popScale.Parent = holder

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 64)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.Text = "LEVEL UP!"
title.TextColor3 = GOLD
title.Parent = holder
local titleStroke = Instance.new("UIStroke")
titleStroke.Color = Color3.fromRGB(80, 50, 10)
titleStroke.Thickness = 3
titleStroke.Parent = title
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(255, 244, 190), GOLD)
grad.Rotation = 90
grad.Parent = title

local sub = Instance.new("TextLabel")
sub.Position = UDim2.fromOffset(0, 66)
sub.Size = UDim2.new(1, 0, 0, 40)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.GothamBold
sub.TextScaled = true
sub.TextColor3 = Color3.fromRGB(245, 240, 225)
sub.Parent = holder
local subStroke = Instance.new("UIStroke")
subStroke.Color = Color3.fromRGB(0, 0, 0)
subStroke.Thickness = 2
subStroke.Transparency = 0.3
subStroke.Parent = sub

local token = 0
local function banner(level)
	token += 1
	local mine = token
	sub.Text = L("เลเวล %d · เลือด สตามินา เกราะ เติมเต็ม", level)
	holder.Visible = true
	popScale.Scale = 0.4
	title.TextTransparency, sub.TextTransparency = 0, 0
	titleStroke.Transparency, subStroke.Transparency = 0, 0.3
	TweenService:Create(popScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.3, function()
		if token ~= mine then return end
		local fade = TweenInfo.new(0.5)
		TweenService:Create(title, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(sub, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(titleStroke, fade, { Transparency = 1 }):Play()
		TweenService:Create(subStroke, fade, { Transparency = 1 }):Play()
		task.wait(0.55)
		if token == mine then holder.Visible = false end
	end)
end

--------------------------------------------------------------------------------
-- แสงรอบตัว (ทุกเครื่องวาดเอง)
--------------------------------------------------------------------------------
local function burst(who)
	local character = who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	-- วงแหวนทองขยายออกที่เท้า
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = GOLD
	ring.Transparency = 0.2
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.Size = Vector3.new(0.15, 2, 2)
	ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.15, 14, 14), Transparency = 1 }):Play()
	Debris:AddItem(ring, 1)
	-- ประกายลอยขึ้นรอบตัว + แสง (ติดตัวไปกับคน 1.6 วิ)
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, -1.5, 0)
	att.Parent = root
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(GOLD, Color3.fromRGB(255, 250, 220))
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.Lifetime = NumberRange.new(0.8, 1.4)
	sparks.Speed = NumberRange.new(4, 8)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Rate = 0
	sparks.Parent = att
	sparks:Emit(40)
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 14
	light.Brightness = 3
	light.Shadows = false
	light.Parent = att
	TweenService:Create(light, TweenInfo.new(1.4), { Brightness = 0 }):Play()
	Debris:AddItem(att, 2)
end

Remotes.LevelUpEffect.OnClientEvent:Connect(function(who, level)
	if typeof(who) ~= "Instance" or not who:IsA("Player") then return end
	burst(who)
	if who == player then
		UiSound.Play("LevelUp")
		banner(tonumber(level) or 1)
	else
		local root = who.Character and who.Character:FindFirstChild("HumanoidRootPart")
		if root then UiSound.PlayAt("LevelUp", root, 0.5, 60) end
	end
end)
