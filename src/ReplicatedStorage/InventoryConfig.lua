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
InventoryConfig.VipSlotCount = 36 -- 6 คอลัมน์ x 6 แถว = เท่ากระเป๋าหลัก (เฟส 2b ผู้ใช้กำหนด · ช่อง 37-72 · เซฟเก่า 37-54 ใช้ต่อได้)
InventoryConfig.VipSlotStart = InventoryConfig.SlotCount + 1
InventoryConfig.VipSlotEnd = InventoryConfig.SlotCount + InventoryConfig.VipSlotCount

-- ช่องทั้งหมดที่มีจริง (ของเก่าที่วน 1..SlotCount ยังเห็นแค่กระเป๋าหลัก ซึ่งถูกแล้ว)
InventoryConfig.TotalSlotCount = InventoryConfig.VipSlotEnd
InventoryConfig.MaxWeight = 500 -- carry this much before the penalties below start (ผู้ใช้ปรับจาก 2000)
InventoryConfig.VipMaxWeight = 750 -- VIP แบกได้มากกว่า (ผู้ใช้สั่ง 2026-10-02) · ถามผ่าน WeightLimit / Inventory.MaxWeight

function InventoryConfig.WeightLimit(isVip)
	return isVip and InventoryConfig.VipMaxWeight or InventoryConfig.MaxWeight
end

-- Overencumbrance. Past MaxWeight you slow down in proportion to the excess, down to a floor so a hoarder can
-- still crawl home rather than being frozen in place.
InventoryConfig.MinSpeedMultiplier = 0.45
-- Past this multiple of MaxWeight, roll and slide are also cut in half: heavy loads should make you commit.
InventoryConfig.HeavyLoadRatio = 1.5
InventoryConfig.HeavyActionPenalty = 0.5

-- Returns the movement multiplier for a given carried weight: 1 up to the limit, then falling away.
-- `limit` = เพดานของคนนั้น (VIP 750) · ไม่ใส่ = MaxWeight
function InventoryConfig.SpeedMultiplier(weight, limit)
	limit = limit or InventoryConfig.MaxWeight
	if weight <= limit then return 1 end
	local over = weight / limit -- 1.0 at the limit, 2.0 at double
	return math.max(InventoryConfig.MinSpeedMultiplier, 1 / over)
end

-- 🔧 เหนือหัว (ผู้ใช้สั่ง 2026-09-29): ของที่ใส่/ถืออยู่ชิ้นไหนก็ได้ ความคงทนต่ำกว่านี้ · ของไม่มีวันพัง (ไม่มีค่า) ไม่นับ
InventoryConfig.WornBelow = 5
function InventoryConfig.AnyWorn(equipped)
	for _, entry in pairs(equipped or {}) do
		if type(entry) == "table" and type(entry.durability) == "number" and entry.durability < InventoryConfig.WornBelow then
			return true
		end
	end
	return false
end

-- อาวุธติดสกินความคงทนหมด = ไม่หาย ค้างที่ 0 ใช้โจมตี/สกิล/ตีบวกไม่ได้จนกว่าจะซ่อม (ผู้ใช้สั่ง 2026-09-29)
-- สกินอยู่บนตัวอาวุธ (`meta.skin`) อาวุธหายเมื่อไหร่สกินที่สุ่มด้วยเพชรมาก็หายตาม · ไม่ติดสกิน = พังหายเหมือนเดิม
function InventoryConfig.KeepsWhenBroken(entry)
	return type(entry) == "table" and type(entry.meta) == "table" and entry.meta.skin ~= nil
end
function InventoryConfig.IsBroken(entry)
	return type(entry) == "table" and type(entry.durability) == "number" and entry.durability <= 0
end

-- กินอาหารอัตโนมัติ (ผู้ใช้สั่ง 2026-10-02): หลอดอาหาร ≤ 10% · ไม่โดนตีมา 5 วิ (ไม่กินกลางวงตี) · ไม่ได้ล้ม/ใช้ของอื่นอยู่
-- 🤤 เหนือหัวที่ ≤ 5% · PlayerInventory ถามทุกวินาที
InventoryConfig.AutoEatBelow = 0.10
InventoryConfig.AutoEatCalmSeconds = 5
InventoryConfig.HungryMarkBelow = 0.05
function InventoryConfig.ShouldAutoEat(hungerFraction, secondsSinceHurt, busy)
	return not busy and hungerFraction <= InventoryConfig.AutoEatBelow
		and secondsSinceHurt >= InventoryConfig.AutoEatCalmSeconds
end

function InventoryConfig.IsHeavilyLoaded(weight, limit)
	return weight > (limit or InventoryConfig.MaxWeight) * InventoryConfig.HeavyLoadRatio
end

return InventoryConfig
