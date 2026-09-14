-- TikTokConfig: every number and every word the TikTok LIVE link uses.
--
-- Data only, like WeatherConfig and ChestConfig. TikTokLive.server reads it and does not decide anything
-- that is written here, so the streamer can retune a live -- how many likes buy a monster, how big a gift
-- has to be for a gold chest, what the viewers have to type -- without touching the code that runs it.
--
-- THE CAPS ARE NOT DECORATION. A live chat produces events faster than a Roblox server can absorb them: a
-- like storm is thousands a minute, and a hundred humanoids in one place is already a slideshow. Every
-- limit below is what stands between a good moment on stream and a server nobody can play on.
local TikTokConfig = {}

--------------------------------------------------------------------------------
-- The link
--------------------------------------------------------------------------------

-- Where the bridge is. In Studio this is the bridge running on the same machine; a published game cannot
-- reach 127.0.0.1 and needs a tunnel address here instead (see tools/tiktok-bridge/README.md).
-- How the events get in.
--   "auto"  Studio polls, a published server subscribes -- which is what each of them can actually do
--   "poll"  always HTTP, for a server that can reach the bridge (a tunnel, or a LAN address)
--   "push"  always MessagingService, and never works in Studio because Open Cloud cannot deliver to it
TikTokConfig.Mode = "auto"

-- The Open Cloud topic the bridge publishes to, for "push". Must match --topic on the bridge.
TikTokConfig.Topic = "TikTokLive"

TikTokConfig.Url = "http://127.0.0.1:8787"
TikTokConfig.Key = "" -- must match --key on the bridge; empty means no key

-- How often the game asks for new events, and how many it will take at once. Twice a second is well inside
-- HttpService's 500-per-minute budget (120/min) and is faster than a viewer can tell.
TikTokConfig.PollSeconds = 0.5
TikTokConfig.BatchSize = 20

-- After this many failed polls in a row the service stops asking and says so once, rather than filling the
-- output with the same error for the length of a stream. It tries again on this longer clock.
TikTokConfig.FailuresBeforeBackoff = 6
TikTokConfig.BackoffSeconds = 15

-- Who the events happen around. Empty means "whichever admin is in the server", which is what a streamer
-- wants on any day they are not on their main account.
TikTokConfig.AdminName = ""

--------------------------------------------------------------------------------
-- Likes -> monsters
--------------------------------------------------------------------------------

TikTokConfig.Mob = {
	Distance = 18, -- studs from the admin the ring is drawn at
	MaxPerEvent = 5, -- however many tens of likes arrived at once
	-- Monsters conjured by TikTok that may be alive at the same time. Beyond this the event is counted and
	-- announced but nothing is spawned: the stream keeps its moment, the server keeps its framerate.
	MaxAlive = 30,
	-- Nothing conjured by a viewer outlives the moment. Without this a two-hour stream ends with two hours
	-- of monsters standing in a field.
	LifetimeSeconds = 180,
}

--------------------------------------------------------------------------------
-- Gifts -> chests
--------------------------------------------------------------------------------

-- The grades the bridge sends, mapped to the chest models the game already has. The bridge decides the
-- grade from the coin count (1-9 / 10-99 / 100+); this is only the translation, kept here so a chest can be
-- swapped without touching either program.
TikTokConfig.Chest = {
	Tiers = {
		Chest_Ironbound = "Chest_Ironbound",
		Chest_Silver = "Chest_Silver",
		Chest_Gold = "Chest_Gold",
	},
	Fallback = "Chest_Ironbound",
	MaxPerMinute = 20, -- a gift train is a train
}

--------------------------------------------------------------------------------
-- Subs -> a boss with the subscriber's name on it
--------------------------------------------------------------------------------

TikTokConfig.Boss = {
	Scale = 3, -- three times the size, the user's number
	Power = 5, -- five times the health and the damage
	Distance = 22,
	MaxAlive = 3, -- three of these at once is already a lot of monster
	LifetimeSeconds = 300,
	TitlePrefix = "👑 ",
	TitleSuffix = " (Sub Boss)",
}

--------------------------------------------------------------------------------
-- Chat commands
--------------------------------------------------------------------------------

-- What a viewer types, in Thai and in English, mapped to what it does. Written as a list of aliases per
-- action rather than a table of words so the Thai and the English cannot drift apart.
TikTokConfig.Commands = {
	dizzy = { words = { "มึน", "งง", "stun", "dizzy" }, seconds = 5 },
	lay = { words = { "นอน", "ล้ม", "lay", "laydown", "layflat", "down" }, seconds = 6 },
	revive = { words = { "ชุบ", "ปั๊ม", "ฟื้น", "revive", "heal" }, fraction = 0.35 },
}

-- Emotes: "!เต้น" and "!emote dance" both reach the same place. Anything not listed here is looked up
-- straight in EmoteConfig, so every emote in the game is reachable by its own id without being repeated.
TikTokConfig.EmoteWords = {
	["เต้น"] = "dance", ["เต้น2"] = "dance2", ["เต้น3"] = "dance3",
	["โบก"] = "wave", ["โบกมือ"] = "wave", ["ชี้"] = "point",
	["เชียร์"] = "cheer", ["หัวเราะ"] = "laugh", ["นั่ง"] = "sit",
	["ไหว้"] = "wai", ["โค้ง"] = "bow", ["คำนับ"] = "bow",
	["ตกใจ"] = "scared", ["เป็นลม"] = "faint", ["สลบ"] = "floorfaint",
	["ขัดสมาธิ"] = "crosslegged", ["นั่งยอง"] = "squat", ["คลาน"] = "floorcrawl",
	["ลอย"] = "levitate", ["ฟันดาบ"] = "slash", ["นินจา"] = "ninjadash",
	["มูนวอล์ก"] = "moondance", ["หมุน"] = "spindance",
}

-- How long the admin is left alone between viewer commands of the same kind, and between any two at all.
-- Without this the admin cannot move for the length of the stream, which stops being funny in about ninety
-- seconds.
TikTokConfig.CommandCooldown = 8
TikTokConfig.GlobalCommandCooldown = 2

--------------------------------------------------------------------------------
-- Top 3 only
--------------------------------------------------------------------------------

TikTokConfig.Top = {
	-- The word after the prefix, then the argument. "!time night", "!weather rain".
	TimeWords = { ["เช้า"] = 7, ["กลางวัน"] = 12, ["เย็น"] = 17.5, ["กลางคืน"] = 0, ["ค่ำ"] = 20,
		day = 12, night = 0, morning = 7, evening = 17.5, auto = false },
	-- Weather ids straight out of WeatherConfig.Order, plus Thai words for the ones a viewer will type.
	WeatherWords = { ["ฝน"] = "rain", ["พายุ"] = "storm", ["หมอก"] = "fog", ["หิมะ"] = "snow",
		["แจ่มใส"] = "clear", ["ทราย"] = "sandstorm", auto = false },
	Cooldown = 20, -- per command word, across all three of them
}

--------------------------------------------------------------------------------
-- What the server says out loud
--------------------------------------------------------------------------------

-- Announcements go through ClassAnnouncement with the "admin" id, which is the banner the game already
-- paints red. Turn this off for a quiet stream; the events still happen.
TikTokConfig.Announce = true
TikTokConfig.AnnounceName = "TikTok LIVE"

-- Prints every event and, for a chat command, which gate it fell through: the word, the action it resolved
-- to, and whether the cooldown or the streamer check stopped it. Worth having permanently, because from the
-- outside "nothing happened in the game" and "the command was never recognised" look identical, and they
-- are the two ends of the chain.
TikTokConfig.Debug = false

return TikTokConfig
