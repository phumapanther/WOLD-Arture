-- CraftFuel: เชื้อเพลิงเครื่องคราฟบนเกาะ (ผู้ใช้สั่ง 2026-10-02) — กติกาล้วน ใช้ทั้งเซิร์ฟ (Crafting) และหน้าต่าง (CraftGui)
--
-- ผู้ใช้เลือก: ถ่านหิน 16 ก้อน = 100% · **กินตามเวลาทำ 100% = 2 ชั่วโมง** (สูตรยิ่งนานยิ่งกินเยอะ ทำหลายรอบคูณตาม) ·
-- **หักตอนกดทำ ไม่พอ = ทำไม่ได้** (เริ่มแล้วทำจนจบเสมอ) · ทุกเครื่องคราฟบนเกาะ เกมหลักใช้ฟรีเหมือนเดิม
-- เชื้อเพลิงเก็บเป็น "วินาทีที่เครื่องทำงานได้" ไว้ที่ entry ของเครื่องที่วาง (`entry.fuel`) · เก็บเครื่องคืนกระเป๋า = ไปกับ meta.fuel
-- เทส craft_fuel_test (offline)
local CraftFuel = {}

CraftFuel.Item = "Coal"
CraftFuel.ItemsToFill = 16
CraftFuel.FullSeconds = 2 * 60 * 60
CraftFuel.SecondsPerItem = CraftFuel.FullSeconds / CraftFuel.ItemsToFill -- 450 = ถ่านก้อนละ 7.5 นาที

-- สถานีใน CraftStations ที่ต้องเติมเชื้อเพลิง (บนเกาะเท่านั้น)
CraftFuel.Stations = { bakery = true, metal = true, loom = true, stove = true, blender = true, still = true }

function CraftFuel.Uses(station, isFarm)
	return isFarm == true and station ~= nil and CraftFuel.Stations[station] == true
end

-- เชื้อเพลิงที่งานหนึ่งใช้ = เวลาทั้งงาน (วินาที × จำนวนรอบ ผู้เรียกคูณมาแล้ว)
function CraftFuel.Cost(seconds)
	return math.ceil(math.max(0, seconds or 0))
end

-- เป็นเปอร์เซ็นต์สำหรับโชว์ในแถวสูตร (ปัดขึ้น ไม่ให้งานสั้นๆ ขึ้นว่า 0%)
function CraftFuel.CostPercent(seconds)
	return math.ceil(CraftFuel.Cost(seconds) / CraftFuel.FullSeconds * 100 - 1e-9)
end

function CraftFuel.Percent(fuel)
	return math.clamp((fuel or 0) / CraftFuel.FullSeconds * 100, 0, 100)
end

-- เติมได้อีกกี่ก้อน (ก้อนสุดท้ายที่ล้นนิดหน่อยยังเติมได้ ไม่งั้นค้างที่ 97% เติมเต็มไม่ได้)
function CraftFuel.Room(fuel)
	return math.max(0, math.ceil((CraftFuel.FullSeconds - (fuel or 0)) / CraftFuel.SecondsPerItem - 1e-9))
end

function CraftFuel.Add(fuel, items)
	return math.min(CraftFuel.FullSeconds, (fuel or 0) + math.max(0, items or 0) * CraftFuel.SecondsPerItem)
end

function CraftFuel.Enough(fuel, cost)
	return (fuel or 0) >= cost
end

return CraftFuel
