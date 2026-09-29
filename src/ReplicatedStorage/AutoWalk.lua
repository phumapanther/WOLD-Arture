-- AutoWalk: กติกาเดินอัตโนมัติตามเส้นนำทาง (กด T · คอมเท่านั้น · ผู้ใช้สั่ง 2026-09-29) — ข้อมูลล้วน เทส `tests/auto_walk_test.lua`
-- เส้นทาง = รายการ { pos = Vector3, jump = bool } ที่ `Navigation` จดไว้ตอนวาด · ตัวเดินจริงอยู่ `AutoWalkController.client`
local AutoWalk = {}

AutoWalk.Reach = 2.5 -- ห่างจุดเท่านี้ในแนวราบ = ถึงแล้ว ไปจุดถัดไป (ไม่นับความสูง: จุดวางบนพื้น ตัวละครสูงกว่า)
AutoWalk.JumpAhead = 4 -- จุดกระโดดอยู่ใกล้เท่านี้ = กระโดด

local function flat(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- จุดที่ต้องเดินไปหา · `from` = จุดที่กำลังไปอยู่ (nil = เส้นเพิ่งมาใหม่ → เริ่มที่จุดใกล้ตัวสุด ไม่ย้อนไปจุดแรก)
-- คืน nil = ถึงปลายเส้นแล้ว (เส้นช่วงยาวถูกแบ่งเป็นท่อน รอ Navigation คำนวณท่อนต่อ)
function AutoWalk.NextIndex(route, position, from)
	local n = #route
	if n == 0 then return nil end
	local i = from
	if not i then
		local best, bestDistance = 1, math.huge
		for k, point in ipairs(route) do
			local d = (point.pos - position).Magnitude
			if d < bestDistance then best, bestDistance = k, d end
		end
		i = best
	end
	while i <= n and flat(route[i].pos, position) <= AutoWalk.Reach do
		i += 1
	end
	if i > n then return nil end
	return i
end

-- ทิศเดินแนวราบยาวหนึ่งหน่วย (ส่งให้ Humanoid:Move) · อยู่ตรงจุดพอดี = ศูนย์
function AutoWalk.Direction(position, target)
	local d = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
	if d.Magnitude < 1e-3 then return Vector3.zero end
	return d.Unit
end

function AutoWalk.ShouldJump(point, position)
	return point ~= nil and point.jump == true and flat(point.pos, position) <= AutoWalk.JumpAhead
end

return AutoWalk
