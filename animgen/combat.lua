-- animgen/combat.lua — builds the punch-combat KeyframeSequences into ServerStorage.WOLD_Animations.
--
-- Why this exists: Roblox's Animation Editor is a GUI tool that can't be driven over MCP, but a KeyframeSequence
-- is just an instance tree, so it can be built from code. Run this, then in Studio right-click each sequence and
-- pick "Save to Roblox" to publish it and get a real Animation ID (publishing is the one step that must be done
-- by hand). Until then, KeyframeSequenceProvider:RegisterKeyframeSequence() plays them in-session with no upload,
-- which is how these were verified.
--
-- Run with:  node tools/run-luau.js animgen/combat.lua
--
-- Poses are R15 joint rotations. The three sequences:
--   Combat_Guard — looping stance: both elbows tucked, fists up by the face. Arms/torso only, so the
--   default walk and run keep driving the legs and the player still moves normally while guarding.
--   Punch_Right / Punch_Left — from guard, one arm extends and the torso drives through, then snaps back to
--   guard so the opposite side can follow immediately (the click-to-click alternating jab the user asked for).

local ServerStorage = game:GetService("ServerStorage")

local NAMES = { "Combat_Guard", "Punch_Right", "Punch_Left" }

local folder = ServerStorage:FindFirstChild("WOLD_Animations")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WOLD_Animations"
	folder.Parent = ServerStorage
end

-- Clear only the sequences this file owns. Destroying the whole folder would take the ones built by
-- animgen/movement.lua and animgen/revive.lua with it, and a sequence that has not been published yet is
-- unrecoverable.
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

-- One keyframe covering the whole R15 chain we animate: waist, both arms, both legs. Poses must mirror the
-- rig's own hierarchy (root -> LowerTorso -> UpperTorso -> limbs) or the engine ignores them.
local function keyframe(seq, time, s)
	local kf = Instance.new("Keyframe")
	kf.Name = "KF_" .. tostring(time)
	kf.Time = time
	local root = pose(kf, "HumanoidRootPart")
	local lower = pose(root, "LowerTorso", s.lowerTorso)
	local upper = pose(lower, "UpperTorso", s.waist)
	local rU = pose(upper, "RightUpperArm", s.rShoulder)
	pose(rU, "RightLowerArm", s.rElbow)
	local lU = pose(upper, "LeftUpperArm", s.lShoulder)
	pose(lU, "LeftLowerArm", s.lElbow)
	-- Legs are deliberately absent: without poses for them the default walk/run/idle animation keeps control
	-- of the lower body, so the player moves normally while the guard only occupies the arms and upper torso.
	kf.Parent = seq
	return kf
end

-- The stance every punch starts and returns to.
local GUARD = {
	-- No vertical offset and no leg rotation: the stance is arms-and-torso only so walking still reads normally.
	lowerTorso = CFrame.new(),
	waist      = CFrame.Angles(rad(-4), rad(16), 0),
	rShoulder  = CFrame.Angles(rad(58), 0, rad(20)),
	rElbow     = CFrame.Angles(rad(105), 0, 0),
	lShoulder  = CFrame.Angles(rad(52), 0, rad(-24)),
	lElbow     = CFrame.Angles(rad(100), 0, 0),
}

local function copy(t, overrides)
	local out = {}
	for k, v in pairs(t) do out[k] = v end
	for k, v in pairs(overrides or {}) do out[k] = v end
	return out
end

-- Guard: looping, with a subtle breathing bob so a held stance doesn't look frozen.
local guard = Instance.new("KeyframeSequence")
guard.Name = "Combat_Guard"
guard.Priority = Enum.AnimationPriority.Action
guard.Loop = true
keyframe(guard, 0.0, GUARD)
keyframe(guard, 0.9, copy(GUARD, {
	rElbow     = CFrame.Angles(rad(100), 0, 0),
	lElbow     = CFrame.Angles(rad(95), 0, 0),
}))
keyframe(guard, 1.8, GUARD)
guard.Parent = folder

local function makePunch(name, side)
	local seq = Instance.new("KeyframeSequence")
	seq.Name = name
	seq.Priority = Enum.AnimationPriority.Action2 -- layers above the held guard
	seq.Loop = false

	local isRight = side == "right"
	local twist = isRight and rad(-30) or rad(30)
	local shoulderKey = isRight and "rShoulder" or "lShoulder"
	local elbowKey = isRight and "rElbow" or "lElbow"
	local offShoulderKey = isRight and "lShoulder" or "rShoulder"
	local offElbowKey = isRight and "lElbow" or "rElbow"

	keyframe(seq, 0.0, GUARD)
	-- windup: torso coils away, punching elbow pulls back
	keyframe(seq, 0.06, copy(GUARD, {
		waist = CFrame.Angles(rad(-4), isRight and rad(26) or rad(-26), 0),
		[elbowKey] = CFrame.Angles(rad(115), 0, 0),
	}))
	-- extension: arm straightens, torso drives through, off hand stays up guarding
	keyframe(seq, 0.16, copy(GUARD, {
		waist = CFrame.Angles(rad(-6), twist, 0),
		[shoulderKey] = CFrame.Angles(rad(92), 0, isRight and rad(6) or rad(-6)),
		[elbowKey] = CFrame.Angles(rad(4), 0, 0),
		[offShoulderKey] = CFrame.Angles(rad(56), 0, isRight and rad(-26) or rad(26)),
		[offElbowKey] = CFrame.Angles(rad(108), 0, 0),
	}))
	-- brief hold so the hit reads on screen
	keyframe(seq, 0.24, copy(GUARD, {
		waist = CFrame.Angles(rad(-5), twist * 0.85, 0),
		[shoulderKey] = CFrame.Angles(rad(86), 0, isRight and rad(6) or rad(-6)),
		[elbowKey] = CFrame.Angles(rad(14), 0, 0),
		[offShoulderKey] = CFrame.Angles(rad(56), 0, isRight and rad(-26) or rad(26)),
		[offElbowKey] = CFrame.Angles(rad(108), 0, 0),
	}))
	-- recover to guard, ready for the opposite side
	keyframe(seq, 0.42, GUARD)
	seq.Parent = folder
	return seq
end

makePunch("Punch_Right", "right")
makePunch("Punch_Left", "left")

local names = {}
for _, name in ipairs(NAMES) do
	local c = folder:FindFirstChild(name)
	local kfs = 0
	for _, k in ipairs(c:GetChildren()) do
		if k:IsA("Keyframe") then kfs += 1 end
	end
	table.insert(names, ("%s(kf=%d, loop=%s)"):format(c.Name, kfs, tostring(c.Loop)))
end
return table.concat(names, " | ")
