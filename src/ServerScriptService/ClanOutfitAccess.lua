-- ClanOutfitAccess: ทางเดียวที่ระบบอื่นสั่งใส่/ถอดชุดแคลนได้
--
-- รูปเดียวกับ AuraAccess / MonowheelAccess ด้วยเหตุผลเดียวกัน: PlayerInventory ต้องสั่งได้ตอนกดแหวน แต่
-- ชุดแคลนเป็นของ ClanOutfit.server ถ้า require กันเองจะเป็นวงจร
--
-- ว่างจนกว่า ClanOutfit.server จะเติมให้ ผู้เรียกต้องเช็ค nil ก่อนเสมอ
local ClanOutfitAccess = {}

-- Toggle(player) -> ok, ข้อความที่จะบอกผู้เล่น
ClanOutfitAccess.Toggle = nil

return ClanOutfitAccess
