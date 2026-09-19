-- PlayerParty.server: ปุ่มชวนตี้ · คำถาม "ตกลงไหม" · และหลอดเลือด/ความหิวของเพื่อนร่วมตี้
--
-- การตัดสินทั้งหมดอยู่ใน `Party.lua` ไฟล์นี้ทำสามอย่างเท่านั้น: รับคำขอจากไคลเอนต์ (ตรวจทุกอย่างใหม่
-- ไม่เชื่ออะไรที่ส่งมา) · ส่งภาพเดียวกันของตี้ให้ทุกคนในตี้ · และเต้นนาฬิกาส่งค่าหลอดของกันและกัน
--
-- **ชวนได้จากหน้ารายชื่อสหายของหินสื่อสารเท่านั้น** (ผู้ใช้กำหนด) — ด่านที่บังคับข้อนี้จริงอยู่ที่นี่
-- ไม่ใช่ที่ปุ่ม: ไคลเอนต์ยิง remote เองได้เสมอ ปุ่มจึงเป็นแค่ทางเข้าที่สะดวก ไม่ใช่กฎ
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local Party = require(game.ServerScriptService.Party)
local Friends = require(game.ServerScriptService.Friends)
local Vitals = require(game.ServerScriptService.Vitals)
local Remotes = require(game.ReplicatedStorage.Remotes)
local SocialConfig = require(game.ReplicatedStorage.SocialConfig)

local function nameOf(player)
	return player.DisplayName ~= "" and player.DisplayName or player.Name
end

local function notify(player, kind, text)
	Remotes.SocialNotify:FireClient(player, kind, text)
end

--------------------------------------------------------------------------------
-- ส่งภาพของตี้
--------------------------------------------------------------------------------

-- ภาพที่ "คนคนหนึ่ง" เห็น: เพื่อนร่วมตี้ของเขา ไม่รวมตัวเอง (หลอดของตัวเองมีอยู่แล้วใน HUD)
-- ตี้สลาย/ไม่มีตี้ = ส่งรายการว่าง ซึ่งเป็นสัญญาณให้ไคลเอนต์เก็บแถบลง ไม่ต้องมี remote ปิดแยกอีกตัว
local function snapshotFor(player)
	local others = {}
	local party = Party.Of(player)
	if party then
		for _, member in ipairs(party.members) do
			if member ~= player then
				local vitals = Vitals.Fractions(member) or {}
				others[#others + 1] = {
					userId = member.UserId,
					name = nameOf(member),
					hp = vitals.hp or 1,
					hunger = vitals.hunger or 1,
					downed = vitals.downed or false,
				}
			end
		end
	end
	return others
end

local function push(player)
	if not player.Parent then return end
	Remotes.PartyStateChanged:FireClient(player, snapshotFor(player))
end

local function pushAll(members)
	for _, member in ipairs(members or {}) do push(member) end
end

--------------------------------------------------------------------------------
-- คำขอจากไคลเอนต์
--------------------------------------------------------------------------------

local function invite(player, targetUserId)
	local target = Players:GetPlayerByUserId(tonumber(targetUserId) or 0)
	if not target then
		notify(player, "error", "คนนี้ไม่ได้อยู่ในเซิร์ฟเวอร์นี้")
		return
	end
	-- เหตุผลเดียวกับโทรจิตและนกพิราบ: รายชื่อสหายคือความยินยอมที่ให้กันไว้ก่อนแล้ว
	-- ถ้าชวนใครก็ได้ คำเชิญจะกลายเป็นช่องทางกวนคนแปลกหน้าที่ปิดไม่ได้
	local state = Friends.Get(player)
	if not state or not state.friends[target.UserId] then
		notify(player, "error", "ชวนเข้าตี้ได้เฉพาะสหายเท่านั้น")
		return
	end

	local ok, message = Party.Invite(player, target)
	notify(player, ok and "info" or "error", message)
	if not ok then return end

	Remotes.PartyInvite:FireClient(target, player.UserId, nameOf(player), SocialConfig.PartyInviteSeconds)
end

local function accept(player, fromUserId)
	local ok, message, party = Party.Accept(player, tonumber(fromUserId) or 0)
	notify(player, ok and "info" or "error", message)
	if not ok then return end

	for _, member in ipairs(party.members) do
		if member ~= player then
			notify(member, "info", ("%s เข้าตี้แล้ว"):format(nameOf(player)))
		end
	end
	pushAll(party.members)
end

local function decline(player, fromUserId)
	local from = Party.Decline(player, tonumber(fromUserId) or 0)
	if from and from.Parent then
		notify(from, "info", ("%s ปฏิเสธคำชวนเข้าตี้"):format(nameOf(player)))
	end
end

local function leave(player)
	local remaining, dissolved = Party.Leave(player)
	if not remaining then
		notify(player, "error", "คุณไม่ได้อยู่ในตี้")
		return
	end
	notify(player, "info", "ออกจากตี้แล้ว")
	for _, member in ipairs(remaining) do
		notify(member, "info", dissolved and ("%s ออกจากตี้ — ตี้สลาย"):format(nameOf(player))
			or ("%s ออกจากตี้"):format(nameOf(player)))
	end
	push(player)
	pushAll(remaining)
end

Remotes.RequestPartyAction.OnServerEvent:Connect(function(player, action, value)
	if typeof(action) ~= "string" then return end
	if action == "invite" then
		invite(player, value)
	elseif action == "accept" then
		accept(player, value)
	elseif action == "decline" then
		decline(player, value)
	elseif action == "leave" then
		leave(player)
	elseif action == "refresh" then
		-- ไม่มีผลข้างเคียง: ไคลเอนต์ขอภาพใหม่หลังเกิดใหม่ เผื่อแถบเพี้ยนระหว่างจอมืด
		push(player)
	end
end)

--------------------------------------------------------------------------------
-- วงจรชีวิต
--------------------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
	local remaining, dissolved = Party.Remove(player)
	if not remaining then return end
	for _, member in ipairs(remaining) do
		notify(member, "info", dissolved and ("%s ออกจากเกม — ตี้สลาย"):format(nameOf(player))
			or ("%s ออกจากเกม"):format(nameOf(player)))
	end
	pushAll(remaining)
end)

-- คนเข้ามาใหม่ยังไม่มีตี้แน่นอน แต่ส่งรายการว่างให้หนึ่งครั้งเพื่อให้ไคลเอนต์รู้ว่าติดต่อกันได้แล้ว
-- (และเพื่อล้างแถบที่ค้างจากตัวละครก่อนหน้า ถ้า GUI ตัวนั้นรอดการเกิดใหม่มา)
Players.PlayerAdded:Connect(push)

--------------------------------------------------------------------------------
-- นาฬิกาหลอดเลือด/ความหิว
--
-- ส่งเฉพาะคนที่อยู่ในตี้จริงๆ — เซิร์ฟเวอร์ที่ไม่มีใครตั้งตี้เลยจึงไม่มีทราฟฟิกจากไฟล์นี้สักไบต์
-- และส่งทุก 0.5 วิเหมือน HUD ของตัวเอง ไม่ใช่ทุกเฟรม: หลอดของคนอื่นไม่ต้องลื่นเท่าของตัวเอง
--------------------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(SocialConfig.PartyPushSeconds)
		for _, player in ipairs(Players:GetPlayers()) do
			if Party.Of(player) then push(player) end
		end
	end
end)
