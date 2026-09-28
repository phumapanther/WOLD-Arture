-- IslandNightRules: กติกาล้วนของมอนบุกเกาะตอนกลางคืน (สเปก 2026-09-28-island-night-raid-design.md)
-- ไม่แตะโลก — ทอยต่อคืน · ชุดมอนตามเลเวลฟาร์ม · ตัวที่พาเหรดสุ่มได้ตามเวลาในคืน · เวลาถึงเช้า
-- `rand` = ฟังก์ชันคืน [0,1) (เทสส่งตัวที่ seed ไว้) · ไม่ส่ง = math.random
local IslandConfig = require(script.Parent.IslandConfig)
local GatherConfig = require(script.Parent.GatherConfig)
local DayNightConfig = require(script.Parent.DayNightConfig)

local Rules = {}
local R = IslandConfig.NightRaid

local function roll(rand)
	return (rand or math.random)()
end

-- ทอยตอนหัวค่ำ: ตัวพิเศษหนึ่งตัวสูงสุด + พาเหรดทอยแยก
function Rules.RollNight(rand)
	local x, acc, special = roll(rand), 0, nil
	for _, o in ipairs(R.odds) do
		acc += o.chance
		if x < acc then
			special = o.id
			break
		end
	end
	return { special = special, parade = roll(rand) < R.paradeChance }
end

-- ชุดมอนที่เลเวลฟาร์มนี้เจอได้ เรียงจากเลือดน้อยไปมาก (= ง่าย → โหด) · ต่ำกว่าชุดแรก = ว่าง
function Rules.PoolFor(level)
	local out = {}
	for _, tier in ipairs(R.pools) do
		if level >= tier.level then
			for _, kind in ipairs(tier.kinds) do out[#out + 1] = kind end
		end
	end
	table.sort(out, function(a, b)
		local ha, hb = GatherConfig.Mobs[a].hp, GatherConfig.Mobs[b].hp
		if ha ~= hb then return ha < hb end
		return a < b
	end)
	return out
end

-- พาเหรดโหดขึ้นตามเวลา: หนึ่งในสามแรกของคืน = ตัวง่ายสุดหนึ่งในสามของชุด · กลาง = สองในสาม · ท้าย = ทั้งชุด
function Rules.PoolAt(level, progress)
	local pool = Rules.PoolFor(level)
	local share = progress < 1 / 3 and 1 / 3 or (progress < 2 / 3 and 2 / 3 or 1)
	local n = math.min(#pool, math.max(1, math.ceil(#pool * share)))
	local out = {}
	for i = 1, n do out[i] = pool[i] end
	return out
end

function Rules.Pick(list, rand)
	if #list == 0 then return nil end
	return list[math.floor(roll(rand) * #list) + 1]
end

-- ความยาวคืนเป็นชั่วโมงในเกม (18:30 → 05:30 = 11)
local NIGHT_HOURS = (DayNightConfig.DawnHour - DayNightConfig.DuskHour) % 24

-- คืนนี้ผ่านไปกี่ส่วน 0..1 · กลางวัน = 0
function Rules.Progress(clockTime)
	if not DayNightConfig.IsNight(clockTime) then return 0 end
	return ((clockTime - DayNightConfig.DuskHour) % 24) / NIGHT_HOURS
end

-- อีกกี่วินาทีจริงถึงเช้า · กลางวัน = 0
function Rules.SecondsToDawn(clockTime)
	if not DayNightConfig.IsNight(clockTime) then return 0 end
	return ((DayNightConfig.DawnHour - clockTime) % 24) * DayNightConfig.DayLengthSeconds / 24
end

return Rules
