-- node tools/offline-test.js tests/quest_log_rules_test.lua
-- แถบเควสรวม (สเปก 2026-09-29-quest-log-oforian): ทอง → ฟ้า → ขาว · ในสีเดียวกันของที่ทำได้ก่อนของที่ล็อก/รอ
local R = require(game.ReplicatedStorage.QuestLogRules)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local lyra = { id = "brasshaven", name = "ความทรงจำแรก" }
local main = R.MainRow(lyra, { goal = "นำเมือกสไลม์ไปให้ไลรา", need = 5 }, 7)
check(main.key == "story:brasshaven" and main.color == "main" and main.state == "active", "แถวเควสหลัก")
check(R.Progress(main) == "5/5", "ความคืบหน้าไม่เกินเป้า (มี 7 ต้องการ 5)")
local locked = R.LockedRow({ id = "saltmere", name = "เส้นทางสู่ซอลต์เมียร์", goal = "หาคำแนะนำจากเจ้าของฟาร์ม" })
check(locked.state == "locked" and R.Dim(locked) and R.DenyText(locked) == "เควสนี้ยังไม่เปิด", "แถวล็อก: จาง + ข้อความ")
local side = R.SideRow({ id = "newcomer", state = "waiting", reason = "รอเดือนหน้า" }, { title = "ของขวัญผู้มาใหม่", goal = "ไปพบออฟาเรียน" })
check(side.key == "side:newcomer" and R.Dim(side) and R.DenyText(side) == "รอเดือนหน้า", "แถวรอ: จาง + เหตุผลของตัวเอง")
local sky = R.SideRow({ id = "sky", state = "active" }, { title = "เกาะลอยฟ้าแห่งความฝัน", goal = "ไปพบออฟาเรียน" })
local b1 = R.BoardRow("Brasshaven|hunt|สไลม์เขียว", "สไลม์เขียว", "ล่าสไลม์ 5 ตัว", 2, 5)
local b2 = R.BoardRow("Brasshaven|gather|Wheat", "ข้าว", "เก็บข้าว 10", 10, 10)
check(b1.state == "active" and b2.state == "done" and b2.goal:find("ส่ง") ~= nil, "งานบอร์ดครบ = done + บอกให้กลับไปส่ง")
check(R.Progress({ need = nil }) == nil, "ไม่มีเป้าจำนวน = ไม่มีตัวนับ")

local rows = R.Merge({ side, locked, sky }, { b1, b2 })
local keys = {}
for _, r in ipairs(rows) do keys[#keys + 1] = r.key end
check(table.concat(keys, ",") == "story:saltmere,side:sky,side:newcomer,board:Brasshaven|hunt|สไลม์เขียว,board:Brasshaven|gather|Wheat",
	"เรียง ทอง → ฟ้า (ทำได้ก่อนรอ) → ขาว: " .. table.concat(keys, ","))
check(R.Merge(nil, nil)[1] == nil, "ไม่มีอะไร = รายการว่าง")
check(R.Signature({ b1 }) ~= R.Signature({ R.BoardRow("Brasshaven|hunt|สไลม์เขียว", "สไลม์เขียว", "ล่าสไลม์ 5 ตัว", 3, 5) }),
	"ความคืบหน้าเปลี่ยน = ลายเซ็นเปลี่ยน (ส่งใหม่)")
check(R.Colors.main ~= R.Colors.side and R.Colors.side ~= R.Colors.board, "สามสีต่างกัน")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
