-- ExportConfig (เฟส 2c ผู้ใช้อนุมัติร่าง 2026-09-27): รถส่งออกบนเกาะ — ของที่ส่งได้ ราคา กติกาใบสั่ง เพชร
--
-- ข้อมูลล้วน (ไม่ require อะไร) · ตัวสุ่มใบสั่งอยู่ที่ `ExportOrders` · ตัวเลขทุกตัวในไฟล์นี้ผมตั้ง ปรับที่นี่ที่เดียว
local ExportConfig = {}

-- ส่งทีละใบ ใบละ 18 นาที นับตอนออฟไลน์ด้วย (os.time ในโปรไฟล์)
ExportConfig.ShipSeconds = 18 * 60 -- ผู้ใช้กำหนด 2026-09-28 (เดิม 30 นาที)
ExportConfig.OrderSlots = 3

-- มูลค่าเป้าต่อใบ = Base + PerLevel × (เลเวล − 1) เหรียญ (Lv1 300 · Lv5 780 · Lv10 1,380 · Lv20 2,580)
-- **เลย TargetKnee ไปแล้วโตช้าลงเหลือ PerLevelAfter** (ขยายเป็น 50 เลเวล 2026-09-27) — ไม่งั้น Lv50 ขอของ 6,000 เหรียญ
-- ต่อใบ = ครึ่งวันเล่นต่อใบเดียว แล้ววันละ 8 ใบที่ใช้ตั้งเส้น EXP ก็เป็นไปไม่ได้ (Lv50 = 3,780)
-- แบ่งเท่าๆ กันให้แต่ละบรรทัด แล้วคิดจำนวนจากราคาต่อชิ้น · **EXP = เหรียญ ÷ ExpDivisor**
ExportConfig.TargetBase = 300
ExportConfig.TargetPerLevel = 120
ExportConfig.TargetKnee = 20
ExportConfig.TargetPerLevelAfter = 40
ExportConfig.ExpDivisor = 5
-- ของชิ้นเดียวที่แพงเกินส่วนแบ่งของบรรทัดเท่านี้ ไม่ออกในบรรทัดนั้น (กันใบ Lv3 ขอนาฬิกาพก)
ExportConfig.OverShare = 2.5
-- บรรทัดต่อใบ: Lv1-2 = 1 · Lv3-6 = 1-2 · Lv7+ = 2-3
ExportConfig.LineBands = {
	{ upTo = 2, min = 1, max = 1 },
	{ upTo = 6, min = 1, max = 2 },
	{ upTo = math.huge, min = 2, max = 3 },
}

-- **ของในใบยากขึ้นตามเลเวล** (ผู้ใช้สั่ง 2026-09-27: "วัตถุดิบก็ขออะไรที่ยากขึ้นเรื่อยๆตามเลเวลด้วย")
-- น้ำหนักของแต่ละชิ้น = e^(−(เลเวลฟาร์ม − เลเวลที่ของชิ้นนั้นปลด) / Decay) ไม่ต่ำกว่า Floor
-- = ของที่เพิ่งปลดออกบ่อยสุด ของพื้นฐานค่อยๆ หายไป · ตาราง 50 เลเวล (2026-09-27) ของปลดห่างกันขึ้น จึงยืด decay 3 → 8
-- (วัดแล้ว: Lv30+ ของพื้นฐาน ~1% · ใบ Lv40-50 ขอของ ~7 ชนิดคละกัน แทนที่จะเป็นแร่เวท/เพชรเกือบทั้งใบ)
ExportConfig.Weighting = { decay = 8, floor = 0.01 }
-- จำนวนสูงสุดต่อบรรทัดโตตามเลเวลที่เลยจุดปลดของชิ้นนั้นมา: max × (1 + QtyGrowth × ส่วนต่าง) (นาฬิกาพก Lv19 ขอได้ 2 เรือน)
ExportConfig.QtyGrowth = 0.08
-- ของขั้นสุดท้าย (★) ต่อใบ: ต่ำกว่า Lv10 ไม่เกิน 1 บรรทัด · Lv10 ขึ้นไป 2
ExportConfig.FinalsFrom10 = 2

-- ใบขอบทอง: ปลดพร้อมของขอบทอง (FarmLevelConfig.GoldBorderLevel) · มีได้ทีละใบ
ExportConfig.Gold = {
	chance = 0.15, -- ต่อใบใหม่หนึ่งใบ
	perUnit = 12, -- เหรียญ = ราคาชิ้นปกติ × 12 × จำนวน + bonus
	bonus = 200,
	expDivisor = 4, -- EXP = เหรียญ ÷ 4 (ใบปกติ ÷ 5)
	twoFrom = 8, -- เลเวลนี้ขึ้นไปขอ 1-2 ชิ้น (ต่ำกว่า = 1)
	gems = 2, -- เพชรเต็มเพดานต่อใบเสมอ (ยังอยู่ในเพดานวัน/เดือน)
}

-- เพชรจากการส่งออก (สเปกแม่): 3 ใบแรกของวันได้แน่นอน · ใบถัดไป 50% · ใบละ 1-2
-- เพดาน ใบละ 2 · วันละ 5 · เดือนละ 150 · วัน/เดือนพลิกตามเวลาไทย (ตัวเดียวกับบอร์ดเควส)
ExportConfig.Gems = {
	guaranteedPerDay = 3,
	chanceAfter = 0.5,
	min = 1, max = 2,
	perOrder = 2, perDay = 5, perMonth = 150,
}

-- สุ่มใบใหม่ฟรีวันละครั้ง (ใบไหนก็ได้ ยกเว้นใบที่กำลังส่ง)
ExportConfig.FreeRerollsPerDay = 1

-- ของที่ส่งออกได้ · `coins` = เหรียญต่อชิ้น (ร้านรับซื้อจ่าย ~0.6 เท่าของ value — ส่งออกคุ้มกว่าเสมอ) ·
-- `max` = ต่อใบไม่เกินเท่านี้ · `level` = เลเวลฟาร์มที่เริ่มออกในใบสั่ง (ต้องไม่ต่ำกว่าเลเวลที่ผลิตของชิ้นนั้นได้ — เทสตรวจ)
-- · `final` = ขั้นสุดท้ายจากเครื่องคราฟ (★)
ExportConfig.Goods = {
	-- ผลผลิตดิบ
	{ id = "Wheat", coins = 30, max = 25, level = 1 },
	{ id = "Vegetable", coins = 28, max = 25, level = 1 },
	{ id = "Egg", coins = 12, max = 30, level = 2 },
	{ id = "Herb", coins = 30, max = 20, level = 6 },
	{ id = "Milk", coins = 16, max = 25, level = 8 },
	{ id = "Meat", coins = 20, max = 25, level = 5 },
	{ id = "IronOre", coins = 15, max = 25, level = 6 },
	{ id = "Cotton", coins = 30, max = 20, level = 10 },
	{ id = "Wool", coins = 22, max = 20, level = 13 },
	{ id = "Corn", coins = 30, max = 20, level = 15 }, -- 2026-10-02 (ราคาเท่าฝ้าย)
	{ id = "Sugarcane", coins = 30, max = 20, level = 20 }, -- อ้อยปลด Lv20 (2026-10-02 · เดิม 17)
	{ id = "SilverOre", coins = 50, max = 12, level = 15 },
	{ id = "Leather", coins = 30, max = 15, level = 17 },
	{ id = "Crystal", coins = 30, max = 10, level = 22 },
	{ id = "MagicBranch", coins = 60, max = 8, level = 5 }, -- ต้นเวทปลด Lv5 (2026-10-02 · เดิม 28)
	{ id = "GoldOre", coins = 90, max = 6, level = 30 },
	{ id = "MagicOre", coins = 120, max = 4, level = 40 },
	{ id = "Diamond", coins = 200, max = 3, level = 45 },

	-- เตาอบขนมปัง
	{ id = "Flour", coins = 60, max = 15, level = 3 },
	{ id = "Dough", coins = 180, max = 6, level = 3 },
	{ id = "SpecialBread", coins = 560, max = 3, level = 8, final = true },
	{ id = "MeatPie", coins = 680, max = 2, level = 9, final = true },
	{ id = "CreamCake", coins = 980, max = 2, level = 15, final = true },
	-- ชุดเนย-น้ำตาล (2026-10-02) · ราคาไล่จากวัตถุดิบ ×1.4 แบบของเตาอบชุดเดิม
	{ id = "Butter", coins = 70, max = 10, level = 15 },
	{ id = "Popcorn", coins = 110, max = 6, level = 16, final = true },
	{ id = "Sugar", coins = 60, max = 12, level = 20 }, -- ตามอ้อย (เดิม 18)
	{ id = "Caramel", coins = 290, max = 4, level = 22 },
	{ id = "GrilledButterCorn", coins = 290, max = 3, level = 23, final = true },
	{ id = "BakedButterCorn", coins = 760, max = 2, level = 25, final = true },

	-- โต๊ะช่างเหล็ก
	{ id = "IronIngot", coins = 70, max = 12, level = 6 },
	{ id = "Nails", coins = 18, max = 40, level = 7 },
	{ id = "Hinge", coins = 230, max = 4, level = 18 },
	{ id = "SilverIngot", coins = 210, max = 5, level = 16 },
	{ id = "MechGear", coins = 180, max = 6, level = 19 },
	{ id = "Padlock", coins = 600, max = 2, level = 24, final = true },
	{ id = "GoldIngot", coins = 365, max = 3, level = 33 },
	{ id = "PocketWatch", coins = 1400, max = 1, level = 37, final = true },
	{ id = "MagicCompass", coins = 1600, max = 1, level = 42, final = true },

	-- กี่ทอผ้า
	{ id = "Thread", coins = 60, max = 15, level = 10 },
	{ id = "Cloth", coins = 310, max = 4, level = 11 },
	{ id = "Yarn", coins = 45, max = 20, level = 13 },
	{ id = "WoolCloth", coins = 235, max = 4, level = 14 },
	{ id = "FineFabric", coins = 1400, max = 1, level = 29, final = true },
}

ExportConfig.ById = {}
for _, good in ipairs(ExportConfig.Goods) do ExportConfig.ById[good.id] = good end

function ExportConfig.Get(id)
	return ExportConfig.ById[id]
end

return ExportConfig
