-- LeaderboardAccess: ทางเดียวที่ระบบอื่นให้แต้มกิจกรรมได้
--
-- รูปเดียวกับ ChestAccess / MobAccess / ChestStorageAccess และด้วยเหตุผลเดียวกัน: ระบบกิจกรรมต้องให้แต้ม
-- ได้ และ Leaderboards ต้องเป็นเจ้าของตัวเลข ถ้าทั้งสองฝั่ง require กันเองจะเป็นวงจร
--
-- ว่างจนกว่า Leaderboards.server จะเติมให้ (และไม่มีวันเติมในล็อบบี้) ผู้เรียกต้องเช็ค nil ก่อนเสมอ
local LeaderboardAccess = {}

-- AddEventPoints(player, amount) -> แต้มรวมหลังบวก
LeaderboardAccess.AddEventPoints = nil

-- GetEventPoints(player) -> แต้มรวมตอนนี้
LeaderboardAccess.GetEventPoints = nil

return LeaderboardAccess
