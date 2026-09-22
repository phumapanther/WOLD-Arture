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

assert(game.PlaceId == 136992335889132 or game.PlaceId == 0, "เฟสนี้สำหรับเพลสเกาะเท่านั้น")

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

local skinFolder = folder(RS, "WOLD_Skins")
local itemFolder = folder(SS, "Model_Item")

-- ตัวสร้างถูกฝังมากับเฟสนี้ตอน build (ดู tools/run-luau.js --skins) — ไม่มีก็แจ้งให้ชัด
local BUILDERS = _G.WOLD_SKIN_BUILDERS
if not BUILDERS then
	status("⚠ ไม่มีตัวสร้างโมเดล — ต้องรันด้วย --skins (node tools/run-luau.js mapgen/98_island_skins.lua --skins --no-lib)", true)
	return
end

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

local msg = ("done: ติดตั้ง %d ชิ้น · มีอยู่แล้ว %d"):format(#made, kept)
if #missing > 0 then msg = msg .. (" · ⚠ ขาด %d: %s"):format(#missing, table.concat(missing, ", ")) end
status(msg, true)
