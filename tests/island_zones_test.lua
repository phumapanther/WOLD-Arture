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
assert(#snap.animals == #C.PenAnimals and snap.max == 10, "สแนปช็อตคอก")
-- ซื้อไก่ 3 ตัว
ok, why = A("PenBuy", player, pen, "Chicken", 3)
assert(ok, "ซื้อไก่: " .. tostring(why))
local e = entryOf(penUid)
assert(e.animal == "Chicken" and e.queue == 3, "คิวสัตว์ " .. tostring(e.queue))
-- เร่งเวลาให้เกิดทีละตัวครบ
for i = 1, 3 do
	A("SetEntry", penUid, "nextAt", os.time() - 1)
	A("ZonesTick")
end
local live = pen:FindFirstChild("Livestock")
assert(live and #live:GetChildren() == 3, "ไก่เกิดครบ 3 ได้ " .. (live and #live:GetChildren() or -1))
local chick = live:GetChildren()[1]
assert(CollectionService:HasTag(chick, "WOLD_Node") and chick:GetAttribute("NodeKind") == "Chicken", "ไก่ติดแท็ก")
table.insert(out, "คอก: ซื้อไก่ 3 เกิดครบ ติดแท็กกด E ได้")
-- ซื้อชนิดอื่นทับไม่ได้
ok, why = A("PenBuy", player, pen, "Cow", 1); assert(not ok, "ต้องห้ามเลี้ยงสองชนิด")
-- เพดาน 10
ok = A("PenBuy", player, pen, "Chicken", 20)
assert(entryOf(penUid).queue + #live:GetChildren() <= C.PenMax, "เกินเพดาน")
table.insert(out, "เพดาน 10 ตัว ✓ ชนิดเดียวต่อคอก ✓")

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
assert(#rocks:GetChildren() >= 1 + C.MinePerRound, ("รอบถัดไปต้องเพิ่ม %d ก้อน ได้ %d"):format(C.MinePerRound, #rocks:GetChildren()))
table.insert(out, ("โซนแร่: ก้อนแรกทันที + รอบละ %d (ตอนนี้ %d ก้อน)"):format(C.MinePerRound, #rocks:GetChildren()))

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
for i = #d.placed, before + 1, -1 do A("Pickup", player, d.placed[i].uid) end
assert(#A("Data").placed == before, "เกาะกลับมาเท่าก่อนเทส")
return table.concat(out, "\n")
