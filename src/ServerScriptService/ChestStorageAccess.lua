-- ChestStorageAccess: ทางเดียวที่ระบบอื่นสั่งงานหีบเก็บของได้
--
-- รูปเดียวกับ ChestAccess, MobAccess, MonowheelAccess และด้วยเหตุผลเดียวกัน: `AdminCommands` ต้องเสกของ
-- ลงหีบได้ และ `StorageChests.server` ต้องเป็นเจ้าของหีบ ถ้าทั้งสองฝั่ง require กันเองจะเป็นวงจร
-- ตัวที่ตื้นกว่าจึงเป็นไฟล์นี้
--
-- ว่างเปล่าจนกว่า StorageChests.server จะเติมให้ (และไม่มีวันเติมในล็อบบี้ซึ่งไม่มีหีบ) ผู้เรียกทุกคน
-- จึงต้องเช็ค nil ก่อนเสมอ
local ChestStorageAccess = {}

-- Scatter(id, count, durability, meta) -> จำนวนที่ลงได้จริง, จำนวนหีบที่โดนใช้
--
-- โปรยของลงหีบทั่วแมพแบบสุ่มรายชิ้น หีบหนึ่งใบรับได้สูงสุด 3 ชิ้น และของไม่รวมกอง
ChestStorageAccess.Scatter = nil

return ChestStorageAccess
