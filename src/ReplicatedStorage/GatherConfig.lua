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
		prompt = "เก็บไม้",
		object = "ต้นไม้",
	},
	Rock = {
		item = "Stone", min = 1, max = 3,
		seconds = 3.0,
		xp = 6,
		tool = "pickaxe",
		prompt = "ทุบหิน",
		object = "ก้อนหิน",
	},
	-- Defined now so the ore and herb nodes the caves already contain light up the moment they are tagged.
	-- Nothing scatters these yet.
	IronOre = {
		item = "IronOre", min = 1, max = 3,
		seconds = 3.5, xp = 8, tool = "pickaxe",
		prompt = "ขุดแร่", object = "สายแร่เหล็ก",
	},
	Crystal = {
		item = "Crystal", min = 1, max = 1,
		seconds = 5.0, xp = 25, tool = "pickaxe",
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
	},
}

return GatherConfig
