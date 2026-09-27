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

-- EXP ที่ต้องใช้ "จากเลเวลนี้ไปเลเวลถัดไป" (ปรับ 2026-09-27 ตามที่ผู้ใช้สั่ง: "ตันต้องใช้เวลา 1-3 เดือน ·
-- ช่วงแรก 3 เลเวลขึ้นง่าย · หลังเลเวล 5 ยากขึ้นอีก")
--
-- ตั้งจาก **จำนวนใบสั่งที่ต้องส่งต่อเลเวล** × EXP เฉลี่ยต่อใบของเลเวลนั้น (วัดจาก ExportOrders จริง 4,000 ใบต่อเลเวล):
--   ใบ/เลเวล  Lv1-4: 2 · 3 · 4 · 6   ·   Lv5-18: 10 → 62 (+4 ต่อเลเวล)   ·   Lv19→20: 66
--   รวมถึง Lv19 (เพดานตอนนี้) ≈ 519 ใบ = วันละ 16 ใบ ~1 เดือน · วันละ 8 ใบ ~2 เดือน · วันละ 6 ใบ ~3 เดือน
-- เปลี่ยนสูตรใบสั่ง (ExportOrders/ExportConfig) เมื่อไหร่ต้องวัด EXP เฉลี่ยใหม่แล้วแก้ตารางนี้ตาม (เทส farm_level_test จับ)
FarmLevelConfig.ExpTable = {
	120, 240, 450, 780, -- Lv1-4: ขึ้นเร็ว (ใบละ ~60-130 EXP)
	1450, 2250, 3750, 5150, 7050, -- Lv5-9
	9150, 11400, 13250, 16150, 18750, -- Lv10-14
	22050, 24500, 27150, 30150, -- Lv15-18
	32250, -- Lv19 → 20 (ใช้วันที่ปลดเพดานเพิ่ม)
}
-- เลยตารางไปแล้ว เลเวลละ +2,000 จากตัวสุดท้าย
FarmLevelConfig.ExpStepAfter = 2000

function FarmLevelConfig.ExpToNext(level)
	local t = FarmLevelConfig.ExpTable
	level = math.max(1, math.floor(level))
	if level <= #t then return t[level] end
	return t[#t] + (level - #t) * FarmLevelConfig.ExpStepAfter
end

-- **เพดานเลเวลตอนนี้ = 19** (ผู้ใช้สั่ง 2026-09-27: "ล็อคให้ตันไปที่เวล 19 ไปก่อน เดี๋ยวเพิ่มของใหม่ วัตถุดิบใหม่
-- ของคราฟใหม่ แล้วค่อยมาปลดล็อคต่อ") · ปลดเพิ่มวันหน้า = ขยับเลขนี้ตัวเดียว (ตาราง EXP ต่อไปได้เองจากสูตร)
FarmLevelConfig.MaxLevel = 19
-- EXP ที่ได้ตอนตันแล้ว · true = สะสมไว้ (วันปลดเพดาน ขึ้นเลเวลตามที่สะสมทันที) · false = หยุดนับที่เส้นเลเวล 19
FarmLevelConfig.BankExpAtMax = false

-- EXP สะสมที่ต้องใช้ถึงเลเวลนี้ (Lv1 = 0)
function FarmLevelConfig.ExpForLevel(level)
	local total = 0
	for l = 1, math.max(1, math.floor(level)) - 1 do total += FarmLevelConfig.ExpToNext(l) end
	return total
end

function FarmLevelConfig.IsMax(level)
	return (tonumber(level) or 1) >= FarmLevelConfig.MaxLevel
end

-- EXP สะสม → (เลเวล, EXP ที่เข้าไปแล้วในเลเวลนี้, EXP ที่เลเวลนี้ต้องการ)
-- ถึงเพดานแล้ว = (MaxLevel, need, need) หลอดเต็ม — ผู้เรียกถาม IsMax เพื่อเขียน "สูงสุด" แทนตัวเลข
function FarmLevelConfig.LevelFromExp(exp)
	exp = tonumber(exp) or 0
	if exp ~= exp or exp < 0 then exp = 0 end
	exp = math.floor(math.min(exp, 1e12))
	local level = 1
	while level < FarmLevelConfig.MaxLevel do
		local need = FarmLevelConfig.ExpToNext(level)
		if exp < need then return level, exp, need end
		exp -= need
		level += 1
	end
	local need = FarmLevelConfig.ExpToNext(level)
	return level, need, need
end

-- EXP ใหม่หลังได้ `gain` · ตันแล้วและไม่สะสม = หยุดที่เส้นเลเวลสูงสุด (ไม่มีวันลด)
function FarmLevelConfig.AddExp(exp, gain)
	local total = math.max(0, math.floor(tonumber(exp) or 0)) + math.max(0, math.floor(tonumber(gain) or 0))
	if not FarmLevelConfig.BankExpAtMax then
		total = math.min(total, math.max(FarmLevelConfig.ExpForLevel(FarmLevelConfig.MaxLevel), tonumber(exp) or 0))
	end
	return total
end

--------------------------------------------------------------------------------
-- ของที่ไม่ใช่ไอเทม
--------------------------------------------------------------------------------

-- แสง (เฟส 2b) ปลดทีละสี: ฟ้า → (ขอบทอง) → ทอง → แดง
FarmLevelConfig.GlowLevels = { blue = 2, gold = 7, red = 10 }
FarmLevelConfig.GoldBorderLevel = 4
FarmLevelConfig.TruckLevel = 1

-- เพดานจำนวนบ้าน (นับบ้านที่วางอยู่ + ในกระเป๋า + ในคลัง ตอนซื้อ) · Lv4 = 1 · Lv9 = 2 · Lv14 = 3 แล้ว +1 ทุก 5 เลเวล
FarmLevelConfig.HouseCapLevels = { 4, 9 }
FarmLevelConfig.HouseCapEvery = 5

function FarmLevelConfig.HouseCap(level)
	level = tonumber(level) or 1
	local cap = 0
	for _, at in ipairs(FarmLevelConfig.HouseCapLevels) do
		if level >= at then cap += 1 end
	end
	local last = FarmLevelConfig.HouseCapLevels[#FarmLevelConfig.HouseCapLevels]
	local nextAt = last + FarmLevelConfig.HouseCapEvery
	if level >= nextAt then cap += 1 + math.floor((level - nextAt) / FarmLevelConfig.HouseCapEvery) end
	return cap
end

-- ไอเทมไหนนับเป็น "บ้าน" (ใช้กับเพดาน)
function FarmLevelConfig.IsHouse(id)
	return type(id) == "string" and id:sub(1, 6) == "House_"
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
local function itemRow(id, prefix)
	local item = ItemCatalog.Get(id)
	return { text = (prefix or "") .. (item and item.name or id), icon = item and item.icon or "" }
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

	for _, row in ipairs(ShopConfig.IslandSells) do
		if FarmLevelConfig.ShopRowLevel(row) == level then add(itemRow(row.id)) end
	end
	for _, a in ipairs(IslandConfig.PenAnimals) do
		if (a.level or 1) == level then add({ text = a.name .. " (คอก)", emoji = a.emoji or "🐾" }) end
	end
	for _, c in ipairs(IslandConfig.Crops) do
		-- พืชเลเวล 1 ออกมากับเมล็ดอยู่แล้ว · พืชที่มีเมล็ดของตัวเองปลดพร้อมเมล็ดในร้าน (แถวร้านบอกแล้ว)
		if (c.level or 1) == level and level > 1 and c.seed == nil then add(itemRow(c.item, "งอกจากเมล็ด: ")) end
	end
	for _, r in ipairs(IslandConfig.MineRocks) do
		if (r.level or 1) == level and level > 1 then
			add({ text = "โซนแร่: " .. (ROCK_NAMES[r.kind] or r.kind), emoji = "⛏️" })
		end
	end
	for _, recipe in ipairs(CraftConfig.Recipes) do
		if recipe.level == level then add(itemRow(recipe.id, "สูตร: ")) end
	end
	return out
end

-- เลเวลสูงสุดที่ตารางยังมีของปลด **ไม่เกินเพดาน** (เพดานบ้าน +1 ทุก 5 เลเวลไปเรื่อยๆ ถ้าไม่หนีบ ตารางจะยาวถึง Lv39)
function FarmLevelConfig.LastUnlockLevel()
	local last = 1
	for level = 1, FarmLevelConfig.MaxLevel do
		if #FarmLevelConfig.UnlocksAt(level) > 0 then last = level end
	end
	return last
end

return FarmLevelConfig
