-- ChestConfig: what is inside each grade of treasure chest, and what a chest is.
--
-- Data only, like ShopConfig and CraftConfig. The server rolls against this; the client is only ever told
-- what came out.
--
-- A chest is a one-off: it is opened once, the window shows what it happened to contain, and closing that
-- window destroys the chest and everything still in it. Nothing here is saved anywhere, which is why the
-- loot can be rolled at the moment of opening rather than when the chest is placed.
local ChestConfig = {}

-- Where the prototype models live. The folder name carries a trailing space in the place -- the user named
-- it that way -- so the lookup tries both rather than silently finding nothing.
ChestConfig.FolderNames = { "Treasure ", "Treasure" }

-- How close you have to stand, and what the button says.
ChestConfig.Range = 10
ChestConfig.PromptText = "เปิดหีบ"

-- How many DIFFERENT kinds of thing a chest holds, and how many of each. The user's numbers, shared by
-- every grade: one to three kinds, five to twenty of each.
ChestConfig.MinKinds, ChestConfig.MaxKinds = 1, 3
ChestConfig.MinEach, ChestConfig.MaxEach = 5, 20

-- Things that come one at a time whatever the roll says. A chest holding fourteen pistols would be worth
-- more than every other way of getting one put together, and fourteen car keys is fourteen cars.
ChestConfig.SingleItems = {
	Sword = true, Greatsword = true, Bow = true, Staff = true, Spellbook = true, Pistol = true,
	CarKey = true, BoatKey = true, AirshipKey = true,
}

--------------------------------------------------------------------------------
-- The pools. A grade picks a category by weight, then an item from that category evenly.
--
-- Splitting it in two stages rather than weighting every item separately is what makes the user's ratios
-- ("legal 50, illegal 30, usable 20") mean what they say: the odds of the CATEGORY are fixed, so adding a
-- new illegal material later cannot quietly make illegal loot more likely overall.
--------------------------------------------------------------------------------

-- Things a player can farm in the open: gathered, mined, fished, picked off a monster.
ChestConfig.Pools = {
	legal = {
		"WoodScrap", "Stone", "IronOre", "Crystal", "Herb", "Fiber", "Slime", "Bone",
		"Fish", "Crab", "Shell", "Shrimp", "Squid",
	},
	-- The steam age's contraband: what the illegal farms produce and the benches eat. None of it is
	-- purchasable, which is exactly why it is worth finding in a box.
	illegal = {
		"Silver", "Blueprint", "Coal", "Chemical", "GearSpare",
	},
	-- Things you press a button to use.
	usable = {
		"Bread", "Water", "HealthPotion", "RepairHammer",
	},
	-- Ammunition, kept out of `usable` so the gold chest can give it its own small share.
	ammo = {
		"Bullet",
	},
	-- Every weapon in the game, including the ones the forge gambles for.
	weapon = {
		"Sword", "Greatsword", "Bow", "Staff", "Spellbook", "Pistol",
	},
	-- A car, in the only form the game has one: its key. The rarest thing in any chest.
	key = {
		"CarKey",
	},
}

--------------------------------------------------------------------------------
-- The four grades. `weights` are the user's ratios, read as relative weights rather than percentages --
-- they happen to total 100, and nothing breaks if a later edit makes them total something else.
--------------------------------------------------------------------------------
ChestConfig.Chests = {
	Chest_Wood = {
		name = "หีบไม้",
		colour = Color3.fromRGB(146, 106, 66),
		weights = { legal = 100 },
	},
	Chest_Ironbound = {
		name = "หีบตีเหล็ก",
		colour = Color3.fromRGB(140, 140, 148),
		weights = { legal = 70, illegal = 30 },
	},
	Chest_Silver = {
		name = "หีบเงิน",
		colour = Color3.fromRGB(196, 200, 210),
		weights = { legal = 50, illegal = 30, usable = 20 },
	},
	Chest_Gold = {
		name = "หีบทอง",
		colour = Color3.fromRGB(226, 184, 78),
		-- The user's five-way split. Weapons and keys are the 3 and the 2: rare enough that a gold chest is
		-- usually still a pile of materials, which is what keeps the rare outcome worth opening one for.
		weights = { legal = 50, illegal = 30, usable = 15, ammo = 3, weapon = 2, key = 2 },
	},
}

-- Which categories count as "rare" -- the things a chest is actually opened hoping for. A chest bought with
-- a TikTok gift doubles the weight of exactly these, which is what makes a gift worth more than the coins.
--
-- Materials are deliberately not here: doubling those would only crowd out the weapons.
ChestConfig.RareCategories = {
	weapon = true,
	key = true,
	ammo = true,
}

-- Every grade, in the order they should be offered. Used by the admin command's argument list.
ChestConfig.Order = { "Chest_Wood", "Chest_Ironbound", "Chest_Silver", "Chest_Gold" }

return ChestConfig
