-- Vault.lua: the warehouse behind Madam Aurelia's counter -- a second bag that does not travel with you.
--
-- Deliberately the same SHAPE as Inventory's slots ({ id, count, durability, meta }), because everything that
-- goes in comes out of a bag slot and goes back to one. A different shape would mean converting on the way in
-- and on the way out, and a conversion is somewhere for a durability or a vehicle plate to quietly go missing.
--
-- What it is NOT is a second Inventory: no weight, no equipping, no hotbar. Things in the vault are out of
-- play -- that is the whole reason to put them there -- so the only operations are "put in" and "take out".
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)

local Vault = {}

-- Bigger than the 36-slot bag, because a warehouse that held less than what you can carry would be pointless.
-- Sixty is five screens of ten rows at the width the window draws.
Vault.SlotCount = 60

local States = {} -- [player] = { slots = { [index] = slot } }

function Vault.Add(player, saved)
	States[player] = { slots = (type(saved) == "table" and saved.Slots) or {} }
	return States[player]
end

function Vault.Remove(player)
	States[player] = nil
end

function Vault.Get(player)
	return States[player]
end

function Vault.Serialize(player)
	local state = States[player]
	if not state then return nil end
	return { Slots = state.slots }
end

--------------------------------------------------------------------------------
-- Putting things in
--------------------------------------------------------------------------------

local function firstFree(state)
	for i = 1, Vault.SlotCount do
		if state.slots[i] == nil then return i end
	end
	return nil
end

-- Tops up part-filled stacks before opening a new shelf, exactly as Inventory.AddItem does. Anything carrying
-- `meta` -- a vehicle key's plate, a trophy fish's weight -- never merges, for the same reason it never merges
-- in the bag: merging keeps one copy's meta and throws the rest away.
--
-- Returns how many actually fitted, which may be fewer than asked for. The caller takes exactly that many out
-- of the bag, so a full warehouse loses nothing.
local function put(state, id, count, durability, meta)
	local stackSize = ItemCatalog.StackSize(id)
	if meta then stackSize = 1 end

	local placed = 0
	if stackSize > 1 then
		for i = 1, Vault.SlotCount do
			local slot = state.slots[i]
			if slot and slot.id == id and not slot.meta and (slot.count or 1) < stackSize then
				local moved = math.min(stackSize - slot.count, count - placed)
				slot.count += moved
				placed += moved
				if placed >= count then return placed end
			end
		end
	end

	while placed < count do
		local free = firstFree(state)
		if not free then return placed end
		local take = math.min(stackSize, count - placed)
		state.slots[free] = { id = id, count = take, durability = durability, meta = meta }
		placed += take
	end
	return placed
end

-- Bag slot -> vault. `count` is clamped to what the slot actually holds, so a client asking for a thousand of
-- a stack of three moves three.
--
-- Inventory is passed in rather than required, the same way Bank takes it: this module has no business
-- depending on the bag's lifecycle, and the one caller already holds both.
function Vault.Store(player, inventory, slotIndex, count)
	local state = States[player]
	if not state then return false, "ยังโหลดข้อมูลไม่เสร็จ" end

	local bag = inventory.Get(player)
	local slot = bag and bag.slots[slotIndex]
	if not slot then return false, "ไม่มีของในช่องนั้น" end

	local held = slot.count or 1
	local want = held
	if type(count) == "number" and count == count then
		want = math.clamp(math.floor(count), 1, held)
	end

	-- A slot carrying meta is one indivisible thing however many the count says, so it moves whole or not at
	-- all -- splitting a vehicle key in half is not a thing.
	if slot.meta then want = held end

	local placed = put(state, slot.id, want, slot.durability, slot.meta)
	if placed <= 0 then return false, "คลังเต็ม" end

	inventory.RemoveFromSlot(player, slotIndex, placed)

	local name = ItemCatalog.DisplayName(slot.id, slot.meta)
	if placed < want then
		return true, ("ฝาก %s x%d (คลังเต็ม เหลือไว้ %d)"):format(name, placed, want - placed)
	end
	return true, ("ฝาก %s x%d เข้าคลัง"):format(name, placed)
end

--------------------------------------------------------------------------------
-- Taking things out
--------------------------------------------------------------------------------

-- Vault slot -> bag. Given to the bag FIRST and only then removed from the shelf: AddItem is the side that
-- can fail (a full bag), and doing it the other way round would delete the item when it did.
function Vault.Take(player, inventory, slotIndex, count)
	local state = States[player]
	if not state then return false, "ยังโหลดข้อมูลไม่เสร็จ" end

	local slot = state.slots[slotIndex]
	if not slot then return false, "ไม่มีของในช่องนั้น" end

	local held = slot.count or 1
	local want = held
	if type(count) == "number" and count == count then
		want = math.clamp(math.floor(count), 1, held)
	end
	if slot.meta then want = held end

	-- One at a time, so a part-full bag takes what fits instead of refusing the lot. Anything carrying meta is
	-- a single item by definition and goes in one call, which is also the only way its meta survives.
	local moved = 0
	if slot.meta then
		if inventory.AddItem(player, slot.id, 1, slot.durability, slot.meta) then moved = 1 end
	else
		for _ = 1, want do
			if not inventory.AddItem(player, slot.id, 1, slot.durability) then break end
			moved += 1
		end
	end
	if moved <= 0 then return false, "กระเป๋าเต็ม" end

	slot.count = held - moved
	if slot.count <= 0 then state.slots[slotIndex] = nil end

	local name = ItemCatalog.DisplayName(slot.id, slot.meta)
	if moved < want then
		return true, ("เบิก %s x%d (กระเป๋าเต็ม)"):format(name, moved)
	end
	return true, ("เบิก %s x%d ออกจากคลัง"):format(name, moved)
end

return Vault
