-- animgen/greatsword.lua — the two-handed sword's guard and its overhead chop.
--
-- Run with:  node tools/run-luau.js animgen/greatsword.lua
-- Then in Studio right-click each sequence in ServerStorage.WOLD_Animations and pick "Save to Roblox" to
-- publish it, and paste the ids into CombatConfig.Weapons.Greatsword.
--
-- Both poses are the user's own description:
--   idle  -- "เหยียดแขนตรงสองมือมาประกบกันด้านหน้า เอียงลงไปจนมือเกือบถึงท้อง"
--            arms straight, hands together in front, angled down until they nearly reach the belly.
--   swing -- "ชูแขนสองข้างเหยียดตรงเหนือหัว และก็เหวี่ยงฟันลง ... จะฟาดจนถึงพื้น"
--            both arms straight overhead, then swung down until the blade reaches the ground.
--
-- Arms and torso ONLY -- no leg poses -- so the ordinary walk and run keep driving the lower body while
-- these hold the upper half. Same rule as animgen/weapons.lua, and the reason the user can walk while
-- holding the guard.
--
-- R15 sign conventions, as measured in the earlier animation passes:
--   * Shoulders/elbows rotate the limb FORWARD on positive X.
--   * On the RIGHT arm, negative Z pulls the hand inward across the chest; the left arm mirrors it.
--   * The waist's Y turns the chest; positive turns it to the character's left.
--   * The waist's X leans the chest: NEGATIVE folds it FORWARD over the legs, positive arches it back.
--     Measured off the working Sword_Slash, whose wind-up is +10 (leaning back) and whose strike is -15
--     then -20 (folding forward through the blow). Getting this backwards makes the character lie back as
--     it swings down, which is what the first version of this file did.

local ServerStorage = game:GetService("ServerStorage")

local NAMES = { "Greatsword_Idle", "Greatsword_Swing", "Greatsword_Leap" }

local folder = ServerStorage:FindFirstChild("WOLD_Animations")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WOLD_Animations"
	folder.Parent = ServerStorage
end

-- Clear only what this file owns: the combat, movement, revive and weapon sequences share this folder, and
-- an unpublished sequence cannot be recovered once destroyed.
for _, name in ipairs(NAMES) do
	local old = folder:FindFirstChild(name)
	if old then old:Destroy() end
end

local rad = math.rad

--------------------------------------------------------------------------------
-- สองมือประกบด้าม
--
-- **มือซ้ายต้องข้ามมาจับด้ามที่ฝั่งขวา ไม่ใช่มาบรรจบกันที่แนวกลางลำตัว**
-- ดาบถูกเชื่อมกับ `RightHand` อย่างเดียว (`WeaponVisuals` ต่อ Motor6D ที่มือขวา) ด้ามจึงอยู่ทางขวาเสมอ
-- ของเดิมกวาดแขนเข้าในเท่ากันสองข้าง (ขวา -16 ซ้าย +16) สองมือเลยไปเจอกันกลางอก ซึ่งไม่มีอะไรอยู่ตรงนั้น
-- มือซ้ายเลยลอยเปล่าข้างดาบ ไม่ได้จับอะไร
--
-- ปรับสองปุ่มนี้ปุ่มเดียวพอ ทุกท่าที่ใช้มืออ่านค่าจากตรงนี้หมด
local L_CROSS = 34 -- องศาที่ไหล่ซ้ายกวาดเข้าใน — มากกว่าขวาเท่าตัว เพราะต้องข้ามลำตัวไปหาด้าม
local L_TUCK = 24  -- ข้อศอกซ้ายงอเก็บ ให้ฝ่ามือทาบลงบนด้ามใต้มือขวา ไม่ใช่เลยไปอีกฝั่ง
local R_IN = 14    -- ไหล่ขวากวาดเข้าในเล็กน้อย ด้ามจะได้อยู่หน้าลำตัว ไม่กางออกข้าง

local function pose(parent, name, cf, easing)
	local p = Instance.new("Pose")
	p.Name = name
	p.CFrame = cf or CFrame.new()
	p.EasingStyle = easing or Enum.PoseEasingStyle.Cubic
	p.EasingDirection = Enum.PoseEasingDirection.Out
	p.Parent = parent
	return p
end

local function keyframe(seq, time, s)
	local kf = Instance.new("Keyframe")
	kf.Name = "KF_" .. tostring(time)
	kf.Time = time
	local root = pose(kf, "HumanoidRootPart")
	local lower = pose(root, "LowerTorso")
	local upper = pose(lower, "UpperTorso", s.waist, s.easing)
	local rU = pose(upper, "RightUpperArm", s.rShoulder, s.easing)
	pose(rU, "RightLowerArm", s.rElbow, s.easing)
	local lU = pose(upper, "LeftUpperArm", s.lShoulder, s.easing)
	pose(lU, "LeftLowerArm", s.lElbow, s.easing)
	kf.Parent = seq
	return kf
end

local function build(name, priority, loop, frames)
	local seq = Instance.new("KeyframeSequence")
	seq.Name = name
	seq.Priority = priority
	seq.Loop = loop
	for _, frame in ipairs(frames) do
		keyframe(seq, frame[1], frame[2])
	end
	seq.Parent = folder
	return seq
end

local function copy(t, overrides)
	local out = {}
	for k, v in pairs(t) do out[k] = v end
	for k, v in pairs(overrides or {}) do out[k] = v end
	return out
end

--------------------------------------------------------------------------------
-- IDLE — the guard. Arms STRAIGHT (elbows at zero, which is what "เหยียดแขนตรง" means: no bend at all),
-- swung inward so the two hands meet on one hilt in front, and angled down far enough that they sit just
-- in front of the belly.
--
-- The shoulder X of 62 degrees is what points the straight arms down-and-forward; a smaller number would
-- hold the sword out horizontally like a spear, which is not the pose described.
--------------------------------------------------------------------------------
local IDLE = {
	waist = CFrame.Angles(rad(-6), 0, 0), -- leaning very slightly FORWARD over the weight of it
	rShoulder = CFrame.Angles(rad(62), 0, rad(-R_IN)),
	rElbow = CFrame.Angles(0, 0, 0), -- straight: มือขวาคือมือที่ถือด้ามจริง
	lShoulder = CFrame.Angles(rad(62), 0, rad(L_CROSS)),
	lElbow = CFrame.Angles(rad(L_TUCK), 0, 0), -- งอเก็บให้มือซ้ายไปทาบด้ามใต้มือขวา
}

-- Breathing, so the guard is not a statue: the tip dips and lifts a couple of degrees.
build("Greatsword_Idle", Enum.AnimationPriority.Idle, true, {
	{ 0.0, IDLE },
	{ 1.6, copy(IDLE, {
		waist = CFrame.Angles(rad(-8), 0, 0),
		rShoulder = CFrame.Angles(rad(65), 0, rad(-R_IN)),
		lShoulder = CFrame.Angles(rad(65), 0, rad(L_CROSS)),
	}) },
	{ 3.2, IDLE },
})

--------------------------------------------------------------------------------
-- SWING — two seconds, matching CombatConfig.Weapons.Greatsword exactly:
--
--   0.00 - 1.20  the wind-up: from the guard, both straight arms rise overhead
--   1.20 - 1.45  the strike: the hitbox is live, the blade comes down through the target
--   1.45         the blade reaches the GROUND -- Greatsword_hit plays here (CombatConfig `slam`)
--   1.45 - 2.00  recovery: dragging it back up out of the earth into the guard
--
-- The numbers in the config are windup 1.2, active 0.25, recovery 0.55 and slam 1.45. If either side is
-- retimed, both have to move together or the sound will land somewhere the blade is not.
--
-- The downswing keyframes use LINEAR easing. Cubic ease-out on a fast arc makes the blade decelerate into
-- the ground, which reads as the swing running out of strength rather than burying itself.
--------------------------------------------------------------------------------
local OVERHEAD = {
	-- Straight arms directly above the head, arching BACK to load the swing: positive X on the waist.
	waist = CFrame.Angles(rad(22), 0, 0),
	rShoulder = CFrame.Angles(rad(172), 0, rad(-(R_IN - 4))),
	rElbow = CFrame.Angles(0, 0, 0),
	lShoulder = CFrame.Angles(rad(172), 0, rad(L_CROSS - 6)),
	lElbow = CFrame.Angles(rad(L_TUCK - 6), 0, 0), -- ชูขึ้นแล้วยังคงคาบด้ามไว้ทั้งสองมือ
}

local GROUND = {
	-- Arms straight down in front, body folded FORWARD over them: the blade is in the earth.
	waist = CFrame.Angles(rad(-42), 0, 0),
	rShoulder = CFrame.Angles(rad(14), 0, rad(-(R_IN - 4))),
	rElbow = CFrame.Angles(0, 0, 0),
	lShoulder = CFrame.Angles(rad(14), 0, rad(L_CROSS - 6)),
	lElbow = CFrame.Angles(rad(L_TUCK - 6), 0, 0), -- ฟาดลงถึงพื้นโดยยังประกบสองมืออยู่
	easing = Enum.PoseEasingStyle.Linear,
}

build("Greatsword_Swing", Enum.AnimationPriority.Action4, false, {
	{ 0.00, IDLE },
	-- Up, and slightly past the vertical: the pause at the top is what makes a two-second swing read as
	-- heavy rather than slow.
	{ 0.85, OVERHEAD },
	{ 1.20, copy(OVERHEAD, { easing = Enum.PoseEasingStyle.Linear }) },
	-- Through the target and into the ground.
	{ 1.45, GROUND },
	-- Hauling it back out.
	{ 1.75, copy(IDLE, {
		waist = CFrame.Angles(rad(-18), 0, 0),
		rShoulder = CFrame.Angles(rad(44), 0, rad(-R_IN)),
		lShoulder = CFrame.Angles(rad(44), 0, rad(L_CROSS)),
		lElbow = CFrame.Angles(rad(L_TUCK), 0, 0),
	}) },
	{ 2.00, IDLE },
})

--------------------------------------------------------------------------------
-- LEAP — the Q skill, for both swords. The user's order of events: wind up FIRST, then jump, and only
-- swing once you have landed on them.
--
--   0.00 - 0.45  the wind-up: blade drawn back and up, weight loaded. Nothing has moved yet.
--   0.45         the server launches the leap here (WeaponSkills LAUNCH_AT)
--   0.45 - 0.85  airborne, holding the loaded pose -- the sword stays cocked the whole flight
--   0.85 - 1.05  the chop, landing with it (WeaponSkills HIT_AT 0.95, inside this window)
--   1.05 - 1.40  recovery back to the guard
--
-- The three constants in WeaponSkills.server.lua mirror these times. Move one and the swing lands somewhere
-- the character is not.
--------------------------------------------------------------------------------
local LOADED = {
	-- Wound back over the shoulder rather than straight overhead: this is a running chop, not the standing
	-- one the basic swing does, and it has to read as different mid-air.
	waist = CFrame.Angles(rad(18), rad(-26), 0),
	rShoulder = CFrame.Angles(rad(150), 0, rad(-26)),
	rElbow = CFrame.Angles(rad(28), 0, 0),
	lShoulder = CFrame.Angles(rad(138), 0, rad(30)),
	lElbow = CFrame.Angles(rad(34), 0, 0),
}

local LANDED = {
	-- Driven down and across the body, folded forward over the landing.
	waist = CFrame.Angles(rad(-38), rad(16), 0),
	rShoulder = CFrame.Angles(rad(16), 0, rad(-6)),
	rElbow = CFrame.Angles(0, 0, 0),
	lShoulder = CFrame.Angles(rad(16), 0, rad(6)),
	lElbow = CFrame.Angles(0, 0, 0),
	easing = Enum.PoseEasingStyle.Linear,
}

build("Greatsword_Leap", Enum.AnimationPriority.Action4, false, {
	{ 0.00, IDLE },
	-- Wind up, and hold it: the pause is what makes the jump read as a consequence of the wind-up rather
	-- than something that happened at the same time.
	{ 0.45, LOADED },
	{ 0.85, copy(LOADED, { easing = Enum.PoseEasingStyle.Linear }) },
	-- Down through them as the feet hit.
	{ 1.05, LANDED },
	{ 1.40, IDLE },
})

print("[greatsword] built " .. table.concat(NAMES, ", ") .. " into ServerStorage.WOLD_Animations")
