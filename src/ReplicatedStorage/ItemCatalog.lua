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
-- All three pure data, and the only things this file requires. See ItemCatalog.IsSellable for what they are read
-- for and why the direction of the dependency matters.
local CraftConfig = require(script.Parent.CraftConfig)
local ShopConfig = require(script.Parent.ShopConfig)
local MailConfig = require(script.Parent.MailConfig)
local PremiumConfig = require(script.Parent.PremiumConfig) -- ข้อมูลล้วนเหมือนกัน ห้าม require ไฟล์นี้กลับ

local ItemCatalog = {}

-- Consuming takes time: the effect lands when the animation finishes, not when the button is pressed.
-- Long enough to be a real commitment in a fight, short enough not to feel like a punishment.
ItemCatalog.ConsumeSeconds = 3

-- ⌛ = ยังไม่มีรูปของตัวเอง
--
-- ผู้ใช้สั่ง (2026-09-18): ไอเทมที่ **ไม่มีรูป** หรือ **ยืมรูปของไอเทมอื่นมาใช้** ให้ขึ้นนาฬิกาทรายแทน
-- วิธีบอกคือ `icon = ""` แล้ว `UI/ItemIcon.Apply` แขวน ⌛ ให้เองทุกหน้าต่าง — อย่าใส่อีโมจิลงช่อง `icon`
-- ตรงๆ มันเป็น ImageLabel ไม่ใช่ข้อความ
--
-- ตอนนี้ที่เป็น ⌛ อยู่: เครื่องมือทอง 4 ชิ้น (ยืมรูปตัวธรรมดา) · ยาใหญ่ (ยืมขวดยาฮีล) · อาหารพรีเมียม 3 ชิ้น
-- (ยืมรูปแอปเปิล) · สกิน/แฟชั่น/ออร่า 15 ชิ้น (ยืมรูปเดียวกันทั้งหมด) รวม 23 ชิ้น
-- **อัปโหลดรูปจริงเมื่อไหร่ ใส่ id กลับเข้าไปที่ `icon` ชิ้นนั้น แล้วมันหายไปเอง ไม่ต้องแก้ที่อื่นเลย**

-- ของบางชิ้นใช้เวลานานกว่านั้น: กล่องปฐมพยาบาลมีท่าพันแผลห้าจังหวะตามคู่มือภาพ (ล้าง สำลี ผ้าก๊อซ กด พัน)
-- ซึ่งเบียดกันจนดูไม่ออกถ้ามีแค่สามวินาที ใส่ `use.holdSeconds` ที่ไอเทมเพื่อยืดเฉพาะชิ้นนั้น
--
-- **ไม่ใช้ชื่อ `use.seconds`** ชื่อนั้นมีเจ้าของแล้ว: มันคือความยาวของบัพที่อาหารให้ (สเต็ก 15 นาที)
function ItemCatalog.HoldSeconds(id)
	local item = ItemCatalog.Items[id]
	local hold = item and item.use and item.use.holdSeconds
	return hold or ItemCatalog.ConsumeSeconds
end

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
		skill = { id = "LungeSlash", name = "พุ่งฟัน", manaCost = 1, cooldown = 6 },
	},
	Bow = {
		icon = "rbxassetid://100309435801424", -- assets/item-icons/Bow.png
		name = "ธนู", kind = "weapon", weight = 4, stackSize = 1,
		damage = 12, range = 6, -- melee fallback; the skill is the real attack
		maxDurability = 100,
		skill = { id = "ScatterShot", name = "ยิงกระจาย", manaCost = 1, cooldown = 6 },
	},
	Staff = {
		icon = "rbxassetid://86359404715162", -- assets/item-icons/Staff.png
		name = "ไม้คทา", kind = "weapon", weight = 5, stackSize = 1,
		damage = 10, range = 6,
		maxDurability = 90,
		skill = { id = "GroupHeal", name = "ฮีลหมู่", manaCost = 1, cooldown = 6 },
	},
	Spellbook = {
		icon = "rbxassetid://98989238832991", -- assets/item-icons/Spellbook.png
		name = "สมุดเวท", kind = "weapon", weight = 3, stackSize = 1,
		damage = 8, range = 5,
		maxDurability = 80,
		skill = { id = "Fireball", name = "ลูกไฟ", manaCost = 1, cooldown = 6 },
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
	-- **เครื่องมือกับปืนไม่มีสกิล Q** (ผู้ใช้สั่ง 2026-09-20) — ของพวกนี้ไม่ใช่อาวุธที่เอาไว้สู้
	-- `WeaponSkills` ปฏิเสธเงียบๆ เหมือนตอนมือเปล่าอยู่แล้ว (`if not item.skill then return end`)
	-- Two-handed, slow, and it leaves whatever it lands on seeing stars. The stun is the reason to carry
	-- something this slow: one swing every two seconds is a bad trade for damage alone.
	Greatsword = {
		icon = "rbxassetid://109719252233813", -- Greatsword (ภาพจริงใน decal 131042286719658)
		name = "ดาบใหญ่", kind = "weapon", weight = 14, stackSize = 1,
		value = 0, sellable = false,
		damage = 42, range = 9,
		-- Heavier than the sword's 120: it is the thing you gamble a 25% craft for.
		maxDurability = 200,
		-- The SAME skill as the sword, by the user's instruction: one leap, one sound, one handler. Only the
		-- name on the button differs, because a greatsword lunging is not called the same thing.
		skill = { id = "LungeSlash", name = "ฟันสังหาร", manaCost = 1, cooldown = 6 },
	},

	-- โล่ไอน้ำ (ผู้ใช้สั่ง 2026-09-20) — รัดอยู่กับท่อนแขนขวา ไม่ได้ถืออยู่ในมือ
	--
	-- ตีด้วยท่าต่อยธรรมดา (ดู `CombatConfig.Weapons.Shield`) แต่ทุกหมัดทำให้คนโดนช้าลง **2 วินาที** —
	-- อาวุธที่ไม่ได้ชนะด้วยดาเมจ แต่ชนะด้วยการที่อีกฝ่ายหนีไม่พ้น
	-- ดาเมจต่อหมัด 10 -> **20** (ผู้ใช้สั่ง 2026-09-20) ยังต่ำกว่าดาบ 18 ต่อฟันเมื่อคิดว่าหมัดแลกมากับ
	-- การไม่มีระยะเอื้อม: 5.5 สตัดคือต้องยืนติดตัวคนโดน
	Shield = {
		icon = "rbxassetid://98926854898318", -- โล่ไอน้ำ (ภาพจริงอยู่ใน decal 128590551137093)
		name = "โล่ไอน้ำ", kind = "weapon", weight = 10, stackSize = 1,
		damage = 20, range = 5.5,
		-- อึดที่สุดในบรรดาอาวุธ: มันคือของที่เอาไว้รับ ไม่ใช่ของที่เอาไว้ฟาด
		maxDurability = 240,
		skill = { id = "Bulwark", name = "คำท้าทองคำ", manaCost = 1, cooldown = 6 },
	},

	Axe = {
		icon = "rbxassetid://94868056279785",
		name = "ขวาน", kind = "weapon", weight = 5, stackSize = 1,
		damage = 14, range = 7,
		maxDurability = 50, -- ครึ่งหนึ่งของเดิม (100) ผู้ใช้สั่ง 2026-09-20
		gathers = "axe",
	},
	Pickaxe = {
		icon = "rbxassetid://71353632810064",
		name = "อีเต้อ", kind = "weapon", weight = 6, stackSize = 1,
		damage = 13, range = 7,
		maxDurability = 55, -- ครึ่งหนึ่งของเดิม (110) ผู้ใช้สั่ง 2026-09-20
		gathers = "pickaxe",
	},
	Shovel = {
		icon = "rbxassetid://111182494345005",
		name = "พลั่ว", kind = "weapon", weight = 4, stackSize = 1,
		damage = 11, range = 7,
		maxDurability = 45, -- ครึ่งหนึ่งของเดิม (90) ผู้ใช้สั่ง 2026-09-20
		gathers = "shovel",
	},

	Pistol = {
		icon = "rbxassetid://76734561926426",
		name = "ปืน", kind = "weapon", weight = 4, stackSize = 1,
		-- The shot does no damage at all. It floors whoever it hits for five seconds, which is a far
		-- nastier thing to do to someone than taking a slice of their health -- and it keeps the guard's
		-- pistol a tool of arrest rather than a way to kill people faster than a sword.
		damage = 0, range = 6,
		maxDurability = 120,
	},
	-- สไนเปอร์ (ผู้ใช้สั่ง 2026-09-25) — ดาเมจคิดเป็นสัดส่วนของเลือดเต็ม ไม่ใช่ตัวเลข `damage` จึงเป็น 0
	-- เลขจริงอยู่ที่ `CombatConfig.Weapons.Sniper` (pierceFraction ใส่คน · mobDamage ใส่มอน)
	-- ไอคอน: ผู้ใช้ให้ decal 72482920404625 → image ที่ resolve แล้ว
	Sniper = {
		icon = "rbxassetid://99786745255231",
		name = "สไนเปอร์", kind = "weapon", weight = 6, stackSize = 1,
		damage = 0, range = 6,
		maxDurability = 120,
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
	Bread = { food = true,
		icon = "rbxassetid://70954901802854", -- assets/item-icons/Bread.png
		name = "ขนมปัง", kind = "consumable", weight = 0.5, stackSize = 7, bagStacks = 1,
		use = { stat = "hunger", amount = 35 },
		useSound = "Eat",
	},
	--------------------------------------------------------------------------
	-- ปลาหายากประจำเขต 9 ชนิด (2026-09-17)
	--
	-- **ไอคอนเป็นภาพจริงที่แกะจาก Decal แล้ว** ทั้งเก้าตัวที่ผู้ใช้ส่งมาเป็น Decal เหมือนทุกครั้ง
	-- ไอดี Decal เดิมอยู่ในคอมเมนต์ท้ายบรรทัด
	--
	-- **stackSize = 1 ทุกตัว** เพราะปลาหายากมีน้ำหนักติดมาเป็นรายตัว (meta.kg) เหมือนปลาธรรมดาที่ตัวใหญ่
	-- ของสองตัวที่น้ำหนักต่างกันรวมกองกันไม่ได้ ไม่งั้นน้ำหนักตัวหนึ่งจะหายไป
	--
	-- ราคาเรียงตามความหายากในตาราง FishingConfig: ตัวที่เจอยากกว่าแพงกว่า
	--------------------------------------------------------------------------
	GreenSnakehead = {
		icon = "rbxassetid://92421219089417", -- decal 81266942951705
		name = "ปลาหมอเขียว", kind = "junk", weight = 2, stackSize = 1, value = 45,
	},
	TigerBarb = {
		icon = "rbxassetid://70521491422033", -- decal 74421872477889
		name = "ปลาเสือลาย", kind = "junk", weight = 2, stackSize = 1, value = 55,
	},
	MilkFish = {
		icon = "rbxassetid://110061776157428", -- decal 84811441087104
		name = "ปลานวลจันทร์", kind = "junk", weight = 2.5, stackSize = 1, value = 60,
	},
	SilverSalmon = {
		icon = "rbxassetid://107178413349147", -- decal 109517786154577
		name = "แซลมอนเกล็ดเงิน", kind = "junk", weight = 3, stackSize = 1, value = 90,
	},
	RainbowFish = {
		icon = "rbxassetid://78477223340132", -- decal 95597970172817
		name = "ปลารุ้ง", kind = "junk", weight = 2, stackSize = 1, value = 120,
	},
	LargemouthBass = {
		icon = "rbxassetid://124860667615523", -- decal 133541589685275
		name = "ปลาบาสปากกว้าง", kind = "junk", weight = 3.5, stackSize = 1, value = 80,
	},
	Sturgeon = {
		icon = "rbxassetid://104343467448610", -- decal 85454181642353
		name = "ปลาสเตอร์เจียน", kind = "junk", weight = 5, stackSize = 1, value = 200,
	},
	Tanker = {
		icon = "rbxassetid://83993996323110", -- decal 115419101737549
		name = "ปลาแทงค์เกอร์", kind = "junk", weight = 6, stackSize = 1, value = 260,
	},
	SwordFish = {
		icon = "rbxassetid://134539526744130", -- decal 136175789012021
		name = "ปลาดาบ", kind = "junk", weight = 4.5, stackSize = 1, value = 320,
	},

	-- แอปเปิลที่ร่วงจากต้นไม้ตอนตัดไม้
	--
	-- **ครึ่งหนึ่งของขนมปังพอดี** ตามที่ผู้ใช้กำหนด: ขนมปังเติมความหิว 35 แอปเปิลจึงเติม 18 (ปัดจาก 17.5)
	-- ถ้าวันไหนขนมปังเปลี่ยนค่า ต้องมาแก้ที่นี่ด้วย — ตัวเลขสองตัวนี้ผูกกันด้วยการตัดสินใจ ไม่ใช่ด้วยโค้ด
	--
	-- เบากว่าขนมปังและสแตคได้มากกว่า เพราะมันคือของที่ได้มาฟรีระหว่างทำอย่างอื่น ไม่ใช่ของที่ตั้งใจซื้อ
	Apple = { food = true,
		icon = "rbxassetid://74006451323045", -- แอปเปิล (ภาพจริงใน decal 71786438182204)
		name = "แอปเปิล", kind = "consumable", weight = 0.3, stackSize = 99,
		value = 5,
		use = { stat = "hunger", amount = 18 },
		useSound = "Eat",
	},
	Water = { food = true,
		icon = "rbxassetid://128474051932298", -- assets/item-icons/Water.png
		name = "น้ำเปล่า", kind = "consumable", weight = 1, stackSize = 5, bagStacks = 1,
		use = { stat = "mana", amount = 1 },
		useSound = "Drink",
	},
	HealthPotion = { medicine = true,
		icon = "rbxassetid://70766990190847", -- assets/item-icons/HealthPotion.png
		name = "ยาฮีล", kind = "consumable", weight = 0.8, stackSize = 5, bagStacks = 1,
		use = { stat = "hp", amount = 40 },
		useSound = "Drink",
	},
	-- ยาใหญ่: ต้มที่เครื่องต้มยาเท่านั้น (สมุนไพร 30 เส้นใย 15 กระดูก 3 เศษไม้ 5) ใช้แล้ว **เลือดเต็มหลอด**
	-- ไม่ใช่ตัวเลขตายตัวอย่างยาฮีล จึงคุ้มเท่ากันทุกเลเวลแม้เลือดสูงสุดจะโตตามเลเวล
	-- ไอคอนยังใช้ขวดยาฮีลไปก่อน (placeholder) เปลี่ยนเมื่อผู้ใช้อัปโหลดรูปขวดใหญ่
	GreatPotion = { medicine = true,
		icon = "rbxassetid://87021272690877", -- placeholder: ขวดเดียวกับยาฮีล
		name = "ยาใหญ่", kind = "consumable", weight = 1.5, stackSize = 3, bagStacks = 1, value = 0, sellable = false,
		use = { stat = "healfull" },
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

	--------------------------------------------------------------------------
	-- ของที่ได้จากสัตว์ มอนสเตอร์ แร่ และไร่นา (ชุดใหญ่ 2026-09-17)
	--
	-- **ไอคอนทุกตัวเป็นภาพจริงที่แกะออกมาจาก Decal แล้ว** ไอดีที่ผู้ใช้ส่งมาทั้ง 16 ตัวเป็น Decal
	-- (AssetTypeId 13) ซึ่งใส่ใน ImageLabel แล้วไม่ขึ้นอะไรเลย ไอดีข้างล่างคือ Texture ข้างในของมัน
	-- คอมเมนต์ท้ายบรรทัดคือไอดี Decal เดิม เผื่อต้องตามกลับ
	--
	-- ราคาเรียงตามความหายาก: ของจากสัตว์เลี้ยงถูกที่สุด (เดินไปกด E ได้เรื่อยๆ) ของจากมอนแพงกว่า
	-- (ต้องสู้) และแร่หายากแพงที่สุด
	--------------------------------------------------------------------------

	-- จากสัตว์เลี้ยง กด E เอาได้ ไม่ต้องสู้
	Egg = { icon = "rbxassetid://77756159415394", name = "ไข่", kind = "junk", weight = 0.4, stackSize = 99, value = 4 }, -- decal 72541945471408
	Milk = { icon = "rbxassetid://93868283165879", name = "นม", kind = "junk", weight = 1, stackSize = 99, value = 6 }, -- decal 136906013299230
	Leather = { icon = "rbxassetid://104360664825228", name = "หนังสัตว์", kind = "junk", weight = 1.5, stackSize = 99, value = 12 }, -- decal 137703605622656
	Wool = { icon = "rbxassetid://126262913039947", name = "ขนแกะ", kind = "junk", weight = 0.8, stackSize = 99, value = 9 }, -- decal 135550468349183
	Meat = { icon = "rbxassetid://115841522653821", name = "เนื้อ", kind = "junk", weight = 1.5, stackSize = 99, value = 8 }, -- decal 84058385063892

	-- จากมอนสเตอร์ ต้องฆ่าถึงจะได้
	Claw = { icon = "rbxassetid://135488469977700", name = "เล็บสัตว์ร้าย", kind = "junk", weight = 0.5, stackSize = 99, value = 14 }, -- decal 140136897541150
	RottenMeat = { icon = "rbxassetid://129554418128212", name = "เนื้อเน่า", kind = "junk", weight = 1.2, stackSize = 99, value = 5 }, -- decal 116771055471302
	BatGuano = { icon = "rbxassetid://91346287330461", name = "มูลค้างคาว", kind = "junk", weight = 0.6, stackSize = 99, value = 7 }, -- decal 84357488942571
	-- ศิลาเวท: หล่นจากทั้งหุ่นไขลานและโกเลมหิน เป็นวัสดุสายเวทที่ไม่ต้องขุด
	RuneStone = { icon = "rbxassetid://89939682004809", name = "ศิลาเวท", kind = "junk", weight = 2, stackSize = 99, value = 30 }, -- decal 117325820864673

	-- แร่ เรียงจากถูกไปแพง
	SilverOre = { icon = "rbxassetid://92203511042577", name = "แร่เงิน", kind = "junk", weight = 2.5, stackSize = 99, value = 35 }, -- decal 135246232974527
	GoldOre = { icon = "rbxassetid://98685006181913", name = "แร่ทอง", kind = "junk", weight = 3, stackSize = 99, value = 70 }, -- decal 106262919143881
	-- แร่เวทมนตร์: ได้จากทั้งสายแร่เวทและจากวิญญาณ (Wraith) สองทางเพราะมันเป็นวัสดุสายเวทตัวหลัก
	MagicOre = { icon = "rbxassetid://83959186215687", name = "แร่เวทมนตร์", kind = "junk", weight = 2, stackSize = 99, value = 90 }, -- decal 120727145622733
	Diamond = { icon = "rbxassetid://88276561126599", name = "เพชร", kind = "junk", weight = 1, stackSize = 99, value = 150 }, -- decal 80982434115389

	-- จากไร่นา — **ขึ้นราคา 4 เท่า 2026-09-23** (ผู้ใช้สั่ง: 5/6/4 -> 20/24/16)
	--
	-- เมล็ดพันธุ์บนเกาะขึ้นราคา 50 -> 300 (6 เท่า) โดยที่ผลผลิตไม่ขยับตาม แปลงผักจึงขาดทุนจริง:
	-- เมล็ด 9 เม็ด = 2,700 เหรียญ ปลูกจนเมล็ดหมด (56 ครั้ง เพราะคืน 0.84 เม็ด/ครั้ง) ขายได้ 891 = คืนแค่ 33%
	-- ที่ 4 เท่า: ขายได้ 2,737 = เสมอตัวพอดี · กำไรจริงของแปลงคือ EXP กับของป้อนครัว/ยา
	--
	-- ⚠️ **กระทบเกมหลักด้วย** นาข้าว/แปลงผัก/สมุนไพรทั้งแมพได้เงินขึ้น 4 เท่าตาม — `value`
	-- เป็นของทั้งเกม แยกราคาเฉพาะเกาะไม่ได้ · ถ้าวันไหนเกมหลักเฟ้อ ทางที่ถูกคือลดราคาเมล็ดกลับ
	-- (เสมอตัวที่ 99) ไม่ใช่ขึ้นราคาผักต่อ
	Vegetable = { icon = "rbxassetid://97077438082748", name = "ผักรวม", kind = "junk", weight = 1, stackSize = 99, value = 20 }, -- decal 97957712627842
	Wheat = { icon = "rbxassetid://138650681258991", name = "ข้าว", kind = "junk", weight = 1, stackSize = 99, value = 24 }, -- decal 77562812947089
	MagicBranch = { icon = "rbxassetid://122305408113810", name = "กิ่งเวทมนตร์", kind = "junk", weight = 0.8, stackSize = 99, value = 25 }, -- decal 105616416463980

	-- Gathered materials. Priced and weighted by where they come from: fibre is picked off a bush
	-- anywhere, herbs need looking for, ore has to be mined, and crystal only grows in the caves. The
	-- gathering tags in docs/design/04-gameplay-hooks.md already name these as resources, so the catalog
	-- entries exist before the system that drops them rather than after.
	IronOre = { icon = "rbxassetid://85652195246479", name = "แร่เหล็ก", kind = "junk", weight = 3, stackSize = 99, value = 6 }, -- assets/item-icons/IronOre.png
	Fiber = { icon = "rbxassetid://89290089367939", name = "เส้นใย", kind = "junk", weight = 0.3, stackSize = 99, value = 2 }, -- assets/item-icons/Fiber.png
	Herb = { icon = "rbxassetid://87753072302137", name = "สมุนไพร", kind = "junk", weight = 0.4, stackSize = 99, value = 16 }, -- assets/item-icons/Herb.png
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
	Silver = { icon = "rbxassetid://109436274068062", -- assets/item-icons/Silver.png
		name = "ซิลเวอร์", kind = "junk", weight = 0.02, stackSize = 9999, value = 1, sellable = false },
	-- The consolation prize for a craft that failed: a gold coin stamped with a broken hammer. Spent at the
	-- smith's "unlucky" page, which is the only thing in the game that takes them.
	Insignia = { icon = "rbxassetid://130387196273181", -- assets/item-icons/coin.png
		name = "เหรียญตราค้อนพัง", kind = "junk", weight = 0.05, stackSize = 9999, value = 0, sellable = false },
	Blueprint = { icon = "rbxassetid://74314329321327", -- assets/item-icons/print.png
		name = "แบบแปลน", kind = "junk", weight = 0.3, stackSize = 16, value = 0, sellable = false },
	-- Also the fuel every vehicle burns: one lump is Config.FuelPerCoal units in the tank.
	Coal = { icon = "rbxassetid://102046178380928", -- assets/item-icons/coal.png
		name = "ถ่านหิน", kind = "junk", weight = 2, stackSize = 16, value = 0, sellable = false },
	Chemical = { icon = "rbxassetid://126730826846983", -- assets/item-icons/chemical.png
		name = "สารเคมี", kind = "junk", weight = 1, stackSize = 8, value = 0, sellable = false },
	GearSpare = { icon = "rbxassetid://97077095423077", -- assets/item-icons/gear.png
		name = "เฟืองอะไหล่", kind = "junk", weight = 1.5, stackSize = 8, value = 0, sellable = false },

	--------------------------------------------------------------------------
	-- Car parts. What a failed key-craft leaves you holding. Six of them, and a full set trades for a key
	-- outright -- so a run of bad luck at the bench still walks towards the same door, just the long way.
	--------------------------------------------------------------------------
	Fueltank = { icon = "rbxassetid://124722881490009", name = "ถังน้ำมัน",
		-- Fueltank (ภาพจริงใน decal 112029627599215)
		kind = "junk", weight = 4, stackSize = 8, value = 0, sellable = false },
	GearCar = { icon = "rbxassetid://130688996186435", name = "เกียร์รถ",
		-- GearCar (ภาพจริงใน decal 120419184642622)
		kind = "junk", weight = 3, stackSize = 8, value = 0, sellable = false },
	Mattress = { icon = "rbxassetid://132598216306109", name = "เบาะรถ",
		-- Mattress (ภาพจริงใน decal 123768545191804)
		kind = "junk", weight = 3, stackSize = 8, value = 0, sellable = false },
	Pipe = { icon = "rbxassetid://74455919915558", name = "ท่อไอเสีย",
		-- Pipe (ภาพจริงใน decal 127934134379642)
		kind = "junk", weight = 2, stackSize = 8, value = 0, sellable = false },
	Steering = { icon = "rbxassetid://106026943102551", name = "พวงมาลัย",
		-- Steering (ภาพจริงใน decal 138083283670733)
		kind = "junk", weight = 2.5, stackSize = 8, value = 0, sellable = false },
	Wheel = { icon = "rbxassetid://80535428552755", name = "ล้อรถ",
		-- Wheel (ภาพจริงใน decal 96711288685556)
		kind = "junk", weight = 5, stackSize = 8, value = 0, sellable = false },

	--------------------------------------------------------------------------
	-- จักรยานล้อเดียว ของแจกที่ทุกคนมีตั้งแต่เริ่ม
	--
	-- ไม่ใช่กุญแจ (kind = "key" ผูกกับระบบโรงรถทั้งชุด) แต่เป็นของกดใช้ที่เรียกพาหนะออกมา กดอีกทีก็เก็บ
	-- ทิ้งไม่ได้และเก็บเข้าคลังไม่ได้ เพราะทุกคนต้องมีติดตัวเสมอ -- หายแล้วจะไม่มีทางได้คืน
	--------------------------------------------------------------------------
	Monowheel = {
		icon = "rbxassetid://95395940932813", -- Monowheel (ภาพจริงใน decal 116009846089971)
		name = "จักรยาน", kind = "consumable",
		weight = 0, stackSize = 1, value = 0, sellable = false,
		use = { stat = "monowheel", amount = 1 },
	},

	--------------------------------------------------------------------------
	-- The one thing that survives a death.
	--
	-- Dying resets the level to 1 and the class to Villager. Carrying this spends ONE of them to keep both,
	-- once. It does not stack: two of them are two separate deaths survived, and a stack would let a single
	-- slot hold a dozen lives, which is the opposite of what makes it worth finding.
	--------------------------------------------------------------------------
	GuardianCharm = {
		icon = "rbxassetid://107664753644079", -- angle (ภาพจริงใน decal 135772507432405)
		name = "เครื่องรางคุ้มครอง", kind = "junk",
		weight = 0.5, stackSize = 1, value = 0, sellable = false,
	},

	--------------------------------------------------------------------------
	-- Treasure chests, as things you carry. Using one drops a chest near you; opening that chest is where
	-- the loot is. They are consumables whose effect is "a chest appears", which is why `use.stat` names the
	-- chest tier rather than a vital.
	--------------------------------------------------------------------------
	Chest_Wood = { icon = "rbxassetid://109904396721698", name = "หีบไม้",
		-- Chest_Wood (ภาพจริงใน decal 101268926197446)
		kind = "consumable", weight = 6, stackSize = 8, value = 0, sellable = false,
		use = { stat = "chest", amount = 1, tier = "Chest_Wood" } },
	Chest_Ironbound = { icon = "rbxassetid://78626070188001", name = "หีบตีเหล็ก",
		-- Chest_Ironbound (ภาพจริงใน decal 135086673189833)
		kind = "consumable", weight = 8, stackSize = 8, value = 0, sellable = false,
		use = { stat = "chest", amount = 1, tier = "Chest_Ironbound" } },
	Chest_Silver = { icon = "rbxassetid://81887415402473", name = "หีบเงิน",
		-- Chest_Silver (ภาพจริงใน decal 70684618691110)
		kind = "consumable", weight = 8, stackSize = 8, value = 0, sellable = false,
		use = { stat = "chest", amount = 1, tier = "Chest_Silver" } },
	Chest_Gold = { icon = "rbxassetid://110326842858537", name = "หีบทอง",
		-- Chest_Gold (ภาพจริงใน decal 134759403444063)
		kind = "consumable", weight = 10, stackSize = 8, value = 0, sellable = false,
		use = { stat = "chest", amount = 1, tier = "Chest_Gold" } },
	-- ⌛ ยังไม่มีรูปของตัวเอง — ยืมรูปหีบทองไปก่อน (เพิ่ม 2026-09-23 พร้อมรางวัลจบแมตช์ PVP)
	-- อัปโหลดรูปหีบเวทมนตร์เมื่อไหร่ ใส่ id กลับมาที่ `icon` ตรงนี้ที่เดียว แล้วนาฬิกาทรายหายเอง
	Chest_Magic = { icon = "", name = "หีบเวทมนตร์",
		kind = "consumable", weight = 10, stackSize = 8, value = 0, sellable = false,
		use = { stat = "chest", amount = 1, tier = "Chest_Magic" } },

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

	--------------------------------------------------------------------------
	-- ของร้านพรีเมียม (ซื้อด้วยเพชร ดู PremiumConfig) — ขายให้บาร์นาบีไม่ได้ทั้งหมด
	--
	-- **เครื่องมือทอง** ทำงานเหมือนตัวธรรมดาทุกอย่าง (gathers/fishing) แต่ `unbreakable` ไม่สึก
	-- และ **ไม่มีสกิล Q เหมือนตัวธรรมดา** (ผู้ใช้สั่ง 2026-09-20) จ่ายเพชรแล้วไม่ต้องสึก ไม่ได้แปลว่าได้ท่าพิเศษ
	-- `prefab` บอก WeaponVisuals ว่าใช้โมเดลถือของตัวไหน (ยังไม่มีโมเดลทองแยก) `tint` ย้อมเป็นทอง
	--------------------------------------------------------------------------
	GoldAxe = { icon = "rbxassetid://112706662089183", name = "ขวานทอง", kind = "weapon", weight = 5, -- decal 96307353249988
		stackSize = 1, value = 0, sellable = false, damage = 14, range = 7, maxDurability = 100,
		unbreakable = true, gathers = "axe", prefab = "Axe", tint = Color3.fromRGB(230, 190, 80) },
	GoldPickaxe = { icon = "rbxassetid://104069293674602", name = "อีเต้อทอง", kind = "weapon", weight = 6, -- decal 109840986974799
		stackSize = 1, value = 0, sellable = false, damage = 13, range = 7, maxDurability = 110,
		unbreakable = true, gathers = "pickaxe", prefab = "Pickaxe", tint = Color3.fromRGB(230, 190, 80) },
	GoldShovel = { icon = "rbxassetid://106548425269373", name = "พลั่วทอง", kind = "weapon", weight = 4, -- decal 100681966190887
		stackSize = 1, value = 0, sellable = false, damage = 11, range = 7, maxDurability = 90,
		unbreakable = true, gathers = "shovel", prefab = "Shovel", tint = Color3.fromRGB(230, 190, 80) },
	GoldFishingRod = { icon = "rbxassetid://76978041372503", name = "คันเบ็ดทอง", kind = "weapon", weight = 3, -- decal 78554973201530
		stackSize = 1, value = 0, sellable = false, damage = 3, range = 6, maxDurability = 80,
		unbreakable = true, fishing = true, prefab = "FishingRod", tint = Color3.fromRGB(230, 190, 80) },

	-- อาหารเสริมบัพ: ซื้อจากร้านพรีเมียมหรือได้จากพาส บัพอยู่ในหน่วยความจำ (Vitals.AddBuff) ออกเกมแล้วหาย
	--
	-- **สั้นแต่แรง** (ผู้ใช้กำหนด 2026-09-19 — เดิมบัพเดียว 30-60 นาที): สองมื้อให้บัพเกือบทุกอย่าง
	-- (ไม่หิว/ไม่เหนื่อย/มานาไม่ลด/เกราะไม่ลด) แต่นับเป็นนาที ไม่ใช่ชั่วโมง ของแบบนี้จึงเป็น
	-- "ของกินก่อนลุยบอส" ไม่ใช่ "ซื้อทีเดียวแล้วลืมระบบหิวไปทั้งเซสชัน"
	--
	-- **ไม่มีอาหารชิ้นไหนให้ "เลือดไม่ลด" อีกแล้ว** (ผู้ใช้สั่ง 2026-09-20) — กลุ่ม `"food"` ใน
	-- `Vitals.BuffGroups` คือทุกบัพยกเว้นเลือด · บัพใหม่ในอนาคตเติมที่นั่นแล้วอาหารได้ไปด้วยเอง
	Feast_Hearty = { food = true, icon = "rbxassetid://90476697790239", name = "มื้อใหญ่นักเดินทาง", kind = "consumable", -- decal 135271030319763
		weight = 0.5, stackSize = 7, bagStacks = 1, value = 0, sellable = false,
		use = { stat = "meal", hunger = true, buff = "food", seconds = 3 * 60 } },
	-- ยาชูกำลัง: ไม่ใช่อาหาร ไม่ทำให้อิ่ม — กันสองหลอดที่หมดระหว่างสู้ (มานา 💙 สตามินา 💛)
	-- เดิมมี "เลือดไม่ลด" ด้วย ผู้ใช้สั่งเอาออก 2026-09-20 · เวลาเท่าเดิมคือหนึ่งนาที
	Tonic_Vigor = { food = true, icon = "rbxassetid://93573276910747", name = "ยาชูกำลัง", kind = "consumable", -- decal 124890963484629
		weight = 0.5, stackSize = 5, bagStacks = 1, value = 0, sellable = false,
		use = { stat = "buff", buff = { "noMana", "noStamina" }, seconds = 60 } },
	Feast_Royal = { food = true, icon = "rbxassetid://79094106381921", name = "งานเลี้ยงราชสำนัก", kind = "consumable", -- decal 117700288552786
		weight = 0.8, stackSize = 7, bagStacks = 1, value = 0, sellable = false,
		use = { stat = "meal", hunger = true, buff = "food", seconds = 10 * 60 } },

	--------------------------------------------------------------------------
	-- สกินอาวุธ (จากกาชา) `skinFor` = อาวุธที่ติดตั้งได้ ติดตั้งแล้วเก็บ id ไว้ใน meta.skin ของอาวุธชิ้นนั้น
	-- `model` = ชื่อโมเดลใน ReplicatedStorage.WOLD_Skins ถ้ามี (ผู้ใช้วางเอง) ไม่มีก็ย้อมสี/วัสดุโมเดลเดิม
	--------------------------------------------------------------------------
	Skin_Sword_Ember = { icon = "rbxassetid://124510978144473", name = "สกินดาบ: เพลิงแดง", kind = "skin", -- decal 138775001311906
		skinFor = "Sword", rarity = "rare", weight = 0.1, stackSize = 99, value = 0, sellable = false,
		tint = Color3.fromRGB(240, 90, 40), material = Enum.Material.Neon },
	Skin_Sword_Frost = { icon = "rbxassetid://98096728560722", name = "สกินดาบ: น้ำแข็ง", kind = "skin", -- decal 88975288660895
		skinFor = "Sword", rarity = "rare", weight = 0.1, stackSize = 99, value = 0, sellable = false,
		tint = Color3.fromRGB(140, 220, 255), material = Enum.Material.Ice },
	Skin_Greatsword_Void = { icon = "rbxassetid://133788314596767", name = "สกินดาบใหญ่: ห้วงมืด", kind = "skin", -- decal 118097164346806
		skinFor = "Greatsword", rarity = "epic", weight = 0.1, stackSize = 99, value = 0, sellable = false,
		tint = Color3.fromRGB(120, 40, 200), material = Enum.Material.Neon },
	Skin_Greatsword_Gold = { icon = "rbxassetid://105858444588905", name = "สกินดาบใหญ่: ทองคำ", kind = "skin", -- decal 137811358215454
		skinFor = "Greatsword", rarity = "legendary", weight = 0.1, stackSize = 99, value = 0, sellable = false,
		tint = Color3.fromRGB(240, 200, 70), material = Enum.Material.Metal },
	Skin_Bow_Vine = { icon = "rbxassetid://79567665061655", name = "สกินธนู: เถาวัลย์", kind = "skin", -- decal 76204120568046
		skinFor = "Bow", rarity = "rare", weight = 0.1, stackSize = 99, value = 0, sellable = false,
		tint = Color3.fromRGB(80, 170, 70), material = Enum.Material.Grass },
	Skin_Pistol_Brass = { icon = "rbxassetid://121895727413795", name = "สกินปืน: ทองเหลือง", kind = "skin", -- decal 95649472327625
		skinFor = "Pistol", rarity = "epic", weight = 0.1, stackSize = 99, value = 0, sellable = false,
		tint = Color3.fromRGB(200, 150, 60), material = Enum.Material.Metal },
	Skin_Staff_Storm = { icon = "rbxassetid://120814003128659", name = "สกินคทา: พายุ", kind = "skin", -- decal 99523853442662
		skinFor = "Staff", rarity = "epic", weight = 0.1, stackSize = 99, value = 0, sellable = false,
		tint = Color3.fromRGB(90, 140, 255), material = Enum.Material.Neon },
	Skin_Spellbook_Blood = { icon = "rbxassetid://133435692028213", name = "สกินสมุดเวท: โลหิต", kind = "skin", -- decal 104468021699307
		skinFor = "Spellbook", rarity = "rare", weight = 0.1, stackSize = 99, value = 0, sellable = false,
		tint = Color3.fromRGB(150, 20, 30), material = Enum.Material.Fabric },

	-- ชุดเกราะแฟชั่น (จากกาชา) ติดตั้งกับเกราะชิ้นไหนก็ได้ เปลี่ยนโมเดลที่สวมโดยไม่แตะค่าเกราะ
	-- `kit` = โมเดลใน workspace.Model_Item — **ชุดจริงเข้าเพลสแล้ว** (ปั้นที่โรงงาน WOLD-Models
	-- `models/fashion_kits.lua` แล้วติดตั้งผ่าน `export/<ชื่อ>.lua`) จึงไม่ต้องยืม Armor_PlateKit อีก
	-- **ห้ามใส่ `tint` กลับเข้ามา** `KitWear` จะเอาไปทาทับทุกชิ้น ชุดจะกลายเป็นก้อนสีเดียว
	Fashion_Knight_Crimson = { icon = "rbxassetid://112606960020319", name = "ชุดอัศวินแดงชาด", kind = "fashion", -- decal 126870390059006
		rarity = "epic", weight = 0.1, stackSize = 99, value = 0, sellable = false,
		kit = "Fashion_Knight_CrimsonKit" },
	Fashion_Ranger_Shadow = { icon = "rbxassetid://94864907326052", name = "ชุดเรนเจอร์เงามืด", kind = "fashion", -- decal 106608070168633
		rarity = "rare", weight = 0.1, stackSize = 99, value = 0, sellable = false,
		kit = "Fashion_Ranger_ShadowKit" },
	Fashion_Royal_Gold = { icon = "rbxassetid://104348258485915", name = "ชุดเกราะราชองครักษ์", kind = "fashion", -- decal 134822973816668
		rarity = "legendary", weight = 0.1, stackSize = 99, value = 0, sellable = false,
		kit = "Fashion_Royal_GoldKit" },

	--------------------------------------------------------------------------
	-- ของประจำตำแหน่ง (`bound`): โผล่ในกระเป๋าเองเมื่อมีสิทธิ์ หายเองเมื่อสิทธิ์หมด ทิ้ง/ให้/เทรด/ฝากไม่ได้
	-- (BoundItems.server เป็นคนเติม-ลบ) ตะหลิวคือกุญแจของครัว: ถือไว้ถึงใช้เตา/เครื่องปั่นได้
	--------------------------------------------------------------------------
	-- **ตะหลิวถือได้จริง** (ผู้ใช้แจ้ง 2026-09-18: กดแล้วถือไม่ได้) — `kind = "weapon"` ในความหมายทางกลไก
	-- อย่างเดียว เหมือนคันเบ็ด: มันต้องลงช่องมือถึงจะโผล่มาอยู่ในมือได้ ดาเมจ 3 เท่าคันเบ็ด (ตีคนด้วยตะหลิว
	-- ไม่ควรเป็นกลยุทธ์) และ `unbreakable` เพราะของประจำตำแหน่งที่พังได้แปลว่าเชฟทำครัวไม่ได้ถาวร
	--
	-- ยังเป็น `bound` เหมือนเดิม: BoundItems กับเตานับ "ช่องมือ" เป็นการมีของด้วยแล้ว ไม่งั้นพอสวมปุ๊บ
	-- ระบบจะคิดว่าตะหลิวหายแล้วแจกใหม่ทันที
	Spatula = { icon = "rbxassetid://122256905985474", name = "ตะหลิวเชฟ", kind = "weapon",
		damage = 3, range = 6, unbreakable = true,
		weight = 0.5, stackSize = 1, value = 0, sellable = false, bound = true, boundClass = "Chef" },
	-- แหวนแคลน: meta.clan = ชื่อแคลน (ไม่ซ้ำกันอยู่แล้ว) ชื่อจึงขึ้นเป็น "แหวนแคลน · ชื่อ"
	--
	-- **กดได้อย่างเดียวคือใส่/ถอดชุดแคลน** ให้คนอื่นไม่ได้ (bound → IsBound กันทั้งที่เซิร์ฟเวอร์และปุ่ม "ให้"
	-- ไม่ขึ้นในเมนูกระเป๋าแล้ว) `use` อยู่บนของที่ไม่ใช่ consumable จึงไม่ถูกใช้หมด — PlayerInventory แยกทาง
	-- ของ stat = "clanoutfit" ออกก่อนถึงทางที่ลบไอเทม เหมือนจักรยานล้อเดียวกับออร่า
	ClanRing = { icon = "rbxassetid://72443695767496", name = "แหวนแคลน", kind = "token",
		weight = 0.1, stackSize = 1, value = 0, sellable = false, bound = true, boundClan = true,
		use = { stat = "clanoutfit" } },

	--------------------------------------------------------------------------
	-- เมนูจากครัว (คราฟที่เตา/เครื่องปั่น) `food` = เก็บในตู้เย็นได้ `use.stat = "meal"` = อิ่มทันที (+บัพ)
	--------------------------------------------------------------------------
	FriedRice = { icon = "rbxassetid://128491566497246", name = "ข้าวผัด", kind = "consumable", food = true,
		weight = 0.6, stackSize = 7, bagStacks = 1, value = 0, sellable = false,
		use = { stat = "meal", hunger = true } },
	Steak = { icon = "rbxassetid://117145640008136", name = "สเต็ก", kind = "consumable", food = true,
		weight = 0.8, stackSize = 7, bagStacks = 1, value = 0, sellable = false,
		use = { stat = "meal", hunger = true, buff = "noHunger", seconds = 15 * 60 } },
	AppleJuice = { icon = "rbxassetid://97122445855806", name = "น้ำแอปเปิล", kind = "consumable", food = true,
		weight = 0.5, stackSize = 7, bagStacks = 1, value = 0, sellable = false,
		use = { stat = "meal", mana = true, buff = "noStamina", seconds = 5 * 60 } },

	-- กล่องเวทมนตร์: เปิดแล้วสุ่มของทุกอย่างที่มีในเซิร์ฟ (เรทใน PremiumConfig.MagicBox)
	MagicBox = { icon = "rbxassetid://109077759074113", name = "กล่องเวทมนตร์", kind = "consumable", -- decal 135550912982213
		weight = 1, stackSize = 10, value = 0, sellable = false,
		use = { stat = "magicbox" } },

	-- กล่องปฐมพยาบาล: **ใครก็ใช้ได้** (ผู้ใช้สั่ง 2026-09-18 — เดิมเป็นของนักบวชเท่านั้น) ใช้แล้วพันแผลตาม
	-- ลำดับในคู่มือภาพ (ล้างแผล → สำลี → ผ้าก๊อซ → กดห้ามเลือด → พันยึด) แล้วเลือดเต็ม
	-- พันแผลเสร็จแล้วได้ **บัพเลือดไม่ลด 10 วินาที** ด้วย (ผู้ใช้สั่ง 2026-09-20) — ช่วงที่ลุกขึ้นมาจาก
	-- การพันแผลกลางวงคือช่วงที่เลือดเต็มแล้วโดนซ้ำจนล้มใหม่ทันที บัพสั้นๆ ตรงนี้คือเวลาให้ถอยออกมา
	FirstAidKit = { icon = "rbxassetid://71486682078701", name = "กล่องปฐมพยาบาล", kind = "consumable",
		medicine = true, weight = 1.2, stackSize = 1, bagStacks = 1, value = 0, sellable = false,
		use = { stat = "firstaid", pose = "bandage", holdSeconds = 6, buff = "noHp", seconds = 10 } },

	-- ออร่า (จากกาชา) ใช้ = เปิด/ปิด เอฟเฟกต์ลอยรอบตัว ไม่ถูกใช้หมด `model` = โมเดลใน ReplicatedStorage.WOLD_Effects
	-- ถ้ามี ไม่มีก็สร้างวงอนุภาคสี `colour` ให้
	Aura_Ember = { icon = "rbxassetid://97308373506888", name = "ออร่าเพลิง", kind = "aura", -- decal 72926330917286
		rarity = "rare", weight = 0.1, stackSize = 1, value = 0, sellable = false,
		colour = Color3.fromRGB(255, 120, 40) },
	Aura_Frost = { icon = "rbxassetid://138815615360906", name = "ออร่าน้ำแข็ง", kind = "aura", -- decal 121440050084959
		rarity = "rare", weight = 0.1, stackSize = 1, value = 0, sellable = false,
		colour = Color3.fromRGB(140, 220, 255) },
	Aura_Void = { icon = "rbxassetid://127724214025681", name = "ออร่าห้วงมืด", kind = "aura", -- decal 136157107778446
		rarity = "epic", weight = 0.1, stackSize = 1, value = 0, sellable = false,
		colour = Color3.fromRGB(140, 60, 220) },
	Aura_Divine = { icon = "rbxassetid://89847370934558", name = "ออร่าเทวะ", kind = "aura", -- decal 122975692106374
		rarity = "legendary", weight = 0.1, stackSize = 1, value = 0, sellable = false,
		colour = Color3.fromRGB(255, 240, 160) },

	--------------------------------------------------------------------------
	-- ของวางบนเกาะฟาร์ม (2026-09-22) — `kind = "placeable"` ทุกชิ้น
	--
	-- ขนาดเป็นช่อง (Footprint) อยู่บนต้นแบบใน ReplicatedStorage.WOLD_Placeables ไม่ใช่ที่นี่ (คำนวณจากกล่องจริง
	-- ตอนสร้าง — mapgen/90_island_placeables.lua) · icon = "" = ⌛ จนกว่าจะมีรูปจริง · ขายคืนไม่ได้ ·
	-- `plot = true` = แปลงปลูก (Island/IslandPlots ต่อปุ่มให้) · ราคาอยู่ที่ ShopConfig.IslandSells
	FarmPlot = { icon = "rbxassetid://135337081423952", name = "แปลงดิน", kind = "placeable", weight = 2, stackSize = 10, value = 0, sellable = false, plot = true },
	Deco_Fence = { icon = "rbxassetid://85772455316409", name = "รั้วไม้", kind = "placeable", weight = 1, stackSize = 20, value = 0, sellable = false },
	Deco_Lamp = { icon = "rbxassetid://99123494309102", name = "โคมไฟไอน้ำ", kind = "placeable", weight = 1, stackSize = 10, value = 0, sellable = false },
	Deco_Bench = { icon = "rbxassetid://100185090469444", name = "ม้านั่ง", kind = "placeable", weight = 1, stackSize = 5, value = 0, sellable = false },
	Deco_FlowerPot = { icon = "rbxassetid://111468730305281", name = "กระถางดอกไม้", kind = "placeable", weight = 1, stackSize = 10, value = 0, sellable = false },
	Deco_Tree = { icon = "rbxassetid://118470948133784", name = "ต้นไม้", kind = "placeable", weight = 2, stackSize = 5, value = 0, sellable = false },
	Deco_Crate = { icon = "rbxassetid://111468730305281", name = "ลังไม้", kind = "placeable", weight = 1, stackSize = 10, value = 0, sellable = false },
	Deco_Barrel = { icon = "rbxassetid://83635511136141", name = "ถังไม้", kind = "placeable", weight = 1, stackSize = 10, value = 0, sellable = false },
	Deco_PathTile = { icon = "rbxassetid://121502177698017", name = "แผ่นทางเดินหิน", kind = "placeable", weight = 0.5, stackSize = 50, value = 0, sellable = false },

	-- ของตกแต่งชิ้นเล็ก (ผู้ใช้สั่ง 2026-09-22) — สแตคเยอะ ราคาถูก ตั้งใจให้ซื้อทีละหลายชิ้นมาโรย
	--
	-- **`spot` บอกว่าเหมาะกับที่ไหน** ("out" นอกบ้าน · "in" ในบ้าน · "both" ได้ทั้งคู่) ร้านเอาไปโชว์เป็นป้าย
	-- กำกับเฉยๆ **ไม่ได้บังคับ** — ระบบวางของตัดสินจากพื้นที่จริง ไม่ได้รู้ว่าตรงไหนคือ "ในบ้าน"
	-- และการห้ามวางเก้าอี้กลางแจ้งก็ไม่ใช่กฎที่ผู้เล่นจะขอบคุณ
	Deco_Rock = { icon = "rbxassetid://99457876178070", name = "ก้อนหิน", kind = "placeable", weight = 1, stackSize = 20, value = 0, sellable = false, spot = "out" },
	Deco_RockBig = { icon = "rbxassetid://118264610759663", name = "หินก้อนใหญ่", kind = "placeable", weight = 2, stackSize = 10, value = 0, sellable = false, spot = "out" },
	Deco_Bush = { icon = "rbxassetid://91305648023477", name = "พุ่มไม้", kind = "placeable", weight = 1, stackSize = 20, value = 0, sellable = false, spot = "out" },
	Deco_Stump = { icon = "rbxassetid://138665904218308", name = "ตอไม้", kind = "placeable", weight = 1, stackSize = 20, value = 0, sellable = false, spot = "out" },
	Deco_Lantern = { icon = "rbxassetid://76303096141550", name = "โคมตั้งพื้น", kind = "placeable", weight = 1, stackSize = 20, value = 0, sellable = false, spot = "both" },
	Deco_Signpost = { icon = "rbxassetid://140181481501106", name = "ป้ายบอกทาง", kind = "placeable", weight = 1, stackSize = 10, value = 0, sellable = false, spot = "out" },
	Deco_Well = { icon = "rbxassetid://123128696064815", name = "บ่อน้ำ", kind = "placeable", weight = 2, stackSize = 3, value = 0, sellable = false, spot = "out" },

	-- **ของป่าจากเกมหลัก** (ผู้ใช้สั่ง 2026-09-23) — โมเดลชุดเดียวกับที่สุ่มโผล่บนผืนดิน เอามาขายเป็น
	-- ของตกแต่งที่ "วางได้ เก็บเกี่ยวได้" เหมือน Deco_Rock/Bush/Tree **แต่เก็บแล้วต้องรอวันใหม่**
	-- (กติกาวันเดียวกับบอร์ดเควส: `QuestConfig.DayNumber()` เที่ยงคืนเวลาไทย)
	-- ราคาสูงกว่าของตกแต่งธรรมดามาก เพราะมันคือแหล่งวัตถุดิบถาวร ไม่ใช่ของประดับ
	Wild_Rock = { icon = "rbxassetid://73024777153946", name = "หินธรรมชาติ", kind = "placeable", weight = 2, stackSize = 10, value = 0, sellable = false, spot = "out" },
	Wild_Herb = { icon = "rbxassetid://107163967815077", name = "พุ่มไม้ป่า", kind = "placeable", weight = 2, stackSize = 10, value = 0, sellable = false, spot = "out" },
	Wild_Tree = { icon = "rbxassetid://90585042806965", name = "ต้นโอ๊ก", kind = "placeable", weight = 3, stackSize = 10, value = 0, sellable = false, spot = "out" },
	Wild_Pine = { icon = "rbxassetid://130965287265276", name = "ต้นสน", kind = "placeable", weight = 3, stackSize = 10, value = 0, sellable = false, spot = "out" },
	Wild_Coal = { icon = "", name = "สายถ่านหิน", kind = "placeable", weight = 3, stackSize = 10, value = 0, sellable = false, spot = "out" },
	Wild_IronOre = { icon = "", name = "สายแร่เหล็ก", kind = "placeable", weight = 3, stackSize = 10, value = 0, sellable = false, spot = "out" },
	Wild_SilverOre = { icon = "", name = "สายแร่เงิน", kind = "placeable", weight = 3, stackSize = 10, value = 0, sellable = false, spot = "out" },
	Wild_Crystal = { icon = "", name = "สายคริสตัล", kind = "placeable", weight = 3, stackSize = 10, value = 0, sellable = false, spot = "out" },
	Wild_GoldOre = { icon = "", name = "สายแร่ทอง", kind = "placeable", weight = 3, stackSize = 10, value = 0, sellable = false, spot = "out" },
	Wild_MagicOre = { icon = "", name = "สายแร่เวท", kind = "placeable", weight = 3, stackSize = 10, value = 0, sellable = false, spot = "out" },
	Wild_DiamondOre = { icon = "", name = "สายเพชร", kind = "placeable", weight = 3, stackSize = 10, value = 0, sellable = false, spot = "out" },

	-- เฟอร์นิเจอร์ในบ้าน — **ใช้งานได้จริง** ชื่อโมเดลตรงกับที่ CraftStations/StorageChests มองหา
	Stove = { icon = "rbxassetid://108749346860365", name = "เตาทำอาหาร", kind = "placeable", weight = 3, stackSize = 3, value = 0, sellable = false, spot = "in" },
	SteamBlender = { icon = "rbxassetid://116376708091790", name = "เครื่องปั่นไอน้ำ", kind = "placeable", weight = 3, stackSize = 3, value = 0, sellable = false, spot = "in" },
	AlchemyStill = { icon = "rbxassetid://103913051779259", name = "เครื่องต้มยา", kind = "placeable", weight = 3, stackSize = 3, value = 0, sellable = false, spot = "in" },
	IceBox = { icon = "rbxassetid://131979279106619", name = "ตู้เย็น", kind = "placeable", weight = 3, stackSize = 3, value = 0, sellable = false, spot = "in" },
	ApothecaryCabinet = { icon = "rbxassetid://80776583408212", name = "ตู้ยา", kind = "placeable", weight = 3, stackSize = 3, value = 0, sellable = false, spot = "in" },

	-- สัตว์เลี้ยง (ไม่ใช่สัตว์ฟาร์ม) — rig เดินได้จริง ลูบหัว/อุ้มได้ ให้บัพทั้งฟาร์ม
	-- `stackSize = 1` เพราะแต่ละตัวเป็นตัวของมันเอง ไม่ใช่ของที่กองรวมกันได้
	Pet_Cat = { icon = "rbxassetid://99681747716275", name = "แมว", kind = "placeable", weight = 2, stackSize = 1, value = 0, sellable = false, spot = "both", pet = true },
	Pet_Dog = { icon = "rbxassetid://125840282304682", name = "สุนัข", kind = "placeable", weight = 2, stackSize = 1, value = 0, sellable = false, spot = "both", pet = true },

	-- ฟาร์มผิดกฎหมาย — วางในบ้านแล้วเป็นจุดฟาร์มจริง (กฎของ IllegalFarm ยังใช้ครบ)
	DistillSet = { icon = "rbxassetid://109416282689187", name = "ชุดกลั่น", kind = "placeable", weight = 3, stackSize = 3, value = 0, sellable = false, spot = "in" },
	Reactor = { icon = "rbxassetid://119765735693171", name = "เตาปฏิกรณ์", kind = "placeable", weight = 3, stackSize = 3, value = 0, sellable = false, spot = "in" },
	Boxs = { icon = "rbxassetid://106613754863320", name = "กองลังของเถื่อน", kind = "placeable", weight = 3, stackSize = 3, value = 0, sellable = false, spot = "in" },
	House_StoneCottage = { icon = "rbxassetid://93632640964050", name = "กระท่อมหิน", kind = "placeable", weight = 2, stackSize = 1, value = 0, sellable = false },
	House_Roundhouse = { icon = "rbxassetid://93997287568589", name = "บ้านทรงกลม", kind = "placeable", weight = 2, stackSize = 1, value = 0, sellable = false },
	House_Longhouse = { icon = "rbxassetid://106117342921842", name = "บ้านยาว", kind = "placeable", weight = 2, stackSize = 1, value = 0, sellable = false },
	House_PipeWorker = { icon = "rbxassetid://75083203720634", name = "บ้านช่างท่อ", kind = "placeable", weight = 2, stackSize = 1, value = 0, sellable = false },
	House_Townhouse = { icon = "rbxassetid://73665442223448", name = "ทาวน์เฮาส์", kind = "placeable", weight = 2, stackSize = 1, value = 0, sellable = false },
	-- คอกสัตว์: วางแล้วกด E เลือกสัตว์ สัตว์เกิดในคอกสูงสุด 10 ตัว (IslandConfig.PenAnimals)
	AnimalPen = { icon = "rbxassetid://77729553650023", name = "คอกสัตว์", kind = "placeable", weight = 3, stackSize = 3, value = 0, sellable = false },
	-- โซนแร่: วางแล้วทุก 10 นาทีสุ่มก้อนแร่โผล่ให้ขุด · ย้ายได้ด้วยการเก็บแล้ววางใหม่
	MineZone = { icon = "rbxassetid://95784879090358", name = "โซนแร่", kind = "placeable", weight = 3, stackSize = 3, value = 0, sellable = false },
	-- เมล็ดพันธุ์ชนิดเดียว หยอดแล้วค่อยรู้ว่าเป็นอะไร (IslandConfig.Crops) — ไม่ใช่ placeable
	Seed = { icon = "rbxassetid://121667533959320", name = "เมล็ดพันธุ์", kind = "junk", weight = 0.05, stackSize = 99, value = 0, sellable = false, vip = true },

	--------------------------------------------------------------------------
	-- เฟส 2c (ผู้ใช้อนุมัติร่าง 2026-09-27): ฝ้าย + เครื่องคราฟขั้นสูง 3 เครื่อง + ของที่เครื่องทำ
	--
	-- ฝ้ายเป็นผลผลิตแปลงผักเหมือนข้าว/ผัก (กระเป๋าหลัก ขายร้านได้) · เมล็ดฝ้ายอยู่กระเป๋า VIP เหมือนเมล็ดสุ่ม
	-- **ของที่เครื่องทำทุกชิ้น: กระเป๋า VIP (ใช้แค่บนเกาะ) · ขายร้านไม่ได้ ส่งเมลไม่ได้ (เป็นของคราฟ) · ส่งออกได้**
	-- ราคาส่งออกอยู่ที่ ExportConfig.Goods ไม่ใช่ `value` · icon = "" = ⌛ จนกว่าจะอัปโหลดรูป
	--------------------------------------------------------------------------
	Cotton = { icon = "", name = "ฝ้าย", kind = "junk", weight = 0.5, stackSize = 99, value = 20 },
	CottonSeed = { icon = "", name = "เมล็ดฝ้าย", kind = "junk", weight = 0.05, stackSize = 99, value = 0, sellable = false, vip = true },

	-- เครื่อง: ชื่อโมเดลตรงกับ CraftStations.STATIONS (ระบบหาจากชื่อ) · สำเร็จ 100% ไม่มีค่าจ้าง
	BakeryOven = { icon = "", name = "เตาอบขนมปัง", kind = "placeable", weight = 3, stackSize = 3, value = 0, sellable = false, spot = "both" },
	MetalBench = { icon = "", name = "โต๊ะช่างเหล็ก", kind = "placeable", weight = 3, stackSize = 3, value = 0, sellable = false, spot = "both" },
	Loom = { icon = "", name = "กี่ทอผ้าไอน้ำ", kind = "placeable", weight = 3, stackSize = 3, value = 0, sellable = false, spot = "both" },

	-- เตาอบขนมปัง (★ = ขั้นสุดท้าย ส่งออกอย่างเดียว ไม่เป็นวัตถุดิบของอะไร)
	Flour = { icon = "", name = "แป้งสาลี", kind = "junk", weight = 0.4, stackSize = 99, value = 0, sellable = false, vip = true },
	Dough = { icon = "", name = "แป้งโด", kind = "junk", weight = 0.6, stackSize = 50, value = 0, sellable = false, vip = true },
	SpecialBread = { icon = "", name = "ขนมปังเนยสด", kind = "junk", weight = 0.6, stackSize = 20, value = 0, sellable = false, vip = true }, -- ★
	MeatPie = { icon = "", name = "พายเนื้อ", kind = "junk", weight = 0.8, stackSize = 20, value = 0, sellable = false, vip = true }, -- ★
	CreamCake = { icon = "", name = "เค้กครีม", kind = "junk", weight = 1, stackSize = 20, value = 0, sellable = false, vip = true }, -- ★

	-- โต๊ะช่างเหล็ก
	IronIngot = { icon = "", name = "เหล็กแท่ง", kind = "junk", weight = 1.5, stackSize = 50, value = 0, sellable = false, vip = true },
	Nails = { icon = "", name = "ตะปู", kind = "junk", weight = 0.05, stackSize = 99, value = 0, sellable = false, vip = true },
	Hinge = { icon = "", name = "บานพับ", kind = "junk", weight = 0.5, stackSize = 50, value = 0, sellable = false, vip = true },
	SilverIngot = { icon = "", name = "เงินแท่ง", kind = "junk", weight = 1.5, stackSize = 50, value = 0, sellable = false, vip = true },
	MechGear = { icon = "", name = "เฟืองกลไก", kind = "junk", weight = 0.5, stackSize = 50, value = 0, sellable = false, vip = true },
	GoldIngot = { icon = "", name = "ทองแท่ง", kind = "junk", weight = 1.5, stackSize = 50, value = 0, sellable = false, vip = true },
	Padlock = { icon = "", name = "แม่กุญแจเหล็ก", kind = "junk", weight = 1, stackSize = 20, value = 0, sellable = false, vip = true }, -- ★
	PocketWatch = { icon = "", name = "นาฬิกาพกทองคำ", kind = "junk", weight = 0.3, stackSize = 20, value = 0, sellable = false, vip = true }, -- ★
	MagicCompass = { icon = "", name = "เข็มทิศเวท", kind = "junk", weight = 0.5, stackSize = 20, value = 0, sellable = false, vip = true }, -- ★

	-- กี่ทอผ้า
	Thread = { icon = "", name = "ด้ายฝ้าย", kind = "junk", weight = 0.1, stackSize = 99, value = 0, sellable = false, vip = true },
	Cloth = { icon = "", name = "ผ้าฝ้ายทอ", kind = "junk", weight = 0.5, stackSize = 50, value = 0, sellable = false, vip = true },
	Yarn = { icon = "", name = "ไหมพรม", kind = "junk", weight = 0.1, stackSize = 99, value = 0, sellable = false, vip = true },
	WoolCloth = { icon = "", name = "ผ้าขนสัตว์", kind = "junk", weight = 0.6, stackSize = 50, value = 0, sellable = false, vip = true },
	FineFabric = { icon = "", name = "ผ้าปักลายชั้นดี", kind = "junk", weight = 0.6, stackSize = 20, value = 0, sellable = false, vip = true }, -- ★
}

-- **สายแร่บนเกาะใช้รูปเดียวกับไอเทมแร่ที่มันให้** (ผู้ใช้สั่ง 2026-09-23)
--
-- เป็นข้อยกเว้นของกติกา "ยืมรูปของไอเทมอื่น = ตั้ง `icon = \"\"` แล้วโชว์ ⌛" — ที่นี่การยืมสื่อความหมาย
-- ได้จริง เพราะสายแร่ทั้งเจ็ดหน้าตาต่างกันชัดเจนอยู่แล้วที่ตัวแร่ข้างใน ไม่ใช่ที่ก้อนหิน
--
-- ⚠️ **คัดลอกจากตารางเดียวกัน ไม่ใช่วางเลข id ซ้ำ** — วันที่ไอคอนแร่ถูกเปลี่ยน สายแร่ต้องตามไปเอง
-- (`Wild_DiamondOre` ยืมของ `Diamond` ไม่ใช่ `DiamondOre` ซึ่งเป็นชื่อ NodeKind ไม่ใช่ชื่อไอเทม)
for wild, ore in pairs({
	Wild_Coal = "Coal",
	Wild_IronOre = "IronOre",
	Wild_SilverOre = "SilverOre",
	Wild_Crystal = "Crystal",
	Wild_GoldOre = "GoldOre",
	Wild_MagicOre = "MagicOre",
	Wild_DiamondOre = "Diamond",
}) do
	local a, b = ItemCatalog.Items[wild], ItemCatalog.Items[ore]
	if a and b then a.icon = b.icon end
end

function ItemCatalog.Get(id)
	return ItemCatalog.Items[id]
end

-- What to call a particular COPY of an item, rather than the kind of item it is.
--
-- Almost everything answers with its catalogue name and nothing more. A vehicle key does not: three car keys
-- in a bag are three different cars, and "กุญแจรถ" three times over is unreadable -- the user could not tell
-- which key opened which vehicle. The plate lives in the slot's `meta`, so it is the slot that has to be
-- asked, not the catalogue.
--
-- One helper rather than the same concatenation at every call site, so a second kind of identity later (a
-- named weapon, a signed letter) is added here and appears everywhere at once. Callers that have no meta to
-- hand pass nothing and get exactly what they got before.
function ItemCatalog.DisplayName(id, meta)
	local item = ItemCatalog.Items[id]
	local base = item and item.name or id
	if type(meta) == "table" and type(meta.plate) == "string" then
		return base .. " " .. meta.plate
	end
	if type(meta) == "table" and type(meta.clan) == "string" then
		return base .. " · " .. meta.clan
	end
	-- ขั้นตีบวก "+n" ต่อท้ายชื่อ (ก่อนชื่อสกิน): "ดาบ +7 (เปลวเพลิง)"
	local level = type(meta) == "table" and tonumber(meta.enhance) or nil
	if level and level == level and level >= 1 then
		base = ("%s +%d"):format(base, math.min(math.floor(level), 10))
	end
	-- อาวุธ/เกราะที่ติดสกินอยู่ บอกชื่อสกินต่อท้าย
	if type(meta) == "table" and type(meta.skin) == "string" then
		local skin = ItemCatalog.Items[meta.skin]
		if skin then
			local short = skin.name:match(": (.+)$") or skin.name
			return base .. " (" .. short .. ")"
		end
	end
	-- ของขอบทอง (เฟส 2b): "ไข่ (ขอบทอง)"
	if ItemCatalog.IsGoldBorder(meta) then
		return base .. " (ขอบทอง)"
	end
	return base
end

-- **ของขอบทอง** (เฟส 2b ผู้ใช้กำหนด 2026-09-26): `meta.gold = true` · ตัวตัดสินตัวเดียวที่กฎโอน/ฝาก/ทิ้ง/ขาย/
-- วัตถุดิบ/เควสทุกตัวถาม — ได้เฉพาะบนเกาะ ติดตัวได้แต่ออกจากมือเจ้าของไม่ได้เลย (ขายบนเกาะ/ส่งออกเท่านั้น)
function ItemCatalog.IsGoldBorder(meta)
	return type(meta) == "table" and meta.gold == true
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

-- Everything the shopkeeper hands over the counter, derived from their own stock list the same way and for
-- the same reason. ShopConfig is data-only too, so this cannot loop back either -- and it must stay that way.
local ShopStock = {}
for _, entry in ipairs(ShopConfig.Sells) do
	ShopStock[entry.id] = true
end

-- May the shop put a price on this? Absent means yes, which is what every item written before V0.5 wants.
-- Read by the counter, the "sell everything" button and the price board alike, so an item cannot be refused
-- in one place and bought in another.
--
-- Three ways to be unsellable:
--
--   `sellable = false` in the entry -- the steam-age materials, which are the price of the new recipes.
--
--   BEING CRAFTABLE. Anything on the forge's list is refused, and the list is what decides rather than a flag
--   somebody has to remember to add. That gap is exactly how bullets ended up sellable: they are `kind =
--   "junk"` like every other material, and the shop buys by kind. Crafting one costs iron, gears, bone,
--   stone, silver and a 300-coin fee -- a counter that then bought it back is a route from materials to coin
--   that the fixed prices were never balanced against.
--
--   BEING ON THE SHOP'S OWN SHELF. The shopkeeper does not buy back what they sell, at the user's request.
--   Derived from ShopConfig.Sells rather than flagged per item, so adding a line to the stock list is the
--   whole change: the day worms or bread are for sale is the day they stop being worth carrying back.
--
-- Weapons, armour and potions were never at risk (the shop only buys `junk`), but they are covered by the
-- same rule now, so the answer does not depend on which kind a future recipe happens to make.
function ItemCatalog.IsSellable(id)
	local item = ItemCatalog.Items[id]
	if not item then return false end
	if item.sellable == false then return false end
	if ShopStock[id] then return false end
	return not CraftableOutput[id]
end

-- May this item be thrown away? Everything may, except a vehicle key.
--
-- A key is not really an item: it is the only handle on a registration that lives in the player's profile,
-- and throwing it away silently destroys a vehicle they paid for. The rule pairs with the other half the
-- user asked for -- a key that is lost by some OTHER route takes its vehicle with it -- so the two together
-- mean a garage can never hold a car whose key does not exist, and a player can never delete a car by
-- pressing a red button in their bag.
-- ของประจำตำแหน่ง (ตะหลิวเชฟ แหวนแคลน) ทิ้ง ให้ เทรด ฝาก ไม่ได้ทั้งหมด — มันคือหลักฐานของสิทธิ์ ไม่ใช่ของ
function ItemCatalog.IsBound(id)
	local item = ItemCatalog.Items[id]
	return item ~= nil and item.bound == true
end

function ItemCatalog.IsDroppable(id, meta)
	-- ของขอบทอง (เฟส 2b) ออกจากมือเจ้าของไม่ได้ทุกทาง — ถามที่นี่ที่เดียว ผู้เรียกต้องส่ง slot.meta มาด้วย
	if ItemCatalog.IsGoldBorder(meta) then return false end
	local item = ItemCatalog.Items[id]
	if not item then return false end
	if item.bound then return false end
	-- จักรยานทิ้งได้แล้ว **เพราะตอนนี้ซื้อคืนได้**
	--
	-- เหตุผลเดิมที่ห้ามทิ้งคือ "ทิ้งแล้วไม่มีทางได้คืน เพราะไม่มีที่ไหนขายและไม่มีสูตรคราฟ" พอบาร์นาบี
	-- ขายที่ 5,000 เหรียญ เหตุผลนั้นก็หมดไป — ของที่ซื้อคืนได้ไม่จำเป็นต้องกันไม่ให้ทิ้ง
	--
	-- กุญแจพาหนะยังห้ามทิ้งเหมือนเดิม เพราะมันไม่ใช่ของที่ซื้อคืนได้: มันเป็นหลักฐานชิ้นเดียวของทะเบียน
	-- ที่อยู่ในโปรไฟล์ ทิ้งแล้วรถหายไปทั้งคัน
	return item.kind ~= "key"
end

-- May this item be PUT AWAY -- in the warehouse, or in a vehicle's boot? Everything may, except a vehicle
-- key. A key may only ever be in a bag or in somebody else's bag.
--
-- Two reasons, and the second one is the one that forced it. A key is the only handle on a registration, so
-- a key locked in a warehouse is a car nobody can reach. And the boot does not store items, it stores
-- COUNTS: `record.trunk[itemId] = n`, with no room for the slot's meta -- so a key put in a boot would come
-- out as a key to nothing, its plate gone, exactly the "คข 8660" problem that broke Baron Vane's garage.
function ItemCatalog.IsStorable(id, meta)
	-- ของขอบทอง (เฟส 2b) ออกจากมือเจ้าของไม่ได้ทุกทาง — ถามที่นี่ที่เดียว ผู้เรียกต้องส่ง slot.meta มาด้วย
	if ItemCatalog.IsGoldBorder(meta) then return false end
	local item = ItemCatalog.Items[id]
	if not item then return false end
	if item.bound then return false end
	-- จักรยานเก็บเข้าคลังได้แล้ว ตามเหตุผลเดียวกับที่ทิ้งได้ (ดู IsDroppable ข้างบน): ซื้อคืนได้แล้ว
	-- จึงไม่ต้องกันไม่ให้วางลง และการมีคันสำรองเก็บไว้ในคลังเป็นเรื่องสมเหตุสมผล
	--
	-- ท้ายรถก็เก็บได้ด้วย และปลอดภัย: ท้ายรถเก็บเป็นจำนวนล้วน (`trunk[id] = n`) ไม่มีที่เก็บ meta
	-- ซึ่งเป็นปัญหาสำหรับกุญแจที่มีทะเบียนติดมา แต่จักรยานไม่มี meta จึงไม่มีอะไรให้หาย
	return item.kind ~= "key"
end

-- ผู้เล่นส่งของชิ้นนี้ทางเมลได้ไหม (ผู้ใช้กำหนด 2026-09-24) — ด่านเดียว ทั้งปุ่มฝั่งไคลเอนต์และเซิร์ฟเวอร์ถามตัวนี้
--
-- ที่เหลือให้ส่งคือวัตถุดิบ: ของที่กดใช้ได้ ของที่คราฟได้ และของต้องห้ามใน MailConfig ทำให้ร้าน/โรงตีเหล็ก/
-- ฟาร์มเถื่อนยังเป็นทางเดียวที่ของพวกนั้นเข้าเกม · เมลจากระบบ/แอดมินไม่ผ่านด่านนี้
-- ของที่ได้จากเพชร ส่งหากันไม่ได้ (ผู้ใช้กำหนด 2026-09-24): ร้านเพชร + ของเกาะที่ขายเป็นเพชร อ่านจากรายการร้านเอง
-- เหมือน CraftableOutput — ของใหม่ที่เพิ่มเข้าร้านเพชรถูกกันให้เองโดยไม่ต้องแก้ที่นี่
local GemBought = {}
for _, row in ipairs(PremiumConfig.Shop) do
	if row.item then GemBought[row.item] = true end
end
for _, row in ipairs(ShopConfig.IslandSells or {}) do
	-- เฟส 2a: ทุกแถวในร้านเกาะซื้อด้วยเพชรได้ จึงส่งเมลไม่ได้ทั้งร้าน รวมเมล็ด (ผู้ใช้เลือก 2026-09-27)
	if select(2, ShopConfig.PricesOf(row)) then GemBought[row.id] = true end
end
-- สกิน ออร่า ชุดแฟชั่น ได้จากกาชา/พาส (จ่ายเพชร) จึงกันด้วยชนิด
local GemKinds = { skin = true, aura = true, fashion = true }

function ItemCatalog.IsMailable(id, meta)
	-- ของขอบทอง (เฟส 2b) ออกจากมือเจ้าของไม่ได้ทุกทาง — ถามที่นี่ที่เดียว ผู้เรียกต้องส่ง slot.meta มาด้วย
	if ItemCatalog.IsGoldBorder(meta) then return false end
	local item = ItemCatalog.Items[id]
	if not item then return false end
	if item.bound or item.kind == "key" then return false end
	if item.use then return false end
	if CraftableOutput[id] then return false end
	if GemBought[id] or GemKinds[item.kind] then return false end
	return not MailConfig.Contraband[id]
end

-- **เพดานจำนวนที่พกติดตัวได้** (ผู้ใช้สั่ง 2026-09-20) — `bagStacks` = จำนวน "กอง" ที่กระเป๋าถือได้
-- นับรวมทั้งกระเป๋า ไม่ใช่ต่อช่อง: ยา อาหาร และเครื่องดื่มถือได้กองเดียว ส่วนที่เกิน `Inventory.AddItem`
-- ส่งเข้าคลังของมาดามออเรเลียให้เอง · ไม่มีฟิลด์นี้ = ไม่จำกัด (แอปเปิลตั้งใจให้ไม่จำกัด)
--
-- ที่เป็น "กอง" ไม่ใช่ "ชิ้น" เพราะเลขที่คนเล่นเห็นคือขนาดกอง การเขียนเพดานเป็นชิ้นจะทำให้ทุกครั้งที่
-- ขนาดกองเปลี่ยน ต้องมาไล่แก้เพดานตามทุกชิ้น แล้วสักวันจะลืม
function ItemCatalog.BagLimit(id)
	local item = ItemCatalog.Items[id]
	if not item or not item.bagStacks then return nil end
	return item.bagStacks * (item.stackSize or 1)
end

-- Weapons and armor carry durability, so they can never stack; everything else stacks by its own limit.
function ItemCatalog.StackSize(id)
	local item = ItemCatalog.Items[id]
	return item and item.stackSize or 1
end

return ItemCatalog
