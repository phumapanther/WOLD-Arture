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
-- These prefabs run along their own Y axis, but the HILT is at +Y and the blade at the origin (measured on
-- the sword: Handle +2.00, Pommel +2.50, Blade 0.00). So leaving the rotation alone hangs the sword point
-- DOWN; it has to be flipped 180 degrees for the blade to stand up, then leaned forward.
local BLADE_UP = CFrame.Angles(math.rad(180), 0, 0)
local GRIP = {
	-- Held between both hands in front of the chest rather than clipped to one hand, so it sits centred.
	Sword = CFrame.new(0, 0.2, -1.6) * BLADE_UP * CFrame.Angles(math.rad(20), 0, 0),
	Bow = CFrame.new(0, -0.2, 0.3) * CFrame.Angles(math.rad(-90), math.rad(90), 0),
	-- The staff is a single part with no separate hilt, so it has no wrong end to flip: leaving it upright
	-- puts its ornamented head at the top, which is the way a staff is carried.
	Staff = CFrame.new(0, 0.2, -1.6) * CFrame.Angles(math.rad(-20), 0, 0),
	-- The spellbook is not gripped: it floats in front of the chest between the open hands, so it hangs off
	-- the torso instead. Attached to the hand it sat off to one side (measured x=2.5 instead of centred).
	Spellbook = CFrame.new(0, 0.4, -2) * CFrame.Angles(math.rad(-70), 0, 0),
}
-- Which body part each weapon joints to. Anything not listed here is held in the hand.
local ATTACH_TO = {
	Spellbook = "UpperTorso",
	-- Two-handed: the blade belongs between the hands, not clipped to the right one.
	Sword = "UpperTorso",
	Staff = "UpperTorso",
}
local DEFAULT_GRIP = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0)

-- Where a given weapon should be jointed: the hand by default, the torso for the floating spellbook.
local function anchorPartFor(character, weaponId)
	local wanted = ATTACH_TO[weaponId]
	if wanted then
		local part = character:FindFirstChild(wanted)
		if part then return part end
	end
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

local function clearHeldWeapon(character)
	local existing = character:FindFirstChild("EquippedWeapon")
	if existing then existing:Destroy() end
	-- The joint can live on the hand or the torso, so clear both rather than assuming.
	for _, name in ipairs({ "RightHand", "Right Arm", "UpperTorso" }) do
		local part = character:FindFirstChild(name)
		local grip = part and part:FindFirstChild("WeaponGrip")
		if grip then grip:Destroy() end
	end
end

local function holdWeapon(player, weaponId)
	local character = player.Character
	if not character then return end
	clearHeldWeapon(character)
	if not weaponId or not PREFABS then return end

	local prefab = PREFABS:FindFirstChild(weaponId)
	local anchor = anchorPartFor(character, weaponId)
	if not prefab or not anchor then return end

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
	motor.Part0 = anchor
	motor.Part1 = root
	motor.C0 = GRIP[weaponId] or DEFAULT_GRIP
	motor.Parent = anchor
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
