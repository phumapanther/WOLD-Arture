-- node tools/offline-test.js tests/locale_p2_social_test.lua
-- หินเวท/เพื่อน/โทร/เมล/อันดับ (ระบบหลายภาษา เฟส 2): ข้อความเซิร์ฟที่เปลี่ยนจาก `..` เป็นแม่แบบเดียว
-- ต้องได้ไทยเหมือนเดิมเป๊ะ และไคลเอนต์ย้อนแม่แบบเป็นภาษาอื่นได้
local L = require(game.ReplicatedStorage.Locale)
local IC = require(game.ReplicatedStorage.ItemCatalog)
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text if not ok then fails += 1 end end
local function tr(lang, text, want, label)
	local got = L.Translate(lang, text)
	check(got == want, ("%s [%s]: %s"):format(label, lang, tostring(got)))
end

-- GlobalRanks: ชื่อสำรองตอนอ่านชื่อไม่ได้ (เดิม `..` กับเลข userId)
local userId = 123456789
local old = "ผู้เล่น #" .. userId
local new = ("ผู้เล่น #%s"):format(tostring(userId))
check(old == new, "ผู้เล่น #<id> ไทยเหมือนเดิม")
tr("en", new, "Player #123456789", "ผู้เล่น #<id>")
tr("ja", new, "プレイヤー #123456789", "ผู้เล่น #<id>")

-- ตารางอันดับ (SocialGui): หน่วยต่อท้ายเดิมเป็น SUFFIX ต่อด้วย %s%s → แม่แบบเต็ม
check(("%d%s"):format(5, " คน") == L.T("th", "%d คน", 5), "อันดับช่อง: N คน ไทยเหมือนเดิม")
check(("%s%s"):format(tostring(1200), " เหรียญ") == L.T("th", "%s เหรียญ", "1200"), "อันดับเงิน: ไทยเหมือนเดิม")
check(("%s%s"):format(tostring(42), " แต้ม") == L.T("th", "%s แต้ม", "42"), "อันดับแต้ม: ไทยเหมือนเดิม")
check(("ช่อง %s"):format("3") .. " (ช่องคุณ)" == L.T("th", "ช่อง %s (ช่องคุณ)", "3"), "ช่องคุณ: ไทยเหมือนเดิม")
check(L.T("en", "ช่อง %s (ช่องคุณ)", "3") == "Channel 3 (yours)", "ช่องคุณ en")
check(L.T("zh", "%s เหรียญ", "1200") == "1200 金币", "อันดับเงิน zh")

-- SocialGui / SocialController: `..` เดิม → แม่แบบ
check("VIP" .. "  —  ฉายาของ VIP" == L.T("th", "%s  —  ฉายาของ VIP", "VIP"), "แถวฉายา VIP ไทยเหมือนเดิม")
check("ส่งของถึง " .. tostring("Bob") == L.T("th", "ส่งของถึง %s", "Bob"), "หัวหน้าส่งของ ไทยเหมือนเดิม")
check("ทำไม่ได้: " .. tostring("x") == L.T("th", "ทำไม่ได้: %s", "x"), "ท่าทางทำไม่ได้ ไทยเหมือนเดิม")
check(L.T("ja", "ส่งของถึง %s", "Bob") == "Bob にアイテムを送る", "หัวหน้าส่งของ ja")

-- ข้อความเซิร์ฟ (แม่แบบเดิม) ย้อนได้ + อาร์กิวเมนต์ที่เป็นคำไทยแปลซ้อน
tr("en", ("ส่งคำขอเป็นเพื่อนถึง %s แล้ว"):format("Bob"), "Friend request sent to Bob", "Friends.Request")
local coal = IC.DisplayName("Coal", nil, "th")
tr("en", ("ส่ง %s x%d ถึง %s แล้ว"):format(coal, 3, "Bob"), "Sent Coal x3 to Bob", "PlayerMail ส่งสำเร็จ")
tr("ja", ("ได้รับเงินโอน %s เหรียญ จาก %s"):format(tostring(500), "Bob"), "500 コインの送金を受け取りました（Bob より）", "เงินโอน")
tr("zh", ("ได้แต้มกิจกรรม +%d (รวม %d)"):format(5, 120), "活动积分 +5（共 120）", "แต้มกิจกรรม")
tr("en", ("มีจดหมายใหม่จาก %s"):format("ระบบ"), "New mail from System", "เมลจากระบบ")
tr("en", ("%s กำลังคุยสายอื่นอยู่"):format("Bob"), "Bob is on another call", "Calls.Start")
tr("en", ("ค่าส่ง %d ซิลเวอร์ — ซิลเวอร์ไม่พอ"):format(500), "Postage is 500 Silver — not enough Silver", "ค่าส่งเมล")

-- กุญแจที่แปลตอนใช้ (locale-check ข้ามเพราะติด `-- locale: skip`) ต้องมีครบทุกภาษา
for _, key in ipairs({ "หินเวทสื่อสาร", "ตั้งค่า", "บอร์ดกิลด์", "รายชื่อสหาย", "ธนาคาร", "ราคากลาง", "โปรไฟล์",
	"กล่องจดหมาย", "ส่งของ", "%s เหรียญ", "%s แต้ม" }) do
	for _, lang in ipairs({ "en", "zh", "ja" }) do
		check(L.T(lang, key) ~= key, ("แปลตอนใช้มีคำแปล %s [%s]"):format(key, lang))
	end
end
check(L.T("th", "ตั้งค่า") == "ตั้งค่า", "ไทยไม่แปล")

-- ปุ่มแถวสหายกว้าง 56 px ตัว 12 ไม่ย่อตัวอักษร: คำต้องสั้นพอ (รีวิวเจอ "パーティー招待"/"Send items" ล้นปุ่ม)
check(L.T("ja", "ชวนตี้") == "招待", "ปุ่มชวนตี้ ja สั้น")
check(L.T("en", "ส่งของ") == "Mail", "ปุ่มส่งของ en สั้น")
check(L.T("zh", "ส่งของ") == "寄送", "ปุ่มส่งของ zh สั้น")
check(L.T("ja", "ส่งของ") == "送る", "ปุ่มส่งของ ja สั้น")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
