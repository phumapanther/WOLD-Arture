-- LobbyServer: only the public server (ServerConfig.IsLobby) runs this. Tracks live channel population
-- from MessagingService heartbeats and routes JoinChannel requests to a Reserved Server.
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsLobby then return end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ChannelRegistry = require(script.Parent.ChannelRegistry)
local Remotes = require(game.ReplicatedStorage.Remotes)

local FIXED_CHANNELS = { Roleplay = 5 } -- ponytail: one constant; raise the number here if you want more channels
local CAP = 30

local liveData = {} -- liveData[mode][channel] = { count, playerIds, updatedAt }
for mode in pairs(FIXED_CHANNELS) do
	liveData[mode] = {}
	ChannelRegistry.SubscribeToHeartbeats(mode, function(channel, count, playerIds)
		liveData[mode][channel] = { count = count, playerIds = playerIds, updatedAt = os.clock() }
	end)
end

local function snapshot()
	local out = {}
	for mode, count in pairs(FIXED_CHANNELS) do
		out[mode] = {}
		for ch = 1, count do
			local d = liveData[mode][ch]
			out[mode][ch] = {
				count = d and d.count or 0,
				playerIds = d and d.playerIds or {},
				full = (d and d.count or 0) >= CAP,
			}
		end
	end
	return out
end

Players.PlayerAdded:Connect(function(player)
	Remotes.ChannelList:FireClient(player, snapshot())
	for mode in pairs(FIXED_CHANNELS) do
		ChannelRegistry.RequestFreshData(mode)
	end
end)

Remotes.JoinChannel.OnServerEvent:Connect(function(player, mode, channel)
	if not FIXED_CHANNELS[mode] or type(channel) ~= "number" or channel < 1 or channel > FIXED_CHANNELS[mode] then
		return
	end
	local d = liveData[mode][channel]
	if d and d.count >= CAP then
		Remotes.JoinFailed:FireClient(player, "full")
		return
	end
	local ok, accessCode = pcall(ChannelRegistry.GetOrCreateChannel, mode, channel)
	if not ok then
		warn("[Lobby] could not get/create channel", mode, channel, accessCode)
		Remotes.JoinFailed:FireClient(player, "create_failed")
		return
	end
	local teleportOk, err = pcall(function()
		TeleportService:TeleportToPrivateServer(game.PlaceId, accessCode, { player })
	end)
	if not teleportOk then
		teleportOk, err = pcall(function()
			TeleportService:TeleportToPrivateServer(game.PlaceId, accessCode, { player })
		end) -- one retry, per spec §6
	end
	if not teleportOk then
		warn("[Lobby] teleport failed for", player.Name, err)
		Remotes.JoinFailed:FireClient(player, "teleport_failed")
	end
end)
