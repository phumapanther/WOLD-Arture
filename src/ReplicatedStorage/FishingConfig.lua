-- FishingConfig: what the water gives up, how often, and what it costs.
--
-- The loot table is written out here rather than pulled from a library. A weighted pick is nine lines of
-- Lua (see Fishing.server), and the reference suggested for it -- Sleitnick/RbxLootTable -- does not exist;
-- neither does the roblox-fishing-system topic, which has no repositories at all.
local FishingConfig = {}

-- One worm per catch, as asked. No worms, no fishing.
FishingConfig.BaitItem = "Worm"
FishingConfig.BaitPerCatch = 1

-- How long between catches. A range rather than a fixed number so two people fishing side by side do not
-- land theirs in lockstep.
FishingConfig.MinSeconds = 20
FishingConfig.MaxSeconds = 30

-- How far ahead the cast looks for water, and how far down. Generous, so standing near a bank counts
-- rather than demanding the player stand in the shallows.
FishingConfig.CastDistance = 18
FishingConfig.CastDepth = 40
-- Fishing stops if the player wanders this far from where they cast: they have walked away from the water.
FishingConfig.LeashDistance = 24

FishingConfig.CastSound = "rbxassetid://110150773255090"
FishingConfig.CastSoundVolume = 0.45
FishingConfig.CastSoundDistance = 60

-- The catch. `weight` is relative, not a percentage -- the picker sums them and rolls once, so adding a new
-- fish never means rebalancing every other number.
--
-- Weights and the catalog's `value` are the same statement made twice: what is rare should be worth more.
-- A shark at weight 2 against a common fish at 40 is one in every twenty-odd catches.
FishingConfig.Loot = {
	{ item = "Fish", weight = 40 },
	{ item = "Crab", weight = 20 },
	{ item = "Shell", weight = 15 },
	{ item = "Shrimp", weight = 10 },
	{ item = "Squid", weight = 8 },
	{ item = "Pufferfish", weight = 4 },
	{ item = "Shark", weight = 2 },
	{ item = "Anglerfish", weight = 1 },
}

return FishingConfig
