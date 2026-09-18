-- PremiumAccess: ทางที่ระบบอื่นแตะเพชร/แบทเทิลพาสได้โดยไม่ต้อง require PremiumStore.server
--
-- รูปเดียวกับ ClanAccess / TownAccess: ว่างจนกว่า PremiumStore.server จะเติม ผู้เรียกต้องเช็ค nil ก่อน
-- Progression.AwardExp เรียก AddPassXp ทุกครั้งที่ให้ EXP — ถ้า require ตรงจะเป็นวงจร
local PremiumAccess = {}

-- AddPassXp(player, exp) -> เติม XP แบทเทิลพาสตาม EXP ที่เพิ่งได้
PremiumAccess.AddPassXp = nil

-- AddGems(player, n) / GetGems(player)
PremiumAccess.AddGems = nil
PremiumAccess.GetGems = nil

return PremiumAccess
