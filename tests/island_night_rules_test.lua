-- node tools/offline-test.js tests/island_night_rules_test.lua   (หรือ node tools/lua.js tests/island_night_rules_test.lua Edit)
-- มอนบุกเกาะตอนกลางคืน (ผู้ใช้สั่ง 2026-09-28) — กติกาล้วนใน IslandNightRules + ตัวเลขใน IslandConfig.NightRaid
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
local Rules = fresh(RS.IslandNightRules)
local C = fresh(RS.IslandConfig)
local GatherConfig = fresh(RS.GatherConfig)
local ItemCatalog = fresh(RS.ItemCatalog)
local R = C.NightRaid
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

-- สุ่มแบบกำหนด seed (math.random ของ Luau · LCG เขียนเองให้เลขติดกันสัมพันธ์กัน พาเหรดเพี้ยน 5.8%)
math.randomseed(20260928)
local rand = math.random

-- 1. ทอยต่อคืน: บอส 5 · พิเศษ 5 · หัวหน้าฝูง 10 · ธรรมดา 80 · พาเหรด 5 (แยกทอย)
local n, count, parade = 100000, { boss = 0, special = 0, leader = 0, none = 0 }, 0
for _ = 1, n do
	local night = Rules.RollNight(rand)
	count[night.special or "none"] += 1
	if night.parade then parade += 1 end
end
local function pct(x) return x / n * 100 end
local function near(x, want, tol) return math.abs(pct(x) - want) <= tol end
check(near(count.boss, 5, 0.4) and near(count.special, 5, 0.4) and near(count.leader, 10, 0.5) and near(count.none, 80, 0.7),
	("ทอยต่อคืน บอส %.2f พิเศษ %.2f หัวหน้า %.2f ธรรมดา %.2f"):format(pct(count.boss), pct(count.special),
		pct(count.leader), pct(count.none)))
check(near(parade, 5, 0.4), ("พาเหรด %.2f%%"):format(pct(parade)))

-- 2. ชุดมอนตามเลเวลฟาร์ม (สะสม) เรียงง่าย→โหด
check(#Rules.PoolFor(2) == 0, "Lv2 ไม่มีมอน")
check(#Rules.PoolFor(3) == 5 and #Rules.PoolFor(9) == 5, "Lv3-9 = 5 ชนิด")
check(#Rules.PoolFor(10) == 8 and #Rules.PoolFor(19) == 8, "Lv10-19 = 8 ชนิด")
check(#Rules.PoolFor(20) == 11, "Lv20+ = 11 ชนิด")
local p = Rules.PoolFor(20)
local sorted = true
for i = 2, #p do
	if GatherConfig.Mobs[p[i - 1]].hp > GatherConfig.Mobs[p[i]].hp then sorted = false end
end
check(sorted and p[1] == "Bat" and p[#p] == "StoneGolem", "เรียงจากเลือดน้อย (ค้างคาว) ไปมาก (โกเลม)")
check(R.minFarmLevel == R.pools[1].level, "เลเวลขั้นต่ำ = ชุดแรก")

-- 3. พาเหรดโหดขึ้นตามเวลาในคืน: ต้นคืน ⊂ กลางคืน ⊂ ท้ายคืน
local early, mid, late = Rules.PoolAt(20, 0.1), Rules.PoolAt(20, 0.5), Rules.PoolAt(20, 0.9)
check(#early < #mid and #mid < #late and #late == 11, ("ต้น %d < กลาง %d < ท้าย %d"):format(#early, #mid, #late))
check(early[1] == "Bat" and table.find(early, "StoneGolem") == nil, "ต้นคืนไม่เจอโกเลม")
check(#Rules.PoolAt(3, 0) >= 1, "เลเวลต่ำต้นคืนยังมีอย่างน้อยหนึ่งชนิด")
check(Rules.Pick({}, rand) == nil and Rules.Pick({ "Bat" }, rand) == "Bat", "Pick ว่าง = nil")

-- 4. เวลา: คืน 11 ชั่วโมงในเกม = 550 วิจริง (วันละ 20 นาที)
check(Rules.Progress(18.5) == 0 and math.abs(Rules.Progress(0) - 0.5) < 1e-9 and Rules.Progress(12) == 0,
	"ความคืบหน้าของคืน (หัวค่ำ 0 · เที่ยงคืน 0.5 · กลางวัน 0)")
check(math.abs(Rules.SecondsToDawn(18.5) - 550) < 1e-6 and math.abs(Rules.SecondsToDawn(0) - 275) < 1e-6
	and Rules.SecondsToDawn(12) == 0, "เวลาถึงเช้า (หัวค่ำ 550 วิ · เที่ยงคืน 275 · กลางวัน 0)")

-- 4b. ป้ายพาเหรดเทียบเวลาถึงเช้าใหม่ได้ (รีวิว 2026-09-28: /time ล็อกนาฬิกา = นับถอยหลังเพี้ยน)
-- เริ่มพาเหรดตอน 20:00 (เหลือ 475 วิ) · 100 วิต่อมานาฬิกาเดินปกติเป็น 22:00 = ไม่ต้องแก้
check(Rules.DawnDrift(475, 100, 22) == nil, "นาฬิกาเดินปกติ = ไม่ต้องส่งภาพใหม่")
-- นาฬิกาถูกล็อกไว้ที่ 20:00 ครบ 100 วิ = เวลาถึงเช้าเลื่อนไปเป็น 575
check(Rules.DawnDrift(475, 100, 20) == 575, "นาฬิกาถูกล็อก = เลื่อนเวลาจบตาม")
-- ปลดล็อกกลางทาง: ของที่ค้างอยู่ต้องกลับมาตรงกับเวลาจริง
check(Rules.DawnDrift(9999, 100, 22) == 475, "เพี้ยนมาก = แก้กลับเป็นเวลาจริง")

-- 5. ตัวเลขตามสเปก + ทุกชื่อมีจริง
check(R.maxHitFraction == 0.10 and R.countMin == 1 and R.countMax == 3, "ตีแรงสุด 10% · เกิด 1-3")
check(R.paradeEverySeconds == 20 and R.paradeMaxAlive == 8, "พาเหรดทุก 20 วิ ไม่เกิน 8")
check(R.boss.kind == "Forgewarden" and R.boss.hp == 1500 and R.boss.drop == "MagicBox", "บอสเกาะ 1,500 ดรอปกล่องเวท")
local missing = {}
local function need(kind) if not GatherConfig.Mobs[kind] then missing[#missing + 1] = kind end end
for _, tier in ipairs(R.pools) do for _, k in ipairs(tier.kinds) do need(k) end end
for _, k in ipairs(R.specials) do need(k) end
need(R.boss.kind)
check(#missing == 0, "ทุกชนิดมีใน GatherConfig.Mobs " .. table.concat(missing, ","))
check(ItemCatalog.Get(R.specialChest) ~= nil and ItemCatalog.Get(R.boss.drop) ~= nil, "หีบทอง/กล่องเวทมีในแคตตาล็อก")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
