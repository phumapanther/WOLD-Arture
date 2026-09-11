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
local WeaponVisualsAccess = require(game.ServerScriptService.WeaponVisualsAccess)

if ServerConfig.IsLobby then return end

local PREFABS = ReplicatedStorage:WaitForChild("WOLD_Weapons", 20)

-- How each weapon sits in the hand. Tuned per weapon because the prefabs have different origins: a sword is
-- held mid-blade, a bow across the grip, a book flat on the palm.
-- These prefabs run along their own Y axis, but the HILT is at +Y and the blade at the origin (measured on
-- the sword: Handle +2.00, Pommel +2.50, Blade 0.00). So leaving the rotation alone hangs the sword point
-- DOWN; it has to be flipped 180 degrees for the blade to stand up, then leaned forward.
local BLADE_UP = CFrame.Angles(math.rad(180), 0, 0)
-- Named because four things use it: the sword and the three tools, which are all built to the same layout.
local SWORD_GRIP = CFrame.new(0, -0.3, 0) * BLADE_UP * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, -2.0, 0)
local GRIP = {
	-- Gripped in the right hand, by the HANDLE. The joint drives the PrimaryPart, which is the Blade, and the
	-- Handle sits 2.0 studs along the blade's local +Y — so the offset has to pull the model back by that much
	-- or the palm ends up holding the blade (measured: handle 3.2 studs from the hand, blade only 1.2).
	-- BLADE_UP flips the model so the point stands up, and the lean is negative because it is applied after
	-- that flip, which reverses it.
	-- Leaned forward from -20 to -90: the blade was standing bolt upright. The lean is applied BEFORE the
	-- handle offset below, so the grip stays put in the palm and only the blade swings down and forward.
	Sword = SWORD_GRIP,
	-- The three tools are built on the sword's layout on purpose -- working end at the origin, grip 2.0 studs
	-- out along +Y -- so they take the sword's offset unchanged. Sharing the value rather than copying the
	-- number three times means a future correction to the sword's grip fixes all four together.
	Axe = SWORD_GRIP,
	Pickaxe = SWORD_GRIP,
	Shovel = SWORD_GRIP,
	-- The rod is built to the same layout, so it takes the same grip. Held in two hands like the sword,
	-- which is what the user asked for -- the two-handed look comes from Sword_Idle, not from the offset.
	FishingRod = SWORD_GRIP,
	-- The pistol needs its OWN grip, not the sword's.
	--
	-- SWORD_GRIP stands its model bolt upright, which is right for a blade and wrong for a gun: measured
	-- the barrel pointing straight up (vertical component 1.00) while the character faced forward. A gun
	-- has to lie along the aim.
	--
	-- The model is built muzzle-at-origin with the grip 2.0 studs out along +Y, so the whole thing is
	-- rotated to lay that axis FORWARD rather than upward, then pulled back by the same 2.0 to put the
	-- stock in the palm instead of the muzzle.
	-- No rotation at all, which is the surprising part. The hand's own axes already lay the model's +Y
	-- backward along the body's facing, so leaving the orientation alone points the barrel FORWARD and
	-- level -- measured 0.34, 0.04, -0.94 against a body facing 0, 0, -1, versus 1.00 straight up under
	-- SWORD_GRIP. All that remains is pulling the model back 2.0 studs so the palm holds the stock rather
	-- than the muzzle.
	Pistol = CFrame.new(0, -0.2, 0) * CFrame.new(0, -2.0, 0),
	-- The bow's belly has to face out to the RIGHT while it is held in the right hand, so the limbs curve away
	-- from the character rather than into it. The 180 is on ROLL, not yaw: the bow lies in a plane, so yawing
	-- it only spins that plane about the arm while rolling it turns the belly over.
	Bow = CFrame.new(0, -0.2, 0.3) * CFrame.Angles(math.rad(-90), 0, math.rad(180)),
	-- The staff is a single part with no separate hilt, so it has no wrong end to flip: leaving it upright
	-- puts its ornamented head at the top, which is the way a staff is carried.
	Staff = CFrame.new(0, 0.9, -1.6) * CFrame.Angles(math.rad(-20), 0, 0),
	-- The spellbook is not gripped: it floats in front of the chest between the open hands, so it hangs off
	-- the torso instead. Attached to the hand it sat off to one side (measured x=2.5 instead of centred).
	Spellbook = CFrame.new(0, 0.4, -2) * CFrame.Angles(math.rad(-70), 0, 0),
}
-- Which body part each weapon joints to WHILE FIGHTING. Anything not listed here is held in the hand.
--
-- These two are the exception because their attack poses put them in front of the chest rather than in a
-- fist: the spellbook floats open between both hands, and the staff is brought across the body. Jointed to
-- the hand they went where the hand went, which is off to one side (measured: spellbook at x=2.5 instead of
-- centred).
local ATTACH_TO = {
	Spellbook = "UpperTorso",
	Staff = "UpperTorso",
}

-- ...but that is only right while the attack pose is up.
--
-- Out of combat there is no pose holding the arms in place, so a book hanging in front of a chest that is
-- walking normally looks like it is stuck to the character rather than carried by them. Carried in the right
-- hand it reads as something a person is holding.
--
-- So both of these move: hand while idle, chest while fighting. The grip differs too, because a thing held
-- at arm's length needs a different offset from one floating at the sternum.
local CARRY_GRIP = {
	-- Tucked against the palm with its spine down, the way a book is carried rather than read.
	Spellbook = CFrame.new(0, -0.6, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(90)),
	-- Upright in the fist, ornamented head up, the way a walking staff is carried.
	--
	-- The offset pulls the model DOWN its own length so the hand meets the shaft rather than the tip. At 1.6
	-- the staff floated clear of the fist; 0.6 puts the grip in the palm. Small numbers here because the
	-- staff's origin already sits near its middle, unlike the sword's, which hangs from the hilt at +2.
	Staff = CFrame.new(0, -0.6, 0) * CFrame.Angles(math.rad(-90), 0, 0),
}
local DEFAULT_GRIP = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0)

-- Who is currently mid-attack, so the two chest-mounted weapons know which way round they should be.
-- Cleared by a timer rather than by an "attack ended" event, because there is no such event: an attack is
-- a moment, and the pose that follows it lets go on its own.
local Fighting = {}

-- Matches STANCE_SECONDS in CombatController, which is how long the attack pose lingers on the client. If
-- the two disagree the weapon snaps back to the hand while the arms are still posed, or hangs at the chest
-- after they have relaxed.
local STANCE_SECONDS = 1.5

-- Where a given weapon should be jointed. The hand by default; the chest for the spellbook and staff, but
-- only while their attack pose is actually up.
local function anchorPartFor(character, weaponId, fighting)
	local wanted = fighting and ATTACH_TO[weaponId] or nil
	if wanted then
		local part = character:FindFirstChild(wanted)
		if part then return part end
	end
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

-- And the offset that goes with wherever it ended up.
local function gripFor(weaponId, fighting)
	if not fighting and CARRY_GRIP[weaponId] then return CARRY_GRIP[weaponId] end
	return GRIP[weaponId] or DEFAULT_GRIP
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

	local fighting = Fighting[player] == true
	local prefab = PREFABS:FindFirstChild(weaponId)
	local anchor = anchorPartFor(character, weaponId, fighting)
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
	motor.C0 = gripFor(weaponId, fighting)
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

--------------------------------------------------------------------------------
-- Moving the chest-mounted weapons between the hand and the chest
--------------------------------------------------------------------------------

-- Only the spellbook and the staff care, so only an attack with one of those rebuilds anything. Every other
-- weapon is in the hand either way, and re-jointing it on every swing would be work for nothing.
local function movesWhileFighting(player)
	local item, entry = Inventory.EquippedWeapon(player)
	local id = (item and entry) and entry.id or nil
	return id ~= nil and ATTACH_TO[id] ~= nil
end

-- Bumped on every attack so a second swing during the countdown extends the pose rather than the first
-- swing's timer dropping the weapon back to the hand while the arms are still raised.
local stanceToken = {}

-- CombatStateChanged is fired BY the server at clients, so it cannot be listened to here. WeaponVisuals is
-- told directly instead, through a function PlayerCombat calls -- the same hand-off pattern the rest of the
-- server uses rather than a second copy of the combat state.
local function onAttack(player)
	if not movesWhileFighting(player) then return end

	local wasFighting = Fighting[player] == true
	Fighting[player] = true
	-- Only rebuild when it actually moves. A chain of swings should not re-joint the weapon on every one.
	if not wasFighting then refresh(player) end

	stanceToken[player] = (stanceToken[player] or 0) + 1
	local mine = stanceToken[player]
	task.delay(STANCE_SECONDS, function()
		if stanceToken[player] ~= mine then return end
		Fighting[player] = nil
		if player.Parent then refresh(player) end
	end)
end

WeaponVisualsAccess.OnAttack = onAttack

Players.PlayerRemoving:Connect(function(player)
	Fighting[player] = nil
	stanceToken[player] = nil
end)
