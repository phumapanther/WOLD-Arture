-- PlayerInventory.server.lua: wires Inventory into the game's lifecycle and validates every client request.
--
-- The client can only ASK to equip/use/drop/sort. Every handler here re-checks that the slot exists, holds
-- what the client thinks it holds, and that the player is in a state to act at all.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
local ChestAccess = require(game.ServerScriptService.ChestAccess)
local MonowheelAccess = require(game.ServerScriptService.MonowheelAccess)
local AuraAccess = require(game.ServerScriptService.AuraAccess)
local ClanOutfitAccess = require(game.ServerScriptService.ClanOutfitAccess)
local Classes = require(game.ServerScriptService.Classes)
local ClassConfig = require(game.ReplicatedStorage.ClassConfig)
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

-- ของเปิดตัวและกติกา "ใครใหม่" อยู่ใน StarterKit.lua (ทดสอบได้) — ไม่มีอาวุธ/เกราะ ตามที่ผู้ใช้กำหนด
local StarterKit = require(game.ServerScriptService.StarterKit)

-- ⚠️ เคยมี TEST_GRANT (อาวุธ 4 · เกราะ 3 · ยา · ค้อนซ่อม) แจกครั้งเดียวให้คนที่ "เคยเล่นแล้ว" ตอนยังเป็นช่วงเทส
-- ถูกลบทิ้ง 2026-09-25 เพราะมันยิงใส่ **ผู้เล่นใหม่ทุกคนตอนเข้าเกมครั้งที่สอง** (ของเปิดตัวไม่ได้ปั๊ม TestGrant ไว้)
-- แล้วล้างกระเป๋าทิ้งทั้งใบ = เครื่องมือฟาร์มหาย ได้อาวุธกับเกราะมาแทน ซึ่งคือสิ่งที่ผู้ใช้เห็นในเกมจริง

PlayerJoin.Each(function(player)
	-- ⚠️ **ในสนาม PVP ไม่มีโปรไฟล์ให้รอ** — เซิร์ฟแมตช์ไม่เปิดเซสชันของใครเลย (ถ้าเปิดแล้วเซฟตอนจบ
	-- กระเป๋าจริงของคนเล่นจะถูกทับด้วยของที่ซื้อในแมตช์ ซึ่ง `06-modes-build-plan.md` §4.3 เตือนไว้)
	--
	-- กระเป๋าในสนามจึงเป็น **ใบเปล่าที่เกิดใหม่ทุกแมตช์** ไม่มีของเปิดตัว ไม่มีของแจก ไม่มีการเซฟ
	-- ของทุกชิ้นในนั้นมาจากร้านในสนามอย่างเดียว ซึ่งคือข้อ "ทุกคนเท่าเทียมกันเวลาสู้" ที่ผู้ใช้สั่ง
	if ServerConfig.IsArena then
		Inventory.Add(player, nil)
		Inventory.Send(player)
		Vitals.SyncArmorFromEquipment(player)
		return
	end

	-- Wait for the profile the same way PlayerProgression does, so a returning player gets their own bag back
	-- rather than a fresh starter kit. No deadline -- this is the worst place of all to give up early: the
	-- starter kit handed out when the read was merely slow is what the next autosave writes over the real bag.
	local data = ProfileAccess.Wait(player)
	local saved = data and data.Inventory

	local giveKit = StarterKit.ShouldGive(data, saved)

	Inventory.Add(player, saved)

	-- ของเกาะที่เซฟไว้ก่อนแยกช่อง (2026-09-22) ยังอยู่ในช่องเกมหลัก — ย้ายให้ตอนโหลด ครั้งเดียวต่อรอบเข้าเกม
	-- เงียบเมื่อไม่มีอะไรต้องย้าย จึงปลอดภัยที่จะเรียกทุกครั้ง
	local movedVip = Inventory.MigrateVipSlots(player)
	if movedVip > 0 then
		print(("[Inventory] ย้ายของเกาะ %d ชิ้นไปช่องกระเป๋า VIP ของ %s"):format(movedVip, player.Name))
	end

	if giveKit then
		for _, entry in ipairs(StarterKit.Items) do
			Inventory.AddItem(player, entry.id, entry.count)
		end
		-- จดในโปรไฟล์เดียวกับกระเป๋า: เซฟพร้อมกันเสมอ (เซิร์ฟล่มก่อนเซฟ = หายทั้งคู่ ได้ชุดใหม่ครั้งหน้าอย่างถูกต้อง)
		data.StarterKit = true
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

-- "3 นาที" / "45 วินาที" — ยาชูกำลังอยู่หนึ่งนาที ถ้าปัดเป็นนาทีเสมอ ของที่สั้นกว่านั้นจะแจ้งว่า "0 นาที"
local function durationText(seconds)
	if seconds < 60 then return ("%d วินาที"):format(math.floor(seconds)) end
	return ("%d นาที"):format(math.floor(seconds / 60))
end

-- แจ้งคนกินว่าได้บัพอะไรนานเท่าไหร่ ชื่อบัพมาจาก Vitals ที่เดียว (ดู `Vitals.BuffText`)
local function notifyBuff(player, buff, seconds)
	Remotes.SocialNotify:FireClient(player, "info", ("%s %s"):format(Vitals.BuffText(buff), durationText(seconds)))
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
	elseif use.stat == "meal" then
		-- เมนูจากครัว: อิ่มทันที / มานาเต็ม / บัพตามเมนู
		if use.hunger then Vitals.Feed(player, 99999) end
		if use.mana then Vitals.AddMana(player, 99) end
		if use.buff then
			Vitals.AddBuff(player, use.buff, use.seconds or 300)
			notifyBuff(player, use.buff, use.seconds or 300)
		end
	elseif use.stat == "firstaid" then
		-- กล่องปฐมพยาบาล: พันแผลแล้วเลือดเต็ม (ท่าพันแผลอยู่ฝั่งไคลเอนต์ระหว่างรอ)
		Vitals.HealFraction(player, 1)
		-- บัพหลังพันแผล (ตอนนี้คือ "เลือดไม่ลด" 10 วิ) — อ่านจาก ItemCatalog ไม่ได้ฝังชื่อบัพไว้ตรงนี้
		-- จะเปลี่ยนบัพหรือเวลาในอนาคตก็แก้ที่ไอเทมชิ้นนั้นที่เดียว เหมือนอาหารทุกจาน
		if use.buff then
			Vitals.AddBuff(player, use.buff, use.seconds or 10)
			notifyBuff(player, use.buff, use.seconds or 10)
		end
	elseif use.stat == "healfull" then
		-- ยาใหญ่: เลือดเต็มหลอด เป็นสัดส่วนไม่ใช่ตัวเลข เลือดสูงสุดโตตามเลเวลแต่ขวดนี้เต็มเสมอ
		Vitals.HealFraction(player, 1)
	elseif use.stat == "magicbox" then
		local MagicBox = require(game.ServerScriptService.MagicBox)
		local got = MagicBox.Roll()
		if not got then return false end
		if not Inventory.HasRoomFor(player, got.id, got.count) then
			Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม เปิดกล่องไม่ได้")
			return false
		end
		Inventory.AddItem(player, got.id, got.count)
		local prize = ItemCatalog.Get(got.id)
		Remotes.SocialNotify:FireClient(player, "info", ("กล่องเวทมนตร์: ได้ %s x%d"):format(prize and prize.name or got.id, got.count))
	elseif use.stat == "buff" then
		-- ของพรีเมียม: บัพชั่วคราวล้วน ไม่ทำให้อิ่ม (ยาชูกำลัง) — ชื่อบัพรับได้ทั้งเดี่ยว "both" "all" และตาราง
		Vitals.AddBuff(player, use.buff, use.seconds or 600)
		notifyBuff(player, use.buff, use.seconds or 600)
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
	elseif Inventory.Get(player) and Inventory.Get(player).equipped[kind] then
		-- ถอดไม่ได้เพราะกระเป๋าเต็ม (Unequip ไม่ยอมให้ล้นเข้าคลัง) — บอกตรงๆ ไม่ใช่ปุ่มที่กดแล้วเงียบ
		Remotes.SocialNotify:FireClient(player, "warn", "กระเป๋าเต็ม ถอดไม่ได้")
	end
end)

-- A client that connected too late to catch the join broadcast asks for one. Read-only: it sends the
-- player their own bag and nothing else, so there is nothing to abuse beyond asking for what they can
-- already see. Inventory.Send is a no-op when the profile has not loaded yet, and the client retries.
Remotes.RequestInventoryRefresh.OnServerEvent:Connect(function(player)
	Inventory.Send(player)
end)

Remotes.RequestAutoSort.OnServerEvent:Connect(function(player, tab)
	if not canAct(player) then return end
	-- **จัดเฉพาะกระเป๋าใบที่เปิดอยู่** ไคลเอนต์ส่งชื่อแท็บมา · ค่าอื่นที่ไม่รู้จัก (หรือไคลเอนต์เก่า
	-- ที่ไม่ส่งอะไรมา) = จัดทั้งสองใบเหมือนเดิม ซึ่งไม่ทำอะไรพัง แค่ไม่ใช่สิ่งที่ผู้ใช้ขอ
	Inventory.AutoSort(player, tab == "main" and "main" or tab == "farm" and "farm" or nil)
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
	if not item then return end

	-- ออร่า: กดใช้ = เปิด/ปิด ไม่ถูกใช้หมด Auras.server เป็นเจ้าของเอฟเฟกต์
	if item.kind == "aura" then
		if AuraAccess.Toggle then AuraAccess.Toggle(player, slot.id) end
		return
	end
	-- ของเฉพาะอาชีพ (ยังไม่มีไอเทมไหนใช้อยู่ตอนนี้ — กล่องปฐมพยาบาลเปิดให้ทุกคนแล้ว)
	--
	-- `item.use and` ต้องมี: ด่าน "ไม่ใช่ consumable ก็จบ" ย้ายลงไปอยู่หลังแหวนแคลนแล้ว ของอย่างก้อนหิน
	-- จึงเดินมาถึงบรรทัดนี้ได้โดยไม่มี use เลย
	if item.use and item.use.classOnly and not Classes.Has(player, item.use.classOnly) then
		local class = ClassConfig.Get(item.use.classOnly)
		return Remotes.SocialNotify:FireClient(player, "warn", ("เฉพาะ%sเท่านั้น"):format(class and class.name or item.use.classOnly))
	end

	-- Nothing but crawling, while crawling -- and that includes drinking.
	--
	-- Deliberately covers the health potion too. Letting a downed player heal themselves out of it would
	-- make the whole rescue system optional: there would be no reason to wait for help, and no reason for
	-- anyone to come. Being floored has to be something another player gets you out of.
	if Vitals.IsDowned(player) then return end

	-- แหวนแคลน: กดแล้วใส่/ถอดชุดแคลน และ **ไม่ถูกใช้หมดไป**
	--
	-- อยู่ก่อนด่าน `kind ~= "consumable"` เพราะแหวนเป็น token และอยู่ก่อนทางที่ลบไอเทมด้วยเหตุผลเดียวกับ
	-- จักรยานล้อเดียว: แหวนเป็นของประจำตำแหน่ง ลบแล้วต้องรอ BoundItems เติมคืน
	if item.use and item.use.stat == "clanoutfit" then
		if not ClanOutfitAccess.Toggle then return end
		local ok, message = ClanOutfitAccess.Toggle(player)
		Remotes.SocialNotify:FireClient(player, ok and "info" or "warn", tostring(message))
		return
	end

	if item.kind ~= "consumable" or not item.use then return end

	-- จักรยานล้อเดียว: กดแล้วเรียก/เก็บทันที และ **ไม่ถูกใช้หมดไป**
	--
	-- แยกออกมาก่อนทางของค้อนซ่อม เพราะทางนั้นลบของทิ้งหนึ่งชิ้นหลังใช้ ซึ่งจะทำให้จักรยานหายจากกระเป๋า
	-- ตั้งแต่กดครั้งแรก แล้วไม่มีทางได้คืนเลย
	if item.use.stat == "monowheel" then
		if not MonowheelAccess.Toggle then return end
		local ok, message = MonowheelAccess.Toggle(player)
		Remotes.SocialNotify:FireClient(player, ok and "info" or "error", tostring(message))
		return
	end

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

	task.delay(ItemCatalog.HoldSeconds(itemId), function()
		-- Stale finish: they were interrupted, left, or started something else.
		if not player.Parent or not Consuming.StillCurrent(player, token) then return end
		Consuming.Cancel(player)
		-- Going down mid-meal wastes it, the same as any other interruption.
		if Vitals.IsDowned(player) then
			Remotes.ConsumeStateChanged:FireAllClients(player, "cancel", itemId)
			return
		end
		-- ⚠️ **คืนของเมื่อใช้ไม่สำเร็จ** — ของถูกหักไปตั้งแต่ตอนเริ่ม (กันกดซ้ำระหว่างท่า) แต่
		-- `applyUse` บอกว่าทำไม่ได้ได้ด้วย: หีบที่หาพื้นวางไม่เจอ · ค้อนที่ไม่มีอะไรให้ซ่อม
		-- คอมเมนต์ใน `applyUse` เขียนไว้ตั้งแต่แรกว่า "ของต้องอยู่ในกระเป๋าต่อ" ซึ่งเป็นจริงแค่ใน
		-- สาขา `repair` ที่หักของทีหลัง — ทางนี้กลืนคำตอบทิ้งมาตลอด
		--
		-- เทียบกับ `false` ตรงๆ ไม่ใช่ `not ok`: สาขาอื่นคืน nil ซึ่ง falsy เหมือนกัน แต่แปลว่า "สำเร็จ"
		if applyUse(player, item) == false then
			Inventory.AddItem(player, itemId, 1)
			Inventory.Send(player)
			flush(player)
			Remotes.ConsumeStateChanged:FireAllClients(player, "cancel", itemId)
			return
		end
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

