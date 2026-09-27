-- Achievements: ความสำเร็จ + ฉายา — อ่านสถิติ จด ปลด และตัดสินว่าหัวใครขึ้นฉายาอะไร
-- (สเปก docs/superpowers/specs/2026-09-25-achievements-design.md · ตัวเลขทั้งหมดใน AchievementConfig)
--
-- เก็บใน profile.Data.Achievements = { stats = {...}, unlocked = { [id] = เวลา }, title = id|nil, seen = { id,... } }
-- · สถิติ `live` (มอน/ปลา/เลเวล) อ่านสดจากระบบเดิม ไม่เก็บซ้ำ — ความจริงชุดเดียว
-- · ที่เหลือจดที่นี่: ตีบวก (Crafting เรียก Record) · PVP/บอสโลก มาทางข้อความ `kind = "stats"` (AddStatsData)
--
-- โมดูลนี้ require แค่ของเบา (ไม่มี Progression/Inventory) เพราะ PlayerProfile ก็ require มัน
local ProfileAccess = require(script.Parent.ProfileAccess)
local PremiumAccess = require(script.Parent.PremiumAccess)
local Vip = require(script.Parent.Vip)
local Classes = require(script.Parent.Classes)
local AchievementConfig = require(game.ReplicatedStorage.AchievementConfig)
local PvpRankConfig = require(game.ReplicatedStorage.PvpRankConfig)
local StoryConfig = require(game.ReplicatedStorage.StoryConfig)

local Achievements = {}

local SEEN_KEEP = 20 -- จำ id ข้อความสถิติไว้กี่ตัว (ProfileStore ส่งซ้ำได้ถ้าเซิร์ฟล่มก่อนเซฟ)

local function bookOf(data)
	if type(data) ~= "table" then return nil end
	local book = data.Achievements
	if type(book) ~= "table" then
		book = {}
		data.Achievements = book
	end
	if type(book.stats) ~= "table" then book.stats = {} end
	if type(book.unlocked) ~= "table" then book.unlocked = {} end
	if type(book.seen) ~= "table" then book.seen = {} end
	return book
end

-- ค่าของสถิติหนึ่งตัว ณ ตอนนี้
function Achievements.StatValue(player, data, stat)
	local book = bookOf(data)
	if not book then return 0 end
	local collection = type(data.Collection) == "table" and data.Collection or {}
	if stat == "mobKills" or stat == "mobKinds" then
		local total, kinds = 0, 0
		for _, n in pairs(type(collection.Mobs) == "table" and collection.Mobs or {}) do
			total += tonumber(n) or 0
			kinds += 1
		end
		return stat == "mobKills" and total or kinds
	elseif stat == "fishTotal" or stat == "fishKinds" then
		local total, kinds = 0, 0
		for _, entry in pairs(type(collection.Fish) == "table" and collection.Fish or {}) do
			total += type(entry) == "table" and (tonumber(entry.n) or 0) or 0
			kinds += 1
		end
		return stat == "fishTotal" and total or kinds
	elseif stat == "level" then
		return tonumber(player and player:GetAttribute("WOLD_Level")) or 0
	end
	return tonumber(book.stats[stat]) or 0
end

-- จดสถิติของคนที่อยู่ในเซิร์ฟนี้ · mode "max" = เก็บค่าสูงสุด (ตีบวก) · อื่นๆ = บวกเพิ่ม
function Achievements.Record(player, stat, value, mode)
	local book = bookOf(ProfileAccess.Get(player))
	if not book or type(value) ~= "number" or value ~= value then return end
	local current = tonumber(book.stats[stat]) or 0
	book.stats[stat] = (mode == "max") and math.max(current, value) or current + value
end

-- ตัวรับข้อความ `kind = "stats"` (PlayerProfile · ทั้งตอนออนไลน์และที่ฝากไว้ตอนออฟไลน์)
-- message = { id, stats = { [stat] = จำนวนที่บวกเพิ่ม } } · id ซ้ำ = เคยนับแล้ว ข้าม
function Achievements.AddStatsData(data, message)
	local book = bookOf(data)
	if not book or type(message) ~= "table" or type(message.stats) ~= "table" then return end
	if type(message.id) == "string" then
		for _, seen in ipairs(book.seen) do
			if seen == message.id then return end
		end
		table.insert(book.seen, message.id)
		while #book.seen > SEEN_KEEP do table.remove(book.seen, 1) end
	end
	for stat, add in pairs(message.stats) do
		local def = AchievementConfig.Stats[stat]
		add = tonumber(add)
		if def and not def.live and add and add == add and add > 0 then
			book.stats[stat] = (tonumber(book.stats[stat]) or 0) + math.floor(add)
		end
	end
end

-- ปลดทุกอันที่ครบเป้าแล้วแต่ยังไม่ปลด · ให้เพชร · คืนรายการที่เพิ่งปลด
function Achievements.Check(player)
	local data = ProfileAccess.Get(player)
	local book = bookOf(data)
	if not book then return {} end
	local fresh = {}
	for _, def in ipairs(AchievementConfig.List) do
		if not book.unlocked[def.id] and AchievementConfig.IsDone(def, Achievements.StatValue(player, data, def.stat)) then
			book.unlocked[def.id] = os.time()
			if PremiumAccess.AddGems then PremiumAccess.AddGems(player, def.gems) end
			table.insert(fresh, def)
		end
	end
	return fresh
end

-- **ฉายาแร็งก์ PVP** (เฟส 3) id = "pvprank_<ขั้น>" · เลือกได้เฉพาะขั้นปัจจุบัน (แอตทริบิวต์ WOLD_PvpTier จาก PvpRankPublisher)
-- แร็งก์เปลี่ยน = ฉายาที่เลือกไว้ใช้ไม่ได้แล้ว หายจากหัว ต้องเลือกขั้นใหม่เอง (roadmap: "หายเมื่อแร็งก์เปลี่ยน")
local function rankTitleOf(player)
	local tierIndex = player:GetAttribute("WOLD_PvpTier")
	if type(tierIndex) ~= "number" then return nil end
	local tier = PvpRankConfig.Tier(tierIndex)
	return { id = "pvprank_" .. tier.id, title = "แร็งก์" .. tier.name, color = tier.color }
end

-- **ฉายาเมือง** (เนื้อเรื่อง) id = "story_<บท>" · ได้ถาวรเมื่อจบบท (`profile.Data.Story.titles` — Story.server เขียน)
local function storyTitlesOf(player)
	local data = ProfileAccess.Get(player)
	local owned = data and type(data.Story) == "table" and type(data.Story.titles) == "table" and data.Story.titles or {}
	local list = {}
	for _, ch in ipairs(StoryConfig.Chapters) do
		if ch.title and owned[ch.title.id] then
			list[#list + 1] = { id = ch.title.id, title = ch.title.text, color = ch.title.color, note = "ฉายาเมือง · จบบท " .. ch.name }
		end
	end
	return list
end

-- ฉายาที่คนนี้เลือกใช้ได้ตอนนี้ไหม
function Achievements.CanUse(player, id)
	if id == AchievementConfig.Special.vip.id then return Vip.Has(player) end
	if type(id) == "string" and id:sub(1, 6) == "story_" then
		for _, t in ipairs(storyTitlesOf(player)) do
			if t.id == id then return true end
		end
		return false
	end
	if type(id) == "string" and id:sub(1, 8) == "pvprank_" then
		local rank = rankTitleOf(player)
		return rank ~= nil and rank.id == id
	end
	local book = bookOf(ProfileAccess.Get(player))
	return book ~= nil and AchievementConfig.Get(id) ~= nil and book.unlocked[id] ~= nil
end

-- เลือกฉายา ("" / nil = ไม่ใช้) · คืน true ถ้ารับ
function Achievements.SetTitle(player, id)
	local book = bookOf(ProfileAccess.Get(player))
	if not book then return false end
	if id == nil or id == "" then
		book.title = nil
		return true
	end
	if type(id) ~= "string" or not Achievements.CanUse(player, id) then return false end
	book.title = id
	return true
end

-- ฉายาที่ขึ้นบนหัวตอนนี้: **หัวแดงชนะเสมอ** (ถอดไม่ได้จนหมด) → ฉายาที่เลือกถ้ายังใช้ได้ (VIP หมด = หาย) → ไม่มี
-- คืน text, color หรือ nil
function Achievements.DisplayTitle(player)
	if Classes.IsMarked(player) then
		local marked = AchievementConfig.Special.marked
		return marked.title, marked.color
	end
	local book = bookOf(ProfileAccess.Get(player))
	local id = book and book.title
	if not id or not Achievements.CanUse(player, id) then return nil end
	local rank = rankTitleOf(player)
	if rank and rank.id == id then return rank.title, rank.color end
	local story = StoryConfig.Title(id)
	if story then return story.text, story.color end
	local def = AchievementConfig.Get(id)
	local title = def and def.title or AchievementConfig.Special.vip.title
	return title, AchievementConfig.ColorOf(id)
end

-- ภาพสำหรับแท็บ "ความสำเร็จ" ในสมุดสะสม
function Achievements.Snapshot(player)
	local data = ProfileAccess.Get(player)
	local book = bookOf(data)
	if not book then return nil end
	local rows = {}
	for order, def in ipairs(AchievementConfig.List) do
		local value = Achievements.StatValue(player, data, def.stat)
		rows[order] = {
			id = def.id, title = def.title, desc = def.desc, gems = def.gems,
			progress = math.min(value, def.goal), goal = def.goal,
			unlocked = book.unlocked[def.id] ~= nil,
			color = AchievementConfig.Tiers[def.tier],
		}
	end
	local vip = AchievementConfig.Special.vip
	return {
		rows = rows,
		equipped = book.title,
		marked = Classes.IsMarked(player),
		vip = Vip.Has(player) and { id = vip.id, title = vip.title, color = vip.color } or nil,
		-- ฉายาพิเศษอื่นที่เลือกได้ตอนนี้ (แร็งก์ PVP · ฉายาเมืองในอนาคต) — หน้าจอวาดเป็นแถวแบบเดียวกับ VIP
		extras = (function()
			local list = {}
			local rank = rankTitleOf(player)
			if rank then list[#list + 1] = { id = rank.id, title = rank.title, color = rank.color, note = "ฉายาแร็งก์ PVP (ตามขั้นตอนนี้)" } end
			for _, t in ipairs(storyTitlesOf(player)) do list[#list + 1] = t end
			return list
		end)(),
	}
end

return Achievements
