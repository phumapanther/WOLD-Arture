-- node tools/lua.js tests/blocking_test.lua Edit   (เพลสไหนก็ได้ — ตัดสินจังหวะเป็นข้อมูลล้วน)
-- ยกการ์ด / ปัดป้อง (เฟส 3 · ArenaConfig.Block): ปัดภายในช่วงจังหวะ · ลดดาเมจหลังจากนั้น · โล่เก่งกว่า · กันกดรัว
local SSS = game.ServerScriptService
local copy = SSS.Blocking:Clone()
copy.Name = "Blocking_t" .. math.random(1, 1e9)
copy.Parent = SSS
local ok0, Blocking = pcall(require, copy)
copy:Destroy()
assert(ok0, Blocking)
local B = require(game.ReplicatedStorage.ArenaConfig).Block

local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end
local function near(a, b) return math.abs(a - b) < 1e-6 end

check(B.reduce == 0.5 and B.window == 0.3 and B.stagger == 0.8 and B.parryLock == 1, "ตัวเลขผู้ใช้: ลด 50% · จังหวะ 0.3 วิ · เซ 0.8 วิ · ล็อก 1 วิ")
check(select(1, Blocking.JudgeState(nil, 0)) == nil and select(2, Blocking.JudgeState({ on = false }, 0)) == 1, "ไม่ได้ยกการ์ด = ดาเมจเต็ม")

local s = {}
Blocking.Raise(s, 10, false)
local v, f = Blocking.JudgeState(s, 10.2)
check(v == "parry" and f == 0, "โดนตีภายใน 0.3 วิหลังยก = ปัดสมบูรณ์ ไม่เสียเลือด")
v, f = Blocking.JudgeState(s, 10.25)
check(v == "block" and near(f, 0.5), "ไม้ที่สองในช่วงเดียวกัน = กันธรรมดา (ปัดได้ทีละครั้ง)")

s = {}
Blocking.Raise(s, 20, false)
v, f = Blocking.JudgeState(s, 20.4)
check(v == "block" and near(f, 0.5), "โดนหลังพ้นจังหวะ = ลดดาเมจครึ่งเดียว")

-- กันกดรัว: ยกแล้วไม่มีอะไรมาโดนในช่วงจังหวะ = ปัดไม่ได้อีก 1 วิหลังช่วงนั้นจบ
s = {}
Blocking.Raise(s, 30, false)
Blocking.Lower(s)
Blocking.Raise(s, 30.1, false)
v = Blocking.JudgeState(s, 30.15)
check(v == "block", "ยก-ปล่อย-ยกรัวๆ (ครั้งแรกไม่ได้ปัดอะไร) = ครั้งถัดไปไม่มีจังหวะปัด")
Blocking.Lower(s)
Blocking.Raise(s, 31.2, false)
check(Blocking.JudgeState(s, 31.25) == "block", "ยังไม่พ้น 1 วิหลังช่วงเดิมจบ (30.3 + 1) = ยังปัดไม่ได้")
Blocking.Lower(s)
Blocking.Raise(s, 31.35, false)
check(Blocking.JudgeState(s, 31.4) == "parry", "พ้นล็อกแล้ว = ปัดได้อีก")

-- ปัดสำเร็จ = ไม่โดนล็อก ยกใหม่ปัดต่อได้ทันที (รางวัลของคนจับจังหวะถูก)
s = {}
Blocking.Raise(s, 40, false)
Blocking.JudgeState(s, 40.1)
Blocking.Lower(s)
Blocking.Raise(s, 40.3, false)
check(Blocking.JudgeState(s, 40.35) == "parry", "ปัดสำเร็จแล้วยกใหม่ = ปัดได้อีกทันที")

-- โล่: ลดมากกว่า จังหวะกว้างกว่า
s = {}
Blocking.Raise(s, 50, true)
check(Blocking.JudgeState(s, 50.4) == "parry", "โล่: ปัดได้ถึง 0.45 วิ")
v, f = Blocking.JudgeState(s, 50.5)
check(v == "block" and near(f, 1 - B.shieldReduce) and B.shieldReduce > B.reduce and B.shieldWindow > B.window,
	"โล่: กันธรรมดาลด 75% (มากกว่าอาวุธอื่น)")

-- ปล่อยการ์ดแล้ว = ดาเมจเต็มทันที
Blocking.Lower(s)
check(Blocking.JudgeState(s, 50.6) == nil, "ปล่อยการ์ด = โดนเต็ม")

return ("%s — %d fail\n%s"):format(fails == 0 and "PASS" or "FAIL", fails, table.concat(out, "\n"))
