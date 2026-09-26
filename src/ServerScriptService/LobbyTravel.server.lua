-- LobbyTravel.server.lua: the trip back to the lobby, and the things that call it off.
--
-- Pressing the menu's "back to lobby" used to save and teleport in the same breath. Nothing was wrong with
-- that except what the player saw, which was nothing: Roblox needs a few seconds to find or build a lobby
-- server and move them to it, and for all of those seconds the game looks exactly as it did before the press.
-- The button read as broken, and broken buttons get pressed again.
--
-- So the trip is now a thing that TAKES TIME on purpose, with a bar over it -- and once there is a window,
-- there is something that can happen during it. A blow landing, or going down, calls the whole thing off.
-- Leaving is not something you should be able to do while a monster is eating you.
--
-- The save still happens on the server and still happens BEFORE the teleport: PlayerRemoving does not
-- reliably fire before a teleport removes the character, which is what lost the save when the client did
-- this itself. ProfileAccess.Flush is PlayerProfile's own saveAll under another name.
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local Vitals = require(game.ServerScriptService.Vitals)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)

-- How long the bar takes to fill, in seconds.
--
-- Long enough that a monster arriving mid-trip has a chance to stop it, short enough that leaving a quiet
-- field is not a chore. It is NOT an attempt to cover the teleport itself -- that wait comes after this one
-- and has no length anybody can predict.
local TRAVEL_SECONDS = 5

-- Checked this often. A tenth of a second is far finer than a player can perceive and costs nothing for the
-- handful of people who are ever leaving at once.
local TICK = 0.1

local Travelling = {} -- [player] = true while the bar is filling
local Leaving = {} -- [player] = true ระหว่างลองเทเลพอร์ต (หลังแถบเต็มแล้ว)
local TELEPORT_ATTEMPTS, TELEPORT_WAIT = 3, 15 -- ลองกี่รอบ · รอผลรอบละกี่วินาที

local function stop(player, reason)
	if not Travelling[player] then return end
	Travelling[player] = nil
	if player:IsDescendantOf(Players) then
		Remotes.LobbyTravelChanged:FireClient(player, "stopped", reason)
	end
end

Remotes.RequestReturnToLobby.OnServerEvent:Connect(function(player)
	-- A second press while the bar is already running is the player asking again because they are not sure it
	-- heard them. Ignored rather than restarting the clock, which would punish exactly that doubt.
	if Travelling[player] then return end

	-- Refused outright when they are already down: the rule below would cancel it on the first tick anyway,
	-- and being told why immediately is better than watching a bar appear and die.
	if Vitals.IsDowned(player) then
		return Remotes.LobbyTravelChanged:FireClient(player, "stopped", "downed")
	end

	Travelling[player] = true
	Remotes.LobbyTravelChanged:FireClient(player, "started", TRAVEL_SECONDS)

	task.spawn(function()
		local startedAt = os.clock()
		local deadline = startedAt + TRAVEL_SECONDS

		while os.clock() < deadline do
			task.wait(TICK)
			if not Travelling[player] then return end -- something else already called it off
			if not player:IsDescendantOf(Players) then
				Travelling[player] = nil
				return
			end

			local state = Vitals.Get(player)
			if not state then
				Travelling[player] = nil
				return
			end
			if state.downed then return stop(player, "downed") end
			-- Any damage that actually landed since the press, EXCEPT starving. Hunger takes blood a sliver at
			-- a time for two minutes, so counting it would mean a starving player could never leave at all --
			-- and "I am hungry" is not the thing this rule is for. Only the kind can tell them apart, which is
			-- why Vitals writes it down rather than this watching HP.
			if state.lastHurtAt > startedAt and state.lastHurtKind ~= "starve" then
				return stop(player, "hit")
			end
		end

		if not Travelling[player] then return end
		if not player:IsDescendantOf(Players) then
			Travelling[player] = nil
			return
		end
		Travelling[player] = nil

		-- Past this line nothing can cancel any more: a teleport, once asked for, is Roblox's to finish.
		Remotes.LobbyTravelChanged:FireClient(player, "leaving")
		-- Guarded because this file and PlayerProfile are separate scripts with no ordering between them. In
		-- practice Flush is set long before anyone can press a button; a nil here would mean the profile system
		-- never started, in which case there is nothing to save anyway.
		if ProfileAccess.Flush then ProfileAccess.Flush(player) end

		-- **ต้องระบุเพลสหลัก ไม่ใช่ `game.PlaceId`**
		--
		-- ล็อบบี้คือเซิร์ฟสาธารณะของ *เพลสหลัก* · `game.PlaceId` ถูกตอนอยู่ในเพลสหลัก แต่บนเกาะ
		-- มันคือเลขของเกาะเอง = เทเลพอร์ตกลับมาที่เดิม ซึ่งดูเหมือนปุ่มไม่ทำงาน (ผู้ใช้แจ้ง 2026-09-22)
		local destination = ServerConfig.MainPlaceId or game.PlaceId
		-- เทเลพอร์ตที่ Roblox รับไปแล้วค้างเงียบได้ (ผู้ใช้แจ้ง 2026-09-26: สนาม PVP บนมือถือกดกลับล็อบบี้แล้วจอดำค้าง)
		-- → ลองซ้ำ 3 รอบ รอบละ 15 วิ · ยังอยู่ในเซิร์ฟนี้ครบทุกรอบ = คืนจอให้พร้อมบอกให้ลองใหม่ ไม่ปล่อยดำไปตลอด
		-- ระหว่างรอบ `Leaving` กันตัวดัก TeleportInitFailed ข้างล่างไม่ให้คืนจอก่อนรอบสุดท้าย
		Leaving[player] = true
		for attempt = 1, TELEPORT_ATTEMPTS do
			if not player:IsDescendantOf(Players) then break end
			local ok, err = pcall(function()
				TeleportService:TeleportAsync(destination, { player })
			end)
			if not ok then warn("[LobbyTravel] teleport attempt", attempt, "failed for", player.UserId, err) end
			local giveUpAt = os.clock() + TELEPORT_WAIT
			while os.clock() < giveUpAt and player:IsDescendantOf(Players) do task.wait(0.5) end
		end
		Leaving[player] = nil
		if player:IsDescendantOf(Players) then
			Remotes.LobbyTravelChanged:FireClient(player, "stopped", "failed")
		end
	end)
end)

-- A teleport that was ACCEPTED can still fail afterwards: a lobby that will not take them, a Roblox hiccup,
-- or Studio, where teleports are always refused. Teleport() does not throw in that case -- it returns
-- perfectly happily and the failure turns up here, later. Without this the player would be left under a bar
-- that says "on my way" and never moves again, which is a worse version of the problem the bar was added to
-- solve.
TeleportService.TeleportInitFailed:Connect(function(player, result, message)
	warn("[LobbyTravel] teleport rejected for", player.UserId, tostring(result), message)
	if Leaving[player] then return end -- ลูปลองซ้ำข้างบนยังไม่จบ มันคืนจอเองตอนหมดรอบ
	if player:IsDescendantOf(Players) then
		Remotes.LobbyTravelChanged:FireClient(player, "stopped", "failed")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Travelling[player] = nil
	Leaving[player] = nil
end)
