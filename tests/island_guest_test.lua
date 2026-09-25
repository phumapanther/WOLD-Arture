-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_guest_test.lua Server
--
-- เพื่อนที่มาเยี่ยมเกาะ (ผู้ใช้สั่ง 2026-09-23): "เก็บฟาร์มสัตว์และฟาร์มผักเราได้ รวมถึงเก็บรวบรวม
-- วัตถุดิบได้ทุกชนิด ... แต่ใช้เครื่องใช้อุปกรณ์ พวกเตาทำอาหารตู้เย็น NPC บอร์ดเควส และอื่นๆ เราไม่ได้"
--
-- ⚠️ Studio มีผู้เล่นคนเดียวและไม่มี `FarmOwnerId` — สวมบทแขกด้วย `PretendGuest` ซึ่งสลับ
-- `IslandAccess.IsOwner` ตัวเดียวกับที่ด่านจริงทุกด่านถาม
local Players = game:GetService("Players")
local T = game:GetService("ServerStorage"):WaitForChild("IslandTest", 20)
local function A(op, ...) return T:Invoke(op, ...) end
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่น")
local C = require(game.ReplicatedStorage.IslandConfig)
local out = {}

local t0 = os.clock()
while not A("Data") and os.clock() - t0 < 20 do task.wait(0.2) end
assert(A("Data"), "ข้อมูลเกาะไม่โหลด")

----------------------------------------------------------------- เตรียมแปลงผักที่สุกแล้วหนึ่งแปลง
if (A("Count", player, "FarmPlot") or 0) < 1 then A("Grant", player, "FarmPlot", 1) end
local slot = assert(A("FindSlot", player, "FarmPlot"), "เสกแปลงไม่ได้")
local cx, cz
for x = -20, 20 do
	for z = -20, 20 do
		if A("CanPlaceAt", x, z, 3, 3, 0, "FarmPlot") then cx, cz = x, z break end
	end
	if cx then break end
end
assert(cx, "ไม่มีที่ว่างพอวางแปลง")
assert(A("Place", player, slot, cx, cz, 0))
local uid = A("Data").placed[#A("Data").placed].uid
local plot = assert(A("ModelOf", uid), "โมเดลแปลง")

if (A("Count", player, C.SeedItem) or 0) < 1 then A("Grant", player, C.SeedItem, 1) end
assert(A("Plant", player, plot), "เจ้าของต้องปลูกได้")
A("SetEntry", uid, "at", os.time() - 99999) -- สุกแล้ว
local function entry()
	for _, e in ipairs(A("Data").placed) do if e.uid == uid then return e end end
end
local crop = assert(entry().crop, "ต้องมีพืชอยู่ในแปลง")
table.insert(out, ("เจ้าของ: วางแปลงที่ (%d,%d) แล้วปลูก %s สำเร็จ"):format(cx, cz, crop))

----------------------------------------------------------------- สวมบทแขก
assert(A("MayUseFixtures", player) == true, "เจ้าของต้องใช้ของบนเกาะได้")
A("PretendGuest", true)
assert(A("MayUseFixtures", player) == false, "แขกต้องใช้ของบนเกาะไม่ได้")

-- เก็บผักได้ (นี่คือ "ขโมย" ที่ผู้ใช้สั่ง)
local before = A("Count", player, crop) or 0
local ok, why = A("Harvest", player, plot)
assert(ok, "แขกต้องเก็บผักได้: " .. tostring(why))
assert((A("Count", player, crop) or 0) > before, "ของต้องเข้ากระเป๋าแขก")
table.insert(out, "แขก: เก็บผักของเจ้าบ้านได้ ✓")

-- แต่ปลูกใหม่ในแปลงเขาไม่ได้
if (A("Count", player, C.SeedItem) or 0) < 1 then A("Grant", player, C.SeedItem, 1) end
local planted, plantWhy = A("Plant", player, plot)
assert(not planted and plantWhy == "notowner", "แขกต้องปลูกไม่ได้ ได้ " .. tostring(plantWhy))
table.insert(out, "แขก: ปลูกในแปลงของเจ้าบ้านไม่ได้ (" .. tostring(plantWhy) .. ") ✓")

-- และซื้อสัตว์เข้าคอกเขาไม่ได้
local pen
for _, e in ipairs(A("Data").placed) do if e.id == C.PenItem then pen = A("ModelOf", e.uid) break end end
if pen then
	local bought, buyWhy = A("PenBuy", player, pen, "Chicken", 1)
	assert(not bought, "แขกต้องซื้อสัตว์ลงคอกเจ้าบ้านไม่ได้")
	table.insert(out, "แขก: ซื้อสัตว์ลงคอกเจ้าบ้านไม่ได้ (" .. tostring(buyWhy) .. ") ✓")
end

----------------------------------------------------------------- คืนสภาพ + เก็บของเทส
A("PretendGuest", false)
assert(A("MayUseFixtures", player) == true, "ถอดบทแขกแล้วต้องกลับเป็นเจ้าของ")
assert(A("Pickup", player, uid), "เก็บแปลงที่เทสวางคืน")
A("Revoke", player, "FarmPlot", A("Count", player, "FarmPlot") or 0)
A("Revoke", player, C.SeedItem, A("Count", player, C.SeedItem) or 0)
A("Revoke", player, crop, A("Count", player, crop) or 0)
table.insert(out, "เก็บของเทสคืนครบ")
return table.concat(out, "\n")
