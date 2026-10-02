-- node tools/lua.js tests/farm_tuning_test.lua Edit
-- ปรับค่า 2026-09-25: สัตว์ในคอกสุ่ม 1-5 ถ่วงน้ำหนัก · แร่ 50/30/10/10 · เควสเงิน ≤1000 ซิลเวอร์ ≤100 · ขนมปัง · บ่อน้ำ
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
local IslandConfig, GatherConfig = fresh(RS.IslandConfig), fresh(RS.GatherConfig)
local QuestConfig, CraftConfig = fresh(RS.QuestConfig), fresh(RS.CraftConfig)
local ShopConfig = fresh(RS.ShopConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end
local function near(a, b) return math.abs(a - b) < 0.02 end

-- สัตว์: สุ่ม 20,000 ครั้ง สัดส่วนต้องใกล้ 5/50/20/20/5
local counts = { 0, 0, 0, 0, 0 }
for _ = 1, 20000 do
	local n = IslandConfig.RollPenYield()
	counts[n] += 1
end
local share = function(n) return counts[n] / 20000 end
check(near(share(2), 0.50), ("ได้ 2 = %.1f%% (เป้า 50)"):format(share(2) * 100))
check(near(share(3) + share(4), 0.40), ("ได้ 3+4 = %.1f%% (เป้า 40)"):format((share(3) + share(4)) * 100))
check(near(share(1) + share(5), 0.10), ("ได้ 1+5 = %.1f%% (เป้า 10)"):format((share(1) + share(5)) * 100))

-- แร่: สายเหล็ก = หิน 50 · เหล็ก 30 · ถ่านหิน 10 · อื่นรวม 10
local roll = GatherConfig.Nodes.IronOre and GatherConfig.Nodes.IronOre.roll
local by = {}
for _, r in ipairs(roll or {}) do by[r.item] = (by[r.item] or 0) + r.chance end
local othersSum = 0
for id, c in pairs(by) do if id ~= "Stone" and id ~= "IronOre" and id ~= "Coal" then othersSum += c end end
check(roll and near(by.Stone, 0.50) and near(by.IronOre, 0.30) and near(by.Coal, 0.10) and near(othersSum, 0.10),
	("สายเหล็ก หิน %.2f เหล็ก %.2f ถ่าน %.2f อื่น %.2f"):format(by.Stone or 0, by.IronOre or 0, by.Coal or 0, othersSum))
local coal = {}
for _, r in ipairs(GatherConfig.Nodes.Coal.roll) do coal[r.item] = (coal[r.item] or 0) + r.chance end
check(near(coal.Stone, 0.50) and near(coal.Coal, 0.45), "สายถ่านหินไม่ถูกแตะ (50/45)")

-- เควส: ทุกงานในทุกบอร์ด
local maxGold, maxSilver = 0, 0
for _, board in ipairs(QuestConfig.Boards) do
	for _, spec in ipairs(board.pool) do
		local silver, gold = QuestConfig.RewardFor(spec)
		maxGold, maxSilver = math.max(maxGold, gold), math.max(maxSilver, silver)
	end
end
check(maxGold <= 1000 and maxSilver <= 100, ("เควสสูงสุด เงิน %d ซิลเวอร์ %d"):format(maxGold, maxSilver))

-- ขนมปังที่เตา · บ่อน้ำ
local bread
for _, r in ipairs(CraftConfig.Recipes) do
	if r.id == "Bread" and r.station == "stove" then bread = r end
end
check(bread and bread.cost.Wheat == 15 and bread.cost.Water == 5, "ขนมปัง = ข้าว 15 น้ำ 5 ที่เตา")
local well = GatherConfig.Nodes.Well
check(well and well.item == "Water" and well.min == 5 and well.max == 5 and not well.tool, "บ่อน้ำ = น้ำ 5 ขวด ไม่ใช้เครื่องมือ")

-- เลเวลสัตว์ (2026-09-25): โตเองตามอายุ Lv5 ครบ 7 วัน · ได้สูงสุดเท่าเลเวล · ตัวใหญ่ขึ้นทุกเลเวล
local DAY = 86400
local t0 = 1000000
check(IslandConfig.PenLevelOf(t0, t0) == 1, "ซื้อมา = Lv1")
check(IslandConfig.PenLevelOf(t0, t0 + 1.74 * DAY) == 1 and IslandConfig.PenLevelOf(t0, t0 + 1.76 * DAY) == 2, "Lv2 ที่ 1.75 วัน")
check(IslandConfig.PenLevelOf(t0, t0 + 6.99 * DAY) == 4 and IslandConfig.PenLevelOf(t0, t0 + 7 * DAY) == 5, "Lv5 ครบ 7 วันพอดี")
check(IslandConfig.PenLevelOf(t0, t0 + 30 * DAY) == 5 and IslandConfig.PenNextLevelIn(t0, t0 + 8 * DAY) == nil, "เพดาน Lv5")
check(math.abs(IslandConfig.PenNextLevelIn(t0, t0) - 1.75 * DAY) < 1, "Lv1 → Lv2 อีก 1.75 วัน")
local maxAt, onlyOne = {}, true
for level = 1, 5 do
	maxAt[level] = 0
	for _ = 1, 3000 do
		local n = IslandConfig.RollPenYield(level)
		maxAt[level] = math.max(maxAt[level], n)
		if level == 1 and n ~= 1 then onlyOne = false end
	end
end
check(onlyOne, "Lv1 ได้ 1 เสมอ")
check(maxAt[2] == 2 and maxAt[3] == 3 and maxAt[4] == 4 and maxAt[5] == 5,
	("ได้สูงสุดตามเลเวล %d/%d/%d/%d"):format(maxAt[2], maxAt[3], maxAt[4], maxAt[5]))
local sc = IslandConfig.PenLevelScale
check(sc[1] < sc[2] and sc[2] < sc[3] and sc[3] < sc[4] and sc[4] < sc[5] and sc[5] == 2, "ตัวโตทุกเลเวล Lv5 = 2 เท่า")

-- เมล็ด · หนอน · ราคา
local sb = IslandConfig.SeedBonus
check(sb.chance == 0.3 and sb.min == 1 and sb.max == 2, "เมล็ดติดมา 1-2 โอกาส 30%")
local wb = GatherConfig.WormBonus
check(wb.min == 3 and wb.max == 5 and wb.chance == 0.4 and GatherConfig.Nodes.Herb.bonus == wb, "หนอน 3-5 โอกาส 40% (สมุนไพร/นาข้าว)")
local pw = IslandConfig.PlotWormBonus
check(pw and pw.item == "Worm" and pw.min == 1 and pw.max == 3 and pw.chance == 0.2, "แปลงผัก + พุ่มบนเกาะ: หนอน 1-3 โอกาส 20% (ผู้ใช้สั่ง 2026-09-29 · พุ่ม 2026-10-01)")
local price = {}
for _, row in ipairs(ShopConfig.IslandSells) do
	price[row.id] = (ShopConfig.PricesOf(row)) -- เฟส 2a: ทุกแถวสองราคา ค่าแรก = เหรียญ
end
check(price.AnimalPen == 7500 and price.MineZone == 30000 and price.FarmPlot == 5000, -- 2026-10-02
	("ราคา คอก %s · โซนแร่ %s · แปลงดิน %s"):format(tostring(price.AnimalPen), tostring(price.MineZone), tostring(price.FarmPlot)))

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
