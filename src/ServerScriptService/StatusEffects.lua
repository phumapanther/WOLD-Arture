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
		-- PlatformStand rather than a WalkSpeed of 0: it stops the engine driving the rig upright and
		-- ignores input entirely, which is what "ขยับไม่ได้" needs.
		humanoid.PlatformStand = true
		-- But PlatformStand ALONE just goes limp and settles wherever physics puts it, which reads as a
		-- bug rather than as being shot. Lay them deliberately on their back, using the same root-joint
		-- pose the downed crawl uses.
		Vitals.SetProne(player, true, true)
	else
		Vitals.SetProne(player, false)
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
-- Dizzy: rooted where you stand, seeing stars, for a few seconds.
--------------------------------------------------------------------------------

-- What a botched minigame costs. Deliberately NOT a knockdown: being shot with an arrow lays you out flat,
-- while fumbling a lock or a repair should leave you standing there swearing at it. So the body stays upright
-- and only the ability to go anywhere is taken away.
--
-- Rooting is done through the speed multiplier PlayerMovement already asks for every tick, rather than with
-- PlatformStand. PlatformStand would fight the movement state machine for the same body, and the crawl and
-- the carry have both already been through that argument.
local function applyDizzyMark(player, dizzy)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end

	local existing = head:FindFirstChild("DizzyMark")
	if not dizzy then
		if existing then existing:Destroy() end
		return
	end
	if existing then return end

	-- Built on the server so everyone nearby sees it, the same way a monster's health bar is: being stunned
	-- in front of other people is part of the cost.
	local gui = Instance.new("BillboardGui")
	gui.Name = "DizzyMark"
	gui.Size = UDim2.fromOffset(60, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = true
	gui.Parent = head

	local stars = Instance.new("TextLabel")
	stars.Size = UDim2.fromScale(1, 1)
	stars.BackgroundTransparency = 1
	stars.Font = Enum.Font.GothamBold
	stars.TextScaled = true
	stars.TextColor3 = Color3.fromRGB(255, 232, 140)
	stars.Text = "\240\159\146\171" -- the dizzy-symbol emoji
	stars.Parent = gui
end

local function setJumping(player, allowed)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	-- Both properties, because which one the engine reads depends on UseJumpPower and a rig may be set either
	-- way. Restoring to Roblox's own defaults rather than to what was there before is safe here: nothing else
	-- in the game changes them.
	humanoid.JumpPower = allowed and 50 or 0
	humanoid.JumpHeight = allowed and 7.2 or 0
end

function StatusEffects.Dizzy(player, seconds)
	-- Already on the floor: leave the crawl alone, exactly as Knockdown does.
	if Vitals.IsDowned(player) then return end
	local state = stateFor(player)
	local wasDizzy = state.dizzyUntil ~= nil
	state.dizzyUntil = os.clock() + seconds
	if not wasDizzy then
		applyDizzyMark(player, true)
		setJumping(player, false)
		Remotes.StatusChanged:FireAllClients(player, "dizzy", true)
	end
end

function StatusEffects.IsDizzy(player)
	local state = Active[player]
	return state ~= nil and state.dizzyUntil ~= nil and os.clock() < state.dizzyUntil
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
	if not state then return 1 end
	local now = os.clock()
	-- Dizzy wins over slow, and is checked first: it is the stronger of the two, and a slow that happened to
	-- expire in the same second must not hand the legs back to someone who is still seeing stars.
	if state.dizzyUntil and now < state.dizzyUntil then return 0 end
	if state.slowUntil and now < state.slowUntil then return state.slowFactor or 0.5 end
	return 1
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
			if state.dizzyUntil and now >= state.dizzyUntil then
				state.dizzyUntil = nil
				applyDizzyMark(player, false)
				setJumping(player, true)
				Remotes.StatusChanged:FireAllClients(player, "dizzy", false)
			end
			-- Going down overrides being dizzy for the same reason it overrides a knockdown: from then on the
			-- crawl owns the body, and a rooted-in-place multiplier would stop the crawl dead.
			if state.dizzyUntil and Vitals.IsDowned(player) then
				state.dizzyUntil = nil
				applyDizzyMark(player, false)
				setJumping(player, true)
				Remotes.StatusChanged:FireAllClients(player, "dizzy", false)
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
