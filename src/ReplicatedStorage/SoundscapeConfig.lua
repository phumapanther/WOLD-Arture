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
-- เสียงฝีเท้าตอนวิ่งถี่ขึ้น 50% ตามความเร็ววิ่งที่เพิ่มเป็น 24 (0.28 -> 0.19)
--
-- **ต้องขยับตามความเร็วเสมอ** ระยะก้าวคือ ความเร็ว x ช่วงห่าง ถ้าวิ่งเร็วขึ้นแต่เสียงยังห่างเท่าเดิม
-- ตัวละครจะก้าวยาวขึ้น 50% ซึ่งตาเห็นเป็นการไถลไปกับพื้น
SoundscapeConfig.StepIntervalRun = 0.19 -- WalkSpeed 24

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
-- Interface and event sounds
--------------------------------------------------------------------------------

-- One-shots for things the interface does, and for two moments in the world worth marking. These are not
-- positional: they are things happening TO YOU, so they play flat rather than from somewhere in the world.
--
-- All at 0.3 of the uploads' natural level, matching the rest of the game's mix.
SoundscapeConfig.Interface = {
	Volume = 0.3,

	-- Per-sound overrides. Anything not named here plays at Volume above, which is what almost everything
	-- should do: a click and a coin belong at the same level, and the interface having one voice is the point.
	--
	-- A table rather than a second flat field, so the exception stays next to the rule and adding another one
	-- later is a line rather than a change to UiSound.
	Volumes = {
		-- The two event announcements, 50% over the common level at the user's request (0.3 -> 0.45). These
		-- are the only interface sounds that have to carry over whatever the player is already standing in --
		-- a fight, a forge, a town at night -- and they fire twice an hour rather than on every button.
		EventSlime = 0.45,
		EventBlackout = 0.45,
		-- The forge, doubled on request (0.3 -> 0.6). It is the only interface sound that LOOPS for the
		-- length of an action rather than firing once, and at the common level it went missing under the
		-- world while the player stood there waiting for it.
		Craft = 0.6,
		-- ชุด QA 2026-09-28: ตัวอักษรบทพูดเบามาก (ขึ้นถี่) · เลเวลขึ้น/กาชาหายาก/ป้ายชื่อเกมดังกว่าปกติ
		Blip = 0.12, LevelUp = 0.5, GachaLegend = 0.45, CutTitle = 0.45, CutRumble = 0.35, ToastError = 0.25,
		-- แตรฉลองเลเวลฟาร์ม (เฟส 2c) — เกิดนานๆ ครั้ง ต้องดังพอให้รู้สึกว่าเป็นช่วงเวลาพิเศษ
		FarmLevelUp = 0.5,
	},

	-- Placing a call, and being called. The ringtone repeats while the caller waits for an answer; the
	-- others are single events.
	Call = "rbxassetid://136630953748080",
	Ringtone = "rbxassetid://97881981206256",

	-- A message arriving, and anything else that wants attention later.
	Notification = "rbxassetid://137070625485720",

	-- Buttons on the speaking stone, and picking items up in the bag. Not equipping, which has its own
	-- heavier sound already.
	Click = "rbxassetid://111830273525239",

	-- The blow that puts you down. Heard ONLY by the person going down: it marks your own defeat, and
	-- everyone nearby hearing it would turn a private moment into a broadcast.
	LastHit = "rbxassetid://137178131907409",

	-- Choosing to respawn.
	Respawn = "rbxassetid://93187755315297",

	-- Being hurt: Roblox's own death grunt, the one every default character makes when it dies, at the user's
	-- request. Not an upload -- it ships with the engine, so there is no asset to publish and nothing to go
	-- missing. Read off a live character's HumanoidRootPart.Died rather than copied from memory, which is the
	-- only way to be sure of an rbxasset path.
	--
	-- Heard ONLY by the person it happened to, like LastHit above: see HurtSoundController. A monster's bite
	-- and starving both use it, because to the player they are the same fact -- something is taking my blood.
	Hurt = "rbxasset://sounds/uuhhh.mp3",

	-- Using a consumable. Which one an item plays is the item's own business, declared as `useSound` in
	-- ItemCatalog, so adding a consumable later means naming its sound rather than editing a list here.
	Eat = "rbxassetid://77895300305950",
	Drink = "rbxassetid://139274681710432",
	Hammer = "rbxassetid://114020474816962",

	-- The forge working. Looped for as long as a craft takes rather than played once, because the wait is
	-- the point: the bar filling and the sound running are the same piece of feedback, and a single clang
	-- against a two-and-a-half-second wait would leave most of it silent.
	Craft = "rbxassetid://99358431994374",

	-- Money changing hands: giving, robbing, a fine paid, a trade closing. Heard by both parties, since a
	-- transfer is a thing that happens between two people rather than to one.
	Coin = "rbxassetid://117316732298294",
	-- The architect putting someone gear back together. Longer and more mechanical than the hand hammer.
	Repair = "rbxassetid://129031223149367",

	--------------------------------------------------------------------------
	-- V1: the minigames, and the two world events.
	--
	-- Ding and Fail are shared by BOTH minigames on purpose -- the arrow game at the illegal farms and the
	-- skill-check bar at the transformers are different games asking the same question, and a player should
	-- learn one pair of sounds rather than four.
	--------------------------------------------------------------------------

	-- Rummaging through a crate or a still, played while the character searches. One-shot, at the start of
	-- the attempt, before the minigame appears.
	Rummage = "rbxassetid://113584262071963",
	-- Hit the beat.
	Ding = "rbxassetid://96197551641029",
	-- Missed it. Ends the minigame wherever it was.
	Fail = "rbxassetid://130496762736639",
	-- The skill-check bar springing up mid-repair. A warning, not a reward: it means "press now".
	SkillCheck = "rbxassetid://118583229541459",
	-- The engine being worked on, looped for the whole thirty seconds of a repair.
	RepairLoop = "rbxassetid://126212750200158",

	-- The two event announcements. Played once when the banner appears, alongside it rather than as part of
	-- it, so a player who has the interface hidden still hears the city break down.
	EventSlime = "rbxassetid://96435027172919",
	EventBlackout = "rbxassetid://114222303730351",

	-- เฟส 2c เลเวลฟาร์ม: แตรฉลองตอนแบนเนอร์ขึ้น ("Success Fanfare Medieval Trumpets" · PreloadAsync ผ่าน 2026-09-27)
	-- และหวูดรถตอนส่งของขึ้นรถ (ไฟล์เดียวกับหวูดรถยนต์ของระบบพาหนะ — ผู้เล่นรู้จักเสียงนี้อยู่แล้ว)
	FarmLevelUp = "rbxassetid://125367748123159",
	ExportShip = "rbxassetid://129823389217678",

	--------------------------------------------------------------------------
	-- QA 2026-09-28: "อินเทอแร็กอะไรแล้วต้องไม่เงียบ" — เสียงชุดใหม่ ผมคัดจาก Creator Store (ผู้ใช้เลือก) ·
	-- ส่วนใหญ่จากคลังที่ Roblox ได้สิทธิ์มา (ProSoundEffects / APM) + ชุด UI ทางการของ Roblox ·
	-- **PreloadAsync ผ่านทุกตัว 2026-09-28** · อยากเปลี่ยนเสียงไหน แก้ id ตรงนี้ที่เดียว · คลิปยาวถูกตัดที่ `MaxSeconds`
	--------------------------------------------------------------------------
	ToastInfo = "rbxassetid://17208361335",   -- Roblox GUI - Notification High (ข้อความทั่วไป)
	ToastError = "rbxassetid://17208353912",  -- Roblox GUI - Negative (ทำไม่ได้/ถูกปฏิเสธ)
	ToastReward = "rbxassetid://9116395089",  -- Magic Glows Soft Clusters Of Chiming Hit (ได้ของ/รางวัล)
	Purchase = "rbxassetid://17208380755",    -- Roblox GUI - Purchase (ซื้อสำเร็จ ร้านเพชร/สนาม)
	Select = "rbxassetid://17208396156",      -- Roblox GUI - Select (ยกเลิกการซื้อ/เลือก)
	LevelUp = "rbxassetid://12222253",        -- victory.wav ของ Roblox (เลเวลตัวละครขึ้น)
	StoryStep = "rbxassetid://15675085146",   -- Roblox_UI_Indicator (ขั้นเควสเนื้อเรื่องใหม่)
	Blip = "rbxassetid://15675032796",        -- Roblox_UI_Small_Click (ตัวอักษรบทพูดขึ้น)
	PaperSwipe = "rbxassetid://15675037413",  -- Roblox_UI_Paper_Swipe (รับงานจากบอร์ด)
	CutRumble = "rbxassetid://9118747853",    -- Rumble Ambience Interior Wind Turbo (เครื่องจักรไอน้ำใต้เมือง)
	CutMagic = "rbxassetid://9116420454",     -- Magic Tone Tonal Shimmer (รูนสว่าง)
	CutFlash = "rbxassetid://9125646917",     -- Magic Whooshes Metallic Shimmer (แสงวาบ)
	CutTitle = "rbxassetid://1839901317",     -- Heavenly sting (APM · ป้ายชื่อเกม)
	Memory = "rbxassetid://9126213744",       -- Whisper Bursts Eerie (ภาพความทรงจำ)
	GachaCommon = "rbxassetid://17208204604", -- Roblox GUI - Bubble
	GachaRare = "rbxassetid://9116418035",    -- Magic Tone Falling Shimmer
	GachaLegend = "rbxassetid://1836473422",  -- Victory Fanfare Sting (APM)
	-- เสียงในโลก (ได้ยินตามระยะ — UiSound.PlayAt / WorldSound)
	TrapThrow = "rbxassetid://9125647212",    -- Magic Whooshes Pass Bys
	TrapLand = "rbxassetid://9116541944",     -- Metal Clanks 2
	TrapSlow = "rbxassetid://12222152",       -- splat.wav ของ Roblox
	TrapStun = "rbxassetid://92090867642655", -- Electric Zap Sound
	TrapKnock = "rbxassetid://9114057128",    -- Desert Wind Light Gusts (คลิปยาว ตัด 1.5 วิ)
	Place = "rbxassetid://9126267420",        -- Wood Hit Dull Thud (วางของบนเกาะ)
	Pickup = "rbxassetid://17208204604",      -- Roblox GUI - Bubble (เก็บของคืนกระเป๋า)
	Plant = "rbxassetid://9114084044",        -- Dirt Digging With Pick (หยอดเมล็ด)
	Harvest = "rbxassetid://9114519078",      -- Foliage Rustle (เก็บผัก)

	-- คลิปที่ยาวเกินจังหวะ: ตัดที่วินาทีนี้ (ค่อยๆ เบาลง 0.3 วิสุดท้าย) · ไม่มีชื่อ = เล่นจนจบ
	MaxSeconds = {
		ToastInfo = 0.8, ToastReward = 1.4, StoryStep = 1.2, CutMagic = 3, GachaRare = 2.2, GachaLegend = 3.5,
		TrapThrow = 0.9, TrapLand = 0.8, TrapStun = 0.9, TrapKnock = 1.5, Harvest = 1, Plant = 0.9,
		Memory = 3, CutTitle = 3.5, CutRumble = 12,
	},
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
	-- Raised 40% from 0.125 at the user's request. Every music level in this file moved by the same 40%, so
	-- the balance BETWEEN them -- lobby over world, combat over both -- is exactly what it was; only the
	-- whole mix is louder.
	Volume = 0.175,
	-- Fades in on arrival rather than starting at full, and fades out when a channel is joined so the music
	-- does not cut off mid-note as the screen blacks out for the teleport.
	FadeSeconds = 2,
}

--------------------------------------------------------------------------------
-- World music
--------------------------------------------------------------------------------

-- Music out in the world, as opposed to the lobby's. Three kinds, in priority order:
--   combat    a fight is happening to you -- interrupts everything, fades back out when it is over
--   zone      you are in a settlement -- its own theme
--   wander    out in open country -- an occasional track, mostly silence
--
-- Only one plays at a time: the highest-priority kind wins and the others fade out under it. Silence is the
-- default, not a failure -- a roleplay game people sit in for hours should not have wall-to-wall music.
--
-- Every id is from APMOfficial or DistrokidOfficial, Roblox's licensed-music partner accounts, so publishing
-- carries no takedown risk. All were load-tested in this place.
SoundscapeConfig.WorldMusic = {
	Volume = 0.098, -- +40%; still quieter than the lobby's, since this plays under footsteps and ambience
	FadeSeconds = 3, -- slow, so a track arriving or leaving is never a noticeable event

	-- Combat. Fades in the moment a real blow lands (dealt or taken, not a swing at air) and fades out
	-- after the last one. Every fresh hit restarts that countdown, so a long fight keeps its music.
	Combat = {
		Tracks = {
			-- Chosen for having no quiet passages: the music starts mid-track on a hit, so a track that
			-- opens softly would fade in on nothing.
			"rbxassetid://9043368831",       -- Race to the Artifact, 1:32 -- brass, choir, never lets up
			"rbxassetid://9043369028",       -- Heroes are Coming, 1:35 -- more heroic than menacing
			"rbxassetid://9043602056",       -- Ghost Ship, 1:02 -- agitated strings and gothic choir
			"rbxassetid://139997523791273",  -- Boss Battle Burnout, 2:52
		},
		Volume = 0.154, -- +40%; still the loudest of the three, because it is meant to take over
		FadeInSeconds = 1.5, -- quick enough to feel like a reaction to being hit
		FadeOutSeconds = 4, -- slow, so the fight ending settles rather than stops
		LingerSeconds = 10, -- quiet for this long after the last blow before it lets go
	},

	-- Out in open country: a track now and then, long gaps between. Deliberately sparse.
	Wander = {
		Tracks = {
			"rbxassetid://93280438567176",   -- Cozy Tavern Ambience II, 5:10
			"rbxassetid://140595275946952",  -- Greensleeves Variations, 5:05
			"rbxassetid://1843259503",       -- Hush Nightingale, 3:56
			"rbxassetid://140648151329276",  -- Noctilucent Calm, 2:26
			"rbxassetid://9042042999",       -- Comfort (b), 2:08 -- warm cello drones, no melody to tire of
			"rbxassetid://77732020920507",   -- The Alchemist's Pendulum, 2:35 -- clockwork, the steampunk half
		},
		FirstDelaySeconds = 300, -- five minutes of nothing before the first track
		GapSeconds = 600, -- and ten minutes between tracks after one finishes
	},

	-- Settlements. Each has its own theme, and its own idea of what it is: a farming village should not
	-- sound like a royal keep. Zone names match SoundscapeConfig.Towns.
	Zones = {
		Brasshaven = {
			Tracks = {
				"rbxassetid://9042223208",   -- Chaconne pour les Ombres -- harpsichord and baroque strings
				"rbxassetid://9042222859",   -- Chaconne des Tendres
				"rbxassetid://1842164153",   -- Brandenburg No. 5, 3:14
				"rbxassetid://1842309221",   -- Catch As Cornet Can -- the most bustling of the four
			},
		},
		["Ironcrest Keep"] = {
			Tracks = {
				"rbxassetid://1840747895",   -- Papal Might -- solemn and ceremonial
				"rbxassetid://1837435717",   -- Redemption -- orchestra and choir
				"rbxassetid://1837435800",   -- A Place for Kings -- brass-forward
			},
		},
		-- The mage village and the spire share the arcane set.
		Astravale = {
			Tracks = {
				"rbxassetid://85026511867827", -- Searching for Sorcery
				"rbxassetid://9039951256",     -- Dance Of The Elves
				"rbxassetid://1840049555",     -- Bells and Harp -- near-melodyless, sits under NPC chatter
			},
		},
		-- ปล่องมังกรหลับ (2026-09-29) ใช้ชุดมืดเดิมของหอเวทเอลด์ที่ไม่เคยถูกสร้าง (โซนเดิมทับปล่องอยู่)
		Wyrmsleep = {
			Tracks = {
				"rbxassetid://1843291182",     -- Time Sphere Cymbalum -- darker, for the crater rather than the village
				"rbxassetid://85026511867827", -- Searching for Sorcery
				"rbxassetid://1840049555",     -- Bells and Harp
			},
		},
	},

	-- Every other settlement is a village and shares the folk set, rather than each needing its own theme
	-- before it has been built.
	DefaultZoneTracks = {
		"rbxassetid://9044850771",   -- Gånglåt från Uppåkra -- solo violin folk
		"rbxassetid://1840385289",   -- Connaught Man's Rambles -- Irish trad
		"rbxassetid://1842316061",   -- Celtic Dance -- livelier
		"rbxassetid://1842176562",   -- Olive Grove -- solo guitar, the sleepiest
	},

	-- After a settlement's track finishes, its theme stays quiet this long before starting another, so a
	-- town is not a continuous soundtrack either.
	ZoneGapSeconds = 600,
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
	{ name = "Wyrmsleep", x = 3250, z = -4850, radius = 400 }, -- ปล่องมังกรหลับ = WyrmsleepConfig.Center
}

return SoundscapeConfig
