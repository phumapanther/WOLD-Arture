-- EmoteConfig: the poses a player can strike, for roleplay rather than for fighting.
--
-- Shared by the picker (which draws it), the client controller (which plays it) and the admin /anim command
-- (which plays any of them by name). One list, so a pose added here appears in all three.
--
-- WHERE THE IDS COME FROM, and why several of them are not what a reference table would tell you:
--
-- Roblox ships a default animation set and NAMES it, on every character, in the Animate script -- each
-- named child holds the real Animation instance. Those names were read off a live character rather than
-- copied from a list, which matters: the list this system was first specified from had `wave` as
-- 507770238, an id that does not resolve at all (the real one ends 239), and had `point` labelled as a
-- gentleman's bow. Both would have shipped as buttons that did nothing, or did the wrong thing.
--
-- Anything Roblox does NOT ship -- sitting cross-legged, lying down, the wai, a bow, a curtsy -- is
-- authored in animgen/emotes.lua and published by hand, exactly like the combat and movement poses. Those
-- entries carry an empty id until that happens, which is safe: an emote with no id is simply not offered.
local EmoteConfig = {}

-- How long a one-shot pose is held before the character stands back up on its own. A looping pose (a sit, a
-- lie-down) ignores this and waits to be cancelled.
EmoteConfig.DefaultSeconds = 3

-- Moving cancels a pose. Measured against the humanoid's own speed rather than against key presses, so a
-- shove, a vehicle or a slope ends it too -- anything that means "you are no longer standing there posing".
EmoteConfig.CancelSpeed = 1.5

-- How far a `keep` pose may travel before it gives out, in studs.
--
-- A sit you can walk around in forever is a sit that never ends, and a player who forgot they pressed it
-- spends the rest of the session gliding about seated. Ten studs is a few paces -- enough to shuffle over
-- and sit somewhere better, not enough to go anywhere.
--
-- Counted as distance ACTUALLY WALKED, not as distance from where the pose started: pacing in a circle uses
-- it up just the same, which is the honest reading of "you got up and moved".
EmoteConfig.KeepDistance = 10

-- id      the name used by /anim and by the picker's button
-- label   what the button says
-- glyph   the emoji on the button
-- anim    the animation id, or "" for one that is authored but not yet published
-- loop    true = holds until cancelled; false = plays once and releases
-- locks   true = the player cannot walk while it runs (a bow being held mid-courtesy)
-- keep    true = the pose STAYS ON while the player walks. Without it a pose ends the moment they move,
--         which is right for a wave and wrong for sitting down -- the user asked to be able to sit, lie or
--         hover and still get about. The two flags are independent: `locks` is the server refusing to let
--         you move, `keep` is the pose surviving the fact that you did.
-- group   which tab of the picker it lands in
EmoteConfig.Emotes = {
	-- Roblox's own, verified by reading them off a live character's Animate script.
	{ id = "wave", label = "โบกมือ", glyph = "\240\159\145\139", anim = "rbxassetid://507770239",
		loop = false, locks = false, group = "greet" },
	{ id = "point", label = "ชี้", glyph = "\240\159\145\137", anim = "rbxassetid://507770453",
		loop = false, locks = false, group = "greet" },
	{ id = "cheer", label = "เชียร์", glyph = "\240\159\153\140", anim = "rbxassetid://507770677",
		loop = false, locks = false, group = "mood" },
	{ id = "laugh", label = "หัวเราะ", glyph = "\240\159\152\130", anim = "rbxassetid://507770818",
		loop = false, locks = false, group = "mood" },
	{ id = "dance", label = "เต้น 1", glyph = "\240\159\149\186", anim = "rbxassetid://507771019",
		loop = true, locks = false, group = "fun" },
	{ id = "dance2", label = "เต้น 2", glyph = "\240\159\149\186", anim = "rbxassetid://507776043",
		loop = true, locks = false, group = "fun" },
	{ id = "dance3", label = "เต้น 3", glyph = "\240\159\149\186", anim = "rbxassetid://507777268",
		loop = true, locks = false, group = "fun" },
	-- The stock sit. Roblox uses it for seats, and it holds a sitting pose perfectly well without one.
	{ id = "sit", label = "นั่งเก้าอี้", glyph = "\240\159\170\145", anim = "rbxassetid://2506281703",
		loop = true, locks = false, keep = true, group = "pose" },

	-- Roblox's own tool and combat animations, offered as things to show off with. Verified the same way as
	-- the emotes above -- played on a live R15 character and measured -- because most of the ids suggested
	-- alongside these turned out to be R6, which load perfectly and then move an R15 rig not at all.
	{ id = "ninjadash", label = "พุ่งนินจา", glyph = "\240\159\146\168", anim = "rbxassetid://13978512316",
		loop = false, locks = false, group = "show" },
	{ id = "slash", label = "ฟันดาบ", glyph = "\226\154\148", anim = "rbxassetid://12520999032",
		loop = false, locks = false, group = "show" },
	{ id = "lunge", label = "พุ่งแทง", glyph = "\240\159\151\161", anim = "rbxassetid://12521002003",
		loop = false, locks = false, group = "show" },
	{ id = "toolhold", label = "ท่าถืออาวุธ", glyph = "\240\159\155\161", anim = "rbxassetid://12520996634",
		loop = true, locks = false, group = "show" },

	-- Authored here: animgen/emotes.lua. Empty until published -- see the note at the top.
	{ id = "wai", label = "ไหว้", glyph = "\240\159\153\143", anim = "rbxassetid://118533343931134",
		loop = false, locks = true, group = "greet" },
	{ id = "bow", label = "โค้งคำนับ", glyph = "\240\159\164\181", anim = "rbxassetid://95117886203171",
		loop = false, locks = true, group = "greet" },
	-- The R6 conversion of the bow, published alongside the hand-authored one. Its own entry rather than
	-- a replacement, the same arrangement as scared2: which reads better is a question for the eye, and
	-- both being on the menu is how it gets answered.
	{ id = "bow2", label = "โค้งคำนับ (R6)", glyph = "\240\159\153\135", anim = "rbxassetid://135741248709600",
		loop = false, locks = true, group = "greet" },
	{ id = "curtsy", label = "คำนับสตรี", glyph = "\240\159\146\131", anim = "rbxassetid://114131409028241",
		loop = false, locks = true, group = "greet" },
	{ id = "crosslegged", label = "นั่งขัดสมาธิ", glyph = "\240\159\167\152", anim = "rbxassetid://72136175089840",
		loop = true, locks = false, keep = true, group = "pose" },
	{ id = "squat", label = "นั่งยอง", glyph = "\240\159\166\134", anim = "rbxassetid://100180068709198",
		loop = true, locks = false, keep = true, group = "pose" },
	-- The R6 crouch, offered next to the authored squat for the same reason.
	{ id = "squat2", label = "นั่งยอง (R6)", glyph = "\240\159\167\141", anim = "rbxassetid://136050444891628",
		loop = true, locks = false, keep = true, group = "pose" },
	{ id = "layflat", label = "นอนราบ", glyph = "\240\159\155\140", anim = "rbxassetid://132277217203777",
		loop = true, locks = false, keep = true, group = "pose" },
	{ id = "scared", label = "ตกใจกลัว", glyph = "\240\159\152\168", anim = "rbxassetid://107875525687391",
		loop = true, locks = false, group = "mood" },

	-- Converted from R6 by animgen/r6convert.lua, and waiting on an upload like the authored ones.
	--
	-- These are the poses that exist as free R6 animations and have no R15 equivalent at all -- there was no
	-- point authoring a moonwalk by hand when one already exists and can be rebuilt onto R15 joints in a
	-- second. Conv_Bow, Conv_Scared and Conv_Crouch were converted too but are NOT listed here: the hand
	-- authored Emote_Bow, Emote_Scared and Emote_Squat already fill those rows, and the converted pair are
	-- there to be compared against them by eye before one is chosen.
	-- The R6 conversion of the same pose, published alongside the hand-authored one. Kept as its own
	-- entry rather than replacing it: which of the two reads better is a question to answer by looking,
	-- and that is easier with both on the menu. Delete whichever loses.
	{ id = "scared2", label = "ตกใจ (R6)", glyph = "\240\159\152\168", anim = "rbxassetid://95047205131830",
		loop = true, locks = false, group = "mood" },
	{ id = "faint", label = "เป็นลม", glyph = "\240\159\152\181", anim = "rbxassetid://119907926426177",
		loop = false, locks = true, group = "mood" },
	{ id = "floorfaint", label = "สลบกับพื้น", glyph = "\240\159\146\128", anim = "rbxassetid://98136194257359",
		loop = false, locks = true, group = "mood" },
	{ id = "spindance", label = "เต้นหมุนตัว", glyph = "\240\159\140\128", anim = "rbxassetid://90655501344602",
		loop = true, locks = false, group = "fun" },
	{ id = "moondance", label = "มูนวอล์ก", glyph = "\240\159\140\153", anim = "rbxassetid://77441901680604",
		loop = true, locks = false, group = "fun" },
	{ id = "floatsit", label = "นั่งลอย", glyph = "\240\159\170\132", anim = "rbxassetid://75719474074286",
		loop = true, locks = false, keep = true, group = "pose" },
	{ id = "levitate", label = "ลอยตัว", glyph = "\226\156\168", anim = "rbxassetid://113438981831194",
		loop = true, locks = false, keep = true, group = "pose" },
	-- นั่งเหยียดขา: the comfortable sit the user asked for, authored in animgen/emotes.lua. Roblox has no
	-- stock pose for it and the R6 "float sit" is a different thing entirely -- that one hovers.
	{ id = "sitlegsout", label = "นั่งเหยียดขา", glyph = "\240\159\167\142", anim = "rbxassetid://76700044719184",
		loop = true, locks = false, keep = true, group = "pose" },
	{ id = "floorcrawl", label = "หมอบคลาน", glyph = "\240\159\166\142", anim = "rbxassetid://94687957009207",
		loop = true, locks = false, keep = true, group = "pose" },
}

EmoteConfig.Groups = {
	{ id = "greet", name = "ทักทาย · มารยาท" },
	{ id = "mood", name = "อารมณ์" },
	{ id = "pose", name = "ท่านั่ง · ท่านอน" },
	{ id = "fun", name = "เต้น · สังคม" },
	{ id = "show", name = "ท่าโชว์ · อาวุธ" },
}

function EmoteConfig.Get(id)
	for _, e in ipairs(EmoteConfig.Emotes) do
		if e.id == id then return e end
	end
	return nil
end

-- Only the ones that can actually play. The picker draws from this so an unpublished pose is not offered as
-- a button that does nothing -- the lesson the "not open yet" buttons on the speaking stone already taught.
function EmoteConfig.Available(group)
	local out = {}
	for _, e in ipairs(EmoteConfig.Emotes) do
		if e.anim ~= "" and (group == nil or e.group == group) then table.insert(out, e) end
	end
	return out
end

-- Every id, published or not, for the admin command: an admin testing a pose needs to be able to name one
-- that is still waiting on an upload and be told so.
function EmoteConfig.Names()
	local out = {}
	for _, e in ipairs(EmoteConfig.Emotes) do table.insert(out, e.id) end
	return out
end

return EmoteConfig
