-- DayNightConfig: how long a day lasts and what the sky looks like through it.
--
-- Shared so the client can read the same numbers (a clock UI, or anything that needs to know it is night)
-- without a second copy of the schedule.
local DayNightConfig = {}

-- One full 24-hour cycle per this many real seconds. 20 minutes is long enough that a session sees a sunset
-- without night dragging.
DayNightConfig.DayLengthSeconds = 20 * 60
DayNightConfig.StartTime = 7 -- players arrive at dawn

-- Night runs from dusk to dawn, crossing midnight. Used for "is it dark" checks by anything that cares.
DayNightConfig.DuskHour = 18.5
DayNightConfig.DawnHour = 5.5

function DayNightConfig.IsNight(clockTime)
	return clockTime >= DayNightConfig.DuskHour or clockTime < DayNightConfig.DawnHour
end

-- Keyframes around the clock. Lighting is interpolated between whichever pair the current hour falls in, so
-- dawn and dusk are gradual rather than a switch being thrown. `hour` must be ascending.
DayNightConfig.Keys = {
	{
		hour = 0, -- deep night
		brightness = 0.6,
		ambient = Color3.fromRGB(28, 32, 52),
		outdoorAmbient = Color3.fromRGB(48, 54, 84),
		colorShift = Color3.fromRGB(18, 22, 46),
		fogColor = Color3.fromRGB(22, 26, 44),
		fogEnd = 900,
		atmosphereDensity = 0.42,
		atmosphereHaze = 1.2,
		atmosphereColor = Color3.fromRGB(40, 48, 78),
	},
	{
		hour = 5.5, -- first light
		brightness = 1.1,
		ambient = Color3.fromRGB(72, 66, 78),
		outdoorAmbient = Color3.fromRGB(112, 100, 110),
		colorShift = Color3.fromRGB(70, 44, 40),
		fogColor = Color3.fromRGB(140, 116, 118),
		fogEnd = 1400,
		atmosphereDensity = 0.36,
		atmosphereHaze = 2.4,
		atmosphereColor = Color3.fromRGB(150, 122, 112),
	},
	{
		hour = 7, -- sunrise, warm and low
		brightness = 2.0,
		ambient = Color3.fromRGB(104, 94, 92),
		outdoorAmbient = Color3.fromRGB(150, 136, 128),
		colorShift = Color3.fromRGB(96, 58, 30),
		fogColor = Color3.fromRGB(196, 164, 140),
		fogEnd = 2200,
		atmosphereDensity = 0.3,
		atmosphereHaze = 2.0,
		atmosphereColor = Color3.fromRGB(196, 168, 142),
	},
	{
		hour = 12, -- midday
		brightness = 2.6,
		ambient = Color3.fromRGB(92, 92, 100),
		outdoorAmbient = Color3.fromRGB(132, 132, 136),
		colorShift = Color3.fromRGB(0, 0, 0),
		fogColor = Color3.fromRGB(186, 200, 216),
		fogEnd = 4000,
		atmosphereDensity = 0.22,
		atmosphereHaze = 1.1,
		atmosphereColor = Color3.fromRGB(199, 210, 226),
	},
	{
		hour = 17, -- late afternoon
		brightness = 2.2,
		ambient = Color3.fromRGB(96, 88, 84),
		outdoorAmbient = Color3.fromRGB(142, 128, 118),
		colorShift = Color3.fromRGB(70, 40, 18),
		fogColor = Color3.fromRGB(196, 170, 146),
		fogEnd = 2800,
		atmosphereDensity = 0.28,
		atmosphereHaze = 1.8,
		atmosphereColor = Color3.fromRGB(206, 176, 148),
	},
	{
		hour = 18.5, -- sunset
		brightness = 1.2,
		ambient = Color3.fromRGB(70, 58, 62),
		outdoorAmbient = Color3.fromRGB(104, 88, 92),
		colorShift = Color3.fromRGB(88, 40, 26),
		fogColor = Color3.fromRGB(150, 104, 92),
		fogEnd = 1600,
		atmosphereDensity = 0.36,
		atmosphereHaze = 2.6,
		atmosphereColor = Color3.fromRGB(168, 116, 98),
	},
	{
		hour = 20, -- dusk fading out
		brightness = 0.7,
		ambient = Color3.fromRGB(38, 40, 60),
		outdoorAmbient = Color3.fromRGB(60, 64, 92),
		colorShift = Color3.fromRGB(26, 28, 52),
		fogColor = Color3.fromRGB(34, 38, 58),
		fogEnd = 1000,
		atmosphereDensity = 0.4,
		atmosphereHaze = 1.6,
		atmosphereColor = Color3.fromRGB(52, 58, 88),
	},
	{
		hour = 24, -- wraps to the 0 entry
		brightness = 0.6,
		ambient = Color3.fromRGB(28, 32, 52),
		outdoorAmbient = Color3.fromRGB(48, 54, 84),
		colorShift = Color3.fromRGB(18, 22, 46),
		fogColor = Color3.fromRGB(22, 26, 44),
		fogEnd = 900,
		atmosphereDensity = 0.42,
		atmosphereHaze = 1.2,
		atmosphereColor = Color3.fromRGB(40, 48, 78),
	},
}

-- The settings for a given hour, interpolated between the two surrounding keyframes.
function DayNightConfig.Sample(clockTime)
	local keys = DayNightConfig.Keys
	local a, b = keys[#keys - 1], keys[#keys]
	for i = 1, #keys - 1 do
		if clockTime >= keys[i].hour and clockTime <= keys[i + 1].hour then
			a, b = keys[i], keys[i + 1]
			break
		end
	end

	local span = b.hour - a.hour
	local t = span > 0 and ((clockTime - a.hour) / span) or 0

	return {
		brightness = a.brightness + (b.brightness - a.brightness) * t,
		ambient = a.ambient:Lerp(b.ambient, t),
		outdoorAmbient = a.outdoorAmbient:Lerp(b.outdoorAmbient, t),
		colorShift = a.colorShift:Lerp(b.colorShift, t),
		fogColor = a.fogColor:Lerp(b.fogColor, t),
		fogEnd = a.fogEnd + (b.fogEnd - a.fogEnd) * t,
		atmosphereDensity = a.atmosphereDensity + (b.atmosphereDensity - a.atmosphereDensity) * t,
		atmosphereHaze = a.atmosphereHaze + (b.atmosphereHaze - a.atmosphereHaze) * t,
		atmosphereColor = a.atmosphereColor:Lerp(b.atmosphereColor, t),
	}
end

return DayNightConfig
