-- TownAccess: ทางเดียวที่ระบบอื่นถามเรื่องเมืองที่แคลนยึดได้
--
-- รูปเดียวกับ ClanAccess / QuestAccess ด้วยเหตุผลเดียวกัน: พ่อค้าประจำเมืองกับบอร์ดเควสต้องรู้ว่า
-- ใครถือเมืองนี้ และ TownCapture ต้องเป็นเจ้าของข้อมูล ถ้า require กันเองจะเป็นวงจร
--
-- ว่างจนกว่า TownCapture.server จะเติมให้ ผู้เรียกต้องเช็ค nil ก่อนเสมอ
local TownAccess = {}

-- OwnerOf(townId) -> clanId, clanName หรือ nil
TownAccess.OwnerOf = nil

-- IsHome(player, townId) -> ผู้เล่นอยู่แคลนที่ถือเมืองนี้ไหม
TownAccess.IsHome = nil

-- รายชื่อเมืองทั้งหมด { { id, name }, ... }
TownAccess.Towns = nil

-- AnchorOf(townId) -> BasePart ที่ปุ่มยึดเมืองแขวนอยู่ (คลังเมืองใช้วัดระยะว่าคนกดยืนที่อนุสาวรีย์จริง)
TownAccess.AnchorOf = nil

-- Owners() -> ตารางเจ้าของเมืองทั้งหมด (อ่านสดจาก DataStore) สำหรับคำสั่งแอดมิน
TownAccess.Owners = nil

-- ForceOwner(townId, clanId | nil, clanName) -> บังคับตั้ง/ล้างเจ้าของเมือง สำหรับคำสั่งแอดมิน
TownAccess.ForceOwner = nil

-- OpenVault(player, townId) -> เปิดคลังเมืองให้คนนั้น (ตรวจสิทธิ์ข้างใน) เติมโดย TownVault.server
-- ปุ่ม F ที่ TownCapture สร้างเป็นคนเรียก — ยังไม่มีค่า = ระบบคลังยังไม่โหลด ปุ่มจะบอกคนกดตรงๆ
TownAccess.OpenVault = nil

return TownAccess
