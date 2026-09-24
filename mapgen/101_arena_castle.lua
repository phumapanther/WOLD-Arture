-- 101_arena_castle.lua: แมพแรกของ WOLD Arena — "ปราสาทเฟืองทอง" (ผู้ใช้สั่ง 2026-09-24)
--
--     WOLD_PLACE=134798670267276 node tools/run-luau.js mapgen/101_arena_castle.lua --no-lib --kit --models
--
-- ธีมปราสาท ใช้ชิ้นส่วน `models/castle_parts.lua` จากโรงงาน WOLD-Models เป็นเปลือก (กำแพงม่าน · หอมุม ·
-- ประตูป้อม) แล้วปั้นพื้นที่เล่นข้างในด้วย K ชุดเดียวกัน
--
-- ผัง (มองจากบน · ทีม A = ทอง อยู่ -Z · ทีม B = เหล็ก อยู่ +Z):
--
--   z -212 ┌──────────── ลานเกิด A (3 แท่น) ─────────────┐
--   z -150 │ กำแพงฐาน ══[ ประตูป้อม A ]══ กำแพงฐาน  │ ← ทางออกข้างสองฝั่ง (x ±80..±112)
--   z -100 │ ทางข้าง │        ลานหน้าฐาน         │ ทางข้าง │
--          │ (สวน/ซาก)║                           ║(ระเบียง) │ ← กำแพงแบ่งเลน x ±64 มีช่องทะลุ z ±38
--      0   │         ║      [ หอนาฬิกากลาง ]     ║          │ ← ลานกลาง: จุดปะทะหลัก
--          │         ║                           ║          │
--   z +212 └──────── (หมุน 180° ทั้งหมด = ฝั่ง B) ─────────┘
--
-- **สมมาตรด้วยการหมุน 180° รอบกลางแมพ** — ปั้นครึ่ง A แล้วเรียกฟังก์ชันเดิมด้วยเฟรมที่หมุนแล้ว
-- สองฝั่งจึงเท่ากันทุกก้อน (ทางข้างขวาของ A = ทางข้างขวาของ B เสมอ)
--
-- ⚠️ **กำแพงล่องหน `Bounds`** ที่ x ±113 / z ±212 คือขอบสนามจริง — กำแพงม่านของปราสาทมีบันไดขึ้นทางเดิน
-- บนกำแพงอยู่ด้านใน ถ้าไม่กั้น คนจะขึ้นไปยืนสูง 40 สตัดแล้วกระโดดลอดช่องใบเสมาออกนอกแมพ
-- ⚠️ ลบเฉพาะของที่เฟสนี้สร้าง (`PhaseBuilt`) ตามกติกาเดิมของโปรเจ็ค
local PHASE = "arena_castle"
local MAP_ID = "Castle"
local MAP_NAME = "ปราสาทเฟืองทอง"
local ORIGIN = Vector3.new(0, 500, 0) -- ต้องตรงกับ `ArenaConfig.Maps`

local IW = 113 -- ครึ่งความกว้างพื้นที่เล่น (แกน X)
local IL = 212 -- ครึ่งความยาวพื้นที่เล่น (แกน Z)

local C, MAT = K.C, K.MAT
local rgb = Color3.fromRGB
local STONE = rgb(150, 146, 138)
local STONE_DARK = rgb(112, 108, 102)
local TEAM = { A = rgb(226, 184, 78), B = rgb(120, 164, 214) } -- = ArenaConfig.Teams

local function status(text, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then
		f = Instance.new("Folder")
		f.Name = "WOLD"
		f.Parent = workspace
	end
	f:SetAttribute("Progress", text)
	f:SetAttribute("Status", done and "done" or "running")
	print("[arena-castle] " .. text)
end
local t0 = os.clock()

--------------------------------------------------------------------------------
-- โฟลเดอร์ + ลบของเก่าของเฟสนี้
--------------------------------------------------------------------------------
local arena = workspace:FindFirstChild("WOLD_Arena")
if not arena then
	arena = Instance.new("Folder")
	arena.Name = "WOLD_Arena"
	arena.Parent = workspace
end
local old = arena:FindFirstChild(MAP_ID)
if old and old:GetAttribute("PhaseBuilt") ~= PHASE then
	error("[arena-castle] WOLD_Arena." .. MAP_ID .. " ไม่ได้สร้างโดยเฟสนี้ — ไม่แตะ (ของผู้ใช้)")
end
if old then old:Destroy() end

local map = Instance.new("Model")
map.Name = MAP_ID
map:SetAttribute("PhaseBuilt", PHASE)
map:SetAttribute("MapName", MAP_NAME)
map.Parent = arena

local O = CFrame.new(ORIGIN)
local function at(base, x, y, z, yaw)
	return base * CFrame.new(x, y, z) * CFrame.Angles(0, yaw or 0, 0)
end

-- กำแพงหินมีใบเสมา สูง h (ไม่รวมใบเสมา) — ใช้ทำกำแพงฐานกับกำแพงแบ่งเลน
local function battlementWall(parent, cf, len, h)
	local g = K.model(parent, "StoneWall")
	K.box(g, cf * CFrame.new(0, 1.5, 0), Vector3.new(len, 3, 9), MAT.Rock, STONE_DARK, { name = "Plinth" })
	K.box(g, cf * CFrame.new(0, h / 2, 0), Vector3.new(len, h, 6), MAT.Rock, STONE, { name = "Wall" })
	K.box(g, cf * CFrame.new(0, h - 1, 0), Vector3.new(len + 0.4, 1.2, 6.8), MAT.Sandstone, STONE:Lerp(C.white, 0.14), { name = "Course" })
	for i = 0, math.floor(len / 6) - 1 do
		K.box(g, cf * CFrame.new(-len / 2 + 3 + i * 6, h + 1.6, 0), Vector3.new(3.4, 3.2, 6.4), MAT.Rock, STONE, { name = "Merlon" })
	end
	return g
end

-- เสาหักของซากปรักหักพัง
local function brokenColumn(parent, cf, h)
	local g = K.model(parent, "Column")
	K.box(g, cf * CFrame.new(0, 1, 0), Vector3.new(7, 2, 7), MAT.Rock, STONE_DARK)
	K.cyl(g, cf * CFrame.new(0, 2 + h / 2, 0), 2.6, h, MAT.Rock, STONE)
	K.box(g, cf * CFrame.new(0.6, 2.4 + h, -0.4) * CFrame.Angles(0.2, 0.5, 0.15), Vector3.new(4.4, 1.6, 4.4), MAT.Rock, STONE)
	return g
end

local function brazier(parent, cf)
	local g = K.model(parent, "Brazier")
	K.cyl(g, cf * CFrame.new(0, 2, 0), 0.5, 4, MAT.Metal, C.iron)
	K.cyl(g, cf * CFrame.new(0, 4.6, 0), 1.8, 1.2, MAT.Metal, C.iron)
	local fire = K.box(g, cf * CFrame.new(0, 5.6, 0), Vector3.new(2.2, 1, 2.2), MAT.Neon, C.ember, { cancollide = false })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = C.ember, 28, 2
	light.Parent = fire
	return g
end

--------------------------------------------------------------------------------
-- 1. พื้น + เปลือกปราสาท (ทั้งแมพ ไม่ต้องหมุน)
--------------------------------------------------------------------------------
status("พื้นและกำแพงปราสาท")
local shell = K.model(map, "CastleShell")
K.box(map, at(O, 0, -2, 0), Vector3.new(340, 4, 540), MAT.Cobblestone, rgb(118, 112, 104), { name = "Floor" })
-- ลานกลางปูหินแผ่น แยกสีให้อ่านออกว่าตรงนี้คือจุดปะทะ
K.box(map, at(O, 0, 0.1, 0), Vector3.new(128, 0.4, 200), MAT.Slate, rgb(96, 92, 88), { name = "CourtyardPaving" })

for _, z in ipairs({ -192, -128, -64, 0, 64, 128, 192 }) do
	K.place("Castle_WallStraight", shell, at(O, -136, 0, z, math.pi / 2))  -- หน้าด้านนอกหัน -X
	K.place("Castle_WallStraight", shell, at(O, 136, 0, z, -math.pi / 2))  -- หน้าด้านนอกหัน +X
end
for _, x in ipairs({ -96, -32, 32, 96 }) do
	K.place("Castle_WallStraight", shell, at(O, x, 0, -236, 0))
	K.place("Castle_WallStraight", shell, at(O, x, 0, 236, math.pi))
end
for _, c in ipairs({ { -136, -236 }, { 136, -236 }, { -136, 236 }, { 136, 236 } }) do
	K.place("Castle_TowerRound", shell, at(O, c[1], 0, c[2], math.atan2(c[1], c[2])))
end

-- กำแพงล่องหน = ขอบสนามจริง
local bounds = K.model(map, "Bounds")
for _, b in ipairs({
	{ -IW - 1, 0, Vector3.new(2, 160, IL * 2 + 4) }, { IW + 1, 0, Vector3.new(2, 160, IL * 2 + 4) },
	{ 0, -IL - 1, Vector3.new(IW * 2 + 4, 160, 2) }, { 0, IL + 1, Vector3.new(IW * 2 + 4, 160, 2) },
}) do
	K.box(bounds, at(O, b[1], 80, b[2]), b[3], MAT.SmoothPlastic, C.black, { name = "Bounds", transparency = 1 })
end

--------------------------------------------------------------------------------
-- 2. หอนาฬิกากลางลาน (อยู่ตรงกลางพอดี สมมาตรในตัว) — บังเส้นสายตาประตูถึงประตู
--------------------------------------------------------------------------------
status("หอนาฬิกากลาง")
local mid = K.model(map, "ClockTower")
K.box(mid, at(O, 0, 1.5, 0), Vector3.new(28, 3, 28), MAT.Rock, STONE_DARK, { name = "Plinth" })
K.box(mid, at(O, 0, 4.5, 0), Vector3.new(20, 3, 20), MAT.Rock, STONE, { name = "Step" })
K.box(mid, at(O, 0, 21, 0), Vector3.new(12, 30, 12), MAT.Rock, STONE, { name = "Tower" })
for i = 0, 3 do
	local face = at(O, 0, 28, 0, i * math.pi / 2) * CFrame.new(0, 0, -6.3)
	K.gear(mid, face * K.yaw(math.pi / 2), 4.4, 16, 0.8, C.brass)
	K.gear(mid, face * CFrame.new(2.6, -5, -0.4) * K.yaw(math.pi / 2), 2, 10, 0.8, C.copper)
end
K.roofPyramid(mid, at(O, 0, 36, 0), 15, 15, 11, MAT.Slate, C.slateRoof, 1.4)
for _, c in ipairs({ { -12, -12 }, { 12, -12 }, { -12, 12 }, { 12, 12 } }) do
	K.lampPost(mid, at(O, c[1], 3, c[2]), 10, rgb(255, 198, 130))
end

--------------------------------------------------------------------------------
-- 3. ครึ่งแมพหนึ่งฝั่ง — เรียกสองครั้ง: A ด้วยเฟรมเดิม · B ด้วยเฟรมหมุน 180°
--------------------------------------------------------------------------------
local function half(side, base)
	local g = K.model(map, "Half" .. side)
	local colour = TEAM[side]

	-- ลานเกิด
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawn" .. side
	spawns.Parent = map
	for i, x in ipairs({ -18, 0, 18 }) do
		K.box(spawns, at(base, x, 0.5, -196), Vector3.new(10, 1, 10), MAT.Neon, colour,
			{ name = ("Pad%d"):format(i), transparency = 0.25 })
	end
	for _, x in ipairs({ -44, 44 }) do
		K.banner(g, at(base, x, 0, -207), 9, 16, colour, 24)
		brazier(g, at(base, x * 0.62, 0, -184))
	end
	-- ชั้นวางอาวุธ/ลังเสบียงหลังแท่นเกิด (ของตกแต่ง ไม่กีดทาง)
	for i, x in ipairs({ -70, -58, 58, 70 }) do
		K.crate(g, at(base, x, 0, -204 + (i % 2) * 4), 5)
	end

	-- ประตูป้อมของทีม: หน้าประตู (ช่องลูกกรง) หันเข้ากลางแมพ
	local gate = K.place("Castle_WallGate", g, at(base, 0, 0, -150, math.pi))
	-- ⚠️ ฐานหิน (Batter) ของประตูป้อมเป็นก้อนเดียวสูง 6 สตัดพาดขวางทางลอดทั้งช่อง — ในโรงงานมันเป็นแค่
	-- ของโชว์ ไม่มีใครเดินผ่าน · ผ่าเป็นสองก้อนเว้นช่องทางลอด (กว้าง 20 + เผื่อ 2 ข้างละ)
	local batter = gate and gate:FindFirstChild("Batter")
	if batter then
		local w = (batter.Size.X - 24) / 2
		for _, s in ipairs({ -1, 1 }) do
			local piece = batter:Clone()
			piece.Size = Vector3.new(w, batter.Size.Y, batter.Size.Z)
			piece.CFrame = batter.CFrame * CFrame.new(s * (12 + w / 2), 0, 0)
			piece.Parent = gate
		end
		batter:Destroy()
	end
	-- กำแพงฐานสองข้างประตู เว้นทางออกข้าง x ±80..±113 ไว้ลงทางข้าง
	for _, s in ipairs({ -1, 1 }) do
		battlementWall(g, at(base, s * 62.5, 0, -150), 35, 16)
		K.banner(g, at(base, s * 76, 0, -144), 7, 12, colour, 20)
	end

	-- ลานหน้าฐาน: ที่กำบังก่อนวิ่งเข้าลานกลาง
	for _, s in ipairs({ -1, 1 }) do
		K.box(g, at(base, s * 26, 4, -114), Vector3.new(12, 8, 7), MAT.Rock, STONE_DARK, { name = "Block" })
	end
	K.crate(g, at(base, 8, 0, -96), 6)
	K.crate(g, at(base, 13, 0, -96), 5)

	-- กำแพงแบ่งเลน x ±64 (ครึ่งนี้: z -100..-44 และ -32..0) ช่องทะลุที่ z -44..-32
	for _, s in ipairs({ -1, 1 }) do
		battlementWall(g, at(base, s * 64, 0, -72, math.pi / 2), 56, 18)
		battlementWall(g, at(base, s * 64, 0, -16, math.pi / 2), 32, 18)
		-- ซุ้มโค้งเหนือช่องทะลุ: บอกด้วยตาว่า "ตรงนี้ผ่านได้"
		K.box(g, at(base, s * 64, 19, -38), Vector3.new(6, 4, 14), MAT.Rock, STONE:Lerp(C.white, 0.1), { name = "Lintel" })
		K.lampPost(g, at(base, s * 70, 0, -46), 9, rgb(255, 198, 130))
	end

	-- ลานกลาง (ครึ่งนี้): ที่กำบังหลายความสูง — กำแพงเตี้ย 3 สตัดกระโดดข้ามได้ บล็อก 8 สตัดบังทั้งตัว
	K.box(g, at(base, 0, 1.5, -68), Vector3.new(26, 3, 4), MAT.Rock, STONE_DARK, { name = "LowWall" })
	K.box(g, at(base, -34, 4, -40), Vector3.new(12, 8, 9), MAT.Rock, STONE, { name = "Block" })
	K.crate(g, at(base, -34, 8, -40), 5)
	K.crate(g, at(base, 30, 0, -58), 6)
	K.crate(g, at(base, 36, 0, -56), 6)
	K.crate(g, at(base, 33, 6, -57), 5)
	for i = 0, 2 do K.barrel(g, at(base, -20 + i * 3.2, 0, -18 - (i % 2) * 2.4), 1.4, 4) end
	brokenColumn(g, at(base, 40, 0, -20), 12)

	-- ทางข้างซ้าย (x -113..-64): สวนซากปรักหักพัง — เสาหักสลับกำแพงเตี้ย ให้กระโดดหลบได้
	local garden = K.model(g, "RuinGarden")
	K.box(garden, at(base, -88.5, 0.15, -100), Vector3.new(49, 0.3, 200), MAT.Grass, C.grass, { name = "Lawn" })
	brokenColumn(garden, at(base, -96, 0, -118), 10)
	brokenColumn(garden, at(base, -80, 0, -78), 14)
	brokenColumn(garden, at(base, -98, 0, -22), 8)
	K.box(garden, at(base, -90, 2, -50), Vector3.new(18, 4, 4), MAT.Rock, STONE_DARK, { name = "LowWall" })
	K.box(garden, at(base, -78, 3.5, -8, 0.4), Vector3.new(10, 7, 8), MAT.Rock, STONE, { name = "Rubble" })

	-- ทางข้างขวา (x 64..113): ระเบียงค่ายทหาร — แท่นสูงมีทางลาด (จุดสูงเล็กๆ) + หลังคามีเสา
	local barracks = K.model(g, "Barracks")
	K.box(barracks, at(base, 92, 3.5, -70), Vector3.new(30, 7, 30), MAT.Rock, STONE_DARK, { name = "Platform" })
	-- K.wedge: ด้านสูงอยู่ +Z → ด้านสูงชนขอบแท่น (z -85) ทางลาดลงไปทางฐาน
	K.wedge(barracks, at(base, 92, 3.5, -99), Vector3.new(14, 7, 28), MAT.Rock, STONE_DARK, { name = "Ramp" })
	for _, x in ipairs({ 78, 106 }) do
		for _, z in ipairs({ -84, -56 }) do
			K.cyl(barracks, at(base, x, 7 + 7, z), 1.3, 14, MAT.Wood, C.wood)
		end
	end
	K.box(barracks, at(base, 92, 21.5, -70), Vector3.new(34, 1, 34), MAT.WoodPlanks, C.plankDark, { name = "Roof" })
	K.box(barracks, at(base, 92, 8.5, -56.5), Vector3.new(30, 3, 1), MAT.Wood, C.wood, { name = "Rail" })
	for i = 0, 1 do K.barrel(barracks, at(base, 104 - i * 3.4, 7, -80), 1.4, 4) end
	K.crate(barracks, at(base, 100, 0, -28), 6)
	K.crate(barracks, at(base, 86, 0, -12), 5)
	brazier(barracks, at(base, 108, 0, -120))
	return g
end

status("ครึ่งฝั่งทีม A")
half("A", O)
status("ครึ่งฝั่งทีม B")
half("B", O * CFrame.Angles(0, math.pi, 0))

--------------------------------------------------------------------------------
-- เก็บกวาด
--------------------------------------------------------------------------------
-- เพลสที่ก๊อปมา/เพลสใหม่มักมีพื้นกับจุดเกิดเริ่มต้นอยู่ใต้สนาม — คนที่โดนสุ่มไปเกิดตรงนั้นร่วงออกนอกโลก
local base = workspace:FindFirstChild("Baseplate")
if base then base:Destroy() end
for _, child in ipairs(workspace:GetChildren()) do
	if child:IsA("SpawnLocation") then child:Destroy() end
end

local n = 0
for _, d in ipairs(map:GetDescendants()) do
	if d:IsA("BasePart") then n += 1; d.Anchored = true end
end
map:SetAttribute("Parts", n)
status(("เสร็จ: %s %d ชิ้น ใน %.1f วิ"):format(MAP_NAME, n, os.clock() - t0), true)
