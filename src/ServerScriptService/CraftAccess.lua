-- CraftAccess: CraftStations.server ขอเปิดหน้าคราฟที่สถานี (เตา/เครื่องปั่น/เครื่องต้มยา) ผ่านทางนี้
-- Crafting.server เป็นเจ้าของหน้าต่างและสูตร เติมฟังก์ชันตอนโหลด
local CraftAccess = {}

-- OpenAt(player, station, model) -> เปิดหน้าคราฟที่โชว์เฉพาะสูตรของ station ("stove"|"blender"|"still")
CraftAccess.OpenAt = nil

-- OnCrafted(player, station, model, recipe) -> ให้สถานีแสดงผล (ไฟที่เตา) เติมโดย CraftStations.server
CraftAccess.OnCrafted = nil

return CraftAccess
