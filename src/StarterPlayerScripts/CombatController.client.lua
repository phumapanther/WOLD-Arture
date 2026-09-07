-- CombatController: turns left-click into an attack request and plays the resulting animations. Like
-- MovementController, it sends intent only — the server decides whether an attack actually happens, what it
-- hits, and when the guard drops. Animations play here (and for other players via CombatStateChanged) purely
-- as presentation.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer

-- One track cache per character, rebuilt on respawn since Animator is recreated with the character.
local tracks = {}

local function loadTracksFor(character)
	tracks = {}
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")
	local weapon = CombatConfig.Weapons[CombatConfig.DefaultWeapon]

	local function load(id, priority)
		if not id or id == "" then return nil end -- unpublished animation: system still works, just silent
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if not ok then
			warn("[Combat] failed to load animation", id, track)
			return nil
		end
		track.Priority = priority
		return track
	end

	tracks.guard = load(weapon.guardAnimation, Enum.AnimationPriority.Action)
	tracks.attacks = {}
	for i, attack in ipairs(weapon.attacks) do
		tracks.attacks[i] = load(attack.animation, Enum.AnimationPriority.Action2)
	end
end

local function onCharacterAdded(character)
	loadTracksFor(character)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end -- don't punch when the click was consumed by a button
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Remotes.RequestAttack:FireServer()
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
		local track = tracks.attacks and tracks.attacks[chainIndex]
		if track then
			track:Stop(0)
			track:Play(0.05)
		end
	end
end)
