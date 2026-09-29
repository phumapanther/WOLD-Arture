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
	if not A("FindSlot", player, "FarmPlot") then A("Grant", player, "FarmPlot", 1) end
	local s = assert(A("FindSlot", player, "FarmPlot"), "เสกแปลงไม่ได้")
	assert(A("Place", player, s, 22, 4, 0)) -- ต้องอยู่บนผืนดิน
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
-- เมล็ดในชุดเริ่มต้นอาจถูกใช้ไปหมดจากการเทสรอบก่อน — เทสเสกของตัวเองแทนการพึ่งกระเป๋าจริง
if not A("FindSlot", player, "Seed") then A("Grant", player, "Seed", 5) end
assert(A("FindSlot", player, "Seed"), "ต้องมีเมล็ด")

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
local plotScale = model:GetScale() -- แปลงขยาย 1.5 เท่า (2026-09-25) ผักใหญ่ตาม
assert(math.abs(crop:GetScale() - 0.35 * plotScale) < 0.01, "ระยะแรกสเกล 0.35 x แปลง ได้ " .. crop:GetScale())

assert(A("SetEntry", uid, "at", os.time() - 100000), "เร่งเวลา") -- แก้ของจริงผ่านเซิร์ฟเวอร์
A("Tick")
assert(math.abs(crop:GetScale() - plotScale) < 0.01, "สุกแล้วสเกลเท่าแปลง ได้ " .. crop:GetScale())
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
-- **หนอนติดมากับดิน** (ผู้ใช้สั่ง 2026-09-22) — 30% ต่อการเก็บหนึ่งครั้ง
--
-- เทสว่า "หาได้จริงไหม" ไม่ใช่ "เรทตรงไหม": 30 ครั้งที่ 30% พลาดหมดได้ 0.7^30 = 1 ใน 8,000
-- (ถ้าอยากวัดเรทจริงต้องหลายพันครั้ง ซึ่งไม่คุ้มเวลาในเทสที่รันทุกรอบ)
-- ⚠️ **คืนของทุกชิ้นที่ลูปนี้ทำให้เกิด** โปรไฟล์นี้เป็นของผู้ใช้จริง — สามสิบรอบทิ้งผักไว้สี่สิบกว่าชิ้น
-- บวกหนอนบวกเมล็ดที่เสกมา ซึ่งพอให้กระเป๋าเต็มจนเทสรอบหน้าวางของไม่ได้ (เคยเจอมาแล้ว ค้าง 5 ชิ้น)
local ROUNDS = 40
local wormsBefore = A("Count", player, "Worm")
local cropBefore = A("Count", player, cropItem)
local seedBefore = A("Count", player, "Seed")
local harvested = 0
for _ = 1, ROUNDS do
	if not A("FindSlot", player, "Seed") then A("Grant", player, "Seed", 10) end
	if not A("Plant", player, model) then break end
	A("SetEntry", uid, "at", os.time() - 100000)
	if not A("Harvest", player, model) then break end
	harvested += 1
end
assert(harvested == ROUNDS, ("เก็บเกี่ยวได้ %d/%d ครั้ง"):format(harvested, ROUNDS))
local wormsGained = A("Count", player, "Worm") - wormsBefore
assert(wormsGained > 0, ("เก็บ %d ครั้งไม่ได้หนอนเลย — โอกาส 20% · พลาดเองคือ 1 ใน 7,500"):format(ROUNDS))

for _, pair in ipairs({ { "Worm", wormsBefore }, { cropItem, cropBefore }, { "Seed", seedBefore } }) do
	local extra = A("Count", player, pair[1]) - pair[2]
	if extra > 0 then A("Revoke", player, pair[1], extra) end
end

if placedHere then assert(A("Pickup", player, uid), "เก็บแปลงที่เทสวางคืน") end -- โปรไฟล์จริง ไม่ทิ้งของเทสไว้
return ("plots ok: %s · หนอนจาก %d ครั้ง = %d ตัว"):format(cropItem, ROUNDS, wormsGained)
