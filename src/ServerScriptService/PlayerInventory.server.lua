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
-- What a brand-new player starts with. Deliberately modest: the full set is a one-off test grant below, not
-- the normal opening hand.
local STARTER_KIT = {
	{ id = "Sword", count = 1 },
	{ id = "LeatherArmor", count = 1 },
	{ id = "Bread", count = 3 },
	{ id = "HealthPotion", count = 2 },
}

-- One-off grant for everyone who has already played, so existing testers all hold the same full kit. Runs
-- once per player, ever: TestGrant in their profile records the version they last received, and only a player
-- whose profile ALREADY EXISTS is eligible — someone joining for the first time after this gets the starter
-- kit above and nothing more.
local TEST_GRANT_VERSION = 1
local TEST_GRANT = {
	-- Every weapon and every armor set, one each.
	{ id = "Sword" }, { id = "Bow" }, { id = "Staff" }, { id = "Spellbook" },
	{ id = "LeatherArmor" }, { id = "ChainmailArmor" }, { id = "PlateArmor" },
	-- Consumables to a full stack, whatever that stack size happens to be.
	{ id = "Bread", full = true },
	{ id = "Water", full = true },
	{ id = "HealthPotion", full = true },
	{ id = "RepairHammer", full = true },
}

Players.PlayerAdded:Connect(function(player)
	-- Wait for the profile the same way PlayerProgression does, so a returning player gets their own bag back
	-- rather than a fresh starter kit.
	local data
	for _ = 1, 40 do
		data = ProfileAccess.Get(player)
		if data then break end
		task.wait(0.1)
	end
	local saved = data and data.Inventory

	-- Eligibility for the one-off grant is "has PLAYED before", which is whether a profile exists at all —
	-- not whether a bag was saved. Keying it off the bag missed anyone who had played before inventories
	-- existed, which is most of the current testers.
	local hasPlayedBefore = data ~= nil and data.Position ~= nil
	local wantsGrant = hasPlayedBefore and (data.TestGrant or 0) < TEST_GRANT_VERSION

	Inventory.Add(player, saved)

	if wantsGrant then
		-- Clear first, so every tester ends up holding exactly the same kit rather than it piling on top of
		-- whatever they happened to have.
		data.TestGrant = TEST_GRANT_VERSION
		local state = Inventory.Get(player)
		if state then
			state.slots = {}
			state.equipped = {}
		end
		for _, entry in ipairs(TEST_GRANT) do
			local count = entry.full and ItemCatalog.StackSize(entry.id) or 1
			Inventory.AddItem(player, entry.id, count)
		end
		if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	elseif not saved then
		-- Brand new: the ordinary opening hand.
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

-- A client that connected too late to catch the join broadcast asks for one. Read-only: it sends the
-- player their own bag and nothing else, so there is nothing to abuse beyond asking for what they can
-- already see. Inventory.Send is a no-op when the profile has not loaded yet, and the client retries.
Remotes.RequestInventoryRefresh.OnServerEvent:Connect(function(player)
	Inventory.Send(player)
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
		-- The repair hammer restores EVERYTHING the player owns to full: what they are wearing and wielding,
		-- plus every worn piece sitting in the bag. Refuse (and keep the hammer) when nothing needs it.
		if not Inventory.RepairAll(player) then return end
		Vitals.SyncArmorFromEquipment(player)
	end

	Inventory.RemoveFromSlot(player, index, 1)
	flush(player)
end)
