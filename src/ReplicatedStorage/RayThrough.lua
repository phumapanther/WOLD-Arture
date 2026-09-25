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

return RayThrough
