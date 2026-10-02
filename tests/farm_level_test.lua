-- node tools/lua.js tests/farm_level_test.lua Edit   (เพลสไหนก็ได้ — ข้อมูลล้วน)
-- เฟส 2c (ผู้ใช้อนุมัติร่าง 2026-09-27): เส้น EXP · ของที่ปลดตามเลเวล · ใบสั่งส่งออก · เพดานเพชร · สูตรเครื่องคราฟ
-- โคลนทั้งชุดลงโฟลเดอร์ชั่วคราว: โมดูลพวกนี้ require พี่น้องด้วย script.Parent และ Edit แคช require ข้ามการรัน
local RS = game.ReplicatedStorage
local temp = Instance.new("Folder")
temp.Name = "FarmLevelTest_" .. math.random(1, 1e9)
temp.Parent = RS
local NAMES = { "CraftConfig", "ShopConfig", "MailConfig", "PremiumConfig", "ItemCatalog", "IslandConfig", "GatherConfig",
	"GoldBorder", "QuestConfig", "FarmLevelConfig", "ExportConfig", "ExportOrders", "PetRules" }
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
	check(mono and #F.ExpTable >= F.MaxLevel - 1, "ตาราง EXP เพิ่มขึ้นเสมอ ยาวถึงเพดาน")
	local l, into, need = F.LevelFromExp(0)
	check(l == 1 and into == 0 and need == F.ExpTable[1], "EXP 0 = Lv1 เริ่มศูนย์")
	check(F.LevelFromExp(F.ExpForLevel(2) - 1) == 1 and F.LevelFromExp(F.ExpForLevel(2)) == 2 and F.LevelFromExp(F.ExpForLevel(3)) == 3, "เส้นแบ่งเลเวลตรงกับ ExpForLevel")
	check(F.LevelFromExp(F.ExpForLevel(10) - 1) == 9 and F.LevelFromExp(F.ExpForLevel(10)) == 10, "Lv10 ที่ EXP สะสมของมันพอดี")
	local n = #F.ExpTable
	check(F.ExpToNext(n + 1) == F.ExpTable[n] + F.ExpStepAfter, "เลยตารางใช้สูตรต่อ")
	-- เพดานเลเวล (ผู้ใช้สั่ง 2026-09-27: ขยายเป็น 50 เลเวล) — ตาราง 50 ขั้นเทสด้วยเพดาน MaxLevel ตรงๆ
	local MAX = F.MaxLevel
	check(F.MaxLevel == 50 and F.IsMax(50, MAX) and not F.IsMax(49, MAX) and #F.ExpTable == 49, "เพดานเลเวล 50 · ตาราง EXP 49 ขั้น")
	local capExp = F.ExpForLevel(F.MaxLevel)
	local ml, mi, mn = F.LevelFromExp(capExp * 3, MAX)
	check(ml == 50 and mi == mn, "EXP เกินเพดาน = Lv50 หลอดเต็ม")
	check(F.LevelFromExp(capExp - 1, MAX) == 49 and F.LevelFromExp(capExp, MAX) == 50, "ถึง Lv50 ที่ EXP สะสมของมันพอดี")
	if not F.BankExpAtMax then
		check(F.AddExp(capExp - 10, 500, MAX) == capExp and F.AddExp(capExp, 500, MAX) == capExp, "ตันแล้ว EXP หยุดที่เส้นเพดาน")
	end
	check(F.AddExp(100, 50) == 150 and F.AddExp(capExp * 2, 10) >= capExp * 2, "AddExp ไม่มีวันลด")
	check(F.LastUnlockLevel() <= F.MaxLevel, "ตารางปลดไม่เกินเพดาน")
	check(F.LevelFromExp(-5) == 1 and F.LevelFromExp(0 / 0) == 1 and F.LevelFromExp("x") == 1, "EXP แปลกๆ = Lv1")
	check(F.LevelFromExp(1e15, MAX) == F.MaxLevel, "EXP มหาศาลไม่วนไม่จบ")
	-- **เปิดถึง Lv20 ไปก่อน** (ผู้ใช้สั่ง 2026-09-28) — ในเกมตันที่ 20 ทั้งที่ตารางยาว 50
	local open = F.Ceiling()
	local line = F.ExpForLevel(open)
	check(open == 20 and F.IsMax(20) and not F.IsMax(19), "เปิดถึง Lv20 (ตัน Lv20 ในเกม)")
	check(F.LevelFromExp(capExp) == 20 and select(2, F.LevelFromExp(capExp)) == select(3, F.LevelFromExp(capExp)),
		"EXP เกินเส้น 20 (แอดมินที่เทสไว้) = Lv20 หลอดเต็ม")
	check(F.AddExp(line - 10, 500) == line and F.AddExp(line, 500) == line, "ถึง Lv20 แล้ว EXP หยุดที่เส้น 20")
	check(F.AddExp(capExp, 500) == capExp, "EXP ที่มีอยู่เกินเส้นไม่ถูกหักทิ้ง (รอวันเปิดเพิ่ม)")

	----------------------------------------------------------------- สิ่งที่ปลด
	check(F.HouseCap(1) == 0 and F.HouseCap(3) == 0 and F.HouseCap(4) == 1 and F.HouseCap(15) == 1
		and F.HouseCap(16) == 2 and F.HouseCap(26) == 3 and F.HouseCap(36) == 4 and F.HouseCap(46) == 5 and F.HouseCap(50) == 5,
		"เพดานบ้าน 0 → Lv4 1 → Lv16 2 → Lv26 3 → Lv36 4 → Lv46 5 (ไม่เกิน 5)")
	check(F.PetCap(1) == 0 and F.PetCap(2) == 1 and F.PetCap(9) == 1 and F.PetCap(10) == 2 and F.PetCap(20) == 3
		and F.PetCap(32) == 4 and F.PetCap(48) == 4 and F.PetCap(49) == 5 and F.PetCap(50) == 5,
		"เพดานสัตว์เลี้ยง Lv2 1 → Lv10 2 → Lv20 3 → Lv32 4 → Lv49 5")
	-- คอกสัตว์ = จำนวนชนิดสัตว์ในคอกที่ปลดแล้ว (ผู้ใช้สั่ง 2026-10-02): ไก่+เป็ด Lv2 · หมู 5 · แพะ+วัว 8 · แกะ 13 · กวาง+ม้า 17
	check(F.PenCap(1) == 0 and F.PenCap(2) == 2 and F.PenCap(4) == 2 and F.PenCap(5) == 3 and F.PenCap(8) == 5
		and F.PenCap(13) == 6 and F.PenCap(16) == 6 and F.PenCap(17) == 8 and F.PenCap(50) == 8,
		"เพดานคอก Lv2 2 → Lv5 3 → Lv8 5 → Lv13 6 → Lv17 8")
	check(F.IsPen("AnimalPen") and not F.IsPen("FarmPlot") and F.NextCapLevel(F.PenCapLevels, 5) == 8, "รู้จักคอก · เลเวลเพดานคอกถัดไป")
	check(F.NextCapLevel(F.PetCapLevels, 5) == 10 and F.NextCapLevel(F.HouseCapLevels, 46) == nil, "เลเวลเพดานถัดไป")
	local g1, g2, g9, g20 = F.GlowAllowed(1), F.GlowAllowed(2), F.GlowAllowed(9), F.GlowAllowed(20)
	check(not g1.blue and not g1.gold and not g1.red, "Lv1 ไม่มีแสง")
	check(g2.blue and not g2.gold and not g2.red and not F.GlowAllowed(8).gold, "Lv2 แสงฟ้า")
	check(g9.blue and g9.gold and not g9.red and g20.red and not F.GlowAllowed(19).red, "Lv9 ทอง · Lv20 แดง")
	check(not F.GoldAllowed(3) and F.GoldAllowed(4), "ขอบทอง Lv4")
	check(F.IsHouse("House_Longhouse") and not F.IsHouse("AnimalPen"), "รู้จักบ้าน")
	check(F.IsPet("Pet_Dog") and F.IsPet("Pet_StoneGolem") and not F.IsPet("AnimalPen") and not F.IsPet(nil), "รู้จักสัตว์เลี้ยง")

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
	check(names(IslandConfig.CropsFor("Seed", 4)) == "Vegetable,Wheat" and names(IslandConfig.CropsFor("Seed", 5)) == "MagicBranch,Vegetable,Wheat",
		"Lv5 + ต้นเวท (ผู้ใช้สั่ง 2026-10-02 · เดิม 28)")
	check(names(IslandConfig.CropsFor("Seed", 6)) == "Herb,MagicBranch,Vegetable,Wheat"
		and names(IslandConfig.CropsFor("Seed", 28)) == "Herb,MagicBranch,Vegetable,Wheat", "Lv6 + สมุนไพร · เมล็ดสุ่มไม่เคยได้ฝ้าย")
	check(#IslandConfig.CropsFor("CottonSeed", 9) == 0 and names(IslandConfig.CropsFor("CottonSeed", 10)) == "Cotton",
		"เมล็ดฝ้ายใช้ได้ Lv10 ได้ฝ้ายอย่างเดียว")
	check(names(IslandConfig.CropsFor("Seed", nil)) == "Herb,MagicBranch,Vegetable,Wheat", "ไม่รู้เลเวล = ไม่ล็อก")
	check(GoldBorder.CropItems.Cotton == true, "ฝ้ายมีขอบทองได้")

	local function has(level, text)
		for _, row in ipairs(F.UnlocksAt(level)) do
			if row.text:find(text, 1, true) then return true end
		end
		return false
	end
	check(has(1, "รถส่งออก") and has(1, "แปลงดิน") and has(2, "แสงฟ้า") and has(2, "ไก่ (คอก)")
		and has(2, "ไก่ (สัตว์เลี้ยง)"), "ตารางปลด Lv1-2")
	check(has(3, "เตาอบขนมปัง") and has(4, "ขอบทอง") and has(4, "มีบ้านได้ 1") and has(4, "กระท่อมหิน")
		and has(4, "สุนัข") and has(4, "แมว"), "ตารางปลด Lv3-4")
	check(has(6, "โซนแร่") and has(10, "กี่ทอผ้าไอน้ำ") and has(10, "เมล็ดฝ้าย") and has(10, "สัตว์เลี้ยงได้ 2")
		and has(16, "โซนแร่: แร่เงิน") and has(20, "แสงแดง") and has(21, "สไลม์พลาสมา") and has(50, "โกเลมหิน"),
		"ตารางปลด Lv6-50")
	check(has(3, "มอนบุกตอนกลางคืน") and has(10, "มอนกลางคืนโหดขึ้น") and has(20, "มอนกลางคืนโหดขึ้น"),
		"🌙 มอนบุกกลางคืน Lv3 · โหดขึ้น Lv10/Lv20 (2026-09-28)")
	check(not has(2, "สัตว์เลี้ยงได้ 1"), "ช่องสัตว์เลี้ยงช่องแรกไม่ขึ้นเป็นแถวแยก (มาพร้อมไก่/เป็ด)")
	-- **3-6 อย่างต่อเลเวล ไม่เกิน 6 · ของไม่พอ = ช่วงหลังลดหลั่นลง แต่ทุกเลเวลมีอะไรปลด** (ผู้ใช้สั่ง 2026-09-27)
	local bad, perLevel, total = {}, {}, 0
	for level = 1, F.MaxLevel do
		local n = #F.UnlocksAt(level)
		perLevel[level] = n
		total += n
		if n < 1 or n > 6 then bad[#bad + 1] = ("Lv%d=%d"):format(level, n) end
	end
	check(#bad == 0, ("ทุกเลเวล 1-50 ปลด 1-6 อย่าง (รวม %d) %s"):format(total, table.concat(bad, ",")))
	local early = 0
	for level = 1, 10 do early += perLevel[level] end
	check(early >= 40 and perLevel[1] <= 6, ("ช่วงแรกปลดเยอะ: Lv1-10 รวม %d อย่าง"):format(early))
	check(F.LastUnlockLevel() == F.MaxLevel and #F.UnlocksAt(F.MaxLevel + 1) == 0, "ตารางยาวถึง Lv50 พอดี ไม่มีของเกินเพดาน")

	----------------------------------------------------------------- สูตรเครื่องคราฟ
	local machineLevel = {}
	for _, row in ipairs(ShopConfig.IslandSells) do machineLevel[row.id] = row.level end
	local STATION_MACHINE = { bakery = "BakeryOven", metal = "MetalBench", loom = "Loom" }
	-- เตาทำอาหารใช้ทั้งเกมหลักและเกาะ — นับเป็นสูตรเกาะเฉพาะแถวที่มี `level` (สูตรเชฟเกมหลักไม่มี) · ข้าวโพดย่างเนย 2026-10-02
	local function machineOf(recipe)
		return STATION_MACHINE[recipe.station or ""] or (recipe.level and recipe.station == "stove" and "Stove") or nil
	end
	-- เลเวลที่ของดิบแต่ละชิ้นเริ่มผลิตได้บนเกาะ (ตรงกับตารางปลด)
	-- ตาราง 50 เลเวล (2026-09-27): ไข่ ไก่/เป็ด 2 · เนื้อ หมู 5 · สมุนไพร/เหล็ก/ถ่าน โซนแร่+สายถ่าน 6 · นม 8 · ฝ้าย 10 ·
	-- ขนแกะ 13 · แร่เงิน สายแร่เงิน 15 · หนัง 17 · คริสตัล 22 · กิ่งเวท 5 (2026-10-02 · เดิม 28) · แร่ทอง 30 · แร่เวท 40 · เพชร 45 · ข้าวโพด 15 · อ้อย 17
	local RAW = { Wheat = 1, Vegetable = 1, Egg = 2, Meat = 5, Herb = 6, IronOre = 6, Coal = 6, Milk = 8, Cotton = 10,
		Wool = 13, SilverOre = 15, Leather = 17, Crystal = 22, MagicBranch = 5, GoldOre = 30, MagicOre = 40, Diamond = 45,
		Corn = 15, Sugarcane = 17 }
	-- ของดิบต้องปลดที่ต้นทางจริง (ร้าน/คอก/พืช) ไม่เกินเลเวลใน RAW — กันแก้ตารางฝั่งเดียว
	local sourceLevel = {}
	local function source(id, level) sourceLevel[id] = math.min(sourceLevel[id] or 99, level) end
	for _, row in ipairs(ShopConfig.IslandSells) do
		local wild = { Wild_Coal = "Coal", Wild_IronOre = "IronOre", Wild_SilverOre = "SilverOre", Wild_Crystal = "Crystal",
			Wild_GoldOre = "GoldOre", Wild_MagicOre = "MagicOre", Wild_DiamondOre = "Diamond", Seed = "Wheat", CottonSeed = "Cotton",
			CornSeed = "Corn", SugarcaneSeed = "Sugarcane" }
		if wild[row.id] then source(wild[row.id], row.level) end
		if row.id == "Seed" then source("Vegetable", row.level) end
		if row.id == "MineZone" then source("IronOre", row.level) end
	end
	local PRODUCE = { Chicken = "Egg", Duck = "Egg", Pig = "Meat", Goat = "Milk", Cow = "Milk", Sheep = "Wool",
		Deer = "Leather", Horse = "Leather" }
	for _, a in ipairs(IslandConfig.PenAnimals) do source(PRODUCE[a.kind], a.level) end
	for _, c in ipairs(IslandConfig.Crops) do if not c.seed then source(c.item, c.level) end end
	local rawProblems = {}
	for id, at in pairs(RAW) do
		if (sourceLevel[id] or 99) ~= at then rawProblems[#rawProblems + 1] = ("%s:RAW %d แต่ต้นทาง %s"):format(id, at, tostring(sourceLevel[id])) end
	end
	check(#rawProblems == 0, "ของดิบปลดตรงกับต้นทางจริง " .. table.concat(rawProblems, " | "))
	local made, final = {}, {}
	for _, good in ipairs(ExportConfig.Goods) do if good.final then final[good.id] = true end end
	local recipeProblems = {}
	for index, recipe in ipairs(CraftConfig.Recipes) do
		local machine = machineOf(recipe)
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
		if machineOf(recipe) then
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
	for level = 1, F.MaxLevel do
		local rng = Random.new(level * 7919)
		local band
		for _, b in ipairs(ExportConfig.LineBands) do if level <= b.upTo then band = b break end end
		for n = 1, 120 do
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
	check(#orderProblems == 0, "ใบธรรมดา Lv1-50 × 120 ใบถูกกติกา " .. table.concat(orderProblems, " | "))
	check(EO.Target(1) == 300 and EO.Target(10) == 1380 and EO.Target(20) == 2580 and EO.Target(50) == 3780,
		"มูลค่าใบ Lv1 300 · Lv10 1,380 · Lv20 2,580 · หลังจากนั้นโตช้าลง Lv50 3,780")
	local rng = Random.new(42)
	local avg1, avg10 = 0, 0
	for _ = 1, 200 do avg1 += EO.NewOrder(1, rng, 1).exp; avg10 += EO.NewOrder(10, rng, 1).exp end
	avg1, avg10 = avg1 / 200, avg10 / 200
	check(avg1 >= 40 and avg1 <= 100 and avg10 >= 200 and avg10 <= 450,
		("EXP เฉลี่ยต่อใบ Lv1 %.0f (≈2 ใบถึง Lv2) · Lv10 %.0f"):format(avg1, avg10))

	-- **จังหวะเลเวล** (ผู้ใช้สั่ง 2026-09-27): "Lv50 ประมาณ 4-6 เดือน และช่วงแรกๆ ต้องง่ายเข้าไว้"
	-- จำลองส่งทีละใบ (เลือกสุ่มจาก 3 ใบ ใบที่ส่งถูกแทนด้วยใบใหม่) 25 รอบ เฉลี่ยจำนวนใบที่ต้องส่งถึงแต่ละเลเวล
	local reach = { [2] = 0, [3] = 0, [4] = 0, [5] = 0, [10] = 0, [20] = 0, [30] = 0, [40] = 0, [50] = 0 }
	local TRIALS = 25
	for trial = 1, TRIALS do
		local r = Random.new(trial * 131)
		local exp, count = 0, 0
		local slots = { EO.NewOrder(1, r, 1), EO.NewOrder(1, r, 2), EO.NewOrder(1, r, 3) }
		local got = {}
		while not got[50] and count < 5000 do
			local pick = r:NextInteger(1, 3)
			exp = F.AddExp(exp, slots[pick].exp, F.MaxLevel) -- จำลองตาราง 50 เลเวลเต็ม (ไม่ใช่เพดานที่เปิดตอนนี้)
			count += 1
			local lv = F.LevelFromExp(exp, F.MaxLevel)
			for target in pairs(reach) do if not got[target] and lv >= target then got[target] = count end end
			local others = {}
			for s = 1, 3 do if s ~= pick then others[#others + 1] = slots[s] end end
			slots[pick] = EO.Fresh(lv, r, count + 3, others)
		end
		for target in pairs(reach) do reach[target] += (got[target] or 5000) / TRIALS end
	end
	check(reach[2] <= 2 and reach[3] <= 4 and reach[4] <= 8 and reach[5] <= 12 and reach[10] <= 60,
		("ช่วงแรกขึ้นง่าย: Lv2 %.1f · Lv3 %.1f · Lv4 %.1f · Lv5 %.1f · Lv10 %.0f ใบ"):format(reach[2], reach[3], reach[4],
			reach[5], reach[10]))
	local days8 = reach[50] / 8
	check(days8 >= 120 and days8 <= 180 and reach[20] < reach[30] and reach[30] < reach[40],
		("ถึง Lv50 ใช้ %.0f ใบ = วันละ 8 ใบ %.0f วัน (%.1f เดือน) · Lv20 %.0f วัน · Lv30 %.0f · Lv40 %.0f"):format(
			reach[50], days8, days8 / 30, reach[20] / 8, reach[30] / 8, reach[40] / 8))

	-- ของยากขึ้นตามเลเวล: Lv10 ข้าว/ผัก/ไข่ แทบไม่ออก · Lv15 ของขั้นสุดท้ายออกบ่อยกว่า Lv5
	local function mix(level)
		local r, basic, finals, lines = Random.new(level * 17), 0, 0, 0
		local byItem = {}
		for i = 1, 1500 do
			for _, line in ipairs(EO.NewOrder(level, r, i).lines) do
				local g = ExportConfig.Get(line.item)
				lines += 1
				if g.level <= 2 then basic += 1 end
				if g.final then finals += 1 end
				byItem[line.item] = (byItem[line.item] or 0) + 1
			end
		end
		local top = 0
		for _, c in pairs(byItem) do top = math.max(top, c) end
		return basic / lines, finals / lines, top / lines
	end
	local b5, f5 = mix(5)
	local b10 = mix(10)
	local b30 = mix(30)
	local b50, f50, top50 = mix(50)
	check(b10 < b5 and b30 < 0.04 and b50 < 0.04 and f50 > f5 and top50 < 0.3,
		("ของพื้นฐาน Lv5 %.0f%% → Lv10 %.0f%% → Lv30 %.0f%% → Lv50 %.0f%% · ขั้นสุดท้าย Lv5 %.0f%% → Lv50 %.0f%% · ชิ้นเดียวมากสุด Lv50 %.0f%%"):format(
			b5 * 100, b10 * 100, b30 * 100, b50 * 100, f5 * 100, f50 * 100, top50 * 100))

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

	----------------------------------------------------------------- สัตว์เลี้ยง (เฟส 2d)
	local PetRules = require(temp.PetRules)
	local GatherConfig = require(temp.GatherConfig)
	local shopLevel = {}
	for _, row in ipairs(ShopConfig.IslandSells) do shopLevel[row.id] = row.level end
	local petProblems, speciesCount = {}, 0
	for id, spec in pairs(IslandConfig.PetSpecies) do
		speciesCount += 1
		local item = ItemCatalog.Get(id)
		if not item or not item.pet or item.kind ~= "placeable" or item.stackSize ~= 1 then
			petProblems[#petProblems + 1] = id .. ":แคตตาล็อก"
		end
		if not shopLevel[id] then petProblems[#petProblems + 1] = id .. ":ไม่มีในร้าน" end
		if not IslandConfig.PetGrowth[spec.group] then petProblems[#petProblems + 1] = id .. ":กลุ่มการโต" end
		if spec.mob and not GatherConfig.Mobs[spec.mob] then petProblems[#petProblems + 1] = id .. ":ไม่มีมอน " .. spec.mob end
		if spec.produce and not GatherConfig.Nodes[spec.produce] then petProblems[#petProblems + 1] = id .. ":ไม่มีสัตว์ " .. spec.produce end
		if spec.group ~= "dogcat" and #PetRules.Drops(id) == 0 then petProblems[#petProblems + 1] = id .. ":ไม่มีของดรอป" end
		if spec.group == "dogcat" and #PetRules.Drops(id) ~= 0 then petProblems[#petProblems + 1] = id .. ":หมา/แมวต้องไม่ดรอป" end
		for _, d in ipairs(PetRules.Drops(id)) do
			if ItemCatalog.Get(d.item).kind ~= "junk" then petProblems[#petProblems + 1] = id .. ":ดรอปของที่ไม่ใช่วัตถุดิบ " .. d.item end
		end
	end
	for id, item in pairs(ItemCatalog.Items or {}) do
		if type(item) == "table" and item.pet and not IslandConfig.PetSpecies[id] then petProblems[#petProblems + 1] = id .. ":ไม่มีข้อมูลสัตว์" end
	end
	check(#petProblems == 0 and speciesCount == 24, ("สัตว์เลี้ยง %d ชนิด ครบร้าน/แคตตาล็อก/ของดรอป %s"):format(speciesCount,
		table.concat(petProblems, " | ")))
	check(IslandConfig.PetPatsToGrow("Pet_GreenSlime") == 20 and IslandConfig.PetPatsToGrow("Pet_Dog") == 20
		and IslandConfig.PetPatsToGrow("Pet_Cow") == 50 and IslandConfig.PetPatsToGrow("Pet_Wolf") == 100
		and IslandConfig.PetPatsToGrow("Pet_Skeleton") == 200, "ลูบถึงโต: หมา/แมว/สไลม์ 20 · ฟาร์ม 50 · ป่า 100 · คน 200")
	check(IslandConfig.PetPats("Pet_Dog", nil) == 20 and IslandConfig.PetPats("Pet_Cat", nil) == 20
		and IslandConfig.PetPats("Pet_Dog", 0) == 0 and IslandConfig.PetPats("Pet_Chicken", nil) == 0
		and IslandConfig.PetPats("Pet_Wolf", 0 / 0) == 0 and IslandConfig.PetPats("Pet_Wolf", -4) == 0,
		"หมา/แมวรุ่นเก่า (ไม่มีค่า) = โตแล้ว · ตัวใหม่เริ่ม 0 · ค่าแปลก = 0")
	check(math.abs(IslandConfig.PetSizeFraction("Pet_Wolf", 0) - 0.3) < 1e-6 and IslandConfig.PetSizeFraction("Pet_Wolf", 100) == 1
		and IslandConfig.PetSizeFraction("Pet_Wolf", 500) == 1 and math.abs(IslandConfig.PetSizeFraction("Pet_Wolf", 50) - 0.65) < 1e-6,
		"ขนาด 30% → เต็มวัย ไม่เกินเต็มวัย")
	-- **ให้วัตถุดิบเดียวกัน = ปลดเลเวลเดียวกัน · เลเวลหนึ่งปลดสัตว์เลี้ยงได้กลุ่มเดียว · สัตว์คอกก็เช่นกัน** (ผู้ใช้สั่ง)
	local sigAtLevel, sigLevel, groupProblems = {}, {}, {}
	for id in pairs(IslandConfig.PetSpecies) do
		local lv, sig = shopLevel[id], PetRules.Signature(id)
		sigAtLevel[lv] = sigAtLevel[lv] or {}
		sigAtLevel[lv][sig] = true
		if sigLevel[sig] and sigLevel[sig] ~= lv then groupProblems[#groupProblems + 1] = sig .. ":คนละเลเวล" end
		sigLevel[sig] = lv
	end
	for lv, sigs in pairs(sigAtLevel) do
		local n = 0
		for _ in pairs(sigs) do n += 1 end
		if n > 1 then groupProblems[#groupProblems + 1] = ("Lv%d:%d กลุ่ม"):format(lv, n) end
	end
	local penAt = {}
	for _, a in ipairs(IslandConfig.PenAnimals) do
		local item = GatherConfig.Nodes[a.kind].item
		penAt[a.level] = penAt[a.level] or item
		if penAt[a.level] ~= item then groupProblems[#groupProblems + 1] = ("คอก Lv%d ให้ของต่างกัน"):format(a.level) end
		if shopLevel["Pet_" .. a.kind] ~= a.level then groupProblems[#groupProblems + 1] = a.kind .. ":สัตว์เลี้ยงคนละเลเวลกับคอก" end
	end
	check(#groupProblems == 0, "ปลดทีละกลุ่มวัตถุดิบ ทั้งสัตว์เลี้ยงและคอก " .. table.concat(groupProblems, " | "))
	local pr = Random.new(5)
	local counts, dropProblems = {}, {}
	for _ = 1, 3000 do
		local got, n = PetRules.Roll("Pet_Skeleton", pr), 0
		for item, c in pairs(got) do
			n += c
			if item ~= "Bone" and item ~= "IronOre" then dropProblems[#dropProblems + 1] = item end
		end
		counts[n] = (counts[n] or 0) + 1
	end
	check(#dropProblems == 0 and (counts[0] or 0) == 0 and (counts[6] or 0) == 0 and counts[1] and counts[5]
		and counts[2] > counts[1] and next(PetRules.Roll("Pet_Dog", pr)) == nil,
		("ลูบได้ 1-5 ชิ้น (1:%d 2:%d 3:%d 4:%d 5:%d) · หมาไม่ดรอป"):format(counts[1] or 0, counts[2] or 0, counts[3] or 0,
			counts[4] or 0, counts[5] or 0))
	check(PetRules.Signature("Pet_Chicken") == "Egg" and PetRules.Signature("Pet_Boar") == PetRules.Signature("Pet_Pig")
		and PetRules.Signature("Pet_SteamSlime") == PetRules.Signature("Pet_BioSlime"), "ไก่ = ไข่ · หมูป่า = หมู · สไลม์พิเศษชุดเดียวกัน")
end)
check(ok, "ไม่มี error " .. tostring(err))
temp:Destroy()
return ("%s — %d fail\n%s"):format(fails == 0 and "PASS" or "FAIL", fails, table.concat(out, "\n"))
