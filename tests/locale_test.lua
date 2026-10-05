-- node tools/offline-test.js tests/locale_test.lua
local L = require(game.ReplicatedStorage.Locale)
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text if not ok then fails += 1 end end

check(L.FromLocaleId("th-th") == "th", "th-th → th")
check(L.FromLocaleId("en-us") == "en", "en-us → en")
check(L.FromLocaleId("zh-cn") == "zh" and L.FromLocaleId("zh-tw") == "zh", "zh-* → zh")
check(L.FromLocaleId("ja-jp") == "ja", "ja-jp → ja")
check(L.FromLocaleId("ko-kr") == "en" and L.FromLocaleId("") == "en" and L.FromLocaleId(nil) == "en", "อื่น/ว่าง → en")
check(L.Valid("ja") and not L.Valid("fr"), "Valid")

check(L.T("en", "กระเป๋าเต็ม") == "Bag is full", "แปลตรงตัว")
check(L.T("th", "กระเป๋าเต็ม") == "กระเป๋าเต็ม", "ไทยไม่แปล")
check(L.T("en", "ไม่มีในตาราง") == "ไม่มีในตาราง", "ไม่มีคำแปล = ไทย")
check(L.T("en", "ตกได้ %s %.1f กก.", "ปลา", 3.25) == "Caught Fish 3.2 kg", "format + แปลอาร์กิวเมนต์ชื่อ")
check(L.T("en", "ตกได้ %s %.1f กก.") == "Caught %s %.1f kg", "ไม่ส่งอาร์กิวเมนต์ = ไม่ format")
local ok = pcall(L.T, "en", "ตกได้ %s %.1f กก.", "ปลา") -- อาร์กิวเมนต์ไม่ครบ
check(ok, "format พังไม่ error")

-- ย้อนแม่แบบ: เซิร์ฟส่งไทยสำเร็จรูปมา
check(L.Translate("en", "ตกได้ ปลา 3.2 กก.") == "Caught Fish 3.2 kg", "Translate จับแม่แบบ + แปลชื่อที่จับได้")
check(L.Translate("en", "กระเป๋าเต็ม") == "Bag is full", "Translate ตรงตัว")
check(L.Translate("en", "ข้อความแปลก ๆ") == "ข้อความแปลก ๆ", "Translate ไม่เจอ = เดิม")
check(L.Translate("th", "ตกได้ ปลา 3.2 กก.") == "ตกได้ ปลา 3.2 กก.", "Translate ไทย = เดิม")
check(L.Translate("en", "ซื้อ ปลา x2 แล้ว") == "Bought Fish x2", "แม่แบบยาวกว่าชนะ (ไม่ไปจับ 'ซื้อ %s')")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
