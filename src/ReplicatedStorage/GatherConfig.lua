-- GatherConfig: what each kind of gathering node gives, how long it takes, and how long it stays spent.
--
-- Nodes are found by TAG, not by name or position: anything tagged WOLD_Node with a NodeKind attribute is a
-- node, wherever it came from. That is what lets the user drop trees and rocks into the map by hand -- or a
-- mapgen phase scatter a thousand of them -- without either side knowing about the other.
local GatherConfig = {}

-- One minute, shared by every node, as the user asked: a node someone else has just taken is spent for
-- everyone until it comes back. Server-wide rather than per-player on purpose -- if each player saw their
-- own trees there would be no reason to walk anywhere, and no reason for a second player to matter.
GatherConfig.RespawnSeconds = 60

-- How close you have to be. Slightly generous, because the prompt is attached to a tree trunk while the
-- model's branches read as "the tree" and players aim at those.
GatherConfig.Range = 10

-- ท่าเก็บของแยกตามชนิดวัตถุดิบ ตามคู่มือภาพของผู้ใช้ (animgen/gather.lua สร้าง สี่ท่านี้ไว้ที่
-- ServerStorage.WOLD_Animations) id ว่าง = ใช้ท่าฟันดาบเดิม ระบบทำงานต่อได้ปกติ
-- ใส่ id หลัง publish (Save to Roblox จากบัญชีเจ้าของเพลส) เป็น "rbxassetid://<เลข>"
GatherConfig.Animations = {
	animal = "rbxassetid://133758220989412", -- Gather_Animal นั่งยองเชือด
	stone = "rbxassetid://92286440480879",   -- Gather_Stone  เหวี่ยงอีเต้อข้ามหัว
	-- ตัดไม้: ผู้ใช้ดู Gather_Wood แล้วบอกว่าแปลก ขอใช้ท่าฟันดาบเดิม (ว่าง = fallback Sword_Slash)
	wood = "",
	bush = "rbxassetid://109356036263400",   -- Gather_Bush   ก้มเก็บ
}

-- จุดชนิดนี้ใช้ท่าไหน: ระบุ `anim` ในคอนฟิกจุดได้ ไม่ระบุก็อนุมานจากเครื่องมือ (ขวาน→wood อีเต้อ→stone
-- พลั่ว→bush) จุดที่ไม่ใช้เครื่องมือถือเป็นการเก็บด้วยมือ (bush) ยกเว้นสัตว์ซึ่งระบุ anim = "animal" ไว้
local TOOL_ANIM = { axe = "wood", pickaxe = "stone", shovel = "bush" }
function GatherConfig.AnimationFor(kind)
	local node = GatherConfig.Nodes[kind]
	if not node then return nil end
	local category = node.anim or TOOL_ANIM[node.tool] or "bush"
	local id = GatherConfig.Animations[category]
	return (id ~= nil and id ~= "") and id or nil, category
end

-- Gathering sounds are POSITIONAL: they belong to the tree being chopped, not to the player chopping it,
-- so everyone nearby hears where the work is happening.
--
-- Each strike is one hit, played on a repeat for the length of the hold rather than one long clip -- a
-- single sound stretched over a 2.5-second chop reads as one thud and a lot of silence.
GatherConfig.HitVolume = 0.35
GatherConfig.HitDistance = 55
GatherConfig.HitInterval = 0.55 -- seconds between strikes while holding

GatherConfig.Nodes = {
	Tree = {
		item = "WoodScrap", min = 2, max = 4,
		-- บางทีก็ได้แอปเปิลแทนไม้ — ของแถมระหว่างทำอย่างอื่น ไม่ใช่เหตุผลที่จะไปตัดไม้
		--
		-- 20% ต่ำพอที่การตัดไม้ยังเป็นการหาไม้อยู่ แต่สูงพอให้คนที่ตัดไปสิบต้นได้กินสองลูก
		alt = { item = "Apple", min = 1, max = 2, chance = 0.20 },
		seconds = 2.5,
		xp = 5,
		-- An axe, and nothing else. This is what makes the three tools worth buying rather than ornaments,
		-- and it means a new player's first goal is a specific purchase rather than a vague one.
		--
		-- The starting gold has to cover the cheapest tool or a new player is stuck with no way to earn --
		-- see the note on Shop prices. Killing slimes needs no tool at all, which is the way out if it ever
		-- goes wrong.
		tool = "axe",
		sound = "rbxassetid://106037813922366", -- assets/sounds/hit_wood
		prompt = "เก็บไม้",
		object = "ต้นไม้",
	},
	Rock = {
		item = "Stone", min = 1, max = 3,
		seconds = 3.0,
		xp = 6,
		tool = "pickaxe",
		sound = "rbxassetid://120916604676149", -- assets/sounds/hit_rock
		prompt = "ทุบหิน",
		object = "ก้อนหิน",
	},
	-- Defined now so the ore and herb nodes the caves already contain light up the moment they are tagged.
	-- Nothing scatters these yet.
	IronOre = {
		item = "IronOre", min = 1, max = 3,
		seconds = 3.5, xp = 8, tool = "pickaxe",
		sound = "rbxassetid://120916604676149", -- stone on stone
		prompt = "ขุดแร่", object = "สายแร่เหล็ก",
	},
	Crystal = {
		item = "Crystal", min = 1, max = 1,
		seconds = 5.0, xp = 25, tool = "pickaxe",
		sound = "rbxassetid://120916604676149",
		prompt = "ขุดคริสตัล", object = "คริสตัล",
	},
	-- Coal, mined the same way iron is. The vehicles burn it and the forge takes it, so it is the one ore a
	-- player comes back for after they have all the gear they want.
	Coal = {
		item = "Coal", min = 1, max = 3,
		seconds = 3.5, xp = 8, tool = "pickaxe",
		sound = "rbxassetid://120916604676149",
		prompt = "ขุดถ่านหิน", object = "ถ่านหิน",
	},
	Herb = {
		item = "Herb", min = 1, max = 2,
		-- A shovel, per the user. Digging a root out is a shovel's job even though picking a leaf is not.
		seconds = 1.5, xp = 4, tool = "shovel",
		prompt = "เก็บสมุนไพร", object = "สมุนไพร",
	},

	--------------------------------------------------------------------------
	-- แร่หายาก 4 ชนิด (โมเดล Ore_* ที่วางไว้ในแมพแล้ว)
	--
	-- ใช้อีเต้อเหมือนแร่เดิมทุกตัว และยิ่งหายากยิ่งขุดนาน — เวลาขุดคือราคาที่จ่ายจริง ไม่ใช่แค่ตัวเลข
	-- ในตาราง เพชรใช้ 8 วินาที ซึ่งนานพอที่จะโดนมอนมาตีระหว่างขุดได้
	--------------------------------------------------------------------------
	MagicOre = {
		item = "MagicOre", min = 1, max = 2,
		seconds = 6.0, xp = 30, tool = "pickaxe",
		sound = "rbxassetid://120916604676149",
		prompt = "ขุดแร่เวทมนตร์", object = "สายแร่เวทมนตร์",
	},
	SilverOre = {
		item = "SilverOre", min = 1, max = 3,
		seconds = 4.0, xp = 12, tool = "pickaxe",
		sound = "rbxassetid://120916604676149",
		prompt = "ขุดแร่เงิน", object = "สายแร่เงิน",
	},
	GoldOre = {
		item = "GoldOre", min = 1, max = 2,
		seconds = 5.5, xp = 22, tool = "pickaxe",
		sound = "rbxassetid://120916604676149",
		prompt = "ขุดแร่ทอง", object = "สายแร่ทอง",
	},
	DiamondOre = {
		item = "Diamond", min = 1, max = 1,
		seconds = 8.0, xp = 45, tool = "pickaxe",
		sound = "rbxassetid://120916604676149",
		prompt = "ขุดเพชร", object = "สายแร่เพชร",
	},

	--------------------------------------------------------------------------
	-- ไร่นา (โมเดล Farm_* ที่วางไว้ในแมพแล้ว)
	--
	-- **ไม่ต้องใช้อุปกรณ์** ต่างจากการฟาร์มไม้/หิน/แร่ทั้งหมด — เก็บผักกับเกี่ยวข้าวด้วยมือเปล่าได้
	-- ซึ่งทำให้ไร่นาเป็นทางหาของทางแรกของคนที่ยังไม่มีเงินซื้ออุปกรณ์เลย เหมือนที่ฟาร์มผิดกฎหมายเป็น
	--------------------------------------------------------------------------
	CropField = {
		-- ผักรวม หรือหนอน (เหยื่อตกปลา) ตามที่ผู้ใช้กำหนด — `alt` คือของอีกอย่างที่สุ่มได้แทน
		item = "Vegetable", min = 1, max = 3,
		alt = { item = "Worm", min = 1, max = 3, chance = 0.35 },
		seconds = 2.0, xp = 5,
		prompt = "เก็บผัก", object = "แปลงผัก",
	},
	WheatField = {
		item = "Wheat", min = 2, max = 4,
		seconds = 2.0, xp = 5,
		prompt = "เกี่ยวข้าว", object = "นาข้าว",
	},
	--------------------------------------------------------------------------
	-- สัตว์เลี้ยง 8 ชนิด — กด E เอาของ ไม่ต้องฆ่า ไม่ต้องใช้อุปกรณ์
	--
	-- **สัตว์ไม่ตายและไม่จางหาย** ต่างจากก้อนแร่ที่ถูกขุดไปแล้ว วัวที่รีดนมแล้วก็ยังเป็นวัวที่ยืนอยู่ตรงนั้น
	-- แค่รีดซ้ำไม่ได้ชั่วคราว — สปอว์เนอร์ตั้ง NoFade ไว้ให้ ปุ่ม E ที่ดับไปคือสัญญาณเดียวที่ต้องการ
	--
	-- ของที่ได้ซ้ำกันหลายตัวโดยตั้งใจ (ไก่กับเป็ดได้ไข่ · วัวกับแพะได้นม · กวางกับม้าได้หนัง) ตามที่
	-- ผู้ใช้กำหนด — ต่างกันที่หาเจอที่ไหนและเดินไปถึงยากแค่ไหน ไม่ใช่ที่ของ
	--------------------------------------------------------------------------
	Chicken = {
		anim = "animal",
		item = "Egg", min = 1, max = 2,
		seconds = 1.5, xp = 3,
		prompt = "เก็บไข่", object = "ไก่",
	},
	Duck = {
		anim = "animal",
		item = "Egg", min = 1, max = 2,
		seconds = 1.5, xp = 3,
		prompt = "เก็บไข่", object = "เป็ด",
	},
	Cow = {
		anim = "animal",
		item = "Milk", min = 1, max = 2,
		seconds = 2.5, xp = 5,
		prompt = "รีดนม", object = "วัว",
	},
	Goat = {
		anim = "animal",
		item = "Milk", min = 1, max = 1,
		seconds = 2.0, xp = 4,
		prompt = "รีดนม", object = "แพะ",
	},
	Sheep = {
		anim = "animal",
		item = "Wool", min = 1, max = 2,
		seconds = 3.0, xp = 6,
		prompt = "ตัดขนแกะ", object = "แกะ",
	},
	Deer = {
		anim = "animal",
		item = "Leather", min = 1, max = 2,
		seconds = 3.0, xp = 8,
		prompt = "เก็บหนัง", object = "กวาง",
	},
	Horse = {
		anim = "animal",
		item = "Leather", min = 1, max = 1,
		seconds = 3.0, xp = 8,
		prompt = "เก็บหนัง", object = "ม้า",
	},
	Pig = {
		anim = "animal",
		item = "Meat", min = 1, max = 2,
		seconds = 2.5, xp = 5,
		prompt = "เก็บเนื้อ", object = "หมู",
	},

	EtherCluster = {
		-- กิ่งเวทมนตร์ หายากกว่าอีกสองอย่างในไร่นา จึงนานกว่าและให้ XP มากกว่า
		item = "MagicBranch", min = 1, max = 2,
		seconds = 4.0, xp = 18,
		prompt = "เก็บกิ่งเวท", object = "พุ่มไม้เวทมนตร์",
	},
}

--------------------------------------------------------------------------------
-- ของแถมจากการเก็บเกี่ยว — `bonus` (ผู้ใช้กำหนด 2026-09-19)
--
-- `bonus` = ของที่ได้ **เพิ่ม** จากของหลัก ต่างจาก `alt` ที่ได้ **แทน** ของหลัก (แปลงผัก: ผักหรือหนอน
-- อย่างใดอย่างหนึ่ง) การเก็บเกี่ยวบางอย่างไม่ใช่การเลือกว่าจะได้อะไร แต่เป็นการรื้อของชิ้นหนึ่งแล้วเจอ
-- อีกชิ้นติดมือมาด้วย — ตีสายแร่ก็ได้เศษหินที่หุ้มมัน ขุดดินหาสมุนไพรก็เจอหนอนในดิน
--------------------------------------------------------------------------------

-- ขุดแร่แล้วได้เศษหิน · 35% × 1-2 ก้อน
--
-- หินเป็นวัตถุดิบคราฟที่หาง่ายอยู่แล้ว ตัวเลขนี้จึงเป็น "ของแถมที่รู้สึกได้" ไม่ใช่เหตุผลให้ไปขุดเพชร
-- เพื่อเอาหิน — คนอยากได้หินยังทุบก้อนหิน (1-3 ก้อน ทุกครั้ง 3 วิ) เร็วกว่าเสมอ
--
-- ติดให้เองทุกจุดที่ "ขุดด้วยอีเต้อและของหลักไม่ใช่หินอยู่แล้ว" แทนการไล่พิมพ์ทีละแร่ — แร่ใหม่ที่เพิ่ม
-- ทีหลังจึงได้กฎนี้ไปด้วยวันที่มันเกิด ไม่มีทางลืม (ก้อนหินธรรมดาหลุดออกไปเองเพราะของหลักมันคือหิน)
GatherConfig.OreStoneBonus = { item = "Stone", min = 1, max = 2, chance = 0.35 }

do
	for _, node in pairs(GatherConfig.Nodes) do
		if node.tool == "pickaxe" and node.item ~= GatherConfig.OreStoneBonus.item and node.bonus == nil then
			node.bonus = GatherConfig.OreStoneBonus
		end
	end
end

-- ขุดสมุนไพรกับเกี่ยวข้าวแล้วเจอหนอน · 30% × 1-2 ตัว
--
-- เหยื่อตกปลาที่เดิมมีทางได้แค่ซื้อจากบาร์นาบีกับแปลงผัก ทั้งสองอย่างนี้คือการรื้อดินและรื้อกอ ซึ่งเป็นที่ที่
-- หนอนอยู่ คนอยากตกปลาจึงหาเหยื่อเองได้ระหว่างทำอย่างอื่น ไม่ต้องเดินกลับเข้าเมืองรอบสอง — และหนอน
-- ราคา 20 เหรียญ การได้ติดมือจึงไม่กระทบเศรษฐกิจอะไร
--
-- เขียนตรงๆ สองบรรทัดแทนการวนลูปแบบแร่ เพราะนี่ไม่ใช่กฎที่อนุมานจากอะไรได้: จุดที่ "เก็บด้วยพลั่ว"
-- ยังมีพุ่มไม้ที่ไม่ควรมีหนอน และข้าวก็ไม่ได้ใช้เครื่องมือเลย มันคือสองจุดที่เลือกมา ไม่ใช่หมวดหนึ่ง
--
-- **แปลงผักไม่ถูกแตะ** มันใช้ `alt` อยู่แล้ว (ผักหรือหนอน อย่างใดอย่างหนึ่ง 35% ตามที่ผู้ใช้กำหนดไว้เดิม)
-- ถ้ามาใส่ `bonus` ทับ แปลงผักจะกลายเป็นจุดที่ได้หนอนสองทางในครั้งเดียว ซึ่งไม่ใช่ที่สั่ง
GatherConfig.WormBonus = { item = "Worm", min = 1, max = 2, chance = 0.30 }
GatherConfig.Nodes.Herb.bonus = GatherConfig.WormBonus
GatherConfig.Nodes.WheatField.bonus = GatherConfig.WormBonus

--------------------------------------------------------------------------------
-- Monsters
--------------------------------------------------------------------------------

GatherConfig.MobHitVolume = 0.4
GatherConfig.MobDieVolume = 0.5
GatherConfig.MobSoundDistance = 60

GatherConfig.Mobs = {
	GreenSlime = {
		name = "สไลม์เขียว",
		hp = 40,
		damage = 6,
		attackCooldown = 1.6,
		attackRange = 6,
		-- How far it notices a player, and how far it will chase before giving up and going home. Chasing
		-- forever would drag every slime in the field into town behind the first player who walked past.
		aggroRange = 26,
		leashRange = 70,
		walkSpeed = 7, -- slower than a walking player (8), so running away always works
		-- โอกาสหลบการโจมตีหนึ่งครั้ง 0 หรือไม่ใส่ = ไม่หลบเลย
		--
		-- สไลม์ตั้งไว้ต่ำตามที่ prompt ระบุ ("DodgeChance ต่ำ") — มันเป็นก้อนเจลลี่ ไม่ใช่นักดาบ
		dodgeChance = 0.08,
		drops = { { item = "Slime", min = 1, max = 2 } },
		xp = 10,
		respawnSeconds = 30,
		colour = Color3.fromRGB(96, 200, 104),
		-- Struck, and killed. Both play at the monster rather than at whoever hit it, so a fight sounds
		-- like it is happening where it is.
		hitSound = "rbxassetid://127637727363472", -- assets/sounds/hit_slime
		dieSound = "rbxassetid://96214777896458",  -- assets/sounds/die_slime
	},
}

--------------------------------------------------------------------------------
-- The special slimes
--------------------------------------------------------------------------------

-- Every weapon a special slime can drop, EXCEPT the pistol.
--
-- The pistol is left out deliberately: it knocks a player down for five seconds, which is the strongest
-- thing anyone can do to someone else in this game, and it should be bought or earned rather than handed
-- out by a monster. Everything else in the catalog's weapon kind is here, tools included -- an axe from a
-- slime is a perfectly good axe.
--
-- Listed by ID rather than derived from ItemCatalog.kind so that adding a weapon tomorrow does not put it
-- in a monster's drop table by accident. A drop table is a design decision, not a consequence.
GatherConfig.WeaponDrops = {
	"Sword", "Bow", "Staff", "Spellbook", "Axe", "Pickaxe", "Shovel", "FishingRod",
}

-- How often a named slime gives up each of its drops. The user set these four numbers directly.
--
-- They are CHANCES, and the amounts stay what they always were -- two to four lumps of goo, one to three
-- iron, one to two crystal. The order is what each is worth to someone trying to craft: goo most often,
-- then iron, then crystal, with the weapon the thing you actually hope for.
GatherConfig.SpecialSlimeChance = 0.70
GatherConfig.SpecialOreChance = 0.15
GatherConfig.SpecialCrystalChance = 0.10
GatherConfig.SpecialWeaponChance = 0.05

--------------------------------------------------------------------------------
-- บอสประจำโลก (2026-09-20) — ตัวแรก: ฟอร์จวอร์เดน ผู้พิทักษ์เตาหลอม
--
-- โมเดลปั้นที่โรงงาน `WOLD-Models/models/boss.lua` → ต้นแบบเข้าเพลสด้วย `mapgen/82_boss_prototype.lua`
-- (`ServerStorage.Model_moster.Boss_Forgewarden`) · **ตัวโมเดลสูง 10 studs แต่เกิดจริงที่สเกล 2.6
-- = สูง ~27 studs** ซึ่งเป็นความสูงระดับบอสโซลไลก์เทียบกับผู้เล่นที่สูง 5
--
-- ตัวเลขชุดนี้ตั้งให้ **สู้กันได้จริงหลายนาที ไม่ใช่ฟันสามทีตาย**: เลือดหลักหมื่น ดาเมจต่อครั้งเท่าโกเลมสามตัว
-- แต่ตีช้าและช่วงเอื้อมไกล — จังหวะหลบคือสิ่งที่ตัดสิน ไม่ใช่ใครตีเร็วกว่า
GatherConfig.Mobs.Forgewarden = {
	name = "ฟอร์จวอร์เดน ผู้พิทักษ์เตาหลอม",
	model = "Boss_Forgewarden",
	boss = true,              -- ธงที่ `BossBrain` ใช้ตัดสินว่าจะเข้าควบคุมตัวนี้แทน AI มอนธรรมดา
	-- **ใหญ่ขึ้นอีก 50% ตามที่ผู้ใช้สั่ง 2026-09-20** (2.6 -> 3.9) = สูงราว 40 studs เทียบกับผู้เล่นสูง 5
	scale = 3.9,              -- สเกลตอนเกิด (ระบบบอสของ Mobs.server คูณให้)
	-- ตีให้โดนง่ายขึ้นอีก 50% (ผู้ใช้สั่งพร้อมกัน) — ไม่ได้ขยายตัวที่ชนได้จริง แต่ขยาย "กล่องที่นับว่าฟันโดน"
	-- ดูเหตุผลเต็มที่ `applyHitPad` ใน `Mobs.server` · ค่าคิดเป็นสัดส่วนของครึ่งความกว้างตัว จึงโตตามสเกลเอง
	hitPadFraction = 0.5,
	hp = 12000,
	damage = 70,
	attackCooldown = 3.2,     -- ช้ากว่ามอนทุกตัวในเกม เพราะทุกไม้มีจังหวะง้างให้หลบ
	-- ระยะเอื้อมโตตามตัวด้วย (26 -> 39 = คูณ 1.5 เท่ากับที่ตัวใหญ่ขึ้น) ไม่งั้นบอสสูง 40 studs จะยืนจ่อหน้า
	-- ผู้เล่นแล้วฟันไม่ถึง เพราะระยะวัดจากใจกลางตัวมันซึ่งตอนนี้อยู่ไกลกว่าเดิมครึ่งเท่า
	attackRange = 39,         -- เอื้อมไกลตามขนาดตัว (วัดหลังสเกลแล้ว)
	aggroRange = 120,
	leashRange = 260,
	walkSpeed = 10,           -- เดินช้าแต่ก้าวยาว · เฟสสองเร็วขึ้นเอง (ดู BossConfig)
	dodgeChance = 0,          -- บอสไม่หลบ มันยืนรับ — สิ่งที่กันมันล้มคือ Poise ไม่ใช่การหลบ
	xp = 900,
	-- **ตัวเลขนี้ไม่ได้เป็นคนตัดสินว่าบอสจะกลับมาเมื่อไหร่แล้ว** (ผู้ใช้กำหนด 2026-09-20: เป็นบอสเวิลด์)
	-- บอสตัวนี้ผูกกับอีเวนต์ `worldboss` ซึ่งตื่นสองทุ่มเวลาไทยและอยู่ 59 นาที — ตายเมื่อไหร่อีเวนต์จบทันที
	-- และหมุดของมันถูกล้างนาฬิกาทุกครั้งที่อีเวนต์เริ่ม · เหลือไว้เป็นตาข่ายกันพลาด เผื่อวันหนึ่งมีใครเอา
	-- ฟอร์จวอร์เดนไปใส่หมุดธรรมดาที่ไม่มี EventOnly
	respawnSeconds = 30 * 60,
	colour = Color3.fromRGB(70, 74, 88),
	hitSound = "rbxassetid://120916604676149",  -- เหล็กกระทบหิน ไม่ใช่เสียงเนื้อ
	dieSound = "rbxassetid://96214777896458",
	drops = {
		{ item = "Silver", min = 400, max = 900 },
		{ item = "GearSpare", min = 6, max = 12 },
		{ item = "Blueprint", min = 2, max = 4 },
		{ item = "RuneStone", min = 3, max = 6, chance = 0.8 },
		{ item = "Chest_Gold", min = 1, max = 1 },
		{ oneOf = GatherConfig.WeaponDrops, min = 1, max = 1, chance = 0.35 },
	},
}

-- Three named slimes, tougher than the green one and worth hunting. They share the green slime's sounds
-- and its shape; what makes them different is that they hit harder, take longer to come back, and can
-- drop a weapon.
--
-- Each also drops its own material every time, so a kill is never wasted even when the weapon roll fails.
local function special(name, colour, extra)
	local base = {
		name = name,
		-- The model to build this monster FROM.
		--
		-- Mobs.server used to sculpt a translucent ball with two eyes for every monster, which was fine as
		-- a placeholder and wrong now that the user has modelled these. Naming the model here means the
		-- kit's own slime is what walks around, and Mobs.server falls back to the ball only if the model
		-- cannot be found.
		model = nil,
		-- Roughly three times what it was (90). As an event boss three of them land at once, for half an
		-- hour, in a server of at least ten people -- at ninety a named slime died to two players before the
		-- rest of the town could walk over, which made the announcement pointless.
		hp = 280,
		damage = 11,
		attackCooldown = 1.5,
		attackRange = 6,
		aggroRange = 30,
		leashRange = 80,
		walkSpeed = 7,   -- still slower than a walking player, so running away always works
		xp = 40,
		-- Half an hour. A named slime is a thing you go looking for, not something you farm in a circle --
		-- at the green slime's 30 seconds a player could stand in one spot and empty the weapon table.
		respawnSeconds = 30 * 60,
		colour = colour,
		hitSound = "rbxassetid://127637727363472",
		dieSound = "rbxassetid://96214777896458",
		-- The wet slap of a huge slime landing, played at the monster while it is chasing someone. It is how
		-- you hear one coming before you see it, which matters for a thing this size.
		hopSound = "rbxassetid://75878881956542", -- assets/sounds/boings
		hopInterval = 1.5,
		hopVolume = 0.35,
		-- How hard it leaves the ground on each of those beats. A slime moves BY hopping, so this is its
		-- gait, not a trick -- turn it down for a heavier lollop, up for something frantic.
		hopPower = 28,
		drops = {
			{ item = "Slime", min = 2, max = 4, chance = GatherConfig.SpecialSlimeChance },
			{ item = "IronOre", min = 1, max = 3, chance = GatherConfig.SpecialOreChance },
			{ item = "Crystal", min = 1, max = 2, chance = GatherConfig.SpecialCrystalChance },
			-- One roll, one weapon out of the eight. Without oneOf this would drop all of them at once.
			{ oneOf = GatherConfig.WeaponDrops, min = 1, max = 1,
				chance = GatherConfig.SpecialWeaponChance },
		},
	}
	for k, v in pairs(extra or {}) do base[k] = v end
	return base
end

-- Boilie: the steam slime. Slowest and toughest of the three.
GatherConfig.Mobs.SteamSlime = special("บอยลี่ สไลม์ไอน้ำ", Color3.fromRGB(255, 160, 50),
	{ hp = 340, damage = 13, walkSpeed = 6, model = "Monster_SteamSlime" })

-- Volt: the plasma slime. Quick and hits fast, but softer.
GatherConfig.Mobs.PlasmaSlime = special("โวลต์ สไลม์พลาสมา", Color3.fromRGB(0, 230, 255),
	{ hp = 240, damage = 10, attackCooldown = 1.1, walkSpeed = 7.5, aggroRange = 36,
		model = "Monster_PlasmaSlime" })

-- Gunk: the bio slime. Middling, but chases furthest.
GatherConfig.Mobs.BioSlime = special("กังก์ สไลม์กรดชีวะ", Color3.fromRGB(100, 255, 80),
	{ leashRange = 110, model = "Monster_BioSlime" })

--------------------------------------------------------------------------------
-- The spider and the skeleton
--------------------------------------------------------------------------------

-- Built from the user's own models rather than from the placeholder ball, and deliberately NOT given the
-- weapon table: these are ordinary monsters that live in numbers around the spot where their model stands,
-- where a named slime is one rare thing in one place.
GatherConfig.Mobs.Spider = {
	name = "แมงมุมยักษ์",
	model = "Monster_Spider",
	hp = 55,
	damage = 8,
	attackCooldown = 1.2,
	attackRange = 7,
	-- Sees further and chases harder than a slime, which is what makes a spider a spider.
	aggroRange = 40,
	leashRange = 95,
	-- Faster than a walking player but slower than a running one, so it is a threat you outrun rather than
	-- out-walk.
	walkSpeed = 11,
	xp = 20,
	respawnSeconds = 90,
	colour = Color3.fromRGB(70, 50, 60),
	hitSound = "rbxassetid://127637727363472",
	dieSound = "rbxassetid://96214777896458",
	drops = {
		{ item = "Fiber", min = 1, max = 3 },
		{ item = "Bone", min = 1, max = 2, chance = 0.4 },
	},
}

GatherConfig.Mobs.Skeleton = {
	name = "โครงกระดูก",
	model = "Monster_Skeleton",
	hp = 70,
	damage = 12,
	attackCooldown = 1.6,
	attackRange = 6,
	aggroRange = 32,
	leashRange = 85,
	walkSpeed = 8,
	xp = 25,
	respawnSeconds = 90,
	colour = Color3.fromRGB(220, 214, 198),
	hitSound = "rbxassetid://127637727363472",
	dieSound = "rbxassetid://96214777896458",
	drops = {
		{ item = "Bone", min = 2, max = 4 },
		{ item = "IronOre", min = 1, max = 2, chance = 0.25 },
	},
}

--------------------------------------------------------------------------------
-- The second batch of monsters (Model_mosterV2). Defined so they are fightable the moment a spawner names
-- them; nothing scatters these yet, as the user asked -- they go into the map by hand later.
--
-- Tuned as a tier above the first batch: this is what a player meets after skeletons stop being frightening.
--------------------------------------------------------------------------------

-- A bandit is a person, so it is the fastest and the most aggressive, but no tougher than a skeleton.
-- The only one here that drops coins-in-all-but-name: it had pockets.
GatherConfig.Mobs.Bandit = {
	name = "โจรป่า",
	model = "Monster_Bandit",
	hp = 85,
	damage = 14,
	attackCooldown = 1.3,
	attackRange = 7,
	aggroRange = 45,
	leashRange = 100,
	walkSpeed = 13, -- faster than a walking player, slower than a sprint
	xp = 35,
	respawnSeconds = 120,
	colour = Color3.fromRGB(120, 92, 66),
	hitSound = "rbxassetid://127637727363472",
	dieSound = "rbxassetid://96214777896458",
	drops = {
		-- ผู้ใช้ขอ "เงินเหรียญซิลเวอร์ 10-50" — ขยับเพดานจาก 40 เป็น 50
		{ item = "Silver", min = 10, max = 50 },
		{ item = "Bullet", min = 2, max = 6, chance = 0.35 },
		{ item = "Blueprint", min = 1, max = 1, chance = 0.1 },
		-- และ "อาวุธแบบสุ่ม" — หนึ่งชิ้นจากตารางเดียวกับที่สไลม์พิเศษใช้ โอกาสต่ำ ไม่งั้นโจรจะเป็นร้านขายอาวุธ
		{ oneOf = GatherConfig.WeaponDrops, min = 1, max = 1, chance = 0.12 },
	},
}

-- Slow, enormous, and hits like a rockfall. The counter is simply walking away from it.
GatherConfig.Mobs.StoneGolem = {
	name = "โกเลมหิน",
	model = "Monster_StoneGolem",
	hp = 260,
	damage = 26,
	attackCooldown = 2.4,
	attackRange = 9,
	aggroRange = 30,
	leashRange = 70,
	walkSpeed = 5, -- slower than a walking player: you can always leave
	xp = 80,
	respawnSeconds = 240,
	colour = Color3.fromRGB(120, 120, 126),
	hitSound = "rbxassetid://120916604676149", -- stone, not flesh
	dieSound = "rbxassetid://96214777896458",
	drops = {
		{ item = "Stone", min = 4, max = 9 },
		{ item = "IronOre", min = 2, max = 5 },
		{ item = "Crystal", min = 1, max = 2, chance = 0.4 },
		-- ศิลาเวท ตามที่ผู้ใช้กำหนดตอนเพิ่มชุดมอนใหม่ (เดิมเขียนเป็นโกเลมตัวที่สองซ้อนทับตัวนี้)
		{ item = "RuneStone", min = 1, max = 2, chance = 0.5 },
	},
}

-- The clockwork sentry is the steam age's own guard dog: metal, precise, and full of the parts it is made
-- of. The only reliable monster source of gears.
GatherConfig.Mobs.ClockworkSentry = {
	name = "ทหารจักรกล",
	model = "Monster_ClockworkSentry",
	hp = 140,
	damage = 18,
	attackCooldown = 1.1, -- it does not tire
	attackRange = 7,
	aggroRange = 38,
	leashRange = 85,
	walkSpeed = 10,
	xp = 55,
	respawnSeconds = 180,
	colour = Color3.fromRGB(150, 130, 90),
	hitSound = "rbxassetid://120916604676149",
	dieSound = "rbxassetid://96214777896458",
	drops = {
		{ item = "GearSpare", min = 1, max = 3 },
		{ item = "Coal", min = 1, max = 3, chance = 0.5 },
		-- ผู้ใช้ขอ "เหล็ก หรือ ศิลาเวท" — oneOf คืออย่างใดอย่างหนึ่ง ไม่ใช่ทั้งคู่
		{ oneOf = { "IronOre", "RuneStone" }, min = 1, max = 3, chance = 0.5 },
	},
}

-- A ghoul is the cheap one of the four -- weaker than a bandit -- but it notices you from further away than
-- anything else here and does not give up easily.
GatherConfig.Mobs.Ghoul = {
	name = "ผีดิบ",
	model = "Monster_Ghoul",
	hp = 95,
	damage = 15,
	attackCooldown = 1.5,
	attackRange = 6,
	aggroRange = 55,
	leashRange = 120,
	walkSpeed = 9,
	xp = 40,
	respawnSeconds = 120,
	colour = Color3.fromRGB(110, 130, 100),
	hitSound = "rbxassetid://127637727363472",
	dieSound = "rbxassetid://96214777896458",
	drops = {
		{ item = "Bone", min = 2, max = 5 },
		{ item = "Herb", min = 1, max = 3, chance = 0.4 },
		{ item = "Chemical", min = 1, max = 2, chance = 0.2 },
	},
}

--------------------------------------------------------------------------------
-- มอนสเตอร์ชุดใหม่ 8 ชนิด (2026-09-17)
--
-- โมเดลทั้งแปดวางไว้ในแมพอยู่แล้ว กระจายกันคนละมุมแผนที่ ไฟล์ `mapgen/67_world_actors.lua` เป็นคนแปลง
-- โมเดลที่วางไว้ให้กลายเป็นสปอว์เนอร์ตรงจุดนั้น — ตัวเลขทั้งหมดอยู่ที่นี่ที่เดียว
--
-- **เรียงความยากจากอ่อนไปแข็ง**: ค้างคาว < หมูป่า < หมาป่า < โจร < ผีดิบ < หุ่นไขลาน < วิญญาณ < โกเลม
-- เลือดและดาเมจไล่ขึ้นตามนั้น และ respawn ยิ่งแข็งยิ่งนาน
--------------------------------------------------------------------------------

-- ค้างคาว: อ่อนที่สุด เร็ว เลือดน้อย เจอเป็นฝูงได้
GatherConfig.Mobs.Bat = {
	name = "ค้างคาว",
	model = "Monster_Bat",
	hp = 30, damage = 5,
	attackCooldown = 1.1, attackRange = 5,
	aggroRange = 35, leashRange = 80,
	walkSpeed = 13,   -- เร็วกว่าคนเดิน (8) แต่ช้ากว่าคนวิ่ง (24) หนีได้ถ้าวิ่ง
	xp = 12, respawnSeconds = 60,
	colour = Color3.fromRGB(70, 60, 80),
	hitSound = "rbxassetid://127637727363472",
	dieSound = "rbxassetid://96214777896458",
	drops = { { item = "BatGuano", min = 1, max = 3 } },
}

-- หมูป่า: ช้า เลือดหนา ไม่ไล่ไกล
GatherConfig.Mobs.Boar = {
	name = "หมูป่า",
	model = "Monster_Boar",
	hp = 70, damage = 9,
	attackCooldown = 1.8, attackRange = 6,
	aggroRange = 24, leashRange = 60,
	walkSpeed = 9,
	xp = 18, respawnSeconds = 90,
	colour = Color3.fromRGB(96, 74, 56),
	hitSound = "rbxassetid://127637727363472",
	dieSound = "rbxassetid://96214777896458",
	drops = { { item = "Meat", min = 1, max = 3 } },
}

-- หมาป่า: เร็ว เจ็บ ไล่ไกล อันตรายกว่าที่เลือดบอก
GatherConfig.Mobs.Wolf = {
	name = "หมาป่า",
	model = "Monster_Wolf",
	hp = 85, damage = 14,
	attackCooldown = 1.2, attackRange = 6,
	aggroRange = 45, leashRange = 110,
	walkSpeed = 16,
	xp = 28, respawnSeconds = 120,
	colour = Color3.fromRGB(88, 88, 96),
	hitSound = "rbxassetid://127637727363472",
	dieSound = "rbxassetid://96214777896458",
	drops = { { item = "Claw", min = 1, max = 2 } },
}

-- วิญญาณ: ลอย เจ็บมาก เลือดกลาง ดรอปแร่เวท
GatherConfig.Mobs.Wraith = {
	name = "วิญญาณ",
	model = "Monster_Wraith",
	hp = 140, damage = 24,
	attackCooldown = 1.6, attackRange = 7,
	aggroRange = 50, leashRange = 120,
	walkSpeed = 11,
	xp = 65, respawnSeconds = 240,
	colour = Color3.fromRGB(120, 140, 190),
	hitSound = "rbxassetid://127637727363472",
	dieSound = "rbxassetid://96214777896458",
	drops = { { item = "MagicOre", min = 1, max = 2 } },
}

return GatherConfig
