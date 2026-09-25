-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_nodes_test.lua Server
-- จุดเก็บเกี่ยวที่สุ่มโผล่บนผืนดิน: โผล่เฉพาะบนดินที่ว่าง · ใช้อุปกรณ์เดียวกับเกมหลัก · เก็บแล้วหายเลย
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local T = game:GetService("ServerStorage"):WaitForChild("IslandTest", 20)
local function A(op, ...) return T:Invoke(op, ...) end
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่น")
local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
local IslandConfig = require(game.ReplicatedStorage.IslandConfig)
local IslandGrid = require(game.ReplicatedStorage.IslandGrid)
local out = {}

local startLive = A("NodeClear") -- เริ่มจากเกาะสะอาด (ของรอบก่อนไม่ปนผล)

----------------------------------------------------------------- เกิดบนดินที่ว่างเท่านั้น
for _ = 1, 40 do A("NodeSpawnOnce") end
local live, soil = A("NodeCount")
assert(soil > 0, "ต้องเจอผืนดิน")
assert(live > 0, "ต้องมีจุดโผล่")

local folder = assert(workspace.WOLD_Island:FindFirstChild("Nodes"), "โฟลเดอร์ Nodes")
local kinds, offSoil, untagged = {}, 0, 0
for _, m in ipairs(folder:GetChildren()) do
	local kind = m:GetAttribute("NodeKind")
	kinds[kind or "?"] = (kinds[kind or "?"] or 0) + 1
	assert(GatherConfig.Nodes[kind], "NodeKind ต้องมีใน GatherConfig: " .. tostring(kind))
	assert(m:GetAttribute("OneShot") == true, "ต้องติด OneShot (เก็บแล้วหายเลย)")
	if not CollectionService:HasTag(m, "WOLD_Node") then untagged += 1 end
	local cx, cz = IslandGrid.cellOf(m:GetPivot().X, m:GetPivot().Z)
	if not IslandGrid.isSoil(cx, cz) then offSoil += 1 end
end
assert(untagged == 0, ("ไม่ติดแท็ก WOLD_Node %d จุด"):format(untagged))
assert(offSoil == 0, ("โผล่นอกผืนดิน %d จุด"):format(offSoil))

local bits = {}
for k, n in pairs(kinds) do bits[#bits + 1] = k .. " x" .. n end
table.sort(bits)
table.insert(out, ("โผล่ %d จุดบนดิน %d ช่อง: %s"):format(live, soil, table.concat(bits, " ")))

----------------------------------------------------------------- อุปกรณ์เดียวกับเกมหลัก + เก็บแล้วหายเลย
local target
for _, m in ipairs(folder:GetChildren()) do
	local cfg = GatherConfig.Nodes[m:GetAttribute("NodeKind")]
	if cfg and cfg.tool == "pickaxe" then target = m break end
end
assert(target, "ต้องมีหิน/แร่สักจุดให้ทดสอบอุปกรณ์")
local kind = target:GetAttribute("NodeKind")

-- ⚠️ `Equip(player, nil)` ไม่ใช่การถอด มันแค่ไม่ทำอะไร — ต้องถอดจริงไม่งั้นยังถือของจากขั้นก่อนอยู่
A("Unequip", player, "weapon")
assert(A("Gather", player, target) ~= true, "มือเปล่าต้องเก็บหิน/แร่ไม่ได้")
assert(target.Parent ~= nil, "เก็บไม่สำเร็จแล้วต้องยังอยู่")

if not A("FindSlot", player, "Pickaxe") then A("Grant", player, "Pickaxe", 1) end
A("Equip", player, assert(A("FindSlot", player, "Pickaxe"), "เสกอีเต้อไม่ได้"))
-- ⚠️ **การขุดใช้ตาราง `roll`** — ทุบสายถ่านหินแล้วส่วนใหญ่ได้ *หิน* ไม่ใช่ถ่านหิน (กติกาเดียวกับ
-- แมพหลักที่ผู้ใช้กำหนดไว้ 2026-09-21) เทสจึงต้องนับของทุกอย่างที่ตารางนั้นออกได้ ไม่ใช่แค่ `item`
local cfg = GatherConfig.Nodes[kind]
local possible = { [cfg.item] = true }
for _, e in ipairs(cfg.roll or {}) do possible[e.item] = true end
local function bagTotal()
	local n = 0
	for id in pairs(possible) do n += (A("Count", player, id) or 0) end
	return n
end
local before = bagTotal()
assert(A("Gather", player, target) == true, "ถืออีเต้อแล้วต้องเก็บได้")
local gained = bagTotal() - before
assert(gained > 0, "ต้องได้ของเข้ากระเป๋า")
local item = "ของจากตารางขุด"
task.wait(0.4) -- OneShot ลบในเฟรมถัดไป
assert(target.Parent == nil, "เก็บแล้วต้องหายไปเลย ไม่ใช่รอเกิดใหม่ที่เดิม")
table.insert(out, ("%s: มือเปล่าไม่ได้ · อีเต้อได้ %s x%d · แล้วหายไปเลย"):format(kind, item, gained))
for id in pairs(possible) do
	local n = (A("Count", player, id) or 0) - (id == cfg.item and 0 or 0)
	if n > 0 then A("Revoke", player, id, n) end -- โปรไฟล์จริง ไม่ทิ้งของเทสไว้
end

----------------------------------------------------------------- ไม่ทับของที่วางไว้
-- วางแปลงผักลงไปหนึ่งแปลง แล้วจุดที่ทับต้องถูกเก็บออกในรอบถัดไป
if (A("Count", player, "FarmPlot") or 0) < 1 then A("Grant", player, "FarmPlot", 1) end
local slot = assert(A("FindSlot", player, "FarmPlot"), "เสกแปลงไม่ได้")
local cx, cz
for _, m in ipairs(folder:GetChildren()) do
	local x, z = IslandGrid.cellOf(m:GetPivot().X, m:GetPivot().Z)
	if A("CanPlaceAt", x, z, 3, 3, 0, "FarmPlot") then cx, cz = x, z break end
end
if cx then
	local ok = A("Place", player, slot, cx, cz, 0)
	assert(ok, "วางแปลงทับจุดเก็บเกี่ยวควรได้ (จุดพวกนี้ไม่ใช่สิ่งกีดขวาง)")
	table.insert(out, ("วางแปลงผักทับช่อง (%d,%d) ได้ · จุดที่ทับจะถูกเก็บออกในรอบถัดไป"):format(cx, cz))
	local uid = A("Data").placed[#A("Data").placed].uid
	assert(A("Pickup", player, uid), "เก็บแปลงที่เทสวางคืน")
end
A("Revoke", player, "FarmPlot", A("Count", player, "FarmPlot") or 0)
A("Revoke", player, "Pickaxe", A("Count", player, "Pickaxe") or 0)

----------------------------------------------------------------- ล้างของเทสออกจากเกาะ
local cleared = A("NodeClear")
assert(#folder:GetChildren() == 0, "ต้องไม่เหลือจุดเทสค้างบนเกาะ")
table.insert(out, ("ล้างจุดเทสคืน %d (เริ่มมา %d) · เพดานจริง %d จุด ทุก %d วิ")
	:format(cleared, startLive, IslandConfig.NodeSpawn.max, IslandConfig.NodeSpawn.everySeconds))
return table.concat(out, "\n")
