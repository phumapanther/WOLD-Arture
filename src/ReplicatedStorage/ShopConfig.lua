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
ShopConfig.Sells = {
	{ id = "Shovel", price = 1200 },
	{ id = "Pickaxe", price = 1500 },
	{ id = "Axe", price = 1400 },
	{ id = "Bread", price = 120 },
	{ id = "Water", price = 80 },
	-- Fishing. The rod is a one-off purchase; worms are the running cost, and one is spent per catch, so a
	-- stack is how long a session at the water lasts.
	{ id = "FishingRod", price = 900 },
	{ id = "Worm", price = 20 },
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
ShopConfig.IslandSells = {
	-- บ้าน: ของชิ้นใหญ่ที่เก็บเงินทั้งเกมมาซื้อ
	{ id = "House_StoneCottage", category = "house", level = 4, coins = 20000 },
	{ id = "House_Roundhouse", category = "house", level = 7, coins = 25000 },
	{ id = "House_Longhouse", category = "house", level = 9, coins = 30000 },
	{ id = "House_PipeWorker", category = "house", level = 10, coins = 40000 },
	{ id = "House_Townhouse", category = "house", level = 11, coins = 50000 },

	-- ของตกแต่ง
	{ id = "Deco_PathTile", category = "decor", level = 1, gems = 2 },
	{ id = "Deco_Rock", category = "decor", level = 1, gems = 3 },
	{ id = "Deco_Bush", category = "decor", level = 1, gems = 4 },
	{ id = "Deco_Stump", category = "decor", level = 1, gems = 4 },
	{ id = "Deco_Fence", category = "decor", level = 1, gems = 4 },
	{ id = "Deco_FlowerPot", category = "decor", level = 1, gems = 8 },
	{ id = "Deco_Crate", category = "decor", level = 1, gems = 10 },
	{ id = "Deco_Barrel", category = "decor", level = 1, gems = 10 },
	{ id = "Deco_Signpost", category = "decor", level = 2, gems = 12 },
	{ id = "Deco_RockBig", category = "decor", level = 2, gems = 14 },
	{ id = "Deco_Lantern", category = "decor", level = 2, gems = 15 },
	{ id = "Deco_Bench", category = "decor", level = 3, gems = 18 },
	{ id = "Deco_Lamp", category = "decor", level = 3, gems = 22 },
	{ id = "Deco_Tree", category = "decor", level = 5, gems = 30 },
	{ id = "Deco_Well", category = "decor", level = 3, gems = 60 },

	-- ของป่าจากเกมหลัก: วางแล้วเก็บเกี่ยวได้วันละครั้ง (ราคาผมตั้งเอง ผู้ใช้ให้มาแค่กติกา)
	{ id = "Wild_Rock", category = "decor", level = 3, gems = 25 },
	{ id = "Wild_Herb", category = "decor", level = 3, gems = 25 },
	{ id = "Wild_Tree", category = "decor", level = 3, gems = 35 },
	{ id = "Wild_Pine", category = "decor", level = 3, gems = 35 },
	{ id = "Wild_Coal", category = "decor", level = 5, gems = 45 },
	{ id = "Wild_IronOre", category = "decor", level = 5, gems = 60 },
	{ id = "Wild_SilverOre", category = "decor", level = 7, gems = 90 },
	{ id = "Wild_Crystal", category = "decor", level = 8, gems = 110 },
	{ id = "Wild_GoldOre", category = "decor", level = 9, gems = 130 },
	{ id = "Wild_MagicOre", category = "decor", level = 10, gems = 180 },
	{ id = "Wild_DiamondOre", category = "decor", level = 11, gems = 250 },

	-- ของใช้: เฟอร์นิเจอร์ในบ้าน (ใช้งานได้จริง)
	{ id = "IceBox", category = "utility", level = 6, gems = 120 },
	{ id = "ApothecaryCabinet", category = "utility", level = 6, gems = 120 },
	{ id = "Stove", category = "utility", level = 7, gems = 180 },
	{ id = "SteamBlender", category = "utility", level = 8, gems = 220 },
	{ id = "AlchemyStill", category = "utility", level = 8, gems = 220 },
	-- ของผิดกฎหมาย: แพงที่สุดเพราะมันพิมพ์เงินได้
	{ id = "Boxs", category = "utility", level = 9, gems = 400 },
	{ id = "DistillSet", category = "utility", level = 10, gems = 500 },
	{ id = "Reactor", category = "utility", level = 10, gems = 500 },
	-- เครื่องคราฟขั้นสูง (เฟส 2c) — ของที่ทำได้ส่งออกกับรถส่งออกเท่านั้น
	{ id = "BakeryOven", category = "utility", level = 3, gems = 120 },
	{ id = "MetalBench", category = "utility", level = 5, gems = 180 },
	{ id = "Loom", category = "utility", level = 6, gems = 220 },

	-- สัตว์: สัตว์เลี้ยง (บัพให้ทั้งฟาร์มขณะอยู่บนเกาะ) + คอก · สัตว์ในคอกซื้อในหน้าต่างคอก (IslandConfig.PenAnimals)
	{ id = "Pet_Cat", category = "animal", level = 4, gems = 250 },
	{ id = "Pet_Dog", category = "animal", level = 4, gems = 250 },
	{ id = "AnimalPen", category = "animal", level = 2, coins = 15000 }, -- ผู้ใช้กำหนด 2026-09-25 (เดิม 35,000)

	-- เพาะปลูก
	-- แปลงผัก: แจกฟรี 9 แปลงตอนเข้าเกาะครั้งแรก · ซื้อเพิ่มสองราคากำหนดเอง (40 x 250 = 10,000 พอดี ·
	-- เหรียญผู้ใช้กำหนด 2026-09-25 เดิม 25,000)
	{ id = "FarmPlot", category = "farm", level = 1, gems = 40, coins = 10000 },
	-- เมล็ด **250 เหรียญต่อ 3 เม็ด** (ผู้ใช้สั่ง 2026-09-24) · `count` คือจำนวนต่อหนึ่งครั้งที่กด ช่องจำนวนคูณขึ้นตามปกติ
	-- เก็บผักแล้วมีโอกาสได้เมล็ดคืน
	{ id = "Seed", category = "farm", level = 1, coins = 250, count = 3 },
	-- เมล็ดฝ้าย (เฟส 2c ผู้ใช้เลือก 2026-09-27): แยกจากเมล็ดสุ่ม หยอดแล้วได้ฝ้ายแน่นอน · ราคาเท่าเมล็ดสุ่ม
	{ id = "CottonSeed", category = "farm", level = 6, coins = 250, count = 3 },
	{ id = "MineZone", category = "farm", level = 5, coins = 30000 }, -- ผู้ใช้กำหนด 2026-09-25 (เดิม 50,000)
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

return ShopConfig
