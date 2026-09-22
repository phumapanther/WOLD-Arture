-- 93_island_fixtures.lua: ของประจำเกาะสามอย่าง — แท่นเกิดล่องหน · สระตกปลา · กำแพงล่องหนรอบขอบ
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/93_island_fixtures.lua --no-lib
--
-- **รันซ้ำได้** ทุกส่วนสร้างใหม่ทับของเดิม (สระขุดใหม่ทับรอยเดิมพอดี ไม่ลามขึ้นเรื่อยๆ)
-- ไม่แตะ WOLD_Island.Placed / Fixed / Showroom
--
-- ⚠️ เลขวงรีของเกาะต้องตรงกับ mapgen/80_sky_island.lua และ ReplicatedStorage/IslandConfig.lua
local T = workspace.Terrain
local CENTER = Vector3.new(0, 800, 0)
local R, OVAL = 220, 0.90

-- สระ: มุมซ้ายบนของเกาะตามผังเดิมใน docs/design/05-future-modes.md (บ่อน้ำอยู่ซ้ายบน)
-- กลางสระอยู่ที่ 55% ของรัศมี ยังห่างขอบ (EdgeMargin 24) สบายๆ และห่างจุดเกิดพอให้เดินไปถึงแต่ไม่เกะกะ
local POND_AT = Vector2.new(-95, -95)
local POND_R = 24 -- รัศมีปากสระ
local POND_DEPTH = 6 -- ลึกจากผิวดิน
local POND_LIP = 6 -- ขอบชายหาดที่ลาดลงไป

-- กำแพงล่องหน: สูงพอที่กระโดดสุดแรง (~7.5 studs) ไม่ข้าม และมองทะลุได้ทั้งหมด
local WALL_HEIGHT = 20
local WALL_THICK = 4
local WALL_SEGMENTS = 96 -- รอบวง ยิ่งมากยิ่งเนียน 96 ชิ้น = ทุก 3.75°
local WALL_MARGIN = 6 -- ตั้งเข้ามาจากขอบจริงเท่านี้ (กันยืนบนหน้าผาแล้วโผล่นอกกำแพง)

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[Fixtures] " .. msg)
end

local island = workspace:FindFirstChild("WOLD_Island")
if not island then island = Instance.new("Folder"); island.Name = "WOLD_Island"; island.Parent = workspace end

local function groundAt(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { T }
	params.IgnoreWater = true -- ต้องการผิวดิน ไม่ใช่ผิวน้ำ (ตอนรันซ้ำสระมีน้ำอยู่แล้ว)
	local hit = workspace:Raycast(Vector3.new(x, CENTER.Y + 120, z), Vector3.new(0, -400, 0), params)
	return hit and hit.Position.Y
end

status("start")

--------------------------------------------------------------------------------
-- 1. แท่นเกิดล่องหน
--------------------------------------------------------------------------------
-- SpawnLocation ยังต้องมีอยู่ (SpawnSelector หาตัวนี้ และ Roblox ใช้มันเกิดจริง) แค่มองไม่เห็นและเดินทะลุพื้นมันได้
-- CanCollide = false ปลอดภัยเพราะผิวดินอยู่ใต้มันพอดี — ไม่ใช่แท่นลอย
local spawnLoc = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
if spawnLoc then
	local ground = groundAt(spawnLoc.Position.X, spawnLoc.Position.Z)
	if ground then
		spawnLoc.CFrame = CFrame.new(spawnLoc.Position.X, ground + spawnLoc.Size.Y / 2, spawnLoc.Position.Z)
	end
	spawnLoc.Transparency = 1
	spawnLoc.CanCollide = false
	spawnLoc.CanQuery = false
	spawnLoc.CanTouch = false
	-- แผ่นตกแต่งที่มากับแท่นเกิด (Decal/SurfaceGui) ทำให้ยัง "เห็น" ได้แม้ Transparency = 1
	for _, d in ipairs(spawnLoc:GetDescendants()) do
		if d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceGui") or d:IsA("ParticleEmitter") then d:Destroy() end
	end
	status("แท่นเกิดล่องหนแล้ว")
else
	warn("[Fixtures] ไม่เจอ SpawnLocation")
end

--------------------------------------------------------------------------------
-- 2. สระตกปลา
--------------------------------------------------------------------------------
-- **แกนของ FillCylinder วิ่งตาม UP vector ของ CFrame** — ไม่หมุนคือทรงกระบอก "ตั้ง" ที่ต้องการ
-- (เผลอใส่ roll 90° รอบแรก ได้กระบอกนอน = กำแพงทรายแนวเหนือ-ใต้ ไม่ใช่สระ · ดู mapgen/60_elderwood.lua:381)
-- **ผิวน้ำต้องต่ำกว่าผิวดินรอบๆ** ไม่งั้นน้ำล้นออกมาเป็นแผ่นบนสนามหญ้า
-- ผิวดินอ้างอิง = ค่าเฉลี่ยของแปดจุดรอบนอกหลุม (พื้นเกาะลาดเอียง ใช้จุดเดียวได้สระเอียงตาม)
-- วัด **ก่อน** แตะอะไร และวัดจากวงที่อยู่นอกเขตขุด จึงรันซ้ำได้โดยไม่ไหลสูงขึ้นทุกรอบ
local samples, sum = 0, 0
for i = 0, 7 do
	local a = i * math.pi / 4
	local rr = POND_R + POND_LIP + 10
	local h = groundAt(POND_AT.X + math.cos(a) * rr, POND_AT.Y + math.sin(a) * rr)
	if h then sum += h; samples += 1 end
end
local pondSurface = samples > 0 and (sum / samples) or nil
if not pondSurface then
	warn("[Fixtures] หาผิวดินรอบสระไม่เจอ ข้ามการขุดสระ")
else
	local bottom = pondSurface - POND_DEPTH
	local waterTop = pondSurface - 1.2 -- ผิวน้ำต่ำกว่าขอบ ไม่งั้นน้ำล้นเป็นแผ่นบนหญ้า

	-- 1) เติมดินให้เต็มก่อน (รันซ้ำ/หลังเคยเจาะพลาด จะได้เริ่มจากพื้นราบเสมอ) แล้วคลุมหญ้าบาง ๆ
	T:FillCylinder(CFrame.new(POND_AT.X, pondSurface - 30, POND_AT.Y), 60, POND_R + POND_LIP + 4, Enum.Material.Ground)
	T:FillCylinder(CFrame.new(POND_AT.X, pondSurface - 1, POND_AT.Y), 2, POND_R + POND_LIP + 4, Enum.Material.Grass)
	-- 2) คว้านอากาศเหนือผิวดินทิ้ง (เผื่อมีอะไรค้าง)
	T:FillCylinder(CFrame.new(POND_AT.X, pondSurface + 40, POND_AT.Y), 80, POND_R + POND_LIP + 4, Enum.Material.Air)

	-- 3) ขุดชาม: วงแหวนซ้อนกันเป็นขั้นบันได นอกตื้น ในลึก (FillCylinder ไม่มีทรงกรวย)
	local rings = 10
	for i = 1, rings do
		local t = i / rings -- 1 = วงในสุด ลึกสุด
		local radius = (POND_R + POND_LIP) * (1 - t) + POND_R * t * 0.98
		local depth = POND_DEPTH * t
		T:FillCylinder(CFrame.new(POND_AT.X, pondSurface - depth / 2 + 0.5, POND_AT.Y), depth + 1, radius, Enum.Material.Air)
	end
	-- 4) ก้นสระเป็นทราย แล้วเติมน้ำถึงผิวน้ำที่ตั้งไว้
	T:FillCylinder(CFrame.new(POND_AT.X, bottom - 1, POND_AT.Y), 3, POND_R + POND_LIP, Enum.Material.Sand)
	T:FillCylinder(CFrame.new(POND_AT.X, (bottom + waterTop) / 2, POND_AT.Y), waterTop - bottom, POND_R * 0.98, Enum.Material.Water)

	status(("ขุดสระที่ (%.0f, %.0f) รัศมี %d ลึก %d ผิวดิน y=%.1f ผิวน้ำ y=%.1f"):format(POND_AT.X, POND_AT.Y, POND_R, POND_DEPTH, pondSurface, waterTop))
end

--------------------------------------------------------------------------------
-- 3. กำแพงล่องหนรอบขอบ
--------------------------------------------------------------------------------
local oldWall = island:FindFirstChild("EdgeWall")
if oldWall then oldWall:Destroy() end
local wall = Instance.new("Folder"); wall.Name = "EdgeWall"; wall.Parent = island

-- วงรีเดียวกับเกาะ หดเข้ามา WALL_MARGIN · แต่ละชิ้นหันด้านหนาเข้าหาศูนย์กลาง และยาวพอให้ชนกับชิ้นข้างๆ
local rx, rz = R - WALL_MARGIN, (R - WALL_MARGIN) * OVAL
local built = 0
for i = 0, WALL_SEGMENTS - 1 do
	local a0 = (i / WALL_SEGMENTS) * math.pi * 2
	local a1 = ((i + 1) / WALL_SEGMENTS) * math.pi * 2
	local p0 = Vector2.new(math.cos(a0) * rx, math.sin(a0) * rz)
	local p1 = Vector2.new(math.cos(a1) * rx, math.sin(a1) * rz)
	local mid = (p0 + p1) / 2
	local span = (p1 - p0).Magnitude

	local ground = groundAt(CENTER.X + mid.X, CENTER.Z + mid.Y) or (CENTER.Y + 16)
	local seg = Instance.new("Part")
	seg.Name = ("Seg%02d"):format(i)
	seg.Anchored = true
	seg.Transparency = 1
	seg.CanCollide = true
	seg.CanQuery = false -- เรย์ของระบบวางของ/ตกปลา ต้องมองทะลุกำแพงไปเจอพื้น
	seg.CanTouch = false
	seg.Material = Enum.Material.SmoothPlastic
	seg.Size = Vector3.new(span + 2, WALL_HEIGHT, WALL_THICK) -- +2 ให้ซ้อนกับชิ้นถัดไป ไม่มีร่องให้ลอด
	seg.CFrame = CFrame.new(CENTER.X + mid.X, ground + WALL_HEIGHT / 2, CENTER.Z + mid.Y)
		* CFrame.Angles(0, -math.atan2(p1.Y - p0.Y, p1.X - p0.X), 0)
	seg.Parent = wall
	built += 1
end

status(("done: กำแพง %d ชิ้น สูง %d รอบวงรี %.0f x %.0f · สระ · แท่นเกิดล่องหน"):format(built, WALL_HEIGHT, rx * 2, rz * 2), true)
