-- node tools/offline-test.js tests/sell_price_test.lua   (หรือ node tools/lua.js tests/sell_price_test.lua Edit)
-- ราคารับซื้อ (ผู้ใช้กำหนด 2026-09-29): ต่ำสุด 5 · ของถูก 5-25 ขยับรอบละ 3-5 (20 ขึ้นไปราว 25%) · ของมอน 1-15 ขยับ 3-5 ·
-- ของแพงสุ่ม ±50% ขยับ ≥ 5 เท่าเดิม · ก้อนหิน/เศษไม้ 1-5 (1 = 70%) · พ่อค้าประจำเมืองต่ำสุด 5
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local S = fresh(game.ReplicatedStorage.ShopConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

-- 1. ช่วงราคา (lo, hi, ขยับต่ำสุด, ขยับสูงสุด)
local lo, hi, mn, mx = S.SellRange("Egg", 4)
check(lo == 5 and hi == 25 and mn == 3 and mx == 5, ("ไข่ (มูลค่า 4) = 5-25 ขยับ 3-5 ได้ %s-%s ขยับ %s-%s"):format(tostring(lo), tostring(hi), tostring(mn), tostring(mx)))
lo, hi = S.SellRange("Wheat", 24)
check(lo == 7 and hi == 25, ("ข้าว (24) = 7-25 ได้ %s-%s"):format(tostring(lo), tostring(hi)))
lo, hi, mn, mx = S.SellRange("Shark", 320)
check(lo == 96 and hi == 288 and mn == 5 and mx == nil, ("ฉลาม (320) = 96-288 ขยับ ≥5 ไม่มีเพดาน ได้ %s-%s ขยับ %s-%s"):format(tostring(lo), tostring(hi), tostring(mn), tostring(mx)))
lo, hi, mn, mx = S.SellRange("SilverOre", 35)
check(lo == 11 and hi == 32 and mx == nil, ("แร่เงิน (35) = ของแพง 11-32 ได้ %s-%s"):format(tostring(lo), tostring(hi)))
for _, id in ipairs({ "Slime", "Bone", "Fiber", "BatGuano", "Claw" }) do
	lo, hi, mn, mx = S.SellRange(id, 14)
	check(lo == 1 and hi == 15 and mn == 3 and mx == 5, ("ของมอน %s = 1-15 ขยับ 3-5 ได้ %s-%s"):format(id, tostring(lo), tostring(hi)))
end
check(S.SellRange("Stone", 1) == nil and S.SellRange("WoodScrap", 1) == nil, "ก้อนหิน/เศษไม้ ไม่ใช้ช่วงนี้ (ScrapSellPrice)")
check(S.SellRange("Nothing", 0) == nil, "ไม่มีมูลค่า = สูตรเดิม")

-- 2. ขยับตามกติกาเสมอ และอยู่ในช่วงเสมอ
math.randomseed(20260929)
local bad = 0
for _, r in ipairs({ { 5, 25, 3, 5 }, { 8, 25, 3, 5 }, { 1, 15, 3, 5 }, { 11, 32, 5, nil }, { 96, 288, 5, nil } }) do
	local a, b, m1, m2 = r[1], r[2], r[3], r[4]
	for _ = 1, 20000 do
		local prev = a + math.random(0, b - a)
		local p = S.NextSellPrice(math.random(), math.random(), prev, a, b, m1, m2)
		local d = math.abs(p - prev)
		if p < a or p > b or d < m1 or (m2 and d > m2) or p ~= math.floor(p) then bad += 1 end
	end
end
check(bad == 0, ("100,000 รอบ: อยู่ในช่วง ขยับ 3-5 (ของแพง ≥5) (ผิด %d)"):format(bad))
check(S.NextSellPrice(0.999999, 0.5, nil, 5, 25, 3, 5) == 25 and S.NextSellPrice(0, 0.5, nil, 5, 25, 3, 5) == 5, "รอบแรก (ไม่มีราคาก่อน) = สุ่มตรงๆ เต็มช่วง")

-- 3. ย้อนประวัติจากจุดเริ่มต่างกัน ต้องได้ราคาตรงกัน (ไม่งั้นราคาเก่าที่โชว์ ≠ ราคาที่เคยโชว์จริง)
local mismatch = 0
for _, r in ipairs({ { 5, 25 }, { 1, 15 } }) do
	for _ = 1, 300 do
		local us = {}
		for i = 1, S.PriceHistorySlots do us[i] = { math.random(), math.random() } end
		local p1, p2 = r[1], r[2]
		for i = 1, #us do
			p1 = S.NextSellPrice(us[i][1], us[i][2], p1, r[1], r[2], 3, 5)
			p2 = S.NextSellPrice(us[i][1], us[i][2], p2, r[1], r[2], 3, 5)
		end
		if p1 ~= p2 then mismatch += 1 end
	end
end
check(mismatch == 0, ("ประวัติ %d รอบลืมจุดเริ่มเสมอ (ไม่ตรง %d จาก 600)"):format(S.PriceHistorySlots, mismatch))

-- 4. ของถูก: ราคา 20-25 รวมราว 25% (ผู้ใช้กำหนด 2026-09-29) · 25 พอดีต่ำกว่า 10% · ได้ครบทุกค่า
for _, a in ipairs({ 5, 6, 7, 8 }) do
	local n, high, top, seen, prev = 200000, 0, 0, {}, nil
	for _ = 1, n do
		prev = S.NextSellPrice(math.random(), math.random(), prev, a, 25, 3, 5)
		seen[prev] = true
		if prev >= 20 then high += 1 end
		if prev == 25 then top += 1 end
	end
	local distinct = 0
	for _ in pairs(seen) do distinct += 1 end
	check(high / n >= 0.2 and high / n <= 0.3 and top / n < 0.1 and distinct == 26 - a,
		("%d-25: 20 ขึ้นไป %.1f%% · 25 พอดี %.1f%% · ได้ %d ค่า"):format(a, high / n * 100, top / n * 100, distinct))
end

-- 5. ก้อนหิน/เศษไม้ 1-5: ได้ 1 = 70% · 2-5 รวม 30% · สุ่มใหม่ทุกรอบไม่ขึ้นกับรอบก่อน
local counts = { 0, 0, 0, 0, 0 }
for i = 0, 9999 do
	local p = S.ScrapSellPrice((i + 0.5) / 10000)
	counts[p] += 1
end
check(counts[1] == 7000 and counts[2] + counts[3] + counts[4] + counts[5] == 3000 and counts[5] > 0 and counts[2] > 0,
	("หิน/เศษไม้: 1 = %d · 2-5 = %d/%d/%d/%d จาก 10000"):format(counts[1], counts[2], counts[3], counts[4], counts[5]))

-- 5b. พ่อค้าประจำเมือง
check(S.FloorSellPrice("Egg", 2.4) == 5 and S.FloorSellPrice("Shark", 192) == 192, "พ่อค้าเมือง: ต่ำสุด 5 ของแพงเท่าเดิม")
check(S.FloorSellPrice("Stone", 0.6) == 0.6, "พ่อค้าเมือง: ก้อนหินไม่ยก")

-- 6. รายการขายของในหน้าร้าน: ยอดรวมทั้งกองมากสุดก่อน (ผู้ใช้สั่ง 2026-09-28) · เท่ากัน = ต่อชิ้นแพงก่อน · แล้วเลขช่อง
local rows = {
	{ slot = 1, id = "Shark", each = 288, total = 288 },
	{ slot = 2, id = "Egg", each = 15, total = 750 },
	{ slot = 3, id = "Milk", each = 12, total = 288 },
	{ slot = 4, id = "Bone", each = 10, total = 10 },
	{ slot = 5, id = "Slime", each = 10, total = 10 },
}
S.SortSellRows(rows)
local order = {}
for i, r in ipairs(rows) do order[i] = r.id end
check(table.concat(order, ",") == "Egg,Shark,Milk,Bone,Slime", "เรียงยอดรวม: " .. table.concat(order, ","))
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
