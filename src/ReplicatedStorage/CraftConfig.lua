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
	-- The unlucky man's page: every weapon in the game, bought outright with the coins a failed craft leaves
	-- behind. It is the floor under the gamble -- twenty-five failed pistols is still a pistol.
	{ id = "unlucky", name = "คนดวงซวย" },
	-- The garage bench. A key is one attempt in twenty, and every failure hands back a car part -- so the
	-- page is really two ways to the same door: gamble, or collect six parts and walk in.
	{ id = "vehicle", name = "พาหนะ" },
	-- หน้าของสถานี (ไม่ใช่ช่างตีเหล็ก) เปิดได้เฉพาะเมื่อยืนที่เครื่องนั้น `station` ตรงกับ CraftStations.server
	{ id = "food", name = "อาหาร", station = "stove" },
	{ id = "drink", name = "เครื่องดื่ม", station = "blender" },
	{ id = "medicine", name = "ยา", station = "still" },
}

-- What one failed attempt is worth. A single coin, so the exchange rates below read directly as "how many
-- failures does this weapon cost": a sword is two, a pistol twenty-five.
CraftConfig.InsigniaPerFailure = 1
CraftConfig.InsigniaItem = "Insignia"

-- How long the hammer swings before you learn the answer. Long enough to feel like work was done, short
-- enough that a failed attempt is not a punishment on its own.
--
-- ค่าเริ่มต้นของทุกสูตร สูตรที่ใส่ `seconds` เองใช้ค่าของตัวเองแทน (ครัวบางเมนูผู้ใช้กำหนดเป็นนาที)
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
	-- ครัว (ผู้ใช้กำหนดสูตร) ไม่มีค่าธรรมเนียม ไม่มีโอกาสล้มเหลว — เตา/เครื่องปั่นไม่ใช่ช่างรับจ้าง
	{ id = "FriedRice", tab = "food", station = "stove", chance = 1, gold = 0,
		cost = { Wheat = 7, Shrimp = 3, Vegetable = 3 } },
	-- สเต็กกับน้ำแอปเปิลใช้เวลาจริงตามที่ผู้ใช้กำหนด (15 นาที / 5 นาที) กดแล้ว **เดินไปทำอย่างอื่นได้**
	-- เตาทำต่อจนครบเวลาแล้วของเด้งเข้ากระเป๋าพร้อมข้อความ กลับมายืนที่เตาเมื่อไหร่ก็เห็นแถบเดินต่อจากเดิม
	{ id = "Steak", tab = "food", station = "stove", chance = 1, gold = 0, seconds = 15 * 60,
		cost = { Meat = 3, Vegetable = 2, Apple = 2, Bread = 5 } },
	{ id = "AppleJuice", tab = "drink", station = "blender", chance = 1, gold = 0, seconds = 5 * 60,
		cost = { Apple = 5, Crystal = 5, Water = 10 } },
	-- เครื่องต้มยา: ยาน้ำขวด · ยาใหญ่ (เลือดเต็มหลอด) · กล่องปฐมพยาบาล — สูตรตามที่ผู้ใช้กำหนด
	{ id = "HealthPotion", tab = "medicine", station = "still", chance = 1, gold = 0,
		cost = { Herb = 15, Crystal = 5 } },
	{ id = "GreatPotion", tab = "medicine", station = "still", chance = 1, gold = 0,
		cost = { Herb = 30, Fiber = 15, Bone = 3, WoodScrap = 5 } },
	{ id = "FirstAidKit", tab = "medicine", station = "still", chance = 1, gold = 0,
		cost = { Herb = 10, Fiber = 6, Water = 3, WoodScrap = 2 } },
	-- The pistol is the prize of the weapon bench: the strongest thing a player can hold, and one attempt
	-- in four. The materials are the user's V1 list -- the new ones (gears, blueprints, silver) are what tie
	-- the weapon bench to the illegal farms, since none of the three can be bought.
	{ id = "Pistol", tab = "weapon", chance = 0.25, gold = 25000,
		cost = { IronOre = 7, Slime = 15, GearSpare = 10, WoodScrap = 15, Blueprint = 5, Silver = 100 } },
	{ id = "Sword", tab = "weapon", chance = 0.50, gold = 12000,
		cost = { IronOre = 10, Slime = 15, WoodScrap = 15, Blueprint = 2 } },
	-- The greatsword sits between the two: a quarter of the pistol's odds-to-own, but it costs coal and
	-- gears on top of the sword's ore, which is what makes it the thing you build after the farms are running.
	{ id = "Greatsword", tab = "weapon", chance = 0.25, gold = 25000,
		cost = { GearSpare = 8, IronOre = 15, WoodScrap = 15, Coal = 15, Slime = 15, Blueprint = 5, Silver = 250 } },

	-- Bullets moved off the weapon bench and in here with the everyday goods, where a near-certain 95% is
	-- what makes ammunition something you top up rather than gamble on.
	-- `yields` is how many come out of one attempt; absent means one, which is what every other recipe
	-- wants. Ammunition and medicine are made in batches because a single bullet for 300 gold and twenty
	-- iron would be a worse deal than buying one, and the crafting bench should not be the expensive way to
	-- get something.
	{ id = "Bullet", tab = "misc", chance = 0.95, gold = 300, yields = 8,
		cost = { IronOre = 4, GearSpare = 5, Bone = 15, Stone = 15, Silver = 25 } },
	{ id = "HealthPotion", tab = "misc", chance = 0.95, gold = 500, yields = 2,
		cost = { Crystal = 10, Herb = 15 } },

	{ id = "ChainmailArmor", tab = "armor", chance = 0.75, gold = 6000,
		cost = { IronOre = 10, Fiber = 15, Slime = 15, Silver = 50 } },

	----------------------------------------------------------------------------
	-- The unlucky man's page.
	--
	-- Not a gamble and not a fee: `chance = 1` and `gold = 0` on purpose, because these coins were ALREADY
	-- paid for by failures at the other benches. Charging again, or rolling again, would be taking the same
	-- money twice.
	--
	-- The prices are the user's, and they rank the weapons the way the game does: a sword for two failures,
	-- a pistol for twenty-five.
	----------------------------------------------------------------------------
	{ id = "Sword", tab = "unlucky", chance = 1, gold = 0, cost = { Insignia = 2 } },
	{ id = "Staff", tab = "unlucky", chance = 1, gold = 0, cost = { Insignia = 15 } },
	{ id = "Spellbook", tab = "unlucky", chance = 1, gold = 0, cost = { Insignia = 15 } },
	{ id = "Bow", tab = "unlucky", chance = 1, gold = 0, cost = { Insignia = 15 } },
	{ id = "Pistol", tab = "unlucky", chance = 1, gold = 0, cost = { Insignia = 25 } },

	----------------------------------------------------------------------------
	-- The garage.
	--
	-- One in twenty, and a failure hands back one of the six car parts instead of a coin -- `failGives`.
	-- Repeats are allowed and expected: the parts are a collection, and the second gearbox is the price of
	-- the one you still need.
	--
	-- The second row is the floor under that gamble, the way the unlucky page is the floor under the others:
	-- a full set of parts IS a key, at chance 1 and no fee, because the failures already paid for it.
	----------------------------------------------------------------------------
	{ id = "CarKey", tab = "vehicle", chance = 0.05, gold = 0,
		cost = { GearSpare = 16, IronOre = 8, WoodScrap = 15, Slime = 15, Blueprint = 5, Silver = 500 },
		failGives = { "Fueltank", "GearCar", "Mattress", "Pipe", "Steering", "Wheel" } },
	{ id = "CarKey", tab = "vehicle", chance = 1, gold = 0,
		cost = { Fueltank = 2, GearCar = 1, Mattress = 1, Pipe = 2, Steering = 1, Wheel = 4 } },

	----------------------------------------------------------------------------
	-- Treasure chests, made at the everyday bench. The rate falls as the loot inside gets better: a wooden
	-- chest is a certainty, a gold one is one in ten.
	----------------------------------------------------------------------------
	{ id = "Chest_Wood", tab = "misc", chance = 1.00, gold = 0,
		cost = { WoodScrap = 20, Stone = 20, Silver = 50 } },
	{ id = "Chest_Ironbound", tab = "misc", chance = 0.70, gold = 0,
		cost = { IronOre = 50, WoodScrap = 50, Silver = 200 } },
	{ id = "Chest_Silver", tab = "misc", chance = 0.40, gold = 0,
		cost = { IronOre = 50, WoodScrap = 50, Silver = 1000 } },
	{ id = "Chest_Gold", tab = "misc", chance = 0.10, gold = 0,
		cost = { IronOre = 100, WoodScrap = 100, Silver = 1000, Insignia = 5 } },
}

return CraftConfig
