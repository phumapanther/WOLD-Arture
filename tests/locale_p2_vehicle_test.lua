-- node tools/offline-test.js tests/locale_p2_vehicle_test.lua
-- ระบบหลายภาษา เฟส 2 กลุ่มพาหนะ: ข้อความเซิร์ฟที่เปลี่ยนจาก .. เป็นแม่แบบเดียว ต้องได้ไทยเดิมเป๊ะ และย้อนแปลงได้
local L = require(game.ReplicatedStorage.Locale)
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text if not ok then fails += 1 end end
local function same(old, new, label) check(old == new, label .. ": " .. new) end
local function tr(lang, text, want, label)
	local got = L.Translate(lang, text)
	check(got == want, label .. " [" .. lang .. "]: " .. tostring(got))
end

local plate = "CAR-1234"

-- ไทยเดิมเป๊ะ (concat เก่า == format ใหม่)
same("🔒 " .. plate .. " ถูกล็อกอยู่ ต้องมีกุญแจถึงจะขึ้นได้", ("🔒 %s ถูกล็อกอยู่ ต้องมีกุญแจถึงจะขึ้นได้"):format(plate), "ขึ้นรถที่ล็อก")
same("🔒 ล็อก " .. plate .. " แล้ว", (true and "🔒 ล็อก %s แล้ว" or "🔓 ปลดล็อก %s แล้ว"):format(plate), "ล็อก")
same("🔓 ปลดล็อก " .. plate .. " แล้ว", (false and "🔒 ล็อก %s แล้ว" or "🔓 ปลดล็อก %s แล้ว"):format(plate), "ปลดล็อก")
same("🔥 ไฟในเตาดับแล้ว — " .. plate .. " ไปต่อไม่ได้ ต้องเติมถ่าน (เปิดท้ายรถแล้วกดเติม)",
	("🔥 ไฟในเตาดับแล้ว — %s ไปต่อไม่ได้ ต้องเติมถ่าน (เปิดท้ายรถแล้วกดเติม)"):format(plate), "ไฟดับ")
same("📜 จดทะเบียน " .. plate .. " เรียบร้อย เป็นพาหนะของคุณแล้ว", ("📜 จดทะเบียน %s เรียบร้อย เป็นพาหนะของคุณแล้ว"):format(plate), "จดทะเบียน")
same("🚂 เบิก " .. plate .. " ออกมาแล้ว", ("🚂 เบิก %s ออกมาแล้ว"):format(plate), "เบิกฟรี")
local used = 5
local refuelMsg = ("เติมถ่าน %d ชิ้น"):format(used)
same("เติมถ่าน " .. used .. " ชิ้น", refuelMsg, "เติมถ่าน")
same("🔥 " .. plate .. " " .. refuelMsg .. " เรียบร้อย", ("🔥 %s %s เรียบร้อย"):format(plate, refuelMsg), "เติมถ่านที่ท้ายรถ")
same("จุดนี้เรียกได้เฉพาะ" .. "เรือเหาะ", ("จุดนี้เรียกได้เฉพาะ%s"):format("เรือเหาะ"), "ผิดจุดเรียก")
same("เรียก" .. "รถไอน้ำ", ("เรียก%s"):format("รถไอน้ำ"), "ปุ่มจุดเรียก")
same(plate .. " ถูกล็อกอยู่ ต้องมีกุญแจถึงจะเปิดท้ายได้", ("%s ถูกล็อกอยู่ ต้องมีกุญแจถึงจะเปิดท้ายได้"):format(plate), "ท้ายล็อก")

-- ย้อนแปลงข้อความเซิร์ฟ
tr("en", "🔒 ล็อก CAR-1234 แล้ว", "🔒 Locked CAR-1234", "ล็อก")
tr("en", "🔥 ไฟในเตาดับแล้ว — CAR-1234 ไปต่อไม่ได้ ต้องเติมถ่าน (เปิดท้ายรถแล้วกดเติม)",
	"🔥 The boiler went out — CAR-1234 can't move, refuel it (open the trunk and tap refuel)", "ไฟดับ")
tr("en", "🔥 CAR-1234 เติมถ่าน 5 ชิ้น เรียบร้อย", "🔥 CAR-1234: added 5 coal, done", "เติมถ่านซ้อนแม่แบบ")
tr("en", "🚂 เบิก CAR-1234 ออกมาแล้ว ค่าบริการ 157 เหรียญ", "🚂 Took out CAR-1234, fee 157 coins", "เบิกมีค่าบริการ")
tr("en", "มีรถไอน้ำครบ 3 คันแล้ว", "Max Steam Car reached (3)", "เพดานทะเบียน แปลชื่อพาหนะ")
tr("en", "จุดนี้เรียกได้เฉพาะเรือเหาะ", "This spot only summons Airship", "ผิดจุดเรียก")
tr("en", "🔒 CAR-1234 ถูกล็อกอยู่ ต้องมีกุญแจถึงจะเปิดท้ายได้", "🔒 CAR-1234 is locked — you need the key to open the trunk", "ปุ่มท้ายรถ (🔒 นำหน้า)")
tr("en", "🔧 ซ่อม CAR-1234 กลับมาเต็มแล้ว (ใช้เฟืองอะไหล่ 3)", "🔧 Repaired CAR-1234 to full (used 3 spare gears)", "ช่างซ่อมถึงที่")
tr("en", "🔒 เจ้าของล็อกพาหนะ", "🔒 The owner locked the vehicle", "เด้งลงจากรถ")

-- ป้ายปุ่ม E (PromptStackController แปลด้วย Show)
tr("en", "รถไอน้ำ CAR-1234", "Steam Car CAR-1234", "ObjectText ชื่อ+ทะเบียน")
tr("en", "เรียกเรือเหาะ", "Summon Airship", "ปุ่มจุดเรียก")
tr("en", "เรียกจักรยานแล้ว", "Monowheel summoned", "จักรยาน (คีย์ตรงชนะแม่แบบเรียก%s)")
tr("en", "ลานจอดเรือเหาะแอสตราเวล", "Astravale Airship Mooring", "ชื่อจุดเรียก")

-- จีน/ญี่ปุ่น
tr("zh", "🏠 ฝาก CAR-1234 เข้าโรงเก็บแล้ว ค่าบริการ 80 เหรียญ", "🏠 CAR-1234 已存回车库，服务费 80 金币", "ฝาก")
tr("ja", "SEA-4321 ถูกเรียกออกมาแล้ว", "SEA-4321 はすでに出庫済み", "เรียกซ้ำ")
tr("ja", "เรือไอน้ำ SEA-4321", "蒸気船 SEA-4321", "ObjectText เรือ")

-- แม่แบบฝั่งไคลเอนต์ (L ส่งชื่อพาหนะเป็นอาร์กิวเมนต์ แปลให้เอง)
check(L.T("en", "ท้าย%s %s", "เรือเหาะ", "AIR-1234") == "Airship trunk AIR-1234", "หัวแผงท้าย: " .. L.T("en", "ท้าย%s %s", "เรือเหาะ", "AIR-1234"))
check(L.T("th", "ท้าย%s %s", "เรือเหาะ", "AIR-1234") == "ท้าย" .. "เรือเหาะ" .. " " .. "AIR-1234", "หัวแผงท้าย ไทยเดิม")
check(L.T("ja", "W/S เร่ง-ถอย · Shift บูสต์ · A/D เลี้ยว · H หวูด · L ล็อก · เบาะซ้อน %d ที่", 1)
	== "W/S 加速/後退 · Shift ブースト · A/D ハンドル · H 汽笛 · L ロック · 同乗席 1", "คำใบ้ขับ (ญี่ปุ่น)")
check(L.T("th", "W/S เร่ง-ถอย · Shift บูสต์ · A/D เลี้ยว · H หวูด · L ล็อก · เบาะซ้อน %d ที่", 1)
	== "W/S เร่ง-ถอย · Shift บูสต์ · A/D เลี้ยว · H หวูด · L ล็อก · เบาะซ้อน " .. 1 .. " ที่", "คำใบ้ขับ ไทยเดิม")

-- ชื่อเมืองในชื่อจุดเรียก ต้องตรงกับชื่อเมืองที่แปลไว้แล้ว (แผนที่/เควสใช้ชื่อเดียวกัน)
local TOWN_IN_STATION = {
	{ "โรงรถซอลต์เมียร์", "ซอลต์เมียร์" }, { "ท่าเรือชายฝั่งซอลต์เมียร์", "ซอลต์เมียร์" },
	{ "ท่าเรืออ่าวบราสเฮเวน", "บราสเฮเวน" }, { "โรงรถค็อกส์เวิร์ธ", "ค็อกส์เวิร์ธ" },
	{ "ลานจอดเรือเหาะสโตนมาร์ก", "สโตนมาร์ก" }, { "ลานจอดเรือเหาะแอสตราเวล", "แอสตราเวล" },
	{ "ลานจอดเรือเหาะปล่องมังกรหลับ", "ปล่องมังกรหลับ" },
}
for _, lang in { "zh", "ja" } do
	for _, pair in TOWN_IN_STATION do
		local station, town = L.Translate(lang, pair[1]), L.Translate(lang, pair[2])
		check(station:find(town, 1, true) ~= nil, ("ชื่อเมือง [%s] %s มี %s"):format(lang, station, town))
	end
end

print(table.concat(out, "\n"))
print(fails == 0 and "PASS" or ("FAIL " .. fails))
