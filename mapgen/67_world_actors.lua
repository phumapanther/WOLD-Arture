-- 67_world_actors.lua — เปิดใช้งานโมเดลที่วางไว้ในแมพแล้ว: มอน สัตว์ แร่ ไร่นา
--
-- รัน: node tools/run-luau.js mapgen/67_world_actors.lua
--
-- **รันซ้ำได้** ติดแท็กซ้ำไม่มีผล และสปอว์เนอร์ที่สร้างแล้วจะถูกใช้ซ้ำแทนที่จะสร้างใหม่
--
-- แนวคิด: ของทั้งสี่กลุ่มถูกจัดวางไว้ในแมพแล้วคนละมุม ไฟล์นี้ไม่ย้ายอะไรเลย แค่ทำให้มัน "ทำงาน"
-- ตรงจุดที่มันยืนอยู่ ตามที่ผู้ใช้สั่ง
--
--   มอนสเตอร์  -> สร้างสปอว์เนอร์ทับตำแหน่งโมเดล แล้วย้ายโมเดลต้นแบบเข้า ServerStorage
--   สัตว์      -> ติดแท็ก WOLD_Node ที่ตัวมันเอง (กด E เอาของ ตัวสัตว์อยู่ที่เดิม)
--   แร่ / ไร่นา -> ติดแท็ก WOLD_Node เหมือนสัตว์
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local SPAWNER_TAG = "WOLD_Spawner"
local NODE_TAG = "WOLD_Node"

--------------------------------------------------------------------------------
-- ตาราง: ชื่อโมเดลในแมพ -> ชนิดใน config
--------------------------------------------------------------------------------

-- มอนสเตอร์: ชื่อโมเดล -> { kind, จำนวน, รัศมี }
--
-- จำนวนกับรัศมีตั้งตามความแข็ง: ตัวอ่อนเกิดเยอะและกระจายกว้าง ตัวแข็งเกิดน้อยและกระจุกกว่า
-- เพื่อไม่ให้เดินไปเจอโกเลมสามตัวพร้อมกันโดยบังเอิญ
local MONSTERS = {
	Monster_Bat = { kind = "Bat", count = 6, radius = 90 },
	Monster_Boar = { kind = "Boar", count = 4, radius = 80 },
	Monster_Wolf = { kind = "Wolf", count = 4, radius = 90 },
	Monster_Bandit = { kind = "Bandit", count = 3, radius = 80 },
	Monster_Ghoul = { kind = "Ghoul", count = 3, radius = 70 },
	Monster_ClockworkSentry = { kind = "ClockworkSentry", count = 3, radius = 70 },
	Monster_Wraith = { kind = "Wraith", count = 2, radius = 60 },
	Monster_StoneGolem = { kind = "StoneGolem", count = 2, radius = 60 },
}

-- สัตว์เลี้ยง · แร่ · ไร่นา: ชื่อโมเดล -> NodeKind ใน GatherConfig.Nodes
local NODES = {
	Animal_Chicken = "Chicken",
	Animal_Duck = "Duck",
	Animal_Cow = "Cow",
	Animal_Goat = "Goat",
	Animal_Sheep = "Sheep",
	Animal_Deer = "Deer",
	Animal_Horse = "Horse",
	Animal_Pig = "Pig",

	Ore_Magic = "MagicOre",
	Ore_Silver = "SilverOre",
	Ore_Gold = "GoldOre",
	Ore_Diamond = "DiamondOre",

	Farm_CropField = "CropField",
	Farm_WheatField = "WheatField",
	Farm_EtherCluster = "EtherCluster",
}

-- ชื่อที่เป็นสัตว์ ใช้ตั้งธง NoFade
local IS_ANIMAL = {
	Chicken = true, Duck = true, Cow = true, Goat = true,
	Sheep = true, Deer = true, Horse = true, Pig = true,
}

--------------------------------------------------------------------------------
-- โมเดลต้นแบบของมอน
--------------------------------------------------------------------------------

-- Mobs.server โคลนมอนจากโมเดลต้นแบบที่หาเจอตามชื่อ — ใน ServerStorage ก่อน แล้วค่อยทั่ว Workspace
--
-- **ตัวที่วางโชว์ไว้ในแมพถูกใช้เป็นต้นแบบตรงนั้นเลย ไม่ย้าย** เพราะ sandbox ของ Studio MCP ย้ายของ
-- เข้า ServerStorage ไม่ได้ (Capabilities: LoadUnownedAsset) — ลองแล้ว error
--
-- ราคาที่ต้องจ่าย: มีมอนยืนนิ่งอยู่ที่จุดนั้นหนึ่งตัวตลอดเวลา ตีไม่ได้ ไม่ขยับ จึงซ่อนมันแทน —
-- ย้ายลงไปใต้ดินลึกๆ ให้พ้นสายตา แต่ยังอยู่ใน Workspace ให้ prototypeFor หาเจอ
local HIDE_DEPTH = 2000

--------------------------------------------------------------------------------
-- มอนสเตอร์
--------------------------------------------------------------------------------

local madeSpawners, movedPrototypes = 0, 0

local function existingSpawner(name)
	for _, s in ipairs(CollectionService:GetTagged(SPAWNER_TAG)) do
		if s.Name == name then return s end
	end
	return nil
end

-- เก็บไว้ก่อน เพราะเราจะย้ายโมเดลออกจาก workspace ระหว่างวน
local monsterModels = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and MONSTERS[d.Name] then
		monsterModels[#monsterModels + 1] = d
	end
end

for _, model in ipairs(monsterModels) do
	local spec = MONSTERS[model.Name]
	local spawnerName = "Spawner_" .. spec.kind

	if existingSpawner(spawnerName) then
		print(("[Actors] มี %s อยู่แล้ว ข้าม"):format(spawnerName))
	else
		local pivot = model:GetPivot().Position

		local part = Instance.new("Part")
		part.Name = spawnerName
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(4, 1, 4)
		-- **ตรงตำแหน่งที่โมเดลถูกวางไว้เป๊ะ** ตามที่ผู้ใช้สั่ง ไม่ย้ายไปไหน
		part.Position = pivot
		part.Parent = workspace

		part:SetAttribute("MobKind", spec.kind)
		part:SetAttribute("Count", spec.count)
		part:SetAttribute("Radius", spec.radius)
		CollectionService:AddTag(part, SPAWNER_TAG)
		madeSpawners += 1

		print(("[Actors] %s -> %s ที่ (%.0f, %.0f, %.0f) จำนวน %d รัศมี %d")
			:format(model.Name, spawnerName, pivot.X, pivot.Y, pivot.Z, spec.count, spec.radius))
	end

	-- ซ่อนตัวโชว์: ย้ายลงใต้ดินลึก ปิดการชน ปิดปุ่ม E ที่ติดมากับโมเดล
	--
	-- ถ้ามีต้นแบบใน ServerStorage อยู่แล้ว (เช่น Ghoul, ClockworkSentry, StoneGolem) ก็ลบตัวโชว์ทิ้งได้เลย
	local stored = ServerStorage:FindFirstChild("Model_mosterV2")
	local hasStored = stored and stored:FindFirstChild(model.Name)
	if hasStored then
		model:Destroy()
	else
		local pos = model:GetPivot().Position
		model:PivotTo(CFrame.new(pos.X, pos.Y - HIDE_DEPTH, pos.Z))
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
			elseif d:IsA("ProximityPrompt") then
				d.Enabled = false
			end
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = 0 end
		movedPrototypes += 1
	end
end

--------------------------------------------------------------------------------
-- สัตว์ · แร่ · ไร่นา
--------------------------------------------------------------------------------

local taggedNodes, alreadyTagged = 0, 0

for _, d in ipairs(workspace:GetDescendants()) do
	local kind = d:IsA("Model") and NODES[d.Name]
	if kind then
		-- ต้องมีชิ้นส่วนสักชิ้นให้แขวนปุ่ม ไม่งั้นติดแท็กไปก็ไม่มีอะไรเกิดขึ้น
		local hasPart = d.PrimaryPart ~= nil
		if not hasPart then
			for _, c in ipairs(d:GetDescendants()) do
				if c:IsA("BasePart") then hasPart = true break end
			end
		end

		if hasPart then
			d:SetAttribute("NodeKind", kind)
			if IS_ANIMAL[kind] then
				d:SetAttribute("NoFade", true)
			end
			if CollectionService:HasTag(d, NODE_TAG) then
				alreadyTagged += 1
			else
				CollectionService:AddTag(d, NODE_TAG)
				taggedNodes += 1
			end
		end
	end
end

print(("[Actors] เสร็จ — สปอว์เนอร์มอนใหม่ %d จุด · ย้ายต้นแบบ %d ตัว · ติดแท็กโหนดใหม่ %d จุด (มีอยู่แล้ว %d)")
	:format(madeSpawners, movedPrototypes, taggedNodes, alreadyTagged))
