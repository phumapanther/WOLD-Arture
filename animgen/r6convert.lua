-- animgen/r6convert.lua — rebuilds R6 animations onto R15 joints.
--
--   node tools/run-luau.js animgen/r6convert.lua --no-lib
--
-- Then publish each sequence (right-click in ServerStorage.WOLD_Animations, "Save to Roblox", as the account
-- that owns the place) and paste the ids into EmoteConfig.
--
-- WHY THIS EXISTS
--
-- Most of the free animation ids floating around for bows, faints, crouches and dances are R6. They load on
-- an R15 character perfectly happily, report a sensible length, and then move nothing at all -- measured:
-- 0.04 studs against 3.46 for a real R15 wave. That silent failure is the whole trap, and it is why every id
-- in this project is verified by playing it and measuring the body rather than by trusting a list.
--
-- They can be converted, though, because an animation is just named poses: read the R6 KeyframeSequence
-- back with KeyframeSequenceProvider and write the same rotations onto the R15 joints that do the same job.
--
-- THE HARD PART IS THE AXES, NOT THE NAMES
--
-- R6's shoulder and hip joints are turned 90 degrees about Y relative to R15's. Copying a pose across
-- without correcting for that rotates the limb around the wrong axis: an arm that should lift forward swings
-- out sideways instead. The correction is to conjugate the pose by that turn --
--
--     R15pose = Ry * R6pose * inverse(Ry)
--
-- -- mirrored for the left side. Measured after the fix: all eight test animations move an R15 rig between
-- 2.55 and 5.67 studs, where before conversion they moved 0.04.
--
-- WHAT IS LOST
--
-- R6 has one part per arm and leg; R15 has three. The whole rotation lands on the UPPER limb, so a converted
-- arm is straight where the original may have implied a bend. Poses read correctly; fine finger-and-elbow
-- detail was never in the R6 source to begin with.
local ServerStorage = game:GetService("ServerStorage")
local KSP = game:GetService("KeyframeSequenceProvider")

local RY = CFrame.Angles(0, math.pi / 2, 0)

-- R6 joint -> the R15 joint that does the same job, and the axis correction it needs.
local MAP = {
	["Torso"]     = { joint = "LowerTorso", fix = nil },   -- the root joint in both rigs
	["Head"]      = { joint = "Head", fix = nil },
	["Right Arm"] = { joint = "RightUpperArm", fix = RY },
	["Left Arm"]  = { joint = "LeftUpperArm", fix = RY:Inverse() },
	["Right Leg"] = { joint = "RightUpperLeg", fix = RY },
	["Left Leg"]  = { joint = "LeftUpperLeg", fix = RY:Inverse() },
}

local PARENT = {
	LowerTorso = "HumanoidRootPart", UpperTorso = "LowerTorso", Head = "UpperTorso",
	RightUpperArm = "UpperTorso", LeftUpperArm = "UpperTorso",
	RightUpperLeg = "LowerTorso", LeftUpperLeg = "LowerTorso",
}

local folder = ServerStorage:FindFirstChild("WOLD_Animations")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WOLD_Animations"
	folder.Parent = ServerStorage
end

local function convert(id, name, loop)
	local ok, src = pcall(function() return KSP:GetKeyframeSequenceAsync("rbxassetid://" .. id) end)
	if not ok then
		warn(("[r6convert] อ่าน %d ไม่ได้: %s"):format(id, tostring(src)))
		return nil
	end

	-- Recursive: the sorter moves sequences into a New_Animations subfolder, and a top-level-only lookup
	-- would build a second copy of each one on the next run.
	local old = folder:FindFirstChild(name, true)
	if old then old:Destroy() end

	local out = Instance.new("KeyframeSequence")
	out.Name = name
	out.Loop = loop and true or false
	out.Priority = Enum.AnimationPriority.Action4
	out.Parent = folder

	local frames = 0
	for _, kf in ipairs(src:GetChildren()) do
		if kf:IsA("Keyframe") then
			frames += 1
			local new = Instance.new("Keyframe")
			new.Name = kf.Name
			new.Time = kf.Time

			-- Poses have to hang off their parent joint's pose or the engine ignores them, so the chain is
			-- built on demand and shared between the limbs that need it.
			local made = {}
			local ensure
			ensure = function(joint)
				if made[joint] then return made[joint] end
				local p = Instance.new("Pose")
				p.Name = joint
				p.CFrame = CFrame.new()
				p.EasingStyle = Enum.PoseEasingStyle.Cubic
				p.EasingDirection = Enum.PoseEasingDirection.InOut
				p.Parent = (joint == "HumanoidRootPart") and new or ensure(PARENT[joint])
				made[joint] = p
				return p
			end
			ensure("HumanoidRootPart")

			for _, pose in ipairs(kf:GetDescendants()) do
				if pose:IsA("Pose") then
					-- Anything not in the map is skipped rather than guessed at -- some of these sequences
					-- carry a "Handle" pose for a tool the animation was authored with, which has no
					-- equivalent here and would land on the wrong joint if forced.
					local m = MAP[pose.Name]
					if m then
						ensure(m.joint).CFrame = m.fix and (m.fix * pose.CFrame * m.fix:Inverse()) or pose.CFrame
					end
				end
			end
			new.Parent = out
		end
	end
	print(("  %-18s <- r6 %-12d  %d เฟรม"):format(name, id, frames))
	return out
end

-- id, ชื่อที่จะได้, วนลูปไหม
--
-- ชื่อขึ้นต้นด้วย Conv_ เพื่อไม่ให้ทับท่าที่ปั้นเอง (Emote_Bow, Emote_Scared, Emote_Squat มีอยู่แล้ว) —
-- สามคู่นั้นจงใจให้เลือกเทียบกันด้วยตาว่าจะใช้ตัวไหน
print("[r6convert] แปลงท่า R6 -> R15:")
for _, row in ipairs({
	-- มีของปั้นเองอยู่แล้ว เอาไว้เทียบ
	{ 204292303, "Conv_Bow", false },
	{ 180612465, "Conv_Scared", true },
	{ 182724289, "Conv_Crouch", true },
	-- ของใหม่ ไม่มีของปั้นเองเทียบ
	{ 181526230, "Conv_Faint", false },
	{ 181525546, "Conv_FloorFaint", false },
	{ 429730430, "Conv_SpinDance", true },
	{ 45834924, "Conv_MoonDance", true },
	{ 179224234, "Conv_FloatSit", true },
	{ 313762630, "Conv_Levitate", true },
	{ 282574440, "Conv_FloorCrawl", true },
}) do
	convert(row[1], row[2], row[3])
end
print("[r6convert] เสร็จแล้ว — publish ทีละตัวแล้วเอา id ไปใส่ EmoteConfig")
