-- FarmLevelConfig (เฟส 2c ผู้ใช้อนุมัติร่าง 2026-09-27): เลเวลฟาร์มบนเกาะ
--
-- สามเรื่อง: **เส้น EXP** · **ของที่ไม่ใช่ไอเทมที่ปลดตามเลเวล** (แสงสามสี ขอบทอง เพดานบ้าน รถส่งออก) ·
-- **ตารางปลดรวม** สำหรับหน้าจอ ซึ่งประกอบจากคอนฟิกของแต่ละเรื่อง — ของแต่ละชิ้นประกาศเลเวลที่คอนฟิกของมันเอง
-- (`ShopConfig.IslandSells[i].level` · `IslandConfig.PenAnimals/Crops/MineRocks[i].level` · สูตร `CraftConfig`)
-- จึงไม่มีตารางที่สองให้ลืมอัปเดต
--
-- ข้อมูลล้วน อ่านได้ทั้งสองฝั่ง (หน้าต่างรถวาดตารางปลดเองจากไฟล์นี้) · require แต่ของที่เป็นข้อมูลล้วนด้วยกัน
-- **ห้ามให้ไฟล์ไหนที่ไฟล์นี้ require กลับมา require ไฟล์นี้** — ทั้งคู่จะโหลดไม่ขึ้น
local ShopConfig = require(script.Parent.ShopConfig)
local IslandConfig = require(script.Parent.IslandConfig)
local CraftConfig = require(script.Parent.CraftConfig)
local ItemCatalog = require(script.Parent.ItemCatalog)

local FarmLevelConfig = {}

--------------------------------------------------------------------------------
-- เส้น EXP — EXP ได้จากการส่งออกอย่างเดียว ไม่มีวันลด ไม่มีเพดาน
--------------------------------------------------------------------------------

-- EXP ที่ต้องใช้ "จากเลเวลนี้ไปเลเวลถัดไป" · **ตาราง 50 เลเวล (ผู้ใช้อนุมัติ 2026-09-27: "Lv50 ประมาณ 4-6 เดือน
-- และช่วงแรกๆ ต้องง่ายเข้าไว้")**
--
-- ตั้งจาก **จำนวนใบสั่งที่ต้องส่งต่อเลเวล** × EXP เฉลี่ยต่อใบของเลเวลนั้น (วัดจาก ExportOrders จริง 5,000 ใบต่อเลเวล
-- ทำให้ไม่ลดลงด้วย running max):
--   ใบ/เลเวล  Lv1-19: เท่าเลขเลเวล (Lv2 หลังใบแรก · Lv5 ~10 ใบ · Lv10 ~45 ใบ)  ·  Lv20-49: 20 → 46 (+0.9 ต่อเลเวล)
--   รวมถึง Lv50 ≈ 1,180 ใบ = วันละ 8 ใบ ~5 เดือน · วันละ 10 ใบ ~4 เดือน · วันละ 6-7 ใบ ~6 เดือน
-- เปลี่ยนสูตรใบสั่ง (ExportOrders/ExportConfig) เมื่อไหร่ต้องวัด EXP เฉลี่ยใหม่แล้วแก้ตารางนี้ตาม (เทส farm_level_test จับ)
FarmLevelConfig.ExpTable = {
	60, 160, 330, 520, -- Lv1-4: ใบเดียว/สองใบก็ขึ้น
	700, 920, 1350, 1700, 2150, -- Lv5-9
	2600, 3000, 3500, 3950, 4500, 5150, 5800, 6250, 6950, 7650, -- Lv10-19
	8500, 9150, 9550, 9900, 10400, 10900, 11450, 12250, 12650, 13400, -- Lv20-29
	13800, 14250, 15150, 15800, 16550, 17150, 18300, 19700, 20450, 20950, -- Lv30-39
	21450, 22000, 23650, 24200, 25000, 25550, 26100, 26650, 27750, 28300, -- Lv40-49 → 50
}
-- เลยตารางไปแล้ว เลเวลละ +2,000 จากตัวสุดท้าย
FarmLevelConfig.ExpStepAfter = 2000

function FarmLevelConfig.ExpToNext(level)
	local t = FarmLevelConfig.ExpTable
	level = math.max(1, math.floor(level))
	if level <= #t then return t[level] end
	return t[#t] + (level - #t) * FarmLevelConfig.ExpStepAfter
end

-- **เพดานเลเวล = 50** (ผู้ใช้สั่ง 2026-09-27: "ปรับไปตันสักเลเวล 50 ... กระจายของปลด 3-6 อย่างต่อเลเวล") ·
-- เดิมตันที่ 19 · ปลดเพิ่มวันหน้า = ขยับเลขนี้ + ต่อ ExpTable (เลยตารางไปใช้ ExpStepAfter)
FarmLevelConfig.MaxLevel = 50
-- EXP ที่ได้ตอนตันแล้ว · true = สะสมไว้ (วันปลดเพดาน ขึ้นเลเวลตามที่สะสมทันที) · false = หยุดนับที่เส้นเลเวลสูงสุด
FarmLevelConfig.BankExpAtMax = false
-- **เปิดถึงเลเวลนี้ไปก่อน** (ผู้ใช้สั่ง 2026-09-28: "ทำให้ตันตอนเวล 20 ไปก่อน แต่ทุกอย่างเหมือนเดิม แค่เวลเกิน 20 ยังไม่ได้")
-- ตาราง EXP/ของปลดทั้ง 50 เลเวลอยู่ครบและหน้าจอยังโชว์ (เลเวลที่เกินขึ้น "ยังไม่เปิด") · เปิดเพิ่ม = ขยับเลขนี้ (ไม่เกิน MaxLevel)
-- ⚠️ ถาม "ตันแล้วไหม / เลเวลจาก EXP" ผ่าน IsMax/LevelFromExp/AddExp เท่านั้น (ใช้เพดานนี้ให้เอง) · ใครมี EXP เกินเส้นอยู่แล้ว
-- (แอดมินที่เทส) EXP ไม่หาย แค่นับเลเวลได้ถึงเพดาน
FarmLevelConfig.OpenLevel = 20

function FarmLevelConfig.Ceiling()
	return math.min(FarmLevelConfig.MaxLevel, FarmLevelConfig.OpenLevel or FarmLevelConfig.MaxLevel)
end

-- EXP สะสมที่ต้องใช้ถึงเลเวลนี้ (Lv1 = 0)
function FarmLevelConfig.ExpForLevel(level)
	local total = 0
	for l = 1, math.max(1, math.floor(level)) - 1 do total += FarmLevelConfig.ExpToNext(l) end
	return total
end

-- `ceiling` (ไม่บังคับ) = เพดานที่จะใช้ · ไม่ใส่ = เพดานที่เปิดอยู่ตอนนี้ (Ceiling) · เทสตาราง 50 เลเวลส่ง MaxLevel
function FarmLevelConfig.IsMax(level, ceiling)
	return (tonumber(level) or 1) >= (ceiling or FarmLevelConfig.Ceiling())
end

-- EXP สะสม → (เลเวล, EXP ที่เข้าไปแล้วในเลเวลนี้, EXP ที่เลเวลนี้ต้องการ)
-- ถึงเพดานแล้ว = (MaxLevel, need, need) หลอดเต็ม — ผู้เรียกถาม IsMax เพื่อเขียน "สูงสุด" แทนตัวเลข
function FarmLevelConfig.LevelFromExp(exp, ceiling)
	ceiling = ceiling or FarmLevelConfig.Ceiling()
	exp = tonumber(exp) or 0
	if exp ~= exp or exp < 0 then exp = 0 end
	exp = math.floor(math.min(exp, 1e12))
	local level = 1
	while level < ceiling do
		local need = FarmLevelConfig.ExpToNext(level)
		if exp < need then return level, exp, need end
		exp -= need
		level += 1
	end
	local need = FarmLevelConfig.ExpToNext(level)
	return level, need, need
end

-- EXP ใหม่หลังได้ `gain` · ตันแล้วและไม่สะสม = หยุดที่เส้นเลเวลสูงสุด (ไม่มีวันลด)
function FarmLevelConfig.AddExp(exp, gain, ceiling)
	local total = math.max(0, math.floor(tonumber(exp) or 0)) + math.max(0, math.floor(tonumber(gain) or 0))
	if not FarmLevelConfig.BankExpAtMax then
		total = math.min(total, math.max(FarmLevelConfig.ExpForLevel(ceiling or FarmLevelConfig.Ceiling()), tonumber(exp) or 0))
	end
	return total
end

--------------------------------------------------------------------------------
-- ของที่ไม่ใช่ไอเทม
--------------------------------------------------------------------------------

-- แสง (เฟส 2b) ปลดทีละสี: ฟ้า → (ขอบทอง) → ทอง → แดง · เลเวลตามตาราง 50 เลเวล (ผู้ใช้อนุมัติ 2026-09-27)
FarmLevelConfig.GlowLevels = { blue = 2, gold = 9, red = 20 }
FarmLevelConfig.GoldBorderLevel = 4
FarmLevelConfig.TruckLevel = 1

-- เพดานจำนวนบ้าน (นับบ้านที่วางอยู่ + ในกระเป๋า + ในคลัง ตอนซื้อ) · แต่ละเลขในรายการ = เลเวลที่มีบ้านได้เพิ่ม 1 หลัง
-- Lv4 = 1 · Lv16 = 2 · Lv26 = 3 · Lv36 = 4 · Lv46 = 5 (เดิม +1 ทุก 5 เลเวลไม่รู้จบ — ผู้ใช้อนุมัติตาราง 2026-09-27)
FarmLevelConfig.HouseCapLevels = { 4, 16, 26, 36, 46 }

-- **เพดานจำนวนสัตว์เลี้ยง** (เฟส 2d · นับแบบเดียวกับบ้าน) · Lv2 = 1 · Lv10 = 2 · Lv20 = 3 · Lv32 = 4 · Lv49 = 5
-- ตัวแรกปลดพร้อมสัตว์เลี้ยงชุดแรก (ไก่/เป็ด) จึงไม่ขึ้นเป็นแถวแยกในตารางปลด
FarmLevelConfig.PetCapLevels = { 2, 10, 20, 32, 49 }

local function countAt(list, level)
	level = tonumber(level) or 1
	local n = 0
	for _, at in ipairs(list) do
		if level >= at then n += 1 end
	end
	return n
end

function FarmLevelConfig.HouseCap(level)
	return countAt(FarmLevelConfig.HouseCapLevels, level)
end

function FarmLevelConfig.PetCap(level)
	return countAt(FarmLevelConfig.PetCapLevels, level)
end

-- **เพดานจำนวนคอกสัตว์** (ผู้ใช้สั่ง 2026-10-02) = จำนวนชนิดสัตว์ในคอกที่ปลดแล้ว — ไก่+เป็ด Lv2 = 2 · หมู Lv5 = 3 ·
-- แพะ+วัว Lv8 = 5 · แกะ Lv13 = 6 · กวาง+ม้า Lv17 = 8 · คิดจาก IslandConfig.PenAnimals ตรงๆ เพิ่มสัตว์ชนิดใหม่ = เพดานขึ้นเอง ·
-- นับแบบเดียวกับบ้าน (วาง + กระเป๋า + คลัง ตอนซื้อ) · ไม่ขึ้นแถวแยกในตารางปลด (ขึ้นพร้อมสัตว์ชนิดใหม่เสมอ)
FarmLevelConfig.PenCapLevels = {}
for _, animal in ipairs(IslandConfig.PenAnimals) do
	table.insert(FarmLevelConfig.PenCapLevels, animal.level)
end
table.sort(FarmLevelConfig.PenCapLevels)

function FarmLevelConfig.PenCap(level)
	return countAt(FarmLevelConfig.PenCapLevels, level)
end

function FarmLevelConfig.IsPen(id)
	return id == IslandConfig.PenItem
end

-- เลเวลแรกที่เพดานในรายการนี้มากกว่าตอนนี้ (บอกผู้เล่นว่าต้องไปถึงไหน) · nil = เต็มเพดานสุดท้ายแล้ว
function FarmLevelConfig.NextCapLevel(list, level)
	level = tonumber(level) or 1
	for _, at in ipairs(list) do
		if at > level then return at end
	end
	return nil
end

-- ไอเทมไหนนับเป็น "บ้าน" (ใช้กับเพดาน)
function FarmLevelConfig.IsHouse(id)
	return type(id) == "string" and id:sub(1, 6) == "House_"
end

-- ไอเทมไหนนับเป็น "สัตว์เลี้ยง" (ใช้กับเพดาน) — ถามจากแคตตาล็อก ตัวใหม่ที่ติด `pet = true` เข้าเพดานเอง
function FarmLevelConfig.IsPet(id)
	local item = type(id) == "string" and ItemCatalog.Get(id)
	return item ~= nil and item ~= false and item.pet == true
end

function FarmLevelConfig.GlowAllowed(level)
	level = tonumber(level) or 1
	local g = FarmLevelConfig.GlowLevels
	return { blue = level >= g.blue, gold = level >= g.gold, red = level >= g.red }
end

function FarmLevelConfig.GoldAllowed(level)
	return (tonumber(level) or 1) >= FarmLevelConfig.GoldBorderLevel
end

-- เลเวลที่ปลดแถวร้านเกาะ · แถวที่ลืมใส่ = 1 (เปิด) — เทสจับแถวที่ลืมก่อนถึงมือผู้เล่น
function FarmLevelConfig.ShopRowLevel(row)
	return row and tonumber(row.level) or 1
end

--------------------------------------------------------------------------------
-- ตารางปลดสำหรับหน้าจอ
--------------------------------------------------------------------------------

-- แถวหนึ่ง = { text, icon?, emoji? } · icon คือ rbxassetid ของไอเทม ("" = ⌛) · emoji ใช้เมื่อไม่ใช่ไอเทม
-- text เป็นไทยเสมอ (หน้าจอแปลด้วย Locale.Show) · `template` = แม่แบบไทยที่มี %s แทนชื่อไอเทม (ย้อนแปลทั้งแถวได้)
local function itemRow(id, template)
	local item = ItemCatalog.Get(id)
	local name = item and item.name or id
	return { text = template and template:format(name) or name, icon = item and item.icon or "" }
end

-- ชื่อก้อนในโซนแร่ (MineRocks ใช้ kind ของ GatherConfig ซึ่งเป็นภาษาอังกฤษ)
local ROCK_NAMES = {
	Rock = "หิน", IronOre = "แร่เหล็ก", SilverOre = "แร่เงิน", GoldOre = "แร่ทอง",
	MagicOre = "แร่เวทมนตร์", DiamondOre = "แร่เพชร",
}

-- ของที่ปลด "ตรงเลเวลนี้พอดี" เรียง: สิ่งพิเศษ → ของในร้าน → สัตว์ → พืช → แร่ในโซนแร่ → สูตรคราฟ
function FarmLevelConfig.UnlocksAt(level)
	local out = {}
	local function add(row) out[#out + 1] = row end

	if level == FarmLevelConfig.TruckLevel then add({ text = "รถส่งออก", emoji = "🚚" }) end
	local g = FarmLevelConfig.GlowLevels
	if level == g.blue then add({ text = "แสงฟ้า (วัตถุดิบ ×2)", emoji = "💠" }) end
	if level == FarmLevelConfig.GoldBorderLevel then add({ text = "ของขอบทอง", emoji = "🌟" }) end
	if level == g.gold then add({ text = "แสงทอง (EXP ×2)", emoji = "✨" }) end
	if level == g.red then add({ text = "แสงแดง (ขอบทอง + ×2 ทุกอย่าง)", emoji = "🔥" }) end
	local cap, before = FarmLevelConfig.HouseCap(level), FarmLevelConfig.HouseCap(level - 1)
	if cap > before then add({ text = ("มีบ้านได้ %d หลัง"):format(cap), emoji = "🏠" }) end
	local pets, petsBefore = FarmLevelConfig.PetCap(level), FarmLevelConfig.PetCap(level - 1)
	if pets > petsBefore and pets > 1 then add({ text = ("สัตว์เลี้ยงได้ %d ตัว"):format(pets), emoji = "🐾" }) end
	-- มอนบุกกลางคืน (2026-09-28): ชุดแรกเปิดระบบ ชุดถัดไป = เจอตัวโหดขึ้น
	for i, tier in ipairs(IslandConfig.NightRaid.pools) do
		if tier.level == level then
			add({ text = i == 1 and "มอนบุกตอนกลางคืน" or "มอนกลางคืนโหดขึ้น", emoji = "🌙" })
		end
	end

	-- ของที่ร้านเกมหลักขายอยู่แล้ว (อุปกรณ์ เหยื่อ ค้อนซ่อม 2026-09-28) ไม่ใช่ของปลดของฟาร์ม — ไม่นับในตาราง
	-- (กติกา 1-6 อย่างต่อเลเวลที่ผู้ใช้อนุมัติ · ไม่งั้น Lv1 กลายเป็น 12 อย่าง)
	local inTown = {}
	for _, row in ipairs(ShopConfig.Sells) do inTown[row.id] = true end
	for _, row in ipairs(ShopConfig.IslandSells) do
		if FarmLevelConfig.ShopRowLevel(row) == level and not inTown[row.id] then add(itemRow(row.id)) end
	end
	for _, a in ipairs(IslandConfig.PenAnimals) do
		if (a.level or 1) == level then add({ text = ("%s (คอก)"):format(a.name), emoji = a.emoji or "🐾" }) end
	end
	for _, c in ipairs(IslandConfig.Crops) do
		-- พืชเลเวล 1 ออกมากับเมล็ดอยู่แล้ว · พืชที่มีเมล็ดของตัวเองปลดพร้อมเมล็ดในร้าน (แถวร้านบอกแล้ว)
		if (c.level or 1) == level and level > 1 and c.seed == nil then add(itemRow(c.item, "งอกจากเมล็ด: %s")) end
	end
	for _, r in ipairs(IslandConfig.MineRocks) do
		if (r.level or 1) == level and level > 1 then
			add({ text = ("โซนแร่: %s"):format(ROCK_NAMES[r.kind] or r.kind), emoji = "⛏️" })
		end
	end
	for _, recipe in ipairs(CraftConfig.Recipes) do
		if recipe.level == level then add(itemRow(recipe.id, "สูตร: %s")) end
	end
	return out
end

-- เลเวลสูงสุดที่ตารางยังมีของปลด **ไม่เกินเพดาน** (ของที่ตั้งเลเวลเกินเพดานไว้ล่วงหน้าจะไม่โผล่ในหน้าจอ)
function FarmLevelConfig.LastUnlockLevel()
	local last = 1
	for level = 1, FarmLevelConfig.MaxLevel do
		if #FarmLevelConfig.UnlocksAt(level) > 0 then last = level end
	end
	return last
end

return FarmLevelConfig
