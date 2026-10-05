-- FarmRegistry.lua: เกาะฟาร์มของใครอยู่ที่เซิร์ฟไหน — ไฟล์เดียวที่แตะ DataStore/TeleportService ของโหมดฟาร์มมิ่ง
--
-- โครงเดียวกับ `ChannelRegistry` เป๊ะ ต่างแค่กุญแจ: ของเดิมคือ "ช่องที่ 3 ของโหมด Roleplay"
-- ของนี่คือ "เกาะของ userId 4871683651" — หนึ่งคนหนึ่งเซิร์ฟถาวร ไม่ใช่ห้องที่หมุนเวียน
--
--   farm_<ownerUserId>        = { accessCode, privateServerId, createdAt }
--   farmcode_<privateServerId> = { ownerUserId }   ← เซิร์ฟเกาะอ่านตอนบูตเพื่อรู้ว่าตัวเองเป็นเกาะของใคร
--   farmguests_<ownerUserId>   = { [userId] = ชื่อ } ← คนที่เจ้าของชวนไว้ (ยังไม่มีระบบชวน อ่านไว้ก่อน)
--   farminvited_<userId>       = { [ownerUserId] = ชื่อเจ้าของ } ← ดัชนีกลับ ไว้วาดแถว "เกาะที่คุณถูกชวน"
--   farmlive_<ownerUserId>     = { at }          ← หัวใจเต้นตอนเจ้าของยืนอยู่บนเกาะตัวเอง (แขกเข้าได้เฉพาะตอนนั้น)
--
-- **สองฝั่งของคำเชิญต้องเขียนคู่กันเสมอ** (guests ของเจ้าของ + invited ของแขก) ฝั่งแรกใช้ตัดสินสิทธิ์
-- ฝั่งหลังใช้วาดรายการ ถ้าเขียนแค่ฝั่งเดียว จะได้แขกที่เข้าได้แต่ไม่เห็นเกาะ หรือเห็นแต่เข้าไม่ได้
local DataStoreService = game:GetService("DataStoreService")
local TeleportService = game:GetService("TeleportService")

local store = DataStoreService:GetDataStore("WOLD_FarmRegistry_v1")

local FarmRegistry = {}

-- เพลสปลายทางของเกาะ (คนละเพลสกับเกมหลัก จักรวาลเดียวกัน) — ดู `ServerConfig.FarmingPlaceId`
-- require ตอนใช้ ไม่ใช่ตอนโหลด: ServerConfig เองก็ require ไฟล์นี้ (เพื่อ OwnerOfServer ตอนบูตเกาะ) ถ้า require บนหัวไฟล์
-- จะวนกัน "required recursively" · ฟังก์ชันนี้ถูกเรียกเฉพาะตอนล็อบบี้จองเซิร์ฟ ซึ่ง ServerConfig โหลดเสร็จไปนานแล้ว
local function farmPlaceId()
	return require(game.ServerScriptService.ServerConfig).FarmingPlaceId
end

local function farmKey(ownerUserId) return "farm_" .. ownerUserId end
local function codeKey(privateServerId) return "farmcode_" .. privateServerId end
local function guestsKey(ownerUserId) return "farmguests_" .. ownerUserId end
local function invitedKey(userId) return "farminvited_" .. userId end
local function liveKey(ownerUserId) return "farmlive_" .. ownerUserId end

--------------------------------------------------------------------------------
-- เซิร์ฟของเกาะ
--------------------------------------------------------------------------------

-- คืน accessCode ของเกาะคนนั้น สร้างครั้งแรกถ้ายังไม่มี
--
-- ไม่ได้ทำบน UpdateAsync ด้วยเหตุผลเดียวกับ ChannelRegistry: `ReserveServer` เป็นการกระทำจริงที่ย้อนไม่ได้
-- และ Roblox เรียก transform ของ UpdateAsync ซ้ำได้เองตอนชนกัน ซึ่งจะกลายเป็นการจองเซิร์ฟทิ้งหลายตัว
function FarmRegistry.GetOrCreate(ownerUserId)
	local placeId = farmPlaceId()
	if not placeId or placeId == 0 then
		error("[FarmRegistry] ยังไม่ได้ตั้ง ServerConfig.FarmingPlaceId", 0) -- locale: skip (log)
	end

	local key = farmKey(ownerUserId)
	local getOk, existing = pcall(function() return store:GetAsync(key) end)
	if not getOk then
		error("[FarmRegistry] อ่านเกาะของ " .. tostring(ownerUserId) .. " ไม่ได้: " .. tostring(existing), 0) -- locale: skip (log)
	end
	if existing and existing.accessCode then return existing.accessCode end

	local reserveOk, accessCode, privateServerId = pcall(TeleportService.ReserveServer, TeleportService, placeId)
	if not reserveOk then
		error("[FarmRegistry] จองเซิร์ฟเกาะไม่สำเร็จ: " .. tostring(accessCode), 0) -- locale: skip (log)
	end

	local setOk, setErr = pcall(function()
		store:SetAsync(key, { accessCode = accessCode, privateServerId = privateServerId, createdAt = os.time() })
	end)
	if not setOk then
		warn("[FarmRegistry] จองเซิร์ฟได้แต่บันทึกไม่ได้ (เซิร์ฟนี้จะถูกทิ้ง):", setErr)
	end
	local revOk, revErr = pcall(function()
		store:SetAsync(codeKey(privateServerId), { ownerUserId = ownerUserId })
	end)
	if not revOk then warn("[FarmRegistry] เขียนทางกลับไม่ได้:", revErr) end
	return accessCode
end

-- เกาะของคนนี้ถูกสร้างไว้แล้วหรือยัง — ใช้ตอนแขกจะเข้า **โดยไม่สร้างให้**
-- (`GetOrCreate` จะจองเซิร์ฟให้คนที่ไม่เคยซื้อ VIP ถ้าเผลอเรียกจากทางของแขก)
function FarmRegistry.Exists(ownerUserId)
	local ok, data = pcall(function() return store:GetAsync(farmKey(ownerUserId)) end)
	return ok and type(data) == "table" and data.accessCode ~= nil
end

--------------------------------------------------------------------------------
-- เจ้าของอยู่บนเกาะตัวเองหรือเปล่า
--------------------------------------------------------------------------------
--
-- **แขกเข้าได้เฉพาะตอนเจ้าของอยู่** (ผู้ใช้สั่ง 2026-09-23: "เพื่อนสามารถเข้าเชิฟเราได้")
--
-- ไม่ใช่กฎเพื่อความสวยงาม — ข้อมูลเกาะอยู่ในโปรไฟล์ของเจ้าของ ซึ่งเซิร์ฟนี้จะเขียนได้ก็ต่อเมื่อ
-- เจ้าของเปิดเซสชันอยู่ตรงนี้ (ProfileStore ล็อกเซสชัน) · ถ้าปล่อยให้แขกเข้าเกาะร้าง ของที่เขาเก็บไป
-- จะหายตอนเซิร์ฟปิด และเจ้าของจะกลับมาเจอผักที่ยังอยู่ครบ = "ขโมย" ที่ไม่มีใครเสียอะไรเลย
local LIVE_SECONDS = 150 -- หัวใจเต้นทุก 60 วิ · เผื่อพลาดสองจังหวะก่อนถือว่าออกไปแล้ว

function FarmRegistry.SetLive(ownerUserId, alive)
	pcall(function()
		if alive then
			store:SetAsync(liveKey(ownerUserId), { at = os.time() })
		else
			store:RemoveAsync(liveKey(ownerUserId))
		end
	end)
end

function FarmRegistry.IsLive(ownerUserId)
	local ok, data = pcall(function() return store:GetAsync(liveKey(ownerUserId)) end)
	if not (ok and type(data) == "table" and tonumber(data.at)) then return false end
	return os.time() - data.at < LIVE_SECONDS
end

--------------------------------------------------------------------------------
-- เซิร์ฟของเกาะ (ต่อ)
--------------------------------------------------------------------------------

-- เซิร์ฟเกาะถามว่า "ฉันเป็นเกาะของใคร" ตอนบูต — คืน ownerUserId หรือ nil
function FarmRegistry.OwnerOfServer(privateServerId)
	if not privateServerId or privateServerId == "" then return nil end
	local ok, data = pcall(function() return store:GetAsync(codeKey(privateServerId)) end)
	if ok and type(data) == "table" then return data.ownerUserId end
	if not ok then warn("[FarmRegistry] อ่านเจ้าของเซิร์ฟไม่ได้:", data) end
	return nil
end

--------------------------------------------------------------------------------
-- แขก
--------------------------------------------------------------------------------

function FarmRegistry.Guests(ownerUserId)
	local ok, data = pcall(function() return store:GetAsync(guestsKey(ownerUserId)) end)
	return (ok and type(data) == "table") and data or {}
end

-- เกาะที่คนนี้ถูกชวนไว้ -> { [ownerUserId] = ชื่อเจ้าของ }
function FarmRegistry.InvitedTo(userId)
	local ok, data = pcall(function() return store:GetAsync(invitedKey(userId)) end)
	return (ok and type(data) == "table") and data or {}
end

function FarmRegistry.IsGuest(ownerUserId, userId)
	if ownerUserId == userId then return true end
	return FarmRegistry.Guests(ownerUserId)[tostring(userId)] ~= nil
		or FarmRegistry.Guests(ownerUserId)[userId] ~= nil
end

-- ชวน/ถอนแขก — เขียนสองฝั่งเสมอ (ดูหัวไฟล์)
function FarmRegistry.SetGuest(ownerUserId, ownerName, userId, name)
	local okA = pcall(function()
		store:UpdateAsync(guestsKey(ownerUserId), function(old)
			local t = (type(old) == "table") and old or {}
			t[tostring(userId)] = name -- nil = ถอนสิทธิ์
			return t
		end)
	end)
	local okB = pcall(function()
		store:UpdateAsync(invitedKey(userId), function(old)
			local t = (type(old) == "table") and old or {}
			t[tostring(ownerUserId)] = name and ownerName or nil
			return t
		end)
	end)
	return okA and okB
end

return FarmRegistry
