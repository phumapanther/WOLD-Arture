-- animgen/revive.lua — builds the CPR and piggyback-carry KeyframeSequences into ServerStorage.WOLD_Animations.
--
-- Same pipeline as animgen/combat.lua: build the instance tree from code, then in Studio right-click each
-- sequence and pick "Save to Roblox" to publish it and get a real Animation ID.
--
-- Run with:  node tools/run-luau.js animgen/revive.lua --no-lib
--
-- The three sequences, as the user described them:
--   CPR_Loop — kneeling back on the calves, shins folded under, knees on the ground, backside pushed back and
--   the torso tipped slightly forward, head down, both arms straight and joined out in front at about 45
--   degrees, rocking up and down on the compressions.
--   Carry_Held — the downed player rides on the carrier's back like a backpack: knees drawn up and bent,
--   arms reaching forward past the carrier's shoulders and joined in front.
--   Carry_Holder — the carrier. Arms and torso only, no leg poses, so the default walk and run keep driving
--   the legs and the carrier still moves normally while holding someone (the Combat_Guard trick).
--
-- The carry needs a joint the animations cannot provide. The system code should build it as:
--   Motor6D  Part0 = carrier.UpperTorso, Part1 = carried.HumanoidRootPart
--            C0 = CFrame.new(0, 0.15, 1.55) * CFrame.Angles(math.rad(-8), 0, 0)
-- Motor6D and not WeldConstraint: a Motor6D still lets the carried player's own Animator drive its rig, which
-- is what plays Carry_Held on top. Three things the joint alone will not fix, all of which look like bugs:
-- the carried humanoid needs PlatformStand = true or it fights the joint, the two characters need to stop
-- colliding with each other (CollisionGroup) or they shove each other apart, and the carried character's parts
-- need SetNetworkOwner(carrier) or the rig jitters hard while the carrier walks.

local ServerStorage = game:GetService("ServerStorage")

local rad = math.rad

-- R15 joint tree. Every pose has to sit under its parent joint's pose or the engine ignores it. A joint with
-- NO pose is left to whatever other track owns it, which is how Carry_Holder below leaves the legs to the walk
-- animation. Duplicated from animgen/movement.lua on purpose: run-luau.js pushes one standalone chunk into
-- Studio, so there is no module to require.
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

-- Only clear what this file owns; wiping the folder would take the combat and movement sequences with it.
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

local function keyframe(seq, time, poses, marker)
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
		p.EasingStyle = Enum.PoseEasingStyle.Cubic
		p.EasingDirection = Enum.PoseEasingDirection.Out
		p.Parent = (name == "HumanoidRootPart") and kf or ensure(PARENT[name])
		made[name] = p
		return p
	end
	ensure("HumanoidRootPart")
	for name in pairs(poses) do
		if name ~= "HumanoidRootPart" then ensure(name) end
	end

	-- A marker is the only way to hang code off a point inside a loop. GetMarkerReachedSignal("Beat") lets the
	-- compression sound and the HUD heartbeat land exactly on the press instead of being timed by a guess.
	if marker then
		local m = Instance.new("KeyframeMarker")
		m.Name = marker
		m.Parent = kf
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

-- The LowerTorso pose is the RootJoint: it offsets and rotates the whole visible body around the root part.
-- Kneeling drops the body by more than a stud this way while the humanoid itself keeps standing upright and
-- colliding normally. A negative pitch tips the torso forward.
local function root(dy, dz, pitch)
	return CFrame.new(0, dy or 0, dz or 0) * CFrame.Angles(rad(pitch or 0), 0, 0)
end

--------------------------------------------------------------------------------
-- CPR_Loop
--------------------------------------------------------------------------------

-- Sitting back on the heels with the torso tipped forward over the patient. The arms read as vertical even
-- though the shoulders are at 45 degrees, because the torso is already leaning forward: the two rotations add
-- up to hands pressing almost straight down, which is what a compression needs to look like.
local KNEEL = {
	LowerTorso = root(-1.62, 0.28, -20),
	UpperTorso = CFrame.Angles(rad(-14), 0, 0),
	Head = CFrame.Angles(rad(-26), 0, 0), -- face down toward the patient
	-- arms straight, hands brought together in front
	RightUpperArm = CFrame.Angles(rad(46), 0, rad(-13)),
	RightLowerArm = CFrame.Angles(rad(3), 0, 0),
	RightHand = CFrame.Angles(rad(12), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(46), 0, rad(13)),
	LeftLowerArm = CFrame.Angles(rad(3), 0, 0),
	LeftHand = CFrame.Angles(rad(12), 0, 0),
	-- shins folded back under the body, tops of the feet flat on the ground
	RightUpperLeg = CFrame.Angles(rad(26), 0, rad(8)),
	RightLowerLeg = CFrame.Angles(rad(-128), 0, 0),
	RightFoot = CFrame.Angles(rad(-42), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(26), 0, rad(-8)),
	LeftLowerLeg = CFrame.Angles(rad(-128), 0, 0),
	LeftFoot = CFrame.Angles(rad(-42), 0, 0),
}

-- Bottom of a compression: the whole body drops onto locked arms rather than the arms bending. Small on
-- purpose — the rhythm sells this, not the distance.
local PRESS = copy(KNEEL, {
	LowerTorso = root(-1.84, 0.24, -27),
	UpperTorso = CFrame.Angles(rad(-20), 0, 0),
	Head = CFrame.Angles(rad(-29), 0, 0),
	RightUpperArm = CFrame.Angles(rad(53), 0, rad(-13)),
	LeftUpperArm = CFrame.Angles(rad(53), 0, rad(13)),
})

-- 0.55s per cycle is about 110 compressions a minute, the real rate, and it reads as urgent on screen.
local cpr = fresh("CPR_Loop", Enum.AnimationPriority.Action, true)
keyframe(cpr, 0.00, KNEEL)
keyframe(cpr, 0.14, PRESS, "Beat")
keyframe(cpr, 0.30, KNEEL)
keyframe(cpr, 0.55, KNEEL)

--------------------------------------------------------------------------------
-- Carry_Held
--------------------------------------------------------------------------------

-- Riding on the carrier's back: knees up and gripping the carrier's waist, arms over the shoulders and joined
-- in front. The Motor6D holds the body in place, so this pose only has to make the limbs wrap correctly.
local HELD = {
	LowerTorso = root(0, 0, -10),
	UpperTorso = CFrame.Angles(rad(-12), 0, 0),
	Head = CFrame.Angles(rad(-8), rad(14), 0), -- head lolls to one side; this player is unconscious
	RightUpperArm = CFrame.Angles(rad(112), 0, rad(-9)),
	RightLowerArm = CFrame.Angles(rad(24), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(112), 0, rad(9)),
	LeftLowerArm = CFrame.Angles(rad(24), 0, 0),
	RightUpperLeg = CFrame.Angles(rad(78), 0, rad(17)),
	RightLowerLeg = CFrame.Angles(rad(-84), 0, 0),
	RightFoot = CFrame.Angles(rad(-10), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(78), 0, rad(-17)),
	LeftLowerLeg = CFrame.Angles(rad(-84), 0, 0),
	LeftFoot = CFrame.Angles(rad(-10), 0, 0),
}

-- Slow, and only a few degrees: a limp body jostled by someone else's walking, not a body doing anything.
local held = fresh("Carry_Held", Enum.AnimationPriority.Action, true)
keyframe(held, 0.00, HELD)
keyframe(held, 1.20, copy(HELD, {
	Head = CFrame.Angles(rad(-11), rad(10), rad(4)),
	RightUpperArm = CFrame.Angles(rad(108), 0, rad(-9)),
	LeftUpperArm = CFrame.Angles(rad(115), 0, rad(9)),
	RightLowerLeg = CFrame.Angles(rad(-80), 0, 0),
}))
keyframe(held, 2.40, HELD)

--------------------------------------------------------------------------------
-- Carry_Holder
--------------------------------------------------------------------------------

-- Arms swept back and forearms hooked up to cradle the passenger's thighs, torso leaning forward under the
-- weight. No leg poses at all, so whatever the player is doing with their legs — walk, run, idle — keeps
-- playing underneath and the carrier still moves normally.
local HOLDER = {
	UpperTorso = CFrame.Angles(rad(-13), 0, 0),
	RightUpperArm = CFrame.Angles(rad(-34), 0, rad(25)),
	RightLowerArm = CFrame.Angles(rad(64), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(-34), 0, rad(-25)),
	LeftLowerArm = CFrame.Angles(rad(64), 0, 0),
}

local holder = fresh("Carry_Holder", Enum.AnimationPriority.Action, true)
keyframe(holder, 0.00, HOLDER)
keyframe(holder, 0.90, copy(HOLDER, {
	UpperTorso = CFrame.Angles(rad(-16), 0, rad(2)),
	RightLowerArm = CFrame.Angles(rad(68), 0, 0),
	LeftLowerArm = CFrame.Angles(rad(61), 0, 0),
}))
keyframe(holder, 1.80, HOLDER)

--------------------------------------------------------------------------------

local out = {}
for _, name in ipairs({ "CPR_Loop", "Carry_Held", "Carry_Holder" }) do
	local seq = folder:FindFirstChild(name)
	local kfs = 0
	for _, k in ipairs(seq:GetChildren()) do
		if k:IsA("Keyframe") then kfs += 1 end
	end
	table.insert(out, ("%s(kf=%d, loop=%s)"):format(name, kfs, tostring(seq.Loop)))
end
return table.concat(out, " | ")
