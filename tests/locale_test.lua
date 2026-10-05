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

-- %% = เครื่องหมายเปอร์เซ็นต์จริง ต้องย้อนแม่แบบได้
check(L.Translate("en", "เชื้อเพลิงไม่พอ ต้องใช้ 38% (มี 12%) — เติมถ่านหินที่แถบด้านบน") == "Not enough fuel: need 38% (have 12%) — add coal in the bar above",
	"Translate แม่แบบที่มี %%: " .. L.Translate("en", "เชื้อเพลิงไม่พอ ต้องใช้ 38% (มี 12%) — เติมถ่านหินที่แถบด้านบน"))

-- ชื่อไอเทมแปลที่ DisplayName ที่เดียว (Task 5)
local IC = require(game.ReplicatedStorage.ItemCatalog)
check(IC.DisplayName("Sword", nil, "en") == "Sword", "ชื่อไอเทมแปล: " .. tostring(IC.DisplayName("Sword", nil, "en")))
check(IC.DisplayName("Sword", { enhance = 3 }, "ja") == "剣 +3", "ขั้นตีบวกต่อท้ายคำแปล: " .. tostring(IC.DisplayName("Sword", { enhance = 3 }, "ja")))
check(IC.DisplayName("Sword", nil, "th") == "ดาบ", "ไทยเหมือนเดิม")
check(IC.DisplayName("Sword", nil) == "ดาบ", "ไม่ส่งภาษา (เซิร์ฟ/ตัวจำลอง) = ไทย")

-- ข้อความเซิร์ฟจริง (Task 6): แม่แบบเดียวทั้งประโยค + อาร์กิวเมนต์ที่เป็นชื่อแปลด้วย
local function tr(lang, text, want, label)
	local got = L.Translate(lang, text)
	check(got == want, label .. ": " .. got)
end
tr("en", "ซื้อ ดาบ x2 ราคา 600 เหรียญ", "Bought Sword x2 for 600 coins", "ซื้อ + สกุลเงินแปล")
tr("en", "🏠 บ้านเต็มแล้ว (2/2 หลัง) — เลเวลฟาร์ม 4 มีได้ 2 หลัง", "🏠 House limit reached (2/2) — farm level 4 allows 2", "เพดานบ้านทั้งประโยค")
tr("en", "สร้าง ดาบ ล้มเหลว วัสดุเสียไป", "Crafting Sword failed, materials lost", "คราฟล้มเหลว")
tr("zh", "ขาย ดาบ x1 ได้ 120", "出售 剑 x1，获得 120", "ขาย (จีน)")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
