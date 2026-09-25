-- AchievementConfig: ความสำเร็จ + ฉายา (สเปก docs/superpowers/specs/2026-09-25-achievements-design.md)
--
-- ผู้ใช้กำหนดโครง (2026-09-25): อยู่ในสมุดสะสม · ฉายาเรืองแสงเหนือหัว เลือกเองจากที่ปลดแล้ว · VIP ได้ฉายา "VIP" ทอง ·
-- หัวแดงขึ้นฉายา "หัวแดง" เองจนหมดเวลา · นับจากมอน/ปลา · เลเวล/ตีบวก · PVP/บอสโลก · ปลดแล้วได้ฉายา + เพชร
-- **ชื่อฉายา เป้า และเพชร ผมตั้งเอง** แก้ที่นี่ที่เดียว
local AchievementConfig = {}

-- สีตามความยาก — ใช้ทั้งหน้าจอและป้ายเหนือหัว
AchievementConfig.Tiers = {
	common = Color3.fromRGB(140, 205, 255),
	rare = Color3.fromRGB(196, 140, 255),
	legend = Color3.fromRGB(255, 205, 80),
}

-- สถิติที่ความสำเร็จอ่านได้ · `live` = อ่านสดจากระบบเดิม ไม่เก็บซ้ำ · ที่เหลือจดใน profile.Data.Achievements.stats
AchievementConfig.Stats = {
	mobKills = { live = true, label = "ฆ่ามอนรวม" },
	mobKinds = { live = true, label = "ชนิดมอนที่ฆ่า" },
	fishTotal = { live = true, label = "ตกปลารวม" },
	fishKinds = { live = true, label = "ชนิดปลาที่ตก" },
	level = { live = true, label = "เลเวล" },
	maxEnhance = { label = "ตีบวกสูงสุด" },
	pvpWins = { label = "ชนะสนาม PVP" },
	pvpAces = { label = "ACE" },
	pvpKills = { label = "คิลในสนาม" },
	bossJoins = { label = "ติดอันดับบอสโลก" },
	bossTop1 = { label = "อันดับ 1 บอสโลก" },
	bossLastHits = { label = "ไม้สุดท้ายบอสโลก" },
}

AchievementConfig.List = {
	{ id = "mobs100", title = "นักล่ามือใหม่", desc = "ฆ่ามอนรวม 100 ตัว", stat = "mobKills", goal = 100, gems = 10, tier = "common" },
	{ id = "mobs1000", title = "นักล่า", desc = "ฆ่ามอนรวม 1,000 ตัว", stat = "mobKills", goal = 1000, gems = 30, tier = "rare" },
	{ id = "mobs10000", title = "เพชฌฆาตแห่งอาร์ทัวร์", desc = "ฆ่ามอนรวม 10,000 ตัว", stat = "mobKills", goal = 10000, gems = 100, tier = "legend" },
	{ id = "mobKinds10", title = "ผู้รู้จักสัตว์ประหลาด", desc = "ฆ่ามอนครบ 10 ชนิด", stat = "mobKinds", goal = 10, gems = 30, tier = "rare" },
	{ id = "fish50", title = "ชาวประมง", desc = "ตกปลารวม 50 ตัว", stat = "fishTotal", goal = 50, gems = 10, tier = "common" },
	{ id = "fish500", title = "เจ้าแห่งคันเบ็ด", desc = "ตกปลารวม 500 ตัว", stat = "fishTotal", goal = 500, gems = 30, tier = "rare" },
	{ id = "fishKinds10", title = "นักสะสมปลา", desc = "ตกปลาครบ 10 ชนิด", stat = "fishKinds", goal = 10, gems = 30, tier = "rare" },
	{ id = "level10", title = "นักผจญภัย", desc = "เลเวล 10", stat = "level", goal = 10, gems = 10, tier = "common" },
	{ id = "level30", title = "ผู้กล้า", desc = "เลเวล 30", stat = "level", goal = 30, gems = 30, tier = "common" },
	{ id = "level50", title = "วีรชน", desc = "เลเวล 50", stat = "level", goal = 50, gems = 50, tier = "rare" },
	{ id = "level100", title = "ตำนาน", desc = "เลเวล 100", stat = "level", goal = 100, gems = 150, tier = "legend" },
	{ id = "enhance5", title = "ช่างฝีมือ", desc = "ตีบวกอาวุธสำเร็จถึง +5", stat = "maxEnhance", goal = 5, gems = 20, tier = "rare" },
	{ id = "enhance10", title = "เทพแห่งเตาหลอม", desc = "ตีบวกอาวุธสำเร็จถึง +10", stat = "maxEnhance", goal = 10, gems = 150, tier = "legend" },
	{ id = "pvpWin1", title = "นักสู้สนาม", desc = "ชนะแมตช์ PVP 1 ครั้ง", stat = "pvpWins", goal = 1, gems = 10, tier = "common" },
	{ id = "pvpWin10", title = "แชมป์สนาม", desc = "ชนะแมตช์ PVP 10 ครั้ง", stat = "pvpWins", goal = 10, gems = 50, tier = "legend" },
	{ id = "pvpAce", title = "เอซ", desc = "ทำ ACE ในสนาม PVP", stat = "pvpAces", goal = 1, gems = 50, tier = "legend" },
	{ id = "pvpKills100", title = "นักฆ่าสนาม", desc = "คิลในสนาม PVP รวม 100", stat = "pvpKills", goal = 100, gems = 50, tier = "rare" },
	{ id = "boss1", title = "ผู้ท้าบอส", desc = "ติดอันดับรางวัลบอสโลก", stat = "bossJoins", goal = 1, gems = 20, tier = "common" },
	{ id = "bossTop1", title = "ผู้โค่นยักษ์", desc = "ดาเมจอันดับ 1 บอสโลก", stat = "bossTop1", goal = 1, gems = 100, tier = "legend" },
	{ id = "bossLastHit", title = "ดาบสุดท้าย", desc = "ฟันไม้สุดท้ายที่ฆ่าบอสโลก", stat = "bossLastHits", goal = 1, gems = 50, tier = "legend" },
}

-- ฉายาที่ไม่ได้มาจากการปลด (ไม่อยู่ใน List จึงไม่มีเพชร)
AchievementConfig.Special = {
	-- VIP: เลือกใช้ได้ตลอดที่ VIP ยังไม่หมด (ผู้ใช้เลือก)
	vip = { id = "vip", title = "VIP", color = Color3.fromRGB(255, 215, 60) },
	-- หัวแดง: ขึ้นเองตอนติดสถานะ ถอดไม่ได้จนหมดเวลา (ผู้ใช้สั่ง) — ชนะทุกฉายา
	marked = { id = "marked", title = "หัวแดง", color = Color3.fromRGB(235, 55, 55) },
}

local ById = {}
for _, def in ipairs(AchievementConfig.List) do ById[def.id] = def end

function AchievementConfig.Get(id)
	return ById[id]
end

-- ครบเป้าหรือยัง · ค่าแปลก (nil/NaN) = ยัง
function AchievementConfig.IsDone(def, value)
	if type(def) ~= "table" or type(value) ~= "number" or value ~= value then return false end
	return value >= def.goal
end

-- สีของฉายา id (ความสำเร็จหรือพิเศษ)
function AchievementConfig.ColorOf(id)
	local def = ById[id]
	if def then return AchievementConfig.Tiers[def.tier] end
	for _, special in pairs(AchievementConfig.Special) do
		if special.id == id then return special.color end
	end
	return AchievementConfig.Tiers.common
end

return AchievementConfig
