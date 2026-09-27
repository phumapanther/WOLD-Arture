# เฟส 2c · เลเวลฟาร์ม + รถส่งออก + คราฟขั้นสูง — Implementation Plan

**Goal:** วงจร เก็บ → คราฟ → ส่งออก → EXP ฟาร์ม → เลเวล → ปลด บนเกาะฟาร์มมิ่ง ตามร่าง
`docs/superpowers/specs/2026-09-27-phase2c-farm-level-design.md` (ผู้ใช้อนุมัติ 2026-09-27 ทั้งไฟล์) + สเปกแม่หัวข้อ "เฟส 2c"

**ผู้ใช้ตัดสิน 2026-09-27:** ผู้เล่นเก่าเริ่ม Lv1 ทุกคน · ฝ้าย = เมล็ดฝ้ายแยก ซื้อในร้าน (เมล็ดเดิมยังสุ่ม) ·
เครื่องคราฟบนเกาะทำได้ทีละ 1-10 ชิ้นต่องาน · ตัวเลขใช้ตามร่าง

## Architecture
- **ข้อมูลล้วน (ReplicatedStorage · เทสใน Edit ได้)**
  - `FarmLevelConfig` — เส้น EXP · `LevelFromExp` · perk (แสง/ขอบทอง/เพดานบ้าน) · `UnlocksAt(level)` รวมจากคอนฟิกทุกตัว
  - `ExportConfig` — ของที่ส่งออกได้ (ราคา/ชิ้น · เพดานต่อใบ · เลเวล) · กติกาใบสั่ง/เพชร · เวลาส่ง
  - `ExportOrders` — สุ่มใบสั่ง (`NewOrder(level, rng, noGold)`) · ทอยเพชร (`RollGems(state, order, day, month, rng)`) · ตรวจใบเก่า (`Valid`)
  - เลเวลอยู่กับของแต่ละชิ้นที่คอนฟิกของมันเอง: `ShopConfig.IslandSells[i].level` · `IslandConfig.PenAnimals[i].level` ·
    `IslandConfig.Crops[i].level` · `IslandConfig.MineRocks[i].level` · สูตร `CraftConfig.Recipes[i].level` — **ของใหม่บนเกาะต้องมี level (เทสตรวจ)**
- **เซิร์ฟ (เกาะเท่านั้น)** `Island/IslandFarm.server.lua` เป็นเจ้าของ `Data.Island.farm` + รถส่งออก + ฉลอง ·
  ประกาศ `IslandAccess.FarmLevel()` · `IslandAccess.RollGlow(canGold)` · `IslandAccess.GoldAllowed()`
  — **ทุกที่ที่ทอยแสง/ขอบทองบนเกาะถามผ่านสองตัวนี้** (Gathering · IslandNodes · IslandZones · IslandPlots)
- **ด่านล็อก** ฝั่งเซิร์ฟทุกจุด ไคลเอนต์แค่วาดสถานะ 🔒: ร้านเกาะ (+เพดานบ้าน) · คอก · โซนแร่ · เมล็ดที่งอก · สูตรคราฟ
- **ไคลเอนต์** `UI/ExportGui` (หน้าต่างรถ) · `ExportController` (หน้าต่าง + ป้ายเหนือรถ + ควัน + ป้ายมุมจอ + แบนเนอร์ฉลอง) ·
  `IslandSeedController` (เลือกเมล็ด) · ShopGui/หน้าต่างคอก/CraftGui วาดแถวที่ล็อก + CraftGui ปุ่ม −/+ จำนวน

## Data
`profile.Data.Island.farm = { exp, celebrated, orders = {o1,o2,o3}, ship = {slot, order, startAt, endAt} | nil,
 nextId, gemDay, gemDayCount, gemDayOrders, gemMonth, gemMonthCount, rerollDay }`
order = `{ id, lines = { {item, qty} }, coins, exp, gold = bool }` · สร้างแบบ lazy · ไม่มีวันลด

## Tasks
1. **Pure config + generator + tests** — FarmLevelConfig · ExportConfig · ExportOrders · level ในคอนฟิกเดิม ·
   `tests/farm_level_test.lua` (เส้น EXP · ร้านเกาะทุกแถวมี level · perk · UnlocksAt ครบ · ใบสั่งไม่เกินเพดาน/มีแต่ของที่ปลด ·
   ใบขอบทองเฉพาะ Lv4+ · เพดานเพชร 2/5/150 · 3 ใบแรกได้แน่นอน) — commit
2. **ของใหม่ + สูตร** — ItemCatalog (ฝ้าย · เมล็ดฝ้าย · 3 เครื่อง · ของคราฟ 17 ชิ้น `vip = true`) · CraftConfig (แท็บ 3 สถานี ·
   สูตรต่อท้าย `batch = true`) · ShopConfig (เครื่อง + เมล็ดฝ้าย) · IslandConfig.Crops ฝ้าย `seed = "CottonSeed"` ·
   StarterKit ไม่มีบ้าน · เทสสูตร (ของมีจริง · ≤2 ชม. · ขั้นสุดท้ายไม่ใช่วัตถุดิบ · เลเวลสูตร ≥ เลเวลเครื่อง) — commit
3. **IslandFarm.server** — ข้อมูล · เลเวล + แอตทริบิวต์บนตัวผู้เล่น · หารถ (ลูป) + ปุ่ม E ท้ายรถ + แอตทริบิวต์ ShipStart/ShipEnd ·
   ส่ง (หักของ รวมของขอบทองสำหรับใบทอง — `Inventory.CountGold/RemoveGold` ใหม่) · จบงาน (ลูป 1 วิ + ตอนโหลด) → เหรียญ/เพชร/EXP ·
   สุ่มใหม่ฟรีวันละครั้ง · ฉลอง (ค้าง → ไคลเอนต์พร้อม → แบนเนอร์ → ตอบรับ → จด + พลุ) · ช่องเทส `FarmTest` — commit
4. **ด่านล็อก** — Shop.server · IslandZones · IslandPlots (+ เลือกเมล็ด) · Gathering · IslandNodes · Crafting (เลเวลสูตร · จำนวน ·
   ชื่อหน้าต่างตามสถานี) · CraftStations · IslandBuild FUNCTIONAL — commit
5. **UI** — ExportGui · ExportController · IslandSeedController · ShopGui/คอก/CraftGui · LoadingController ตั้งธงโหลดจบ ·
   `load_all_modules` ผ่าน — commit
6. **โมเดล** — เตาอบ · โต๊ะช่างเหล็ก · กี่ทอผ้า · ต้นฝ้าย ใน `mapgen/90_island_placeables.lua` (modelkit) → รันเพลสเกาะ → ภาพ — commit
7. **ดัน + ตรวจ + เอกสาร** — ดันสามเพลส (กรอง denylist) hash ตรง 0 · เทสทั้งหมด · สเปก/CLAUDE.md · รายการเทสในเกม — commit

## Review focus
- ส่งออกระหว่างกระเป๋า/โปรไฟล์ยังไม่โหลด · ออกเกมกลางส่ง · เซิร์ฟปิดกลางส่ง → ไม่มีทางได้รางวัลซ้ำ/หาย (จดลงโปรไฟล์ก่อนแจก)
- ใบธรรมดาห้ามกินของขอบทอง · ใบขอบทองกินเฉพาะชิ้นทอง · ของไม่ครบ = ไม่แตะอะไร
- เพชรเกินเพดานไม่ได้ทุกทาง (วันพลิก · เดือนพลิก · ใบขอบทอง)
- ฉลองไม่ซ้ำ ไม่หาย · แขกเปิดรถไม่ได้ · เลเวลไม่มีวันลด
- ของที่มีอยู่แล้วใช้ต่อได้ (คอกเก่า · โซนแร่เก่า · บ้านเก่า · เครื่องครัวเก่า)
