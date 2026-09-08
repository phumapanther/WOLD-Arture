-- animgen/movement.lua — builds the roll and slide KeyframeSequences into ServerStorage.WOLD_Animations.
--
-- Same pipeline as animgen/combat.lua: a KeyframeSequence is just an instance tree, so it can be built from
-- code even though the Animation Editor is a GUI that MCP cannot drive. Run this, then in Studio right-click
-- each sequence and pick "Save to Roblox" to publish it and get a real Animation ID.
--
-- Run with:  node tools/run-luau.js animgen/movement.lua --no-lib
--
-- The two moves, as the user described them:
--   Roll_Forward — drop into a very deep knee bend with the chest folded down almost onto the thighs, then
--   tumble one full forward revolution and come back up on the feet.
--   Slide_Enter / Slide_Hold — recline back until the body sits about 45 degrees off the ground, one knee
--   drawn up and bent, the other leg stretched straight out, both arms spread wide, and the whole body
--   rolled slightly onto the side of the bent leg.
--
-- IMPORTANT — neither animation moves the character. Roblox has no root motion: a KeyframeSequence only poses
-- the rig, so the actual travel must come from code (velocity on the root part) with Humanoid.AutoRotate off.
-- The animation just makes that travel look like a roll or a slide.

local ServerStorage = game:GetService("ServerStorage")

local rad = math.rad

-- R15 joint tree. Every pose has to sit under its parent joint's pose or the engine ignores it, so the builder
-- below walks this table to create the ancestors it needs. A joint with NO pose is left to whatever other track
-- owns it — that is how Combat_Guard keeps the default walk driving the legs, and why Carry_Holder in
-- animgen/revive.lua lists no leg joints. Both files carry their own copy of this helper because run-luau.js
-- pushes a single standalone chunk into Studio; there is no module to require.
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

-- Only clear what this file owns. Wiping the whole folder would take the combat sequences with it, and a
-- sequence that has not been published yet is unrecoverable.
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

-- opts.easing / opts.direction control how the engine interpolates INTO this keyframe. The spin keyframes use
-- Linear: with the default Cubic-Out every 90-degree step would decelerate on its own and the roll would read
-- as four separate lurches instead of one continuous tumble.
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

	kf.Parent = seq
	return kf
end

local function copy(t, overrides)
	local out = {}
	for k, v in pairs(t) do out[k] = v end
	for k, v in pairs(overrides or {}) do out[k] = v end
	return out
end

-- The LowerTorso pose is the RootJoint, so it rotates and offsets the whole visible body around the root
-- part's centre. Dropping it is how a roll or slide gets down to the deck without touching HipHeight: the
-- humanoid keeps standing upright and colliding normally, only the rig you see moves. Pitch is negative for
-- a forward tumble (a positive X rotation leans a torso back), roll is positive toward the character's left.
local function root(dy, dz, pitch, roll)
	return CFrame.new(0, dy or 0, dz or 0) * CFrame.Angles(rad(pitch or 0), 0, rad(roll or 0))
end

--------------------------------------------------------------------------------
-- Roll_Forward
--------------------------------------------------------------------------------

-- Deep crouch on the feet: knees folded hard, heels off the ground, chest down near the thighs. This is the
-- shape the roll enters from and lands back into.
local CROUCH = {
	LowerTorso = root(-1.30, 0.10, 0, 0),
	UpperTorso = CFrame.Angles(rad(-52), 0, 0),
	Head = CFrame.Angles(rad(-14), 0, 0),
	RightUpperArm = CFrame.Angles(rad(70), 0, rad(12)),
	RightLowerArm = CFrame.Angles(rad(48), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(70), 0, rad(-12)),
	LeftLowerArm = CFrame.Angles(rad(48), 0, 0),
	RightUpperLeg = CFrame.Angles(rad(74), 0, rad(7)),
	RightLowerLeg = CFrame.Angles(rad(-126), 0, 0),
	RightFoot = CFrame.Angles(rad(-38), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(74), 0, rad(-7)),
	LeftLowerLeg = CFrame.Angles(rad(-126), 0, 0),
	LeftFoot = CFrame.Angles(rad(-38), 0, 0),
}

-- The ball the body holds all the way through the spin: knees pulled into the chest, chin tucked, arms
-- wrapped in. Radius matters — anything sticking out clips the floor when the body passes upside down.
local BALL = {
	UpperTorso = CFrame.Angles(rad(-44), 0, 0),
	Head = CFrame.Angles(rad(-32), 0, 0),
	RightUpperArm = CFrame.Angles(rad(64), 0, rad(16)),
	RightLowerArm = CFrame.Angles(rad(126), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(64), 0, rad(-16)),
	LeftLowerArm = CFrame.Angles(rad(126), 0, 0),
	RightUpperLeg = CFrame.Angles(rad(100), 0, rad(8)),
	RightLowerLeg = CFrame.Angles(rad(-134), 0, 0),
	RightFoot = CFrame.Angles(rad(-30), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(100), 0, rad(-8)),
	LeftLowerLeg = CFrame.Angles(rad(-134), 0, 0),
	LeftFoot = CFrame.Angles(rad(-30), 0, 0),
}

local roll = fresh("Roll_Forward", Enum.AnimationPriority.Action3, false)
local LINEAR = { easing = Enum.PoseEasingStyle.Linear, direction = Enum.PoseEasingDirection.InOut }

-- Dip, then one revolution in four 90-degree steps, then back onto the feet. The steps must be 90 degrees:
-- the engine lerps a pose along the shortest arc, so a single 0 -> -360 keyframe would not rotate at all and
-- a 180-degree step would pick its direction at random.
keyframe(roll, 0.00, { LowerTorso = root(-0.25, 0, 0, 0) })
keyframe(roll, 0.10, CROUCH)
keyframe(roll, 0.20, copy(BALL, { LowerTorso = root(-1.50, -0.10, -90, 0) }), LINEAR)
keyframe(roll, 0.30, copy(BALL, { LowerTorso = root(-1.45, 0, -180, 0) }), LINEAR)
keyframe(roll, 0.40, copy(BALL, { LowerTorso = root(-1.50, 0.10, -270, 0) }), LINEAR)
keyframe(roll, 0.50, copy(CROUCH, { LowerTorso = root(-1.35, 0.05, -360, 0) }), LINEAR)
keyframe(roll, 0.66, { LowerTorso = root(-0.15, 0, 0, 0) })

--------------------------------------------------------------------------------
-- Slide_Enter / Slide_Hold
--------------------------------------------------------------------------------

-- Flip this to "right" to mirror the whole slide; nothing else in the file needs to change.
local BENT_SIDE = "left"

local bent, straight = "Left", "Right"
if BENT_SIDE == "right" then bent, straight = "Right", "Left" end
local lean = (BENT_SIDE == "left") and 1 or -1 -- roll onto the side of the bent leg

-- Reclined about 45 degrees off the ground, hips dropped and shifted back, rolled toward the bent knee.
local SLIDE = {
	LowerTorso = root(-1.50, 0.35, 45, 16 * lean),
	UpperTorso = CFrame.Angles(rad(-6), 0, rad(7 * lean)),
	Head = CFrame.Angles(rad(-40), rad(-6 * lean), 0), -- chin down so the player still faces where they slide
	-- bent leg: drawn up with the knee cocked
	[bent .. "UpperLeg"] = CFrame.Angles(rad(58), 0, rad(-11 * lean)),
	[bent .. "LowerLeg"] = CFrame.Angles(rad(-76), 0, 0),
	[bent .. "Foot"] = CFrame.Angles(rad(-12), 0, 0),
	-- trailing leg: stretched straight out ahead
	[straight .. "UpperLeg"] = CFrame.Angles(rad(42), 0, rad(7 * lean)),
	[straight .. "LowerLeg"] = CFrame.Angles(rad(-5), 0, 0),
	[straight .. "Foot"] = CFrame.Angles(rad(16), 0, 0),
	-- both arms flung wide for balance
	RightUpperArm = CFrame.Angles(rad(-16), 0, rad(74)),
	RightLowerArm = CFrame.Angles(rad(14), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(-16), 0, rad(-74)),
	LeftLowerArm = CFrame.Angles(rad(14), 0, 0),
}

-- Enter overshoots slightly lower and flatter than the hold, so the drop into the slide has some weight.
local enter = fresh("Slide_Enter", Enum.AnimationPriority.Action2, false)
keyframe(enter, 0.00, { LowerTorso = root(-0.20, 0, 6, 0) })
keyframe(enter, 0.14, copy(SLIDE, {
	LowerTorso = root(-1.62, 0.45, 38, 20 * lean),
	RightUpperArm = CFrame.Angles(rad(-24), 0, rad(80)),
	LeftUpperArm = CFrame.Angles(rad(-24), 0, rad(-80)),
}))
keyframe(enter, 0.26, SLIDE)

-- Hold loops so a long slide never freezes: a slow drift in the arms and the cocked knee, nothing more.
local hold = fresh("Slide_Hold", Enum.AnimationPriority.Action2, true)
keyframe(hold, 0.00, SLIDE)
keyframe(hold, 0.45, copy(SLIDE, {
	[bent .. "LowerLeg"] = CFrame.Angles(rad(-70), 0, 0),
	RightUpperArm = CFrame.Angles(rad(-12), 0, rad(70)),
	LeftUpperArm = CFrame.Angles(rad(-20), 0, rad(-77)),
	Head = CFrame.Angles(rad(-37), rad(-6 * lean), 0),
}))
keyframe(hold, 0.90, SLIDE)

--------------------------------------------------------------------------------

local out = {}
for _, name in ipairs({ "Roll_Forward", "Slide_Enter", "Slide_Hold" }) do
	local seq = folder:FindFirstChild(name)
	local kfs = 0
	for _, k in ipairs(seq:GetChildren()) do
		if k:IsA("Keyframe") then kfs += 1 end
	end
	table.insert(out, ("%s(kf=%d, loop=%s)"):format(name, kfs, tostring(seq.Loop)))
end
return table.concat(out, " | ")
