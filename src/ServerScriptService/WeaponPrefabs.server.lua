-- WeaponPrefabs.server.lua: builds the held weapon models into ReplicatedStorage.WOLD_Weapons at startup.
--
-- These used to be Creator Store models turned into prefabs by a one-off script that was never committed --
-- and which destroyed its own source models on the way out. When the folder disappeared from the place there
-- was no way to rebuild it, and every weapon silently vanished from players' hands (holdWeapon finds no
-- prefab and returns quietly). Building them from parts in code means the place file holds nothing the
-- project cannot recreate on its own.
--
-- Each model is one welded rigid body with a PrimaryPart, laid out along its LOCAL +Y with the grip end at
-- +Y, because that is the convention WeaponVisuals' GRIP offsets were measured against.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "WOLD_Weapons"

-- Colours picked to read at a glance in a crowd rather than to be realistic.
local STEEL = Color3.fromRGB(198, 202, 212)
local DARK_STEEL = Color3.fromRGB(120, 126, 138)
local WOOD = Color3.fromRGB(122, 84, 52)
local DARK_WOOD = Color3.fromRGB(84, 58, 38)
local LEATHER = Color3.fromRGB(72, 52, 40)
local GOLD = Color3.fromRGB(198, 158, 78)
local GOLD_DARK = Color3.fromRGB(146, 112, 46)
-- เข้มกว่าเดิม (96,226,158) หนึ่งขั้น: Neon ดันความสว่างขึ้นเอง สีจางจะเบิร์นจนกลายเป็นฟ้าขาว
local GEM = Color3.fromRGB(52, 198, 132)
local PAGES = Color3.fromRGB(232, 224, 198)

local function part(name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	-- A held weapon must never collide with its owner or be shoved by physics.
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- Welds every part to the primary one and returns the finished model.
local function assemble(name, primary, others)
	local model = Instance.new("Model")
	model.Name = name
	primary.Parent = model
	model.PrimaryPart = primary
	for _, p in ipairs(others) do
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = primary
		weld.Part1 = p
		weld.Parent = primary
	end
	return model
end

--------------------------------------------------------------------------------
-- รูปทรงอื่นนอกจากกล่อง
--------------------------------------------------------------------------------

-- อาวุธห้าชิ้นข้างล่าง (ดาบ ธนู ปืน สมุดเวท คทา) ออกแบบในโรงงานโมเดล WOLD-Models ที่
-- `models/weapon_base.lua` แล้วคัดลอกตัวเลขมาตรงๆ ตัวช่วยชุดนี้จึงรับพารามิเตอร์แบบเดียวกับ modelkit
-- เป๊ะ (`K.cyl` `K.ball` `K.wedge` `K.yaw/pitch/roll/deg`) แก้ที่โรงงานแล้วย้ายกลับมาได้โดยไม่ต้องแปลงเลข
--
-- ทุกชิ้นเก็บลง `bag` ให้ `assembleBag` เชื่อมเข้ากับ PrimaryPart ทีเดียว — ของเดิมไล่ใส่ตารางเองทุกชิ้น
-- ซึ่งพอชิ้นส่วนขึ้นจาก 5 เป็น 25 ชิ้นก็อ่านไม่ออกแล้ว
local function deg(d) return math.rad(d) end
local function yaw(a) return CFrame.Angles(0, a, 0) end
local function pitch(a) return CFrame.Angles(a, 0, 0) end
local function roll(a) return CFrame.Angles(0, 0, a) end

local function box(bag, name, cf, size, color, material)
	local p = part(name, size, cf, color, material)
	bag[#bag + 1] = p
	return p
end

-- ทรงกระบอกของ Roblox วางแกนตาม X จึงต้อง roll 90 องศาให้ตั้งตามแกน Y ของเฟรมที่ส่งเข้ามา
local function cyl(bag, name, cf, radius, height, color, material)
	local p = part(name, Vector3.new(height, radius * 2, radius * 2), cf * roll(math.pi / 2), color, material)
	p.Shape = Enum.PartType.Cylinder
	bag[#bag + 1] = p
	return p
end

local function ball(bag, name, cf, diameter, color, material)
	local p = part(name, Vector3.new(diameter, diameter, diameter), cf, color, material)
	p.Shape = Enum.PartType.Ball
	bag[#bag + 1] = p
	return p
end

local function wedge(bag, name, cf, size, color, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	bag[#bag + 1] = p
	return p
end

-- จานกลมที่หันหน้าตามแกน X ของเฟรม — ต่างจาก `cyl` ตรงที่ไม่ roll ให้ ใช้ทำเฟือง หน้าปัด ฝาถัง
local function disc(bag, name, cf, radius, thick, color, material)
	local p = part(name, Vector3.new(thick, radius * 2, radius * 2), cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	bag[#bag + 1] = p
	return p
end

-- เฟือง: จานหนึ่งใบ + ฟันรอบขอบ หมุนรอบแกน X ของเฟรมเดียวกัน
local function gear(bag, name, cf, radius, teeth, thick, color)
	disc(bag, name, cf, radius * 0.80, thick, color, Enum.Material.Metal)
	for i = 1, teeth do
		local a = (i / teeth) * math.pi * 2
		box(bag, name .. "Tooth", cf * pitch(a) * CFrame.new(0, radius * 0.90, 0),
			Vector3.new(thick, radius * 0.38, radius * 0.30), color, Enum.Material.Metal)
	end
end

-- ปลายแหลมจากลิ่มสองชิ้นประกบ · `width` = ความกว้างเต็มของใบ ลิ่มแต่ละชิ้นกินครึ่งหนึ่ง
-- **WedgePart หนาที่ local +Z แล้วลาดลงเป็นศูนย์ที่ local -Z เนื้ออยู่ฝั่ง local -Y** (วัดจากภาพในโรงงาน
-- ไม่ใช่จากเอกสาร) เดากลับด้านเมื่อไหร่ได้ทรงโบว์ไทแทนที่จะเป็นปลายแหลม
local function bladeTip(bag, name, topY, len, width, thick, color, material)
	local yc, half = topY - len / 2, width / 2
	local size = Vector3.new(thick, half, len)
	-- **ทิศของลิ่มคิดผิดมารอบหนึ่ง** WedgePart เต็มความสูงที่ local +Z และเรียวเป็นศูนย์ที่ local -Z
	-- ใส่ pitch(+90) เข้าไป local +Z ไปชี้ลง = ใบกว้างที่ปลายและแหลมตรงที่ต่อกับใบ คือปลายดาบกลับหัว
	-- ที่ถูกคือ local +Z ต้องชี้ขึ้น (pitch -90) แล้วครึ่งฝั่ง +Z ต้อง roll 180 อีกทีให้เนื้อหันเข้าหาแกนกลาง
	wedge(bag, name .. "R", CFrame.new(0, yc, width / 4) * pitch(-math.pi / 2) * roll(math.pi), size, color, material)
	wedge(bag, name .. "L", CFrame.new(0, yc, -width / 4) * pitch(-math.pi / 2), size, color, material)
end

-- เชื่อมทุกชิ้นใน bag เข้ากับ primary (ข้าม primary เอง)
local function assembleBag(name, primary, bag)
	local others = {}
	for _, p in ipairs(bag) do
		if p ~= primary then others[#others + 1] = p end
	end
	return assemble(name, primary, others)
end

--------------------------------------------------------------------------------
-- The four weapons
--------------------------------------------------------------------------------

local Builders = {}

-- Sword: blade at the origin, hilt at +Y. WeaponVisuals flips it 180 so the point stands up, and offsets by
-- 2.0 studs to put the HANDLE in the palm -- both measured against exactly this layout, so it must not move.
function Builders.Sword()
	local b = {}
	-- สันกลางหนา แล้วเอาแท่งสี่เหลี่ยมหมุน 45 องศาไปทาบเป็นคมสองข้าง — ได้หน้าตัดทรงเพชร
	-- **นี่คือสิ่งเดียวที่ทำให้ใบมีดเลิกเป็นแผ่นกระดาน** มองมุมไหนก็มีเส้นสันวิ่งกลางใบ
	local blade = box(b, "Blade", CFrame.new(), Vector3.new(0.15, 2.90, 0.30), STEEL, Enum.Material.Metal)
	for _, s in ipairs({ 1, -1 }) do
		box(b, "Edge", CFrame.new(0, 0, s * 0.16) * yaw(deg(45)), Vector3.new(0.13, 2.90, 0.13), STEEL, Enum.Material.Metal)
		box(b, "Fuller", CFrame.new(s * 0.077, 0.12, 0), Vector3.new(0.02, 2.30, 0.11), DARK_STEEL, Enum.Material.Metal)
	end
	bladeTip(b, "Tip", -1.45, 0.58, 0.50, 0.15, STEEL, Enum.Material.Metal)

	box(b, "Ricasso", CFrame.new(0, 1.32, 0), Vector3.new(0.19, 0.30, 0.36), DARK_STEEL, Enum.Material.Metal)

	box(b, "Guard", CFrame.new(0, 1.55, 0), Vector3.new(0.26, 0.24, 0.40), GOLD, Enum.Material.Metal)
	for _, s in ipairs({ 1, -1 }) do
		box(b, "GuardArm", CFrame.new(0, 1.51, s * 0.42) * pitch(s * deg(14)),
			Vector3.new(0.22, 0.18, 0.48), GOLD, Enum.Material.Metal)
		ball(b, "GuardTip", CFrame.new(0, 1.42, s * 0.68), 0.22, GOLD, Enum.Material.Metal)
	end
	box(b, "Langet", CFrame.new(0, 1.37, 0), Vector3.new(0.21, 0.24, 0.18), GOLD_DARK, Enum.Material.Metal)

	-- ด้ามกลมพันหนัง + ปลอกทองคาดสี่เส้น (ของเดิมเป็นกล่องสี่เหลี่ยมชิ้นเดียว)
	cyl(b, "Collar", CFrame.new(0, 1.70, 0), 0.15, 0.11, GOLD, Enum.Material.Metal)
	cyl(b, "Handle", CFrame.new(0, 2.02, 0), 0.115, 0.84, LEATHER, Enum.Material.Fabric)
	for i = 0, 3 do
		cyl(b, "Wrap" .. i, CFrame.new(0, 1.76 + i * 0.21, 0), 0.135, 0.06, GOLD_DARK, Enum.Material.Metal)
	end

	cyl(b, "PommelDisc", CFrame.new(0, 2.40, 0), 0.18, 0.09, GOLD, Enum.Material.Metal)
	ball(b, "Pommel", CFrame.new(0, 2.54, 0), 0.32, GOLD, Enum.Material.Metal)
	ball(b, "Rivet", CFrame.new(0, 2.70, 0), 0.13, GOLD_DARK, Enum.Material.Metal)
	return assembleBag("Sword", blade, b)
end

-- Greatsword: built from parts like every other weapon here.
--
-- The id the user supplied (131042286719658) is a DECAL, not a Model -- it is the inventory icon, and there
-- is no 3D greatsword on the account to load. So the weapon in the hand is built to the sword's layout at
-- half again the size: blade at the origin, hilt at +Y, which is what WeaponVisuals' grip maths expects.
--
-- If a real model is uploaded later, this is the one function to replace.
function Builders.Greatsword()
	local b = {}
	local COPPER = Color3.fromRGB(176, 108, 62)
	local COPPER_DARK = Color3.fromRGB(128, 76, 44)
	local BRIGHT = Color3.fromRGB(216, 220, 230)
	local BRASS = Color3.fromRGB(198, 158, 78)
	local BRASS_DARK = Color3.fromRGB(142, 108, 44)
	local DIAL = Color3.fromRGB(238, 232, 212)

	-- ใบมีดคมเดียว: หน้าใบทองแดง แผงเว้าสีเข้มกลางใบ สันหลังหนาฝั่ง -Z คมเหล็กสว่างฝั่ง +Z
	local blade = box(b, "Blade", CFrame.new(), Vector3.new(0.26, 4.40, 0.62), COPPER, Enum.Material.Metal)
	box(b, "Panel", CFrame.new(0, 0.30, -0.06), Vector3.new(0.29, 3.10, 0.32), COPPER_DARK, Enum.Material.Metal)
	box(b, "Belly", CFrame.new(0, 0.55, 0.02), Vector3.new(0.25, 2.30, 0.74), COPPER, Enum.Material.Metal)
	box(b, "Spine", CFrame.new(0, 0, -0.34), Vector3.new(0.30, 4.40, 0.18), COPPER_DARK, Enum.Material.Metal)
	box(b, "Edge", CFrame.new(0, -0.05, 0.38), Vector3.new(0.18, 4.30, 0.22), BRIGHT, Enum.Material.Metal)
	box(b, "EdgeBevel", CFrame.new(0, -0.05, 0.47) * yaw(deg(45)), Vector3.new(0.11, 4.30, 0.11), BRIGHT, Enum.Material.Metal)
	for i = -2, 2 do
		ball(b, "SpineRivet", CFrame.new(0, i * 0.78, -0.34), 0.11, BRASS, Enum.Material.Metal)
	end
	-- **ปลายสร้างเหมือนดาบธรรมดาทุกประการ** ลิ่มคู่สมมาตรรอบ z = 0 ห้ามเอาอะไรไปเกาะข้างเดียวของปลาย
	-- ไม่งั้นปลายจะดูเฉียงไปคนละทางกับดาบเล่มอื่น ทั้งที่ตัวลิ่มเองวางเหมือนกันเป๊ะ
	bladeTip(b, "Tip", -2.20, 0.62, 0.70, 0.26, COPPER, Enum.Material.Metal)

	-- ชุดเครื่องกลที่โคนใบ — ของที่เกาะสันหลังต้องยื่นพ้นสัน (z ต่ำกว่า -0.43) ไม่งั้นจมหายในซิลูเอต
	box(b, "Mount", CFrame.new(0, 1.50, -0.12), Vector3.new(0.34, 1.34, 0.62), BRASS, Enum.Material.Metal)
	box(b, "MountBand", CFrame.new(0, 2.02, -0.12), Vector3.new(0.38, 0.26, 0.66), BRASS_DARK, Enum.Material.Metal)
	box(b, "MountBandLow", CFrame.new(0, 0.94, -0.12), Vector3.new(0.38, 0.22, 0.66), BRASS_DARK, Enum.Material.Metal)
	cyl(b, "Boiler", CFrame.new(0, 1.92, -0.62), 0.17, 0.56, BRASS, Enum.Material.Metal)
	cyl(b, "BoilerCap", CFrame.new(0, 2.22, -0.62), 0.19, 0.10, BRASS_DARK, Enum.Material.Metal)
	cyl(b, "ValveStem", CFrame.new(0, 2.38, -0.62), 0.055, 0.24, BRASS_DARK, Enum.Material.Metal)
	disc(b, "ValveWheel", CFrame.new(0, 2.52, -0.62), 0.15, 0.05, BRASS, Enum.Material.Metal)
	box(b, "BoilerFoot", CFrame.new(0, 1.92, -0.48), Vector3.new(0.10, 0.20, 0.20), BRASS_DARK, Enum.Material.Metal)
	ball(b, "GemSocket", CFrame.new(0, 1.20, -0.56), 0.28, BRASS_DARK, Enum.Material.Metal)
	ball(b, "Gem", CFrame.new(0, 1.20, -0.60), 0.22, GEM, Enum.Material.Neon)
	box(b, "Pipe", CFrame.new(0, 1.56, -0.56) * pitch(deg(14)), Vector3.new(0.08, 0.62, 0.08), BRASS, Enum.Material.Metal)

	gear(b, "GearBig", CFrame.new(0.19, 1.34, -0.02), 0.34, 9, 0.07, BRASS)
	gear(b, "GearSmall", CFrame.new(0.21, 0.80, 0.14), 0.21, 7, 0.06, BRASS_DARK)
	gear(b, "GearTiny", CFrame.new(0.18, 1.80, 0.16), 0.16, 6, 0.06, BRASS)

	-- การ์ดแผ่นทองเหลือง + แขนม้วนสองข้าง + นาฬิกาฝังหน้าการ์ด
	box(b, "Guard", CFrame.new(0, 2.30, 0), Vector3.new(0.34, 0.32, 1.06), BRASS, Enum.Material.Metal)
	box(b, "GuardBlock", CFrame.new(0, 2.30, 0), Vector3.new(0.38, 0.20, 0.52), BRASS_DARK, Enum.Material.Metal)
	for _, s in ipairs({ 1, -1 }) do
		box(b, "Scroll1", CFrame.new(0, 2.12, s * 0.62) * pitch(s * deg(30)),
			Vector3.new(0.26, 0.46, 0.26), BRASS, Enum.Material.Metal)
		box(b, "Scroll2", CFrame.new(0, 1.84, s * 0.88) * pitch(s * deg(56)),
			Vector3.new(0.20, 0.36, 0.20), BRASS, Enum.Material.Metal)
		ball(b, "ScrollCurl", CFrame.new(0, 1.64, s * 0.94), 0.22, BRASS, Enum.Material.Metal)
	end
	disc(b, "ClockRim", CFrame.new(0.20, 2.30, 0), 0.34, 0.10, BRASS, Enum.Material.Metal)
	disc(b, "ClockFace", CFrame.new(0.26, 2.30, 0), 0.27, 0.05, DIAL)
	box(b, "HandHour", CFrame.new(0.29, 2.39, 0), Vector3.new(0.03, 0.19, 0.04), BRASS_DARK, Enum.Material.Metal)
	box(b, "HandMinute", CFrame.new(0.29, 2.30, 0.10), Vector3.new(0.03, 0.04, 0.21), BRASS_DARK, Enum.Material.Metal)
	ball(b, "HandPin", CFrame.new(0.29, 2.30, 0), 0.07, BRASS_DARK, Enum.Material.Metal)

	cyl(b, "Collar", CFrame.new(0, 2.56, 0), 0.17, 0.12, BRASS, Enum.Material.Metal)
	cyl(b, "Handle", CFrame.new(0, 3.02, 0), 0.125, 1.28, DARK_WOOD, Enum.Material.Wood)
	for i = 0, 4 do
		cyl(b, "GripBand" .. i, CFrame.new(0, 2.66 + i * 0.19, 0), 0.155, 0.07, BRASS, Enum.Material.Metal)
	end
	cyl(b, "PommelCollar", CFrame.new(0, 3.64, 0), 0.17, 0.10, BRASS_DARK, Enum.Material.Metal)
	ball(b, "Pommel", CFrame.new(0, 3.82, 0), 0.34, BRASS, Enum.Material.Metal)
	ball(b, "PommelTip", CFrame.new(0, 4.00, 0), 0.15, BRASS_DARK, Enum.Material.Metal)
	return assembleBag("Greatsword", blade, b)
end

-- Bow: the riser is the body, the limbs curve away from it, and the string runs between the tips.
function Builders.Bow()
	local b = {}
	local riser = box(b, "Riser", CFrame.new(), Vector3.new(0.26, 1.30, 0.34), DARK_WOOD, Enum.Material.Wood)
	box(b, "RiserSpine", CFrame.new(0, 0, -0.22), Vector3.new(0.20, 1.06, 0.16), WOOD, Enum.Material.Wood)
	box(b, "ArrowShelf", CFrame.new(0, 0.30, -0.14), Vector3.new(0.30, 0.09, 0.22), WOOD, Enum.Material.Wood)
	cyl(b, "Grip", CFrame.new(), 0.165, 0.62, LEATHER, Enum.Material.Fabric)
	for _, y in ipairs({ -0.24, 0.24 }) do
		cyl(b, "GripBand", CFrame.new(0, y, 0), 0.18, 0.06, DARK_WOOD, Enum.Material.Leather)
	end

	-- **ปีกสามท่อนไล่มุม 10/20/32 องศา** ของเดิมใช้กล่องเดียวเอียง 14 องศา ซึ่งอ่านเป็นไม้หักไม่ใช่ธนูโค้ง
	for _, s in ipairs({ 1, -1 }) do
		local side = s == 1 and "Upper" or "Lower"
		box(b, side .. "Limb1", CFrame.new(0, s * 0.95, 0.10) * pitch(s * deg(10)),
			Vector3.new(0.20, 0.80, 0.26), WOOD, Enum.Material.Wood)
		box(b, side .. "Limb2", CFrame.new(0, s * 1.62, 0.29) * pitch(s * deg(20)),
			Vector3.new(0.17, 0.76, 0.22), WOOD, Enum.Material.Wood)
		box(b, side .. "Limb3", CFrame.new(0, s * 2.12, 0.56) * pitch(s * deg(32)),
			Vector3.new(0.14, 0.58, 0.18), DARK_WOOD, Enum.Material.Wood)
		-- ท้องปีกสีอ่อนกว่า = เห็นความหนาของปีก ไม่ใช่แผ่นเดียว
		box(b, side .. "Belly", CFrame.new(0, s * 1.62, 0.17) * pitch(s * deg(20)),
			Vector3.new(0.09, 0.76, 0.10), Color3.fromRGB(158, 116, 74), Enum.Material.Wood)
		box(b, side .. "Nock", CFrame.new(0, s * 2.36, 0.70) * pitch(s * deg(32)),
			Vector3.new(0.12, 0.24, 0.15), GOLD, Enum.Material.Metal)
	end

	box(b, "String", CFrame.new(0, 0, 0.70), Vector3.new(0.04, 4.60, 0.04), PAGES)
	box(b, "Serving", CFrame.new(0, 0, 0.70), Vector3.new(0.06, 0.34, 0.06), DARK_WOOD, Enum.Material.Fabric)
	return assembleBag("Bow", riser, b)
end

-- Staff: a long shaft with a gem cradled at the top. Held against the torso, so it reads at full length.
function Builders.Staff()
	local b = {}
	-- ก้านเรียวจากโคนไปปลาย: สามท่อนรัศมีต่างกัน แทนแท่งเดียวความหนาเท่ากันตลอดของเดิม
	-- **PrimaryPart ต้องเป็นชิ้นที่ไม่ถูกหมุน** `cyl` ใส่ roll 90 องศาให้ทรงกระบอกตั้งตรง (แกนของ Cylinder
	-- ใน Roblox คือแกน X เสมอ) ถ้าเอาทรงกระบอกนั้นเป็นตัวขับ Motor6D คทาจะนอนขวางในมือทั้งดุ้น
	-- เพราะ `GRIP.Staff` วัดมาจากแกนของโมเดลที่ไม่ได้หมุน — แกนกลางสี่เหลี่ยมชิ้นนี้จึงเป็นตัวขับแทน
	local shaft = box(b, "Core", CFrame.new(), Vector3.new(0.13, 4.00, 0.13), WOOD, Enum.Material.Wood)
	cyl(b, "Shaft", CFrame.new(), 0.10, 4.00, WOOD, Enum.Material.Wood)
	cyl(b, "ShaftLower", CFrame.new(0, -1.40, 0), 0.118, 1.20, WOOD, Enum.Material.Wood)
	cyl(b, "ShaftUpper", CFrame.new(0, 1.45, 0), 0.086, 1.10, WOOD, Enum.Material.Wood)
	for _, y in ipairs({ -1.60, -0.80, 0.00, 0.80, 1.60 }) do
		cyl(b, "CarvedRing", CFrame.new(0, y, 0), 0.128, 0.07, DARK_WOOD, Enum.Material.Wood)
	end
	-- ปุ่มปมของไม้ — ทำให้ก้านอ่านเป็นกิ่งไม้ ไม่ใช่ท่อกลม
	ball(b, "Knot1", CFrame.new(0.06, -0.42, 0), 0.17, WOOD, Enum.Material.Wood)
	ball(b, "Knot2", CFrame.new(-0.05, 0.56, 0.04), 0.15, WOOD, Enum.Material.Wood)
	ball(b, "Knot3", CFrame.new(0.04, 1.16, -0.05), 0.14, WOOD, Enum.Material.Wood)

	cyl(b, "Binding", CFrame.new(0, 1.30, 0), 0.135, 0.46, LEATHER, Enum.Material.Fabric)
	for _, y in ipairs({ 1.14, 1.46 }) do
		cyl(b, "BindStrap", CFrame.new(0, y, 0), 0.15, 0.06, DARK_WOOD, Enum.Material.Leather)
	end

	-- อุ้งเล็บสามนิ้ว นิ้วละสองท่อน งุ้มเข้าหาอัญมณี
	for _, a in ipairs({ 0, 120, 240 }) do
		box(b, "Claw" .. a, CFrame.new(0, 1.96, 0) * yaw(deg(a)) * CFrame.new(0, 0, 0.20) * pitch(deg(-16)),
			Vector3.new(0.09, 0.52, 0.10), DARK_WOOD, Enum.Material.Wood)
		box(b, "ClawTip" .. a, CFrame.new(0, 2.32, 0) * yaw(deg(a)) * CFrame.new(0, 0, 0.27) * pitch(deg(-42)),
			Vector3.new(0.07, 0.38, 0.08), DARK_WOOD, Enum.Material.Wood)
	end

	local gem = ball(b, "Gem", CFrame.new(0, 2.25, 0), 0.52, GEM, Enum.Material.Neon)
	box(b, "GemFacet", CFrame.new(0, 2.25, 0) * yaw(deg(45)) * pitch(deg(45)),
		Vector3.new(0.36, 0.36, 0.36), GEM, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = GEM
	light.Range = 10
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = gem

	cyl(b, "Ferrule", CFrame.new(0, -2.00, 0), 0.118, 0.34, DARK_STEEL, Enum.Material.Metal)
	box(b, "Spike", CFrame.new(0, -2.26, 0), Vector3.new(0.10, 0.24, 0.10), DARK_STEEL, Enum.Material.Metal)
	return assembleBag("Staff", shaft, b)
end

-- Spellbook: a closed tome. It floats at the chest rather than being gripped, so it is small and flat.
function Builders.Spellbook()
	local b = {}
	local COVER = Color3.fromRGB(96, 48, 40)
	local COVER_DARK = Color3.fromRGB(72, 34, 28)

	-- **กองกระดาษชั้นกลางอยู่ที่จุดกำเนิดพอดี** เพราะมันคือ PrimaryPart ที่ Motor6D ขับ — ของเดิมใช้ปก
	-- ที่จุดกำเนิดเป็นตัวขับ ถ้าไม่มีชิ้นไหนอยู่ที่ 0 เลย เล่มจะเลื่อนจากมือไปหนึ่งขั้น
	local pages = box(b, "Pages", CFrame.new(), Vector3.new(1.18, 0.08, 1.48), PAGES)
	box(b, "PagesUp", CFrame.new(0.015, 0.08, 0.015), Vector3.new(1.15, 0.08, 1.45), PAGES)
	box(b, "PagesDown", CFrame.new(-0.015, -0.08, -0.015), Vector3.new(1.15, 0.08, 1.45), PAGES)
	box(b, "CoverFront", CFrame.new(0, 0.18, 0), Vector3.new(1.32, 0.11, 1.62), COVER, Enum.Material.Leather)
	box(b, "CoverBack", CFrame.new(0, -0.18, 0), Vector3.new(1.32, 0.11, 1.62), COVER, Enum.Material.Leather)

	box(b, "Spine", CFrame.new(-0.64, 0, 0), Vector3.new(0.24, 0.48, 1.64), COVER_DARK, Enum.Material.Leather)
	for _, z in ipairs({ -0.54, -0.18, 0.18, 0.54 }) do
		box(b, "SpineBand", CFrame.new(-0.66, 0, z), Vector3.new(0.26, 0.52, 0.10), GOLD, Enum.Material.Metal)
	end
	for _, sx in ipairs({ 1, -1 }) do
		for _, sz in ipairs({ 1, -1 }) do
			box(b, "Corner", CFrame.new(sx * 0.52, 0.23, sz * 0.68), Vector3.new(0.26, 0.05, 0.22), GOLD, Enum.Material.Metal)
		end
	end
	box(b, "Inlay1", CFrame.new(0, 0.24, 0), Vector3.new(0.52, 0.04, 0.06), GOLD_DARK, Enum.Material.Metal)
	box(b, "Inlay2", CFrame.new(0, 0.24, 0), Vector3.new(0.06, 0.04, 0.72), GOLD_DARK, Enum.Material.Metal)
	ball(b, "Boss", CFrame.new(0, 0.24, 0), 0.26, GOLD, Enum.Material.Metal)
	-- อัญมณีต้องโผล่พ้นหัวหมุด ไม่งั้นจมอยู่ข้างในทั้งเม็ด
	ball(b, "Rune", CFrame.new(0, 0.34, 0), 0.19, GEM, Enum.Material.Neon)

	box(b, "Clasp", CFrame.new(0.64, 0, 0), Vector3.new(0.15, 0.32, 0.28), GOLD, Enum.Material.Metal)
	box(b, "Strap", CFrame.new(0.52, 0.23, 0), Vector3.new(0.28, 0.05, 0.18), COVER_DARK, Enum.Material.Leather)
	box(b, "Ribbon", CFrame.new(0.26, -0.22, 0.72), Vector3.new(0.11, 0.03, 0.42), Color3.fromRGB(168, 54, 58), Enum.Material.Fabric)
	return assembleBag("Spellbook", pages, b)
end

--------------------------------------------------------------------------------
-- The three tools
--------------------------------------------------------------------------------

-- All three follow the sword's convention exactly: the working end sits at the origin and the grip runs out
-- to +Y, with the hand meeting the shaft 2.0 studs along it. That is not a coincidence to be tidied away --
-- WeaponVisuals reuses the sword's GRIP offset for these, and it was measured against precisely this layout.
-- Move the handle and the tool ends up held by its blade.

-- ด้ามไม้กลมของเครื่องมือทั้งสามชิ้น
--
-- **แกนกลางสี่เหลี่ยม `Core` มีไว้เป็น PrimaryPart** — ด้ามจริงเป็นทรงกระบอกซึ่ง `cyl` roll 90 องศาให้เสมอ
-- เอาทรงกระบอกไปเป็นตัวขับ Motor6D แล้วเครื่องมือจะนอนขวางมือทั้งดุ้น (บทเรียนเดียวกับคทา)
local function toolHaft(bag, gripY, gripLen)
	local core = box(bag, "Core", CFrame.new(), Vector3.new(0.11, 3.00, 0.11), WOOD, Enum.Material.Wood)
	cyl(bag, "Haft", CFrame.new(), 0.085, 3.00, WOOD, Enum.Material.Wood)
	cyl(bag, "HaftSwell", CFrame.new(0, 1.25, 0), 0.10, 0.90, WOOD, Enum.Material.Wood)
	cyl(bag, "Grip", CFrame.new(0, gripY, 0), 0.105, gripLen, LEATHER, Enum.Material.Fabric)
	for i = -1, 1 do
		cyl(bag, "GripWrap", CFrame.new(0, gripY + i * (gripLen / 3), 0), 0.122, 0.06, DARK_WOOD, Enum.Material.Fabric)
	end
	return core
end

-- Axe: a wedge head on one side of the haft, with a small back-spike to balance it visually.
function Builders.Axe()
	local b = {}
	local BRIGHT = Color3.fromRGB(224, 228, 238)
	local core = toolHaft(b, 2.00, 0.90)

	cyl(b, "Collar", CFrame.new(0, -0.62, 0), 0.115, 0.26, DARK_STEEL, Enum.Material.Metal)
	box(b, "Eye", CFrame.new(0, -1.10, 0.17), Vector3.new(0.19, 0.66, 0.26), DARK_STEEL, Enum.Material.Metal)
	-- แกนใบสี่เหลี่ยมหนึ่งชิ้น แล้วบานออกด้วยลิ่มบน-ล่าง ได้เส้นเฉียงเส้นเดียวจากโคนถึงคม
	-- **บานด้วยกล่องซ้อนเป็นชั้นไม่ได้** ขอบจะเป็นบันไดเห็นชัด (เจอมาแล้วตอนทำขวานทอง)
	box(b, "Bit", CFrame.new(0, -1.10, 0.56), Vector3.new(0.14, 0.74, 0.82), STEEL, Enum.Material.Metal)
	wedge(b, "FlareTop", CFrame.new(0, -0.63, 0.56), Vector3.new(0.12, 0.30, 0.82), STEEL, Enum.Material.Metal)
	wedge(b, "FlareBottom", CFrame.new(0, -1.57, 0.56) * roll(math.pi), Vector3.new(0.12, 0.30, 0.82), STEEL, Enum.Material.Metal)
	box(b, "Edge", CFrame.new(0, -1.10, 1.00), Vector3.new(0.05, 1.32, 0.10), BRIGHT, Enum.Material.Metal)
	box(b, "Cheek", CFrame.new(0.07, -1.10, 0.56), Vector3.new(0.02, 0.56, 0.60), DARK_STEEL, Enum.Material.Metal)
	box(b, "Poll", CFrame.new(0, -1.10, -0.16), Vector3.new(0.16, 0.42, 0.26), DARK_STEEL, Enum.Material.Metal)
	box(b, "PollFace", CFrame.new(0, -1.10, -0.30), Vector3.new(0.13, 0.30, 0.10), STEEL, Enum.Material.Metal)

	cyl(b, "Butt", CFrame.new(0, 2.52, 0), 0.12, 0.17, DARK_STEEL, Enum.Material.Metal)
	return assembleBag("Axe", core, b)
end

-- Pickaxe: a head crossing the haft, pointed one way and chisel-flat the other.
function Builders.Pickaxe()
	local b = {}
	local BRIGHT = Color3.fromRGB(224, 228, 238)
	local core = toolHaft(b, 2.00, 0.90)

	cyl(b, "Collar", CFrame.new(0, -0.78, 0), 0.125, 0.32, DARK_STEEL, Enum.Material.Metal)
	box(b, "Crown", CFrame.new(0, -1.15, 0), Vector3.new(0.22, 0.42, 0.42), DARK_STEEL, Enum.Material.Metal)
	box(b, "CrownBand", CFrame.new(0, -1.15, 0), Vector3.new(0.26, 0.20, 0.48), STEEL, Enum.Material.Metal)

	-- เขาโค้งสองข้าง: โคนต่ำ ปลายเชิดขึ้นออกนอก
	-- **ฝั่ง +Z ต้องใช้มุมลบ** ใส่มุมบวกปลายจะตกลงกลายเป็นหัวคว่ำ (บทเรียนจากอีเต้อทอง)
	for _, s in ipairs({ 1, -1 }) do
		local side = s == 1 and "R" or "L"
		box(b, "Horn1" .. side, CFrame.new(0, -1.18, s * 0.32) * pitch(-s * deg(8)),
			Vector3.new(0.16, 0.24, 0.50), DARK_STEEL, Enum.Material.Metal)
		box(b, "Horn2" .. side, CFrame.new(0, -1.10, s * 0.76) * pitch(-s * deg(22)),
			Vector3.new(0.14, 0.20, 0.50), STEEL, Enum.Material.Metal)
		box(b, "Horn3" .. side, CFrame.new(0, -0.92, s * 1.10) * pitch(-s * deg(38)),
			Vector3.new(0.11, 0.16, 0.40), STEEL, Enum.Material.Metal)
		box(b, "Point" .. side, CFrame.new(0, -0.75, s * 1.30) * pitch(-s * deg(46)),
			Vector3.new(0.07, 0.10, 0.22), BRIGHT, Enum.Material.Metal)
	end

	cyl(b, "Butt", CFrame.new(0, 2.52, 0), 0.12, 0.17, DARK_STEEL, Enum.Material.Metal)
	return assembleBag("Pickaxe", core, b)
end

-- Shovel: a dished blade at the bottom, a T-handle at the top so it reads as a shovel and not a paddle.
function Builders.Shovel()
	local b = {}
	local BRIGHT = Color3.fromRGB(224, 228, 238)
	local core = toolHaft(b, 1.86, 0.72)

	box(b, "Blade", CFrame.new(0, -1.26, 0.06), Vector3.new(0.82, 0.90, 0.10), STEEL, Enum.Material.Metal)
	-- ปลายเสียมเรียวลง — **yaw 90 องศาก่อน** เพราะใบกว้างตามแกน X ไม่ใช่แกน Z เหมือนใบดาบ
	-- ไม่หมุนแล้วลิ่มจะไปเรียวทางด้านหนาของใบ ได้ทรงตีนช้างบานออกแทนปลายแหลม
	local tipBag = {}
	bladeTip(tipBag, "BladeTip", -1.71, 0.48, 0.82, 0.10, STEEL, Enum.Material.Metal)
	for _, p in ipairs(tipBag) do
		p.CFrame = CFrame.new(0, 0, 0.06) * yaw(math.pi / 2) * p.CFrame
		b[#b + 1] = p
	end
	-- ขอบยกสองข้างของใบ = เห็นว่าใบเป็นแอ่ง ไม่ใช่แผ่นเรียบ
	for _, s in ipairs({ 1, -1 }) do
		box(b, "BladeWall", CFrame.new(s * 0.39, -1.22, 0.02), Vector3.new(0.08, 0.84, 0.18), DARK_STEEL, Enum.Material.Metal)
	end
	box(b, "Shoulder", CFrame.new(0, -0.82, 0.06), Vector3.new(0.46, 0.22, 0.12), DARK_STEEL, Enum.Material.Metal)
	box(b, "Edge", CFrame.new(0, -1.62, 0.11), Vector3.new(0.52, 0.10, 0.04), BRIGHT, Enum.Material.Metal)

	cyl(b, "Socket", CFrame.new(0, -0.64, 0), 0.115, 0.44, DARK_STEEL, Enum.Material.Metal)
	box(b, "Wing", CFrame.new(0, -0.90, -0.04), Vector3.new(0.15, 0.50, 0.16), DARK_STEEL, Enum.Material.Metal)

	-- หูจับตัว D: ขาสองข้างเอียงออกแล้วปิดด้วยคานบน (ของเดิมเป็นคานขวางชิ้นเดียว)
	for _, s in ipairs({ 1, -1 }) do
		box(b, "DArm", CFrame.new(s * 0.13, 2.30, 0) * roll(s * deg(16)),
			Vector3.new(0.09, 0.46, 0.10), DARK_WOOD, Enum.Material.Wood)
	end
	box(b, "DTop", CFrame.new(0, 2.54, 0), Vector3.new(0.40, 0.10, 0.11), DARK_WOOD, Enum.Material.Wood)
	box(b, "DBand", CFrame.new(0, 2.54, 0), Vector3.new(0.14, 0.12, 0.13), DARK_STEEL, Enum.Material.Metal)
	return assembleBag("Shovel", core, b)
end

--------------------------------------------------------------------------------
-- The pistol
--------------------------------------------------------------------------------

-- A steampunk flintlock: brass barrel, wooden stock, a little boiler drum where a hammer would be. Built to
-- the same convention as the rest -- muzzle at the origin, grip out along +Y -- so it takes SWORD_GRIP.
function Builders.Pistol()
	local b = {}
	-- ลำกล้องแปดเหลี่ยม: กล่องสองใบซ้อนโดยใบหนึ่งหมุน 45 องศา (ของเดิมเป็นกล่องเหลี่ยมใบเดียว)
	local barrel = box(b, "Barrel", CFrame.new(), Vector3.new(0.18, 1.80, 0.18), GOLD, Enum.Material.Metal)
	box(b, "BarrelFacet", yaw(deg(45)), Vector3.new(0.18, 1.80, 0.18), GOLD, Enum.Material.Metal)
	cyl(b, "Muzzle", CFrame.new(0, -0.96, 0), 0.13, 0.20, DARK_STEEL, Enum.Material.Metal)
	cyl(b, "MuzzleRing", CFrame.new(0, -0.84, 0), 0.115, 0.08, GOLD, Enum.Material.Metal)
	box(b, "FrontSight", CFrame.new(0, -0.74, 0.13), Vector3.new(0.05, 0.11, 0.07), DARK_STEEL, Enum.Material.Metal)
	cyl(b, "Ramrod", CFrame.new(0, -0.20, 0.17), 0.035, 1.20, DARK_WOOD, Enum.Material.Wood)

	box(b, "Breech", CFrame.new(0, 0.78, 0), Vector3.new(0.23, 0.42, 0.26), DARK_STEEL, Enum.Material.Metal)
	box(b, "Stock", CFrame.new(0, 0.92, -0.08), Vector3.new(0.21, 0.86, 0.32), WOOD, Enum.Material.Wood)
	box(b, "Tang", CFrame.new(0, 1.46, -0.13), Vector3.new(0.18, 0.44, 0.22), WOOD, Enum.Material.Wood)

	-- กลไกฝั่งขวา: แผ่นล็อก นกสับพร้อมปากคีบ จานดินปืน เหล็กไฟ
	box(b, "Lockplate", CFrame.new(0.12, 0.84, -0.10), Vector3.new(0.05, 0.54, 0.32), DARK_STEEL, Enum.Material.Metal)
	box(b, "Hammer", CFrame.new(0.13, 1.06, -0.26) * pitch(deg(26)), Vector3.new(0.07, 0.32, 0.14), DARK_STEEL, Enum.Material.Metal)
	box(b, "HammerJaw", CFrame.new(0.13, 1.20, -0.32), Vector3.new(0.09, 0.13, 0.13), GOLD, Enum.Material.Metal)
	box(b, "Frizzen", CFrame.new(0.12, 0.86, -0.29), Vector3.new(0.07, 0.20, 0.13), GOLD, Enum.Material.Metal)
	box(b, "Pan", CFrame.new(0.10, 0.78, -0.25), Vector3.new(0.10, 0.08, 0.14), GOLD, Enum.Material.Metal)
	ball(b, "SidePlate", CFrame.new(-0.12, 0.86, -0.10), 0.16, GOLD, Enum.Material.Metal)

	box(b, "Trigger", CFrame.new(0, 1.54, -0.26) * pitch(deg(16)), Vector3.new(0.06, 0.24, 0.09), DARK_STEEL, Enum.Material.Metal)
	-- โกร่งไกเป็นตัว U อยู่ฝั่ง -Z เหมือนด้ามและไก ไม่งั้นห่วงไปโผล่ด้านบนปืน คนละฝั่งกับนิ้วที่ควรลอด
	box(b, "GuardFront", CFrame.new(0, 1.42, -0.30), Vector3.new(0.07, 0.07, 0.28), GOLD, Enum.Material.Metal)
	box(b, "GuardBow", CFrame.new(0, 1.62, -0.42), Vector3.new(0.07, 0.40, 0.07), GOLD, Enum.Material.Metal)
	box(b, "GuardRear", CFrame.new(0, 1.82, -0.36), Vector3.new(0.07, 0.08, 0.20), GOLD, Enum.Material.Metal)

	box(b, "Grip", CFrame.new(0, 2.00, -0.22) * pitch(deg(18)), Vector3.new(0.24, 0.92, 0.32), WOOD, Enum.Material.Wood)
	box(b, "GripPanel", CFrame.new(0, 2.04, -0.28) * pitch(deg(18)), Vector3.new(0.26, 0.52, 0.22), DARK_WOOD, Enum.Material.Wood)
	box(b, "ButtCap", CFrame.new(0, 2.46, -0.36), Vector3.new(0.28, 0.17, 0.36), GOLD, Enum.Material.Metal)
	return assembleBag("Pistol", barrel, b)
end

--------------------------------------------------------------------------------
-- The fishing rod
--------------------------------------------------------------------------------

-- Same convention as the sword and the tools: working end at the origin, grip 2.0 studs out along +Y, so
-- it takes the shared SWORD_GRIP unchanged. The "working end" here is the rod tip, which is why the pole
-- runs DOWN from the grip rather than up.
function Builders.FishingRod()
	local pole = part("Pole", Vector3.new(0.12, 3.2, 0.12), CFrame.new(0, 0, 0), WOOD)
	local others = {
		part("Tip", Vector3.new(0.08, 0.7, 0.08), CFrame.new(0, -1.85, 0), DARK_WOOD),
		-- The reel, sitting just above the hand.
		part("Reel", Vector3.new(0.5, 0.5, 0.28), CFrame.new(0, 1.5, 0.2), DARK_STEEL, Enum.Material.Metal),
		part("ReelHandle", Vector3.new(0.12, 0.12, 0.36), CFrame.new(0.28, 1.5, 0.34), GOLD, Enum.Material.Metal),
		part("Grip", Vector3.new(0.2, 0.9, 0.2), CFrame.new(0, 2.0, 0), LEATHER),
		part("Butt", Vector3.new(0.24, 0.2, 0.24), CFrame.new(0, 2.5, 0), DARK_WOOD),
		-- The line: a thin pale strand from the tip back to the reel, so it reads as a rod and not a stick.
		part("Line", Vector3.new(0.03, 3.1, 0.03), CFrame.new(0, -0.2, 0.12), PAGES),
	}
	return assemble("FishingRod", pole, others)
end

--------------------------------------------------------------------------------
-- ตะหลิวเชฟ
--------------------------------------------------------------------------------

-- แบบเดียวกับดาบและเครื่องมือ: ปลายที่ใช้งาน (ใบพาย) อยู่ที่จุดกำเนิด ด้ามยื่นไป +Y 2.0 จึงใช้ SWORD_GRIP
-- ได้ทั้งดุ้นโดยไม่ต้องวัดใหม่ ใบแบนและกว้างพอให้อ่านออกว่าเป็นตะหลิว ไม่ใช่พลั่วเล็ก
function Builders.Spatula()
	local blade = part("Blade", Vector3.new(0.9, 1.0, 0.08), CFrame.new(0, 0, 0), STEEL, Enum.Material.Metal)
	local others = {
		-- มุมใบมนขึ้นนิดหน่อยด้วยชิ้นแคบกว่าที่ปลาย
		part("Lip", Vector3.new(0.7, 0.14, 0.08), CFrame.new(0, -0.55, 0), STEEL, Enum.Material.Metal),
		-- คอที่ต่อใบเข้ากับด้าม หักมุมขึ้นเล็กน้อยเหมือนตะหลิวจริง
		part("Neck", Vector3.new(0.18, 0.9, 0.1), CFrame.new(0, 0.95, 0.06), DARK_STEEL, Enum.Material.Metal),
		part("Handle", Vector3.new(0.22, 0.9, 0.22), CFrame.new(0, 2.0, 0.1), DARK_WOOD),
		part("Butt", Vector3.new(0.26, 0.18, 0.26), CFrame.new(0, 2.5, 0.1), GOLD, Enum.Material.Metal),
	}
	return assemble("Spatula", blade, others)
end

--------------------------------------------------------------------------------
-- โล่ไอน้ำ — ทรงหยดน้ำ (heater shield) ตามภาพอ้างอิงที่ผู้ใช้ส่งมา (decal 128590551137093)
--------------------------------------------------------------------------------

-- **ผังต่างจากอาวุธชิ้นอื่นในไฟล์นี้โดยตั้งใจ** ชิ้นอื่นวาง "ปลายที่ใช้งาน" ไว้ที่จุดกำเนิดแล้วให้ด้ามยื่นไป +Y
-- เพราะมันถูกจับด้วยมือ · โล่ไม่ได้ถูกจับ มัน **รัดอยู่กับท่อนแขนขวา** (ผู้ใช้กำหนด) ผังจึงเป็น:
--   · หน้าโล่หันไป -Z (ตรงกับกติกา "หน้า = -Z" ของโปรเจ็ค)  · กว้างตามแกน X  · สูงตามแกน Y
--   · จุดกำเนิด = กลางแผ่น ซึ่งเป็น PrimaryPart ที่ไม่ถูกหมุน (Motor6D ขับชิ้นนี้ ถ้าเอาทรงกระบอกที่ถูก
--     roll ไว้มาเป็นตัวขับ โล่จะนอนขวางแขนทั้งใบ — บทเรียนเดียวกับคทาในไฟล์นี้)
-- ระยะวางบนแขนอยู่ที่ `GRIP.Shield` ใน `WeaponVisuals` ไม่ใช่ที่นี่
function Builders.Shield()
	local b = {}
	local COPPER = Color3.fromRGB(186, 112, 66)
	local COPPER_DARK = Color3.fromRGB(138, 78, 46)
	local RUBY = Color3.fromRGB(214, 62, 86)

	local W, H, T = 2.00, 1.80, 0.18   -- กว้าง · สูงของส่วนสี่เหลี่ยม · ความหนาแผ่น
	local POINT = 1.05                 -- ความยาวของปลายแหลมที่ยื่นลงจากขอบล่าง
	local half = W / 2

	-- แผ่นหลักอยู่ที่จุดกำเนิดพอดี = PrimaryPart
	local plate = box(b, "Plate", CFrame.new(), Vector3.new(W, H, T), STEEL, Enum.Material.Metal)

	-- ปลายแหลมล่าง: ลิ่มสองชิ้นประกบ เต็มความสูงตรงกลางและเรียวเป็นศูนย์ที่ขอบข้าง
	--
	-- ใช้ลิ่มเองแทน `bladeTip` เพราะ bladeTip ถูกเขียนตามผังของดาบ (หนาตามแกน X กว้างตามแกน Z)
	-- ส่วนโล่หนาตามแกน Z กว้างตามแกน X — เอามาใช้ตรงๆ จะได้ปลายที่บิดไปคนละระนาบ
	local ptY = -H / 2 - POINT / 2
	wedge(b, "PointR", CFrame.new(half / 2, ptY, 0) * yaw(deg(-90)),
		Vector3.new(T, POINT, half), STEEL, Enum.Material.Metal)
	wedge(b, "PointL", CFrame.new(-half / 2, ptY, 0) * yaw(deg(90)),
		Vector3.new(T, POINT, half), STEEL, Enum.Material.Metal)

	-- ขอบทองเหลืองรอบใบ — เป็นสิ่งที่ทำให้อ่านออกว่าเป็นโล่ ไม่ใช่แผ่นเหล็กสี่เหลี่ยม
	local RIM = 0.22
	box(b, "RimTop", CFrame.new(0, H / 2 - 0.02, 0), Vector3.new(W + 0.14, RIM, T + 0.08), GOLD, Enum.Material.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		box(b, "RimSide", CFrame.new(sx * (half - 0.02), 0, 0), Vector3.new(RIM, H + 0.10, T + 0.08), GOLD, Enum.Material.Metal)
		-- ขอบเฉียงสองเส้นที่วิ่งลงไปบรรจบกันที่ปลาย มุมคำนวณจากสัดส่วนจริงของปลาย ไม่ได้เดา
		-- **มุมวัดจากแกนตั้ง ไม่ใช่จากแกนนอน** (`atan2(half, POINT)` ไม่ใช่ `atan2(POINT, half)`)
		-- แท่งขอบมีความยาวอยู่บนแกน Y ของมันเอง การเอียงจึงคือมุมระหว่างขอบกับแนวตั้ง — สลับสองค่านี้
		-- แล้วขอบทองจะสั้นกว่าปลายเหล็กในแนวดิ่งและยื่นเกินออกด้านข้าง (เห็นเป็นปลายเหล็กโผล่ใต้กรอบ)
		local angle = math.atan2(half, POINT)
		local runLen = math.sqrt(POINT * POINT + half * half)
		box(b, "RimPoint", CFrame.new(sx * half / 2, ptY, 0) * roll(-sx * angle),
			Vector3.new(RIM, runLen + 0.14, T + 0.08), GOLD, Enum.Material.Metal)
	end

	-- แถบเหล็กกลางตั้งและแถบขวาง เหมือนในภาพ
	-- ความสูงกับจุดกึ่งกลางคิดจากขอบบนจริง ไม่ได้ตั้งลอยๆ — รอบแรกแถบโผล่พ้นขอบทองด้านบนเป็นติ่ง
	local spineTop, spineBottom = H / 2 - 0.02, -H / 2 - POINT * 0.45
	box(b, "SpineBand", CFrame.new(0, (spineTop + spineBottom) / 2, -0.04),
		Vector3.new(0.34, spineTop - spineBottom, T + 0.06), DARK_STEEL, Enum.Material.Metal)
	box(b, "CrossBand", CFrame.new(0, -0.05, -0.04), Vector3.new(W - 0.20, 0.26, T + 0.05), DARK_STEEL, Enum.Material.Metal)

	-- เฟืองสามตัวบนหน้าโล่ · `gear`/`disc` หันหน้าตามแกน X ของเฟรม จึง yaw 90 ให้หันออกหน้าโล่ (-Z)
	--
	-- **หลัง `FACE` แล้ว local +X ของเฟรมคือ -Z ของโลก = ด้านหน้าโล่** ค่าบวกใน CFrame.new ตัวแรกจึงแปลว่า
	-- "ขยับออกมาข้างหน้า" — รอบแรกผมใส่ค่าลบ หน้าปัดกับเข็มเลยไปซ่อนอยู่หลังขอบทองจนเหลือแต่วงกลมทึบ
	local FACE = yaw(deg(90))
	gear(b, "GearBig", CFrame.new(0.54, 0.38, -T / 2 - 0.02) * FACE, 0.46, 11, 0.08, GOLD)
	gear(b, "GearSmall", CFrame.new(-0.52, -0.44, -T / 2 - 0.02) * FACE, 0.34, 9, 0.08, GOLD)
	gear(b, "GearTiny", CFrame.new(0.50, -0.52, -T / 2 - 0.02) * FACE, 0.24, 7, 0.07, COPPER)

	-- หน้าปัดแรงดัน: ขอบทองเหลือง หน้าปัดขาว เข็มหนึ่งอัน
	local gaugeAt = CFrame.new(-0.52, 0.46, -T / 2 - 0.04) * FACE
	disc(b, "GaugeRim", gaugeAt, 0.30, 0.10, GOLD, Enum.Material.Metal)
	disc(b, "GaugeFace", gaugeAt * CFrame.new(0.06, 0, 0), 0.23, 0.04, PAGES, Enum.Material.SmoothPlastic)
	box(b, "GaugeNeedle", gaugeAt * CFrame.new(0.09, 0.07, 0.01) * pitch(deg(35)),
		Vector3.new(0.03, 0.18, 0.035), RUBY, Enum.Material.Neon)
	ball(b, "GaugePin", gaugeAt * CFrame.new(0.10, 0, 0), 0.07, GOLD_DARK, Enum.Material.Metal)

	-- โล่กลางรูปหยดน้ำเล็ก (escutcheon) ทองแดง + กุญแจมีมงกุฎ ตามภาพ
	box(b, "Boss", CFrame.new(0, -0.02, -T / 2 - 0.08), Vector3.new(0.76, 0.86, 0.16), COPPER, Enum.Material.Metal)
	box(b, "BossRim", CFrame.new(0, -0.02, -T / 2 - 0.07), Vector3.new(0.86, 0.94, 0.12), GOLD_DARK, Enum.Material.Metal)
	-- โล่เล็กตรงกลางมีปลายแหลมของตัวเองเหมือนในภาพ ไม่ใช่สี่เหลี่ยมตัด — ลิ่มคู่เดียวกับปลายใบใหญ่
	for _, sx in ipairs({ -1, 1 }) do
		wedge(b, "BossPoint", CFrame.new(sx * 0.19, -0.62, -T / 2 - 0.08) * yaw(deg(-90 * sx)),
			Vector3.new(0.16, 0.34, 0.38), COPPER, Enum.Material.Metal)
		wedge(b, "BossPointRim", CFrame.new(sx * 0.215, -0.64, -T / 2 - 0.07) * yaw(deg(-90 * sx)),
			Vector3.new(0.12, 0.38, 0.43), GOLD_DARK, Enum.Material.Metal)
	end
	box(b, "Crown", CFrame.new(0, 0.38, -T / 2 - 0.17), Vector3.new(0.36, 0.09, 0.06), GOLD, Enum.Material.Metal)
	for i = -1, 1 do
		box(b, "CrownSpike", CFrame.new(i * 0.13, 0.45, -T / 2 - 0.17), Vector3.new(0.07, 0.11, 0.06), GOLD, Enum.Material.Metal)
	end
	box(b, "KeyShaft", CFrame.new(0, -0.14, -T / 2 - 0.18), Vector3.new(0.08, 0.52, 0.06), GOLD, Enum.Material.Metal)
	disc(b, "KeyBow", CFrame.new(0, 0.18, -T / 2 - 0.18) * FACE, 0.13, 0.06, GOLD, Enum.Material.Metal)
	disc(b, "KeyBowHole", CFrame.new(0, 0.18, -T / 2 - 0.22) * FACE, 0.06, 0.04, COPPER_DARK, Enum.Material.Metal)
	box(b, "KeyBit", CFrame.new(0.09, -0.36, -T / 2 - 0.18), Vector3.new(0.12, 0.09, 0.06), GOLD, Enum.Material.Metal)
	box(b, "KeyBit2", CFrame.new(0.08, -0.22, -T / 2 - 0.18), Vector3.new(0.09, 0.08, 0.06), GOLD, Enum.Material.Metal)

	-- อัญมณีมุมบนและกลางยอด สลับแดง-เขียวเหมือนภาพ
	ball(b, "GemTop", CFrame.new(0, H / 2 + 0.02, -T / 2 - 0.02), 0.20, RUBY, Enum.Material.Neon)
	for _, sx in ipairs({ -1, 1 }) do
		ball(b, "GemUpper", CFrame.new(sx * (half - 0.10), H / 2 - 0.30, -T / 2 - 0.02), 0.17,
			sx < 0 and RUBY or GEM, Enum.Material.Neon)
		ball(b, "GemLower", CFrame.new(sx * (half - 0.12), -0.62, -T / 2 - 0.02), 0.15,
			sx < 0 and GEM or RUBY, Enum.Material.Neon)
	end
	ball(b, "GemPoint", CFrame.new(0, ptY - POINT / 2 + 0.16, -T / 2 - 0.02), 0.17, GEM, Enum.Material.Neon)

	-- หมุดรอบขอบ — ระยะห่างคงที่ ไม่ใช่สุ่ม ของที่ตีด้วยมือยังเรียงเป็นระเบียบ
	for i = -2, 2 do
		ball(b, "RivetTop", CFrame.new(i * 0.42, H / 2 - 0.02, -T / 2 - 0.06), 0.09, GOLD_DARK, Enum.Material.Metal)
		for _, sx in ipairs({ -1, 1 }) do
			ball(b, "RivetSide", CFrame.new(sx * (half - 0.02), i * 0.42, -T / 2 - 0.06), 0.09, GOLD_DARK, Enum.Material.Metal)
		end
	end

	-- ด้านหลัง: สายรัดแขนสองเส้นกับคานจับ — ส่วนนี้ไม่ได้อยู่ในภาพ (ภาพเห็นแต่ด้านหน้า) แต่ถ้าไม่มี
	-- โล่จะดูเหมือนแผ่นป้ายที่ลอยติดแขนอยู่เฉยๆ
	box(b, "StrapUpper", CFrame.new(0, 0.34, T / 2 + 0.10), Vector3.new(1.10, 0.20, 0.10), LEATHER)
	box(b, "StrapLower", CFrame.new(0, -0.30, T / 2 + 0.10), Vector3.new(1.10, 0.20, 0.10), LEATHER)
	box(b, "GripBar", CFrame.new(0.42, 0.02, T / 2 + 0.18), Vector3.new(0.12, 0.70, 0.12), DARK_WOOD)

	return assembleBag("Shield", plate, b)
end

--------------------------------------------------------------------------------

-- Rebuilt on every server start rather than trusted to survive in the place file: that is exactly how the
-- originals were lost. Cheap enough (four models of five parts) that there is no reason to cache them.
local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
if existing then existing:Destroy() end

local folder = Instance.new("Folder")
folder.Name = FOLDER_NAME

for name, build in pairs(Builders) do
	local ok, model = pcall(build)
	if ok and model then
		model.Parent = folder
	else
		warn(("[WeaponPrefabs] failed to build %s: %s"):format(name, tostring(model)))
	end
end

folder.Parent = ReplicatedStorage
