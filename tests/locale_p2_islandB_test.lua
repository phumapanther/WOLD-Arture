-- node tools/offline-test.js tests/locale_p2_islandB_test.lua
-- หลายภาษาเฟส 2 กลุ่ม islandB (แปลงผัก/เมล็ด · เลเวลฟาร์ม · รถส่งออก): ไทยเหมือนเดิมทุกไบต์ + ย้อนแปลได้ทั้งประโยค
local L = require(game.ReplicatedStorage.Locale)
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text if not ok then fails += 1 end end
local function tr(lang, text, want, label)
	local got = L.Translate(lang, text)
	check(got == want, label .. ": " .. tostring(got))
end
local function commas(n)
	local s = tostring(math.floor(n))
	repeat local k; s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
	return s
end
local grain = { en = L.T("en", "ข้าว"), zh = L.T("zh", "ข้าว"), ja = L.T("ja", "ข้าว") }

-- IslandPlots: เก็บเกี่ยว (เดิม %s x%d%s + ส่วนต่อท้าย) → สองแม่แบบ
for _, gold in ipairs({ true, false }) do
	local old = ("เก็บเกี่ยวได้ %s x%d%s"):format("ข้าว", 4, gold and " (🌟 ขอบทอง 1 ชิ้น)" or "")
	local new = (gold and "เก็บเกี่ยวได้ %s x%d (🌟 ขอบทอง 1 ชิ้น)" or "เก็บเกี่ยวได้ %s x%d"):format("ข้าว", 4)
	check(old == new, "เก็บเกี่ยว ไทยเท่าเดิม (ทอง=" .. tostring(gold) .. ")")
end
tr("en", "เก็บเกี่ยวได้ ข้าว x4 (🌟 ขอบทอง 1 ชิ้น)", ("Harvested %s x4 (🌟 1 gold-rimmed)"):format(grain.en), "เก็บเกี่ยวทอง en")
tr("en", "เก็บเกี่ยวได้ ข้าว x4", ("Harvested %s x4"):format(grain.en), "เก็บเกี่ยว en")

-- IslandPlots: ป้ายปุ่ม (เดิม name .. " · สุกแล้ว")
check(("%s · สุกแล้ว"):format("ข้าว") == "ข้าว" .. " · สุกแล้ว", "ObjectText สุกแล้ว ไทยเท่าเดิม")
tr("ja", "ข้าว · สุกแล้ว", ("%s · 収穫どき"):format(grain.ja), "สุกแล้ว ja")
tr("zh", "ข้าว · เหลือ 12 นาที", ("%s · 剩余 12 分钟"):format(grain.zh), "เหลือ N นาที zh")
tr("en", "เจอหนอน x2 ในดิน", "Found Worm x2 in the soil", "หนอนในดิน en")
tr("ja", "หยอดเมล็ดแล้ว — ขึ้นเป็นข้าว ใช้เวลา 15 นาที", ("種をまきました — %sに育つまで 15 分"):format(grain.ja), "หยอดเมล็ด ja")

-- IslandFarm: รถกลับ (เดิมต่อ " · +%d 💎" ด้วย ..) → สี่แม่แบบ
for _, case in ipairs({ { false, 0 }, { false, 3 }, { true, 0 }, { true, 2 } }) do
	local wasMax, gems, coins, exp = case[1], case[2], 12500, 1340
	local old = wasMax and ("🚚 รถส่งออกกลับมาแล้ว! +%s เหรียญ · ฟาร์มเลเวลสูงสุดแล้ว"):format(commas(coins))
		or ("🚚 รถส่งออกกลับมาแล้ว! +%s เหรียญ · +%s EXP ฟาร์ม"):format(commas(coins), commas(exp))
	if gems > 0 then old ..= (" · +%d 💎"):format(gems) end
	local new
	if wasMax then
		new = gems > 0 and ("🚚 รถส่งออกกลับมาแล้ว! +%s เหรียญ · ฟาร์มเลเวลสูงสุดแล้ว · +%d 💎"):format(commas(coins), gems)
			or ("🚚 รถส่งออกกลับมาแล้ว! +%s เหรียญ · ฟาร์มเลเวลสูงสุดแล้ว"):format(commas(coins))
	else
		new = gems > 0 and ("🚚 รถส่งออกกลับมาแล้ว! +%s เหรียญ · +%s EXP ฟาร์ม · +%d 💎"):format(commas(coins), commas(exp), gems)
			or ("🚚 รถส่งออกกลับมาแล้ว! +%s เหรียญ · +%s EXP ฟาร์ม"):format(commas(coins), commas(exp))
	end
	check(old == new, ("รถกลับ ไทยเท่าเดิม (max=%s gems=%d)"):format(tostring(wasMax), gems))
end
tr("en", "🚚 รถส่งออกกลับมาแล้ว! +12,500 เหรียญ · +1,340 EXP ฟาร์ม · +3 💎",
	"🚚 Export truck is back! +12,500 coins · +1,340 farm EXP · +3 💎", "รถกลับ + เพชร en")
tr("zh", "🚚 รถส่งออกกลับมาแล้ว! +12,500 เหรียญ · ฟาร์มเลเวลสูงสุดแล้ว",
	"🚚 出口货车回来了！+12,500 金币 · 农场已达最高等级", "รถกลับ ตันแล้ว zh")
tr("en", "ของไม่ครบ: ข้าว 3/5", ("Not enough: %s 3/5"):format(grain.en), "ของไม่ครบ en")

-- FarmLevelConfig: แถวตารางปลด (เดิม prefix .. ชื่อ) → แม่แบบ %s · ไทยเท่าเดิม + ย้อนแปลได้
check(("%s (คอก)"):format("ไก่") == "ไก่" .. " (คอก)", "แถวคอก ไทยเท่าเดิม")
check(("สูตร: %s"):format("ข้าว") == "สูตร: " .. "ข้าว", "แถวสูตร ไทยเท่าเดิม")
check(("โซนแร่: %s"):format("แร่เหล็ก") == "โซนแร่: " .. "แร่เหล็ก", "แถวโซนแร่ ไทยเท่าเดิม")
tr("en", "โซนแร่: แร่เหล็ก", "Mining zone: Iron Ore", "โซนแร่ en")
tr("en", "สูตร: ข้าว", ("Recipe: %s"):format(grain.en), "สูตร en")
local ok, FLC = pcall(require, game.ReplicatedStorage.FarmLevelConfig)
if ok then
	local seen = 0
	for level = 1, FLC.MaxLevel do
		for _, row in ipairs(FLC.UnlocksAt(level)) do
			local en = L.Translate("en", row.text)
			if en == row.text then check(false, ("แถวปลด Lv%d ไม่มีคำแปล: %s"):format(level, row.text)) end
			seen += 1
		end
	end
	check(seen > 0, ("ตารางปลดทุกแถวแปลได้ (%d แถว)"):format(seen))
else
	check(true, "ข้าม UnlocksAt (โหลด FarmLevelConfig ในตัวจำลองไม่ได้: " .. tostring(FLC) .. ")")
end

-- หน้าจอ (L ตรงๆ)
check(L.T("zh", "📦 ใบสั่งซื้อ %d", 2) == "📦 订单 2", "ใบสั่งซื้อ zh")
check(L.T("en", "เลเวล %d   <font color=\"#%s\">%s</font>", 5, "aabbcc", "x") == "Level 5   <font color=\"#aabbcc\">x</font>", "หัวเลเวล rich text en")
check(L.T("ja", "💎 ครบวันนี้แล้ว") == "💎 本日の上限です", "GemHint ja")
check(L.T("th", "🚚 ว่าง") == "🚚 ว่าง", "ไทยไม่แปล")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
