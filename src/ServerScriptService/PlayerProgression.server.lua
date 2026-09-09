-- PlayerProgression.server.lua: wires Progression into the game's lifecycle, and binds it to Vitals.
--
-- The two modules depend on each other (a level-up refills the bars; the bars' maximums depend on level), so
-- neither requires the other — this file injects each into the other once, at startup, before any player joins.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Progression = require(game.ServerScriptService.Progression)
local Classes = require(game.ServerScriptService.Classes)
local Vitals = require(game.ServerScriptService.Vitals)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)

if ServerConfig.IsLobby then return end

Progression.BindVitals(Vitals)
Vitals.BindProgression(Progression)
-- PlayerProfile calls this when it saves; publishing it here keeps the profile system free of any dependency
-- on progression.
ProfileAccess.SerializeProgression = Progression.Serialize

Players.PlayerAdded:Connect(function(player)
	-- Wait briefly for the profile session, so a returning player is restored at their saved level rather than
	-- flashing level 1. If it never arrives (a failed load) they start fresh, which is the safe direction.
	local saved
	for _ = 1, 40 do
		local data = ProfileAccess.Get(player)
		if data then
			saved = data.Progression
			break
		end
		task.wait(0.1)
	end
	Progression.Add(player, saved)

	-- Shared by CharacterAdded and by a character that already exists when this runs. Missing the second case
	-- left the very first character with no death hook at all, so the first death never cost a level.
	local function setUpCharacter(character)
		local humanoid = character:WaitForChild("Humanoid")

		-- Every death resets the level, whatever killed the player. Hooked to Humanoid.Died rather than to
		-- Vitals.Kill because a player can die by paths that never call it — drowning, the void, falling, or
		-- being killed by another player — and each of those must cost the level too.
		humanoid.Died:Connect(function()
			Progression.ResetOnDeath(player)
			-- The class goes with the level, and for the same reason: the card is offered at "level 5 with no
			-- basic class", so a player who kept theirs through a death would never be asked again. Hooked
			-- here rather than in a second Died listener of its own -- one death, one place that decides what
			-- a death costs.
			Classes.ResetOnDeath(player)
		end)

		-- Scale and tag have to be re-applied every respawn: the character is rebuilt from scratch.
		Progression.Refresh(player, character)
	end

	player.CharacterAdded:Connect(setUpCharacter)
	if player.Character then
		task.spawn(setUpCharacter, player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Progression.Remove(player)
end)
