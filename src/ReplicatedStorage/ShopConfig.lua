-- ShopConfig: what the shopkeeper sells, and what they will buy.
--
-- Only the tools and the two basics for now, as the user asked. Weapons, armor and potions are deliberately
-- absent: those are meant to come from the crafter, and a shop that sold them would leave the crafter with
-- nothing to do the day it exists.
local ShopConfig = {}

-- What the shopkeeper hands over, at a fixed price. Stock is unlimited -- a shop that ran out would just
-- be a wall between a player and the game while nobody is around to restock it.
--
-- **ทุกราคา ×10 จากเดิม ยกเว้นจักรยาน** (ผู้ใช้กำหนด 2026-09-19 — พลั่ว 120→1,200 อีเต้อ 150→1,500
-- ขวาน 140→1,400 ขนมปัง 12→120 น้ำ 8→80 คันเบ็ด 90→900 หนอน 2→20) เงินที่หาได้จากการขายของยังเท่าเดิม
-- ตั้งใจให้ของในร้านเป็นเป้าที่ต้องเก็บเงิน ไม่ใช่ของที่ซื้อได้จากกำไรรอบเดียว
-- **2026-09-28 ผู้ใช้ปรับ**: พลั่ว/ขวาน 900 · อีเต้อ 1,200 · คันเบ็ด 1,500 · เพิ่มค้อนซ่อม 3,000
-- อุปกรณ์ + เหยื่อ + ค้อนซ่อมขายบนเกาะด้วย ราคาเหรียญอ่านจากตารางนี้ (`mainPrice` ในร้านเกาะ) แก้ที่นี่ที่เดียว
ShopConfig.Sells = {
	{ id = "Shovel", price = 900 },
	{ id = "Pickaxe", price = 1200 },
	{ id = "Axe", price = 900 },
	{ id = "Bread", price = 120 },
	{ id = "Water", price = 80 },
	-- Fishing. The rod is a one-off purchase; worms are the running cost, and one is spent per catch, so a
	-- stack is how long a session at the water lasts.
	{ id = "FishingRod", price = 1500 },
	{ id = "Worm", price = 20 },
	{ id = "RepairHammer", price = 3000 },
	-- จักรยาน ราคาที่ผู้ใช้กำหนด — **คันเดียวในร้านที่ไม่ถูก ×10** (ผู้ใช้สั่งเว้นไว้ 2026-09-19)
	--
	-- ยังแพงที่สุดในร้านอยู่ (ถัดมาคืออีเต้อ 1,500) แต่ไม่ได้อยู่คนละชั้นเหมือนเดิมแล้ว: ทุกคนได้ฟรีหนึ่งคัน
	-- ตั้งแต่เริ่มเกมอยู่แล้ว ราคานี้จึงเป็นค่าปรับของการทำหาย ไม่ใช่ราคาที่ต้องจ่ายเพื่อเริ่มมี — และต้องแพงพอ
	-- ที่การซื้อเก็บไว้หลายคันจะไม่คุ้มกว่าการเรียกคันเดิมออกมาใช้
	{ id = "Monowheel", price = 5000 },
}

-- ร้านบนเกาะฟาร์ม — Shop.server เลือกตารางนี้เมื่อ ServerConfig.Mode == "Farming" (สต็อกเกมหลักไม่เปลี่ยน)
--
-- **ทุกชิ้นซื้อได้สองสกุล** (เฟส 2a ผู้ใช้กำหนด 2026-09-26): 1 เพชร = 250 เหรียญ · เพชรปัดขึ้น ขั้นต่ำ 1
-- แถวเขียนราคาสกุลที่ตั้งมาแต่เดิม (`coins` หรือ `gems`) อีกสกุลคำนวณที่ ShopConfig.PricesOf ที่เดียว ·
-- เขียนทั้งสองได้ถ้าอยากกำหนดเอง (แปลงผัก) · `category` = แท็บในหน้าร้าน (ShopConfig.IslandCategories)
-- **ของทั้งร้านส่งเมลไม่ได้ รวมเมล็ด** (ผู้ใช้เลือก 2026-09-27 · กฎของที่ซื้อด้วยเพชรใน ItemCatalog.IsMailable)
-- เรียงตามแท็บ · ลำดับแถวไม่ได้เซฟที่ไหน (index ที่ไคลเอนต์ส่งกลับมาอ่านจากตารางเดียวกันตอนรัน) จึงสลับได้
-- **`level` = เลเวลฟาร์มที่ปลดให้ซื้อ** (เฟส 2c ผู้ใช้อนุมัติ 2026-09-27) · ของที่ซื้อไปแล้วใช้ต่อได้เสมอ ล็อกแค่การซื้อใหม่
-- ทุกแถวต้องมี (เทส farm_level_test ตรวจ) · ตารางปลดทั้งหมดดู FarmLevelConfig.UnlocksAt
local function mainPrice(id)
	for _, row in ipairs(ShopConfig.Sells) do
		if row.id == id then return row.price end
	end
	error("ShopConfig: " .. id .. " ไม่มีในร้านเกมหลัก")
end

ShopConfig.IslandSells = {
	-- บ้าน: ของชิ้นใหญ่ที่เก็บเงินทั้งเกมมาซื้อ
	{ id = "House_StoneCottage", category = "house", level = 4, coins = 20000 },
	{ id = "House_Roundhouse", category = "house", level = 12, coins = 25000 },
	{ id = "House_Longhouse", category = "house", level = 20, coins = 30000 },
	{ id = "House_PipeWorker", category = "house", level = 26, coins = 40000 },
	{ id = "House_Townhouse", category = "house", level = 36, coins = 50000 },

	-- ของตกแต่ง
	{ id = "Deco_PathTile", category = "decor", level = 1, gems = 2 },
	{ id = "Deco_Rock", category = "decor", level = 1, gems = 3 },
	{ id = "Deco_Bush", category = "decor", level = 3, gems = 4 },
	{ id = "Deco_Stump", category = "decor", level = 3, gems = 4 },
	{ id = "Deco_Fence", category = "decor", level = 1, gems = 4 },
	{ id = "Deco_FlowerPot", category = "decor", level = 4, gems = 8 },
	{ id = "Deco_Crate", category = "decor", level = 5, gems = 10 },
	{ id = "Deco_Barrel", category = "decor", level = 5, gems = 10 },
	{ id = "Deco_Signpost", category = "decor", level = 7, gems = 12 },
	{ id = "Deco_RockBig", category = "decor", level = 9, gems = 14 },
	{ id = "Deco_Lantern", category = "decor", level = 7, gems = 15 },
	{ id = "Deco_Bench", category = "decor", level = 9, gems = 18 },
	{ id = "Deco_Lamp", category = "decor", level = 18, gems = 22 },
	{ id = "Deco_Tree", category = "decor", level = 19, gems = 30 },
	{ id = "Deco_Well", category = "decor", level = 28, gems = 60 }, -- 25 → 28 (2026-10-02 · ต้นเวทย้ายไป Lv5 ทิ้ง Lv28 ว่าง · กติกา 1-6 อย่างต่อเลเวล)

	-- ของป่าจากเกมหลัก: วางแล้วเก็บเกี่ยวได้วันละครั้ง (ราคาผมตั้งเอง ผู้ใช้ให้มาแค่กติกา)
	{ id = "Wild_Rock", category = "decor", level = 11, gems = 25 },
	{ id = "Wild_Herb", category = "decor", level = 12, gems = 25 },
	{ id = "Wild_Tree", category = "decor", level = 12, gems = 35 },
	{ id = "Wild_Pine", category = "decor", level = 14, gems = 35 },
	{ id = "Wild_Coal", category = "decor", level = 6, gems = 45 },
	{ id = "Wild_IronOre", category = "decor", level = 13, gems = 60 },
	{ id = "Wild_SilverOre", category = "decor", level = 15, gems = 90 },
	{ id = "Wild_Crystal", category = "decor", level = 22, gems = 110 },
	{ id = "Wild_GoldOre", category = "decor", level = 30, gems = 130 },
	{ id = "Wild_MagicOre", category = "decor", level = 40, gems = 180 },
	{ id = "Wild_DiamondOre", category = "decor", level = 45, gems = 250 },

	-- ของใช้: อุปกรณ์ เหยื่อ ค้อนซ่อม — ราคาเดียวกับร้านเกมหลัก (ผู้ใช้สั่ง 2026-09-28) · ส่งเมลไม่ได้เหมือนทั้งร้าน
	-- (ผู้ใช้เลือก: ขวาน/หนอน/คันเบ็ด ที่ซื้อในเมืองก็ส่งเมลไม่ได้ตามไปด้วย เพราะด่านถามจาก id)
	{ id = "Axe", category = "utility", level = 1, coins = mainPrice("Axe") },
	{ id = "Pickaxe", category = "utility", level = 1, coins = mainPrice("Pickaxe") },
	{ id = "Shovel", category = "utility", level = 1, coins = mainPrice("Shovel") },
	{ id = "FishingRod", category = "utility", level = 1, coins = mainPrice("FishingRod") },
	{ id = "Worm", category = "utility", level = 1, coins = mainPrice("Worm") },
	{ id = "RepairHammer", category = "utility", level = 1, coins = mainPrice("RepairHammer") },

	-- ของใช้: เฟอร์นิเจอร์ในบ้าน (ใช้งานได้จริง)
	{ id = "IceBox", category = "utility", level = 14, gems = 120 },
	{ id = "ApothecaryCabinet", category = "utility", level = 18, gems = 120 },
	{ id = "Stove", category = "utility", level = 23, gems = 180 },
	{ id = "SteamBlender", category = "utility", level = 27, gems = 220 },
	{ id = "AlchemyStill", category = "utility", level = 35, gems = 220 },
	-- ของผิดกฎหมาย: แพงที่สุดเพราะมันพิมพ์เงินได้
	{ id = "Boxs", category = "utility", level = 38, gems = 400 },
	{ id = "DistillSet", category = "utility", level = 43, gems = 500 },
	{ id = "Reactor", category = "utility", level = 48, gems = 500 },
	-- เครื่องคราฟขั้นสูง (เฟส 2c) — ของที่ทำได้ส่งออกกับรถส่งออกเท่านั้น
	-- ราคาเหรียญไล่ 10k/15k/20k (ผู้ใช้สั่ง 2026-10-02 · เดิมเพชร 120/180/220) · เพชรคำนวณให้ 40/60/80
	{ id = "BakeryOven", category = "utility", level = 3, coins = 10000 },
	{ id = "MetalBench", category = "utility", level = 6, coins = 15000 },
	{ id = "Loom", category = "utility", level = 10, coins = 20000 },
	-- หุ่นฟางฝึกซ้อม (2026-10-02) ตีได้ EXP ตัวละคร เพดานรวมทุกหุ่น 1,000/วัน
	{ id = "TrainingDummy", category = "utility", level = 19, coins = 15000 },

	-- สัตว์: สัตว์เลี้ยง (บัพให้ทั้งฟาร์มขณะอยู่บนเกาะ) + คอก · สัตว์ในคอกซื้อในหน้าต่างคอก (IslandConfig.PenAnimals)
	{ id = "Pet_Cat", category = "animal", level = 4, gems = 250 },
	{ id = "Pet_Dog", category = "animal", level = 4, gems = 250 },
	-- สัตว์เลี้ยงเฟส 2d (ผู้ใช้อนุมัติราคา + ตาราง 50 เลเวล 2026-09-27) · ตัวที่ให้วัตถุดิบเดียวกันปลดเลเวลเดียวกัน
	-- (และเลเวลเดียวกับสัตว์ชนิดนั้นในคอก) · จำนวนที่มีได้ = `FarmLevelConfig.PetCap` · ข้อมูลตัวสัตว์อยู่ `IslandConfig.PetSpecies`
	{ id = "Pet_Chicken", category = "animal", level = 2, coins = 5000 },
	{ id = "Pet_Duck", category = "animal", level = 2, coins = 6000 },
	{ id = "Pet_Pig", category = "animal", level = 5, coins = 10000 },
	{ id = "Pet_Boar", category = "animal", level = 5, gems = 220 },
	{ id = "Pet_GreenSlime", category = "animal", level = 7, gems = 100 },
	{ id = "Pet_Goat", category = "animal", level = 8, coins = 12000 },
	{ id = "Pet_Cow", category = "animal", level = 8, coins = 20000 },
	{ id = "Pet_Bat", category = "animal", level = 11, gems = 150 },
	{ id = "Pet_Sheep", category = "animal", level = 13, coins = 15000 },
	{ id = "Pet_Spider", category = "animal", level = 15, gems = 260 },
	{ id = "Pet_Deer", category = "animal", level = 17, coins = 25000 },
	{ id = "Pet_Horse", category = "animal", level = 17, coins = 30000 },
	{ id = "Pet_Wolf", category = "animal", level = 19, gems = 260 },
	{ id = "Pet_SteamSlime", category = "animal", level = 21, gems = 180 },
	{ id = "Pet_PlasmaSlime", category = "animal", level = 21, gems = 300 },
	{ id = "Pet_BioSlime", category = "animal", level = 21, gems = 320 },
	{ id = "Pet_Skeleton", category = "animal", level = 25, gems = 350 },
	{ id = "Pet_Bandit", category = "animal", level = 30, gems = 400 },
	{ id = "Pet_Ghoul", category = "animal", level = 34, gems = 450 },
	{ id = "Pet_ClockworkSentry", category = "animal", level = 39, gems = 450 },
	{ id = "Pet_Wraith", category = "animal", level = 44, gems = 500 },
	{ id = "Pet_StoneGolem", category = "animal", level = 50, gems = 600 },
	-- 7,500 (ผู้ใช้สั่ง 2026-10-02 · เดิม 15,000 · 35,000) · จำนวนคอกที่มีได้ = FarmLevelConfig.PenCap (ชนิดสัตว์ที่ปลดแล้ว)
	{ id = "AnimalPen", category = "animal", level = 2, coins = 7500 },

	-- เพาะปลูก
	-- แปลงผัก: แจกฟรี 9 แปลงตอนเข้าเกาะครั้งแรก · ซื้อเพิ่มสองราคากำหนดเอง (40 x 250 = 10,000 พอดี ·
	-- เหรียญผู้ใช้กำหนด 2026-09-25 เดิม 25,000)
	{ id = "FarmPlot", category = "farm", level = 1, coins = 5000 }, -- ผู้ใช้สั่ง 2026-10-02 (เดิม 10,000 / 40 เพชร) · เพชรคำนวณให้ 20
	-- เมล็ด **250 เหรียญต่อ 3 เม็ด** (ผู้ใช้สั่ง 2026-09-24) · `count` คือจำนวนต่อหนึ่งครั้งที่กด ช่องจำนวนคูณขึ้นตามปกติ
	-- เก็บผักแล้วมีโอกาสได้เมล็ดคืน
	{ id = "Seed", category = "farm", level = 1, coins = 250, count = 3 },
	-- เมล็ดฝ้าย (เฟส 2c ผู้ใช้เลือก 2026-09-27): แยกจากเมล็ดสุ่ม หยอดแล้วได้ฝ้ายแน่นอน · ราคาเท่าเมล็ดสุ่ม
	{ id = "CottonSeed", category = "farm", level = 10, coins = 250, count = 3 },
	{ id = "CornSeed", category = "farm", level = 15, coins = 250, count = 3 }, -- 2026-10-02
	{ id = "SugarcaneSeed", category = "farm", level = 20, coins = 250, count = 3 }, -- 2026-10-02 · Lv17 → 20 (ผู้ใช้สั่ง)
	{ id = "MineZone", category = "farm", level = 6, coins = 30000 }, -- ผู้ใช้กำหนด 2026-09-25 (เดิม 50,000)
}

-- เฟส 2a (ผู้ใช้กำหนด 2026-09-26): ทุกชิ้นในร้านเกาะสองราคา · 1 เพชร = 250 เหรียญ · เพชรปัดขึ้น ขั้นต่ำ 1
-- แถวเขียนราคาสกุลเดียวก็พอ อีกสกุลคำนวณที่นี่ที่เดียว (สัตว์ในคอกก็ใช้ GemsFor ตัวเดียวกัน)
ShopConfig.GemRate = 250

-- ราคาขายของขอบทอง (เฟส 2b ผู้ใช้กำหนด 2026-09-26): บนเกาะเท่านั้น 3 เท่าของราคาตลาดตอนนั้น · ขายทีละชิ้น
-- nil = ร้านนี้ไม่รับ (ร้านเกมหลัก + พ่อค้าประจำเมือง)
ShopConfig.GoldSellMultiplier = 3
function ShopConfig.GoldSellPrice(base, onIsland)
	if not onIsland then return nil end
	return math.max(1, math.floor(base * ShopConfig.GoldSellMultiplier + 0.5))
end
ShopConfig.IslandCategories = {
	{ id = "house", label = "บ้าน" },
	{ id = "decor", label = "ของตกแต่ง" },
	{ id = "utility", label = "ของใช้" },
	{ id = "animal", label = "สัตว์" },
	{ id = "farm", label = "เพาะปลูก" },
}

function ShopConfig.GemsFor(coins)
	return math.max(1, math.ceil(coins / ShopConfig.GemRate))
end

-- ราคาสองสกุลของแถวร้าน · แถวร้านเกมหลัก (`price`) = เหรียญอย่างเดียว เพชรเป็น nil
function ShopConfig.PricesOf(row)
	if row.price then return row.price, nil end
	local coins = row.coins or (row.gems and row.gems * ShopConfig.GemRate)
	local gems = row.gems or (row.coins and ShopConfig.GemsFor(row.coins))
	return coins, gems
end

-- ราคาในสกุลที่ขอ · nil = แถวนี้ขายสกุลนั้นไม่ได้ · "gems" = เพชร อย่างอื่น/ไม่ระบุ = เหรียญ
function ShopConfig.PriceFor(row, currency)
	local coins, gems = ShopConfig.PricesOf(row)
	if currency == "gems" then return gems end
	return coins
end

-- What the shopkeeper buys, and for how much of the catalog `value`. Well under 1 on purpose: the gap
-- between what a thing sells for and what it costs to buy back is the only thing stopping "buy low from
-- the shop, sell high to the shop" being infinite money.
ShopConfig.BuyFraction = 0.6

-- Anything of these kinds can be sold. Named by kind rather than listed by id so a material added later is
-- sellable the day it exists.
ShopConfig.Buys = { junk = true }

-- Prices drift so the same material is not worth the same forever. Rerolled on a timer shared by the whole
-- server, not per player, so everyone standing at the counter sees one price.
-- How far a price may drift from the catalog value, either way. Half, so a material can be worth anything
-- from 50% to 150% of its usual price depending on when you walk in -- which is what makes checking the
-- board before selling worth doing.
ShopConfig.PriceSwing = 0.50

-- Coins paid per kilogram on a fish that carries a recorded weight.
--
-- Only trophies carry one, so this never touches a common catch. Added on top of the base rather than
-- multiplying it, which keeps the species the bigger part of the price: a 42 kg legendary common fish is
-- worth about 130 against its usual 5, and still well under a shark's 190 -- so a lucky monster of a minnow
-- is a good day, not a reason to stop fishing for anything rarer.
ShopConfig.GoldPerKg = 3
ShopConfig.RerollSeconds = 1800 -- half an hour, as asked

-- ราคารับซื้อ (ผู้ใช้กำหนด 2026-09-29 · แทนชุด 2026-09-28): **ต่ำสุด 5** · ของถูก (ช่วง ±50% ไม่ถึง 25) = lo-25
-- **ขยับรอบละ 3-5** · 20 ขึ้นไปราว 25% ของเวลา 25 พอดีราว 3% (ได้เองจากการเดินสุ่ม — ขอบมีทางเข้าน้อย · เทสวัด) ·
-- ของดรอปมอน 1-15 ขยับ 3-5 · ของแพงสุ่ม ±50% ขยับ ≥ 5 ไม่มีเพดานเท่าเดิม · ก้อนหิน/เศษไม้ 1-5 (ScrapSellPrice) ·
-- พ่อค้าประจำเมืองต่ำสุด 5
ShopConfig.MinSellPrice = 5
ShopConfig.MinSellTop = 25 -- เพดานของของถูก
ShopConfig.MinPriceMove = 5 -- ของแพง: ขยับอย่างน้อยเท่านี้ ไม่มีเพดาน
ShopConfig.CheapPriceMove = { 3, 5 } -- ของถูก + ของมอน: ขยับรอบละ 3-5
ShopConfig.MonsterSellRange = { 1, 15 }
-- ของดรอปจากมอนล้วน (ผู้ใช้เลือก) · เนื้อ/คริสตัล/แร่/สมุนไพรที่มอนดรอปด้วยไม่นับ (ได้จากทางอื่นเป็นหลัก)
ShopConfig.MonsterMaterials = { Slime = true, Bone = true, Fiber = true, BatGuano = true, Claw = true }
ShopConfig.PriceFloorExempt = { Stone = true, WoodScrap = true }
ShopConfig.ScrapOneChance = 0.7 -- ก้อนหิน/เศษไม้: 1 = 70% · 2-5 เท่ากันในอีก 30%
ShopConfig.ScrapTop = 5
-- ย้อนประวัติกี่รอบตอนคำนวณราคา (หนึ่งสัปดาห์) — รอบนี้ขึ้นกับรอบก่อน ทุกเซิร์ฟย้อนจากจุดเดียวกันจึงได้ราคาเดียวกัน
-- และราคา "เดิม" ที่หน้าราคากลางโชว์ตรงกับที่เคยโชว์จริง (ประวัติลืมจุดเริ่มเองในไม่กี่รอบ · เทส sell_price_test)
ShopConfig.PriceHistorySlots = 336

-- ช่วงราคารับซื้อเป็นจำนวนเต็ม คืน lo, hi, ขยับต่ำสุด, ขยับสูงสุด (nil = ไม่มีเพดาน)
-- · nil = ไม่ใช้ช่วง (ก้อนหิน/เศษไม้ → ScrapSellPrice · ไม่มีมูลค่า → สูตรเดิม)
function ShopConfig.SellRange(id, value)
	if ShopConfig.PriceFloorExempt[id] then return nil end
	local cheap = ShopConfig.CheapPriceMove
	if ShopConfig.MonsterMaterials[id] then
		local r = ShopConfig.MonsterSellRange
		return r[1], r[2], cheap[1], cheap[2]
	end
	if not value or value <= 0 then return nil end
	local centre = value * ShopConfig.BuyFraction
	local lo = math.max(ShopConfig.MinSellPrice, math.floor(centre * (1 - ShopConfig.PriceSwing) + 0.5))
	local hi = math.floor(centre * (1 + ShopConfig.PriceSwing) + 0.5)
	if hi < ShopConfig.MinSellTop then return lo, ShopConfig.MinSellTop, cheap[1], cheap[2] end
	return lo, hi, ShopConfig.MinPriceMove, nil
end

-- ราคารอบนี้จากเลขสุ่มสองตัว (0..1) กับราคารอบก่อน · สุ่มทั้งช่วงก่อน ห่างรอบก่อนตามกติกา (moveMin-moveMax) = ใช้เลย
-- โดยไม่ดูรอบก่อน ประวัติจึงลืมจุดเริ่มเอง · ไม่ผ่าน = สุ่มใหม่จากค่าที่ผ่าน (u2) · ผลรวมสองทาง = สุ่มเท่ากันในค่าที่ผ่าน
function ShopConfig.NextSellPrice(u, u2, prev, lo, hi, moveMin, moveMax)
	local price = lo + math.min(hi - lo, math.floor(u * (hi - lo + 1)))
	if prev == nil then return price end
	moveMin = moveMin or ShopConfig.MinPriceMove
	moveMax = moveMax or (hi - lo)
	local d = math.abs(price - prev)
	if d >= moveMin and d <= moveMax then return price end
	local belowLo, belowHi = math.max(lo, prev - moveMax), math.min(hi, prev - moveMin)
	local aboveLo, aboveHi = math.max(lo, prev + moveMin), math.min(hi, prev + moveMax)
	local nBelow = math.max(0, belowHi - belowLo + 1)
	local nAbove = math.max(0, aboveHi - aboveLo + 1)
	local n = nBelow + nAbove
	if n == 0 then return price end -- ช่วงแคบเกิน (ไม่เกิดกับ SellRange)
	local pick = math.min(n - 1, math.floor(u2 * n))
	if pick < nBelow then return belowLo + pick end
	return aboveLo + (pick - nBelow)
end

-- ก้อนหิน/เศษไม้: สุ่มใหม่ทุกรอบจากเลขสุ่มตัวเดียว ไม่ขึ้นกับรอบก่อน
function ShopConfig.ScrapSellPrice(u)
	local one = ShopConfig.ScrapOneChance
	if u < one then return 1 end
	local span = ShopConfig.ScrapTop - 1
	return 2 + math.min(span - 1, math.floor((u - one) / (1 - one) * span))
end

-- รายการขายของในหน้าร้าน (ผู้ใช้สั่ง 2026-09-28): **ยอดรวมทั้งกองมากสุดก่อน** · เท่ากัน = ต่อชิ้นแพงก่อน · แล้วเลขช่อง
-- แถว = { slot, each, total } · เรียงในที่ (ใช้ทั้งร้านเกมหลักและร้านเกาะ)
function ShopConfig.SortSellRows(rows)
	table.sort(rows, function(a, b)
		if a.total ~= b.total then return a.total > b.total end
		if a.each ~= b.each then return a.each > b.each end
		return a.slot < b.slot
	end)
	return rows
end

-- ราคาคงที่ (พ่อค้าประจำเมือง) หลังยกพื้น MinSellPrice (5) · ของยกเว้นไม่ยก
function ShopConfig.FloorSellPrice(id, price)
	if ShopConfig.PriceFloorExempt[id] then return price end
	return math.max(ShopConfig.MinSellPrice, price)
end

return ShopConfig
