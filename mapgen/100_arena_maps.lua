-- 100_arena_maps.lua: แมพของโหมด PVP 3v3 — อบเข้าเพลส `WOLD Arena` ครั้งเดียว ไม่ได้เจนตอนรัน
--
--     WOLD_PLACE=<เลขเพลสสนาม> node tools/run-luau.js mapgen/100_arena_maps.lua --no-lib
--
-- **รันได้ในเพลสเปล่า ไม่พึ่ง lib และไม่พึ่ง world-layout** (โครงเดียวกับ `80_sky_island.lua`)
--
-- ออกแบบตามหลักแมพ FPS ที่ผู้ใช้ระบุ:
--   1. **สมมาตรจริง** — สร้างครึ่งเดียวแล้วหมุน 180° รอบแกนกลางเป็นอีกครึ่ง สองฝั่งจึงเท่ากัน
--      ทุกก้อนหินโดยไม่ต้องไปวัดทีหลัง (ถ้าวางมือสองฝั่ง ไม่มีวันเท่ากันจริง และจะไม่มีใครรู้ว่าไม่เท่า)
--   2. **สามเลน** ซ้าย/กลาง/ขวา ให้โอบล้อมได้ ไม่ใช่วิ่งชนกันกลางทุ่งทางเดียว
--   3. **จุดปะทะสองจุด (Site A / Site B)** มีของบังสายตา ระยะจากสปอว์นทั้งสองฝั่งเท่ากันเป๊ะ
--   4. **ไม่มีเส้นสายตาจากสปอว์นถึงสปอว์น** — กำแพงกลางบังไว้ ใครซุ่มจากจุดเกิดยิงข้ามแมพไม่ได้
--
-- ⚠️ **ลบเฉพาะของที่เฟสนี้สร้าง** (แอตทริบิวต์ `PhaseBuilt`) ตามบทเรียนที่เจอมาสามครั้งบนเกาะ:
-- เฟสที่ลบทั้งโฟลเดอร์คือเฟสที่กินงานผู้ใช้ · ของที่ผู้ใช้วางเองในโฟลเดอร์เดียวกันจะรอดเสมอ
local PHASE = "arena_maps"
local FOLDER_NAME = "WOLD_Arena"

local function root()
	local f = workspace:FindFirstChild("WOLD")
	if not f then
		f = Instance.new("Folder")
		f.Name = "WOLD"
		f.Parent = workspace
	end
	return f
end

local function status(text, done)
	local f = root()
	f:SetAttribute("Progress", text)
	f:SetAttribute("Status", done and "done" or "running")
	print("[arena] " .. text)
end

local t0 = os.clock()

--------------------------------------------------------------------------------
-- ตัวเลขของสนาม — แก้ตรงนี้ที่เดียว
--------------------------------------------------------------------------------
local HALF_LEN = 190   -- ครึ่งความยาวแมพ (แกน Z) จากกลางถึงหลังสปอว์น
local HALF_WID = 150   -- ครึ่งความกว้าง (แกน X)
local WALL_H = 40      -- กำแพงรอบสนาม สูงพอไม่มีใครกระโดดข้าม
local FLOOR_T = 6

local MAPS = {
	{
		id = "Foundry", name = "โรงหล่อ", origin = Vector3.new(0, 500, 0),
		-- โทนโรงหล่อ: อิฐเผา เหล็กร้อน ทองเหลือง
		floor = { Color3.fromRGB(86, 74, 66), Enum.Material.Slate },
		wall = { Color3.fromRGB(122, 74, 52), Enum.Material.Brick },
		cover = { Color3.fromRGB(150, 108, 54), Enum.Material.Metal },
		accent = Color3.fromRGB(226, 128, 54),
	},
	{
		id = "Cistern", name = "บ่อพักน้ำ", origin = Vector3.new(4000, 500, 0),
		-- โทนบ่อน้ำใต้เมือง: หินเปียก ทองเหลืองเขียวสนิม
		floor = { Color3.fromRGB(72, 78, 84), Enum.Material.Concrete },
		wall = { Color3.fromRGB(92, 100, 106), Enum.Material.Slate },
		cover = { Color3.fromRGB(96, 132, 122), Enum.Material.Metal },
		accent = Color3.fromRGB(96, 178, 196),
	},
}

--------------------------------------------------------------------------------
local function folderRoot()
	local f = workspace:FindFirstChild(FOLDER_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = workspace
	end
	return f
end

local built = 0

local function block(parent, name, centre, size, colour, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = centre
	part.Color = colour
	part.Material = material or Enum.Material.Concrete
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Parent = parent
	built += 1
	return part
end

--------------------------------------------------------------------------------
-- ครึ่งแมพ: ทุกชิ้นที่ z < 0 (ฝั่งทีม A) — อีกครึ่งเกิดจากการหมุน 180°
--------------------------------------------------------------------------------
-- คืนรายการ { name, offset (จากกลางแมพ), size } ของครึ่งเดียว
local function halfPieces()
	local pieces = {}
	local function add(name, x, y, z, sx, sy, sz, kind)
		pieces[#pieces + 1] = { name = name, offset = Vector3.new(x, y, z), size = Vector3.new(sx, sy, sz), kind = kind }
	end

	-- กำแพงหลังสปอว์น (ปิดท้ายสนาม)
	add("BackWall", 0, WALL_H / 2, -HALF_LEN, HALF_WID * 2, WALL_H, 8, "wall")

	-- **กำแพงแบ่งเลน** สองแผง ทำให้เกิดทางเดิน 3 สาย: ซ้าย กลาง ขวา
	-- เว้นช่องตรงปลายทั้งสองข้างไว้ให้ข้ามเลนได้ ไม่งั้นมันเป็นสามอุโมงค์ที่ไม่มีทางเลือกอะไรเลย
	add("LaneWallL", -56, 9, -70, 8, 18, 120, "wall")
	add("LaneWallR", 56, 9, -70, 8, 18, 120, "wall")

	-- ของบังสายตาหน้าสปอว์น — กันการซุ่มยิงคนที่เพิ่งเกิด
	add("SpawnCover", 0, 6, -150, 44, 12, 8, "cover")

	-- จุดปะทะ (Site) ของฝั่งนี้: ยกพื้นเตี้ยๆ พร้อมลังสี่ใบล้อม
	add("SitePad", -84, 1.5, -46, 56, 3, 56, "cover")
	add("SiteCrateA", -104, 5, -26, 14, 10, 14, "cover")
	add("SiteCrateB", -64, 4, -66, 12, 8, 12, "cover")
	add("SitePillar", -84, 12, -46, 10, 24, 10, "wall")

	-- เลนขวาของฝั่งนี้: ทางอ้อมแคบๆ ไว้โอบหลัง
	add("FlankBox", 100, 5, -60, 18, 10, 18, "cover")
	add("FlankWall", 118, 9, -20, 8, 18, 70, "wall")

	-- ของบังกลางเลนกลาง — **สำคัญที่สุด**: ถ้ากลางแมพโล่ง คนที่ซื้อธนู/ปืนก่อนชนะทุกยกโดยไม่ต้องขยับ
	add("MidCrate", -18, 5, -22, 16, 10, 16, "cover")
	add("MidRamp", 30, 3, -34, 26, 6, 26, "cover")

	return pieces
end

-- ระยะจากสปอว์นถึงกลางแมพของทั้งสองฝั่ง = HALF_LEN - 22 เท่ากันเป๊ะโดยโครงสร้าง (หมุน 180°)
local function spawnOffsets()
	local list = {}
	for i = 1, 3 do
		list[i] = Vector3.new((i - 2) * 22, 3, -(HALF_LEN - 22))
	end
	return list
end

--------------------------------------------------------------------------------
local function buildMap(spec)
	local parent = folderRoot()

	-- ลบของเก่าที่เฟสนี้เคยสร้าง (และเฉพาะของเฟสนี้)
	local existing = parent:FindFirstChild(spec.id)
	if existing and existing:GetAttribute("PhaseBuilt") == PHASE then
		existing:Destroy()
	elseif existing then
		warn(("[arena] %s มีอยู่แล้วและไม่ได้สร้างโดยเฟสนี้ — ข้ามไป (ของผู้ใช้ไม่ถูกแตะ)"):format(spec.id))
		return
	end

	local model = Instance.new("Model")
	model.Name = spec.id
	model:SetAttribute("PhaseBuilt", PHASE)
	model.Parent = parent

	local O = spec.origin

	-- พื้น
	block(model, "Floor", O - Vector3.new(0, FLOOR_T / 2, 0),
		Vector3.new(HALF_WID * 2, FLOOR_T, HALF_LEN * 2), spec.floor[1], spec.floor[2])

	-- กำแพงข้างสองด้าน (ยาวตลอดแมพ สมมาตรอยู่แล้วโดยตัวมันเอง)
	for _, sign in ipairs({ -1, 1 }) do
		block(model, "SideWall", O + Vector3.new(sign * HALF_WID, WALL_H / 2, 0),
			Vector3.new(8, WALL_H, HALF_LEN * 2), spec.wall[1], spec.wall[2])
	end

	-- ครึ่งหนึ่ง แล้วหมุน 180° เป็นอีกครึ่ง
	local colours = { wall = spec.wall, cover = spec.cover }
	for _, piece in ipairs(halfPieces()) do
		local paint = colours[piece.kind] or spec.cover
		block(model, piece.name .. "_A", O + piece.offset, piece.size, paint[1], paint[2])
		-- หมุน 180° รอบแกน Y ที่กลางแมพ = กลับทั้งแกน X และ Z · ขนาดก็กลับตามแกนแนวนอน
		local mirrored = Vector3.new(-piece.offset.X, piece.offset.Y, -piece.offset.Z)
		block(model, piece.name .. "_B", O + mirrored,
			Vector3.new(piece.size.X, piece.size.Y, piece.size.Z), paint[1], paint[2])
	end

	-- จุดเกิดสองฝั่ง — แผ่นเรืองแสงสีทีม อ่านออกทันทีว่าฝั่งไหนของใคร
	local TEAM_COLOUR = { A = Color3.fromRGB(226, 184, 78), B = Color3.fromRGB(120, 164, 214) }
	for _, side in ipairs({ "A", "B" }) do
		local folder = Instance.new("Folder")
		folder.Name = "Spawn" .. side
		folder.Parent = model
		for i, offset in ipairs(spawnOffsets()) do
			local at = side == "A" and offset or Vector3.new(-offset.X, offset.Y, -offset.Z)
			local pad = block(folder, ("Pad%d"):format(i), O + at, Vector3.new(10, 1, 10),
				TEAM_COLOUR[side], Enum.Material.Neon)
			pad.Transparency = 0.25
		end
	end

	-- ไฟกลางแมพ ให้จุดปะทะสว่างกว่ามุมมืด (คนถึงอยากเข้าไปแลกกันตรงนั้น)
	local beacon = block(model, "Beacon", O + Vector3.new(0, 30, 0), Vector3.new(6, 6, 6), spec.accent, Enum.Material.Neon)
	beacon.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 90
	light.Brightness = 2
	light.Color = spec.accent
	light.Parent = beacon

	model:SetAttribute("MapName", spec.name)
	status(("แมพ %s เสร็จ (%d ชิ้น)"):format(spec.name, built))
end

--------------------------------------------------------------------------------
status("เริ่มสร้างแมพสนาม PVP")

for _, spec in ipairs(MAPS) do
	buildMap(spec)
end

-- เพลสใหม่มักมีพื้นกับจุดเกิดเริ่มต้นติดมา — จุดเกิดนั้นอยู่ที่ y≈0 ซึ่งอยู่ใต้สนามทั้งสอง
-- คนที่โดนสุ่มไปโผล่ตรงนั้นคือคนที่หล่นออกนอกโลก (บทเรียนเดียวกับตอนสร้างเพลสเกาะ)
local base = workspace:FindFirstChild("Baseplate")
if base then base:Destroy() end
for _, child in ipairs(workspace:GetChildren()) do
	if child:IsA("SpawnLocation") then child:Destroy() end
end

status(("เสร็จทั้งหมด %d ชิ้น ใน %.1f วิ"):format(built, os.clock() - t0), true)
