-- CombatController: turns left-click into an attack request and plays the resulting animations. Like
-- MovementController, it sends intent only — the server decides whether an attack actually happens, what it
-- hits, and when the guard drops. Animations play here (and for other players via CombatStateChanged) purely
-- as presentation.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)
local AimAccess = require(game.ReplicatedStorage.UI.AimAccess)

local player = Players.LocalPlayer
local equippedWeaponId = nil -- set from EquipmentChanged; drives which animation set is loaded

-- One track cache per character, rebuilt on respawn since Animator is recreated with the character.
local tracks = {}

local function loadTracksFor(character)
	tracks = {}
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")
	-- equippedWeaponId is kept in step by EquipmentChanged below; nil means bare hands.
	local weapon = CombatConfig.Weapons[equippedWeaponId or CombatConfig.DefaultWeapon]
		or CombatConfig.Weapons[CombatConfig.DefaultWeapon]

	local function load(id, priority, looped)
		if not id or id == "" then return nil end -- unpublished animation: system still works, just silent
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if not ok then
			warn("[Combat] failed to load animation", id, track)
			return nil
		end
		track.Priority = priority
		track.Looped = looped or false
		return track
	end

	-- The weapon's held stance. Movement priority, NOT Idle: at Idle it ties with Roblox's own idle and mood
	-- animations at equal weight (measured: three tracks all at Idle, w=1.00) and the default wins, so the
	-- stance never showed. Movement still sits below Action, so swings play over it, and because the stance
	-- poses no leg joints the default walk and run keep driving the legs regardless of priority.
	tracks.idle = load(weapon.idleAnimation, Enum.AnimationPriority.Movement, true)
	tracks.guard = load(weapon.guardAnimation, Enum.AnimationPriority.Action)
	tracks.attacks = {}
	for i, attack in ipairs(weapon.attacks) do
		tracks.attacks[i] = load(attack.animation, Enum.AnimationPriority.Action4)
	end
end

-- How fast counts as moving. Above a crawl, so a character nudged by a slope or settling against a wall does
-- not flicker between standing and walking.
local MOVING_SPEED = 1.5

-- The weapon's held stance plays while STANDING STILL, and stops the moment the player walks.
--
-- It poses both shoulders and the waist at Movement priority, which is the same priority Roblox's own walk
-- and run animations use. Played last it wins, so a player carrying a sword walked with their arms locked in
-- front of them and their body rigid -- no swing, no stride. Dropping it while moving hands those joints
-- back to the default walk, and the stance returns the moment they stop.
--
-- The alternative, lowering its priority below Movement, does not work: at Idle it ties with Roblox's own
-- idle and mood tracks at equal weight and the default wins, which is the bug the original comment here was
-- written about. Playing and stopping it is the only lever that behaves.
local function playHeldStance()
	if not tracks.idle or tracks.idle.IsPlaying then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- Never start the stance mid-stride; the movement watcher below will start it when they stop.
	if humanoid and humanoid.MoveDirection.Magnitude > 0 then return end
	tracks.idle:Play(0.25)
end

-- Watches the character's own movement and swaps the stance out while they are on the move.
local function watchMovement(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local wasMoving = false
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not character.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			return
		end
		-- MoveDirection rather than the assembly's velocity: it is what the player is ASKING for, so it goes
		-- to zero the instant they let go of the key rather than trailing off as the character slides to a
		-- halt, and it is not fooled by being pushed, carried or shoved by a mob.
		local moving = humanoid.MoveDirection.Magnitude > 0
			and humanoid.AssemblyLinearVelocity.Magnitude > MOVING_SPEED
		if moving == wasMoving then return end
		wasMoving = moving

		-- A swing owns the arms while it lasts; the stance is restored by the swing's own Stopped handler.
		for _, track in pairs(tracks.attacks or {}) do
			if track.IsPlaying then return end
		end

		if not tracks.idle then return end
		if moving then
			tracks.idle:Stop(0.15)
		elseif not tracks.idle.IsPlaying then
			tracks.idle:Play(0.2)
		end
	end)
end

local function onCharacterAdded(character)
	loadTracksFor(character)
	playHeldStance()
	watchMovement(character)
end

-- The weapon decides which animations play, so a change has to rebuild the cache.
local function useWeapon(weaponId)
	if weaponId == equippedWeaponId then return end
	-- Drop the previous weapon's stance before the new tracks replace the table.
	if tracks.idle then tracks.idle:Stop(0.2) end
	equippedWeaponId = weaponId
	if player.Character then
		loadTracksFor(player.Character)
		playHeldStance()
	end
end

-- Fires for every player; only our own matters here.
Remotes.EquipmentChanged.OnClientEvent:Connect(function(who, weaponId)
	if who ~= player then return end
	useWeapon(weaponId)
end)

-- EquipmentChanged only fires when equipment CHANGES, so a player who joins already holding a weapon was
-- never told and loaded the bare-hands animations — which is why attacking looked like a punch until the
-- weapon was taken off and put back on. InventoryUpdate carries the equipped set and does arrive on join, so
-- it is the reliable source for the initial state.
Remotes.InventoryUpdate.OnClientEvent:Connect(function(data)
	useWeapon(data and data.equipped and data.equipped.weapon and data.equipped.weapon.id or nil)
end)

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end -- don't punch when the click was consumed by a button
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- The aim point rides along with every attack. The server ignores it for a weapon that does not
		-- throw anything, so a sword is unaffected by whatever the camera happens to be looking at.
		Remotes.RequestAttack:FireServer(AimAccess.Point and AimAccess.Point() or nil)
	elseif input.KeyCode == Enum.KeyCode.Q then
		-- Which skill this is depends on the equipped weapon; the server resolves that and the mana cost.
		Remotes.RequestSkill:FireServer()
	end
end)

-- Play animations for whoever the server says did what — including this player, so the local view matches
-- what everyone else sees rather than predicting separately.
Remotes.CombatStateChanged.OnClientEvent:Connect(function(who, event, chainIndex)
	if who ~= player then return end -- other players' characters animate via their own replicated tracks
	if event == "guard_start" then
		if tracks.guard then tracks.guard:Play(0.15) end
	elseif event == "guard_end" then
		if tracks.guard then tracks.guard:Stop(0.2) end
	elseif event == "attack" then
		-- The looping guard holds every joint at full weight, so a swing playing underneath it barely moves
		-- (measured: 1.22 studs of reach solo, ~0.04 with the guard running). Stop the guard for the swing and
		-- bring it back when the swing ends — the punch animation starts and ends on the guard pose anyway.
		for _, other in pairs(tracks.attacks or {}) do
			other:Stop(0)
		end
		if tracks.guard then tracks.guard:Stop(0.05) end
		-- The held stance holds every arm joint, so a swing blended under it barely moves. Same fault the
		-- guard had against the punches; stop it for the swing and bring it back after.
		if tracks.idle then tracks.idle:Stop(0.05) end
		local track = tracks.attacks and tracks.attacks[chainIndex]
		if track then
			track:Play(0.05)
			track.Stopped:Once(function()
				-- Don't restore anything if a newer swing is already running.
				local swinging = false
				for _, other in pairs(tracks.attacks or {}) do
					if other.IsPlaying then swinging = true end
				end
				if swinging then return end
				-- Back to whichever held pose this weapon has: its own stance, or the bare-hands guard.
				if tracks.idle then
					if not tracks.idle.IsPlaying then tracks.idle:Play(0.15) end
				elseif tracks.guard and not tracks.guard.IsPlaying then
					tracks.guard:Play(0.1)
				end
			end)
		end
	end
end)
