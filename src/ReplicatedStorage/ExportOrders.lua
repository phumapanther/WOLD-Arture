-- ExportOrders (เฟส 2c): สุ่มใบสั่งซื้อของรถส่งออก · ทอยเพชร · นับวัน/เดือน — ข้อมูลล้วน ไม่รู้จักผู้เล่น/กระเป๋า
--
-- เซิร์ฟ (`Island/IslandFarm`) เป็นคนถือของจริง ไฟล์นี้แค่ตอบว่า "ใบใหม่หน้าตาแบบไหน" และ "ได้เพชรกี่เม็ด"
-- จึงเทสใน Edit ได้ทั้งหมด (`tests/farm_level_test.lua`) · ทุกฟังก์ชันที่สุ่มรับ `rng` (Random) จากผู้เรียก
local ExportConfig = require(script.Parent.ExportConfig)
local FarmLevelConfig = require(script.Parent.FarmLevelConfig)
local GoldBorder = require(script.Parent.GoldBorder)
local QuestConfig = require(script.Parent.QuestConfig)

local ExportOrders = {}

local function clampLevel(level)
	return math.max(1, math.floor(tonumber(level) or 1))
end

-- ของที่ออกในใบได้ที่เลเวลนี้
function ExportOrders.Pool(level)
	level = clampLevel(level)
	local pool = {}
	for _, good in ipairs(ExportConfig.Goods) do
		if (good.level or 1) <= level then pool[#pool + 1] = good end
	end
	return pool
end

-- **ของที่เพิ่งปลดออกบ่อยสุด ของพื้นฐานค่อยๆ หายไปตามเลเวล** (ผู้ใช้สั่ง 2026-09-27: ของในใบต้องยากขึ้นเรื่อยๆ)
-- เลเวลของชิ้นที่ปลดช้าที่สุดในกองส่งออกตอนนี้ (Lv11 — เพชร) · เลเวลฟาร์มเกินนี้ = ไม่มีของใหม่ให้ขอแล้ว
local TOP = 1
for _, good in ipairs(ExportConfig.Goods) do TOP = math.max(TOP, good.level or 1) end

-- วัด "ความเก่า" เทียบกับของใหม่สุดที่ปลดได้ ไม่ใช่เทียบกับเลเวลตรงๆ — ไม่งั้นเลยเลเวลที่มีของใหม่ไปแล้ว ทุกชิ้นเก่าลง
-- พร้อมกันจนชนพื้น แล้วข้าว/ผักกลับมาออกบ่อยอีก (วัดแล้ว: Lv19 ของพื้นฐาน 9% แทน 2%) · ความยากช่วงนั้นมาจากจำนวน
function ExportOrders.WeightOf(good, level)
	local W = ExportConfig.Weighting
	local ref = math.min(clampLevel(level), TOP)
	return math.max(W.floor, math.exp(-(ref - (good.level or 1)) / W.decay))
end

-- จำนวนสูงสุดต่อบรรทัดที่เลเวลนี้ (โตตามเลเวลที่เลยจุดปลดของชิ้นนั้นมา)
function ExportOrders.MaxQty(good, level)
	local over = math.max(0, clampLevel(level) - (good.level or 1))
	return math.max(1, math.floor(good.max * (1 + ExportConfig.QtyGrowth * over) + 0.5))
end

local function pickWeighted(list, rng, level)
	local total = 0
	for _, good in ipairs(list) do total += ExportOrders.WeightOf(good, level) end
	local roll = rng:NextNumber() * total
	for _, good in ipairs(list) do
		roll -= ExportOrders.WeightOf(good, level)
		if roll <= 0 then return good end
	end
	return list[#list]
end

function ExportOrders.Target(level)
	level = clampLevel(level)
	local knee = ExportConfig.TargetKnee or math.huge
	local early = math.min(level, knee) - 1
	local late = math.max(0, level - knee)
	return ExportConfig.TargetBase + ExportConfig.TargetPerLevel * early + (ExportConfig.TargetPerLevelAfter or 0) * late
end

function ExportOrders.LineCount(level, rng)
	level = clampLevel(level)
	for _, band in ipairs(ExportConfig.LineBands) do
		if level <= band.upTo then return rng:NextInteger(band.min, band.max) end
	end
	return 1
end

-- ใบธรรมดา · `id` = เลขประจำใบ (เซิร์ฟนับให้)
function ExportOrders.NewOrder(level, rng, id)
	level = clampLevel(level)
	local pool = ExportOrders.Pool(level)
	local lineCount = ExportOrders.LineCount(level, rng)
	local share = ExportOrders.Target(level) / lineCount
	local finalsLeft = level >= 10 and ExportConfig.FinalsFrom10 or 1
	local picked = {}
	local order = { id = id, lines = {}, coins = 0 }
	for _ = 1, lineCount do
		local candidates = {}
		for _, good in ipairs(pool) do
			if not picked[good.id] and good.coins <= share * ExportConfig.OverShare
				and not (good.final and finalsLeft <= 0) then
				candidates[#candidates + 1] = good
			end
		end
		if #candidates == 0 then break end
		local good = pickWeighted(candidates, rng, level)
		picked[good.id] = true
		if good.final then finalsLeft -= 1 end
		local qty = math.clamp(math.floor(share / good.coins + 0.5), 1, ExportOrders.MaxQty(good, level))
		table.insert(order.lines, { item = good.id, qty = qty })
		order.coins += good.coins * qty
	end
	-- กันพลาด: ทุกเลเวลมีข้าวอยู่ในกอง (30 เหรียญ ≤ ส่วนแบ่งต่ำสุด 300 × 2.5) จึงไม่ควรว่าง
	if #order.lines == 0 then
		local good = ExportConfig.Goods[1]
		order.lines[1] = { item = good.id, qty = 1 }
		order.coins = good.coins
	end
	order.exp = math.ceil(order.coins / ExportConfig.ExpDivisor)
	return order
end

-- ของที่มีขอบทองได้และปลดแล้ว (ผลผลิตแปลง/สัตว์/แร่ที่อยู่ในกองส่งออก)
function ExportOrders.GoldPool(level)
	local pool = {}
	for _, good in ipairs(ExportOrders.Pool(level)) do
		if GoldBorder.GatherItems[good.id] or GoldBorder.CropItems[good.id] then pool[#pool + 1] = good end
	end
	return pool
end

-- ใบขอบทอง · nil = ยังไม่ปลด/ไม่มีของที่เป็นขอบทองได้
function ExportOrders.NewGoldOrder(level, rng, id)
	level = clampLevel(level)
	if not FarmLevelConfig.GoldAllowed(level) then return nil end
	local pool = ExportOrders.GoldPool(level)
	if #pool == 0 then return nil end
	local good = pickWeighted(pool, rng, level)
	local G = ExportConfig.Gold
	local qty = level >= G.twoFrom and rng:NextInteger(1, 2) or 1
	local coins = good.coins * G.perUnit * qty + G.bonus
	return {
		id = id, gold = true,
		lines = { { item = good.id, qty = qty } },
		coins = coins,
		exp = math.ceil(coins / G.expDivisor),
	}
end

-- ใบใหม่สำหรับช่องหนึ่ง: ใบขอบทองถ้าปลดแล้ว ไม่มีใบทองค้างในช่องอื่น และทอยติด · ไม่งั้นใบธรรมดา
function ExportOrders.Fresh(level, rng, id, others)
	for _, other in pairs(others or {}) do
		if type(other) == "table" and other.gold then return ExportOrders.NewOrder(level, rng, id) end
	end
	if rng:NextNumber() < ExportConfig.Gold.chance then
		local gold = ExportOrders.NewGoldOrder(level, rng, id)
		if gold then return gold end
	end
	return ExportOrders.NewOrder(level, rng, id)
end

-- ใบที่โหลดมาจากโปรไฟล์ยังใช้ได้ไหม (ของถูกถอดจากคอนฟิก/ข้อมูลเสีย = สุ่มใบใหม่แทน)
function ExportOrders.Valid(order)
	if type(order) ~= "table" or type(order.lines) ~= "table" then return false end
	if #order.lines < 1 or #order.lines > 3 then return false end
	for _, line in ipairs(order.lines) do
		if type(line) ~= "table" or not ExportConfig.Get(line.item) then return false end
		local qty = line.qty
		if type(qty) ~= "number" or qty ~= math.floor(qty) or qty < 1 or qty > 999 then return false end
	end
	if order.gold and #order.lines ~= 1 then return false end
	return type(order.coins) == "number" and order.coins >= 0 and type(order.exp) == "number" and order.exp >= 0
end

--------------------------------------------------------------------------------
-- เพชร
--------------------------------------------------------------------------------

-- เลขวัน/เดือนตามเวลาไทย (วันเดียวกับ QuestConfig.DayNumber) · `now` = os.time()
function ExportOrders.DayMonth(now)
	now = now or os.time()
	local shifted = now + QuestConfig.TimeZoneOffsetSeconds
	local day = math.floor(shifted / QuestConfig.RerollSeconds)
	local t = os.date("!*t", shifted)
	return day, t.year * 12 + t.month
end

-- ล้างตัวนับเมื่อวัน/เดือนเปลี่ยน (แก้ `farm` ตรงๆ) · เรียกก่อนอ่าน/ทอยทุกครั้ง
function ExportOrders.ResetCounters(farm, now)
	local day, month = ExportOrders.DayMonth(now)
	if farm.gemDay ~= day then
		farm.gemDay, farm.gemDayCount, farm.gemDayOrders = day, 0, 0
	end
	if farm.gemMonth ~= month then
		farm.gemMonth, farm.gemMonthCount = month, 0
	end
	farm.gemDayCount = tonumber(farm.gemDayCount) or 0
	farm.gemDayOrders = tonumber(farm.gemDayOrders) or 0
	farm.gemMonthCount = tonumber(farm.gemMonthCount) or 0
	return day, month
end

-- ใบนี้ได้เพชรกี่เม็ด (เรียกหลัง ResetCounters) · ไม่แก้ตัวนับ — ผู้เรียกบวกเองหลังแจกจริง
function ExportOrders.RollGems(farm, order, rng)
	local G = ExportConfig.Gems
	local n
	if order.gold then
		n = ExportConfig.Gold.gems
	elseif farm.gemDayOrders < G.guaranteedPerDay or rng:NextNumber() < G.chanceAfter then
		n = rng:NextInteger(G.min, G.max)
	else
		n = 0
	end
	n = math.min(n, G.perOrder, G.perDay - farm.gemDayCount, G.perMonth - farm.gemMonthCount)
	return math.max(0, n)
end

-- ข้อความบนการ์ดใบสั่งบอกว่าจะได้เพชรไหม (เรียกหลัง ResetCounters)
function ExportOrders.GemHint(farm, order)
	local G = ExportConfig.Gems
	local room = math.min(G.perOrder, G.perDay - farm.gemDayCount, G.perMonth - farm.gemMonthCount)
	if room <= 0 then
		return farm.gemMonthCount >= G.perMonth and "💎 ครบเดือนนี้แล้ว" or "💎 ครบวันนี้แล้ว"
	end
	if order and order.gold then return ("💎 %d"):format(math.min(ExportConfig.Gold.gems, room)) end
	local top = math.min(G.max, room)
	local range = top > G.min and ("%d-%d"):format(G.min, top) or tostring(top)
	if farm.gemDayOrders < G.guaranteedPerDay then return "💎 " .. range end
	return ("💎 %s (%d%%)"):format(range, math.floor(G.chanceAfter * 100 + 0.5))
end

return ExportOrders
