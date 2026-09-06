-- ChannelRegistry.lua: the only file that touches DataStoreService / MessagingService / TeleportService for channels.
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local TeleportService = game:GetService("TeleportService")

local store = DataStoreService:GetDataStore("WOLD_ChannelRegistry_v1")

local ChannelRegistry = {}

local function slotKey(mode, channel)
	return ("slot_%s_%d"):format(mode, channel)
end
local function codeKey(privateServerId)
	return "code_" .. privateServerId
end

function ChannelRegistry.GetOrCreateChannel(mode, channel)
	-- Deliberately NOT built on UpdateAsync: ReserveServer is a side-effecting, non-idempotent external call
	-- (it really reserves a server), and Roblox may invoke an UpdateAsync transform function more than once
	-- internally on write contention — calling ReserveServer inside one would risk reserving extra servers for
	-- the same slot even in normal operation. Get-then-set is simpler and keeps ReserveServer to exactly one call.
	-- ReserveServer only works on a real published server (HTTP 403 in Studio, Play or not); errors here are
	-- expected in Studio and only resolvable by a real publish — see spec §6 and plan Task 7.
	local key = slotKey(mode, channel)
	local getOk, existing = pcall(function()
		return store:GetAsync(key)
	end)
	if not getOk then
		error("[ChannelRegistry] GetOrCreateChannel(" .. mode .. ", " .. channel .. ") lookup failed: " .. tostring(existing), 0)
	end
	if existing then
		return existing.accessCode
	end

	local reserveOk, accessCode, privateServerId = pcall(TeleportService.ReserveServer, TeleportService, game.PlaceId)
	if not reserveOk then
		error("[ChannelRegistry] ReserveServer failed for " .. mode .. "/" .. channel .. ": " .. tostring(accessCode), 0)
	end

	-- ponytail: known small race — two players picking an empty slot at the same instant can each reserve a
	-- server; the second write below wins and the first reservation is orphaned (wasted, harmless at hobby scale)
	local setOk, setErr = pcall(function()
		store:SetAsync(key, { accessCode = accessCode, privateServerId = privateServerId, createdAt = os.time() })
	end)
	if not setOk then
		warn("[ChannelRegistry] failed to persist new slot (a reserved server now exists but is not recorded):", setErr)
	end
	local revOk, revErr = pcall(function()
		store:SetAsync(codeKey(privateServerId), { mode = mode, channel = channel })
	end)
	if not revOk then warn("[ChannelRegistry] failed to write reverse lookup:", revErr) end
	return accessCode
end

function ChannelRegistry.IdentifySelfFor(privateServerId)
	if privateServerId == "" then
		return nil, nil
	end
	local ok, data = pcall(function()
		return store:GetAsync(codeKey(privateServerId))
	end)
	if ok and data then
		return data.mode, data.channel
	end
	warn("[ChannelRegistry] could not identify self for PrivateServerId", privateServerId)
	return "Roleplay", 0
end

function ChannelRegistry.IdentifySelf()
	return ChannelRegistry.IdentifySelfFor(game.PrivateServerId)
end

function ChannelRegistry.PublishHeartbeat(mode, channel, count, playerIds)
	local ok, err = pcall(function()
		MessagingService:PublishAsync("ChannelHeartbeat_" .. mode, {
			channel = channel,
			count = count,
			playerIds = playerIds,
			ts = os.time(),
		})
	end)
	if not ok then warn("[ChannelRegistry] heartbeat publish failed:", err) end
end

function ChannelRegistry.SubscribeToHeartbeats(mode, callback)
	MessagingService:SubscribeAsync("ChannelHeartbeat_" .. mode, function(message)
		local d = message.Data
		callback(d.channel, d.count, d.playerIds)
	end)
end

function ChannelRegistry.RequestFreshData(mode)
	local ok, err = pcall(function()
		MessagingService:PublishAsync("ChannelPing_" .. mode, { ts = os.time() })
	end)
	if not ok then warn("[ChannelRegistry] ping publish failed:", err) end
end

function ChannelRegistry.SubscribeToPings(mode, callback)
	MessagingService:SubscribeAsync("ChannelPing_" .. mode, function()
		callback()
	end)
end

return ChannelRegistry
