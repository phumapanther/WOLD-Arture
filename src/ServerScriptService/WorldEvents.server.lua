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

local function start(id)
	if EventState.Active[id] then return end
	local config = EventConfig.Events[id]
	if not config then return end

	local now = workspace:GetServerTimeNow()
	EventState.Active[id] = {
		startedAt = now,
		-- An event with no duration runs until something ends it. The blackout is the one: it is over when
		-- the last transformer is fixed and not a second earlier.
		endsAt = config.durationSeconds and (now + config.durationSeconds) or nil,
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

	if config.durationSeconds then
		task.delay(config.durationSeconds, function()
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

for id, config in pairs(EventConfig.Events) do
	NextIn[id] = rollGap(config)
end

task.spawn(function()
	while true do
		task.wait(EventConfig.TickSeconds)

		local enough = #Players:GetPlayers() >= EventConfig.MinPlayers
		if enough then
			for id, config in pairs(EventConfig.Events) do
				-- An event already running does not count down towards its own next firing. Half an hour of
				-- slimes followed immediately by another half hour would never let the world be quiet.
				if not EventState.Active[id] then
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
