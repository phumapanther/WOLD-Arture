-- ProgressionConfig: EXP, levels, body growth, and what a level-up restores.
-- Shared by the server (which owns every value) and the client (which only renders the bar and the tag).
local ProgressionConfig = {}

ProgressionConfig.MaxLevel = 100

-- EXP to go from `level` to `level + 1`. Quadratic, so later levels are meaningfully harder without becoming
-- impossible: level 1->2 costs 100, 50->51 costs ~3.6k, 99->100 costs ~14k.
ProgressionConfig.BaseExp = 100
ProgressionConfig.ExpGrowth = 1.4 -- exponent on the level
function ProgressionConfig.ExpForNextLevel(level)
	if level >= ProgressionConfig.MaxLevel then return math.huge end -- capped: no further level-ups
	return math.floor(ProgressionConfig.BaseExp * level ^ ProgressionConfig.ExpGrowth)
end

-- EXP awards. The user's ratios: killing a monster is the baseline, killing a player gives a tenth of that,
-- and each hit on a training dummy gives half of a player kill.
ProgressionConfig.ExpPerMonsterKill = 100 -- no monsters exist yet; here so the ratios below are readable
ProgressionConfig.ExpPerPlayerKill = ProgressionConfig.ExpPerMonsterKill / 10 -- 10
ProgressionConfig.ExpPerDummyHit = ProgressionConfig.ExpPerPlayerKill / 2 -- 5, once per punch

-- Body growth: the character reaches 10x its normal size at MaxLevel, one step every 10 levels.
ProgressionConfig.MaxScale = 10
ProgressionConfig.LevelsPerGrowth = 10
-- Scale at a given level, stepped rather than continuous so growing is a visible event.
function ProgressionConfig.ScaleForLevel(level)
	local steps = math.floor((level - 1) / ProgressionConfig.LevelsPerGrowth)
	local maxSteps = math.floor((ProgressionConfig.MaxLevel - 1) / ProgressionConfig.LevelsPerGrowth)
	if maxSteps <= 0 then return 1 end
	return 1 + (ProgressionConfig.MaxScale - 1) * (steps / maxSteps)
end

-- Growing makes the body bigger, so the pools grow with it: a level-100 player who kept a 100-hunger bar
-- would starve on the same 30-minute clock as a level-1 one despite being ten times the size (the user's
-- point). HP scales the same way so a large player is not a large target with a small health bar.
ProgressionConfig.MaxHPPerLevel = 5 -- +5 max HP per level: 100 at level 1, 595 at level 100
ProgressionConfig.MaxHungerPerLevel = 3 -- +3 max hunger per level: 100 -> 397

function ProgressionConfig.MaxHPForLevel(baseMax, level)
	return baseMax + ProgressionConfig.MaxHPPerLevel * (level - 1)
end

function ProgressionConfig.MaxHungerForLevel(baseMax, level)
	return baseMax + ProgressionConfig.MaxHungerPerLevel * (level - 1)
end

-- Dying wipes everything back to level 1 — the whole risk of growing. Being downed and revived does NOT: only
-- an actual death resets.
ProgressionConfig.ResetLevelOnDeath = true

return ProgressionConfig
