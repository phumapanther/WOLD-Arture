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

-- Shared entry guard: the target must actually be downed, in range, and not already involved in a rescue.
local function canRescue(rescuer, target, range)
	if not rescuer or not target or rescuer == target then return false end
	if not Vitals.IsDowned(target) then return false end
	if Vitals.IsDowned(rescuer) then return false end
	if CarriedBy[target] then return false end
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
		if root then pcall(function() root:SetNetworkOwner(entry.target) end) end
	end

	local carrierHumanoid = characterOf(carrier) and characterOf(carrier):FindFirstChildOfClass("Humanoid")
	if carrierHumanoid then carrierHumanoid.WalkSpeed = 8 end

	Remotes.CarryStateChanged:FireAllClients(carrier, "carry_end", entry.target)
end

Remotes.RequestCarry.OnServerEvent:Connect(function(carrier, target)
	if typeof(target) ~= "Instance" or not target:IsA("Player") then return end
	if not canRescue(carrier, target, ActionConfig.Carry.range) then return end

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

	Carrying[carrier] = { target = target, joint = joint }
	CarriedBy[target] = carrier

	local carrierHumanoid = carrierChar:FindFirstChildOfClass("Humanoid")
	if carrierHumanoid then carrierHumanoid.WalkSpeed = ActionConfig.Carry.walkSpeed end

	Remotes.CarryStateChanged:FireAllClients(carrier, "carry_start", target)
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

Players.PlayerAdded:Connect(function(player)
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
		-- A carried player who stopped being downed (revived by someone else, or respawned) is set down.
		if not entry.target.Parent or not Vitals.IsDowned(entry.target) or not characterOf(carrier) then
			dropCarried(carrier)
		end
	end
end)
