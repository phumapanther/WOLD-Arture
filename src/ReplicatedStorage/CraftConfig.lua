-- CraftConfig: what the blacksmith can make, and out of what.
--
-- Data only, like ShopConfig. A recipe is { id = what comes out, tab = which page it sits on,
-- cost = { [material id] = how many } }, and the ORDER of this list is the contract with the client: a craft
-- request names a position in it and nothing else, so the client never sends an item id or a quantity that
-- the server would have to believe.
local CraftConfig = {}

-- The three pages, in the order they appear across the top of the window. Kept here rather than in the GUI so
-- adding a page is an entry in this file, the way adding an item is an entry in the catalog.
CraftConfig.Tabs = {
	{ id = "weapon", name = "อาวุธ" },
	{ id = "misc", name = "ไอเทมจิปาถะ" },
	{ id = "armor", name = "ชุดเกราะ" },
}

-- Amounts are the user's, exactly as given. Every id here is checked against ItemCatalog at startup by
-- Crafting.server, so a typo is a loud warning on boot rather than a recipe that silently never appears.
CraftConfig.Recipes = {
	{ id = "Pistol", tab = "weapon", cost = { IronOre = 15, WoodScrap = 10, Crystal = 3, Slime = 20 } },
	{ id = "Bullet", tab = "weapon", cost = { IronOre = 10, Bone = 15, Stone = 20 } },
	{ id = "Sword", tab = "weapon", cost = { IronOre = 20, WoodScrap = 10, Slime = 10 } },

	{ id = "HealthPotion", tab = "misc", cost = { Crystal = 10, Herb = 15 } },

	{ id = "ChainmailArmor", tab = "armor", cost = { IronOre = 30, Fiber = 20, Slime = 15 } },
}

return CraftConfig
