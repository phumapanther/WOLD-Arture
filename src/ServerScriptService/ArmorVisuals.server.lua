-- ArmorVisuals.server.lua: ใส่เกราะแล้วเห็นเกราะบนตัวจริง
--
-- โมเดลเกราะสามชุดอยู่ใน `workspace.Model_Item` แต่ละชุดประกอบด้วยชิ้นส่วนที่ **ตั้งชื่อตามข้อต่อ R15**
-- (`Armor_UpperTorso`, `Armor_LeftHand`, ...) จึงสวมได้ด้วยการจับคู่ชื่อตรงๆ ไม่ต้องวัดตำแหน่งเอง
--
-- ชิ้นที่ไม่ตรงกับชื่อ R15 (`Armor_Seams`, `Armor_Pouch`, `Armor_Plume`, `Armor_SteamPlant`,
-- `Armor_Scabbard`, `Armor_Livery`) เป็นของตกแต่ง เชื่อมไว้กับลำตัวแทน — จะได้ติดตัวไปด้วยแทนที่จะถูกทิ้ง
--
-- **เชื่อมด้วย WeldConstraint ไม่ใช่ Motor6D**: เกราะไม่ต้องขยับข้อต่อของตัวเอง มันแค่ต้องติดไปกับ
-- ชิ้นส่วนที่มันสวมอยู่ ซึ่งขยับตามอนิเมชันอยู่แล้ว Motor6D จะทำให้ Animator พยายามขับมันด้วย
local Players = game:GetService("Players")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local Inventory = require(game.ServerScriptService.Inventory)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local KitWear = require(game.ServerScriptService.KitWear)

--------------------------------------------------------------------------------
-- ชุดเกราะ
--------------------------------------------------------------------------------

-- ไอเทมในกระเป๋า -> ชื่อโมเดลชุดเกราะ
local KITS = {
	LeatherArmor = "Armor_LeatherKit",
	ChainmailArmor = "Armor_ChainKit",
	PlateArmor = "Armor_PlateKit",
}

local FOLDER_NAME = "WOLD_ArmorOn" -- ชื่อโฟลเดอร์ที่ห้อยอยู่ในตัวละคร

--------------------------------------------------------------------------------
-- สวม / ถอด
--
-- กลไกการเชื่อมชิ้นส่วนย้ายไปอยู่ `KitWear` แล้ว เพราะชุดแคลน (ClanOutfit.server) ใช้ของเดียวกันเป๊ะ
--------------------------------------------------------------------------------

local function stripArmor(character)
	KitWear.Strip(character, FOLDER_NAME)
end

local function wearArmor(player, itemId, skinId)
	local character = player.Character
	if not character then return end

	-- ชุดแฟชั่น (สกินเกราะจากกาชา) เปลี่ยนโมเดลที่สวมและ/หรือย้อมสี ค่าเกราะมาจากไอเทมจริงเหมือนเดิม
	local fashion = skinId and ItemCatalog.Get(skinId) or nil
	local kitName = (fashion and fashion.kit) or KITS[itemId]
	if not kitName then
		stripArmor(character)
		return
	end
	KitWear.Wear(character, kitName, fashion and fashion.tint or nil, FOLDER_NAME)
end

--------------------------------------------------------------------------------
-- ตามการใส่เกราะ
--------------------------------------------------------------------------------

-- **ไม่ได้ฟัง EquipmentChanged** เพราะมันเป็น remote ขาออก (server -> client) ฝั่งเซิร์ฟเวอร์ฟังไม่ได้
-- ลูปข้างล่างเป็นตัวจับการเปลี่ยนแปลงแทน ซึ่งทนกว่าอยู่แล้ว: มันตามทั้งการเปลี่ยนเกราะและการเกิดใหม่
-- ด้วยกลไกเดียวกัน

-- ลูปถามใหม่ทุกครึ่งวินาที
--
-- **กฎเหล็กของโปรเจ็คนี้** เกราะต้องมาหลังตัวละครประกอบเสร็จ และ EquipmentChanged อาจถูกยิงก่อนที่
-- ตัวละครจะมีแขนขาครบ การผูกครั้งเดียวจะแพ้จังหวะกับบางคน และเป็นคนละคนทุกรอบ
--
-- ตัวเทียบคือ "ใส่อะไรอยู่" เทียบกับ "วาดอะไรไว้" ถ้าตรงกันก็ไม่ทำอะไร จึงไม่ได้สร้างเกราะใหม่ทุกครึ่งวิ
local Drawn = {} -- [player] = itemId ที่วาดไว้แล้ว

task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				local _, entry = Inventory.EquippedArmor(player)
				local skinId = entry and entry.meta and entry.meta.skin or nil
				-- คีย์เทียบรวมสกินด้วย ติด/ถอดสกินโดยไม่เปลี่ยนเกราะก็ต้องวาดใหม่
				local wanted = entry and (entry.id .. "|" .. (skinId or "")) or nil
				-- ใส่ชุดแคลนอยู่ = ซ่อนเกราะ (ค่าเกราะยังอยู่ครบ หายแค่รูป) ไม่งั้นชุดสองชุดซ้อนกันจนกะพริบ
				-- ClanOutfit.server เป็นคนติด/ถอดแอตทริบิวต์นี้ ถอดชุดเมื่อไหร่คีย์ก็ต่างจากเดิมแล้ววาดคืนเอง
				if character:GetAttribute("WOLD_ClanOutfit") then wanted = nil end
				local shown = Drawn[player]
				-- ตัวละครใหม่ = โฟลเดอร์หายไปด้วย ต้องวาดใหม่แม้ไอเทมไม่เปลี่ยน
				local present = character:FindFirstChild(FOLDER_NAME) ~= nil
				if wanted ~= shown or (wanted and not present) then
					if wanted then wearArmor(player, entry.id, skinId) else stripArmor(character) end
					Drawn[player] = wanted
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Drawn[player] = nil
end)
