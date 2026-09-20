-- LobbyServer: only the public server (ServerConfig.IsLobby) runs this. Tracks live channel population
-- from MessagingService heartbeats and routes JoinChannel requests to a Reserved Server.
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsLobby then return end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ChannelRegistry = require(script.Parent.ChannelRegistry)
local FarmRegistry = require(script.Parent.FarmRegistry)
local Vip = require(game.ServerScriptService.Vip)
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

--------------------------------------------------------------------------------
-- โหมดฟาร์มมิ่ง: เกาะของคุณเอง + เกาะที่คุณถูกชวน
--
-- ต่างจากช่อง Roleplay ที่มี 5 ห้องตายตัวเหมือนกันทุกคน — แถวของโหมดนี้ **ไม่เหมือนกันสักคน**
-- จึงคิดต่อคนตอนจะส่ง ไม่ใช่คิดรวมแล้วกระจาย
--
-- ทุกแถวต้องยิง DataStore (VIP หนึ่งครั้ง + รายชื่อเกาะที่ถูกชวนหนึ่งครั้ง) จึงแคชไว้ต่อคน:
-- ล็อบบี้ส่งรายการใหม่ทุก 5 วิอยู่แล้ว ถ้าไม่แคชคือยิง DataStore ทุก 5 วิต่อหัวจนโควตาหมด
local farmCache = {} -- [player] = { at = os.clock(), rows = {...} }
local FARM_CACHE_SECONDS = 30

local function nameOf(player)
	return player.DisplayName ~= "" and player.DisplayName or player.Name
end

local function farmRowsFor(player)
	local cached = farmCache[player]
	if cached and os.clock() - cached.at < FARM_CACHE_SECONDS then return cached.rows end

	local rows = {}
	local hasVip = Vip.PeekAsync and select(1, Vip.PeekAsync(player.UserId)) or false
	-- แถวของตัวเองมาก่อนเสมอ และ **ขึ้นให้เห็นแม้ยังไม่มี VIP** — ปุ่มที่หายไปไม่ได้ขายอะไรให้ใคร
	rows[#rows + 1] = {
		ownerId = player.UserId,
		ownerName = nameOf(player),
		mine = true,
		locked = (not hasVip) and "vip" or nil,
	}
	for ownerId, ownerName in pairs(FarmRegistry.InvitedTo(player.UserId)) do
		local id = tonumber(ownerId)
		if id and id ~= player.UserId then
			rows[#rows + 1] = { ownerId = id, ownerName = tostring(ownerName), mine = false }
		end
	end

	farmCache[player] = { at = os.clock(), rows = rows }
	return rows
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
	Remotes.ChannelList:FireClient(player, snapshot(), farmRowsFor(player))
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
		Remotes.ChannelList:FireClient(player, data, farmRowsFor(player))
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
	-- กดรีเฟรชเองคือการบอกว่า "ข้อมูลที่เห็นอาจเก่า" ทิ้งแคชเกาะไปด้วย ไม่งั้นคนเพิ่งซื้อ VIP
	-- จะยังเห็นแถวล็อกอยู่อีกครึ่งนาทีทั้งที่กดรีเฟรชแล้ว
	farmCache[player] = nil
	Remotes.ChannelList:FireClient(player, snapshot(), farmRowsFor(player))
end)

Players.PlayerRemoving:Connect(function(player)
	lastManualRefresh[player] = nil
	farmCache[player] = nil
end)

-- Real teleport failures (server unreachable, and — always, in Studio — "there is no second server to reach")
-- are NOT thrown as Luau errors; TeleportToPrivateServer returns normally and Roblox reports the failure later
-- via this event instead. The pcall in the handler below only catches synchronous validation errors.
-- lastAttempt tracks each player's most recent access code ourselves, rather than trying to recover it from
-- the event's own parameters (TeleportOptions isn't reliably populated for the TeleportToPrivateServer call shape).
local lastAttempt = {} -- [player] = { accessCode: string, retried: boolean }

TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, targetPlaceId)
	local attempt = lastAttempt[player]
	-- ปลายทางเป็นเพลสเกาะได้แล้ว ไม่ใช่เพลสนี้เสมอไป — เทียบกับเพลสที่พยายามไปจริง ไม่ใช่ `game.PlaceId`
	local expected = (attempt and attempt.placeId) or game.PlaceId
	if targetPlaceId ~= expected then return end
	if attempt and not attempt.retried then
		attempt.retried = true -- per spec §6: one retry before giving up
		task.spawn(function()
			pcall(function() TeleportService:TeleportToPrivateServer(expected, attempt.accessCode, { player }) end)
		end)
		return
	end
	lastAttempt[player] = nil
	warn("[Lobby] TeleportInitFailed for", player.Name, teleportResult, errorMessage)
	Remotes.JoinFailed:FireClient(player, "teleport_failed")
end)

-- เข้าเกาะฟาร์ม: `channel` คือ **userId ของเจ้าของเกาะ** ไม่ใช่เลขห้อง
--
-- ตรวจสิทธิ์ที่นี่ใหม่ทั้งหมด ไม่เชื่อแถวที่ไคลเอนต์เห็น: เกาะของตัวเองต้องมี VIP · เกาะคนอื่นต้องถูกชวนไว้จริง
local function joinFarm(player, ownerId)
	if ServerConfig.FarmingPlaceId == 0 then
		return Remotes.JoinFailed:FireClient(player, "farm_not_ready")
	end
	if ownerId == player.UserId then
		local hasVip = Vip.PeekAsync and select(1, Vip.PeekAsync(player.UserId)) or false
		if not hasVip then return Remotes.JoinFailed:FireClient(player, "need_vip") end
	elseif not FarmRegistry.IsGuest(ownerId, player.UserId) then
		return Remotes.JoinFailed:FireClient(player, "not_invited")
	end

	local ok, accessCode = pcall(FarmRegistry.GetOrCreate, ownerId)
	if not ok then
		warn("[Lobby] สร้างเกาะของ", ownerId, "ไม่ได้:", accessCode)
		return Remotes.JoinFailed:FireClient(player, "create_failed")
	end
	-- เกาะอยู่คนละเพลส จึงต้องบอกเลขเพลสด้วย (ของช่อง Roleplay เป็นเพลสเดียวกับล็อบบี้)
	lastAttempt[player] = { accessCode = accessCode, retried = false, placeId = ServerConfig.FarmingPlaceId }
	local teleportOk, err = pcall(function()
		TeleportService:TeleportToPrivateServer(ServerConfig.FarmingPlaceId, accessCode, { player })
	end)
	if not teleportOk then
		lastAttempt[player] = nil
		warn("[Lobby] เทเลพอร์ตเข้าเกาะล้มเหลวทันที:", err)
		Remotes.JoinFailed:FireClient(player, "teleport_failed")
	end
end

Remotes.JoinChannel.OnServerEvent:Connect(function(player, mode, channel)
	if mode == "Farming" then
		if type(channel) ~= "number" then return end
		return joinFarm(player, math.floor(channel))
	end
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
