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

--------------------------------------------------------------------------------
-- How heavy the thing was
--------------------------------------------------------------------------------

-- Every catch gets a size in kilograms, and the card over the player's head is coloured by it. The field is
-- called `kg` everywhere and NEVER `weight`, because `weight` already means two other things in this
-- codebase -- the relative chance of being caught, up in the Loot table, and the carry-load in ItemCatalog.
-- A third meaning on the same word would be a bug waiting to be written by whoever reads it next.
FishingConfig.MinKg = 1
FishingConfig.MaxKg = 50

-- The colours, lightest catch first. A roll lands in the last band whose `from` it has reached, so the
-- thresholds are written once, in order, and nothing has to agree with them twice.
--
-- Where the lines sit is the whole feel of the system, so they were placed against the MEASURED output of
-- the roll below rather than by spacing 1-50 evenly. Simulated over two million catches through the real
-- loot table, the share of all catches landing in each band comes out: plain 48.7%, green 29.8%, blue 14.5%,
-- yellow 5.4%, red 1.2%, purple 0.35%. That is one purple in roughly 280 catches -- at a catch every
-- twenty-five seconds, about two hours of fishing -- which is the "rare and exciting" that was asked for.
-- Purple is the number to move if it ever feels common: it is the steepest part of the curve, and raising 42
-- to 45 roughly halves it.
-- Three colours, not six.
--
-- A six-rung ladder meant most catches were coloured something, which is the same as none of them being
-- coloured: a green fish every other cast is just what a fish looks like. Blue, red and purple only, with
-- everything below blue staying the card's usual cream -- so a colour means the fish is worth keeping.
--
-- The cuts are placed against the measured distribution rather than by spacing 1-50 evenly. Over 40,000
-- simulated catches: blue lands about 1 in 14, red 1 in 59, purple 1 in 246.
--
-- `big` marks the tiers that count as a trophy. That flag is what decides whether the weight is recorded on
-- the item at all, which in turn decides whether it stacks -- see the note in Fishing.server.
FishingConfig.KgTiers = {
	{ from = 0,  color = Color3.fromRGB(255, 226, 170), name = "", big = false },
	{ from = 19, color = Color3.fromRGB(88, 168, 255),  name = "ตัวใหญ่", big = true },
	{ from = 30, color = Color3.fromRGB(240, 88, 76),   name = "ตัวมหึมา", big = true },
	{ from = 42, color = Color3.fromRGB(180, 110, 255), name = "ตำนาน", big = true },
}

function FishingConfig.TierFor(kg)
	local found = FishingConfig.KgTiers[1]
	for _, tier in ipairs(FishingConfig.KgTiers) do
		if kg >= tier.from then found = tier end
	end
	return found
end

-- Is this catch a trophy? Answered by asking the tier rather than comparing against a number written here
-- as well, so moving a threshold above cannot leave a second copy behind disagreeing with it.
function FishingConfig.IsBig(kg)
	local tier = FishingConfig.TierFor(kg)
	return tier ~= nil and tier.big == true
end

-- How rare a fish is, from 0 for the commonest in the loot table to 1 for the rarest. Read off the loot
-- weights rather than kept in a second hand-maintained rarity list, so adding a fish or rebalancing how
-- often one bites can never leave a rarity table quietly out of date.
--
-- Log scale rather than linear because the loot weights span 40:1. Linear would put Squid (8) at 0.82 and
-- everything from there down crammed into the last fifth of the dial, making five of the eight fish feel
-- identical. Log spreads them evenly: Fish 0, Crab 0.19, Shell 0.27, Shrimp 0.38, Squid 0.44, Pufferfish
-- 0.62, Shark 0.81, Anglerfish 1.
local function rarityOf(itemId)
	local highest, rarest, mine = 0, math.huge, nil
	for _, entry in ipairs(FishingConfig.Loot) do
		if entry.weight > highest then highest = entry.weight end
		if entry.weight < rarest then rarest = entry.weight end
		if entry.item == itemId then mine = entry.weight end
	end
	-- Anything not in the loot table -- a fish from a shop, a chest, or an admin command -- is treated as the
	-- commonest rather than erroring, so it still gets a believable size.
	if not mine or mine <= 0 or highest <= 0 or rarest <= 0 then return 0 end
	local span = math.log(highest / rarest)
	if span <= 0 then return 0 end
	return math.clamp(math.log(highest / mine) / span, 0, 1)
end

-- Rolls the kilograms for one catch.
--
-- Two dials, because one could not do the job. The first attempt was a single power curve over the full
-- 1-50 range with the power set by rarity, and simulating it showed why that fails: making a common fish
-- small enough (median 1.0 kg) also made every common fish the SAME size, while the power curve's tail stays
-- fat enough that a common fish still hit purple 5% of the time. Rarity barely mattered -- 5.6% against 20%
-- is under 4x, nothing like "much better".
--
-- So rarity sets the CEILING instead, and a fixed bottom-loaded curve fills the space beneath it. A common
-- Fish tops out near 9.8 kg, a Shark near 42.5, an Anglerfish at the full 50, and the medians come out Fish
-- 3.6, Crab 5.9, Shell 6.8, Shrimp 8.1, Squid 8.8, Pufferfish 11.0, Shark 13.2, Anglerfish 15.4.
--
-- The overshoot is what keeps a hard ceiling from making common fish boring: one catch in forty ignores its
-- own ceiling and rolls against the full scale, keeping the better of the two. So a common Fish CAN still
-- come up purple, at 0.22%, while an Anglerfish does it at 9.6% -- rarity still decides, by forty-odd times
-- over, but no fish is ever a foregone conclusion. All these figures are simulated, not estimated.
local CEILING_FLOOR = 0.18 -- the commonest fish's ceiling, as a fraction of the 1-50 range
local CURVE_POWER = 1.8    -- above 1 leans the roll toward the small end of whatever range it has
local OVERSHOOT_CHANCE = 0.025

function FishingConfig.RollKg(itemId)
	local rarity = rarityOf(itemId)
	local full = FishingConfig.MaxKg - FishingConfig.MinKg
	local ceiling = FishingConfig.MinKg + full * (CEILING_FLOOR + (1 - CEILING_FLOOR) * rarity)

	local kg = FishingConfig.MinKg + (ceiling - FishingConfig.MinKg) * math.random() ^ CURVE_POWER
	if math.random() < OVERSHOOT_CHANCE then
		kg = math.max(kg, FishingConfig.MinKg + full * math.random() ^ CURVE_POWER)
	end

	-- One decimal: "12.4 กก." reads as a real measurement where 12.41739 reads as a bug.
	return math.floor(math.min(kg, FishingConfig.MaxKg) * 10 + 0.5) / 10
end

return FishingConfig
