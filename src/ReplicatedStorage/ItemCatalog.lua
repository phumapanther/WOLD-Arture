-- ItemCatalog: every item in the game as data. Adding an item is an entry here, not new logic anywhere else.
--
-- Shared by server and client: the server validates against it, the client renders names and icons from it.
--
-- Fields every item has:
--   name        display name (Thai)
--   kind        "weapon" | "armor" | "consumable" | "junk"
--   weight      carried weight; the inventory's total drives the movement penalty
--   stackSize   1 = cannot stack (weapons, armor), >1 = stacks up to this many per slot
-- Icons: the PNGs in assets/item-icons/ are cut from the user's design sheet and must be uploaded by hand
-- (create.roblox.com -> Creations -> Images), since image upload is a website action. Paste each returned
-- rbxassetid:// into the matching `icon` field below; an empty string is safe -- the UI falls back to the
-- item's name as text.
-- ICON IDS: an ImageLabel needs the IMAGE asset id, not the DECAL id. Uploading a picture through the
-- Creator Dashboard gives you a Decal id, and pasting that here shows a blank square with no error at all.
-- To find the real one: InsertService:LoadAsset(decalId) in Studio, then read the Decal's Texture property.
-- Pure data, and the only thing this file requires. See ItemCatalog.IsSellable for what it is read for and
-- why the direction of the dependency matters.
local CraftConfig = require(script.Parent.CraftConfig)

local ItemCatalog = {}

-- Consuming takes time: the effect lands when the animation finishes, not when the button is pressed.
-- Long enough to be a real commitment in a fight, short enough not to feel like a punishment.
ItemCatalog.ConsumeSeconds = 3

ItemCatalog.Items = {
	--------------------------------------------------------------------------
	-- Weapons. Each defines the Q skill it grants and the animations its basic
	-- attack uses; equipping one swaps the combat animations wholesale.
	--------------------------------------------------------------------------
	Sword = {
		icon = "rbxassetid://113229682531477", -- assets/item-icons/Sword.png
		name = "ดาบ", kind = "weapon", weight = 6, stackSize = 1,
		damage = 18, range = 7,
		maxDurability = 120,
		skill = { id = "LungeSlash", name = "พุ่งฟัน", manaCost = 1, cooldown = 3 },
	},
	Bow = {
		icon = "rbxassetid://100309435801424", -- assets/item-icons/Bow.png
		name = "ธนู", kind = "weapon", weight = 4, stackSize = 1,
		damage = 12, range = 6, -- melee fallback; the skill is the real attack
		maxDurability = 100,
		skill = { id = "ScatterShot", name = "ยิงกระจาย", manaCost = 1, cooldown = 3 },
	},
	Staff = {
		icon = "rbxassetid://86359404715162", -- assets/item-icons/Staff.png
		name = "ไม้คทา", kind = "weapon", weight = 5, stackSize = 1,
		damage = 10, range = 6,
		maxDurability = 90,
		skill = { id = "GroupHeal", name = "ฮีลหมู่", manaCost = 1, cooldown = 3 },
	},
	Spellbook = {
		icon = "rbxassetid://98989238832991", -- assets/item-icons/Spellbook.png
		name = "สมุดเวท", kind = "weapon", weight = 3, stackSize = 1,
		damage = 8, range = 5,
		maxDurability = 80,
		skill = { id = "Fireball", name = "ลูกไฟ", manaCost = 1, cooldown = 3 },
	},

	--------------------------------------------------------------------------
	-- Tools. Weapons in every mechanical sense -- they equip to the weapon slot
	-- and swing with the sword's own animation, which is what the user asked for
	-- -- but each one is also the key to a kind of gathering node. `gathers`
	-- names the GatherConfig tool it satisfies; combat does not read it.
	--
	-- Damage sits below the sword's 18: a pickaxe swung at a person should be
	-- worse than a weapon made for it, or nobody would ever carry a sword.
	--------------------------------------------------------------------------
	Axe = {
		icon = "rbxassetid://94868056279785",
		name = "ขวาน", kind = "weapon", weight = 5, stackSize = 1,
		damage = 14, range = 7,
		maxDurability = 100,
		gathers = "axe",
		skill = { id = "LungeSlash", name = "พุ่งฟัน", manaCost = 1, cooldown = 3 },
	},
	Pickaxe = {
		icon = "rbxassetid://71353632810064",
		name = "อีเต้อ", kind = "weapon", weight = 6, stackSize = 1,
		damage = 13, range = 7,
		maxDurability = 110,
		gathers = "pickaxe",
		skill = { id = "LungeSlash", name = "พุ่งฟัน", manaCost = 1, cooldown = 3 },
	},
	Shovel = {
		icon = "rbxassetid://111182494345005",
		name = "พลั่ว", kind = "weapon", weight = 4, stackSize = 1,
		damage = 11, range = 7,
		maxDurability = 90,
		gathers = "shovel",
		skill = { id = "LungeSlash", name = "พุ่งฟัน", manaCost = 1, cooldown = 3 },
	},

	Pistol = {
		icon = "rbxassetid://76734561926426",
		name = "ปืน", kind = "weapon", weight = 4, stackSize = 1,
		-- The shot does no damage at all. It floors whoever it hits for five seconds, which is a far
		-- nastier thing to do to someone than taking a slice of their health -- and it keeps the guard's
		-- pistol a tool of arrest rather than a way to kill people faster than a sword.
		damage = 0, range = 6,
		maxDurability = 120,
		skill = { id = "LungeSlash", name = "พุ่งฟัน", manaCost = 1, cooldown = 3 },
	},
	FishingRod = {
		icon = "rbxassetid://108988125515479",
		name = "คันเบ็ด", kind = "weapon", weight = 3, stackSize = 1,
		-- A weapon in the mechanical sense only: it equips to the weapon slot so it can be held in two
		-- hands, and swinging it is what casts the line. The damage is deliberately pitiful -- hitting
		-- someone with a fishing rod should not be a strategy.
		damage = 3, range = 6,
		maxDurability = 80,
		fishing = true,
		skill = { id = "LungeSlash", name = "พุ่งฟัน", manaCost = 1, cooldown = 3 },
	},

	--------------------------------------------------------------------------
	-- Armor. `armor` is the pool it grants; `absorbFraction` is how much of an
	-- incoming hit it eats. Heavier armor lasts longer but costs carry weight.
	--------------------------------------------------------------------------
	LeatherArmor = {
		icon = "rbxassetid://131986289115512", -- assets/item-icons/LeatherArmor.png
		name = "เกราะหนัง", kind = "armor", weight = 8, stackSize = 1,
		armor = 60, absorbFraction = 0.5,
	},
	ChainmailArmor = {
		icon = "rbxassetid://137536880363064", -- assets/item-icons/ChainmailArmor.png
		name = "เกราะเหล็กโซ่", kind = "armor", weight = 16, stackSize = 1,
		armor = 140, absorbFraction = 0.6,
	},
	PlateArmor = {
		icon = "rbxassetid://128618993703994", -- assets/item-icons/PlateArmor.png
		name = "เกราะเหล็กหนัก", kind = "armor", weight = 28, stackSize = 1,
		armor = 260, absorbFraction = 0.7,
	},

	--------------------------------------------------------------------------
	-- Consumables. `use` names what Vitals should restore; the amount is in the
	-- same units as the stat itself.
	--------------------------------------------------------------------------
	Bread = {
		icon = "rbxassetid://70954901802854", -- assets/item-icons/Bread.png
		name = "ขนมปัง", kind = "consumable", weight = 0.5, stackSize = 16,
		use = { stat = "hunger", amount = 35 },
		useSound = "Eat",
	},
	Water = {
		icon = "rbxassetid://128474051932298", -- assets/item-icons/Water.png
		name = "น้ำเปล่า", kind = "consumable", weight = 1, stackSize = 16,
		use = { stat = "mana", amount = 1 },
		useSound = "Drink",
	},
	HealthPotion = {
		icon = "rbxassetid://70766990190847", -- assets/item-icons/HealthPotion.png
		name = "ยาฮีล", kind = "consumable", weight = 0.8, stackSize = 5,
		use = { stat = "hp", amount = 40 },
		useSound = "Drink",
	},
	RepairHammer = {
		icon = "rbxassetid://94401710904380", -- assets/item-icons/RepairHammer.png
		name = "ค้อนซ่อม", kind = "consumable", weight = 3, stackSize = 15,
		use = { stat = "repair", amount = 1 }, -- restores the equipped armor's durability
		useSound = "Hammer",
	},

	--------------------------------------------------------------------------
	-- Junk. No effect yet; they exist to be gathered, carried and sold later.
	--------------------------------------------------------------------------
	Bone = { icon = "rbxassetid://97472792310870", name = "กระดูก", kind = "junk", weight = 1, stackSize = 99, value = 2 }, -- assets/item-icons/Bone.png
	-- Dropped by slimes, the way bone comes off skeletons and fibre off spiders. Light and cheap: it is the
	-- drop from the weakest thing in the world, so it has to be the least worth carrying home.
	Slime = { icon = "rbxassetid://127535718276590", name = "เมือกสไลม์", kind = "junk", weight = 0.5, stackSize = 99, value = 3 },
	WoodScrap = { icon = "rbxassetid://133089629701208", name = "เศษไม้", kind = "junk", weight = 1.5, stackSize = 99, value = 1 },
	Stone = { icon = "rbxassetid://115614728197402", name = "ก้อนหิน", kind = "junk", weight = 2.5, stackSize = 99, value = 1 },

	-- Gathered materials. Priced and weighted by where they come from: fibre is picked off a bush
	-- anywhere, herbs need looking for, ore has to be mined, and crystal only grows in the caves. The
	-- gathering tags in docs/design/04-gameplay-hooks.md already name these as resources, so the catalog
	-- entries exist before the system that drops them rather than after.
	IronOre = { icon = "rbxassetid://85652195246479", name = "แร่เหล็ก", kind = "junk", weight = 3, stackSize = 99, value = 6 }, -- assets/item-icons/IronOre.png
	Fiber = { icon = "rbxassetid://89290089367939", name = "เส้นใย", kind = "junk", weight = 0.3, stackSize = 99, value = 2 }, -- assets/item-icons/Fiber.png
	Herb = { icon = "rbxassetid://87753072302137", name = "สมุนไพร", kind = "junk", weight = 0.4, stackSize = 99, value = 4 }, -- assets/item-icons/Herb.png
	Crystal = { icon = "rbxassetid://76877650996022", name = "คริสตัล", kind = "junk", weight = 1.2, stackSize = 99, value = 15 }, -- assets/item-icons/Crystal.png

	--------------------------------------------------------------------------
	-- The sea's catch. Value tracks rarity: a shark is worth eighty of the commonest fish, which is what
	-- makes a long session at the water worth the worms it costs.
	--------------------------------------------------------------------------
	Fish = { icon = "rbxassetid://122960988755820", name = "ปลา", kind = "junk", weight = 1.2, stackSize = 99, value = 8 },
	Crab = { icon = "rbxassetid://73086014428726", name = "ปู", kind = "junk", weight = 1, stackSize = 99, value = 12 },
	Shell = { icon = "rbxassetid://105080925349379", name = "หอย", kind = "junk", weight = 0.6, stackSize = 99, value = 10 },
	Shrimp = { icon = "rbxassetid://87303093153934", name = "กุ้ง", kind = "junk", weight = 0.5, stackSize = 99, value = 18 },
	Squid = { icon = "rbxassetid://128279410160112", name = "หมึก", kind = "junk", weight = 1.4, stackSize = 99, value = 24 },
	Pufferfish = { icon = "rbxassetid://122396428148223", name = "ปลาปักเป้า", kind = "junk", weight = 1.1, stackSize = 99, value = 55 },
	Anglerfish = { icon = "rbxassetid://89621592057467", name = "ปลาแองเกลอ", kind = "junk", weight = 2, stackSize = 99, value = 180 },
	Shark = { icon = "rbxassetid://105856971417865", name = "ฉลาม", kind = "junk", weight = 8, stackSize = 99, value = 320 },

	-- Pistol ammunition. Sixteen to a stack, as the user asked, so carrying a lot of shots costs real bag
	-- space rather than one slot holding a war's worth.
	Bullet = { icon = "rbxassetid://99384118358133", name = "กระสุน", kind = "junk", weight = 0.1, stackSize = 16, value = 3 },

	-- Bait. One is spent per catch, so a stack of worms is how long a session lasts.
	Worm = { icon = "rbxassetid://91361977777697", name = "หนอน", kind = "junk", weight = 0.05, stackSize = 99, value = 1 },

	--------------------------------------------------------------------------
	-- The steam age's own materials (V0.5). Every one of them is `sellable = false`: they are the currency of
	-- the illegal trades and the crafting bench, and a shopkeeper who bought them would turn every one of
	-- them straight back into gold -- which is exactly what the fixed prices on the crafting recipes are
	-- meant to stop.
	--
	-- The stack sizes are the user's, and they are the whole pacing of the farm: chemicals and gears come
	-- eight to a slot, so a night of distilling fills the bag rather than one corner of it.
	--------------------------------------------------------------------------
	-- "Unlimited" as the user asked, expressed as a number rather than math.huge: an infinite stack cannot be
	-- written to a DataStore (JSON has no inf) and would come back from a save as nil, emptying the slot. Ten
	-- thousand of anything is past the point where a real player notices a ceiling.
	Silver = { icon = "rbxassetid://135974684914132", -- assets/item-icons/Silver.png
		name = "ซิลเวอร์", kind = "junk", weight = 0.02, stackSize = 9999, value = 1, sellable = false },
	-- The consolation prize for a craft that failed: a gold coin stamped with a broken hammer. Spent at the
	-- smith's "unlucky" page, which is the only thing in the game that takes them.
	Insignia = { icon = "rbxassetid://76808778183807", -- assets/item-icons/coin.png
		name = "เหรียญตราค้อนพัง", kind = "junk", weight = 0.05, stackSize = 9999, value = 0, sellable = false },
	Blueprint = { icon = "rbxassetid://100494667680016", -- assets/item-icons/print.png
		name = "แบบแปลน", kind = "junk", weight = 0.3, stackSize = 16, value = 0, sellable = false },
	-- Also the fuel every vehicle burns: one lump is Config.FuelPerCoal units in the tank.
	Coal = { icon = "rbxassetid://138735405435297", -- assets/item-icons/coal.png
		name = "ถ่านหิน", kind = "junk", weight = 2, stackSize = 16, value = 0, sellable = false },
	Chemical = { icon = "rbxassetid://133356301567666", -- assets/item-icons/chemical.png
		name = "สารเคมี", kind = "junk", weight = 1, stackSize = 8, value = 0, sellable = false },
	GearSpare = { icon = "rbxassetid://115193645709696", -- assets/item-icons/gear.png
		name = "เฟืองอะไหล่", kind = "junk", weight = 1.5, stackSize = 8, value = 0, sellable = false },

	--------------------------------------------------------------------------
	-- Vehicle keys. One key is one vehicle: each carries its own plate in the
	-- slot's `meta`, so two keys are two different vehicles and must never merge
	-- into a stack. stackSize = 1 states that in the catalog; Inventory.AddItem
	-- refuses to merge anything carrying meta, which is what actually enforces it.
	--------------------------------------------------------------------------
	CarKey = { icon = "rbxassetid://123656993683458", name = "กุญแจรถ",
		kind = "key", vehicle = "car", weight = 0.2, stackSize = 1, value = 0 },
	BoatKey = { icon = "rbxassetid://101179246285116", name = "กุญแจเรือ",
		kind = "key", vehicle = "boat", weight = 0.2, stackSize = 1, value = 0 },
	AirshipKey = { icon = "rbxassetid://85317443858917", name = "กุญแจเรือเหาะ",
		kind = "key", vehicle = "airship", weight = 0.2, stackSize = 1, value = 0 },
}

function ItemCatalog.Get(id)
	return ItemCatalog.Items[id]
end

function ItemCatalog.Exists(id)
	return ItemCatalog.Items[id] ~= nil
end

-- Everything the forge can make, derived from the recipe list rather than typed out again.
--
-- Read once at load, into a set. CraftConfig is pure data and requires nothing at all, so this cannot loop
-- back around -- but that is the reason it works, so **CraftConfig must stay data-only**; the day it requires
-- this file back, both stop loading.
local CraftableOutput = {}
for _, recipe in ipairs(CraftConfig.Recipes) do
	CraftableOutput[recipe.id] = true
end

-- May the shop put a price on this? Absent means yes, which is what every item written before V0.5 wants.
-- Read by the counter, the "sell everything" button and the price board alike, so an item cannot be refused
-- in one place and bought in another.
--
-- Two ways to be unsellable:
--
--   `sellable = false` in the entry -- the steam-age materials, which are the price of the new recipes.
--
--   BEING CRAFTABLE. Anything on the forge's list is refused, and the list is what decides rather than a flag
--   somebody has to remember to add. That gap is exactly how bullets ended up sellable: they are `kind =
--   "junk"` like every other material, and the shop buys by kind. Crafting one costs iron, gears, bone,
--   stone, silver and a 300-coin fee -- a counter that then bought it back is a route from materials to coin
--   that the fixed prices were never balanced against.
--
-- Weapons, armour and potions were never at risk (the shop only buys `junk`), but they are covered by the
-- same rule now, so the answer does not depend on which kind a future recipe happens to make.
function ItemCatalog.IsSellable(id)
	local item = ItemCatalog.Items[id]
	if not item then return false end
	if item.sellable == false then return false end
	return not CraftableOutput[id]
end

-- Weapons and armor carry durability, so they can never stack; everything else stacks by its own limit.
function ItemCatalog.StackSize(id)
	local item = ItemCatalog.Items[id]
	return item and item.stackSize or 1
end

return ItemCatalog
