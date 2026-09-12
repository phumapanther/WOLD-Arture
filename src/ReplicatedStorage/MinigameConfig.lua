-- MinigameConfig: the two quick-time games, and every number that makes them feel the way they do.
--
-- There are exactly two, and everything in V1 that asks the player to prove they were paying attention uses
-- one of them:
--
--   "arrows"     — the Audition game. A row of directions appears and has to be pressed in order, in time.
--                  Used at the illegal farms (the still, the pipe, the crates).
--   "skillcheck" — the hammer-strike bar. A pointer sweeps a track and has to be stopped inside the green
--                  zone. Used during a transformer repair, where it pops up unannounced.
--
-- Shared by server and client: the server picks the numbers for one attempt out of these ranges and sends
-- them down, the client draws exactly what it was sent. Nothing here is read by the client to DECIDE
-- anything -- it is read to draw, and to know which key does what.
local MinigameConfig = {}

--------------------------------------------------------------------------------
-- Arrows (Audition)
--------------------------------------------------------------------------------

MinigameConfig.Arrows = {
	-- The four directions, in the order the on-screen pad lays them out. The names are what travel over the
	-- wire, so they are plain strings rather than KeyCodes -- a client should not be able to send an enum the
	-- server then has to interpret.
	Directions = { "Up", "Down", "Left", "Right" },

	-- How long a single attempt runs for. The sequence length is what makes a farm harder or easier, so it
	-- comes from the farm's own config; these are the bounds the server clamps it to.
	MinLength = 4,
	MaxLength = 8,

	-- Seconds allowed for each arrow. This is the "in time" half of the game: pressing the right direction
	-- too late is as much a miss as pressing the wrong one, which is what makes it a rhythm game rather than
	-- a spelling test.
	SecondsPerStep = 1.1,

	-- How long the row is shown before the first press is expected. Long enough to read four to eight arrows,
	-- short enough that it is still a reaction.
	LeadIn = 0.8,
}

--------------------------------------------------------------------------------
-- Skill check (the hammer strike)
--------------------------------------------------------------------------------

MinigameConfig.SkillCheck = {
	-- How wide the green zone is, as a fraction of the whole track. A quarter is generous; the difficulty
	-- comes from how fast the pointer moves and from being interrupted mid-repair, not from a sliver.
	MinZone = 0.13,
	MaxZone = 0.2,

	-- Full sweeps of the track per second. Rolled per pop, so two checks in one repair are never identical.
	MinSpeed = 0.62,
	MaxSpeed = 0.95,

	-- The attempt is over either way after this long, whether or not anything was pressed. Without it a
	-- player could simply never press and leave the repair hanging.
	Timeout = 6,
}

--------------------------------------------------------------------------------
-- Shared
--------------------------------------------------------------------------------

-- The floor on how quickly a "success" may be reported. A press that lands faster than a human hand could
-- move did not come from a hand, and the server treats it as a miss rather than trusting it.
MinigameConfig.MinPlausibleSeconds = 0.12

-- Extra grace on top of the client's own deadline before the server gives up waiting and calls it a failure.
-- Covers the round trip and a bad frame; anything longer than this and the answer is not coming.
MinigameConfig.ServerGrace = 3

return MinigameConfig
