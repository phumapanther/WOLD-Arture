-- SlotCodec: ช่องกระเป๋า ⇄ รูปแบบที่เซฟลง DataStore ได้โดยไม่มีช่องหาย
--
-- ⚠️ **บั๊กที่ไฟล์นี้แก้ (2026-09-25 ผู้ใช้แจ้ง "ของกระเป๋า VIP หายหลังออกเข้าเซิร์ฟ")**: DataStore เก็บเป็น JSON
-- และตารางช่องเป็น sparse (ของอยู่ช่อง 1-3, 7, 37-40) · ถ้ามีของที่ช่อง 1 JSON เข้ารหัสเป็น **array แล้วตัดทิ้งทุกช่อง
-- หลังรูแรก** (วัดแล้ว: {1,2,3,37,38} → ["a","b","c"]) = กระเป๋า VIP หายทั้งใบ และของหลังรูในกระเป๋าหลักก็หายด้วย
-- · ถ้าช่อง 1 ว่าง มันกลายเป็น object คีย์สตริงแทน (จึงรอดบ้างไม่รอดบ้าง ดูเหมือนสุ่ม)
--
-- ทางแก้: เซฟด้วย **คีย์สตริงเสมอ** ("1", "37") → JSON เป็น object ทุกครั้ง ไม่มีอะไรถูกตัด
-- โหลด: รับได้ทั้ง array (เซฟเก่า) และ object คีย์สตริง แล้วคืนคีย์เป็นตัวเลข
local SlotCodec = {}

function SlotCodec.ForSave(slots)
	local out = {}
	for index, slot in pairs(slots or {}) do
		if slot then out[tostring(index)] = slot end
	end
	return out
end

-- คีย์หลังโหลดจาก DataStore อาจเป็นสตริง ("40") ซึ่ง `state.slots[40]` หาไม่เจอ แต่ `pairs` ยังเห็น —
-- แปลงกลับเป็นตัวเลขที่นี่ที่เดียว
function SlotCodec.FromSave(saved)
	local out = {}
	if type(saved) ~= "table" then return out end
	for k, v in pairs(saved) do
		local index = tonumber(k)
		if index and v then out[index] = v end
	end
	return out
end

return SlotCodec
