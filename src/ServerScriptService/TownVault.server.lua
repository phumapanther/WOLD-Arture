-- TownVault.server.lua: คลังเมือง — ของ **เมือง** ที่แคลนผู้ยึดใช้ร่วมกัน
--
-- กติกาที่ผู้ใช้กำหนด (2026-09-19):
--   · ใช้ได้เฉพาะสมาชิกแคลนที่ยึดเมืองนั้นอยู่ **ตอนนี้**
--   · เป็นคลังรวม ทุกคนในแคลนเห็นของเหมือนกัน และเอาเข้า-ออกได้ทุกคน (ไม่มีชั้นยศแบบคลังแคลน)
--   · เก็บ Log ว่าใครเอาอะไรเข้า/ออก ย้อนหลัง 10 ครั้ง
--   · เปิดด้วยปุ่ม **F** ที่จุดยึด (อนุสาวรีย์) — คนไม่มีแคลนไม่เห็นปุ่มอะไรเลย · คนมีแคลนที่ไม่ได้ถือเมือง
--     เห็นแค่ **E** (ยึด) · คนของแคลนที่ถือเมืองอยู่เห็นแค่ **F**
--
-- **ของอยู่กับเมือง ไม่ได้อยู่กับแคลน**: เมืองเปลี่ยนมือแล้วของที่ค้างในคลังตกเป็นของผู้ยึดคนใหม่
-- นี่คือการอ่านคำว่า "คลังเมือง" ตรงตัว และทำให้การเสียเมืองมีราคาจริง — ถ้าอยากให้ของตามแคลนไปด้วย
-- ต้องย้ายที่เก็บไปไว้ในตัวแคลน ซึ่งเป็นคนละระบบกัน
local Players = game:GetService("Players")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local ClanConfig = require(game.ReplicatedStorage.ClanConfig)
local ClanStore = require(game.ServerScriptService.ClanStore)
local ClanAccess = require(game.ServerScriptService.ClanAccess)
local TownAccess = require(game.ServerScriptService.TownAccess)
local Inventory = require(game.ServerScriptService.Inventory)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Remotes = require(game.ReplicatedStorage.Remotes)

local PROMPT_DISTANCE = 14
local USE_DISTANCE = PROMPT_DISTANCE + 6 -- เผื่อคนเดินถอยระหว่างเปิดหน้าต่างค้างไว้

local Open = {} -- [player] = townId ที่เปิดค้างอยู่ ใช้ตัดสินว่าจะส่งภาพใหม่ให้ใคร

local function notify(player, kind, text)
	Remotes.SocialNotify:FireClient(player, kind, text)
end

local function townName(townId)
	for _, t in ipairs(TownAccess.Towns or {}) do
		if t.id == townId then return t.name end
	end
	return townId
end

--------------------------------------------------------------------------------
-- สิทธิ์
--------------------------------------------------------------------------------

-- คืน ได้/ไม่ได้, เหตุผล — ตรวจใหม่ทุกครั้งที่มีคนกด ไม่เชื่อว่าปุ่มที่โผล่บนจอแปลว่ามีสิทธิ์
-- (ไคลเอนต์ยิง remote เองได้ และเมืองเปลี่ยนมือได้ระหว่างที่หน้าต่างเปิดค้างอยู่)
local function mayUse(player, townId)
	if type(townId) ~= "string" then return false end
	local clan = ClanAccess.ClanOf and ClanAccess.ClanOf(player) or nil
	if not clan then return false, "ต้องอยู่ในแคลนที่ยึดเมืองนี้ก่อน" end
	if not (TownAccess.IsHome and TownAccess.IsHome(player, townId)) then
		return false, ("คลังนี้เป็นของแคลนที่ยึด%sอยู่"):format(townName(townId))
	end

	-- ต้องยืนอยู่ที่อนุสาวรีย์จริง คลังเมืองไม่ใช่กระเป๋าที่เปิดจากที่ไหนก็ได้
	local anchor = TownAccess.AnchorOf and TownAccess.AnchorOf(townId) or nil
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if anchor and root and (anchor.Position - root.Position).Magnitude > USE_DISTANCE then
		return false, "ต้องยืนที่อนุสาวรีย์ของเมือง"
	end
	return true
end

--------------------------------------------------------------------------------
-- ส่งภาพของคลัง
--------------------------------------------------------------------------------

-- `fresh` = ไปอ่าน DataStore ใหม่ · ใช้ตอน **เปิดคลัง** เท่านั้น เพราะคลังนี้ถูกแก้จากเซิร์ฟเวอร์อื่นได้
-- ส่วนการวาดใหม่หลังฝาก/หยิบใช้ค่าที่ `UpdateTownVault` เพิ่งคืนมา (แคชแล้ว) — อ่านซ้ำทุกครั้งที่มีคน
-- ขยับของหนึ่งชิ้นคือการเผาโควตา DataStore ไปกับคำตอบที่เรารู้อยู่แล้ว
local function snapshot(townId, fresh)
	local data = ClanStore.GetTownVault(townId, fresh == true)
	local stored = data.vault or {}

	local slots, used = {}, 0
	for i = 1, ClanConfig.TownVaultSlots do
		local entry = stored[i]
		if entry then
			used += 1
			local item = ItemCatalog.Get(entry.id)
			slots[i] = {
				index = i, id = entry.id, count = entry.count or 1,
				name = ItemCatalog.DisplayName(entry.id, entry.meta) or entry.id,
				icon = item and item.icon or "",
			}
		else
			-- false ไม่ใช่ nil ด้วยเหตุผลเดียวกับคลังแคลน: nil ทำให้ช่องหายไปตอนข้ามสาย
			-- ตารางคงที่จะกลายเป็นรายการที่สั้นลงเรื่อยๆ และไคลเอนต์จะไม่รู้ว่าช่องไหนว่าง
			slots[i] = false
		end
	end

	local log = {}
	for _, row in ipairs(data.log or {}) do
		local item = ItemCatalog.Get(row.id)
		log[#log + 1] = {
			name = row.name, action = row.action, count = row.count or 1, at = row.at,
			itemName = item and (ItemCatalog.DisplayName(row.id, row.meta) or row.id) or row.id,
		}
	end

	local clanName
	if TownAccess.OwnerOf then
		local _, name = TownAccess.OwnerOf(townId)
		clanName = name
	end

	return {
		townId = townId,
		townName = townName(townId),
		clanName = clanName,
		cols = ClanConfig.TownVaultCols,
		rows = ClanConfig.TownVaultRows,
		slots = slots,
		used = used,
		total = ClanConfig.TownVaultSlots,
		log = log,
	}
end

local function push(player, townId, fresh)
	if not player.Parent then return end
	-- ไม่ส่งกระเป๋ามาด้วย: ไคลเอนต์มี `InventoryUpdate` ของตัวเองอยู่แล้วและวาดฝั่งขวาจากตัวนั้น
	-- (ทรงเดียวกับคลังแคลน) ส่งซ้ำแปลว่ามีภาพกระเป๋าสองชุดที่ไม่ตรงกันได้
	Remotes.TownVaultUpdate:FireClient(player, snapshot(townId, fresh))
end

-- ทุกคนที่เปิดคลังเดียวกันค้างอยู่ในเซิร์ฟเวอร์นี้เห็นผลทันที — คลังรวมที่คนอื่นหยิบของออกไปแล้ว
-- แต่จอเรายังโชว์ของอยู่ คือที่มาของการกดแล้ว "ไม่มีอะไรเกิดขึ้น" ซึ่งอ่านเหมือนเกมพัง
local function pushViewers(townId)
	for player, openTown in pairs(Open) do
		if openTown == townId then
			-- เมืองเปลี่ยนมือระหว่างที่หน้าต่างเปิดค้างอยู่ = คนนั้นไม่ใช่เจ้าของคลังอีกแล้ว หยุดส่งให้ทันที
			-- (การกดของเขาถูกปฏิเสธอยู่แล้วที่ `mayUse` แต่การเห็นของข้างในก็เป็นสิทธิ์ที่หมดไปพร้อมกัน)
			if mayUse(player, townId) then
				push(player, townId)
			else
				Open[player] = nil
			end
		end
	end
end

--------------------------------------------------------------------------------
-- เข้า-ออก
--------------------------------------------------------------------------------

-- เขียน log ไว้ในก้อนเดียวกับการแก้ของ (อยู่ใน transform ของ UpdateAsync) — ถ้าแยกเขียนทีหลัง
-- จะมีช่องที่ของขยับแล้วแต่ log ยังไม่ลง แล้ว "ย้อนหลัง 10 ครั้ง" จะไม่ตรงกับสิ่งที่เกิดจริง
local function addLog(data, player, action, entry)
	table.insert(data.log, 1, {
		name = player.DisplayName ~= "" and player.DisplayName or player.Name,
		action = action, id = entry.id, count = entry.count or 1, meta = entry.meta, at = os.time(),
	})
	while #data.log > ClanConfig.TownVaultLogSize do
		table.remove(data.log)
	end
end

local function put(player, townId, bagIndex, count)
	local ok, why = mayUse(player, townId)
	if not ok then return notify(player, "warn", why or "ใช้คลังนี้ไม่ได้") end

	local state = Inventory.Get(player)
	local slot = state and state.slots[bagIndex]
	if not slot then return end
	if not ItemCatalog.IsStorable(slot.id) then
		return notify(player, "warn", "ของชิ้นนี้ฝากคลังไม่ได้")
	end
	count = math.clamp(math.floor(tonumber(count) or 1), 1, slot.count or 1)

	local stored = { id = slot.id, count = count, durability = slot.durability, meta = slot.meta }
	local full = false
	local result = ClanStore.UpdateTownVault(townId, function(data)
		local free
		for i = 1, ClanConfig.TownVaultSlots do
			if data.vault[i] == nil then free = i break end
		end
		if not free then full = true return nil end
		data.vault[free] = stored
		addLog(data, player, "in", stored)
		return data
	end)
	if full then return notify(player, "warn", "คลังเมืองเต็ม") end
	if not result then return notify(player, "error", "ฝากของไม่สำเร็จ") end

	Inventory.RemoveFromSlot(player, bagIndex, count)
	pushViewers(townId)
end

local function take(player, townId, index)
	local ok, why = mayUse(player, townId)
	if not ok then return notify(player, "warn", why or "ใช้คลังนี้ไม่ได้") end
	index = math.floor(tonumber(index) or 0)
	if index < 1 or index > ClanConfig.TownVaultSlots then return end

	local taken = nil
	local result = ClanStore.UpdateTownVault(townId, function(data)
		local entry = data.vault[index]
		if not entry then return nil end
		taken = entry
		-- เคลียร์ช่อง ไม่ใช่ table.remove — ของในตารางต้องอยู่กับที่ ไม่งั้นทุกชิ้นกระโดดขึ้นหนึ่งช่อง
		-- ทุกครั้งที่มีคนหยิบ ซึ่งในคลังรวมที่หลายคนหยิบพร้อมกันจะกลายเป็นหยิบผิดชิ้นกันทั้งวง
		data.vault[index] = nil
		addLog(data, player, "out", entry)
		return data
	end)
	if not result or not taken then return end

	if not Inventory.AddItem(player, taken.id, taken.count, taken.durability, taken.meta) then
		-- คืนที่ช่องเดิมและถอน log บรรทัดที่เพิ่งลง: การหยิบครั้งนี้ไม่ได้เกิดขึ้นจริง
		ClanStore.UpdateTownVault(townId, function(data)
			data.vault[index] = taken
			if data.log[1] and data.log[1].action == "out" then table.remove(data.log, 1) end
			return data
		end)
		pushViewers(townId)
		return notify(player, "error", "กระเป๋าเต็ม")
	end
	pushViewers(townId)
end

--------------------------------------------------------------------------------
-- คำขอจากไคลเอนต์
--------------------------------------------------------------------------------

Remotes.RequestTownVault.OnServerEvent:Connect(function(player, action, townId, a, b)
	if typeof(action) ~= "string" then return end

	if action == "open" then
		local ok, why = mayUse(player, townId)
		if not ok then return notify(player, "warn", why or "ใช้คลังนี้ไม่ได้") end
		Open[player] = townId
		push(player, townId, true)
	elseif action == "close" then
		Open[player] = nil
	elseif action == "put" then
		put(player, townId, a, b)
	elseif action == "take" then
		take(player, townId, a)
	elseif action == "refresh" then
		if Open[player] == townId and mayUse(player, townId) then push(player, townId, true) end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Open[player] = nil
end)

--------------------------------------------------------------------------------
-- ทางเข้าจากปุ่ม F
--
-- **ปุ่มถูกสร้างโดย `TownCapture.server`** ที่ชิ้นเดียวกับปุ่มยึดเมือง ไฟล์นี้ประกาศแค่ "กดแล้วทำอะไร"
-- รอบแรกไฟล์นี้สร้างปุ่มเองโดยรอ `TownAccess.AnchorOf` ซึ่งเป็นการนัดเวลาข้ามสคริปต์ — และเป็นทางที่
-- ปุ่ม F หายไปทั้งเกมได้โดยไม่มี error ให้เห็น ตอนนี้ปุ่มทั้งสองเกิดพร้อมกันที่เดียว ไม่มีจังหวะให้พลาด
--------------------------------------------------------------------------------

TownAccess.OpenVault = function(player, townId)
	local ok, why = mayUse(player, townId)
	if not ok then return notify(player, "warn", why or "ใช้คลังนี้ไม่ได้") end
	Open[player] = townId
	push(player, townId, true)
end
