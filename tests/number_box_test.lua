-- node tools/offline-test.js tests/number_box_test.lua   (หรือ node tools/lua.js tests/number_box_test.lua Edit)
-- ช่องกรอกตัวเลขทั้งเกม (ผู้ใช้สั่ง 2026-10-02): พิมพ์เกินที่มี = เด้งเป็นเลขสูงสุดเอง · ตัวอักษรที่ไม่ใช่ตัวเลขถูกตัด
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end
local N = fresh(game.ReplicatedStorage.UI.NumberBox)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

check(N.Clean("30000", 4000) == "4000", "มี 4,000 พิมพ์ 30000 = เด้งเป็น 4000")
check(N.Clean("3000", 4000) == "3000", "ไม่เกิน = ตามที่พิมพ์")
check(N.Clean("4000", 4000) == "4000", "เท่าเพดานพอดี = ไม่ขยับ")
check(N.Clean("12a3", 4000) == "123", "ตัวอักษรถูกตัด")
check(N.Clean("", 4000) == "", "ช่องว่าง = ว่าง (ยังไม่พิมพ์)")
check(N.Clean("50", 0) == "0", "ไม่มีเงินเลย = 0")
check(N.Clean("007", 100) == "7", "ศูนย์นำหน้าหาย")
check(N.Clean("99999999999999999999", nil) == "999999999999", "ไม่มีเพดาน = ตัดที่ 12 หลัก (ไม่กลายเป็น 1e+20)")
check(N.Clean("123", nil) == "123", "ไม่มีเพดาน = ตามที่พิมพ์")
check(N.Clean("500", 120.7) == "120", "เพดานเป็นทศนิยม = ปัดลง")
check(N.Clean(N.Clean("30000", 4000), 4000) == "4000", "ทำซ้ำได้ผลเดิม (ไม่วนตอนเขียนกลับลงช่อง)")
check(N.Value("4000") == 4000 and N.Value("") == nil, "Value: ตัวเลข / ว่าง = nil")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
