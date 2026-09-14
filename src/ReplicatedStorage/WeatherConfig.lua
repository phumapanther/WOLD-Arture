-- WeatherConfig: the sky's moods, as adjustments to whatever the clock already decided.
--
-- Weather is a MODIFIER, never an absolute. DayNight rewrites Lighting four times a second from its own
-- keyframes, so anything that set FogEnd outright would be overwritten within a quarter of a second --
-- weather has to be applied on top of that sample, every time, which is what `Apply` below is for.
--
-- That also means fog at noon and fog at midnight look different without either being configured twice: the
-- rain multiplies whatever brightness the hour had, so a storm at night is simply a dark night.
local WeatherConfig = {}

-- How often the sky changes its mind, and how long the change takes to arrive. Two hours, as the user asked.
WeatherConfig.RollEverySeconds = 2 * 60 * 60
-- Eased over half a minute rather than snapped: weather that arrives between two frames reads as a bug.
WeatherConfig.TransitionSeconds = 30

-- `fogEnd` and `brightness` scale what the clock produced. `density`/`haze` are added to the atmosphere.
-- `particles` names the effect the client draws -- rain and snow are drawn on the CLIENT, at the camera,
-- because a world-sized particle field is both expensive and pointless when only one player can see it.
--
-- `weight` is how often it comes up in the two-hourly roll. Clear weather is the most likely thing by a
-- wide margin: weather is an event, and a world that is always doing something has no weather at all.
WeatherConfig.Kinds = {
	clear = {
		name = "ท้องฟ้าแจ่มใส",
		weight = 30,
		fogEnd = 1, brightness = 1, density = 0, haze = 0,
		announce = false, -- the default sky is not news
	},
	bright = {
		name = "แดดจัด",
		weight = 14,
		-- Further than usual and brighter: the day you can see the far shore from the city wall.
		fogEnd = 1.6, brightness = 1.25, density = -0.05, haze = -0.3,
		tint = Color3.fromRGB(255, 250, 230),
		announce = true,
	},
	fog = {
		name = "หมอกหนา",
		weight = 14,
		-- The user's "มองได้ไม่ไกล". A fifth of the usual draw distance is close enough to lose a road in.
		fogEnd = 0.2, brightness = 0.85, density = 0.45, haze = 2.4,
		tint = Color3.fromRGB(214, 218, 224),
		announce = true,
	},
	rain = {
		name = "ฝนตก",
		weight = 16,
		fogEnd = 0.45, brightness = 0.7, density = 0.2, haze = 1.1,
		tint = Color3.fromRGB(170, 185, 205),
		particles = "rain",
		-- The user asked for the screen itself to be hard to see through, not only the world: this is the
		-- streaking on the lens, drawn by the client over everything.
		wetScreen = 0.35,
		sound = "rain",
		announce = true,
	},
	storm = {
		name = "พายุฝนฟ้าคะนอง",
		weight = 8,
		fogEnd = 0.3, brightness = 0.5, density = 0.3, haze = 1.6,
		tint = Color3.fromRGB(140, 150, 175),
		particles = "rain",
		wetScreen = 0.5,
		sound = "rain",
		-- Lightning: the sky goes white for a moment, every so often. Drawn by the client for the same
		-- reason the rain is.
		lightning = { everyMin = 8, everyMax = 26 },
		announce = true,
	},
	snow = {
		name = "หิมะตก",
		weight = 10,
		fogEnd = 0.35, brightness = 0.95, density = 0.25, haze = 1.3,
		tint = Color3.fromRGB(226, 236, 246),
		particles = "snow",
		announce = true,
	},
	sandstorm = {
		name = "พายุทราย",
		weight = 8,
		-- The worst visibility of the lot, and the only one that tints everything the colour of the dust.
		fogEnd = 0.15, brightness = 0.8, density = 0.6, haze = 3,
		tint = Color3.fromRGB(214, 178, 112),
		particles = "sand",
		wetScreen = 0.2, -- grit on the lens rather than water, same effect
		sound = "wind",
		announce = true,
	},
}

-- Fixed order, for the admin command's list and so a roll is reproducible.
WeatherConfig.Order = { "clear", "bright", "fog", "rain", "storm", "snow", "sandstorm" }

WeatherConfig.Default = "clear"

-- Applies a weather kind on top of one DayNight sample, in place. Called by DayNight every time it writes
-- Lighting, so the two can never fight over who set the fog.
function WeatherConfig.Apply(sample, kindId, blend)
	local kind = WeatherConfig.Kinds[kindId]
	if not kind then return sample end

	-- `blend` runs 0 to 1 while weather is arriving or leaving, so nothing snaps.
	blend = math.clamp(blend or 1, 0, 1)
	local function mix(base, target)
		return base + (target - base) * blend
	end

	sample.fogEnd = mix(sample.fogEnd, sample.fogEnd * kind.fogEnd)
	sample.brightness = mix(sample.brightness, sample.brightness * kind.brightness)
	sample.atmosphereDensity = math.clamp(mix(sample.atmosphereDensity, sample.atmosphereDensity + kind.density), 0, 1)
	sample.atmosphereHaze = math.clamp(mix(sample.atmosphereHaze, sample.atmosphereHaze + kind.haze), 0, 10)
	if kind.tint then
		sample.fogColor = sample.fogColor:Lerp(kind.tint, blend * 0.75)
		sample.atmosphereColor = sample.atmosphereColor:Lerp(kind.tint, blend * 0.6)
	end
	return sample
end

return WeatherConfig
