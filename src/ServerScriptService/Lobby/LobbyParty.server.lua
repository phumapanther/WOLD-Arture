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

local MAX = SocialConfig.PvpPartyMax or 3
local FRIEND_CACHE_SECONDS = 30

-- **ยังไม่มีเพลส Arena** (ผู้ใช้เลือก 2026-09-23: "ทำ UI ก่อน ปุ่มเล่นพักไว้") — กดเล่นแล้วเข้าสถานะ
-- ค้นหาห้องจริงๆ เพื่อให้เห็นหน้าตา แต่พอครบเวลานี้จะบอกตรงๆ ว่าโหมดยังไม่เปิด ไม่ใช่หมุนค้างหลอกกันเล่น
local PLACEHOLDER_SECONDS = 12

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
-- สถานะการค้นหาห้อง
--------------------------------------------------------------------------------
local Searching = {} -- [player] = os.clock() ที่เริ่มกด

--------------------------------------------------------------------------------
-- ภาพที่ส่งให้หน้าจอ
--------------------------------------------------------------------------------
-- **หนึ่งภาพต่อคน ไม่ใช่ภาพกลาง** — แต่ละคนเห็นคำเชิญของตัวเองและช่องของตัวเองเป็นช่องแรกเสมอ
local function snapshotFor(player)
	local members = {}
	members[#members + 1] = { userId = player.UserId, name = nameOf(player), me = true }
	for _, other in ipairs(Party.Members(player)) do
		if other ~= player then
			members[#members + 1] = { userId = other.UserId, name = nameOf(other) }
		end
	end

	-- คำเชิญที่ค้างอยู่: `Party` เก็บไว้ในตารางของมัน ถามผ่าน `Party.PendingFor` ถ้ามี
	local from = Party.PendingFor(player)
	local invite = from and { userId = from.UserId, name = nameOf(from) } or nil

	local searchedFor = Searching[player] and (os.clock() - Searching[player]) or nil
	return {
		max = MAX,
		members = members,
		invite = invite,
		searching = searchedFor ~= nil,
		searchSeconds = searchedFor and math.floor(searchedFor) or nil,
		-- โหมดยังไม่เปิดจริง: บอกหน้าจอให้ขึ้นข้อความหลังหมุนไปสักพัก
		notReady = (searchedFor ~= nil) and (searchedFor >= PLACEHOLDER_SECONDS) or false,
	}
end

local function push(player)
	if player and player:IsDescendantOf(Players) then
		Remotes.PvpPartyUpdate:FireClient(player, snapshotFor(player))
	end
end

-- ส่งให้ทั้งตี้ — ใครเข้าออกตี้ ทุกคนในนั้นต้องเห็นพร้อมกัน
local function pushParty(player)
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
	-- ทั้งตี้เข้าคิวพร้อมกัน — คนที่กดคือคนที่พาไป
	for _, member in ipairs(Party.Members(player)) do
		Searching[member] = os.clock()
		push(member)
	end
end

ACTIONS.cancel = function(player)
	for _, member in ipairs(Party.Members(player)) do
		Searching[member] = nil
		push(member)
	end
	Searching[player] = nil
	push(player)
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
task.spawn(function()
	while true do
		task.wait(1)
		for player in pairs(Searching) do
			push(player)
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.defer(push, player)
end)

Players.PlayerRemoving:Connect(function(player)
	local mates = Party.Members(player)
	Searching[player] = nil
	friendCache[player] = nil
	Party.Remove(player)
	for _, other in ipairs(mates) do
		if other ~= player then push(other) end
	end
end)
