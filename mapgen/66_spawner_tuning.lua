-- 66_spawner_tuning.lua — ระยะปลุกไกลขึ้น มอนเยอะขึ้นเท่าตัว และกระจายกันมากขึ้น
--
-- รัน: node tools/run-luau.js mapgen/66_spawner_tuning.lua
--
-- **รันซ้ำได้** ตั้งค่าทับของเดิมเสมอ ไม่สะสม (ไม่ได้คูณสองซ้ำทุกครั้งที่รัน — เขียนค่าตรงๆ)
local CollectionService = game:GetService("CollectionService")

local SPAWNER_TAG = "WOLD_Spawner"

-- ระยะที่ผู้เล่นต้องเข้ามาใกล้ก่อนมอนจะเริ่มโผล่ ผู้ใช้ขอ 200
--
-- เดิม 30 ซึ่งใกล้มาก — มอนโผล่ตอนอยู่ตรงหน้าแล้ว ที่ 200 จะเห็นมันดันตัวขึ้นมาแต่ไกล มีเวลาตัดสินใจ
-- ว่าจะสู้หรือเลี่ยง ซึ่งเป็นจังหวะที่ทำให้ระบบโผล่จากดินมีความหมาย
local TRIGGER_RADIUS = 200

-- ค่าใหม่รายจุด: จำนวนเท่าตัว และรัศมีที่ทำให้ยังห่างกันราว 50 studs
--
-- **รัศมีต้องโตขึ้น ไม่ใช่เล็กลง** ผู้ใช้ขอให้ "กระจายกันออกไป 50 st" ซึ่งหมายถึงระยะห่างระหว่างตัว
-- ไม่ใช่รัศมีของวง — วัดแล้ว: ที่รัศมีเดิม 90 การเพิ่มมอนจาก 4 เป็น 8 ตัวทำให้ห่างกันเหลือ 33 studs
-- ถ้าตั้งรัศมีเป็น 50 ตรงๆ จะยิ่งแย่ (18 studs = กองกันเป็นกระจุก)
--
-- ตัวเลขข้างล่างมาจากการจำลอง: 8 ตัวในรัศมี 140 ห่างกันเฉลี่ย ~50 · 6 ตัวในรัศมี 120 ก็ราวเดียวกัน
-- **จุดโครงกระดูกกับผีดิบซ้อนกันโดยตั้งใจ** อย่า "แก้" ทีหลัง
--
-- สองจุดนี้ห่างกันแค่ 120 studs แต่ระยะปลุก 200 แปลว่าเดินเข้าไปใกล้จุดหนึ่งจะปลุกทั้งสองจุด และวงเกิด
-- ก็ทับกันด้วย (140 + 120 > 120) ผลคืออันเดด 14 ตัวโผล่พร้อมกันปนกันสองชนิด
--
-- ผู้ใช้ยืนยันว่าต้องการแบบนี้ — เป็น "สนามอันเดด" ที่ต้องเตรียมตัวก่อนเข้า ไม่ใช่จุดฟาร์มเบาๆ
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
