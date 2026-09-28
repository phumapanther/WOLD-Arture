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
-- **1 โรบักซ์ = 1 เพชร ตายตัวทุกแพ็ก** (ผู้ใช้กำหนด 2026-09-19) ไม่มีส่วนลดซื้อเยอะ
-- แพ็กใหญ่มีไว้ให้กดครั้งเดียวจบ ไม่ใช่ให้ได้เรทดีกว่า — ราคาต่อเพชรเท่ากันหมด คนเลือกได้โดยไม่ต้องคิดเลข
PremiumConfig.GemPacks = {
	{ gems = 100, robux = 100, productId = nil },
	{ gems = 550, robux = 550, productId = nil },
	{ gems = 1200, robux = 1200, productId = nil },
	{ gems = 3000, robux = 3000, productId = nil },
}

--------------------------------------------------------------------------------
-- ร้านค้า
--------------------------------------------------------------------------------

-- แต่ละแถว: ไอเทมในแคตตาล็อก จำนวน ราคาเพชร คำโปรย
--
-- **ราคาทั้งแผง ผู้ใช้กำหนดเอง 2026-09-19** (เดิมเครื่องมือ 600-800 อาหาร 120-150) ไม่ได้คิดจากสูตรไหน
-- ห้ามไปปรับตามหลักเศรษฐกิจภายหลังโดยไม่ถาม: เครื่องมือถูกลงเพราะควรซื้อได้จากเพชรก้อนแรก
-- ส่วนอาหารบัพสั้นลงมาก (นาที ไม่ใช่ชั่วโมง ดู ItemCatalog) ราคาจึงเป็นของใช้แล้วหมด ไม่ใช่ของสะสม
--
-- คำโปรยของอาหารต้องตรงกับ `use.seconds` ใน ItemCatalog เสมอ — คนอ่านป้ายก่อนจ่ายเพชร
PremiumConfig.Shop = {
	-- ขวาน/พลั่ว 150 · คันเบ็ด 300 (ผู้ใช้กำหนด 2026-09-28 เดิม 250/200/400) · อีเต้อไม่ได้สั่งเปลี่ยน คง 250
	{ id = "gold_axe", item = "GoldAxe", count = 1, price = 150, blurb = "ตัดไม้ได้ตลอดกาล ไม่มีวันพัง" },
	{ id = "gold_pickaxe", item = "GoldPickaxe", count = 1, price = 250, blurb = "ขุดแร่ได้ตลอดกาล ไม่มีวันพัง" },
	{ id = "gold_shovel", item = "GoldShovel", count = 1, price = 150, blurb = "ขุดสมุนไพรได้ตลอดกาล ไม่มีวันพัง" },
	{ id = "gold_rod", item = "GoldFishingRod", count = 1, price = 300, blurb = "ตกปลาได้ตลอดกาล ไม่มีวันพัง" },
	{ id = "feast_hearty", item = "Feast_Hearty", count = 1, price = 60, blurb = "อิ่มทันที + บัพทุกอย่างยกเว้นเลือด 3 นาที" },
	{ id = "tonic_vigor", item = "Tonic_Vigor", count = 1, price = 30, blurb = "มานา สตามินา ไม่ลด 1 นาที" },
	{ id = "feast_royal", item = "Feast_Royal", count = 1, price = 80, blurb = "อิ่มทันที + บัพทุกอย่างยกเว้นเลือด 10 นาที" },

	-- **แลกเพชรเป็นเหรียญในเกม** (ผู้ใช้สั่ง 2026-09-24) — ใช้ได้ทั้งเกมหลักและโหมดฟาร์มมิ่ง
	-- เงินเป็นกระเป๋าเดียวกันทั้ง universe (โปรไฟล์ก้อนเดียว) แลกที่ไหนก็ใช้ได้อีกที่
	--
	-- แถวเหล่านี้ใช้ `gold` แทน `item` — `buy` แยกสองทางที่บรรทัดเดียว จึงไม่ต้องมีหน้าต่างใหม่
	-- และไม่กินช่องกระเป๋า (เงินไม่ใช่ไอเทม) · ซื้อเยอะคุ้มกว่า เป็นส่วนลดตามชุด ไม่ใช่สูตร
	--
	-- **อัตราตั้งต้น 60 เหรียญต่อเพชร — ตัวเลขผมตั้งเอง ผู้ใช้ยังไม่ได้กำหนด**
	-- อ้างอิงจากของในร้านทั้งสองฝั่ง: ขวานทอง 250 เพชร เทียบขวานธรรมดา 1,400 เหรียญ ≈ 5.6
	-- ตั้งที่ 60 จึงแพงกว่าการซื้อของตรงๆ สิบเท่า — เงินควรเป็นทางลัดที่แพง ไม่ใช่ทางลัดที่คุ้ม
	{ id = "cash_small", name = "ถุงเหรียญ", icon = "rbxassetid://130387196273181", gold = 3000, price = 50, blurb = "เงินในเกม 3,000 เหรียญ" },
	{ id = "cash_medium", name = "หีบเหรียญ", icon = "rbxassetid://130387196273181", gold = 13000, price = 200, blurb = "เงินในเกม 13,000 เหรียญ (คุ้มกว่า 8%)" },
	{ id = "cash_large", name = "รถขนเหรียญ", icon = "rbxassetid://130387196273181", gold = 70000, price = 1000, blurb = "เงินในเกม 70,000 เหรียญ (คุ้มกว่า 17%)" },
}

--------------------------------------------------------------------------------
-- VIP (ผู้ใช้กำหนด 2026-09-20: **ขายด้วยเพชร ในหน้าร้านแคชนี่แหละ** ไม่ใช่ Game Pass โรบัค)
--
-- VIP คือกุญแจของ **โหมดฟาร์มมิ่ง** — เกาะลอยฟ้าส่วนตัว (ดู `docs/design/06-modes-build-plan.md`)
-- อย่างอื่นในเกมหลักไม่ได้ผูกกับ VIP เลย จงใจ: คนไม่ซื้อไม่ได้เสียเปรียบในเกมหลักแม้แต่อย่างเดียว
--
-- **เก็บเป็นวัน ไม่ใช่ตลอดชีพ** — ของตลอดชีพขายได้ครั้งเดียวต่อคน แล้วเกาะที่ต้องดูแลตลอดไปจะไม่มีรายได้
-- มาคู่กับมันเลย · ต่ออายุได้เรื่อยๆ เวลาที่เหลือทบกัน (ซื้อตอนยังไม่หมดอายุ = บวกเพิ่มจากของเดิม)
--
-- **ราคา 150 เพชร/30 วัน (ผู้ใช้กำหนด 2026-09-22)** ลดจาก 300 ที่ผมตั้งไว้ก่อนหน้า
-- 1 โรบักซ์ = 1 เพชรตายตัว จึงราว 150 โรบักซ์ต่อเดือน เทียบกับพาสทั้งซีซัน 450
PremiumConfig.Vip = {
	price = 150,
	days = 30,
	name = "VIP",
	blurb = "ปลดโหมดฟาร์มมิ่ง — เกาะลอยฟ้าส่วนตัว ชวนเพื่อนเข้าได้",
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

-- ตู้กาชา — **สองชั้น** (ผู้ใช้กำหนด 2026-09-19)
--
--   `pool`  = ของหลักของตู้นั้น (ออร่า / สกินอาวุธ / ชุดแฟชั่น / รถ) ออกแค่ **10%**
--   ที่เหลือ 90% ออกของฟาร์ม ของผิดกฎหมาย ซิลเวอร์ เหรียญค้อนแตก อาหาร และปลา (ดู `GachaFiller`)
--
-- **สุ่มครบ 10 ครั้งได้ของหลักอย่างน้อย 1 ชิ้นแน่นอน** — ตัวนับสะสมข้ามการกดอยู่ในโปรไฟล์ผู้เล่น
-- ไม่ใช่นับเฉพาะในชุด 10 ครั้ง ดังนั้นกดเดี่ยว 10 ครั้งก็การันตีเหมือนกัน (ดู `PremiumStore.server`)
--
-- ของซ้ำได้ซ้ำไปเลย (ผู้ใช้กำหนด) เก็บไว้เทรด/ให้เพื่อนได้ · 10 ครั้งถูกกว่า 10 ครั้งเดี่ยว 10%
PremiumConfig.GachaJackpotChance = 0.10  -- โอกาสออกของหลักต่อการสุ่มหนึ่งครั้ง
PremiumConfig.GachaPity = 10             -- สุ่มครบเท่านี้โดยไม่ได้ของหลัก ครั้งถัดไปบังคับให้ออก
PremiumConfig.Gacha = {
	{
		id = "aura", name = "กาชาออร่า", icon = "✨", cost = 50, cost10 = 450,
		blurb = "เอฟเฟกต์ลอยรอบตัวละคร ใช้จากกระเป๋าเพื่อเปิด/ปิด",
		pool = { "Aura_Ember", "Aura_Frost", "Aura_Void", "Aura_Divine" },
	},
	{
		id = "weapon", name = "กาชาสกินอาวุธ", icon = "⚔️", cost = 150, cost10 = 1350,
		blurb = "สกินติดตั้งได้เฉพาะอาวุธชนิดเดียวกัน ถอดออกได้",
		pool = { "Skin_Sword_Ember", "Skin_Sword_Frost", "Skin_Greatsword_Void", "Skin_Greatsword_Gold",
			"Skin_Bow_Vine", "Skin_Pistol_Brass", "Skin_Staff_Storm", "Skin_Spellbook_Blood" },
	},
	{
		id = "armor", name = "กาชาชุดเกราะแฟชั่น", icon = "🛡️", cost = 100, cost10 = 900,
		blurb = "เปลี่ยนรูปลักษณ์เกราะที่สวม ค่าเกราะเท่าเดิม",
		pool = { "Fashion_Knight_Crimson", "Fashion_Ranger_Shadow", "Fashion_Royal_Gold" },
	},
	{
		id = "vehicle", name = "กาชาพาหนะ", icon = "🚗", cost = 200, cost10 = 1800,
		blurb = "รถแบบใหม่ๆ มาในอนาคต",
		pool = {}, -- ว่าง = ปุ่มสุ่มขึ้น "เร็วๆ นี้"
	},
	{
		-- **ตู้รวม** (ผู้ใช้กำหนด 2026-09-19): ของทุกตู้กองรวมกัน ถูกที่สุด แต่ออกยากที่สุดและ**ไม่มีการันตี**
		--
		-- เพดานสองชั้นที่ต้องไม่ละเมิด: ต่อชิ้นไม่เกิน 0.5% · รวมทุกชิ้นไม่เกิน 5%
		-- `JackpotChance` คิดให้เองจากจำนวนของในสระ = min(5%, 0.5% x จำนวนชิ้น) เพดานจึงถูกเสมอ
		-- ไม่ว่าจะเพิ่มของอีกกี่ชิ้นในอนาคต (ตอนนี้ 15 ชิ้น -> รวม 5% ต่อชิ้น 0.33%)
		--
		-- **ผู้ใช้สั่งลดครึ่งหนึ่ง 2026-09-20** (เดิม 1% ต่อชิ้น / รวม 10%) — ของแรร์ในตู้รวมจึงออกยากขึ้น
		-- เท่าตัว สมกับที่มันเป็นตู้ถูกสุดและไม่มีการันตี · ตู้เฉพาะทางไม่ถูกแตะ ยังออกของหลัก 10% เท่าเดิม
		-- **ลดที่เพดานทั้งสองชั้น ไม่ใช่แค่ชั้นเดียว** ถ้าลดแค่ `perItemCap` พอของครบ 20 ชิ้นเมื่อไหร่
		-- ตัว min จะไปติดเพดานรวม 10% เหมือนเดิม แล้วการลดครั้งนี้จะหายไปเงียบๆ
		--
		-- **`uniform = true` สำคัญมาก** ถ้าปล่อยให้ถ่วงน้ำหนักตาม rarity เหมือนตู้อื่น ของระดับ "หายาก"
		-- (weight 30 เทียบกับตำนาน 2) จะกินส่วนแบ่งจนเกิน 1% ต่อชิ้นทันที = ผิดเพดานที่ผู้ใช้กำหนด
		id = "all", name = "กาชารวม", icon = "🎰", cost = 25, cost10 = 225,
		blurb = "รวมของทุกตู้ไว้ที่เดียว ราคาถูกสุด แต่โอกาสต่ำและไม่มีการันตี",
		perItemCap = 0.005, jackpotCap = 0.05, uniform = true, pity = false,
		pool = {}, -- เติมจากตู้อื่นข้างล่าง
	},
}

-- สระของตู้รวม = ของหลักของทุกตู้กองรวมกัน **สร้างจากตู้อื่น ไม่ได้พิมพ์ซ้ำ**
-- เพิ่มรถเข้ากาชาพาหนะเมื่อไหร่ ตู้รวมได้ไปด้วยเองทันที ไม่มีทางลืมอัปเดตสองที่
do
	local all
	for _, g in ipairs(PremiumConfig.Gacha) do if g.id == "all" then all = g end end
	for _, g in ipairs(PremiumConfig.Gacha) do
		if g.id ~= "all" then
			for _, id in ipairs(g.pool) do all.pool[#all.pool + 1] = id end
		end
	end
end

-- โอกาสออกของหลักของตู้หนึ่ง — ตู้ที่ตั้งเพดานไว้จะคิดจากจำนวนของในสระ ตู้อื่นใช้ค่ากลาง
function PremiumConfig.JackpotChance(banner)
	if banner.perItemCap then
		return math.min(banner.jackpotCap or PremiumConfig.GachaJackpotChance, banner.perItemCap * #banner.pool)
	end
	return banner.jackpotChance or PremiumConfig.GachaJackpotChance
end

--------------------------------------------------------------------------------
-- แบทเทิลพาส
--------------------------------------------------------------------------------

-- **พาสรายเดือน** (ผู้ใช้สั่ง 2026-09-27): ซีซัน = เดือนปฏิทิน (เวลาไทย) เปลี่ยนเองทุกวันที่ 1 — ความคืบหน้าเริ่มใหม่ ·
-- ปลดพรีเมียมใหม่ทุกเดือน · ของที่รับไปแล้วไม่หาย · เลขซีซันคิดจากปฏิทิน ทุกเซิร์ฟได้เลขเดียวกันโดยไม่ต้องคุยกัน
-- (เดิม `season = 1` ตั้งมือ) · กันยายน 2026 = ซีซัน 1 ความคืบหน้าที่เก็บไว้ตอนนั้นจึงอยู่ต่อถึงสิ้นเดือน
PremiumConfig.Pass = {
	tiers = 30,
	xpPerTier = 1000,
	-- XP พาส = EXP ที่ได้ในเกม × ตัวคูณนี้ (ส่งเควส ฆ่ามอน เก็บของ ตกปลา ล้วนผ่าน Progression.AwardExp)
	xpPerExp = 1,
	-- ปลดสายพรีเมียมด้วยเพชร
	premiumCost = 450,  -- ผู้ใช้กำหนด 2026-09-19 (เดิม 950)
}

-- รางวัลรายขั้น { item, count } หรือ { gold = n } หรือ { gems = n } ว่าง = ขั้นนั้นไม่มีของสายนี้
-- ของผิดกฎหมาย (Chemical/GearSpare/Blueprint) ซิลเวอร์ อาหารพิเศษ หีบ เงิน-ทอง เหรียญตราค้อนแตก (Insignia)
-- ตามที่ผู้ใช้กำหนด สายฟรีเน้นซิลเวอร์ สายพรีเมียมเน้นของผิดกฎหมาย/หีบ/เพชรคืน
local function silver(n) return { item = "Silver", count = n } end
local function gold(n) return { gold = n } end
local function gems(n) return { gems = n } end
local function item(id, n) return { item = id, count = n or 1 } end

-- หีบสายฟรีให้ทีละใบ **สายพรีเมียมให้ทีละสิบใบ** (ผู้ใช้กำหนด 2026-09-20 — เดิมสายพรีเมียมก็ใบเดียว)
-- หีบหนึ่งกองได้ 8 ใบ สิบใบจึงกินสองช่องและหนักราว 80-100 หน่วย: ตั้งใจให้เป็นของที่ต้องขนกลับบ้าน
-- เครื่องรางคุ้มครอง (ผู้ใช้สั่ง 2026-09-25 "แบทเทิลพาสแจกโทเท็มด้วย") — ขั้นที่ใส่ผมเลือก:
-- สายฟรีขั้น 17 (แทนถ่านหิน 20) · สายพรีเมียมขั้น 14 กับ 24 (แทนเฟืองอะไหล่)
PremiumConfig.Pass.Free = {
	[1] = silver(100), [2] = gold(1000), [3] = silver(150), [4] = item("Bread", 5), [5] = item("Chest_Wood"),
	[6] = silver(150), [7] = gold(1500), [8] = item("Insignia", 1), [9] = silver(200), [10] = item("Chest_Ironbound"),
	[11] = silver(200), [12] = gold(2000), [13] = item("Feast_Hearty"), [14] = silver(250), [15] = item("Chest_Ironbound"),
	[16] = silver(250), [17] = item("GuardianCharm", 1), [18] = gold(2500), [19] = silver(300), [20] = item("Chest_Silver"),
	[21] = silver(300), [22] = item("Insignia", 2), [23] = gold(3000), [24] = silver(350), [25] = item("Chest_Silver"),
	-- ขั้นสุดท้ายสายฟรี: กล่องเวทมนตร์ **ใบเดียว** (ผู้ใช้กำหนด) — สายพรีเมียมได้สิบใบที่ขั้นเดียวกัน
	[26] = silver(400), [27] = item("Tonic_Vigor"), [28] = gold(4000), [29] = item("Chest_Gold"), [30] = item("MagicBox", 1),
}

PremiumConfig.Pass.Premium = {
	[1] = gems(50), [2] = item("Chemical", 3), [3] = silver(300), [4] = item("GearSpare", 3), [5] = item("Chest_Ironbound", 10),
	[6] = item("Blueprint", 2), [7] = gold(3000), [8] = item("Insignia", 3), [9] = item("Feast_Royal"), [10] = item("Chest_Silver", 10),
	[11] = item("Chemical", 5), [12] = silver(500), [13] = gems(50), [14] = item("GuardianCharm", 1), [15] = item("Chest_Silver", 10),
	[16] = item("Blueprint", 3), [17] = gold(5000), [18] = item("Insignia", 5), [19] = item("Feast_Royal", 2), [20] = item("Chest_Gold", 10),
	[21] = item("Chemical", 8), [22] = silver(800), [23] = gems(100), [24] = item("GuardianCharm", 1), [25] = item("Chest_Gold", 10),
	-- ขั้นสุดท้ายสายพรีเมียม: กล่องเวทมนตร์ 10 ใบ (หีบทอง 20 ใบที่เคยอยู่ขั้นนี้ย้ายไปขั้น 29)
	[26] = item("Blueprint", 5), [27] = gold(8000), [28] = item("Insignia", 10), [29] = item("Chest_Gold", 20), [30] = item("MagicBox", 10),
}

-- **ของประจำเดือนสายพรีเมียม** (ผู้ใช้สั่ง 2026-09-27): ขั้นท้าย = สกินอาวุธ · ครึ่งทาง = ออร่า · สุ่มใหม่ทุกเดือน
-- **ได้เพิ่มจากของเดิมของขั้นนั้น** (ผู้ใช้เลือก — ขั้น 15 หีบเงิน 10 + ออร่า · ขั้น 30 กล่องเวท 10 + สกิน)
-- สระ = ของหลักในตู้กาชาชนิดนั้น (เพิ่มสกิน/ออร่าเข้าตู้เมื่อไหร่ ก็เข้ามาหมุนในพาสเอง)
PremiumConfig.Pass.Monthly = { [15] = "aura", [30] = "weapon" }

local THAI_MONTHS = { "มกราคม", "กุมภาพันธ์", "มีนาคม", "เมษายน", "พฤษภาคม", "มิถุนายน", "กรกฎาคม", "สิงหาคม",
	"กันยายน", "ตุลาคม", "พฤศจิกายน", "ธันวาคม" }
local TZ = 7 * 3600 -- เวลาไทย (ตัวเดียวกับที่ QuestConfig ใช้พลิกวัน)
PremiumConfig.PassBaseMonth = 2026 * 12 + 8 -- เดือนที่นับจากปี 0 (มกราคม = 0) · กันยายน 2026 = ซีซัน 1

-- ซีซันของเวลา `now` (os.time) — เดือนไทยที่เท่าไหร่นับจากกันยายน 2026
function PremiumConfig.PassSeason(now)
	local t = os.date("!*t", math.floor(tonumber(now) or os.time()) + TZ)
	return (t.year * 12 + (t.month - 1)) - PremiumConfig.PassBaseMonth + 1
end

local function monthOf(season)
	local m = PremiumConfig.PassBaseMonth + (math.floor(season) - 1)
	return math.floor(m / 12), m % 12 + 1
end

-- os.time ที่ซีซันนี้จบ = เที่ยงคืนวันที่ 1 ของเดือนถัดไป เวลาไทย
function PremiumConfig.PassSeasonEnds(season)
	local year, month = monthOf(season + 1)
	return os.time({ year = year, month = month, day = 1, hour = 0, min = 0, sec = 0 }) - TZ
end

function PremiumConfig.PassName(season)
	local year, month = monthOf(season)
	return ("พาสเดือน%s %d"):format(THAI_MONTHS[month], year + 543)
end

-- ของประจำเดือนชนิดหนึ่ง: สับสระด้วยเมล็ดคงที่แล้วเดินทีละเดือน = เดือนติดกันไม่ซ้ำ และวนครบทุกชิ้นก่อนซ้ำ
-- (คิดจากเลขซีซันล้วน ทุกเซิร์ฟ/ทุกเครื่องได้ชิ้นเดียวกัน)
function PremiumConfig.PassMonthlyItem(season, kind)
	local banner = PremiumConfig.GachaById(kind)
	local pool = banner and banner.pool or {}
	if #pool == 0 then return nil end
	local order = table.clone(pool)
	local rng = Random.new(#kind * 7919 + #pool)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	return order[((math.floor(season) - 1) % #order) + 1]
end

-- ของทั้งหมดของขั้นหนึ่ง (รายการ) — ของประจำขั้น + ของประจำเดือน (สายพรีเมียม) · ว่าง = ขั้นนั้นไม่มีของสายนี้
function PremiumConfig.PassRewards(season, track, tier)
	local out = {}
	local base = (track == "premium" and PremiumConfig.Pass.Premium or PremiumConfig.Pass.Free)[tier]
	if base then out[#out + 1] = base end
	local kind = track == "premium" and PremiumConfig.Pass.Monthly[tier]
	local id = kind and PremiumConfig.PassMonthlyItem(season, kind)
	if id then out[#out + 1] = { item = id, count = 1, monthly = true } end
	return out
end

--------------------------------------------------------------------------------
-- กล่องเวทมนตร์: สุ่ม "ทุกอย่างที่มีในเซิร์ฟ" ตามเรทที่ผู้ใช้กำหนด สระแต่ละหมวดสร้างจาก ItemCatalog ตอนใช้
--------------------------------------------------------------------------------

PremiumConfig.MagicBox = {
	-- หมวด → น้ำหนัก (รวม 100)
	{ id = "farm", weight = 80, count = { 3, 8 } },      -- ของฟาร์ม: ของขายได้ทั่วไป (junk ที่ขายได้)
	{ id = "illegal", weight = 10, count = { 1, 3 } },   -- ของผิดกฎหมาย
	{ id = "consumable", weight = 5, count = { 1, 2 } }, -- ของใช้
	{ id = "weapon", weight = 3, count = { 1, 1 } },     -- อาวุธ
	{ id = "vehicle", weight = 1, count = { 1, 1 } },    -- พาหนะ
	{ id = "skin", weight = 1, count = { 1, 1 } },       -- สกิน/ออร่า/ชุดแฟชั่น
}
PremiumConfig.MagicBoxIllegal = { "Chemical", "GearSpare", "Blueprint", "Coal", "Silver" }
PremiumConfig.MagicBoxVehicles = { "Monowheel" }

-- สระ 90% — **สร้างจาก ItemCatalog ตอนเรียก ไม่ใช่ลิสต์ที่พิมพ์มือไว้**
-- ลิสต์มือจะเพี้ยนเงียบๆ ทุกครั้งที่มีคนเพิ่ม/เปลี่ยนชื่อไอเทม ส่วนตัวกรองนี้เก็บของใหม่ให้เองอัตโนมัติ
--
-- เอาอะไรเข้าบ้าง: ของฟาร์ม/ของเก็บเกี่ยว/ปลา (`kind == "junk"` ที่ขายได้) · อาหารทุกชนิด (`food`) ·
-- ของผิดกฎหมายกับซิลเวอร์และเหรียญค้อนแตกที่ระบุชื่อไว้ตรงๆ เพราะพวกนี้ตั้ง `sellable = false`
--
-- เอาอะไรออก: ของประจำตำแหน่ง (`bound`) และของพรีเมียมทุกชนิด — ไม่งั้นตู้ออร่าจะแจกสกินอาวุธปนมา
PremiumConfig.GachaFillerNamed = { "Chemical", "GearSpare", "Blueprint", "Coal", "Silver", "Insignia" }

function PremiumConfig.GachaFiller(catalog)
	local out = {}
	local seen = {}
	for _, id in ipairs(PremiumConfig.GachaFillerNamed) do
		if catalog.Items[id] then out[#out + 1] = id; seen[id] = true end
	end
	for id, item in pairs(catalog.Items) do
		local premium = item.kind == "skin" or item.kind == "fashion" or item.kind == "aura" or item.kind == "key"
		if not seen[id] and not item.bound and not premium
			and (item.food == true or (item.kind == "junk" and item.sellable ~= false)) then
			out[#out + 1] = id
			seen[id] = true
		end
	end
	table.sort(out) -- ลำดับคงที่ ไม่งั้นน้ำหนักสุ่มขยับทุกครั้งที่เซิร์ฟเวอร์บูต
	return out
end

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
