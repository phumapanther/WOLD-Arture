-- LobbyParty: ปาร์ตี้ของโหมด PVP ที่รวมตัวกันในล็อบบี้ (ผู้ใช้ส่งภาพร่างมา 2026-09-23)
--
-- **คนละตี้กับตี้ในเกม** ถึงจะใช้ `Party.lua` เป็นสถานะตัวเดียวกันก็ตาม — `PlayerParty.server` ซึ่ง
-- ดูแลตี้ในเกมข้ามล็อบบี้ไปเลย (`if ServerConfig.IsLobby then return end`) เพราะมันต้องการ `Vitals`
-- กับ `Friends` ที่ล็อบบี้ไม่มี (ล็อบบี้ไม่เปิดเซสชันโปรไฟล์ของใคร — กฎเดิมของโปรเจ็ค)
--
-- ⚠️ **คำเชิญส่งได้เฉพาะคนที่อยู่ในล็อบบี้เซิร์ฟเดียวกัน** ตอนนี้ — ข้ามเซิร์ฟต้องใช้ MessagingService
-- ซึ่งยังไม่ได้ทำ · รายชื่อเพื่อนจึงบอกด้วยว่าใครอยู่ที่นี่ และการชวนคนที่ไม่อยู่จะถูกปฏิเสธพร้อมเหตุผล
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsLobby then return end

local Players = game:GetService("Players")
local Party = require(game.ServerScriptService.Party)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)
local SocialConfig = require(game.ReplicatedStorage.SocialConfig)
local ArenaConfig = require(game.ReplicatedStorage.ArenaConfig)
local ArenaQueue = require(script.Parent.ArenaQueue)
local AdminRoster = require(game.ServerScriptService.AdminRoster)

local MAX = SocialConfig.PvpPartyMax or 3
local FRIEND_CACHE_SECONDS = 30

local function nameOf(player)
	return player.DisplayName ~= "" and player.DisplayName or player.Name
end

--------------------------------------------------------------------------------
-- เพื่อน
--------------------------------------------------------------------------------
-- อ่านจากโปรไฟล์แบบอ่านอย่างเดียว ทางเดียวกับที่ `LobbyServer` ใช้ตัดสินสิทธิ์เข้าเกาะเพื่อน
-- **`Data.Social.Friends` ไม่ใช่ `Data.Friends`** (`PlayerSocial` เก็บรวมไว้ในก้อน Social)
local friendCache = {} -- [player] = { at, list }

local function friendsOf(player)
	local cached = friendCache[player]
	if cached and os.clock() - cached.at < FRIEND_CACHE_SECONDS then return cached.list end

	local list = {}
	if ProfileAccess.PeekAsync then
		local data = ProfileAccess.PeekAsync(player.UserId)
		local social = data and data.Social
		for id, name in pairs((social and social.Friends) or {}) do
			local n = tonumber(id)
			if n then list[#list + 1] = { userId = n, name = tostring(name) } end
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	friendCache[player] = { at = os.clock(), list = list }
	return list
end

--------------------------------------------------------------------------------
-- เลเวลตัวละครในเกมหลัก (ผู้ใช้สั่ง 2026-09-24: "หน้าล็อบบี้โชว์เลเวลตัวละครจากเกมหลัก")
--------------------------------------------------------------------------------
-- อ่านผ่าน PeekAsync (อ่านอย่างเดียว) ครั้งเดียวต่อคนต่อเซิร์ฟล็อบบี้ — เลเวลไม่ขยับระหว่างยืนในล็อบบี้
-- `snapshotFor` ห้าม yield จึงคืน nil ไปก่อน แล้วดึงเบื้องหลัง เสร็จเมื่อไหร่ค่อยส่งภาพใหม่ให้ทั้งตี้
local levelCache = {} -- [userId] = level | false (กำลังดึง)
local pushParty -- ประกาศข้างล่าง

-- คืน { level, class } · class = อาชีพขั้นสูงสุดที่ถืออยู่ (elite > advanced > basic) ใช้ทาสีกรอบการ์ด
local function levelOf(player)
	local cached = levelCache[player.UserId]
	if cached ~= nil then return cached or nil end
	levelCache[player.UserId] = false
	task.spawn(function()
		local data = ProfileAccess.PeekAsync and ProfileAccess.PeekAsync(player.UserId)
		local progression = data and data.Progression
		local role = data and data.Role
		levelCache[player.UserId] = {
			level = (progression and progression.Level) or 1,
			class = role and (role.Elite or role.Advanced or role.Basic) or nil,
		}
		if player.Parent and pushParty then pushParty(player) end
	end)
	return nil
end

--------------------------------------------------------------------------------
-- สถานะการค้นหาห้อง
--------------------------------------------------------------------------------
-- **คิวอยู่ที่ `ArenaQueue` ไม่ใช่ที่นี่** — ไฟล์นี้เป็นเจ้าของ "ปาร์ตี้" กับ "หน้าจอ" เท่านั้น
-- ส่วนการจับคู่ เติมบอท และเทเลพอร์ต เป็นเรื่องของโมดูลนั้น (ดูเหตุผลที่หัวไฟล์มัน)

--------------------------------------------------------------------------------
-- ภาพที่ส่งให้หน้าจอ
--------------------------------------------------------------------------------
-- **หนึ่งภาพต่อคน ไม่ใช่ภาพกลาง** — แต่ละคนเห็นคำเชิญของตัวเองและช่องของตัวเองเป็นช่องแรกเสมอ
local function snapshotFor(player)
	local members = {}
	local function member(p, me)
		local info = levelOf(p)
		return { userId = p.UserId, name = nameOf(p), me = me or nil,
			level = info and info.level or nil, class = info and info.class or nil }
	end
	members[#members + 1] = member(player, true)
	for _, other in ipairs(Party.Members(player)) do
		if other ~= player then members[#members + 1] = member(other) end
	end

	-- คำเชิญที่ค้างอยู่: `Party` เก็บไว้ในตารางของมัน ถามผ่าน `Party.PendingFor` ถ้ามี
	local from = Party.PendingFor(player)
	local invite = from and { userId = from.UserId, name = nameOf(from) } or nil

	local searchedFor = ArenaQueue.SecondsWaiting(player)
	local launching = ArenaQueue.IsLaunching(player)
	return {
		max = MAX,
		members = members,
		invite = invite,
		searching = (searchedFor ~= nil) or launching,
		searchSeconds = searchedFor and math.floor(searchedFor) or nil,
		-- กำลังย้ายเข้าสนามอยู่ — หน้าจอต้องค้างที่ "เจอห้องแล้ว" ไม่ใช่เด้งกลับเป็นปุ่มเล่น
		launching = launching,
		-- คนในคิวตอนนี้ / ที่ต้องการ · ทำให้การรอมีรูปร่าง ไม่ใช่นาฬิกาเปล่าๆ
		queued = ArenaQueue.Waiting(),
		needed = ArenaConfig.MatchPlayers,
		-- อีกกี่วินาทีจะเติมบอทให้ (ผู้ใช้กำหนด: หาไม่ครบใน 3 นาที → บอทมาเติม)
		botsIn = searchedFor and math.max(0, math.ceil(ArenaConfig.Bots.searchSeconds - searchedFor)) or nil,
		-- **เพลสสนามยังไม่มี = บอกตรงๆ ตั้งแต่ก่อนกด** ไม่ใช่ปล่อยให้หมุนแล้วค่อยเฉลย
		notReady = ServerConfig.ArenaPlaceId == 0,
		-- ปุ่ม "เริ่มเลย" ของแอดมิน (ข้ามคิว เล่นคนเดียวกับบอทได้)
		admin = AdminRoster.IsAdmin(player),
	}
end

local function push(player)
	if player and player:IsDescendantOf(Players) then
		Remotes.PvpPartyUpdate:FireClient(player, snapshotFor(player))
	end
end

-- ส่งให้ทั้งตี้ — ใครเข้าออกตี้ ทุกคนในนั้นต้องเห็นพร้อมกัน
function pushParty(player)
	push(player)
	for _, other in ipairs(Party.Members(player)) do
		if other ~= player then push(other) end
	end
end

--------------------------------------------------------------------------------
-- คำสั่งจากหน้าจอ
--------------------------------------------------------------------------------
local function notify(player, text)
	Remotes.SocialNotify:FireClient(player, "warn", text)
end

local ACTIONS = {}

ACTIONS.refresh = function(player)
	push(player)
end

ACTIONS.friends = function(player)
	local here = {}
	for _, p in ipairs(Players:GetPlayers()) do here[p.UserId] = true end
	local rows = {}
	for _, f in ipairs(friendsOf(player)) do
		rows[#rows + 1] = { userId = f.userId, name = f.name, here = here[f.userId] == true }
	end
	Remotes.PvpPartyUpdate:FireClient(player, { friends = rows })
end

ACTIONS.invite = function(player, userId)
	userId = tonumber(userId)
	if not userId then return end

	-- ⚠️ **เพดานของ PVP คือ 3 ไม่ใช่ `SocialConfig.PartyMax` (4)** — ต้องกันที่นี่ก่อน
	-- เพราะ `Party.Invite` ใช้เลข 4 ของตี้ในเกม
	if #Party.Members(player) >= MAX then
		return notify(player, ("ปาร์ตี้เต็มแล้ว (%d คน)"):format(MAX))
	end

	local friend = false
	for _, f in ipairs(friendsOf(player)) do
		if f.userId == userId then friend = true break end
	end
	if not friend then return notify(player, "ชวนได้เฉพาะคนที่เป็นเพื่อนกันแล้ว") end

	local target = Players:GetPlayerByUserId(userId)
	if not target then
		return notify(player, "เพื่อนคนนี้ไม่ได้อยู่ในล็อบบี้ตอนนี้")
	end
	if #Party.Members(target) > 1 then
		return notify(player, "เขาอยู่ในปาร์ตี้อื่นแล้ว")
	end

	local ok, reason = Party.Invite(player, target)
	if not ok then return notify(player, reason or "ชวนไม่สำเร็จ") end
	Remotes.SocialNotify:FireClient(target, "info", ("%s ชวนเข้าปาร์ตี้"):format(nameOf(player)))
	push(target)
	push(player)
end

ACTIONS.accept = function(player, fromUserId)
	local ok, reason = Party.Accept(player, tonumber(fromUserId) or 0)
	if not ok then return notify(player, reason or "รับคำเชิญไม่สำเร็จ") end
	pushParty(player)
end

ACTIONS.decline = function(player, fromUserId)
	Party.Decline(player, tonumber(fromUserId) or 0)
	push(player)
end

ACTIONS.leave = function(player)
	local mates = Party.Members(player)
	Party.Leave(player)
	push(player)
	for _, other in ipairs(mates) do
		if other ~= player then push(other) end
	end
end

ACTIONS.play = function(player)
	if ServerConfig.ArenaPlaceId == 0 then
		return notify(player, "สนาม PVP ยังไม่เปิด (ยังไม่ได้สร้างเพลส)")
	end
	-- ทั้งตี้เข้าคิวพร้อมกัน — **คนที่กดคือคนที่พาไป** ปาร์ตี้ถูกจับเป็นก้อนเดียวเสมอ ไม่ถูกหั่นข้ามทีม
	local members = Party.Members(player)
	local ok, reason = ArenaQueue.Join(members, player)
	if not ok then return notify(player, reason or "เข้าคิวไม่สำเร็จ") end
	for _, member in ipairs(members) do push(member) end
end

ACTIONS.cancel = function(player)
	local members = ArenaQueue.Leave(player)
	push(player)
	for _, member in ipairs(members) do
		if member ~= player then push(member) end
	end
end

-- แอดมินกดเริ่มเองโดยไม่ต้องรอใคร — ที่ว่างที่เหลือเป็นบอททั้งสองฝั่ง
ACTIONS.solo = function(player)
	local members = Party.Members(player)
	local ok, reason = ArenaQueue.StartSolo(player, members)
	if not ok then return notify(player, reason or "เริ่มแมตช์ไม่สำเร็จ") end
	for _, member in ipairs(members) do push(member) end
end

Remotes.RequestPvpParty.OnServerEvent:Connect(function(player, action, arg)
	local fn = ACTIONS[action]
	if fn then fn(player, arg) end
end)

--------------------------------------------------------------------------------
-- นาฬิกา
--------------------------------------------------------------------------------
-- ส่งภาพใหม่ทุกวินาทีให้คนที่กำลังค้นหาห้องอยู่ เพื่อให้ตัวเลขเดินจริง
-- (ทรงเดียวกับหน้าต่างคอกสัตว์บนเกาะ: ภาพที่ส่งมาอัปเดตไม่มีสิทธิ์เปิดหน้าต่าง มันแค่วาดทับของที่เปิดอยู่)
-- คิวเป็นคนบอกว่าใครต้องวาดใหม่ (ตัวเลขเดิน เจอห้อง เติมบอท ฯลฯ) — ไฟล์นี้แค่วาดตาม
ArenaQueue.Start(function(players)
	for _, player in ipairs(players) do push(player) end
end)

--------------------------------------------------------------------------------
-- กลับจากสนาม: ตี้เดิมรวมตัวเอง · มีคนกด "เล่นต่อทันที" = เข้าคิวต่อเลย (ผู้ใช้สั่ง 2026-10-01)
--------------------------------------------------------------------------------
-- สนามส่งทั้งตี้มาด้วย TeleportAsync ก้อนเดียวพร้อม `arenaReturn = { party = {userId…}, again }` (ArenaMatch.sendPartyHome)
-- ⚠️ เชื่อเฉพาะข้อมูลที่มาจากเพลสสนาม (`SourcePlaceId`) และรวมได้เฉพาะคนที่พกรายชื่อชุดเดียวกันเป๊ะ —
-- ปลอมรายชื่อมาลากคนอื่นเข้าตี้ไม่ได้ เพราะรายชื่อที่อีกฝั่งพกมาเขียนโดยเซิร์ฟสนาม
local REGROUP_SECONDS = 15 -- รอคนในตี้ที่มาช้าสุดเท่านี้ก่อนเข้าคิว (ส่งก้อนเดียวกันปกติถึงพร้อมกัน)
local Returning = {} -- [รายชื่อเรียงแล้ว] = { ids, players = {}, again, at, queued }

local function arenaReturnOf(player)
	local ok, join = pcall(function() return player:GetJoinData() end)
	if not ok or type(join) ~= "table" or join.SourcePlaceId ~= ServerConfig.ArenaPlaceId then return nil end
	local data = type(join.TeleportData) == "table" and join.TeleportData.arenaReturn
	if type(data) ~= "table" or type(data.party) ~= "table" or #data.party > MAX then return nil end
	local ids, mine = {}, false
	for _, id in ipairs(data.party) do
		if type(id) ~= "number" then return nil end
		ids[#ids + 1] = id
		if id == player.UserId then mine = true end
	end
	if not mine then return nil end
	table.sort(ids)
	return ids, data.again == true
end

local function regroup(group)
	local here = {}
	for _, p in ipairs(group.players) do
		if p.Parent then here[#here + 1] = p end
	end
	local leader = here[1]
	if not leader then return end
	for i = 2, #here do
		local p = here[i]
		if Party.Of(p) == nil and Party.Invite(leader, p) then Party.Accept(p, leader.UserId) end
	end
	pushParty(leader)
	if group.queued or not group.again then return end
	if #here < #group.ids and os.clock() - group.at < REGROUP_SECONDS then return end
	group.queued = true
	ACTIONS.play(leader)
end

local function arrivedFromArena(player)
	local ids, again = arenaReturnOf(player)
	if not ids then return end
	local key = table.concat(ids, ",")
	local group = Returning[key]
	if not group or os.clock() - group.at > 60 then
		group = { ids = ids, players = {}, at = os.clock() }
		Returning[key] = group
		-- คนที่หายไประหว่างทาง (ปิดเกม/เด้ง) ไม่ทำให้คนที่ถึงแล้วรอตลอดไป
		task.delay(REGROUP_SECONDS + 1, function()
			if Returning[key] == group then
				regroup(group)
				Returning[key] = nil
			end
		end)
	end
	group.again = group.again or again
	table.insert(group.players, player)
	regroup(group)
end

Players.PlayerAdded:Connect(function(player)
	task.defer(push, player)
	-- รอให้หน้าจอล็อบบี้ของเขาพร้อมสักครู่ก่อน ภาพตี้/สถานะค้นหาจะได้ไม่ส่งไปหาจอที่ยังไม่มี (ไคลเอนต์ขอภาพซ้ำเองอยู่แล้ว)
	task.delay(2, arrivedFromArena, player)
end)

Players.PlayerRemoving:Connect(function(player)
	local mates = Party.Members(player)
	ArenaQueue.RemovePlayer(player)
	friendCache[player] = nil
	levelCache[player.UserId] = nil
	Party.Remove(player)
	for _, other in ipairs(mates) do
		if other ~= player then push(other) end
	end
end)
