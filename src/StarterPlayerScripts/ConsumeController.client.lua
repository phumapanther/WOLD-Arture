-- ConsumeController: the eating and drinking pose, and the item held to the mouth.
--
-- Presentation only. The server decides who is consuming, for how long, and when the effect lands; this
-- draws what that looks like for everyone watching.
--
-- The pose is built from joint poses rather than an uploaded animation, for the same reason the touch icons
-- are drawn from frames: an animation would need uploading under the right account and could go missing,
-- while this cannot. Both arms bend at the elbow, the hands come to the mouth, and the whole thing bobs.
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Remotes = require(game.ReplicatedStorage.Remotes)
local SoundscapeConfig = require(game.ReplicatedStorage.SoundscapeConfig)

-- One entry per player currently eating, so several people can eat at once.
local active = {} -- [player] = { connection, model, startedAt }

local BOB_SPEED = 6 -- bobs per second; roughly the rhythm of chewing
local BOB_STUDS = 0.12

--------------------------------------------------------------------------------

-- The little copy of the item, floating at the mouth. Uses the item's own icon, shrunk -- so bread looks
-- like bread and a potion like a potion without modelling anything.
local function makeHeldItem(character, itemId)
	local head = character:FindFirstChild("Head")
	local item = itemId and ItemCatalog.Get(itemId)
	if not head or not item or not item.icon or item.icon == "" then return nil end

	local part = Instance.new("Part")
	part.Name = "WOLD_ConsumeItem"
	part.Size = Vector3.new(0.9, 0.9, 0.05)
	part.Transparency = 1 -- the decals carry the picture; the part itself is only a surface to hang them on
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Parent = character

	-- Both faces, so the item reads from in front and behind rather than vanishing at some angles.
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local decal = Instance.new("Decal")
		decal.Texture = item.icon
		decal.Face = face
		decal.Parent = part
	end

	-- A weld rather than setting CFrame every frame: the item then follows the head through every animation
	-- for free, including the bob below.
	local weld = Instance.new("Weld")
	weld.Part0 = head
	weld.Part1 = part
	weld.C0 = CFrame.new(0, -0.35, -0.75) -- just in front of the mouth
	weld.Parent = part
	return part, weld
end

-- Raises both hands to the mouth and bobs. Written to the joints each frame after the animator has run,
-- which is the same approach the crawl uses -- an animation playing underneath would otherwise win.
-- ท่าพันแผล (กล่องปฐมพยาบาล ตามคู่มือภาพของผู้ใช้): แขนซ้ายยื่นออกหน้าเป็นแขนที่บาดเจ็บ มือขวาวนรอบ
-- ปลายแขนซ้าย = ทำความสะอาด → สำลี → ผ้าก๊อซ → กด → พัน จังหวะช้ากว่ากิน (2 รอบต่อวิ) และวนเป็นวงกลม
local function startBandagePose(character)
	local leftJoint = character:FindFirstChild("LeftUpperArm")
	local rightJoint = character:FindFirstChild("RightUpperArm")
	if not leftJoint or not rightJoint then return nil end
	local leftShoulder = leftJoint:FindFirstChild("LeftShoulder")
	local rightShoulder = rightJoint:FindFirstChild("RightShoulder")
	local leftElbow = character:FindFirstChild("LeftLowerArm")
	local rightElbow = character:FindFirstChild("RightLowerArm")
	leftElbow = leftElbow and leftElbow:FindFirstChild("LeftElbow")
	rightElbow = rightElbow and rightElbow:FindFirstChild("RightElbow")
	local head = character:FindFirstChild("Head")
	local neck = head and head:FindFirstChild("Neck")
	if not leftShoulder or not rightShoulder then return nil end

	local started = os.clock()
	return RunService.Stepped:Connect(function()
		local t = os.clock() - started
		-- แขนซ้ายชูออกหน้าระดับอก ค่อนข้างนิ่ง (บาดเจ็บ) งอศอกเล็กน้อยให้ปลายแขนขวางหน้าตัว
		leftShoulder.Transform = CFrame.Angles(math.rad(80), math.rad(-25), math.rad(20))
		if leftElbow then leftElbow.Transform = CFrame.Angles(math.rad(35), 0, 0) end
		-- มือขวาวนรอบปลายแขนซ้าย: ไหล่ขวาแกว่งเป็นวงเล็กๆ ศอกงอตาม
		local a = t * math.pi * 2 * 2
		rightShoulder.Transform = CFrame.Angles(math.rad(70 + 14 * math.sin(a)), math.rad(10 * math.cos(a)), math.rad(-30 + 12 * math.cos(a)))
		if rightElbow then rightElbow.Transform = CFrame.Angles(math.rad(60 + 18 * math.sin(a)), 0, 0) end
		-- ก้มมองแผล
		if neck then neck.Transform = CFrame.Angles(math.rad(-22), 0, 0) end
	end)
end

local function startPose(character)
	local torso = character:FindFirstChild("UpperTorso")
	local leftJoint = character:FindFirstChild("LeftUpperArm")
	local rightJoint = character:FindFirstChild("RightUpperArm")
	if not torso or not leftJoint or not rightJoint then return nil end

	local leftShoulder = leftJoint:FindFirstChild("LeftShoulder")
	local rightShoulder = rightJoint:FindFirstChild("RightShoulder")
	local leftElbow = character:FindFirstChild("LeftLowerArm")
	local rightElbow = character:FindFirstChild("RightLowerArm")
	leftElbow = leftElbow and leftElbow:FindFirstChild("LeftElbow")
	rightElbow = rightElbow and rightElbow:FindFirstChild("RightElbow")
	if not leftShoulder or not rightShoulder then return nil end

	local started = os.clock()
	return RunService.Stepped:Connect(function()
		local t = os.clock() - started
		local bob = math.sin(t * BOB_SPEED) * BOB_STUDS

		-- Upper arms swing forward and in toward the chest; the elbows fold so the hands finish at the face.
		-- Written as Transform, which the animator applies on top of whatever else is playing, so walking
		-- and running still move the legs underneath.
		-- POSITIVE X swings the arms FORWARD on an R15 rig; the first version used negative and put both
		-- hands behind the character's back. The elbows fold the same way, bringing the hands up to the
		-- face rather than down behind the hips.
		leftShoulder.Transform = CFrame.new(0, bob, 0)
			* CFrame.Angles(math.rad(75 - bob * 60), 0, math.rad(28))
		rightShoulder.Transform = CFrame.new(0, bob, 0)
			* CFrame.Angles(math.rad(75 - bob * 60), 0, math.rad(-28))
		if leftElbow then
			leftElbow.Transform = CFrame.Angles(math.rad(70), 0, 0)
		end
		if rightElbow then
			rightElbow.Transform = CFrame.Angles(math.rad(70), 0, 0)
		end
	end)
end

local function stop(player)
	local entry = active[player]
	if not entry then return end
	active[player] = nil
	if entry.connection then entry.connection:Disconnect() end
	if entry.model and entry.model.Parent then entry.model:Destroy() end
end

local function start(player, itemId)
	stop(player) -- never stack two poses on one player
	local character = player.Character
	if not character then return end

	local item = itemId and ItemCatalog.Get(itemId)
	local pose = item and item.use and item.use.pose
	local connection = pose == "bandage" and startBandagePose(character) or startPose(character)
	-- ท่าพันแผลถือของไว้ที่มือ ไม่ใช่ที่ปาก
	local model = pose ~= "bandage" and makeHeldItem(character, itemId) or nil
	active[player] = { connection = connection, model = model, startedAt = os.clock() }
end

--------------------------------------------------------------------------------

-- The noise an item makes when it is used. Which sound is the item's own business -- ItemCatalog names it
-- -- so a consumable added later needs no change here. Played at the character rather than flat: eating is
-- something bystanders should hear from where you are standing.
local function playUseSound(character, itemId)
	local item = itemId and ItemCatalog.Get(itemId)
	local name = item and item.useSound
	local id = name and SoundscapeConfig.Interface[name]
	if not character or not id or id == "" then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = SoundscapeConfig.Interface.Volume
	sound.RollOffMaxDistance = 40 -- a personal sound; not something to carry across the square
	sound.Parent = root
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 6)
end

Remotes.ConsumeStateChanged.OnClientEvent:Connect(function(player, state, itemId)
	if state == "used" then
		-- An instant item: no pose, no held model, just the sound.
		playUseSound(player.Character, itemId)
		return
	end
	if state == "start" then
		playUseSound(player.Character, itemId)
		start(player, itemId)
	else
		-- "finish" and "cancel" look the same from here: the hands come down and the item goes away. The
		-- difference is whether the server applied the effect, which the player sees in their bars.
		stop(player)
	end
end)

-- A rebuilt rig has no pose to keep; the joints it was writing to are gone.
Players.PlayerRemoving:Connect(stop)
for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterRemoving:Connect(function() stop(player) end)
end
Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function() stop(player) end)
end)
