-- AmbienceController: the sound of being somewhere.
--
-- A set of long loops whose volumes are driven by where the listener stands and what time it is. They stack
-- rather than switch, so a wooded coast at night is surf and crickets together, and walking inland fades
-- the surf out without the crickets noticing.
--
-- Client-side because it is a listener-relative effect: every player hears their own surroundings, and
-- there is nothing for the server to arbitrate. The clock is the one shared input, and DayNight already
-- publishes that as a workspace attribute.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local SoundscapeConfig = require(game.ReplicatedStorage.SoundscapeConfig)
local DayNightConfig = require(game.ReplicatedStorage.DayNightConfig)
local MapTerrain = require(game.ReplicatedStorage.MapTerrain)

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local player = Players.LocalPlayer

--------------------------------------------------------------------------------
-- The loops
--------------------------------------------------------------------------------

-- Parented to SoundService rather than to a part: these are not positional. Ambience is what surrounds the
-- listener, so it should not pan or fade as the camera turns.
local sounds = {} -- [layerName] = Sound

for name, layer in pairs(SoundscapeConfig.Ambience) do
	local sound = Instance.new("Sound")
	sound.Name = "WOLD_Ambience_" .. name
	sound.SoundId = layer.id
	sound.Looped = true
	sound.Volume = 0 -- everything fades up from silence; nothing slams in on join
	sound.Parent = SoundService
	sound:Play()
	sounds[name] = sound
end

--------------------------------------------------------------------------------
-- Where the listener is
--------------------------------------------------------------------------------

-- Distance to the nearest water, read off the sampled terrain grid rather than by raycasting. The grid is
-- 120x120 over 16000 studs, so a cell is ~133 studs -- coarse, but the surf fade runs over 700 studs, and
-- searching a handful of cells costs nothing next to casting rays every frame.
local CELL = (MapTerrain.HalfSize * 2) / MapTerrain.Size

local function distanceToWater(x, z)
	local gx = math.floor((x + MapTerrain.HalfSize) / CELL) + 1
	local gz = math.floor((z + MapTerrain.HalfSize) / CELL) + 1

	-- Rings outward from the listener's cell, stopping at the first water found. Searching only as far as
	-- the fade distance means the common case (inland, no water anywhere near) exits after a few rings.
	local maxRings = math.ceil(SoundscapeConfig.CoastFadeDistance / CELL) + 1
	for ring = 0, maxRings do
		for dx = -ring, ring do
			for dz = -ring, ring do
				-- Only the ring's edge; the inside was covered by earlier iterations.
				if math.abs(dx) == ring or math.abs(dz) == ring then
					if MapTerrain.MaterialAt(gx + dx, gz + dz) == "w" then
						-- Centre-to-centre distance is accurate enough at this scale and avoids pretending
						-- to a precision the grid does not have.
						return math.sqrt(dx * dx + dz * dz) * CELL
					end
				end
			end
		end
	end
	return math.huge
end

-- 0 at the fade distance, 1 at the full distance, linear between.
local function coastLevel(x, z)
	local d = distanceToWater(x, z)
	if d >= SoundscapeConfig.CoastFadeDistance then return 0 end
	if d <= SoundscapeConfig.CoastFullDistance then return 1 end
	local span = SoundscapeConfig.CoastFadeDistance - SoundscapeConfig.CoastFullDistance
	return 1 - (d - SoundscapeConfig.CoastFullDistance) / span
end

local function mountainLevel(y)
	if y <= SoundscapeConfig.MountainStartHeight then return 0 end
	if y >= SoundscapeConfig.MountainFullHeight then return 1 end
	local span = SoundscapeConfig.MountainFullHeight - SoundscapeConfig.MountainStartHeight
	return (y - SoundscapeConfig.MountainStartHeight) / span
end

-- 1 out in the country, TownDuck in the middle of a settlement, blended across the town's edge so walking
-- through a gate is a fade rather than a step change.
local function townMultiplier(x, z)
	local nearest = 1
	for _, town in ipairs(SoundscapeConfig.Towns) do
		local dx, dz = x - town.x, z - town.z
		local d = math.sqrt(dx * dx + dz * dz)
		if d < town.radius then
			-- Full duck at the centre, easing back to normal at the edge.
			local t = d / town.radius
			local m = SoundscapeConfig.TownDuck + (1 - SoundscapeConfig.TownDuck) * t
			nearest = math.min(nearest, m)
		end
	end
	return nearest
end

--------------------------------------------------------------------------------
-- Day and night
--------------------------------------------------------------------------------

-- How much "day" it is: 1 in daylight, 0 at night, crossing gradually at dawn and dusk. Reading the same
-- clock and the same dusk/dawn hours the sky uses keeps the crickets arriving with the dark.
local function dayFactor(clockTime)
	local twilight = SoundscapeConfig.TwilightHours
	local dawn, dusk = DayNightConfig.DawnHour, DayNightConfig.DuskHour

	if clockTime >= dawn + twilight and clockTime <= dusk - twilight then return 1 end
	-- Sunrise: dark to light across the twilight window.
	if clockTime > dawn - twilight and clockTime < dawn + twilight then
		return (clockTime - (dawn - twilight)) / (twilight * 2)
	end
	-- Sunset: light to dark.
	if clockTime > dusk - twilight and clockTime < dusk + twilight then
		return 1 - (clockTime - (dusk - twilight)) / (twilight * 2)
	end
	return 0
end

--------------------------------------------------------------------------------
-- Driving the volumes
--------------------------------------------------------------------------------

-- Recomputing every frame is pointless -- none of these inputs change meaningfully in 16ms -- but the fade
-- toward the target does need to be smooth, so the target is sampled slowly and approached every frame.
local SAMPLE_INTERVAL = 0.5
local sinceSample = SAMPLE_INTERVAL -- sample immediately on the first frame
local targets = {}

local function sampleTargets()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		-- No character to stand anywhere: fade everything out rather than leaving the last position's
		-- ambience playing under the respawn screen.
		for name in pairs(sounds) do targets[name] = 0 end
		return
	end

	local pos = root.Position
	local clockTime = workspace:GetAttribute("WOLD_ClockTime") or 12
	local day = dayFactor(clockTime)
	local town = townMultiplier(pos.X, pos.Z)
	local coast = coastLevel(pos.X, pos.Z)
	local mountain = mountainLevel(pos.Y)

	for name, layer in pairs(SoundscapeConfig.Ambience) do
		local level = layer.volume

		if layer.when == "day" then
			level *= day
		elseif layer.when == "night" then
			level *= (1 - day)
		end

		if layer.zone == "coast" then
			level *= coast
		elseif layer.zone == "mountain" then
			level *= mountain
		end

		-- Wildlife quietens among buildings; wind and surf are weather and do not care that there is a town
		-- in the way.
		if layer.zone == nil then
			level *= town
		end

		targets[name] = level
	end
end

RunService.Heartbeat:Connect(function(dt)
	sinceSample += dt
	if sinceSample >= SAMPLE_INTERVAL then
		sinceSample = 0
		sampleTargets()
	end

	-- Move each layer toward its target at a fixed rate, so every fade takes the same time regardless of
	-- how far it has to travel.
	local step = dt / SoundscapeConfig.AmbienceFadeSeconds
	for name, sound in pairs(sounds) do
		local target = targets[name] or 0
		local current = sound.Volume
		if current < target then
			sound.Volume = math.min(target, current + step)
		elseif current > target then
			sound.Volume = math.max(target, current - step)
		end
	end
end)
