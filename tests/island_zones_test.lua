-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_zones_test.lua Server
-- ⚠️ โปรไฟล์จริง: เก็บทุกอย่างที่เทสวางคืนตอนจบ
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local T = game:GetService("ServerStorage"):WaitForChild("IslandTest", 10)
local function A(op, ...) return T:Invoke(op, ...) end
local C = require(game.ReplicatedStorage.IslandConfig)
local G = require(game.ReplicatedStorage.IslandGrid)
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่น")
local t0 = os.clock(); while not A("Data") and os.clock() - t0 < 20 do task.wait(0.2) end
local data = assert(A("Data"))
local before = #data.placed
local out = {}
local function entryOf(uid)
	for _, e in ipairs(A("Data").placed) do if e.uid == uid then return e end end
end

-- หาช่องว่างที่ "ไม่ใช่ดิน" เองแทนการพิมพ์พิกัดตายตัว — เกาะเปลี่ยนรูปได้ (ผู้ใช้แต่งเอง) เทสจึงต้องหาที่ยืนเอง
local used = {}
local function freeCell(w, d)
	for cz = -24, 24, 2 do
		for cx = -30, -6, 2 do
			local key = cx .. "," .. cz
			if not used[key] and not G.isSoil(cx, cz) then
				local can = A("CanPlaceAt", cx, cz, w, d)
				if can then
					for i = 0, w do for j = 0, d do used[(cx + i) .. "," .. (cz + j)] = true end end
					return cx, cz
				end
			end
		end
	end
	error("หาช่องว่างไม่เจอ")
end

----------------------------------------------------------------- คอกสัตว์
A("Grant", player, "gold", 50000) -- เทสซื้อสัตว์ ต้องมีเงินของตัวเอง ไม่พึ่งเงินในโปรไฟล์จริง
assert(A("Grant", player, "AnimalPen", 1), "เสกคอก")
local penSlot = assert(A("FindSlot", player, "AnimalPen"))
local px, pz = freeCell(6, 6)
local ok, why = A("Place", player, penSlot, px, pz, 0); assert(ok, ("วางคอกที่ (%d,%d): %s"):format(px, pz, tostring(why)))
local penUid = A("Data").placed[#A("Data").placed].uid
local pen = assert(A("ModelOf", penUid))
A("ZonesTick")
assert(pen:FindFirstChild("PenPrompt", true), "ปุ่มคอก")
local snap = A("PenSnapshot", pen)
assert(#snap.animals == #C.PenAnimals and snap.max == C.PenMax, "สแนปช็อตคอก")
-- ซื้อไก่ 3 ตัว
ok, why = A("PenBuy", player, pen, "Chicken", 3)
assert(ok, "ซื้อไก่: " .. tostring(why))
local live = pen:FindFirstChild("Livestock")
assert(live and #live:GetChildren() == 3, "ซื้อแล้วต้องเกิดทันที 3 ตัว ได้ " .. (live and #live:GetChildren() or -1))
assert(entryOf(penUid).animal == "Chicken", "จำชนิดที่เลี้ยง")
local chick = live:GetChildren()[1]
assert(CollectionService:HasTag(chick, "WOLD_Node") and chick:GetAttribute("NodeKind") == "Chicken", "ไก่ติดแท็ก")
-- **เก็บซ้ำได้แล้ว ไม่ใช่เก็บครั้งเดียวหาย** (ผู้ใช้เลือก 2026-09-22) — `HerdAnimal` คือธงที่สั่ง
-- Gathering ให้ลบตัวนั้นทิ้งหลังเก็บ ตอนนี้ต้องไม่มี และต้องมีคูลดาวน์ของตัวเองแทน
assert(chick:GetAttribute("HerdAnimal") == nil, "ต้องไม่ติด HerdAnimal แล้ว (เก็บซ้ำได้)")
-- **คูลดาวน์เป็นของรายชนิดแล้ว** (ผู้ใช้สั่ง 2026-09-23: 15-45 นาที) ไม่ใช่ค่ากลางตัวเดียว
assert(chick:GetAttribute("RespawnSeconds") == C.PenHarvestFor("Chicken"), "คูลดาวน์เก็บซ้ำของไก่")
assert(chick:GetAttribute("YieldWeighted") == true, "ผลผลิตสุ่มถ่วงน้ำหนัก 1-5")
-- ยังโตไม่พอ: ปุ่มถูกปิด
assert(chick:GetAttribute("Spent") == true, "ตัวที่เพิ่งเกิดต้องยังเก็บไม่ได้")
A("ZonesTick")
assert(chick:GetAttribute("Spent") == true, "ยังไม่ถึงเวลาก็ยังเก็บไม่ได้")
table.insert(out, "คอก: ซื้อไก่ 3 เกิดทันที · ยังโตไม่พอ เก็บไม่ได้")
-- เร่งนาฬิกาของตัวมันเอง แล้วต้องปลดให้เก็บได้
for _, a in ipairs(live:GetChildren()) do a:SetAttribute("ReadyAt", os.time() - 1) end
A("ZonesTick")
assert(chick:GetAttribute("Spent") == nil, "โตแล้วต้องเก็บได้")
-- Gathering ของเกมหลักเป็นคนใส่ปุ่ม ซึ่งมาถึงคนละจังหวะกับการเกิด — รอมันตามให้ทัน แล้วปลดอีกรอบ
local anyPrompt, waited = false, os.clock()
while not anyPrompt and os.clock() - waited < 8 do
	A("ZonesTick")
	for _, d in ipairs(chick:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Enabled then anyPrompt = true end
	end
	if not anyPrompt then task.wait(0.5) end
end
assert(anyPrompt, "ปุ่มเก็บต้องเปิด (Gathering ใส่ปุ่มให้แล้ว)")
table.insert(out, "โตแล้วปุ่มเก็บเปิด ✓ (เก็บซ้ำได้ มีคูลดาวน์)")

-- **เก็บจริงแล้วต้องยังอยู่ แต่เก็บซ้ำทันทีไม่ได้** — หัวใจของสิ่งที่ผู้ใช้สั่งรอบนี้
-- เรียก `Gather` ฝั่งเซิร์ฟเวอร์ตรงๆ เพราะกด E จากเครื่องมือทำไม่ได้ (ProximityPrompt จำลองไม่ได้)
-- ⚠️ **ล้างธงแสงก่อนวัด** — ของเรืองแสงฟ้าให้วัตถุดิบสองเท่า (ผู้ใช้สั่ง 2026-09-23) ซึ่งถูกต้อง
-- แต่เทสข้อนี้วัด `PenYield` ไม่ได้วัดแสง · ไม่ล้างแล้วมันจะตกเป็นครั้งคราวแบบหาสาเหตุยาก
chick:SetAttribute("Glow", nil)
local eggBefore = A("Count", player, "Egg") or 0
local gathered = A("Gather", player, chick)
assert(gathered, "เก็บไข่ไม่สำเร็จ")
assert(chick.Parent ~= nil, "เก็บแล้วสัตว์ต้องยังอยู่ ไม่ใช่หายไป")
local gained = (A("Count", player, "Egg") or 0) - eggBefore
assert(gained >= 1 and gained <= 5, ("ได้ไข่ %d ฟอง ต้องอยู่ในช่วง 1-5"):format(gained))
assert(chick:GetAttribute("Spent") == true, "เก็บแล้วต้องติดคูลดาวน์")
A("ZonesTick")
assert(chick:GetAttribute("Spent") == true, "ZonesTick ต้องไม่ปลดคูลดาวน์ให้ (Gathering เป็นเจ้าของ)")
A("Revoke", player, "Egg", gained) -- โปรไฟล์จริง ไม่ทิ้งของเทสไว้
table.insert(out, ("เก็บซ้ำได้: ไข่ %d ฟอง · สัตว์ยังอยู่ · ติดคูลดาวน์ %d นาที (ของไก่ ไม่ใช่ค่ากลาง)")
	:format(gained, chick:GetAttribute("RespawnSeconds") / 60))
-- ซื้อชนิดอื่นทับไม่ได้
ok, why = A("PenBuy", player, pen, "Cow", 1); assert(not ok, "ต้องห้ามเลี้ยงสองชนิด")
-- เพดาน PenMax: ซื้อเกินแล้วต้องได้แค่ที่ว่าง
ok = A("PenBuy", player, pen, "Chicken", 20)
assert(#live:GetChildren() == C.PenMax, ("เพดาน %d ได้ %d"):format(C.PenMax, #live:GetChildren()))
ok, why = A("PenBuy", player, pen, "Chicken", 1)
assert(not ok and why:find("เต็ม"), "คอกเต็มต้องปฏิเสธ: " .. tostring(why))
table.insert(out, ("เพดาน %d ตัว ✓ ชนิดเดียวต่อคอก ✓"):format(C.PenMax))

----------------------------------------------------------------- โซนแร่
assert(A("Grant", player, "MineZone", 1), "เสกโซนแร่")
local mineSlot = assert(A("FindSlot", player, "MineZone"))
local mx, mz = freeCell(5, 6)
ok, why = A("Place", player, mineSlot, mx, mz, 0); assert(ok, ("วางโซนแร่ที่ (%d,%d): %s"):format(mx, mz, tostring(why)))
local mineUid = A("Data").placed[#A("Data").placed].uid
local mine = assert(A("ModelOf", mineUid))
A("ZonesTick")
local rocks = mine:FindFirstChild("Rocks")
assert(rocks and #rocks:GetChildren() >= 1, "ก้อนแรกต้องมาทันที")
local rock = rocks:GetChildren()[1]
assert(CollectionService:HasTag(rock, "WOLD_Node") and rock:GetAttribute("NodeKind"), "ก้อนแร่ติดแท็ก")
-- เร่งรอบถัดไป
A("SetEntry", mineUid, "nextAt", os.time() - 1)
A("ZonesTick")
-- **เกิดทีละ 1-2 ก้อนแบบสุ่มแล้ว** (ผู้ใช้สั่ง 2026-09-23) ของเดิมเป็นเลขตายตัว `MinePerRound`
assert(#rocks:GetChildren() >= 1 + C.MinePerRoundMin,
	("รอบถัดไปต้องเพิ่มอย่างน้อย %d ก้อน ได้ %d"):format(C.MinePerRoundMin, #rocks:GetChildren()))
table.insert(out, ("โซนแร่: ก้อนแรกทันที + รอบละ %d-%d ทุก %d นาที (ตอนนี้ %d ก้อน)")
	:format(C.MinePerRoundMin, C.MinePerRoundMax, C.MineEverySeconds / 60, #rocks:GetChildren()))

----------------------------------------------------------------- ต้นไม้
assert(A("Grant", player, "Deco_Tree", 1), "เสกต้นไม้")
local treeSlot = assert(A("FindSlot", player, "Deco_Tree"))
local tx, tz = freeCell(2, 2)
ok, why = A("Place", player, treeSlot, tx, tz, 0); assert(ok, ("วางต้นไม้ที่ (%d,%d): %s"):format(tx, tz, tostring(why)))
local treeUid = A("Data").placed[#A("Data").placed].uid
local tree = assert(A("ModelOf", treeUid))
A("ZonesTick")
assert(not CollectionService:HasTag(tree, "WOLD_Node"), "ต้นกล้ายังตัดไม่ได้")
A("SetEntry", treeUid, "at", os.time() - C.TreeGrowSeconds - 10)
A("ZonesTick")
assert(CollectionService:HasTag(tree, "WOLD_Node") and tree:GetAttribute("NodeKind") == "Tree", "โตแล้วตัดได้")
assert(math.abs(tree:GetScale() - 1) < 0.02, "โตเต็มสเกล 1 ได้ " .. tree:GetScale())
table.insert(out, "ต้นไม้: ต้นกล้าตัดไม่ได้ → โตเต็มที่ติดแท็ก Tree")

----------------------------------------------------------------- เก็บคืนทุกชิ้น
local d = A("Data")
-- ⚠️ **คอกที่ยังมีสัตว์อยู่เก็บคืนไม่ได้แล้ว** (กันทิ้งฝูงที่จ่ายเงินซื้อมา — เพิ่ม 2026-09-23)
-- เทสจึงต้องล้างฝูงของตัวเองก่อน · ล้าง `herd` ในโปรไฟล์ด้วย ไม่งั้น tick ถัดไปคืนสัตว์กลับมาให้อีก
for i = #d.placed, before + 1, -1 do
	local e = d.placed[i]
	if e.herd or e.animal then
		A("SetEntry", e.uid, "herd", nil)
		A("SetEntry", e.uid, "animal", nil)
		local m = A("ModelOf", e.uid)
		local live = m and m:FindFirstChild("Livestock")
		for _, a in ipairs(live and live:GetChildren() or {}) do a:Destroy() end
	end
end
d = A("Data")
for i = #d.placed, before + 1, -1 do A("Pickup", player, d.placed[i].uid) end
assert(#A("Data").placed == before, "เกาะกลับมาเท่าก่อนเทส")
return table.concat(out, "\n")
