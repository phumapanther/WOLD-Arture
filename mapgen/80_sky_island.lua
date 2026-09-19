-- 80_sky_island.lua: เกาะลอยฟ้าของโหมดฟาร์มมิ่ง — **ตัวเกาะเปล่าๆ อย่างเดียว** (ผู้ใช้จะตกแต่งเอง)
--
-- รูปทรงตามภาพอ้างอิงที่ผู้ใช้ส่งมา: จานหญ้ากว้างโค้งนิดๆ ด้านบน · ขอบหญ้าย้อยลงมาคลุมขอบหิน ·
-- ใต้ดินเป็นกรวยหินสีน้ำตาลแดงคว่ำ ปลายแหลมเป็นแง่งไม่เท่ากัน ไม่ใช่กรวยเรียบ
--
-- **รันได้ในเพลสเปล่าๆ โดยไม่ต้องพึ่ง lib**: ไฟล์นี้ยืนได้ด้วยตัวเอง (ไม่ใช้ `L.*` ไม่ใช้ world-layout)
-- เพราะปลายทางจริงคือเพลส `WOLD Farming` ที่ยังไม่มีอะไรอยู่ในนั้นเลย
--     node tools/run-luau.js mapgen/80_sky_island.lua --no-lib
--
-- ดูรูปทรงก่อนสร้างเพลสจริง: ตั้ง `workspace:SetAttribute("SkyIslandOrigin", Vector3.new(x, y, z))`
-- ให้ไปโผล่ไกลๆ นอกแมพหลัก แล้วรันในเพลสหลักได้ ลบทิ้งทีหลังด้วย `workspace:SetAttribute("SkyIslandErase", true)`
--
-- **ไม่แตะอะไรนอกบริเวณของตัวเอง**: ไม่ Terrain:Clear() ไม่ลบโมเดลใคร เขียนวอกเซลเฉพาะกล่องของเกาะ
-- เท่านั้น — เพลสหลักจึงปลอดภัยแม้จะรันผิดที่

local T = workspace.Terrain
local RES = 4 -- ขนาดวอกเซลของ Roblox ตายตัว 4 สตัด ทุกพิกัดด้านล่างต้องลงตัวกับเลขนี้

--------------------------------------------------------------------------------
-- ตัวเลขทั้งหมดของเกาะ — แก้ตรงนี้ที่เดียว
--------------------------------------------------------------------------------

local R = 220          -- รัศมีจานหญ้า (เส้นผ่าศูนย์กลาง 440 สตัด) พอสำหรับผัง 8 โซนในแผน
local DOME = 16        -- กลางเกาะนูนกว่าขอบเท่านี้ — โค้งพอให้ไม่เป็นจานแบน แต่ยังวางของได้ทุกที่
local GRASS = 12       -- ความหนาชั้นหญ้าที่กลางเกาะ (ขอบบางลงเอง)
local DIRT = 14        -- ชั้นดินสีน้ำตาลใต้หญ้า ก่อนถึงหิน
local DEPTH = 300      -- ความลึกจากผิวถึงปลายแหลมล่างสุด
local TAPER = 1.45     -- ยิ่งมากกรวยยิ่งผอมและแหลม (1.0 = กรวยตรงๆ)
local EDGE_NOISE = 0.035 -- ขอบเกาะหยักไม่กลมเป๊ะ (สัดส่วนของ R) มากไปได้แหว่งเป็นเว้า น้อยไปได้จานกลมเป๊ะ
local OVAL = 0.90      -- เกาะรีเล็กน้อยตามภาพอ้างอิง (แกน Z สั้นกว่าแกน X เท่านี้)
local SPIKES = 5       -- จำนวนแง่งยาวที่ห้อยลงจากก้นเกาะ
-- **ความหนาขั้นต่ำของขอบเกาะ** — ถ้าปล่อยให้ความหนาเรียวเป็นศูนย์ที่ขอบ วอกเซลแถวสุดท้ายจะมี
-- occupancy บางเฉียบ แล้วตัวปั้นผิวของ Roblox จะดันมันออกมาเป็นครีบแหลมรอบเกาะ (เจอมาแล้วรอบแรก)
-- ขอบที่หนาพอจะจบเป็นหน้าผาคมๆ เหมือนในภาพอ้างอิงแทน
local RIM = 22
local SEED = 20260919

-- สีตามภาพอ้างอิง: หญ้าเขียวอมเหลือง ดินน้ำตาลแดง หินเข้มกว่าแต่ยังเป็นน้ำตาลแดง ไม่ใช่เทา
-- (ในเพลสหลักมีหมอก/บรรยากาศของแมพใหญ่คลุมอยู่ สีที่เห็นตอนพรีวิวจะจมกว่าของจริงในเพลสเกาะ)
local GRASS_COLOR = Color3.fromRGB(96, 152, 48)
local DIRT_COLOR = Color3.fromRGB(134, 74, 50)
local ROCK_COLOR = Color3.fromRGB(112, 56, 46)

local ORIGIN = workspace:GetAttribute("SkyIslandOrigin") or Vector3.new(0, 800, 0)
local ERASE = workspace:GetAttribute("SkyIslandErase") == true

-- รายงานผ่านโฟลเดอร์ `workspace.WOLD` เหมือนเฟสอื่น เพราะ `tools/run-luau.js` รอดูแอตทริบิวต์
-- Status/Progress ที่นั่น ไม่งั้นตัวรันจะนั่งรอจนหมดเวลาโดยที่งานเสร็จไปนานแล้ว
local function root()
	local f = workspace:FindFirstChild("WOLD")
	if not f then
		f = Instance.new("Folder")
		f.Name = "WOLD"
		f.Parent = workspace
	end
	return f
end

local function status(msg, done)
	local f = root()
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[SkyIsland] " .. msg)
end

-- **กันรันผิดเพลส**: เพลสหลักมีแมพจริงอยู่ การหย่อนเกาะลงกลางแมพโดยไม่ได้ตั้งใจคือของที่ต้องตามลบ
-- ตั้งพิกัดเองเมื่อไหร่ถือว่ารู้ตัวแล้ว (ใช้ตอนอยากดูรูปทรงไกลๆ นอกแมพก่อนสร้างเพลสจริง)
local MAIN_PLACE = 88774255487951
if game.PlaceId == MAIN_PLACE and workspace:GetAttribute("SkyIslandOrigin") == nil then
	status("หยุด: นี่คือเพลสหลัก ถ้าตั้งใจจะดูรูปทรงที่นี่ ให้ตั้ง workspace:SetAttribute(\"SkyIslandOrigin\", Vector3.new(20000, 2500, 0)) ก่อน", true)
	return
end

--------------------------------------------------------------------------------
-- รูปทรง
--------------------------------------------------------------------------------

-- Perlin ของ Roblox เอง คืนค่าราว [-0.5, 0.5] — ซ้อนสามชั้นให้ได้ความหยาบที่ไม่ซ้ำแบบ
local function fbm(x, z, scale, octaves)
	local sum, amp, freq, norm = 0, 1, 1 / scale, 0
	for _ = 1, octaves or 3 do
		sum += math.noise(x * freq, z * freq, SEED) * amp
		norm += amp
		amp *= 0.5
		freq *= 2.1
	end
	return sum / norm -- ~[-0.5, 0.5]
end

-- ขอบเกาะไม่กลมเป๊ะ: รัศมีจริงขยับตามมุม
--
-- **ความถี่ของ noise รอบวงคือตัวชี้ขาดว่าได้เกาะหรือได้รูปหลายเหลี่ยม** — เดินรอบวงในสเปซของ noise
-- ด้วยรัศมีเล็ก (~1.5) จะได้ลอนใหญ่ 3-4 ลอน ซึ่งตาอ่านเป็นหกเหลี่ยมทันที (เจอมาแล้วรอบแรก)
-- รัศมี 5 ขึ้นไปได้ลอนถี่พอที่ขอบจะอ่านเป็น "วงกลมที่ไม่เรียบ" ตามภาพอ้างอิง
local function radiusAt(angle)
	local k = 3.0
	local a = math.noise(math.cos(angle) * k, math.sin(angle) * k, 11)
	local b = math.noise(math.cos(angle) * k * 2.6, math.sin(angle) * k * 2.6, 23) * 0.4
	return R * (1 + EDGE_NOISE * (a + b) * 2)
end

-- แง่งยาวใต้ก้นเกาะ — มุมกับความยาวสุ่มครั้งเดียวตอนเริ่ม ไม่ได้สุ่มรายวอกเซล
-- (สุ่มรายวอกเซลจะได้ก้อนหินพรุนเป็นฟองน้ำ ไม่ใช่แง่งหินที่ห้อยลงมาเป็นเส้น)
local spikes = {}
do
	local rng = Random.new(SEED)
	for i = 1, SPIKES do
		spikes[i] = {
			angle = rng:NextNumber(0, math.pi * 2),
			-- อยู่ค่อนไปทางแกนกลาง: แง่งที่เกาะขอบจะอ่านเป็นครีบยื่นออกข้าง ไม่ใช่หินย้อยใต้ท้องเกาะ
			dist = rng:NextNumber(0, 0.35), -- ระยะจากแกนกลาง เป็นสัดส่วนของ R
			len = rng:NextNumber(0.12, 0.42),  -- ยาวเพิ่มจากกรวยหลัก เป็นสัดส่วนของ DEPTH
			width = rng:NextNumber(0.08, 0.18),
		}
	end
end

-- ผิวบน (y) ที่ระยะ r (0..1 ของรัศมี ณ มุมนั้น)
local function topAt(r, x, z)
	local dome = DOME * (1 - r * r)
	local bump = fbm(x, z, 70, 3) * 6 * (1 - r) -- เนินเตี้ยๆ ให้ไม่เรียบเหมือนโต๊ะ
	return dome + bump
end

-- ผิวล่าง (y ติดลบ) ที่ระยะ r — กรวยคว่ำ + แง่ง
local function bottomAt(r, x, z, angle, top)
	if r >= 1 then return 0 end
	local cone = -DEPTH * (1 - r) ^ TAPER
	-- หินย้วยเป็นริ้วตามแนวดิ่ง: ใช้ noise ของ (มุม, ความลึก) ไม่ใช่ของ (x,z) ริ้วจึงลากลงเป็นเส้น
	local ripple = fbm(math.cos(angle) * 60, math.sin(angle) * 60, 40, 2) * DEPTH * 0.10 * (1 - r)
	local extra = 0
	for _, s in ipairs(spikes) do
		local da = math.abs((angle - s.angle + math.pi) % (math.pi * 2) - math.pi)
		local dr = math.abs(r - s.dist)
		local near = math.max(0, 1 - (da / (s.width * math.pi * 2)) ^ 2) * math.max(0, 1 - (dr / 0.22) ^ 2)
		extra = math.min(extra, -DEPTH * s.len * near)
	end
	-- ขอบต้องหนาอย่างน้อย RIM เสมอ ดูเหตุผลที่ค่าคงที่ข้างบน
	return math.min(cone + ripple + extra, (top or 0) - RIM)
end

--------------------------------------------------------------------------------
-- เขียนวอกเซล
--------------------------------------------------------------------------------

local MARGIN = 40
local minY = -DEPTH * 1.5
local maxY = DOME + 40

local function alignDown(v) return math.floor(v / RES) * RES end
local function alignUp(v) return math.ceil(v / RES) * RES end

local x0 = alignDown(ORIGIN.X - R - MARGIN)
local x1 = alignUp(ORIGIN.X + R + MARGIN)
local z0 = alignDown(ORIGIN.Z - R - MARGIN)
local z1 = alignUp(ORIGIN.Z + R + MARGIN)
local y0 = alignDown(ORIGIN.Y + minY)
local y1 = alignUp(ORIGIN.Y + maxY)

local function eraseAll()
	T:FillRegion(Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x1, y1, z1)):ExpandToGrid(RES), RES, Enum.Material.Air)
	local old = workspace:FindFirstChild("WOLD_SkyIsland")
	if old then old:Destroy() end
end

if ERASE then
	eraseAll()
	workspace:SetAttribute("SkyIslandErase", false)
	status("ลบเกาะและวอกเซลในกล่องเดิมแล้ว", true)
	return
end

status(("เริ่มเขียนเกาะที่ %s"):format(tostring(ORIGIN)))

-- เขียนทับของเดิมได้เสมอ: ลบกล่องเดิมก่อน แล้วค่อยเขียนใหม่ รันซ้ำจึงไม่ได้เกาะซ้อนสองชั้น
eraseAll()

local AIR = Enum.Material.Air
local GRASS_M = Enum.Material.Grass
local DIRT_M = Enum.Material.Ground
local ROCK_M = Enum.Material.Rock

T:SetMaterialColor(GRASS_M, GRASS_COLOR)
T:SetMaterialColor(DIRT_M, DIRT_COLOR)
T:SetMaterialColor(ROCK_M, ROCK_COLOR)

local CHUNK = 16 -- วอกเซลต่อด้าน = 64 สตัด · 16*16*(ความสูง) ต่อการเขียนหนึ่งครั้ง
local yCount = (y1 - y0) / RES
local chunksX = math.ceil((x1 - x0) / (CHUNK * RES))
local chunksZ = math.ceil((z1 - z0) / (CHUNK * RES))
local total, done, filled = chunksX * chunksZ, 0, 0
local t0 = os.clock()

for cx = 0, chunksX - 1 do
	for cz = 0, chunksZ - 1 do
		local bx = x0 + cx * CHUNK * RES
		local bz = z0 + cz * CHUNK * RES
		local ex = math.min(bx + CHUNK * RES, x1)
		local ez = math.min(bz + CHUNK * RES, z1)
		local nx = (ex - bx) / RES
		local nz = (ez - bz) / RES

		local mats, occs = {}, {}
		local any = false
		for ix = 1, nx do
			mats[ix], occs[ix] = {}, {}
			-- จุดกึ่งกลางวอกเซล ไม่ใช่มุม: ผิวที่คำนวณจากมุมจะเหลื่อมไปครึ่งวอกเซลทุกด้าน
			local wx = bx + (ix - 0.5) * RES - ORIGIN.X
			for iy = 1, yCount do
				mats[ix][iy], occs[ix][iy] = {}, {}
				local wy0 = y0 + (iy - 1) * RES - ORIGIN.Y
				local wy1 = wy0 + RES
				for iz = 1, nz do
					local wz = bz + (iz - 0.5) * RES - ORIGIN.Z
					-- วัดระยะบนวงรี (ย่อแกน Z ก่อน) เกาะจึงรีเหมือนภาพอ้างอิง ไม่ใช่จานกลมเป๊ะ
					local ez_ = wz / OVAL
					local dist = math.sqrt(wx * wx + ez_ * ez_)
					local angle = math.atan2(ez_, wx)
					local rad = radiusAt(angle)
					local r = dist / rad

					local material, occ = AIR, 0
					if r < 1 then
						local top = topAt(r, wx, wz)
						local bottom = bottomAt(r, wx, wz, angle, top)
						-- **ขอบหญ้าย้อยคลุมหิน** ตามภาพ: ใกล้ขอบ ชั้นดิน/หินหดเข้าเร็วกว่าชั้นหญ้า
						local overlap = math.min(wy1, top) - math.max(wy0, bottom)
						if overlap > 0 then
							occ = math.clamp(overlap / RES, 0, 1)
							local mid = (math.max(wy0, bottom) + math.min(wy1, top)) * 0.5
							local grassT = GRASS * (0.35 + 0.65 * (1 - r))
							if mid >= top - grassT then
								material = GRASS_M
							elseif mid >= top - grassT - DIRT then
								material = DIRT_M
							else
								material = ROCK_M
							end
						end
					end
					mats[ix][iy][iz] = material
					occs[ix][iy][iz] = occ
					if occ > 0 then any = true end
				end
			end
		end

		if any then
			local region = Region3.new(Vector3.new(bx, y0, bz), Vector3.new(ex, y1, ez)):ExpandToGrid(RES)
			T:WriteVoxels(region, RES, mats, occs)
			filled += 1
		end
		done += 1
		if done % 8 == 0 or done == total then
			status(("%d/%d ก้อน"):format(done, total))
		end
		-- ยอมให้ Studio หายใจระหว่างทาง ไม่งั้นหน้าต่างค้างจนดูเหมือนแขวน
		if done % 4 == 0 then task.wait() end
	end
end

--------------------------------------------------------------------------------
-- ที่ยืน
--------------------------------------------------------------------------------

-- จุดเกิดเล็กๆ กลางเกาะ ไม่งั้นเพลสใหม่จะไม่มีที่ให้ยืนเลยและคนเข้ามาจะร่วงตลอดกาล
-- (ผู้ใช้สั่งว่ายังไม่ต้องมีอะไร — อันนี้คือของที่ลบทิ้งได้ทันทีที่วางจุดเกิดจริง)
local folder = Instance.new("Folder")
folder.Name = "WOLD_SkyIsland"
folder.Parent = workspace

local spawn = Instance.new("SpawnLocation")
spawn.Name = "IslandSpawn"
spawn.Size = Vector3.new(12, 1, 12)
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Material = Enum.Material.Slate
spawn.Color = Color3.fromRGB(120, 120, 128)
spawn.Position = ORIGIN + Vector3.new(0, DOME + 1, 0)
spawn.Parent = folder

-- เผื่อรันในเพลสใหม่ที่ยังมีพื้นเริ่มต้นติดมา
local base = workspace:FindFirstChild("Baseplate")
if base then base:Destroy() end

status(("เกาะรัศมี %d ลึก %d · เขียน %d/%d ก้อน ใน %.0f วิ"):format(R, DEPTH, filled, total, os.clock() - t0), true)
