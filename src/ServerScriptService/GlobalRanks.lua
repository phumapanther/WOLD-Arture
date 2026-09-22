-- GlobalRanks.lua: อันดับของ **ทั้งเกม** ไม่ใช่แค่คนในเซิร์ฟเวอร์นี้
--
-- เลเวลกับเงินเท่านั้น (ผู้ใช้กำหนด 2026-09-22) — แต้มกิจกรรมกับ "ช่องไหนคนเยอะ" ยังเป็นของเดิม
-- เพราะอย่างหลังโดยนิยามคือจำนวนคนที่ออนไลน์ *ตอนนี้* ซึ่งไม่ใช่สิ่งที่เก็บลงตารางอันดับได้
--
-- ## ทำไมต้องมีไฟล์นี้
--
-- `Leaderboards.server` อ่านจาก `Players:GetPlayers()` = คนที่อยู่ในเซิร์ฟเวอร์นี้เท่านั้น ซึ่งใช้ได้ดี
-- ในเซิร์ฟเวอร์เกมหลักที่มีคนหลายสิบคน แต่ **บนเกาะส่วนตัวมันคือรายชื่อที่มีชื่อเดียว** — คำถามว่า
-- "ใครรวยสุดในเกม" จึงตอบไม่ได้เลยจากที่นั่น
--
-- ## OrderedDataStore: ข้อจำกัดที่กำหนดรูปร่างของไฟล์นี้
--
-- 1. **เก็บได้แต่จำนวนเต็ม** ชื่อผู้เล่นจึงเก็บที่นี่ไม่ได้ · คีย์คือ userId (สตริง) ค่าคือตัวเลข
--    ชื่อถูกเติมทีหลังด้วย `Players:GetNameFromUserIdAsync` แล้วแคชไว้
-- 2. **โควตาเขียนจำกัด** เขียนทุกครั้งที่เงินขยับ = ยิง DataStore ทุกครั้งที่ขายของชิ้นเดียว
--    → เขียน**ตามรอบ** (ทุก UPDATE_SECONDS) และเขียนเฉพาะคนที่ค่าเปลี่ยนจริงตั้งแต่รอบก่อน
-- 3. **อ่านก็มีโควตา** → แคชตารางไว้ CACHE_SECONDS ทุกคนในเซิร์ฟเวอร์ใช้สำเนาเดียวกัน
--
-- ## ค่าที่เก็บ
--
-- เงินเก็บเป็น **จำนวนเต็มของเหรียญ** (ติดตัว + ในธนาคาร) เหมือนที่ตารางเดิมคิด — ไม่งั้น "คนรวยสุด"
-- จะกลายเป็นคนที่พกเงินสดเยอะสุด ซึ่งคนละเรื่องกับรวย และจะสอนให้คนไม่ฝากเงินเพื่อไต่อันดับ
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GlobalRanks = {}

-- **ชื่อตารางมีเลขเวอร์ชันต่อท้าย** วันที่อยากล้างอันดับใหม่ (เช่นรีเซ็ตซีซัน หรือแก้หน่วยที่เก็บ)
-- ให้ขยับเลขนี้ แทนที่จะต้องไปไล่ลบคีย์ทีละคน ซึ่ง OrderedDataStore ทำไม่ได้อยู่แล้ว
local STORES = {
	levels = "WOLD_Rank_Levels_v1",
	gold = "WOLD_Rank_Gold_v1",
}

GlobalRanks.TopCount = 50 -- ท็อปกี่คน
local CACHE_SECONDS = 60 -- อ่านตารางใหม่ทุกกี่วินาที
local NAME_CACHE = {} -- [userId] = ชื่อ (ไม่หมดอายุ ชื่อเปลี่ยนไม่บ่อยพอจะคุ้มกับการถามซ้ำ)

local stores = {}
local function storeFor(kind)
	if not stores[kind] then
		local name = STORES[kind]
		if not name then return nil end
		local ok, s = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
		if not ok then return nil end
		stores[kind] = s
	end
	return stores[kind]
end

--------------------------------------------------------------------------------
-- เขียน
--------------------------------------------------------------------------------

-- ค่าที่เขียนไปล่าสุดของแต่ละคน — กันเขียนซ้ำค่าเดิม
local LastWritten = {} -- [userId] = { levels = n, gold = n }

-- **ค่าติดลบหรือใหญ่เกินเขียนไม่ได้** OrderedDataStore รับ int64 แต่ในทางปฏิบัติค่าที่เกิน 2^53
-- จะเพี้ยนตอนแปลงกลับเป็น number ของ Lua · จำกัดไว้ให้ปลอดภัย
local MAX_VALUE = 2 ^ 40

local function sane(value)
	value = math.floor(tonumber(value) or 0)
	if value < 0 then return 0 end
	if value > MAX_VALUE then return MAX_VALUE end
	return value
end

-- บันทึกค่าของคนหนึ่งลงตารางอันดับ · เงียบเมื่อค่าไม่เปลี่ยน
function GlobalRanks.Write(userId, kind, value)
	local store = storeFor(kind)
	if not store then return false end
	userId = tonumber(userId)
	if not userId then return false end
	value = sane(value)

	local last = LastWritten[userId]
	if last and last[kind] == value then return true end

	local ok = pcall(store.SetAsync, store, tostring(userId), value)
	if ok then
		LastWritten[userId] = last or {}
		LastWritten[userId][kind] = value
		NAME_CACHE[userId] = NAME_CACHE[userId] -- คงไว้เฉยๆ
	end
	return ok
end

function GlobalRanks.Forget(userId)
	LastWritten[tonumber(userId) or 0] = nil
end

--------------------------------------------------------------------------------
-- อ่าน
--------------------------------------------------------------------------------

local Cache = {} -- [kind] = { rows = {...}, at = os.clock() }

-- ชื่อจาก userId · **ต้องหุ้ม pcall** บัญชีที่ถูกลบไปแล้วจะโยน error ไม่ใช่คืน nil
local function nameOf(userId)
	local cached = NAME_CACHE[userId]
	if cached then return cached end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		NAME_CACHE[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	name = ok and name or ("ผู้เล่น #" .. userId)
	NAME_CACHE[userId] = name
	return name
end

-- ตารางอันดับของชนิดนี้ · คืน {} เมื่ออ่านไม่ได้ (ยังไม่เปิด API / DataStore ล่ม)
function GlobalRanks.Top(kind)
	local cached = Cache[kind]
	if cached and os.clock() - cached.at < CACHE_SECONDS then return cached.rows end

	local store = storeFor(kind)
	if not store then return cached and cached.rows or {} end

	local ok, pages = pcall(store.GetSortedAsync, store, false, GlobalRanks.TopCount)
	if not ok then
		-- อ่านไม่ได้ก็ใช้ของเก่าต่อ ดีกว่าโชว์ตารางว่าง
		return cached and cached.rows or {}
	end

	local rows = {}
	local okPage, page = pcall(pages.GetCurrentPage, pages)
	if okPage then
		for _, entry in ipairs(page) do
			local userId = tonumber(entry.key)
			if userId then
				rows[#rows + 1] = { userId = userId, value = entry.value, name = nameOf(userId) }
			end
		end
	end

	Cache[kind] = { rows = rows, at = os.clock() }
	return rows
end

-- อันดับของคนคนหนึ่ง (นับจากตารางท็อปที่อ่านมา) · nil = ไม่ติดท็อป
function GlobalRanks.PlaceOf(kind, userId)
	for i, row in ipairs(GlobalRanks.Top(kind)) do
		if row.userId == userId then return i end
	end
	return nil
end

-- ล้างแคชการอ่าน (เทส)
function GlobalRanks.ClearCache()
	Cache = {}
end

return GlobalRanks
