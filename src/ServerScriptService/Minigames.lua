-- Minigames.lua: the server's half of the two quick-time games.
--
-- A system that wants to ask the player to prove something calls Minigames.Run(player, spec, onResult). This
-- module rolls the numbers, sends them down, waits for the single bit that comes back, and calls onResult
-- exactly once -- whether the player succeeded, failed, ran out of time, or left the server.
--
-- What the client is trusted with, and what it is not:
--   trusted:     "I hit it" / "I missed it". There is no way to verify a keypress from the server, and every
--                game that has ever had a QTE has this same hole.
--   NOT trusted: that a minigame was allowed to happen at all, what it was worth, how long it took, or that
--                the answer belongs to the attempt it claims to. All four are decided here, and the reward
--                is handed out by the CALLER after onResult -- the client never names a prize.
--
-- A token ties an answer to an attempt. Without it, a client could keep one old "success" around and replay
-- it against every future attempt.
local Players = game:GetService("Players")
local MinigameConfig = require(game.ReplicatedStorage.MinigameConfig)
local StatusEffects = require(game.ServerScriptService.StatusEffects)
local Remotes = require(game.ReplicatedStorage.Remotes)

local Minigames = {}

-- [player] = { token, startedAt, deadline, onResult, finished }
local Pending = {}

local nextToken = 0
local function makeToken()
	nextToken += 1
	return ("mg%d_%d"):format(nextToken, math.random(1000, 9999))
end

--------------------------------------------------------------------------------

-- Calls back once and once only. Every path out of an attempt -- the answer, the timeout, leaving the server,
-- a second attempt replacing this one -- comes through here, so a caller can hold state safely knowing the
-- callback is not going to fire twice and leave two rewards behind.
local function settle(player, success)
	local entry = Pending[player]
	if not entry or entry.finished then return end
	entry.finished = true
	Pending[player] = nil

	-- The legs come back here and nowhere else, so every way out of an attempt releases them: the answer, the
	-- timeout, leaving the server, or a second attempt replacing this one. A release that lived in only one of
	-- those paths would leave somebody frozen for good.
	StatusEffects.SetRooted(player, false)
	if entry.onResult then
		-- Wrapped: a caller that errors must not take the minigame system down with it, and must not leave
		-- the next attempt blocked behind a half-cleared entry.
		local ok, err = pcall(entry.onResult, success)
		if not ok then warn("[Minigames] result handler failed:", err) end
	end
end

function Minigames.IsBusy(player)
	return Pending[player] ~= nil
end

-- Ends whatever is running for this player as a failure. Used when the world moves on underneath an attempt
-- -- the repair was cancelled, the node was taken by somebody else.
function Minigames.Cancel(player)
	settle(player, false)
end

--------------------------------------------------------------------------------
-- Starting one
--------------------------------------------------------------------------------

-- spec.kind is "arrows" or "skillcheck". Everything else is optional and clamped:
--   arrows:     spec.length   how many directions to press
--   skillcheck: nothing -- the zone and the speed are rolled here, so no two pops are the same
--   both:       spec.title    what the window says this is for
local function buildArrows(spec)
	local config = MinigameConfig.Arrows
	local length = math.clamp(math.floor(tonumber(spec.length) or 5), config.MinLength, config.MaxLength)

	local sequence = {}
	for i = 1, length do
		local pick = config.Directions[math.random(1, #config.Directions)]
		-- Never the same arrow twice in a row. Two identical presses in a rhythm game read as one press that
		-- did not register, and the player blames the game rather than their hands.
		if i > 1 and pick == sequence[i - 1] then
			pick = config.Directions[(table.find(config.Directions, pick) % #config.Directions) + 1]
		end
		sequence[i] = pick
	end

	local window = config.LeadIn + length * config.SecondsPerStep
	return {
		kind = "arrows",
		sequence = sequence,
		secondsPerStep = config.SecondsPerStep,
		leadIn = config.LeadIn,
	}, window
end

local function buildSkillCheck()
	local config = MinigameConfig.SkillCheck
	local width = config.MinZone + math.random() * (config.MaxZone - config.MinZone)
	-- Kept off both ends of the track: a zone butted against an edge is trivially hit by holding the button
	-- down, because the pointer sits there for a frame while it turns around.
	local start = 0.12 + math.random() * (0.88 - width - 0.12)
	return {
		kind = "skillcheck",
		zoneStart = start,
		zoneEnd = start + width,
		speed = config.MinSpeed + math.random() * (config.MaxSpeed - config.MinSpeed),
		timeout = config.Timeout,
	}, config.Timeout
end

function Minigames.Run(player, spec, onResult)
	spec = spec or {}

	-- One at a time. A second attempt while one is live ends the first as a failure rather than running both:
	-- two overlapping games would both be answered by the same keypress.
	if Pending[player] then settle(player, false) end

	local payload, window
	if spec.kind == "skillcheck" then
		payload, window = buildSkillCheck()
	else
		payload, window = buildArrows(spec)
	end

	local token = makeToken()
	payload.token = token
	payload.title = spec.title
	payload.subtitle = spec.subtitle

	local entry = {
		token = token,
		startedAt = os.clock(),
		deadline = os.clock() + window + MinigameConfig.ServerGrace,
		onResult = onResult,
	}
	Pending[player] = entry

	-- Held still for as long as the game is up. A quick-time event asks for the player's whole attention, and
	-- before this a jump during a transformer repair moved the character far enough to count as walking away
	-- and cancelled it. Not the dizzy state: no stars, no punishment, just the character standing still.
	StatusEffects.SetRooted(player, true)

	Remotes.MinigameStart:FireClient(player, payload)

	-- The server's own clock on the attempt. The client runs its own and normally answers first; this is what
	-- happens when it does not -- a player who alt-tabs, or a client that simply stops talking, fails rather
	-- than holding a node's cooldown hostage forever.
	task.delay(window + MinigameConfig.ServerGrace, function()
		if Pending[player] == entry then settle(player, false) end
	end)

	return token
end

--------------------------------------------------------------------------------
-- The answer
--------------------------------------------------------------------------------

Remotes.MinigameFinish.OnServerEvent:Connect(function(player, token, success)
	local entry = Pending[player]
	if not entry then return end
	-- Wrong attempt, or a replayed answer from an old one. Ignored rather than failed: failing here would let
	-- anyone end someone else's attempt by sending a stale token.
	if type(token) ~= "string" or token ~= entry.token then return end

	local elapsed = os.clock() - entry.startedAt
	if success == true and elapsed < MinigameConfig.MinPlausibleSeconds then
		-- Faster than a hand can move. Not an accusation, just not believed.
		return settle(player, false)
	end
	if os.clock() > entry.deadline then
		return settle(player, false)
	end

	settle(player, success == true)
end)

Players.PlayerRemoving:Connect(function(player)
	settle(player, false)
end)

return Minigames
