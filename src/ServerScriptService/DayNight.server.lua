-- DayNight.server.lua: the world clock. Advances Lighting.ClockTime, which is what actually moves Roblox's
-- sun and moon across the sky, and drives the lighting through the keyframes in DayNightConfig so dawn and
-- dusk look like dawn and dusk rather than noon with the sun in a different place.
--
-- The clock is owned by the SERVER and replicated as a Workspace attribute, so every player sees the same
-- time of day. Lighting properties are set on the server too: they replicate to every client, which keeps a
-- single source of truth instead of each client running its own cycle and drifting apart.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local DayNightConfig = require(game.ReplicatedStorage.DayNightConfig)
local DayNightAccess = require(game.ServerScriptService.DayNightAccess)
local WeatherConfig = require(game.ReplicatedStorage.WeatherConfig)

Lighting.ClockTime = DayNightConfig.StartTime
-- Replicated so client code (and any later clock UI) can read the time without recomputing it.
workspace:SetAttribute("WOLD_ClockTime", Lighting.ClockTime)
workspace:SetAttribute("WOLD_IsNight", DayNightConfig.IsNight(Lighting.ClockTime))

-- Reused rather than found every frame.
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")

-- The sun and moon rise and set on their own from ClockTime; GeographicLatitude tilts the arc they travel.
-- Measured: latitude 20 puts the noon sun at y=1.00, i.e. straight overhead, which leaves shadows pointing
-- nowhere. Roblox's own default keeps it slightly off vertical (y=0.95) so midday still casts a direction.
Lighting.GeographicLatitude = 41.7
Lighting.GlobalShadows = true

local HOURS_PER_SECOND = 24 / DayNightConfig.DayLengthSeconds

-- Applying every frame is wasteful and the change is invisible at that rate; a quarter second is smooth
-- enough for a 20-minute day and costs a fraction as much replication.
local APPLY_INTERVAL = 0.25
local sinceApply = 0

-- Set by Weather.server: returns (kindId, blend) for the sky right now, or nil while no weather runs. A
-- function rather than a require, so DayNight keeps no dependency on the weather system and works exactly
-- as before in a place that has none.
local weatherSource = nil
function DayNightAccess.SetWeatherSource(fn)
	weatherSource = fn
end

local function apply(clockTime)
	local s = DayNightConfig.Sample(clockTime)
	-- Weather sits ON TOP of the clock's own sample, every time, because this function rewrites Lighting
	-- four times a second -- anything that set the fog outside of here would be erased within a tick.
	if weatherSource then
		local kindId, blend = weatherSource()
		if kindId then
			WeatherConfig.Apply(s, kindId, blend)
		end
	end
	Lighting.Brightness = s.brightness
	Lighting.Ambient = s.ambient
	Lighting.OutdoorAmbient = s.outdoorAmbient
	Lighting.ColorShift_Top = s.colorShift
	Lighting.FogColor = s.fogColor
	Lighting.FogEnd = s.fogEnd
	if atmosphere then
		atmosphere.Density = s.atmosphereDensity
		atmosphere.Haze = s.atmosphereHaze
		atmosphere.Color = s.atmosphereColor
	end

	workspace:SetAttribute("WOLD_ClockTime", clockTime)
	workspace:SetAttribute("WOLD_IsNight", DayNightConfig.IsNight(clockTime))
end

apply(Lighting.ClockTime)

-- An hour the clock has been pinned to, or nil while it runs normally. An admin setting the world to
-- "morning" means morning STAYS -- not that it starts at dawn and is dusk twenty minutes later -- so holding
-- has to stop the advance rather than just set the hour once.
local heldAt = nil

DayNightAccess.Hold = function(hour)
	heldAt = hour and (hour % 24) or nil
	if heldAt then
		Lighting.ClockTime = heldAt
		apply(heldAt)
	end
	return heldAt or Lighting.ClockTime
end

DayNightAccess.HeldAt = function()
	return heldAt
end

RunService.Heartbeat:Connect(function(dt)
	-- Still applied while held, not merely left alone: something else may have moved Lighting, and a held sky
	-- that quietly drifts back is worse than one that never held.
	if heldAt then
		sinceApply += dt
		if sinceApply >= APPLY_INTERVAL then
			sinceApply = 0
			Lighting.ClockTime = heldAt
			apply(heldAt)
		end
		return
	end

	Lighting.ClockTime = (Lighting.ClockTime + dt * HOURS_PER_SECOND) % 24

	sinceApply += dt
	if sinceApply >= APPLY_INTERVAL then
		sinceApply = 0
		apply(Lighting.ClockTime)
	end
end)
