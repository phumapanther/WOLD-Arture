-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_build_test.lua Server
-- ⚠️ Studio Play เขียน DataStore จริง — เทสนี้เก็บคืนทุกชิ้นที่มันวางตอนจบ
-- execute_luau อยู่ใน sandbox: require(IslandAccess) ได้สำเนาเปล่า จึงเรียกผ่าน ServerStorage.IslandTest (BindableFunction)
-- ตารางที่ได้กลับมาเป็นสำเนา — อ่านได้ แก้ไม่ถึงของจริง ต้องเรียก A("Data") ใหม่ทุกครั้งที่อยากเห็นค่าล่าสุด
local Players = game:GetService("Players")
local T = game:GetService("ServerStorage"):WaitForChild("IslandTest", 10)
local function A(op, ...) return T:Invoke(op, ...) end
local G = require(game.ReplicatedStorage.IslandGrid)
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่นใน Play")
assert(A("IsOwner", player), "ใน Studio คนแรกต้องเป็นเจ้าของ")
local t0 = os.clock()
while not A("Data") and os.clock() - t0 < 20 do task.wait(0.2) end
local data = assert(A("Data"), "ข้อมูลเกาะไม่โหลด")
assert(data.starter == true, "ธงชุดเริ่มต้น")
local slot = assert(A("FindSlot", player, "FarmPlot"), "ไม่มี FarmPlot ในกระเป๋า")

local before = #data.placed
local ok, why = A("Place", player, slot, 10, 10, 0); assert(ok, "วางแปลง: " .. tostring(why))
data = A("Data")
assert(#data.placed == before + 1, "entry ถูกเพิ่ม")
local uid = data.placed[#data.placed].uid
local model = assert(A("ModelOf", uid), "โมเดลโผล่")
assert(model:GetAttribute("ItemId") == "FarmPlot" and model:GetAttribute("CellX") == 10, "แอตทริบิวต์")
assert(model.PrimaryPart:FindFirstChild("PickupPrompt"), "ปุ่มเก็บ")
local wx, wz = G.centreOf(10, 10, 2, 2, 0)
assert((Vector2.new(model:GetPivot().X, model:GetPivot().Z) - Vector2.new(wx, wz)).Magnitude < 0.01, "pivot ที่กึ่งกลาง footprint")
assert(math.abs(model:GetPivot().Y - 817) < 6, "อยู่บนผิวเกาะ y=" .. model:GetPivot().Y)

slot = assert(A("FindSlot", player, "FarmPlot"))
ok, why = A("Place", player, slot, 11, 11, 0); assert(not ok and why == "occupied", "ทับ: " .. tostring(why))
ok, why = A("Place", player, slot, 58, 0, 0); assert(not ok and why == "edge", "ขอบ: " .. tostring(why))
local sp = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local sx, sz = G.cellOf(sp.Position.X, sp.Position.Z)
ok, why = A("Place", player, slot, sx, sz, 0); assert(not ok and why == "blocked", "จุดเกิด: " .. tostring(why))
ok, why = A("Place", player, 99, 20, 20, 0); assert(not ok and why == "noitem", "ช่องว่าง: " .. tostring(why))

local fence = assert(A("FindSlot", player, "Deco_Fence"), "ไม่มีรั้ว")
local fenceCount = A("Count", player, "Deco_Fence")
ok, why = A("Place", player, fence, 15, 15, 1); assert(ok, "รั้วหมุน: " .. tostring(why))
assert(A("Count", player, "Deco_Fence") == fenceCount - 1, "รั้วถูกหักจากกระเป๋า")

local plotCount = A("Count", player, "FarmPlot")
ok, why = A("Pickup", player, uid); assert(ok, "เก็บ: " .. tostring(why))
assert(A("ModelOf", uid) == nil, "โมเดลหาย")
assert(A("Count", player, "FarmPlot") == plotCount + 1, "แปลงกลับเข้ากระเป๋า")
ok, why = A("Pickup", player, uid); assert(not ok and why == "missing", "เก็บซ้ำ: " .. tostring(why))
ok, why = A("Place", player, A("FindSlot", player, "FarmPlot"), 10, 10, 0); assert(ok, "วางที่เดิมได้อีกหลังเก็บ")

-- เก็บคืนทุกชิ้นที่เทสวาง (โปรไฟล์จริง) — ไล่จากท้ายเพราะ Pickup ถอดออกจาก array
data = A("Data")
for i = #data.placed, before + 1, -1 do
	local e = data.placed[i]
	assert(A("Pickup", player, e.uid), "เก็บคืน uid " .. e.uid)
end
data = A("Data")
assert(#data.placed == before, "เกาะกลับมาเท่าก่อนเทส")
return ("build ok: วางอยู่ %d ชิ้น (เท่าก่อนเทส)"):format(#data.placed)
