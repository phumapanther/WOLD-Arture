-- animgen/weapons.lua — per-weapon idle and attack KeyframeSequences into ServerStorage.WOLD_Animations.
--
-- Same pipeline as animgen/combat.lua: build the instance tree from code, then in Studio right-click each
-- sequence and pick "Save to Roblox" to publish it and get a real Animation ID.
--
-- Run with:  node tools/run-luau.js animgen/weapons.lua
--
-- EVERY sequence here poses arms and torso ONLY, never the legs. That is deliberate and is what makes
-- "ขาขยับเดินวิ่งแบบปกติ" work: a joint with no Pose is left to whatever other track owns it, so Roblox's
-- default walk and run keep driving the lower body while these hold the upper. The same trick keeps
-- Combat_Guard from freezing the legs (see animgen/combat.lua).
--
-- R15 sign conventions, established by measurement in earlier passes:
--   * Shoulders/elbows rotate the limb FORWARD on positive X.
--   * Positive Z on a shoulder swings that arm away from the body (out to its own side).
--   * The waist's Y turns the chest; positive turns it to the character's left.

local ServerStorage = game:GetService("ServerStorage")

local NAMES = {
	"Sword_Idle", "Sword_Swing_Left", "Sword_Swing_Right",
	"Bow_Idle", "Bow_Shoot",
	"Staff_Idle", "Staff_Swing",
	"Spellbook_Idle", "Spellbook_Cast",
}

local folder = ServerStorage:FindFirstChild("WOLD_Animations")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WOLD_Animations"
	folder.Parent = ServerStorage
end

-- Clear only what this file owns; the combat, movement and revive sequences live in the same folder and an
-- unpublished sequence is unrecoverable once destroyed.
for _, name in ipairs(NAMES) do
	local old = folder:FindFirstChild(name)
	if old then old:Destroy() end
end

local rad = math.rad

local function pose(parent, name, cf)
	local p = Instance.new("Pose")
	p.Name = name
	p.CFrame = cf or CFrame.new()
	p.EasingStyle = Enum.PoseEasingStyle.Cubic
	p.EasingDirection = Enum.PoseEasingDirection.Out
	p.Parent = parent
	return p
end

-- Arms and torso only. No leg poses: see the header.
local function keyframe(seq, time, s)
	local kf = Instance.new("Keyframe")
	kf.Name = "KF_" .. tostring(time)
	kf.Time = time
	local root = pose(kf, "HumanoidRootPart")
	local lower = pose(root, "LowerTorso")
	local upper = pose(lower, "UpperTorso", s.waist)
	local rU = pose(upper, "RightUpperArm", s.rShoulder)
	pose(rU, "RightLowerArm", s.rElbow)
	local lU = pose(upper, "LeftUpperArm", s.lShoulder)
	pose(lU, "LeftLowerArm", s.lElbow)
	kf.Parent = seq
	return kf
end

local function copy(t, overrides)
	local out = {}
	for k, v in pairs(t) do out[k] = v end
	for k, v in pairs(overrides or {}) do out[k] = v end
	return out
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

--------------------------------------------------------------------------------
-- SWORD — both hands on the hilt in front, blade pointing up and tipped forward.
--------------------------------------------------------------------------------
local SWORD_IDLE = {
	waist = CFrame.Angles(0, rad(-14), 0), -- chest turned slightly so the hands meet centre-front
	-- The sword hangs off the RIGHT hand, so that arm sets the blade's angle: raised in front, elbow bent so
	-- the hilt sits at chest height and the blade runs up and slightly forward.
	-- Measured convention: on the RIGHT arm negative Z pulls the hand inward across the chest (z=-40 puts it
	-- at x=-0.12, z=0 at x=+1.05), and the left arm mirrors it. Both hands therefore need to swing inward to
	-- meet on one hilt.
	rShoulder = CFrame.Angles(rad(38), 0, rad(-30)),
	rElbow = CFrame.Angles(rad(72), 0, 0),
	lShoulder = CFrame.Angles(rad(42), 0, rad(26)),
	lElbow = CFrame.Angles(rad(78), 0, 0),
}

build("Sword_Idle", Enum.AnimationPriority.Idle, true, {
	{ 0.0, SWORD_IDLE },
	-- A slow breath so a held stance is not a frozen statue.
	{ 1.3, copy(SWORD_IDLE, {
		rShoulder = CFrame.Angles(rad(35), 0, rad(-30)),
		lShoulder = CFrame.Angles(rad(39), 0, rad(26)),
	}) },
	{ 2.6, SWORD_IDLE },
})

-- Diagonal swing to the character's LEFT: wind up over the right shoulder, cut down across the body.
build("Sword_Swing_Left", Enum.AnimationPriority.Action, false, {
	{ 0.0, SWORD_IDLE },
	{ 0.12, copy(SWORD_IDLE, { -- wind up: blade cocked back over the right shoulder
		waist = CFrame.Angles(0, rad(-42), 0),
		rShoulder = CFrame.Angles(rad(6), 0, rad(-42)),
		rElbow = CFrame.Angles(rad(112), 0, 0),
		lShoulder = CFrame.Angles(rad(18), 0, rad(30)),
		lElbow = CFrame.Angles(rad(104), 0, 0),
	}) },
	{ 0.30, copy(SWORD_IDLE, { -- cut through, ending low across the left
		waist = CFrame.Angles(0, rad(38), 0),
		rShoulder = CFrame.Angles(rad(84), 0, rad(34)),
		rElbow = CFrame.Angles(rad(16), 0, 0),
		lShoulder = CFrame.Angles(rad(76), 0, rad(-10)),
		lElbow = CFrame.Angles(rad(28), 0, 0),
	}) },
	{ 0.62, SWORD_IDLE }, -- recover
})

-- Mirror of the above: wind up over the left, cut down to the right.
build("Sword_Swing_Right", Enum.AnimationPriority.Action, false, {
	{ 0.0, SWORD_IDLE },
	{ 0.12, copy(SWORD_IDLE, {
		waist = CFrame.Angles(0, rad(34), 0),
		rShoulder = CFrame.Angles(rad(14), 0, rad(-8)),
		rElbow = CFrame.Angles(rad(118), 0, 0),
		lShoulder = CFrame.Angles(rad(8), 0, rad(48)),
		lElbow = CFrame.Angles(rad(110), 0, 0),
	}) },
	{ 0.30, copy(SWORD_IDLE, {
		waist = CFrame.Angles(0, rad(-46), 0),
		rShoulder = CFrame.Angles(rad(80), 0, rad(-40)),
		rElbow = CFrame.Angles(rad(20), 0, 0),
		lShoulder = CFrame.Angles(rad(70), 0, rad(-28)),
		lElbow = CFrame.Angles(rad(34), 0, 0),
	}) },
	{ 0.62, SWORD_IDLE },
})

--------------------------------------------------------------------------------
-- BOW — bow arm straight out front, string arm drawn back at the elbow.
--------------------------------------------------------------------------------
local BOW_IDLE = {
	-- Chest turned toward the bow arm, which is what tips the torso and elbow forward on that side.
	waist = CFrame.Angles(0, rad(-30), 0),
	-- Right hand holds the bow: arm straight out in front, barely any elbow bend.
	rShoulder = CFrame.Angles(rad(88), 0, rad(-10)),
	rElbow = CFrame.Angles(rad(4), 0, 0),
	-- Left hand draws the string. The shoulder must stay LOW (a small forward angle) while the elbow folds
	-- past 90 degrees, or the hand ends up in front of the bow instead of behind it — measured 1.26 vs 1.12,
	-- which read as both arms reaching forward.
	lShoulder = CFrame.Angles(rad(-14), 0, rad(-24)),
	lElbow = CFrame.Angles(rad(150), 0, 0),
}

build("Bow_Idle", Enum.AnimationPriority.Idle, true, {
	{ 0.0, BOW_IDLE },
	{ 1.5, copy(BOW_IDLE, { lElbow = CFrame.Angles(rad(90), 0, 0) }) },
	{ 3.0, BOW_IDLE },
})

-- Loosing an arrow: the draw hand snaps open and back, the bow arm holds steady.
-- The draw is slow and the release is instant, because that is the shape of the act: a bow is hauled back
-- against its own resistance and then lets go all at once.
--
-- The timings here MUST line up with the windup in CombatConfig, which is when the arrow actually leaves.
-- They used to release at 0.20 against a windup of 0.15, so the string snapped open a frame before the shot
-- and the draw itself was over too quickly to see. The release keyframe now sits at 0.38, just under the
-- bow's 0.4 windup, so the arrow leaves on the frame the hand opens.
build("Bow_Shoot", Enum.AnimationPriority.Action, false, {
	{ 0.0, BOW_IDLE },
	{ 0.30, copy(BOW_IDLE, { -- full draw: shoulder pulls further behind, elbow folds tight
		lShoulder = CFrame.Angles(rad(-26), 0, rad(-30)),
		lElbow = CFrame.Angles(rad(158), 0, 0),
	}) },
	{ 0.38, copy(BOW_IDLE, { -- release: string hand snaps open and away
		lShoulder = CFrame.Angles(rad(-34), 0, rad(-40)),
		lElbow = CFrame.Angles(rad(110), 0, 0),
		rShoulder = CFrame.Angles(rad(92), 0, rad(-10)),
	}) },
	{ 0.70, BOW_IDLE },
})

--------------------------------------------------------------------------------
-- STAFF — held like the sword; the swing throws a beam rather than cutting.
--------------------------------------------------------------------------------
build("Staff_Idle", Enum.AnimationPriority.Idle, true, {
	{ 0.0, SWORD_IDLE },
	{ 1.3, copy(SWORD_IDLE, {
		rShoulder = CFrame.Angles(rad(35), 0, rad(-30)),
		lShoulder = CFrame.Angles(rad(39), 0, rad(26)),
	}) },
	{ 2.6, SWORD_IDLE },
})

-- One sweeping swing, the same shape as the sword's left cut, since the beam does the damage.
build("Staff_Swing", Enum.AnimationPriority.Action, false, {
	{ 0.0, SWORD_IDLE },
	{ 0.14, copy(SWORD_IDLE, {
		waist = CFrame.Angles(0, rad(-40), 0),
		rShoulder = CFrame.Angles(rad(2), 0, rad(-38)),
		rElbow = CFrame.Angles(rad(108), 0, 0),
		lShoulder = CFrame.Angles(rad(16), 0, rad(28)),
		lElbow = CFrame.Angles(rad(100), 0, 0),
	}) },
	{ 0.32, copy(SWORD_IDLE, { -- staff thrust forward as the beam leaves it
		waist = CFrame.Angles(0, rad(10), 0),
		rShoulder = CFrame.Angles(rad(92), 0, rad(6)),
		rElbow = CFrame.Angles(rad(10), 0, 0),
		lShoulder = CFrame.Angles(rad(84), 0, rad(-8)),
		lElbow = CFrame.Angles(rad(22), 0, 0),
	}) },
	{ 0.70, SWORD_IDLE },
})

--------------------------------------------------------------------------------
-- SPELLBOOK — arms open to the sides, elbows softly bent; the book floats in front.
--------------------------------------------------------------------------------
local BOOK_IDLE = {
	waist = CFrame.Angles(rad(-4), 0, 0),
	-- Both arms out and forward, palms toward the floating book. Positive Z swings an arm away from the body,
	-- so the RIGHT arm needs positive and the left negative to open them out — reversed, the hands met in the
	-- middle (measured 0.43 studs apart) instead of framing the book.
	rShoulder = CFrame.Angles(rad(46), 0, rad(46)),
	rElbow = CFrame.Angles(rad(40), 0, 0),
	lShoulder = CFrame.Angles(rad(46), 0, rad(-46)),
	lElbow = CFrame.Angles(rad(40), 0, 0),
}

build("Spellbook_Idle", Enum.AnimationPriority.Idle, true, {
	{ 0.0, BOOK_IDLE },
	{ 1.4, copy(BOOK_IDLE, { -- hands drift as if channelling
		rShoulder = CFrame.Angles(rad(50), 0, rad(42)),
		lShoulder = CFrame.Angles(rad(50), 0, rad(-42)),
	}) },
	{ 2.8, BOOK_IDLE },
})

-- Casting: hands push forward as the orb leaves the book.
build("Spellbook_Cast", Enum.AnimationPriority.Action, false, {
	{ 0.0, BOOK_IDLE },
	{ 0.14, copy(BOOK_IDLE, { -- gather: hands draw in toward the book
		rShoulder = CFrame.Angles(rad(34), 0, rad(28)),
		rElbow = CFrame.Angles(rad(74), 0, 0),
		lShoulder = CFrame.Angles(rad(34), 0, rad(-28)),
		lElbow = CFrame.Angles(rad(74), 0, 0),
	}) },
	{ 0.28, copy(BOOK_IDLE, { -- push: both palms thrust forward
		rShoulder = CFrame.Angles(rad(88), 0, rad(16)),
		rElbow = CFrame.Angles(rad(10), 0, 0),
		lShoulder = CFrame.Angles(rad(88), 0, rad(-16)),
		lElbow = CFrame.Angles(rad(10), 0, 0),
	}) },
	{ 0.60, BOOK_IDLE },
})

local names = {}
for _, name in ipairs(NAMES) do
	local seq = folder:FindFirstChild(name)
	local kfs = 0
	if seq then
		for _, k in ipairs(seq:GetChildren()) do
			if k:IsA("Keyframe") then kfs += 1 end
		end
	end
	table.insert(names, ("%s(kf=%d)"):format(name, kfs))
end
return table.concat(names, " | ")
