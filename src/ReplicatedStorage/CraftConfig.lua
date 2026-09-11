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

-- How long the hammer swings before you learn the answer. Long enough to feel like work was done, short
-- enough that a failed attempt is not a punishment on its own.
CraftConfig.CraftSeconds = 2.5

-- Amounts and success rates are the user's, exactly as given. Every id here is checked against ItemCatalog
-- at startup by Crafting.server, so a typo is a loud warning on boot rather than a recipe that silently
-- never appears.
--
-- `chance` is the odds the attempt WORKS. A failure still costs the materials AND the fee -- that is the
-- whole weight behind a 25% pistol, and a failure that cost nothing would just mean pressing the button
-- again.
--
-- `gold` is the smith's fee, in the bands the user set: tens of thousands for a weapon, thousands for
-- armour, hundreds for everyday goods. Paired with the success rate it is what actually prices a thing --
-- a pistol is 25,000 a go at one-in-four, so it costs 100,000 on average to walk away with one.
CraftConfig.Recipes = {
	-- The pistol is the prize of the weapon bench: the strongest thing a player can hold, and one attempt
	-- in four.
	{ id = "Pistol", tab = "weapon", chance = 0.25, gold = 25000,
		cost = { IronOre = 15, WoodScrap = 10, Crystal = 3, Slime = 20 } },
	{ id = "Sword", tab = "weapon", chance = 0.50, gold = 12000,
		cost = { IronOre = 20, WoodScrap = 10, Slime = 10 } },

	-- Bullets moved off the weapon bench and in here with the everyday goods, where a near-certain 95% is
	-- what makes ammunition something you top up rather than gamble on.
	-- `yields` is how many come out of one attempt; absent means one, which is what every other recipe
	-- wants. Ammunition and medicine are made in batches because a single bullet for 300 gold and twenty
	-- iron would be a worse deal than buying one, and the crafting bench should not be the expensive way to
	-- get something.
	{ id = "Bullet", tab = "misc", chance = 0.95, gold = 300, yields = 8,
		cost = { IronOre = 10, Bone = 15, Stone = 20 } },
	{ id = "HealthPotion", tab = "misc", chance = 0.95, gold = 500, yields = 2,
		cost = { Crystal = 10, Herb = 15 } },

	{ id = "ChainmailArmor", tab = "armor", chance = 0.75, gold = 6000,
		cost = { IronOre = 30, Fiber = 20, Slime = 15 } },
}

return CraftConfig
