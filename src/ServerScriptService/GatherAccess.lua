-- GatherAccess: ทางที่ระบบอื่นสั่งเก็บเกี่ยวได้โดยไม่ต้อง require Gathering.server
--
-- รูปเดียวกับ PremiumAccess / TownAccess / IslandAccess: ว่างจนกว่า `Gathering.server` จะเติม
-- ผู้เรียกต้องเช็ค nil ก่อนเสมอ
--
-- มีไว้เพราะการกด `ProximityPrompt` จำลองจากสคริปต์ไม่ได้เลย (`InputHoldBegin` ไม่ทำให้ `Triggered`
-- ยิง) — เทสที่ต้องพิสูจน์ว่า "เก็บแล้วได้ของเท่าไหร่ สัตว์ยังอยู่ไหม" จึงต้องมีประตูฝั่งเซิร์ฟเวอร์
local GatherAccess = {}

-- Gather(player, node) -> true ถ้าเก็บสำเร็จ · เดินผ่านด่านเดียวกับการกดปุ่มทุกด่าน
-- (ยังไม่ถึงเวลา / ไม่มีเครื่องมือ / กระเป๋าเต็ม) ไม่ได้ข้ามอะไรให้
GatherAccess.Gather = nil

return GatherAccess
