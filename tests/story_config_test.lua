-- node tools/offline-test.js tests/story_config_test.lua
-- ข้อมูลเรื่อง (2026-09-29): บทล็อกไม่เริ่ม · บทพูดของทุกเควสฟ้ามีจริง · คัทซีนรถมีครบทุกฉาก
local S = require(game.ReplicatedStorage.StoryConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local fresh = { ch = {} }
local ch, p, locked = S.Current(fresh)
check(ch and ch.id == "brasshaven" and p.step == 1 and locked == nil, "คนใหม่ = บทไลรา ขั้น 1")
local done = { ch = { brasshaven = { step = 5, done = true } } }
ch, p, locked = S.Current(done)
check(ch == nil and p == nil and locked and locked.id == "saltmere", "จบบทไลรา = ไม่มีบทเล่น + คืนบทล็อก")
check(done.ch.saltmere == nil, "บทล็อกไม่ถูกสร้างความคืบหน้า")
check(locked.goal == "หาคำแนะนำจากเจ้าของฟาร์มเพื่อเดินทางไปยังซอลต์เมียร์", "ข้อความบทล็อกตรงสเปก")
check(S.Npcs.Oforian and S.Npcs.Oforian.name == "ออฟาเรียน เทพหุ่นฟาง", "ชื่อเทพ")
for _, id in ipairs({ "newcomer", "travel", "friends", "sky" }) do
	local def = S.SideQuests[id]
	check(def and def.title ~= "" and S.Dialogues[def.dialogue] ~= nil, "เควสฟ้า " .. id .. " มีชื่อ + บทพูด")
end
check(S.SideQuests.sky.title == "เกาะลอยฟ้าแห่งความฝัน" and S.SideQuests.friends.title == "สายใยมิตรภาพ", "ชื่อเควสตรงที่ผู้ใช้อนุมัติ")
check(S.Dialogues[S.OforianIdle] ~= nil and S.Dialogues.island_welcome ~= nil, "บทพูดทักทาย + ต้อนรับบนเกาะ")
local shots = {}
for _, beat in ipairs(S.SkyCutscene) do shots[#shots + 1] = beat.shot end
check(table.concat(shots, ",") == "glow,truck,board,rise,clouds,flash,title", "คัทซีนรถ 7 ฉากตามสเปก")
local total = 0
for _, beat in ipairs(S.SkyCutscene) do total += beat.seconds end
check(total >= 20 and total <= 30, ("คัทซีนยาว ~25 วิ (%.1f)"):format(total))
check(S.Title("story_brasshaven") ~= nil, "ฉายาบทไลรายังหาเจอ (บทล็อกไม่มีฉายา ไม่ทำพัง)")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
