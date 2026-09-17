-- Collection: สมุดสะสม — ปลาที่เคยตกได้ และมอนที่เคยฆ่า
--
-- เก็บ **สถิติ ไม่ใช่ของ**: ปลาที่บันทึกไว้ที่นี่ไม่ได้อยู่ในกระเป๋า มันคือบันทึกว่าเคยตกได้แล้ว
-- ขายปลาทิ้งไปก็ยังอยู่ในสมุด ซึ่งเป็นเหตุผลทั้งหมดที่สมุดมีค่า
--
-- **เซฟติดตัวข้ามเซสชัน** ผ่าน profile เหมือนกระเป๋าและเลเวล — สะสมมาสามเดือนแล้วหายตอนออกเกม
-- คือสิ่งเดียวที่ทำให้ระบบสะสมไร้ความหมาย
--
-- รูปข้อมูลตั้งใจให้เล็กที่สุดเท่าที่จะตอบคำถามได้ เพราะมันไปกินโควตา DataStore ร่วมกับทุกอย่างในโปรไฟล์:
--   Fish  = { [itemId] = { n = จำนวนที่ตกได้, best = น้ำหนักที่หนักที่สุด } }
--   Mobs  = { [mobKind] = จำนวนที่ฆ่า }
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)

local Collection = {}

--------------------------------------------------------------------------------
-- อ่าน/เขียนผ่านโปรไฟล์
--------------------------------------------------------------------------------

-- คืนตารางสะสมของผู้เล่น สร้างให้ถ้ายังไม่มี หรือ nil ถ้าโปรไฟล์ยังมาไม่ถึง
--
-- **เขียนลง profile.Data ตรงๆ ไม่ได้เก็บสำเนาไว้ที่นี่** เพราะ PlayerProfile เป็นคนเซฟ ถ้าเก็บสำเนา
-- แยกไว้จะมีความจริงสองชุดที่ต้องคอยให้ตรงกัน และชุดที่อยู่ในมือเราไม่ใช่ชุดที่ถูกเซฟ
local function bookOf(player)
	local data = ProfileAccess.Get(player)
	if not data then return nil end
	if not data.Collection then
		data.Collection = { Fish = {}, Mobs = {} }
	end
	-- โปรไฟล์เก่าที่มี Collection แต่ยังไม่มีสองคีย์นี้ (เผื่อเพิ่มอย่างอื่นทีหลัง)
	data.Collection.Fish = data.Collection.Fish or {}
	data.Collection.Mobs = data.Collection.Mobs or {}
	return data.Collection
end

--------------------------------------------------------------------------------
-- บันทึก
--------------------------------------------------------------------------------

-- ตกปลาได้หนึ่งตัว
function Collection.RecordFish(player, itemId, kg)
	local book = bookOf(player)
	if not book or not itemId then return end

	local entry = book.Fish[itemId]
	if not entry then
		entry = { n = 0, best = 0 }
		book.Fish[itemId] = entry
	end
	entry.n += 1
	-- เก็บเฉพาะตัวที่หนักที่สุด ไม่ได้เก็บทุกตัว — สมุดตอบคำถาม "เคยได้ตัวใหญ่สุดเท่าไหร่"
	-- ไม่ใช่ "ได้ตัวไหนบ้างเมื่อไหร่" ซึ่งจะโตไม่มีที่สิ้นสุด
	if kg and kg > (entry.best or 0) then
		entry.best = kg
	end
end

-- ฆ่ามอนได้หนึ่งตัว
function Collection.RecordMob(player, kind)
	local book = bookOf(player)
	if not book or not kind then return end
	book.Mobs[kind] = (book.Mobs[kind] or 0) + 1
end

--------------------------------------------------------------------------------
-- อ่านออกไปโชว์
--------------------------------------------------------------------------------

-- ภาพรวมสำหรับส่งให้ไคลเอนต์วาด
--
-- ส่งเป็นรายการเรียงแล้ว ไม่ใช่ตารางดิบ: ไคลเอนต์ไม่ควรต้องรู้จักลำดับที่ถูกต้อง และ pairs() ส่งข้าม
-- สายไปแล้วลำดับไม่แน่นอน หน้าจอจะสลับไปมาทุกครั้งที่เปิด
function Collection.Snapshot(player)
	local book = bookOf(player)
	if not book then return nil end

	local fish, mobs = {}, {}
	local fishKinds, fishTotal = 0, 0
	local mobKinds, mobTotal = 0, 0

	for id, entry in pairs(book.Fish) do
		fish[#fish + 1] = { id = id, n = entry.n or 0, best = entry.best or 0 }
		fishKinds += 1
		fishTotal += entry.n or 0
	end
	for kind, n in pairs(book.Mobs) do
		mobs[#mobs + 1] = { id = kind, n = n }
		mobKinds += 1
		mobTotal += n
	end

	-- เรียงจากที่ได้เยอะสุดลงมา ชื่อเป็นตัวตัดสินเมื่อเท่ากัน เพื่อให้ลำดับคงที่ทุกครั้ง
	local function byCount(a, b)
		if a.n ~= b.n then return a.n > b.n end
		return a.id < b.id
	end
	table.sort(fish, byCount)
	table.sort(mobs, byCount)

	return {
		fish = fish, mobs = mobs,
		fishKinds = fishKinds, fishTotal = fishTotal,
		mobKinds = mobKinds, mobTotal = mobTotal,
	}
end

return Collection
