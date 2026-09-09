-- SocialConfig: every number and name the social system uses, in one place so balance changes never mean
-- hunting through UI code.
--
-- See docs/superpowers/specs/2026-09-08-social-system-design.md.
local SocialConfig = {}

--------------------------------------------------------------------------------
-- Guild board
--------------------------------------------------------------------------------

SocialConfig.BoardMaxPosts = 50 -- kept per server; older posts fall off the end
SocialConfig.BoardMaxLength = 200 -- characters in one post
SocialConfig.BoardCooldown = 5 -- seconds between posts, per player, to blunt spam

-- The floating feed on the game screen: the newest few posts, visible without opening the stone.
SocialConfig.FeedCount = 5 -- how many can be on screen at once
SocialConfig.FeedSeconds = 10 -- how long one stays before it starts fading
SocialConfig.FeedFadeSeconds = 1.2 -- how long the fade itself takes

--------------------------------------------------------------------------------
-- Friends and pigeon messages
--------------------------------------------------------------------------------

SocialConfig.MaxFriends = 50
SocialConfig.MaxPendingRequests = 20 -- a cap so nobody can be buried in requests
SocialConfig.MessageMaxLength = 200
SocialConfig.MessageCooldown = 1 -- seconds between messages, per player
SocialConfig.MessageHistory = 30 -- messages kept per conversation, in server memory

--------------------------------------------------------------------------------
-- Bank
--------------------------------------------------------------------------------

-- Pocket gold is lost on death; banked gold is not. That difference is the whole reason the bank exists,
-- so it is stated here rather than left implicit in whatever code happens to reset gold.
SocialConfig.BankMaxTransfer = 1000000 -- one transfer cannot exceed this, as a blast radius on any bug
SocialConfig.BankMinTransfer = 1

-- Depositing and withdrawing happen at a banker NPC in the world, not from the stone: the stone is for
-- reaching people, and walking to a teller is what makes the bank a place. Transfers stay here, because
-- sending money to someone is exactly the kind of thing a communication device is for.

--------------------------------------------------------------------------------
-- Profile cards
--------------------------------------------------------------------------------

-- Showing your profile raises a card above your head that everyone nearby can see, so several people can
-- introduce themselves at once and each card is its own.
SocialConfig.CardRange = 60 -- studs; beyond this a card is not worth drawing
SocialConfig.CardMaxVisible = 8 -- cards drawn at once, nearest first, so a crowd cannot flood the screen
SocialConfig.CardSeconds = 10 -- a card takes itself down after this, so nobody leaves a sign up all session

--------------------------------------------------------------------------------
-- Ranks
--------------------------------------------------------------------------------

-- Rank is derived from level, never stored: one source of truth, and no migration when the bands move.
-- Ordered high to low so the first match wins.
SocialConfig.Ranks = {
	{ id = "S", minLevel = 90, color = Color3.fromRGB(232, 190, 84), glow = true },
	{ id = "A", minLevel = 70, color = Color3.fromRGB(228, 142, 68) },
	{ id = "B", minLevel = 55, color = Color3.fromRGB(168, 122, 220) },
	{ id = "C", minLevel = 40, color = Color3.fromRGB(96, 168, 232) },
	{ id = "D", minLevel = 25, color = Color3.fromRGB(104, 196, 118) },
	{ id = "E", minLevel = 10, color = Color3.fromRGB(154, 208, 140) },
	{ id = "F", minLevel = 1, color = Color3.fromRGB(158, 158, 168) },
}

function SocialConfig.RankFor(level)
	level = level or 1
	for _, rank in ipairs(SocialConfig.Ranks) do
		if level >= rank.minLevel then return rank end
	end
	return SocialConfig.Ranks[#SocialConfig.Ranks]
end

--------------------------------------------------------------------------------
-- The eight buttons on the stone
--------------------------------------------------------------------------------

-- `ready = false` draws the button but answers with a "not open yet" notice instead of a screen. The user
-- asked for these to exist now and work later; a dead button that does nothing reads as a frozen game.
SocialConfig.Screens = {
	{ id = "board", name = "บอร์ดกิลด์", glyph = "\240\159\147\156", ready = true },
	{ id = "friends", name = "รายชื่อสหาย", glyph = "\240\159\145\165", ready = true },
	{ id = "bank", name = "ธนาคาร", glyph = "\240\159\146\176", ready = true },
	{ id = "profile", name = "โปรไฟล์", glyph = "\240\159\145\164", ready = true },
	-- Opens the world map, which is its own screen rather than a page inside the stone: it wants the whole
	-- window, and M has to reach it without the stone being open.
	{ id = "map", name = "แผนที่", glyph = "\240\159\151\186", ready = true },
	{ id = "market", name = "ราคากลาง", glyph = "\226\154\150", ready = false,
		notice = "ตลาดกลางยังไม่เปิดใช้งาน" },
	{ id = "callGuard", name = "เรียกทหารยาม", glyph = "\240\159\155\161", ready = false,
		notice = "ปุ่มฉุกเฉินจะใช้ได้เมื่อระบบอาชีพเปิด" },
	{ id = "callPriest", name = "เรียกนักบวช", glyph = "\226\156\154", ready = false,
		notice = "ปุ่มฉุกเฉินจะใช้ได้เมื่อระบบอาชีพเปิด" },
	{ id = "callArchitect", name = "เรียกช่างสร้าง", glyph = "\240\159\148\168", ready = false,
		notice = "ปุ่มฉุกเฉินจะใช้ได้เมื่อระบบอาชีพเปิด" },
}

--------------------------------------------------------------------------------
-- The stone as a handset
--------------------------------------------------------------------------------

-- Wallpapers behind the icon grid. Gradients rather than images: no upload, and they cannot go missing the
-- way an asset can.
SocialConfig.Wallpapers = {
	{ id = "rune", name = "รูนสีคราม", from = Color3.fromRGB(26, 38, 54), to = Color3.fromRGB(12, 16, 22) },
	{ id = "ember", name = "ถ่านไฟ", from = Color3.fromRGB(54, 28, 22), to = Color3.fromRGB(16, 12, 12) },
	{ id = "moss", name = "มอสส์", from = Color3.fromRGB(26, 46, 34), to = Color3.fromRGB(12, 18, 14) },
	{ id = "dusk", name = "สนธยา", from = Color3.fromRGB(42, 30, 56), to = Color3.fromRGB(14, 12, 20) },
	{ id = "stone", name = "หินเปล่า", from = Color3.fromRGB(38, 41, 52), to = Color3.fromRGB(16, 17, 22) },
}

function SocialConfig.WallpaperFor(id)
	for _, w in ipairs(SocialConfig.Wallpapers) do
		if w.id == id then return w end
	end
	return SocialConfig.Wallpapers[1]
end

-- The battery is decoration -- there is no power system and a stone does not have a cell. It drains slowly
-- and refills on its own so the readout is never simply static, and never runs the player out of anything.
SocialConfig.BatteryDrainPerMinute = 0.4
SocialConfig.BatteryMin = 0.35

-- Voice is deliberately not a screen of its own: it lives inside the friends screen, on a conversation.
SocialConfig.VoiceNotice = "โทรจิตยังไม่เปิดใช้งาน — ต้องเปิดระบบเสียงของ Roblox และยืนยันอายุก่อน"

return SocialConfig
