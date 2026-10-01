-- ArenaRegistry.lua: เซิร์ฟแมตช์ PVP ตัวไหนเป็นของใคร และรางวัลที่รอส่งกลับเกมหลัก
--
-- ไฟล์เดียวที่แตะ DataStore/TeleportService ของโหมด PVP — โครงเดียวกับ `ChannelRegistry` กับ
-- `FarmRegistry` เป๊ะ ต่างแค่กุญแจ: ของช่องคือ "ช่องที่ 3 ของโหมด Roleplay" ของเกาะคือ "เกาะของ userId"
-- ส่วนของนี่คือ **"แมตช์หนึ่งแมตช์"** ซึ่งเกิดมาแล้วตายไปพร้อมเซิร์ฟ ไม่ใช่ห้องถาวร
--
--   arenamatch_<privateServerId> = { mapId, teams = { A = {userId…}, B = {userId…} }, bots = { A = n, B = n }, parties, createdAt }
--   arenareward_<userId>         = { { gold = n, chest = "Chest_…", at = os.time() }, … }
--
-- ⚠️ **เซิร์ฟแมตช์ต้องไม่เชื่อ `TeleportData` เรื่องทีม** (`06-modes-build-plan.md` §4.2)
-- ไคลเอนต์แก้ TeleportData ไม่ได้ก็จริง แต่ระบบที่เชื่อข้อมูลขามาอย่างเดียวจะพังทันทีที่มีใครเข้าผิดเซิร์ฟ
-- หรือเข้าเซิร์ฟที่จองไว้ให้คนอื่น — บันทึกที่นี่คือคำตอบสุดท้ายว่าใครอยู่ทีมไหน
--
-- ⚠️ **รางวัลไม่ได้เขียนลงโปรไฟล์โดยตรง** เพราะเซิร์ฟแมตช์ไม่เคยเปิดเซสชันโปรไฟล์ของใคร (ถ้าเปิด
-- กระเป๋าจริงของคนเล่นจะถูกทับด้วยของในแมตช์ตอนเซฟ) — ฝากไว้ที่นี่ แล้วเกมหลักมารับเองตอนเข้าเกม
local DataStoreService = game:GetService("DataStoreService")
local TeleportService = game:GetService("TeleportService")

local store = DataStoreService:GetDataStore("WOLD_ArenaRegistry_v1")

local ArenaRegistry = {}

-- require ตอนใช้ ไม่ใช่ตอนโหลด — `ServerConfig` require ไฟล์นี้เองตอนบูต (เพื่อถามว่าเซิร์ฟนี้เป็นแมตช์
-- ของใคร) ถ้า require บนหัวไฟล์จะวนกัน "required recursively" เหมือนที่ `FarmRegistry` เจอมาแล้ว
local function arenaPlaceId()
	return require(game.ServerScriptService.ServerConfig).ArenaPlaceId
end

local function matchKey(privateServerId) return "arenamatch_" .. privateServerId end
local function rewardKey(userId) return "arenareward_" .. userId end

--------------------------------------------------------------------------------
-- เซิร์ฟของแมตช์
--------------------------------------------------------------------------------

-- จองเซิร์ฟใหม่หนึ่งตัวสำหรับแมตช์นี้ แล้วบันทึกว่าใครอยู่ทีมไหน → คืน accessCode
--
-- ไม่ได้ทำบน UpdateAsync ด้วยเหตุผลเดียวกับอีกสองทะเบียน: `ReserveServer` เป็นการกระทำจริงที่ย้อนไม่ได้
-- และ Roblox เรียก transform ของ UpdateAsync ซ้ำได้เองตอนเขียนชนกัน = จองเซิร์ฟทิ้งหลายตัว
-- `admin` = แอดมินกดเริ่มเอง (ไม่นับแร็งก์ · เฟส 3)
-- `parties` = { {userId…}, … } ใครมาด้วยกัน — ตอนจบสนามส่งกลับล็อบบี้เป็นก้อนตามนี้ ตี้จะได้ไม่แตก (2026-10-01)
function ArenaRegistry.CreateMatch(mapId, teams, bots, admin, parties)
	local placeId = arenaPlaceId()
	if not placeId or placeId == 0 then
		error("[ArenaRegistry] ยังไม่ได้ตั้ง ServerConfig.ArenaPlaceId", 0)
	end

	local reserveOk, accessCode, privateServerId = pcall(TeleportService.ReserveServer, TeleportService, placeId)
	if not reserveOk then
		error("[ArenaRegistry] จองเซิร์ฟแมตช์ไม่สำเร็จ: " .. tostring(accessCode), 0)
	end

	local record = {
		mapId = mapId,
		teams = teams,
		bots = bots or { A = 0, B = 0 },
		admin = admin == true or nil,
		parties = parties,
		createdAt = os.time(),
	}
	local setOk, setErr = pcall(function() store:SetAsync(matchKey(privateServerId), record) end)
	if not setOk then
		-- เซิร์ฟถูกจองไปแล้วแต่ไม่มีใครรู้ว่ามันคือแมตช์ไหน — ส่งคนเข้าไปตอนนี้คือส่งเข้าห้องที่จะเด้ง
		-- ทุกคนกลับทันที บอกให้รู้ตรงนี้ดีกว่าให้ไปตายเอาข้างหน้า
		error("[ArenaRegistry] จองเซิร์ฟได้แต่บันทึกแมตช์ไม่ได้: " .. tostring(setErr), 0)
	end
	return accessCode, privateServerId, record
end

-- เซิร์ฟแมตช์ถามตอนบูตว่า "ฉันเป็นแมตช์ไหน" — คืนบันทึก หรือ nil ถ้าไม่ใช่เซิร์ฟที่ถูกจองไว้
function ArenaRegistry.MatchOfServer(privateServerId)
	if not privateServerId or privateServerId == "" then return nil end
	local ok, data = pcall(function() return store:GetAsync(matchKey(privateServerId)) end)
	if ok and type(data) == "table" then return data end
	if not ok then warn("[ArenaRegistry] อ่านบันทึกแมตช์ไม่ได้:", data) end
	return nil
end

-- แมตช์จบแล้ว ลบบันทึกทิ้ง — ไม่ลบก็ไม่พัง (เซิร์ฟนั้นปิดไปแล้วและจะไม่มีใครถามอีก) แต่ DataStore
-- ที่โตขึ้นเรื่อยๆ โดยไม่มีใครลบคือขยะที่ค่าใช้จ่ายไม่เคยลด
function ArenaRegistry.ClearMatch(privateServerId)
	if not privateServerId or privateServerId == "" then return end
	pcall(function() store:RemoveAsync(matchKey(privateServerId)) end)
end

--------------------------------------------------------------------------------
-- รางวัลที่รอส่งกลับเกมหลัก
--------------------------------------------------------------------------------

-- ฝากรางวัลไว้ให้คนคนหนึ่ง · **UpdateAsync ตรงนี้ถูกต้อง** ต่างจากตอนจองเซิร์ฟ: มันไม่มีผลข้างเคียง
-- นอกตัวมันเอง ถูกเรียกซ้ำก็ได้ผลเท่าเดิม และมันต้องกันการเขียนทับกันจริงๆ (หกคนจบแมตช์พร้อมกัน)
local MAX_PENDING = 20 -- คนที่ไม่เข้าเกมหลักสักที ไม่ควรสะสมกองรางวัลไม่จำกัด

function ArenaRegistry.QueueReward(userId, reward)
	if not userId or type(reward) ~= "table" then return false end
	reward.at = os.time()
	local ok, err = pcall(function()
		store:UpdateAsync(rewardKey(userId), function(old)
			local list = type(old) == "table" and old or {}
			table.insert(list, reward)
			while #list > MAX_PENDING do table.remove(list, 1) end
			return list
		end)
	end)
	if not ok then warn("[ArenaRegistry] ฝากรางวัลของ", userId, "ไม่ได้:", err) end
	return ok
end

-- เกมหลักมารับ: อ่านแล้วล้างในจังหวะเดียวกัน
--
-- ⚠️ **ล้างก่อนจ่าย ไม่ใช่จ่ายก่อนล้าง** — ถ้าจ่ายแล้วล้างไม่สำเร็จ คนนั้นจะได้รางวัลซ้ำทุกครั้งที่เข้าเกม
-- (ช่องโหว่ที่ขยายตัวเอง) ส่วนทางนี้ กรณีเลวร้ายที่สุดคือรางวัลหายหนึ่งชุด ซึ่งแก้ด้วยการแจกมือได้
function ArenaRegistry.ClaimRewards(userId)
	local claimed = nil
	local ok, err = pcall(function()
		store:UpdateAsync(rewardKey(userId), function(old)
			if type(old) == "table" and #old > 0 then claimed = old end
			return {}
		end)
	end)
	if not ok then
		warn("[ArenaRegistry] รับรางวัลของ", userId, "ไม่ได้:", err)
		return nil
	end
	return claimed
end

return ArenaRegistry
