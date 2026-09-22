-- IslandAccess: ช่องทางระหว่างสคริปต์ของเกาะ (IslandBuild ↔ IslandPlots) และทางเข้าสำหรับสคริปต์ทดสอบ
-- ทรงเดียวกับ MobAccess: ตารางช่องว่าง เจ้าของแต่ละช่องคือสคริปต์ที่ตั้งมัน · เป็น nil นอกเพลสเกาะ ทุกคนที่เรียกต้องเช็ค
local IslandAccess = {}

-- ตั้งโดย IslandBuild
IslandAccess.IsOwner = nil -- (player) -> bool
IslandAccess.Data = nil -- () -> profile.Data.Island ของเจ้าของ หรือ nil ถ้ายังไม่โหลด
IslandAccess.EntryOf = nil -- (model) -> entry ในตาราง placed
IslandAccess.ModelOf = nil -- (uid) -> model
IslandAccess.Place = nil -- (player, slotIndex, cx, cz, r) -> ok, reason
IslandAccess.Pickup = nil -- (player, uid) -> ok, reason
IslandAccess.FindSlot = nil -- (player, itemId) -> slotIndex   (ให้สคริปต์ทดสอบ ซึ่ง require Inventory ไม่ได้)
IslandAccess.Count = nil -- (player, itemId) -> n

-- ตั้งโดย IslandPlots
IslandAccess.Plant = nil -- (player, plotModel) -> ok, reason
IslandAccess.Harvest = nil -- (player, plotModel) -> ok, reason
IslandAccess.Tick = nil -- () รันการโตหนึ่งรอบทันที

return IslandAccess
