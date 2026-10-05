-- node tools/offline-test.js tests/locale_p2_arena_test.lua
-- สนาม PVP (ร้าน · ตาราง · HUD · แผนที่ · ข้อความแมตช์ · คิว · รางวัล · แร็งก์ · กับดัก · เป้าเล็ง) แปลครบ · ไทยเหมือนเดิม
local L = require(game.ReplicatedStorage.Locale)
local AC = require(game.ReplicatedStorage.ArenaConfig)
local TC = require(game.ReplicatedStorage.TrapConfig)
local IC = require(game.ReplicatedStorage.ItemCatalog)
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text if not ok then fails += 1 end end
local function tr(lang, th, want, label)
	local got = L.Translate(lang, th)
	check(got == want, ("%s %s: %s"):format(label, lang, got))
end

-- ป้ายจากคอนฟิก + ตารางในไฟล์ UI ที่แปลตอนใช้ (locale: skip) ต้องมีคำแปลครบทุกภาษา
local labels = { AC.Teams.A.name, AC.Teams.B.name, AC.Maps[1].name }
for _, v in pairs(AC.SlotLabel) do labels[#labels + 1] = v end
for _, v in pairs(AC.SizeLabel) do labels[#labels + 1] = v end
for _, v in ipairs(AC.Bots.names) do labels[#labels + 1] = v end
for _, a in ipairs(TC.Ammo) do labels[#labels + 1] = a.name end
for _, v in ipairs({ "อาวุธระยะใกล้", "อาวุธระยะไกล", "กำลังรอผู้เล่น", "เตรียมตัว — ซื้อของ", "สู้!", "จบรอบ", "จบแมตช์",
	"ผู้เล่น", "ดาเมจ", "คะแนน", "รางวัล", "เงิน", "ของ", "หยิบ", "สนามประลอง", "ทีมชนะ", "ทีมแพ้" }) do
	labels[#labels + 1] = v
end
for _, lang in ipairs({ "en", "zh", "ja" }) do
	local missing = {}
	for _, th in ipairs(labels) do
		if L.T(lang, th) == th then missing[#missing + 1] = th end
	end
	check(#missing == 0, ("%s ป้ายสนามครบ %d อัน (ขาด: %s)"):format(lang, #labels, tostring(missing[1])))
end

-- PvpRewards: แม่แบบเดียวทั้งประโยค = ไทยเดิมทุกตัวอักษร (สองแบบ: มี/ไม่มีหีบ)
local gold, exp, given = 170, 375, { ("%s x%d"):format(IC.Items.Chest_Gold.name, 1) }
local old = ("รางวัลจากสนาม PVP: %d เหรียญ · %d EXP"):format(gold, exp)
local oldWith = old .. " · " .. table.concat(given, ", ")
local newWith = ("รางวัลจากสนาม PVP: %d เหรียญ · %d EXP · %s"):format(gold, exp, table.concat(given, ", "))
check(newWith == oldWith, "รางวัล PVP + หีบ ไทยเหมือนเดิม")
check(("รางวัลจากสนาม PVP: %d เหรียญ · %d EXP"):format(gold, exp) == old, "รางวัล PVP ไม่มีหีบ ไทยเหมือนเดิม")
tr("en", newWith, "PVP arena reward: 170 coins · 375 EXP · Gold Chest x1", "รางวัล PVP + หีบ")
tr("zh", old, "PVP 竞技场奖励：170 金币 · 375 EXP", "รางวัล PVP")

-- ข้อความแมตช์จากเซิร์ฟ (ArenaMatch.notify → ArenaShopGui:Flash แปลด้วย Show)
local sword, great = IC.Items.Sword.name, IC.Items.Greatsword.name
tr("en", ("ซื้อ %s แล้ว"):format(sword), "Bought " .. IC.DisplayName("Sword", nil, "en"), "ซื้อแล้ว")
tr("en", "ซื้อ ปลา x2 แล้ว", "Bought Fish x2", "ไม่ทับแม่แบบซื้อ x จำนวน")
tr("en", ("รอบนี้ซื้อ%sครบแล้ว"):format(AC.SlotLabel.weapon), "Weapon: bought max this round", "ซื้อครบช่อง")
tr("ja", ("ยกเลิก %s แล้ว · คืน %d ซิลเวอร์"):format(great, 3000),
	IC.DisplayName("Greatsword", nil, "ja") .. " をキャンセル · 3000 シルバー返金", "ยกเลิกการซื้อ")
tr("en", ("หยิบ %s แล้ว"):format(IC.Items.Pistol.name), "Picked up " .. IC.DisplayName("Pistol", nil, "en"), "หยิบอาวุธ")
tr("en", ("มานา %d/%d"):format(2, 3), "Mana 2/3", "เติมมานา")
tr("en", "ซิลเวอร์ไม่พอ", "Not enough Silver", "ซิลเวอร์ไม่พอ")

-- กับดัก (TrapWeapon → SocialNotify → ToastController แปลด้วย Show) · ชื่อกระสุนในช่อง %s แปลด้วย
local sticky, blast = TC.AmmoById.TrapAmmo_Slow.name, TC.AmmoById.TrapAmmo_Blast.name
tr("en", ("🪤 กับดัก%sหมดเวลา ไม่มีใครมาโดน"):format(sticky), "🪤 Your Sticky trap expired untouched", "กับดักหมดเวลา")
tr("ja", ("🪤 โดนกับดัก%s!"):format(blast), "🪤 爆発の罠にかかった！", "โดนกับดัก")
tr("zh", ("🪤 กับดัก%sทำงาน โดน %d เป้า"):format(blast, 2), "🪤 爆炸陷阱触发，命中 2 个目标", "กับดักทำงาน")

-- ชื่อบอท + เมลรางวัล
tr("en", "หุ่นไอน้ำ-03", "Steambot-03", "ชื่อบอทในคอนฟิก")
tr("zh", ("หุ่นไอน้ำ-%02d"):format(7), "蒸汽机器人-07", "ชื่อบอทสำรอง")
tr("ja", ("รางวัลสนาม PVP — อันดับ %d"):format(2), "PVPアリーナ報酬 — 2 位", "หัวเมลรางวัล")

-- แม่แบบฝั่งไคลเอนต์ (L) แปลอาร์กิวเมนต์ชื่อเฟส/แมพ · ไทยเหมือน format เดิม
check(L.T("en", "รอบ %d · %s · %s", 3, "สู้!", AC.Maps[1].name) == "Round 3 · Fight! · Goldgear Castle", "แถบรอบ HUD (en)")
check(L.T("th", "รอบ %d · %s · %s", 3, "สู้!", AC.Maps[1].name) == ("รอบ %d · %s · %s"):format(3, "สู้!", AC.Maps[1].name), "แถบรอบ HUD (th)")
check(L.T("en", "%s หมด", sticky) == "Sticky: empty", "กระสุนกับดักหมด (en)")
check(L.T("th", "%s  (คุณ)"):format("Bob") == "Bob" .. "  (คุณ)", "ชื่อเรา (th)")
check(L.T("ja", "ขนาด  %s", AC.SizeLabel.large) == "サイズ  大", "ขนาดในร้าน (ja)")

-- ป้ายการ์ด "เงินไม่พอ" ภาษาอื่นใช้คำสั้น (ป้ายกว้าง 62 px) · ชื่อบอทบนป้ายคิล/ชื่อเหนือหัวแปล ชื่อคนจริงผ่านตรง
tr("en", "ป้ายซิลเวอร์ไม่พอ", "No Silver", "ป้ายการ์ดซิลเวอร์ไม่พอ")
tr("zh", "ป้ายซิลเวอร์ไม่พอ", "银币不足", "ป้ายการ์ดซิลเวอร์ไม่พอ")
tr("ja", "ป้ายซิลเวอร์ไม่พอ", "シルバー不足", "ป้ายการ์ดซิลเวอร์ไม่พอ")
tr("ja", "หุ่นไอน้ำ-05", L.T("ja", "หุ่นไอน้ำ-%02d", 5), "ชื่อบอทบนป้ายคิล")
tr("en", "Bob_123", "Bob_123", "ชื่อคนจริงไม่แปล")
check(("%s (%d)"):format(L.T("zh", sticky), 3) == "黏滞 (3)", "เมนูเลือกกระสุนกับดัก (zh)")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
