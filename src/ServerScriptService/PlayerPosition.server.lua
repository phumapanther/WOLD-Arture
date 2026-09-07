-- PlayerPosition.server.lua: the only file that touches the player-position DataStore. Answers the client's
-- GetSpawnPosition RemoteFunction (SpawnSelector can't reach DataStoreService itself — client-only) and saves
-- the player's last position on PlayerRemoving (covers disconnect and the return-to-lobby teleport, both of
-- which fire it). One save trigger only, no periodic autosave — see docs/superpowers/specs/2026-09-07-player-position-design.md.
-- Respawn-repositioning and save-on-leave are channel-server-only: the lobby has its own dedicated LobbySpawn
-- room, and saving a player's position while they're standing in that room (y=1000+) would clobber a real saved
-- map position with lobby coordinates.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)
local SpawnSelector = require(game.ReplicatedStorage.SpawnSelector)

local store = DataStoreService:GetDataStore("WOLD_PlayerPosition_v1")

local function key(userId)
	return "pos_" .. userId
end

local function loadSavedPosition(userId)
	local ok, data = pcall(function()
		return store:GetAsync(key(userId))
	end)
	if not ok then
		warn("[PlayerPosition] load failed for", userId, data)
		return nil
	end
	if not data then return nil end
	return Vector3.new(data.x, data.y, data.z)
end

Remotes.GetSpawnPosition.OnServerInvoke = function(player)
	local saved = loadSavedPosition(player.UserId)
	return SpawnSelector.ResolvePosition(saved)
end

-- Respawn-on-death: Roblox's own respawn just grabs whatever SpawnLocation is in workspace, bypassing this
-- entirely (same root cause as the earlier lobby-room bug) — reposition every respawn ourselves instead. The
-- first spawn of a session is skipped here: LoadingController.client.lua already choreographs it (raycast wait,
-- loading-screen timing) via the same GetSpawnPosition remote, so repositioning it again here would just fight
-- that sequence.
local hasSpawnedOnce = {} -- [player] = true once their first CharacterAdded this session has fired
if not ServerConfig.IsLobby then
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			if not hasSpawnedOnce[player] then
				hasSpawnedOnce[player] = true
				return
			end
			local hrp = character:WaitForChild("HumanoidRootPart")
			local saved = loadSavedPosition(player.UserId)
			hrp.CFrame = CFrame.new(SpawnSelector.ResolvePosition(saved))
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		hasSpawnedOnce[player] = nil
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end -- never spawned in this session — nothing to save
		local p = hrp.Position
		local ok, err = pcall(function()
			store:SetAsync(key(player.UserId), { x = p.X, y = p.Y, z = p.Z })
		end)
		if not ok then warn("[PlayerPosition] save failed for", player.UserId, err) end
	end)
end
