-- PlayerProgression.server.lua: wires Progression into the game's lifecycle, and binds it to Vitals.
--
-- The two modules depend on each other (a level-up refills the bars; the bars' maximums depend on level), so
-- neither requires the other — this file injects each into the other once, at startup, before any player joins.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Progression = require(game.ServerScriptService.Progression)
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

	player.CharacterAdded:Connect(function(character)
		-- Scale and tag have to be re-applied every respawn: the character is rebuilt from scratch.
		character:WaitForChild("Humanoid")
		Progression.Refresh(player, character)
	end)

	if player.Character then
		Progression.Refresh(player, player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Progression.Remove(player)
end)
