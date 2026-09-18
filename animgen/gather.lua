-- animgen/gather.lua — ท่าเก็บวัตถุดิบ 4 แบบ เข้า ServerStorage.WOLD_Animations ตามคู่มือภาพของผู้ใช้
--
--   Gather_Animal  แดง    "ก้มตัวและขุด"   นั่งยองคร่อมซาก มือขวาเชือดสั้นๆ ซ้ายจับหนัง (ระยะหัว-ลำตัว)
--   Gather_Stone   ส้ม    "ฟันและกระแทก"  เหวี่ยงอีเต้อข้ามหัวสองมือ ถ่ายน้ำหนักจากเท้าหลังไปเท้าหน้า
--   Gather_Wood    น้ำเงิน "ฟันและบิดตัว"  เหวี่ยงขวานด้านข้าง แขนบน 45° บิดสะโพก-ลำตัวตาม
--   Gather_Bush    เขียว  "ก้มและเก็บ"    ก้มตัว มือหนึ่งจับ ดึงขึ้นมา ส่งเข้าอีกมือ
--
-- ทุกท่าเป็นลูป 4 จังหวะตามภาพ: เริ่ม (F1) → ยืดสุด (F5) → กระแทก (F8) → คืนตัว (F12) และมีคีย์กลางเพื่อไม่ให้
-- เอนจิ้นลัดทางสั้นระหว่างสองท่าสุดขั้ว (บทเรียนจาก Farm_Search)
--
-- ท่อเดียวกับ animgen/farm.lua: สร้าง instance จากโค้ด → คลิกขวา sequence ใน Studio → Save to Roblox
-- (**ต้องเป็นบัญชีเจ้าของเพลส**) → เอา id ใส่ `GatherConfig.Animations` ช่องว่าง = ระบบใช้ท่าฟันดาบเดิม
--
-- รัน:      node tools/run-luau.js animgen/gather.lua --no-lib
-- พรีวิว:   node tools/preview-anim.js animgen/gather.lua Gather_Stone --speed 0.6   (ต้องอยู่ใน Play)

local ServerStorage = game:GetService("ServerStorage")

local rad = math.rad

-- ต้นไม้ข้อต่อ R15 ทุก Pose ต้องอยู่ใต้ Pose ของข้อต่อแม่ ไม่งั้นเอนจิ้นไม่สน (ซ้ำกับไฟล์ animgen อื่นโดยตั้งใจ:
-- run-luau.js ดันไฟล์เดียวโดดๆ เข้า Studio ไม่มีโมดูลให้ require)
local PARENT = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	LeftUpperArm = "UpperTorso", LeftLowerArm = "LeftUpperArm", LeftHand = "LeftLowerArm",
	RightUpperArm = "UpperTorso", RightLowerArm = "RightUpperArm", RightHand = "RightLowerArm",
	LeftUpperLeg = "LowerTorso", LeftLowerLeg = "LeftUpperLeg", LeftFoot = "LeftLowerLeg",
	RightUpperLeg = "LowerTorso", RightLowerLeg = "RightUpperLeg", RightFoot = "RightLowerLeg",
}

local folder = ServerStorage:FindFirstChild("WOLD_Animations")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WOLD_Animations"
	folder.Parent = ServerStorage
end

-- ลบเฉพาะสี่ท่าของไฟล์นี้ ไม่แตะท่าของไฟล์อื่น
local function fresh(name, priority, loop)
	local old = folder:FindFirstChild(name)
	if old then old:Destroy() end
	local seq = Instance.new("KeyframeSequence")
	seq.Name = name
	seq.Priority = priority
	seq.Loop = loop and true or false
	seq.Parent = folder
	return seq
end

local function keyframe(seq, time, poses, easing)
	local kf = Instance.new("Keyframe")
	kf.Name = ("KF_%.2f"):format(time)
	kf.Time = time
	local made = {}
	local ensure
	ensure = function(name)
		if made[name] then return made[name] end
		local p = Instance.new("Pose")
		p.Name = name
		p.CFrame = poses[name] or CFrame.new()
		p.EasingStyle = easing or Enum.PoseEasingStyle.Cubic
		p.EasingDirection = Enum.PoseEasingDirection.InOut
		p.Parent = (name == "HumanoidRootPart") and kf or ensure(PARENT[name])
		made[name] = p
		return p
	end
	ensure("HumanoidRootPart")
	for name in pairs(poses) do
		if name ~= "HumanoidRootPart" then ensure(name) end
	end
	kf.Parent = seq
	return kf
end

local function copy(t, overrides)
	local out = {}
	for k, v in pairs(t) do out[k] = v end
	for k, v in pairs(overrides or {}) do out[k] = v end
	return out
end

-- LowerTorso = RootJoint: เลื่อน/หมุน "ร่างที่มองเห็น" ทั้งตัวรอบ root โดย humanoid ยังยืนตรงชนปกติ
-- dy ลบ = ย่อตัวลง · pitch ลบ = ก้มไปข้างหน้า · yaw = บิดทั้งตัว
local function root(dy, dz, pitch, yaw)
	return CFrame.new(0, dy or 0, dz or 0) * CFrame.Angles(rad(pitch or 0), rad(yaw or 0), 0)
end

-- แกนที่ใช้ทั้งไฟล์ (สรุปจากท่าที่ผ่านตามาแล้วใน farm/sword):
--   UpperArm  pitch + = แขนเหวี่ยงไปข้างหน้า/ขึ้น  − = ไปข้างหลัง/ยกข้ามหัว   roll (Z) กางออกข้าง
--   LowerArm  pitch + = งอศอก (มือมาหน้า)
--   UpperTorso pitch − = ก้มหน้า + = แอ่นหลัง   yaw = บิดลำตัว
--   UpperLeg  pitch + = ยกเข่ามาหน้า   LowerLeg pitch − = งอเข่า   Foot pitch + = วางเท้าราบ

--------------------------------------------------------------------------------
-- Gather_Animal — นั่งยองคร่อมซาก มือขวาเชือดสั้นๆ ซ้ายจับหนัง (แดง)
--------------------------------------------------------------------------------

-- ต่ำกว่า Farm_Search: ซากอยู่ระดับพื้น ไม่ใช่ระดับเอว เข่าซ้ายจรดพื้น ขาขวาตั้ง
local ANIMAL_BASE = {
	LowerTorso = root(-1.55, 0.2, -30),
	UpperTorso = CFrame.Angles(rad(-22), rad(6), 0),
	Head = CFrame.Angles(rad(-28), 0, 0),

	-- ซ้ายยื่นไปจับหนังไว้ ค่อนข้างนิ่งทั้งรอบ
	LeftUpperArm = CFrame.Angles(rad(64), 0, rad(18)),
	LeftLowerArm = CFrame.Angles(rad(30), 0, 0),
	LeftHand = CFrame.Angles(rad(-20), 0, 0),

	-- ขวาถือมีด ท่าเริ่ม: ศอกงอ มืออยู่ใกล้ตัว
	RightUpperArm = CFrame.Angles(rad(40), 0, rad(-10)),
	RightLowerArm = CFrame.Angles(rad(70), 0, 0),
	RightHand = CFrame.Angles(rad(-10), 0, rad(20)),

	-- ขาขวาตั้งเข่า ขาซ้ายคุกเข่า
	RightUpperLeg = CFrame.Angles(rad(70), 0, rad(8)),
	RightLowerLeg = CFrame.Angles(rad(-100), 0, 0),
	RightFoot = CFrame.Angles(rad(30), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(-20), 0, rad(-10)),
	LeftLowerLeg = CFrame.Angles(rad(-110), 0, 0),
	LeftFoot = CFrame.Angles(rad(40), 0, 0),
}

-- F5 ยืดสุด: มีดยื่นไปข้างหน้าจนสุดแขน ลำตัวตามไปนิด
local ANIMAL_EXTEND = copy(ANIMAL_BASE, {
	UpperTorso = CFrame.Angles(rad(-28), rad(10), 0),
	RightUpperArm = CFrame.Angles(rad(78), 0, rad(-14)),
	RightLowerArm = CFrame.Angles(rad(22), 0, 0),
	RightHand = CFrame.Angles(rad(-18), 0, rad(24)),
})

-- F8 กระแทก/ลาก: ดึงมีดกลับเข้าหาตัวแรงๆ ไหล่ตามมา ซ้ายดึงหนังสวนทางเล็กน้อย
local ANIMAL_PULL = copy(ANIMAL_BASE, {
	UpperTorso = CFrame.Angles(rad(-16), rad(-4), 0),
	RightUpperArm = CFrame.Angles(rad(26), 0, rad(-4)),
	RightLowerArm = CFrame.Angles(rad(92), 0, 0),
	RightHand = CFrame.Angles(rad(-4), 0, rad(16)),
	LeftUpperArm = CFrame.Angles(rad(56), 0, rad(22)),
	LeftLowerArm = CFrame.Angles(rad(44), 0, 0),
})

local animal = fresh("Gather_Animal", Enum.AnimationPriority.Action, true)
keyframe(animal, 0.00, ANIMAL_BASE)
keyframe(animal, 0.30, ANIMAL_EXTEND)
keyframe(animal, 0.50, ANIMAL_PULL)
keyframe(animal, 0.75, ANIMAL_BASE)
keyframe(animal, 1.00, ANIMAL_BASE)

--------------------------------------------------------------------------------
-- Gather_Stone — เหวี่ยงอีเต้อข้ามหัวสองมือ (ส้ม)
--------------------------------------------------------------------------------

-- ยืนแยกขาหน้า-หลัง: ขวาถอยหลังรับน้ำหนักตอนง้าง ซ้ายก้าวหน้า
local STONE_BASE = {
	LowerTorso = root(-0.25, 0, -6),
	UpperTorso = CFrame.Angles(rad(-6), rad(-8), 0),
	Head = CFrame.Angles(rad(-14), rad(6), 0),

	-- สองมือกำด้าม ระดับอก
	RightUpperArm = CFrame.Angles(rad(50), 0, rad(-12)),
	RightLowerArm = CFrame.Angles(rad(60), 0, 0),
	RightHand = CFrame.Angles(0, 0, rad(10)),
	LeftUpperArm = CFrame.Angles(rad(46), rad(-10), rad(30)),
	LeftLowerArm = CFrame.Angles(rad(70), 0, 0),
	LeftHand = CFrame.Angles(0, 0, rad(-10)),

	RightUpperLeg = CFrame.Angles(rad(-18), rad(-8), rad(6)),
	RightLowerLeg = CFrame.Angles(rad(-14), 0, 0),
	RightFoot = CFrame.Angles(rad(10), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(22), rad(6), rad(-6)),
	LeftLowerLeg = CFrame.Angles(rad(-22), 0, 0),
	LeftFoot = CFrame.Angles(rad(4), 0, 0),
}

-- F5 ยืดสุด: อีเต้อขึ้นข้ามหัวไปข้างหลัง หลังแอ่น น้ำหนักลงเท้าหลัง (ขวา)
local STONE_RAISE = copy(STONE_BASE, {
	LowerTorso = root(-0.1, -0.15, 8),
	UpperTorso = CFrame.Angles(rad(14), rad(-10), 0),
	Head = CFrame.Angles(rad(-4), rad(6), 0),
	RightUpperArm = CFrame.Angles(rad(-150), rad(6), rad(-16)),
	RightLowerArm = CFrame.Angles(rad(40), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(-140), rad(-10), rad(26)),
	LeftLowerArm = CFrame.Angles(rad(46), 0, 0),
	RightUpperLeg = CFrame.Angles(rad(-26), rad(-8), rad(6)),
	RightLowerLeg = CFrame.Angles(rad(-26), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(12), rad(6), rad(-6)),
	LeftLowerLeg = CFrame.Angles(rad(-8), 0, 0),
})

-- F8 กระแทก: แขนฟาดลงสุด ลำตัวก้มตาม น้ำหนักถ่ายไปเท้าหน้า (ซ้าย) เข่าหน้างอรับ
local STONE_IMPACT = copy(STONE_BASE, {
	LowerTorso = root(-0.6, 0.25, -34),
	UpperTorso = CFrame.Angles(rad(-24), rad(-4), 0),
	Head = CFrame.Angles(rad(-18), rad(4), 0),
	RightUpperArm = CFrame.Angles(rad(58), rad(4), rad(-10)),
	RightLowerArm = CFrame.Angles(rad(12), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(54), rad(-8), rad(26)),
	LeftLowerArm = CFrame.Angles(rad(16), 0, 0),
	RightUpperLeg = CFrame.Angles(rad(-8), rad(-8), rad(6)),
	RightLowerLeg = CFrame.Angles(rad(-8), 0, 0),
	RightFoot = CFrame.Angles(rad(28), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(48), rad(6), rad(-6)),
	LeftLowerLeg = CFrame.Angles(rad(-52), 0, 0),
	LeftFoot = CFrame.Angles(rad(10), 0, 0),
})

-- แกว่งลงต้องเร็ว: ช่วงกระแทกใช้ Linear ไม่งั้นเอนจิ้นชะลอปลายทางแล้วอีเต้อ "ลอย" ลงหิน
local stone = fresh("Gather_Stone", Enum.AnimationPriority.Action, true)
keyframe(stone, 0.00, STONE_BASE)
keyframe(stone, 0.40, STONE_RAISE)
keyframe(stone, 0.50, STONE_RAISE, Enum.PoseEasingStyle.Linear) -- ค้างบนสุดแวบหนึ่ง ให้อ่านออกว่าง้าง
keyframe(stone, 0.68, STONE_IMPACT, Enum.PoseEasingStyle.Linear)
keyframe(stone, 0.80, STONE_IMPACT)
keyframe(stone, 1.15, STONE_BASE)

--------------------------------------------------------------------------------
-- Gather_Wood — เหวี่ยงขวานด้านข้าง บิดสะโพก-ลำตัวตาม (น้ำเงิน)
--------------------------------------------------------------------------------

-- ยืนหันข้างให้ต้นไม้ (ต้นไม้อยู่ทางซ้ายหน้า) ขวานยกด้านขวา
local WOOD_BASE = {
	LowerTorso = root(-0.15, 0, 0, 12),
	UpperTorso = CFrame.Angles(rad(-4), rad(-14), 0),
	Head = CFrame.Angles(rad(-6), rad(26), 0), -- ตามองต้นไม้แม้ตัวจะบิด

	-- แขนบน 45° ตามภาพ: ขวายกออกข้าง-หลัง ซ้ายจับด้ามช่วยข้ามตัว
	RightUpperArm = CFrame.Angles(rad(-20), rad(10), rad(-45)),
	RightLowerArm = CFrame.Angles(rad(64), 0, 0),
	RightHand = CFrame.Angles(0, 0, rad(12)),
	LeftUpperArm = CFrame.Angles(rad(40), rad(-24), rad(36)),
	LeftLowerArm = CFrame.Angles(rad(70), 0, 0),

	RightUpperLeg = CFrame.Angles(rad(-6), rad(-10), rad(8)),
	RightLowerLeg = CFrame.Angles(rad(-12), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(8), rad(8), rad(-8)),
	LeftLowerLeg = CFrame.Angles(rad(-10), 0, 0),
}

-- F5 ง้างสุด: ขวานเหวี่ยงไปข้างหลังขวา ลำตัวบิดตาม (yaw ลบ) สะโพกตาม (root yaw)
local WOOD_WIND = copy(WOOD_BASE, {
	LowerTorso = root(-0.1, 0, 2, 26),
	UpperTorso = CFrame.Angles(rad(2), rad(-34), 0),
	Head = CFrame.Angles(rad(-4), rad(44), 0),
	RightUpperArm = CFrame.Angles(rad(-70), rad(20), rad(-60)),
	RightLowerArm = CFrame.Angles(rad(50), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(10), rad(-30), rad(50)),
	LeftLowerArm = CFrame.Angles(rad(80), 0, 0),
	RightUpperLeg = CFrame.Angles(rad(-12), rad(-14), rad(8)),
	LeftUpperLeg = CFrame.Angles(rad(4), rad(10), rad(-8)),
})

-- F8 กระแทก: เหวี่ยงข้ามตัวไปทางซ้ายหน้า ลำตัวบิดกลับสุด (yaw บวก) น้ำหนักลงเท้าซ้าย
local WOOD_HIT = copy(WOOD_BASE, {
	LowerTorso = root(-0.3, 0.1, -10, -14),
	UpperTorso = CFrame.Angles(rad(-12), rad(26), 0),
	Head = CFrame.Angles(rad(-8), rad(-6), 0),
	RightUpperArm = CFrame.Angles(rad(70), rad(-30), rad(20)),
	RightLowerArm = CFrame.Angles(rad(10), 0, 0),
	RightHand = CFrame.Angles(0, 0, rad(4)),
	LeftUpperArm = CFrame.Angles(rad(76), rad(-10), rad(-6)),
	LeftLowerArm = CFrame.Angles(rad(14), 0, 0),
	RightUpperLeg = CFrame.Angles(rad(-14), rad(-6), rad(8)),
	RightLowerLeg = CFrame.Angles(rad(-6), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(30), rad(6), rad(-8)),
	LeftLowerLeg = CFrame.Angles(rad(-34), 0, 0),
})

local wood = fresh("Gather_Wood", Enum.AnimationPriority.Action, true)
keyframe(wood, 0.00, WOOD_BASE)
keyframe(wood, 0.38, WOOD_WIND)
keyframe(wood, 0.46, WOOD_WIND, Enum.PoseEasingStyle.Linear)
keyframe(wood, 0.62, WOOD_HIT, Enum.PoseEasingStyle.Linear)
keyframe(wood, 0.72, WOOD_HIT)
keyframe(wood, 1.05, WOOD_BASE)

--------------------------------------------------------------------------------
-- Gather_Bush — ก้มตัว จับ ดึงขึ้น ส่งเข้าอีกมือ (เขียว)
--------------------------------------------------------------------------------

-- ก้มจากเอว เข่างอนิดเดียว มือซ้ายพักไว้ระดับอกเป็น "ที่รับของ"
local BUSH_BASE = {
	LowerTorso = root(-0.35, 0.1, -16),
	UpperTorso = CFrame.Angles(rad(-22), rad(8), 0),
	Head = CFrame.Angles(rad(-26), rad(-4), 0),

	LeftUpperArm = CFrame.Angles(rad(46), 0, rad(14)),
	LeftLowerArm = CFrame.Angles(rad(96), 0, 0),
	LeftHand = CFrame.Angles(rad(-20), 0, rad(-10)),

	RightUpperArm = CFrame.Angles(rad(30), 0, rad(-8)),
	RightLowerArm = CFrame.Angles(rad(30), 0, 0),

	RightUpperLeg = CFrame.Angles(rad(14), 0, rad(6)),
	RightLowerLeg = CFrame.Angles(rad(-22), 0, 0),
	RightFoot = CFrame.Angles(rad(8), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(14), 0, rad(-6)),
	LeftLowerLeg = CFrame.Angles(rad(-22), 0, 0),
	LeftFoot = CFrame.Angles(rad(8), 0, 0),
}

-- F1→F5 มือขวาลงไปจับที่พุ่ม ลำตัวก้มลงอีก
local BUSH_GRASP = copy(BUSH_BASE, {
	LowerTorso = root(-0.55, 0.2, -26),
	UpperTorso = CFrame.Angles(rad(-30), rad(12), 0),
	Head = CFrame.Angles(rad(-30), rad(-6), 0),
	RightUpperArm = CFrame.Angles(rad(74), rad(6), rad(-10)),
	RightLowerArm = CFrame.Angles(rad(8), 0, 0),
	RightHand = CFrame.Angles(rad(-24), 0, 0),
	RightUpperLeg = CFrame.Angles(rad(22), 0, rad(6)),
	RightLowerLeg = CFrame.Angles(rad(-34), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(22), 0, rad(-6)),
	LeftLowerLeg = CFrame.Angles(rad(-34), 0, 0),
})

-- F8 กระตุก: ดึงขึ้นเร็วๆ ตัวยืดขึ้นนิด
local BUSH_PULL = copy(BUSH_BASE, {
	LowerTorso = root(-0.25, 0.05, -10),
	UpperTorso = CFrame.Angles(rad(-12), rad(8), 0),
	Head = CFrame.Angles(rad(-16), rad(-2), 0),
	RightUpperArm = CFrame.Angles(rad(40), rad(4), rad(-8)),
	RightLowerArm = CFrame.Angles(rad(80), 0, 0),
	RightHand = CFrame.Angles(rad(-10), 0, 0),
})

-- F12 ส่งเข้ามือซ้าย: มือขวาเข้ามาหาอกซ้าย มือซ้ายรับแล้วแนบตัว
local BUSH_HANDOFF = copy(BUSH_BASE, {
	LowerTorso = root(-0.25, 0.05, -8),
	UpperTorso = CFrame.Angles(rad(-10), rad(4), 0),
	RightUpperArm = CFrame.Angles(rad(36), rad(-24), rad(-16)),
	RightLowerArm = CFrame.Angles(rad(100), 0, 0),
	RightHand = CFrame.Angles(rad(-6), rad(-20), 0),
	LeftUpperArm = CFrame.Angles(rad(40), rad(10), rad(12)),
	LeftLowerArm = CFrame.Angles(rad(104), 0, 0),
})

local bush = fresh("Gather_Bush", Enum.AnimationPriority.Action, true)
keyframe(bush, 0.00, BUSH_BASE)
keyframe(bush, 0.35, BUSH_GRASP)
keyframe(bush, 0.55, BUSH_PULL)
keyframe(bush, 0.85, BUSH_HANDOFF)
keyframe(bush, 1.20, BUSH_BASE)

print("[WOLD] animgen/gather: Gather_Animal / Gather_Stone / Gather_Wood / Gather_Bush built into ServerStorage.WOLD_Animations")
print("[WOLD] publish each (right-click -> Save to Roblox, as the place owner) and paste ids into GatherConfig.Animations")
