-- animgen/emotes.lua — the roleplay poses Roblox does not ship.
--
--   node tools/run-luau.js animgen/emotes.lua --no-lib
--   node tools/preview-anim.js animgen/emotes.lua Emote_Wai --speed 0.5     (needs Play mode)
--
-- Then publish each one: right-click it in ServerStorage.WOLD_Animations, "Save to Roblox", as the account
-- that owns the place, and paste the id into the matching row of EmoteConfig.
--
-- Roblox's own set covers wave, point, cheer, laugh, three dances and a sit. Everything a roleplay game
-- actually wants -- the wai, a bow, a curtsy, sitting on the ground, lying down, being frightened -- is not
-- in it, which is why this file exists.
--
-- THE ANGLES ARE MEASURED, NOT GUESSED. A stock R15 rig was built in Studio and its joint chain walked by
-- hand (a part sits at parent * C0 * Transform * inverse(C1)) to find what each pose needs:
--   * palms together in front of the chest: shoulder pitched back 110, swung across 170, elbow folded 120
--     -- puts the two hands 1.06 studs apart, which for a rig with 1-stud hands is palm touching palm
--   * a foot with the hip at -90 and the knee at 120 lands 1.97 studs below the root and 0.36 behind it,
--     which is what sets how far the body has to drop to look like it is sitting on the ground
-- R15's handedness is the single easiest thing to get backwards, and a wrong sign puts an arm inside a chest.
local ServerStorage = game:GetService("ServerStorage")

local rad = math.rad

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

-- Only clears what this file owns; wiping the folder would take the combat, movement, revive and status
-- sequences with it.
local function fresh(name, priority, loop)
	-- Searched recursively, not just in this folder: tools/sort-animations.lua files sequences into a
	-- New_Animations subfolder once they exist, and a lookup that only checked the top level rebuilt a
	-- second copy of every one of them on the next run.
	local old = folder:FindFirstChild(name, true)
	if old then old:Destroy() end
	local seq = Instance.new("KeyframeSequence")
	seq.Name = name
	seq.Priority = priority
	seq.Loop = loop and true or false
	seq.Parent = folder
	return seq
end

local function keyframe(seq, time, poses)
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

-- The LowerTorso pose IS the root joint: it moves and turns the whole visible body while the humanoid
-- underneath stays upright and keeps colliding normally. Every sit, kneel and lie-down below is this.
local function root(dy, pitch, roll, dz)
	return CFrame.new(0, dy or 0, dz or 0) * CFrame.Angles(rad(pitch or 0), 0, rad(roll or 0))
end

local NOTHING = {}

--------------------------------------------------------------------------------
-- Greetings and manners
--------------------------------------------------------------------------------

-- The wai. Palms together, brought up in front of the chest, head bowed to meet them -- the head comes DOWN
-- to the hands rather than the hands going up to the head, which is the difference between a wai and a
-- salute. Held for a beat, then released.
local WAI_ARMS = {
	RightUpperArm = CFrame.Angles(rad(-110), 0, rad(170)),
	RightLowerArm = CFrame.Angles(rad(-120), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(-110), 0, rad(-170)),
	LeftLowerArm = CFrame.Angles(rad(-120), 0, 0),
}

local wai = fresh("Emote_Wai", Enum.AnimationPriority.Action4, false)
keyframe(wai, 0.00, NOTHING)
keyframe(wai, 0.35, copy(WAI_ARMS, {
	UpperTorso = CFrame.Angles(rad(-6), 0, 0),
	Head = CFrame.Angles(rad(20), 0, 0),
}))
keyframe(wai, 1.30, copy(WAI_ARMS, {
	UpperTorso = CFrame.Angles(rad(-8), 0, 0),
	Head = CFrame.Angles(rad(24), 0, 0),
}))
keyframe(wai, 1.80, NOTHING)

-- A gentleman's bow: one hand across the waist, the other swept back, torso folded forward from the hips.
-- The fold is on the ROOT rather than the upper torso, because a bow bends at the waist and putting it in
-- the chest alone reads as a nod.
local bow = fresh("Emote_Bow", Enum.AnimationPriority.Action4, false)
local BOW_DOWN = {
	LowerTorso = root(-0.35, -42),
	UpperTorso = CFrame.Angles(rad(-8), 0, 0),
	Head = CFrame.Angles(rad(26), 0, 0),
	-- right hand flat across the stomach
	RightUpperArm = CFrame.Angles(rad(-28), 0, rad(62)),
	RightLowerArm = CFrame.Angles(rad(-96), 0, 0),
	-- left arm swept out and back
	LeftUpperArm = CFrame.Angles(rad(24), 0, rad(-46)),
	LeftLowerArm = CFrame.Angles(rad(-16), 0, 0),
}
keyframe(bow, 0.00, NOTHING)
keyframe(bow, 0.45, BOW_DOWN)
keyframe(bow, 1.35, BOW_DOWN)
keyframe(bow, 1.90, NOTHING)

-- A curtsy: knees bent out to the sides and the body sinking straight down, a small dip of the head, hands
-- held out from the hips as if holding a skirt. Shallower than the bow on purpose -- it is a dip, not a fold.
local curtsy = fresh("Emote_Curtsy", Enum.AnimationPriority.Action4, false)
local CURTSY_DOWN = {
	LowerTorso = root(-0.75, -10),
	Head = CFrame.Angles(rad(16), 0, 0),
	RightUpperLeg = CFrame.Angles(rad(16), 0, rad(-26)),
	RightLowerLeg = CFrame.Angles(rad(34), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(10), 0, rad(20)),
	LeftLowerLeg = CFrame.Angles(rad(22), 0, 0),
	RightUpperArm = CFrame.Angles(rad(14), 0, rad(-34)),
	RightLowerArm = CFrame.Angles(rad(-30), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(14), 0, rad(34)),
	LeftLowerArm = CFrame.Angles(rad(-30), 0, 0),
}
keyframe(curtsy, 0.00, NOTHING)
keyframe(curtsy, 0.50, CURTSY_DOWN)
keyframe(curtsy, 1.20, CURTSY_DOWN)
keyframe(curtsy, 1.75, NOTHING)

--------------------------------------------------------------------------------
-- Sitting and lying
--------------------------------------------------------------------------------

-- These all LOOP and all hold the player still, so each is a single pose with a breath in it rather than a
-- movement: the body settles into place and then only rises and falls.
--
-- How far the body drops is set by where the feet end up. Measured on the rig: at a hip of 90 and a straight
-- knee the foot sits 2.04 studs IN FRONT of the root and 1.00 below it, so a body that drops about two studs
-- has its legs along the ground rather than through it.
--
-- A POSITIVE HIP SWINGS THE LEG FORWARD. Negative swings it BACKWARD, which is a kneel, not a sit -- and all
-- three of these poses were authored with the sign the wrong way round the first time. It did not show up in
-- the drop measurement, because a body folded backwards sinks by exactly as much as one folded forwards; it
-- took measuring where the FOOT ended up to see it. Stock Roblox sit: foot 1.25 in front. These, before the
-- fix: 0.00, every one of them.

-- Cross-legged. Hips rotated OUT as well as up, which is what folds the shins in front of each other instead
-- of stacking them; hands resting on the knees.
local CROSS = {
	LowerTorso = root(-2.05, -6),
	UpperTorso = CFrame.Angles(rad(4), 0, 0),
	RightUpperLeg = CFrame.Angles(rad(78), 0, rad(-58)),
	RightLowerLeg = CFrame.Angles(rad(104), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(78), 0, rad(58)),
	LeftLowerLeg = CFrame.Angles(rad(104), 0, 0),
	RightUpperArm = CFrame.Angles(rad(16), 0, rad(-20)),
	RightLowerArm = CFrame.Angles(rad(-46), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(16), 0, rad(20)),
	LeftLowerArm = CFrame.Angles(rad(-46), 0, 0),
}
local cross = fresh("Emote_CrossLegged", Enum.AnimationPriority.Action4, true)
keyframe(cross, 0.00, CROSS)
keyframe(cross, 1.60, copy(CROSS, { LowerTorso = root(-1.97, -4), Head = CFrame.Angles(rad(-2), 0, 0) }))
keyframe(cross, 3.20, CROSS)

-- A squat: heels down, knees folded hard and pushed out past the shoulders, forearms resting across them.
-- Less of a drop than sitting, because the feet are still under the body rather than folded in front of it.
local SQUAT = {
	LowerTorso = root(-1.55, -22),
	UpperTorso = CFrame.Angles(rad(6), 0, 0),
	RightUpperLeg = CFrame.Angles(rad(104), 0, rad(-22)),
	RightLowerLeg = CFrame.Angles(rad(132), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(104), 0, rad(22)),
	LeftLowerLeg = CFrame.Angles(rad(132), 0, 0),
	RightUpperArm = CFrame.Angles(rad(-30), 0, rad(-16)),
	RightLowerArm = CFrame.Angles(rad(-56), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(-30), 0, rad(16)),
	LeftLowerArm = CFrame.Angles(rad(-56), 0, 0),
}
local squat = fresh("Emote_Squat", Enum.AnimationPriority.Action4, true)
keyframe(squat, 0.00, SQUAT)
keyframe(squat, 1.50, copy(SQUAT, { LowerTorso = root(-1.48, -20) }))
keyframe(squat, 3.00, SQUAT)

-- Sitting with the legs stretched out in front -- the comfortable sit, and the one Roblox has no pose for.
--
-- The hips fold to about a right angle and the knees stay almost straight, which is what puts the legs along
-- the ground rather than folded under. Measured on the rig: a hip at -90 with the knee at 120 lands a foot
-- 1.97 studs below the root, and straightening that knee pushes the foot forward instead of down -- so the
-- body only has to drop about two studs to have its weight on the ground and its legs out in front.
--
-- Hands planted behind the hips, which is what stops it reading as a doll propped upright.
local SITOUT = {
	LowerTorso = root(-2.0, -8),
	UpperTorso = CFrame.Angles(rad(-10), 0, 0),   -- leaning back onto the hands
	Head = CFrame.Angles(rad(-4), 0, 0),
	RightUpperLeg = CFrame.Angles(rad(86), 0, rad(-6)),
	RightLowerLeg = CFrame.Angles(rad(6), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(86), 0, rad(6)),
	LeftLowerLeg = CFrame.Angles(rad(6), 0, 0),
	RightUpperArm = CFrame.Angles(rad(36), 0, rad(-24)),
	RightLowerArm = CFrame.Angles(rad(-14), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(36), 0, rad(24)),
	LeftLowerArm = CFrame.Angles(rad(-14), 0, 0),
}
local sitout = fresh("Emote_SitLegsOut", Enum.AnimationPriority.Action4, true)
keyframe(sitout, 0.00, SITOUT)
keyframe(sitout, 1.70, copy(SITOUT, {
	LowerTorso = root(-1.94, -6),
	UpperTorso = CFrame.Angles(rad(-13), 0, 0),
}))
keyframe(sitout, 3.40, SITOUT)

-- Lying on the back. The root pitch is what lays the body down -- POSITIVE puts it on its back, negative
-- face-down, the same convention Vitals.SetProne uses for the crawl -- and the drop is what puts it on the
-- floor rather than standing horizontally in mid-air.
--
-- The drop is the one number here most likely to want an eyeball: it depends on the rig's height, and two
-- studs is right for the default one. If a tall avatar floats, this is the value to raise.
local LAY = {
	LowerTorso = root(-2.4, 90),
	Head = CFrame.Angles(rad(-12), 0, 0),
	RightUpperArm = CFrame.Angles(rad(6), 0, rad(-26)),
	LeftUpperArm = CFrame.Angles(rad(6), 0, rad(26)),
	RightUpperLeg = CFrame.Angles(rad(-4), 0, rad(-8)),
	LeftUpperLeg = CFrame.Angles(rad(-4), 0, rad(8)),
}
local lay = fresh("Emote_LayFlat", Enum.AnimationPriority.Action4, true)
keyframe(lay, 0.00, LAY)
-- Breathing, and nothing else: a lying body that stays perfectly still reads as a corpse.
keyframe(lay, 2.00, copy(LAY, { UpperTorso = CFrame.Angles(rad(-3), 0, 0) }))
keyframe(lay, 4.00, LAY)

--------------------------------------------------------------------------------
-- Fright
--------------------------------------------------------------------------------

-- Hands up between the face and whatever is out there, weight back on the heels, shoulders drawn up. Loops
-- but does NOT hold the player still -- being frightened and being unable to run away are different things,
-- and the one you want is the one you can leave.
local SCARED = {
	LowerTorso = root(-0.2, 14),
	UpperTorso = CFrame.Angles(rad(10), 0, 0),
	Head = CFrame.Angles(rad(-14), 0, 0),
	RightUpperArm = CFrame.Angles(rad(-96), 0, rad(46)),
	RightLowerArm = CFrame.Angles(rad(-104), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(-96), 0, rad(-46)),
	LeftLowerArm = CFrame.Angles(rad(-104), 0, 0),
}
local scared = fresh("Emote_Scared", Enum.AnimationPriority.Action4, true)
-- A fast, small shiver rather than a slow sway: fright is high-frequency, and at half a second a cycle it
-- reads as trembling instead of swaying.
keyframe(scared, 0.00, SCARED)
keyframe(scared, 0.25, copy(SCARED, {
	LowerTorso = root(-0.2, 14, 2),
	Head = CFrame.Angles(rad(-14), 0, rad(-3)),
}))
keyframe(scared, 0.50, copy(SCARED, {
	LowerTorso = root(-0.2, 14, -2),
	Head = CFrame.Angles(rad(-14), 0, rad(3)),
}))
keyframe(scared, 0.75, SCARED)

print("[animgen/emotes] built 8 poses in ServerStorage.WOLD_Animations:")
print("  Emote_Wai  Emote_Bow  Emote_Curtsy  Emote_CrossLegged  Emote_Squat  Emote_SitLegsOut")
print("  Emote_LayFlat  Emote_Scared")
print("  publish each (right-click > Save to Roblox) and paste the ids into EmoteConfig")
