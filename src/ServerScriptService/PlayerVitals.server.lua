-- PlayerVitals.server.lua: drives the vitals tick. All the logic lives in Vitals.lua (a module, because
-- PlayerMovement and PlayerCombat need to reach it too); this file only wires it to the game's lifecycle.
--
-- Gated to channel servers: the lobby has no gameplay, and firing VitalsUpdate where nothing listens fills
-- Roblox's unhandled-remote queue (the "invocation queue exhausted" spam PlayerMovement hit).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Vitals = require(game.ServerScriptService.Vitals)
local Remotes = require(game.ReplicatedStorage.Remotes)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)

if ServerConfig.IsLobby then return end

-- Respawn protection is visible: the character pulses transparent so other players can see it can't be hit.
-- Server-side so everyone sees the same thing, and accessories/hats blink along with the body.
local function blinkWhileInvulnerable(player, character)
	local parts = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			table.insert(parts, { part = descendant, original = descendant.Transparency })
		end
	end

	task.spawn(function()
		while Vitals.IsInvulnerable(player) and character.Parent do
			for _, entry in ipairs(parts) do
				if entry.part.Parent then entry.part.Transparency = math.min(1, entry.original + 0.55) end
			end
			task.wait(0.25)
			for _, entry in ipairs(parts) do
				if entry.part.Parent then entry.part.Transparency = entry.original end
			end
			task.wait(0.25)
		end
		-- Always land back on the original values, however the loop ended.
		for _, entry in ipairs(parts) do
			if entry.part.Parent then entry.part.Transparency = entry.original end
		end
	end)
end

PlayerJoin.Each(function(player)
	Vitals.Add(player)
	player.CharacterAdded:Connect(function(character)
		Vitals.ResetForRespawn(player)
		Vitals.Send(player, true)
		blinkWhileInvulnerable(player, character)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	Vitals.Remove(player)
end)

Remotes.RequestRespawn.OnServerEvent:Connect(function(player)
	-- Re-verified server-side: the instant-respawn button only means anything while actually downed.
	if not Vitals.IsDowned(player) then return end
	Vitals.Respawn(player)
end)

RunService.Heartbeat:Connect(function(dt)
	for player, state in pairs(Vitals.All()) do
		Vitals.Tick(player, state, dt)
		Vitals.Send(player)
	end
end)
