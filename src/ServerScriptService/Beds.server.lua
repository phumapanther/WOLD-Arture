-- Beds.server.lua: เตียงทุกหลังกด E แล้วนอน เลือดฟื้นวินาทีละ 1% จนกว่าจะลุก
--
-- โมเดลชื่อ "Bed" มี 245 หลังทั่วแมพ (ชุดคิทบ้าน) ทุกหลังมีชิ้น Mattress — ปุ่มแขวนที่ฟูก
--
-- การนอน = ตรึง HumanoidRootPart ไว้เหนือฟูกในท่านอนหงาย ส่วน humanoid ยังมีชีวิตปกติ (อนิเมชันยืนเล่นต่อ
-- ในท่านอน อ่านออกว่า "นอนพัก" พอ) · ลุกได้สามทาง: กด E ที่เตียงอีกครั้ง · **กดเดินหรือกระโดด** (ดูหัวข้อ
-- "ขยับ = ลุก" ท้ายไฟล์) · ตาย/ออกเกม/เกิดใหม่ล้างสถานะเอง
local Players = game:GetService("Players")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local Vitals = require(game.ServerScriptService.Vitals)
local Remotes = require(game.ReplicatedStorage.Remotes)

local RANGE = 8
local REGEN_PER_SECOND = 0.01 -- 1% ของเลือดเต็ม

local Sleeping = {} -- [player] = { bed = model, prompt = prompt }

local function wake(player)
	local s = Sleeping[player]
	if not s then return end
	Sleeping[player] = nil
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root then
		root.Anchored = false
		-- ยืนขึ้นข้างเตียง ไม่ใช่ตื่นมาในท่านอนกลางอากาศ
		root.CFrame = CFrame.new(root.Position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, select(2, root.CFrame:ToEulerAnglesYXZ()), 0)
	end
	if humanoid then
		humanoid.AutoRotate = true
		-- ปุ่มกระโดดที่ค้างเป็น true ตอนตรึงตัวอยู่ จะเด้งทันทีที่ปล่อย — ล้างทิ้งก่อนลุก
		humanoid.Jump = false
	end
	if s.prompt and s.prompt.Parent then s.prompt.ActionText = "นอนพัก" end
end

local function lieDown(player, bed, mattress, prompt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end
	if Vitals.IsDowned(player) then return end
	-- ที่เดียวนอนได้คนเดียว
	for other, s in pairs(Sleeping) do
		if s.bed == bed and other ~= player then
			return Remotes.SocialNotify:FireClient(player, "warn", "มีคนนอนอยู่แล้ว")
		end
	end
	wake(player)

	-- นอนหงายบนฟูก หัวไปทางหัวเตียง (ด้านหลังของฟูก) ยกขึ้นครึ่งความหนาตัว
	--
	-- **สองท่อน ไม่ใช่ท่อนเดียว** (แก้ 2026-09-18: ของเดิมนอนคว่ำหน้า)
	--   `Angles(-90, 0, 0)` เอียงตัวลงนอน — แต่แกนหน้าอก (-Z ของ HRP) ชี้ลงพื้น = คว่ำหน้า
	--   `Angles(0, 180, 0)` ที่คูณ **ทีหลัง** คือการพลิกรอบแกนของตัวเองที่ชี้จากเท้าไปหัว
	--     หน้าอกจึงหงายขึ้นฟ้าโดยที่หัวยังอยู่ทางหัวเตียงเหมือนเดิม
	-- ถ้าเปลี่ยนเป็น `Angles(90, 0, 0)` ท่อนเดียวจะหงายก็จริง แต่หัวไปโผล่ปลายเตียงแทน
	local top = mattress.CFrame * CFrame.new(0, mattress.Size.Y * 0.5 + 1.0, 0)
	root.CFrame = top * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.Angles(0, math.rad(180), 0)
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	humanoid.AutoRotate = false
	Sleeping[player] = { bed = bed, prompt = prompt }
	prompt.ActionText = "ลุก"
	Remotes.SocialNotify:FireClient(player, "info", "นอนพัก เลือดฟื้น 1% ต่อวินาที — ขยับหรือกด E เพื่อลุก")
end

--------------------------------------------------------------------------------
-- ต่อสาย
--------------------------------------------------------------------------------

local wired = {}

local function wire(bed)
	local mattress = bed:FindFirstChild("Mattress") or bed:FindFirstChildWhichIsA("BasePart")
	if not mattress then return end
	wired[bed] = true
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BedPrompt"
	prompt.ActionText = "นอนพัก"
	prompt.ObjectText = "เตียง"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = RANGE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = mattress
	prompt.Triggered:Connect(function(player)
		if Sleeping[player] and Sleeping[player].bed == bed then
			wake(player)
		else
			lieDown(player, bed, mattress, prompt)
		end
	end)
end

task.spawn(function()
	while true do
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("Model") and d.Name == "Bed" and not wired[d] then wire(d) end
		end
		task.wait(60)
	end
end)

--------------------------------------------------------------------------------
-- ฟื้นเลือด + ล้างสถานะ
--------------------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(1)
		for player, s in pairs(Sleeping) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid or humanoid.Health <= 0 or Vitals.IsDowned(player) or not s.bed.Parent then
				Sleeping[player] = nil
				if s.prompt and s.prompt.Parent then s.prompt.ActionText = "นอนพัก" end
			else
				Vitals.HealFraction(player, REGEN_PER_SECOND)
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- ขยับ = ลุก
--
-- ผู้ใช้สั่ง (2026-09-18): กดเดินหรือกระโดดตอนนอนอยู่ ให้ลุกเองโดยไม่ต้องกด E ซ้ำ — เตียงไม่ควรเป็นกับดัก
-- ที่ต้องหาปุ่มออก
--
-- อ่านจาก humanoid ฝั่งเซิร์ฟเวอร์ ไม่ใช่ธงจากไคลเอนต์ ด้วยเหตุผลเดียวกับที่การตกปลาเขียนไว้: `MoveDirection`
-- ไม่เป็นศูนย์เฉพาะตอนที่ผู้เล่น **สั่งเดินจริงๆ** โดนชนหรือยืนบนของที่เคลื่อนที่ไม่นับ · `Jump` เป็นพร็อพเพอร์ตี้
-- ที่ ControlModule ตั้งตอนกดสเปซ ซึ่งยังตั้งอยู่แม้ตัวจะถูกตรึงไว้จนกระโดดไม่ขึ้น
--
-- รอบละ 0.15 วิ ถี่พอให้รู้สึกว่า "กดแล้วลุกเลย" และถูกกว่าการต่อ event ต่อคนมาก
--------------------------------------------------------------------------------

local WATCH_SECONDS = 0.15

task.spawn(function()
	while true do
		task.wait(WATCH_SECONDS)
		-- `wake` ลบคีย์ที่กำลังวนอยู่พอดี ซึ่ง Lua อนุญาต (ลบคีย์ปัจจุบันระหว่าง pairs ได้ ลบคีย์อื่นไม่ได้)
		for player in pairs(Sleeping) do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local moving = humanoid.MoveDirection.Magnitude > 0.1
				local jumping = humanoid.Jump or humanoid:GetState() == Enum.HumanoidStateType.Jumping
				if moving or jumping then
					wake(player)
					Remotes.SocialNotify:FireClient(player, "info", "ลุกจากเตียงแล้ว")
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player) Sleeping[player] = nil end)
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function() Sleeping[player] = nil end)
end)
