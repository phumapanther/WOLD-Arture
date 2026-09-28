-- node tools/offline-test.js tests/sell_price_test.lua   (หรือ node tools/lua.js tests/sell_price_test.lua Edit)
-- ราคารับซื้อ (ผู้ใช้กำหนด 2026-09-28): ต่ำสุด 10 (ยกเว้นก้อนหิน/เศษไม้) · ของถูกสุ่มได้ถึงอย่างน้อย 20 ·
-- สุ่ม ±50% เท่าเดิม · ทุกรอบ 30 นาทีขยับจากรอบก่อนอย่างน้อย 5 · พ่อค้าประจำเมืองต่ำสุด 10 ด้วย
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

-- 1. ช่วงราคา
local lo, hi = S.SellRange("Egg", 4)
check(lo == 10 and hi == 20, ("ไข่ (มูลค่า 4) = 10-20 ได้ %s-%s"):format(tostring(lo), tostring(hi)))
lo, hi = S.SellRange("Wheat", 24)
check(lo == 10 and hi == 22, ("ข้าว (24) = 10-22 ได้ %s-%s"):format(tostring(lo), tostring(hi)))
lo, hi = S.SellRange("Shark", 320)
check(lo == 96 and hi == 288, ("ฉลาม (320) = 96-288 เท่าเดิม ได้ %s-%s"):format(tostring(lo), tostring(hi)))
check(S.SellRange("Stone", 1) == nil and S.SellRange("WoodScrap", 1) == nil, "ก้อนหิน/เศษไม้ ใช้สูตรเดิม")
check(S.SellRange("Nothing", 0) == nil, "ไม่มีมูลค่า = สูตรเดิม")

-- 2. ขยับอย่างน้อย 5 เสมอ และอยู่ในช่วงเสมอ (ทุกช่วงกว้าง ≥ 10)
math.randomseed(20260928)
local bad = 0
for _, range in ipairs({ { 10, 20 }, { 10, 22 }, { 21, 63 }, { 96, 288 } }) do
	local a, b = range[1], range[2]
	for _ = 1, 20000 do
		local prev = a + math.random(0, b - a)
		local p = S.NextSellPrice(math.random(), math.random(), prev, a, b)
		if p < a or p > b or math.abs(p - prev) < S.MinPriceMove or p ~= math.floor(p) then bad += 1 end
	end
end
check(bad == 0, ("80,000 รอบ: อยู่ในช่วงและห่างรอบก่อน ≥ 5 (ผิด %d)"):format(bad))
local first = S.NextSellPrice(0.999999, 0.5, nil, 10, 20)
check(first == 20 and S.NextSellPrice(0, 0.5, nil, 10, 20) == 10, "รอบแรก (ไม่มีราคาก่อน) = สุ่มตรงๆ เต็มช่วง")

-- 3. ย้อนประวัติจากจุดเริ่มต่างกัน ต้องได้ราคาตรงกัน (ไม่งั้นราคาเก่าที่โชว์ ≠ ราคาที่เคยโชว์จริง)
local mismatch = 0
for _ = 1, 300 do
	local us = {}
	for i = 1, S.PriceHistorySlots do us[i] = { math.random(), math.random() } end
	local p1, p2 = 10, 20
	for i = 1, #us do
		p1 = S.NextSellPrice(us[i][1], us[i][2], p1, 10, 20)
		p2 = S.NextSellPrice(us[i][1], us[i][2], p2, 10, 20)
	end
	if p1 ~= p2 then mismatch += 1 end
end
check(mismatch == 0, ("ประวัติ %d รอบลืมจุดเริ่มเสมอ (ไม่ตรง %d จาก 300)"):format(S.PriceHistorySlots, mismatch))

-- 4. กระจายทั่วช่วง ไม่กองที่เดิม
local seen, prev = {}, nil
for _ = 1, 5000 do
	prev = S.NextSellPrice(math.random(), math.random(), prev, 10, 20)
	seen[prev] = true
end
local distinct = 0
for _ in pairs(seen) do distinct += 1 end
check(distinct == 11, ("ช่วง 10-20 ได้ครบทุกค่า (%d ค่า)"):format(distinct))

-- 5. พ่อค้าประจำเมือง
check(S.FloorSellPrice("Egg", 2.4) == 10 and S.FloorSellPrice("Shark", 192) == 192, "พ่อค้าเมือง: ต่ำสุด 10 ของแพงเท่าเดิม")
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
