-- QuestAccess: ทางเดียวที่ระบบอื่นรายงานความคืบหน้าเควสได้
--
-- รูปเดียวกับ ChestAccess / MobAccess / LeaderboardAccess ด้วยเหตุผลเดียวกัน: Mobs กับ Fishing ต้อง
-- บอกได้ว่าผู้เล่นเพิ่งฆ่าอะไร/ตกอะไรได้ และ Quests ต้องเป็นเจ้าของงาน ถ้า require กันเองจะเป็นวงจร
--
-- ว่างจนกว่า Quests.server จะเติมให้ ผู้เรียกต้องเช็ค nil ก่อนเสมอ
local QuestAccess = {}

-- RecordKill(player, mobName) — ชื่อมอนเป็นชื่อไทยตามที่ GatherConfig ตั้ง
QuestAccess.RecordKill = nil

-- RecordCatch(player, itemId)
QuestAccess.RecordCatch = nil

return QuestAccess
