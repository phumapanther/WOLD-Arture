-- ClassConfig: the classes a player can hold, and what colour that paints their name.
--
-- Two tiers. A basic class is chosen at level 5 and an advanced one at level 50, so a character carries at
-- most one of each. Death resets the level to 1 (Progression already does this), which is what makes the
-- choice worth anything: you pick again on the way back up, and a class is a thing you can lose.
--
-- This file is vocabulary only -- names, colours, tiers. What each class can DO lives with the action that
-- does it, the same way RoleConfig kept the roles separate from the abilities.
local ClassConfig = {}

ClassConfig.BasicLevel = 5
ClassConfig.AdvancedLevel = 50
-- The level cap. A class here is the end of a whole climb, and dying takes it like any other -- which is
-- what stops "noble" being a permanent aristocracy.
ClassConfig.EliteLevel = 100

-- Keys are what is stored in the profile; `name` is what a player sees. `color` paints the nametag.
--
-- Most classes are plain white on purpose: a colour should mean something, so only the classes that carry
-- authority or a warning get one. The beggar is near-black, which reads as shabby rather than important.
ClassConfig.Classes = {
	--------------------------------------------------------------------------
	-- Basic, chosen at level 5.
	--------------------------------------------------------------------------
	-- The class everyone starts as, and returns to on death. Not "no class": a player with no class at all
	-- would have no actions and an empty nametag, and the difference between "has not chosen" and "chose to
	-- stay a villager" is not worth modelling.
	Villager = {
		name = "ชาวบ้าน", tier = "basic",
		color = Color3.fromRGB(255, 255, 255),
		blurb = "อุ้มเพื่อน",
	},
	Adventurer = {
		name = "นักผจญภัย", tier = "basic",
		color = Color3.fromRGB(255, 255, 255),
		blurb = "อุ้มเพื่อน ให้เงิน",
	},
	Rogue = {
		name = "โจร", tier = "basic",
		color = Color3.fromRGB(255, 255, 255),
		blurb = "ปล้น อุ้ม",
	},
	Beggar = {
		name = "ขอทาน", tier = "basic",
		color = Color3.fromRGB(50, 50, 50),
		blurb = "ขอเงิน ปล้น",
	},
	Merchant = {
		name = "พ่อค้า", tier = "basic",
		color = Color3.fromRGB(255, 255, 255),
		blurb = "แลกเปลี่ยนของ ให้เงิน",
	},

	--------------------------------------------------------------------------
	-- Advanced, chosen at level 50.
	--------------------------------------------------------------------------
	Guard = {
		name = "ทหารยาม", tier = "advanced",
		color = Color3.fromRGB(0, 120, 255),
		blurb = "จับกุม ยึดของ ปรับเงิน",
	},
	Priest = {
		name = "นักบวช", tier = "advanced",
		color = Color3.fromRGB(0, 220, 100),
		blurb = "ฮีล ชุบคนล้มได้ดีกว่า",
	},
	Architect = {
		name = "นักประดิษฐ์", tier = "advanced",
		color = Color3.fromRGB(255, 140, 0),
		blurb = "ซ่อมของทั้งตัว",
	},
	--------------------------------------------------------------------------
	-- Elite, chosen at level 100 -- the cap.
	--------------------------------------------------------------------------
	Noble = {
		name = "ขุนนาง", tier = "elite",
		color = Color3.fromRGB(255, 215, 0),
		blurb = "จับกุม ยึดของ ปรับเงิน สั่งการบ้านเมือง",
	},
	Chef = {
		name = "เชฟ", tier = "advanced",
		color = Color3.fromRGB(255, 120, 180),
		blurb = "แลกเปลี่ยนของ",
	},
}

--------------------------------------------------------------------------------
-- Passive perks
--------------------------------------------------------------------------------

-- The one standing benefit each class carries. Passive: true for as long as the class is held, with nothing
-- to press -- which is what separates these from ClassActionConfig, the menu of things a class can DO.
--
-- Kept in ClassConfig rather than on the server so the class card can show a player what they are choosing
-- BEFORE they choose it. ServerScriptService.ClassPerks reads the same table to decide what actually
-- happens, so the promise on the card and the behaviour in the game cannot drift apart.
--
-- The villager has none on purpose: it is the class you hold before choosing and return to on death, so an
-- empty row is a real answer rather than a gap.
ClassConfig.Perks = {
	Adventurer = { id = "doubleExp", name = "การเรียนรู้", blurb = "ได้ EXP สองเท่า" },
	Merchant = { id = "doubleHarvest", name = "ตาดีได้", blurb = "ได้ของจากการฟาร์มสองเท่า" },
	Rogue = { id = "doubleDamage", name = "การทำร้ายทุกสิ่งคือพร", blurb = "ทำดาเมจสองเท่า" },
	Guard = { id = "armorNeverBreaks", name = "ความเที่ยงธรรมเป็นเกราะ", blurb = "เกราะไม่พัง" },
	Priest = { id = "noStaminaDrain", name = "หมอไม่เหนื่อย", blurb = "สตามินาไม่ลด" },
	Chef = { id = "noHunger", name = "คนทำอาหารไม่หิวหรอกนะ", blurb = "ความหิวไม่ลด" },
	Architect = { id = "weaponNeverBreaks", name = "จะพังได้ไง ซ่อมได้ตลอด", blurb = "อาวุธไม่พัง" },
}

-- A failed robbery marks the thief for everyone to see. Not a class, a temporary state -- so it overrides
-- whatever colour the class would have painted, and expires on its own.
ClassConfig.MarkedColor = Color3.fromRGB(255, 0, 0)
ClassConfig.MarkedSeconds = 10 * 60

-- ราคาของหัวแดงแต่ละเหตุ ตามที่ผู้ใช้กำหนด
ClassConfig.MarkedSecondsQte = 3 * 60   -- ทำควิกไทม์อีเวนต์พลาด
ClassConfig.MarkedSecondsKill = 5 * 60  -- ฆ่าคนตาย

ClassConfig.DefaultColor = Color3.fromRGB(255, 255, 255)

-- What a player is before they have chosen anything, and what a death returns them to.
ClassConfig.DefaultClass = "Villager"

function ClassConfig.Exists(id)
	return ClassConfig.Classes[id] ~= nil
end

function ClassConfig.Get(id)
	return ClassConfig.Classes[id]
end

function ClassConfig.DisplayName(id)
	local class = ClassConfig.Classes[id]
	return class and class.name or id
end

function ClassConfig.ColorOf(id)
	local class = ClassConfig.Classes[id]
	return class and class.color or ClassConfig.DefaultColor
end

-- Every class of a tier, sorted so the selection card is in the same order every time rather than in
-- whatever order pairs() happens to walk the table.
function ClassConfig.OfTier(tier)
	local list = {}
	for id, class in pairs(ClassConfig.Classes) do
		if class.tier == tier then table.insert(list, id) end
	end
	table.sort(list)
	return list
end

-- The level a tier unlocks at, or nil for a tier that does not exist.
function ClassConfig.LevelFor(tier)
	if tier == "basic" then return ClassConfig.BasicLevel end
	if tier == "advanced" then return ClassConfig.AdvancedLevel end
	if tier == "elite" then return ClassConfig.EliteLevel end
	return nil
end

-- Which tier a level has just unlocked, or nil. Used on level-up to decide whether to offer a choice.
function ClassConfig.TierUnlockedAt(level)
	if level == ClassConfig.BasicLevel then return "basic" end
	if level == ClassConfig.AdvancedLevel then return "advanced" end
	if level == ClassConfig.EliteLevel then return "elite" end
	return nil
end

-- Matches a class by id, case-insensitively and by prefix, so "/role guard" and "/role gu" both work. Nil
-- when the text matches nothing, or is ambiguous between two classes.
function ClassConfig.Match(text)
	if not text or text == "" then return nil end
	text = text:lower()
	local hit
	for id in pairs(ClassConfig.Classes) do
		if id:lower() == text then return id end -- an exact name always wins over a prefix
		if id:lower():sub(1, #text) == text then
			if hit then return nil end -- ambiguous
			hit = id
		end
	end
	return hit
end

return ClassConfig
