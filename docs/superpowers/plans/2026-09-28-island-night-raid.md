# มอนบุกเกาะตอนกลางคืน + พาเหรดมอนสเตอร์ — แผนลงมือ

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** เกาะที่เลเวลฟาร์ม ≥ 3 มีมอนบุก 1-3 ตัวทุกคืน (ลุ้นบอส/มอนพิเศษ/หัวหน้าฝูง) + อีเวนต์พาเหรด 5% · ตายบนเกาะไม่เสียเลเวล/อาชีพ

**Architecture:** เปิด `Mobs.server` ของเกมหลักบนเพลสเกาะ (AI/ดรอป/EXP/นับเควสได้ฟรี) แล้วเพิ่มทางเกิดแบบ "บุก" (`MobAccess.SpawnRaid/Despawn`)
ตัวคุมจังหวะคืน `Island/IslandNight.server` · กติกาล้วนแยกเป็น `IslandNightRules` (เทสออฟไลน์ได้) · ตัวเลขทั้งหมด `IslandConfig.NightRaid`
· ต้นแบบมอนบนเพลสเกาะสร้างจากโรงงานด้วยเฟส mapgen ใหม่

**Tech Stack:** Luau (Roblox) · Rojo project 3 เพลส · เครื่องมือ `tools/offline-check.sh` `tools/offline-test.js` `tools/lua.js` `tools/run-luau.js` `tools/verify.js`

**Spec:** `docs/superpowers/specs/2026-09-28-island-night-raid-design.md`

## Global Constraints

- เลเวลฟาร์มขั้นต่ำ 3 (ของเจ้าของเกาะ) · กลางคืน = `DayNightConfig.IsNight` (18:30-05:30)
- หัวค่ำเกิด 1-3 ตัว · ทอยต่อคืน: บอส 5% · มอนพิเศษ 5% · หัวหน้าฝูง 10% · สูงสุดหนึ่งตัวพิเศษต่อคืน (แทนมอนธรรมดาหนึ่งตัว)
- บอสเกาะ = ฟอร์จวอร์เดนขนาดเดิม เลือด 1,500 ดรอป `MagicBox` 1 ใบอย่างเดียว + EXP
- มอนพิเศษ = SteamSlime/PlasmaSlime/BioSlime ดรอปปกติ + `Chest_Gold` 1 · หัวหน้าฝูง ดรอปวัตถุดิบ 2 เท่า EXP 2 เท่า
- ตีแรงสุด 10% ของเลือดเต็มคนที่โดน (ทุกตัว) · ไม่คูณกลางคืน 2 เท่า · เช้า = มอนบุกหายหมด ไม่ดรอป
- เกิดเฉพาะช่องดินในรั้วฟาร์มที่ว่าง (ไม่ใช่น้ำ) ห่างเป้า 30-60 สตัดก่อน · ไล่ทุกคนบนเกาะ
- ชุดมอน Lv3: Bat GreenSlime Spider Boar Skeleton · Lv10 +Bandit Wolf Ghoul · Lv20 +ClockworkSentry Wraith StoneGolem
- พาเหรด 5% ต่อคืน · ป้ายแบบอีเวนต์เกมหลัก + นับถอยหลังถึงเช้า · ทุก 20 วิ ไม่เกิน 8 ตัว · โหดขึ้นตามเวลาในคืน
- ตายบนเกาะ: ไม่ลดเลเวล ไม่ถอดอาชีพ ไม่ใช้เครื่องราง
- ห้ามกด Play (ผู้ใช้เทสเอง) · commit เฉพาะไฟล์ของงานนี้ ลงท้าย `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
- ดันโค้ดด้วย `node tools/verify.js <project> --push` ทั้งสามเพลส จบที่ `mismatches 0`

## Review Focus

1. **เจ้าของออกกลางคืน / เซิร์ฟปิด** — มอนบุกหายไปกับเซิร์ฟ ไม่มีอะไรเซฟ ไม่มีของค้าง (ไม่มีโค้ดเซฟ = ถูกต้อง)
2. **ทุกคนล้มหมด** — มอนต้องไม่ติดอยู่กับร่างที่ล้ม (`chaseAll` หาเป้าใหม่ · ไม่มีใครยืน = เดินวนที่จุดเกิด)
3. **สัตว์เลี้ยง/สัตว์ในคอก** ใช้โมเดลมอนเดียวกันแต่ไม่มีแท็ก `WOLD_Mob` — `Mobs` ต้องไม่ไปจับ/ตีพวกมัน
4. **มอนตกขอบเกาะ** — `Mobs` เดิมวาร์ปกลับ `state.home` เมื่อต่ำกว่า y -150 (ช่องดินที่เกิด) ไม่ร่วงหายเงียบ
5. **แขก (เพื่อน) ตายบนเกาะ** ก็ไม่เสียเลเวล (`IsFarm` ครอบทุกคนในเซิร์ฟ)

(ทั้งห้าข้อพิสูจน์ได้เฉพาะในเกม — อยู่ในรายการเทสของผู้ใช้ท้ายแผน)

---

### Task 1: กติกาล้วน + คอนฟิก

**Files:**
- Modify: `src/ReplicatedStorage/IslandConfig.lua` (ต่อท้าย `IslandConfig.NodeWeightsOpen` ก่อน `IslandConfig.MineItem`)
- Create: `src/ReplicatedStorage/IslandNightRules.lua`
- Test: `tests/island_night_rules_test.lua`

**Interfaces:**
- Produces: `IslandConfig.NightRaid` (ตารางข้างล่าง) · `IslandNightRules.RollNight(rand) -> { special = "boss"|"special"|"leader"|nil, parade = bool }`
  · `PoolFor(level) -> { kind... }` (เรียงเลือดน้อย→มาก) · `PoolAt(level, progress) -> { kind... }` · `Pick(list, rand) -> kind|nil`
  · `Progress(clockTime) -> 0..1` · `SecondsToDawn(clockTime) -> number` · `rand` = ฟังก์ชันคืน [0,1) ไม่ส่ง = `math.random`

- [ ] **Step 1: เขียนเทสที่ต้องตก** — `tests/island_night_rules_test.lua`

```lua
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

-- สุ่มแบบกำหนด seed เอง (ไม่พึ่ง Random.new — ตัวจำลองออฟไลน์อาจไม่มี)
local seed = 20260928
local function rand()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

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
```

- [ ] **Step 2: รันให้เห็นว่าตก**

Run: `node tools/offline-test.js tests/island_night_rules_test.lua`
Expected: `ERROR ... IslandNightRules` (ยังไม่มีโมดูล)

- [ ] **Step 3: คอนฟิก** — ต่อท้ายหลังฟังก์ชัน `IslandConfig.NodeWeightsOpen` (ก่อน `IslandConfig.MineItem = "MineZone"`)

```lua
--------------------------------------------------------------------------------
-- มอนบุกเกาะตอนกลางคืน + พาเหรดมอนสเตอร์ (ผู้ใช้สั่ง 2026-09-28)
-- สเปก docs/superpowers/specs/2026-09-28-island-night-raid-design.md · กติกา `IslandNightRules` · ตัวคุม `Island/IslandNight.server`
--------------------------------------------------------------------------------
IslandConfig.NightRaid = {
	minFarmLevel = 3,              -- เลเวลฟาร์มของเจ้าของเกาะ (= ชุดแรกใน pools)
	countMin = 1, countMax = 3,    -- มอนตอนหัวค่ำ
	-- ทอยครั้งเดียวต่อคืนตามลำดับนี้ สูงสุดหนึ่งตัวพิเศษ (ติดแล้วแทนมอนธรรมดาหนึ่งตัวในคืนนั้น)
	odds = {
		{ id = "boss", chance = 0.05 },
		{ id = "special", chance = 0.05 },
		{ id = "leader", chance = 0.10 },
	},
	paradeChance = 0.05,           -- ทอยแยก คืนพาเหรดก็มีตัวพิเศษได้
	paradeEverySeconds = 20,
	paradeMaxAlive = 8,            -- นับรวมมอนตอนหัวค่ำ
	maxHitFraction = 0.10,         -- ตีแรงสุด 10% ของเลือดเต็มคนที่โดน ทุกตัวรวมบอส
	spawnMinDistance = 30, spawnMaxDistance = 60,
	-- ชุดมอนตามเลเวลฟาร์ม สะสมจากขั้นก่อน · ชื่อ = คีย์ใน GatherConfig.Mobs (เทส island_night_rules ตรวจ)
	pools = {
		{ level = 3, kinds = { "Bat", "GreenSlime", "Spider", "Boar", "Skeleton" } },
		{ level = 10, kinds = { "Bandit", "Wolf", "Ghoul" } },
		{ level = 20, kinds = { "ClockworkSentry", "Wraith", "StoneGolem" } },
	},
	specials = { "SteamSlime", "PlasmaSlime", "BioSlime" },
	specialChest = "Chest_Gold",
	-- บอสโลกขนาดเดิม แต่ไม่ถึกเท่าเดิม · ดรอปกล่องเวทมนตร์อย่างเดียว (หีบเวทยังไม่มีโมเดล กดใช้แล้วเงียบ)
	boss = { kind = "Forgewarden", hp = 1500, drop = "MagicBox" },
	-- หัวหน้าฝูง: ใหญ่ขึ้น 2 เท่า เลือด 3 เท่า (ตัวเลขผมตั้ง) · ดรอปวัตถุดิบ 2 เท่า EXP 2 เท่า (ผู้ใช้กำหนด)
	leader = { scale = 2, power = 3, amount = 2, xp = 2 },
	-- ป้ายพาเหรด (ทรงเดียวกับอีเวนต์เกมหลัก) · ไอคอนยืมของอีเวนต์สไลม์ไว้ก่อน
	banner = {
		icon = "rbxassetid://139399362647202",
		message = "🌙 พาเหรดมอนสเตอร์",
		colour = Color3.fromRGB(170, 130, 255),
		sound = "EventSlime",
	},
	tag = "WOLD_Raid",             -- แท็กบนตัวมอนบุก ให้ IslandNight นับ/เก็บตอนเช้า
}
```

- [ ] **Step 4: โมดูลกติกา** — `src/ReplicatedStorage/IslandNightRules.lua`

```lua
-- IslandNightRules: กติกาล้วนของมอนบุกเกาะตอนกลางคืน (สเปก 2026-09-28-island-night-raid-design.md)
-- ไม่แตะโลก — ทอยต่อคืน · ชุดมอนตามเลเวลฟาร์ม · ตัวที่พาเหรดสุ่มได้ตามเวลาในคืน · เวลาถึงเช้า
-- `rand` = ฟังก์ชันคืน [0,1) (เทสส่งตัวที่ seed ไว้) · ไม่ส่ง = math.random
local IslandConfig = require(script.Parent.IslandConfig)
local GatherConfig = require(script.Parent.GatherConfig)
local DayNightConfig = require(script.Parent.DayNightConfig)

local Rules = {}
local R = IslandConfig.NightRaid

local function roll(rand)
	return (rand or math.random)()
end

-- ทอยตอนหัวค่ำ: ตัวพิเศษหนึ่งตัวสูงสุด + พาเหรดทอยแยก
function Rules.RollNight(rand)
	local x, acc, special = roll(rand), 0, nil
	for _, o in ipairs(R.odds) do
		acc += o.chance
		if x < acc then
			special = o.id
			break
		end
	end
	return { special = special, parade = roll(rand) < R.paradeChance }
end

-- ชุดมอนที่เลเวลฟาร์มนี้เจอได้ เรียงจากเลือดน้อยไปมาก (= ง่าย → โหด) · ต่ำกว่าชุดแรก = ว่าง
function Rules.PoolFor(level)
	local out = {}
	for _, tier in ipairs(R.pools) do
		if level >= tier.level then
			for _, kind in ipairs(tier.kinds) do out[#out + 1] = kind end
		end
	end
	table.sort(out, function(a, b)
		local ha, hb = GatherConfig.Mobs[a].hp, GatherConfig.Mobs[b].hp
		if ha ~= hb then return ha < hb end
		return a < b
	end)
	return out
end

-- พาเหรดโหดขึ้นตามเวลา: หนึ่งในสามแรกของคืน = ตัวง่ายสุดหนึ่งในสามของชุด · กลาง = สองในสาม · ท้าย = ทั้งชุด
function Rules.PoolAt(level, progress)
	local pool = Rules.PoolFor(level)
	local share = progress < 1 / 3 and 1 / 3 or (progress < 2 / 3 and 2 / 3 or 1)
	local n = math.min(#pool, math.max(1, math.ceil(#pool * share)))
	local out = {}
	for i = 1, n do out[i] = pool[i] end
	return out
end

function Rules.Pick(list, rand)
	if #list == 0 then return nil end
	return list[math.floor(roll(rand) * #list) + 1]
end

-- ความยาวคืนเป็นชั่วโมงในเกม (18:30 → 05:30 = 11)
local NIGHT_HOURS = (DayNightConfig.DawnHour - DayNightConfig.DuskHour) % 24

-- คืนนี้ผ่านไปกี่ส่วน 0..1 · กลางวัน = 0
function Rules.Progress(clockTime)
	if not DayNightConfig.IsNight(clockTime) then return 0 end
	return ((clockTime - DayNightConfig.DuskHour) % 24) / NIGHT_HOURS
end

-- อีกกี่วินาทีจริงถึงเช้า · กลางวัน = 0
function Rules.SecondsToDawn(clockTime)
	if not DayNightConfig.IsNight(clockTime) then return 0 end
	return ((DayNightConfig.DawnHour - clockTime) % 24) * DayNightConfig.DayLengthSeconds / 24
end

return Rules
```

- [ ] **Step 5: รันให้ผ่าน**

Run: `bash tools/offline-check.sh src/ReplicatedStorage/IslandConfig.lua src/ReplicatedStorage/IslandNightRules.lua && node tools/offline-test.js tests/island_night_rules_test.lua`
Expected: `OK (2 files)` แล้ว `PASS` ทุกบรรทัด `ok`

- [ ] **Step 6: Commit**

```bash
git add src/ReplicatedStorage/IslandConfig.lua src/ReplicatedStorage/IslandNightRules.lua tests/island_night_rules_test.lua
git commit -m "Island night raid: config + pure rules (rolls, level pools, parade escalation, dawn timer)"
```

---

### Task 2: แถว 🌙 ในตารางปลดของรถส่งออก

**Files:**
- Modify: `src/ReplicatedStorage/FarmLevelConfig.lua` (`FarmLevelConfig.UnlocksAt` ต่อจากแถวเพดานสัตว์เลี้ยง)
- Test: `tests/farm_level_test.lua`

**Interfaces:**
- Consumes: `IslandConfig.NightRaid.pools` (Task 1)

- [ ] **Step 1: เทสที่ต้องตก** — ใน `tests/farm_level_test.lua` ต่อจาก check ที่ลงท้าย `"ตารางปลด Lv6-50")`

```lua
	check(has(3, "มอนบุกตอนกลางคืน") and has(10, "มอนกลางคืนโหดขึ้น") and has(20, "มอนกลางคืนโหดขึ้น"),
		"🌙 มอนบุกกลางคืน Lv3 · โหดขึ้น Lv10/Lv20 (2026-09-28)")
```

- [ ] **Step 2: รันให้เห็นว่าตก**

Run: `node tools/offline-test.js tests/farm_level_test.lua`
Expected: `FAIL 🌙 มอนบุกกลางคืน ...`

- [ ] **Step 3: เพิ่มแถว** — ใน `FarmLevelConfig.UnlocksAt` ต่อจากบรรทัด `if pets > petsBefore and pets > 1 then add(...) end`

```lua
	-- มอนบุกกลางคืน (2026-09-28): ชุดแรกเปิดระบบ ชุดถัดไป = เจอตัวโหดขึ้น
	for i, tier in ipairs(IslandConfig.NightRaid.pools) do
		if tier.level == level then
			add({ text = i == 1 and "มอนบุกตอนกลางคืน" or "มอนกลางคืนโหดขึ้น", emoji = "🌙" })
		end
	end
```

- [ ] **Step 4: รันให้ผ่าน (รวมกติกา 1-6 อย่างต่อเลเวล)**

Run: `node tools/offline-test.js tests/farm_level_test.lua`
Expected: `PASS — 0 fail` (Lv3 = 6 อย่างพอดี)

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/FarmLevelConfig.lua tests/farm_level_test.lua
git commit -m "Farm unlock table: night raid rows at Lv3/10/20"
```

---

### Task 3: ตายบนเกาะไม่เสียเลเวล/อาชีพ

**Files:**
- Modify: `src/ServerScriptService/PlayerProgression.server.lua` (hook `humanoid.Died` ในฟังก์ชัน `setUpCharacter`)

- [ ] **Step 1: ยืนยันว่า hook นี้เป็นที่เดียวที่การตายเสียเลเวล/อาชีพ**

Run: `grep -rn "ResetOnDeath" src --include=*.lua`
Expected: เรียกจาก `PlayerProgression.server.lua` เท่านั้น (Progression + Classes)

- [ ] **Step 2: ข้ามทั้งหมดบนเกาะ** — บรรทัดแรกใน `humanoid.Died:Connect(function()` ก่อน `if spendCharm(player) then return end`
(`ServerConfig` require อยู่แล้วบรรทัด 6)

```lua
			-- ตายบนเกาะฟาร์มมิ่งไม่เสียอะไร (ผู้ใช้สั่ง 2026-09-28 · มอนบุกกลางคืน) — ไม่ลดเลเวล ไม่ถอดอาชีพ
			-- ไม่ใช้เครื่องราง · ทุกทางที่ตาย (มอน จมน้ำ ตก) และทุกคนในเซิร์ฟ (เจ้าของ + แขก)
			if ServerConfig.IsFarm then return end
```

- [ ] **Step 3: คอมไพล์**

Run: `bash tools/offline-check.sh src/ServerScriptService/PlayerProgression.server.lua`
Expected: `OK (1 files)` · พิสูจน์ผลจริงได้ในเกมเท่านั้น (รายการเทสท้ายแผน)

- [ ] **Step 4: Commit**

```bash
git add src/ServerScriptService/PlayerProgression.server.lua
git commit -m "Dying on the farming island costs no level, class or charm"
```

---

### Task 4: `Mobs` รองรับมอนบุก + เปิดบนเพลสเกาะ

**Files:**
- Modify: `src/ServerScriptService/Mobs.server.lua` (`drop` · ลูป AI · หลัง `MobAccess.SpawnBoss`)
- Modify: `farming.project.json` (ถอด `Mobs.server.lua` ออกจาก `globIgnorePaths`)

**Interfaces:**
- Produces: `MobAccess.SpawnRaid(kind, position: Vector3, target: Player, opts) -> Model|nil`
  opts = `{ hp?, power?, scale?, title?, loot? = { amount?, chance?, xp?, only? = {drop...}, extra? = {drop...} }, maxHitFraction?, tag? }`
  · `MobAccess.Despawn(model)` (เก็บออก ไม่ดรอป)

- [ ] **Step 1: `drop` รับ `loot.only` / `loot.extra`** — ใน `local function drop(...)` แทรกก่อน `for _, entry in ipairs(drops) do`

```lua
	-- มอนบุกเกาะ (2026-09-28): `loot.only` = ดรอปแทนทั้งตาราง (บอสเกาะ = กล่องเวท) · `loot.extra` = ต่อท้าย (มอนพิเศษ + หีบทอง)
	if loot and loot.only then
		drops = loot.only
	elseif loot and loot.extra then
		local extended = table.clone(drops)
		for _, entry in ipairs(loot.extra) do table.insert(extended, entry) end
		drops = extended
	end
```

- [ ] **Step 2: ลูป AI — `chaseAll` ไม่มีระยะเลิกไล่/ระยะสนใจ และทิ้งเป้าที่ล้ม**

แทน
```lua
			if not hunted and (position - state.home).Magnitude > config.leashRange then
```
ด้วย
```lua
			if not hunted and not state.chaseAll and (position - state.home).Magnitude > config.leashRange then
```

แทน
```lua
				elseif not targetRoot or (targetRoot.Position - position).Magnitude > config.leashRange then
					-- Lost them (left, died, went down, or outran the leash): look for someone else.
					state.target = nearestPlayer(position, config.aggroRange)
```
ด้วย
```lua
				elseif not targetRoot or (not state.chaseAll and (targetRoot.Position - position).Magnitude > config.leashRange)
					or (state.chaseAll and state.target:GetAttribute("WOLD_Downed")) then
					-- Lost them (left, died, went down, or outran the leash): look for someone else.
					-- มอนบุกเกาะ (`chaseAll`) หาคนทั้งเกาะ ไม่มีระยะสนใจ และไม่ยืนเฝ้าคนที่ล้มแล้ว
					state.target = nearestPlayer(position, state.chaseAll and math.huge or config.aggroRange)
```

- [ ] **Step 3: ลูป AI — เพดานดาเมจ** แทน
```lua
							local hurt = Vitals.ApplyDamage(state.target, config.damage * (state.damageScale or 1), "combat")
```
ด้วย
```lua
							local amount = config.damage * (state.damageScale or 1)
							-- มอนบุกเกาะ: ตีแรงสุดเท่านี้ของเลือดเต็มคนที่โดน (IslandConfig.NightRaid.maxHitFraction)
							if state.maxHitFraction then
								amount = math.min(amount, (Vitals.MaxHP(state.target) or 100) * state.maxHitFraction)
							end
							local hurt = Vitals.ApplyDamage(state.target, amount, "combat")
```

- [ ] **Step 4: API ใหม่** — ต่อท้ายฟังก์ชัน `MobAccess.SpawnBoss` (ก่อนคอมเมนต์ "มีใครยืนอยู่ในระยะนี้ไหม")

```lua
-- มอนบุกเกาะตอนกลางคืน (2026-09-28) — `Island/IslandNight.server` เป็นคนเรียก
-- เกิดตรงจุดที่สั่ง (ช่องดินที่เลือกมาแล้ว) และ **ไล่คนทั้งเกาะ** ไม่ผูกกับคนเดียวแบบ SpawnHunters (`hunt`)
-- เลือด/ดาเมจไม่คูณกลางคืน (บนเกาะมอนมาตอนกลางคืนเสมอ) · ตกขอบ = วาร์ปกลับจุดเกิด (`home`) ตามกฎเดิมของลูป AI
MobAccess.SpawnRaid = function(kind, position, target, opts)
	opts = opts or {}
	local config = GatherConfig.Mobs[kind]
	if not config then return nil end
	local shape = (opts.scale or opts.title) and { scale = opts.scale, title = opts.title } or nil
	local model = spawnHunter(kind, config, target, position, 0, shape)
	if not model then return nil end
	local state = Live[model]
	local power = opts.power or 1
	local maxHp = opts.hp or config.hp * power
	state.hp, state.maxHp, state.damageScale = maxHp, maxHp, power
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = maxHp
		humanoid.Health = maxHp
	end
	state.loot = opts.loot -- nil = ดรอปปกติ (ทับค่าของ shape ที่ spawnHunter ตั้งเป็นดรอปบอส)
	state.maxHitFraction = opts.maxHitFraction
	state.hunt = nil
	state.chaseAll = true
	if opts.tag then CollectionService:AddTag(model, opts.tag) end
	return model
end

-- เก็บออกโดยไม่ดรอป (เช้ามาแล้วมอนบุกหายไป)
MobAccess.Despawn = function(model)
	if Live[model] then despawn(model) end
end
```

- [ ] **Step 5: เปิดบนเพลสเกาะ** — ลบบรรทัด `"src/ServerScriptService/Mobs.server.lua",` จาก `globIgnorePaths` ใน `farming.project.json`

- [ ] **Step 6: คอมไพล์ + ตรวจ JSON**

Run: `bash tools/offline-check.sh src/ServerScriptService/Mobs.server.lua && node -e "require('./farming.project.json'); console.log('json ok')" && grep -c "Mobs.server" farming.project.json`
Expected: `OK (1 files)` · `json ok` · `0`

- [ ] **Step 7: Commit**

```bash
git add src/ServerScriptService/Mobs.server.lua farming.project.json
git commit -m "Mobs: raid spawns (chase whole island, hit cap, loot only/extra, despawn) and enable Mobs on the island"
```

---

### Task 5: ต้นแบบมอนบนเพลสเกาะ

**Files:**
- Create: `mapgen/104_island_mobs.lua`
- Test: `tests/island_mob_protos_test.lua`

- [ ] **Step 1: เทส (Edit) ที่ต้องตกบนเพลสเกาะ** — `tests/island_mob_protos_test.lua`

```lua
-- node tools/lua.js tests/island_mob_protos_test.lua Edit                                (เพลสหลัก = ต้นฉบับ)
-- WOLD_PLACE=136992335889132 node tools/lua.js tests/island_mob_protos_test.lua Edit   (เพลสเกาะ)
-- มอนบุกเกาะ (2026-09-28): ทุกชนิดใน IslandConfig.NightRaid มีต้นแบบให้ Mobs (ไม่งั้นได้ลูกบอลสไลม์เขียวทุกตัว)
-- พิมพ์จำนวนชิ้น/ขนาดไว้เทียบสองเพลส
local ServerStorage = game:GetService("ServerStorage")
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end
local GatherConfig = fresh(game.ReplicatedStorage.GatherConfig)
local R = fresh(game.ReplicatedStorage.IslandConfig).NightRaid

local kinds = {}
for _, tier in ipairs(R.pools) do for _, k in ipairs(tier.kinds) do kinds[#kinds + 1] = k end end
for _, k in ipairs(R.specials) do kinds[#kinds + 1] = k end
kinds[#kinds + 1] = R.boss.kind

local out, fails = {}, 0
for _, kind in ipairs(kinds) do
	local model = GatherConfig.Mobs[kind].model
	if model then -- สไลม์เขียวไม่มีโมเดล (Mobs.buildSlime ปั้นเอง)
		local found
		for _, name in ipairs({ "Model_moster", "Model_mosterV2", "New_moster" }) do
			local f = ServerStorage:FindFirstChild(name)
			found = found or (f and f:FindFirstChild(model))
		end
		if found then
			local parts = 0
			for _, p in ipairs(found:GetDescendants()) do if p:IsA("BasePart") then parts += 1 end end
			local _, size = found:GetBoundingBox()
			out[#out + 1] = ("ok   %-24s %3d ชิ้น %5.1f x %5.1f x %5.1f"):format(model, parts, size.X, size.Y, size.Z)
		else
			fails += 1
			out[#out + 1] = "FAIL ไม่มีต้นแบบ " .. model
		end
	end
end
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
```

- [ ] **Step 2: รันทั้งสองเพลส**

Run: `node tools/lua.js tests/island_mob_protos_test.lua Edit > "$S/protos_main.txt"; WOLD_PLACE=136992335889132 node tools/lua.js tests/island_mob_protos_test.lua Edit`
(`$S` = สแครชแพด)
Expected: เพลสหลัก `PASS` (14 ต้นแบบ) · เพลสเกาะ `FAIL x14`

- [ ] **Step 3: เฟสสร้างต้นแบบ** — `mapgen/104_island_mobs.lua`

```lua
-- 104_island_mobs.lua: ต้นแบบมอนให้ `Mobs.server` บนเพลสเกาะ → ServerStorage.Model_moster (มอนบุกกลางคืน 2026-09-28)
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/104_island_mobs.lua --kit --models --no-lib
--
-- ต่อด้วยบอส + ท่าถืออาวุธ (สองเฟสเดิม รันบนเพลสเกาะได้เหมือนเพลสหลัก):
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/82_boss_prototype.lua --kit
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/86_repin_held_gear.lua --no-lib
--
-- ⚠️ **ห้ามรันที่เพลสหลัก** — ต้นแบบที่นั่นผู้ใช้วางเองและแก้ท่ามาแล้ว (เฟส 84-86) · เฟสหยุดเองถ้าไม่ใช่เพลสเกาะ
-- ไม่มีต้นแบบ = `Mobs.buildMonster` ถอยไปปั้นลูกบอลสไลม์เขียวให้ทุกชนิด (เงียบ ไม่มี error)
-- สไลม์เขียวไม่ต้องมี (ลูกบอลของ `Mobs.buildSlime`) · รันซ้ำได้ (ลบตัวชื่อเดียวกันก่อน)
-- โมเดลมาจากโรงงานชุดเดียวกับสัตว์เลี้ยงเฟส 103 · `Mobs.buildFromModel` จัดการสคริปต์/ข้อต่อ R15/HumanoidRootPart เอง
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
if game.PlaceId ~= 136992335889132 then
	error("[IslandMobs] เฟสนี้รันเฉพาะเพลสเกาะ — PlaceId ตอนนี้ " .. game.PlaceId)
end

local BUILDERS = {
	"Monster_Bat", "Monster_Boar", "Monster_Wolf", "Monster_Spider",
	"Monster_Skeleton", "Monster_Bandit", "Monster_Ghoul", "Monster_ClockworkSentry", "Monster_Wraith",
	"Monster_StoneGolem", "Monster_SteamSlime", "Monster_PlasmaSlime", "Monster_BioSlime",
}

local folder = ServerStorage:FindFirstChild("Model_moster")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Model_moster"
	folder.Parent = ServerStorage
end

-- ของ kit ที่มอนในเกมไม่ต้องมี: สคริปต์โชว์ของโรงงาน · ปุ่ม · ป้ายชื่อ · แท็ก (ทรงเดียวกับ strip ในเฟส 103)
local function strip(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then d:Destroy() end
	end
	for _, d in ipairs(m:GetDescendants()) do
		for _, tag in ipairs(CollectionService:GetTags(d)) do CollectionService:RemoveTag(d, tag) end
	end
	for _, tag in ipairs(CollectionService:GetTags(m)) do CollectionService:RemoveTag(m, tag) end
end

local made, failed = 0, {}
for _, name in ipairs(BUILDERS) do
	local ok, err = pcall(function()
		local old = folder:FindFirstChild(name)
		if old then old:Destroy() end
		local m = K.place(name, workspace, CFrame.new(0, 5000, 0))
		if not m then error("ไม่มี builder (ลืม --models?)") end
		m.Parent = nil
		strip(m)
		m.Name = name
		m.Parent = folder
	end)
	if ok then made += 1 else failed[#failed + 1] = name .. ": " .. tostring(err) end
end
for _, f in ipairs(failed) do warn("[IslandMobs] " .. f) end
print(("[IslandMobs] done %d ตัว · พัง %d"):format(made, #failed))
```

- [ ] **Step 4: รันสามเฟสบนเพลสเกาะ**

Run:
```bash
WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/104_island_mobs.lua --kit --models --no-lib
WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/82_boss_prototype.lua --kit
WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/86_repin_held_gear.lua --no-lib
```
Expected: `[IslandMobs] done 13 ตัว · พัง 0` · บอสสร้างเสร็จ · เฟส 86 จบไม่มี error

- [ ] **Step 5: เทสผ่าน + เทียบกับเพลสหลัก**

Run: `WOLD_PLACE=136992335889132 node tools/lua.js tests/island_mob_protos_test.lua Edit` แล้วเทียบกับ `$S/protos_main.txt`
Expected: `PASS` 14 ต้นแบบ · ขนาด (กล่อง) ใกล้กับเพลสหลักทุกตัว — ตัวไหนต่างเกิน 20% จดไว้บอกผู้ใช้ (อาจเป็นเวอร์ชันโรงงานต่างกัน)

- [ ] **Step 6: Commit**

```bash
git add mapgen/104_island_mobs.lua tests/island_mob_protos_test.lua
git commit -m "Island: monster prototypes for Mobs (factory builds + boss + repin)"
```

---

### Task 6: ตัวคุมคืน `IslandNight` + ป้ายพาเหรด + คำสั่ง `/night`

**Files:**
- Create: `src/ServerScriptService/Island/IslandNight.server.lua`
- Modify: `src/ServerScriptService/Island/IslandNodes.server.lua` (ส่งออกช่องดิน · ใกล้ `IslandAccess.NodeCount`)
- Modify: `src/ServerScriptService/Island/IslandAccess.lua` (ประกาศช่องใหม่ในรายการหัวไฟล์)
- Modify: `src/StarterPlayerScripts/EventBannerController.client.lua` (เสียงจากภาพอีเวนต์)
- Modify: `src/ServerScriptService/AdminCommands.server.lua` (`Commands.night` ต่อจาก `Commands.farm`)
- Modify: `arena.project.json` (denylist `IslandNight.server.lua`)

**Interfaces:**
- Consumes: Task 1 `IslandNightRules.*` + `IslandConfig.NightRaid` · Task 4 `MobAccess.SpawnRaid/Despawn`
- Produces: `IslandAccess.SoilCells() -> { {cx, cz}... }` · `IslandAccess.SoilCellFree(cx, cz) -> bool` · `IslandAccess.NightAdmin(admin, args) -> string`

- [ ] **Step 1: ช่องดินจาก IslandNodes** — ต่อท้ายบรรทัด `IslandAccess.NodeCount = ...`

```lua
-- มอนบุกกลางคืน (IslandNight 2026-09-28): ช่องดินในรั้ว + "ช่องนี้ว่างไหม" กติกาเดียวกับจุดเกิดของสุ่ม
-- (ไม่มีของสุ่ม ไม่มีของวาง เดินถึงจากจุดเกิด)
IslandAccess.SoilCells = function() return soilCells end
IslandAccess.SoilCellFree = freeCell
```
และใน `IslandAccess.lua` เพิ่มในรายการหัวไฟล์:
```lua
IslandAccess.SoilCells = nil -- () -> { {cx, cz}... } ช่องดินในรั้ว (IslandNodes)
IslandAccess.SoilCellFree = nil -- (cx, cz) -> bool ช่องดินนี้ว่างให้ของใหม่ไหม (IslandNodes)
IslandAccess.NightAdmin = nil -- (admin, args) -> ข้อความ · คำสั่ง /night (IslandNight)
```

- [ ] **Step 2: ป้ายเล่นเสียงจากภาพอีเวนต์ได้** — `EventBannerController.client.lua` ในฟังก์ชัน `apply` แทน
```lua
			local config = EventConfig.Events[id]
			if config and config.sound then UiSound.Play(config.sound) end
```
ด้วย
```lua
			local config = EventConfig.Events[id]
			-- เกาะส่งเสียงมากับภาพเอง (พาเหรดมอนสเตอร์ไม่อยู่ใน EventConfig — ไม่งั้น WorldEvents เกมหลักจะสุ่มเริ่มมัน)
			local sound = (config and config.sound) or spec.sound
			if sound then UiSound.Play(sound) end
```

- [ ] **Step 3: ตัวคุมคืน** — `src/ServerScriptService/Island/IslandNight.server.lua`

```lua
-- IslandNight.server.lua: มอนบุกเกาะตอนกลางคืน + อีเวนต์พาเหรดมอนสเตอร์ (ผู้ใช้สั่ง 2026-09-28)
-- สเปก docs/superpowers/specs/2026-09-28-island-night-raid-design.md · กติกาล้วน `IslandNightRules` · ตัวเลข `IslandConfig.NightRaid`
--
-- ไฟล์นี้คุมแค่จังหวะ: เพิ่งมืด → ทอยแล้วปล่อยมอน · คืนพาเหรด → เติมทุก 20 วิ · เพิ่งสว่าง → เก็บหมด
-- AI · ดรอป · EXP · นับเควส/สมุด อยู่กับ `Mobs.server` (ผ่าน `MobAccess.SpawnRaid/Despawn`)
-- ป้ายพาเหรด: เกาะไม่มี `WorldEvents.server` → ยิง `EventStateChanged` เอง ทรงเดียวกับ `WorldEvents.picture()`
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsFarm then return end

local IslandConfig = require(game.ReplicatedStorage.IslandConfig)
local IslandGrid = require(game.ReplicatedStorage.IslandGrid)
local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
local Rules = require(game.ReplicatedStorage.IslandNightRules)
local Remotes = require(game.ReplicatedStorage.Remotes)
local MobAccess = require(game.ServerScriptService.MobAccess)
local IslandAccess = require(script.Parent.IslandAccess)

local R = IslandConfig.NightRaid
local Parade = nil -- { startedAt, endsAt } (เวลาเซิร์ฟ) ระหว่างคืนพาเหรด
local nextParadeAt = 0

local function isNight()
	return workspace:GetAttribute("WOLD_IsNight") == true
end

local function farmLevel()
	return IslandAccess.FarmLevel and IslandAccess.FarmLevel() or 1
end

local function raiders()
	local out = {}
	for _, m in ipairs(CollectionService:GetTagged(R.tag)) do
		if m.Parent then out[#out + 1] = m end
	end
	return out
end

-- ภาพอีเวนต์ทรงเดียวกับ WorldEvents.picture() · ว่าง = ไม่มีป้าย
local function picture()
	if not Parade then return {} end
	local b = R.banner
	return { parade = { icon = b.icon, message = b.message, colour = b.colour, sound = b.sound,
		startedAt = Parade.startedAt, endsAt = Parade.endsAt } }
end

local function publish()
	Remotes.EventStateChanged:FireAllClients(picture())
end

-- คนที่เข้าเกาะกลางคืนพาเหรดก็ต้องเห็นป้าย (EventBannerController ถามตอนเริ่ม)
Remotes.RequestEventState.OnServerEvent:Connect(function(player)
	Remotes.EventStateChanged:FireClient(player, picture())
end)

-- คนบนเกาะที่ยังยืนอยู่
local function standing()
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and not p:GetAttribute("WOLD_Downed") then out[#out + 1] = p end
	end
	return out
end

-- ช่องดินในรั้วที่ว่าง ห่างเป้า 30-60 สตัดก่อน ไม่มีก็ช่องดินว่างไหนก็ได้ · ไม่มีเลย = nil (ไม่เกิด)
local function spawnPoint(target)
	local cells = IslandAccess.SoilCells and IslandAccess.SoilCells() or {}
	if #cells == 0 or not IslandAccess.SoilCellFree then return nil end
	local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	local near, far = {}, {}
	for _, c in ipairs(cells) do
		local x, z = IslandGrid.worldOf(c[1], c[2])
		local d = root and Vector2.new(x - root.Position.X, z - root.Position.Z).Magnitude or 0
		if d >= R.spawnMinDistance and d <= R.spawnMaxDistance then near[#near + 1] = c else far[#far + 1] = c end
	end
	for _, list in ipairs({ near, far }) do
		for _ = 1, math.min(30, #list) do
			local c = list[math.random(#list)]
			if IslandAccess.SoilCellFree(c[1], c[2]) then
				local y = IslandGrid.surfaceAt(c[1], c[2])
				if y then
					local x, z = IslandGrid.worldOf(c[1], c[2])
					return Vector3.new(x, y, z)
				end
			end
		end
	end
	return nil
end

-- ปล่อยหนึ่งตัว · role = nil (ธรรมดา) | "boss" | "special" | "leader" · kind = ชนิดจากชุดตามเลเวล
local function spawn(role, kind)
	local list = standing()
	if #list == 0 or not MobAccess.SpawnRaid then return nil end
	local target = list[math.random(#list)]
	local at = spawnPoint(target)
	if not at then return nil end
	local opts = { maxHitFraction = R.maxHitFraction, tag = R.tag }
	if role == "boss" then
		kind = R.boss.kind
		opts.hp = R.boss.hp
		opts.loot = { only = { { item = R.boss.drop, min = 1, max = 1 } } }
	elseif role == "special" then
		kind = Rules.Pick(R.specials)
		opts.loot = { extra = { { item = R.specialChest, min = 1, max = 1 } } }
	elseif role == "leader" then
		local L, config = R.leader, GatherConfig.Mobs[kind]
		opts.scale = L.scale * (config.scale or 1)
		opts.power = L.power
		opts.title = "👑 หัวหน้าฝูง " .. (config.name or kind)
		opts.loot = { amount = L.amount, xp = L.xp }
	end
	if not kind then return nil end
	return MobAccess.SpawnRaid(kind, at, target, opts)
end

local function startParade()
	local now = workspace:GetServerTimeNow()
	Parade = { startedAt = now, endsAt = now + Rules.SecondsToDawn(Lighting.ClockTime) }
	nextParadeAt = os.clock() + R.paradeEverySeconds
	publish()
end

-- หัวค่ำ: 1-3 ตัว (ตัวแรกเป็นตัวพิเศษถ้าทอยติด) + พาเหรดถ้าทอยติด · คืนจำนวนที่เกิดจริง
local function raid(night)
	local pool = Rules.PoolFor(math.max(farmLevel(), R.minFarmLevel))
	local made = 0
	for i = 1, math.random(R.countMin, R.countMax) do
		if spawn(i == 1 and night.special or nil, Rules.Pick(pool)) then made += 1 end
	end
	if night.parade then startParade() end
	return made
end

-- เช้า: มอนบุกหายหมด ไม่ดรอป + ปิดป้าย
local function dawn()
	local n = 0
	for _, m in ipairs(raiders()) do
		MobAccess.Despawn(m)
		n += 1
	end
	if Parade then
		Parade = nil
		publish()
	end
	return n
end

-- จังหวะคืน (ลูป 1 วิ) · บูตกลางคืนไม่นับว่าเพิ่งมืด (เซิร์ฟเริ่มตอนเช้าเสมอ StartTime 7)
local wasNight = nil
task.spawn(function()
	while true do
		task.wait(1)
		local night = isNight()
		if wasNight ~= nil and night ~= wasNight then
			if night then
				if farmLevel() >= R.minFarmLevel then
					local night0 = Rules.RollNight()
					local made = raid(night0)
					print(("[IslandNight] มืดแล้ว: มอน %d ตัว · พิเศษ %s · พาเหรด %s"):format(
						made, tostring(night0.special), tostring(night0.parade)))
				end
			else
				local n = dawn()
				if n > 0 then print(("[IslandNight] เช้าแล้ว: เก็บมอนบุก %d ตัว"):format(n)) end
			end
		end
		wasNight = night
		if Parade and night and os.clock() >= nextParadeAt then
			nextParadeAt = os.clock() + R.paradeEverySeconds
			if #raiders() < R.paradeMaxAlive then
				local level = math.max(farmLevel(), R.minFarmLevel)
				spawn(nil, Rules.Pick(Rules.PoolAt(level, Rules.Progress(Lighting.ClockTime))))
			end
		end
	end
end)

-- /night [raid | parade | boss | special | leader | clear] — เทสในเกม (AdminCommands เรียก)
IslandAccess.NightAdmin = function(_, args)
	local sub = string.lower(args[1] or "")
	local pool = Rules.PoolFor(math.max(farmLevel(), R.minFarmLevel))
	if sub == "raid" then
		return ("ปล่อยมอนบุก %d ตัว"):format(raid({ special = nil, parade = false }))
	elseif sub == "parade" then
		if not isNight() then return "พาเหรดเริ่มได้ตอนกลางคืนเท่านั้น — /time 20 ก่อน" end
		startParade()
		return "เริ่มพาเหรดมอนสเตอร์ถึงเช้า"
	elseif sub == "boss" or sub == "special" or sub == "leader" then
		return spawn(sub, Rules.Pick(pool)) and ("ปล่อย %s แล้ว"):format(sub)
			or "ปล่อยไม่ได้ (ไม่มีช่องดินว่าง · ไม่มีใครยืนอยู่ · หรือไม่มีต้นแบบมอน)"
	elseif sub == "clear" then
		return ("เก็บมอนบุก %d ตัว"):format(dawn())
	elseif sub ~= "" then
		return "ใช้: /night [raid | parade | boss | special | leader | clear]"
	end
	return ("ตอนนี้%s · มอนบุก %d ตัว%s · เลเวลฟาร์ม %d (มอนบุกเริ่มที่ %d) · ช่องดิน %d"):format(
		isNight() and "กลางคืน" or "กลางวัน", #raiders(), Parade and " · พาเหรดอยู่" or "",
		farmLevel(), R.minFarmLevel, IslandAccess.SoilCells and #IslandAccess.SoilCells() or 0)
end
```

- [ ] **Step 4: คำสั่งแอดมิน** — `AdminCommands.server.lua` ต่อจาก `Commands.farm`

```lua
-- /night [raid | parade | boss | special | leader | clear] -- มอนบุกเกาะตอนกลางคืน (บนเกาะของตัวเอง · 2026-09-28)
-- ไม่ใส่อะไร = ดูสถานะ · อยากเห็นของจริงตอนหัวค่ำ: /farm level 3 แล้ว /time 18 ตามด้วย /time auto
Commands.night = function(admin, args)
	if not ServerConfig.IsFarm then return reply(admin, "ใช้ได้บนเกาะฟาร์มเท่านั้น") end
	local IslandAccess = require(game.ServerScriptService.Island.IslandAccess)
	if not IslandAccess.NightAdmin then return reply(admin, "ระบบมอนกลางคืนยังไม่พร้อม") end
	reply(admin, IslandAccess.NightAdmin(admin, args))
end
```

- [ ] **Step 5: ตัดออกจากเพลสสนาม** — `arena.project.json` เพิ่มหลังบรรทัด `IslandNodes.server.lua` ใน `globIgnorePaths`

```json
    "src/ServerScriptService/Island/IslandNight.server.lua",
```

- [ ] **Step 6: คอมไพล์ทุกไฟล์ + JSON + เทสเดิมที่แตะส่วนเดียวกัน**

Run:
```bash
bash tools/offline-check.sh src/ServerScriptService/Island/IslandNight.server.lua src/ServerScriptService/Island/IslandNodes.server.lua src/ServerScriptService/Island/IslandAccess.lua src/StarterPlayerScripts/EventBannerController.client.lua src/ServerScriptService/AdminCommands.server.lua
node -e "require('./arena.project.json'); console.log('json ok')"
node tools/offline-test.js tests/island_night_rules_test.lua
node tools/offline-test.js tests/farm_level_test.lua
```
Expected: `OK (5 files)` · `json ok` · `PASS` · `PASS — 0 fail`

- [ ] **Step 7: Commit**

```bash
git add src/ServerScriptService/Island/IslandNight.server.lua src/ServerScriptService/Island/IslandNodes.server.lua src/ServerScriptService/Island/IslandAccess.lua src/StarterPlayerScripts/EventBannerController.client.lua src/ServerScriptService/AdminCommands.server.lua arena.project.json
git commit -m "IslandNight: dusk raids, parade event with dawn countdown banner, dawn cleanup, /night admin"
```

---

### Task 7: ดันสามเพลส + ตรวจรวม + เอกสาร

**Files:**
- Modify: `CLAUDE.md` (หัวข้อใหม่ใต้ "ปรับราคา/สูตร 2026-09-28")

- [ ] **Step 1: ดันและตรวจทั้งสามเพลส**

Run:
```bash
for p in default farming arena; do node tools/verify.js $p.project.json --push; done
for p in default farming arena; do node tools/verify.js $p.project.json | tail -1; done
```
Expected: บรรทัดสุดท้ายทั้งสามเพลส `mismatches 0` · เพลสเกาะมี `Mobs` + `IslandNight` · เพลสสนามไม่มี `IslandNight`

- [ ] **Step 2: ⚠️ Rojo ไม่ลบของ — `Mobs` ต้องมีในเพลสเกาะจริง** (ถูก denylist มาตลอด `verify --push` สร้างให้)

Run: `WOLD_PLACE=136992335889132 node tools/mcp-call.js execute_luau '{"datamodel_type":"Edit","code":"return tostring(game.ServerScriptService:FindFirstChild(\"Mobs\")) .. \" \" .. tostring(game.ServerScriptService.Island:FindFirstChild(\"IslandNight\"))"}'`
Expected: `Mobs IslandNight`

- [ ] **Step 3: โหลดโมดูลทั้งหมดใน Edit (จับ "ใช้ก่อนประกาศ" ในโมดูล)**

Run: `node tools/lua.js "$S/load_all_modules.lua" Edit` (สแครชแพดเดิม) และ `WOLD_PLACE=136992335889132 node tools/lua.js "$S/load_all_modules.lua" Edit`
Expected: `failed=0` (timeout เฉพาะ `Remotes` = ปกติ)

- [ ] **Step 4: CLAUDE.md** — เพิ่มใต้หัวข้อ "ปรับราคา/สูตร 2026-09-28"

```markdown
**มอนบุกเกาะตอนกลางคืน + พาเหรดมอนสเตอร์ (2026-09-28) — ดันสามเพลส · ยังไม่ได้เทสในเกม** สเปก `docs/superpowers/specs/2026-09-28-island-night-raid-design.md` · แผน `docs/superpowers/plans/2026-09-28-island-night-raid.md`
- ⚠️ **`Mobs.server` รันบนเพลสเกาะแล้ว** (ถอดจาก denylist) · ต้นแบบมอนบนเกาะมาจาก `mapgen/104_island_mobs.lua` (+82 บอส +86 ท่าถือ) — **ไม่มีต้นแบบ = ทุกตัวเป็นลูกบอลสไลม์เขียวเงียบๆ** (`tests/island_mob_protos_test.lua` ตรวจ)
- `Island/IslandNight.server` คุมจังหวะ · `IslandNightRules` กติกาล้วน · ตัวเลข `IslandConfig.NightRaid` · `MobAccess.SpawnRaid/Despawn` (ไล่ทั้งเกาะ `chaseAll` · เพดานตี `maxHitFraction` · `loot.only/extra`)
- ป้ายพาเหรดไม่อยู่ใน `EventConfig.Events` (ไม่งั้น WorldEvents เกมหลักสุ่มเริ่ม) — เกาะยิง `EventStateChanged` เอง + ตอบ `RequestEventState` · เสียงมากับภาพ (`spec.sound`)
- ⚠️ **ตายบนเกาะไม่เสียเลเวล/อาชีพ/เครื่องราง** (`PlayerProgression` `if ServerConfig.IsFarm then return end`)
- คำสั่งเทส **`/night [raid | parade | boss | special | leader | clear]`** · ของจริงตอนหัวค่ำ: `/farm level 3` → `/time 18` → `/time auto`
```

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: island night raid notes"
```

## รายการเทสในเกม (ผู้ใช้ — ต้อง publish ทั้งสามเพลส เพลสเกาะสำคัญสุด)

1. `/night` (ไม่ใส่อะไร) บนเกาะ = บอกกลางวัน/คืน เลเวลฟาร์ม ช่องดิน > 0
2. `/night raid` → มอน 1-3 ตัวโผล่บนผืนดินในรั้ว **หน้าตาเหมือนเกมหลัก** (ไม่ใช่ลูกบอลเขียว) เดินมาไล่ ตีทีละไม่เกิน 10% ของหลอดเลือด
3. `/night leader` ตัวใหญ่กว่าปกติสองเท่า ฆ่าแล้วได้วัตถุดิบ 2 เท่า · `/night special` สไลม์ชื่อเฉพาะ ฆ่าแล้วได้หีบทอง ·
   `/night boss` ฟอร์จวอร์เดนตัวใหญ่ เลือด 1,500 ฆ่าแล้วได้กล่องเวทมนตร์
4. `/farm level 3` → `/time 18` → `/time auto` → รอหัวค่ำ มอนมาเอง · รอเช้า มอนหายหมด
5. `/time 20` → `/time auto` → `/night parade` → ป้าย "🌙 พาเหรดมอนสเตอร์" + นับถอยหลัง มีเสียง · มอนเพิ่มทุก 20 วิ ไม่เกิน 8 · เช้าป้ายหาย
6. ปล่อยให้มอนตีจนล้มแล้วกดเกิดใหม่ → **เลเวลและอาชีพเท่าเดิม** · เครื่องรางไม่หาย
7. เพื่อนมาเที่ยวเกาะตอนมอนบุก → มอนไล่เพื่อนด้วย · สัตว์เลี้ยง/สัตว์ในคอกไม่โดนตี
8. เกมหลัก: มอนปกติ/บอสโลกเหมือนเดิม · ตายในเกมหลักยังเสียเลเวลตามเดิม
