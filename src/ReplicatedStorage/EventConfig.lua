-- EventConfig: the two things the world does to itself, and everything about how they look and when.
--
-- Shared by server and client. The server owns the schedule and decides what is running; the client reads
-- this only to draw the banner -- the icon, the wording, the colour. Nothing here lets a client decide that
-- an event is happening.
local EventConfig = {}

-- Nobody gets an event in an empty server. Both of these are things that happen TO a town: three mutant
-- slimes and a city-wide power cut are a crowd's problem, and in a server of two they are just an
-- interruption with nobody to share it with.
--
-- The countdown does not even START below this. A server that dips under ten while the clock is running
-- keeps it -- the check is for beginning, not for continuing -- because losing the eleventh player halfway
-- through would otherwise reset a timer nobody can see.
EventConfig.MinPlayers = 10

-- How often the scheduler looks at the clock. Events are measured in tens of minutes; a second's resolution
-- on a half-hour timer costs nothing and keeps the loop trivially simple.
EventConfig.TickSeconds = 1

--------------------------------------------------------------------------------

EventConfig.Events = {
	--------------------------------------------------------------------------
	-- The mutant slimes. Three of them at once, for half an hour, every half hour.
	--
	-- Before V1 the three named slimes stood in the world permanently and came back thirty minutes after
	-- they died, which made them a place you visited rather than a thing that happened. As an event they are
	-- the opposite: they are not there at all until the announcement, and they are gone when it ends,
	-- whether anyone killed them or not.
	--------------------------------------------------------------------------
	slime = {
		icon = "rbxassetid://139399362647202", -- assets/item-icons/event_slime.png
		message = "สไลม์กลายพันธุ์",
		sound = "EventSlime",
		colour = Color3.fromRGB(126, 226, 140),
		-- Every half hour, lasting half an hour: one is always either running or half an hour away.
		everySeconds = 30 * 60,
		durationSeconds = 30 * 60,
	},

	--------------------------------------------------------------------------
	-- The city's engines fail.
	--
	-- The only event with no clock on it. It ends when every transformer in the map has been repaired and
	-- not a moment before, which is why the banner's right-hand side shows a count of machines rather than a
	-- countdown -- there is nothing to count down to.
	--------------------------------------------------------------------------
	blackout = {
		icon = "rbxassetid://115675604536116", -- assets/item-icons/event_electric.png
		message = "เครื่องยนต์ไอน้ำ ขัดข้อง",
		sound = "EventBlackout",
		colour = Color3.fromRGB(255, 196, 92),
		-- Random rather than fixed, so it is never something players can stand around waiting for.
		minGapSeconds = 25 * 60,
		maxGapSeconds = 45 * 60,
		-- No durationSeconds on purpose: see above.
	},
}

--------------------------------------------------------------------------------
-- What a blackout does to the world
--------------------------------------------------------------------------------

-- How much darker every screen gets. A quarter, as the user asked, applied as a ColorCorrection on the
-- CLIENT: Lighting is not replicated per player, and doing it on the server would also darken the lobby and
-- anyone in a menu.
EventConfig.BlackoutDarkness = 0.25

-- How long the screen takes to fall dark and come back. Instant would read as a graphics glitch; this reads
-- as the lamps going out one street at a time.
EventConfig.BlackoutFadeSeconds = 2.5

--------------------------------------------------------------------------------
-- Putting a transformer back together
--------------------------------------------------------------------------------

-- The repair is thirty seconds of standing still while skill checks interrupt you. What makes it a
-- commitment rather than a wait is that WALKING ENDS IT: the whole thirty seconds is lost, not paused.
EventConfig.Repair = {
	Seconds = 30,
	Range = 10,

	-- How far you may drift from where you started before the repair drops. Generous enough to cover the
	-- character settling and a nudge from someone running past, tight enough that a step away is a step away.
	LeaveDistance = 6,

	-- Two to four checks in the thirty seconds, never two in the same breath. The first is held back so the
	-- player has a moment to realise the repair has begun before being asked to react to something.
	MinChecks = 2,
	MaxChecks = 4,
	FirstCheckAfter = 4,
	MinCheckGap = 5,

	-- What a missed check costs. Shorter than the farms' five seconds because the repair can be tried again
	-- immediately -- the punishment is the thirty seconds you just lost, and being rooted on top of that for
	-- five would be punishing the same mistake twice.
	DizzySeconds = 2,

	-- One roll from this table on a finished repair, plus the silver, so every repair is worth something.
	-- "กระดาษ" in the user's list is the blueprint: it is the paper item the game already has.
	Rewards = {
		{ item = "GearSpare", min = 1, max = 2 },
		{ item = "Chemical", min = 1, max = 2 },
		{ item = "Coal", min = 1, max = 2 },
		{ item = "Blueprint", min = 1, max = 1 },
		{ item = "Silver", min = 20, max = 60 },
	},
	-- Coin, on top of whatever the roll gave. The repair is civic work and the city pays for it.
	GoldMin = 150,
	GoldMax = 400,
	Xp = 30,
}

return EventConfig
