-- 66_spawner_tuning.lua — ระยะปลุกไกลขึ้น มอนเยอะขึ้นเท่าตัว และกระจายกันมากขึ้น
--
-- รัน: node tools/run-luau.js mapgen/66_spawner_tuning.lua
--
-- **รันซ้ำได้** ตั้งค่าทับของเดิมเสมอ ไม่สะสม (ไม่ได้คูณสองซ้ำทุกครั้งที่รัน — เขียนค่าตรงๆ)
local CollectionService = game:GetService("CollectionService")

local SPAWNER_TAG = "WOLD_Spawner"

-- ระยะที่ผู้เล่นต้องเข้ามาใกล้ก่อนมอนจะเริ่มโผล่
--
-- ลองที่ 200 แล้วไกลเกินไป ผู้ใช้ปรับลงเหลือ 50 — ใกล้พอที่การโผล่จะเกิดต่อหน้า แต่ยังไกลกว่า 30 เดิม
--
-- 50 อยู่ใต้ aggroRange ของผีดิบ (55) เล็กน้อย แปลว่ามอนที่เกิดใกล้ตัวจะไล่แทบจะทันทีที่ขึ้นมาเสร็จ
-- ซึ่งเป็นสิ่งที่ตั้งใจตอนนี้: เจอปุ๊บสู้ปั๊บ ไม่ใช่เดินเข้าไปหาทีละตัว
local TRIGGER_RADIUS = 50

-- ค่าใหม่รายจุด: จำนวนเท่าตัว และรัศมีที่ทำให้ยังห่างกันราว 50 studs
--
-- **รัศมีต้องโตขึ้น ไม่ใช่เล็กลง** ผู้ใช้ขอให้ "กระจายกันออกไป 50 st" ซึ่งหมายถึงระยะห่างระหว่างตัว
-- ไม่ใช่รัศมีของวง — วัดแล้ว: ที่รัศมีเดิม 90 การเพิ่มมอนจาก 4 เป็น 8 ตัวทำให้ห่างกันเหลือ 33 studs
-- ถ้าตั้งรัศมีเป็น 50 ตรงๆ จะยิ่งแย่ (18 studs = กองกันเป็นกระจุก)
--
-- ตัวเลขข้างล่างมาจากการจำลอง: 8 ตัวในรัศมี 140 ห่างกันเฉลี่ย ~50 · 6 ตัวในรัศมี 120 ก็ราวเดียวกัน
-- **ระยะปลุก (50) เล็กกว่ารัศมีเกิด (140) โดยตั้งใจ**
--
-- แปลว่าตอนถูกปลุก ผู้เล่นยืนอยู่ "ในวง" ไม่ใช่ที่ขอบ มอนจึงโผล่รอบตัวได้ทุกทิศรวมทั้งด้านหลัง
-- และตัวที่ไกลสุดอยู่ราว 190 studs ซึ่งเกิน aggroRange มันจะยืนรออยู่ตรงนั้นจนกว่าจะเดินเข้าไป
-- ไม่ได้วิ่งมาทั้งฝูงพร้อมกัน
--
-- หมายเหตุ: ตอน trigger เป็น 200 จุดโครงกระดูกกับผีดิบ (ห่างกัน 120) ถูกปลุกพร้อมกันเป็น 14 ตัว
-- พอลดเหลือ 50 สองจุดนั้นแยกกันแล้ว ปลุกทีละจุด
local TUNING = {
	Spider = { count = 8, radius = 140 },
	Skeleton = { count = 8, radius = 140 },
	Ghoul = { count = 6, radius = 120 },
}

local changed = 0

for _, spawner in ipairs(CollectionService:GetTagged(SPAWNER_TAG)) do
	local kind = spawner:GetAttribute("MobKind")
	local tune = kind and TUNING[kind]
	if tune then
		local beforeCount = spawner:GetAttribute("Count")
		local beforeRadius = spawner:GetAttribute("Radius")

		spawner:SetAttribute("Count", tune.count)
		spawner:SetAttribute("Radius", tune.radius)
		spawner:SetAttribute("TriggerRadius", TRIGGER_RADIUS)
		-- ปลดธงรอคนออก ไม่งั้นจุดที่เพิ่งถูกเคลียร์จะเงียบจนกว่าจะมีคนเดินเข้า-ออกครบรอบ
		spawner:SetAttribute("AwaitExit", nil)

		print(("[Tune] %-18s %s: จำนวน %s -> %d | รัศมี %s -> %d | ปลุกที่ %d st")
			:format(spawner.Name, kind, tostring(beforeCount), tune.count,
				tostring(beforeRadius), tune.radius, TRIGGER_RADIUS))
		changed += 1
	end
end

print(("[Tune] เสร็จ — ปรับ %d จุด (สไลม์ไม่แตะ)"):format(changed))
