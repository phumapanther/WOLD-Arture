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
-- `accept(c)` (ไม่ใส่ก็ได้) ปฏิเสธตัวที่ห้ามนับ (เพื่อน ศพ มองไม่เห็นจากปากกระบอก) — ถูกปฏิเสธแล้วไล่ตัวถัดไปตามแนวยิง
-- ไม่ใช่เสียนัดทิ้ง (รีวิวเฟส 0: เดิมเลือกตัวใกล้สุดก่อนกรอง เพื่อนยืนหน้าศัตรูกินนัดเฉียดไป)
function RayThrough.NearestNear(origin, unit, maxDist, candidates, radius, accept)
	local inRange = {}
	for _, c in ipairs(candidates) do
		local rel = c.position - origin
		local t = rel:Dot(unit)
		if t >= 0 and t <= maxDist and (rel - unit * t).Magnitude <= radius + (c.pad or 0) then
			inRange[#inRange + 1] = { c = c, t = t }
		end
	end
	table.sort(inRange, function(a, b) return a.t < b.t end)
	for _, entry in ipairs(inRange) do
		if not accept or accept(entry.c) then return entry.c end
	end
	return nil
end

return RayThrough
