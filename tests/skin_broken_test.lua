-- node tools/offline-test.js tests/skin_broken_test.lua  (หรือ node tools/lua.js tests/skin_broken_test.lua Edit)
-- อาวุธติดสกินความคงทนหมด = ไม่หาย แค่ใช้ไม่ได้จนกว่าจะซ่อม (ผู้ใช้สั่ง 2026-09-29) · ไม่ติดสกิน = พังหายเหมือนเดิม
local InventoryConfig = require(game.ReplicatedStorage.InventoryConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

check(InventoryConfig.KeepsWhenBroken({ id = "Sword", durability = 3, meta = { skin = "Skin_Sword_Royal" } }) == true,
	"ติดสกิน = พังแล้วไม่หาย")
check(InventoryConfig.KeepsWhenBroken({ id = "Sword", durability = 3 }) == false, "ไม่มีสกิน = พังหายเหมือนเดิม")
check(InventoryConfig.KeepsWhenBroken({ id = "Sword", durability = 3, meta = { enhance = 5 } }) == false,
	"ตีบวกอย่างเดียวไม่นับเป็นสกิน")
check(InventoryConfig.KeepsWhenBroken(nil) == false, "มือเปล่า = ไม่มีอะไรให้เก็บ")

check(InventoryConfig.IsBroken({ id = "Sword", durability = 0 }) == true, "ความคงทน 0 = พัง")
check(InventoryConfig.IsBroken({ id = "Sword", durability = 1 }) == false, "เหลือ 1 = ยังใช้ได้")
check(InventoryConfig.IsBroken({ id = "GoldAxe" }) == false, "ไม่มีค่าความคงทน (ไม่มีวันพัง) = ไม่พัง")
check(InventoryConfig.IsBroken(nil) == false, "มือเปล่า = ไม่พัง")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
