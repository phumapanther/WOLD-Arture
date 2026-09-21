-- Party.lua: ตี้ของผู้เล่น — สูงสุดตาม `SocialConfig.PartyMax` (ตอนนี้ 4 คน) และคนในตี้เดียวกันตีกันไม่ได้
--
-- อยู่ในหน่วยความจำของเซิร์ฟเวอร์นี้เท่านั้น ไม่เซฟ: ตี้คือ "ตอนนี้เราเล่นด้วยกัน" ไม่ใช่ความสัมพันธ์ถาวร
-- (อันนั้นคือรายชื่อสหายซึ่งอยู่ในโปรไฟล์) ออกเกมแล้วหลุดตี้เอง เข้ามาใหม่ก็ชวนกันใหม่
--
-- **ไฟล์นี้ตัดสินอย่างเดียว ไม่ยุ่งกับ remote และไม่รู้จัก UI** — `PlayerParty.server` เป็นคนคุยกับไคลเอนต์
-- ส่วน `PlayerCombat`/`WeaponSkills` ถาม `Party.SameParty` ตรงจุดที่จะทำดาเมจ เพราะเป็นโมดูลธรรมดา
-- การ require จากหลายสคริปต์จึงได้ตารางเดียวกัน (ModuleScript แคชต่อ VM)
local SocialConfig = require(game.ReplicatedStorage.SocialConfig)

local Party = {}

-- [player] = party · party = { members = { player, ... }, leader = player }
-- ทุกคนในตี้ชี้มาที่ตารางเดียวกัน การเปลี่ยนสมาชิกจึงเห็นพร้อมกันทุกคนโดยไม่ต้องไล่ซิงก์
local Of = {}

-- คำเชิญที่ยังไม่ถูกตอบ: [target] = { [fromUserId] = { from = player, at = os.clock() } }
-- เก็บฝั่งคนถูกชวน เพราะคำถามที่ต้องตอบคือของเขา และคนหนึ่งถูกชวนพร้อมกันได้หลายตี้
local Invites = {}

local function expired(invite)
	return os.clock() - invite.at > SocialConfig.PartyInviteSeconds
end

--------------------------------------------------------------------------------
-- อ่านสถานะ
--------------------------------------------------------------------------------

function Party.Of(player)
	return Of[player]
end

-- สมาชิกทั้งหมด (รวมตัวเอง) — คนที่ไม่มีตี้คืนตัวเองคนเดียว ผู้เรียกจึงไม่ต้องเขียน `if party then` ทุกที่
function Party.Members(player)
	local party = Of[player]
	if not party then return { player } end
	local out = {}
	for _, member in ipairs(party.members) do out[#out + 1] = member end
	return out
end

-- **ด่านเดียวที่ห้ามตีกัน** — เรียกจากทุกที่ที่ผู้เล่นทำดาเมจใส่ผู้เล่น
function Party.SameParty(a, b)
	if not a or not b or a == b then return false end
	local party = Of[a]
	return party ~= nil and party == Of[b]
end

function Party.IsFull(party)
	return #party.members >= SocialConfig.PartyMax
end

--------------------------------------------------------------------------------
-- ชวน / รับ / ปฏิเสธ
--------------------------------------------------------------------------------

-- คืน ok, ข้อความ — ข้อความคือสิ่งที่คนกดปุ่มจะได้อ่าน จึงบอกเหตุผลจริงเสมอ ไม่ใช่ "ทำไม่ได้"
function Party.Invite(from, target)
	if not from or not target or from == target then return false, "ชวนตัวเองไม่ได้" end
	if Of[target] then
		-- แยกสองกรณีเพราะคนกดอ่านคนละความหมาย: "อยู่ในตี้อื่น" แปลว่าต้องรอเขาออกก่อน
		-- ส่วน "อยู่ในตี้คุณแล้ว" แปลว่ากดผิดเฉยๆ
		if Of[target] == Of[from] then return false, ("%s อยู่ในตี้คุณอยู่แล้ว"):format(target.DisplayName) end
		return false, ("%s อยู่ในตี้อื่นแล้ว"):format(target.DisplayName)
	end

	local party = Of[from]
	if party and Party.IsFull(party) then
		return false, ("ตี้เต็มแล้ว (สูงสุด %d คน)"):format(SocialConfig.PartyMax)
	end

	local mine = Invites[target] or {}
	Invites[target] = mine
	local existing = mine[from.UserId]
	if existing and not expired(existing) then
		return false, "ชวนไปแล้ว รอเขาตอบก่อน"
	end
	mine[from.UserId] = { from = from, at = os.clock() }
	return true, ("ส่งคำชวนถึง %s แล้ว"):format(target.DisplayName)
end

-- รับคำชวน: ตี้เกิดตรงนี้ถ้าคนชวนยังไม่มีตี้ — ไม่ใช่ตอนกดชวน เพราะตี้คนเดียวไม่ใช่ตี้
-- และคนที่ชวนแล้วถูกปฏิเสธไม่ควรค้างอยู่ในตี้ร้างที่ตัวเองไม่รู้ว่ามี
--
-- คืน ok, ข้อความ, party, สมาชิกที่ต้องอัปเดตหน้าจอ
function Party.Accept(target, fromUserId)
	local mine = Invites[target]
	local invite = mine and mine[fromUserId]
	if not invite or expired(invite) then
		if mine then mine[fromUserId] = nil end
		return false, "คำชวนนี้หมดอายุแล้ว"
	end
	mine[fromUserId] = nil

	local from = invite.from
	if not from.Parent then return false, "คนที่ชวนออกจากเกมไปแล้ว" end
	if Of[target] then return false, "คุณอยู่ในตี้อื่นแล้ว" end

	local party = Of[from]
	if not party then
		party = { members = { from }, leader = from }
		Of[from] = party
	elseif Party.IsFull(party) then
		return false, ("ตี้เต็มแล้ว (สูงสุด %d คน)"):format(SocialConfig.PartyMax)
	end

	party.members[#party.members + 1] = target
	Of[target] = party
	return true, ("เข้าตี้ของ %s แล้ว"):format(from.DisplayName), party
end

function Party.Decline(target, fromUserId)
	local mine = Invites[target]
	local invite = mine and mine[fromUserId]
	if mine then mine[fromUserId] = nil end
	return invite and invite.from or nil
end

--------------------------------------------------------------------------------
-- ออกจากตี้
--------------------------------------------------------------------------------

-- ออกเอง ออกเพราะปิดเกม หรือโดนเตะ — จากมุมของสถานะคืออย่างเดียวกัน
-- คืนรายชื่อ "คนที่ยังอยู่" เพื่อให้ผู้เรียกไปอัปเดตหน้าจอของพวกเขา (คนที่ออกไปแล้วอัปเดตแยก)
--
-- **เหลือคนเดียว = ตี้สลาย** ไม่ปล่อยให้มีตี้หนึ่งคนค้างไว้ ไม่งั้นคนนั้นจะเห็นแถบตี้เปล่าๆ
-- และ "ตีกันไม่ได้" จะเหลือความหมายแค่กับตัวเอง ซึ่งไม่มีอยู่จริงอยู่แล้ว
function Party.Leave(player)
	local party = Of[player]
	if not party then return nil end
	Of[player] = nil

	for index, member in ipairs(party.members) do
		if member == player then
			table.remove(party.members, index)
			break
		end
	end

	if #party.members <= 1 then
		local left = party.members
		for _, member in ipairs(left) do Of[member] = nil end
		party.members = {}
		return left, true
	end

	if party.leader == player then party.leader = party.members[1] end
	return party.members, false
end

-- ออกจากเกม: ถอนออกจากตี้ และทิ้งคำเชิญทุกใบที่เกี่ยวกับเขา (ทั้งที่ได้รับและที่ส่งไปหาคนอื่น)
-- ถ้าไม่ล้างฝั่งที่ส่งไป ตารางจะถือ Player ที่ออกไปแล้วไว้จนกว่าคนรับจะกดตอบ
function Party.Remove(player)
	local remaining, dissolved = Party.Leave(player)
	Invites[player] = nil
	for _, mine in pairs(Invites) do
		mine[player.UserId] = nil
	end
	return remaining, dissolved
end

return Party
