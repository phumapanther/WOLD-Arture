-- IslandAccess: ช่องทางระหว่างสคริปต์ของเกาะ (IslandBuild ↔ IslandPlots) และทางเข้าสำหรับสคริปต์ทดสอบ
-- ทรงเดียวกับ MobAccess: ตารางช่องว่าง เจ้าของแต่ละช่องคือสคริปต์ที่ตั้งมัน · เป็น nil นอกเพลสเกาะ ทุกคนที่เรียกต้องเช็ค
local IslandAccess = {}

-- ตั้งโดย IslandBuild
IslandAccess.IsOwner = nil -- (player) -> bool
IslandAccess.Data = nil
-- NodeStore() -> ตารางจุดที่สุ่มโผล่ (เซฟในโปรไฟล์) · nil = โปรไฟล์ยังไม่โหลด
IslandAccess.NodeStore = nil -- () -> profile.Data.Island ของเจ้าของ หรือ nil ถ้ายังไม่โหลด
IslandAccess.EntryOf = nil -- (model) -> entry ในตาราง placed
IslandAccess.ModelOf = nil -- (uid) -> model
IslandAccess.Place = nil -- (player, slotIndex, cx, cz, r) -> ok, reason
IslandAccess.Pickup = nil -- (player, uid) -> ok, reason
IslandAccess.FindSlot = nil -- (player, itemId) -> slotIndex   (ให้สคริปต์ทดสอบ ซึ่ง require Inventory ไม่ได้)
IslandAccess.Count = nil -- (player, itemId) -> n
IslandAccess.CanPlaceAt = nil -- (cx, cz, w, d, r, itemId) -> ok, reason (ลองดูเฉยๆ ไม่วางจริง)
IslandAccess.Grant = nil -- (player, itemId, count) เสกของเข้ากระเป๋า (เทสเท่านั้น)

-- ตั้งโดย IslandZones (คอก/โซนแร่/ต้นไม้)
IslandAccess.PenBuy = nil -- (player, penModel, kind, count) -> ok, reason
IslandAccess.PenRelease = nil -- (player, penModel) -> ok, จำนวนที่ปล่อย · ทางเดียวที่เปลี่ยนชนิดสัตว์ได้
IslandAccess.PenSnapshot = nil -- (penModel) -> ภาพรวมของคอกสำหรับวาดหน้าจอ
IslandAccess.ZonesTick = nil -- () รันรอบเดียวทันที (เทส)

-- ตั้งโดย IslandPets (สัตว์เลี้ยง + โบนัสจากของตกแต่ง)
IslandAccess.GrowthMultiplier = nil -- () -> ตัวคูณเวลาโตของพืช (< 1 = เร็วขึ้น)
IslandAccess.FarmExpMultiplier = nil -- () -> ตัวคูณ EXP จากการทำฟาร์ม (> 1 = ได้เพิ่ม)

-- ตั้งโดย IslandPlots
IslandAccess.Plant = nil -- (player, plotModel) -> ok, reason
IslandAccess.Harvest = nil -- (player, plotModel) -> ok, reason
IslandAccess.Tick = nil -- () รันการโตหนึ่งรอบทันที

return IslandAccess
