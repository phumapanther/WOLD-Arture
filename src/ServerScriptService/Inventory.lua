-- Inventory.lua: the single owner of every player's bag, equipped gear, gold and carry weight.
--
-- A module, like Vitals and Progression, because several systems reach it: combat asks what weapon is
-- equipped, movement asks how overloaded the player is, and PlayerProfile saves the contents.
--
-- Slots are a flat array of { id = string, count = number, durability = number? }, or nil for an empty slot.
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local InventoryConfig = require(game.ReplicatedStorage.InventoryConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local Inventory = {}

local States = {} -- [player] = { slots, equipped = {weapon, armor}, gold }

function Inventory.Add(player, saved)
	States[player] = {
		slots = saved and saved.Slots or {},
		equipped = saved and saved.Equipped or {},
		gold = saved and saved.Gold or 0,
		-- [hotbar 1-6] = item id. Ids rather than bag positions: the bag gets sorted and items move, and a
		-- hotbar pointing at "slot 7" would silently start pointing at something else. An id still names the
		-- same thing after any rearrangement, and simply shows empty when the last one is used up.
		hotbar = saved and saved.Hotbar or {},
	}
	return States[player]
end

function Inventory.Remove(player)
	States[player] = nil
end

function Inventory.Get(player)
	return States[player]
end

--------------------------------------------------------------------------------
-- Weight
--------------------------------------------------------------------------------

-- Equipped gear counts toward the load: wearing plate armor should slow you down whether or not it sits in
-- the bag. Otherwise players would "carry" everything by wearing it.
function Inventory.Weight(player)
	local state = States[player]
	if not state then return 0 end
	local total = 0
	for _, slot in pairs(state.slots) do
		local item = ItemCatalog.Get(slot.id)
		if item then total += item.weight * (slot.count or 1) end
	end
	for _, entry in pairs(state.equipped) do
		local item = entry and ItemCatalog.Get(entry.id)
		if item then total += item.weight end
	end
	return total
end

function Inventory.SpeedMultiplier(player)
	return InventoryConfig.SpeedMultiplier(Inventory.Weight(player))
end

function Inventory.IsHeavilyLoaded(player)
	return InventoryConfig.IsHeavilyLoaded(Inventory.Weight(player))
end

--------------------------------------------------------------------------------
-- Adding and removing
--------------------------------------------------------------------------------

-- **ของชิ้นนี้อยู่ฝั่งไหนของกระเป๋า** — เกณฑ์เดียวกับแท็บบนหน้าจอเป๊ะ
--
-- `InventoryGui.IsFarmItem` อ่านจาก `vip = true` หรือ `kind == "placeable"` · ที่นี่ต้องคิดเหมือนกัน
-- ไม่งั้นของจะไปลงช่องที่แท็บนั้นมองไม่เห็น แล้วอ่านเหมือนของหาย
local function isVipItem(id)
	local item = ItemCatalog.Get(id)
	if not item then return false end
	return item.vip == true or item.kind == "placeable"
end

-- ช่วงช่องที่ของชนิดนี้ใช้ได้
local function rangeFor(id)
	if isVipItem(id) then
		return InventoryConfig.VipSlotStart, InventoryConfig.VipSlotEnd
	end
	return 1, InventoryConfig.SlotCount
end

local function firstFreeSlot(state, id)
	local from, to = rangeFor(id)
	for i = from, to do
		if state.slots[i] == nil then return i end
	end
	return nil
end

-- Fills existing stacks before opening a new slot, so picking up ten stones does not eat ten slots.
-- `meta` is per-ITEM data that makes two otherwise identical items different things: a vehicle key's plate,
-- for one. Anything carrying it is never merged into a stack, because merging would throw away every copy's
-- meta but the first -- two car keys would become "CarKey x2" for a single car.
-- ถืออยู่ในกระเป๋าตอนนี้กี่ชิ้น (ไม่นับของที่สวมอยู่ — เพดานพกติดตัวใช้กับของกินของใช้ ซึ่งไม่มีอะไรสวมได้)
function Inventory.CountOf(player, id)
	local state = States[player]
	if not state then return 0 end
	local total = 0
	local from, to = rangeFor(id)
	for i = from, to do
		local slot = state.slots[i]
		if slot and slot.id == id then total += slot.count or 1 end
	end
	return total
end

-- ยังรับของชิ้นนี้ได้อีกกี่ชิ้นก่อนชนเพดานพกติดตัว · nil = ไม่มีเพดาน (ของส่วนใหญ่ในเกม)
function Inventory.RoomUnderLimit(player, id)
	local limit = ItemCatalog.BagLimit(id)
	if not limit then return nil end
	return math.max(0, limit - Inventory.CountOf(player, id))
end

-- ของที่เกินเพดานไปไหน — ตั้งโดย `BankVault.server` ให้ชี้ไปที่คลังของมาดามออเรเลีย
--
-- เป็น hook ไม่ใช่ `require` ตรงๆ เพราะกระเป๋าไม่ควรรู้จักคลัง: ของที่ล้นจะไปลงที่ไหนเป็นการตัดสินใจ
-- ของเกม ไม่ใช่ของโครงสร้างข้อมูล · ไม่มีใครตั้ง = ของที่เกินไม่ถูกเพิ่ม และ AddItem คืน false
Inventory.Overflow = nil

function Inventory.AddItem(player, id, count, durability, meta)
	local state = States[player]
	if not state or not ItemCatalog.Exists(id) then return false end
	count = count or 1

	-- **เพดานพกติดตัว** (ยา/อาหาร/เครื่องดื่ม กองเดียว — ผู้ใช้สั่ง 2026-09-20)
	--
	-- ตัดสินตั้งแต่ก่อนลงช่อง ไม่ใช่ตัดทิ้งทีหลัง: ส่วนที่เกินต้องไปลงคลังให้ครบจำนวน ไม่ใช่หายไปเฉยๆ
	-- ของที่มี `meta` (กุญแจรถ ปลาที่มีน้ำหนัก) ไม่ถูกจำกัด — มันเป็นของเฉพาะชิ้น ไม่ใช่ของที่กองได้
	local spill = 0
	if not meta then
		local room = Inventory.RoomUnderLimit(player, id)
		if room and count > room then
			spill = count - room
			count = room
		end
	end

	local stackSize = ItemCatalog.StackSize(id)
	if meta then stackSize = 1 end
	if count > 0 and stackSize > 1 then
		local from, to = rangeFor(id)
		for i = from, to do
			local slot = state.slots[i]
			if slot and slot.id == id and slot.count < stackSize then
				local moved = math.min(stackSize - slot.count, count)
				slot.count += moved
				count -= moved
				if count <= 0 then
					Inventory.Send(player)
					return Inventory.SpillOver(player, id, spill, durability)
				end
			end
		end
	end

	while count > 0 do
		local free = firstFreeSlot(state, id)
		if not free then
			Inventory.Send(player)
			-- กระเป๋าเต็มจริงๆ ของที่เหลือรวมส่วนที่เกินเพดานด้วย ลองส่งเข้าคลังทั้งก้อน
			Inventory.SpillOver(player, id, spill + count, durability)
			return false -- bag full; whatever fitted has been kept
		end
		local put = math.min(stackSize, count)
		local item = ItemCatalog.Get(id)
		state.slots[free] = {
			id = id,
			count = put,
			-- Weapons and armor track wear; nothing else does.
			durability = durability or item.maxDurability or item.armor,
			-- Only present on items that carry their own identity. Absent everywhere else, so the slot
			-- shape is unchanged for the things that were working before.
			meta = meta,
		}
		count -= put
	end

	Inventory.Send(player)
	return Inventory.SpillOver(player, id, spill, durability)
end

-- ส่งส่วนที่เกินเพดานเข้าคลัง คืน true เมื่อ "ของทุกชิ้นมีที่อยู่แล้ว"
--
-- คลังเต็มด้วย = คืน false เหมือนกระเป๋าเต็ม ผู้เรียกที่เคยรับมือกับกระเป๋าเต็มอยู่แล้ว (คราฟ ร้านค้า
-- รางวัลพาส) จึงรับมือกับกรณีนี้ได้โดยไม่ต้องแก้อะไร — และของไม่หายไปเงียบๆ
function Inventory.SpillOver(player, id, count, durability)
	if not count or count <= 0 then return true end
	if not Inventory.Overflow then return false end
	local placed = Inventory.Overflow(player, id, count, durability) or 0
	if placed <= 0 then return false end

	local item = ItemCatalog.Get(id)
	local name = item and item.name or id
	local limit = ItemCatalog.BagLimit(id)
	Remotes.SocialNotify:FireClient(player, "info",
		("%s พกได้ไม่เกิน %d ชิ้น — ส่วนที่เกิน %d ชิ้นเข้าคลังแล้ว"):format(name, limit or 0, placed))
	return placed >= count
end

-- Would `count` of `id` fit, without actually putting them anywhere?
--
-- Crafting needs this because it spends the materials before it knows whether the attempt worked, so it has
-- no chance to hand the product over first and find out the bag is full. Asking up front is what stops a
-- successful craft burning the cost and then having nowhere to put the sword.
--
-- Deliberately mirrors AddItem's own reasoning -- top up part-filled stacks first, then take empty slots --
-- because an answer that disagreed with what AddItem then does would be worse than no answer at all.
function Inventory.HasRoomFor(player, id, count, meta)
	local state = States[player]
	if not state or not ItemCatalog.Exists(id) then return false end
	count = count or 1

	local stackSize = ItemCatalog.StackSize(id)
	if meta then stackSize = 1 end

	-- **ถามเฉพาะฝั่งของมันเอง** ของเกาะเต็มไม่ได้แปลว่าซื้อยาในเมืองไม่ได้ และกลับกัน
	local from, to = rangeFor(id)

	if stackSize > 1 then
		for i = from, to do
			local slot = state.slots[i]
			if slot and slot.id == id and slot.count < stackSize then
				count -= math.min(stackSize - slot.count, count)
				if count <= 0 then return true end
			end
		end
	end

	for i = from, to do
		if not state.slots[i] then
			count -= stackSize
			if count <= 0 then return true end
		end
	end
	return false
end

function Inventory.RemoveFromSlot(player, index, count)
	local state = States[player]
	local slot = state and state.slots[index]
	if not slot then return false end
	count = count or slot.count or 1
	slot.count = (slot.count or 1) - count
	if slot.count <= 0 then state.slots[index] = nil end
	Inventory.Send(player)
	return true
end

--------------------------------------------------------------------------------
-- Auto-sort
--------------------------------------------------------------------------------

-- Merges partial stacks, then packs everything to the front ordered by kind and name, so the bag reads the
-- same way every time.
local KIND_ORDER = { weapon = 1, armor = 2, consumable = 3, junk = 4 }

-- **ย้ายของเกาะที่ค้างอยู่ในช่องเกมหลักไปช่อง VIP** (ของเก่าที่เซฟไว้ก่อนแยกช่อง 2026-09-22)
--
-- เรียกครั้งเดียวตอนโหลดโปรไฟล์ · ของที่ย้ายไม่ได้ (ช่อง VIP เต็ม) **ปล่อยไว้ที่เดิม** ดีกว่าทำหาย —
-- มันยังใช้ได้ปกติ แค่ยังกินช่องเกมหลักอยู่จนกว่าจะเอาไปวางบนเกาะ
function Inventory.MigrateVipSlots(player)
	local state = States[player]
	if not state then return 0 end
	local moved = 0
	for i = 1, InventoryConfig.SlotCount do
		local slot = state.slots[i]
		if slot and isVipItem(slot.id) then
			local free = firstFreeSlot(state, slot.id)
			if not free then break end
			state.slots[free] = slot
			state.slots[i] = nil
			moved += 1
		end
	end
	if moved > 0 then Inventory.Send(player) end
	return moved
end

function Inventory.AutoSort(player)
	local state = States[player]
	if not state then return end

	-- **จัดทีละฝั่ง** กระเป๋าหลักกับกระเป๋า VIP อยู่คนละช่วงดัชนีและไม่ปะปนกัน — อัดของฝั่งไหน
	-- ก็ชิดหน้าของช่วงนั้น · ถ้าอัดรวมกันเหมือนเดิม ของ VIP จะถูกย้ายมาทับช่องเกมหลักทันที
	local function sortRange(from, to)
		local totals, singles = {}, {}
		for i = from, to do
			local slot = state.slots[i]
			if slot then
				-- A slot with meta keeps its own identity, so it is sorted as a single rather than counted
				-- into a total -- the same reason weapons and armor are.
				if ItemCatalog.StackSize(slot.id) > 1 and not slot.meta then
					totals[slot.id] = (totals[slot.id] or 0) + (slot.count or 1)
				else
					table.insert(singles, slot)
				end
				state.slots[i] = nil
			end
		end

		local entries = {}
		for id, count in pairs(totals) do
			local stackSize = ItemCatalog.StackSize(id)
			while count > 0 do
				local put = math.min(stackSize, count)
				table.insert(entries, { id = id, count = put })
				count -= put
			end
		end
		for _, slot in ipairs(singles) do
			table.insert(entries, slot)
		end

		table.sort(entries, function(a, b)
			-- **ของที่ไม่มีในแคตตาล็อกแล้วต้องไม่ทำให้การจัดกระเป๋าพังทั้งยก**
			-- (`Get` คืน nil ได้จริง: ไอเทมที่ถูกถอดออกจากเกมแต่ยังค้างในเซฟเก่า)
			local ia, ib = ItemCatalog.Get(a.id), ItemCatalog.Get(b.id)
			local ka = KIND_ORDER[ia and ia.kind] or 9
			local kb = KIND_ORDER[ib and ib.kind] or 9
			if ka ~= kb then return ka < kb end
			if a.id ~= b.id then return a.id < b.id end
			return (a.count or 1) > (b.count or 1)
		end)

		for i, entry in ipairs(entries) do
			local target = from + i - 1
			if target > to then break end
			state.slots[target] = entry
		end
	end

	sortRange(1, InventoryConfig.SlotCount)
	sortRange(InventoryConfig.VipSlotStart, InventoryConfig.VipSlotEnd)

	Inventory.Send(player)
end

--------------------------------------------------------------------------------
-- Equipping
--------------------------------------------------------------------------------

-- Set by WeaponVisuals: puts the equipped weapon in the character's hand. Left nil in the lobby, where no
-- weapon visuals run.
Inventory.OnWeaponChanged = nil

local function broadcastEquipment(player, state)
	Remotes.EquipmentChanged:FireAllClients(player,
		state.equipped.weapon and state.equipped.weapon.id or nil,
		state.equipped.armor and state.equipped.armor.id or nil)
	if Inventory.OnWeaponChanged then Inventory.OnWeaponChanged(player) end
end

function Inventory.Equip(player, index)
	local state = States[player]
	local slot = state and state.slots[index]
	if not slot then return false end
	local item = ItemCatalog.Get(slot.id)
	if not item or (item.kind ~= "weapon" and item.kind ~= "armor") then return false end

	local key = item.kind -- "weapon" | "armor"
	local previous = state.equipped[key]
	-- meta ติดไปด้วย: สกินที่ติดตั้งไว้ (meta.skin) ต้องอยู่กับชิ้นนั้นตอนสวม ไม่งั้นถอดสวมทีสกินหาย
	state.equipped[key] = { id = slot.id, durability = slot.durability, meta = slot.meta }
	state.slots[index] = nil
	-- The piece coming off goes back into the bag rather than vanishing.
	if previous then
		Inventory.AddItem(player, previous.id, 1, previous.durability, previous.meta)
	end

	broadcastEquipment(player, state)
	Inventory.Send(player)
	return true
end

-- Destroys the equipped piece outright (worn to nothing). Unlike Unequip it does NOT go back in the bag,
-- and unlike hand-rolled clearing it goes through broadcastEquipment, so the model actually leaves the hand.
function Inventory.BreakEquipped(player, kind)
	local state = States[player]
	if not state or not state.equipped[kind] then return false end
	state.equipped[kind] = nil
	broadcastEquipment(player, state)
	return true
end

-- Restores every worn piece the player owns -- equipped and bagged -- to its catalog maximum. Returns false
-- when nothing was actually damaged, so the caller can decline to spend the repair item.
function Inventory.RepairAll(player)
	local state = States[player]
	if not state then return false end

	local repaired = false
	local function restore(entry)
		local item = entry and ItemCatalog.Get(entry.id)
		local full = item and (item.maxDurability or item.armor)
		if not full or (entry.durability or full) >= full then return end
		entry.durability = full
		repaired = true
	end

	for _, entry in pairs(state.equipped) do restore(entry) end
	for i = 1, InventoryConfig.TotalSlotCount do restore(state.slots[i]) end

	if repaired then Inventory.Send(player) end
	return repaired
end

function Inventory.Unequip(player, kind)
	local state = States[player]
	local entry = state and state.equipped[kind]
	if not entry then return false end
	state.equipped[kind] = nil
	Inventory.AddItem(player, entry.id, 1, entry.durability, entry.meta)
	broadcastEquipment(player, state)
	return true
end

-- Takes `amount` off the equipped weapon's durability; at zero it breaks and is gone. Returns false when
-- nothing wearable is held.
--
-- One place for every kind of wear -- a sword swing, a tree felled, a fish landed -- so "what happens at
-- zero" is answered once. The inventor's perk is the caller's business (PlayerCombat checks it).
function Inventory.WearEquipped(player, amount)
	local item, entry = Inventory.EquippedWeapon(player)
	if not item or not entry or not entry.durability then return false end
	-- เครื่องมือทองจากร้านพรีเมียม: ไม่มีวันพัง
	if item.unbreakable then return true end
	entry.durability -= amount or 1
	if entry.durability <= 0 then
		-- Through BreakEquipped rather than clearing the slot: doing it by hand skips OnWeaponChanged, and
		-- the broken tool's model stays in the player's hand while the animations fall back to fists.
		Inventory.BreakEquipped(player, "weapon")
	end
	Inventory.Send(player)
	return true
end

-- Returns the catalog entry and the live slot (which carries the durability), or nil when nothing is worn.
function Inventory.EquippedWeapon(player)
	local state = States[player]
	local entry = state and state.equipped.weapon
	return entry and ItemCatalog.Get(entry.id) or nil, entry
end

function Inventory.EquippedArmor(player)
	local state = States[player]
	local entry = state and state.equipped.armor
	return entry and ItemCatalog.Get(entry.id) or nil, entry
end

--------------------------------------------------------------------------------
-- Gold and replication
--------------------------------------------------------------------------------

function Inventory.AddGold(player, amount)
	local state = States[player]
	if not state then return end
	state.gold = math.max(0, state.gold + amount)
	Inventory.Send(player)
end

-- Puts an item id in a hotbar slot, or clears it when id is nil. Assigning something that is already in
-- another hotbar slot moves it rather than duplicating it: six slots showing the same potion would be six
-- ways to do one thing.
function Inventory.SetHotbar(player, index, id)
	local state = States[player]
	if not state then return false end
	if type(index) ~= "number" or index < 1 or index > InventoryConfig.HotbarSlots then return false end

	if id == nil then
		state.hotbar[index] = nil
		return true
	end
	if not ItemCatalog.Exists(id) then return false end

	for i, existing in pairs(state.hotbar) do
		if existing == id and i ~= index then state.hotbar[i] = nil end
	end
	state.hotbar[index] = id
	return true
end

-- The bag slot currently holding this id, or nil. The hotbar stores what to use, not where it lives, so
-- using one is a lookup at the moment of the press.
function Inventory.FindSlotById(player, id)
	local state = States[player]
	if not state or not id then return nil end
	for index, slot in pairs(state.slots) do
		if slot and slot.id == id then return index end
	end
	return nil
end

function Inventory.Send(player)
	local state = States[player]
	if not state then return end
	Remotes.InventoryUpdate:FireClient(player, {
		slots = state.slots,
		equipped = state.equipped,
		gold = state.gold,
		hotbar = state.hotbar,
		weight = Inventory.Weight(player),
		maxWeight = InventoryConfig.MaxWeight,
	})
end

function Inventory.Serialize(player)
	local state = States[player]
	if not state then return nil end
	return { Slots = state.slots, Equipped = state.equipped, Gold = state.gold, Hotbar = state.hotbar }
end

return Inventory
