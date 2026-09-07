-- PlayerPosition.server.lua: the only file that touches the player-position DataStore. Answers the client's
-- GetSpawnPosition RemoteFunction (SpawnSelector can't reach DataStoreService itself — client-only), saves the
-- player's position when they ask to return to the lobby (RequestReturnToLobby, saved server-side BEFORE the
-- teleport is issued), and PlayerRemoving as a backup for real disconnects/crashes that never fire that event.
--
-- PlayerRemoving alone is NOT reliable for the teleport-out case: it's a documented Roblox behavior that
-- PlayerRemoving does not consistently fire before TeleportService actually removes the character, so a
-- character read at that point can already be gone (https://devforum.roblox.com/t/1789562,
-- https://devforum.roblox.com/t/1794382). Confirmed as the root cause of a real bug here: position saved on
-- "return to lobby" was silently lost, so the next join fell back to the default spawn point instead.
--
-- Respawn-repositioning and save-on-leave are channel-server-only: the lobby has its own dedicated LobbySpawn
-- room, and saving a player's position while they're standing in that room (y=1000+) would clobber a real saved
-- map position with lobby coordinates.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
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

local function savePosition(player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end -- never spawned in this session — nothing to save
	local p = hrp.Position
	local ok, err = pcall(function()
		store:SetAsync(key(player.UserId), { x = p.X, y = p.Y, z = p.Z })
	end)
	if not ok then warn("[PlayerPosition] save failed for", player.UserId, err) end
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

	-- Primary save path: the client asks to return to the lobby, server saves THEN teleports. Saving here
	-- (character still fully exists) is what actually fixed the lost-position bug — see the file header.
	Remotes.RequestReturnToLobby.OnServerEvent:Connect(function(player)
		savePosition(player)
		local ok, err = pcall(function()
			TeleportService:Teleport(game.PlaceId, player)
		end)
		if not ok then warn("[PlayerPosition] return-to-lobby teleport failed for", player.UserId, err) end
	end)

	-- Backup save path: real disconnects/crashes never fire RequestReturnToLobby. PlayerRemoving's timing
	-- relative to character teardown isn't guaranteed on every leave path, but it's the only hook available
	-- here — better than nothing for the cases the primary path doesn't cover.
	Players.PlayerRemoving:Connect(function(player)
		hasSpawnedOnce[player] = nil
		savePosition(player)
	end)
end
