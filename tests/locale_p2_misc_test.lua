-- node tools/offline-test.js tests/locale_p2_misc_test.lua
-- ท่าทาง · แถบตี้ · จอกลับล็อบบี้ · เตือนอยู่นิ่ง · เดินอัตโนมัติ · จอล้ม/ชุบ · ปฏิเสธโจมตี/สกิล · ข้อความโปรไฟล์ แปลครบ · ไทยเหมือนเดิม
local L = require(game.ReplicatedStorage.Locale)
local EC = require(game.ReplicatedStorage.EmoteConfig)
local GV = require(game.ReplicatedStorage.GameVersion)
local IC = require(game.ReplicatedStorage.ItemCatalog)
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text if not ok then fails += 1 end end
local function tr(lang, th, want, label)
	local got = L.Translate(lang, th)
	check(got == want, ("%s %s: %s"):format(label, lang, tostring(got)))
end

-- ป้ายจากคอนฟิก (ท่าทาง กลุ่ม ไฮไลต์เวอร์ชัน) + ข้อความในไคลเอนต์ที่แปลตอนแสดง (locale: skip) ต้องมีคำแปลครบทุกภาษา
local labels = {}
for _, e in ipairs(EC.Emotes) do labels[#labels + 1] = e.label end
for _, g in ipairs(EC.Groups) do labels[#labels + 1] = g.name end
for _, h in ipairs(GV.Highlights) do labels[#labels + 1] = h end
for _, v in ipairs({ "ยกเลิก — โดนโจมตีระหว่างรอ", "ยกเลิก — คุณล้มลงแล้ว", "ไปล็อบบี้ไม่สำเร็จ ลองใหม่อีกครั้ง",
	"ปักหมุดบนแผนที่ก่อน (กด M) แล้วกด T เพื่อเดินอัตโนมัติ", "หยุดเดินอัตโนมัติ (ล้มอยู่)", "ถึงจุดหมายแล้ว",
	"กด T หรือแตะ ", "กด T ", "แตะ", "ชุบ", "อุ้ม", "เกิดใหม่ทันที" }) do
	labels[#labels + 1] = v
end
for _, lang in ipairs({ "en", "zh", "ja" }) do
	local missing = {}
	for _, th in ipairs(labels) do
		if L.T(lang, th) == th then missing[#missing + 1] = th end
	end
	check(#missing == 0, ("%s ป้ายครบ %d อัน (ขาด: %s)"):format(lang, #labels, tostring(missing[1])))
end

-- เตือนอยู่นิ่ง: เดิมต่อสองท่อนด้วย .. → แม่แบบเดียวต่ออุปกรณ์ · ไทยเหมือนเดิมทุกตัวอักษร
local tail = (" — อีก %d นาทีระบบของ Roblox จะตัดการเชื่อมต่อเพราะอยู่นิ่ง"):format(4)
check(L.T("th", "แตะจอหรือขยับตัวละคร — อีก %d นาทีระบบของ Roblox จะตัดการเชื่อมต่อเพราะอยู่นิ่ง", 4)
	== "แตะจอหรือขยับตัวละคร" .. tail, "เตือนอยู่นิ่ง (มือถือ) ไทยเหมือนเดิม")
check(L.T("th", "ขยับเมาส์หรือกดปุ่มอะไรก็ได้ — อีก %d นาทีระบบของ Roblox จะตัดการเชื่อมต่อเพราะอยู่นิ่ง", 4)
	== "ขยับเมาส์หรือกดปุ่มอะไรก็ได้" .. tail, "เตือนอยู่นิ่ง (คอม) ไทยเหมือนเดิม")
check(L.T("en", "ขยับเมาส์หรือกดปุ่มอะไรก็ได้ — อีก %d นาทีระบบของ Roblox จะตัดการเชื่อมต่อเพราะอยู่นิ่ง", 4)
	== "Move the mouse or press any key — Roblox will disconnect you for idling in 4 min", "เตือนอยู่นิ่ง en")

-- เดินอัตโนมัติ: ช่อง %s = วิธีกดของเครื่องนั้น แปลไปพร้อมกัน
local HOW_KEY, HOW_TOUCH = "กด T ", "แตะ"
check(L.T("th", "🚶 เดินอัตโนมัติ — %sเพื่อหยุด", HOW_KEY) == "🚶 เดินอัตโนมัติ — กด T เพื่อหยุด", "ป้ายเดินอัตโนมัติ ไทยเหมือนเดิม")
check(L.T("en", "🚶 เดินอัตโนมัติ — %sเพื่อหยุด", HOW_KEY) == "🚶 Auto-walk — Press T to stop", "ป้ายเดินอัตโนมัติ en")
check(L.T("ja", "🚶 %sเพื่อเดินอัตโนมัติไปหมุด", HOW_TOUCH) == "🚶 タップでピンまで自動歩行", "ป้ายเดินอัตโนมัติ ja")
check(L.T("zh", "🚶 เดินอัตโนมัติ — %sเพื่อหยุด", HOW_KEY) == "🚶 自动行走中 — 按 T 停止", "ป้ายเดินอัตโนมัติ zh")

-- ท่าทาง / แถบตี้ (ไคลเอนต์แปลเอง)
check(L.T("th", "เลิก%s", "โบกมือ") == "เลิกโบกมือ", "เลิกท่า ไทยเหมือนเดิม")
check(L.T("en", "เลิก%s", "โบกมือ") == "Stopped Wave", "เลิกท่า en")
check(L.T("en", "%s (ล้ม)", "Somchai") == "Somchai (downed)", "ชื่อในตี้ (ล้ม) en")
check(L.T("ja", "ตี้ · %d คน", 3) == "パーティー · 3人", "หัวแถบตี้ ja")
check(L.Translate("en", "เลิกนำทางแล้ว") ~= "Stopped นำทางแล้ว", "แม่แบบ เลิก%s ไม่แย่งกุญแจตรงตัว")

-- ข้อความเซิร์ฟ (ตี้ · ต่อสู้ · สกิล · โปรไฟล์) ย้อนแม่แบบได้ · ชื่อคนไม่แปล
tr("en", ("%s อยู่ในตี้อื่นแล้ว"):format("Somchai"), "Somchai is already in another party", "ชวนคนมีตี้")
tr("en", ("%s ออกจากตี้ — ตี้สลาย"):format("Somchai"), "Somchai left the party — party disbanded", "ตี้สลาย")
tr("en", ("%s ออกจากตี้"):format("Somchai"), "Somchai left the party", "ออกจากตี้")
tr("zh", ("ตี้เต็มแล้ว (สูงสุด %d คน)"):format(4), "队伍已满（最多 4 人）", "ตี้เต็ม")
tr("en", ("สกิลยังไม่พร้อม อีก %d วิ"):format(math.ceil(2.3)), "Skill not ready — 3 s left", "คูลดาวน์สกิล")
local bullet = IC.Items.Bullet and IC.Items.Bullet.name or "กระสุน"
tr("en", ("%sหมด — ต่อยแทน"):format(bullet), ("Out of %s — punching instead"):format(L.T("en", bullet)), "กระสุนหมด")
tr("en", "มานาไม่พอ", "Not enough mana", "มานาไม่พอ")
tr("en", "โจมตีไม่ได้ขณะมึนหัว", "Can't attack while dizzy", "Deny + กริยาโจมตี")
tr("ja", ("ได้รับ VIP %d วัน — เปิดโหมดฟาร์มมิ่งได้แล้ว"):format(30), "VIP 30日分を受け取りました — ファーミングモードが使えます", "VIP จากข้อความฝาก")

-- ข้อความเตะ: เซิร์ฟแปลตามภาษาคนนั้นเอง (ไทย = ข้อความเดิม)
local kick = "เซสชันข้อมูลของคุณถูกเปิดจากที่อื่น"
check(L.T("th", kick) == kick, "ข้อความเตะ ไทยเหมือนเดิม")
check(L.T("zh", kick) == "你的数据会话已在其他地方打开", "ข้อความเตะ zh")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
