-- RayThrough: raycast ที่ทะลุของบางอย่างได้ (สไนทะลุเพื่อนร่วมทีม/ศพ — รีวิวจบงาน 2026-09-25)
--
-- `skip(part)` คืน instance ที่ต้องมองข้าม (มักเป็นร่างทั้งตัว) หรือ nil = หยุดที่ชิ้นนี้
-- ยิงต่อจากจุดที่ชน ด้วยระยะที่เหลือ · กันวนไม่รู้จบด้วย `maxHops` (ดีฟอลต์ 4)
-- ⚠️ เขียนทับ `params.FilterDescendantsInstances` ด้วยของที่ข้ามเพิ่ม — ส่ง params ใหม่ทุกนัด
local RayThrough = {}

function RayThrough.Cast(origin, direction, params, skip, maxHops)
	local filter = table.clone(params.FilterDescendantsInstances)
	local unit, remaining = direction.Unit, direction.Magnitude
	local start = origin
	for _ = 1, maxHops or 4 do
		local result = workspace:Raycast(start, unit * remaining, params)
		if not result then return nil end
		local ignore = skip(result.Instance)
		if not ignore then return result end
		table.insert(filter, ignore)
		params.FilterDescendantsInstances = filter
		remaining -= (result.Position - start).Magnitude
		start = result.Position
		if remaining <= 0 then return nil end
	end
	return nil
end

-- กระสุนเฉียดเป้า: ใครอยู่ใกล้แนวยิงที่สุด (ระยะตั้งฉาก ≤ radius + pad) ก่อนจุดที่กระสุนหยุด
-- ตำแหน่งมอนบนจอผู้ยิงช้ากว่าเซิร์ฟเวอร์ ~0.1-0.2 วิ มอนวิ่ง 8-16 สตัด/วิ = คลาด 1-3 สตัด (QA 2026-09-26)
-- `candidates` = { { model, position = Vector3, pad = number? } } · คืนแถวที่ถูกเลือก หรือ nil
function RayThrough.NearestNear(origin, unit, maxDist, candidates, radius)
	local best, bestT = nil, math.huge
	for _, c in ipairs(candidates) do
		local rel = c.position - origin
		local t = rel:Dot(unit)
		if t >= 0 and t <= maxDist and t < bestT then
			local perp = (rel - unit * t).Magnitude
			if perp <= radius + (c.pad or 0) then
				best, bestT = c, t
			end
		end
	end
	return best
end

return RayThrough
