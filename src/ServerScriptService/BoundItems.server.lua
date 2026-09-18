-- BoundItems.server.lua: ของประจำตำแหน่งที่โผล่และหายจากกระเป๋าเอง
--
--   ตะหลิวเชฟ (Spatula)  ↔ มีอาชีพเชฟ
--   แหวนแคลน (ClanRing) ↔ อยู่ในแคลน (meta.clan = ชื่อแคลน)
--
-- ลูปถามทุก 3 วิ ไม่ผูกกับเหตุการณ์ "เปลี่ยนอาชีพ"/"เข้าแคลน": สองอย่างนั้นเกิดได้จากหลายที่ (การ์ดเลือกอาชีพ
-- คำสั่งแอดมิน ตายแล้วอาชีพหลุด หัวแคลนอนุมัติจากเซิร์ฟอื่น) ลูปเดียวที่ดู "ความจริงตอนนี้" ไม่พลาดสักทาง
-- ของพวกนี้ทิ้ง/ให้/เทรด/ฝากไม่ได้ (ItemCatalog.IsBound) จึงมีอยู่แค่ในกระเป๋าเท่านั้น
local Players = game:GetService("Players")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local Classes = require(game.ServerScriptService.Classes)
local ClanAccess = require(game.ServerScriptService.ClanAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)

-- ผู้เล่นคนนี้ควรมีของชิ้นนี้ไหม คืน true/false, meta ที่ควรติดมา
local function entitled(player, id, item)
	if item.boundClass then
		return Classes.Has(player, item.boundClass), nil
	end
	if item.boundClan then
		local clan = ClanAccess.ClanOf and ClanAccess.ClanOf(player) or nil
		if clan then return true, { clan = clan.name } end
		return false, nil
	end
	return false, nil
end

local function reconcile(player)
	local state = Inventory.Get(player)
	if not state then return end
	-- **ช่องมือนับเป็นการมีของด้วย** ตะหลิวถือได้แล้ว และการสวมคือการย้ายของออกจากกระเป๋า ถ้าดูแต่กระเป๋า
	-- ลูปนี้จะเห็นว่าเชฟไม่มีตะหลิวแล้วแจกใหม่ทุก 3 วิ จนกระเป๋าเต็มไปด้วยตะหลิว
	local _, wielded = Inventory.EquippedWeapon(player)
	for id, item in pairs(ItemCatalog.Items) do
		if item.bound then
			local should, meta = entitled(player, id, item)
			local inHand = wielded ~= nil and wielded.id == id
			-- ที่มีอยู่ตอนนี้ (ชิ้นแรกที่เจอ)
			local haveIndex, haveSlot
			for index, slot in pairs(state.slots) do
				if slot.id == id then haveIndex, haveSlot = index, slot break end
			end
			if not should then
				-- สิทธิ์หมด: หลุดจากมือก่อน (ของชิ้นนั้นไม่ใช่ของเขาแล้ว ไม่ได้ตกลงกระเป๋า) แล้วลบในกระเป๋า
				-- ทุกชิ้น (เผื่อมีซ้ำจากทางไหนสักทาง)
				local lost = false
				if inHand then
					Inventory.BreakEquipped(player, "weapon")
					lost = true
				end
				if haveSlot then
					for index, slot in pairs(state.slots) do
						if slot.id == id then Inventory.RemoveFromSlot(player, index, slot.count or 1) end
					end
					lost = true
				end
				if lost then
					Remotes.SocialNotify:FireClient(player, "warn", ("%sหายไปแล้ว"):format(item.name))
				end
			elseif not haveSlot and not inHand then
				if Inventory.HasRoomFor(player, id, 1, meta) then
					Inventory.AddItem(player, id, 1, nil, meta)
					Remotes.SocialNotify:FireClient(player, "info", ("ได้รับ%s"):format(ItemCatalog.DisplayName(id, meta)))
				end
			elseif haveSlot and meta and (not haveSlot.meta or haveSlot.meta.clan ~= meta.clan) then
				-- ย้ายแคลน: แหวนวงเดิมชื่อผิด เปลี่ยนป้ายให้ตรง
				haveSlot.meta = meta
				Inventory.Send(player)
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(3)
		for _, player in ipairs(Players:GetPlayers()) do
			local ok, err = pcall(reconcile, player)
			if not ok then warn("[BoundItems]", err) end
		end
	end
end)
