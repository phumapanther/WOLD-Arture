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
ShopConfig.IslandSells = {
	{ id = "Seed", price = 50 },
	{ id = "FarmPlot", price = 300 },
	{ id = "Deco_Fence", price = 50 },
	{ id = "Deco_PathTile", price = 30 },
	{ id = "Deco_FlowerPot", price = 150 },
	{ id = "Deco_Crate", price = 200 },
	{ id = "Deco_Barrel", price = 200 },
	{ id = "Deco_Bench", price = 350 },
	{ id = "Deco_Lamp", price = 400 },
	{ id = "Deco_Tree", price = 600 },

	-- ของตกแต่งชิ้นเล็ก (ผู้ใช้สั่ง 2026-09-22) — ถูกกว่าของใหญ่มาก ตั้งใจให้ซื้อทีละหลายชิ้นมาโรย
	{ id = "Deco_Rock", price = 40 },
	{ id = "Deco_Bush", price = 60 },
	{ id = "Deco_Stump", price = 60 },
	{ id = "Deco_Lantern", price = 220 },
	{ id = "Deco_Signpost", price = 180 },
	{ id = "Deco_RockBig", price = 250 },
	{ id = "Deco_Well", price = 1200 },

	-- เฟอร์นิเจอร์ในบ้าน ใช้งานได้จริง — แพงกว่าของตกแต่งเพราะมันคือเครื่องมือ ไม่ใช่ของประดับ
	{ id = "IceBox", price = 4000 },
	{ id = "ApothecaryCabinet", price = 4000 },
	{ id = "Stove", price = 6000 },
	{ id = "SteamBlender", price = 7000 },
	{ id = "AlchemyStill", price = 7000 },

	-- ฟาร์มผิดกฎหมาย — แพงที่สุดในหมวดของใช้ เพราะมันพิมพ์เงินได้ (คูลดาวน์ 30 นาที/จุด)
	{ id = "Boxs", price = 15000 },
	{ id = "DistillSet", price = 18000 },
	{ id = "Reactor", price = 18000 },

	{ id = "AnimalPen", price = 3500 },
	{ id = "MineZone", price = 5000 },
	{ id = "House_StoneCottage", price = 20000 },
	{ id = "House_Roundhouse", price = 25000 },
	{ id = "House_Longhouse", price = 30000 },
	{ id = "House_PipeWorker", price = 40000 },
	{ id = "House_Townhouse", price = 50000 },
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
