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
	{ id = "market", name = "ราคากลาง", glyph = "\226\154\150", ready = false,
		notice = "ตลาดกลางยังไม่เปิดใช้งาน" },
	{ id = "callGuard", name = "เรียกทหารยาม", glyph = "\240\159\155\161", ready = false,
		notice = "ปุ่มฉุกเฉินจะใช้ได้เมื่อระบบอาชีพเปิด" },
	{ id = "callPriest", name = "เรียกนักบวช", glyph = "\226\156\154", ready = false,
		notice = "ปุ่มฉุกเฉินจะใช้ได้เมื่อระบบอาชีพเปิด" },
	{ id = "callArchitect", name = "เรียกช่างสร้าง", glyph = "\240\159\148\168", ready = false,
		notice = "ปุ่มฉุกเฉินจะใช้ได้เมื่อระบบอาชีพเปิด" },
}

-- Voice is deliberately not a screen of its own: it lives inside the friends screen, on a conversation.
SocialConfig.VoiceNotice = "โทรจิตยังไม่เปิดใช้งาน — ต้องเปิดระบบเสียงของ Roblox และยืนยันอายุก่อน"

return SocialConfig
