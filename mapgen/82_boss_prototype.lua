-- 82_boss_prototype.lua: ปั้นต้นแบบบอส `Boss_Forgewarden` เข้า `ServerStorage.Model_moster`
--
-- **ต้นฉบับอยู่ที่โรงงาน** `C:\Users\watch\WOLD-Models/models/boss.lua` — แก้รูปทรงที่นั่น ดูภาพที่นั่น
-- แล้วคัดลอกกลับมาที่นี่ (กติกาเดียวกับ `weapon_base.lua` → `WeaponPrefabs.server.lua`)
--
-- รัน: `node tools/run-luau.js mapgen/82_boss_prototype.lua --kit`
-- รันซ้ำได้เสมอ ของเก่าถูกลบก่อน · `Mobs.server` โคลนต้นแบบนี้ตอนบอสเกิด (`prototypeFor` หาใน
-- ServerStorage ก่อนเสมอ) แล้ว `ScaleTo` ตามที่ระบบบอสสั่ง
--
-- **ไม่แตะแมพเลยสักชิ้น** เขียนลง ServerStorage อย่างเดียว
local ServerStorage = game:GetService("ServerStorage")

-- โรงงานมี `K.stint` มาจาก stone.lua ซึ่งเกมไม่ได้พอร์ตมา — ชุดเกราะเรียกมันเฉพาะตอนใส่ `wear`
-- ซึ่งบอสตัวนี้ไม่ได้ใส่ แต่กันไว้ไม่ให้พังถ้าวันหลังมีคนเปิดใช้
K.stint = K.stint or function(rng, color, amount)
	local d = (rng:NextNumber() - 0.5) * (amount or 0.2)
	return color:Lerp(d > 0 and Color3.new(1, 1, 1) or Color3.new(0, 0, 0), math.abs(d))
end

-- ตัวสร้างของโรงงานเรียก `K.build(ชื่อ, nil, fn)` ซึ่งวางของลงกริดโชว์ในเพลสโรงงาน
-- ที่นี่ไม่มีกริดนั้น จึงดักไว้ให้สร้างเป็น Model เปล่าๆ แล้วส่งเข้า ServerStorage แทน
local built = nil
local realBuild = K.build
K.build = function(name, _, fn)
	local m = Instance.new("Model")
	m.Name = name
	fn(m)
	built = m
	return m
end

local C, MAT = K.C, K.MAT
local rgb = Color3.fromRGB

local IRON = rgb(64, 68, 80)
local IRON_DARK = rgb(38, 40, 48)
local BRASS = rgb(178, 138, 66)
local BRASS_DIM = rgb(122, 94, 46)
local EMBER = rgb(255, 122, 34)
local EMBER_DEEP = rgb(214, 72, 18)
local CLOTH = rgb(78, 28, 32)
local CLOTH_DARK = rgb(50, 18, 22)

-- เขาโค้ง: ท่อนสั้นต่อกันแล้วหมุนทีละนิด — โค้งจริงด้วยชิ้นตรงหลายชิ้น ไม่ใช่กล่องเอียงชิ้นเดียว
local function horn(g, cf, segs, len, r0, curve)
	local at = cf
	for i = 1, segs do
		local t = (i - 1) / segs
		K.cyl(g, at * CFrame.new(0, len / 2, 0), r0 * (1 - t * 0.72), len, MAT.Metal,
			BRASS:Lerp(IRON_DARK, t * 0.5), { name = "Horn", cancollide = false })
		at = at * CFrame.new(0, len * 0.9, 0) * K.pitch(curve) * K.roll(curve * 0.3)
	end
	K.cyl(g, at, r0 * 0.2, len * 0.45, MAT.Neon, EMBER, { name = "HornTip", cancollide = false })
end

-- ไอ/ควัน — ตัวเดียวอ่านว่า "เครื่องยนต์ยังเดินอยู่" ดีกว่าพาร์ทสิบชิ้น
local function steam(parent, size, rate, color)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color or rgb(205, 205, 210))
	e.Size = NumberSequence.new(size or 1.2)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(1.0, 1.9)
	e.Rate = rate or 5
	e.Speed = NumberRange.new(1.6, 3.2)
	e.VelocitySpread = 14
	e.LightEmission = 0.25
	e.Parent = parent
	return e
end

K.build("Boss_Forgewarden", nil, function(m)
	R.new(m, {
		skin = IRON_DARK, shirt = IRON_DARK, pants = IRON_DARK, face = false,
		health = 15000, walkSpeed = 12,
		-- **ตัวเองต้องผอม** ความหนามาจากเกราะ ถ้าตัวหนาด้วยเกราะหนาด้วยจะได้ถังที่มีหมวก (รอบสองเป็นแบบนั้น)
		width = 1.1, height = 1.1, depth = 1.0, head = 1.05, proportion = 1,
	})
	R.paint(m, R.LIMBS, IRON_DARK, MAT.Metal)

	-- เกราะเหล็กหนักทั้งชุด คิดขนาดจากข้อต่อจริง · `bulk` คือความหนาส่วนเกินของบอส (คู่มือแนะ 0.1–0.2)
	R.armor(m, "plate", {
		bulk = 0.1,
		seed = 41,
		-- **ไม่เอากระโปรงเหล็กของชุดปกติ** (LowerTorso) — มันกว้างเท่าไหล่และยาวคลุมต้นขา พอรวมกับผ้าคลุม
		-- แล้วช่วงเอวถึงพื้นกลายเป็นก้อนทึบก้อนเดียว เงาจึงอ่านเป็น "ถังมีหมวก" ไม่ใช่ "คนสวมเกราะ"
		-- เอวของบอสทำเองข้างล่าง: เข็มขัดแคบ + แผ่นข้างสองแผ่น เปิดกลางไว้ให้เห็นขา
		skip = { LowerTorso = true },
		steam = true,          -- ไอพ่นจากปล่องหลัง
		plume = false,         -- ไม่เอาขนนก บอสใช้เขาแทน
		colors = {
			plate = IRON, base = IRON, dark = IRON_DARK, trim = BRASS,
			glow = EMBER, cloth = CLOTH, strap = rgb(48, 32, 24),
		},
	})

	local head = R.limb(m, "Head")
	local torso = R.limb(m, "UpperTorso")
	local hand = R.limb(m, "RightHand")

	----------------------------------------------------------------------------
	-- หมวก: เขาคู่ + ช่องมองที่สว่างกว่าเกราะปกติ (บอสต้องอ่านออกจากระยะไกล)
	----------------------------------------------------------------------------
	R.armorAttach(m, "Head", function(g, H)
		local s = head.Size
		for _, sx in ipairs({ -1, 1 }) do
			horn(g, H * CFrame.new(sx * s.X * 0.42, s.Y * 0.36, s.Z * 0.05)
				* K.roll(sx * 0.5) * K.pitch(-0.3), 5, s.Y * 0.30, s.X * 0.17, 0.24)
		end
		-- แถบไฟช่องมอง: กว้างกว่าของเกราะปกติและมีไฟส่องออกมาจริง
		local slit = K.box(g, H * CFrame.new(0, s.Y * 0.02, -s.Z * 0.56),
			Vector3.new(s.X * 0.78, s.Y * 0.1, s.Z * 0.1), MAT.Neon, EMBER, { name = "VisorGlow", cancollide = false })
		local l = Instance.new("PointLight")
		l.Color = EMBER; l.Range = 18; l.Brightness = 2.4; l.Parent = slit
		-- เขี้ยวตะแกรงใต้ช่องมอง ทำให้หน้าไม่ใช่แผ่นเรียบ
		for i = -1, 1 do
			K.box(g, H * CFrame.new(i * s.X * 0.16, -s.Y * 0.24, -s.Z * 0.52),
				Vector3.new(s.X * 0.07, s.Y * 0.16, s.Z * 0.08), MAT.Metal, BRASS_DIM, { name = "Fang", cancollide = false })
		end
	end, "BossHelm")

	----------------------------------------------------------------------------
	-- บ่า: หนามสามซี่ต่อข้าง — เงาไหล่คือสิ่งที่บอกว่า "ตัวนี้ใหญ่"
	----------------------------------------------------------------------------
	for _, side in ipairs({ { "Left", -1 }, { "Right", 1 } }) do
		local name, sx = side[1], side[2]
		local arm = R.limb(m, name .. "UpperArm")
		R.armorAttach(m, name .. "UpperArm", function(g, A)
			local s = arm.Size
			for i = -1, 1 do
				K.wedge(g, A * CFrame.new(sx * s.X * 0.5 + i * s.X * 0.42, s.Y * 0.62, i * s.Z * 0.2)
					* K.pitch(-math.pi / 2) * K.yaw(0.18 * i),
					Vector3.new(s.X * 0.28, s.Y * (0.62 - math.abs(i) * 0.18), s.Z * 0.55),
					MAT.Metal, BRASS_DIM, { name = "Spike", cancollide = false })
			end
			K.chain(g, (A * CFrame.new(sx * s.X * 0.9, s.Y * 0.35, -s.Z * 0.3)).Position,
				(A * CFrame.new(sx * s.X * 0.55, -s.Y * 0.45, -s.Z * 0.45)).Position, 5, s.X * 0.06, BRASS_DIM)
		end, name .. "BossSpikes")
	end

	----------------------------------------------------------------------------
	-- อก: ประตูเตาที่ใหญ่และสว่างกว่า "แกนไอน้ำ" ของเกราะปกติ + ไอร้อนพ่นออกมา
	----------------------------------------------------------------------------
	R.armorAttach(m, "UpperTorso", function(g, T)
		local s = torso.Size
		local doorCF = T * CFrame.new(0, s.Y * 0.04, -s.Z * 0.88)
		K.cylX(g, doorCF * K.yaw(math.pi / 2), s.X * 0.3, s.Z * 0.12, MAT.Metal, BRASS, { name = "FurnaceRim", cancollide = false })
		local glow = K.cylX(g, doorCF * CFrame.new(0, 0, -s.Z * 0.06) * K.yaw(math.pi / 2),
			s.X * 0.24, s.Z * 0.08, MAT.Neon, EMBER_DEEP, { name = "FurnaceGlow", cancollide = false })
		for i = -2, 2 do -- ซี่ตะแกรงหน้าไฟ ทำให้ไฟอยู่ "ข้างใน" ไม่ใช่แปะบนอก
			K.box(g, doorCF * CFrame.new(i * s.X * 0.09, 0, -s.Z * 0.09),
				Vector3.new(s.X * 0.035, s.Y * 0.36, s.Z * 0.05), MAT.Metal, IRON_DARK, { name = "Bar", cancollide = false })
		end
		K.rivetRing(g, doorCF * CFrame.new(0, 0, s.Z * 0.02), s.X * 0.28, 10, s.X * 0.035, BRASS_DIM)
		local l = Instance.new("PointLight")
		l.Color = EMBER; l.Range = 34; l.Brightness = 3; l.Parent = glow
		steam(glow, s.X * 0.9, 4, rgb(255, 150, 80))

		-- **ผ้าคลุม** — เงาร่างแบบโซลไลก์มาจากผ้ายาวที่ไหล่ ไม่ใช่จากตัวที่อ้วนขึ้น
		-- **ผ้าอยู่ข้างหลัง ไม่ใช่รอบตัว** รอบที่แล้วมันห่อขาจนบอสกลายเป็นถัง — ขาที่มองเห็นคือสิ่งที่บอกว่า
		-- นี่คือคนสวมเกราะ ไม่ใช่ตู้เหล็ก · ผ้าจึงถอยไป z ไกลขึ้นและสั้นลงหนึ่งช่วง
		-- **ชายผ้าต้องไม่ต่ำกว่าฝ่าเท้า** — วัดแล้วรอบก่อนผ้าห้อยต่ำกว่าพื้นรองเท้า 0.37 studs ทำให้กล่องขอบ
		-- ของโมเดลเริ่มที่ชายผ้า ไม่ใช่ที่เท้า · ผลคือเวลาวางลงพื้นจริงผ้าจะจมดินและตัวจะลอย และในภาพถ่าย
		-- ขาจะหายไปในเงาผ้าทั้งสองข้าง (นี่คือสาเหตุที่บอสดูเป็นถังไม่มีขามาสามรอบ)
		-- ผืนกลางถูกถอดออก: มันห้อยระหว่างขาพอดีและปิดช่องว่างที่ทำให้เห็นว่ามีสองขา
		-- เหลือสองผืนที่ห้อยหลังไหล่แต่ละข้าง ซึ่งให้ความ "ยาว" โดยไม่กลืนขา
		-- **ชายผ้าต้องจบเหนือเข่า** วัดแล้วรอบก่อนผ้าลงมาถึง y1.1 ขณะที่ขาเริ่มที่ y0.2 — ผ้ากว้าง 5.4
		-- บังขากว้าง 2.7 ที่เป็นสีเดียวกันสนิท ขาจึงหายไปในเงาผ้าทุกมุม (นี่คือต้นเหตุจริงของ "บอสไม่มีขา")
		for i, panel in ipairs({
			{ x = -0.62, w = 0.72, len = 1.25, tilt = 0.06 },
			{ x = 0.62, w = 0.72, len = 1.25, tilt = 0.06 },
			{ x = -0.98, w = 0.4, len = 0.95, tilt = 0.14 },
			{ x = 0.98, w = 0.4, len = 0.95, tilt = 0.14 },
		}) do
			local col = i <= 2 and CLOTH or CLOTH_DARK
			local w, len = s.X * panel.w, s.Y * panel.len
			K.box(g, T * CFrame.new(s.X * panel.x, s.Y * 0.4 - len / 2, s.Z * 0.95) * K.pitch(panel.tilt),
				Vector3.new(w, len, s.Z * 0.09), MAT.Fabric, col, { name = "Cape", cancollide = false })
			K.wedge(g, T * CFrame.new(s.X * panel.x, s.Y * 0.4 - len, s.Z * 0.95) * K.pitch(math.pi / 2 + panel.tilt),
				Vector3.new(s.Z * 0.09, s.Y * 0.4, w), MAT.Fabric, col, { name = "CapeTorn", cancollide = false })
		end
		K.box(g, T * CFrame.new(0, s.Y * 0.42, 0) * K.pitch(0.08),
			Vector3.new(s.X * 1.22, s.Y * 0.14, s.Z * 1.3), MAT.Leather, rgb(48, 32, 24), { name = "CapeStrap", cancollide = false })
	end, "BossFurnace")

	----------------------------------------------------------------------------
	-- เอว: แคบและเปิดกลาง — ช่วงที่แคบระหว่างไหล่กว้างกับขาคือสิ่งที่ทำให้เงาอ่านออกว่าเป็นคน
	----------------------------------------------------------------------------
	local waist = R.limb(m, "LowerTorso")
	R.armorAttach(m, "LowerTorso", function(g, L)
		local s = waist.Size
		K.box(g, L * CFrame.new(0, s.Y * 0.05, 0), Vector3.new(s.X * 1.06, s.Y * 0.72, s.Z * 1.12),
			MAT.Metal, IRON, { name = "WaistPlate", cancollide = false })
		K.box(g, L * CFrame.new(0, -s.Y * 0.3, 0), Vector3.new(s.X * 1.12, s.Y * 0.26, s.Z * 1.18),
			MAT.Leather, rgb(46, 30, 24), { name = "Belt", cancollide = false })
		K.box(g, L * CFrame.new(0, -s.Y * 0.3, -s.Z * 0.62), Vector3.new(s.X * 0.36, s.Y * 0.36, s.Z * 0.16),
			MAT.Metal, BRASS, { name = "Buckle", cancollide = false })
		K.cylX(g, L * CFrame.new(0, -s.Y * 0.3, -s.Z * 0.7) * K.yaw(math.pi / 2), s.X * 0.08, s.Z * 0.1,
			MAT.Neon, EMBER, { name = "BuckleEye", cancollide = false })
		-- แผ่นข้างสะโพกสองแผ่น ห้อยแค่ข้างลำตัว ไม่ปิดหน้าขา
		for _, sx in ipairs({ -1, 1 }) do
			K.box(g, L * CFrame.new(sx * s.X * 0.56, -s.Y * 0.62, -s.Z * 0.1) * K.roll(sx * 0.08),
				Vector3.new(s.X * 0.3, s.Y * 0.9, s.Z * 0.8), MAT.Metal, IRON_DARK, { name = "Tasset", cancollide = false })
			K.box(g, L * CFrame.new(sx * s.X * 0.56, -s.Y * 1.02, -s.Z * 0.1),
				Vector3.new(s.X * 0.32, s.Y * 0.1, s.Z * 0.84), MAT.Metal, BRASS_DIM, { name = "TassetTrim", cancollide = false })
		end
	end, "BossWaist")

	----------------------------------------------------------------------------
	-- ดาบใหญ่: ยาวกว่าตัว ตั้งพาดบ่า ใบมีร่องไฟ
	----------------------------------------------------------------------------
	R.armorAttach(m, "RightHand", function(g, HD)
		local s = hand.Size
		local U = s.X                               -- หน่วยวัดของดาบ = ความกว้างมือ ดาบจึงโตตามตัวเสมอ
		-- ด้ามชี้ลง-หลัง ใบชี้ขึ้น-หลัง = ท่าพาดบ่าแบบบอสโซลไลก์
		-- **มุมของดาบวัดจากภาพ ไม่ใช่จากการเดา**: ที่ pitch 0 ใบชี้ขึ้นตามแกน +Y ของมือ · ยิ่งลบยิ่งคว่ำไปข้างหน้า
		-- (รอบแรก -62 ได้ดาบนอนขวางหน้า รอบสอง -108 ได้ดาบปักดิน) · บวกนิดเดียวคือท่าพาดบ่าที่ต้องการ
		-- เยื้องออกข้างลำตัวด้วย roll: ดาบที่ตั้งกลางตัวพอดีจะบังหัวและอกในมุมหน้า ซึ่งเป็นมุมที่คนเล่นเห็นบ่อยสุด
		-- ยกดาบขึ้นตามแกนของมันเอง ไม่งั้นหัวด้ามห้อยต่ำกว่าฝ่าเท้า (วัดแล้วเกินไป 0.58 studs)
		-- ปลายด้ามที่จิ้มดินคือสิ่งที่ทำให้บอสยืนลอยตอนวางลงพื้นจริง
		local base = HD * CFrame.new(U * 0.2, -U * 0.15, -U * 0.3)
			* K.pitch(math.rad(14)) * K.roll(math.rad(-16)) * K.yaw(math.rad(8))
			* CFrame.new(0, U * 0.85, 0)

		K.cyl(g, base * CFrame.new(0, -U * 1.1, 0), U * 0.2, U * 2.6, MAT.Leather, rgb(44, 30, 26), { name = "Grip", cancollide = false })
		for i = 0, 5 do
			K.cyl(g, base * CFrame.new(0, -U * (2.2 - i * 0.42), 0), U * 0.23, U * 0.14, MAT.Leather, rgb(28, 18, 16), { name = "Wrap", cancollide = false })
		end
		K.ball(g, base * CFrame.new(0, -U * 2.5, 0), U * 0.55, MAT.Metal, BRASS, { name = "Pommel", cancollide = false })
		K.cylX(g, base * CFrame.new(0, -U * 2.5, 0) * K.yaw(math.pi / 2), U * 0.22, U * 0.6, MAT.Neon, EMBER, { name = "PommelGem", cancollide = false })

		K.box(g, base * CFrame.new(0, U * 0.35, 0), Vector3.new(U * 3.4, U * 0.36, U * 0.55), MAT.Metal, IRON, { name = "Crossguard", cancollide = false })
		K.box(g, base * CFrame.new(0, U * 0.35, 0), Vector3.new(U * 3.6, U * 0.16, U * 0.3), MAT.Metal, BRASS, { name = "GuardTrim", cancollide = false })
		for _, gx in ipairs({ -1.6, 1.6 }) do
			K.wedge(g, base * CFrame.new(U * gx, U * 0.35, 0) * K.roll(gx > 0 and -math.pi / 2 or math.pi / 2),
				Vector3.new(U * 0.55, U * 0.55, U * 0.4), MAT.Metal, IRON_DARK, { name = "GuardTip", cancollide = false })
		end
		K.gear(g, base * CFrame.new(0, U * 0.72, 0) * K.yaw(math.pi / 2), U * 0.45, 10, U * 0.22, BRASS_DIM)

		K.box(g, base * CFrame.new(0, U * 1.05, 0), Vector3.new(U * 0.7, U * 0.9, U * 0.4), MAT.Metal, IRON_DARK, { name = "Ricasso", cancollide = false })
		K.box(g, base * CFrame.new(0, U * 2.8, 0), Vector3.new(U * 1.2, U * 3.0, U * 0.34), MAT.Metal, rgb(152, 156, 168), { name = "Blade", cancollide = false })
		K.box(g, base * CFrame.new(0, U * 5.1, 0), Vector3.new(U * 0.95, U * 1.7, U * 0.3), MAT.Metal, rgb(164, 168, 180), { name = "BladeUpper", cancollide = false })
		K.box(g, base * CFrame.new(0, U * 3.0, 0), Vector3.new(U * 0.32, U * 4.3, U * 0.38), MAT.Neon, EMBER_DEEP, { name = "Fuller", cancollide = false })
		for i = 0, 3 do
			K.box(g, base * CFrame.new(0, U * (2.0 + i * 1.15), 0), Vector3.new(U * 0.52, U * 0.34, U * 0.44),
				MAT.Neon, EMBER, { name = "Vent", cancollide = false })
		end
		-- ปลายดาบ: ลิ่มสองชิ้นประกบตามผังของโรงงาน (ดู CLAUDE.md เรื่อง WedgePart)
		for _, hx in ipairs({ -1, 1 }) do
			K.wedge(g, base * CFrame.new(hx * U * 0.25, U * 6.45, 0) * K.pitch(-math.pi / 2)
				* (hx > 0 and K.roll(math.pi) or CFrame.new()),
				Vector3.new(U * 0.3, U * 1.5, U * 0.5), MAT.Metal, rgb(174, 178, 190), { name = "Tip", cancollide = false })
		end
		local hot = K.box(g, base * CFrame.new(0, U * 4.6, 0), Vector3.new(U * 0.36, U * 0.22, U * 0.42),
			MAT.Neon, rgb(255, 202, 122), { name = "HeatCore", cancollide = false })
		local bl = Instance.new("PointLight")
		bl.Color = EMBER; bl.Range = 22; bl.Brightness = 1.8; bl.Parent = hot
		steam(hot, U * 1.1, 3, rgb(255, 168, 108))
	end, "Greatsword")

	----------------------------------------------------------------------------
	-- **ขาต้องสว่างกว่าตัว** ไม่ใช่เพราะสวย แต่เพราะขาสีเดียวกับผ้าคลุมและเกราะอกคือขาที่มองไม่เห็น
	-- เกราะจริงก็เป็นแบบนี้: ชิ้นที่ถูกขัดบ่อย (แข้ง เข่า รองเท้า) สว่างกว่าชิ้นที่อยู่ใต้ผ้าคลุม
	----------------------------------------------------------------------------
	local LEG_STEEL = rgb(128, 134, 148)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			local n = d.Name
			if n:find("Greave") or n:find("Cuisse") or n:find("Sabaton") or n:find("Poleyn") or n:find("Knee") then
				if d.Material ~= MAT.Neon then
					d.Color = n:find("Trim") and BRASS or LEG_STEEL
				end
			end
		end
	end
	for _, side in ipairs({ "Left", "Right" }) do
		local limb = R.limb(m, side .. "LowerLeg")
		if limb then
			R.armorAttach(m, side .. "LowerLeg", function(g, L)
				local s = limb.Size
				K.cylX(g, L * CFrame.new(0, s.Y * 0.12, 0) * K.yaw(math.pi / 2), s.X * 0.62, s.Z * 1.24,
					MAT.Metal, BRASS_DIM, { name = "GreaveBand", cancollide = false })
			end, side .. "LegBand")
		end
	end

	-- ไม่ใส่ `R.controller` กับป้ายชื่อของโรงงาน: ในเกม `Mobs.server` เป็นคนขับตัวนี้และติดหลอดเลือด/ชื่อเอง
	-- ถ้าติดมาด้วยจะได้บอสที่เดินสุ่มเองแข่งกับ AI ของเกม และมีป้ายชื่อซ้อนกันสองอัน
	K.attrs(m, {
		Boss = true, Damage = 85, AttackRange = 14, AggroRange = 90, Faction = "construct", Tier = 9,
	})
end)


K.build = realBuild

--------------------------------------------------------------------------------
-- **แปลงข้อต่อเป็น Motor6D ก่อนส่งเข้าเกม**
--
-- `CreateHumanoidModelFromDescription` รุ่นใหม่คืนโครงที่ข้อต่อเป็น `AnimationConstraint` + `BallSocketConstraint`
-- ไม่ใช่ `Motor6D` (นับได้ 15 + 14 ตัว ไม่มี Motor6D เลยสักตัว) — แต่ `Mobs.rigR15` ของเกมมองหา Motor6D
-- ถ้าไม่เจอมันจะ **สร้างเองแล้วลบ weld ทุกตัวที่แตะชิ้นนั้น** ซึ่งคือ weld ที่ยึดเกราะทั้งชุดไว้กับแขนขา
-- ผลคือบอสจะโผล่มาในเกมโดยเกราะ ดาบ ผ้าคลุม ร่วงกองอยู่กับพื้น
--
-- ทำให้เสร็จตรงนี้ทีเดียว: ต้นแบบมี Motor6D มาแล้ว `rigR15` จึงข้ามไปเฉยๆ (มันเช็ก `FindFirstChildWhichIsA`)
-- และ weld ของเกราะรอด
--------------------------------------------------------------------------------

local R15_JOINTS = {
	{ "LowerTorso", "HumanoidRootPart", "Root" },
	{ "UpperTorso", "LowerTorso", "Waist" },
	{ "Head", "UpperTorso", "Neck" },
	{ "LeftUpperArm", "UpperTorso", "LeftShoulder" },
	{ "LeftLowerArm", "LeftUpperArm", "LeftElbow" },
	{ "LeftHand", "LeftLowerArm", "LeftWrist" },
	{ "RightUpperArm", "UpperTorso", "RightShoulder" },
	{ "RightLowerArm", "RightUpperArm", "RightElbow" },
	{ "RightHand", "RightLowerArm", "RightWrist" },
	{ "LeftUpperLeg", "LowerTorso", "LeftHip" },
	{ "LeftLowerLeg", "LeftUpperLeg", "LeftKnee" },
	{ "LeftFoot", "LeftLowerLeg", "LeftAnkle" },
	{ "RightUpperLeg", "LowerTorso", "RightHip" },
	{ "RightLowerLeg", "RightUpperLeg", "RightKnee" },
	{ "RightFoot", "RightLowerLeg", "RightAnkle" },
}

local function partNamed(model, name)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == name then return d end
	end
	return nil
end

local function toMotor6D(model)
	-- ข้อต่อแบบ constraint ต้องออกก่อน ไม่งั้นสองระบบขับชิ้นเดียวกันแล้วตัวสั่น
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("AnimationConstraint") or d:IsA("BallSocketConstraint") then d:Destroy() end
	end
	local made = 0
	for _, joint in ipairs(R15_JOINTS) do
		local part, parent = partNamed(model, joint[1]), partNamed(model, joint[2])
		if part and parent and not part:FindFirstChildWhichIsA("Motor6D") then
			local motor = Instance.new("Motor6D")
			motor.Name = joint[3]
			motor.Part0 = parent
			motor.Part1 = part
			-- C0 จากตำแหน่งที่ชิ้นส่วนอยู่จริงตอนนี้ ท่าที่ปั้นไว้จึงไม่ถูกดีดกลับเป็นท่ามาตรฐาน
			motor.C0 = parent.CFrame:ToObjectSpace(part.CFrame)
			motor.C1 = CFrame.new()
			-- **แขวนไว้ที่ Part1 (ชิ้นลูก) ตามมาตรฐาน R15 ของ Roblox** ไม่ใช่ที่ Part0
			--
			-- รอบแรกแขวนไว้ที่ Part0 แล้วเจอว่า `Mobs.rigR15` ถามว่า "ชิ้นนี้มี Motor6D เป็นลูกไหม"
			-- ชิ้นปลายทาง (Head / มือ / เท้า) จึงดูเหมือนยังไม่มีข้อต่อ → เกมสร้างข้อต่อซ้ำทับ (ร่างแตกเป็น
			-- สองก้อนซ้อนกัน ก้อนหนึ่งนิ่ง) และลบ weld ของเกราะ/ดาบที่ชิ้นนั้นทิ้ง (ดาบไม่แกว่งตามแขน)
			-- ฝั่งเกมแก้ให้ถามจาก Part1 แล้ว ตรงนี้แก้ให้ตรงมาตรฐานด้วย จะได้ไม่ต้องพึ่งกันสองทาง
			motor.Parent = part
			made += 1
		end
	end
	return made
end

local madeJoints = toMotor6D(built)

-- `Animate` เป็น LocalScript ที่ติดมากับ rig — ในโมเดลฝั่งเซิร์ฟเวอร์มันไม่มีวันรัน และ `Mobs` เล่นอนิเมชันเอง
for _, d in ipairs(built:GetDescendants()) do
	if d:IsA("LocalScript") or d:IsA("Script") then d:Destroy() end
end

local folder = ServerStorage:FindFirstChild("Model_moster")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Model_moster"
	folder.Parent = ServerStorage
end
local old = folder:FindFirstChild("Boss_Forgewarden")
if old then old:Destroy() end

-- ต้นแบบต้องมี `Root` ที่ `Mobs.buildFromModel` เอาไปเป็น HumanoidRootPart ไม่ได้ — rig มีของจริงอยู่แล้ว
-- (`HumanoidRootPart`) จึงปล่อยไว้ตามนั้น แค่ตั้ง PrimaryPart ให้ถูกตัว
built.PrimaryPart = built:FindFirstChild("HumanoidRootPart") or built.PrimaryPart
built.Parent = folder

local _, size = built:GetBoundingBox()
local root = workspace:FindFirstChild("WOLD") or Instance.new("Folder")
root.Name = "WOLD"
root.Parent = workspace
-- สเกลตอนเกิดจริงอ่านจากคอนฟิกของเกม ไม่ใช่เลขที่พิมพ์ไว้ตรงนี้ — รอบก่อนเขียน 2.6 ไว้ตายตัวแล้วพอ
-- ผู้ใช้สั่งให้ใหญ่ขึ้นเป็น 3.9 ข้อความสรุปก็รายงานความสูงผิดไปทั้งที่โมเดลถูก
local liveScale = 1
local okConf, conf = pcall(function() return require(game.ReplicatedStorage.GatherConfig).Mobs.Forgewarden end)
if okConf and conf and conf.scale then liveScale = conf.scale end
root:SetAttribute("Progress", ("Boss_Forgewarden %d ชิ้น สูง %.1f studs (x%.1f = %.0f) ข้อต่อ %d"):format(
	#built:GetDescendants(), size.Y, liveScale, size.Y * liveScale, madeJoints))
root:SetAttribute("Status", "done")
print("[Boss] " .. root:GetAttribute("Progress"))
