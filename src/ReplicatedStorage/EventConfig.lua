-- EventConfig: the two things the world does to itself, and everything about how they look and when.
--
-- Shared by server and client. The server owns the schedule and decides what is running; the client reads
-- this only to draw the banner -- the icon, the wording, the colour. Nothing here lets a client decide that
-- an event is happening.
local EventConfig = {}

-- Nobody gets an event in an empty server. Both of these are things that happen TO a town: three mutant
-- slimes and a city-wide power cut are a crowd's problem, and in a server of two they are just an
-- interruption with nobody to share it with.
--
-- The countdown does not even START below this. A server that dips under ten while the clock is running
-- keeps it -- the check is for beginning, not for continuing -- because losing the eleventh player halfway
-- through would otherwise reset a timer nobody can see.
EventConfig.MinPlayers = 10

-- How often the scheduler looks at the clock. Events are measured in tens of minutes; a second's resolution
-- on a half-hour timer costs nothing and keeps the loop trivially simple.
EventConfig.TickSeconds = 1

-- เวลาท้องถิ่นที่ `atHour` หมายถึง — นาฬิกาของเซิร์ฟเวอร์ Roblox เป็น UTC เสมอ ไม่ว่าเครื่องจะตั้งอยู่ที่ไหน
-- ตัวเลขเดียวกับ `QuestConfig.TimeZoneOffsetSeconds` แต่ไม่ได้ require กัน: ระบบเควสเป็นเจ้าของคำว่า
-- "วันนี้" ของมัน ส่วนไฟล์นี้เป็นเจ้าของคำว่า "สองทุ่ม" ของมัน
EventConfig.TimeZoneOffsetSeconds = 7 * 60 * 60

--------------------------------------------------------------------------------

EventConfig.Events = {
	--------------------------------------------------------------------------
	-- The mutant slimes. Three of them at once, for half an hour, every half hour.
	--
	-- Before V1 the three named slimes stood in the world permanently and came back thirty minutes after
	-- they died, which made them a place you visited rather than a thing that happened. As an event they are
	-- the opposite: they are not there at all until the announcement, and they are gone when it ends,
	-- whether anyone killed them or not.
	--------------------------------------------------------------------------
	slime = {
		icon = "rbxassetid://139399362647202", -- assets/item-icons/event_slime.png
		message = "สไลม์กลายพันธุ์",
		sound = "EventSlime",
		colour = Color3.fromRGB(126, 226, 140),
		-- Every half hour, lasting half an hour: one is always either running or half an hour away.
		everySeconds = 30 * 60,
		durationSeconds = 30 * 60,
	},

	--------------------------------------------------------------------------
	-- The city's engines fail.
	--
	-- The only event with no clock on it. It ends when every transformer in the map has been repaired and
	-- not a moment before, which is why the banner's right-hand side shows a count of machines rather than a
	-- countdown -- there is nothing to count down to.
	--------------------------------------------------------------------------
	blackout = {
		icon = "rbxassetid://135773985386159", -- assets/item-icons/event_electric.png
		message = "เครื่องยนต์ไอน้ำ ขัดข้อง",
		sound = "EventBlackout",
		colour = Color3.fromRGB(255, 196, 92),
		-- Random rather than fixed, so it is never something players can stand around waiting for.
		minGapSeconds = 25 * 60,
		maxGapSeconds = 45 * 60,
		-- No durationSeconds on purpose: see above.
	},

	--------------------------------------------------------------------------
	-- บอสโลก: ฟอร์จวอร์เดน ตื่นสองทุ่ม อยู่ 59 นาที
	--
	-- **ต่างจากอีเวนต์อีกสองตัวตรงที่มันไม่ได้นับถอยหลังจากตอนเซิร์ฟบูต แต่ผูกกับนาฬิกาจริง** (`atHour`)
	-- ผู้ใช้กำหนดว่า "เกิดสองทุ่ม" ซึ่งเป็นเวลานัดของคนเล่น ไม่ใช่ช่วงห่าง — ทุกเซิร์ฟที่เปิดอยู่ตอนสองทุ่ม
	-- จึงเห็นบอสพร้อมกัน แทนที่จะเห็นคนละเวลาตามว่าเซิร์ฟไหนบูตเมื่อไหร่
	--
	-- ตัวบอส ตำแหน่ง และรางวัล ไม่ได้อยู่ในนี้ — ดู `EventConfig.WorldBoss` ข้างล่าง
	--------------------------------------------------------------------------
	worldboss = {
		icon = "rbxassetid://89939682004809", -- ศิลาเวท (ยืมมาก่อน ยังไม่มีไอคอนของอีเวนต์นี้เอง)
		message = "ฟอร์จวอร์เดน ตื่นจากเตาหลอม",
		sound = "EventSlime",
		colour = Color3.fromRGB(236, 120, 48),
		-- เวลาไทย ไม่ใช่เวลาของเซิร์ฟเวอร์ Roblox (ซึ่งเป็น UTC เสมอ) — ตัวแปลงคือ `EventConfig.TimeZoneOffsetSeconds`
		atHour = 20,
		durationSeconds = 59 * 60,
		-- เซิร์ฟที่บูตหลังสองทุ่มไปแล้วก็ยังได้บอส แต่ได้ **เวลาที่เหลือจริง** ไม่ใช่ 59 นาทีใหม่ —
		-- ไม่งั้นคนที่เข้าเซิร์ฟใหม่ตอนสามทุ่มจะได้อีเวนต์ของตัวเองที่ไม่ตรงกับใครเลย
		-- เหลือน้อยกว่านี้ก็ข้ามรอบไปเลย: บอสเลือดหมื่นสองที่เหลือห้านาทีคือประกาศที่ไม่มีใครชนะได้
		minRemainingSeconds = 10 * 60,
		-- บอสโลกไม่รอให้เซิร์ฟมีคนครบสิบ ต่างจากสไลม์/ไฟดับ: มันเป็นเวลานัด ถ้าเลื่อนตามจำนวนคน
		-- คนที่มารอตามนัดจะไม่เจออะไรเลย
		minPlayers = 1,
	},
}

--------------------------------------------------------------------------------
-- What a blackout does to the world
--------------------------------------------------------------------------------

-- How much darker every screen gets. A quarter, as the user asked, applied as a ColorCorrection on the
-- CLIENT: Lighting is not replicated per player, and doing it on the server would also darken the lobby and
-- anyone in a menu.
EventConfig.BlackoutDarkness = 0.25

-- How long the screen takes to fall dark and come back. Instant would read as a graphics glitch; this reads
-- as the lamps going out one street at a time.
EventConfig.BlackoutFadeSeconds = 2.5

--------------------------------------------------------------------------------
-- Putting a transformer back together
--------------------------------------------------------------------------------

-- The repair is thirty seconds of standing still while skill checks interrupt you. What makes it a
-- commitment rather than a wait is that WALKING ENDS IT: the whole thirty seconds is lost, not paused.
EventConfig.Repair = {
	Seconds = 30,
	Range = 10,

	-- How far you may drift from where you started before the repair drops. Generous enough to cover the
	-- character settling and a nudge from someone running past, tight enough that a step away is a step away.
	LeaveDistance = 6,

	-- Two to four checks in the thirty seconds, never two in the same breath. The first is held back so the
	-- player has a moment to realise the repair has begun before being asked to react to something.
	MinChecks = 2,
	MaxChecks = 4,
	FirstCheckAfter = 4,
	MinCheckGap = 5,

	-- What a missed check costs. Shorter than the farms' five seconds because the repair can be tried again
	-- immediately -- the punishment is the thirty seconds you just lost, and being rooted on top of that for
	-- five would be punishing the same mistake twice.
	DizzySeconds = 2,

	-- One roll from this table on a finished repair, plus the silver, so every repair is worth something.
	-- "กระดาษ" in the user's list is the blueprint: it is the paper item the game already has.
	Rewards = {
		{ item = "GearSpare", min = 1, max = 2 },
		{ item = "Chemical", min = 1, max = 2 },
		{ item = "Coal", min = 1, max = 2 },
		{ item = "Blueprint", min = 1, max = 1 },
		{ item = "Silver", min = 20, max = 60 },
	},
	-- Coin, on top of whatever the roll gave. The repair is civic work and the city pays for it.
	GoldMin = 150,
	GoldMax = 400,
	Xp = 30,
}

--------------------------------------------------------------------------------
-- บอสโลก — เวลา รางวัล และการจัดอันดับ
--------------------------------------------------------------------------------

-- ทุกอย่างที่ `WorldBoss.server.lua` ต้องรู้ แยกจาก `GatherConfig.Mobs.Forgewarden` ซึ่งเป็นตัวบอสเอง
-- (เลือด ดาเมจ ดรอปตอนฆ่า) — ตรงนี้คือ **อีเวนต์** ที่บังเอิญมีบอสอยู่ข้างใน
EventConfig.WorldBoss = {
	-- ต้องตรงกับแอตทริบิวต์ `MobKind` บนหมุด `workspace.WOLD.BossSpawns.BossSpawn_Forgewarden`
	-- (หมุดคือคนตัดสินว่าบอสไปโผล่ตรงไหน ลากย้ายได้ใน Studio — ดู `mapgen/83_boss_spawner.lua`)
	kind = "Forgewarden",

	--------------------------------------------------------------------------
	-- รางวัล (ผู้ใช้กำหนด: เรียงตามดาเมจมากสุด→น้อยสุด + รางวัลคนลาสฮิต)
	--------------------------------------------------------------------------

	-- ต้องทำดาเมจอย่างน้อยเท่านี้ (สัดส่วนของเลือดบอส) ถึงจะติดอันดับ
	-- ตีหนึ่งทีแล้วยืนดูไม่ใช่การร่วมรบ และถ้าไม่มีด่านนี้ คนที่เดินผ่านมาฟันทิ้งไว้ก็ได้ของเท่าคนที่สู้จริง
	MinDamageFraction = 0.01,

	-- **ตัวเลขทั้งหมดในตารางนี้ผมตั้งเป็นค่าเริ่มต้น ผู้ใช้ยังไม่ได้กำหนด** ปรับได้ตามใจ
	--
	-- `upTo` = อันดับสุดท้ายของช่วงนั้น (1 = ที่หนึ่ง · 3 = ที่สองถึงสาม เพราะช่วงก่อนหน้ากินไปแล้ว)
	-- เรียงจากน้อยไปมาก ช่วงสุดท้ายใช้ `math.huge` = ที่เหลือทั้งหมดที่ผ่านเกณฑ์ดาเมจขั้นต่ำ
	Ranks = {
		{ upTo = 1,         label = "อันดับ 1", gold = 5000, xp = 900,
			items = { { id = "MagicBox", count = 2 }, { id = "RuneStone", count = 5 }, { id = "Silver", count = 400 } } },
		{ upTo = 3,         label = "อันดับ 2-3", gold = 3000, xp = 600,
			items = { { id = "MagicBox", count = 1 }, { id = "RuneStone", count = 3 }, { id = "Silver", count = 250 } } },
		{ upTo = 10,        label = "อันดับ 4-10", gold = 1500, xp = 400,
			items = { { id = "RuneStone", count = 2 }, { id = "Silver", count = 120 } } },
		{ upTo = math.huge, label = "ร่วมรบ", gold = 600, xp = 200,
			items = { { id = "Silver", count = 50 } } },
	},

	-- คนที่ฟันไม้สุดท้าย (ผู้ใช้กำหนด: กล่องเวทมนตร์ 1 กล่อง)
	-- **ได้เฉพาะตอนบอสตายจริง** หมดเวลาแล้วบอสยังยืนอยู่ = ไม่มีไม้สุดท้าย ไม่มีรางวัลข้อนี้
	-- (รางวัลตามอันดับยังจ่ายตามปกติ เพราะผู้ใช้บอกว่า "บอสไม่ต้องตายก็ได้")
	LastHit = { item = "MagicBox", count = 1 },

	-- ประกาศท็อปกี่คนให้ทั้งเซิร์ฟเห็นตอนจบ
	AnnounceTop = 3,
}

return EventConfig
