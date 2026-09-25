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
-- ราคาทั้งหมด Claude ตั้งไว้ก่อน ผู้ใช้ยังไม่ได้กำหนด (2026-09-22)
-- **สองสกุลเงิน** (ผู้ใช้กำหนด 2026-09-22)
--
--   `currency = "gems"`  เพชร — ของตกแต่ง สัตว์เลี้ยง ของผิดกฎหมาย และแปลงผักส่วนที่ซื้อเพิ่ม
--   ไม่ใส่ (ดีฟอลต์)     เหรียญของเกมหลัก — เมล็ด บ้าน
--
-- แปลงผักมี **สองแถว** คือสิ่งเดียวที่ซื้อได้ทั้งสองสกุล: จ่ายเพชรถูก หรือจ่ายเหรียญแพงมาก
-- (ผู้ใช้สั่ง "ซื้อเพิ่มใช้เพชร และใช้เงินเกมหลักได้ แต่แพงมาก") — 9 แปลงแรกยังแจกฟรีในชุดเริ่มต้น
ShopConfig.IslandSells = {
	-- ราคาเมล็ดขึ้นเป็นหลักร้อย (ผู้ใช้สั่ง 2026-09-23) · เก็บผักแล้วมีโอกาสได้เมล็ดคืน 1-3 เมล็ด
	-- **250 เหรียญต่อ 3 เม็ด** (ผู้ใช้สั่ง 2026-09-24) เดิม 300 ต่อเม็ด — ต่อเม็ดจึงตกจาก
	-- 300 เหลือ 83 · `count` คือจำนวนต่อหนึ่งครั้งที่กด ช่องจำนวนก็คูณขึ้นตามปกติ
	{ id = "Seed", price = 250, count = 3 },

	-- แปลงผัก: แจกฟรี 9 แปลงตอนเข้าเกาะครั้งแรก · ซื้อเพิ่มได้สองทาง
	{ id = "FarmPlot", price = 40, currency = "gems" },
	{ id = "FarmPlot", price = 10000 }, -- ผู้ใช้กำหนด 2026-09-25 (เดิม 25,000)

	-- บ้าน: เหรียญเกมหลัก (ของชิ้นใหญ่ที่เก็บเงินทั้งเกมมาซื้อ)
	{ id = "House_StoneCottage", price = 20000 },
	{ id = "House_Roundhouse", price = 25000 },
	{ id = "House_Longhouse", price = 30000 },
	{ id = "House_PipeWorker", price = 40000 },
	{ id = "House_Townhouse", price = 50000 },

	-- ของตกแต่ง: เพชรทั้งหมด
	{ id = "Deco_PathTile", price = 2, currency = "gems" },
	{ id = "Deco_Rock", price = 3, currency = "gems" },
	{ id = "Deco_Bush", price = 4, currency = "gems" },
	{ id = "Deco_Stump", price = 4, currency = "gems" },
	{ id = "Deco_Fence", price = 4, currency = "gems" },
	{ id = "Deco_FlowerPot", price = 8, currency = "gems" },
	{ id = "Deco_Crate", price = 10, currency = "gems" },
	{ id = "Deco_Barrel", price = 10, currency = "gems" },
	{ id = "Deco_Signpost", price = 12, currency = "gems" },
	{ id = "Deco_RockBig", price = 14, currency = "gems" },
	{ id = "Deco_Lantern", price = 15, currency = "gems" },
	{ id = "Deco_Bench", price = 18, currency = "gems" },
	{ id = "Deco_Lamp", price = 22, currency = "gems" },
	{ id = "Deco_Tree", price = 30, currency = "gems" },
	{ id = "Deco_Well", price = 60, currency = "gems" },

	-- ของป่าจากเกมหลัก: วางแล้วเก็บเกี่ยวได้วันละครั้ง (ราคาผมตั้งเอง ผู้ใช้ให้มาแค่กติกา)
	{ id = "Wild_Rock", price = 25, currency = "gems" },
	{ id = "Wild_Herb", price = 25, currency = "gems" },
	{ id = "Wild_Tree", price = 35, currency = "gems" },
	{ id = "Wild_Pine", price = 35, currency = "gems" },
	{ id = "Wild_Coal", price = 45, currency = "gems" },
	{ id = "Wild_IronOre", price = 60, currency = "gems" },
	{ id = "Wild_SilverOre", price = 90, currency = "gems" },
	{ id = "Wild_Crystal", price = 110, currency = "gems" },
	{ id = "Wild_GoldOre", price = 130, currency = "gems" },
	{ id = "Wild_MagicOre", price = 180, currency = "gems" },
	{ id = "Wild_DiamondOre", price = 250, currency = "gems" },

	-- เฟอร์นิเจอร์ในบ้าน (ใช้งานได้จริง): เพชร
	{ id = "IceBox", price = 120, currency = "gems" },
	{ id = "ApothecaryCabinet", price = 120, currency = "gems" },
	{ id = "Stove", price = 180, currency = "gems" },
	{ id = "SteamBlender", price = 220, currency = "gems" },
	{ id = "AlchemyStill", price = 220, currency = "gems" },

	-- สัตว์เลี้ยง (ไม่ใช่สัตว์ฟาร์ม): เพชร · บัพให้ทั้งฟาร์มขณะอยู่บนเกาะ
	{ id = "Pet_Cat", price = 250, currency = "gems" },
	{ id = "Pet_Dog", price = 250, currency = "gems" },

	-- ของผิดกฎหมาย: เพชร แพงที่สุดเพราะมันพิมพ์เงินได้
	{ id = "Boxs", price = 400, currency = "gems" },
	{ id = "DistillSet", price = 500, currency = "gems" },
	{ id = "Reactor", price = 500, currency = "gems" },

	-- คอก/โซนแร่: เหรียญเกมหลัก (เป็นเครื่องมือหาของ ไม่ใช่ของตกแต่ง)
	{ id = "AnimalPen", price = 15000 }, -- ผู้ใช้กำหนด 2026-09-25 (เดิม 35,000)
	{ id = "MineZone", price = 30000 }, -- ผู้ใช้กำหนด 2026-09-25 (เดิม 50,000)
}

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
