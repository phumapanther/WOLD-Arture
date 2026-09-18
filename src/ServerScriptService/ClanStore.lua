-- ClanStore: ใครอยู่แคลนไหน แคลนมีอะไรบ้าง และเก็บมันไว้ข้ามเซิร์ฟเวอร์
--
-- **แคลนเป็นของทั้งเกม ไม่ใช่ของเซิร์ฟเวอร์** คนในแคลนเดียวกันอาจอยู่คนละช่อง และเมืองที่ยึดได้ต้อง
-- ยังเป็นของแคลนนั้นแม้เซิร์ฟเวอร์ที่ยึดจะปิดไปแล้ว — จึงต้องอยู่ใน DataStore ไม่ใช่ในหน่วยความจำ
--
-- รูปข้อมูล:
--   clans/<id> = { id, name, blurb, image, leader, created, silver, vault, members = { [userId] = role },
--                  names = { [userId] = ชื่อที่เห็น }, towns = { [townId] = true } }
--   index      = { [clanId] = true }   -- รายชื่อแคลนทั้งหมด ใช้วาดหน้ารายการ
--
-- **แยก index ออกจากตัวแคลน** เพราะหน้ารายการต้องอ่านทุกแคลน ถ้าเก็บรวมไว้ก้อนเดียวทุกการบริจาค
-- จะเขียนทับทั้งก้อน ซึ่งเป็นการแข่งกันเขียนระหว่างเซิร์ฟเวอร์ที่จะทำให้ข้อมูลหาย
local DataStoreService = game:GetService("DataStoreService")
local ClanConfig = require(game.ReplicatedStorage.ClanConfig)

local ClanStore = {}

local STORE_NAME = "WOLD_Clans_v1"
local INDEX_KEY = "index"

local store
local ok = pcall(function() store = DataStoreService:GetDataStore(STORE_NAME) end)
if not ok then store = nil end

-- แคลนที่อ่านมาแล้วในเซิร์ฟเวอร์นี้ ลดการอ่านซ้ำ
local Cache = {}
local IndexCache = nil

--------------------------------------------------------------------------------
-- อ่าน / เขียน
--------------------------------------------------------------------------------

local function clanKey(id)
	return "clan_" .. id
end

function ClanStore.Get(clanId, fresh)
	if not clanId then return nil end
	if not fresh and Cache[clanId] then return Cache[clanId] end
	if not store then return Cache[clanId] end
	local success, data = pcall(function() return store:GetAsync(clanKey(clanId)) end)
	if success and type(data) == "table" then
		Cache[clanId] = data
		return data
	end
	if not success then warn("[ClanStore] อ่านแคลนไม่ได้:", data) end
	return Cache[clanId]
end

-- เขียนทับทั้งแคลน ใช้กับการเปลี่ยนที่ไม่แข่งกัน (เปลี่ยนรายละเอียด รับสมาชิก)
function ClanStore.Save(clan)
	if not clan or not clan.id then return false end
	Cache[clan.id] = clan
	if not store then return false, "DataStore ใช้ไม่ได้" end
	local success, err = pcall(function() store:SetAsync(clanKey(clan.id), clan) end)
	if not success then
		warn("[ClanStore] เขียนแคลนไม่ได้:", err)
		return false, "บันทึกไม่สำเร็จ"
	end
	return true
end

-- แก้แบบปลอดภัยจากการแข่งกันเขียน
--
-- **ต้องใช้กับเงินและคลังเสมอ** สองเซิร์ฟเวอร์ที่บริจาคพร้อมกันด้วย SetAsync จะเขียนทับกัน แล้วเงิน
-- ของฝั่งหนึ่งหายไปเงียบๆ UpdateAsync อ่าน-แก้-เขียนเป็นก้อนเดียวจึงไม่มีช่องให้หาย
function ClanStore.Update(clanId, transform)
	if not store then
		-- ไม่มี DataStore ก็ยังทำงานต่อได้ในเซิร์ฟเวอร์นี้ แค่ไม่ถาวร
		local clan = Cache[clanId]
		if clan then
			local changed = transform(clan)
			if changed then Cache[clanId] = changed end
			return changed or clan
		end
		return nil
	end
	local success, result = pcall(function()
		return store:UpdateAsync(clanKey(clanId), function(old)
			return transform(old)
		end)
	end)
	if not success then
		warn("[ClanStore] แก้แคลนไม่ได้:", result)
		return nil
	end
	if type(result) == "table" then Cache[clanId] = result end
	return result
end

--------------------------------------------------------------------------------
-- รายชื่อแคลนทั้งหมด
--------------------------------------------------------------------------------

function ClanStore.Index(fresh)
	if IndexCache and not fresh then return IndexCache end
	if not store then
		IndexCache = IndexCache or {}
		return IndexCache
	end
	local success, data = pcall(function() return store:GetAsync(INDEX_KEY) end)
	IndexCache = (success and type(data) == "table") and data or {}
	return IndexCache
end

local function addToIndex(clanId, name)
	if not store then
		IndexCache = IndexCache or {}
		IndexCache[clanId] = name
		return
	end
	pcall(function()
		store:UpdateAsync(INDEX_KEY, function(old)
			old = (type(old) == "table") and old or {}
			old[clanId] = name
			return old
		end)
	end)
	IndexCache = nil -- บังคับอ่านใหม่รอบหน้า
end

-- ลบแคลนทิ้ง (ยุบ) ทั้งตัวแคลนและชื่อในดัชนี
function ClanStore.Delete(clanId)
	Cache[clanId] = nil
	if not store then
		if IndexCache then IndexCache[clanId] = nil end
		return true
	end
	local ok = pcall(function() store:RemoveAsync(clanKey(clanId)) end)
	if not ok then return false end
	pcall(function()
		store:UpdateAsync(INDEX_KEY, function(old)
			old = (type(old) == "table") and old or {}
			old[clanId] = nil
			return old
		end)
	end)
	IndexCache = nil
	return true
end

--------------------------------------------------------------------------------
-- เมืองที่ถูกยึด
--------------------------------------------------------------------------------

-- towns = { [townId] = { clanId, clanName, since = os.time() } }
--
-- **คีย์เดียวทั้งเกม แยกจากตัวแคลน** เพราะคำถาม "เมืองนี้ใครถือ ยึดได้หรือยัง" ถูกถามจากทุกเซิร์ฟเวอร์
-- ทุกครึ่งนาที — อ่านคีย์เดียวถูกกว่าไล่อ่านทุกแคลน และที่สำคัญกว่า: การตัดสินคูลดาวน์ทำใน
-- UpdateAsync ของคีย์นี้ สองเซิร์ฟเวอร์ที่ยึดเมืองเดียวกันพร้อมกันจึงมีผู้ชนะคนเดียว ส่วน clan.towns
-- ยังเขียนไว้ให้หน้าแคลนโชว์ แต่ไม่ใช่ตัวตัดสินอีกต่อไป
local TOWNS_KEY = "towns"
local TownsCache = {}

function ClanStore.GetTowns(fresh)
	if not fresh or not store then return TownsCache end
	local success, data = pcall(function() return store:GetAsync(TOWNS_KEY) end)
	if success and type(data) == "table" then TownsCache = data end
	return TownsCache
end

-- transform(towns) -> towns ที่แก้แล้ว หรือ nil = ไม่เปลี่ยน คืน towns ล่าสุด
function ClanStore.UpdateTowns(transform)
	if not store then
		local changed = transform(TownsCache)
		if changed then TownsCache = changed end
		return TownsCache
	end
	local success, result = pcall(function()
		return store:UpdateAsync(TOWNS_KEY, function(old)
			return transform((type(old) == "table") and old or {})
		end)
	end)
	if not success then
		warn("[ClanStore] แก้เมืองไม่ได้:", result)
		return nil
	end
	if type(result) == "table" then TownsCache = result end
	return TownsCache
end

--------------------------------------------------------------------------------
-- สร้างแคลน
--------------------------------------------------------------------------------

-- id สร้างจากชื่อ ไม่ใช่ตัวเลขวิ่ง
--
-- **ทำให้ชื่อซ้ำกันไม่ได้โดยอัตโนมัติ** สองแคลนชื่อเดียวกันจะชนกันที่คีย์เดียวกัน UpdateAsync จึงเห็น
-- ว่ามีอยู่แล้วและปฏิเสธ — ไม่ต้องมีตารางเช็คชื่อซ้ำแยกอีกชุดที่อาจไม่ตรงกับความจริง
local function idFor(name)
	local clean = name:lower():gsub("[^%w\128-\255]", "")
	return clean ~= "" and clean or ("clan" .. tostring(os.time()))
end

-- คืน clan, errorMessage
function ClanStore.Create(name, blurb, leaderId, leaderName)
	name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if #name < ClanConfig.NameMinLength then
		return nil, ("ชื่อแคลนสั้นเกินไป (อย่างน้อย %d ตัว)"):format(ClanConfig.NameMinLength)
	end
	if #name > ClanConfig.NameMaxLength then
		return nil, ("ชื่อแคลนยาวเกินไป (ไม่เกิน %d ตัว)"):format(ClanConfig.NameMaxLength)
	end

	local id = idFor(name)
	local created = nil
	local taken = false

	local result = ClanStore.Update(id, function(old)
		if old then
			taken = true
			return nil -- ไม่เขียนทับของเดิม
		end
		created = {
			id = id,
			name = name,
			blurb = tostring(blurb or ""):sub(1, ClanConfig.BlurbMaxLength),
			-- รูปแคลนกับเสื้อแคลน: วางโครงไว้ก่อนตามที่ผู้ใช้สั่ง ยังไม่มีระบบอัปโหลด
			image = "",
			shirt = "",
			leader = leaderId,
			created = os.time(),
			silver = 0,
			vault = {},
			members = { [tostring(leaderId)] = "leader" },
			names = { [tostring(leaderId)] = leaderName },
			towns = {},
		}
		return created
	end)

	if taken then return nil, "มีแคลนชื่อนี้อยู่แล้ว" end
	if not result and not created then return nil, "สร้างแคลนไม่สำเร็จ" end

	local clan = result or created
	addToIndex(id, name)
	return clan, nil
end

--------------------------------------------------------------------------------
-- สมาชิก
--------------------------------------------------------------------------------

function ClanStore.MemberCount(clan)
	local n = 0
	for _ in pairs(clan.members or {}) do n += 1 end
	return n
end

function ClanStore.RoleOf(clan, userId)
	return clan and clan.members and clan.members[tostring(userId)] or nil
end

return ClanStore
