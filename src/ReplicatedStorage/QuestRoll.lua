-- QuestRoll: สุ่มงานบนบอร์ดเควสหนึ่งบอร์ดของวันหนึ่ง — ข้อมูลล้วน เทสใน Edit ได้ (tests/quest_roll_test.lua)
--
-- ยกออกมาจาก Quests.server (2026-09-27) เพื่อให้กติกา "งานบังคับ" ของบอร์ดบราสเฮเวนตรวจได้ครบทุกวันโดยไม่ต้องกด Play
local QuestConfig = require(script.Parent.QuestConfig)

local QuestRoll = {}

-- `extra` = จำนวนครั้งที่ **คนคนนั้น** รีบอร์ดด้วยเพชรวันนี้ (0 = ชุดประจำวันที่ทุกคนเห็นเหมือนกัน)
function QuestRoll.Roll(board, day, extra)
	-- สุ่มหยิบจากคลังโดยไม่ซ้ำ: คัดลอกคลังแล้วหยิบออกทีละอัน
	local pool = {}
	for _, spec in ipairs(board.pool) do pool[#pool + 1] = spec end

	-- **เมล็ดสุ่มจากวันที่และชื่อบอร์ด ไม่ใช่สุ่มลอยๆ**
	--
	-- ทุกเซิร์ฟเวอร์ต้องเห็นบอร์ดชุดเดียวกันในวันเดียวกัน ไม่งั้นย้ายช่องแล้วงานเปลี่ยน และรีสตาร์ทเซิร์ฟ
	-- จะกลายเป็นปุ่มสุ่มงานใหม่ — เมล็ดที่คำนวณได้จากวันที่ทำให้ทุกเซิร์ฟเวอร์ได้ผลเดียวกันโดยไม่ต้องคุยกัน
	--
	-- **การรีด้วยเพชรบวกเข้าไปในเมล็ด ไม่ได้สุ่มลอยๆ** (ผู้ใช้สั่ง 2026-09-24) — ชุดที่ N ของคนคนหนึ่ง
	-- จึงคำนวณซ้ำได้เสมอ เซิร์ฟรีสตาร์ทกลางคันก็ยังเห็นชุดเดิม ไม่ใช่ชุดที่สี่ที่เขาไม่ได้จ่าย
	local seed = day
	for i = 1, #board.id do seed += board.id:byte(i) * i end
	seed += (extra or 0) * 7919
	local rng = Random.new(seed)

	-- **งานบังคับของบอร์ด** (`board.mustHave` · ผู้ใช้สั่ง 2026-09-27 บอร์ดบราสเฮเวน): หยิบหนึ่งใบจากกลุ่มนั้นก่อน
	-- แล้ว **ตัดทั้งกลุ่มออกจากคลัง** = มีงานกลุ่มนี้ทุกวันเสมอ แต่ไม่มีวันออกสองใบพร้อมกัน (ล่าสไลม์ + ส่งเมือกสไลม์)
	-- ตำแหน่งของใบบังคับสุ่มเอา ไม่ใช่ช่องแรกเสมอ · ทั้งหมดจาก rng ตัวเดียวกัน ทุกเซิร์ฟจึงยังได้ชุดเดียวกัน
	-- บอร์ดที่ไม่มี mustHave ไม่เรียก rng เพิ่ม = ชุดงานของบอร์ดเดิมทั้งหกไม่เปลี่ยนไปจากก่อนมีกติกานี้
	local forced
	if board.mustHave then
		local group = {}
		for i = #pool, 1, -1 do
			if pool[i].group == board.mustHave then group[#group + 1] = table.remove(pool, i) end
		end
		table.sort(group, function(a, b) return (a.item or a.mob or "") < (b.item or b.mob or "") end)
		if #group > 0 then forced = group[rng:NextInteger(1, #group)] end
	end
	local slots = math.min(QuestConfig.SlotsPerBoard, #pool + (forced and 1 or 0))
	local forcedAt = forced and rng:NextInteger(1, slots) or nil

	local quests = {}
	for slot = 1, slots do
		local pick
		if slot == forcedAt then
			pick = forced
		else
			pick = table.remove(pool, rng:NextInteger(1, #pool))
		end
		-- จำนวนถูกสุ่มตอนโพสต์ ไม่ใช่ตอนรับ — ทุกคนที่เห็นบอร์ดนี้จึงเห็นเลขเดียวกัน
		local need = rng:NextInteger(pick.min, pick.max)
		quests[#quests + 1] = {
			kind = pick.kind,
			item = pick.item,
			mob = pick.mob,
			need = need,
			gold = pick.gold,
			xp = pick.xp,
			board = board.id,
		}
	end
	return quests
end

return QuestRoll
