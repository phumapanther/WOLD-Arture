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

return TownAccess
