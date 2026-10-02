-- node tools/offline-test.js tests/auto_eat_test.lua   (หรือ node tools/lua.js tests/auto_eat_test.lua Edit)
-- กินอาหารอัตโนมัติ (ผู้ใช้สั่ง 2026-10-02): เลือกได้เฉพาะของที่เติมหลอดอาหาร · กินเมื่อเหลือ ≤ 10% และไม่โดนตีมา 5 วิ ·
-- 🤤 เหนือหัวเมื่อเหลือ ≤ 5%
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
local ItemCatalog, InventoryConfig = fresh(RS.ItemCatalog), fresh(RS.InventoryConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

for _, id in ipairs({ "Bread", "Apple", "FriedRice", "Steak", "Feast_Hearty", "Feast_Royal" }) do
	check(ItemCatalog.FillsHunger(id) == true, id .. " เติมหลอดอาหาร = เลือกกินอัตโนมัติได้")
end
for _, id in ipairs({ "Water", "Tonic_Vigor", "AppleJuice", "HealthPotion", "Stone", "NoSuchItem" }) do
	check(ItemCatalog.FillsHunger(id) == false, id .. " ไม่เติมหลอดอาหาร = เลือกไม่ได้")
end

check(InventoryConfig.AutoEatBelow == 0.10 and InventoryConfig.HungryMarkBelow == 0.05, "เกณฑ์ 10% กินเอง · 5% ขึ้น 🤤")
local should = InventoryConfig.ShouldAutoEat
check(should(0.10, 60, false) == true, "เหลือ 10% พอดี ไม่ได้โดนตี = กิน")
check(should(0.11, 60, false) == false, "เหลือ 11% = ยังไม่กิน")
check(should(0, math.huge, false) == true, "หลอดหมด ไม่เคยโดนตี = กิน")
check(should(0.05, 4.9, false) == false, "โดนตีมาไม่ถึง 5 วิ = รอ")
check(should(0.05, 5, false) == true, "พ้น 5 วิแล้ว = กิน")
check(should(0.05, 60, true) == false, "กำลังใช้ของ/ล้มอยู่ = ไม่กิน")

-- 🤤 ต้องอยู่ในลำดับป้ายเหนือหัว ไม่งั้นมันซ้อนทับป้ายอื่นกลางหัว (OverheadMarks.Arrange)
local Marks = fresh(game.ServerScriptService.OverheadMarks)
check(table.find(Marks.Order, "HungryMark") ~= nil, "ป้าย 🤤 อยู่ในลำดับเรียงป้ายเหนือหัว")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
