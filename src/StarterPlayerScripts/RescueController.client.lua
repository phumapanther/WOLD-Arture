-- RescueController: shows the "ชุบ" / "อุ้ม" buttons over a downed player and plays the rescue animations.
--
-- The prompts are ProximityPrompts rather than a hand-built billboard: Roblox already draws them at a
-- distance, handles hold-to-activate, and works with both mouse and touch, which is exactly the
-- "walk close and a small button appears" behaviour asked for.
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local Players = game:GetService("Players")
local ActionConfig = require(game.ReplicatedStorage.ActionConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer
local prompts = {} -- [player] = { revive, carry }
local tracks = {} -- animations for THIS player acting as rescuer/carrier
local heldTracks = {} -- [player] = track, for whoever is being carried

local function loadTrack(character, id, looped)
	if not id or id == "" then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return nil end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
	if not ok then return nil end
	track.Priority = Enum.AnimationPriority.Action2
	track.Looped = looped or false
	return track
end

local function reloadOwnTracks(character)
	tracks = {
		cpr = loadTrack(character, ActionConfig.Revive.animation, true),
		holder = loadTrack(character, ActionConfig.Carry.holderAnimation, true),
	}
end

player.CharacterAdded:Connect(reloadOwnTracks)
if player.Character then reloadOwnTracks(player.Character) end

--------------------------------------------------------------------------------
-- Prompts on downed players
--------------------------------------------------------------------------------

local function removePrompts(target)
	local entry = prompts[target]
	if not entry then return end
	if entry.revive then entry.revive:Destroy() end
	if entry.carry then entry.carry:Destroy() end
	prompts[target] = nil
end

local function addPrompts(target)
	if target == player or prompts[target] then return end
	local character = target.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local function make(actionText, keyboardKey, order, holdSeconds)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = actionText
		prompt.ObjectText = target.DisplayName
		prompt.KeyboardKeyCode = keyboardKey
		prompt.MaxActivationDistance = ActionConfig.Revive.range
		prompt.RequiresLineOfSight = false
		prompt.UIOffset = Vector2.new(0, order * 44)
		-- The prompt draws its own filling ring for a hold, so the wait is visible without any UI of ours.
		prompt.HoldDuration = holdSeconds or 0
		prompt.Parent = root
		return prompt
	end

	prompts[target] = {
		-- Reviving is a tap because the five seconds of CPR happen AFTER it, on the server, with its own
		-- animation. Carrying has no such phase, so its wait is the hold itself.
		revive = make("ชุบ", Enum.KeyCode.E, 0),
		carry = make("อุ้ม", Enum.KeyCode.F, 1, ActionConfig.Carry.holdSeconds),
	}

	prompts[target].revive.Triggered:Connect(function()
		Remotes.RequestRevive:FireServer(target)
	end)
	prompts[target].carry.Triggered:Connect(function()
		Remotes.RequestCarry:FireServer(target)
	end)
end

-- Prompts follow the downed state, so they appear and disappear with it rather than being polled.
Remotes.DownedStateChanged.OnClientEvent:Connect(function(isDowned)
	-- This fires only for the local player; other players' downed state arrives via CarryStateChanged and the
	-- attribute below, which the server keeps in step.
	if isDowned then
		-- Our own prompts must never target us.
		removePrompts(player)
	end
end)

-- Nobody gets a prompt on a passenger, and a passenger gets no prompts on anybody.
--
-- Someone slung over another player's shoulder is still downed, so the downed attribute alone went on
-- offering them as a rescue target -- to everyone walking past AND to the passenger themselves, who could
-- keep pressing F to be picked up again by whoever was already carrying them.
--
-- Two separate cases, both of which have to be covered:
--   * a carried TARGET is not someone you can revive or lift, so their prompts come down for everyone;
--   * a carried VIEWER cannot act at all, so every prompt they can see comes down, whoever it belongs to.
local function amCarried()
	return player:GetAttribute("WOLD_BeingCarried") == true
end

local function shouldOffer(target)
	if amCarried() then return false end
	if target:GetAttribute("WOLD_BeingCarried") then return false end
	return target:GetAttribute("WOLD_Downed") == true
end

-- The server marks downed players with an attribute so every client can see who to offer prompts on.
local function watchPlayer(target)
	if target == player then return end
	local function refresh()
		if shouldOffer(target) then
			addPrompts(target)
		else
			removePrompts(target)
		end
	end
	target:GetAttributeChangedSignal("WOLD_Downed"):Connect(refresh)
	target:GetAttributeChangedSignal("WOLD_BeingCarried"):Connect(refresh)
	target.CharacterAdded:Connect(function()
		removePrompts(target)
		task.wait(0.5)
		refresh()
	end)
	refresh()
end

-- When WE are picked up or put down, every prompt we can see has to be re-decided at once -- not just the
-- one on our carrier.
local function refreshEveryone()
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			if shouldOffer(other) then addPrompts(other) else removePrompts(other) end
		end
	end
end

player:GetAttributeChangedSignal("WOLD_BeingCarried"):Connect(refreshEveryone)

for _, other in ipairs(Players:GetPlayers()) do watchPlayer(other) end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(removePrompts)

-- Carrying someone: press the same key again to set them down.
local UserInputService = game:GetService("UserInputService")
local carryingSomeone = false
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Deliberately ignores gameProcessed: while carrying someone, that player's own "อุ้ม" ProximityPrompt is
	-- still in range and also bound to F, so it marks the key as consumed and the drop never fired.
	if not carryingSomeone then return end
	if input.KeyCode == Enum.KeyCode.F then
		Remotes.RequestDrop:FireServer()
	end
end)

--------------------------------------------------------------------------------
-- Animation playback
--------------------------------------------------------------------------------

Remotes.CarryStateChanged.OnClientEvent:Connect(function(actor, event, target)
	if event == "revive_start" and actor == player then
		if tracks.cpr then tracks.cpr:Play(0.2) end
	elseif event == "revive_end" and actor == player then
		if tracks.cpr then tracks.cpr:Stop(0.2) end
	elseif event == "carry_start" then
		if actor == player then
			carryingSomeone = true
			if tracks.holder then tracks.holder:Play(0.2) end
			-- Someone already on your back should not still be offering "ชุบ"/"อุ้ม".
			removePrompts(target)
		end
		if target == player then
			-- We are the one being carried: play the ride-along pose on our own rig.
			local character = player.Character
			local track = character and loadTrack(character, ActionConfig.Carry.heldAnimation, true)
			if track then
				track:Play(0.2)
				heldTracks[player] = track
			end
		end
	elseif event == "carry_end" then
		if actor == player then
			carryingSomeone = false
			if tracks.holder then tracks.holder:Stop(0.2) end
			-- Set down and still downed: the prompts come back so they can be picked up or revived again.
			if target and target:GetAttribute("WOLD_Downed") then
				task.delay(0.3, function()
					if target.Parent and target:GetAttribute("WOLD_Downed") then addPrompts(target) end
				end)
			end
		end
		if target == player and heldTracks[player] then
			heldTracks[player]:Stop(0.2)
			heldTracks[player] = nil
		end
	end
end)
