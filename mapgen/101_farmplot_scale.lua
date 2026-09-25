-- 101_farmplot_scale.lua — ขยายแปลงผักบนเกาะ 1.5 เท่า (ผู้ใช้สั่ง 2026-09-25) 2x2 ช่อง → 3x3 ช่อง
--
--   WOLD_PLACE=136992335889132 node tools/lua.js mapgen/101_farmplot_scale.lua Edit
--
-- แก้ต้นแบบ `ReplicatedStorage.WOLD_Placeables.FarmPlot` ในเพลสตรงๆ แล้วติด `Manual = true` — เฟส 90 เห็นธงนี้
-- แล้วไม่สร้างทับ (กติกาเดิมของโปรเจ็ค) รันเฟส 90 ซ้ำแปลงจึงไม่หดกลับ · รันไฟล์นี้ซ้ำได้ (`ScaleTo` เป็นสเกลสัมบูรณ์)
--
-- ของที่ตามมาเอง ไม่ต้องทำอะไรเพิ่ม: `IslandBuild` อ่าน Footprint ใหม่ แล้วดันแปลงที่วางติดกันจนซ้อนออกไปตอนโหลดเกาะ
-- (ครั้งเดียว จดที่ใหม่ลงโปรไฟล์) · ghost ตอนวางเป็น 3x3 · ผักโตตามสเกลแปลง (`IslandPlots.showCrop`)
local SCALE = 1.5

local RS = game:GetService("ReplicatedStorage")
local IslandConfig = require(RS.IslandConfig)
local folder = RS:FindFirstChild("WOLD_Placeables")
local proto = folder and folder:FindFirstChild("FarmPlot")
assert(proto, "ไม่มี WOLD_Placeables.FarmPlot (รันเฟส 90 ก่อน)")

local before = proto:GetAttribute("Footprint")
proto:ScaleTo(SCALE)

-- ช่องคิดแบบเดียวกับ `finish()` ของเฟส 90 (ขนาดกล่องครอบหารช่อง ปัดขึ้น เผื่อเศษ 0.05)
local _, size = proto:GetBoundingBox()
local function cells(studs) return math.max(1, math.ceil(studs / IslandConfig.Cell - 0.05)) end
proto:SetAttribute("Footprint", Vector2.new(cells(size.X), cells(size.Z)))
proto:SetAttribute("Manual", true)

return ("FarmPlot สเกล %.2f · Footprint %s → %s · กล่อง %.1f x %.1f x %.1f"):format(
	proto:GetScale(), tostring(before), tostring(proto:GetAttribute("Footprint")), size.X, size.Y, size.Z)
