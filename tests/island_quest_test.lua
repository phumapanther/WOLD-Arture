-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_quest_test.lua Server
--
-- เทสว่าบอร์ดเควสบนเกาะให้งานชุดเดียวกับเกมหลัก และสิทธิ์ "รับแล้ว/ส่งแล้ว" ข้ามเพลสได้จริง
--
-- **อ่านสแนปช็อตของจริง** ผ่าน ServerStorage.QuestTest (BindableFunction) — ทรงเดียวกับ IslandTest
-- เพราะ `require` ใน sandbox ของ execute_luau คืนสำเนาใหม่เสมอ (QuestAccess ที่มันเห็นเป็นตารางว่าง)
-- สิ่งที่ต้องพิสูจน์คือ "สิ่งที่เซิร์ฟเวอร์ส่งให้หน้าจอ" ไม่ใช่ "สิ่งที่คอนฟิกบอกว่าควรเป็น"
--
-- ⚠️ โปรไฟล์จริง: งานที่เทสแตะต้องคืนสภาพเดิมตอนจบ
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local QuestConfig = require(game.ReplicatedStorage.QuestConfig)

local T = assert(game:GetService("ServerStorage"):WaitForChild("QuestTest", 10), "ไม่มีช่องเทส QuestTest")
local function Q(op, ...) return T:Invoke(op, ...) end
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่น")
local out = {}

----------------------------------------------------------------- บอร์ดมีปุ่มจริง
local board, prompt
local t0 = os.clock()
while os.clock() - t0 < 12 do
	for _, m in ipairs(CollectionService:GetTagged("WOLD_QuestBoard")) do
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.Name == "QuestPrompt" then board, prompt = m, d end
		end
	end
	if prompt then break end
	task.wait(0.5)
end
assert(prompt, "บอร์ดเควสต้องมีปุ่ม E (Quests.server เป็นคนใส่ — ไม่มี = สคริปต์ไม่ได้รันบนเกาะ)")
assert(board:GetAttribute("BoardId") == QuestConfig.MainBoardId,
	"บอร์ดบนเกาะต้องเป็นบอร์ดรวม ได้ " .. tostring(board:GetAttribute("BoardId")))
table.insert(out, ("บอร์ด %s = บอร์ดรวม · ปุ่ม E ระยะ %d"):format(board.Name, prompt.MaxActivationDistance))

local BOARD_ID = QuestConfig.MainBoardId

----------------------------------------------------------------- สแนปช็อตของจริง
local snap = assert(Q("Snapshot", player, BOARD_ID), "สร้างสแนปช็อตไม่ได้")
assert(snap.isMain, "ต้องเป็นบอร์ดรวม")
assert(snap.boardName == QuestConfig.MainBoardName, "ชื่อบอร์ด: " .. tostring(snap.boardName))

----------------------------------------------------------------- งานมาจากทุกเมือง ไม่ใช่เมืองเดียว
local towns = {}
for _, q in ipairs(snap.offered) do towns[q.board] = true end
for _, q in ipairs(snap.active) do towns[q.board] = true end
local names = {}
for _, b in ipairs(QuestConfig.Boards) do if towns[b.id] then names[#names + 1] = b.name end end
assert(#names >= 2, ("บอร์ดรวมต้องคายงานหลายเมือง ได้ %d: %s"):format(#names, table.concat(names, ",")))
table.insert(out, ("งานบนบอร์ด %d ใบ จาก %d เมือง: %s")
	:format(#snap.offered + #snap.active, #names, table.concat(names, " · ")))

-- ทุกใบต้องมีเนื้อความ รางวัล และชื่อเมืองต้นทางครบ (หน้าจอวาดจากค่าพวกนี้)
for _, q in ipairs(snap.offered) do
	assert(q.text and q.text ~= "", "ใบงานต้องมีคำอธิบาย")
	assert(q.silver and q.silver > 0 and q.gold and q.gold > 0, "ใบงานต้องบอกรางวัล")
	assert(q.from and q.from ~= "", "บอร์ดรวมต้องบอกว่างานมาจากเมืองไหน")
end
local sample = snap.offered[1]
table.insert(out, ("ตัวอย่าง: [%s] %s · +%d ซิลเวอร์ +%d เหรียญ")
	:format(sample.from, sample.text, sample.silver, sample.gold))

----------------------------------------------------------------- งานที่รับจากเกมหลัก = รับแล้วบนเกาะ
-- **โปรไฟล์ก็อ่านผ่านช่องเทสเหมือนกัน** `require(ProfileAccess)` ใน sandbox คืนสำเนาว่าง (Get = nil)
local heldBefore = #assert(Q("Held", player), "โปรไฟล์ไม่โหลด")
local offeredBefore = #snap.offered

-- เลียนแบบ "รับใบนี้ไปแล้วตอนอยู่เกมหลัก" โดยเขียนลงโปรไฟล์ตรงๆ — ซึ่งคือสิ่งที่ accept() ทำจริง
-- และเป็น DataStore ก้อนเดียวกันทั้งจักรวาล (เพลสเกาะอยู่ universe เดียวกับเกมหลัก)
local pick = snap.offered[1]
assert(Q("AddHeld", player, {
	kind = pick.kind, item = pick.item, mob = pick.mob, need = pick.need,
	gold = pick.gold, xp = pick.xp, board = pick.board, got = 0,
}), "เขียนงานลงโปรไฟล์")

snap = Q("Snapshot", player, BOARD_ID)
assert(#snap.active == heldBefore + 1, ("ต้องขึ้นว่ารับแล้ว %d ใบ ได้ %d"):format(heldBefore + 1, #snap.active))
assert(#snap.offered == offeredBefore - 1, "ใบที่รับแล้วต้องหายจากช่องที่ยังรับได้ (ไม่โชว์ซ้ำสองที่)")
local shown
for _, a in ipairs(snap.active) do if a.text == pick.text then shown = a end end
assert(shown, "ใบที่รับจากเกมหลักต้องขึ้นเนื้อความเดียวกัน")
assert(shown.from == pick.from, "ต้องบอกเมืองต้นทางเดิม ได้ " .. tostring(shown.from))
table.insert(out, ("งาน '%s' [%s] ที่รับจากเกมหลัก → บนเกาะขึ้นช่อง 'รับแล้ว' ทันที (%d/%d)")
	:format(pick.text, pick.from, #snap.active, snap.maxActive))

-- คืนสภาพ
assert(Q("DropHeld", player, heldBefore) == heldBefore, "เก็บงานที่เทสรับคืนแล้ว")

----------------------------------------------------------------- ส่งแล้ววันนี้ = ไม่โผล่ให้รับซ้ำ
-- กุญแจคำนวณโดยเซิร์ฟเวอร์เอง ไม่ใช่เทสเดาสูตร — สูตรเปลี่ยนเมื่อไหร่เทสตามทันเอง
local key = assert(Q("Key", pick), "คำนวณกุญแจไม่ได้")
assert(Q("MarkDone", player, key, true), "ปั๊มตราว่าส่งแล้ว")

snap = Q("Snapshot", player, BOARD_ID)
assert(#snap.offered == offeredBefore - 1, "ใบที่ส่งไปแล้ววันนี้ต้องไม่โผล่ให้รับซ้ำ")
assert(snap.finishedToday >= 1, "ต้องนับว่าทำครบไปแล้ววันนี้ ได้ " .. tostring(snap.finishedToday))
table.insert(out, ("ใบที่ส่งจากเกมหลักแล้ว → บนเกาะรับซ้ำไม่ได้ (ทำครบแล้ววันนี้ %d ใบ)")
	:format(snap.finishedToday))

Q("MarkDone", player, key, false) -- ล้างตราที่เทสปั๊ม

----------------------------------------------------------------- คืนสภาพครบ
snap = Q("Snapshot", player, BOARD_ID)
assert(#snap.offered == offeredBefore and #snap.active == heldBefore, "บอร์ดกลับมาเท่าก่อนเทส")
table.insert(out, "เก็บของเทสคืนครบ · บอร์ดเท่าเดิม")
return table.concat(out, "\n")
