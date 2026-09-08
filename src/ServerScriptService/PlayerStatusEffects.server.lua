-- PlayerStatusEffects.server.lua: drives the status-effect timers and clears them across respawns. All the
-- logic lives in StatusEffects.lua (a module, because combat and movement both reach it); this only wires it
-- to the game's lifecycle, the same split as Vitals/PlayerVitals.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local StatusEffects = require(game.ServerScriptService.StatusEffects)
local Remotes = require(game.ReplicatedStorage.Remotes)

if ServerConfig.IsLobby then return end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- A fresh rig never inherits an old effect.
		StatusEffects.ClearFor(player)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then humanoid.PlatformStand = false end
		Remotes.StatusChanged:FireAllClients(player, "knockdown", false)
		Remotes.StatusChanged:FireAllClients(player, "slow", false)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	StatusEffects.ClearFor(player)
end)

RunService.Heartbeat:Connect(function()
	StatusEffects.Tick()
end)
