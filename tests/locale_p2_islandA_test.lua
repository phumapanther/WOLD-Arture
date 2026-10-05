-- node tools/offline-test.js tests/locale_p2_islandA_test.lua
-- หลายภาษา เฟส 2 กลุ่ม islandA (จัดเกาะ · สัตว์เลี้ยง · คอก · มอนบุก · แขก): ไทยออกมาเหมือนเดิมทุกไบต์ + ไคลเอนต์ย้อนแปลงได้
local L = require(game.ReplicatedStorage.Locale)
local IslandConfig = require(game.ReplicatedStorage.IslandConfig)
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text if not ok then fails += 1 end end
local function tr(lang, text, want, label)
	local got = L.Translate(lang, text)
	check(got == want, label .. ": " .. tostring(got))
end

-- ลูบหัวสัตว์เลี้ยง (IslandPets.pat): ต่อท่อนด้วยแม่แบบแทน .. — ไทยต้องตรงกับของเดิมเป๊ะ
local GOT = {
	"%s · ได้ %s ×%d",
	"%s · ได้ %s ×%d · %s ×%d",
}
local base = ("%s ดูมีความสุข (+%d EXP)"):format("ไก่", 20)
local old1 = base .. " · ได้ " .. "กระดูก ×3" .. " · " .. "โต 45%"
local new1 = ("%s · %s"):format(GOT[1]:format(base, "กระดูก", 3), ("โต %d%%"):format(45))
check(new1 == old1, "ลูบหัว 1 ชนิด + โต: ไทยเท่าเดิม")
tr("en", new1, "Chicken looks happy (+20 EXP) · got Bone ×3 · Growth 45%", "ลูบหัว en")

local old2 = base .. " · ได้ " .. "กระดูก ×2 · แร่เหล็ก ×1" .. " · กระเป๋าเต็ม ได้ของไม่ครบ" .. " · " .. "โตเต็มวัย"
local new2 = ("%s · %s"):format(("%s · กระเป๋าเต็ม ได้ของไม่ครบ"):format(GOT[2]:format(base, "กระดูก", 2, "แร่เหล็ก", 1)), "โตเต็มวัย")
check(new2 == old2, "ลูบหัว 2 ชนิด + กระเป๋าเต็ม + โตเต็มวัย: ไทยเท่าเดิม")
tr("en", new2, "Chicken looks happy (+20 EXP) · got Bone ×2 · Iron Ore ×1 · bag full, some items lost · Fully grown", "ลูบหัว 2 ชนิด en")
tr("zh", ("🎉 %s โตเต็มวัยแล้ว!"):format("สุนัข"), "🎉 狗 已经成年了！", "โตเต็มวัย zh")

-- ป้ายเหนือหัว (rich text) + ปุ่ม E บนตัวสัตว์
tr("ja", ("%s  <font color=\"#9BE08A\">โต %d%%</font>"):format("สุนัข", 45), "犬  <font color=\"#9BE08A\">成長 45%</font>", "ป้ายโต ja")
tr("en", ("%s · %s"):format("แมว", "โต 10%"), "Cat · Growth 10%", "ObjectText ชื่อ·โต en")

-- ปุ่มเก็บผลผลิตในคอก (IslandZones.tickPen): ชื่อ+เลเวลอยู่ในแม่แบบเดียวกับสถานะ
local label = ("%s Lv%d"):format("วัว", 3)
check(("%s Lv%d · เก็บไปแล้ว"):format("วัว", 3) == label .. " · เก็บไปแล้ว", "คอก เก็บไปแล้ว: ไทยเท่าเดิม")
check(("%s Lv%d · เก็บได้"):format("วัว", 3) == label .. " · เก็บได้", "คอก เก็บได้: ไทยเท่าเดิม")
tr("en", ("%s Lv%d · เก็บไปแล้ว"):format("วัว", 3), "Cow Lv3 · harvested", "คอก เก็บไปแล้ว en")
tr("zh", ("%s Lv%d · โตอีก %d นาที"):format("ไก่", 1, 7), "鸡 Lv1 · 长大还需 7 分钟", "คอก โตอีก zh")
tr("en", ("ซื้อ%s %d ตัว — โตพอให้เก็บใน %d นาที"):format("แพะ", 2, IslandConfig.PenGrowSeconds / 60),
	("Bought Goat x2 — ready to harvest in %d min"):format(IslandConfig.PenGrowSeconds / 60), "ซื้อสัตว์ en")
tr("en", ("🔒 %s ปลดที่เลเวลฟาร์ม %d (ตอนนี้ Lv%d)"):format("ม้า", 17, 4), "🔒 Horse unlocks at farm level 17 (now Lv4)", "ปลดสัตว์ en")

-- หัวหน้าฝูงมอนบุก (IslandNight.spawn)
check(("👑 หัวหน้าฝูง %s"):format("หมาป่า") == "👑 หัวหน้าฝูง " .. "หมาป่า", "หัวหน้าฝูง: ไทยเท่าเดิม")
tr("en", ("👑 หัวหน้าฝูง %s"):format("หมาป่า"), "👑 Pack Leader " .. L.T("en", "หมาป่า"), "หัวหน้าฝูง en")
tr("en", ("ตอนนี้%s · มอนบุก %d ตัว%s · เลเวลฟาร์ม %d (มอนบุกเริ่มที่ %d) · ช่องดิน %d"):format("กลางคืน", 3, "", 5, 3, 40),
	"Now: Night · raiders 3 · farm level 5 (raids from 3) · soil cells 40", "สถานะ /night en (ไม่มีพาเหรด)")

-- วางของ / แขก
tr("en", ("เกาะเต็มแล้ว (%d ชิ้น)"):format(IslandConfig.MaxPlaced), ("Island is full (%d items)"):format(IslandConfig.MaxPlaced), "เกาะเต็ม en")
tr("ja", "เจ้าของเกาะออกจากเกมแล้ว — กำลังพากลับหน้าเลือกโหมด", "島の持ち主が退出しました — モード選択に戻ります", "แขกถูกพากลับ ja")

-- หน้าต่างคอก (ไคลเอนต์ประกอบด้วย L): ไทยเท่าเดิม · อังกฤษครบประโยค
local function row(lang)
	local who = L.T(lang, "%s Lv%d", "ไก่", 2)
	local grow = L.T(lang, " · Lv%d ใน %s", 3, L.T(lang, "%d วัน %d ชม.", 1, 4))
	return L.T(lang, "%s · โตอีก %s (%d%%)%s", who, L.T(lang, "%d นาที", 5), 40, grow)
end
check(row("th") == ("%s · โตอีก %s (%d%%)%s"):format("ไก่ Lv2", "5 นาที", 40, " · Lv3 ใน 1 วัน 4 ชม."), "แถวคอก ไทยเท่าเดิม: " .. row("th"))
check(row("en") == "Chicken Lv2 · grows in 5 min (40%) · Lv3 in 1 d 4 h", "แถวคอก en: " .. row("en"))
check(L.T("en", "ในคอก %d/%d ตัว · เก็บได้ %d%s", 2, 3, 1, L.T("en", " · รออยู่ %d", 1)) == "In pen 2/3 · ready 1 · waiting 1", "หัวหน้าต่างคอก en")
check(L.T("ja", "ย้าย: %s", "แปลงดิน") == "移動: " .. L.T("ja", "แปลงดิน"), "จัดเกาะ ย้าย ja")

-- หัวจัดเกาะต้องไม่ทับปุ่ม "ออก (F4)" (ป้ายกว้าง 416 px GothamBold 15 ≈ 8 px/ตัว) · ปุ่ม "ออก" ใช้ร่วมกับออกจากตี้ = 退出 ไม่ใช่ 終了
local head = L.T("en", "🏗️ จัดเกาะ · แตะของเพื่อเลือก · ลากเพื่อย้าย")
check(utf8.len(head) <= 46, "หัวจัดเกาะ en สั้นพอ: " .. head)
check(L.T("ja", "ออก") == "退出", "ปุ่มออก ja: " .. L.T("ja", "ออก"))
check(L.T("ja", "ออก (F4)") == "退出 (F4)", "ปุ่มออก F4 ja: " .. L.T("ja", "ออก (F4)"))

-- ชื่อสัตว์ในคอกทุกตัวมีคำแปล
for _, a in ipairs(IslandConfig.PenAnimals) do
	check(L.T("en", a.name) ~= a.name, "ชื่อสัตว์คอกแปลแล้ว: " .. a.name .. " → " .. L.T("en", a.name))
end

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
