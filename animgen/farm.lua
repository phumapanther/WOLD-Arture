-- animgen/farm.lua — builds Farm_Search into ServerStorage.WOLD_Animations.
--
-- One looping pose: crouched over something at waist height, both hands working at it. It is played in two
-- places, which is why it is deliberately generic rather than specific to either:
--   * the illegal farms -- rummaging through a crate, working a still, levering a pipe open
--   * a transformer repair -- thirty seconds of hands inside a machine
--
-- Same pipeline as animgen/revive.lua: build the instance tree from code, then in Studio right-click the
-- sequence and pick "Save to Roblox" to publish it. **It must be published from the account that owns the
-- place** or it silently fails to load for everyone else. Paste the returned id into
-- `FarmConfig.SearchAnimation`; an empty id there is safe, the systems simply run without the pose.
--
-- Run with:  node tools/run-luau.js animgen/farm.lua --no-lib
-- Preview without publishing:  node tools/preview-anim.js animgen/farm.lua Farm_Search --speed 0.6
-- (the preview has to be run from inside Play mode -- see CLAUDE.md)

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

-- Only clear what this file owns. Wiping the folder would take the combat, movement and revive sequences
-- with it -- a mistake animgen/combat.lua made once already.
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

-- The LowerTorso pose is the RootJoint: it offsets and rotates the whole VISIBLE body around the root part,
-- so the character can be crouched a stud lower while the humanoid itself keeps standing upright and
-- colliding normally. Nothing here touches HipHeight.
local function root(dy, dz, pitch)
	return CFrame.new(0, dy or 0, dz or 0) * CFrame.Angles(rad(pitch or 0), 0, 0)
end

--------------------------------------------------------------------------------
-- Farm_Search
--------------------------------------------------------------------------------

-- Half-crouched, bent forward over something at about waist height, both arms reaching down and in. The legs
-- ARE posed here, unlike Carry_Holder: this pose is only ever played standing still, so there is no walk
-- animation underneath it that needs the legs left alone.
local CROUCH = {
	LowerTorso = root(-0.85, 0.1, -28),
	UpperTorso = CFrame.Angles(rad(-16), 0, 0),
	Head = CFrame.Angles(rad(-20), 0, 0), -- looking down at the work

	-- Arms forward and down, elbows bent, hands close together in front of the belly. Read together with the
	-- torso's own forward lean, the hands end up at roughly knee height in front, which is where a crate or a
	-- machine's innards are.
	RightUpperArm = CFrame.Angles(rad(58), 0, rad(-14)),
	RightLowerArm = CFrame.Angles(rad(48), 0, 0),
	RightHand = CFrame.Angles(rad(-14), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(58), 0, rad(14)),
	LeftLowerArm = CFrame.Angles(rad(48), 0, 0),
	LeftHand = CFrame.Angles(rad(-14), 0, 0),

	-- Knees bent, feet flat. Slight outward splay so the stance reads as braced rather than as a curtsy.
	RightUpperLeg = CFrame.Angles(rad(30), 0, rad(6)),
	RightLowerLeg = CFrame.Angles(rad(-48), 0, 0),
	RightFoot = CFrame.Angles(rad(18), 0, 0),
	LeftUpperLeg = CFrame.Angles(rad(30), 0, rad(-6)),
	LeftLowerLeg = CFrame.Angles(rad(-48), 0, 0),
	LeftFoot = CFrame.Angles(rad(18), 0, 0),
}

-- The rummage itself: the two hands take turns digging, and the shoulders roll with them. Small angles on
-- purpose -- what sells "searching" is the alternation and the speed, not the reach. A big swing would read
-- as digging a hole.
local DIG_RIGHT = copy(CROUCH, {
	UpperTorso = CFrame.Angles(rad(-18), rad(-9), 0),
	RightUpperArm = CFrame.Angles(rad(70), 0, rad(-10)),
	RightLowerArm = CFrame.Angles(rad(58), 0, 0),
	LeftUpperArm = CFrame.Angles(rad(50), 0, rad(18)),
	LeftLowerArm = CFrame.Angles(rad(40), 0, 0),
	Head = CFrame.Angles(rad(-22), rad(-7), 0),
})

local DIG_LEFT = copy(CROUCH, {
	UpperTorso = CFrame.Angles(rad(-18), rad(9), 0),
	LeftUpperArm = CFrame.Angles(rad(70), 0, rad(10)),
	LeftLowerArm = CFrame.Angles(rad(58), 0, 0),
	RightUpperArm = CFrame.Angles(rad(50), 0, rad(-18)),
	RightLowerArm = CFrame.Angles(rad(40), 0, 0),
	Head = CFrame.Angles(rad(-22), rad(7), 0),
})

-- Action priority, so it plays over the idle but a real action (a swing, going down) still wins.
local search = fresh("Farm_Search", Enum.AnimationPriority.Action, true)

-- Four beats to a cycle at 1.2 seconds: right, middle, left, middle. The middle keys are what stop the two
-- digs blending into one continuous sway -- without them the engine takes the short path between the two
-- extremes and the hands never come back to the centre.
keyframe(search, 0.0, CROUCH)
keyframe(search, 0.3, DIG_RIGHT)
keyframe(search, 0.6, CROUCH)
keyframe(search, 0.9, DIG_LEFT)
keyframe(search, 1.2, CROUCH)

print("[WOLD] animgen/farm: Farm_Search built into ServerStorage.WOLD_Animations")
print("[WOLD] publish it (right-click -> Save to Roblox, as the place owner) and paste the id into FarmConfig.SearchAnimation")
