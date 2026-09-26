-- BankVault.server.lua: Madam Aurelia, who keeps your money and your things.
--
-- Found by TAG like every other working villager: WOLD_Npc with NpcKind="bank". The user places the model;
-- this file never knows where she stands.
--
-- Two halves behind one counter:
--   * the purse -- pocket gold in and out of the bank balance, which is the balance the speaking stone has
--     always shown. Bank.lua already owns it and validates every amount; this adds a second door to the same
--     room rather than a second room.
--   * the warehouse -- Vault.lua, a second set of shelves that does not travel with the player.
--
-- Every number the client sends is a wish. What is actually moved is decided here, from state the client
-- cannot see, and the whole picture is pushed back afterwards so the window can never be showing a balance
-- the server does not agree with.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local IslandAccess = require(game.ServerScriptService.Island.IslandAccess)
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local InventoryConfig = require(game.ReplicatedStorage.InventoryConfig)
local Inventory = require(game.ServerScriptService.Inventory)
local Bank = require(game.ServerScriptService.Bank)
local Vault = require(game.ServerScriptService.Vault)
local Vitals = require(game.ServerScriptService.Vitals)
local EventState = require(game.ServerScriptService.EventState)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)

local TAG = "WOLD_Npc"
local KIND = "bank"
local RANGE = 12

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

ProfileAccess.SerializeVault = function(player)
	return Vault.Serialize(player)
end

-- Same shape as PlayerSocial's loader: wait for the profile, then start from what it holds. A load that never
-- arrives starts an empty warehouse, which is the safe direction -- an empty one can be filled, but one
-- invented from nothing could be SAVED over the real one.
local function load(player)
	local data = ProfileAccess.Wait(player)
	local saved = data and data.Vault
	Vault.Add(player, saved)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(load, player)
end)

Players.PlayerRemoving:Connect(function(player)
	Vault.Remove(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(load, player)
end

--------------------------------------------------------------------------------
-- Who is close enough
--------------------------------------------------------------------------------

local function nearBanker(player)
	-- แขกบนเกาะของคนอื่นคุยกับ NPC ของเจ้าบ้านไม่ได้ (ผู้ใช้สั่ง 2026-09-23)
	-- ตอบที่นี่ที่เดียวเพราะทั้งปุ่ม E และ remote ทุกตัวถามผ่านฟังก์ชันนี้ — ปิดประตูบานเดียวพอ
	if not IslandAccess.MayUseFixtures(player) then return false end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	for _, npc in ipairs(CollectionService:GetTagged(TAG)) do
		if npc:GetAttribute("NpcKind") == KIND then
			local position = npc:IsA("BasePart") and npc.Position or npc:GetPivot().Position
			if (position - root.Position).Magnitude <= RANGE then return true end
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- The whole picture
--------------------------------------------------------------------------------

-- Rows are built from the SERVER's copy of the bag and the shelves, so the window is never drawing from the
-- client's own idea of what it is carrying. The slot index rides along with each row and is the only thing
-- an action names.
local function rows(slots, count)
	local out = {}
	for index = 1, count do
		local slot = slots[index]
		if slot then
			local item = ItemCatalog.Get(slot.id)
			if item then
				table.insert(out, {
					slot = index, id = slot.id, name = ItemCatalog.DisplayName(slot.id, slot.meta),
					icon = item.icon,
					count = slot.count or 1,
					-- So the window can mark a keyed item as one indivisible thing rather than offering to
					-- split a stack of one.
					unique = slot.meta ~= nil or nil,
				})
			end
		end
	end
	return out
end

-- **ที่ที่ของล้นเพดานพกติดตัวไปลง** (ผู้ใช้สั่ง 2026-09-20)
--
-- ตั้งไว้ที่นี่เพราะไฟล์นี้คือเจ้าของคลัง ส่วน `Inventory` แค่ถือ hook ไว้เฉยๆ — กระเป๋าจึงไม่ต้องรู้จัก
-- คลัง และเพลสที่ไม่มีมาดามออเรเลีย (ล็อบบี้) ก็ไม่มีใครตั้ง hook นี้ ของที่เกินก็แค่ใส่ไม่ได้ตามปกติ
Inventory.Overflow = function(player, id, count, durability, meta)
	local placed = Vault.Deposit(player, id, count, durability, meta)
	-- เซฟทันทีเหมือนทุกครั้งที่ของเข้าคลัง (เหตุผลเดียวกับ `Bank.set`): ของที่ฝากไว้สำคัญเกินกว่าจะหาย
	-- ไปกับช่วงรอ autosave · หน้าต่างคลังที่เปิดค้างอยู่จะเห็นของใหม่ตอนกดอะไรสักอย่างในหน้าต่างนั้น
	-- ซึ่งส่งภาพรวมกลับมาใหม่ทุกครั้งอยู่แล้ว
	if placed > 0 and ProfileAccess.Flush then ProfileAccess.Flush(player) end
	return placed
end
Inventory.OverflowRoom = Vault.RoomFor

local function snapshot(player)
	local bag = Inventory.Get(player)
	local vault = Vault.Get(player)
	return {
		gold = bag and bag.gold or 0,
		banked = Bank.Get(player),
		bag = bag and rows(bag.slots, InventoryConfig.SlotCount) or {},
		vault = vault and rows(vault.slots, Vault.SlotCount) or {},
		vaultSlots = Vault.SlotCount,
		vaultUsed = vault and (function()
			local used = 0
			for i = 1, Vault.SlotCount do
				if vault.slots[i] then used += 1 end
			end
			return used
		end)() or 0,
	}
end

-- The same two conditions the shop and the forge check, in the same order: you cannot do business face-down
-- in the dirt, and you cannot do business at all while the city's engines are out.
local function canTrade(player)
	if Vitals.IsDowned(player) then return false end
	return EventState.NpcAvailable()
end

local function open(player)
	local ok, reason = canTrade(player)
	if not ok then
		if reason then Remotes.SocialNotify:FireClient(player, "error", reason) end
		return
	end
	Remotes.VaultOpen:FireClient(player, snapshot(player))
end

Remotes.RequestVaultOpen.OnServerEvent:Connect(function(player)
	if not nearBanker(player) then return end
	open(player)
end)

--------------------------------------------------------------------------------
-- Doing business
--------------------------------------------------------------------------------

Remotes.RequestVaultAction.OnServerEvent:Connect(function(player, action, index, amount)
	if type(action) ~= "string" then return end

	local allowed, reason = canTrade(player)
	if not allowed then
		if reason then Remotes.SocialNotify:FireClient(player, "error", reason) end
		return
	end
	-- Re-checked on every action rather than only on opening: a player can walk away with the window still up.
	if not nearBanker(player) then
		return Remotes.SocialNotify:FireClient(player, "error", "อยู่ไกลจากธนาคารเกินไป")
	end

	local ok, message
	if action == "deposit" then
		ok, message = Bank.Deposit(player, amount)
	elseif action == "withdraw" then
		ok, message = Bank.Withdraw(player, amount)
	elseif action == "store" then
		if type(index) ~= "number" then return end
		-- A vehicle key may not be put away. Taking one OUT is still allowed on purpose: profiles saved
		-- before this rule may already have a key sitting in the warehouse, and trapping it there would be
		-- a car its owner can never reach again.
		local state = Inventory.Get(player)
		local slot = state and state.slots[index]
		if slot and not ItemCatalog.IsStorable(slot.id) then
			Remotes.SocialNotify:FireClient(player, "error", "กุญแจเก็บในคลังไม่ได้ — ต้องพกติดตัวไว้")
			Remotes.VaultOpen:FireClient(player, snapshot(player))
			return
		end
		ok, message = Vault.Store(player, Inventory, index, amount)
	elseif action == "take" then
		if type(index) ~= "number" then return end
		ok, message = Vault.Take(player, Inventory, index, amount)
	else
		return
	end

	if message then
		Remotes.SocialNotify:FireClient(player, ok and "info" or "error", message)
	end
	-- Flushed on anything that worked, for the reason Bank.set gives: money and stored goods are too
	-- important to lose to the gap between autosave ticks.
	if ok and ProfileAccess.Flush then ProfileAccess.Flush(player) end

	-- Redrawn from a fresh snapshot even on a refusal, so a window that was showing a stale bag corrects
	-- itself instead of leaving the player pressing a row that is no longer there.
	Remotes.VaultOpen:FireClient(player, snapshot(player))
end)

--------------------------------------------------------------------------------
-- The prompt on the NPC
--------------------------------------------------------------------------------

local function register(npc)
	if npc:GetAttribute("NpcKind") ~= KIND then return end
	-- HumanoidRootPart first, for the reason Shop.server gives: the kit's NPC models set PrimaryPart to a 1x1
	-- pivot handle at the model's feet, and a prompt measures its range from the part it hangs on.
	local anchor = npc:IsA("BasePart") and npc
		or (npc:IsA("Model") and (npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("UpperTorso")
			or npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart", true)))
	if not anchor then return end
	if anchor:FindFirstChild("VaultPrompt") then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VaultPrompt"
	-- ป้ายปรับได้จากแอตทริบิวต์ เพราะ "นายธนาคาร" ไม่ใช่คำที่ถูกเสมอ — บนเกาะมันคือลังไม้ ไม่ใช่คน
	prompt.ActionText = npc:GetAttribute("NpcAction") or "ธนาคาร/คลัง"
	prompt.ObjectText = npc:GetAttribute("NpcName") or "นายธนาคาร"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = RANGE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = anchor

	prompt.Triggered:Connect(open)
end

for _, npc in ipairs(CollectionService:GetTagged(TAG)) do
	task.spawn(register, npc)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(npc)
	task.spawn(register, npc)
end)
