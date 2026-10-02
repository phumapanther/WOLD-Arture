-- node tools/offline-test.js tests/farm_corn_test.lua   (หรือ node tools/lua.js tests/farm_corn_test.lua Edit)
-- ข้าวโพด/อ้อย + ของคราฟชุดเนย-น้ำตาล + หุ่นฟางฝึกซ้อม (ผู้ใช้อนุมัติตาราง 2026-10-02 · เลเวลฟาร์ม 15-25)
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end
local RS = game.ReplicatedStorage
local ItemCatalog, IslandConfig = fresh(RS.ItemCatalog), fresh(RS.IslandConfig)
local CraftConfig, ShopConfig = fresh(RS.CraftConfig), fresh(RS.ShopConfig)
local ExportConfig, ProgressionConfig = fresh(RS.ExportConfig), fresh(RS.ProgressionConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

-- 1. ไอเทม
for _, id in ipairs({ "Corn", "Sugarcane", "CornSeed", "SugarcaneSeed", "Butter", "Popcorn", "Sugar", "Caramel",
	"GrilledButterCorn", "BakedButterCorn" }) do
	check(ItemCatalog.Exists(id), "มีไอเทม " .. id)
end
local dummy = ItemCatalog.Get("TrainingDummy")
check(dummy and dummy.kind == "placeable", "หุ่นฟางฝึกซ้อม = ของวางบนเกาะ")

-- 2. พืช: ปลูกจากเมล็ดของมันเอง ตามเลเวล
local function grows(seed, level, item)
	for _, c in ipairs(IslandConfig.CropsFor(seed, level)) do
		if c.item == item then return c end
	end
	return nil
end
local corn, cane = grows("CornSeed", 15, "Corn"), grows("SugarcaneSeed", 17, "Sugarcane")
check(corn and corn.seconds == 30 * 60 and corn.min == 2 and corn.max == 4, "ข้าวโพด Lv15 · 30 นาที · 2-4")
check(cane and cane.seconds == 35 * 60 and cane.min == 2 and cane.max == 4, "อ้อย Lv17 · 35 นาที · 2-4")
check(not grows("CornSeed", 14, "Corn") and not grows("SugarcaneSeed", 16, "Sugarcane"), "ยังไม่ถึงเลเวล = ไม่งอก")
check(not grows("Seed", 30, "Corn") and not grows("Seed", 30, "Sugarcane"), "เมล็ดสุ่มไม่ให้ข้าวโพด/อ้อย")
check(table.find(IslandConfig.SeedItems, "CornSeed") and table.find(IslandConfig.SeedItems, "SugarcaneSeed"),
	"เมล็ดใหม่หยอดลงแปลงได้")

-- 3. สูตร (ต่อท้าย CraftConfig — ลำดับคือสัญญากับไคลเอนต์)
local byId, lastOld, firstNew = {}, nil, nil
for i, r in ipairs(CraftConfig.Recipes) do
	if r.tab ~= "unlucky" then byId[r.id] = r end
	if r.id == "AirshipKey" then lastOld = i end
	if r.id == "Butter" and not firstNew then firstNew = i end
end
check(lastOld and firstNew and firstNew > lastOld, "สูตรใหม่อยู่ท้ายรายการ (หลังกุญแจเรือเหาะ)")
local function recipe(id, station, level, cost, yields)
	local r = byId[id]
	local same = r and r.station == station and r.level == level and (r.yields or 1) == (yields or 1) and r.batch == true
	for item, n in pairs(cost) do same = same and r.cost[item] == n end
	for item in pairs(r and r.cost or {}) do same = same and cost[item] ~= nil end
	check(same, ("%s @%s Lv%d"):format(id, station, level))
end
recipe("Butter", "bakery", 15, { Milk = 3 })
recipe("Popcorn", "bakery", 16, { Corn = 3, Butter = 1 }, 2)
recipe("Sugar", "bakery", 18, { Sugarcane = 3 }, 2)
recipe("Caramel", "bakery", 22, { Sugar = 2, Butter = 1, Milk = 1 })
recipe("GrilledButterCorn", "stove", 23, { Corn = 2, Butter = 2 })
recipe("BakedButterCorn", "bakery", 25, { Corn = 3, Butter = 2, Caramel = 1 })
recipe("CreamCake", "bakery", 15, { Dough = 3, Egg = 4, Butter = 1 }) -- สูตรเก่าเปลี่ยนนมเป็นเนย

-- 4. ร้านเกาะ
local rows = {}
for _, row in ipairs(ShopConfig.IslandSells) do rows[row.id] = row end
check(rows.CornSeed and rows.CornSeed.level == 15 and rows.SugarcaneSeed and rows.SugarcaneSeed.level == 17,
	"ร้านขายเมล็ดข้าวโพด Lv15 · อ้อย Lv17")
check(rows.TrainingDummy and rows.TrainingDummy.level == 19 and ShopConfig.PricesOf(rows.TrainingDummy) == 15000,
	"ร้านขายหุ่นฟาง Lv19 15,000")

-- 5. ใบสั่งส่งออก
for _, id in ipairs({ "Corn", "Sugarcane", "Butter", "Popcorn", "Sugar", "Caramel", "GrilledButterCorn", "BakedButterCorn" }) do
	check(ExportConfig.ById[id] ~= nil, "ส่งออกได้: " .. id)
end

-- 6. เพดาน EXP หุ่นฟาง 1,000/วัน รวมทุกตัว
local grant = ProgressionConfig.DummyGrant
check(ProgressionConfig.DummyDailyExpCap == 1000, "เพดาน 1,000 ต่อวัน")
local g, rec, capped = grant(nil, 100)
check(g == 5 and rec.day == 100 and rec.exp == 5 and not capped, "ครั้งแรกของวัน = 5")
g, rec, capped = grant({ day = 100, exp = 998 }, 100)
check(g == 2 and rec.exp == 1000 and capped, "เหลือ 2 = ได้ 2 แล้วชนเพดาน (บอกครั้งเดียว)")
g, rec, capped = grant({ day = 100, exp = 1000 }, 100)
check(g == 0 and rec.exp == 1000 and not capped, "เต็มแล้ว = 0 ไม่บอกซ้ำ")
g, rec = grant({ day = 99, exp = 1000 }, 100)
check(g == 5 and rec.day == 100 and rec.exp == 5, "วันใหม่ = เริ่มนับใหม่")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
