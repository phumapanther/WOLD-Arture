-- BlockController: ยกการ์ด / ปัดป้อง ฝั่งไคลเอนต์ — **สนาม PVP เท่านั้น** (เฟส 3 ข้อแรก · ผู้ใช้กำหนด 2026-09-27)
--
-- สองหน้าที่:
--   1. ปุ่ม: **คลิกขวาค้าง** (คอม) · **L2 ค้าง** (จอย) · ปุ่ม 🛡️ กดค้าง (มือถือ — TouchActionGui ยิงผ่าน WOLD_ArenaAction →
--      ArenaController → ไฟล์นี้ไม่ต้องรู้) → ส่งแค่ "ยก/ปล่อย" (`RequestBlock`) เซิร์ฟตัดสินทุกอย่าง (BlockGuard/Blocking)
--      ถือสไน = คลิกขวาเป็นของ AimController (เลิกส่อง) ไฟล์นี้ไม่ยุ่ง
--   2. ท่า: วาดท่ายกการ์ด (แขนไขว้หน้าหน้า) ให้ **ทุกคน** ที่มีแอตทริบิวต์ `WOLD_Blocking` และท่าเสียหลักตอนถูกปัด (StatusChanged "stagger")
--      เขียน Transform หลัง Animator (Stepped) แบบเดียวกับ WorkPoses — ไม่ต้องอัปโหลดอนิเมชัน ท่าเดินของขายังทำงานข้างใต้
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

if workspace:GetAttribute("ArenaMode") ~= true then return end

local Remotes = require(game.ReplicatedStorage.Remotes)
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)
local player = Players.LocalPlayer

--------------------------------------------------------------------------------
-- ปุ่ม
--------------------------------------------------------------------------------

local holding = false

local function holdingSniper()
	local id = player:GetAttribute("WOLD_Weapon")
	local spec = type(id) == "string" and CombatConfig.Weapons[id]
	return spec and spec.scope == true
end

local function setHold(on)
	if on and holdingSniper() then return end
	if holding == on then return end
	holding = on
	Remotes.RequestBlock:FireServer(on)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
		setHold(true)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
		setHold(false)
	end
end)

-- ปุ่มมือถือ (ArenaController ส่งต่อมาที่ช่องนี้) · ช่องทางอยู่ ReplicatedStorage ไม่ใช่ PlayerGui (บทเรียน QA 2026-09-26)
local channel = Instance.new("BindableEvent")
channel.Name = "WOLD_BlockAction"
channel.Parent = game.ReplicatedStorage
channel.Event:Connect(function(on) setHold(on == true) end)

-- เซิร์ฟปล่อยการ์ดให้เอง (ล้ม กลิ้ง เปลี่ยนเป็นสไน) → ปุ่มค้างอยู่ก็ต้องรู้ ไม่งั้นปล่อยนิ้วแล้วส่ง false ซ้ำ ไม่เสียหาย
-- แต่กดใหม่ครั้งถัดไปจะไม่ส่ง true (holding ยังเป็น true) — เทียบกับของจริงทุก 0.2 วิ
task.spawn(function()
	while true do
		if holding and player:GetAttribute("WOLD_Blocking") ~= true then
			task.wait(0.3) -- ให้เวลาเซิร์ฟตอบครั้งแรกก่อนตัดสินว่าถูกปล่อย
			if holding and player:GetAttribute("WOLD_Blocking") ~= true then holding = false end
		end
		task.wait(0.2)
	end
end)

--------------------------------------------------------------------------------
-- ท่า (ทุกคน)
--------------------------------------------------------------------------------

local function rad(d) return math.rad(d) end

local staggerUntil = {} -- [player] = os.clock()
Remotes.StatusChanged.OnClientEvent:Connect(function(who, kind, on)
	if kind ~= "stagger" or typeof(who) ~= "Instance" then return end
	staggerUntil[who] = on and (os.clock() + 1) or nil
end)

local function motor(character, part, name)
	local p = character:FindFirstChild(part)
	return p and p:FindFirstChild(name) or nil
end

local function set(joint, cf)
	if joint then joint.Transform = cf end
end

-- **X บวก = แขนยกไปข้างหน้า** บน R15 (บทเรียน ConsumeController/WorkPoses) · คอค่าลบ = ก้ม
local function blockPose(character)
	set(motor(character, "RightUpperArm", "RightShoulder"), CFrame.Angles(rad(96), 0, rad(-42)))
	set(motor(character, "RightLowerArm", "RightElbow"), CFrame.Angles(rad(82), 0, 0))
	set(motor(character, "LeftUpperArm", "LeftShoulder"), CFrame.Angles(rad(92), 0, rad(40)))
	set(motor(character, "LeftLowerArm", "LeftElbow"), CFrame.Angles(rad(86), 0, 0))
	set(motor(character, "Head", "Neck"), CFrame.Angles(rad(-8), 0, 0))
end

-- เสียหลักถอยหลัง: ลำตัวแอ่น แขนกางลอยออก (สั้นๆ ตามเวลาที่เซ)
local function staggerPose(character, t)
	local wobble = math.sin(t * 18) * (1 - math.clamp(t / 0.8, 0, 1))
	set(motor(character, "UpperTorso", "Waist"), CFrame.Angles(rad(16 + 5 * wobble), rad(6 * wobble), 0))
	set(motor(character, "RightUpperArm", "RightShoulder"), CFrame.Angles(rad(35), 0, rad(-55)))
	set(motor(character, "LeftUpperArm", "LeftShoulder"), CFrame.Angles(rad(35), 0, rad(55)))
	set(motor(character, "Head", "Neck"), CFrame.Angles(rad(10), 0, 0))
end

RunService.Stepped:Connect(function()
	local now = os.clock()
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		if character then
			local until_ = staggerUntil[other]
			if until_ and now < until_ then
				staggerPose(character, 1 - (until_ - now))
			elseif other:GetAttribute("WOLD_Blocking") == true then
				blockPose(character)
			end
		end
	end
	for who, t in pairs(staggerUntil) do
		if now >= t or not who.Parent then staggerUntil[who] = nil end
	end
end)
