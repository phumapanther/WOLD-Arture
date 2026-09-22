-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_plots_test.lua Server
-- เรียกผ่าน ServerStorage.IslandTest (BindableFunction) เหมือน island_build_test — ตารางที่ได้เป็นสำเนา ต้องอ่านใหม่ทุกครั้ง
-- และเร่งเวลาด้วย SetEntry (แก้สำเนาไม่ถึงของจริง) · ⚠️ โปรไฟล์จริง: เก็บแปลงที่เทสวางคืนตอนจบ
local Players = game:GetService("Players")
local T = game:GetService("ServerStorage"):WaitForChild("IslandTest", 10)
local function A(op, ...) return T:Invoke(op, ...) end
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่น")
local t0 = os.clock()
while not A("Data") and os.clock() - t0 < 20 do task.wait(0.2) end
local data = assert(A("Data"), "ข้อมูลเกาะไม่โหลด")

local uid, placedHere
for _, e in ipairs(data.placed) do if e.id == "FarmPlot" and not e.crop then uid = e.uid break end end
if not uid then
	local s = assert(A("FindSlot", player, "FarmPlot"), "ไม่มีแปลงในกระเป๋า")
	assert(A("Place", player, s, 20, 20, 0))
	data = A("Data")
	uid = data.placed[#data.placed].uid
	placedHere = true
end
local function entry()
	for _, e in ipairs(A("Data").placed) do if e.uid == uid then return e end end
	error("entry หาย uid " .. uid)
end
local model = assert(A("ModelOf", uid))
A("Tick")
assert(model.Soil:FindFirstChild("PlotPrompt"), "ปุ่มแปลง")
assert(A("FindSlot", player, "Seed"), "ต้องมีเมล็ด (ชุดเริ่มต้นให้ 5)")

local seeds = A("Count", player, "Seed")
local ok, why = A("Plant", player, model); assert(ok, "หยอด: " .. tostring(why))
local e = entry()
assert(e.crop and e.at, "บันทึก crop/at")
assert(A("Count", player, "Seed") == seeds - 1, "เมล็ดถูกหัก")
ok, why = A("Plant", player, model); assert(not ok and why == "planted", "หยอดซ้ำ: " .. tostring(why))
ok, why = A("Harvest", player, model); assert(not ok and why == "unripe", "เก็บก่อนสุก: " .. tostring(why))
ok, why = A("Pickup", player, uid); assert(not ok and why == "growing", "เก็บแปลงที่ปลูกอยู่: " .. tostring(why))
A("Tick")
local crop = assert(model:FindFirstChild("Crop"), "โมเดลพืชโผล่")
assert(math.abs(crop:GetScale() - 0.35) < 0.01, "ระยะแรกสเกล 0.35 ได้ " .. crop:GetScale())

assert(A("SetEntry", uid, "at", os.time() - 100000), "เร่งเวลา") -- แก้ของจริงผ่านเซิร์ฟเวอร์
A("Tick")
assert(math.abs(crop:GetScale() - 1) < 0.01, "สุกแล้วสเกล 1 ได้ " .. crop:GetScale())
assert(model.Soil.PlotPrompt.ActionText == "เก็บเกี่ยว", "ป้ายเก็บเกี่ยว ได้ " .. model.Soil.PlotPrompt.ActionText)
local cropItem = e.crop
local before = A("Count", player, cropItem)
ok, why = A("Harvest", player, model); assert(ok, "เก็บเกี่ยว: " .. tostring(why))
assert(A("Count", player, cropItem) > before, "ได้ " .. cropItem .. " เข้ากระเป๋า")
e = entry()
assert(e.crop == nil and e.at == nil, "แปลงว่างอีกครั้ง")
assert(not model:FindFirstChild("Crop"), "โมเดลพืชหาย")
A("Tick")
assert(model.Soil.PlotPrompt.ActionText == "หยอดเมล็ด", "ป้ายกลับเป็นหยอดเมล็ด")
if placedHere then assert(A("Pickup", player, uid), "เก็บแปลงที่เทสวางคืน") end -- โปรไฟล์จริง ไม่ทิ้งของเทสไว้
return "plots ok: " .. cropItem
