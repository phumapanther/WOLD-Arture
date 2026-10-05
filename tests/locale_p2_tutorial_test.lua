-- node tools/offline-test.js tests/locale_p2_tutorial_test.lua
-- สมุดสอนเล่น (TutorialConfig) แปลครบทุกบรรทัด · ไทยเหมือนเดิม · ตัวหนา ** และย่อหน้ารอดการแปล
local L = require(game.ReplicatedStorage.Locale)
local TC = require(game.ReplicatedStorage.TutorialConfig)
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text if not ok then fails += 1 end end

-- ทุกข้อความในสมุด (ชื่อสมุด · คำใบ้ · ชื่อหัวข้อ · บรรทัดเนื้อหา)
local texts = { TC.Title, TC.ButtonTooltip }
for _, section in ipairs(TC.Sections) do
	texts[#texts + 1] = section.title
	for _, line in ipairs(section.body) do
		if line ~= "" then texts[#texts + 1] = line end
	end
end
check(#texts > 300, "นับข้อความได้ " .. #texts)

local function count(s, p) local _, n = s:gsub(p, "") return n end
for _, lang in ipairs({ "en", "zh", "ja" }) do
	local missing, bold, indent = {}, 0, 0
	for _, th in ipairs(texts) do
		local tr = L.Translate(lang, th)
		if tr == th then missing[#missing + 1] = th end
		if count(tr, "%*%*") ~= count(th, "%*%*") then bold += 1 end
		if #tr:match("^ *") ~= #th:match("^ *") then indent += 1 end
	end
	check(#missing == 0, ("%s แปลครบ (ขาด %d: %s)"):format(lang, #missing, tostring(missing[1])))
	check(bold == 0, ("%s ตัวหนา ** ครบทุกบรรทัด (ไม่ตรง %d)"):format(lang, bold))
	check(indent == 0, ("%s ย่อหน้าเท่าต้นฉบับ (ไม่ตรง %d)"):format(lang, indent))
end

-- ไทยเหมือนเดิมเป๊ะ
local same = true
for _, th in ipairs(texts) do if L.Translate("th", th) ~= th or L.T("th", th) ~= th then same = false end end
check(same, "ภาษาไทยไม่เปลี่ยนสักบรรทัด")

local function tr(lang, th, want)
	local got = L.Translate(lang, th)
	check(got == want, ("%s %s → %s"):format(lang, th, got))
end
tr("en", "สอนเล่น", "Tutorial")
tr("en", "ปุ่มบังคับ (คอม)", "Controls (PC)")
tr("ja", "การตกปลา", "釣り")
tr("zh", "WASD — เดิน", "WASD — 移动")
-- บรรทัดที่มี % จริง (ไม่ใช่ตัวคั่น) ต้องย้อนแปลได้ตรงตัว
tr("en", "   ดาบ 50% · ดาบใหญ่ 25% · ปืน 25% · เกราะโซ่ 75%", "   Sword 50% · Greatsword 25% · Pistol 25% · Chainmail 75%")
tr("ja", "   หมา/แมว/สไลม์ 20 ครั้ง · สัตว์ฟาร์ม 50 · สัตว์ป่า 100 · มอนแบบคน 200 — ป้ายเหนือหัวบอก % ความโต",
	"   犬/猫/スライム 20 回 · 家畜 50 · 野生動物 100 · 人型モンスター 200 — 頭上の札に成長 % が出る")

-- ชื่อปุ่ม/ไอเทม/เมืองที่สมุดอ้างถึง ต้องตรงกับคำแปลของของจริงในเกม (ไม่งั้นผู้เล่นหาปุ่มไม่เจอ)
local QUOTE = { en = { "'", "'" }, zh = { "“", "”" }, ja = { "「", "」" } }
local function refers(th, label, quoted)
	for _, lang in ipairs({ "en", "zh", "ja" }) do
		local name = L.Translate(lang, label):gsub(" ?%(%%d%)$", ""):gsub("（%%d）$", "")
		if quoted then name = QUOTE[lang][1] .. name .. QUOTE[lang][2] end
		local line = L.Translate(lang, th)
		check(line:find(name, 1, true) ~= nil, ("%s อ้าง %s ตรงของจริง: %s"):format(lang, name, line))
	end
end
local towns = "แต่ละเมืองมีบอร์ดเควสของตัวเอง 6 เมือง (โกลด์เมโดว์ สโตนมาร์ก ซอลต์เมียร์ เอลเดอร์วูด ค็อกส์เวิร์ธ แอสตราเวล)"
for _, town in ipairs({ "โกลด์เมโดว์", "สโตนมาร์ก", "ซอลต์เมียร์", "เอลเดอร์วูด", "ค็อกส์เวิร์ธ", "แอสตราเวล" }) do refers(towns, town) end
refers("**แต่ความล้มเหลวไม่สูญเปล่า — ได้เหรียญคนดวงซวย 1 เหรียญทุกครั้ง**", "เหรียญตราค้อนพัง")
refers("   ของ: ซิลเวอร์ เงิน ของผิดกฎหมาย หีบสมบัติ อาหารพิเศษ เหรียญตราค้อนแตก และเพชรคืน", "เหรียญตราค้อนพัง")
refers("กด E ที่บอร์ด → กด 'รับงาน' บนใบประกาศ รับได้พร้อมกันสูงสุด 3 งาน", "รับงาน", true)
refers("ไม่อยากทำต่อ กด 'ยกเลิกงาน' บนใบประกาศ 2 ครั้ง ไม่เสียอะไร", "ยกเลิกงาน", true)
refers("ชวนกันได้ทางเดียว: กด P เปิดหินสื่อสาร → 'รายชื่อสหาย' → ปุ่ม 'ชวนตี้' ที่ชื่อเพื่อน", "ชวนตี้", true)
refers("ออกจากตี้: กดปุ่ม 'ออก' ที่มุมขวาบนของแถบนั้น · ออกจากเกมก็หลุดตี้เอง", "ออก", true)
refers("   สกินอาวุธ: กดที่อาวุธ (ในกระเป๋าหรือช่องสวม) → 'ติดตั้งสกิน' → เลือก · ถอดได้ สกินกลับมาเป็นไอเทม", "ติดตั้งสกิน (%d)", true)
-- "coins" = เหรียญทอง ในคำศัพท์กลาง ห้ามใช้กับเหรียญตรา
local prices = L.Translate("en", "   ดาบ 2 เหรียญ · คฑา/สมุดเวท/ธนู 15 · ปืน 25")
check(not prices:lower():find("coin"), "en ราคาแลกอาวุธไม่ใช้คำว่า coins: " .. prices)

-- ตัวหนาแปลงเป็น RichText แบบเดียวกับ TutorialGui
local bolded = (L.Translate("en", "**สัตว์ฟาร์ม** (ไก่ เป็ด วัว แพะ แกะ กวาง ม้า หมู) กด E มือเปล่าได้เลย"):gsub("%*%*(.-)%*%*", "<b>%1</b>"))
check(bolded:sub(1, 19) == "<b>Farm animals</b>", "ตัวหนาหลังแปล: " .. bolded)

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
