-- CombatController: turns left-click into an attack request and plays the resulting animations. Like
-- MovementController, it sends intent only — the server decides whether an attack actually happens, what it
-- hits, and when the guard drops. Animations play here (and for other players via CombatStateChanged) purely
-- as presentation.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

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

-- The weapon's held stance plays for as long as one is equipped, not only while guarding.
local function playHeldStance()
	if tracks.idle and not tracks.idle.IsPlaying then
		tracks.idle:Play(0.25)
	end
end

local function onCharacterAdded(character)
	loadTracksFor(character)
	playHeldStance()
end

-- The weapon decides which animations play, so a swap has to rebuild the cache. Fires for every player; only
-- our own matters here.
Remotes.EquipmentChanged.OnClientEvent:Connect(function(who, weaponId)
	if who ~= player then return end
	-- Drop the previous weapon's stance before the new tracks replace the table.
	if tracks.idle then tracks.idle:Stop(0.2) end
	equippedWeaponId = weaponId
	if player.Character then
		loadTracksFor(player.Character)
		playHeldStance()
	end
end)

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end -- don't punch when the click was consumed by a button
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Remotes.RequestAttack:FireServer()
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
