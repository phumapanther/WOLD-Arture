-- node tools/offline-test.js tests/island_fishing_test.lua   (หรือ node tools/lua.js tests/island_fishing_test.lua Edit)
-- ตกปลาบนเกาะ (ผู้ใช้สั่ง 2026-10-02): ทั้งเกาะ = สระเดียว ตกได้ปลาครบทุกชนิดในเกม · บางทีได้ของดรอปมอน ·
-- ขยะ (เศษไม้ ก้อนหิน) · ขนมปัง/น้ำ — ของที่ไม่ใช่ปลาติดธง junk (ไม่มีน้ำหนัก ไม่นับสมุดสะสม/เควสปลา)
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end
local F = fresh(game.ReplicatedStorage.FishingConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local loot, zone = F.IslandLoot()
check(zone and zone.id == "IslandPond", "เขตบนเกาะ = สระบนเกาะ")
local inPool = {}
for _, entry in ipairs(loot) do inPool[entry.item] = entry end

-- ปลาทุกชนิดในเกม = ตารางปลาธรรมดา + ปลาประจำถิ่นทุกเขตของเกมหลัก
local missing = {}
for _, entry in ipairs(F.Loot) do
	if not inPool[entry.item] then missing[#missing + 1] = entry.item end
end
for _, z in ipairs(F.Zones) do
	for _, entry in ipairs(z.fish) do
		if not inPool[entry.item] then missing[#missing + 1] = entry.item end
	end
end
check(#missing == 0, "สระบนเกาะตกได้ปลาครบทุกชนิด · ขาด: " .. table.concat(missing, ","))

for _, id in ipairs({ "Slime", "Bone", "Fiber", "BatGuano", "Claw", "WoodScrap", "Stone", "Bread", "Water" }) do
	check(inPool[id] and inPool[id].junk == true and inPool[id].weight > 0, "ตกได้ของที่ไม่ใช่ปลา: " .. id)
end

local total, extra = 0, 0
for _, entry in ipairs(loot) do
	total += entry.weight
	if entry.junk then extra += entry.weight end
end
check(extra / total > 0.05 and extra / total < 0.25, ("ของที่ไม่ใช่ปลาออกบ้างไม่บ่อย: %.1f%%"):format(extra / total * 100))

-- ปลาไม่ถูกติดธง junk (ไม่งั้นเสียน้ำหนัก/สมุดสะสม)
local fishFlagged = false
for _, entry in ipairs(F.Loot) do if inPool[entry.item].junk then fishFlagged = true end end
check(not fishFlagged, "ปลาไม่ถูกนับเป็นของจิปาถะ")

-- เกมหลักไม่ถูกแตะ: ตารางปกติไม่มีของที่ไม่ใช่ปลา
local mainHasJunk = false
for _, entry in ipairs(F.Loot) do if entry.junk then mainHasJunk = true end end
check(not mainHasJunk, "เกมหลักยังตกได้แต่ปลา")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
