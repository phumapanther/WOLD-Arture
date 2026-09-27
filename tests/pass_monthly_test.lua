-- node tools/lua.js tests/pass_monthly_test.lua Edit   (เพลสไหนก็ได้ — ข้อมูลล้วน)
-- แบทเทิลพาสรายเดือน (ผู้ใช้สั่ง 2026-09-27): ซีซัน = เดือนไทย · สายพรีเมียมขั้น 30 = กล่องเวท 10 + สกินอาวุธประจำเดือน ·
-- ขั้น 15 = หีบเงิน 10 + ออร่าประจำเดือน · สุ่มใหม่ทุกเดือน (เดือนติดกันไม่ซ้ำ)
local RS = game.ReplicatedStorage
local temp = Instance.new("Folder")
temp.Name = "PassTest_" .. math.random(1, 1e9)
temp.Parent = RS
for _, name in ipairs({ "PremiumConfig", "CraftConfig", "ShopConfig", "MailConfig", "ItemCatalog" }) do
	RS[name]:Clone().Parent = temp
end
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local ok, err = pcall(function()
	local P = require(temp.PremiumConfig)
	local ItemCatalog = require(temp.ItemCatalog)
	local TZ = 7 * 3600
	-- เวลาไทย → os.time (os.time ของตาราง = UTC ใน Roblox)
	local function thai(y, m, d, h, mi)
		return os.time({ year = y, month = m, day = d, hour = h, min = mi or 0, sec = 0 }) - TZ
	end
	check(P.PassSeason(thai(2026, 9, 15, 12)) == 1, "กันยายน 2026 = ซีซัน 1 (ความคืบหน้าเดิมอยู่ต่อ)")
	check(P.PassSeason(thai(2026, 9, 30, 23, 59)) == 1 and P.PassSeason(thai(2026, 10, 1, 0, 0)) == 2,
		"พลิกซีซันตอนเที่ยงคืนวันที่ 1 เวลาไทย")
	check(P.PassSeason(thai(2027, 1, 1, 0, 1)) == 5 and P.PassSeason(thai(2027, 12, 31, 23)) == 16, "ข้ามปีนับต่อถูก")
	check(P.PassSeasonEnds(1) == thai(2026, 10, 1, 0, 0) and P.PassSeasonEnds(4) == thai(2027, 1, 1, 0, 0),
		"ซีซันจบตอนเที่ยงคืนวันที่ 1 เดือนถัดไป")
	check(P.PassName(1):find("กันยายน 2569", 1, true) ~= nil and P.PassName(5):find("มกราคม 2570", 1, true) ~= nil,
		"ชื่อพาส " .. P.PassName(1) .. " / " .. P.PassName(5))

	local problems = {}
	for _, kind in ipairs({ "weapon", "aura" }) do
		local pool = P.GachaById(kind).pool
		local seenAll, prev = {}, nil
		for season = 1, #pool * 3 do
			local id = P.PassMonthlyItem(season, kind)
			if not id or not table.find(pool, id) then problems[#problems + 1] = kind .. ":ของนอกสระ " .. tostring(id) end
			if id == prev then problems[#problems + 1] = ("%s:ซีซัน %d ซ้ำเดือนก่อน"):format(kind, season) end
			if season <= #pool then seenAll[id] = true end
			prev = id
			if P.PassMonthlyItem(season, kind) ~= id then problems[#problems + 1] = kind .. ":สุ่มไม่คงที่" end
		end
		local n = 0
		for _ in pairs(seenAll) do n += 1 end
		if n ~= #pool then problems[#problems + 1] = ("%s:%d เดือนแรกได้ %d/%d แบบ"):format(kind, #pool, n, #pool) end
		local want = kind == "weapon" and "skin" or "aura"
		for _, id in ipairs(pool) do
			local item = ItemCatalog.Get(id)
			if not item or item.kind ~= want then problems[#problems + 1] = id .. ":ไม่ใช่ " .. want end
		end
	end
	check(#problems == 0, "ของประจำเดือน: อยู่ในสระ · เดือนติดกันไม่ซ้ำ · วนครบทุกแบบก่อนซ้ำ " .. table.concat(problems, " | "))

	local r30 = P.PassRewards(3, "premium", 30)
	local r15 = P.PassRewards(3, "premium", 15)
	check(#r30 == 2 and r30[1].item == "MagicBox" and r30[1].count == 10 and r30[2].monthly and r30[2].item == P.PassMonthlyItem(3, "weapon"),
		"พรีเมียมขั้น 30 = กล่องเวท 10 + สกินอาวุธประจำเดือน")
	check(#r15 == 2 and r15[1].item == "Chest_Silver" and r15[2].monthly and r15[2].item == P.PassMonthlyItem(3, "aura"),
		"พรีเมียมขั้น 15 = หีบเงิน 10 + ออร่าประจำเดือน")
	check(#P.PassRewards(3, "free", 30) == 1 and #P.PassRewards(3, "free", 15) == 1 and #P.PassRewards(3, "premium", 14) == 1,
		"สายฟรีและขั้นอื่นได้ของเดียวเหมือนเดิม")
	check(P.PassRewards(1, "premium", 30)[2].item ~= P.PassRewards(2, "premium", 30)[2].item, "เดือนหน้าได้สกินคนละแบบ")
end)
check(ok, "ไม่มี error " .. tostring(err))
temp:Destroy()
return ("%s — %d fail\n%s"):format(fails == 0 and "PASS" or "FAIL", fails, table.concat(out, "\n"))
