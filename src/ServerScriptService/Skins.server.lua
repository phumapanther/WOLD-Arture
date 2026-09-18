-- Skins.server.lua: ติดตั้ง/ถอดสกินอาวุธและชุดเกราะแฟชั่น (ของจากกาชา)
--
-- สกินเป็นไอเทมในกระเป๋า (kind = "skin" / "fashion") ติดตั้งแล้วหายจากกระเป๋าไปอยู่ใน `meta.skin` ของอาวุธ/
-- เกราะชิ้นนั้น ถอดแล้วกลับมาเป็นไอเทม — สกินจึงเป็น "ของ" ตลอดเวลา ไม่ใช่ธงลอยๆ เทรด/ให้เพื่อนได้เหมือนของอื่น
-- และไม่มีทางมีสกินสองอันบนชิ้นเดียว
--
-- **แยกตามอาวุธ** (ผู้ใช้กำหนด): สกินดาบใหญ่ติดได้เฉพาะดาบใหญ่ (`skinFor`) ชุดแฟชั่นติดเกราะชิ้นไหนก็ได้
-- รูปลักษณ์จริงเป็นเรื่องของ WeaponVisuals / ArmorVisuals ซึ่งอ่าน meta.skin เอง ที่นี่แค่ย้ายของ
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Remotes = require(game.ReplicatedStorage.Remotes)
local Inventory = require(game.ServerScriptService.Inventory)

-- ชิ้นเป้าหมาย: "equipped:weapon" / "equipped:armor" / "bag:<index>" คืน entry กับตัวเขียนกลับ
local function targetOf(player, target)
	local state = Inventory.Get(player)
	if not state then return nil end
	target = tostring(target or "")
	local kind = target:match("^equipped:(%a+)$")
	if kind then
		local entry = state.equipped[kind]
		if not entry then return nil end
		return entry, kind
	end
	local index = tonumber(target:match("^bag:(%d+)$") or "")
	if index and state.slots[index] then
		local entry = state.slots[index]
		local item = ItemCatalog.Get(entry.id)
		if not item or (item.kind ~= "weapon" and item.kind ~= "armor") then return nil end
		return entry, item.kind
	end
	return nil
end

-- สกินนี้ใส่กับชิ้นนี้ได้ไหม
local function fits(skin, entry, kind)
	if kind == "weapon" then
		return skin.kind == "skin" and skin.skinFor == entry.id
	elseif kind == "armor" then
		return skin.kind == "fashion"
	end
	return false
end

local function refreshVisuals(player)
	-- ทั้งสองระบบวาดใหม่เมื่อ "สิ่งที่สวม" เปลี่ยน: อาวุธผ่าน OnWeaponChanged ส่วนเกราะมีลูปของตัวเอง
	-- ที่เทียบ id+skin ทุกครึ่งวิ
	if Inventory.OnWeaponChanged then Inventory.OnWeaponChanged(player) end
	Inventory.Send(player)
end

local function install(player, target, skinIndex)
	local entry, kind = targetOf(player, target)
	if not entry then return end
	local state = Inventory.Get(player)
	local skinSlot = state.slots[math.floor(tonumber(skinIndex) or 0)]
	local skin = skinSlot and ItemCatalog.Get(skinSlot.id)
	if not skin then return end
	if not fits(skin, entry, kind) then
		return Remotes.SocialNotify:FireClient(player, "warn", "สกินนี้ใส่กับชิ้นนี้ไม่ได้")
	end
	local previous = entry.meta and entry.meta.skin
	-- สกินเดิมต้องมีที่ให้กลับไป ไม่งั้นมันหายไปเฉยๆ
	if previous and not Inventory.HasRoomFor(player, previous, 1) then
		return Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม ถอดสกินเดิมออกไม่ได้")
	end
	Inventory.RemoveFromSlot(player, math.floor(tonumber(skinIndex)), 1)
	entry.meta = entry.meta or {}
	entry.meta.skin = skin.name and skinSlot.id or nil
	if previous then Inventory.AddItem(player, previous, 1) end
	Remotes.SocialNotify:FireClient(player, "info", ("ติดตั้ง %s แล้ว"):format(skin.name))
	refreshVisuals(player)
end

local function remove(player, target)
	local entry = targetOf(player, target)
	if not entry or not entry.meta or not entry.meta.skin then return end
	local skinId = entry.meta.skin
	if not Inventory.HasRoomFor(player, skinId, 1) then
		return Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม")
	end
	entry.meta.skin = nil
	if next(entry.meta) == nil then entry.meta = nil end
	Inventory.AddItem(player, skinId, 1)
	local skin = ItemCatalog.Get(skinId)
	Remotes.SocialNotify:FireClient(player, "info", ("ถอด %s แล้ว"):format(skin and skin.name or skinId))
	refreshVisuals(player)
end

Remotes.RequestSkin.OnServerEvent:Connect(function(player, action, target, skinIndex)
	if action == "install" then install(player, target, skinIndex)
	elseif action == "remove" then remove(player, target)
	end
end)
