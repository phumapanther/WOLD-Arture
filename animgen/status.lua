-- animgen/status.lua — the status-effect poses. Right now that is one: Dizzy_Loop.
--
-- Same pipeline as the others: build the instance tree from code, then in Studio right-click the sequence in
-- ServerStorage.WOLD_Animations and pick "Save to Roblox" to publish it and get a real Animation ID.
--
--   node tools/run-luau.js animgen/status.lua --no-lib
--   node tools/preview-anim.js animgen/status.lua Dizzy_Loop        (needs Play mode)
--
-- Dizzy_Loop — both hands clamped to the sides of the head, head hanging, and the whole body rolling slowly
-- from one side to the other like someone who cannot find the floor. Looped, because the spell lasts as long
-- as the effect does and the code has no idea how long that will be.
--
-- The arm angles are NOT guesses. A stock R15 rig was built in Studio and its joint chain walked by hand --
-- a part sits at parent * C0 * Transform * inverse(C1) -- to find which shoulder and elbow angles actually
-- land a hand beside the head. Measured result: shoulder pitched back 125 degrees and swung out 90, elbow
-- folded 130, puts the hand 0.80 studs to the side of the head and level with it. Guessing at R15's
-- handedness is exactly how an arm ends up inside a chest.
local ServerStorage = game:GetService("ServerStorage")

local rad = math.rad

-- R15 joint tree. Every pose has to sit under its parent joint's pose or the engine ignores it. Duplicated
-- from the other animgen files on purpose: run-luau.js pushes one standalone chunk into Studio, so there is
-- no module to require.
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

-- Only clear what this file owns; wiping the folder would take the combat, movement and revive sequences.
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

-- The LowerTorso pose is the RootJoint: it rotates the whole VISIBLE body around the root part while the
-- humanoid underneath stays upright and keeps colliding normally. The roll is the sway.
local function root(roll, pitch, dy)
	return CFrame.new(0, dy or 0, 0) * CFrame.Angles(rad(pitch or 0), 0, rad(roll or 0))
end

--------------------------------------------------------------------------------
-- Dizzy_Loop
--------------------------------------------------------------------------------

-- Hands to the head, and there they stay for the whole loop. Only the sway moves, which is what makes it
-- read as "cannot stand up straight" rather than as a set of gestures.
local HOLD = {
	UpperTorso = CFrame.Angles(rad(-6), 0, 0), -- shoulders hunched a little
	Head = CFrame.Angles(rad(14), 0, 0),       -- chin down
	RightUpperArm = CFrame.Angles(rad(-125), 0, rad(-90)),
	RightLowerArm = CFrame.Angles(rad(-130), 0, 0),
	RightHand = CFrame.Angles(rad(10), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(-125), 0, rad(90)),
	LeftLowerArm = CFrame.Angles(rad(-130), 0, 0),
	LeftHand = CFrame.Angles(rad(10), 0, 0),
}

local dizzy = fresh("Dizzy_Loop", Enum.AnimationPriority.Action, true)

-- Two seconds for a full left-right-left, which is slow enough to read as unsteady rather than as shivering.
-- The pose at 2.00 is the pose at 0.00, or the loop jumps on every repeat.
--
-- The head counter-rolls slightly against the body: a head that rolls WITH the torso looks like a plank
-- tipping over, while one that lags behind looks like it is being held on.
keyframe(dizzy, 0.00, copy(HOLD, {
	LowerTorso = root(8, 4, -0.06),
	Head = CFrame.Angles(rad(14), 0, rad(-4)),
}))
keyframe(dizzy, 0.50, copy(HOLD, {
	LowerTorso = root(0, 7, -0.12), -- lowest point of the sway, folded forward most
	Head = CFrame.Angles(rad(18), 0, 0),
}))
keyframe(dizzy, 1.00, copy(HOLD, {
	LowerTorso = root(-8, 4, -0.06),
	Head = CFrame.Angles(rad(14), 0, rad(4)),
}))
keyframe(dizzy, 1.50, copy(HOLD, {
	LowerTorso = root(0, 7, -0.12),
	Head = CFrame.Angles(rad(18), 0, 0),
}))
keyframe(dizzy, 2.00, copy(HOLD, {
	LowerTorso = root(8, 4, -0.06),
	Head = CFrame.Angles(rad(14), 0, rad(-4)),
}))

print("[animgen/status] Dizzy_Loop built in ServerStorage.WOLD_Animations")
print("  publish it: right-click the sequence -> Save to Roblox (as the account that owns the place),")
print("  then paste the id into StatusConfig.DizzyAnimation")
