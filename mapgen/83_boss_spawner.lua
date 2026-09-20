-- 83_boss_spawner.lua: จุดเกิดบอสฟอร์จวอร์เดน — **ทำเป็นหมุดที่ลากย้ายเองได้ใน Studio**
--
-- ผู้ใช้ถามว่า "จุดเกิดบอสอยู่ตรงไหน จะปรับ" — คำตอบคือหมุดชิ้นนี้:
--   `workspace.WOLD.BossSpawns.BossSpawn_Forgewarden`
-- เปิด Explorer เลือกมัน กด F เพื่อวาปกล้องไปหา แล้ว **ลากไปวางที่ไหนก็ได้** บอสจะไปเกิดที่นั่นทันที
-- (ระบบอ่านตำแหน่งสดทุกครั้งที่จะปล่อยมอน ไม่ได้จำค่าไว้ตอนเซิร์ฟบูต)
--
-- **รันซ้ำแล้วหมุดไม่ถูกย้ายกลับ** — เฟสนี้สร้างให้เฉพาะตอนที่ยังไม่มี ถ้ามีอยู่แล้วจะแก้แค่แอตทริบิวต์
-- ตำแหน่งที่ลากเองไว้จึงไม่หายเวลารันเฟสใหม่ (บทเรียนจากเฟสอื่นที่ลบของเก่าทิ้งทุกครั้ง)
--
-- ปรับพฤติกรรมได้จากแอตทริบิวต์บนหมุด ไม่ต้องแก้โค้ด:
--   MobKind       ชนิดมอน (ต้องมีใน `GatherConfig.Mobs`)
--   Count         มีพร้อมกันได้กี่ตัว — บอสคือ 1
--   Radius        รัศมีสุ่มจุดยืนรอบหมุด
--   EventOnly     หมุดนี้ว่างเปล่าจนกว่าอีเวนต์ชื่อนี้จะเริ่ม — บอสโลกตื่นสองทุ่ม ไม่ใช่เดินไปเจอ
--   NoBoss        กันไม่ให้ระบบ "บอสประจำสปอว์เนอร์" คูณขนาด/พลังซ้ำ — บอสตัวนี้มีสเกลของตัวเองแล้ว
--
-- **ไม่มี TriggerRadius แล้ว** (ผู้ใช้กำหนด 2026-09-20: เป็นบอสเวิลด์ที่เกิดตามเวลา) ถ้ายังมีอยู่ บอสจะรอ
-- ให้มีคนเดินเข้ามาใกล้ 150 studs ก่อนถึงจะโผล่ ซึ่งแปลว่าประกาศตอนสองทุ่มแล้วลานยังว่าง จนกว่าจะมีคน
-- ไปถึงหน้าเตาหลอม — เฟสนี้จึงลบแอตทริบิวต์นั้นทิ้งทุกครั้งที่รัน
local CollectionService = game:GetService("CollectionService")

local MOB_KIND = "Forgewarden"
local MARKER_NAME = "BossSpawn_" .. MOB_KIND

-- จุดตั้งต้น: หน้าโรงหลอม (`workspace.Foundry`) — ผู้พิทักษ์เตาหลอมควรอยู่ที่เตาหลอม
-- ถ้าหาโรงหลอมไม่เจอ ใช้พิกัดสำรองที่วัดไว้แล้วว่าเป็นพื้นดินจริง
-- พิกัดนี้วัดแล้วจากการยิงเรย์ 24 จุดรอบโรงหลอม: พื้นดินจริง (ไม่ใช่หลังคาโรงงาน) และต่างระดับแค่
-- 0.7 studs ในรัศมี 16 — ลานที่แบนพอให้บอสสูง 27 studs ยืนได้โดยไม่มีชิ้นส่วนโรงงานเกะกะ
local FALLBACK = Vector3.new(-980, 25, 5457)

local function groundAt(x, z, fromY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace:FindFirstChild("WOLD_Mobs") }
	local hit = workspace:Raycast(Vector3.new(x, (fromY or 400) + 200, z), Vector3.new(0, -2000, 0), params)
	return hit and hit.Position.Y or nil
end

local root = workspace:FindFirstChild("WOLD")
if not root then
	root = Instance.new("Folder")
	root.Name = "WOLD"
	root.Parent = workspace
end

local folder = root:FindFirstChild("BossSpawns")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "BossSpawns"
	folder.Parent = root
end

local marker = folder:FindFirstChild(MARKER_NAME)
local created = false

if not marker then
	created = true
	-- ตำแหน่งตั้งต้นหน้าโรงหลอม เว้นระยะจากตัวอาคารพอให้บอสสูง 27 studs ยืนได้โดยไม่ทับหลังคา
	-- ใช้พิกัดที่วัดมาแล้วตรงๆ ไม่ได้คำนวณจากกล่องขอบของโรงหลอม — รอบแรกคำนวณเอาแล้วได้จุดที่
	-- ติดเครนและจมพื้นครึ่งแผ่น (กล่องขอบของอาคารไม่ได้บอกว่าตรงไหนเป็นลานว่าง)
	local spot = FALLBACK
	local y = groundAt(spot.X, spot.Z, spot.Y) or spot.Y

	-- หมุดเป็นแผ่นรูนบนพื้น ไม่ใช่กล่องล่องหน: ของที่มองเห็นคือของที่ย้ายถูกจุด และผู้เล่นจะได้รู้ว่า
	-- "ตรงนี้มีอะไรจะโผล่" ซึ่งเป็นภาษาของเกมโซลไลก์อยู่แล้ว (ลานบอสมีขอบเขตชัดเจนเสมอ)
	marker = Instance.new("Part")
	marker.Name = MARKER_NAME
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.6, 26, 26)
	marker.CFrame = CFrame.new(spot.X, y + 0.6, spot.Z) * CFrame.Angles(0, 0, math.rad(90))
	marker.Anchored = true
	marker.CanCollide = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(196, 74, 20)
	marker.Transparency = 0.72
	marker.Parent = folder

	local ring = Instance.new("Part")
	ring.Name = "Rim"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 30, 30)
	ring.CFrame = marker.CFrame * CFrame.new(-0.1, 0, 0)
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Slate
	ring.Color = Color3.fromRGB(54, 46, 44)
	ring.Parent = marker

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 40)
	light.Range = 40
	light.Brightness = 1.2
	light.Parent = marker
end

-- แอตทริบิวต์ถูกเขียนใหม่ทุกครั้ง (ค่าพวกนี้คือ "กติกา" ไม่ใช่ของที่ผู้ใช้ลากเอง)
marker:SetAttribute("MobKind", MOB_KIND)
marker:SetAttribute("Count", 1)
marker:SetAttribute("Radius", 10)
marker:SetAttribute("TriggerRadius", nil)
marker:SetAttribute("NoBoss", true)
-- ผูกกับอีเวนต์บอสโลก: `Mobs.server` จะไม่ปล่อยอะไรจากหมุดนี้เลยจนกว่า `WorldBoss.server` จะเปิดให้
marker:SetAttribute("EventOnly", "worldboss")
-- กันเฟสธรรมชาติ/เฟสอื่นลบทิ้งตอนรันซ้ำ (กติกาของโปรเจ็ค: Manual = ของที่คนวางเอง)
marker:SetAttribute("Manual", true)
CollectionService:AddTag(marker, "WOLD_Spawner")

local pos = marker.Position
root:SetAttribute("Progress", ("%s %s ที่ %.0f, %.0f, %.0f (ลากย้ายได้ใน Studio)"):format(
	created and "สร้างหมุดบอส" or "อัปเดตหมุดบอส", MARKER_NAME, pos.X, pos.Y, pos.Z))
root:SetAttribute("Status", "done")
print("[BossSpawn] " .. root:GetAttribute("Progress"))
