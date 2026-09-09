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
local ItemCatalog = {}

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
	},
	Water = {
		icon = "rbxassetid://128474051932298", -- assets/item-icons/Water.png
		name = "น้ำเปล่า", kind = "consumable", weight = 1, stackSize = 16,
		use = { stat = "mana", amount = 1 },
	},
	HealthPotion = {
		icon = "rbxassetid://77251269114612", -- assets/item-icons/HealthPotion.png
		name = "ยาฮีล", kind = "consumable", weight = 0.8, stackSize = 5,
		use = { stat = "hp", amount = 40 },
	},
	RepairHammer = {
		icon = "rbxassetid://94401710904380", -- assets/item-icons/RepairHammer.png
		name = "ค้อนซ่อม", kind = "consumable", weight = 3, stackSize = 15,
		use = { stat = "repair", amount = 1 }, -- restores the equipped armor's durability
	},

	--------------------------------------------------------------------------
	-- Junk. No effect yet; they exist to be gathered, carried and sold later.
	--------------------------------------------------------------------------
	Bone = { icon = "", name = "กระดูก", kind = "junk", weight = 1, stackSize = 99, value = 2 }, -- assets/item-icons/Bone.png
	WoodScrap = { icon = "rbxassetid://140646776701721", name = "เศษไม้", kind = "junk", weight = 1.5, stackSize = 99, value = 1 },
	Stone = { icon = "rbxassetid://111540893837307", name = "ก้อนหิน", kind = "junk", weight = 2.5, stackSize = 99, value = 1 },

	-- Gathered materials. Priced and weighted by where they come from: fibre is picked off a bush
	-- anywhere, herbs need looking for, ore has to be mined, and crystal only grows in the caves. The
	-- gathering tags in docs/design/04-gameplay-hooks.md already name these as resources, so the catalog
	-- entries exist before the system that drops them rather than after.
	IronOre = { icon = "", name = "แร่เหล็ก", kind = "junk", weight = 3, stackSize = 99, value = 6 }, -- assets/item-icons/IronOre.png
	Fiber = { icon = "", name = "เส้นใย", kind = "junk", weight = 0.3, stackSize = 99, value = 2 }, -- assets/item-icons/Fiber.png
	Herb = { icon = "", name = "สมุนไพร", kind = "junk", weight = 0.4, stackSize = 99, value = 4 }, -- assets/item-icons/Herb.png
	Crystal = { icon = "", name = "คริสตัล", kind = "junk", weight = 1.2, stackSize = 99, value = 15 }, -- assets/item-icons/Crystal.png
}

function ItemCatalog.Get(id)
	return ItemCatalog.Items[id]
end

function ItemCatalog.Exists(id)
	return ItemCatalog.Items[id] ~= nil
end

-- Weapons and armor carry durability, so they can never stack; everything else stacks by its own limit.
function ItemCatalog.StackSize(id)
	local item = ItemCatalog.Items[id]
	return item and item.stackSize or 1
end

return ItemCatalog
