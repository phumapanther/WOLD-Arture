-- node tools/offline-test.js tests/vip_weight_test.lua   (หรือ node tools/lua.js tests/vip_weight_test.lua Edit)
-- VIP แบกได้ 750 (ผู้ใช้สั่ง 2026-10-02) · คนทั่วไป 500 เท่าเดิม · ช้าลง/กลิ้งสั้นลงนับจากเพดานของคนนั้น
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end
local C = fresh(game.ReplicatedStorage.InventoryConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

check(C.WeightLimit(false) == 500 and C.WeightLimit(true) == 750, "เพดาน: ทั่วไป 500 · VIP 750")
local vip = C.WeightLimit(true)
check(C.SpeedMultiplier(700, vip) == 1, "VIP แบก 700 ไม่ช้า")
check(C.SpeedMultiplier(700, C.WeightLimit(false)) < 1, "คนทั่วไปแบก 700 ช้าลง")
check(C.SpeedMultiplier(751, vip) < 1, "VIP เกิน 750 ช้าลง")
check(C.SpeedMultiplier(500) == 1 and C.SpeedMultiplier(501) < 1, "ไม่ส่งเพดาน = 500 เหมือนเดิม")
check(math.abs(C.SpeedMultiplier(1500, vip) - 0.5) < 1e-9, "VIP แบก 2 เท่าของเพดาน = ช้าครึ่งหนึ่ง")
check(not C.IsHeavilyLoaded(1000, vip) and C.IsHeavilyLoaded(1126, vip), "VIP กลิ้ง/สไลด์สั้นลงเกิน 1,125 (1.5 เท่า)")
check(C.IsHeavilyLoaded(751) and not C.IsHeavilyLoaded(750), "ไม่ส่งเพดาน = เกิน 750 เหมือนเดิม")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
