-- animgen/sword.lua — builds the sword hold and the 4-stage swing into ServerStorage.WOLD_Animations.
--
-- Run with:  node tools/run-luau.js animgen/sword.lua --no-lib
-- Preview:   node tools/preview-anim.js animgen/sword.lua Sword_Slash --speed 0.3
--
-- Built from the user's stage-by-stage spec: wind-up 0.18s, strike 0.06s, follow-through 0.12s, recovery
-- 0.30s, with HitStart/HitEnd markers on the strike so the hitbox and the blade trail are driven by the
-- animation instead of by task.wait() guesses. The structure, the timings and the marker plan are used exactly
-- as written. Three things had to change to survive contact with the actual R15 rig, all of them mechanical:
--
-- 1. POSES ARE NAMED AFTER PARTS, NOT JOINTS. A Pose called "RightShoulder" does nothing; the pose that drives
--    the RightShoulder Motor6D is named "RightUpperArm". Elbow -> RightLowerArm, wrist -> RightHand, waist ->
--    UpperTorso, root -> LowerTorso. The spec's joint names are mapped that way throughout.
--
-- 2. THE X SIGNS ARE INVERTED FOR THIS RIG. The spec is self-consistent (X+ = lean forward, elbow bend
--    negative) but R15 runs the other way, which is checkable against the punches already published from
--    animgen/combat.lua: Combat_Guard leans into its stance with waist X = -4, and Punch_Right extends the arm
--    with elbow X = +4 (straight) out of a guard at +105 (folded). So on this rig X+ leans the torso BACK,
--    X+ swings a hanging arm FORWARD, and elbows and knees bend POSITIVE and NEGATIVE respectively. Every X in
--    the spec is negated here; Y and Z were already right (Y- turns right, and the spec's Y- for the wind-up
--    is a right turn). Forward is -Z, so the strike's "+0.2 studs forward" is -0.2 here.
--
-- 3. POSES COMPOSE WITH THEIR PARENT, SO ANGLES ADD. The spec puts Y = 65 on both LowerTorso and UpperTorso in
--    the follow-through; because UpperTorso hangs off LowerTorso that would be 130 degrees of twist. The
--    rotation is split across the two joints instead so the total reads as the intended maximum.
--
-- Also worth knowing: Enum.PoseEasingStyle offers only Linear, Constant, Cubic, Elastic and Bounce. Back, Sine,
-- Quad and Exponential exist in TweenService, not in KeyframeSequences. The spec's easings map to the nearest
-- real ones: Back(In) -> Cubic In, Exponential(Out) -> Linear (the spec's own second choice, and the right one
-- for a strike that should not decelerate), Sine(Out) -> Cubic Out, Cubic(InOut) -> Cubic InOut unchanged.

local ServerStorage = game:GetService("ServerStorage")

local rad = math.rad

-- Combat_Guard leaves the legs unposed so the default walk keeps driving them and the player can still move
-- while guarding. The sword hold has the same problem and the same fix, so the spec's leg stance (feet apart,
-- knees softened) is off by default: with it on, a player holding a sword slides around on locked legs. Flip
-- this to true for a stationary stance — for a cutscene, or once a "planted" stance has its own state.
local INCLUDE_LEG_STANCE = false

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

-- opts.easing / opts.direction set how the engine interpolates INTO this keyframe; opts.marker adds a
-- KeyframeMarker for GetMarkerReachedSignal.
local function keyframe(seq, time, poses, opts)
	opts = opts or {}
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
		p.EasingStyle = opts.easing or Enum.PoseEasingStyle.Cubic
		p.EasingDirection = opts.direction or Enum.PoseEasingDirection.Out
		p.Parent = (name == "HumanoidRootPart") and kf or ensure(PARENT[name])
		made[name] = p
		return p
	end
	ensure("HumanoidRootPart")
	for name in pairs(poses) do
		if name ~= "HumanoidRootPart" then ensure(name) end
	end

	if opts.marker then
		local m = Instance.new("KeyframeMarker")
		m.Name = opts.marker
		m.Parent = kf
	end

	kf.Parent = seq
	return kf
end

local function merge(...)
	local out = {}
	for _, t in ipairs({ ... }) do
		for k, v in pairs(t) do out[k] = v end
	end
	return out
end

local function root(dy, dz, yaw)
	return CFrame.new(0, dy or 0, dz or 0) * CFrame.Angles(0, rad(yaw or 0), 0)
end

local CUBIC_IN = { easing = Enum.PoseEasingStyle.Cubic, direction = Enum.PoseEasingDirection.In }
local CUBIC_OUT = { easing = Enum.PoseEasingStyle.Cubic, direction = Enum.PoseEasingDirection.Out }
local CUBIC_INOUT = { easing = Enum.PoseEasingStyle.Cubic, direction = Enum.PoseEasingDirection.InOut }

--------------------------------------------------------------------------------
-- Sword_Idle — the held stance
--------------------------------------------------------------------------------

-- Bladed stance: the body turned slightly right so the sword side trails, right hand on the grip at waist
-- height, left hand up at the chest for balance, blade angled up about 45 degrees rather than straight up.
local HOLD = {
	LowerTorso = root(-0.15, 0, -12),
	UpperTorso = CFrame.Angles(rad(-4), rad(-10), 0),
	Head = CFrame.Angles(0, rad(22), 0), -- eyes stay forward even though the torso is turned
	RightUpperArm = CFrame.Angles(rad(26), 0, rad(14)),
	RightLowerArm = CFrame.Angles(rad(72), 0, 0),
	RightHand = CFrame.Angles(0, 0, rad(-10)),
	LeftUpperArm = CFrame.Angles(rad(36), 0, rad(-26)),
	LeftLowerArm = CFrame.Angles(rad(84), 0, 0),
}

local STANCE_LEGS = {
	RightUpperLeg = CFrame.Angles(rad(-8), rad(-14), rad(6)),
	RightLowerLeg = CFrame.Angles(rad(-12), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(6), rad(-6), rad(-6)),
	LeftLowerLeg = CFrame.Angles(rad(-9), 0, 0),
}
if INCLUDE_LEG_STANCE then HOLD = merge(HOLD, STANCE_LEGS) end

-- 2.4s breathing loop: chest and blade rise about 0.1 studs and settle. Cubic InOut both ways, which is what
-- keeps a held pose from looking like it is being stepped between two states.
local idle = fresh("Sword_Idle", Enum.AnimationPriority.Action, true)
keyframe(idle, 0.00, HOLD, CUBIC_INOUT)
keyframe(idle, 1.20, merge(HOLD, {
	LowerTorso = root(-0.05, 0, -12), -- the 0.1 stud rise
	UpperTorso = CFrame.Angles(rad(-2), rad(-10), 0),
	RightUpperArm = CFrame.Angles(rad(29), 0, rad(14)),
	RightLowerArm = CFrame.Angles(rad(75), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(39), 0, rad(-26)),
}), CUBIC_INOUT)
keyframe(idle, 2.40, HOLD, CUBIC_INOUT)

--------------------------------------------------------------------------------
-- Sword_Slash — wind-up, strike, follow-through, recovery
--------------------------------------------------------------------------------

-- Stage 1 (0.18s, Cubic In): the whole body coils right and drops, sword cocked back over the right shoulder.
-- The Cubic In is what makes it read as compression rather than as drifting into position.
local WINDUP = {
	LowerTorso = root(-0.30, 0, -25),
	UpperTorso = CFrame.Angles(rad(10), rad(-35), 0), -- leaning back, twisted away from the target
	Head = CFrame.Angles(0, rad(30), 0), -- eyes stay on the target while the torso turns off it
	RightUpperArm = CFrame.Angles(rad(-110), rad(25), rad(22)), -- up and behind the shoulder
	RightLowerArm = CFrame.Angles(rad(75), 0, 0), -- elbow folded, blade dropped behind the back
	RightHand = CFrame.Angles(rad(30), 0, 0), -- wrist cocked
	LeftUpperArm = CFrame.Angles(rad(45), 0, rad(-40)), -- counterweight up at the chest
	LeftLowerArm = CFrame.Angles(rad(80), 0, 0),
	RightUpperLeg = CFrame.Angles(rad(-12), rad(-15), 0), -- rear leg loaded
	RightLowerLeg = CFrame.Angles(rad(-20), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(12), rad(-8), 0), -- front foot planted
	LeftLowerLeg = CFrame.Angles(rad(-12), 0, 0),
}

-- Stage 2 (0.06s, Linear): the fastest thing in the animation. Linear on purpose — any ease-out here bleeds
-- speed out of exactly the frames that sell the cut. Diagonal down-left: the arm swings forward and across
-- the body while the waist snaps back the other way.
local STRIKE = {
	LowerTorso = root(-0.15, -0.20, 40), -- driving forward (-Z is forward) and snapping left
	UpperTorso = CFrame.Angles(rad(-15), rad(50), 0), -- folding forward over the cut
	Head = CFrame.Angles(rad(-12), rad(-18), 0), -- looking down the line of the blade
	RightUpperArm = CFrame.Angles(rad(45), rad(-20), rad(-45)), -- forward and cutting across to the left
	RightLowerArm = CFrame.Angles(rad(10), 0, 0), -- elbow snapped straight for maximum reach
	RightHand = CFrame.Angles(rad(35), 0, 0), -- wrist flicks through the cut
	LeftUpperArm = CFrame.Angles(rad(-40), 0, rad(-20)), -- thrown back to counter the swing
	LeftLowerArm = CFrame.Angles(rad(30), 0, 0),
	RightUpperLeg = CFrame.Angles(rad(-20), rad(-10), 0), -- rear leg extends, driving the hips through
	RightLowerLeg = CFrame.Angles(rad(-5), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(20), 0, 0), -- front knee takes the weight
	LeftLowerLeg = CFrame.Angles(rad(-35), 0, 0),
}

-- Stage 3 (0.12s, Cubic Out): nothing stops at the impact point. The blade runs out to the left hip and the
-- shoulders keep turning after it, decelerating.
local FOLLOW = {
	LowerTorso = root(-0.20, -0.10, 55),
	UpperTorso = CFrame.Angles(rad(-20), rad(25), 0), -- split with the root: 80 degrees of twist in total
	Head = CFrame.Angles(rad(-10), rad(-30), 0),
	RightUpperArm = CFrame.Angles(rad(25), rad(-35), rad(-72)), -- swept low across to the left hip
	RightLowerArm = CFrame.Angles(rad(30), 0, 0), -- elbow folds back up as the swing bleeds off
	RightHand = CFrame.Angles(0, 0, rad(-25)), -- wrist rolls after the blade
	LeftUpperArm = CFrame.Angles(rad(-50), 0, rad(-28)),
	LeftLowerArm = CFrame.Angles(rad(35), 0, 0),
	RightUpperLeg = CFrame.Angles(rad(-16), rad(-6), 0),
	RightLowerLeg = CFrame.Angles(rad(-10), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(16), 0, 0),
	LeftLowerLeg = CFrame.Angles(rad(-28), 0, 0),
}

local slash = fresh("Sword_Slash", Enum.AnimationPriority.Action4, false)

-- Stage 4 is the return to HOLD: recovering into the held stance rather than to a neutral rig is what lets the
-- next click start from a real position, and what makes the slash blend back under Sword_Idle cleanly.
-- The legs are posed here even though HOLD leaves them free — a 0.66s Action4 clip owns the whole body for its
-- duration and then hands the legs back.
local RECOVER = merge(HOLD, STANCE_LEGS)

keyframe(slash, 0.00, RECOVER, CUBIC_OUT)
keyframe(slash, 0.18, WINDUP, CUBIC_IN)
keyframe(slash, 0.24, STRIKE, { easing = Enum.PoseEasingStyle.Linear, direction = Enum.PoseEasingDirection.InOut, marker = "HitStart" })
keyframe(slash, 0.36, FOLLOW, { easing = Enum.PoseEasingStyle.Cubic, direction = Enum.PoseEasingDirection.Out, marker = "HitEnd" })
keyframe(slash, 0.66, RECOVER, CUBIC_INOUT)

--------------------------------------------------------------------------------

local out = {}
for _, name in ipairs({ "Sword_Idle", "Sword_Slash" }) do
	local seq = folder:FindFirstChild(name)
	local kfs, markers = 0, {}
	for _, k in ipairs(seq:GetChildren()) do
		if k:IsA("Keyframe") then
			kfs += 1
			for _, m in ipairs(k:GetChildren()) do
				if m:IsA("KeyframeMarker") then table.insert(markers, m.Name) end
			end
		end
	end
	table.insert(out, ("%s(kf=%d, loop=%s%s)"):format(name, kfs, tostring(seq.Loop),
		#markers > 0 and (", markers=" .. table.concat(markers, "/")) or ""))
end
return table.concat(out, " | ")
