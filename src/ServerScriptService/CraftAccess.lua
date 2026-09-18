-- CraftAccess: CraftStations.server ขอเปิดหน้าคราฟที่สถานี (เตา/เครื่องปั่น/เครื่องต้มยา) ผ่านทางนี้
-- Crafting.server เป็นเจ้าของหน้าต่างและสูตร เติมฟังก์ชันตอนโหลด
local CraftAccess = {}

-- OpenAt(player, station, model) -> เปิดหน้าคราฟที่โชว์เฉพาะสูตรของ station ("stove"|"blender"|"still")
CraftAccess.OpenAt = nil

-- OnCrafted(player, station, model, recipe) -> ให้สถานีแสดงผลตอนเสร็จ (ไฟทิ้งท้ายที่เตา) เติมโดย CraftStations.server
CraftAccess.OnCrafted = nil

-- OnCraftStarted(player, station, model, seconds) -> เริ่มทำ
--
-- มีเพราะสูตรที่ใช้เวลาจริง (สเต็ก 15 นาที) ต้องเห็นไฟลุกอยู่ **ระหว่าง** ทำ ไม่ใช่ลุกตอนทำเสร็จแล้ว
CraftAccess.OnCraftStarted = nil

return CraftAccess
