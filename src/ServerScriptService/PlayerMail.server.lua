-- PlayerMail.server.lua: กล่องจดหมายในหินเวท — ส่งของหาสหาย รับ ลบ
-- ดีไซน์: docs/superpowers/specs/2026-09-24-mail-design.md · ตรรกะกล่องอยู่ที่ Mail.lua ไฟล์นี้ถือแค่กฎของผู้เล่น
--
-- ไม่รันในล็อบบี้ (ไม่มีโปรไฟล์) และถูกกันออกจากเพลสสนามใน arena.project.json (ห้ามเปิดเซสชันที่นั่น)
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby or ServerConfig.IsArena then return end

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local Mail = require(game.ServerScriptService.Mail)
local MailConfig = require(game.ReplicatedStorage.MailConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local Friends = require(game.ServerScriptService.Friends)
local Progression = require(game.ServerScriptService.Progression)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)
local Remotes = require(game.ReplicatedStorage.Remotes)

-- [player] = true ระหว่างส่ง · MessageAsync ค้างได้หลายวินาที ถ้าไม่กัน กดสองทีหักของสองรอบ
local Sending = {}

local function snapshot(player)
	local data = ProfileAccess.Get(player)
	if not data then return end
	local unread = Mail.Unread(data)
	player:SetAttribute("WOLD_MailUnread", unread)
	Remotes.MailUpdate:FireClient(player, {
		letters = Mail.Box(data), cap = MailConfig.BoxSize, fee = MailConfig.Fee, unread = unread,
	})
end

Mail.Changed = function(player, letter)
	if not player:IsDescendantOf(Players) then return end
	snapshot(player)
	if letter then
		Remotes.SocialNotify:FireClient(player, "mail", ("มีจดหมายใหม่จาก %s"):format(letter.fromName))
	end
end

-- ข้อความที่คนอื่นจะอ่านต้องผ่านตัวกรองของ Roblox · Broadcast เพราะผู้รับอ่านทีหลัง อาจอยู่คนละเซิร์ฟ
local function filtered(player, text)
	if text == "" then return "" end
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PrivateChat)
			:GetNonChatStringForBroadcastAsync()
	end)
	return ok and result or nil
end

-- ตัดข้อความที่ขอบตัวอักษร ไม่ใช่ที่ไบต์ — ไทย 3 ไบต์ต่อตัว `:sub(1, 200)` จะผ่ากลางตัวอักษรแล้วได้ UTF-8
-- เสีย ซึ่งทั้งตัวกรองและ DataStore ปฏิเสธ · คืน nil = ข้อความไม่ใช่ UTF-8 ตั้งแต่แรก
local function clip(text)
	if type(text) ~= "string" then return "" end
	if utf8.len(text) == nil then return nil end
	text = text:gsub("[\r\n\t]", " ")
	local cut = utf8.offset(text, MailConfig.BodyMaxLength + 1)
	return cut and text:sub(1, cut - 1) or text
end

local function send(player, toUserId, slotIndex, count, body)
	if Sending[player] then return false, "กำลังส่งฉบับก่อนหน้า รอสักครู่" end
	toUserId, slotIndex = tonumber(toUserId), tonumber(slotIndex)
	count = math.floor(tonumber(count) or 0)
	local mine = Friends.Get(player)
	local friendName = toUserId and mine and mine.friends[toUserId]
	if not friendName then return false, "ส่งได้เฉพาะคนในรายชื่อสหาย" end

	local state = Inventory.Get(player)
	local slot = state and slotIndex and state.slots[slotIndex]
	if not slot then return false, "ไม่มีของในช่องนั้น" end
	if not ItemCatalog.IsMailable(slot.id) then return false, "ของชิ้นนี้ส่งทางเมลไม่ได้ (ส่งได้เฉพาะวัตถุดิบ)" end
	-- เขียนเป็น "ต้องอยู่ในช่วง" ไม่ใช่ "ห้ามออกนอกช่วง": ไคลเอนต์ส่ง NaN (0/0) มาได้ และ NaN ตอบ false กับทุกการ
	-- เปรียบเทียบ — แบบเดิมจึงปล่อยผ่าน แล้วช่องกลายเป็น NaN ที่ผ่านทุกด่านตลอดไป = ปั๊มของ
	if not (count >= 1 and count <= (slot.count or 1)) then return false, "จำนวนไม่ถูกต้อง" end
	if Inventory.CountOf(player, MailConfig.FeeItem) < MailConfig.Fee then
		return false, ("ค่าส่ง %d ซิลเวอร์ — ซิลเวอร์ไม่พอ"):format(MailConfig.Fee)
	end

	Sending[player] = true
	local ok, result = pcall(function()
		body = clip(body)
		if not body then return { false, "ข้อความมีตัวอักษรที่อ่านไม่ได้" } end
		local clean = filtered(player, body)
		if not clean then return { false, "กรองข้อความไม่สำเร็จ ลองใหม่อีกครั้ง" } end

		-- ตัวกรอง yield → ของในช่องอาจเปลี่ยนไปแล้ว (ใช้ ทิ้ง ย้าย) ตรวจใหม่ก่อนหัก
		slot = state.slots[slotIndex]
		if not slot or not ItemCatalog.IsMailable(slot.id) or not (count <= (slot.count or 1)) then
			return { false, "ของในช่องเปลี่ยนไประหว่างส่ง" }
		end
		local item = { id = slot.id, count = count, durability = slot.durability, meta = slot.meta }
		local letter = { from = player.UserId, fromName = player.DisplayName, subject = "", body = clean, items = { item } }
		-- ProfileStore:MessageAsync วนลองใหม่ไม่รู้จบเมื่อเขียนไม่ได้ — จดหมายที่แปลงเป็น JSON ไม่ได้จะค้างปุ่มส่ง
		-- ทั้งเซสชันหลังหักของไปแล้ว จึงตรวจก่อนแตะกระเป๋า
		if not pcall(HttpService.JSONEncode, HttpService, letter) then
			return { false, "ส่งของชิ้นนี้ไม่ได้ (ข้อมูลของเสีย)" }
		end
		if not Inventory.RemoveById(player, MailConfig.FeeItem, MailConfig.Fee) then
			return { false, "ซิลเวอร์ไม่พอ" }
		end
		Inventory.RemoveFromSlot(player, slotIndex, count)

		local sent = Mail.Send(toUserId, letter)
		if not sent then
			-- ponytail: คืนเข้ากระเป๋าตรงๆ ช่องที่เพิ่งว่างถูกเติมเต็มระหว่าง yield ได้ในทางทฤษฎี (ของหาย)
			-- ถ้าเจอจริง ให้ส่งคืนเป็นเมลถึงตัวเองแทน
			Inventory.AddItem(player, item.id, item.count, item.durability, item.meta)
			Inventory.AddItem(player, MailConfig.FeeItem, MailConfig.Fee)
			return { false, "ส่งไม่สำเร็จ (ไปรษณีย์ไม่ตอบ) คืนของและค่าส่งแล้ว" }
		end
		ProfileAccess.Flush(player)
		return { true, ("ส่ง %s x%d ถึง %s แล้ว"):format(ItemCatalog.DisplayName(item.id, item.meta), count, friendName), item }
	end)
	Sending[player] = nil
	if not ok then
		warn("[Mail] send:", result)
		return false, "เกิดข้อผิดพลาด"
	end
	return result[1], result[2], result[3]
end

local function claim(player, letterId)
	local data = ProfileAccess.Get(player)
	if not data then return false, "ข้อมูลยังไม่พร้อม" end
	local _, letter = Mail.Find(data, letterId)
	if not letter then return false, "ไม่พบจดหมาย" end
	if letter.claimed then return false, "รับไปแล้ว" end

	-- ไอเทมที่ถูกถอดออกจากเกมหลังเมลถูกส่ง: ข้ามไป ไม่ให้ติดทั้งฉบับ
	local items, need = {}, {}
	for _, it in ipairs(letter.items) do
		if ItemCatalog.Exists(it.id) then
			items[#items + 1] = it
			need[it.id] = (need[it.id] or 0) + it.count
		end
	end
	-- รวมต่อชนิดก่อนถาม ไม่งั้นสองรายการชนิดเดียวกันผ่านด่านทีละอันแต่ใส่รวมกันไม่พอ
	-- ponytail: ของที่มี meta (สแตค 1) ถามรวมเป็นก้อนเดียวกับของชนิดเดียวกัน — เมลผู้เล่นมีของชิ้นเดียวจึงพอ
	for id, n in pairs(need) do
		if not Inventory.HasRoomFor(player, id, n) then return false, "กระเป๋าเต็ม เก็บของก่อนแล้วกดรับใหม่" end
	end

	letter.claimed = true
	letter.read = true
	for _, it in ipairs(items) do Inventory.AddItem(player, it.id, it.count, it.durability, it.meta) end
	if letter.gold > 0 then Inventory.AddGold(player, letter.gold) end
	if letter.exp > 0 then Progression.AwardExp(player, letter.exp) end
	ProfileAccess.Flush(player)
	return true, "รับของแล้ว"
end

local function deletable(letter)
	return letter.claimed or not Mail.HasAttachment(letter)
end

local function remove(player, letterId)
	local data = ProfileAccess.Get(player)
	if not data then return false, "ข้อมูลยังไม่พร้อม" end
	local index, letter = Mail.Find(data, letterId)
	if not letter then return false, "ไม่พบจดหมาย" end
	if not deletable(letter) then return false, "รับของก่อนแล้วค่อยลบ" end
	table.remove(Mail.Box(data), index)
	Mail.Drain(player, data)
	return true
end

local function clean(player)
	local data = ProfileAccess.Get(player)
	if not data then return false, "ข้อมูลยังไม่พร้อม" end
	local box = Mail.Box(data)
	for i = #box, 1, -1 do
		if deletable(box[i]) then table.remove(box, i) end
	end
	Mail.Drain(player, data)
	return true
end

local function markRead(player)
	local data = ProfileAccess.Get(player)
	if not data then return false end
	for _, letter in ipairs(Mail.Box(data)) do letter.read = true end
	return true
end

local OPS = {
	send = send, claim = claim, delete = remove, clean = clean, read = markRead,
	list = function() return true end,
}

Remotes.RequestMail.OnServerEvent:Connect(function(player, op, ...)
	local fn = OPS[op]
	if not fn then return end
	local ok, message = fn(player, ...)
	if type(message) == "string" then
		Remotes.SocialNotify:FireClient(player, ok and "info" or "error", message)
	end
	snapshot(player)
end)

-- เข้าเกม: ดึงคิวที่ค้าง (ถ้ามี) และส่งภาพกล่องไปก่อน ป้ายตัวเลขจะได้ขึ้นก่อนเปิดหินเวท
PlayerJoin.Each(function(player)
	local data = ProfileAccess.Wait(player)
	if not data then return end
	Mail.Drain(player, data)
	snapshot(player)
end)

Players.PlayerRemoving:Connect(function(player)
	Sending[player] = nil
	Mail.Forget(player)
end)

--------------------------------------------------------------------------------
-- ช่องเทสใน Studio (tests/mail_test.lua) — ทรงเดียวกับ QuestTest · เซิร์ฟเวอร์จริงไม่มีช่องนี้
--------------------------------------------------------------------------------

if game:GetService("RunService"):IsStudio() then
	local function withFriend(player, userId, on, fn)
		local mine = Friends.Get(player)
		local before = mine.friends[userId]
		mine.friends[userId] = on and "เพื่อนเทส" or nil
		local results = table.pack(pcall(fn))
		mine.friends[userId] = before
		assert(results[1], results[2])
		return table.unpack(results, 2, results.n)
	end

	local function withTransport(kind, fn)
		local real = Mail.Transport
		local captured = nil
		Mail.Transport = function(_, letter)
			captured = letter
			if kind == "slow" then task.wait(1) end
			return kind ~= "fail"
		end
		local results = table.pack(pcall(fn))
		Mail.Transport = real
		assert(results[1], results[2])
		return captured, table.unpack(results, 2, results.n)
	end

	local bf = Instance.new("BindableFunction")
	bf.Name = "MailTest"
	bf.OnInvoke = function(op, player, ...)
		local args = table.pack(...)
		if op == "Grant" then return Inventory.AddItem(player, args[1], args[2]) end
		if op == "Revoke" then return args[2] <= 0 or Inventory.RemoveById(player, args[1], args[2]) end
		if op == "Count" then return Inventory.CountOf(player, args[1]) end
		if op == "SlotOf" then return Inventory.FindSlotById(player, args[1]) end
		if op == "Send" then
			local to, slot, count, body, opts = args[1], args[2], args[3], args[4], args[5]
			return withFriend(player, to, opts.friend, function()
				local captured, ok, msg = withTransport(opts.transport, function()
					return send(player, to, slot, count, body)
				end)
				return ok, msg, ok and captured or nil
			end)
		end
		if op == "DoubleSend" then
			local to, slot, count = args[1], args[2], args[3]
			return withFriend(player, to, true, function()
				local _, first, second = withTransport("slow", function()
					local secondResult
					task.delay(0.2, function() secondResult = send(player, to, slot, count, "") end)
					local firstResult = send(player, to, slot, count, "")
					return firstResult, secondResult
				end)
				return first, second
			end)
		end
		local data = ProfileAccess.Get(player)
		if op == "Put" then
			local letter, forceRemoveId = args[1], args[2]
			if forceRemoveId then
				local index = Mail.Find(data, forceRemoveId)
				if index then table.remove(Mail.Box(data), index) end
				return true
			end
			letter.id = "test-" .. math.random(1, 1e9)
			Mail.Deliver(player, data, letter, function() end)
			return letter.id
		end
		-- เทสที่ล้มกลางทางทิ้งจดหมายค้าง รันซ้ำไม่กี่รอบกล่องก็เต็ม 50 — เทสล้างกล่องก่อนเริ่มเสมอ
		if op == "ClearBox" then
			data.Mail = {}
			Mail.Forget(player)
			return true
		end
		if op == "Claim" then return claim(player, args[1]) end
		if op == "Remove" then return (remove(player, args[1])) end
		if op == "Letter" then return select(2, Mail.Find(data, args[1])) end
		if op == "FullBox" then
			local saved = data.Mail
			data.Mail = {}
			for i = 1, MailConfig.BoxSize do Mail.Deliver(player, data, { id = "fill" .. i }, function() end) end
			local processed = false
			Mail.Deliver(player, data, { id = "extra" }, function() processed = true end)
			local result = { heldBefore = Mail.HeldCount(player), processedBefore = processed }
			remove(player, "fill1")
			result.processedAfter = processed
			result.inBoxAfter = Mail.Find(data, "extra") ~= nil
			data.Mail = saved
			Mail.Forget(player)
			return result
		end
		error("MailTest: ไม่มี op " .. tostring(op))
	end
	bf.Parent = game:GetService("ServerStorage")
end
