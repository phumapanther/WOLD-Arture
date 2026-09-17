-- ClanAccess: ทางเดียวที่ระบบอื่นถามเรื่องแคลนได้
--
-- รูปเดียวกับ ChestAccess / MobAccess / QuestAccess ด้วยเหตุผลเดียวกัน: ร้านค้าประจำเมืองต้องรู้ว่า
-- ผู้เล่นอยู่แคลนไหนเพื่อคิดภาษีและส่วนลด และ Clans ต้องเป็นเจ้าของข้อมูล ถ้า require กันเองจะเป็นวงจร
--
-- ว่างจนกว่า Clans.server จะเติมให้ ผู้เรียกต้องเช็ค nil ก่อนเสมอ
local ClanAccess = {}

-- ClanOf(player) -> ตารางแคลน หรือ nil
ClanAccess.ClanOf = nil

-- ClanIdOf(player) -> id หรือ nil (เร็วกว่า ไม่ต้องอ่าน DataStore)
ClanAccess.ClanIdOf = nil

-- AddSilver(clanId, amount) — ใช้กับภาษีจากร้านประจำเมือง
ClanAccess.AddSilver = nil

-- GiveRing(player) — แหวนแคลน ยังเป็นโครงไว้ก่อน
ClanAccess.GiveRing = nil

return ClanAccess
