-- FarmConfig: the three illegal trades, and what each one is worth.
--
-- Nodes are found by TAG, exactly like the gathering nodes in GatherConfig: anything tagged WOLD_Farm with a
-- FarmKind attribute naming an entry below becomes workable, wherever it came from. The user places the
-- models (or mapgen/63_farm_nodes.lua tags the ones already in the world) and this file never knows where any
-- of them are.
--
-- These are NOT gathering nodes, and the difference is the point:
--   * no tool is needed, so this is what a player with nothing can do
--   * the cooldown is half an hour and belongs to the WHOLE SERVER, not to the player -- a spot someone has
--     just worked is worked for everybody
--   * the reward is won, not taken: a rhythm minigame stands between the press and the goods, and failing it
--     costs the attempt AND leaves you standing there seeing stars
local FarmConfig = {}

-- Half an hour, as the user asked, and it starts THE MOMENT the button is pressed -- not when the minigame
-- ends. Failing does not give the spot back, which is what makes the minigame worth taking seriously.
FarmConfig.CooldownSeconds = 30 * 60

-- How close you have to stand. Matched to GatherConfig.Range so every "press E at a thing in the world" in
-- the game has the same reach.
FarmConfig.Range = 10

-- The character rummages for this long before the minigame appears, with the rummaging sound playing at the
-- node. Long enough to read as an action rather than a menu; short enough not to be a wait.
FarmConfig.SearchSeconds = 1.4

-- What a failed attempt costs: rooted where you stand, seeing stars, unable to move. The user's five seconds.
FarmConfig.DizzySeconds = 5

-- The rummaging animation, played on the character while they search. Left empty deliberately: the
-- KeyframeSequence is built by `animgen/farm.lua` into ServerStorage.WOLD_Animations and has to be published
-- from the place owner's own account before it has an id (right-click the sequence -> Save to Roblox, then
-- paste the rbxassetid:// here). An empty string is safe -- the whole system runs, it is just quieter.
FarmConfig.SearchAnimation = ""

-- Played at the node rather than at the player, so everyone nearby hears where the work is happening --
-- the same rule the gathering strikes follow.
FarmConfig.SearchSound = "rbxassetid://113584262071963" -- assets/sounds/rummaging
FarmConfig.SearchVolume = 0.45
FarmConfig.SearchDistance = 55

--------------------------------------------------------------------------------
-- The three spots
--------------------------------------------------------------------------------

-- `sequence` is how many arrows the minigame asks for. It is the only difficulty dial: the crates are the
-- easy one a new player can manage, the reactor is the one you have to concentrate on.
--
-- `rewards` is a list of things given on success, each with a min and a max. `oneOf` instead means "roll ONE
-- of these", which is what the crates do -- a crate gives coal OR a blueprint OR a handful of silver, never
-- all three.
FarmConfig.Nodes = {
	DistillSet = {
		prompt = "ผลิต",
		object = "ชุดกลั่นเคมี",
		sequence = 5,
		xp = 18,
		rewards = { { item = "Chemical", min = 2, max = 3 } },
	},
	Reactor = {
		prompt = "งัด",
		object = "ถังปฏิกรณ์",
		sequence = 6,
		xp = 20,
		rewards = { { item = "GearSpare", min = 2, max = 3 } },
	},
	Boxs = {
		prompt = "ขโมย",
		object = "ลังสินค้า",
		sequence = 4,
		xp = 12,
		-- Even odds across the three, because the silver band (30-100) is already the wide one: weighting it
		-- down as well would make a crate feel like it mostly gives nothing.
		oneOf = {
			{ item = "Coal", min = 1, max = 1 },
			{ item = "Blueprint", min = 1, max = 1 },
			{ item = "Silver", min = 30, max = 100 },
		},
	},
}

return FarmConfig
