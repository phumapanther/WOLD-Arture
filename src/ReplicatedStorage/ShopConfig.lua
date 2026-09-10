-- ShopConfig: what the shopkeeper sells, and what they will buy.
--
-- Only the tools and the two basics for now, as the user asked. Weapons, armor and potions are deliberately
-- absent: those are meant to come from the crafter, and a shop that sold them would leave the crafter with
-- nothing to do the day it exists.
local ShopConfig = {}

-- What the shopkeeper hands over, at a fixed price. Stock is unlimited -- a shop that ran out would just
-- be a wall between a player and the game while nobody is around to restock it.
ShopConfig.Sells = {
	{ id = "Shovel", price = 120 },
	{ id = "Pickaxe", price = 150 },
	{ id = "Axe", price = 140 },
	{ id = "Bread", price = 12 },
	{ id = "Water", price = 8 },
	-- Fishing. The rod is a one-off purchase; worms are the running cost, and one is spent per catch, so a
	-- stack is how long a session at the water lasts.
	{ id = "FishingRod", price = 90 },
	{ id = "Worm", price = 2 },
}

-- What the shopkeeper buys, and for how much of the catalog `value`. Well under 1 on purpose: the gap
-- between what a thing sells for and what it costs to buy back is the only thing stopping "buy low from
-- the shop, sell high to the shop" being infinite money.
ShopConfig.BuyFraction = 0.6

-- Anything of these kinds can be sold. Named by kind rather than listed by id so a material added later is
-- sellable the day it exists.
ShopConfig.Buys = { junk = true }

-- Prices drift so the same material is not worth the same forever. Rerolled on a timer shared by the whole
-- server, not per player, so everyone standing at the counter sees one price.
ShopConfig.PriceSwing = 0.35 -- +/- 35% around the catalog value
ShopConfig.RerollSeconds = 1800 -- half an hour, as asked

return ShopConfig
