-- node tools/lua.js tests/farm_level_test.lua Edit   (เพลสไหนก็ได้ — ข้อมูลล้วน)
-- เฟส 2c (ผู้ใช้อนุมัติร่าง 2026-09-27): เส้น EXP · ของที่ปลดตามเลเวล · ใบสั่งส่งออก · เพดานเพชร · สูตรเครื่องคราฟ
-- โคลนทั้งชุดลงโฟลเดอร์ชั่วคราว: โมดูลพวกนี้ require พี่น้องด้วย script.Parent และ Edit แคช require ข้ามการรัน
local RS = game.ReplicatedStorage
local temp = Instance.new("Folder")
temp.Name = "FarmLevelTest_" .. math.random(1, 1e9)
temp.Parent = RS
local NAMES = { "CraftConfig", "ShopConfig", "MailConfig", "PremiumConfig", "ItemCatalog", "IslandConfig", "GatherConfig",
	"GoldBorder", "QuestConfig", "FarmLevelConfig", "ExportConfig", "ExportOrders" }
local missing = {}
for _, name in ipairs(NAMES) do
	local m = RS:FindFirstChild(name)
	if m then m:Clone().Parent = temp else missing[#missing + 1] = name end
end

local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

check(#missing == 0, "มีโมดูลครบ " .. table.concat(missing, ","))
local ok, err = pcall(function()
	local ItemCatalog = require(temp.ItemCatalog)
	local ShopConfig = require(temp.ShopConfig)
	local IslandConfig = require(temp.IslandConfig)
	local CraftConfig = require(temp.CraftConfig)
	local F = require(temp.FarmLevelConfig)
	local ExportConfig = require(temp.ExportConfig)
	local EO = require(temp.ExportOrders)
	local GoldBorder = require(temp.GoldBorder)

	----------------------------------------------------------------- เส้น EXP
	local mono = true
	for i = 2, #F.ExpTable do if F.ExpTable[i] <= F.ExpTable[i - 1] then mono = false end end
	check(mono and #F.ExpTable >= F.MaxLevel, "ตาราง EXP เพิ่มขึ้นเสมอ ยาวถึงเพดาน")
	local l, into, need = F.LevelFromExp(0)
	check(l == 1 and into == 0 and need == F.ExpTable[1], "EXP 0 = Lv1 เริ่มศูนย์")
	check(F.LevelFromExp(F.ExpForLevel(2) - 1) == 1 and F.LevelFromExp(F.ExpForLevel(2)) == 2 and F.LevelFromExp(F.ExpForLevel(3)) == 3, "เส้นแบ่งเลเวลตรงกับ ExpForLevel")
	check(F.LevelFromExp(F.ExpForLevel(10) - 1) == 9 and F.LevelFromExp(F.ExpForLevel(10)) == 10, "Lv10 ที่ EXP สะสมของมันพอดี")
	local n = #F.ExpTable
	check(F.ExpToNext(n + 1) == F.ExpTable[n] + F.ExpStepAfter, "เลยตารางใช้สูตรต่อ")
	-- เพดานเลเวล (ผู้ใช้สั่ง 2026-09-27: ตัน Lv19 ไปก่อน)
	check(F.MaxLevel == 19 and F.IsMax(19) and not F.IsMax(18), "เพดานเลเวล 19")
	local capExp = F.ExpForLevel(F.MaxLevel)
	local ml, mi, mn = F.LevelFromExp(capExp * 3)
	check(ml == 19 and mi == mn, "EXP เกินเพดาน = Lv19 หลอดเต็ม")
	check(F.LevelFromExp(capExp - 1) == 18 and F.LevelFromExp(capExp) == 19, "ถึง Lv19 ที่ EXP สะสมของมันพอดี")
	if not F.BankExpAtMax then
		check(F.AddExp(capExp - 10, 500) == capExp and F.AddExp(capExp, 500) == capExp, "ตันแล้ว EXP หยุดที่เส้นเพดาน")
	end
	check(F.AddExp(100, 50) == 150 and F.AddExp(capExp * 2, 10) >= capExp * 2, "AddExp ไม่มีวันลด")
	check(F.LastUnlockLevel() <= F.MaxLevel, "ตารางปลดไม่เกินเพดาน")
	check(F.LevelFromExp(-5) == 1 and F.LevelFromExp(0 / 0) == 1 and F.LevelFromExp("x") == 1, "EXP แปลกๆ = Lv1")
	check(F.LevelFromExp(1e15) == F.MaxLevel, "EXP มหาศาลไม่วนไม่จบ")

	----------------------------------------------------------------- สิ่งที่ปลด
	check(F.HouseCap(1) == 0 and F.HouseCap(3) == 0 and F.HouseCap(4) == 1 and F.HouseCap(8) == 1
		and F.HouseCap(9) == 2 and F.HouseCap(13) == 2 and F.HouseCap(14) == 3 and F.HouseCap(19) == 4,
		"เพดานบ้าน 0 → Lv4 1 → Lv9 2 → Lv14 3 → Lv19 4")
	local g1, g2, g7, g10 = F.GlowAllowed(1), F.GlowAllowed(2), F.GlowAllowed(7), F.GlowAllowed(10)
	check(not g1.blue and not g1.gold and not g1.red, "Lv1 ไม่มีแสง")
	check(g2.blue and not g2.gold and not g2.red, "Lv2 แสงฟ้า")
	check(g7.blue and g7.gold and not g7.red and g10.red, "Lv7 ทอง · Lv10 แดง")
	check(not F.GoldAllowed(3) and F.GoldAllowed(4), "ขอบทอง Lv4")
	check(F.IsHouse("House_Longhouse") and not F.IsHouse("AnimalPen"), "รู้จักบ้าน")

	local badRows = {}
	for _, row in ipairs(ShopConfig.IslandSells) do
		if type(row.level) ~= "number" or row.level < 1 or not ItemCatalog.Exists(row.id) then
			badRows[#badRows + 1] = row.id
		end
	end
	check(#badRows == 0, "ร้านเกาะทุกแถวมี level และมีของจริง " .. table.concat(badRows, ","))
	local badAnimals = {}
	for _, a in ipairs(IslandConfig.PenAnimals) do
		if type(a.level) ~= "number" or type(a.emoji) ~= "string" then badAnimals[#badAnimals + 1] = a.kind end
	end
	check(#badAnimals == 0, "สัตว์คอกทุกตัวมี level + emoji " .. table.concat(badAnimals, ","))
	local rockOk = true
	for _, r in ipairs(IslandConfig.MineRocks) do
		if type(r.level) ~= "number" then rockOk = false end
		if (r.kind == "Rock" or r.kind == "IronOre") and r.level ~= 1 then rockOk = false end
	end
	check(rockOk, "ก้อนในโซนแร่มี level · หิน/เหล็ก = 1 (โซนแร่เดิมยังขุดได้)")

	local function names(list)
		local t = {}
		for _, c in ipairs(list) do t[#t + 1] = c.item end
		table.sort(t)
		return table.concat(t, ",")
	end
	check(names(IslandConfig.CropsFor("Seed", 1)) == "Vegetable,Wheat", "เมล็ดสุ่ม Lv1 = ข้าว/ผัก")
	check(names(IslandConfig.CropsFor("Seed", 3)) == "Herb,Vegetable,Wheat", "Lv3 + สมุนไพร")
	check(names(IslandConfig.CropsFor("Seed", 20)) == "Herb,MagicBranch,Vegetable,Wheat", "เมล็ดสุ่มไม่เคยได้ฝ้าย")
	check(#IslandConfig.CropsFor("CottonSeed", 5) == 0 and names(IslandConfig.CropsFor("CottonSeed", 6)) == "Cotton",
		"เมล็ดฝ้ายใช้ได้ Lv6 ได้ฝ้ายอย่างเดียว")
	check(names(IslandConfig.CropsFor("Seed", nil)) == "Herb,MagicBranch,Vegetable,Wheat", "ไม่รู้เลเวล = ไม่ล็อก")
	check(GoldBorder.CropItems.Cotton == true, "ฝ้ายมีขอบทองได้")

	local function has(level, text)
		for _, row in ipairs(F.UnlocksAt(level)) do
			if row.text:find(text, 1, true) then return true end
		end
		return false
	end
	check(has(1, "รถส่งออก") and has(1, "แปลงดิน") and has(2, "แสงฟ้า") and has(2, "ไก่"), "ตารางปลด Lv1-2")
	check(has(3, "เตาอบขนมปัง") and has(4, "ขอบทอง") and has(4, "มีบ้านได้ 1") and has(4, "กระท่อมหิน"), "ตารางปลด Lv3-4")
	check(has(6, "กี่ทอผ้าไอน้ำ") and has(6, "เมล็ดฝ้าย") and has(7, "โซนแร่: แร่เงิน") and has(10, "แสงแดง"), "ตารางปลด Lv6-10")
	local empty = {}
	for level = 1, 11 do if #F.UnlocksAt(level) == 0 then empty[#empty + 1] = level end end
	check(#empty == 0, "ทุกเลเวล 1-11 มีของปลด " .. table.concat(empty, ","))
	check(F.LastUnlockLevel() >= 14, "ตารางยาวถึง Lv14 (บ้านหลังที่ 3)")

	----------------------------------------------------------------- สูตรเครื่องคราฟ
	local machineLevel = {}
	for _, row in ipairs(ShopConfig.IslandSells) do machineLevel[row.id] = row.level end
	local STATION_MACHINE = { bakery = "BakeryOven", metal = "MetalBench", loom = "Loom" }
	-- เลเวลที่ของดิบแต่ละชิ้นเริ่มผลิตได้บนเกาะ (ตรงกับตารางปลด)
	local RAW = { Wheat = 1, Vegetable = 1, Egg = 2, Herb = 3, Milk = 4, Meat = 4, IronOre = 5, Coal = 5, Cotton = 6,
		Wool = 6, SilverOre = 7, Leather = 8, Crystal = 8, MagicBranch = 8, GoldOre = 9, MagicOre = 10, Diamond = 11 }
	local made, final = {}, {}
	for _, good in ipairs(ExportConfig.Goods) do if good.final then final[good.id] = true end end
	local recipeProblems = {}
	for index, recipe in ipairs(CraftConfig.Recipes) do
		local machine = STATION_MACHINE[recipe.station or ""]
		if machine then
			made[recipe.id] = recipe.level
			local good = ExportConfig.Get(recipe.id)
			if recipe.chance ~= 1 or (recipe.gold or 0) ~= 0 or not recipe.batch then
				recipeProblems[#recipeProblems + 1] = recipe.id .. ":ต้องสำเร็จแน่นอน/ไม่มีค่าจ้าง/ทำหลายรอบได้"
			end
			if (recipe.seconds or 0) > 2 * 3600 then recipeProblems[#recipeProblems + 1] = recipe.id .. ":เกิน 2 ชม." end
			if not recipe.level or recipe.level < (machineLevel[machine] or 99) then
				recipeProblems[#recipeProblems + 1] = recipe.id .. ":เลเวลต่ำกว่าเครื่อง"
			end
			if not good or good.level ~= recipe.level then
				recipeProblems[#recipeProblems + 1] = recipe.id .. ":ไม่มีในกองส่งออก/เลเวลไม่ตรงสูตร"
			end
			if not ItemCatalog.Exists(recipe.id) or not (ItemCatalog.Get(recipe.id).vip or recipe.id == "Cotton") then
				recipeProblems[#recipeProblems + 1] = recipe.id .. ":ต้องอยู่กระเป๋า VIP"
			end
			if ItemCatalog.IsSellable(recipe.id) or ItemCatalog.IsMailable(recipe.id) then
				recipeProblems[#recipeProblems + 1] = recipe.id .. ":ต้องขาย/ส่งเมลไม่ได้"
			end
			if index <= 31 then recipeProblems[#recipeProblems + 1] = recipe.id .. ":ต้องต่อท้ายตาราง" end
		end
	end
	for _, recipe in ipairs(CraftConfig.Recipes) do
		if STATION_MACHINE[recipe.station or ""] then
			for material in pairs(recipe.cost) do
				local at = made[material] or RAW[material]
				if not at or at > recipe.level then
					recipeProblems[#recipeProblems + 1] = recipe.id .. ":ยังผลิต " .. material .. " ไม่ได้ที่ Lv" .. recipe.level
				end
			end
		end
		for material in pairs(recipe.cost) do
			if final[material] then recipeProblems[#recipeProblems + 1] = material .. ":ขั้นสุดท้ายห้ามเป็นวัตถุดิบ" end
		end
	end
	check(#recipeProblems == 0, "สูตรเครื่องคราฟถูกกติกาทั้งหมด " .. table.concat(recipeProblems, " | "))
	check(CraftConfig.MaxBatch == 10, "ทำได้ 1-10 รอบต่องาน")
	local goodProblems = {}
	for _, good in ipairs(ExportConfig.Goods) do
		local at = made[good.id] or RAW[good.id]
		if not ItemCatalog.Exists(good.id) then goodProblems[#goodProblems + 1] = good.id .. ":ไม่มีไอเทม" end
		if not at or good.level < at then goodProblems[#goodProblems + 1] = good.id .. ":ออกก่อนผลิตได้" end
		if good.coins < 1 or good.max < 1 then goodProblems[#goodProblems + 1] = good.id .. ":ราคา/จำนวนเสีย" end
	end
	check(#goodProblems == 0, "ของส่งออกทุกชิ้นผลิตได้ทันเลเวล " .. table.concat(goodProblems, " | "))

	----------------------------------------------------------------- ใบสั่ง
	local orderProblems = {}
	for level = 1, 15 do
		local rng = Random.new(level * 7919)
		local band
		for _, b in ipairs(ExportConfig.LineBands) do if level <= b.upTo then band = b break end end
		for n = 1, 300 do
			local o = EO.NewOrder(level, rng, n)
			local coins, finals = 0, 0
			if not EO.Valid(o) or o.gold then orderProblems[#orderProblems + 1] = "Lv" .. level .. ":ใบเสีย" break end
			if #o.lines < band.min or #o.lines > band.max then
				orderProblems[#orderProblems + 1] = ("Lv%d:บรรทัด %d"):format(level, #o.lines) break
			end
			local seen = {}
			for _, line in ipairs(o.lines) do
				local good = ExportConfig.Get(line.item)
				if good.level > level or line.qty > EO.MaxQty(good, level) or seen[line.item] then
					orderProblems[#orderProblems + 1] = ("Lv%d:%s x%d"):format(level, line.item, line.qty) break
				end
				seen[line.item] = true
				if good.final then finals += 1 end
				coins += good.coins * line.qty
			end
			if coins ~= o.coins or o.exp ~= math.ceil(coins / ExportConfig.ExpDivisor)
				or finals > (level >= 10 and ExportConfig.FinalsFrom10 or 1) then
				orderProblems[#orderProblems + 1] = "Lv" .. level .. ":เหรียญ/EXP/ของขั้นสุดท้ายเกิน" break
			end
			if level == 1 and o.lines[1].item ~= "Wheat" and o.lines[1].item ~= "Vegetable" then
				orderProblems[#orderProblems + 1] = "Lv1 ขอ " .. o.lines[1].item break
			end
		end
	end
	check(#orderProblems == 0, "ใบธรรมดา Lv1-15 × 300 ใบถูกกติกา " .. table.concat(orderProblems, " | "))
	local rng = Random.new(42)
	local avg1, avg10 = 0, 0
	for _ = 1, 200 do avg1 += EO.NewOrder(1, rng, 1).exp; avg10 += EO.NewOrder(10, rng, 1).exp end
	avg1, avg10 = avg1 / 200, avg10 / 200
	check(avg1 >= 40 and avg1 <= 100 and avg10 >= 200 and avg10 <= 450,
		("EXP เฉลี่ยต่อใบ Lv1 %.0f (≈2 ใบถึง Lv2) · Lv10 %.0f"):format(avg1, avg10))

	-- **จังหวะเลเวล** (ผู้ใช้สั่ง 2026-09-27): 3 เลเวลแรกขึ้นง่าย · หลัง Lv5 ยากขึ้น · ถึงเพดานใช้ 1-3 เดือน
	-- จำลองส่งทีละใบ (เลือกสุ่มจาก 3 ใบ ใบที่ส่งถูกแทนด้วยใบใหม่) 60 รอบ เฉลี่ยจำนวนใบที่ต้องส่งถึงแต่ละเลเวล
	local reach = { [2] = 0, [3] = 0, [4] = 0, [5] = 0, [19] = 0 }
	local TRIALS = 60
	for trial = 1, TRIALS do
		local r = Random.new(trial * 131)
		local exp, count = 0, 0
		local slots = { EO.NewOrder(1, r, 1), EO.NewOrder(1, r, 2), EO.NewOrder(1, r, 3) }
		local got = {}
		while not got[19] and count < 5000 do
			local pick = r:NextInteger(1, 3)
			exp = F.AddExp(exp, slots[pick].exp)
			count += 1
			local lv = F.LevelFromExp(exp)
			for target in pairs(reach) do if not got[target] and lv >= target then got[target] = count end end
			local others = {}
			for s = 1, 3 do if s ~= pick then others[#others + 1] = slots[s] end end
			slots[pick] = EO.Fresh(lv, r, count + 3, others)
		end
		for target in pairs(reach) do reach[target] += (got[target] or 5000) / TRIALS end
	end
	check(reach[2] <= 3 and reach[3] <= 6 and reach[4] <= 11 and reach[5] <= 18,
		("3 เลเวลแรกขึ้นง่าย: Lv2 %.1f · Lv3 %.1f · Lv4 %.1f · Lv5 %.1f ใบ"):format(reach[2], reach[3], reach[4], reach[5]))
	local days8 = reach[19] / 8
	check(reach[19] >= 450 and reach[19] <= 620 and days8 >= 30 and days8 <= 90,
		("ถึง Lv19 ใช้ %.0f ใบ = วันละ 8 ใบ %.0f วัน · วันละ 16 ใบ %.0f วัน"):format(reach[19], days8, reach[19] / 16))

	-- ของยากขึ้นตามเลเวล: Lv10 ข้าว/ผัก/ไข่ แทบไม่ออก · Lv15 ของขั้นสุดท้ายออกบ่อยกว่า Lv5
	local function mix(level)
		local r, basic, finals, lines = Random.new(level * 17), 0, 0, 0
		for i = 1, 1500 do
			for _, line in ipairs(EO.NewOrder(level, r, i).lines) do
				local g = ExportConfig.Get(line.item)
				lines += 1
				if g.level <= 2 then basic += 1 end
				if g.final then finals += 1 end
			end
		end
		return basic / lines, finals / lines
	end
	local b5, f5 = mix(5)
	local b10 = mix(10)
	local b19, f19 = mix(19)
	check(b10 < 0.05 and b19 < 0.05 and f19 > f5,
		("ของพื้นฐาน Lv5 %.0f%% → Lv10 %.0f%% → Lv19 %.0f%% · ขั้นสุดท้าย Lv5 %.0f%% → Lv19 %.0f%%"):format(
			b5 * 100, b10 * 100, b19 * 100, f5 * 100, f19 * 100))

	check(EO.NewGoldOrder(3, rng, 1) == nil, "ใบขอบทองยังไม่มีที่ Lv3")
	local goldProblems = {}
	for level = 4, 12 do
		for n = 1, 100 do
			local o = EO.NewGoldOrder(level, rng, n)
			local line = o and o.lines[1]
			if not o or not o.gold or not EO.Valid(o) then goldProblems[#goldProblems + 1] = "Lv" .. level .. ":ไม่ได้ใบ" break end
			local good = ExportConfig.Get(line.item)
			if not (GoldBorder.GatherItems[line.item] or GoldBorder.CropItems[line.item]) or good.level > level
				or (level < ExportConfig.Gold.twoFrom and line.qty ~= 1) or line.qty > 2
				or o.coins ~= good.coins * ExportConfig.Gold.perUnit * line.qty + ExportConfig.Gold.bonus then
				goldProblems[#goldProblems + 1] = ("Lv%d:%s x%d = %d"):format(level, line.item, line.qty, o.coins) break
			end
		end
	end
	check(#goldProblems == 0, "ใบขอบทอง Lv4-12 ขอของที่เป็นทองได้ 1 (Lv8+ 1-2) " .. table.concat(goldProblems, " | "))
	local goldCount = 0
	for _ = 1, 6000 do if EO.Fresh(10, rng, 1, {}).gold then goldCount += 1 end end
	check(math.abs(goldCount / 6000 - ExportConfig.Gold.chance) < 0.02, ("ใบใหม่เป็นใบทอง %.1f%%"):format(goldCount / 60))
	local sticky = false
	for _ = 1, 500 do if EO.Fresh(10, rng, 1, { { gold = true } }).gold then sticky = true end end
	check(not sticky, "มีใบทองค้างอยู่แล้ว = ไม่ออกใบทองซ้ำ")
	for _ = 1, 200 do if EO.Fresh(3, rng, 1, {}).gold then sticky = true end end
	check(not sticky, "Lv3 ไม่มีใบทองเลย")

	check(not EO.Valid(nil) and not EO.Valid({ lines = {}, coins = 1, exp = 1 })
		and not EO.Valid({ lines = { { item = "Nope", qty = 1 } }, coins = 1, exp = 1 })
		and not EO.Valid({ lines = { { item = "Wheat", qty = 0 } }, coins = 1, exp = 1 })
		and not EO.Valid({ gold = true, lines = { { item = "Egg", qty = 1 }, { item = "Wheat", qty = 1 } }, coins = 1, exp = 1 })
		and EO.Valid({ lines = { { item = "Wheat", qty = 3 } }, coins = 90, exp = 18 }), "ตรวจใบเสียได้")

	----------------------------------------------------------------- เพชร
	local G = ExportConfig.Gems
	local now = os.time()
	local gemProblems = {}
	for day = 0, 199 do
		local farm = {}
		local at = now + day * 86400
		EO.ResetCounters(farm, at)
		for n = 1, 12 do
			local o = { lines = { { item = "Wheat", qty = 1 } }, coins = 30, exp = 6, gold = (n == 5) }
			local gems = EO.RollGems(farm, o, rng)
			if gems > G.perOrder then gemProblems[#gemProblems + 1] = "เกินใบละ 2" end
			if n <= 3 and gems < 1 then gemProblems[#gemProblems + 1] = "ใบที่ " .. n .. " ไม่ได้เพชร" end
			farm.gemDayOrders += 1
			farm.gemDayCount += gems
			farm.gemMonthCount += gems
		end
		if farm.gemDayCount > G.perDay then gemProblems[#gemProblems + 1] = "วันละ " .. farm.gemDayCount end
	end
	check(#gemProblems == 0, "เพชร: 3 ใบแรกได้แน่นอน · ใบละ ≤2 · วันละ ≤5 (200 วัน) " .. table.concat(gemProblems, ","))
	local farm = {}
	EO.ResetCounters(farm, now)
	farm.gemMonthCount = G.perMonth - 1
	local capped = 0
	for _ = 1, 50 do capped = math.max(capped, EO.RollGems(farm, { gold = true }, rng)) end
	farm.gemMonthCount = G.perMonth
	check(capped == 1 and EO.RollGems(farm, { gold = true }, rng) == 0, "เพดานเดือน 150 ตัดทุกใบรวมใบทอง")
	local f2 = { gemDay = -1, gemDayCount = 5, gemDayOrders = 9, gemMonth = -1, gemMonthCount = 99 }
	EO.ResetCounters(f2, now)
	check(f2.gemDayCount == 0 and f2.gemDayOrders == 0 and f2.gemMonthCount == 0, "วัน/เดือนใหม่ล้างตัวนับ")
	local f3 = {}
	EO.ResetCounters(f3, now)
	f3.gemDayCount, f3.gemDayOrders, f3.gemMonthCount = 3, 2, 3
	EO.ResetCounters(f3, now)
	check(f3.gemDayCount == 3 and f3.gemDayOrders == 2, "วันเดิมไม่ล้าง")
	check(EO.GemHint({ gemDayCount = 0, gemDayOrders = 0, gemMonthCount = 0 }, {}) == "💎 1-2"
		and EO.GemHint({ gemDayCount = 4, gemDayOrders = 1, gemMonthCount = 4 }, {}) == "💎 1"
		and EO.GemHint({ gemDayCount = 5, gemDayOrders = 4, gemMonthCount = 5 }, {}) == "💎 ครบวันนี้แล้ว"
		and EO.GemHint({ gemDayCount = 1, gemDayOrders = 1, gemMonthCount = 1 }, { gold = true }) == "💎 2",
		"ป้ายเพชรบนการ์ด")

	----------------------------------------------------------------- แสงตามเลเวล
	local seen = { blue = 0, gold = 0, red = 0 }
	for _ = 1, 20000 do
		local g = IslandConfig.RollGlow(true, F.GlowAllowed(1))
		if g then seen[g] += 1 end
	end
	check(seen.blue + seen.gold + seen.red == 0, "Lv1 ทอยแสงไม่ติดเลย")
	seen = { blue = 0, gold = 0, red = 0 }
	for _ = 1, 40000 do
		local g = IslandConfig.RollGlow(true, F.GlowAllowed(2))
		if g then seen[g] += 1 end
	end
	check(seen.gold + seen.red == 0 and math.abs(seen.blue / 40000 - 0.07) < 0.006, ("Lv2 ฟ้าอย่างเดียว %.2f%%"):format(seen.blue / 400))
end)
check(ok, "ไม่มี error " .. tostring(err))
temp:Destroy()
return ("%s — %d fail\n%s"):format(fails == 0 and "PASS" or "FAIL", fails, table.concat(out, "\n"))
