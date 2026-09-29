-- QuestConfig: บอร์ดเควสแต่ละแห่ง และงานที่มันสุ่มออกมา
--
-- ข้อมูลล้วน เหมือน ShopConfig และ CraftConfig ด้วยเหตุผลเดียวกัน: วันที่อยากเพิ่มงานใหม่ คนแก้จะได้แก้
-- ที่ไฟล์เดียวโดยไม่ต้องรู้จักโค้ดเลย
--
-- **แต่ละบอร์ดสุ่มจากคลังของตัวเอง** ตามที่ผู้ใช้กำหนด บอร์ดเหมืองให้งานขุด บอร์ดประมงให้งานตกปลา
-- ซึ่งทำให้การเดินทางไปอีกหมู่บ้านมีเหตุผล — ไม่ใช่แค่บอร์ดเดียวกันตั้งอยู่หกที่
local QuestConfig = {}

-- งานบนบอร์ดสุ่มใหม่วันละครั้ง ตามที่ผู้ใช้กำหนด
--
-- **นับจากปฏิทินจริง ไม่ใช่เวลาที่เซิร์ฟเวอร์เปิดมา** ถ้าใช้เวลาเปิดเซิร์ฟ แต่ละเซิร์ฟเวอร์จะนับคนละรอบ
-- แล้วผู้เล่นที่ย้ายช่องจะเจอบอร์ดคนละชุด และการรีสตาร์ทเซิร์ฟเวอร์จะกลายเป็นวิธีสุ่มงานใหม่
--
-- ทั้งเกมจึงแบ่งเวลาเป็น "วันที่เท่าไหร่นับจาก epoch" แล้วใช้เลขนั้นเป็นเมล็ดสุ่ม — ทุกเซิร์ฟเวอร์
-- คำนวณได้เองและได้ผลเดียวกันโดยไม่ต้องคุยกัน
QuestConfig.RerollSeconds = 24 * 60 * 60

-- **วันพลิกตอนเที่ยงคืนเวลาไทย ไม่ใช่เที่ยงคืน UTC** (ผู้ใช้กำหนด 2026-09-19)
--
-- `os.time()` เป็นเวลา UTC หารตรงๆ วันจึงพลิกตอน 7 โมงเช้าบ้านเรา ซึ่งไม่ใช่ "วันใหม่" ของใครเลย
--
-- **บวกก่อนหาร ไม่ใช่ลบ** — เวลาไทย = UTC + 7 เราต้องแปลงเป็นเวลาไทยก่อนแล้วค่อยตัดเป็นวัน
-- (ลบจะเลื่อนไปผิดทาง: วันพลิกตอนบ่ายสองแทน วัดแล้วทั้งสองทาง) · เป็นค่าคงที่ ไม่ได้ไปถามเวลาท้องถิ่นของ
-- เครื่องไหน ทุกเซิร์ฟเวอร์จึงยังได้เลขเดียวกันเหมือนเดิม
QuestConfig.TimeZoneOffsetSeconds = 7 * 60 * 60 -- ไทย = UTC+7

-- วันที่เท่าไหร่แล้ว (นับจาก epoch ตามเส้นแบ่งวันข้างบน) ใช้เป็นเมล็ดสุ่มของบอร์ด
--
-- **ฟังก์ชันนี้เป็นเจ้าของ "วันนี้" ของระบบเควสทั้งระบบ** ทั้งการสุ่มกระดานและสิทธิ์ "ส่งไปแล้ววันนี้"
-- (`profile.QuestsDone.day` ใน `Quests.server`) อ่านจากตัวนี้ตัวเดียว ขยับที่นี่แล้วสองอย่างนั้นเลื่อนพร้อมกัน
-- เสมอ — อย่าคำนวณวันเองที่อื่น
-- **รีบอร์ดด้วยเพชร** (ผู้ใช้สั่ง 2026-09-24) — จ่ายแล้วได้ชุดงานใหม่ทันที ทั้งเกมหลักและโหมดฟาร์มมิ่ง
--
-- **ราคาเป็นตัวเลขที่ผมตั้งเอง ผู้ใช้ยังไม่ได้กำหนด** · ไล่จากรางวัลของบอร์ด: งานหนึ่งใบให้ราว 300-900
-- เหรียญ สามใบจึงราว 1,500 ส่วน 25 เพชรแลกเงินได้ราว 1,500 ที่ร้านแคช — ตั้งให้พอๆ กัน คนที่รีจึงจ่าย
-- ค่า "ได้เล่นต่อ" ไม่ใช่ซื้อกำไรตรงๆ · **ราคาคงที่ ไม่แพงขึ้นตามจำนวนครั้ง** (ผู้ใช้ไม่ได้สั่งให้ไต่)
QuestConfig.RerollPrice = 25

function QuestConfig.DayNumber()
	return math.floor((os.time() + QuestConfig.TimeZoneOffsetSeconds) / QuestConfig.RerollSeconds)
end

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
		-- **บอร์ดประจำเมืองหลวง** (ผู้ใช้สั่ง 2026-09-27) — โมเดล `QuestBoard_FirstTown` ที่ผู้ใช้วางข้างจุดเกิดเอง
		-- (เฟส 68 ตั้ง BoardId ให้) · งานพื้นฐานของคนเพิ่งเริ่ม: วัตถุดิบแถวเมือง + ล่ามอนสามชนิดรอบๆ
		-- **กติกาผู้ใช้: ทุกวันต้องมีงานสไลม์หนึ่งใบเสมอ (ล่าสไลม์ หรือ ส่งเมือกสไลม์) และสองใบนี้ไม่ออกพร้อมกันเด็ดขาด**
		-- → `mustHave = "slime"` + `group = "slime"` บนสองงานนั้น (Quests.server หยิบจากกลุ่มหนึ่งใบก่อน แล้วตัดทั้งกลุ่มทิ้ง)
		-- จำนวน/ความยากของงานที่มีในบอร์ดอื่นใช้เลขเดียวกับบอร์ดนั้น · งานใหม่ (เมือก กระดูก เส้นใย ล่าสไลม์ ล่าโครงกระดูก) ผมตั้ง
		id = "Brasshaven", name = "บราสเฮเวน", where = Vector3.new(2080, 48, 3760),
		blurb = "เมืองหลวง",
		mustHave = "slime",
		pool = {
			{ kind = "gather", item = "WoodScrap", min = 15, max = 30, gold = 260, xp = 30 },
			{ kind = "gather", item = "Stone", min = 15, max = 30, gold = 250, xp = 30 },
			{ kind = "gather", item = "IronOre", min = 8, max = 15, gold = 380, xp = 50 },
			{ kind = "gather", item = "Crystal", min = 3, max = 6, gold = 650, xp = 85 }, -- "ควอส" (ผู้ใช้ยืนยัน = คริสตัล)
			{ kind = "gather", item = "Coal", min = 10, max = 20, gold = 340, xp = 45 },
			{ kind = "gather", item = "Slime", min = 8, max = 15, gold = 280, xp = 35, group = "slime" },
			{ kind = "gather", item = "Bone", min = 8, max = 15, gold = 300, xp = 40 },
			{ kind = "gather", item = "Fiber", min = 10, max = 20, gold = 260, xp = 30 },
			{ kind = "gather", item = "Herb", min = 6, max = 12, gold = 300, xp = 40 },
			{ kind = "hunt", mob = "โครงกระดูก", min = 3, max = 6, gold = 600, xp = 100 },
			{ kind = "hunt", mob = "สไลม์เขียว", min = 5, max = 10, gold = 350, xp = 60, group = "slime" },
			{ kind = "hunt", mob = "แมงมุมยักษ์", min = 4, max = 8, gold = 460, xp = 80 },
		},
	},
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
			{ kind = "hunt", mob = "ทหารจักรกล", min = 2, max = 4, gold = 900, xp = 140 },
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
-- บอร์ดรวมของสมาคม
--------------------------------------------------------------------------------

-- บอร์ดใหญ่ที่สมาคมกลาง รวมงานจากทุกบอร์ดมาไว้ที่เดียว
--
-- **ไม่มีคลังงานของตัวเอง** มันไม่ได้สุ่มงานใหม่ แต่แสดงงานชุดเดียวกับที่บอร์ดประจำเมืองแสดงอยู่ในวันนั้น
-- — ถ้ามีคลังของตัวเอง งานที่นี่จะเป็นคนละชุดกับที่เมือง แล้วคำว่า "รวม" ก็ไม่จริง
--
-- ประโยชน์คือได้เห็นงานทั้งหมดในที่เดียวโดยไม่ต้องเดินไปหกเมือง แต่ยังต้องเดินไปทำงานอยู่ดี
QuestConfig.MainBoardId = "MainGuild"
QuestConfig.MainBoardName = "สมาคมนักผจญภัย"
QuestConfig.MainBoardBlurb = "รวมงานจากทุกเมือง"

--------------------------------------------------------------------------------
-- ล็อกบอร์ดเมือง (ผู้ใช้สั่ง 2026-09-27 · docs/story/01-brasshaven.md)
--------------------------------------------------------------------------------
-- บราสเฮเวน (เมืองหลวง) เปิดให้ทุกคนตั้งแต่แรก · เมืองอื่น **ปลดเมื่อจบเนื้อเรื่องของเมืองนั้น** (`profile.Data.Story.towns`)
-- หรือเป็น VIP (ใช้ได้ทุกเมืองเหมือนเดิม) · ตอนนี้มีแค่บทบราสเฮเวน เมืองอื่นจึงล็อกสำหรับสายฟรีทั้งหมด
-- ล็อก = รับงานใหม่ไม่ได้ + สุ่มบอร์ดใหม่ไม่ได้ · **งานที่รับค้างไว้ก่อนล็อกยังส่งได้** · บอร์ดรวมบนเกาะไม่ล็อก
QuestConfig.OpenTowns = { Brasshaven = true }
QuestConfig.LockedText = "🔒 ปลดเมื่อจบเนื้อเรื่องเมืองนี้ (เร็วๆ นี้) · VIP ใช้ได้ทุกเมือง"

-- เมืองนี้รับงานได้ไหม · `storyTowns` = { [townId] = true } เมืองที่จบบทแล้ว
function QuestConfig.TownOpen(townId, vip, storyTowns)
	if QuestConfig.OpenTowns[townId] or vip then return true end
	return type(storyTowns) == "table" and storyTowns[townId] == true
end

--------------------------------------------------------------------------------
-- รูปภาพบนใบประกาศ
--------------------------------------------------------------------------------

-- ใบประกาศเปล่า ใช้เป็นพื้นหลังของทุกงาน
--
-- **ไอดีทั้งหมดแกะจาก Decal แล้ว** ที่ผู้ใช้ส่งมาเป็น Decal ทุกตัวเหมือนเคย ใส่ตรงๆ จะขึ้นเป็นช่องว่าง
-- โดยไม่มี error — ไอดี Decal เดิมอยู่ในคอมเมนต์ท้ายบรรทัด
QuestConfig.NoticeImage = "rbxassetid://136156584232604" -- decal 127563830445716

-- รูปมอนบนใบประกาศ คีย์เป็น **ชื่อไทย** ให้ตรงกับ `mob` ในคลังงาน
--
-- ใช้ชื่อไทยเป็นคีย์เพราะเควสเก็บชื่อไทยไว้อยู่แล้ว (มันคือสิ่งที่ผู้เล่นอ่าน) การใส่คีย์อังกฤษจะต้อง
-- แปลงกลับไปมา และเป็นจุดที่ชื่อสองชุดหลุดจากกันได้
QuestConfig.MobImages = {
	["โครงกระดูก"] = "rbxassetid://120795805584592", -- decal 94260847126992
	["สไลม์เขียว"] = "rbxassetid://114880438110484", -- decal 130982830301061
	-- decal เดิม 122241010306288 ถูก archive รูปจึงโหลดไม่ขึ้น (2026-09-29) · เทส quest_images_test
	["แมงมุมยักษ์"] = "rbxassetid://123422205393294", -- decal 133189115072411
	["โจรป่า"] = "rbxassetid://97071754226124", -- decal 88010389309543
	["ทหารจักรกล"] = "rbxassetid://80599978341770", -- decal 76597832164707
	["ผีดิบ"] = "rbxassetid://99107159502707", -- decal 119494710161738
	["โกเลมหิน"] = "rbxassetid://136857380271784", -- decal 107594742104427
	["ค้างคาว"] = "rbxassetid://128319028250465", -- decal 127977511777118
	["หมูป่า"] = "rbxassetid://136761950936459", -- decal 134251541132663
	["หมาป่า"] = "rbxassetid://119455202581107", -- decal 102852735957992
	["วิญญาณ"] = "rbxassetid://140289937910799", -- decal 128184742399484
}

--------------------------------------------------------------------------------
-- รางวัล
--------------------------------------------------------------------------------

-- `gold` ในตารางข้างบนคือ **ค่าความยาก** ไม่ใช่รางวัลจริง
--
-- รางวัลจริงคำนวณจากมัน ไม่ได้เขียนไว้ทีละงาน เพราะผู้ใช้กำหนดมาเป็นช่วง ("ซิลเวอร์ 100-500 ตามความยาก",
-- "เงิน 1000+") ซึ่งเป็นกฎเดียวที่ใช้กับทุกงาน — เขียนกฎไว้ที่เดียวแล้วงานใหม่ได้รางวัลถูกต้องทันที
-- โดยไม่ต้องไปคิดเลขเอง และไม่มีทางที่งานง่ายจะให้มากกว่างานยากเพราะพิมพ์ผิด
--
-- ช่วงความยากอ่านจากตารางจริง ไม่ได้ฝังตัวเลขไว้ — เพิ่มงานที่ยากกว่าเดิม เพดานก็ขยับตาม
local DIFFICULTY_MIN, DIFFICULTY_MAX

local function difficultyRange()
	if DIFFICULTY_MIN then return DIFFICULTY_MIN, DIFFICULTY_MAX end
	local lo, hi = math.huge, -math.huge
	for _, board in ipairs(QuestConfig.Boards) do
		for _, spec in ipairs(board.pool) do
			local d = spec.gold or 0
			if d < lo then lo = d end
			if d > hi then hi = d end
		end
	end
	DIFFICULTY_MIN, DIFFICULTY_MAX = lo, math.max(hi, lo + 1)
	return DIFFICULTY_MIN, DIFFICULTY_MAX
end

-- **ผู้ใช้ปรับ 2026-09-25: ต่อเควสเงินไม่เกิน 1,000 ซิลเวอร์ไม่เกิน 100** (เดิม 1,000-3,000 / 100-500)
-- เพดานเป็นของผู้ใช้ · ขั้นต่ำผมตั้ง (ลดตามสัดส่วนเดิม) · โบนัสแคลนยึดเมือง ×2 ยังคูณทับอยู่ (Quests.server)
QuestConfig.SilverMin = 20
QuestConfig.SilverMax = 100

QuestConfig.GoldMin = 300
QuestConfig.GoldMax = 1000

-- รางวัลของงานหนึ่ง คืน ซิลเวอร์, เงิน
--
-- ปัดเป็นเลขกลมเพื่อให้อ่านบนกระดาษแล้วจำได้ ไม่ใช่ 1147 เหรียญ
function QuestConfig.RewardFor(quest)
	local lo, hi = difficultyRange()
	local t = math.clamp(((quest.gold or lo) - lo) / (hi - lo), 0, 1)
	local silver = math.floor((QuestConfig.SilverMin + t * (QuestConfig.SilverMax - QuestConfig.SilverMin)) / 10 + 0.5) * 10
	local gold = math.floor((QuestConfig.GoldMin + t * (QuestConfig.GoldMax - QuestConfig.GoldMin)) / 50 + 0.5) * 50
	return silver, gold
end

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
