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

local function apply(clockTime)
	local s = DayNightConfig.Sample(clockTime)
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

RunService.Heartbeat:Connect(function(dt)
	Lighting.ClockTime = (Lighting.ClockTime + dt * HOURS_PER_SECOND) % 24

	sinceApply += dt
	if sinceApply >= APPLY_INTERVAL then
		sinceApply = 0
		apply(Lighting.ClockTime)
	end
end)
