-- node tools/lua.js tests/pvp_rank_test.lua Edit   (เพลสไหนก็ได้ — ข้อมูลล้วน)
-- แร็งก์ PVP (เฟส 3): 6 ขั้น 0/300/700/1200/1800/2500 · +25/−18 ไม่ติดลบ · ซีซันไตรมาส (ซีซัน 1 = ตอนนี้ถึง 31 ธ.ค. 2026) ·
-- ขึ้นซีซันใหม่ลด 2 ขั้น · นับแมตช์ซ้ำไม่ได้ · ขั้นที่ฉลองแล้วเลื่อนลงตามตอนตกขั้น
local copy = game.ReplicatedStorage.PvpRankConfig:Clone()
copy.Name = "PvpRankConfig_t" .. math.random(1, 1e9)
copy.Parent = game.ReplicatedStorage
local ok0, R = pcall(require, copy)
copy:Destroy()
assert(ok0, R)

local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end
local TZ = 7 * 3600
local function thai(y, m, d, h) return os.time({ year = y, month = m, day = d, hour = h or 0, min = 0, sec = 0 }) - TZ end

local names = {}
for _, t in ipairs(R.Tiers) do names[#names + 1] = t.name .. "@" .. t.min end
check(table.concat(names, " ") == "ไอร่อน@0 ซิลเวอร์@300 โกลด์@700 คริสตัล@1200 ไดมอนด์@1800 เมจิก@2500", "6 ขั้นตามแร่ " .. table.concat(names, " "))
check(R.Win == 25 and R.Loss == 18 and R.SeasonDrop == 2, "ชนะ +25 · แพ้ −18 · จบซีซันลด 2 ขั้น")
check(R.TierIndex(0) == 1 and R.TierIndex(299) == 1 and R.TierIndex(300) == 2 and R.TierIndex(2499) == 5
	and R.TierIndex(2500) == 6 and R.TierIndex(99999) == 6 and R.TierIndex(-5) == 1, "เส้นแบ่งขั้นถูก")
check(R.NextMin(650) == 700 and R.NextMin(3000) == nil, "แต้มถึงขั้นถัดไป")

check(R.Season(thai(2026, 9, 27, 12)) == 1 and R.Season(thai(2026, 12, 31, 23)) == 1, "ปลาย ก.ย. ถึง 31 ธ.ค. 2026 = ซีซัน 1")
check(R.Season(thai(2027, 1, 1, 0)) == 2 and R.Season(thai(2027, 3, 31, 23)) == 2 and R.Season(thai(2027, 4, 1, 0)) == 3,
	"ไตรมาสถัดไป = ซีซัน 2, 3 (พลิกเที่ยงคืนเวลาไทย)")
check(R.SeasonEnds(1) == thai(2027, 1, 1) and R.SeasonEnds(2) == thai(2027, 4, 1), "ซีซันจบวันแรกของไตรมาสถัดไป")

-- นับแมตช์
local r = R.Normalize(nil, 1)
check(r.p == 0 and not r.played and r.seen == 1, "คนใหม่: 0 แต้ม ยังไม่เคยเล่น")
local counted
r, counted = R.Apply(r, 1, "m1", -18)
check(counted and r.p == 0 and r.played, "แพ้ตอน 0 แต้ม = ไม่ติดลบ แต่นับว่าเล่นแล้ว")
for i = 1, 12 do r = R.Apply(r, 1, "w" .. i, 25) end
check(r.p == 300 and R.TierIndex(r.p) == 2 and r.seen == 1, "ชนะ 12 ครั้ง = 300 ซิลเวอร์ · ยังไม่ได้ฉลอง (seen 1)")
local _, again = R.Apply(r, 1, "w12", 25)
check(again == false and r.p == 300, "แมตช์เดิมนับซ้ำไม่ได้")
r.seen = 2
r = R.Apply(r, 1, "l1", -18)
check(r.p == 282 and r.seen == 1 and r.last.kind == "loss" and r.last.d == -18, "แพ้ตกขั้น = ขั้นที่ฉลองเลื่อนลงตาม (ขึ้นใหม่ได้ฉลองอีก)")

-- จบซีซัน: ลด 2 ขั้น
local d = R.Normalize({ p = 1900, s = 1, seen = 5, played = true, m = {} }, 2)
check(d.p == 700 and R.TierIndex(d.p) == 3 and d.seen == 3 and d.last.kind == "season", "ไดมอนด์ 1900 → ซีซันใหม่ = โกลด์ 700")
local d2 = R.Normalize({ p = 2600, s = 1, seen = 6, played = true, m = {} }, 3)
check(d2.p == 300, "ข้ามสองซีซัน = ลดสองรอบ (เมจิก → คริสตัล → ซิลเวอร์)")
local d3 = R.Normalize({ p = 350, s = 1, seen = 2, played = true, m = {} }, 2)
check(d3.p == 0, "ซิลเวอร์ลด 2 ขั้น = ไอร่อน 0 (ไม่ต่ำกว่าขั้นแรก)")
local d4 = R.Normalize({ p = 1900, s = 2, seen = 5, played = true, m = {} }, 2)
check(d4.p == 1900 and d4.last == nil, "ซีซันเดียวกัน = ไม่ลด")
local d5 = R.Normalize({ p = 0, s = 1 }, 5)
check(d5.p == 0 and d5.last == nil, "ไม่เคยเล่นแร็งก์ = ไม่มีอะไรให้ลด")

-- จำรหัสแมตช์ไม่เกิน 30
local big = R.Normalize(nil, 1)
for i = 1, 45 do big = R.Apply(big, 1, "x" .. i, 25) end
check(#big.m == 30 and big.p == 45 * 25, "จำรหัสแมตช์ล่าสุด 30 ตัว")

return ("%s — %d fail\n%s"):format(fails == 0 and "PASS" or "FAIL", fails, table.concat(out, "\n"))
