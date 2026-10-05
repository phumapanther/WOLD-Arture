-- node tools/offline-test.js tests/locale_p2_economy_test.lua
-- หลายภาษาเฟส 2 กลุ่ม economy: ร้านพรีเมียม/กาชา/พาส · ธนาคาร/คลัง · เทรด · หีบ · สกิน/ออร่า/ของประจำตำแหน่ง
local L = require(game.ReplicatedStorage.Locale)
local IC = require(game.ReplicatedStorage.ItemCatalog)
local PC = require(game.ReplicatedStorage.PremiumConfig)
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text if not ok then fails += 1 end end
local function tr(lang, text, want, label)
	local got = L.Translate(lang, text)
	check(got == want, label .. ": " .. tostring(got))
end

-- รับของพาสสองชิ้น (ขั้นของประจำเดือน): แม่แบบใหม่ต้องได้ไทยเท่าการต่อ " + " เดิมทุกไบต์
local a, b = "หีบเงิน x10", "ออร่าเพลิง x1"
local new = ("รับ %s + %s (ขั้น %d)"):format(a, b, 15)
local old = ("รับ %s (ขั้น %d)"):format(table.concat({ a, b }, " + "), 15)
check(new == old, "รับของสองชิ้น ไทยเท่าเดิม: " .. new)
tr("en", new, ("Claimed Silver Chest x10 + %s x1 (tier 15)"):format(IC.DisplayName("Aura_Ember", nil, "en")), "รับของสองชิ้น (en)")
tr("en", ("รับ %s (ขั้น %d)"):format("เงิน 500", 3), "Claimed Coins 500 (tier 3)", "รับของชิ้นเดียว (en)")

-- ชื่อพาส: ไทยใช้ พ.ศ. เหมือนเดิม · ภาษาอื่นใช้ ค.ศ.
check(PC.PassName(1) == "พาสเดือนกันยายน 2569", "ชื่อพาสไทยเดิม: " .. PC.PassName(1))
check(PC.PassName(1, "th") == PC.PassName(1), "ชื่อพาส lang=th = เดิม")
check(PC.PassName(1, "en") == "September 2026 Pass", "ชื่อพาส en: " .. PC.PassName(1, "en"))
check(PC.PassName(4, "ja") == "12月（2026年）パス", "ชื่อพาส ja: " .. PC.PassName(4, "ja"))

-- ข้อความเซิร์ฟ: ธนาคาร/คลัง/ร้านเพชร/สกิน/ออร่า/ของประจำตำแหน่ง/เทรด
tr("en", ("ฝาก %d เหรียญ"):format(500), "Deposited 500 coins", "ฝากเงิน")
tr("ja", ("เบิก %s x%d ออกจากคลัง"):format("ดาบ", 3), "倉庫から 剣 x3 を取り出しました", "เบิกของ (ja)")
tr("en", ("ซื้อ %s x%d แล้ว (-%d เพชร)"):format("ขวานทอง", 1, 150),
	("Bought %s x1 (-150 gems)"):format(IC.DisplayName("GoldAxe", nil, "en")), "ซื้อร้านเพชร (ไม่ไปจับ 'ซื้อ %s x%d แล้ว')")
tr("en", ("เปิด%s"):format("ออร่าเพลิง"), ("Turned on %s"):format(IC.DisplayName("Aura_Ember", nil, "en")), "เปิดออร่า")
tr("zh", ("ได้รับ%s"):format(IC.DisplayName("Spatula")), ("获得 %s"):format(IC.DisplayName("Spatula", nil, "zh")), "ได้ของประจำตำแหน่ง (zh)")
tr("en", ("เก็บรถ %s เข้าโรงรถก่อนถึงจะยกกุญแจให้กันได้"):format("CAR-1234"),
	"Park vehicle CAR-1234 in the garage before handing over its key", "เทรดกุญแจรถ")
tr("en", ("เป็น VIP แล้ว เหลือ %d วัน (-%d เพชร)"):format(30, 150), "You're VIP — 30 days left (-150 gems)", "ซื้อ VIP")
tr("th", "ฝาก ดาบ x2 เข้าคลัง", "ฝาก ดาบ x2 เข้าคลัง", "ไทยไม่แปล")

-- ป้ายฝั่งไคลเอนต์ (L) + ค่าคอนฟิก
check(L.T("en", "สุ่ม 10  💎 %d", 450) == "Roll 10  💎 450", "ปุ่มสุ่ม 10")
check(L.T("ja", "คลังสินค้า  %d/%d ช่อง", 3, 60) == "倉庫  3/60 枠", "หัวคลัง (ja)")
check(L.T("en", PC.GachaById("aura").name) == "Aura Gacha", "ชื่อตู้กาชาจากคอนฟิก")
check(L.T("zh", "%s x%d", "ถุงเหรียญ", 2) == "金币袋 x2", "ชื่อแถวร้าน + จำนวน (zh)")

-- ปุ่มรับรางวัลพาส: "รับ" ภาษาอื่นแปลว่ารับคำเชิญ (Accept/接受) จึงใช้คีย์แยก "รับของ"
check(L.T("en", "รับของ") == "Claim", "ปุ่มรับพาส (en): " .. L.T("en", "รับของ"))
check(L.T("zh", "รับของ") == "领取", "ปุ่มรับพาส (zh): " .. L.T("zh", "รับของ"))
check(L.T("ja", "รับของ") == "受取", "ปุ่มรับพาส (ja): " .. L.T("ja", "รับของ"))

for _, line in ipairs(out) do print(line) end
print(fails == 0 and "PASS" or ("FAIL " .. fails))
