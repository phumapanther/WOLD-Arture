-- PlayerInventory.server.lua: wires Inventory into the game's lifecycle and validates every client request.
--
-- The client can only ASK to equip/use/drop/sort. Every handler here re-checks that the slot exists, holds
-- what the client thinks it holds, and that the player is in a state to act at all.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
local ChestAccess = require(game.ServerScriptService.ChestAccess)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)

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
	-- ของเปิดตัวตามที่ผู้ใช้กำหนด: เครื่องมือครบสามอย่าง คันเบ็ด และขนมปังหนึ่งสแตค
	--
	-- ให้เครื่องมือครบทั้งสามเพราะการเก็บเกี่ยวบังคับว่าต้องมีเครื่องมือให้ตรงชนิด คนเข้าใหม่ไม่มีเงิน
	-- และไม่มีทางหาได้เลยถ้าไม่มีอันไหนสักอัน
	{ id = "Axe", count = 1 },
	{ id = "Shovel", count = 1 },
	{ id = "Pickaxe", count = 1 },
	{ id = "FishingRod", count = 1 },
	{ id = "Bread", count = 16 },
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

PlayerJoin.Each(function(player)
	-- Wait for the profile the same way PlayerProgression does, so a returning player gets their own bag back
	-- rather than a fresh starter kit. No deadline -- this is the worst place of all to give up early: the
	-- starter kit handed out when the read was merely slow is what the next autosave writes over the real bag.
	local data = ProfileAccess.Wait(player)
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
	elseif not hasPlayedBefore then
		-- **เงื่อนไขคือ "ไม่เคยเล่นมาก่อน" ไม่ใช่ "กระเป๋าว่าง"**
		--
		-- ของเดิมเช็ค `not saved` ซึ่งเป็นจริงเมื่อกระเป๋าว่างด้วย คนเก่าที่บังเอิญของหมดเกลี้ยงจึงได้ของ
		-- เปิดตัวใหม่ทุกครั้งที่เข้าเกม ซึ่งเป็นบั๊กที่ผู้ใช้รายงาน ตัวชี้ขาดคือโปรไฟล์มีอยู่แล้วหรือยัง
		-- ซึ่งคือ `hasPlayedBefore` ตัวเดียวกับที่ของแจกรอบเดียวใช้อยู่แล้ว
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

local Consuming = require(game.ServerScriptService.Consuming)

-- The click of gear going on. Played at the player rather than to them alone, so someone nearby drawing a
-- sword is something you can hear.
local function playEquipSound(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or CombatConfig.EquipSound == "" then return end
	local sound = Instance.new("Sound")
	sound.SoundId = CombatConfig.EquipSound
	sound.Volume = CombatConfig.EquipSoundVolume
	sound.RollOffMaxDistance = CombatConfig.EquipSoundDistance
	sound.Parent = root
	sound:Play()
	game:GetService("Debris"):AddItem(sound, CombatConfig.EquipSoundMaxSeconds)
end

local function canAct(player)
	-- Nothing in the bag is usable while crawling: a downed player cannot rummage.
	return not Vitals.IsDowned(player)
end

-- Applies what an item does. Split out because it now runs three seconds after the request rather than
-- during it, and both paths have to agree on what "using" means.
local function applyUse(player, item)
	local use = item.use
	if use.stat == "hp" then
		Vitals.Heal(player, use.amount)
	elseif use.stat == "hunger" then
		Vitals.Feed(player, use.amount)
	elseif use.stat == "mana" then
		Vitals.AddMana(player, use.amount)
	elseif use.stat == "chest" then
		-- Using a chest item drops the real chest on the ground beside you. It is not "consumed into an
		-- effect" like food -- it becomes a thing in the world, which is why this returns false when there
		-- is nowhere to put it: the item must stay in the bag rather than vanishing for nothing.
		if not ChestAccess.SpawnNear then return false end
		return ChestAccess.SpawnNear(player, use.tier)
	elseif use.stat == "repair" then
		-- The repair hammer restores EVERYTHING the player owns to full: what they are wearing and wielding,
		-- plus every worn piece sitting in the bag.
		if not Inventory.RepairAll(player) then return false end
		Vitals.SyncArmorFromEquipment(player)
	end
	return true
end

-- Named rather than inline so the hotbar can equip through exactly the same path a click in the bag takes.
-- Two copies of "wear this" would be two places to keep the armor sync and the sound in step.
local function doEquip(player, index)
	if type(index) ~= "number" or not canAct(player) then return end
	if Inventory.Equip(player, index) then
		syncArmor(player)
		playEquipSound(player)
		flush(player)
	end
end

Remotes.RequestEquip.OnServerEvent:Connect(doEquip)

Remotes.RequestUnequip.OnServerEvent:Connect(function(player, kind)
	if kind ~= "weapon" and kind ~= "armor" then return end
	if not canAct(player) then return end
	if Inventory.Unequip(player, kind) then
		syncArmor(player)
		playEquipSound(player)
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

	-- A vehicle key may not be thrown away. The button is hidden for keys in the bag menu, but the refusal
	-- has to live here too: the menu is the client's, and this remote can be fired without it.
	local state = Inventory.Get(player)
	local slot = state and state.slots[index]
	if slot and not ItemCatalog.IsDroppable(slot.id) then
		return Remotes.SocialNotify:FireClient(player, "error", "กุญแจทิ้งไม่ได้ — ทิ้งแล้วรถจะหายจากโรงรถด้วย")
	end

	-- Dropping destroys the item for now; world pickups arrive with the gathering sub-project.
	Inventory.RemoveFromSlot(player, index)
	flush(player)
end)

local function doUseItem(player, index)
	if type(index) ~= "number" or not canAct(player) then return end
	-- One at a time: a second potion while the first is going down would otherwise stack two effects for
	-- one wait.
	if Consuming.IsConsuming(player) then return end

	local state = Inventory.Get(player)
	local slot = state and state.slots[index]
	if not slot then return end

	local item = ItemCatalog.Get(slot.id)
	if not item or item.kind ~= "consumable" or not item.use then return end

	-- Nothing but crawling, while crawling -- and that includes drinking.
	--
	-- Deliberately covers the health potion too. Letting a downed player heal themselves out of it would
	-- make the whole rescue system optional: there would be no reason to wait for help, and no reason for
	-- anyone to come. Being floored has to be something another player gets you out of.
	if Vitals.IsDowned(player) then return end

	-- The repair hammer is a tool, not food -- there is nothing to raise to the mouth, so it stays instant.
	if item.use.stat == "repair" then
		if not applyUse(player, item) then return end
		Inventory.RemoveFromSlot(player, index, 1)
		flush(player)
		-- "used" rather than "start": there is no pose to hold and nothing to finish, only a noise. Sent to
		-- everyone because a hammer is a thing you hear someone else doing, unlike swallowing a potion.
		Remotes.ConsumeStateChanged:FireAllClients(player, "used", slot.id)
		return
	end

	-- Spend the item NOW so it cannot be used twice while the animation runs, and so an interrupted meal
	-- costs something. The effect is what waits.
	local itemId = slot.id
	Inventory.RemoveFromSlot(player, index, 1)
	flush(player)

	local token = Consuming.Begin(player, itemId)
	Remotes.ConsumeStateChanged:FireAllClients(player, "start", itemId)

	task.delay(ItemCatalog.ConsumeSeconds, function()
		-- Stale finish: they were interrupted, left, or started something else.
		if not player.Parent or not Consuming.StillCurrent(player, token) then return end
		Consuming.Cancel(player)
		-- Going down mid-meal wastes it, the same as any other interruption.
		if Vitals.IsDowned(player) then
			Remotes.ConsumeStateChanged:FireAllClients(player, "cancel", itemId)
			return
		end
		applyUse(player, item)
		Remotes.ConsumeStateChanged:FireAllClients(player, "finish", itemId)
	end)
end

Remotes.RequestUseItem.OnServerEvent:Connect(doUseItem)

-- Dropping an item onto a hotbar slot. The client says what it wants placed; the server decides whether that
-- is a real item and stores it.
Remotes.RequestSetHotbar.OnServerEvent:Connect(function(player, index, id)
	if not canAct(player) then return end
	-- nil clears the slot, which is how dragging something back out of the bar works.
	if id ~= nil and type(id) ~= "string" then return end
	if Inventory.SetHotbar(player, index, id) then
		Inventory.Send(player)
		flush(player)
	end
end)

-- Pressing a hotbar slot. What that means depends on what is in it: food is eaten, a weapon or a piece of
-- armor is worn. The bar holds an ITEM rather than an action, so the difference is decided here -- and it
-- routes through the same two functions a click in the bag uses, so nothing is validated twice or
-- differently.
Remotes.RequestUseHotbar.OnServerEvent:Connect(function(player, index)
	if type(index) ~= "number" or not canAct(player) then return end
	local state = Inventory.Get(player)
	local id = state and state.hotbar and state.hotbar[index]
	if not id then return end

	-- Looked up now rather than remembered: the bag gets sorted and items move, and the last of something
	-- can be used up entirely, in which case the slot simply does nothing until it is refilled.
	local slotIndex = Inventory.FindSlotById(player, id)
	if not slotIndex then return end

	local item = ItemCatalog.Get(id)
	if not item then return end
	if item.kind == "consumable" then
		doUseItem(player, slotIndex)
	elseif item.kind == "weapon" or item.kind == "armor" then
		doEquip(player, slotIndex)
	end
end)

-- Being downed or dying interrupts whatever was being eaten.
local function interrupt(player)
	if Consuming.Cancel(player) then
		Remotes.ConsumeStateChanged:FireAllClients(player, "cancel")
	end
end

Players.PlayerRemoving:Connect(function(player)
	Consuming.Remove(player)
end)

PlayerJoin.Each(function(player)
	player.CharacterRemoving:Connect(function()
		interrupt(player)
	end)
end)

