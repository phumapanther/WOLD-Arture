-- PlayerRescue.server.lua: reviving (CPR) and carrying a downed player. Sub-project 3b — the revive hook the
-- vitals spec reserved is Vitals.Recover, which this file is the only caller of.
--
-- Server-authoritative: the client asks to revive or carry someone, the server re-checks distance, downed
-- state, and that neither player is already busy.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Vitals = require(game.ServerScriptService.Vitals)
local ActionConfig = require(game.ReplicatedStorage.ActionConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)
local RescueAccess = require(game.ServerScriptService.RescueAccess)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)

if ServerConfig.IsLobby then return end

-- Carrier and carried must stop colliding or they shove each other apart (see animgen/revive.lua's notes).
local CARRY_GROUP = "WOLD_Carried"
pcall(function()
	PhysicsService:RegisterCollisionGroup(CARRY_GROUP)
	PhysicsService:CollisionGroupSetCollidable(CARRY_GROUP, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(CARRY_GROUP, CARRY_GROUP, false)
end)

local Reviving = {} -- [rescuer] = { target, startedAt }
local Carrying = {} -- [carrier] = { target, joint }
local CarriedBy = {} -- [carried] = carrier, so a downed player can only be picked up once

local function characterOf(player)
	return player and player.Character
end

local function rootOf(player)
	local character = characterOf(player)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function withinRange(a, b, range)
	local ra, rb = rootOf(a), rootOf(b)
	if not ra or not rb then return false end
	return (ra.Position - rb.Position).Magnitude <= range
end

-- Shared entry guard: the target must be in range and neither player already involved in a rescue.
--
-- `consented` lifts the downed requirement, and ONLY that. It is set by the carry path after the target has
-- agreed, never by anything a client sends: picking up a healthy player who has not said yes would be a way
-- to take someone hostage.
local function canRescue(rescuer, target, range, consented)
	if not rescuer or not target or rescuer == target then return false end
	if not consented and not Vitals.IsDowned(target) then return false end
	if Vitals.IsDowned(rescuer) then return false end
	if CarriedBy[target] then return false end
	-- Nor can someone who is BEING carried pick anybody up. Checked here rather than only at the prompt,
	-- because a player can ask to carry somebody and be picked up themselves before the request lands --
	-- the answer has to be decided when the carry actually starts, not when it was requested.
	if CarriedBy[rescuer] then return false end
	if Carrying[rescuer] or Reviving[rescuer] then return false end
	return withinRange(rescuer, target, range)
end

--------------------------------------------------------------------------------
-- Revive (CPR)
--------------------------------------------------------------------------------

local function stopReviving(rescuer, completed)
	local entry = Reviving[rescuer]
	if not entry then return end
	Reviving[rescuer] = nil
	Remotes.CarryStateChanged:FireAllClients(rescuer, "revive_end", entry.target)
	if completed then
		Vitals.Recover(entry.target, ActionConfig.Revive.hpFraction)
	end
end

Remotes.RequestRevive.OnServerEvent:Connect(function(rescuer, target)
	if typeof(target) ~= "Instance" or not target:IsA("Player") then return end
	if not canRescue(rescuer, target, ActionConfig.Revive.range) then return end
	Reviving[rescuer] = { target = target, startedAt = os.clock() }
	Remotes.CarryStateChanged:FireAllClients(rescuer, "revive_start", target)
end)

--------------------------------------------------------------------------------
-- Carry
--------------------------------------------------------------------------------

local function setCarriedPhysics(character, carrier, carried)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = carried and CARRY_GROUP or "Default"
		end
	end
	if carried and carrier then
		-- Without this the carried rig jitters badly while the carrier walks.
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then pcall(function() root:SetNetworkOwner(carrier) end) end
	end
end

local function dropCarried(carrier)
	local entry = Carrying[carrier]
	if not entry then return end
	Carrying[carrier] = nil
	CarriedBy[entry.target] = nil
	entry.target:SetAttribute("WOLD_BeingCarried", false)

	if entry.joint then entry.joint:Destroy() end

	local character = characterOf(entry.target)
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		-- PlatformStand was holding the carried player still against the joint; releasing it hands them back
		-- to the downed state's own crawling controls.
		if humanoid then humanoid.PlatformStand = false end
		setCarriedPhysics(character, nil, false)
		-- Back on the ground: if they are still downed, lie them down again.
		Vitals.SetProneSuspended(entry.target, false)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			-- **ต้องหยุดความเร็วที่ค้างอยู่ก่อนคืนเจ้าของฟิสิกส์** ไม่งั้นตัวจะไหลไปเรื่อยๆ หลังถูกวาง
			--
			-- ตอนถูกอุ้ม ร่างถูกลากไปตามตัวคนอุ้ม เอนจิ้นจึงบันทึกความเร็วสะสมไว้ พอปล่อย PlatformStand
			-- แล้วคืนสิทธิ์ให้ไคลเอนต์ของคนที่ถูกวาง ความเร็วก้อนนั้นยังอยู่ — และร่างที่ล้มอยู่ถูกปิด
			-- การชนของแขนขาไว้ (setLimbCollision) จึงแทบไม่มีอะไรหยุดมัน กลายเป็นไถลยาว
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			pcall(function() root:SetNetworkOwner(entry.target) end)
		end
	end

	local carrierHumanoid = characterOf(carrier) and characterOf(carrier):FindFirstChildOfClass("Humanoid")
	if carrierHumanoid then carrierHumanoid.WalkSpeed = 8 end

	Remotes.CarryStateChanged:FireAllClients(carrier, "carry_end", entry.target)
end

-- Shared by the downed carry (no consent needed -- they cannot answer) and the consented carry of a player
-- who is up and has agreed.
local function beginCarry(carrier, target, consented)
	if not canRescue(carrier, target, ActionConfig.Carry.range, consented) then return false end

	local carrierChar = characterOf(carrier)
	local targetChar = characterOf(target)
	local torso = carrierChar and carrierChar:FindFirstChild("UpperTorso")
	local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
	if not torso or not targetRoot then return end

	local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
	if targetHumanoid then targetHumanoid.PlatformStand = true end
	-- Stand the carried body upright before the joint takes hold: they are still downed, so without this the
	-- prone tilt stays applied and they ride face-down.
	Vitals.SetProneSuspended(target, true)
	setCarriedPhysics(targetChar, carrier, true)

	-- Motor6D, not a weld: it still lets the carried player's own Animator drive its rig, which is what plays
	-- Carry_Held on top of the joint.
	local joint = Instance.new("Motor6D")
	joint.Name = "WOLD_CarryJoint"
	joint.Part0 = torso
	joint.Part1 = targetRoot
	joint.C0 = ActionConfig.Carry.jointC0
	joint.Parent = torso

	-- Remembered, because the upkeep loop below needs to know whether being un-downed should end this carry.
	Carrying[carrier] = { target = target, joint = joint, consented = consented }
	CarriedBy[target] = carrier
	-- Published as an attribute, the way Vitals publishes WOLD_Downed, so every CLIENT can see who is being
	-- carried. CarriedBy is server-only, and the prompts are drawn client-side -- without this a passenger
	-- went on being offered as a rescue target to everyone around them, including themselves.
	--
	-- Named WOLD_BeingCarried rather than WOLD_Carried because the CollisionGroup above already owns that
	-- name. They are different namespaces and would not have collided, but two unrelated things called the
	-- same thing in one file is a trap for whoever reads it next.
	target:SetAttribute("WOLD_BeingCarried", true)

	local carrierHumanoid = carrierChar:FindFirstChildOfClass("Humanoid")
	if carrierHumanoid then carrierHumanoid.WalkSpeed = ActionConfig.Carry.walkSpeed end

	Remotes.CarryStateChanged:FireAllClients(carrier, "carry_start", target)
	return true
end

-- Published so ClassActions can start a carry once its consent prompt has been answered, without either
-- file duplicating the joint, the physics group and the network ownership this sets up. Through a module
-- rather than a global, the same hand-off ProfileAccess and HudAccess use.
RescueAccess.BeginCarry = beginCarry

-- Published for the same reason: being carried has consequences in files that must not require this one.
RescueAccess.IsCarried = function(player)
	return CarriedBy[player] ~= nil
end

Remotes.RequestCarry.OnServerEvent:Connect(function(carrier, target)
	if typeof(target) ~= "Instance" or not target:IsA("Player") then return end
	-- The plain remote never consents: it is the downed-player rescue, and a downed player cannot answer.
	beginCarry(carrier, target, false)
end)

Remotes.RequestDrop.OnServerEvent:Connect(function(carrier)
	dropCarried(carrier)
end)

--------------------------------------------------------------------------------
-- Upkeep: end a rescue the moment it stops being valid, so nothing is left dangling.
--------------------------------------------------------------------------------

local function cleanupPlayer(player)
	stopReviving(player, false)
	dropCarried(player)
	local carrier = CarriedBy[player]
	if carrier then dropCarried(carrier) end
end

Players.PlayerRemoving:Connect(cleanupPlayer)

PlayerJoin.Each(function(player)
	player.CharacterRemoving:Connect(function()
		cleanupPlayer(player)
	end)
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()

	for rescuer, entry in pairs(Reviving) do
		local stillValid = entry.target.Parent
			and Vitals.IsDowned(entry.target)
			and withinRange(rescuer, entry.target, ActionConfig.Revive.range)
		if not stillValid then
			stopReviving(rescuer, false) -- walked away or the target left; no revive
		elseif now - entry.startedAt >= ActionConfig.Revive.duration then
			stopReviving(rescuer, true)
		end
	end

	for carrier, entry in pairs(Carrying) do
		-- A carried player who stopped being downed is set down -- unless they agreed to be carried while
		-- up, in which case being fine is the normal state and dropping them would end every such carry on
		-- the frame it started.
		local lostReason = not entry.consented and not Vitals.IsDowned(entry.target)
		-- And a CARRIER who goes down drops what they were carrying. canRescue already refuses to start a
		-- carry while downed, but nothing was watching for someone collapsing mid-carry -- so a player who
		-- was floored while hauling a friend went on hauling them, crawling, with the friend riding along.
		-- Someone on their hands and knees is not carrying anybody.
		local carrierDown = Vitals.IsDowned(carrier)
		if not entry.target.Parent or lostReason or carrierDown or not characterOf(carrier) then
			dropCarried(carrier)
		end
	end
end)
