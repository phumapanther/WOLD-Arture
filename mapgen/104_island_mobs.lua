-- 104_island_mobs.lua: ต้นแบบมอนให้ `Mobs.server` บนเพลสเกาะ → ServerStorage.Model_moster (มอนบุกกลางคืน 2026-09-28)
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/104_island_mobs.lua --kit --models --no-lib
--
-- ต่อด้วยบอส + ท่าถืออาวุธ (สองเฟสเดิม รันบนเพลสเกาะได้เหมือนเพลสหลัก):
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/82_boss_prototype.lua --kit
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/86_repin_held_gear.lua --no-lib
--
-- ⚠️ **ห้ามรันที่เพลสหลัก** — ต้นแบบที่นั่นผู้ใช้วางเองและแก้ท่ามาแล้ว (เฟส 84-86) · เฟสหยุดเองถ้าไม่ใช่เพลสเกาะ
-- ไม่มีต้นแบบ = `Mobs.buildMonster` ถอยไปปั้นลูกบอลสไลม์เขียวให้ทุกชนิด (เงียบ ไม่มี error)
-- สไลม์เขียวไม่ต้องมี (ลูกบอลของ `Mobs.buildSlime`) · รันซ้ำได้ (ลบตัวชื่อเดียวกันก่อน)
-- โมเดลมาจากโรงงานชุดเดียวกับสัตว์เลี้ยงเฟส 103 · `Mobs.buildFromModel` จัดการสคริปต์/ข้อต่อ R15/HumanoidRootPart เอง
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
if game.PlaceId ~= 136992335889132 then
	error("[IslandMobs] เฟสนี้รันเฉพาะเพลสเกาะ — PlaceId ตอนนี้ " .. game.PlaceId)
end

local BUILDERS = {
	"Monster_Bat", "Monster_Boar", "Monster_Wolf", "Monster_Spider",
	"Monster_Skeleton", "Monster_Bandit", "Monster_Ghoul", "Monster_ClockworkSentry", "Monster_Wraith",
	"Monster_StoneGolem", "Monster_SteamSlime", "Monster_PlasmaSlime", "Monster_BioSlime",
}

local folder = ServerStorage:FindFirstChild("Model_moster")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Model_moster"
	folder.Parent = ServerStorage
end

-- ของ kit ที่มอนในเกมไม่ต้องมี: สคริปต์โชว์ของโรงงาน · ปุ่ม · ป้ายชื่อ · แท็ก (ทรงเดียวกับ strip ในเฟส 103)
local function strip(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then d:Destroy() end
	end
	for _, d in ipairs(m:GetDescendants()) do
		for _, tag in ipairs(CollectionService:GetTags(d)) do CollectionService:RemoveTag(d, tag) end
	end
	for _, tag in ipairs(CollectionService:GetTags(m)) do CollectionService:RemoveTag(m, tag) end
end

local made, failed = 0, {}
for _, name in ipairs(BUILDERS) do
	local ok, err = pcall(function()
		local old = folder:FindFirstChild(name)
		if old then old:Destroy() end
		local m = K.place(name, workspace, CFrame.new(0, 5000, 0))
		if not m then error("ไม่มี builder (ลืม --models?)") end
		m.Parent = nil
		strip(m)
		m.Name = name
		m.Parent = folder
	end)
	if ok then made += 1 else failed[#failed + 1] = name .. ": " .. tostring(err) end
end
for _, f in ipairs(failed) do warn("[IslandMobs] " .. f) end
print(("[IslandMobs] done %d ตัว · พัง %d"):format(made, #failed))
