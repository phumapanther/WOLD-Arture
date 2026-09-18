-- ClanOutfit.server.lua: ชุดแคลนที่ใส่ด้วยการกดแหวนแคลน
--
-- **แหวนกดได้อย่างเดียวคือเรื่องนี้** (ผู้ใช้สั่ง 2026-09-18) ส่วน "ให้คนอื่น" ถูกกันไว้สองชั้นแล้ว: แหวนเป็น
-- ของประจำตำแหน่ง (`bound`) ClassActions ปฏิเสธ RequestGiveItem และเมนูในกระเป๋าก็ไม่ขึ้นปุ่ม "ให้" ให้กดอีก
--
-- โมเดลชุด: หา `Clan_Uniform` ใน `workspace.Model_Item` ก่อน (ผู้ใช้จะวางชุดจริงวันหลัง) ยังไม่มีก็ยืมชุด
-- เกราะเต็มยศมาย้อมสีประจำแคลนไปพลางๆ — ชุดแคลนจึงมีหน้าตาตั้งแต่วันแรกโดยไม่ต้องรอโมเดล เหมือนที่ออร่าทำ
--
-- สีประจำแคลนคิดจาก **ชื่อแคลน** ไม่ได้เก็บไว้ที่ไหน: ชื่อแคลนไม่ซ้ำกันอยู่แล้ว สีจึงคงที่ตลอดไปสำหรับแคลนหนึ่ง
-- และไม่ต้องเพิ่มช่องใน DataStore วันที่หัวแคลนเลือกสีเองได้ ค่อยอ่านจาก ClanStore แทนบรรทัดเดียว
local Players = game:GetService("Players")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local Inventory = require(game.ServerScriptService.Inventory)
local ClanAccess = require(game.ServerScriptService.ClanAccess)
local ClanOutfitAccess = require(game.ServerScriptService.ClanOutfitAccess)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local KitWear = require(game.ServerScriptService.KitWear)

local FOLDER_NAME = "WOLD_ClanOutfit"
local ATTRIBUTE = "WOLD_ClanOutfit" -- ArmorVisuals อ่านตัวนี้เพื่อซ่อนเกราะระหว่างใส่ชุด
local REAL_KIT = "Clan_Uniform"     -- โมเดลชุดจริงที่ผู้ใช้จะวางเอง
local FALLBACK_KIT = "Armor_PlateKit"

--------------------------------------------------------------------------------

local function hasRing(player)
	local state = Inventory.Get(player)
	if not state then return false end
	for _, slot in pairs(state.slots) do
		if slot.id == "ClanRing" then return true end
	end
	return false
end

local function clanOf(player)
	return ClanAccess.ClanOf and ClanAccess.ClanOf(player) or nil
end

-- สีจากชื่อ: ผลรวมถ่วงน้ำหนักของตัวอักษร -> เฉดสี อิ่มตัวและสว่างคงที่ จะได้ไม่มีแคลนไหนได้สีโคลน
local function clanColour(name)
	local hash = 0
	for index = 1, #name do
		hash = (hash * 31 + name:byte(index)) % 360
	end
	return Color3.fromHSV(hash / 360, 0.62, 0.78)
end

local function strip(character)
	if not character then return end
	KitWear.Strip(character, FOLDER_NAME)
	character:SetAttribute(ATTRIBUTE, nil)
end

local function draw(player)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return false end
	local clan = clanOf(player)
	if not clan then return false end

	local kitName = KitWear.Model(REAL_KIT) and REAL_KIT or FALLBACK_KIT
	-- ชุดจริงมีสีของมันเองอยู่แล้ว ย้อมเฉพาะชุดที่ยืมมา
	local tint = (kitName == FALLBACK_KIT) and clanColour(clan.name or "") or nil
	if not KitWear.Wear(character, kitName, tint, FOLDER_NAME) then return false end
	character:SetAttribute(ATTRIBUTE, true)
	return true
end

--------------------------------------------------------------------------------
-- เปิด / ปิด
--------------------------------------------------------------------------------

ClanOutfitAccess.Toggle = function(player)
	local data = ProfileAccess.Get(player)
	if not data then return false, "ยังโหลดข้อมูลไม่เสร็จ" end
	if not clanOf(player) then return false, "ต้องอยู่ในแคลนก่อน" end

	if data.ClanOutfit then
		data.ClanOutfit = nil
		strip(player.Character)
		return true, "ถอดชุดแคลนแล้ว"
	end

	data.ClanOutfit = true
	if not draw(player) then
		data.ClanOutfit = nil
		return false, "ยังไม่มีโมเดลชุดแคลนให้ใส่"
	end
	local clan = clanOf(player)
	return true, ("ใส่ชุดแคลน %s"):format(clan and clan.name or "")
end

--------------------------------------------------------------------------------
-- ลูปถามใหม่ (กฎเหล็ก StreamingEnabled)
--
-- ตัวละครใหม่ไม่มีโฟลเดอร์ → วาดใหม่ · ออกจากแคลนหรือแหวนหาย → ถอดให้เอง เหมือนที่ออร่าทำกับไอเทมออร่า
--------------------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = ProfileAccess.Get(player)
			local character = player.Character
			if data and character and character:FindFirstChild("HumanoidRootPart") then
				local wanted = data.ClanOutfit and true or false
				if wanted and (not clanOf(player) or not hasRing(player)) then
					data.ClanOutfit = nil
					wanted = false
				end
				local shown = character:FindFirstChild(FOLDER_NAME) ~= nil
				if wanted and not shown then
					draw(player)
				elseif shown and not wanted then
					strip(character)
				end
			end
		end
	end
end)
