-- PlayerInventory.server.lua: wires Inventory into the game's lifecycle and validates every client request.
--
-- The client can only ASK to equip/use/drop/sort. Every handler here re-checks that the slot exists, holds
-- what the client thinks it holds, and that the player is in a state to act at all.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)

if ServerConfig.IsLobby then return end

ProfileAccess.SerializeInventory = Inventory.Serialize
Vitals.BindInventory(Inventory)

-- The armor pool follows the worn set, so re-sync on every equipment change rather than only on equip: this
-- covers unequipping and swapping too.
local function syncArmor(player)
	task.defer(function() Vitals.SyncArmorFromEquipment(player) end)
end

-- Starting kit, so a new player has something to test the bag with rather than an empty grid.
-- ponytail: all four weapons for now so every Q skill is reachable without a shop or drops. Trim this to a
-- sword once items can actually be found in the world.
local STARTER_KIT = {
	{ id = "Sword", count = 1 },
	{ id = "Bow", count = 1 },
	{ id = "Staff", count = 1 },
	{ id = "Spellbook", count = 1 },
	{ id = "LeatherArmor", count = 1 },
	{ id = "Bread", count = 3 },
	{ id = "Water", count = 3 },
	{ id = "HealthPotion", count = 2 },
	{ id = "RepairHammer", count = 1 },
}

Players.PlayerAdded:Connect(function(player)
	-- Wait for the profile the same way PlayerProgression does, so a returning player gets their own bag back
	-- rather than a fresh starter kit.
	local saved
	for _ = 1, 40 do
		local data = ProfileAccess.Get(player)
		if data then
			saved = data.Inventory
			break
		end
		task.wait(0.1)
	end

	Inventory.Add(player, saved)
	if not saved then
		for _, entry in ipairs(STARTER_KIT) do
			Inventory.AddItem(player, entry.id, entry.count)
		end
	end
	Inventory.Send(player)
	Vitals.SyncArmorFromEquipment(player)
end)

Players.PlayerRemoving:Connect(function(player)
	Inventory.Remove(player)
end)

--------------------------------------------------------------------------------
-- Client requests. Each one re-validates rather than trusting the index it was handed.
--------------------------------------------------------------------------------

-- Anything that changes the bag is worth persisting at once rather than waiting for the autosave tick.
local function flush(player)
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
end

local function canAct(player)
	-- Nothing in the bag is usable while crawling: a downed player cannot rummage.
	return not Vitals.IsDowned(player)
end

Remotes.RequestEquip.OnServerEvent:Connect(function(player, index)
	if type(index) ~= "number" or not canAct(player) then return end
	if Inventory.Equip(player, index) then
		syncArmor(player)
		flush(player)
	end
end)

Remotes.RequestUnequip.OnServerEvent:Connect(function(player, kind)
	if kind ~= "weapon" and kind ~= "armor" then return end
	if not canAct(player) then return end
	if Inventory.Unequip(player, kind) then
		syncArmor(player)
		flush(player)
	end
end)

Remotes.RequestAutoSort.OnServerEvent:Connect(function(player)
	if not canAct(player) then return end
	Inventory.AutoSort(player)
	flush(player)
end)

Remotes.RequestDropItem.OnServerEvent:Connect(function(player, index)
	if type(index) ~= "number" or not canAct(player) then return end
	-- Dropping destroys the item for now; world pickups arrive with the gathering sub-project.
	Inventory.RemoveFromSlot(player, index)
	flush(player)
end)

Remotes.RequestUseItem.OnServerEvent:Connect(function(player, index)
	if type(index) ~= "number" or not canAct(player) then return end
	local state = Inventory.Get(player)
	local slot = state and state.slots[index]
	if not slot then return end

	local item = ItemCatalog.Get(slot.id)
	if not item or item.kind ~= "consumable" or not item.use then return end

	local use = item.use
	if use.stat == "hp" then
		Vitals.Heal(player, use.amount)
	elseif use.stat == "hunger" then
		Vitals.Feed(player, use.amount)
	elseif use.stat == "mana" then
		Vitals.AddMana(player, use.amount)
	elseif use.stat == "repair" then
		-- The repair hammer restores the equipped armor rather than healing the player.
		local armorItem, entry = Inventory.EquippedArmor(player)
		if not armorItem or not entry then return end -- nothing to repair: don't consume the hammer
		entry.durability = armorItem.armor
		Vitals.SyncArmorFromEquipment(player)
	end

	Inventory.RemoveFromSlot(player, index, 1)
	flush(player)
end)
