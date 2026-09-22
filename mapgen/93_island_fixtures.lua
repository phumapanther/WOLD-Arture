-- 93_island_fixtures.lua: ของประจำเกาะ — แท่นเกิดล่องหน · กำแพงล่องหนรอบขอบ · รั้วรอบผืนดินปลูกผัก
--
-- **ไม่แตะ terrain เลย** (ผู้ใช้ปั้นภูมิประเทศเอง) ทุกอย่างในนี้เป็น Part ที่ลบทิ้งแล้วสร้างใหม่ได้
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/93_island_fixtures.lua --no-lib
--
-- **รันซ้ำได้** ทุกส่วนสร้างใหม่ทับของเดิม · ไม่แตะ WOLD_Island.Placed / Fixed / Showroom
--
-- ⚠️ เลขวงรีของเกาะต้องตรงกับ mapgen/80_sky_island.lua และ ReplicatedStorage/IslandConfig.lua
local T = workspace.Terrain
local CENTER = Vector3.new(0, 800, 0)
local R, OVAL = 220, 0.90

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
-- SpawnLocation ยังต้องมีอยู่ (SpawnSelector หาตัวนี้ และ Roblox ใช้มันเกิดจริง) แค่มองไม่เห็น
--
-- ⚠️ **ต้อง `CanCollide = true`** (แก้ 2026-09-22: ผู้ใช้เข้าเซิร์ฟจริงแล้วร่วงทะลุเกาะ ลอยนิ่งกลางฟ้า)
--
-- ของเดิมปิด collide ไว้โดยให้เหตุผลว่า "ผิวดินอยู่ใต้มันพอดี" ซึ่งจริงตอนที่เขียน แต่ **ผู้ใช้แต่งเกาะเองได้
-- ตลอดเวลา** — ขุดสระ ปรับเนิน ย้ายดิน พอผิวดินใต้แท่นหายไปเมื่อไหร่ คนที่เกิดมาก็ไม่มีอะไรรองรับ
-- แล้วร่วงทะลุเกาะลงไปเรื่อยๆ (กำแพงขอบกันแค่ด้านข้าง ไม่ได้กันด้านล่าง)
--
-- แท่นที่ชนได้แต่มองไม่เห็นแก้ได้ทั้งสองทาง: ยืนได้เสมอไม่ว่าใต้มันจะเป็นอะไร และยังมองไม่เห็นอยู่ดี
local spawnLoc = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
if spawnLoc then
	local ground = groundAt(spawnLoc.Position.X, spawnLoc.Position.Z)
	if ground then
		spawnLoc.CFrame = CFrame.new(spawnLoc.Position.X, ground + spawnLoc.Size.Y / 2, spawnLoc.Position.Z)
	else
		-- ไม่มีผิวดินใต้จุดเกิด (ผู้ใช้ขุดออก) — ยกขึ้นไประดับกลางเกาะแล้วให้แท่นเป็นพื้นแทน
		spawnLoc.CFrame = CFrame.new(spawnLoc.Position.X, CENTER.Y + 17, spawnLoc.Position.Z)
		warn("[Fixtures] ไม่เจอผิวดินใต้จุดเกิด — ใช้แท่นเกิดเป็นพื้นแทน")
	end
	spawnLoc.Transparency = 1
	spawnLoc.Anchored = true
	spawnLoc.CanCollide = true
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
-- 2. (ถอดออกแล้ว) สระตกปลา
--------------------------------------------------------------------------------
-- **ผู้ใช้ขุดสระและทำทางตกปลาเองแล้ว** (2026-09-22) โค้ดขุดสระ ทางไม้ ใบบัว ดอกบัว ถูกถอดออกทั้งหมด
-- เฟสนี้จึงไม่แตะ terrain อีกเลย — เหลือแค่แท่นเกิด กำแพงขอบ และรั้วรอบผืนดิน ซึ่งล้วนเป็น Part
--
-- ตกปลาในน้ำของผู้ใช้ได้อยู่แล้ว: `Fishing.server` อ่าน Terrain Water ตรงๆ และเขต "สระบนเกาะ" ใน
-- `FishingConfig.Zones` (ศูนย์กลาง -95,-95 รัศมี 40) ทำให้ตกได้ครบทุกชนิดของเกมหลัก
-- ⚠️ ถ้าย้ายแหล่งน้ำไปไกลกว่ารัศมีนั้น ต้องไปแก้ `centre`/`radius` ของเขตนั้นให้ตรงกับน้ำจริง

--------------------------------------------------------------------------------
-- 3. กำแพงล่องหนรอบขอบ
--------------------------------------------------------------------------------
-- ⚠️ **ห้ามลบทั้งโฟลเดอร์** (แก้ 2026-09-22: ผู้ใช้แจ้งว่ากำแพงที่สร้างเองหายไป)
--
-- ของเดิม `EdgeWall:Destroy()` แล้วสร้างใหม่ ซึ่งลบ**ทุกอย่าง**ในนั้น รวมถึงกำแพงที่ผู้ใช้เพิ่มเอง
-- หรือชิ้นที่ลากย้ายไว้ · เฟสนี้เป็นเจ้าของเฉพาะชิ้นชื่อ `Seg00`-`Seg95` ที่มันปั้นเอง — ลบเฉพาะพวกนั้น
-- แล้วของที่ผู้ใช้วางเองรอดทุกครั้งที่รันซ้ำ (กติกาเดียวกับที่เฟส 91 ใช้กับ `Fixed`)
local wall = island:FindFirstChild("EdgeWall")
if not wall then
	wall = Instance.new("Folder"); wall.Name = "EdgeWall"; wall.Parent = island
end
-- ⚠️ **ตัดสินจากแอตทริบิวต์ ไม่ใช่จากชื่อ** (ผู้ใช้แจ้ง 2026-09-22: เคยสร้างกำแพงชื่อ `Seg00` ไว้เอง
-- แล้วหายไป) — ชื่อเป็นของใครก็ได้ ผู้ใช้ลอกชื่อเดิมมาตั้งเพราะมันสื่อความหมายดีอยู่แล้ว
-- เฟสปั๊ม `PhaseBuilt = true` บนชิ้นที่มันสร้าง แล้วลบเฉพาะชิ้นที่มีตรานั้น
--
-- ของเก่าที่สร้างไว้ก่อนมีตรานี้จะไม่มีแอตทริบิวต์ = **รอดทั้งหมด** ซึ่งปลอดภัยกว่าเดาผิดแล้วลบงานคน
local keptWall = 0
for _, c in ipairs(wall:GetChildren()) do
	if c:GetAttribute("PhaseBuilt") then c:Destroy() else keptWall += 1 end
end

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
	seg:SetAttribute("PhaseBuilt", true) -- ตราของเฟส: รันซ้ำแล้วลบเฉพาะชิ้นนี้ ไม่แตะของผู้ใช้
	seg.Parent = wall
	built += 1
end
if keptWall > 0 then
	print(("[Fixtures] คงกำแพงที่ผู้ใช้เพิ่มเองไว้ %d ชิ้น"):format(keptWall))
end

--------------------------------------------------------------------------------
-- 4. รั้วรอบผืนดินปลูกผัก
--------------------------------------------------------------------------------
-- **เดินตามขอบดินจริง ไม่ใช่กรอบสี่เหลี่ยมที่พิมพ์ไว้** ผู้ใช้ระบายดินรูปไหน ขยายทีหลัง หรือย้ายไปที่อื่น
-- รันเฟสนี้ซ้ำแล้วรั้วตามไปเอง · ช่องดิน = ช่องที่ผิวเป็นวัสดุ Ground (เหมือนที่ IslandGrid.isSoil ใช้)
local CELL = 4
-- ⚠️ เหตุผลเดียวกับ EdgeWall: ลบเฉพาะชิ้นที่เฟสนี้ปั้นเอง (`Rail` / `Post`) ของที่ผู้ใช้เพิ่มเองรอด
local fence = island:FindFirstChild("SoilFence")
if not fence then
	fence = Instance.new("Folder"); fence.Name = "SoilFence"; fence.Parent = island
end
local keptFence = 0
for _, c in ipairs(fence:GetChildren()) do
	if c:GetAttribute("PhaseBuilt") then c:Destroy() else keptFence += 1 end
end
if keptFence > 0 then
	print(("[Fixtures] คงรั้วที่ผู้ใช้เพิ่มเองไว้ %d ชิ้น"):format(keptFence))
end

local function soilAt(cx, cz)
	local wx = CENTER.X + (cx + 0.5) * CELL
	local wz = CENTER.Z + (cz + 0.5) * CELL
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { T }
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(wx, CENTER.Y + 80, wz), Vector3.new(0, -300, 0), params)
	return hit ~= nil and hit.Material == Enum.Material.Ground, hit and hit.Position.Y
end

-- สแกนทั้งเกาะหาช่องดิน (เกาะกว้าง 440 = ±55 ช่อง) แล้วเก็บขอบไว้: ช่องดินที่เพื่อนบ้านด้านนั้นไม่ใช่ดิน
local soil, edges = {}, {}
local minCX, maxCX, minCZ, maxCZ, soilCount = 1e9, -1e9, 1e9, -1e9, 0
for cx = -56, 56 do
	for cz = -56, 56 do
		local is, y = soilAt(cx, cz)
		if is then
			soil[cx .. "," .. cz] = y
			soilCount += 1
			minCX, maxCX = math.min(minCX, cx), math.max(maxCX, cx)
			minCZ, maxCZ = math.min(minCZ, cz), math.max(maxCZ, cz)
		end
	end
end

if soilCount == 0 then
	status("ไม่เจอผืนดิน (วัสดุ Ground) — ข้ามการทำรั้ว")
else
	-- ประตู: เว้นรั้วสองช่องติดกันตรงกึ่งกลางด้านที่หันเข้าหาจุดเกิด (ด้าน -X ถ้าดินอยู่ทางตะวันออกของจุดเกิด)
	local gateCZ = math.floor((minCZ + maxCZ) / 2)
	local gateSide = (minCX + maxCX) / 2 > 0 and "west" or "east"
	local DIRS = {
		{ dx = 0, dz = -1, along = "x" }, -- เหนือ
		{ dx = 0, dz = 1, along = "x" },  -- ใต้
		{ dx = -1, dz = 0, along = "z" }, -- ตะวันตก
		{ dx = 1, dz = 0, along = "z" },  -- ตะวันออก
	}
	local posts, rails = 0, 0
	for key, y in pairs(soil) do
		local cx, cz = key:match("(-?%d+),(-?%d+)")
		cx, cz = tonumber(cx), tonumber(cz)
		for _, d in ipairs(DIRS) do
			if not soil[(cx + d.dx) .. "," .. (cz + d.dz)] then
				-- ช่องประตู: สองช่องกลางด้านที่กำหนด ไม่ต้องมีรั้ว
				local isGate = (gateSide == "west" and d.dx == -1 or gateSide == "east" and d.dx == 1)
					and (cz == gateCZ or cz == gateCZ + 1)
				if not isGate then
					local wx = CENTER.X + (cx + 0.5) * CELL + d.dx * CELL / 2
					local wz = CENTER.Z + (cz + 0.5) * CELL + d.dz * CELL / 2
					local long = d.along == "x" and Vector3.new(CELL, 0.28, 0.24) or Vector3.new(0.24, 0.28, CELL)
					for _, ry in ipairs({ 1.2, 2.4 }) do
						local rail = Instance.new("Part")
						rail.Anchored = true
						rail.Name = "Rail"
						rail:SetAttribute("PhaseBuilt", true)
						rail.Size = long
						rail.CFrame = CFrame.new(wx, y + ry, wz)
						rail.Material = Enum.Material.Wood
						rail.Color = Color3.fromRGB(159, 124, 90)
						rail.Parent = fence
						rails += 1
					end
					local post = Instance.new("Part")
					post.Anchored = true
					post.Name = "Post"
					post:SetAttribute("PhaseBuilt", true)
					post.Size = Vector3.new(0.4, 3.2, 0.4)
					post.CFrame = CFrame.new(wx + (d.along == "x" and CELL / 2 or 0), y + 1.6, wz + (d.along == "z" and CELL / 2 or 0))
					post.Material = Enum.Material.Wood
					post.Color = Color3.fromRGB(110, 82, 58)
					post.Parent = fence
					posts += 1
				end
			end
		end
	end
	status(("รั้วรอบผืนดิน: ช่องดิน %d ช่อง · ราว %d เสา %d · ประตูด้าน%s"):format(soilCount, rails, posts, gateSide == "west" and "ตะวันตก" or "ตะวันออก"))
end

status(("done: กำแพง %d ชิ้น · แท่นเกิดล่องหน · รั้วผืนดิน"):format(built), true)
