-- 97_island_skyscape.lua — ท้องฟ้ารอบเกาะ: เมฆ + เกาะลอยฟ้าไกลๆ ให้ไม่โล่งจนโดดเดี่ยว
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/97_island_skyscape.lua --no-lib
--
-- รันซ้ำได้: ลบ `WOLD_Island.Skyscape` เดิมทิ้งแล้วสร้างใหม่ · ลบทิ้งอย่างเดียวด้วย `IslandSkyErase = true`
--
-- ## สามชั้น
--
-- 1. **เมฆจริงของ Terrain** (`Clouds`) — เมฆชั้นสูงที่เคลื่อนไหวเอง ฟรีทั้งหมด ไม่กินพาร์ทสักชิ้น
-- 2. **เกาะลอยฟ้าไกลๆ** 14 เกาะ วงใน/วงนอก — เป็น **Part ไม่ใช่ Terrain**
-- 3. **แพเมฆใกล้ๆ** ลอยต่ำกว่าระดับเกาะ ให้รู้สึกว่าเกาะเราลอยอยู่จริง ไม่ใช่ตั้งอยู่บนพื้นที่มองไม่เห็น
--
-- ## ทำไมเกาะไกลต้องเป็น Part ไม่ใช่ Terrain
--
-- Terrain เป็นก้อนเดียวทั้งเพลส แก้ตรงไหนก็เขียน voxel ตรงนั้นจริงๆ — เกาะประดับ 14 ก้อนที่ระยะ
-- 700-2,000 สตัด จะกิน voxel มหาศาลโดยที่ไม่มีใครเดินไปถึง และย้าย/ลบทีหลังยากกว่ามาก
-- ส่วน Part ย้ายได้ ลบได้ ปิด `CanCollide`/`CanQuery` แล้วไม่รบกวนอะไรเลย
--
-- ## ข้อที่สำคัญที่สุด: ห้ามรบกวนระบบที่มีอยู่
--
-- * **`CanQuery = false` ทุกชิ้น** ไม่งั้น `IslandGrid.obstructed` กับ `reachable` จะเห็นมันเป็นสิ่งกีดขวาง
--   (บทเรียนจากกล่องโซนหมู่บ้าน `Zone_*` ที่มองไม่เห็นแต่เรย์ชน แล้วลานจอดรถไปลอยเหนือหมู่บ้าน 200 สตัด)
-- * **`CanCollide = false`** คนบินไปไม่ถึงอยู่แล้ว (มีกำแพงล่องหน) แต่ถ้าชนได้แล้วมีใครไปถึง จะยืนบนอากาศได้
-- * **ไม่แตะ `Lighting.FogEnd` / `Atmosphere.Density`** `DayNight.server` เขียนทับทุก 0.25 วินาทีตามเวลาของวัน
--   และระบบอากาศเขียนทับอีกชั้น — ตั้งตรงนี้ก็หายภายในเสี้ยววินาที ต้องแก้ที่ `DayNightConfig` ถึงจะอยู่
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

assert(game.PlaceId == 136992335889132 or game.PlaceId == 0, "เฟสนี้สำหรับเพลสเกาะเท่านั้น")

local CENTRE = Vector3.new(0, 800, 0)
local SEED = 20260922
local ERASE = workspace:GetAttribute("IslandSkyErase") == true

local rng = Random.new(SEED)

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[Skyscape] " .. msg)
end

local island = workspace:FindFirstChild("WOLD_Island")
if not island then island = Instance.new("Folder"); island.Name = "WOLD_Island"; island.Parent = workspace end
local old = island:FindFirstChild("Skyscape")
if old then old:Destroy() end

if ERASE then
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then clouds:Destroy() end
	status("done: ลบเมฆและเกาะประดับออกหมดแล้ว", true)
	return
end

local root = Instance.new("Folder")
root.Name = "Skyscape"
root.Parent = island

--------------------------------------------------------------------------------
-- 1. เมฆชั้นสูงของ Terrain
--------------------------------------------------------------------------------

-- ของจริงในเอนจิน เคลื่อนไหวเองตามลม ไม่กินพาร์ทเลย
--
-- `Cover` = ฟ้าถูกเมฆบังแค่ไหน (0 = ไม่มีเมฆ 1 = มืดครึ้ม) · `Density` = เมฆทึบแค่ไหน
-- ตั้งให้ "สวยแต่ยังเห็นฟ้า" ตามที่ผู้ใช้ขอ — ครึ้มเกินไปเกาะจะดูหม่น ไม่ใช่โปร่ง
local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
if not clouds then
	clouds = Instance.new("Clouds")
	clouds.Parent = workspace.Terrain
end
clouds.Cover = 0.55
clouds.Density = 0.62
clouds.Color = Color3.fromRGB(255, 255, 255)

--------------------------------------------------------------------------------
-- ตัวช่วยปั้น
--------------------------------------------------------------------------------

-- ทุกชิ้นที่เฟสนี้สร้างผ่านตัวนี้ตัวเดียว — กฎ CanQuery/CanCollide จึงพลาดไม่ได้
local function decor(parent, size, cf, colour, material)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.Slate
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false -- ⚠️ สำคัญที่สุด: ระบบวางของยิงกล่องถามว่า "ช่องนี้ว่างไหม"
	p.CanTouch = false
	p.CastShadow = false -- ไกลเกินกว่าเงาจะมีความหมาย และเงาของ 14 เกาะแพงโดยเปล่าประโยชน์
	p.Parent = parent
	return p
end

local GRASS = Color3.fromRGB(96, 152, 48)
local ROCK = Color3.fromRGB(112, 56, 46)
local ROCK_COOL = Color3.fromRGB(96, 92, 104)

-- เกาะลอยฟ้าหนึ่งก้อน: จานหญ้าด้านบน + กรวยหินห้อยลงล่าง ทรงเดียวกับเกาะจริงที่ผู้เล่นยืนอยู่
--
-- **ทรงต้องเหมือนเกาะหลัก** ไม่งั้นมันดูเหมือนก้อนหินลอย ไม่ใช่ "เกาะแบบเดียวกับที่ฉันอยู่"
-- ซึ่งเป็นทั้งหมดของการมีมัน — ผู้ใช้ขอ "วิวที่ไม่รู้สึกโดดเดี่ยว" ไม่ใช่ขอก้อนหิน
local function floatingIsle(parent, at, radius, tint)
	local isle = Instance.new("Model")
	isle.Name = "Isle"
	isle.Parent = parent

	local rock = tint or ROCK
	-- จานหญ้า: ทรงกระบอกแบนๆ
	--
	-- ⚠️ **แกนของ Cylinder คือแกน X ของตัวพาร์ทเอง** `Size.X` จึงเป็น "ความหนาของจาน" ไม่ใช่ความกว้าง
	-- และ Y/Z เป็นเส้นผ่าศูนย์กลาง · หมุน `Angles(0,0,pi/2)` เพื่อเอาแกน X ไปชี้ขึ้นตามแกน Y ของโลก
	-- (รอบแรกผมใส่ขนาดแบบ Block คือ กว้าง×หนา×ลึก แล้วได้จานตั้งฉากนอนตะแคง — กรอบเกาะออกมา
	--  313 กว้าง × 56 สูง แทนที่จะสูงเป็นกรวย)
	local top = decor(isle, Vector3.new(radius * 0.22, radius * 2, radius * 2 * 0.9),
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2), GRASS, Enum.Material.Grass)
	top.Shape = Enum.PartType.Cylinder

	-- กรวยหินใต้เกาะ ซ้อนหลายชั้น เล็กลงเรื่อยๆ จนแหลม
	local layers = 5
	for i = 1, layers do
		local t = i / layers
		local r = radius * (1 - t * 0.82)
		local h = radius * 0.34
		local y = at.Y - radius * 0.12 - (i - 0.5) * h * 0.8
		-- เช่นเดียวกัน: X = ความหนาของชั้น · Y/Z = เส้นผ่าศูนย์กลาง
		local piece = decor(isle, Vector3.new(h, r * 2, r * 2 * 0.9),
			CFrame.new(at.X, y, at.Z) * CFrame.Angles(0, 0, math.pi / 2), rock, Enum.Material.Slate)
		piece.Shape = Enum.PartType.Cylinder
	end

	-- แง่งหินห้อยจากก้น ให้เงาใต้เกาะไม่จบเป็นกรวยเกลี้ยงเกินไป
	local spikes = rng:NextInteger(2, 4)
	for _ = 1, spikes do
		local a = rng:NextNumber() * math.pi * 2
		local d = radius * rng:NextNumber(0.1, 0.4)
		local len = radius * rng:NextNumber(0.5, 1.1)
		decor(isle, Vector3.new(radius * 0.22, len, radius * 0.22),
			CFrame.new(at.X + math.cos(a) * d, at.Y - radius * 1.5 - len / 2, at.Z + math.sin(a) * d),
			rock, Enum.Material.Slate)
	end

	-- ต้นไม้เล็กๆ บนเกาะใหญ่ ให้รู้ว่ามันเป็นที่ที่มีชีวิต ไม่ใช่หินเปล่า
	if radius > 45 then
		for _ = 1, rng:NextInteger(2, 5) do
			local a = rng:NextNumber() * math.pi * 2
			local d = radius * rng:NextNumber(0, 0.6)
			local x, z = at.X + math.cos(a) * d, at.Z + math.sin(a) * d
			local th = radius * rng:NextNumber(0.16, 0.28)
			decor(isle, Vector3.new(th * 0.22, th, th * 0.22),
				CFrame.new(x, at.Y + radius * 0.11 + th / 2, z),
				Color3.fromRGB(94, 62, 44), Enum.Material.Wood)
			decor(isle, Vector3.new(th * 1.1, th * 0.9, th * 1.1),
				CFrame.new(x, at.Y + radius * 0.11 + th, z),
				Color3.fromRGB(74, 128, 52), Enum.Material.Grass)
		end
	end
	return isle
end

--------------------------------------------------------------------------------
-- 2. เกาะลอยฟ้ารอบๆ
--------------------------------------------------------------------------------

-- **วงใน 6 เกาะ · วงนอก 8 เกาะ** วงในใหญ่และใกล้พอให้เห็นรายละเอียด วงนอกเล็กและจางเป็นฉากหลัง
--
-- ระยะเริ่มที่ 700 สตัด — ไกลกว่ากำแพงล่องหน (รัศมี ~220) มากพอที่จะไม่มีใครบินไปถึง
-- และใกล้พอที่จะยังเห็นชัดว่าเป็นเกาะ ไม่ใช่จุดเบลอ
local RINGS = {
	{ count = 6, dist = 760, spread = 180, radius = { 55, 95 }, y = { -70, 60 }, tint = ROCK },
	{ count = 8, dist = 1500, spread = 420, radius = { 70, 140 }, y = { -180, 170 }, tint = ROCK_COOL },
}

local made = 0
for ri, ring in ipairs(RINGS) do
	-- กระจายมุมให้ทั่ว ไม่ใช่สุ่มล้วน — สุ่มล้วนจะได้กระจุกข้างหนึ่งและโล่งอีกข้าง
	local base = rng:NextNumber() * math.pi * 2
	for i = 1, ring.count do
		local a = base + (i / ring.count) * math.pi * 2 + rng:NextNumber(-0.22, 0.22)
		local d = ring.dist + rng:NextNumber(-ring.spread, ring.spread)
		local at = Vector3.new(
			CENTRE.X + math.cos(a) * d,
			CENTRE.Y + rng:NextNumber(ring.y[1], ring.y[2]),
			CENTRE.Z + math.sin(a) * d * 0.95)
		floatingIsle(root, at, rng:NextNumber(ring.radius[1], ring.radius[2]), ring.tint)
		made += 1
	end
	if ri == 1 then rng = Random.new(SEED + 7) end -- วงนอกใช้ชุดสุ่มของตัวเอง
end

--------------------------------------------------------------------------------
-- 3. แพเมฆใกล้ๆ
--------------------------------------------------------------------------------

-- เมฆของ Terrain อยู่**สูงเหนือหัว**เสมอ ซึ่งไม่ช่วยเรื่อง "เกาะลอยอยู่บนอะไร"
-- แพเมฆพวกนี้อยู่ **ต่ำกว่าเกาะ** เพื่อให้เวลาเดินไปขอบแล้วมองลง เห็นเมฆอยู่ข้างใต้จริงๆ
local CLOUD = Color3.fromRGB(246, 248, 252)

local function cloudRaft(at, scale)
	local raft = Instance.new("Model")
	raft.Name = "CloudRaft"
	raft.Parent = root
	-- **ก้อนต้องเหลื่อมกันจนกลืนเป็นก้อนเดียว ไม่ใช่เรียงเป็นแถวลูกบอล**
	--
	-- รอบแรกผมสุ่มตำแหน่งในกรอบกว้างเท่าๆ กันทุกก้อน แล้วได้ "แถวลูกปิงปองสีขาว" ชัดเจนในภาพ —
	-- เพราะก้อนห่างกันเกินกว่าจะซ้อน และกลมเท่ากันหมด
	--
	-- สามอย่างที่แก้: (1) ก้อนกลางใหญ่แล้วก้อนรอบเล็กลงตามระยะ (2) ระยะสุ่มแคบกว่ารัศมีก้อน ก้อนจึง
	-- ทับกันเสมอ (3) แบนลง (Y ~0.4 ของ X) เพราะเมฆจริงแผ่ตามแนวนอน ไม่ใช่ทรงกลม
	local blobs = rng:NextInteger(7, 11)
	for i = 1, blobs do
		-- ก้อนแรกเป็นแกนกลาง ก้อนต่อมากระจายออกแต่ยังทับแกน
		local t = (i == 1) and 0 or rng:NextNumber(0.25, 1.0)
		local s = scale * (1.0 - t * 0.55)
		local a = rng:NextNumber() * math.pi * 2
		local off = scale * 0.42 * t
		local p = decor(raft,
			Vector3.new(s, s * rng:NextNumber(0.34, 0.46), s * rng:NextNumber(0.78, 0.95)),
			CFrame.new(
				at.X + math.cos(a) * off,
				at.Y + rng:NextNumber(-scale * 0.06, scale * 0.06),
				at.Z + math.sin(a) * off * 0.8),
			CLOUD, Enum.Material.SmoothPlastic)
		p.Shape = Enum.PartType.Ball
		-- **เกือบทึบ** โปร่งมากแล้วจะเห็นขอบก้อนที่ซ้อนกันข้างใน ซึ่งเป็นสิ่งที่ทำให้ดูเป็นลูกบอล
		p.Transparency = 0.06
		p.CastShadow = false
	end
	return raft
end

-- **อยู่ต่ำกว่าเกาะมากพอที่จะเป็น "พื้นเมฆ" ไม่ใช่ของลอยระดับสายตา**
-- ใกล้ระดับเกาะเมื่อไหร่ มันจะบังวิวเกาะประดับ และเห็นชัดว่าเป็นก้อนกลมๆ
local rafts = 0
for i = 1, 11 do
	local a = (i / 11) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
	local d = rng:NextNumber(420, 1100)
	cloudRaft(Vector3.new(
		CENTRE.X + math.cos(a) * d,
		CENTRE.Y - rng:NextNumber(240, 430),
		CENTRE.Z + math.sin(a) * d), rng:NextNumber(150, 260))
	rafts += 1
end

--------------------------------------------------------------------------------
-- 4. ปรับ Sky/Atmosphere เท่าที่ไม่ชนกับนาฬิกา
--------------------------------------------------------------------------------

-- **แตะเฉพาะค่าที่ `DayNight.server` ไม่ได้เขียน** มันเขียน FogColor/FogEnd และ Atmosphere
-- Density/Haze/Color ทุก 0.25 วินาที — ตั้งค่าพวกนั้นที่นี่จะหายทันที
-- ส่วน `Offset` กับ `Decay` ไม่มีใครแตะ จึงตั้งได้จริงและอยู่ถาวร
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	-- ดันระยะไกลให้ขาวนวลขึ้น = เกาะวงนอกจางหายเข้าไปในฟ้าแทนที่จะลอยเด่นเป็นก้อนดำ
	atmosphere.Offset = 0.25
	atmosphere.Decay = Color3.fromRGB(176, 196, 222)
end

local count = 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
end

status(("done: เกาะลอยฟ้า %d เกาะ · แพเมฆ %d กลุ่ม · %d พาร์ท (ไม่ชน ไม่ถูกเรย์ถาม)")
	:format(made, rafts, count), true)
