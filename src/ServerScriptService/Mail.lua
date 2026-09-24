-- Mail.lua: กล่องจดหมาย — ส่ง รับเข้ากล่อง และถือคิวตอนกล่องเต็ม · ไม่รู้จัก remote ไม่รู้จัก UI
-- ดีไซน์: docs/superpowers/specs/2026-09-24-mail-design.md
--
-- เมลเดินทางด้วย ProfileStore:MessageAsync เข้าไปอยู่ในโปรไฟล์ของผู้รับเอง ส่งถึงคนที่ออฟไลน์หรือเล่นอยู่
-- อีกเซิร์ฟได้ และตอนกดรับ เมลกับกระเป๋าอยู่ในโปรไฟล์ก้อนเดียวกัน = ของไม่หายไม่ซ้ำ
--
-- ⚠️ **ข้อความที่ยังไม่ `processed()` ProfileStore เก็บค้างไว้ในโปรไฟล์** แต่เรียกตัวรับให้แค่ครั้งเดียวต่อเซสชัน
-- กล่องเต็มจึงต้องจำ callback ไว้เอง (Held) แล้วดึงเข้ากล่องเมื่อมีช่อง · เซิร์ฟปิดก่อน = มาใหม่รอบหน้า ไม่หาย
local HttpService = game:GetService("HttpService")
local MailConfig = require(game.ReplicatedStorage.MailConfig)
local ProfileAccess = require(script.Parent.ProfileAccess)

local Mail = {}

local Held = {} -- [player] = { { letter, processed }, ... } เมลที่มาถึงตอนกล่องเต็ม
local fallbackStore = nil

-- hook: PlayerMail.server ตั้งไว้เพื่อส่งภาพกล่องใหม่ให้ไคลเอนต์ · letter = ฉบับที่เพิ่งมาถึง (nil = แค่เปลี่ยน)
Mail.Changed = nil

-- ทางส่งจริง แยกออกมาให้เทสสวมแทนได้โดยไม่แตะ DataStore
function Mail.Transport(userId, letter)
	if ProfileAccess.MessageAsync then return ProfileAccess.MessageAsync(userId, letter) end
	-- ponytail: เซิร์ฟสนามไม่มี PlayerProfile.server (ห้ามเปิดเซสชันที่นั่น) จึงไม่มีใครตั้ง MessageAsync
	-- เปิด store ชื่อเดียวกันเองไว้ส่งข้อความอย่างเดียว — MessageAsync ไม่ต้องเปิดเซสชัน ไม่แย่งล็อกใคร
	fallbackStore = fallbackStore or require(script.Parent.ProfileStore).New("WOLD_PlayerProfile_v1", {})
	local ok, sent = pcall(function()
		return fallbackStore:MessageAsync("Player_" .. userId, letter)
	end)
	if not ok then warn("[Mail] ส่งถึง", userId, "ไม่ได้:", sent) end
	return ok and sent == true
end

-- ส่งเมลหนึ่งฉบับ คืน true เมื่อ ProfileStore รับฝากแล้ว (ยัง yield ได้หลายวินาที)
function Mail.Send(toUserId, letter)
	toUserId = tonumber(toUserId)
	if not toUserId or type(letter) ~= "table" then return false end
	letter.kind = "mail"
	letter.id = HttpService:GenerateGUID(false)
	letter.at = os.time()
	return Mail.Transport(toUserId, letter) == true
end

function Mail.Box(data)
	if type(data.Mail) ~= "table" then data.Mail = {} end
	return data.Mail
end

function Mail.Find(data, letterId)
	for index, letter in ipairs(Mail.Box(data)) do
		if letter.id == letterId then return index, letter end
	end
	return nil, nil
end

function Mail.HasAttachment(letter)
	return #(letter.items or {}) > 0 or (letter.gold or 0) > 0 or (letter.exp or 0) > 0
end

function Mail.Unread(data)
	local n = 0
	for _, letter in ipairs(Mail.Box(data)) do
		if not letter.read then n += 1 end
	end
	return n
end

-- ข้อความมาจากเซิร์ฟของเราเองทั้งหมด แต่ผ่าน DataStore มา — จัดรูปให้ตรงก่อนเก็บ ของที่ผิดรูปคือเมลที่
-- จะทำให้หน้าจอหรือการกดรับพังทุกครั้งที่เปิดกล่อง
local function sanitize(m)
	if type(m) ~= "table" or type(m.id) ~= "string" then return nil end
	local items = {}
	for _, it in ipairs(type(m.items) == "table" and m.items or {}) do
		if type(it) == "table" and type(it.id) == "string" then
			items[#items + 1] = {
				id = it.id,
				count = math.max(1, math.floor(tonumber(it.count) or 1)),
				durability = tonumber(it.durability),
				meta = type(it.meta) == "table" and it.meta or nil,
			}
		end
	end
	return {
		id = m.id,
		at = tonumber(m.at) or os.time(),
		from = tonumber(m.from) or 0,
		fromName = tostring(m.fromName or "ระบบ"),
		subject = tostring(m.subject or ""),
		body = tostring(m.body or ""),
		items = items,
		gold = math.max(0, math.floor(tonumber(m.gold) or 0)),
		exp = math.max(0, math.floor(tonumber(m.exp) or 0)),
		claimed = m.claimed == true,
		read = m.read == true,
	}
end

-- ตัวรับข้อความ `kind == "mail"` (เรียกจาก MessageHandler ใน PlayerProfile.server)
function Mail.Deliver(player, data, message, processed)
	local letter = sanitize(message)
	-- ข้อความเสีย: ทิ้ง ถ้าไม่ processed มันจะค้างคิวแล้วมาหาทุกครั้งที่เข้าเกม
	if not letter then processed() return true end
	-- id ซ้ำ = ฉบับนี้อยู่ในกล่องแล้ว (ProfileStore ส่งซ้ำได้ถ้าเซิร์ฟล่มก่อนเซฟ) ปล่อยคิวเฉยๆ
	if Mail.Find(data, letter.id) then processed() return true end

	local box = Mail.Box(data)
	if #box >= MailConfig.BoxSize then
		Held[player] = Held[player] or {}
		table.insert(Held[player], { letter = letter, processed = processed })
		return false
	end
	table.insert(box, letter)
	processed()
	if Mail.Changed then task.defer(Mail.Changed, player, letter) end
	return true
end

-- ดึงเมลที่รอคิวเข้ากล่องเท่าที่มีช่อง เรียกทุกครั้งที่กล่องมีช่องว่างเพิ่ม (ลบ/ล้าง) และตอนเข้าเกม
function Mail.Drain(player, data)
	local held = Held[player]
	while held and #held > 0 and #Mail.Box(data) < MailConfig.BoxSize do
		local entry = table.remove(held, 1)
		Mail.Deliver(player, data, entry.letter, entry.processed)
	end
end

function Mail.HeldCount(player)
	return Held[player] and #Held[player] or 0
end

function Mail.Forget(player)
	Held[player] = nil
end

return Mail
