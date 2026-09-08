-- WeaponVisuals.server.lua: puts the equipped weapon in the character's hand.
--
-- Driven entirely by the inventory: whatever is in the weapon slot is what appears, and it is rebuilt on
-- respawn and on every equipment change. Nothing here decides anything — it only mirrors state.
--
-- Motor6D rather than a WeldConstraint, per the reference: a Motor6D is a real joint, so the weapon moves
-- with the hand under animation instead of being frozen relative to it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Inventory = require(game.ServerScriptService.Inventory)

if ServerConfig.IsLobby then return end

local PREFABS = ReplicatedStorage:WaitForChild("WOLD_Weapons", 20)

-- How each weapon sits in the hand. Tuned per weapon because the prefabs have different origins: a sword is
-- held mid-blade, a bow across the grip, a book flat on the palm.
local GRIP = {
	Sword = CFrame.new(0, -1.6, 0) * CFrame.Angles(math.rad(-90), 0, 0),
	Bow = CFrame.new(0, -0.2, 0.3) * CFrame.Angles(math.rad(-90), math.rad(90), 0),
	Staff = CFrame.new(0, -1.4, 0) * CFrame.Angles(math.rad(-90), 0, 0),
	Spellbook = CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(90)),
}
local DEFAULT_GRIP = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0)

local function clearHeldWeapon(character)
	local existing = character:FindFirstChild("EquippedWeapon")
	if existing then existing:Destroy() end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local grip = hand and hand:FindFirstChild("WeaponGrip")
	if grip then grip:Destroy() end
end

local function holdWeapon(player, weaponId)
	local character = player.Character
	if not character then return end
	clearHeldWeapon(character)
	if not weaponId or not PREFABS then return end

	local prefab = PREFABS:FindFirstChild(weaponId)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not prefab or not hand then return end

	local model = prefab:Clone()
	model.Name = "EquippedWeapon"
	local root = model.PrimaryPart
	if not root then
		model:Destroy()
		return
	end

	-- Parent first, then joint: a Motor6D whose parts are not both in the workspace does nothing.
	model.Parent = character

	local motor = Instance.new("Motor6D")
	motor.Name = "WeaponGrip"
	motor.Part0 = hand
	motor.Part1 = root
	motor.C0 = GRIP[weaponId] or DEFAULT_GRIP
	motor.Parent = hand
end

local function refresh(player)
	local item, entry = Inventory.EquippedWeapon(player)
	holdWeapon(player, (item and entry) and entry.id or nil)
end

-- Inventory calls this whenever the weapon slot changes, so the hand updates the instant it happens rather
-- than on a poll.
Inventory.OnWeaponChanged = refresh

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- The rig is rebuilt on respawn, so the weapon has to be re-attached.
		character:WaitForChild("RightHand", 10)
		task.wait(0.2)
		refresh(player)
	end)
end)

-- A player whose weapon was ALREADY equipped when they joined never triggers OnWeaponChanged, and their
-- character can finish loading before PlayerInventory has read the saved bag. Re-check for a short while
-- after each join so a restored weapon still ends up in hand.
local function refreshUntilArmed(player)
	task.spawn(function()
		for _ = 1, 20 do
			task.wait(0.5)
			if not player.Parent then return end
			local item, entry = Inventory.EquippedWeapon(player)
			local character = player.Character
			if character then
				local wanted = (item and entry) and entry.id or nil
				local held = character:FindFirstChild("EquippedWeapon")
				-- Only act when the hand disagrees with the inventory. Crucially this does NOT stop on
				-- "nothing equipped": at this point the profile may simply not have loaded yet, and giving up
				-- there is what left a restored weapon out of the player's hand.
				if wanted and not held then
					refresh(player)
					return
				elseif wanted and held then
					return -- already correct
				end
			end
		end
	end)
end

Players.PlayerAdded:Connect(refreshUntilArmed)
for _, player in ipairs(Players:GetPlayers()) do
	refreshUntilArmed(player)
	if player.Character then task.spawn(refresh, player) end
end
