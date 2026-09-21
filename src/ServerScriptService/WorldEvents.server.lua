-- WorldEvents.server.lua: the clock the world runs on.
--
-- Owns three things and nothing else: WHEN an event happens, WHAT the announcement says, and telling every
-- client the current picture. What an event actually DOES to the world belongs to whichever system owns that
-- part of the world -- the transformers implement the blackout, the monster spawners implement the slimes --
-- and each registers a start/stop pair with EventState. This file calls them without knowing what they do.
--
-- The whole set of live events is broadcast on every change rather than "started"/"ended" messages. A
-- snapshot cannot be missed, cannot arrive out of order, and answers a latecomer's first question with the
-- same message everyone else already got.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local EventConfig = require(game.ReplicatedStorage.EventConfig)
local EventState = require(game.ServerScriptService.EventState)
local Remotes = require(game.ReplicatedStorage.Remotes)

--------------------------------------------------------------------------------
-- Telling everyone
--------------------------------------------------------------------------------

-- Built fresh each time from EventState plus the config, so the client is sent everything it needs to draw a
-- banner and nothing it could use to decide one. Times are in SERVER time, which is the same clock on every
-- machine -- os.clock on the server would be meaningless anywhere else.
local function picture()
	local out = {}
	for id, entry in pairs(EventState.Active) do
		local config = EventConfig.Events[id]
		out[id] = {
			icon = config and config.icon,
			message = config and config.message,
			colour = config and config.colour,
			startedAt = entry.startedAt,
			endsAt = entry.endsAt,
			detail = entry.detail,
			-- { current, maximum } ของเป้าหมายที่มีเลือด (บอสโลก) — ไม่มี = ไม่มีหลอดใต้ป้าย
			hp = entry.hp,
		}
	end
	return out
end

local function publish()
	Remotes.EventStateChanged:FireAllClients(picture())
end

EventState.Publish = publish

Remotes.RequestEventState.OnServerEvent:Connect(function(player)
	Remotes.EventStateChanged:FireClient(player, picture())
end)

--------------------------------------------------------------------------------
-- Starting and stopping
--------------------------------------------------------------------------------

local function stop(id)
	if not EventState.Active[id] then return end
	EventState.Active[id] = nil

	local hooks = EventState.Hooks[id]
	if hooks and hooks.stop then
		local ok, err = pcall(hooks.stop)
		if not ok then warn(("[WorldEvents] %s stop handler failed: %s"):format(id, tostring(err))) end
	end
	publish()
	print(("[WOLD] event %s ended"):format(id))
end

-- `seconds` ตัดหน้า `durationSeconds` ของคอนฟิก ใช้ตอนเซิร์ฟบูตมากลางอีเวนต์ที่ผูกกับนาฬิกาจริง
-- (บอสโลกเกิดสองทุ่ม เซิร์ฟที่บูตสองทุ่มครึ่งต้องได้เวลาที่เหลือ 29 นาที ไม่ใช่ 59 นาทีใหม่)
local function start(id, seconds)
	if EventState.Active[id] then return end
	local config = EventConfig.Events[id]
	if not config then return end

	local runFor = seconds or config.durationSeconds
	local now = workspace:GetServerTimeNow()
	EventState.Active[id] = {
		startedAt = now,
		-- An event with no duration runs until something ends it. The blackout is the one: it is over when
		-- the last transformer is fixed and not a second earlier.
		endsAt = runFor and (now + runFor) or nil,
	}

	local hooks = EventState.Hooks[id]
	if hooks and hooks.start then
		local ok, err = pcall(hooks.start)
		if not ok then
			warn(("[WorldEvents] %s start handler failed: %s"):format(id, tostring(err)))
			-- An event whose effects failed to apply is an announcement with nothing behind it, which is
			-- worse than no announcement: players would go looking for something that is not there.
			EventState.Active[id] = nil
			return
		end
	end

	publish()
	print(("[WOLD] event %s started"):format(id))

	if runFor then
		task.delay(runFor, function()
			stop(id)
		end)
	end
end

-- Published so an event's own system can end it. The blackout uses this the moment the last machine is
-- repaired; nothing else needs it, because everything else ends on its own clock.
EventState.Stop = stop
EventState.Start = start

--------------------------------------------------------------------------------
-- The schedule
--------------------------------------------------------------------------------

-- Seconds until each event next fires. Counted down only while the server is busy enough to deserve one --
-- see EventConfig.MinPlayers for why the check is on STARTING the countdown rather than on continuing it.
local NextIn = {}

local function rollGap(config)
	if config.everySeconds then return config.everySeconds end
	local low = config.minGapSeconds or 600
	local high = config.maxGapSeconds or low
	return low + math.random() * (high - low)
end

--------------------------------------------------------------------------------
-- อีเวนต์ที่ผูกกับนาฬิกาจริง (`atHour`)
--------------------------------------------------------------------------------

-- ต่างจากอีเวนต์แบบ "ทุกๆ กี่นาที" ตรงที่มันไม่ได้นับจากตอนเซิร์ฟบูต — ทุกเซิร์ฟที่เปิดอยู่ตอนสองทุ่ม
-- จะเริ่มพร้อมกัน เพราะทุกเซิร์ฟอ่านนาฬิกาเรือนเดียวกัน (`os.time()` เป็น UTC ทุกเครื่อง)
--
-- คืน **เวลาเริ่มของรอบที่ครอบ `now` อยู่** ถ้ามี ไม่งั้นคืนรอบถัดไป — สองอย่างนี้ต่างกันตรงที่รอบแรก
-- แปลว่า "เริ่มเดี๋ยวนี้ด้วยเวลาที่เหลือ" ส่วนรอบหลังแปลว่า "รออีกเท่านี้"
local function hourWindow(config, now)
	local offset = config.timeZoneOffsetSeconds or EventConfig.TimeZoneOffsetSeconds or 0
	local localNow = now + offset
	local dayStart = math.floor(localNow / 86400) * 86400
	local todayAt = dayStart + config.atHour * 3600

	-- รอบของ "เมื่อวาน" ต้องคิดด้วย: อีเวนต์ที่เริ่ม 23:30 แล้วยาวข้ามเที่ยงคืน ตอนตีหนึ่งยังอยู่ในรอบนั้น
	local duration = config.durationSeconds or 0
	for _, startLocal in ipairs({ todayAt - 86400, todayAt }) do
		if localNow >= startLocal and localNow < startLocal + duration then
			return startLocal - offset, (startLocal + duration) - localNow
		end
	end

	local nextLocal = (localNow < todayAt) and todayAt or (todayAt + 86400)
	return nextLocal - offset, nil
end

for id, config in pairs(EventConfig.Events) do
	if not config.atHour then NextIn[id] = rollGap(config) end
end

-- รอบที่เซิร์ฟนี้ปล่อยไปแล้ว: กันอีเวนต์ประจำเวลาเริ่มซ้ำตัวเองภายในนาทีเดียวกัน
-- (ลูปเดินทุกวินาที ส่วนหน้าต่างเวลากว้างเป็นนาที)
local FiredWindow = {}

task.spawn(function()
	while true do
		task.wait(EventConfig.TickSeconds)

		local online = #Players:GetPlayers()
		local now = os.time()

		for id, config in pairs(EventConfig.Events) do
			-- จำนวนคนขั้นต่ำเป็นรายอีเวนต์ได้ ไม่ใช่ค่าเดียวทั้งระบบ: บอสโลกเป็นเวลานัด ถ้ามันรอคนครบสิบ
			-- เหมือนสไลม์ คนที่มารอตามนัดในเซิร์ฟเล็กจะไม่เจออะไรเลย
			local enough = online >= (config.minPlayers or EventConfig.MinPlayers)

			-- An event already running does not count down towards its own next firing. Half an hour of
			-- slimes followed immediately by another half hour would never let the world be quiet.
			if enough and not EventState.Active[id] then
				if config.atHour then
					local windowStart, remaining = hourWindow(config, now)
					if remaining and FiredWindow[id] ~= windowStart then
						FiredWindow[id] = windowStart
						-- เหลือน้อยเกินกว่าจะสู้ได้ก็ข้ามรอบนี้ไป **แต่ยังปั๊มว่ารอบนี้ผ่านไปแล้ว**
						-- ไม่งั้นทุกวินาทีที่เหลือของหน้าต่างจะถามคำถามเดิมซ้ำ
						if remaining >= (config.minRemainingSeconds or 0) then start(id, remaining) end
					end
				else
					NextIn[id] -= EventConfig.TickSeconds
					if NextIn[id] <= 0 then
						NextIn[id] = rollGap(config)
						start(id)
					end
				end
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Admin: /event
--------------------------------------------------------------------------------

-- Exposed for AdminCommands so an event can be tested without ten players and half an hour of waiting. The
-- functions are already published above; this is only a note that they are the intended door.
