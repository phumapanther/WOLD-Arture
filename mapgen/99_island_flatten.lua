-- 99_island_flatten.lua: ปรับ **เฉพาะหญ้ากับดิน** บนเกาะให้เป็นระนาบเดียว
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/99_island_flatten.lua --no-lib
--
-- ผู้ใช้สั่ง 2026-09-22: "เกาะทั้งเกาะมันไม่เรียบเป็นเนิน แก้ได้ไหม แบบไม่ให้กระทบโมเดล fix ที่ตั้งไว้"
-- แล้วระบุขอบเขตตามมาสองรอบ:
--   · "ภูเขากับน้ำที่ไว้ตกปลาตรงนั้นก็อย่าไปแตะ ให้มันเรียบ"
--   · "แค่ส่วนที่เป็นหญ้าสำหรับวางโมเดลตกแต่ง กับส่วนที่เป็นดินสำหรับวางแปลงผัก ให้มันแบน ก็พอ"
--
-- ⚠️ **ใช้ ReadVoxels/WriteVoxels ห้าม FillBlock** สองตัวนั้นเขียนทับทุกอย่างในกรอบ รวมหินที่ผู้ใช้
-- แต่งไว้และน้ำในบ่อ (บทเรียนเดียวกับ `95_island_water_level`)
--
-- **ของที่ผู้ใช้วางเองขยับตามพื้นของตัวมันเอง ไม่ใช่ตามค่าเดียวทั้งเกาะ** — `WOLD_Island.Fixed` มีกลุ่ม
-- ที่กว้าง 180 สตัด (Ruin_WallFragment) ซึ่งคร่อมพื้นหลายระดับ ถ้าเลื่อนทั้งกลุ่มด้วยค่าเดียวจะมีชิ้น
-- ลอยและชิ้นจม จึงวัดพื้นใต้ **ทีละชิ้น** ก่อนปรับ แล้วเลื่อนชิ้นนั้นด้วยส่วนต่างของคอลัมน์ตัวเอง
-- · คอลัมน์ที่ไม่ถูกแตะ (ภูเขา/บ่อ) ส่วนต่างเป็น 0 เอง ของที่อยู่ตรงนั้นจึงไม่ขยับเลย
--
-- **ของที่ซื้อมาวาง (`Placed`) ไม่ต้องขยับ** `IslandBuild` ปลูกมันใหม่จากโปรไฟล์ทุกครั้งที่เซิร์ฟบูต
-- โดยหาผิวดินเองด้วย `groundAt` — มันจะลงมาอยู่บนพื้นใหม่ให้เอง
--
-- **ย้อนกลับได้**: เฟสสำรองเทอร์เรนไว้ที่ `ServerStorage.FlattenBackup` ก่อนแตะอะไร คืนค่าด้วย
--     workspace.Terrain:PasteRegion(game.ServerStorage.FlattenBackup, <corner>, true)
-- โดย `<corner>` อ่านจากแอตทริบิวต์ `Corner` บนตัว backup (เป็น Vector3int16 หน่วย voxel)

local T = workspace.Terrain
local SS = game:GetService("ServerStorage")

local RES = 4 -- ขนาด voxel ของ Terrain
-- **ผิวที่เห็นจริงสูงกว่าเลขที่เขียนลง voxel อยู่ 2 สตัด** (วัดแล้ว: สั่ง 810 ได้ผิว 812.0)
-- เทอร์เรนแบบ smooth วาดผิวจาก isosurface ระหว่าง voxel ข้างเคียง ไม่ใช่ที่ระดับความตันตรงๆ
-- ตัวแปรที่อ่านง่ายคือ "อยากให้ผิวอยู่ที่ไหน" ส่วน TARGET เป็นค่าที่ต้องเขียนเพื่อให้ได้แบบนั้น
local SURFACE = 812 -- ระดับผิวที่ต้องการให้เห็น (สูงกว่าผิวน้ำบ่อ 808 อยู่ 4 สตัด บ่อจึงยังเป็นบ่อ)
local TARGET = SURFACE - 2

-- **มาจากการวัด ไม่ใช่ตั้งเอง**: ยิงเรย์ 8,793 จุดทั่วเกาะแล้วแยกตามวัสดุ
--   · หญ้า/ดิน 7,712 จุด — ต่ำ 769.9 · p10 802.9 · **p50 809.7** · p90 816.3 · สูง 819.5
--   · หิน 1,081 จุด — กระจุกอยู่ x -188..0 z -192..-44 (ภูเขาที่ผู้ใช้ปั้น) สูงถึง 852
-- 810 คือค่ากลางปัดเศษ = ยกกับลดพอๆ กัน และสูงกว่าผิวน้ำบ่อ (808) อยู่ 2 สตัด บ่อจึงยังเป็นบ่อ

local BOUNDS = { x0 = -224, x1 = 224, z0 = -224, z1 = 224, y0 = 760, y1 = 864 }
local CHUNK = 64

-- แตะเฉพาะคอลัมน์ที่ผิวอยู่ในช่วงนี้ — นอกช่วงคือ **ขอบเกาะที่ลาดลงไป** (ต่ำสุดที่วัดได้ 769.9)
-- ถ้าดึงขอบขึ้นมาเป็น 810 ด้วย จะได้กำแพงดินล้อมเกาะแทนที่จะเป็นเกาะลอยฟ้า
local WINDOW = 14 -- 796..824

local MARGIN = 2 -- เว้นระยะรอบภูเขา/บ่อ กี่ voxel (2 = 8 สตัด) ตีนเขาจะได้ไม่ถูกตัดเป็นหน้าผา

-- **ไล่ระดับเข้าหาขอบ กี่ voxel** (4 = 16 สตัด) — ถ้าตัดตรงๆ คอลัมน์ที่ 797 (อยู่ในช่วงพอดี) จะถูกยก
-- ขึ้น 810 ส่วนเพื่อนบ้านที่ 795 (เกินช่วง) อยู่ที่เดิม = **กำแพงดิน 15 สตัดรอบขอบเกาะ**
-- คอลัมน์ที่อยู่ห่างจากของที่ห้ามแตะไม่ถึงระยะนี้จึงได้เป้าหมายที่ไล่ระดับ ไม่ใช่ 810 เต็ม
local BLEND = 4
local FILL_DEPTH = 16 -- ตอนยกพื้นขึ้น เติมเนื้อดินลงไปลึกเท่านี้ (ไม่ไล่เติมจนถึงใต้เกาะ)

assert(game.PlaceId == 136992335889132 or game.PlaceId == 0, "เฟสนี้สำหรับเพลสเกาะเท่านั้น")

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[Flatten] " .. msg)
end

local AIR = Enum.Material.Air
local WATER = Enum.Material.Water
local SOFT = { [Enum.Material.Grass] = true, [Enum.Material.Ground] = true }

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { T }
rayParams.IgnoreWater = true

local function groundAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, BOUNDS.y1 + 40, z), Vector3.new(0, -400, 0), rayParams)
	return hit and hit.Position.Y or nil
end

--------------------------------------------------------------------------------
-- 0. สำรอง
--------------------------------------------------------------------------------
-- ⚠️ **ไม่ทับสำรองเดิม** รันเฟสซ้ำบนพื้นที่เรียบไปแล้วจะได้สำรองของพื้นเรียบ = ย้อนกลับไม่ได้อีก
-- อยากถ่ายสำรองใหม่จริงๆ ให้ลบ `ServerStorage.FlattenBackup` ทิ้งเองก่อน
-- ⚠️ `CopyRegion` รับ **Region3int16 ซึ่งนับเป็นหน่วย voxel (stud ÷ 4)** ไม่ใช่ studs
if SS:FindFirstChild("FlattenBackup") then
	status("มีสำรองอยู่แล้ว (ไม่ถ่ายใหม่ กันทับของเดิม)")
else
	local corner = Vector3int16.new(BOUNDS.x0 / RES, BOUNDS.y0 / RES, BOUNDS.z0 / RES)
	local far = Vector3int16.new(BOUNDS.x1 / RES, BOUNDS.y1 / RES, BOUNDS.z1 / RES)
	local backup = T:CopyRegion(Region3int16.new(corner, far))
	backup.Name = "FlattenBackup"
	backup:SetAttribute("Corner", ("%d,%d,%d"):format(corner.X, corner.Y, corner.Z))
	backup.Parent = SS
	status("สำรองเทอร์เรนไว้ที่ ServerStorage.FlattenBackup แล้ว")
end

--------------------------------------------------------------------------------
-- 1. จำพื้นใต้ของที่ผู้ใช้วางไว้ **ก่อน** แตะอะไร
--------------------------------------------------------------------------------
local isl = workspace:FindFirstChild("WOLD_Island")
local fixed = isl and isl:FindFirstChild("Fixed")
-- ⚠️ **ตัวละคร (โมเดลที่มี Humanoid) ต้องขยับทั้งตัว ห้ามขยับทีละชิ้น**
--
-- แขนขาถูกขับด้วย Motor6D ไม่ใช่ด้วย CFrame ของตัวเอง — เขียน CFrame รายชิ้นจึงไม่มีความหมาย
-- และถ้าชิ้นส่วนไม่ได้ anchored การดันพื้นขึ้นใต้ตัวมันคือการยัดเทอร์เรนเข้าไปในร่าง ซึ่งจบได้ทั้ง
-- "เด้งกระเด็น" และ "ทะลุเกาะร่วงลงไป" — ร่วงพ้น `FallenPartsDestroyHeight` เมื่อไหร่เอนจินลบทิ้งให้เลย
-- (สงสัยว่านี่คือสาเหตุที่บาร์นาบีหายไปหลังรันเฟสนี้ 2026-09-22)
local function rigOf(part)
	local m = part:FindFirstAncestorWhichIsA("Model")
	while m and m ~= fixed do
		if m:FindFirstChildWhichIsA("Humanoid") then return m end
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

local before, beforeRig = {}, {}
local fixedParts = 0
for _, m in ipairs(fixed and fixed:GetDescendants() or {}) do
	if m:IsA("BasePart") then
		local rig = rigOf(m)
		if rig then
			if beforeRig[rig] == nil then
				local at = rig:GetPivot().Position
				beforeRig[rig] = groundAt(at.X, at.Z) or false
			end
		else
			before[m] = groundAt(m.Position.X, m.Position.Z)
			fixedParts += 1
		end
	end
end
local rigCount = 0
for _ in pairs(beforeRig) do rigCount += 1 end
status(("จำพื้นใต้ของที่ตั้งไว้เอง %d ชิ้น · ตัวละคร %d ตัว (ขยับทั้งตัว)"):format(fixedParts, rigCount))

--------------------------------------------------------------------------------
-- 2. รอบแรก: ดูว่าคอลัมน์ไหนแตะได้ (ยังไม่เขียนอะไร)
--------------------------------------------------------------------------------
-- คีย์เป็น "ดัชนีคอลัมน์" ในหน่วย voxel ของทั้งเกาะ เพื่อให้ระยะเว้นข้ามขอบก้อนได้
local function key(cx, cz) return cx * 100000 + cz end

local surface, blocked = {}, {}
for bx = BOUNDS.x0, BOUNDS.x1 - 1, CHUNK do
	for bz = BOUNDS.z0, BOUNDS.z1 - 1, CHUNK do
		local region = Region3.new(
			Vector3.new(bx, BOUNDS.y0, bz),
			Vector3.new(math.min(bx + CHUNK, BOUNDS.x1), BOUNDS.y1, math.min(bz + CHUNK, BOUNDS.z1))
		):ExpandToGrid(RES)
		local mats, occs = T:ReadVoxels(region, RES)
		local sx, sy, sz = mats.Size.X, mats.Size.Y, mats.Size.Z
		local base = region.CFrame.Position - region.Size / 2

		for i = 1, sx do
			for k = 1, sz do
				local cx = math.floor((base.X + (i - 0.5) * RES) / RES)
				local cz = math.floor((base.Z + (k - 0.5) * RES) / RES)
				local topY, topMat, hasWater = nil, nil, false
				for j = 1, sy do
					local m = mats[i][j][k]
					if m == WATER then hasWater = true end
					if m ~= AIR and occs[i][j][k] > 0 then
						topY = base.Y + (j - 0.5) * RES
						topMat = m
					end
				end
				if topY then
					-- **บ่อกับภูเขาไม่แตะ** (ผู้ใช้สั่ง) · ขอบเกาะที่ลาดลงไปก็ไม่แตะ
					if hasWater or not SOFT[topMat] or math.abs(topY - TARGET) > WINDOW then
						blocked[key(cx, cz)] = true
					else
						surface[key(cx, cz)] = { y = topY, mat = topMat, cx = cx, cz = cz }
					end
				end
			end
		end
	end
end

-- เว้นระยะรอบสิ่งที่ห้ามแตะ — ตัดพื้นชิดตีนเขาเป็นหน้าผาตรงๆ ดูแย่กว่าปล่อยให้ลาดต่อ
local grown = {}
for k2 in pairs(blocked) do grown[k2] = true end
for _, s in pairs(surface) do
	for dx = -MARGIN, MARGIN do
		for dz = -MARGIN, MARGIN do
			if blocked[key(s.cx + dx, s.cz + dz)] then grown[key(s.cx, s.cz)] = true end
		end
	end
end

-- ระยะจากขอบ (BFS หลายต้นทางจากทุกคอลัมน์ที่ห้ามแตะ) แล้วแปลงเป็นเป้าหมายของคอลัมน์นั้น
local dist, frontier = {}, {}
for _, s in pairs(surface) do
	if grown[key(s.cx, s.cz)] then
		dist[key(s.cx, s.cz)] = 0
		frontier[#frontier + 1] = s
	end
end
-- คอลัมน์ที่ไม่มีผิวเลย (อากาศนอกเกาะ) ก็เป็นขอบ — หาจากเพื่อนบ้านของคอลัมน์ที่แตะได้
for _, s in pairs(surface) do
	local k2 = key(s.cx, s.cz)
	if dist[k2] == nil then
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local n = key(s.cx + d[1], s.cz + d[2])
			if surface[n] == nil and blocked[n] == nil then
				dist[k2] = 0
				frontier[#frontier + 1] = s
				break
			end
		end
	end
end
local head = 1
while head <= #frontier do
	local s = frontier[head]; head += 1
	local d0 = dist[key(s.cx, s.cz)]
	if d0 < BLEND then
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local n = surface[key(s.cx + d[1], s.cz + d[2])]
			if n and dist[key(n.cx, n.cz)] == nil then
				dist[key(n.cx, n.cz)] = d0 + 1
				frontier[#frontier + 1] = n
			end
		end
	end
end
for _, s in pairs(surface) do
	local d = dist[key(s.cx, s.cz)]
	if d == nil then
		s.target = TARGET -- ไกลจากขอบพอ เรียบเต็มที่
	else
		s.target = s.y + (TARGET - s.y) * (d / (BLEND + 1))
	end
end

local editable, untouched, blended = 0, 0, 0
for k2, s in pairs(surface) do
	if grown[k2] then
		untouched += 1
	else
		editable += 1
		if dist[k2] then blended += 1 end
	end
end
for _ in pairs(blocked) do untouched += 1 end
status(("คอลัมน์: เรียบเต็มที่ %d · ไล่ระดับเข้าขอบ %d · ไม่แตะ %d (ภูเขา/บ่อ/ขอบเกาะ)")
	:format(editable - blended, blended, untouched))

--------------------------------------------------------------------------------
-- 3. รอบสอง: เขียนจริง
--------------------------------------------------------------------------------
local raised, lowered = 0, 0
for bx = BOUNDS.x0, BOUNDS.x1 - 1, CHUNK do
	for bz = BOUNDS.z0, BOUNDS.z1 - 1, CHUNK do
		local region = Region3.new(
			Vector3.new(bx, BOUNDS.y0, bz),
			Vector3.new(math.min(bx + CHUNK, BOUNDS.x1), BOUNDS.y1, math.min(bz + CHUNK, BOUNDS.z1))
		):ExpandToGrid(RES)
		local mats, occs = T:ReadVoxels(region, RES)
		local sx, sy, sz = mats.Size.X, mats.Size.Y, mats.Size.Z
		local base = region.CFrame.Position - region.Size / 2
		local touched = false

		for i = 1, sx do
			for k = 1, sz do
				local cx = math.floor((base.X + (i - 0.5) * RES) / RES)
				local cz = math.floor((base.Z + (k - 0.5) * RES) / RES)
				local s = surface[key(cx, cz)]
				if s and not grown[key(cx, cz)] then
					local goal = s.target
					if s.y > goal then lowered += 1 else raised += 1 end
					for j = 1, sy do
						local bottom = base.Y + (j - 1) * RES
						local top = bottom + RES
						local m = mats[i][j][k]
						if top <= goal then
							-- ใต้ผิวใหม่: ต้องตัน · **เติมเฉพาะช่องอากาศ และเฉพาะช่วงตื้น**
							-- ของที่เป็นดิน/หินอยู่แล้วไม่ถูกแตะ (ไม่ทับงานที่ผู้ใช้แต่งไว้ใต้ผิว)
							if (m == AIR or occs[i][j][k] < 1) and bottom >= goal - FILL_DEPTH then
								mats[i][j][k] = (m == AIR) and s.mat or m
								occs[i][j][k] = 1
								touched = true
							end
						elseif bottom >= goal then
							-- เหนือผิวใหม่: โกนเนินทิ้ง **เฉพาะดิน/หญ้า** หินที่โผล่มาไม่แตะ
							if m ~= AIR and SOFT[m] then
								mats[i][j][k], occs[i][j][k] = AIR, 0
								touched = true
							end
						else
							-- ช่องที่ผิวใหม่พาดผ่าน: ความตันเป็นเศษส่วน ผิวจึงอยู่ที่ TARGET เป๊ะ
							-- ไม่ใช่ขั้นบันไดทีละ 4 สตัด
							local want = (goal - bottom) / RES
							if m == AIR or SOFT[m] then
								mats[i][j][k] = s.mat
								occs[i][j][k] = want
								touched = true
							end
						end
					end
				end
			end
		end

		if touched then T:WriteVoxels(region, RES, mats, occs) end
	end
end
-- ⚠️ **ต้องรอให้เทอร์เรนสร้าง collision ใหม่ก่อนยิงเรย์** (เจอจริง 2026-09-22: รอบแรกของที่ตั้งไว้
-- ไม่ขยับสักชิ้น เพราะเรย์ยังชนผิวเก่าอยู่) `WriteVoxels` คืนค่าทันทีก็จริง แต่ collision mesh
-- ถูกสร้างใหม่นอกเธรด — เรย์ในเฟรมเดียวกันจึงยังเห็นพื้นเดิมทุกจุด
for _ = 1, 10 do task.wait() end
status(("ปรับพื้นแล้ว: ยกขึ้น %d คอลัมน์ · ลดลง %d คอลัมน์ (ผิวที่ %d)"):format(raised, lowered, SURFACE))

--------------------------------------------------------------------------------
-- 4. ของที่ผู้ใช้ตั้งไว้เอง ตามพื้นของตัวมันเองขึ้นมา
--------------------------------------------------------------------------------
local moved, stayed, skipped = 0, 0, 0
for part, oldY in pairs(before) do
	if part.Parent then
		local newY = groundAt(part.Position.X, part.Position.Z)
		if not oldY or not newY then
			skipped += 1
		else
			local delta = newY - oldY
			if math.abs(delta) < 0.05 then
				stayed += 1 -- คอลัมน์นี้ไม่ถูกแตะ (ภูเขา/บ่อ) ของจึงอยู่ที่เดิมเป๊ะ
			elseif math.abs(delta) > WINDOW + RES then
				skipped += 1 -- ขยับเกินที่ควรเป็น ไม่เดา ปล่อยไว้ให้ผู้ใช้ดูเอง
			else
				part.CFrame = part.CFrame + Vector3.new(0, delta, 0)
				moved += 1
			end
		end
	end
end
-- ตัวละคร: ขยับทีละตัวด้วย PivotTo แล้วยกให้พ้นพื้นนิดหนึ่ง เผื่อฟิสิกส์ยังไม่ทันรู้ว่าพื้นขยับ
local rigsMoved = 0
for rig, oldY in pairs(beforeRig) do
	if rig.Parent and oldY then
		local at = rig:GetPivot().Position
		local newY = groundAt(at.X, at.Z)
		if newY and math.abs(newY - oldY) >= 0.05 and math.abs(newY - oldY) <= WINDOW + RES then
			pcall(function() rig:PivotTo(rig:GetPivot() + Vector3.new(0, newY - oldY + 0.5, 0)) end)
			rigsMoved += 1
		end
	end
end
status(("ของที่ตั้งไว้เอง: ขยับตามพื้น %d ชิ้น · อยู่ที่เดิม %d · ข้าม %d · ตัวละคร %d ตัว")
	:format(moved, stayed, skipped, rigsMoved))

status(("done: พื้นหญ้า/ดินเรียบที่ y=%d · ภูเขา บ่อ และขอบเกาะไม่ถูกแตะ"):format(SURFACE), true)
