-- ChannelServer: only a Reserved Server (not the lobby) runs this. Reports its own population periodically.
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local Players = game:GetService("Players")
local ChannelRegistry = require(script.Parent.ChannelRegistry)

local function currentPlayerIds()
	local ids = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(ids, p.UserId)
	end
	return ids
end

local function heartbeat()
	ChannelRegistry.PublishHeartbeat(ServerConfig.Mode, ServerConfig.Channel, #Players:GetPlayers(), currentPlayerIds())
end

ChannelRegistry.SubscribeToPings(ServerConfig.Mode, heartbeat)
heartbeat()

task.spawn(function()
	while true do
		task.wait(12)
		heartbeat()
	end
end)
