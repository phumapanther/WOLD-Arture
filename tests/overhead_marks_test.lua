-- node tools/lua.js tests/overhead_marks_test.lua Edit
-- อีโมจิสถานะเหนือหัว (ผู้ใช้สั่ง 2026-09-29): 🐌 ของหนักเกิน · 🔧 ของที่ใส่/ถือใกล้พัง (ความคงทน < 5) ·
-- หลายสถานะพร้อมกัน = ขึ้นทุกอันเรียงข้างกัน ไม่ซ้อนทับจุดเดียว
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local Marks = fresh(game.ServerScriptService.OverheadMarks)
local InventoryConfig = fresh(game.ReplicatedStorage.InventoryConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

-- 1. ของใกล้พัง: ชิ้นไหนก็ได้ที่ใส่/ถืออยู่ ความคงทนต่ำกว่า 5 · ของไม่มีวันพัง (ไม่มีค่า) ไม่นับ
check(InventoryConfig.AnyWorn({ weapon = { id = "Sword", durability = 4 } }) == true, "ดาบเหลือ 4 = ใกล้พัง")
check(InventoryConfig.AnyWorn({ weapon = { id = "Sword", durability = 5 } }) == false, "ดาบเหลือ 5 = ยังไม่ขึ้น")
check(InventoryConfig.AnyWorn({ weapon = { id = "GoldAxe" }, armor = { id = "LeatherArmor", durability = 2 } }) == true,
	"เกราะเหลือ 2 = ใกล้พัง (อาวุธไม่มีวันพังไม่นับ)")
check(InventoryConfig.AnyWorn({}) == false and InventoryConfig.AnyWorn(nil) == false, "ไม่ได้ใส่อะไร = ไม่ขึ้น")

-- 2. ของหนัก = ตัวคูณความเร็ว < 1 (เกินขีดน้ำหนัก)
check(InventoryConfig.SpeedMultiplier(InventoryConfig.MaxWeight) == 1, "น้ำหนักพอดีขีด = ไม่ช้า")
check(InventoryConfig.SpeedMultiplier(InventoryConfig.MaxWeight + 1) < 1, "เกินขีด = ช้าลง (ขึ้น 🐌)")

-- 3. ป้ายบนหัวจริง: เปิดสองอัน = สองป้ายคนละตำแหน่ง · ปิดหนึ่ง = อันที่เหลือกลับกลาง
local head = Instance.new("Part")
head.Name = "Head"
head.Anchored = true
head.Parent = workspace
Marks.Set(head, "HeavyMark", "🐌", Color3.new(1, 1, 1), true)
local one = head:FindFirstChild("HeavyMark")
check(one ~= nil and one:IsA("BillboardGui") and one.SizeOffset.X == 0, "ป้ายเดียว = อยู่กลาง")
Marks.Set(head, "WornMark", "🔧", Color3.new(1, 1, 1), true)
local worn = head:FindFirstChild("WornMark")
check(worn ~= nil and one.SizeOffset.X < 0 and worn.SizeOffset.X > 0,
	("สองป้าย = เรียงซ้าย/ขวา (%.2f · %.2f)"):format(one.SizeOffset.X, worn and worn.SizeOffset.X or 0))
Marks.Set(head, "TiredMark", "💦", Color3.new(1, 1, 1), true)
local xs = {}
for _, g in ipairs(head:GetChildren()) do xs[#xs + 1] = g.SizeOffset.X end
table.sort(xs)
check(#xs == 3 and xs[1] < xs[2] and xs[2] < xs[3] and math.abs(xs[1] + xs[3]) < 1e-6, "สามป้าย = ไม่ทับกัน กึ่งกลางที่เดิม")
Marks.Set(head, "HeavyMark", "🐌", Color3.new(1, 1, 1), true) -- เรียกซ้ำตอนเปิดอยู่แล้ว = ไม่ซ้อน
local count = 0
for _ in ipairs(head:GetChildren()) do count += 1 end
check(count == 3, "เปิดซ้ำไม่สร้างป้ายซ้อน")
Marks.Set(head, "WornMark", nil, nil, false)
Marks.Set(head, "TiredMark", nil, nil, false)
check(head:FindFirstChild("WornMark") == nil and one.SizeOffset.X == 0, "ปิดจนเหลือหนึ่ง = กลับกลาง")
head:Destroy()

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
