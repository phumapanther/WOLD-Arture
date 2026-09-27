-- PvpRankStore: แต้มแร็งก์ PVP ใน DataStore คีย์ของตัวเอง (เฟส 3 · roadmap: ผู้ใช้เลือก — ไม่ฝากในโปรไฟล์)
--
-- **ทำไมไม่อยู่ในโปรไฟล์:** ข้อความเข้าโปรไฟล์ถูกรับตอนเปิดเซสชันในเกมหลัก/เกาะเท่านั้น แต่ **ล็อบบี้ไม่เคยเปิดเซสชัน**
-- และล็อบบี้คือที่ที่ต้องฉลองเลื่อนขั้นทันทีที่กลับจากแมตช์ · คีย์แยกอ่านได้จากทุกเพลส
--
-- เขียน: เซิร์ฟสนามตอนจบแมตช์ (`RecordMatch` · UpdateAsync · ตัดซ้ำด้วยรหัสแมตช์) · ล็อบบี้ (`MarkSeen` หลังฉลอง)
-- อ่าน: ล็อบบี้ (ฉลอง + บรรทัดในหน้าปาร์ตี้) · เกมหลัก/เกาะ (ฉายา + กรอบการ์ด) · ลดขั้นจบซีซันคิดตอนอ่าน/เขียน (`Normalize`)
-- ไม่ต้องไล่เขียนทุกคนตอนเปลี่ยนซีซัน
local DataStoreService = game:GetService("DataStoreService")
local PvpRankConfig = require(game.ReplicatedStorage.PvpRankConfig)

local PvpRankStore = {}

local STORE_NAME = "WOLD_PvpRank_v1"
local store = nil
local function storeOf()
	if not store then
		local ok, s = pcall(function() return DataStoreService:GetDataStore(STORE_NAME) end)
		if ok then store = s end
	end
	return store
end

local function keyOf(userId) return "u_" .. tostring(userId) end

-- บันทึกของคนนี้ (ปรับเป็นซีซันปัจจุบันแล้ว) · nil = อ่านไม่ได้ (DataStore ล่ม/Studio ไม่เปิดสิทธิ์)
function PvpRankStore.Read(userId)
	local s = storeOf()
	if not s then return nil end
	local ok, data = pcall(function() return s:GetAsync(keyOf(userId)) end)
	if not ok then return nil end
	return PvpRankConfig.Normalize(data, PvpRankConfig.Season(os.time()))
end

local function update(userId, fn)
	local s = storeOf()
	if not s then return false end
	for attempt = 1, 3 do
		local ok = pcall(function()
			s:UpdateAsync(keyOf(userId), function(old)
				return fn(PvpRankConfig.Normalize(old, PvpRankConfig.Season(os.time())))
			end)
		end)
		if ok then return true end
		task.wait(attempt)
	end
	return false
end

-- นับแมตช์หนึ่ง (+25 / −18) · แมตช์เดิมเขียนซ้ำ = ไม่นับซ้ำ
function PvpRankStore.RecordMatch(userId, matchId, delta)
	return update(userId, function(r)
		local record = PvpRankConfig.Apply(r, PvpRankConfig.Season(os.time()), matchId, delta)
		return record
	end)
end

-- ฉลองเลื่อนขั้นให้ดูแล้ว — จดขั้นที่เห็น (ไม่ฉลองซ้ำตอนเข้าล็อบบี้ครั้งหน้า)
function PvpRankStore.MarkSeen(userId, tierIndex)
	return update(userId, function(r)
		r.seen = math.max(r.seen or 1, math.min(tonumber(tierIndex) or 1, PvpRankConfig.TierIndex(r.p)))
		return r
	end)
end

return PvpRankStore
