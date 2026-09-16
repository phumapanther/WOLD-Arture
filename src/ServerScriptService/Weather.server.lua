-- Weather.server.lua: what the sky is doing, and when it changes its mind.
--
-- The server owns the decision and nothing else. It picks a kind, eases it in, and tells every client --
-- which then draws its own rain, its own snow and its own lightning, at its own camera. A world-sized
-- particle field would cost every machine in the server the same money to render something only one player
-- can ever be standing in.
--
-- The LIGHTING half is not sent to anyone: DayNight already rewrites Lighting on the server four times a
-- second and it replicates, so weather hooks into that sample rather than racing it.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local WeatherConfig = require(game.ReplicatedStorage.WeatherConfig)
local WeatherAccess = require(game.ServerScriptService.WeatherAccess)
local DayNightAccess = require(game.ServerScriptService.DayNightAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)

-- What the sky is now, what it is turning into, and how far along that is.
local current = WeatherConfig.Default
local incoming = nil
local blend = 1

-- An admin-forced kind stays until it is released, the same way /time holds the clock: "make it rain" means
-- rain STAYS, not that it rains until the next roll two hours later.
local held = nil
local nextRollAt = os.clock() + WeatherConfig.RollEverySeconds

--------------------------------------------------------------------------------
-- Choosing
--------------------------------------------------------------------------------

local function pickWeighted()
	local total = 0
	for _, id in ipairs(WeatherConfig.Order) do
		total += WeatherConfig.Kinds[id].weight or 0
	end
	local roll = math.random() * total
	for _, id in ipairs(WeatherConfig.Order) do
		roll -= WeatherConfig.Kinds[id].weight or 0
		if roll <= 0 then return id end
	end
	return WeatherConfig.Default
end

-- Tells everyone what the sky is doing. The client needs the kind and how far along the change is; it reads
-- everything else out of the shared config itself.
local function broadcast()
	Remotes.WeatherChanged:FireAllClients(current, incoming, blend)
end

local function changeTo(kindId, announce)
	if kindId == current and not incoming then return end
	incoming = kindId
	blend = 0
	broadcast()

	local kind = WeatherConfig.Kinds[kindId]
	if announce and kind and kind.announce then
		Remotes.SocialNotify:FireAllClients("info", ("สภาพอากาศ: %s"):format(kind.name))
	end
end

--------------------------------------------------------------------------------
-- The clock
--------------------------------------------------------------------------------

local accumulator = 0

RunService.Heartbeat:Connect(function(dt)
	-- Easing the change in. Runs every frame because it is two floats; the roll below does not.
	if incoming then
		blend = math.min(1, blend + dt / WeatherConfig.TransitionSeconds)
		if blend >= 1 then
			current, incoming, blend = incoming, nil, 1
			broadcast()
		end
	end

	accumulator += dt
	if accumulator < 1 then return end
	accumulator = 0

	-- A held sky never rolls. The deadline still moves, so releasing the hold does not immediately fire a
	-- roll that was "due" during it.
	if held then
		nextRollAt = os.clock() + WeatherConfig.RollEverySeconds
		return
	end

	if os.clock() >= nextRollAt then
		nextRollAt = os.clock() + WeatherConfig.RollEverySeconds
		changeTo(pickWeighted(), true)
	end
end)

--------------------------------------------------------------------------------
-- Hand-offs
--------------------------------------------------------------------------------

-- DayNight calls this every time it writes Lighting. Returns the kind to draw and how far along it is: while
-- a change is easing, the INCOMING kind is the one being mixed towards, from a blend of zero.
--
-- **ห้ามเรียกตรงๆ ตอนบูต** DayNight.server อาจยังไม่ได้รัน ซึ่งแปลว่า `SetWeatherSource` ยังเป็น nil และ
-- ทั้งสคริปต์นี้จะตายทันทีด้วย "attempt to call a nil value" — เจอจริงตอนเทส ผลคือระบบอากาศทั้งระบบเงียบ
-- ทั้งรอบ ทั้งที่ไม่มีอะไรผิดในตัวมันเอง ลำดับการรันของสคริปต์ใน ServerScriptService ไม่มีใครรับประกัน
local function publishSource()
	local fn = function()
		if incoming then return incoming, blend end
		return current, 1
	end
	if DayNightAccess.SetWeatherSource then
		DayNightAccess.SetWeatherSource(fn)
		return true
	end
	return false
end

if not publishSource() then
	task.spawn(function()
		-- ถามใหม่จนกว่า DayNight จะพร้อม กฎเดียวกับที่ใช้ทั้งโปรเจ็ค: ลูปที่ถามใหม่ไม่มีจังหวะให้แพ้
		for _ = 1, 60 do
			task.wait(0.5)
			if publishSource() then return end
		end
		warn("[Weather] DayNight ไม่พร้อมใน 30 วินาที — แสงจะไม่เปลี่ยนตามอากาศ (ฝน/หิมะยังตกปกติ)")
	end)
end

WeatherAccess.Set = function(kindId)
	if kindId == nil then
		held = nil
		-- Released: roll one now rather than leaving whatever the admin forced sitting there for two hours.
		changeTo(pickWeighted(), true)
		return current
	end
	if not WeatherConfig.Kinds[kindId] then return current end
	held = kindId
	changeTo(kindId, true)
	return kindId
end

WeatherAccess.Current = function()
	return incoming or current
end

-- A player who joins mid-storm should arrive in the storm. Sent on join rather than asked for, because the
-- client has nothing useful to draw until it knows.
Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		if player.Parent then
			Remotes.WeatherChanged:FireClient(player, current, incoming, blend)
		end
	end)
end)
