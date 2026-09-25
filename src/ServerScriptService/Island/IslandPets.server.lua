-- IslandPets.server.lua: สัตว์เลี้ยงบนเกาะ — เดินเล่นเอง ลูบหัวได้ อุ้มย้ายที่ได้ และให้บัพกับทั้งฟาร์ม
--
-- **ต่างจากสัตว์ในคอกโดยสิ้นเชิง** สัตว์ในคอกเป็นกล่องนิ่งที่กด E เก็บผลผลิตแล้วหายไป (`IslandZones`)
-- ส่วนสัตว์เลี้ยงเป็น rig จริงที่ไม่ให้ผลผลิตอะไรเลย มันให้ **บัพ** แทน และอยู่ถาวร
--
-- ## ทำไมต้องมีไฟล์นี้ ทั้งที่ `IslandBuild` วางของให้อยู่แล้ว
--
-- ของที่ `IslandBuild` วางถูก **anchor ทุกชิ้น** และนั่นคือสิ่งที่ถูกต้องสำหรับบ้าน รั้ว ก้อนหิน —
-- แต่สัตว์ที่ anchor ไว้คือสัตว์สตัฟฟ์ ไฟล์นี้ปลด anchor แล้วส่งให้ `BeastGait` ขับ
--
-- ## กฎเหล็กที่ต้องระวัง
--
-- ⚠️ `BeastGait` **โมดูล** (`ServerScriptService.BeastGait`) ไม่ใช่ **สคริปต์** ที่ติดมากับโมเดล —
-- สคริปต์ในโมเดลเขียน `Motor6D.Transform` ซึ่ง**ไม่ replicate** (ใน Studio เห็นขยับ ในเกมจริงยืนแข็ง)
-- โมดูลปิดสคริปต์นั้นให้แล้วทำแบบเดียวกันลง `C0` · เรียก `Attach` เสมอ อย่าปล่อยให้สคริปต์ทำเอง
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsFarm then return end

local IslandConfig = require(game.ReplicatedStorage.IslandConfig)
local IslandAccess = require(game.ServerScriptService.Island.IslandAccess)
local BeastGait = require(game.ServerScriptService.BeastGait)
local Remotes = require(game.ReplicatedStorage.Remotes)

local WANDER_RADIUS = 60 -- เดินเล่นไกลจากจุดที่วางได้เท่านี้ (ทั่วฟาร์ม ไม่ใช่ยืนกับที่)
local PET_COOLDOWN = 20 -- ลูบหัวซ้ำได้ทุกกี่วินาที (กันกดรัวเอาข้อความ)
local CARRY_RANGE = 12

local Live = {} -- [model] = { uid, carriedBy }

-- **ประกาศไว้ก่อนใช้** ปุ่มถูกผูกใน `setup` ซึ่งอยู่เหนือนิยามจริงของสองตัวนี้ — local ที่ประกาศทีหลัง
-- จะเป็น nil ตอน closure จับได้ (กับดัก "ใช้ก่อนประกาศ" ที่โปรเจ็คนี้เจอมาห้าครั้ง)
local pat, toggleCarry
local PetTimes = {} -- [player] = os.clock ล่าสุดที่ลูบหัว

--------------------------------------------------------------------------------
-- ตั้งสัตว์ให้เดินได้
--------------------------------------------------------------------------------

local function isPet(model)
	local id = model:GetAttribute("ItemId")
	return id and IslandConfig.Pets[id] == true
end

local function setup(model)
	if Live[model] then return end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end

	-- **ปลด anchor ทุกชิ้น** IslandBuild ตรึงของที่วางไว้ทั้งหมด ซึ่งถูกสำหรับบ้านแต่ผิดสำหรับสัตว์
	-- ยกเว้น Root ล่องหนของระบบเกาะ ซึ่งไม่ใช่ส่วนหนึ่งของตัวสัตว์
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Root" then d.Anchored = false end
	end

	-- เดินเล่นรอบจุดที่วาง — `BeastGait` อ่าน WanderRadius จากตัวโมเดล
	model:SetAttribute("WanderRadius", WANDER_RADIUS)
	BeastGait.Attach(model, { wander = true })

	Live[model] = { uid = model:GetAttribute("Uid") }

	-- ปุ่มลูบหัว (E) และอุ้ม (F) — แขวนที่ HumanoidRootPart เพราะปุ่มวัดระยะจากชิ้นที่มันเกาะ
	if not root:FindFirstChild("PetPrompt") then
		local pet = Instance.new("ProximityPrompt")
		pet.Name = "PetPrompt"
		pet.ActionText = "ลูบหัว"
		pet.ObjectText = model:GetAttribute("ItemId") == "Pet_Cat" and "แมว" or "สุนัข"
		pet.KeyboardKeyCode = Enum.KeyCode.E
		pet.HoldDuration = 0
		pet.MaxActivationDistance = 10
		pet.RequiresLineOfSight = false
		pet.Parent = root
		pet.Triggered:Connect(function(player) pat(model, player) end)
	end

	-- **ปุ่มอุ้มต้องไม่ชนกับปุ่มเก็บของระบบเกาะ** ซึ่งก็ใช้ F เหมือนกัน
	-- `IslandBuild` แขวนปุ่มเก็บ (PickupPrompt) ไว้ที่ Root — ปุ่มอุ้มอยู่คนละชิ้นและใกล้กว่า
	-- คนที่อยากเก็บสัตว์คืนกระเป๋ายังถอยออกไปกดปุ่มเก็บได้ตามเดิม
	if not root:FindFirstChild("CarryPrompt") then
		local carry = Instance.new("ProximityPrompt")
		carry.Name = "CarryPrompt"
		carry.ActionText = "อุ้ม"
		carry.ObjectText = ""
		carry.KeyboardKeyCode = Enum.KeyCode.F
		carry.GamepadKeyCode = Enum.KeyCode.ButtonX
		carry.HoldDuration = 0
		carry.MaxActivationDistance = CARRY_RANGE
		carry.RequiresLineOfSight = false
		carry.Parent = root
		carry.Triggered:Connect(function(player)
			-- ลูบหัวสัตว์ของเพื่อนได้ แต่ **อุ้มไปวางที่อื่นไม่ได้** — นั่นคือการจัดของบนเกาะเขา
			if not IslandAccess.MayUseFixtures(player) then
				return Remotes.SocialNotify:FireClient(player, "warn", IslandAccess.FixtureDenied)
			end
			toggleCarry(model, player)
		end)
	end
end

--------------------------------------------------------------------------------
-- ลูบหัว
--------------------------------------------------------------------------------

function pat(model, player)
	local entry = Live[model]
	if not entry or entry.carriedBy then return end
	local last = PetTimes[player] or -math.huge
	if os.clock() - last < PET_COOLDOWN then return end
	PetTimes[player] = os.clock()

	-- หันมาหาคนลูบ แล้วกระโดดเบาๆ — ไม่มีอนิเมชันเฉพาะ ใช้สิ่งที่ Humanoid ทำได้อยู่แล้ว
	local root = model:FindFirstChild("HumanoidRootPart")
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if root and hrp then
		local look = Vector3.new(hrp.Position.X, root.Position.Y, hrp.Position.Z)
		root.CFrame = CFrame.lookAt(root.Position, look)
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.Jump = true end

	local name = model:GetAttribute("ItemId") == "Pet_Cat" and "แมว" or "สุนัข"
	Remotes.SocialNotify:FireClient(player, "info", ("%s ดูมีความสุข"):format(name))
end

--------------------------------------------------------------------------------
-- อุ้ม / วาง
--------------------------------------------------------------------------------

-- อุ้มแล้วเดินไปวางที่ใหม่ได้ — **ไม่ผ่านระบบตารางของเกาะ** เพราะสัตว์ไม่ได้กินช่อง
-- (มันเดินไปเรื่อยอยู่แล้ว การจองช่องให้ของที่ขยับตลอดเวลาไม่มีความหมาย)
--
-- ⚠️ **อุ้ม = เชื่อม (Weld) ตัวสัตว์เข้ากับตัวคนอุ้ม** (แก้ 2026-09-25 ผู้ใช้แจ้ง "อุ้มแล้วกระตุกไปมา")
-- เดิมเซิร์ฟเวอร์เขียน CFrame ของสัตว์ทุกเฟรม แต่ตัวสัตว์ไม่ anchored ฟิสิกส์ยังทำงาน และ Roblox ยกความเป็น
-- เจ้าของฟิสิกส์ให้ผู้เล่นที่อยู่ใกล้ = สองฝั่งแย่งกันขยับ + ตำแหน่งคนอุ้มบนเซิร์ฟเวอร์ช้ากว่าบนจอเขา
-- เชื่อมแล้วสัตว์เป็นชิ้นส่วนเดียวกับตัวคนอุ้ม เครื่องของคนอุ้มขยับให้เองทั้งก้อน ลื่นเท่าตัวละคร
-- ระหว่างอุ้ม: ไร้มวล (ไม่ถ่วงคนอุ้ม) · ไม่ชน (ไม่ดันคนอุ้ม) · PlatformStand (ขาไม่พยายามเดิน)
local CARRY_OFFSET = CFrame.new(0, 0.5, -2.2) * CFrame.Angles(0, math.pi, 0)

local function setCarried(model, on)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.PlatformStand = on end
	-- ระหว่างอุ้ม ปุ่ม E/F ลอยตามหน้าคนอุ้มตลอด (ผู้ใช้สั่ง 2026-09-25 ให้ซ่อน) → ปิดทั้งสองปุ่มสำหรับทุกคน
	-- คนอุ้มวางลงผ่านปุ่มบนจอของตัวเอง (IslandPetController ← แอตทริบิวต์ CarriedBy · Remotes.IslandPetDrop)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	for _, name in ipairs({ "PetPrompt", "CarryPrompt" }) do
		local prompt = hrp and hrp:FindFirstChild(name)
		if prompt then prompt.Enabled = not on end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Root" then
			if on then
				d:SetAttribute("PetCollide", d.CanCollide)
				d.CanCollide, d.Massless = false, true
			else
				local was = d:GetAttribute("PetCollide")
				if was ~= nil then d.CanCollide = was end
				d.Massless = false
				d:SetAttribute("PetCollide", nil)
			end
		end
	end
end

local function release(model, entry)
	entry.carriedBy = nil
	model:SetAttribute("CarriedBy", nil)
	local root = model:FindFirstChild("HumanoidRootPart")
	local weld = root and root:FindFirstChild("PetCarryWeld")
	if weld then weld:Destroy() end
	setCarried(model, false)
end

function toggleCarry(model, player)
	local entry = Live[model]
	if not entry then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	if entry.carriedBy == player then
		-- วางลง: ตรงหน้าคนอุ้ม ระดับพื้น
		release(model, entry)
		local root = model:FindFirstChild("HumanoidRootPart")
		if root then
			local drop = hrp.CFrame * CFrame.new(0, 0, -4)
			root.CFrame = CFrame.new(drop.Position.X, hrp.Position.Y - 1.5, drop.Position.Z)
			-- เดินเล่นรอบจุดใหม่ ไม่ใช่เดินกลับไปที่เดิม
			model:SetAttribute("WanderHome", root.Position)
		end
		BeastGait.Attach(model, { wander = true })
		Remotes.SocialNotify:FireClient(player, "info", "วางลงแล้ว")
		return
	end

	if entry.carriedBy then
		return Remotes.SocialNotify:FireClient(player, "error", "มีคนอุ้มอยู่แล้ว")
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then return end
	entry.carriedBy = player
	model:SetAttribute("CarriedBy", player.UserId)
	BeastGait.Detach(model)
	setCarried(model, true)
	root.CFrame = hrp.CFrame * CARRY_OFFSET
	local weld = Instance.new("Weld")
	weld.Name = "PetCarryWeld"
	weld.Part0, weld.Part1 = hrp, root
	weld.C0 = CARRY_OFFSET
	weld.Parent = root
	Remotes.SocialNotify:FireClient(player, "info", "อุ้มไว้แล้ว — กด F หรือปุ่ม วางลง บนจอ")
end

-- คนอุ้มตาย/ร่างใหม่/ออกเกม = ปล่อยสัตว์ลงตรงนั้น (Weld ไปกับร่างเก่า ต้องคืนสภาพสัตว์เอง)
-- ไม่เขียน CFrame ทุกเฟรมแล้ว — Weld ทำให้เอง (ดูหมายเหตุเหนือ setCarried)
RunService.Heartbeat:Connect(function()
	for model, entry in pairs(Live) do
		if not model.Parent then
			Live[model] = nil
		elseif entry.carriedBy then
			local char = entry.carriedBy.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local root = model:FindFirstChild("HumanoidRootPart")
			local weld = root and root:FindFirstChild("PetCarryWeld")
			if not (hrp and root and weld and weld.Part0 == hrp) then
				release(model, entry)
				BeastGait.Attach(model, { wander = true })
			end
		end
	end
end)

Remotes.IslandPetDrop.OnServerEvent:Connect(function(player)
	for model, entry in pairs(Live) do
		if entry.carriedBy == player then
			toggleCarry(model, player)
			return
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	PetTimes[player] = nil
	for model, entry in pairs(Live) do
		if entry.carriedBy == player then
			release(model, entry)
			BeastGait.Attach(model, { wander = true })
		end
	end
end)

--------------------------------------------------------------------------------
-- บัพให้ทั้งฟาร์ม
--------------------------------------------------------------------------------

-- มีสัตว์เลี้ยงอยู่บนเกาะไหม · **นับจากของที่วางอยู่จริง ไม่ใช่จากตารางที่จำไว้**
-- ผู้เล่นเก็บสัตว์คืนกระเป๋าได้ตลอด คำตอบจึงต้องมาจากโลกตอนนี้
local function petCount()
	local n = 0
	for model in pairs(Live) do
		if model.Parent then n += 1 end
	end
	return n
end

-- ของตกแต่งที่วางอยู่กี่ชิ้น — ยิ่งเยอะ EXP จากฟาร์มยิ่งเพิ่ม (ผู้ใช้สั่ง)
local function decorCount()
	local data = IslandAccess.Data and IslandAccess.Data()
	if not data then return 0 end
	local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
	local n = 0
	for _, entry in ipairs(data.placed or {}) do
		local item = ItemCatalog.Get(entry.id)
		-- นับเฉพาะของตกแต่ง: ไม่นับแปลงผัก คอก โซนแร่ บ้าน สัตว์เลี้ยง ซึ่งเป็นเครื่องมือ ไม่ใช่การตกแต่ง
		if item and item.kind == "placeable" and item.spot and not item.pet
			and entry.id:sub(1, 5) == "Deco_" then
			n += 1
		end
	end
	return n
end

-- ตัวคูณเวลาโตของพืช (< 1 = เร็วขึ้น) — `IslandPlots` เรียกตอนคำนวณว่าสุกหรือยัง
IslandAccess.GrowthMultiplier = function()
	if petCount() > 0 then return 1 - IslandConfig.PetGrowBonus end
	return 1
end

-- ตัวคูณ EXP จากการทำฟาร์ม (> 1 = ได้เพิ่ม) — สัตว์เลี้ยง + จำนวนของตกแต่ง
IslandAccess.FarmExpMultiplier = function()
	local bonus = 0
	if petCount() > 0 then bonus += IslandConfig.PetExpBonus end
	bonus += math.min(decorCount() * IslandConfig.DecorExpPerItem, IslandConfig.DecorExpCap)
	return 1 + bonus
end

--------------------------------------------------------------------------------
-- ลูปหาสัตว์ที่เพิ่งถูกวาง
--------------------------------------------------------------------------------

-- กฎเหล็กของโปรเจ็ค: ลูปถามใหม่ ไม่ใช่ผูก event ครั้งเดียว — ของถูกวางตอนไหนก็ได้
task.spawn(function()
	while true do
		local island = workspace:FindFirstChild("WOLD_Island")
		local placed = island and island:FindFirstChild("Placed")
		if placed then
			for _, model in ipairs(placed:GetChildren()) do
				if model:IsA("Model") and isPet(model) then setup(model) end
			end
		end
		task.wait(1)
	end
end)

-- ช่องเทสใน Studio (ทรงเดียวกับ IslandTest)
if RunService:IsStudio() then
	local bf = Instance.new("BindableFunction")
	bf.Name = "PetTest"
	bf.OnInvoke = function(op, ...)
		if op == "Count" then return petCount() end
		if op == "Decor" then return decorCount() end
		if op == "Growth" then return IslandAccess.GrowthMultiplier() end
		if op == "Exp" then return IslandAccess.FarmExpMultiplier() end
		if op == "Pat" then pat(...) return true end
		if op == "Carry" then toggleCarry(...) return true end
		if op == "CarriedBy" then
			local model = ...
			local e = Live[model]
			return e and e.carriedBy or nil
		end
		error("PetTest: ไม่มี op " .. tostring(op))
	end
	bf.Parent = game:GetService("ServerStorage")
end
