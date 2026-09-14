-- Progression.lua: the single owner of EXP, level, and body scale. A module (like Vitals) because combat, the
-- training dummies, and the vitals system all need to reach it.
--
-- Server-authoritative: the client only renders the bar and the overhead tag.
local Players = game:GetService("Players")
local ProgressionConfig = require(game.ReplicatedStorage.ProgressionConfig)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local VitalsConfig = require(game.ReplicatedStorage.VitalsConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)
local ClassPerks = require(game.ServerScriptService.ClassPerks)

local Progression = {}

local States = {} -- [player] = { level, exp }

-- Vitals is injected rather than required, because Vitals must not depend on Progression and vice versa:
-- level-up refills the vitals, and the vitals' maximums depend on level. PlayerProgression.server.lua wires
-- the two together at startup.
local Vitals = nil
function Progression.BindVitals(vitals)
	Vitals = vitals
end

function Progression.Add(player, saved)
	States[player] = {
		level = saved and saved.Level or 1,
		exp = saved and saved.Exp or 0,
	}
	return States[player]
end

function Progression.Remove(player)
	States[player] = nil
end

function Progression.Get(player)
	return States[player]
end

function Progression.GetLevel(player)
	local state = States[player]
	return state and state.level or 1
end

-- Max HP and max hunger both grow with level; every other system asks here rather than reading the flat
-- VitalsConfig maximum, so a grown player's bars are right everywhere.
function Progression.MaxHP(player)
	return ProgressionConfig.MaxHPForLevel(VitalsConfig.MaxHP, Progression.GetLevel(player))
end

function Progression.MaxHunger(player)
	return ProgressionConfig.MaxHungerForLevel(VitalsConfig.MaxHunger, Progression.GetLevel(player))
end

local function send(player)
	local state = States[player]
	if not state then return end
	Remotes.ProgressionUpdate:FireClient(player, {
		level = state.level,
		exp = state.exp,
		expForNext = ProgressionConfig.ExpForNextLevel(state.level),
	})
end
Progression.Send = send

-- The overhead "Lv." tag is an attribute so every client can render it above other players, the same way the
-- downed flag replicates.
local function publishLevel(player)
	local state = States[player]
	player:SetAttribute("WOLD_Level", state and state.level or 1)
end

--------------------------------------------------------------------------------
-- Body scale
--------------------------------------------------------------------------------

-- R15 humanoids expose scale as NumberValues under the Humanoid; setting them resizes the whole rig properly
-- (parts, joints and collision), which manually scaling parts does not.
local SCALE_VALUES = { "BodyDepthScale", "BodyWidthScale", "BodyHeightScale", "HeadScale" }

function Progression.ApplyScale(player, character)
	character = character or player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local scale = ProgressionConfig.ScaleForLevel(Progression.GetLevel(player))
	for _, name in ipairs(SCALE_VALUES) do
		local value = humanoid:FindFirstChild(name)
		if value then value.Value = scale end
	end
end

--------------------------------------------------------------------------------
-- Earning EXP
--------------------------------------------------------------------------------

-- Every EXP source funnels through here so the level-up rules live in one place.
function Progression.AwardExp(player, amount)
	local state = States[player]
	if not state or amount <= 0 then return end
	if state.level >= ProgressionConfig.MaxLevel then return end -- capped

	-- The adventurer's doubling is applied HERE rather than at each of the dozen places experience is
	-- awarded -- a kill, a dummy, a fish, a harvest, a craft -- so it cannot be forgotten by whatever awards
	-- experience next.
	amount = ClassPerks.ExpFor(player, amount)

	state.exp += amount

	local levelledUp = false
	while state.level < ProgressionConfig.MaxLevel do
		local needed = ProgressionConfig.ExpForNextLevel(state.level)
		if state.exp < needed then break end
		state.exp -= needed
		state.level += 1
		levelledUp = true
	end

	if state.level >= ProgressionConfig.MaxLevel then
		state.exp = 0 -- nothing left to spend it on
	end

	if levelledUp then
		-- Persist immediately: a level is too expensive to lose to the gap between autosave ticks.
		if ProfileAccess.Flush then ProfileAccess.Flush(player) end
		publishLevel(player)
		Progression.ApplyScale(player)
		-- Level-up refills everything, armor included (confirmed: the reward for levelling. A plain respawn
		-- still does NOT refill armor — see Vitals.ResetForRespawn).
		if Vitals then Vitals.RefillOnLevelUp(player) end
		Remotes.LevelUp:FireClient(player, state.level)
	end

	send(player)
end

-- Death wipes the lot: back to level 1, normal size. This is the risk that pays for growing.
function Progression.ResetOnDeath(player)
	local state = States[player]
	if not state or not ProgressionConfig.ResetLevelOnDeath then return end
	if state.level == 1 and state.exp == 0 then return end
	state.level = 1
	state.exp = 0
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	publishLevel(player)
	Progression.ApplyScale(player)
	send(player)
end

-- Called on join and every respawn, so the tag and the body size are right from the first frame.
function Progression.Refresh(player, character)
	publishLevel(player)
	Progression.ApplyScale(player, character)
	send(player)
end

function Progression.Serialize(player)
	local state = States[player]
	if not state then return nil end
	return { Level = state.level, Exp = state.exp }
end

return Progression
