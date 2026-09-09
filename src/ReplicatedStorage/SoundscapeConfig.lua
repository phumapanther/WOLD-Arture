-- SoundscapeConfig: what the world sounds like -- footsteps underfoot, and the ambience around you.
--
-- Two separate systems share this file because they are both "world audio" and are tuned against each
-- other: ambience has to sit under footsteps without either drowning the other out.
--
-- Every asset id here was load-tested in this place before being written down. Roblox ships exactly one
-- built-in footstep sound (action_footsteps_plastic), which is why every surface sounds identical by
-- default; these are free Creator Store uploads standing in for the set the engine does not provide.
local SoundscapeConfig = {}

--------------------------------------------------------------------------------
-- Footsteps
--------------------------------------------------------------------------------

-- Terrain and part materials, grouped by what they should SOUND like rather than what they are. Cobblestone
-- and Basalt are different rock to look at and the same rock to walk on.
--
-- Anything not listed falls back to Default, so a material added to the map later is never silent.
SoundscapeConfig.MaterialGroups = {
	-- Worked stone and bare rock: the streets of Brasshaven, cliffs, cave floors.
	[Enum.Material.Cobblestone] = "Stone",
	[Enum.Material.Rock] = "Stone",
	[Enum.Material.Slate] = "Stone",
	[Enum.Material.Concrete] = "Stone",
	[Enum.Material.Basalt] = "Stone",
	[Enum.Material.Brick] = "Stone",
	[Enum.Material.Limestone] = "Stone",
	[Enum.Material.Pavement] = "Stone",
	[Enum.Material.Marble] = "Stone",
	[Enum.Material.Granite] = "Stone",
	[Enum.Material.CrackedLava] = "Stone",
	[Enum.Material.Asphalt] = "Stone",

	-- Floorboards, decks, bridges.
	[Enum.Material.Wood] = "Wood",
	[Enum.Material.WoodPlanks] = "Wood",

	-- Open country. LeafyGrass is the forest floor, Ground is bare dirt.
	[Enum.Material.Grass] = "Grass",
	[Enum.Material.LeafyGrass] = "Grass",
	[Enum.Material.Ground] = "Dirt",

	[Enum.Material.Sand] = "Sand",

	-- Anything soft and wet underfoot. Snow keeps its own set: a footprint in snow crunches, it does not
	-- squelch.
	[Enum.Material.Mud] = "Wet",
	[Enum.Material.Snow] = "Snow",
	[Enum.Material.Glacier] = "Snow",
	[Enum.Material.Salt] = "Snow",

	-- Metal walkways around the steam works.
	[Enum.Material.Metal] = "Metal",
	[Enum.Material.CorrodedMetal] = "Metal",
	[Enum.Material.DiamondPlate] = "Metal",
}

SoundscapeConfig.DefaultGroup = "Dirt"

-- Wading through shallow water overrides the ground underneath: standing in a river should sound wet even
-- though the riverbed is sand.
SoundscapeConfig.WaterGroup = "Wet"

-- Several clips per surface, picked at random per step. One clip repeated at walking pace turns into a
-- machine-gun tick within a few seconds; this plus the pitch jitter below is what stops that.
--
-- The Half-Life 2 sets are used wherever possible because each is a matched 1-4 set from a single creator:
-- the four clips of a set share a tone, so the rotation sounds like one surface rather than four.
SoundscapeConfig.Footsteps = {
	Stone = {
		"rbxassetid://81623756670923",
		"rbxassetid://78754179999047",
		"rbxassetid://79418255155423",
		"rbxassetid://112240321395589",
	},
	-- Gravel rather than concrete: a cobbled medieval street is loose stone, not a poured slab.
	Gravel = {
		"rbxassetid://128887017112229",
		"rbxassetid://71610680142742",
		"rbxassetid://75687267679546",
		"rbxassetid://109995312794051",
	},
	Wood = {
		"rbxassetid://87921439933530",
		"rbxassetid://89597871459985",
		"rbxassetid://139932856876296",
		"rbxassetid://75643573822739",
	},
	Grass = {
		"rbxassetid://105277634319381",
		"rbxassetid://98069158661569",
		"rbxassetid://135182192451997",
		"rbxassetid://116425333836106",
	},
	Dirt = {
		"rbxassetid://80932364310315",
		"rbxassetid://130611100801821",
		"rbxassetid://97480467702673",
		"rbxassetid://114765760744945",
	},
	Sand = {
		"rbxassetid://84209465430801",
		"rbxassetid://115151668857364",
		"rbxassetid://93919782627384",
		"rbxassetid://105793766638092",
	},
	Wet = {
		"rbxassetid://80424042962324",
		"rbxassetid://115927028681166",
		"rbxassetid://85714151902569",
		"rbxassetid://95408825712170",
	},
	-- One creator's set, not a blend: mixing two people's snow recordings in one rotation sounds like two
	-- different surfaces alternating underfoot.
	Snow = {
		"rbxassetid://103816422099881",
		"rbxassetid://135918121539048",
		"rbxassetid://103079968724414",
	},
	-- No dedicated metal set was found free; concrete is the nearest hard-surface stand-in. Swap these when
	-- the steam works are built and the sound actually matters.
	Metal = {
		"rbxassetid://81623756670923",
		"rbxassetid://112240321395589",
	},
}

SoundscapeConfig.FootstepVolume = 0.35
SoundscapeConfig.FootstepDistance = 45 -- studs; far enough to hear someone approach, not across the square

-- Pitch jitter per step. Even with four clips in rotation, an exact repeat every fourth step is audible;
-- a few percent of random pitch makes each one land slightly differently.
SoundscapeConfig.FootstepPitchJitter = 0.08

-- Seconds between steps at each gait. The engine gives no "foot planted" event, so steps are timed from
-- speed: these are the intervals that looked right against the walk and run animations.
SoundscapeConfig.StepIntervalWalk = 0.55 -- WalkSpeed 4, the deliberate walk
SoundscapeConfig.StepIntervalNormal = 0.42 -- WalkSpeed 8
SoundscapeConfig.StepIntervalRun = 0.28 -- WalkSpeed 16

-- Below this the character is shuffling in place rather than travelling, and should make no sound at all.
SoundscapeConfig.MinStepSpeed = 1.5

--------------------------------------------------------------------------------
-- Water
--------------------------------------------------------------------------------

-- Swimming, and the muffled world with your head under. Three separate things happen here: strokes while
-- swimming, one-shots on crossing the surface either way, and a loop plus a filter while submerged.
SoundscapeConfig.Water = {
	-- Strokes, played on a timer while swimming, the way footsteps are played while walking. No clean
	-- isolated arm-stroke exists in the free library; these are short single water impacts, pitched up a
	-- little, which read as strokes at low volume.
	Strokes = {
		"rbxassetid://9117823333",
		"rbxassetid://9125703162",
		"rbxassetid://9125702439",
		"rbxassetid://9125702803",
	},
	StrokeInterval = 0.75, -- slower than a footstep: a swimming stroke is a longer motion
	StrokeVolume = 0.16,
	StrokePitch = 1.15, -- these clips are water impacts; a little brighter sells them as a stroke
	StrokePitchJitter = 0.1,

	-- Going in. Chosen over the pool-jump takes because its description is a body falling in and dropping
	-- under, which is what entering deep water actually sounds like.
	EnterSounds = {
		"rbxassetid://9119481909",
		"rbxassetid://9117823374",
		"rbxassetid://9117822989",
	},
	EnterVolume = 0.3,

	-- Coming out. Only one purpose-recorded water exit exists free; the drip layers a tail onto it.
	ExitSounds = {
		"rbxassetid://9120548576",
	},
	ExitVolume = 0.25,

	-- The muffled drone with your head under -- the "อื้อๆ". 59 seconds of low bubble rumble, long enough
	-- that the loop point is inaudible.
	SubmergedAmbience = "rbxassetid://9112889917",
	SubmergedVolume = 0.35,

	-- Occasional breath bubbles while submerged, so being under is not one unchanging drone.
	BubbleSounds = {
		"rbxassetid://9120310416",
		"rbxassetid://9120310104",
	},
	BubbleVolume = 0.2,
	BubbleIntervalMin = 2.5, -- seconds between bubble bursts, randomised in this range
	BubbleIntervalMax = 6,

	-- How much of the ordinary world you can still hear underwater. Everything above the surface ducks to
	-- this while submerged, which is what actually sells "head under" -- more than the drone does.
	SubmergedDuck = 0.25,
	-- Muffling proper: a low-pass filter on everything else, so what does come through is dull rather than
	-- merely quiet. Frequencies above this are cut.
	SubmergedLowPassHz = 500,

	-- Crossing the surface fades over this, so bobbing up for air is a quick swell rather than a click.
	SurfaceFadeSeconds = 0.35,
}

--------------------------------------------------------------------------------
-- Lobby music
--------------------------------------------------------------------------------

-- Plays on the channel-select screen while people browse and wait. Every track below comes from
-- DistrokidOfficial or APMOfficial, which are Roblox's own licensed-music partner accounts rather than
-- community re-uploads, so publishing the game carries no takedown risk. All were load-tested here.
SoundscapeConfig.LobbyMusic = {
	Tracks = {
		-- Cozy Tavern Ambience II, 5:10. The default: long enough that most players never hear it loop
		-- while picking a server, and the tavern mood lands on medieval-fantasy without being battle music.
		"rbxassetid://93280438567176",
		"rbxassetid://118107681971739", -- Cozy Tavern Ambience IX, 4:49
		"rbxassetid://140595275946952", -- Greensleeves Variations, 5:05 -- the most literally medieval
		"rbxassetid://138384771239589", -- Cozy Tavern Ambience VII, 3:42
		"rbxassetid://1843259503",      -- Hush Nightingale, 3:56 -- soft and pastoral
	},
	Volume = 0.25,
	-- Fades in on arrival rather than starting at full, and fades out when a channel is joined so the music
	-- does not cut off mid-note as the screen blacks out for the teleport.
	FadeSeconds = 2,
}

--------------------------------------------------------------------------------
-- Ambience
--------------------------------------------------------------------------------

-- Each layer is a long loop whose volume is driven by where the listener is and what time it is. Layers
-- stack: standing on a wooded coast at night, you hear surf and crickets together.
--
-- `volume` is the layer's volume when fully faded in, before any distance falloff.
SoundscapeConfig.Ambience = {
	-- Daytime insect drone. Tagged "Night" by its uploader but the content is a constant cicada wall, which
	-- is the sound of a hot afternoon.
	Cicadas = {
		id = "rbxassetid://9112757161",
		volume = 0.09,
		when = "day",
		-- Real cicadas come in waves: a chorus builds, holds, then dies back. Held at a flat level this was
		-- the one layer you never stopped hearing, which is exactly what makes a drone tiring. `swell` makes
		-- it rise and fall instead, and dip near silence between choruses.
		swell = { period = 26, low = 0.05, high = 1 },
	},
	-- The clean rural set rather than the one recorded next to a freeway.
	Crickets = {
		id = "rbxassetid://9112764891",
		volume = 0.12,
		when = "night",
	},
	Birds = {
		id = "rbxassetid://9112832081",
		volume = 0.09,
		when = "day",
	},
	-- Surf. The "Ocean Surf" clips were rejected despite fitting the brief: their descriptions list a prop
	-- plane flying past, which would be a strange thing to hear on a medieval coastline.
	Waves = {
		id = "rbxassetid://9119677305",
		volume = 0.13,
		when = "always",
		zone = "coast",
	},
	-- Exposed high wind. The leaves-in-trees recordings are a better wind sound but carry birdsong, which
	-- would fight the Birds layer on a bare peak.
	Wind = {
		id = "rbxassetid://5799870105",
		volume = 0.20,
		when = "always",
		zone = "mountain",
	},
}

-- How long a layer takes to fade in or out. Long enough that walking over a ridge sounds like the wind
-- rising rather than a switch being thrown.
SoundscapeConfig.AmbienceFadeSeconds = 2.5

-- Day and night are read from the world clock the DayNight system already publishes, so the ambience turns
-- over at exactly the same moment the sky does. Dawn and dusk cross-fade over this many hours rather than
-- swapping at the instant the sun clears the horizon.
SoundscapeConfig.TwilightHours = 1.0

--------------------------------------------------------------------------------
-- Zones
--------------------------------------------------------------------------------

-- Coast: surf rises as the sea gets closer. Distances are to the nearest water, in studs.
-- Both cut to 40% of their first values (120/700): the surf carried far too far inland, and you could hear
-- the sea from places with no sea in sight.
SoundscapeConfig.CoastFullDistance = 48 -- at or under this, surf is at full volume
SoundscapeConfig.CoastFadeDistance = 280 -- beyond this, silent

-- Mountain: wind rises with altitude. The snow line from world-layout.json is where it starts to be heard.
SoundscapeConfig.MountainStartHeight = 700
SoundscapeConfig.MountainFullHeight = 1400

-- Town: nature quietens among buildings. The countryside should feel different from a street, so the
-- natural layers duck rather than cut out entirely -- a city with no birds at all sounds dead.
SoundscapeConfig.TownDuck = 0.35 -- multiplier applied to nature layers while in town

-- Settlement centres, in world studs, from docs/design/world-layout.json (normalised pos x half_size 8000).
-- The capital gets a wide radius because it is a walled city; the villages are a cluster of buildings.
SoundscapeConfig.Towns = {
	{ name = "Brasshaven", x = 2080, z = 3760, radius = 900 },
	{ name = "Ironcrest Keep", x = 1760, z = 2080, radius = 400 },
	{ name = "Goldmeadow", x = -960, z = 960, radius = 350 },
	{ name = "Cogsworth", x = 800, z = -1120, radius = 400 },
	{ name = "Stonemark", x = -960, z = -3360, radius = 350 },
	{ name = "Elderwood", x = -4000, z = 160, radius = 350 },
	{ name = "Saltmere", x = -3600, z = 4960, radius = 350 },
	{ name = "Astravale", x = 3840, z = -3360, radius = 350 },
	{ name = "Spire of Eld", x = 3600, z = -4800, radius = 300 },
}

return SoundscapeConfig
