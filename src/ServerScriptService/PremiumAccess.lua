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

-- SpendGems(player, n) -> true ถ้าพอและหักแล้ว · ร้านบนเกาะใช้ซื้อของตกแต่ง/สัตว์เลี้ยง/ของผิดกฎหมาย
PremiumAccess.SpendGems = nil

-- GrantPremiumPass(player) -> true เมื่อปลดสายพรีเมียมของพาสเดือนนี้ให้แล้ว · false, "owned" = ปลดอยู่แล้ว (ของขวัญหุ่นฟาง)
-- HasPremiumPass(player) -> พาสเดือนนี้เป็นพรีเมียมอยู่ไหม
PremiumAccess.GrantPremiumPass = nil
PremiumAccess.HasPremiumPass = nil

return PremiumAccess
