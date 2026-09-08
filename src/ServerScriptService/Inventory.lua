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

local function firstFreeSlot(state)
	for i = 1, InventoryConfig.SlotCount do
		if state.slots[i] == nil then return i end
	end
	return nil
end

-- Fills existing stacks before opening a new slot, so picking up ten stones does not eat ten slots.
function Inventory.AddItem(player, id, count, durability)
	local state = States[player]
	if not state or not ItemCatalog.Exists(id) then return false end
	count = count or 1

	local stackSize = ItemCatalog.StackSize(id)
	if stackSize > 1 then
		for i = 1, InventoryConfig.SlotCount do
			local slot = state.slots[i]
			if slot and slot.id == id and slot.count < stackSize then
				local moved = math.min(stackSize - slot.count, count)
				slot.count += moved
				count -= moved
				if count <= 0 then
					Inventory.Send(player)
					return true
				end
			end
		end
	end

	while count > 0 do
		local free = firstFreeSlot(state)
		if not free then
			Inventory.Send(player)
			return false -- bag full; whatever fitted has been kept
		end
		local put = math.min(stackSize, count)
		local item = ItemCatalog.Get(id)
		state.slots[free] = {
			id = id,
			count = put,
			-- Weapons and armor track wear; nothing else does.
			durability = durability or item.maxDurability or item.armor,
		}
		count -= put
	end

	Inventory.Send(player)
	return true
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

function Inventory.AutoSort(player)
	local state = States[player]
	if not state then return end

	local totals = {} -- [id] = count, for stackables
	local singles = {} -- weapons/armor keep their own durability, so they never merge
	for i = 1, InventoryConfig.SlotCount do
		local slot = state.slots[i]
		if slot then
			if ItemCatalog.StackSize(slot.id) > 1 then
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
		local ka = KIND_ORDER[ItemCatalog.Get(a.id).kind] or 9
		local kb = KIND_ORDER[ItemCatalog.Get(b.id).kind] or 9
		if ka ~= kb then return ka < kb end
		if a.id ~= b.id then return a.id < b.id end
		return (a.count or 1) > (b.count or 1)
	end)

	for i, entry in ipairs(entries) do
		if i > InventoryConfig.SlotCount then break end
		state.slots[i] = entry
	end

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
	state.equipped[key] = { id = slot.id, durability = slot.durability }
	state.slots[index] = nil
	-- The piece coming off goes back into the bag rather than vanishing.
	if previous then
		Inventory.AddItem(player, previous.id, 1, previous.durability)
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
	for i = 1, InventoryConfig.SlotCount do restore(state.slots[i]) end

	if repaired then Inventory.Send(player) end
	return repaired
end

function Inventory.Unequip(player, kind)
	local state = States[player]
	local entry = state and state.equipped[kind]
	if not entry then return false end
	state.equipped[kind] = nil
	Inventory.AddItem(player, entry.id, 1, entry.durability)
	broadcastEquipment(player, state)
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

function Inventory.Send(player)
	local state = States[player]
	if not state then return end
	Remotes.InventoryUpdate:FireClient(player, {
		slots = state.slots,
		equipped = state.equipped,
		gold = state.gold,
		weight = Inventory.Weight(player),
		maxWeight = InventoryConfig.MaxWeight,
	})
end

function Inventory.Serialize(player)
	local state = States[player]
	if not state then return nil end
	return { Slots = state.slots, Equipped = state.equipped, Gold = state.gold }
end

return Inventory
