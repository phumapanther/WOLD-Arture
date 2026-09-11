-- The one runnable check behind the fish weight curve.
--
-- The colour thresholds in FishingConfig are justified by measured percentages, and a comment claiming
-- "one purple in 280 catches" is worthless if nobody can re-run it. This does: it rolls the real functions
-- a hundred thousand times through the real loot table and asserts the distribution still matches what the
-- comments promise. Change CURVE_POWER or a loot weight and this is what tells you the comments went stale.
--
-- Run with: node tools/run-luau.js tests/fish-weight-check.lua
local FishingConfig = require(game.ReplicatedStorage.FishingConfig)

local N = 100000

-- Every roll must stay inside the advertised range. The overshoot path is the one that could break this,
-- since it rolls against the full scale after a ceiling has already been applied.
local lowest, highest = math.huge, -math.huge
for _ = 1, N do
	local kg = FishingConfig.RollKg("Fish")
	lowest = math.min(lowest, kg)
	highest = math.max(highest, kg)
end
assert(lowest >= FishingConfig.MinKg, ("rolled below MinKg: %.2f"):format(lowest))
assert(highest <= FishingConfig.MaxKg, ("rolled above MaxKg: %.2f"):format(highest))

-- Rarity must actually matter, which is the entire feature. A rarer fish has to land heavier on average by
-- a wide margin, not a rounding error.
local function meanKg(itemId)
	local total = 0
	for _ = 1, N do total += FishingConfig.RollKg(itemId) end
	return total / N
end
local commonMean, rareMean = meanKg("Fish"), meanKg("Anglerfish")
assert(rareMean > commonMean * 2.5,
	("rarity barely matters: Fish %.1f kg vs Anglerfish %.1f kg"):format(commonMean, rareMean))

-- Purple has to stay rare. Measured at about 0.35% of all catches; the band here is wide enough not to trip
-- on sampling noise but tight enough to catch a real regression in either direction.
local total = 0
for _, entry in ipairs(FishingConfig.Loot) do total += entry.weight end
local purpleFrom = FishingConfig.KgTiers[#FishingConfig.KgTiers].from
local purple = 0
for _ = 1, N do
	local roll, running = math.random() * total, 0
	for _, entry in ipairs(FishingConfig.Loot) do
		running += entry.weight
		if roll <= running then
			if FishingConfig.RollKg(entry.item) >= purpleFrom then purple += 1 end
			break
		end
	end
end
local share = purple / N
assert(share > 0.001 and share < 0.01,
	("purple is %.3f%% of catches, expected near 0.35%%"):format(share * 100))

-- The ladder must be ordered and complete, or TierFor silently returns the wrong colour.
for i = 2, #FishingConfig.KgTiers do
	assert(FishingConfig.KgTiers[i].from > FishingConfig.KgTiers[i - 1].from, "tiers are out of order")
end
assert(FishingConfig.TierFor(0).from == 0, "a nothing catch is not plain")
assert(FishingConfig.TierFor(FishingConfig.MaxKg).from == purpleFrom, "a max catch is not purple")

print(("ok -- Fish avg %.1f kg, Anglerfish avg %.1f kg, purple %.3f%% of catches")
	:format(commonMean, rareMean, share * 100))
