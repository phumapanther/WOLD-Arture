-- 64_emerge_spawners.lua — เปิดระบบ "โผล่จากดิน" ให้มอนที่ควรโผล่จากดิน
--
-- รัน: node tools/run-luau.js mapgen/64_emerge_spawners.lua
--
-- **รันซ้ำได้ ไม่สร้างของซ้ำ** ตั้งค่าแอตทริบิวต์ทับของเดิมเสมอ และสปอว์เนอร์ผีดิบสร้างเมื่อยังไม่มีเท่านั้น
--
-- ตัวระบบอยู่ใน `Mobs.server.lua` แล้ว (startEmerge + ด่าน TriggerRadius) ไฟล์นี้แค่ไปติดสวิตช์ให้
-- จุดที่ควรใช้ — สไลม์ไม่ติด เพราะมันเด้งมาตามพื้นอยู่แล้ว การให้มันคลานขึ้นจากดินไม่เข้ากับตัวมัน
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local SPAWNER_TAG = "WOLD_Spawner"

-- ชนิดที่ควรโผล่ขึ้นมาจากดิน ตามที่ผู้ใช้เลือก: โครงกระดูก แมงมุม ผีดิบ
local EMERGE_KINDS = {
	Skeleton = true,
	Spider = true,
	Ghoul = true,
}

-- รอให้คนเข้ามาใกล้เท่านี้ก่อนถึงจะเริ่มปล่อยมอน
local TRIGGER_RADIUS = 30

local changed, skipped = 0, 0

for _, spawner in ipairs(CollectionService:GetTagged(SPAWNER_TAG)) do
	local kind = spawner:GetAttribute("MobKind")
	if kind and EMERGE_KINDS[kind] then
		spawner:SetAttribute("Emerge", true)
		spawner:SetAttribute("TriggerRadius", TRIGGER_RADIUS)
		-- เคลียร์ธงรอคนออก เผื่อรอบก่อนค้างไว้ ไม่งั้นจุดนั้นจะเงียบจนกว่าจะมีคนเดินเข้า-ออกครบรอบ
		spawner:SetAttribute("AwaitExit", nil)
		print(("[Emerge] %s (%s) -> โผล่จากดิน + รอคนเข้าใกล้ %d"):format(spawner.Name, kind, TRIGGER_RADIUS))
		changed += 1
	else
		skipped += 1
	end
end

--------------------------------------------------------------------------------
-- สปอว์เนอร์ผีดิบ — ยังไม่มีในแมพ ทั้งที่คอนฟิกกับโมเดลพร้อมแล้ว
--------------------------------------------------------------------------------

-- วางไว้ใกล้จุดโครงกระดูก: ทั้งคู่เป็นอันเดด อยู่โซนเดียวกันสมเหตุสมผล และเป็นที่ที่ผู้เล่นไปถึงได้จริง
-- (พิกัดโครงกระดูกอ่านจากแมพจริง ไม่ได้ตั้งเอง)
local function findSpawner(name)
	for _, s in ipairs(CollectionService:GetTagged(SPAWNER_TAG)) do
		if s.Name == name then return s end
	end
	return nil
end

local existing = findSpawner("Spawner_Ghoul")
if existing then
	print("[Emerge] มี Spawner_Ghoul อยู่แล้ว ไม่สร้างซ้ำ")
else
	local anchor = findSpawner("Spawner_Skeleton")
	if not anchor then
		warn("[Emerge] ไม่เจอ Spawner_Skeleton จึงไม่รู้จะวางผีดิบตรงไหน — ข้ามไป")
	elseif not ServerStorage:FindFirstChild("Model_mosterV2")
		or not ServerStorage.Model_mosterV2:FindFirstChild("Monster_Ghoul") then
		warn("[Emerge] ไม่เจอโมเดล Monster_Ghoul ใน ServerStorage — ข้ามไป")
	else
		local base = anchor:IsA("BasePart") and anchor.Position or anchor:GetPivot().Position
		-- เยื้องออกไปแล้วต้อง **หาพื้นจริงตรงนั้นเอง** ไม่ใช่ใช้ความสูงของจุดโครงกระดูก
		-- ห่างกัน 120 studs พื้นอาจสูงคนละระดับ การใช้ค่าเดิมจะได้สปอว์เนอร์ลอยอยู่กลางอากาศหรือจมอยู่ในเขา
		local wantX, wantZ = base.X + 120, base.Z
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { workspace:FindFirstChild("WOLD_Mobs") }
		params.IgnoreWater = true
		local hit = workspace:Raycast(Vector3.new(wantX, base.Y + 300, wantZ), Vector3.new(0, -900, 0), params)
		if not hit then
			warn("[Emerge] หาพื้นตรงจุดผีดิบไม่เจอ — ข้ามการสร้าง")
			hit = nil
		end

		if hit then
		local part = Instance.new("Part")
		part.Name = "Spawner_Ghoul"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(4, 1, 4)
		-- เยื้องจากโครงกระดูกไป 120 studs เพื่อไม่ให้สองฝูงทับกัน แต่ยังอยู่โซนเดียวกัน
		part.Position = Vector3.new(wantX, hit.Position.Y + 1, wantZ)
		part.Parent = workspace

		part:SetAttribute("MobKind", "Ghoul")
		part:SetAttribute("Count", 3)
		part:SetAttribute("Radius", 70)
		part:SetAttribute("Emerge", true)
		part:SetAttribute("TriggerRadius", TRIGGER_RADIUS)
		CollectionService:AddTag(part, SPAWNER_TAG)

		print(("[Emerge] สร้าง Spawner_Ghoul ที่ (%.0f, %.0f, %.0f)")
			:format(part.Position.X, part.Position.Y, part.Position.Z))
		changed += 1
		end
	end
end

print(("[Emerge] เสร็จ — ตั้งค่า %d จุด ข้าม %d จุด (สไลม์และอื่นๆ ไม่เปลี่ยน)"):format(changed, skipped))
