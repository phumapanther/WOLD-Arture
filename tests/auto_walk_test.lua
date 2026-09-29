-- node tools/offline-test.js tests/auto_walk_test.lua  (หรือ node tools/lua.js tests/auto_walk_test.lua Edit)
-- กด T เดินอัตโนมัติตามเส้นนำทาง (ผู้ใช้สั่ง 2026-09-29): เลือกจุดถัดไป · ข้ามจุดที่ถึงแล้ว · ปลายเส้น = รอเส้นช่วงต่อ
local AutoWalk = require(game.ReplicatedStorage.AutoWalk)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local route = {
	{ pos = Vector3.new(0, 0, 0) },
	{ pos = Vector3.new(0, 0, 10) },
	{ pos = Vector3.new(0, 2, 20), jump = true },
	{ pos = Vector3.new(10, 2, 20) },
}

-- เส้นเพิ่งคำนวณจากตัวเรา: จุดแรกอยู่ใต้เท้า = ข้ามไปจุดที่ 2
check(AutoWalk.NextIndex(route, Vector3.new(0, 3, 0), nil) == 2, "จุดแรกใต้เท้า = เดินไปจุดที่ 2")
-- เดินมาถึงจุด 2 แล้ว (ห่างในแนวราบ < Reach แม้ความสูงต่างกัน) = ไปจุด 3
check(AutoWalk.NextIndex(route, Vector3.new(0.5, 5, 9), 2) == 3, "ถึงจุด 2 แล้ว (วัดแนวราบ) = ไปจุด 3")
-- ยังไม่ถึง = จุดเดิม
check(AutoWalk.NextIndex(route, Vector3.new(0, 3, 4), 2) == 2, "ยังไม่ถึง = จุดเดิม")
-- เส้นใหม่มาตอนเดินไปครึ่งทาง: เริ่มที่จุดที่ใกล้ตัวที่สุด ไม่ย้อนกลับไปจุดแรก
check(AutoWalk.NextIndex(route, Vector3.new(0, 3, 19), nil) == 3 or AutoWalk.NextIndex(route, Vector3.new(0, 3, 19), nil) == 4,
	"เส้นใหม่กลางทาง = ไม่ย้อนไปจุดแรก")
-- ถึงจุดสุดท้ายแล้ว = nil (รอเส้นช่วงต่อ ไม่ใช่หยุด — ถึงหมุดจริงเมื่อไหร่ Navigation ล้างหมุดเอง)
check(AutoWalk.NextIndex(route, Vector3.new(10, 3, 20), 4) == nil, "ปลายเส้น = nil")
check(AutoWalk.NextIndex({}, Vector3.new(), nil) == nil, "เส้นว่าง = nil")

-- ทิศเดิน = แนวราบหนึ่งหน่วย
local d = AutoWalk.Direction(Vector3.new(0, 5, 0), Vector3.new(3, 0, 4))
check(math.abs(d.Magnitude - 1) < 1e-6 and d.Y == 0, "ทิศเดินแนวราบ ยาว 1")
check(AutoWalk.Direction(Vector3.new(1, 0, 1), Vector3.new(1, 9, 1)) == Vector3.zero, "อยู่ตรงจุดพอดี = ไม่ขยับ")

-- กระโดดเมื่อจุดที่กำลังไปเป็นจุดกระโดดและใกล้แล้ว
check(AutoWalk.ShouldJump(route[3], Vector3.new(0, 0, 18)) == true, "ใกล้จุดกระโดด = กระโดด")
check(AutoWalk.ShouldJump(route[3], Vector3.new(0, 0, 10)) == false, "จุดกระโดดยังไกล = ยังไม่กระโดด")
check(AutoWalk.ShouldJump(route[2], Vector3.new(0, 0, 9)) == false, "จุดธรรมดา = ไม่กระโดด")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
