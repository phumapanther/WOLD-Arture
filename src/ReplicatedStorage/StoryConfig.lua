-- StoryConfig: เนื้อเรื่อง "ผู้มากับแสงวิบวับ" (ผู้ใช้อนุมัติร่าง 2026-09-27 · docs/story/01-brasshaven.md) — ข้อมูลล้วน
--
-- ตอนนี้มีบทเดียว: บราสเฮเวน (เมืองหลวง) · บทถัดไป (ซอลต์เมียร์ ...) ต่อท้าย `Chapters` ได้เลย ระบบอ่านทีละบทตามลำดับ
-- ความคืบหน้าอยู่ `profile.Data.Story` = { cut = เห็นคัทซีนแล้ว, ch = { [chapterId] = { step, got, done } },
--   towns = { [townId] = true } (จบบทเมืองนั้น = ปลดบอร์ดเควสเมืองนั้น · QuestConfig.TownOpen), titles = { [titleId] = true } }
-- **ไม่ใช้ `Quests`/`QuestsDone`** — เควสเนื้อเรื่องไม่ใช่งานบนบอร์ด ไม่นับโควตาวันละ 3
local StoryConfig = {}

StoryConfig.Npcs = {
	-- NPC ที่ผูกกับเนื้อเรื่อง: แท็ก `WOLD_StoryNpc` + แอตทริบิวต์ `StoryNpc` = id (mapgen/110_story_brasshaven.lua วาง)
	Lyra = { name = "ไลรา", color = Color3.fromRGB(70, 180, 255) },
	-- หุ่นฟางข้างจุดเกิดแรก (Dummy_Spawn) · ไม่ใช่ WOLD_StoryNpc — ปุ่มอยู่ VipGiftPrompt.server (2026-09-29)
	Oforian = { name = "ออฟาเรียน เทพหุ่นฟาง", color = Color3.fromRGB(255, 214, 120) },
}

--------------------------------------------------------------------------------
-- บทพูด — id → รายการบรรทัด { who = id ของ NPC หรือ nil = คำบรรยาย, text }
--------------------------------------------------------------------------------
StoryConfig.Dialogues = {
	-- ขั้น 1 คุยกับไลรา → ต่อด้วยคำขอของขั้น 2 เลย (ขั้น 2 เริ่มทันทีที่คุยจบ)
	b1 = {
		{ who = "Lyra", text = "ข้าชื่อไลรา ข้าศึกษาวงเวทนี้มาสามปี มันเงียบมาตลอด… จนเช้านี้ที่เครื่องจักรใหญ่ใต้เมืองเร่งรอบ" },
		{ who = "Lyra", text = "ไอน้ำกับเวทไม่ควรมาเจอกัน แต่เจ้าคือหลักฐานว่ามันเจอกันแล้ว" },
		{ who = "Lyra", text = "ถ้าเจ้าอยากรู้ว่าตัวเองเป็นใคร ช่วยข้าเก็บข้อมูลก่อน เวทที่รั่วจากวงนี้ไหลไปที่ไหน มันทิ้งร่องรอยไว้ที่นั่น" },
		{ who = "Lyra", text = "สไลม์รอบเมืองดูดเวทที่รั่วออกไปเหมือนฟองน้ำ เอาเมือกสไลม์มาให้ข้า 5 ก้อน เมือกของพวกมันจะบอกข้าว่าเวทแรงแค่ไหน" },
	},
	b2_wait = {
		{ who = "Lyra", text = "เมือกสไลม์ 5 ก้อนนะ — สไลม์มีอยู่รอบนอกเมือง ตีมันแล้วเก็บเมือกมา" },
	},
	-- ขั้น 2 ส่งเมือกครบ → คำขอของขั้น 3
	b2 = {
		{ who = "Lyra", text = "ได้แล้ว… ให้ข้าดูหน่อย" },
		{ who = "Lyra", text = "…ผลออกมาแย่กว่าที่คิด เวทนี้ไม่ได้ปลุกแค่เจ้า — มันปลุกคนที่ตายไปแล้วด้วย" },
		{ who = "Lyra", text = "โครงกระดูกที่เดินอยู่นอกเมืองพวกนั้น เคยเป็นคนแบบเจ้า ช่วยให้พวกเขาได้พักเถอะ — สักสามร่าง" },
	},
	b3_wait = {
		{ who = "Lyra", text = "โครงกระดูกอยู่นอกเมือง ช่วยให้พวกเขาได้พักสามร่าง แล้วค่อยกลับมา" },
	},
	-- ล่าครบ → คำบรรยายสั้นๆ (ไม่มีใครพูด) พาไปจุดหมาย
	b3_done = {
		{ text = "ร่างสุดท้ายสลายเป็นผงแสง… ประกายรอบตัวคุณสั่นไหวเหมือนถูกเรียก" },
		{ text = "มีบางอย่างอยู่ที่อนุสาวรีย์กลางเมือง — ไปที่นั่น" },
	},
	b4_wait = {
		{ who = "Lyra", text = "ประกายรอบตัวเจ้ากำลังชี้ไปทางอนุสาวรีย์กลางเมือง ลองไปยืนตรงนั้นดู" },
	},
	-- ขั้น 5 กลับมาหาไลรา → จบบท
	b5 = {
		{ who = "Lyra", text = "เจ้าเห็นห้องทดลอง? …งั้นตำนานก็จริง" },
		{ who = "Lyra", text = "คนในยุคก่อนถูกทดลองจนกลายเป็นเวทวิญญาณ แล้วถูกผนึกไว้ในวงเวท" },
		{ who = "Lyra", text = "วงแบบนี้ไม่ได้มีวงเดียว ข้าได้ยินว่าที่ซอลต์เมียร์ ชาวประมงเห็นแสงแบบเดียวกันใต้น้ำ" },
		{ who = "Lyra", text = "ถ้าความทรงจำของเจ้ากระจายอยู่ มันน่าจะอยู่ที่นั่น — แต่ก่อนออกเดินทาง ไปช่วยคนที่บอร์ดเควสก่อน เมืองนี้ต้องการคนแบบเจ้า" },
	},
	done = {
		{ who = "Lyra", text = "ข้ายังเฝ้าวงเวทนี้อยู่ ถ้าเจ้าได้ข่าวจากซอลต์เมียร์ เล่าให้ข้าฟังด้วย" },
	},
	-- ออฟาเรียน เทพหุ่นฟาง (2026-09-29 ผู้ใช้อนุมัติบทพูด)
	o_idle = {
		{ who = "Oforian", text = "ทุ่งนายังเขียวดีอยู่… เจ้าเองก็เติบโตต่อไปนะ" },
	},
	o_newcomer = {
		{ who = "Oforian", text = "ข้าคือออฟาเรียน ผู้เฝ้าทุ่งนาแห่งอาร์ตูร์มาตั้งแต่ก่อนเมืองนี้จะมีเครื่องจักรสักตัว" },
		{ who = "Oforian", text = "ผู้มาใหม่ทุกคนที่ผ่านหน้าข้าไป ข้าจะมอบพรเล็กๆ ติดตัวไว้เสมอ" },
		{ who = "Oforian", text = "รับม้วนพรแห่งฤดูกาลนี้ไป — ทุกครั้งที่เจ้าเติบโต มันจะตอบแทนเจ้า" },
	},
	o_sky = {
		{ who = "Oforian", text = "ข้าเฝ้ามองเจ้ามาตลอด ตั้งแต่วันแรกที่เจ้าหยิบจอบขึ้นมา" },
		{ who = "Oforian", text = "ห้าก้าวแห่งการเติบโต… น้อยคนนักจะเดินมาได้ไกลขนาดนี้โดยไม่หยุด" },
		{ who = "Oforian", text = "เหนือเมฆขึ้นไปมีเกาะที่เหล่าเทพใช้พักผ่อน — เกาะลอยฟ้าแห่งความฝัน" },
		{ who = "Oforian", text = "ข้าจะมอบสิทธิ์ให้เจ้าครอบครองมันสามสิบวัน ปลูก เลี้ยง สร้างมันตามใจเจ้า" },
	},
	o_travel = {
		{ who = "Oforian", text = "เจ้าช่วยไลราไขความลับของวงเวทได้แล้ว… ข่าวไปถึงหูข้าเร็วกว่าลมเสียอีก" },
		{ who = "Oforian", text = "การเดินทางของเจ้าเพิ่งเริ่ม รับนี่ไว้เป็นเสบียง — เพชรจากใต้รากทุ่งนาของข้า" },
	},
	o_friends = {
		{ who = "Oforian", text = "ข้าเห็นว่าเจ้าไม่ได้เดินทางคนเดียวอีกแล้ว" },
		{ who = "Oforian", text = "มิตรภาพเป็นสิ่งที่แม้แต่เทพก็สร้างเองไม่ได้ ข้าจึงอยากให้มันมีแสงให้คนอื่นเห็น" },
		{ who = "Oforian", text = "รับแสงนี้ไป ให้มันห้อมล้อมเจ้าทุกที่ที่เจ้าไป" },
	},
	island_welcome = {
		{ who = "Oforian", text = "(เสียงของออฟาเรียนลอยมากับลม) ที่นี่เป็นของเจ้าแล้ว ผู้เติบโต" },
		{ who = "Oforian", text = "ดินผืนนี้ตอบแทนคนที่ดูแลมัน — ปลูก เลี้ยง แล้วส่งผลผลิตไปกับรถคันนั้นเถิด" },
	},
}

--------------------------------------------------------------------------------
-- บท
--------------------------------------------------------------------------------
-- step.kind: talk = คุยกับ NPC · deliver = ส่งของ (คุยตอนมีครบ) · hunt = ล่ามอนหลังรับขั้นนี้ (ชื่อไทยตาม GatherConfig) ·
-- reach = ไปยืนในวงของหมุด (`WOLD_StoryMarker` · แอตทริบิวต์ Chapter) แล้วเล่นภาพความทรงจำ
StoryConfig.Chapters = {
	{
		id = "brasshaven", town = "Brasshaven", name = "ความทรงจำแรก", npc = "Lyra",
		title = { id = "story_brasshaven", text = "ผู้ตื่นแห่งบราสเฮเวน", color = Color3.fromRGB(150, 214, 255) },
		reward = { exp = 500, gold = 2000 },
		steps = {
			{ kind = "talk", goal = "คุยกับไลรา", dialogue = "b1" },
			{ kind = "deliver", item = "Slime", need = 5, goal = "นำเมือกสไลม์ไปให้ไลรา", dialogue = "b2", wait = "b2_wait" },
			{ kind = "hunt", mob = "โครงกระดูก", need = 3, goal = "ล่าโครงกระดูก", wait = "b3_wait", after = "b3_done" },
			{ kind = "reach", goal = "ไปที่อนุสาวรีย์กลางเมือง", radius = 9, memory = "m1", wait = "b4_wait" },
			{ kind = "talk", goal = "กลับไปหาไลรา", dialogue = "b5" },
		},
		doneDialogue = "done",
	},
	-- บทถัดไปแบบล็อก (2026-09-29): แถวทองจาง + 🔒 ให้รู้ว่ามีต่อ · วันที่เขียนบทจริง ถอด `locked` แล้วใส่ขั้น/NPC
	{
		id = "saltmere", town = "Saltmere", locked = true, name = "เส้นทางสู่ซอลต์เมียร์",
		goal = "หาคำแนะนำจากเจ้าของฟาร์มเพื่อเดินทางไปยังซอลต์เมียร์", steps = {},
	},
}

-- เควสรองของออฟาเรียน (สีฟ้า) · ของ/ธง/ลำดับอยู่ที่ `VipGift.Quests` · ที่นี่คือชื่อกับบทพูด
StoryConfig.SideQuests = {
	newcomer = { title = "ของขวัญผู้มาใหม่", goal = "ไปพบออฟาเรียน เทพหุ่นฟาง ข้างจุดเกิด", dialogue = "o_newcomer" },
	travel = { title = "ของขวัญการเดินทาง", goal = "ไปพบออฟาเรียน เทพหุ่นฟาง ข้างจุดเกิด", dialogue = "o_travel" },
	friends = { title = "สายใยมิตรภาพ", goal = "ไปพบออฟาเรียน เทพหุ่นฟาง ข้างจุดเกิด", dialogue = "o_friends" },
	sky = { title = "เกาะลอยฟ้าแห่งความฝัน", goal = "ไปพบออฟาเรียน เทพหุ่นฟาง ข้างจุดเกิด", dialogue = "o_sky" },
}
StoryConfig.OforianIdle = "o_idle"

-- คัทซีนรถคาร์โก้ (~24.5 วิ · shot ที่ StoryController รู้จัก: glow truck board rise clouds flash title)
StoryConfig.SkyTitle = "เกาะลอยฟ้าแห่งความฝัน"
StoryConfig.SkySubtitle = "ของขวัญจากออฟาเรียน · 30 วัน"
StoryConfig.SkyCutscene = {
	{ shot = "glow", seconds = 3.5, who = "Oforian", text = "จงไปเถิด ผู้เติบโต…" },
	{ shot = "truck", seconds = 4.5, text = "ไอน้ำพวยพุ่ง ฟ้าแลบแปลบ — รถคันหนึ่งก่อตัวขึ้นจากแสง" },
	{ shot = "board", seconds = 2.5, text = "คุณก้าวขึ้นรถ…" },
	{ shot = "rise", seconds = 5, text = "รถลอยขึ้นเหนือหลังคาบราสเฮเวน" },
	{ shot = "clouds", seconds = 4, text = "ทะลุผ่านเมฆขึ้นไป…" },
	{ shot = "flash", seconds = 1 },
	{ shot = "title", seconds = 4, title = StoryConfig.SkyTitle, subtitle = StoryConfig.SkySubtitle },
}

--------------------------------------------------------------------------------
-- คัทซีนเข้าเกมครั้งแรก (~28 วิ · ผู้เล่นใหม่เท่านั้น · มีปุ่มข้าม)
--------------------------------------------------------------------------------
-- shot: ชื่อมุมกล้องที่ StoryController รู้จัก (black · rooftops · descend · flash · wake · lyra · lyraClose · title)
StoryConfig.Cutscene = {
	{ shot = "black", seconds = 3, text = "…ได้ยินไหม…" },
	{ shot = "rooftops", seconds = 4, text = "เสียงเครื่องจักรไอน้ำของบราสเฮเวนสั่นสะเทือนลงลึกใต้ดิน…" },
	{ shot = "descend", seconds = 4, text = "…ไปปลุกวงเวทที่หลับใหลมานานนับร้อยปี" },
	{ shot = "flash", seconds = 1 },
	{ shot = "wake", seconds = 4.5, text = "คุณตื่นขึ้น… จำไม่ได้แม้แต่ชื่อของตัวเอง" },
	{ shot = "lyra", seconds = 4, who = "Lyra", text = "เข็มมันไม่เคยกระดิกแบบนี้… เจ้า—เจ้าออกมาจากวงเวทนั่นจริงๆ!" },
	{ shot = "lyraClose", seconds = 4, who = "Lyra", text = "ผู้มากับแสงวิบวับ… ตำนานเก่าพูดถึงคนแบบเจ้าไว้" },
	{ shot = "title", seconds = 3.5, title = "WOLD ARTURE", subtitle = "ผู้มากับแสงวิบวับ" },
}
StoryConfig.CutsceneMaxSeconds = 60 -- เซิร์ฟปล่อยตัว (ปลดตรึง) เองถ้าไคลเอนต์ไม่ตอบ

-- ภาพความทรงจำ (ขั้น reach) ~6 วิ: จอขาวซีด ภาพกะพริบ
StoryConfig.Memories = {
	m1 = {
		{ seconds = 2, text = "ห้องหินเย็นเฉียบ…" },
		{ seconds = 2, text = "คนในชุดคลุมขาวก้มมอง…" },
		{ seconds = 2.5, text = "มีคนเรียกชื่อคุณ แต่เสียงขาดหายไปก่อนจะได้ยิน" },
	},
}

-- บทที่กำลังเล่น + ความคืบหน้า (สร้างให้ถ้ายังไม่มี) · เจอบทที่ `locked` = หยุด ไม่สร้างความคืบหน้า คืนเป็นค่าที่สาม (แถวล็อก)
function StoryConfig.Current(story)
	for _, ch in ipairs(StoryConfig.Chapters) do
		if ch.locked then return nil, nil, ch end
		local p = story.ch[ch.id]
		if type(p) ~= "table" then
			p = { step = 1, got = 0 }
			story.ch[ch.id] = p
		end
		if not p.done then return ch, p, nil end
	end
	return nil, nil, nil
end

function StoryConfig.Chapter(id)
	for _, ch in ipairs(StoryConfig.Chapters) do
		if ch.id == id then return ch end
	end
	return nil
end

-- ฉายาเมือง id → { text, color } (Achievements ใช้)
function StoryConfig.Title(id)
	for _, ch in ipairs(StoryConfig.Chapters) do
		if ch.title and ch.title.id == id then return ch.title end
	end
	return nil
end

return StoryConfig
