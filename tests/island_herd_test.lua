-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_herd_test.lua Server
--
-- สัตว์ในคอกต้องอยู่ข้ามการรีสตาร์ท (ผู้ใช้แจ้ง 2026-09-23: ซื้อทิ้งไว้แล้วออกเกม กลับมาสัตว์หาย)
--
-- ⚠️ **ทดสอบการ "ออกเกมแล้วกลับมา" ตรงๆ ไม่ได้** — ของในโปรไฟล์ที่แก้ระหว่าง Studio Play ไม่ถูกเซฟ
-- (วัดไว้แล้ว 2026-09-22) · แต่สิ่งที่ต้องพิสูจน์คือ **ทางคืนสัตว์** ซึ่งจำลองได้ตรงกว่า: ล้างโฟลเดอร์
-- `Livestock` ทิ้ง = สภาพเดียวกับเซิร์ฟที่เพิ่งบูต (workspace ว่าง แต่โปรไฟล์ยังมีฝูง) แล้วดูว่ามันคืนไหม
local Players = game:GetService("Players")
local T = game:GetService("ServerStorage"):WaitForChild("IslandTest", 20)
local function A(op, ...) return T:Invoke(op, ...) end
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่น")
local C = require(game.ReplicatedStorage.IslandConfig)
local out = {}

local t0 = os.clock()
while not A("Data") and os.clock() - t0 < 20 do task.wait(0.2) end
local data = assert(A("Data"), "ข้อมูลเกาะไม่โหลด")

-- หาคอกที่ว่างอยู่ ไม่มีก็วางเอง (เทสต้องไม่พึ่งของในกระเป๋าผู้ใช้)
local penUid, placedHere
for _, e in ipairs(data.placed) do
	if e.id == C.PenItem and not e.animal then penUid = e.uid break end
end
if not penUid then
	if (A("Count", player, C.PenItem) or 0) < 1 then A("Grant", player, C.PenItem, 1) end
	local slot = assert(A("FindSlot", player, C.PenItem), "เสกคอกไม่ได้")
	local cx, cz
	for x = -20, 20 do
		for z = -20, 20 do
			if A("CanPlaceAt", x, z, 6, 6, 0, C.PenItem) then cx, cz = x, z break end
		end
		if cx then break end
	end
	assert(cx, "ไม่มีที่ว่างพอวางคอก")
	assert(A("Place", player, slot, cx, cz, 0))
	penUid = A("Data").placed[#A("Data").placed].uid
	placedHere = true
end
local pen = assert(A("ModelOf", penUid), "โมเดลคอก")
local function entry()
	for _, e in ipairs(A("Data").placed) do if e.uid == penUid then return e end end
end
local function livestock() return pen:FindFirstChild("Livestock") end

----------------------------------------------------------------- ซื้อแล้วต้องถูกจดลงโปรไฟล์ทันที
A("Grant", player, "gold", 5000) -- ใช้เงินของเทสเอง ไม่แตะเงินจริง
local ok, why = A("PenBuy", player, pen, "Chicken", 2)
assert(ok, "ซื้อไก่: " .. tostring(why))
assert(#livestock():GetChildren() == 2, "ต้องมีไก่ 2 ตัวในคอก")

local herd = entry().herd
assert(herd and #herd == 2, "ต้องจดฝูงลงโปรไฟล์ทันทีที่ซื้อ ได้ " .. tostring(herd and #herd))
for _, h in ipairs(herd) do
	assert(h.b and h.r, "แต่ละตัวต้องมีเวลาเกิดกับเวลาโต")
	assert(not h.g, "เพิ่งซื้อต้องยังไม่โต")
end
table.insert(out, ("ซื้อไก่ 2 ตัว → จดลงโปรไฟล์ %d ตัว"):format(#herd))

----------------------------------------------------------------- โตแล้วโปรไฟล์ต้องรู้
for _, a in ipairs(livestock():GetChildren()) do a:SetAttribute("ReadyAt", os.time() - 1) end
A("ZonesTick")
for _, a in ipairs(livestock():GetChildren()) do
	assert(a:GetAttribute("Grown") == true, "โตแล้วต้องติดธง Grown")
	assert(math.abs(a:GetScale() - 1) < 0.02, "โตแล้วต้องเต็มสเกล ได้ " .. a:GetScale())
end
herd = entry().herd
assert(herd and #herd == 2, "ฝูงยังต้องครบ")
for _, h in ipairs(herd) do assert(h.g, "โปรไฟล์ต้องรู้ว่าโตแล้ว") end
table.insert(out, "โตเต็มวัย → โปรไฟล์จดธง Grown ตาม")

----------------------------------------------------------------- จำลองรีสตาร์ท: คอกว่าง โปรไฟล์ยังมีฝูง
for _, a in ipairs(livestock():GetChildren()) do a:Destroy() end
assert(#livestock():GetChildren() == 0, "ล้างคอกแล้ว")
assert(entry().herd and #entry().herd == 2, "โปรไฟล์ต้องยังจำฝูงไว้ (นี่คือจุดที่เคยหาย)")

A("ZonesTick")
local back = livestock():GetChildren()
assert(#back == 2, ("ต้องคืนสัตว์ครบ 2 ตัว ได้ %d"):format(#back))
for _, a in ipairs(back) do
	assert(a.Name == "Chicken", "ชนิดต้องเหมือนเดิม")
	assert(a:GetAttribute("Grown") == true, "ตัวที่โตแล้วต้องกลับมาโตแล้ว ไม่ใช่เริ่มนับใหม่")
	-- ⚠️ กับดักที่เจอตอนเขียน: `ScaleTo(PenBabyScale)` เคยรันทุกตัว ตัวเต็มวัยจึงค้างครึ่งตัวถาวร
	assert(math.abs(a:GetScale() - 1) < 0.02, "ตัวที่โตแล้วต้องกลับมาเต็มสเกล ได้ " .. a:GetScale())
	assert(not a:GetAttribute("Spent"), "ตัวที่ไม่ได้ติดคูลดาวน์ต้องเก็บได้เลย")
end
table.insert(out, "ล้างคอก (=รีสตาร์ท) → คืนครบ 2 ตัว โตแล้ว เต็มสเกล")

----------------------------------------------------------------- คูลดาวน์ที่ค้างมาต้องหมดอายุเองได้
local one = back[1]
-- ⚠️ **รอให้ Gathering ใส่ปุ่มก่อน** มันผูกจากแท็กแบบ async (`GetInstanceAddedSignal` + `task.spawn`)
-- สัตว์ที่เพิ่งถูกคืนมาจึงยังไม่มีปุ่มในเฟรมเดียวกัน — เช็คเร็วไปจะฟ้องว่า "ปุ่มไม่เปิด" ทั้งที่ยังไม่มีปุ่ม
local function promptOf(a)
	for _, d in ipairs(a:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Name == "GatherPrompt" then return d end
	end
end
local waited = os.clock()
while not promptOf(one) and os.clock() - waited < 10 do task.wait(0.3) end
assert(promptOf(one), "Gathering ต้องใส่ปุ่มให้สัตว์ที่ถูกคืนมา")

one:SetAttribute("Spent", true)
one:SetAttribute("ReadyAgainAt", os.time() + 99999)
A("ZonesTick")
assert(one:GetAttribute("Spent") == true, "ยังไม่ถึงเวลา ต้องยังเก็บไม่ได้")
one:SetAttribute("ReadyAgainAt", os.time() - 1)
A("ZonesTick")
assert(not one:GetAttribute("Spent"), "ครบเวลาแล้ว tickPen ต้องปลดให้ (task.delay ของ Gathering ตายไปกับเซิร์ฟเก่า)")
assert(promptOf(one).Enabled, "ต้องเปิดปุ่มคืนด้วย ไม่งั้นได้สัตว์ที่กดไม่ได้ตลอดไป")
table.insert(out, "คูลดาวน์ที่ค้างข้ามรีสตาร์ท → หมดอายุเองแล้วปุ่มกลับมา")

----------------------------------------------------------------- คอกที่ยังมีสัตว์ เก็บคืนไม่ได้
-- สัตว์ไม่หายตอนถูกเก็บเกี่ยวอีกแล้ว คอกจึงไม่มีวันว่างเอง — การเก็บคอกจะทิ้งฝูงทั้งฝูงแบบเงียบๆ
local canPick, pickWhy = A("Pickup", player, penUid)
assert(not canPick and pickWhy == "livestock", "คอกที่มีสัตว์ต้องเก็บไม่ได้ ได้ " .. tostring(pickWhy))
table.insert(out, "คอกที่ยังมีสัตว์อยู่ เก็บคืนไม่ได้ (กันทิ้งฝูงที่จ่ายเงินซื้อมา)")

----------------------------------------------------------------- เก็บของเทสคืน
-- ⚠️ ต้องล้าง `herd` ด้วย ไม่งั้น tick ถัดไปคืนสัตว์กลับมาให้อีก (ซึ่งถูกแล้วสำหรับเซิร์ฟที่เพิ่งบูต)
A("SetEntry", penUid, "herd", nil)
A("SetEntry", penUid, "animal", nil)
for _, a in ipairs(livestock():GetChildren()) do a:Destroy() end
A("ZonesTick")
assert(#livestock():GetChildren() == 0, "ล้างฝูงเทสออกหมดแล้ว")
if placedHere then
	assert(A("Pickup", player, penUid), "เก็บคอกที่เทสวางคืน")
	A("Revoke", player, C.PenItem, A("Count", player, C.PenItem) or 0)
end
table.insert(out, "เก็บของเทสคืนครบ")
return table.concat(out, "\n")
