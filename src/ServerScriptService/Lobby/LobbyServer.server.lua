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

-- Rebroadcast on a timer so the counts go stale by at most this long. Without it the list was only ever sent
-- once, on join, so a server filling up while you sat on the menu still showed empty.
local REFRESH_SECONDS = 5

local function broadcast()
	local data = snapshot()
	for _, player in ipairs(Players:GetPlayers()) do
		Remotes.ChannelList:FireClient(player, data)
	end
end

task.spawn(function()
	while true do
		task.wait(REFRESH_SECONDS)
		if #Players:GetPlayers() > 0 then
			for mode in pairs(FIXED_CHANNELS) do
				ChannelRegistry.RequestFreshData(mode)
			end
			broadcast()
		end
	end
end)

-- The refresh button asks for an immediate update rather than waiting out the timer. Rate-limited per player
-- so holding it down cannot spam the cross-server data request.
local lastManualRefresh = {} -- [player] = os.clock()
Remotes.RequestChannelRefresh.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if lastManualRefresh[player] and now - lastManualRefresh[player] < 1 then return end
	lastManualRefresh[player] = now
	for mode in pairs(FIXED_CHANNELS) do
		ChannelRegistry.RequestFreshData(mode)
	end
	Remotes.ChannelList:FireClient(player, snapshot())
end)

Players.PlayerRemoving:Connect(function(player)
	lastManualRefresh[player] = nil
end)

-- Real teleport failures (server unreachable, and — always, in Studio — "there is no second server to reach")
-- are NOT thrown as Luau errors; TeleportToPrivateServer returns normally and Roblox reports the failure later
-- via this event instead. The pcall in the handler below only catches synchronous validation errors.
-- lastAttempt tracks each player's most recent access code ourselves, rather than trying to recover it from
-- the event's own parameters (TeleportOptions isn't reliably populated for the TeleportToPrivateServer call shape).
local lastAttempt = {} -- [player] = { accessCode: string, retried: boolean }

TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, targetPlaceId)
	if targetPlaceId ~= game.PlaceId then return end
	local attempt = lastAttempt[player]
	if attempt and not attempt.retried then
		attempt.retried = true -- per spec §6: one retry before giving up
		task.spawn(function()
			pcall(function() TeleportService:TeleportToPrivateServer(game.PlaceId, attempt.accessCode, { player }) end)
		end)
		return
	end
	lastAttempt[player] = nil
	warn("[Lobby] TeleportInitFailed for", player.Name, teleportResult, errorMessage)
	Remotes.JoinFailed:FireClient(player, "teleport_failed")
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
	lastAttempt[player] = { accessCode = accessCode, retried = false }
	local teleportOk, err = pcall(function()
		TeleportService:TeleportToPrivateServer(game.PlaceId, accessCode, { player })
	end)
	if not teleportOk then
		-- a synchronous throw means TeleportInitFailed will not also fire for this attempt; report it directly
		lastAttempt[player] = nil
		warn("[Lobby] teleport call threw for", player.Name, err)
		Remotes.JoinFailed:FireClient(player, "teleport_failed")
	end
	-- if teleportOk, either the teleport is proceeding for real, or (always, in Studio) it will fail
	-- asynchronously and be reported by the TeleportInitFailed handler above
end)
