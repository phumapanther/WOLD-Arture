-- 98_island_skins.lua — ติดตั้งสกินอาวุธ เครื่องมือทอง และชุดแฟชั่นลงเพลสเกาะ
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/98_island_skins.lua --no-lib
--
-- ## ทำไมต้องมีเฟสนี้
--
-- สกินกับชุดเกราะ **ไม่ได้ซิงก์มากับ Rojo** เพราะมันไม่ใช่โค้ด มันคือ *โมเดล* ที่วางมือไว้ในเพลสหลัก
-- (`ReplicatedStorage.WOLD_Skins` และ `ServerStorage.Model_Item`) — เพลสเกาะจึงไม่มีเลยสักชิ้น
--
-- ผลคือ: ข้อมูลซิงก์ถูกทุกอย่าง (สกินที่ติดตั้งอยู่ใน `meta.skin` ชุดที่ใส่อยู่ในโปรไฟล์เดียวกัน)
-- แต่ **มองไม่เห็นอะไรเลยบนเกาะ** — `WeaponVisuals` หาโมเดลสกินไม่เจอก็ตกไปใช้รูปทรงมาตรฐาน
-- และ `KitWear` หาชุดไม่เจอก็ไม่ใส่อะไรให้ พร้อม warn ลง F9
--
-- เฟสนี้สร้างจาก **ต้นฉบับในรีโป** (`assets/models-from-factory/*.lua`) ซึ่ง CLAUDE.md บันทึกไว้ว่า
-- "ถ้าเพลสหาย ติดตั้งใหม่ได้โดยไม่ต้องเปิดโรงงาน" — นี่คือการใช้งานจริงครั้งแรกของมัน
--
-- **รันซ้ำได้**: ของที่มีอยู่แล้วถูกข้าม (ไม่ทับของที่ผู้ใช้แก้มือ) · `SkinsErase = true` เพื่อล้างทิ้ง
--
-- ⚠️ **ห้ามเอาสกินไปไว้ใน `WOLD_Weapons`** โฟลเดอร์นั้นถูก `WeaponPrefabs.server` ลบทิ้งแล้วสร้างใหม่
-- ทุกครั้งที่เซิร์ฟเวอร์บูต ของจะหายหมด (กฎเดิมใน CLAUDE.md)
local RS, SS = game:GetService("ReplicatedStorage"), game:GetService("ServerStorage")

-- รันได้ทั้งเพลสเกาะและเพลสหลัก: ต้นฉบับอยู่ในรีโปทั้งคู่ และเพลสหลักก็เคยทำ `WOLD_Skins` หายมาแล้ว
-- (ตรวจ 2026-09-22: ไม่มีสักชิ้น → สกินกาชาแปดชิ้นตกไปใช้รูปทรงมาตรฐานย้อมสี)
assert(game.PlaceId == 136992335889132 or game.PlaceId == 88774255487951 or game.PlaceId == 0,
	"เฟสนี้สำหรับเพลสเกาะหรือเพลสหลักเท่านั้น")

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[Skins] " .. msg)
end

local ERASE = workspace:GetAttribute("SkinsErase") == true

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then f = Instance.new("Folder"); f.Name = name; f.Parent = parent end
	return f
end

if ERASE then
	for _, spec in ipairs({ { RS, "WOLD_Skins" }, { SS, "Model_Item" } }) do
		local f = spec[1]:FindFirstChild(spec[2])
		if f then f:Destroy() end
	end
	status("done: ลบ WOLD_Skins และ Model_Item ออกแล้ว", true)
	return
end

-- ชื่อไฟล์ → ที่อยู่ปลายทาง
--
-- **ชุดแฟชั่นไปอยู่ `ServerStorage.Model_Item`** ไม่ใช่ workspace — มันคือต้นแบบไว้โคลน ไม่ใช่ของในโลก
-- (บทเรียน 2026-09-19: วางไว้ workspace ที่ (0,0,0) แล้วชุดโผล่ใต้ดินเพราะผิวดินตรงนั้นอยู่ y=56)
local SKINS = {
	"Skin_Sword_Ember", "Skin_Sword_Frost", "Skin_Greatsword_Gold", "Skin_Greatsword_Void",
	"Skin_Bow_Vine", "Skin_Pistol_Brass", "Skin_Staff_Storm", "Skin_Spellbook_Blood",
	"GoldAxe", "GoldPickaxe", "GoldShovel", "GoldFishingRod",
}
local KITS = { "Fashion_Knight_CrimsonKit", "Fashion_Ranger_ShadowKit", "Fashion_Royal_GoldKit" }

-- **ชุดเกราะสามชุดหลัก** มาคนละทางกับของข้างบน: มันไม่มีต้นฉบับที่โรงงาน มันยืนอยู่ในแมพหลักจริงๆ
-- จึงถูกคัดลอกออกมาเป็นตัวเลข (`assets/models-from-main/armorkits.lua` · รันด้วย `--furniture`)
-- · ไม่มีข้อมูลก็ข้ามไปเงียบๆ เพราะเพลสหลักมีของจริงอยู่แล้วใน `workspace.Model_Item`
local ARMOR = { "Armor_PlateKit", "Armor_LeatherKit", "Armor_ChainKit" }
local armorBuild = _G.WOLD_MAIN_MODELS and _G.WOLD_MAIN_MODELS.armorkits

local skinFolder = folder(RS, "WOLD_Skins")
local itemFolder = folder(SS, "Model_Item")

-- ตัวสร้างถูกฝังมากับเฟสนี้ตอน build (ดู tools/run-luau.js --skins) — ไม่มีก็แจ้งให้ชัด
local BUILDERS = _G.WOLD_SKIN_BUILDERS
if not BUILDERS then
	status("⚠ ไม่มีตัวสร้างโมเดล — ต้องรันด้วย --skins (node tools/run-luau.js mapgen/98_island_skins.lua --skins --no-lib)", true)
	return
end

-- **ระยะยกของโรงงาน (O) ที่ต้องหักออก** — ผู้ใช้แจ้ง 2026-09-22: "สกินทองถือกลางอุปกรณ์ ไม่ใช่ตรงด้าม"
--
-- โรงงานยกโมเดลขึ้นพ้นแท่นโชว์ก่อน export ส่วนผังของเกมคือ **ปลายที่ใช้งานอยู่ที่จุดกำเนิด ด้ามที่ y = 2.0**
-- ซึ่ง `WeaponVisuals.GRIP` วัดมาจากผังนั้น · ไม่หักออก = ทั้งชิ้นสูงเกินไป 2.2 ฝ่ามือเลยไปอยู่กลางด้าม
-- (วัดยืนยัน: ดาบมี `Handle` ที่ y 4.20 ซึ่ง 4.20 - 2.2 = 2.00 ตรงผังเป๊ะ · ปืน `Grip` 3.40 - 1.4 = 2.00)
--
-- **`Root` ไม่ขยับ** มันคือ PrimaryPart ที่ Motor6D ขับ ต้องอยู่ที่จุดกำเนิดเสมอ — ที่เลื่อนคือตัวโมเดล
local LIFT = {
	Skin_Sword_Ember = 2.2, Skin_Sword_Frost = 2.2,
	Skin_Greatsword_Gold = 2.9, Skin_Greatsword_Void = 2.9,
	Skin_Bow_Vine = 2.6,
	Skin_Pistol_Brass = 1.4,
	Skin_Staff_Storm = 2.4,
	Skin_Spellbook_Blood = 0.5,
	GoldAxe = 2.2, GoldPickaxe = 2.2, GoldShovel = 2.2, GoldFishingRod = 2.2,
}

local made, kept, missing = {}, 0, {}

local function install(name, parent)
	if parent:FindFirstChild(name) then kept += 1 return end
	local build = BUILDERS[name]
	if not build then missing[#missing + 1] = name return end
	local ok, model = pcall(build)
	if not ok or not model then missing[#missing + 1] = name .. "(สร้างไม่ผ่าน)" return end
	model.Name = name
	-- ต้นแบบต้องนิ่ง ไม่ร่วง และไม่ไปขวางอะไร
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end

	-- ⚠️ **เชื่อมทุกชิ้นเข้า `Root` ด้วย** (แก้ 2026-09-22: ผู้ใช้แจ้งว่าถือเครื่องมือทองแล้วไม่เห็นโมเดล)
	--
	-- `WeaponVisuals` ปลด `Anchored` ตอนเอาไปแขวนกับมือ (ไม่งั้นตัวละครถูกตรึง) แล้วขับ **เฉพาะ
	-- `PrimaryPart`** ด้วย Motor6D ตัวเดียว — ชิ้นที่เหลือที่ไม่ได้เชื่อมไว้จึงร่วงลงพื้นทันที
	-- เหลือแต่ `Root` ที่มองไม่เห็นอยู่ในมือ = **อาการคือ "ไม่ขึ้นโมเดลเลย" ไม่ใช่ "โมเดลเพี้ยน"**
	--
	-- ตอนที่เป็นต้นแบบนอนรออยู่ มันถูก anchored อยู่แล้ว weld จึงไม่มีผลอะไรจนกว่าจะถูกถือ
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if root then
		model.PrimaryPart = root

		-- หักระยะยกของโรงงานออกก่อน แล้วค่อยเชื่อม (weld จำระยะตอนที่มันถูกสร้าง — สร้างก่อนเลื่อนไม่ได้)
		local lift = LIFT[name]
		if lift then
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") and d ~= root then d.CFrame = d.CFrame - Vector3.new(0, lift, 0) end
			end
		end

		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d ~= root then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = d
				weld.Parent = root
			end
		end
	else
		missing[#missing + 1] = name .. "(ไม่มี Root ให้เชื่อม)"
	end
	model.Parent = parent
	made[#made + 1] = name
end

for _, name in ipairs(SKINS) do install(name, skinFolder) end
for _, name in ipairs(KITS) do install(name, itemFolder) end

-- ⚠️ **ชุดเกราะไม่ผ่าน `install`** มันไม่มี `Root` ให้เชื่อมแบบอาวุธ และ **ห้ามเชื่อม weld เข้า Root**
-- ด้วย — `KitWear` แยกชิ้นไปเชื่อมกับข้อต่อ R15 ทีละชิ้นเอง · โครงสองชั้นก็ต้องอยู่ครบ
-- ⚠️ **เพลสหลักมีของจริงอยู่ใน `workspace.Model_Item`** — ห้ามสร้างสำเนาใน ServerStorage ทับ
-- `KitWear.Model` หา ServerStorage ก่อน สำเนาจึงชนะของจริง แล้ววันที่ผู้ใช้แก้ชุดในแมพด้วยมือ
-- การแก้นั้นจะถูกมองข้ามเงียบๆ (กับดักแบบเดียวกับ `WOLD_Weapons` ที่ค้างใน Edit datamodel)
local worldItems = workspace:FindFirstChild("Model_Item")
for _, name in ipairs(ARMOR) do
	if itemFolder:FindFirstChild(name) or (worldItems and worldItems:FindFirstChild(name)) then
		kept += 1
	elseif not armorBuild then
		missing[#missing + 1] = name .. "(ต้องรันด้วย --furniture)"
	else
		local ok, model = pcall(armorBuild, name)
		if ok and model then
			model.Parent = itemFolder
			made[#made + 1] = name
		else
			missing[#missing + 1] = name .. "(สร้างไม่ผ่าน)"
		end
	end
end

-- **หีบสมบัติ** มาทางเดียวกับชุดเกราะ (คัดลอกเป็นตัวเลขจากเพลสหลัก) — `TreasureChests.server` หาต้นแบบ
-- จาก `ServerStorage.Treasure` ถ้าไม่เจอมันจะ `warn` แล้วไม่วางหีบเลย ซึ่งเป็นอาการที่ผู้ใช้เจอบนเกาะ
-- (2026-09-23 "ไอเท้มหีบใช้แล้วโมเดลไม่ออกมา") · สคริปต์เพิ่งถูกถอดออกจาก denylist ของ farming
--
-- ⚠️ **ห้ามยกฐานขึ้น y = 0 และต้องตั้ง `WorldPivot` ไว้ที่จุดกำเนิด** — `spawnChest` วางด้วย
-- `PivotTo(y + ความสูง/2)` ซึ่งถูกต้องก็ต่อเมื่อจุดหมุนอยู่ตรงกับของเดิม (ตัวดัมพ์เทียบจากจุดหมุนเดิม)
local CHEST_FOLDER = "Treasure"
local chestBuild = _G.WOLD_MAIN_MODELS and _G.WOLD_MAIN_MODELS.chests
local ChestConfig = require(RS:WaitForChild("ChestConfig"))
local chestFolder = folder(SS, CHEST_FOLDER)
for _, tier in ipairs(ChestConfig.Order) do
	if chestFolder:FindFirstChild(tier) then
		kept += 1
	elseif not chestBuild then
		missing[#missing + 1] = tier .. "(ต้องรันด้วย --furniture)"
	else
		local ok, model = pcall(chestBuild, tier)
		if ok and model then
			model.Parent = chestFolder
			made[#made + 1] = tier
		else
			missing[#missing + 1] = tier .. "(สร้างไม่ผ่าน)"
		end
	end
end

local msg = ("done: ติดตั้ง %d ชิ้น · มีอยู่แล้ว %d"):format(#made, kept)
if #missing > 0 then msg = msg .. (" · ⚠ ขาด %d: %s"):format(#missing, table.concat(missing, ", ")) end
status(msg, true)
