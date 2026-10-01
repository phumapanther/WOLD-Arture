-- node tools/lua.js tests/blocking_test.lua Edit   (เพลสไหนก็ได้ — ตัดสินจังหวะเป็นข้อมูลล้วน)
-- ยกการ์ด / ปัดป้อง (ArenaConfig.Block) · **กดทีละครั้ง** (ผู้ใช้สั่ง 2026-10-01):
-- กด → ยก 0.1 วิ (โดนเต็ม) → ปัดสมบูรณ์ 0.2 วิ → กันธรรมดา 50% อีก 0.2 วิ → การ์ดลงเอง ต้องกดใหม่
local SSS = game.ServerScriptService
local copy = SSS.Blocking:Clone()
copy.Name = "Blocking_t" .. math.random(1, 1e9)
copy.Parent = SSS
local ok0, Blocking = pcall(require, copy)
copy:Destroy()
assert(ok0, Blocking)
-- โคลนสด: `require` ใน Edit แคชของเก่าข้ามรอบ (แก้ตัวเลขแล้วเทสยังเห็นค่าเดิม)
local cfg = game.ReplicatedStorage.ArenaConfig:Clone()
cfg.Name = "ArenaConfig_t" .. math.random(1, 1e9)
cfg.Parent = game.ReplicatedStorage
local B = require(cfg).Block
cfg:Destroy()

local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end
local function near(a, b) return math.abs(a - b) < 1e-6 end

check(B.windup == 0.1 and B.active == 0.4 and B.window == 0.2 and B.reduce == 0.5 and B.stagger == 1.5,
	"ตัวเลขผู้ใช้: ยก 0.1 · การ์ด 0.4 (ปัด 0.2 แรก) · ลด 50% · เซ 1.5 วิ")
check(select(1, Blocking.JudgeState(nil, 0)) == nil and select(2, Blocking.JudgeState({}, 0)) == 1, "ไม่ได้กด = ดาเมจเต็ม")

local s = {}
check(Blocking.Raise(s, 10, false) == true, "กดครั้งแรกติด")
check(Blocking.JudgeState(s, 10.05) == nil, "โดนระหว่างยกการ์ด (0.1 วิแรก) = เต็ม")
check(Blocking.Up(s, 10.05), "ระหว่างยก = นับว่ากำลังกัน (เดินช้า/ตีไม่ได้)")
local v, f = Blocking.JudgeState(s, 10.2)
check(v == "parry" and f == 0, "โดนใน 0.2 วิแรกของการ์ด = ปัดสมบูรณ์ ไม่เสียเลือด")
v, f = Blocking.JudgeState(s, 10.25)
check(v == "block" and near(f, 0.5), "ไม้ที่สองในช่วงปัด = กันธรรมดา (ปัดได้ทีละครั้งต่อการกด)")

s = {}
Blocking.Raise(s, 20, false)
v, f = Blocking.JudgeState(s, 20.4)
check(v == "block" and near(f, 0.5), "โดนช่วง 0.2 วิหลังของการ์ด = ลดครึ่งเดียว")
check(Blocking.JudgeState(s, 20.55) == nil and not Blocking.Up(s, 20.55), "พ้น 0.5 วิ = การ์ดลงเอง โดนเต็ม")

-- กดซ้ำระหว่างการ์ดยังอยู่ = ไม่มีผล (ไม่ต่อเวลา ไม่รีเซ็ตช่วงปัด)
s = {}
Blocking.Raise(s, 30, false)
check(Blocking.Raise(s, 30.3, false) == false, "กดซ้ำตอนการ์ดยังไม่ลง = ไม่ติด")
check(not Blocking.Up(s, 30.51), "กดซ้ำไม่ได้ต่อเวลาการ์ด")
check(Blocking.Raise(s, 30.6, false) == true, "การ์ดลงแล้วกดใหม่ได้")
check(Blocking.JudgeState(s, 30.65) == nil, "กดใหม่ก็ต้องรอยกการ์ด 0.1 วิอีกรอบ")
check(Blocking.JudgeState(s, 30.75) == "parry", "แล้วปัดได้ตามปกติ")

-- ถูกปล่อยก่อนเวลา (ล้ม/กลิ้ง) = เต็มทันที และกดใหม่ได้เลย
s = {}
Blocking.Raise(s, 40, false)
Blocking.Lower(s)
check(Blocking.JudgeState(s, 40.2) == nil and not Blocking.Up(s, 40.2), "ถูกปล่อยการ์ด = โดนเต็ม")
check(Blocking.Raise(s, 40.25, false) == true, "ถูกปล่อยแล้วกดใหม่ได้ทันที")

-- โล่: ปัดนานกว่า ลดมากกว่า แต่การ์ดยาวเท่ากัน
s = {}
Blocking.Raise(s, 50, true)
check(Blocking.JudgeState(s, 50.38) == "parry", "โล่: ปัดได้ถึง 0.3 วิของการ์ด")
v, f = Blocking.JudgeState(s, 50.45)
check(v == "block" and near(f, 1 - B.shieldReduce) and B.shieldReduce > B.reduce and B.shieldWindow > B.window,
	"โล่: กันธรรมดาลด 75% (มากกว่าอาวุธอื่น)")
check(Blocking.JudgeState(s, 50.55) == nil, "โล่: การ์ดลงเองที่ 0.5 วิเหมือนกัน")

return ("%s — %d fail\n%s"):format(fails == 0 and "PASS" or "FAIL", fails, table.concat(out, "\n"))
