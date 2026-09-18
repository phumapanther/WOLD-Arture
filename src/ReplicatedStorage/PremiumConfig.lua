-- PremiumConfig: ร้านค้าพรีเมียม กาชา และแบทเทิลพาส — ทุกราคาเป็น "เพชร"
--
-- **ยังไม่เปิดขายด้วยโรบัค** (ผู้ใช้กำหนด) เพชรเป็นสกุลเงินพรีเมียมในโปรไฟล์ ตอนนี้ได้จากแอดมิน `/gems`
-- วันเปิดขาย: สร้าง Developer Product ใน Roblox แล้วใส่ product id ลง `Products` — PremiumStore.server
-- แลกเป็นเพชรให้ผ่าน ProcessReceipt โดยไม่ต้องแตะร้าน/กาชา/พาสเลย เพราะทั้งสามคิดเป็นเพชรอยู่แล้ว
--
-- ไอเทมทุกชิ้นที่อ้างถึงต้องมีใน ItemCatalog (เครื่องมือทอง อาหารบัพ สกิน ออร่า ชุดแฟชั่น)
local PremiumConfig = {}

PremiumConfig.GemName = "เพชร"
PremiumConfig.GemIcon = "💎"

--------------------------------------------------------------------------------
-- โรบัค → เพชร (ว่างไว้จนกว่าจะเปิดขาย)
--------------------------------------------------------------------------------

-- [developerProductId] = จำนวนเพชร   เช่น [1234567890] = 500
PremiumConfig.Products = {}

-- แพ็กที่โชว์ในหน้าร้าน (ปุ่มกดไม่ได้จนกว่า Products จะมี id ตรงกัน)
PremiumConfig.GemPacks = {
	{ gems = 100, robux = 79, productId = nil },
	{ gems = 550, robux = 399, productId = nil },
	{ gems = 1200, robux = 799, productId = nil },
	{ gems = 3000, robux = 1899, productId = nil },
}

--------------------------------------------------------------------------------
-- ร้านค้า
--------------------------------------------------------------------------------

-- แต่ละแถว: ไอเทมในแคตตาล็อก จำนวน ราคาเพชร คำโปรย
PremiumConfig.Shop = {
	{ id = "gold_axe", item = "GoldAxe", count = 1, price = 800, blurb = "ตัดไม้ได้ตลอดกาล ไม่มีวันพัง" },
	{ id = "gold_pickaxe", item = "GoldPickaxe", count = 1, price = 800, blurb = "ขุดแร่ได้ตลอดกาล ไม่มีวันพัง" },
	{ id = "gold_shovel", item = "GoldShovel", count = 1, price = 600, blurb = "ขุดสมุนไพรได้ตลอดกาล ไม่มีวันพัง" },
	{ id = "gold_rod", item = "GoldFishingRod", count = 1, price = 600, blurb = "ตกปลาได้ตลอดกาล ไม่มีวันพัง" },
	{ id = "feast_hearty", item = "Feast_Hearty", count = 3, price = 120, blurb = "ไม่หิว 30 นาที ×3" },
	{ id = "tonic_vigor", item = "Tonic_Vigor", count = 3, price = 120, blurb = "วิ่งไม่เหนื่อย 30 นาที ×3" },
	{ id = "feast_royal", item = "Feast_Royal", count = 1, price = 150, blurb = "ไม่หิว ไม่เหนื่อย 1 ชั่วโมง" },
}

--------------------------------------------------------------------------------
-- กาชา
--------------------------------------------------------------------------------

-- น้ำหนักตามความหายาก: ยิ่งหายากยิ่งออกยาก สีใช้ตอนโชว์ผล
PremiumConfig.Rarity = {
	common = { weight = 60, name = "ธรรมดา", colour = Color3.fromRGB(180, 180, 190) },
	rare = { weight = 30, name = "หายาก", colour = Color3.fromRGB(90, 160, 255) },
	epic = { weight = 8, name = "มหากาพย์", colour = Color3.fromRGB(190, 90, 255) },
	legendary = { weight = 2, name = "ตำนาน", colour = Color3.fromRGB(255, 200, 60) },
}

-- ตู้กาชา: สุ่มไอเทมจาก pool ตามน้ำหนักของ rarity ของไอเทมนั้น (อ่านจาก ItemCatalog) **ของซ้ำได้ซ้ำไปเลย**
-- (ผู้ใช้กำหนด) เก็บไว้เทรด/ให้เพื่อนได้ 10 ครั้งถูกกว่า 10 ครั้งเดี่ยว
PremiumConfig.Gacha = {
	{
		id = "aura", name = "กาชาออร่า", icon = "✨", cost = 100, cost10 = 900,
		blurb = "เอฟเฟกต์ลอยรอบตัวละคร ใช้จากกระเป๋าเพื่อเปิด/ปิด",
		pool = { "Aura_Ember", "Aura_Frost", "Aura_Void", "Aura_Divine" },
	},
	{
		id = "weapon", name = "กาชาสกินอาวุธ", icon = "⚔️", cost = 100, cost10 = 900,
		blurb = "สกินติดตั้งได้เฉพาะอาวุธชนิดเดียวกัน ถอดออกได้",
		pool = { "Skin_Sword_Ember", "Skin_Sword_Frost", "Skin_Greatsword_Void", "Skin_Greatsword_Gold",
			"Skin_Bow_Vine", "Skin_Pistol_Brass", "Skin_Staff_Storm", "Skin_Spellbook_Blood" },
	},
	{
		id = "armor", name = "กาชาชุดเกราะแฟชั่น", icon = "🛡️", cost = 120, cost10 = 1080,
		blurb = "เปลี่ยนรูปลักษณ์เกราะที่สวม ค่าเกราะเท่าเดิม",
		pool = { "Fashion_Knight_Crimson", "Fashion_Ranger_Shadow", "Fashion_Royal_Gold" },
	},
	{
		id = "vehicle", name = "กาชาพาหนะ", icon = "🚗", cost = 300, cost10 = 2700,
		blurb = "รถแบบใหม่ๆ มาในอนาคต",
		pool = {}, -- ว่าง = ปุ่มสุ่มขึ้น "เร็วๆ นี้"
	},
}

--------------------------------------------------------------------------------
-- แบทเทิลพาส
--------------------------------------------------------------------------------

-- ซีซัน: เปลี่ยนเลขแล้วความคืบหน้าของทุกคนเริ่มใหม่ (ของที่รับไปแล้วไม่หาย)
PremiumConfig.Pass = {
	season = 1,
	name = "ซีซัน 1 — ยุครุ่งอรุณ",
	tiers = 30,
	xpPerTier = 1000,
	-- XP พาส = EXP ที่ได้ในเกม × ตัวคูณนี้ (ส่งเควส ฆ่ามอน เก็บของ ตกปลา ล้วนผ่าน Progression.AwardExp)
	xpPerExp = 1,
	-- ปลดสายพรีเมียมด้วยเพชร
	premiumCost = 950,
}

-- รางวัลรายขั้น { item, count } หรือ { gold = n } หรือ { gems = n } ว่าง = ขั้นนั้นไม่มีของสายนี้
-- ของผิดกฎหมาย (Chemical/GearSpare/Blueprint) ซิลเวอร์ อาหารพิเศษ หีบ เงิน-ทอง เหรียญตราค้อนแตก (Insignia)
-- ตามที่ผู้ใช้กำหนด สายฟรีเน้นซิลเวอร์ สายพรีเมียมเน้นของผิดกฎหมาย/หีบ/เพชรคืน
local function silver(n) return { item = "Silver", count = n } end
local function gold(n) return { gold = n } end
local function gems(n) return { gems = n } end
local function item(id, n) return { item = id, count = n or 1 } end

PremiumConfig.Pass.Free = {
	[1] = silver(100), [2] = gold(1000), [3] = silver(150), [4] = item("Bread", 5), [5] = item("Chest_Wood"),
	[6] = silver(150), [7] = gold(1500), [8] = item("Insignia", 1), [9] = silver(200), [10] = item("Chest_Ironbound"),
	[11] = silver(200), [12] = gold(2000), [13] = item("Feast_Hearty"), [14] = silver(250), [15] = item("Chest_Ironbound"),
	[16] = silver(250), [17] = item("Coal", 20), [18] = gold(2500), [19] = silver(300), [20] = item("Chest_Silver"),
	[21] = silver(300), [22] = item("Insignia", 2), [23] = gold(3000), [24] = silver(350), [25] = item("Chest_Silver"),
	[26] = silver(400), [27] = item("Tonic_Vigor"), [28] = gold(4000), [29] = silver(500), [30] = item("Chest_Gold"),
}

PremiumConfig.Pass.Premium = {
	[1] = gems(50), [2] = item("Chemical", 3), [3] = silver(300), [4] = item("GearSpare", 3), [5] = item("Chest_Ironbound"),
	[6] = item("Blueprint", 2), [7] = gold(3000), [8] = item("Insignia", 3), [9] = item("Feast_Royal"), [10] = item("Chest_Silver"),
	[11] = item("Chemical", 5), [12] = silver(500), [13] = gems(50), [14] = item("GearSpare", 5), [15] = item("Chest_Silver"),
	[16] = item("Blueprint", 3), [17] = gold(5000), [18] = item("Insignia", 5), [19] = item("Feast_Royal", 2), [20] = item("Chest_Gold"),
	[21] = item("Chemical", 8), [22] = silver(800), [23] = gems(100), [24] = item("GearSpare", 8), [25] = item("Chest_Gold"),
	[26] = item("Blueprint", 5), [27] = gold(8000), [28] = item("Insignia", 10), [29] = silver(1000), [30] = item("Chest_Gold", 2),
}

function PremiumConfig.GachaById(id)
	for _, g in ipairs(PremiumConfig.Gacha) do
		if g.id == id then return g end
	end
	return nil
end

function PremiumConfig.ShopById(id)
	for _, row in ipairs(PremiumConfig.Shop) do
		if row.id == id then return row end
	end
	return nil
end

return PremiumConfig
