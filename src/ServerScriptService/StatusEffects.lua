-- StatusEffects.lua: temporary states weapons inflict — knocked down by an arrow, slowed by a spell.
--
-- Kept apart from Vitals because these are not vitals: they expire on a timer, stack by replacement rather
-- than by accumulation, and must clear cleanly if the victim dies or respawns mid-effect.
--
-- Server-authoritative: the effect is applied here and the client is only told so it can render.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Vitals = require(game.ServerScriptService.Vitals)
local Remotes = require(game.ReplicatedStorage.Remotes)

local StatusEffects = {}

-- [player] = { knockdownUntil = number?, slowUntil = number?, slowFactor = number? }
local Active = {}

local NORMAL_WALK_SPEED = 8

local function stateFor(player)
	Active[player] = Active[player] or {}
	return Active[player]
end

--------------------------------------------------------------------------------
-- Knockdown: flat on the ground, unable to move, for a few seconds.
--------------------------------------------------------------------------------

local function applyKnockdownPosture(player, down)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if down then
		-- PlatformStand rather than a WalkSpeed of 0: it also drops the character to the floor, which is what
		-- "ล้มลงไปนอน" means, and the engine stops driving the rig upright.
		humanoid.PlatformStand = true
	else
		humanoid.PlatformStand = false
		-- The engine leaves a platform-standing humanoid lying there; nudge it back onto its feet.
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	Remotes.StatusChanged:FireAllClients(player, "knockdown", down)
end

function StatusEffects.Knockdown(player, seconds)
	-- A downed player is already on the floor; knocking them down again would fight the crawl.
	if Vitals.IsDowned(player) then return end
	local state = stateFor(player)
	local wasDown = state.knockdownUntil ~= nil
	state.knockdownUntil = os.clock() + seconds
	if not wasDown then applyKnockdownPosture(player, true) end
end

--------------------------------------------------------------------------------
-- Slow: movement speed cut for a few seconds.
--------------------------------------------------------------------------------

function StatusEffects.Slow(player, seconds, factor)
	local state = stateFor(player)
	state.slowUntil = os.clock() + seconds
	state.slowFactor = factor or 0.5
	Remotes.StatusChanged:FireAllClients(player, "slow", true)
end

-- PlayerMovement asks for this every tick, so the slow rides on top of whatever speed the movement state and
-- carry weight already decided rather than fighting them for the WalkSpeed property.
function StatusEffects.SpeedMultiplier(player)
	local state = Active[player]
	if not state or not state.slowUntil then return 1 end
	if os.clock() >= state.slowUntil then return 1 end
	return state.slowFactor or 0.5
end

function StatusEffects.IsKnockedDown(player)
	local state = Active[player]
	return state ~= nil and state.knockdownUntil ~= nil
end

--------------------------------------------------------------------------------
-- Expiry and cleanup, driven by PlayerStatusEffects.server.lua
--------------------------------------------------------------------------------

-- Drops every effect a player has. Used on respawn and on leaving; safe when they have none.
function StatusEffects.ClearFor(player)
	Active[player] = nil
end

function StatusEffects.Tick()
	local now = os.clock()
	for player, state in pairs(Active) do
		if not player.Parent then
			Active[player] = nil
		else
			if state.knockdownUntil and now >= state.knockdownUntil then
				state.knockdownUntil = nil
				applyKnockdownPosture(player, false)
			end
			if state.slowUntil and now >= state.slowUntil then
				state.slowUntil = nil
				Remotes.StatusChanged:FireAllClients(player, "slow", false)
			end
			-- Going down overrides a knockdown: the crawl owns the body from then on.
			if state.knockdownUntil and Vitals.IsDowned(player) then
				state.knockdownUntil = nil
				applyKnockdownPosture(player, false)
			end
		end
	end
end

return StatusEffects
