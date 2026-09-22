-- Leaderboards.server.lua: ตารางอันดับสี่ชนิดในหินสื่อสาร
--
-- เลเวล · เงิน · แต้มกิจกรรม · คนออนไลน์รายช่อง
--
-- **สามอันแรกเป็นอันดับของเซิร์ฟเวอร์นี้ ไม่ใช่ของทั้งเกม** ตามที่ผู้ใช้กำหนด ("ในเชิฟ") ซึ่งเป็นสิ่งที่
-- ทำได้จริงโดยไม่ต้องแตะ DataStore เลย — อันดับข้ามเซิร์ฟเวอร์ต้องอ่าน-เขียน OrderedDataStore ทุกครั้ง
-- ที่ค่าขยับ ซึ่งแพงและช้ากว่ามาก และจะกลายเป็นตารางที่คนในเซิร์ฟนี้ไม่มีชื่ออยู่เลย
--
-- อันที่สี่เป็นข้อยกเว้น: มันคือ "ช่องไหนคนเยอะ" ซึ่งโดยนิยามต้องมองข้ามเซิร์ฟเวอร์ ใช้ heartbeat
-- ที่ระบบเลือกช่องส่งอยู่แล้วทุกๆ ไม่กี่วินาที จึงไม่ได้เพิ่มภาระอะไรใหม่
local Players = game:GetService("Players")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local Progression = require(game.ServerScriptService.Progression)
local Inventory = require(game.ServerScriptService.Inventory)
local Bank = require(game.ServerScriptService.Bank)
local Collection = require(game.ServerScriptService.Collection)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local ChannelRegistry = require(game.ServerScriptService.Lobby.ChannelRegistry)
local GlobalRanks = require(game.ServerScriptService.GlobalRanks)
local Remotes = require(game.ReplicatedStorage.Remotes)

--------------------------------------------------------------------------------
-- แต้มกิจกรรม
--------------------------------------------------------------------------------

-- แต้มสะสมจากการเล่นกิจกรรมพิเศษ เก็บในโปรไฟล์จึงติดตัวข้ามเซสชัน
--
-- **ไม่ได้ให้เองที่นี่** ไฟล์นี้แค่เก็บและจัดอันดับ ส่วนใครควรได้กี่แต้มเป็นเรื่องของระบบที่เป็นเจ้าของ
-- กิจกรรมนั้นๆ — เหมือนที่ WorldEvents ถือนาฬิกาแต่ Mobs เป็นคนทำสไลม์
local EventPoints = {}

function EventPoints.Add(player, amount)
	local data = ProfileAccess.Get(player)
	if not data then return 0 end
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	data.EventPoints = (data.EventPoints or 0) + amount
	return data.EventPoints
end

function EventPoints.Get(player)
	local data = ProfileAccess.Get(player)
	return data and data.EventPoints or 0
end

--------------------------------------------------------------------------------
-- คนออนไลน์รายช่อง
--------------------------------------------------------------------------------

-- [channel] = { count, updatedAt }
local Channels = {}

-- ข้อมูลเก่ากว่านี้ถือว่าช่องนั้นตายแล้ว — เซิร์ฟเวอร์ที่ปิดไปจะหยุดส่ง heartbeat เฉยๆ ไม่มีใครมาบอกลา
local STALE_SECONDS = 45

do
	local ok = pcall(function()
		ChannelRegistry.SubscribeToHeartbeats(ServerConfig.Mode, function(channel, count)
			Channels[channel] = { count = count or 0, updatedAt = os.clock() }
		end)
	end)
	if not ok then
		warn("[Leaderboards] ต่อ heartbeat ไม่ได้ — อันดับออนไลน์จะเห็นแค่ช่องนี้")
	end
end

--------------------------------------------------------------------------------
-- สร้างตาราง
--------------------------------------------------------------------------------

local function sortedBy(valueOf)
	local rows = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local value = valueOf(player) or 0
		rows[#rows + 1] = { name = player.DisplayName, userId = player.UserId, value = value }
	end
	-- ชื่อเป็นตัวตัดสินเมื่อค่าเท่ากัน ลำดับจึงคงที่ ไม่สลับไปมาทุกครั้งที่เปิดดู
	table.sort(rows, function(a, b)
		if a.value ~= b.value then return a.value > b.value end
		return a.name < b.name
	end)
	return rows
end

local function build(player)
	-- เงิน = ติดตัว + ในธนาคาร
	--
	-- **ต้องรวมสองอย่าง** ไม่งั้น "คนรวยที่สุด" จะกลายเป็นคนที่พกเงินสดเยอะที่สุด ซึ่งคนละเรื่องกับรวย
	-- และจะสอนให้คนไม่ฝากเงินเพื่อไต่อันดับ ทั้งที่เกมออกแบบให้ฝากเงินปลอดภัยกว่า
	local gold = sortedBy(function(p)
		local state = Inventory.Get(p)
		local carried = state and state.gold or 0
		return carried + Bank.Get(p)
	end)

	local levels = sortedBy(function(p) return Progression.GetLevel(p) end)
	local points = sortedBy(function(p) return EventPoints.Get(p) end)

	-- **เลเวลกับเงินเป็นอันดับของทั้งเกม ไม่ใช่แค่เซิร์ฟนี้** (ผู้ใช้กำหนด 2026-09-22)
	--
	-- อ่านจาก OrderedDataStore ซึ่งทุกเซิร์ฟเวอร์เขียนลงที่เดียวกัน · อ่านไม่ได้ (API ปิด / DataStore ล่ม)
	-- ก็ตกกลับไปใช้ตารางในเซิร์ฟเวอร์แบบเดิม ดีกว่าโชว์ตารางว่าง
	--
	-- **เหตุผลที่บนเกาะต้องใช้อันแบบนี้**: เกาะเป็นเซิร์ฟส่วนตัว `Players:GetPlayers()` คืนชื่อเดียว
	-- ตารางในเซิร์ฟจึงไม่มีความหมายเลยที่นั่น
	local globalLevels = GlobalRanks.Top("levels")
	local globalGold = GlobalRanks.Top("gold")

	-- ช่อง: รวมข้อมูลที่ได้ยินจากช่องอื่น บวกช่องนี้ซึ่งรู้จำนวนจริงอยู่แล้ว
	local now = os.clock()
	local channels = {}
	for id, entry in pairs(Channels) do
		if now - entry.updatedAt <= STALE_SECONDS then
			channels[#channels + 1] = { channel = id, count = entry.count }
		end
	end
	-- ช่องของเราเอง: นับสดตรงนี้แทนที่จะรอ heartbeat ของตัวเองวนกลับมา
	local mine = ServerConfig.Channel
	local replaced = false
	for _, row in ipairs(channels) do
		if row.channel == mine then
			row.count = #Players:GetPlayers()
			replaced = true
		end
	end
	if not replaced and mine then
		channels[#channels + 1] = { channel = mine, count = #Players:GetPlayers() }
	end
	table.sort(channels, function(a, b)
		if a.count ~= b.count then return a.count > b.count end
		return tostring(a.channel) < tostring(b.channel)
	end)

	return {
		levels = #globalLevels > 0 and globalLevels or levels,
		gold = #globalGold > 0 and globalGold or gold,
		-- หน้าจอใช้บอกผู้เล่นว่าตารางที่เห็นครอบคลุมแค่ไหน
		levelsScope = #globalLevels > 0 and "global" or "server",
		goldScope = #globalGold > 0 and "global" or "server",
		points = points,
		channels = channels,
		myChannel = mine,
	}
end

--------------------------------------------------------------------------------
-- คำขอจากไคลเอนต์
--------------------------------------------------------------------------------

Remotes.RequestLeaderboards.OnServerEvent:Connect(function(player)
	Remotes.LeaderboardUpdate:FireClient(player, build(player))
end)

Remotes.RequestCollection.OnServerEvent:Connect(function(player)
	local snapshot = Collection.Snapshot(player)
	if snapshot then
		Remotes.CollectionUpdate:FireClient(player, snapshot)
	end
end)

--------------------------------------------------------------------------------
-- เผยแพร่ให้ระบบอื่นเรียกใช้
--------------------------------------------------------------------------------

-- ระบบกิจกรรมเรียกผ่านตัวนี้เพื่อให้แต้ม
local LeaderboardAccess = require(game.ServerScriptService.LeaderboardAccess)
LeaderboardAccess.AddEventPoints = function(player, amount)
	local total = EventPoints.Add(player, amount)
	if amount and amount > 0 then
		Remotes.SocialNotify:FireClient(player, "info",
			("ได้แต้มกิจกรรม +%d (รวม %d)"):format(amount, total))
	end
	return total
end
LeaderboardAccess.GetEventPoints = EventPoints.Get
