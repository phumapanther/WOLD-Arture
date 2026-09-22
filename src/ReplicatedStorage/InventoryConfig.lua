-- InventoryConfig: bag size, carry weight, and what being overloaded costs you.
local InventoryConfig = {}

-- Hotbar slots, shared so the UI, the server and the number keys cannot disagree about how many there are.
InventoryConfig.HotbarSlots = 6

InventoryConfig.SlotCount = 36 -- the personal bag grid, 6 columns x 6 rows

-- **ช่องของ "กระเป๋า VIP" อยู่แยกจาก 36 ช่องข้างบน** (ผู้ใช้สั่ง 2026-09-22)
--
-- ของเกาะ (บ้าน แปลงผัก รั้ว เมล็ด สัตว์เลี้ยง …) เคยกินช่องเดียวกับของเกมหลัก คนที่เข้าเกาะครั้งเดียว
-- ก็เสียช่องถาวร 4-6 ช่องแล้วซื้อของในเมืองไม่ได้ ทั้งที่กระเป๋าดูเหมือนยังว่าง
--
-- **เป็นช่วงดัชนีที่ต่อท้าย ไม่ใช่ตารางใหม่** — `state.slots` ยังเป็นตารางเดียว มีโค้ด 67 จุดนอก
-- `Inventory.lua` ที่วน `state.slots` อยู่ (จับกุม ออร่า คลัง คราฟ ตกปลา …) ถ้าแยกเป็นตารางที่สอง
-- ต้องไล่แก้ทั้งหมดนั้น · ช่วงดัชนีทำให้ของยังอยู่ที่เดิมในสายตาโค้ดเก่า แค่ไม่แย่งช่องกัน
InventoryConfig.VipSlotCount = 18 -- 6 คอลัมน์ x 3 แถว
InventoryConfig.VipSlotStart = InventoryConfig.SlotCount + 1
InventoryConfig.VipSlotEnd = InventoryConfig.SlotCount + InventoryConfig.VipSlotCount

-- ช่องทั้งหมดที่มีจริง (ของเก่าที่วน 1..SlotCount ยังเห็นแค่กระเป๋าหลัก ซึ่งถูกแล้ว)
InventoryConfig.TotalSlotCount = InventoryConfig.VipSlotEnd
InventoryConfig.MaxWeight = 500 -- carry this much before the penalties below start (ผู้ใช้ปรับจาก 2000)

-- Overencumbrance. Past MaxWeight you slow down in proportion to the excess, down to a floor so a hoarder can
-- still crawl home rather than being frozen in place.
InventoryConfig.MinSpeedMultiplier = 0.45
-- Past this multiple of MaxWeight, roll and slide are also cut in half: heavy loads should make you commit.
InventoryConfig.HeavyLoadRatio = 1.5
InventoryConfig.HeavyActionPenalty = 0.5

-- Returns the movement multiplier for a given carried weight: 1 up to the limit, then falling away.
function InventoryConfig.SpeedMultiplier(weight)
	if weight <= InventoryConfig.MaxWeight then return 1 end
	local over = weight / InventoryConfig.MaxWeight -- 1.0 at the limit, 2.0 at double
	return math.max(InventoryConfig.MinSpeedMultiplier, 1 / over)
end

function InventoryConfig.IsHeavilyLoaded(weight)
	return weight > InventoryConfig.MaxWeight * InventoryConfig.HeavyLoadRatio
end

return InventoryConfig
