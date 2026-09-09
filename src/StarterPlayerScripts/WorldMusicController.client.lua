-- WorldMusicController: music out in the world.
--
-- Three kinds of music, in priority order:
--   combat   a fight is happening to you -- takes over, and lets go once the blows stop
--   zone     you are inside a settlement -- that place's own theme
--   wander   open country -- an occasional track, mostly silence
--
-- Only one plays at a time. The highest-priority kind that has something to play wins, and the others fade
-- out underneath it. Two players standing together hear different music if one of them is being hit.
--
-- The governing idea is that SILENCE IS THE DEFAULT. This is a roleplay game people sit in for hours; music
-- is an occasional thing that arrives, says something, and goes away again. Hence the long gaps, and hence
-- every timer below being minutes rather than seconds.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local SoundscapeConfig = require(game.ReplicatedStorage.SoundscapeConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local Music = SoundscapeConfig.WorldMusic
if not Music then return end

local player = Players.LocalPlayer

--------------------------------------------------------------------------------
-- Two players: one for whatever is playing, one for combat.
--------------------------------------------------------------------------------

-- Combat gets its own Sound so it can cut in over a zone theme and hand back to it afterwards. Sharing one
-- would mean losing the interrupted track's position and restarting it from the top.
local function newTrack(name)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.Volume = 0
	sound.Looped = false -- a track ending is a real event here: it starts one of the long gaps
	sound.Parent = SoundService
	return sound
end

local ambientTrack = newTrack("WOLD_WorldMusic")
local combatTrack = newTrack("WOLD_CombatMusic")

-- Never the same track twice in a row out of the same pool.
local lastPicked = {}
local function pick(tracks, poolKey)
	if not tracks or #tracks == 0 then return nil end
	if #tracks == 1 then return tracks[1] end
	local index
	repeat
		index = math.random(1, #tracks)
	until index ~= lastPicked[poolKey]
	lastPicked[poolKey] = index
	return tracks[index]
end

--------------------------------------------------------------------------------
-- Which settlement, if any
--------------------------------------------------------------------------------

local function currentZone()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local pos = root.Position
	-- The nearest town whose radius contains us. Radii do not overlap in the current layout, but taking the
	-- nearest is the honest answer if they ever do.
	local best, bestDistance = nil, math.huge
	for _, town in ipairs(SoundscapeConfig.Towns) do
		local dx, dz = pos.X - town.x, pos.Z - town.z
		local d = math.sqrt(dx * dx + dz * dz)
		if d < town.radius and d < bestDistance then
			best, bestDistance = town.name, d
		end
	end
	return best
end

local function tracksForZone(zone)
	local entry = Music.Zones[zone]
	return (entry and entry.Tracks) or Music.DefaultZoneTracks
end

--------------------------------------------------------------------------------
-- Combat
--------------------------------------------------------------------------------

-- Set to a deadline whenever a blow lands. Combat music plays while now < this.
local combatUntil = 0

Remotes.CombatHit.OnClientEvent:Connect(function()
	-- Every fresh hit restarts the countdown rather than extending a fixed window, so a long fight keeps its
	-- music the whole way through and only ten quiet seconds end it.
	combatUntil = os.clock() + Music.Combat.LingerSeconds
	if not combatTrack.IsPlaying then
		combatTrack.SoundId = pick(Music.Combat.Tracks, "combat")
		combatTrack.TimePosition = 0
		combatTrack:Play()
	end
end)

--------------------------------------------------------------------------------
-- Choosing what the ambient player should be doing
--------------------------------------------------------------------------------

-- The next moment a track is allowed to start. Silence until then.
local nextAllowedAt = os.clock() + Music.Wander.FirstDelaySeconds
local playingZone = nil -- the zone the current ambient track belongs to, nil for a wander track

-- A track finishing starts one of the long gaps, so music does not run continuously.
ambientTrack.Ended:Connect(function()
	-- Read which pool it came from BEFORE clearing it: a settlement theme and a wander track have different
	-- gaps, and clearing first would always have taken the wander one.
	local wasZone = playingZone
	playingZone = nil
	nextAllowedAt = os.clock() + (wasZone and Music.ZoneGapSeconds or Music.Wander.GapSeconds)
end)

local function updateAmbientChoice()
	local zone = currentZone()

	-- Leaving the area a track belongs to ends it: walking out of a village should take the village's music
	-- with you, and the gap starts from here rather than the track being resumed later.
	if ambientTrack.IsPlaying and playingZone ~= zone then
		ambientTrack:Stop()
		playingZone = nil
		nextAllowedAt = os.clock() + Music.Wander.GapSeconds
		return
	end

	if ambientTrack.IsPlaying then return end
	if os.clock() < nextAllowedAt then return end

	-- Nothing playing and the wait is over: start something appropriate to where we are.
	local tracks = zone and tracksForZone(zone) or Music.Wander.Tracks
	local id = pick(tracks, zone or "wander")
	if not id then return end
	ambientTrack.SoundId = id
	ambientTrack.TimePosition = 0
	ambientTrack:Play()
	playingZone = zone
end

--------------------------------------------------------------------------------
-- Volumes
--------------------------------------------------------------------------------

local CHOICE_INTERVAL = 1 -- the choice depends on position and clocks; a second is plenty
local sinceChoice = CHOICE_INTERVAL

local function approach(sound, target, seconds, dt)
	local step = dt / seconds * math.max(target, Music.Volume)
	if sound.Volume < target then
		sound.Volume = math.min(target, sound.Volume + step)
	elseif sound.Volume > target then
		sound.Volume = math.max(target, sound.Volume - step)
	end
end

RunService.Heartbeat:Connect(function(dt)
	sinceChoice += dt
	if sinceChoice >= CHOICE_INTERVAL then
		sinceChoice = 0
		updateAmbientChoice()
	end

	local inCombat = os.clock() < combatUntil

	-- Combat takes precedence: it fades up while everything else ducks away under it.
	approach(combatTrack, inCombat and Music.Combat.Volume or 0,
		inCombat and Music.Combat.FadeInSeconds or Music.Combat.FadeOutSeconds, dt)
	-- Held at zero when there is no track, not just when combat is on: the fade would otherwise walk the
	-- volume up during a silent gap, so the next track would begin already at full instead of fading in.
	local ambientTarget = (inCombat or not ambientTrack.IsPlaying) and 0 or Music.Volume
	approach(ambientTrack, ambientTarget, Music.FadeSeconds, dt)

	-- Stopped rather than left running at zero, so the next fight starts its track from the beginning
	-- instead of halfway through the last one.
	if not inCombat and combatTrack.IsPlaying and combatTrack.Volume <= 0 then
		combatTrack:Stop()
	end

	-- And the same for the theme underneath. Ducking it to zero left it PLAYING under the fight, so the two
	-- ran on together and the theme came back mid-phrase when combat ended -- audibly two tracks at once.
	-- Stopping it means the town gets a fresh track afterwards rather than the middle of an old one.
	if inCombat and ambientTrack.IsPlaying and ambientTrack.Volume <= 0 then
		ambientTrack:Stop()
		playingZone = nil
		-- A breath before the theme returns, rather than it snapping back the instant the fight ends.
		nextAllowedAt = os.clock() + Music.FadeSeconds
	end
end)
