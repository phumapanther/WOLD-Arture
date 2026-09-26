-- ArenaQueue.lua: คิวจับคู่ 3v3 ของโหมด PVP — ตัวที่พาคนออกจากล็อบบี้ไปสนามจริง
--
-- เป็นโมดูล ไม่ใช่ `.server.lua` เพราะ `LobbyParty.server` เป็นเจ้าของหน้าจอปาร์ตี้อยู่แล้ว และ
-- **ต้องมีเจ้าของการวาดคนเดียว** ไม่งั้นสองสคริปต์จะผลัดกันส่งภาพคนละเวอร์ชันให้จอเดียวกัน
-- ตัวนี้จึงถือแค่ "ใครอยู่ในคิว นานแค่ไหน และเมื่อไหร่จะได้ไป" แล้วบอก `LobbyParty` ให้วาดใหม่
--
-- ⚠️ **คิวอยู่ในหน่วยความจำของล็อบบี้เซิร์ฟนี้ตัวเดียว** — ล็อบบี้สองเซิร์ฟไม่เห็นคิวของกัน
-- ที่ขนาดผู้เล่นตอนนี้ (ล็อบบี้เดียว) มันตรงกับความจริงทุกประการ และการเติมบอทเมื่อครบเวลา (1:30)
-- แปลว่า **ไม่มีใครติดค้างในคิวตลอดกาล** ต่อให้ทั้งเซิร์ฟมีคนเดียว · ถ้าวันหนึ่งล็อบบี้มีหลายเซิร์ฟจริง
-- ทางแก้คือ MessagingService ประกาศคิวข้ามเซิร์ฟ (ทรงเดียวกับ heartbeat ของช่อง) ไม่ใช่รื้อไฟล์นี้
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local ArenaConfig = require(game.ReplicatedStorage.ArenaConfig)
local AdminRoster = require(game.ServerScriptService.AdminRoster)
local ArenaRegistry = require(script.Parent.ArenaRegistry)
local ArenaTeams = require(script.Parent.ArenaTeams)
local ServerConfig = require(game.ServerScriptService.ServerConfig)

local ArenaQueue = {}

local TEAM_SIZE = ArenaConfig.TeamSize
local FULL = ArenaConfig.MatchPlayers
local BOT_FILL_SECONDS = ArenaConfig.Bots.searchSeconds

-- หนึ่งรายการ = หนึ่งปาร์ตี้ (คนเดียวก็นับเป็นปาร์ตี้หนึ่ง) — **ปาร์ตี้ต้องไม่ถูกหั่นข้ามทีม**
-- นั่นคือเหตุผลที่คิวเก็บเป็นก้อน ไม่ใช่เก็บเป็นรายคนแล้วค่อยจับคู่ทีหลัง
local Queue = {} -- { { members = {Player…}, at = os.clock(), leader = Player } }

local onChange = nil -- ตั้งโดย LobbyParty: เรียกเมื่อต้องวาดหน้าจอของคนเหล่านี้ใหม่

--------------------------------------------------------------------------------
-- ค้นหา
--------------------------------------------------------------------------------
local function entryOf(player)
	for _, entry in ipairs(Queue) do
		for _, member in ipairs(entry.members) do
			if member == player then return entry end
		end
	end
	return nil
end

function ArenaQueue.IsSearching(player)
	return entryOf(player) ~= nil
end

-- วินาทีที่คนนี้รออยู่ (นับจากตอนปาร์ตี้ของเขากดเล่น) หรือ nil ถ้าไม่ได้อยู่ในคิว
function ArenaQueue.SecondsWaiting(player)
	local entry = entryOf(player)
	return entry and (os.clock() - entry.at) or nil
end

-- จำนวนคนที่อยู่ในคิวทั้งหมดตอนนี้ — หน้าจอเอาไปบอกว่า "3/6" ซึ่งทำให้การรอมีรูปร่าง
function ArenaQueue.Waiting()
	local n = 0
	for _, entry in ipairs(Queue) do n += #entry.members end
	return n
end

-- คนที่ถูกส่งเข้าสนามแล้ว แต่ยังไม่หายไปจากเซิร์ฟ (Roblox ใช้เวลาย้ายคนสักพัก)
-- หน้าจอต้องขึ้น "เจอห้องแล้ว" ค้างไว้ ไม่ใช่เด้งกลับไปเป็นปุ่ม "เล่น" ระหว่างรอย้าย
local Launching = {} -- [player] = os.clock()

function ArenaQueue.IsLaunching(player)
	return Launching[player] ~= nil
end

--------------------------------------------------------------------------------
-- เข้า/ออกคิว
--------------------------------------------------------------------------------
function ArenaQueue.Join(members, leader)
	if #members == 0 then return false, "ไม่มีใครในปาร์ตี้" end
	if #members > TEAM_SIZE then return false, ("ปาร์ตี้เกิน %d คน"):format(TEAM_SIZE) end
	for _, member in ipairs(members) do
		if entryOf(member) or Launching[member] then return false, "อยู่ในคิวอยู่แล้ว" end
	end
	table.insert(Queue, { members = members, at = os.clock(), leader = leader or members[1] })
	return true
end

function ArenaQueue.Leave(player)
	local entry = entryOf(player)
	if not entry then return {} end
	for i, e in ipairs(Queue) do
		if e == entry then table.remove(Queue, i) break end
	end
	return entry.members
end

-- ผู้เล่นออกจากเกม: ถอดออกจากปาร์ตี้ที่อยู่ในคิว **โดยไม่ล้มทั้งปาร์ตี้** — เพื่อนที่เหลือยังรอต่อได้
function ArenaQueue.RemovePlayer(player)
	Launching[player] = nil
	local entry = entryOf(player)
	if not entry then return end
	for i, member in ipairs(entry.members) do
		if member == player then table.remove(entry.members, i) break end
	end
	if #entry.members == 0 then
		for i, e in ipairs(Queue) do
			if e == entry then table.remove(Queue, i) break end
		end
	end
end

--------------------------------------------------------------------------------
-- จัดทีม
--------------------------------------------------------------------------------
-- จัดทีม = ArenaTeams.Assign (เจอก่อนได้ไปก่อน · ก้อนที่ลงไม่ได้รอแมตช์หน้า) — แยกไฟล์ไว้ให้เทสได้
local function assign(entries)
	return ArenaTeams.Assign(entries, TEAM_SIZE)
end

--------------------------------------------------------------------------------
-- ส่งเข้าสนาม
--------------------------------------------------------------------------------
local function userIdsOf(list)
	local ids = {}
	for _, player in ipairs(list) do table.insert(ids, player.UserId) end
	return ids
end

-- คืน true ถ้าส่งไปแล้ว · `reason` มีไว้บอกหน้าจอเวลาไปไม่ได้
local function launch(entries)
	-- ทุกก้อนที่ส่งมาต้องลงทีมได้ครบ (ผู้เรียกหยิบมาด้วย assign อยู่แล้ว · กันไว้เผื่อทางอื่น)
	local chosenAll, teams = assign(entries)
	if #chosenAll ~= #entries then return false end

	local everyone = {}
	for _, side in ipairs(ArenaConfig.TeamOrder) do
		for _, player in ipairs(teams[side]) do table.insert(everyone, player) end
	end
	if #everyone == 0 then return false end

	local map = ArenaConfig.Maps[math.random(#ArenaConfig.Maps)]
	local bots = { A = TEAM_SIZE - #teams.A, B = TEAM_SIZE - #teams.B }

	local ok, accessCode = pcall(ArenaRegistry.CreateMatch, map.id, {
		A = userIdsOf(teams.A),
		B = userIdsOf(teams.B),
	}, bots)
	if not ok then
		warn("[ArenaQueue] จองเซิร์ฟแมตช์ไม่สำเร็จ:", accessCode)
		return false, "create_failed"
	end

	-- ถอดออกจากคิวก่อนเทเลพอร์ต: ถ้าย้ายช้า ตัวนับจะได้ไม่พาพวกเขาไปแมตช์ที่สองระหว่างรอ
	for _, entry in ipairs(entries) do
		for i, e in ipairs(Queue) do
			if e == entry then table.remove(Queue, i) break end
		end
	end
	for _, player in ipairs(everyone) do Launching[player] = os.clock() end
	if onChange then onChange(everyone) end

	local teleportOk, err = pcall(function()
		TeleportService:TeleportToPrivateServer(ServerConfig.ArenaPlaceId, accessCode, everyone)
	end)
	if not teleportOk then
		warn("[ArenaQueue] เทเลพอร์ตเข้าสนามล้มเหลวทันที:", err)
		for _, player in ipairs(everyone) do Launching[player] = nil end
		if onChange then onChange(everyone) end
		return false, "teleport_failed"
	end
	print(("[ArenaQueue] ส่ง %d คน (บอท A=%d B=%d) เข้าแมพ %s"):format(#everyone, bots.A, bots.B, map.id))
	return true
end

-- **แอดมินเริ่มแมตช์คนเดียวได้** (ผู้ใช้สั่ง · `06-modes-build-plan.md` §4.2 บอกว่าต้องมาก่อนระบบจับคู่
-- เพราะเป็นสิ่งเดียวที่ทำให้เทสสนามได้โดยไม่ต้องหาคนหกคน) — ข้ามคิวไปเลย ที่เหลือเป็นบอท
function ArenaQueue.StartSolo(player, members)
	if not AdminRoster.IsAdmin(player) then return false, "ไม่ใช่แอดมิน" end
	if ServerConfig.ArenaPlaceId == 0 then return false, "ยังไม่มีเพลสสนาม" end
	for _, member in ipairs(members) do ArenaQueue.RemovePlayer(member) end
	local sent, reason = launch({ { members = members, at = os.clock(), leader = player } })
	if not sent then return false, reason or "เริ่มแมตช์ไม่สำเร็จ" end
	return true
end

--------------------------------------------------------------------------------
-- นาฬิกาของคิว
--------------------------------------------------------------------------------
-- เรียกครั้งเดียวจาก `LobbyParty.server` · `notify(players)` = วาดหน้าจอของคนเหล่านี้ใหม่
function ArenaQueue.Start(notify)
	onChange = notify

	task.spawn(function()
		while true do
			task.wait(1)
			if ServerConfig.ArenaPlaceId ~= 0 and #Queue > 0 then
				-- หยิบตามลำดับที่เข้าคิว (Queue เรียงตามเวลาที่กดเล่นอยู่แล้ว) ทีละก้อนที่ลงทีมได้ — ก้อนที่ลงไม่ได้รอต่อ
				local chosen, teams = assign(Queue)
				local count = #teams.A + #teams.B
				if count == FULL then
					-- 1) ครบหกคนเมื่อไหร่ไปเมื่อนั้น
					launch(chosen)
				elseif count > 0 then
					-- 2) **ครบเวลา (ArenaConfig.Bots.searchSeconds) แล้วยังไม่ครบหกคน → เติมบอท** (ผู้ใช้กำหนด)
					-- ตัดสินจากคนที่รอนานที่สุดในชุดที่ได้ไป (ก้อนแรกเสมอ) · ก้อนที่ถูกข้ามรอแมตช์ถัดไป
					if os.clock() - chosen[1].at >= BOT_FILL_SECONDS then
						launch(chosen)
					end
				end
			end

			-- วาดใหม่ให้ทุกคนที่ยังรออยู่ เพื่อให้ตัวเลขบนจอเดินจริง
			local watching = {}
			for _, entry in ipairs(Queue) do
				for _, member in ipairs(entry.members) do table.insert(watching, member) end
			end
			for player in pairs(Launching) do
				-- ค้างไว้ไม่เกินครึ่งนาที: เทเลพอร์ตที่ไม่เคยเกิดขึ้นจริงต้องคืนปุ่มให้เขากดใหม่ได้
				if os.clock() - Launching[player] > 30 then
					Launching[player] = nil
					table.insert(watching, player)
				end
			end
			if #watching > 0 and onChange then onChange(watching) end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		ArenaQueue.RemovePlayer(player)
	end)
end

return ArenaQueue
