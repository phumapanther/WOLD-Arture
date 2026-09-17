-- QuestConfig: บอร์ดเควสแต่ละแห่ง และงานที่มันสุ่มออกมา
--
-- ข้อมูลล้วน เหมือน ShopConfig และ CraftConfig ด้วยเหตุผลเดียวกัน: วันที่อยากเพิ่มงานใหม่ คนแก้จะได้แก้
-- ที่ไฟล์เดียวโดยไม่ต้องรู้จักโค้ดเลย
--
-- **แต่ละบอร์ดสุ่มจากคลังของตัวเอง** ตามที่ผู้ใช้กำหนด บอร์ดเหมืองให้งานขุด บอร์ดประมงให้งานตกปลา
-- ซึ่งทำให้การเดินทางไปอีกหมู่บ้านมีเหตุผล — ไม่ใช่แค่บอร์ดเดียวกันตั้งอยู่หกที่
local QuestConfig = {}

-- งานบนบอร์ดอยู่ได้นานแค่ไหนก่อนสุ่มใหม่
--
-- ยาวพอให้ทำเสร็จได้จริงโดยไม่ต้องรีบ แต่สั้นพอที่กลับมาพรุ่งนี้แล้วเจอของใหม่
QuestConfig.RerollSeconds = 30 * 60

-- กี่งานต่อบอร์ด
QuestConfig.SlotsPerBoard = 3

-- รับพร้อมกันได้กี่งาน
--
-- สามงานคือ "เลือกได้ว่าจะทำอะไรก่อน" ส่วนสิบงานคือรายการของที่ต้องเก็บระหว่างทางอยู่แล้ว ซึ่งไม่ใช่เควส
QuestConfig.MaxActive = 3

--------------------------------------------------------------------------------
-- ชนิดของงาน
--------------------------------------------------------------------------------

-- `kind` บอกว่านับความคืบหน้าจากอะไร:
--   gather = มีของกี่ชิ้นในกระเป๋า (ส่งของ — ของหายไปตอนส่ง)
--   hunt   = ฆ่ามอนชนิดนั้นกี่ตัวนับจากรับงาน
--   fish   = ตกปลาชนิดนั้นได้กี่ตัวนับจากรับงาน
--
-- `pool` คือคลังของบอร์ด สุ่มหยิบมา SlotsPerBoard งานทุกครั้งที่ครบเวลา

--------------------------------------------------------------------------------
-- บอร์ดทั้งหก
--------------------------------------------------------------------------------

QuestConfig.Boards = {
	{
		id = "Goldmeadow", name = "โกลด์เมโดว์", where = Vector3.new(-960, 154, 960),
		blurb = "หมู่บ้านเกษตร",
		pool = {
			{ kind = "gather", item = "Wheat", min = 10, max = 20, gold = 300, xp = 40 },
			{ kind = "gather", item = "Vegetable", min = 8, max = 15, gold = 280, xp = 35 },
			{ kind = "gather", item = "Milk", min = 5, max = 10, gold = 320, xp = 40 },
			{ kind = "gather", item = "Egg", min = 8, max = 16, gold = 260, xp = 30 },
			{ kind = "gather", item = "Wool", min = 4, max = 8, gold = 350, xp = 45 },
			{ kind = "hunt", mob = "หมูป่า", min = 3, max = 6, gold = 400, xp = 70 },
		},
	},
	{
		id = "Stonemark", name = "สโตนมาร์ก", where = Vector3.new(-960, 394, -3360),
		blurb = "เมืองเหมืองแร่",
		pool = {
			{ kind = "gather", item = "IronOre", min = 8, max = 15, gold = 380, xp = 50 },
			{ kind = "gather", item = "Coal", min = 10, max = 20, gold = 340, xp = 45 },
			{ kind = "gather", item = "Stone", min = 15, max = 30, gold = 250, xp = 30 },
			{ kind = "gather", item = "SilverOre", min = 3, max = 6, gold = 700, xp = 90 },
			{ kind = "gather", item = "GoldOre", min = 2, max = 4, gold = 1100, xp = 130 },
			{ kind = "hunt", mob = "โกเลมหิน", min = 1, max = 2, gold = 1400, xp = 200 },
		},
	},
	{
		id = "Saltmere", name = "ซอลต์เมียร์", where = Vector3.new(-3600, 146, 5260),
		blurb = "หมู่บ้านประมง",
		pool = {
			{ kind = "fish", item = "Fish", min = 5, max = 12, gold = 280, xp = 35 },
			{ kind = "fish", item = "Crab", min = 3, max = 8, gold = 320, xp = 40 },
			{ kind = "fish", item = "Squid", min = 2, max = 5, gold = 420, xp = 55 },
			{ kind = "fish", item = "SilverSalmon", min = 1, max = 2, gold = 900, xp = 110 },
			{ kind = "fish", item = "Tanker", min = 1, max = 1, gold = 1200, xp = 150 },
			{ kind = "gather", item = "Shell", min = 6, max = 12, gold = 240, xp = 30 },
		},
	},
	{
		id = "Elderwood", name = "เอลเดอร์วูด", where = Vector3.new(-4000, 169, 160),
		blurb = "หมู่บ้านคนตัดไม้",
		pool = {
			{ kind = "gather", item = "WoodScrap", min = 15, max = 30, gold = 260, xp = 30 },
			{ kind = "gather", item = "Herb", min = 6, max = 12, gold = 300, xp = 40 },
			{ kind = "gather", item = "Apple", min = 5, max = 10, gold = 220, xp = 25 },
			{ kind = "gather", item = "Leather", min = 4, max = 8, gold = 420, xp = 55 },
			{ kind = "hunt", mob = "หมาป่า", min = 3, max = 6, gold = 500, xp = 90 },
			{ kind = "hunt", mob = "แมงมุมยักษ์", min = 4, max = 8, gold = 460, xp = 80 },
		},
	},
	{
		id = "Cogsworth", name = "ค็อกส์เวิร์ธ", where = Vector3.new(970, 162, -1120),
		blurb = "เมืองช่างกล",
		pool = {
			{ kind = "gather", item = "GearSpare", min = 4, max = 8, gold = 500, xp = 60 },
			{ kind = "gather", item = "Chemical", min = 4, max = 8, gold = 480, xp = 60 },
			{ kind = "gather", item = "Coal", min = 12, max = 25, gold = 360, xp = 45 },
			{ kind = "gather", item = "Blueprint", min = 2, max = 4, gold = 800, xp = 100 },
			{ kind = "hunt", mob = "หุ่นไขลาน", min = 2, max = 4, gold = 900, xp = 140 },
			{ kind = "gather", item = "Silver", min = 100, max = 250, gold = 600, xp = 70 },
		},
	},
	{
		id = "Astravale", name = "แอสตราเวล", where = Vector3.new(3840, 1270, -3360),
		blurb = "ดินแดนเวทมนตร์",
		pool = {
			{ kind = "gather", item = "MagicOre", min = 3, max = 6, gold = 1000, xp = 120 },
			{ kind = "gather", item = "MagicBranch", min = 4, max = 8, gold = 700, xp = 90 },
			{ kind = "gather", item = "RuneStone", min = 3, max = 6, gold = 750, xp = 95 },
			{ kind = "gather", item = "Crystal", min = 3, max = 6, gold = 650, xp = 85 },
			{ kind = "hunt", mob = "วิญญาณ", min = 2, max = 4, gold = 1100, xp = 170 },
			{ kind = "fish", item = "RainbowFish", min = 1, max = 2, gold = 1300, xp = 160 },
		},
	},
}

--------------------------------------------------------------------------------
-- คำอธิบายงาน
--------------------------------------------------------------------------------

-- ข้อความบนกระดาษ สร้างจากตัวงานเอง ไม่ได้เขียนไว้ทีละบรรทัด — งานใหม่จึงมีคำอธิบายทันทีโดยไม่ต้องเขียนเพิ่ม
function QuestConfig.Describe(quest, itemName)
	if quest.kind == "hunt" then
		return ("ล่า%s %d ตัว"):format(quest.mob, quest.need)
	elseif quest.kind == "fish" then
		return ("ตก%s %d ตัว"):format(itemName or quest.item, quest.need)
	end
	return ("ส่ง%s %d ชิ้น"):format(itemName or quest.item, quest.need)
end

return QuestConfig
