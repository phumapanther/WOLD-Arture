-- PromptStack: จัดปุ่ม E/F (ProximityPrompt) ที่โผล่พร้อมกันบนโมเดลเดียวกันให้เรียงลงมา ไม่ทับกัน
--
-- ผู้ใช้แจ้ง 2026-09-26: "ปุ่มกับ E ยังซ้อนกันอยู่หลายโมเดล ทั้งโหมดฟาร์มและโหมดหลัก" — Roblox วาดปุ่มทุกอันที่ตำแหน่งของ
-- ชิ้นที่มันแขวน ระบบหลายระบบแขวนปุ่มบนโมเดลเดียวกัน (เก็บ E + ฟาร์มออโต้ F · เก็บของเข้ากระเป๋า F บนของตกแต่ง ·
-- ลูบหัว/อุ้มสัตว์ · อาชีพ/ช่วยคนล้มบนตัวผู้เล่น · ยึดเมือง/คลังเมือง ...) แต่ละระบบเดาระยะเลื่อนของตัวเอง (44 px
-- ซึ่งเตี้ยกว่าปุ่ม ~72 px) และไม่รู้จักปุ่มของระบบอื่นเลย → ที่นี่ที่เดียวเป็นเจ้าของ UIOffset ของทุกปุ่มฝั่งไคลเอนต์
--
-- โมดูลนี้คิดตำแหน่งอย่างเดียว (ทดสอบได้) — `PromptStackController` ป้อนปุ่มที่โชว์อยู่และเขียนค่าลงปุ่ม
local PromptStack = {}

PromptStack.Spacing = 80 -- px ระหว่างปุ่มในกองเดียวกัน (ปุ่มมาตรฐานสูง ~72)
PromptStack.GroupStuds = 4 -- จุดแขวนห่างกันไม่เกินนี้ = กองเดียวกัน

-- entries = { { key = <อะไรก็ได้>, pos = Vector3, order = number, name = string } }
-- คืน `offsets, sizes` — { [key] = Vector2 } กับ { [key] = จำนวนปุ่มในกองของมัน }
-- กองละหลายปุ่มเรียงบนลงล่างตาม order แล้ว name (E ก่อน F) กึ่งกลางกองอยู่ที่จุดเดิม · ปุ่มเดี่ยว = Vector2.zero
function PromptStack.Layout(entries)
	local sorted = table.clone(entries)
	table.sort(sorted, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.name < b.name
	end)
	local groups = {}
	for _, e in ipairs(sorted) do
		local home
		for _, g in ipairs(groups) do
			if (g.pos - e.pos).Magnitude <= PromptStack.GroupStuds then home = g break end
		end
		if not home then
			home = { pos = e.pos, items = {} }
			table.insert(groups, home)
		end
		table.insert(home.items, e)
	end
	local out, sizes = {}, {}
	for _, g in ipairs(groups) do
		local n = #g.items
		for i, e in ipairs(g.items) do
			out[e.key] = Vector2.new(0, (i - (n + 1) / 2) * PromptStack.Spacing)
			sizes[e.key] = n
		end
	end
	return out, sizes
end

return PromptStack
