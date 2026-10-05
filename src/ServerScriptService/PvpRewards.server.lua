-- PvpRewards.server.lua: รับรางวัลที่สนาม PVP ฝากไว้ แล้วใส่กระเป๋าจริงของคนนั้น
--
-- อยู่ฝั่ง **เกมหลัก** เพราะที่นี่คือที่เดียวที่โปรไฟล์ของคนคนนั้นถูกเปิดเซสชันอยู่จริง เซิร์ฟแมตช์
-- ไม่เคยเปิดโปรไฟล์ใครเลย (ถ้าเปิดแล้วเซฟตอนจบ มันจะทับกระเป๋าจริงด้วยของที่ซื้อในแมตช์)
--
-- ⚠️ **ล้างคิวก่อนจ่าย** (`ArenaRegistry.ClaimRewards` ทำให้แล้ว) — ถ้าจ่ายก่อนล้างแล้วล้างพลาด
-- คนนั้นจะได้รางวัลซ้ำทุกครั้งที่เข้าเกม ซึ่งเป็นช่องโหว่ที่ขยายตัวเอง · ทางนี้กรณีแย่สุดคือรางวัล
-- หายหนึ่งชุด ซึ่งแอดมินแจกคืนได้
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby or ServerConfig.IsArena then return end

local ArenaRegistry = require(game.ServerScriptService.Lobby.ArenaRegistry)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local Progression = require(game.ServerScriptService.Progression)
local Remotes = require(game.ReplicatedStorage.Remotes)

PlayerJoin.Each(function(player)
	-- รอโปรไฟล์ด้วยเหตุผลเดียวกับทุกระบบที่เติมของให้คน: เติมก่อนกระเป๋าจริงมาถึง = เติมลงกระเป๋าเปล่า
	-- ที่กำลังจะถูกเขียนทับ
	if not ProfileAccess.Wait(player) then return end

	local rewards = ArenaRegistry.ClaimRewards(player.UserId)
	if not rewards or #rewards == 0 then return end

	local gold, exp, chests = 0, 0, {}
	for _, reward in ipairs(rewards) do
		gold += tonumber(reward.gold) or 0
		exp += tonumber(reward.exp) or 0
		if reward.chest and ItemCatalog.Items[reward.chest] then
			chests[reward.chest] = (chests[reward.chest] or 0) + 1
		end
	end

	if gold > 0 then Inventory.AddGold(player, gold) end
	-- EXP (ผู้ใช้สั่ง 2026-09-24) · `Progression` ถูกเติมโดย PlayerProgression หลังโปรไฟล์มาถึง ซึ่งอาจช้ากว่า
	-- `ProfileAccess.Wait` นิดหนึ่ง — `AwardExp` เงียบเมื่อยังไม่มีสถานะ จึงต้องรอให้มีก่อน
	if exp > 0 then
		local deadline = os.clock() + 15
		while not Progression.Get(player) and os.clock() < deadline and player.Parent do task.wait(0.25) end
		Progression.AwardExp(player, exp)
	end

	local given, heldBack = {}, 0
	for id, count in pairs(chests) do
		if Inventory.HasRoomFor(player, id, count) then
			Inventory.AddItem(player, id, count)
			local item = ItemCatalog.Items[id]
			table.insert(given, ("%s x%d"):format(item and item.name or id, count))
		else
			-- กระเป๋าเต็ม: **ฝากกลับเข้าคิว** ไม่ใช่ทิ้ง — ของที่หายไปเพราะกระเป๋าเต็มคือรางวัลที่ถูกริบ
			-- โดยไม่มีใครบอก · ไม่ซ้ำซ้อนเพราะคิวถูกล้างไปแล้วตอนรับ
			ArenaRegistry.QueueReward(player.UserId, { gold = 0, chest = id })
			heldBack += count
		end
	end

	Inventory.Send(player)

	-- แม่แบบเดียวทั้งประโยค (ไคลเอนต์แปลย้อนได้) · มีหีบ = ต่อท้ายรายการหีบ
	local line = #given > 0 and ("รางวัลจากสนาม PVP: %d เหรียญ · %d EXP · %s"):format(gold, exp, table.concat(given, ", "))
		or ("รางวัลจากสนาม PVP: %d เหรียญ · %d EXP"):format(gold, exp)
	Remotes.SocialNotify:FireClient(player, "info", line)
	if heldBack > 0 then
		Remotes.SocialNotify:FireClient(player, "warn",
			("มีหีบ %d ใบรออยู่ — กระเป๋าเต็ม เข้าเกมใหม่อีกครั้งหลังเก็บของ"):format(heldBack))
	end
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
end)
