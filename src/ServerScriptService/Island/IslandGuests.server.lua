-- IslandGuests: เพื่อนที่มาเยี่ยมเกาะ — ประกาศว่าเจ้าของอยู่ และส่งแขกกลับเมื่อเขาไม่อยู่แล้ว
--
-- ผู้ใช้สั่ง 2026-09-23: "เพิ่มระบบเพื่อนสามารถเข้าเชิฟเราได้ถ้าเพิ่มเพื่อนกันแล้ว และเพื่อนที่เข้ามา
-- สามารถมาขโมยเก็บฟาร์มสัตว์และฟาร์มผักเราได้ รวมถึงเก็บรวบรวมวัตถุดิบได้ทุกชนิด พวกหินแร่ไม้พุ่มไม้
-- แต่ใช้เครื่องใช้อุปกรณ์ พวกเตาทำอาหารตู้เย็น NPC บอร์ดเควส และอื่นๆ เราไม่ได้"
--
-- สิทธิ์ "ใช้ของบนเกาะไม่ได้" อยู่ที่ `IslandAccess.MayUseFixtures` ซึ่งแต่ละระบบถามเอง ·
-- ไฟล์นี้ดูแลอีกครึ่งหนึ่ง: **แขกอยู่ได้เฉพาะตอนเจ้าของอยู่**
--
-- ⚠️ **ไม่ใช่กฎมารยาท มันคือข้อจำกัดของข้อมูล** — เกาะทั้งเกาะอยู่ใน `profile.Data.Island` ของเจ้าของ
-- ซึ่งเซิร์ฟนี้เขียนได้ก็ต่อเมื่อเจ้าของเปิดเซสชัน ProfileStore อยู่ตรงนี้ · ถ้าปล่อยให้แขกเดินเก็บของ
-- ในเกาะร้าง ทุกอย่างที่เขาเก็บจะหายไปตอนเซิร์ฟปิด และเจ้าของจะกลับมาเจอผักครบเหมือนไม่มีอะไรเกิดขึ้น
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsFarm then return end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FarmRegistry = require(game.ServerScriptService.Lobby.FarmRegistry)
local Remotes = require(ReplicatedStorage.Remotes)

local ownerId = ServerConfig.FarmOwnerId
-- nil = Studio หรือเซิร์ฟที่ระบุเจ้าของไม่ได้ (IslandBuild ยกให้คนแรกที่เข้า) — ไม่มีใครให้เทียบ ปล่อยผ่าน
if not ownerId then return end

local HEARTBEAT = 60 -- ต้องถี่กว่า FarmRegistry.LIVE_SECONDS พอให้พลาดได้สองจังหวะ
local GRACE_SECONDS = 60 -- แขกกับเจ้าของเทเลพอร์ตมาไม่พร้อมกัน แขกอาจถึงก่อน
local FAREWELL_SECONDS = 5

local function ownerHere()
	return Players:GetPlayerByUserId(ownerId) ~= nil
end

local sending = {} -- [player] = true · กันส่งซ้ำ

local function sendHome(player, message)
	if sending[player] then return end
	sending[player] = true
	Remotes.SocialNotify:FireClient(player, "warn", message)
	task.delay(FAREWELL_SECONDS, function()
		if not player:IsDescendantOf(Players) then return end
		-- ล็อบบี้คือเซิร์ฟสาธารณะของ **เพลสหลัก** — `game.PlaceId` ตรงนี้คือเลขของเกาะ (บทเรียน LobbyTravel)
		local ok, err = pcall(function()
			TeleportService:Teleport(ServerConfig.MainPlaceId or game.PlaceId, player)
		end)
		if not ok then warn("[IslandGuests] ส่งแขกกลับล็อบบี้ไม่สำเร็จ:", err) end
	end)
end

--------------------------------------------------------------------------------
-- ประกาศว่าเจ้าของอยู่ (ล็อบบี้อ่านตัวนี้ตัดสินว่าแขกกดเข้าได้ไหม)
--------------------------------------------------------------------------------
task.spawn(function()
	local announced = false
	while true do
		local here = ownerHere()
		-- เขียนซ้ำทุกรอบตอนอยู่ (หัวใจต้องเต้น) · เขียนลบครั้งเดียวตอนไม่อยู่ (ไม่ต้องย้ำว่าว่าง)
		if here then
			FarmRegistry.SetLive(ownerId, true)
			announced = true
		elseif announced then
			FarmRegistry.SetLive(ownerId, false)
			announced = false
		end
		task.wait(HEARTBEAT)
	end
end)

--------------------------------------------------------------------------------
-- แขกอยู่ได้เฉพาะตอนเจ้าของอยู่
--------------------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	if player.UserId == ownerId then
		FarmRegistry.SetLive(ownerId, true) -- ไม่ต้องรอหัวใจเต้นรอบหน้า เพื่อนที่กดพร้อมกันจะได้เข้าได้เลย
		return
	end
	print(("[IslandGuests] แขก %s (userId=%d) เข้าเกาะของ userId=%d")
		:format(player.Name, player.UserId, ownerId))
	-- **รอเจ้าของก่อน ไม่ตัดสินทันที** — ล็อบบี้เช็คแล้วว่าเจ้าของอยู่ แต่ถ้าเจ้าของเพิ่งรีจอยน์
	-- (ออกแล้วเข้าใหม่) แขกอาจมาถึงเซิร์ฟก่อนเขาหนึ่งอึดใจ · เด้งทันทีคือการลงโทษจังหวะ ไม่ใช่กฎ
	task.spawn(function()
		local deadline = os.clock() + GRACE_SECONDS
		while os.clock() < deadline do
			if not player:IsDescendantOf(Players) then return end
			if ownerHere() then return end
			task.wait(2)
		end
		if player:IsDescendantOf(Players) then
			sendHome(player, "เจ้าของเกาะไม่ได้อยู่ที่นี่ — กำลังพากลับหน้าเลือกโหมด")
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	sending[player] = nil
	if player.UserId ~= ownerId then return end
	FarmRegistry.SetLive(ownerId, false) -- ทันที ไม่รอหัวใจหยุดเต้นเอง
	for _, other in ipairs(Players:GetPlayers()) do
		if other.UserId ~= ownerId then
			sendHome(other, "เจ้าของเกาะออกจากเกมแล้ว — กำลังพากลับหน้าเลือกโหมด")
		end
	end
end)

game:BindToClose(function()
	if ownerHere() then FarmRegistry.SetLive(ownerId, false) end
end)
