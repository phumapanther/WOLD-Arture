-- StoryAccess: ทางที่ระบบอื่นรายงานเหตุการณ์ให้เนื้อเรื่อง (`Story.server`) — ทรงเดียวกับ QuestAccess/MobAccess
-- ว่างจนกว่า Story.server จะเติม (เพลสหลักเท่านั้น) ผู้เรียกต้องเช็ค nil ก่อนเสมอ
local StoryAccess = {}

-- RecordKill(player, mobName) — ชื่อมอนเป็นชื่อไทยตาม GatherConfig (เรียกจาก Mobs.server ตัวเดียวกับเควส)
StoryAccess.RecordKill = nil

return StoryAccess
