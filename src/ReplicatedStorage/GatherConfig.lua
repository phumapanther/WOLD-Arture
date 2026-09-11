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
	Herb = {
		item = "Herb", min = 1, max = 2,
		-- A shovel, per the user. Digging a root out is a shovel's job even though picking a leaf is not.
		seconds = 1.5, xp = 4, tool = "shovel",
		prompt = "เก็บสมุนไพร", object = "สมุนไพร",
	},
}

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

-- How often a special slime gives up a weapon. One kill in ten.
GatherConfig.SpecialWeaponChance = 0.10

-- Ore and crystal sit ABOVE the weapon chance and below a certainty, which is the order the user asked
-- for: low, but likelier than the weapon. Iron is the commoner of the two because crystal is worth more
-- than twice as much in the shop and is wanted three at a time by the pistol recipe.
GatherConfig.SpecialOreChance = 0.35
GatherConfig.SpecialCrystalChance = 0.22

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
		hp = 90,
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
		drops = {
			{ item = "Slime", min = 2, max = 4 },
			-- Ore and crystal: uncommon, but a good deal more likely than the weapon. A named slime is a
			-- long walk and a thirty-minute wait, so a trip that yields nothing but goo is a wasted one --
			-- these are what make the walk pay for itself while the weapon stays the thing you hope for.
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
	{ hp = 110, damage = 13, walkSpeed = 6, model = "Monster_SteamSlime" })

-- Volt: the plasma slime. Quick and hits fast, but softer.
GatherConfig.Mobs.PlasmaSlime = special("โวลต์ สไลม์พลาสมา", Color3.fromRGB(0, 230, 255),
	{ hp = 80, damage = 10, attackCooldown = 1.1, walkSpeed = 7.5, aggroRange = 36,
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

return GatherConfig
