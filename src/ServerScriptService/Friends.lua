-- Friends.lua: the friend list, and the pigeon messages between friends.
--
-- The LIST is permanent (it lives in both players' profiles, so it survives rejoins and holds across
-- channels). The CONVERSATIONS are not: they live in this server's memory and are gone when it closes,
-- which is the same trade the guild board makes.
--
-- Friendship is mutual and requires consent: you send a request, they accept. One-sided adding turns a
-- friend list into a spam surface.
local SocialConfig = require(game.ReplicatedStorage.SocialConfig)
local ProfileAccess = require(script.Parent.ProfileAccess)
local Announce = require(script.Parent.Announce)

local Friends = {}

-- [player] = { friends = {[userId] = name}, pending = {[userId] = name} }
-- `pending` holds requests SENT TO this player, waiting on their answer.
local States = {}

-- Conversations, keyed by the two user ids sorted so either direction finds the same thread.
local Threads = {} -- ["123:456"] = { {from, name, text, at}, ... } oldest first
local LastMessageAt = {} -- [player] = os.clock()

local function threadKey(a, b)
	return (a < b) and (a .. ":" .. b) or (b .. ":" .. a)
end

local function count(map)
	local n = 0
	for _ in pairs(map) do n += 1 end
	return n
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function Friends.Add(player, saved)
	States[player] = {
		-- Profile keys come back from the DataStore as strings; normalise to numbers so lookups by UserId work.
		friends = {},
		pending = {},
	}
	local state = States[player]
	for id, name in pairs((saved and saved.Friends) or {}) do
		state.friends[tonumber(id) or id] = name
	end
	for id, name in pairs((saved and saved.Pending) or {}) do
		state.pending[tonumber(id) or id] = name
	end
	return state
end

function Friends.Remove(player)
	States[player] = nil
	LastMessageAt[player] = nil
end

function Friends.Get(player)
	return States[player]
end

function Friends.Serialize(player)
	local state = States[player]
	if not state then return nil end
	-- Keys are written as strings because that is what survives a DataStore round trip intact.
	local friends, pending = {}, {}
	for id, name in pairs(state.friends) do friends[tostring(id)] = name end
	for id, name in pairs(state.pending) do pending[tostring(id)] = name end
	return { Friends = friends, Pending = pending }
end

--------------------------------------------------------------------------------
-- Requests
--------------------------------------------------------------------------------

local function displayName(player)
	return player.DisplayName ~= "" and player.DisplayName or player.Name
end

-- Sends a request to a player in this server. Returns false plus a reason the UI can show.
function Friends.Request(player, targetName)
	if typeof(targetName) ~= "string" then return false, "ชื่อไม่ถูกต้อง" end
	local wanted = targetName:gsub("^@", ""):gsub("%s", ""):lower()
	if wanted == "" then return false, "ใส่ชื่อด้วย" end

	local Players = game:GetService("Players")
	local target
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Name:lower() == wanted or other.DisplayName:lower() == wanted then
			target = other
			break
		end
	end
	if not target then return false, "ไม่เจอผู้เล่นชื่อนี้ในเซิร์ฟเวอร์" end
	if target == player then return false, "เพิ่มตัวเองไม่ได้" end

	local mine, theirs = States[player], States[target]
	if not mine or not theirs then return false, "ยังโหลดข้อมูลไม่เสร็จ" end
	if mine.friends[target.UserId] then return false, "เป็นเพื่อนกันอยู่แล้ว" end
	if count(mine.friends) >= SocialConfig.MaxFriends then return false, "รายชื่อเพื่อนเต็มแล้ว" end
	if count(theirs.friends) >= SocialConfig.MaxFriends then return false, "รายชื่อเพื่อนของอีกฝ่ายเต็ม" end
	if theirs.pending[player.UserId] then return false, "ส่งคำขอไปแล้ว รออีกฝ่ายตอบรับ" end

	-- They already asked you: accept instead of starting a second request in the other direction.
	if mine.pending[target.UserId] then
		return Friends.Accept(player, target.UserId)
	end

	if count(theirs.pending) >= SocialConfig.MaxPendingRequests then
		return false, "อีกฝ่ายมีคำขอค้างเยอะเกินไป"
	end

	theirs.pending[player.UserId] = displayName(player)
	if ProfileAccess.Flush then ProfileAccess.Flush(target) end
	return true, ("ส่งคำขอเป็นเพื่อนถึง %s แล้ว"):format(target.Name), target
end

-- Accepts a pending request. The other player does NOT have to still be here -- the request is already
-- recorded, so the friendship can complete either way; only their live state needs updating if they are.
function Friends.Accept(player, fromUserId)
	fromUserId = tonumber(fromUserId)
	local mine = States[player]
	if not mine or not fromUserId then return false, "คำขอไม่ถูกต้อง" end
	local name = mine.pending[fromUserId]
	if not name then return false, "ไม่มีคำขอจากคนนี้" end
	if count(mine.friends) >= SocialConfig.MaxFriends then return false, "รายชื่อเพื่อนเต็มแล้ว" end

	mine.pending[fromUserId] = nil
	mine.friends[fromUserId] = name

	-- Add the other side too, so the friendship is symmetric wherever they are.
	local Players = game:GetService("Players")
	local other = Players:GetPlayerByUserId(fromUserId)
	if other and States[other] then
		States[other].friends[player.UserId] = displayName(player)
		States[other].pending[player.UserId] = nil
		if ProfileAccess.Flush then ProfileAccess.Flush(other) end
	end
	-- If they are offline the pairing is one-sided until they next join; PlayerSocial repairs that on load.

	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	return true, ("เป็นเพื่อนกับ %s แล้ว"):format(name), other
end

function Friends.Decline(player, fromUserId)
	fromUserId = tonumber(fromUserId)
	local mine = States[player]
	if not mine or not fromUserId or not mine.pending[fromUserId] then return false, "ไม่มีคำขอจากคนนี้" end
	mine.pending[fromUserId] = nil
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	return true, "ปฏิเสธคำขอแล้ว"
end

function Friends.RemoveFriend(player, userId)
	userId = tonumber(userId)
	local mine = States[player]
	if not mine or not userId or not mine.friends[userId] then return false, "ไม่ได้เป็นเพื่อนกัน" end
	local name = mine.friends[userId]
	mine.friends[userId] = nil

	local Players = game:GetService("Players")
	local other = Players:GetPlayerByUserId(userId)
	if other and States[other] then
		States[other].friends[player.UserId] = nil
		if ProfileAccess.Flush then ProfileAccess.Flush(other) end
	end
	-- A friend removed while offline keeps this player in THEIR list until they next load; repaired on join.

	Threads[threadKey(player.UserId, userId)] = nil
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	return true, ("ลบ %s ออกจากรายชื่อแล้ว"):format(name), other
end

-- Drops any friendship this player's list claims that the other side no longer agrees with. Called when a
-- profile loads, which is the only moment both halves can be compared.
function Friends.Reconcile(player)
	local mine = States[player]
	if not mine then return end
	local Players = game:GetService("Players")
	for userId in pairs(mine.friends) do
		local other = Players:GetPlayerByUserId(userId)
		local theirs = other and States[other]
		if theirs and not theirs.friends[player.UserId] then
			mine.friends[userId] = nil
		end
	end
end

--------------------------------------------------------------------------------
-- Pigeon messages
--------------------------------------------------------------------------------

local function clean(text)
	if typeof(text) ~= "string" then return nil end
	text = text:gsub("[\r\n\t]", " "):gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
	if text == "" then return nil end
	return Announce.Trim(text, SocialConfig.MessageMaxLength)
end

-- Sends to a friend who is in this server. Returns the recipient too, so the caller can notify them.
function Friends.Send(player, toUserId, text)
	toUserId = tonumber(toUserId)
	local mine = States[player]
	if not mine or not toUserId then return false, "ผู้รับไม่ถูกต้อง" end
	if not mine.friends[toUserId] then return false, "ส่งได้เฉพาะเพื่อนเท่านั้น" end

	local body = clean(text)
	if not body then return false, "ข้อความว่างเปล่า" end

	local now = os.clock()
	local last = LastMessageAt[player]
	if last and now - last < SocialConfig.MessageCooldown then return false, "ส่งเร็วเกินไป" end
	LastMessageAt[player] = now

	local Players = game:GetService("Players")
	local target = Players:GetPlayerByUserId(toUserId)
	-- Cross-server delivery would need MessagingService; the spec puts that out of scope, so say so plainly
	-- rather than accepting a message that will never arrive.
	if not target then return false, "เพื่อนคนนี้ไม่ได้อยู่ในเซิร์ฟเวอร์นี้" end

	-- **ผ่านตัวกรองของ Roblox ก่อนส่ง** (QA 2026-09-26) แบบแชทส่วนตัว สำหรับผู้รับคนนั้น · กรองไม่ได้ = ไม่ส่ง
	body = Announce.FilterFor(body, player.UserId, toUserId)
	if not body then return false, "กรองข้อความไม่สำเร็จ ลองใหม่อีกครั้ง" end

	local key = threadKey(player.UserId, toUserId)
	local thread = Threads[key]
	if not thread then
		thread = {}
		Threads[key] = thread
	end
	local message = {
		from = player.UserId,
		name = displayName(player),
		text = body,
		at = os.time(),
	}
	table.insert(thread, message)
	while #thread > SocialConfig.MessageHistory do
		table.remove(thread, 1) -- oldest first, so trim from the front
	end
	return true, message, target
end

function Friends.Thread(player, otherUserId)
	otherUserId = tonumber(otherUserId)
	if not otherUserId then return {} end
	local thread = Threads[threadKey(player.UserId, otherUserId)]
	if not thread then return {} end
	local out = table.create(#thread)
	for i, m in ipairs(thread) do out[i] = m end
	return out
end

return Friends
