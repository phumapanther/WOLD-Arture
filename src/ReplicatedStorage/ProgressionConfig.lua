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
-- **เพดาน EXP จากหุ่นฟางต่อวัน รวมทุกหุ่น** (ผู้ใช้สั่ง 2026-10-02 · เกมหลัก + บนเกาะ · เดิมไม่จำกัด = ยืนตี AFK ได้เลเวลไม่จบ)
ProgressionConfig.DummyDailyExpCap = 1000
-- `record` = { day, exp } ที่เซฟไว้ (nil = ยังไม่เคยตี) · `today` = QuestConfig.DayNumber() (เที่ยงคืนไทย)
-- คืน (EXP ที่ให้ครั้งนี้, บันทึกใหม่, เพิ่งชนเพดานพอดีไหม — ไว้บอกผู้เล่นครั้งเดียว)
function ProgressionConfig.DummyGrant(record, today)
	local used = (type(record) == "table" and record.day == today and tonumber(record.exp)) or 0
	local cap = ProgressionConfig.DummyDailyExpCap
	local grant = math.max(0, math.min(ProgressionConfig.ExpPerDummyHit, cap - used))
	return grant, { day = today, exp = used + grant }, grant > 0 and used + grant >= cap
end

-- Killing UP is worth more: the further above you the victim was, the bigger the multiplier. Killing down is
-- worth less, but never nothing, so farming low levels stops being efficient without becoming pointless.
-- The bonus is per level of difference and capped, or a level-1 player downing a level-100 one would earn a
-- hundred levels back in a single hit.
ProgressionConfig.KillLevelBonusPerLevel = 0.25 -- +25% per level the victim is above the killer
ProgressionConfig.KillLevelPenaltyPerLevel = 0.08 -- -8% per level they were below
ProgressionConfig.MaxKillMultiplier = 6
ProgressionConfig.MinKillMultiplier = 0.2

-- How much the kill is worth, given both levels. Only the killer's last hit calls this.
function ProgressionConfig.KillMultiplier(killerLevel, victimLevel)
	local gap = (victimLevel or 1) - (killerLevel or 1)
	local multiplier
	if gap >= 0 then
		multiplier = 1 + gap * ProgressionConfig.KillLevelBonusPerLevel
	else
		multiplier = 1 + gap * ProgressionConfig.KillLevelPenaltyPerLevel
	end
	return math.clamp(multiplier, ProgressionConfig.MinKillMultiplier, ProgressionConfig.MaxKillMultiplier)
end

-- Body growth. Set to 1, which means nobody grows: at 10x a level-100 player's root sat thirty studs off
-- the ground, and a giant standing next to a normal player could barely be fought or interacted with at all
-- -- the hitbox fix made it possible, not pleasant. Left as a knob rather than deleted, because the growth
-- is a nice idea at a sane number: 1.5 or 2 would read as "big" without breaking the world around them.
ProgressionConfig.MaxScale = 1
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
