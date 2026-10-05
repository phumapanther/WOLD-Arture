-- node tools/offline-test.js tests/locale_p2_classes_test.lua
-- อาชีพ/การกระทำของอาชีพ/จับกุม/คุก/เหตุผลที่ทำไม่ได้ (ระบบหลายภาษา เฟส 2): ข้อความเซิร์ฟที่เปลี่ยนจาก `..`
-- เป็นแม่แบบเดียวต้องได้ไทยเหมือนเดิมเป๊ะ และไคลเอนต์ย้อนแม่แบบเป็นภาษาอื่นได้
local L = require(game.ReplicatedStorage.Locale)
local IC = require(game.ReplicatedStorage.ItemCatalog)
local ClassConfig = require(game.ReplicatedStorage.ClassConfig)
local ClassActionConfig = require(game.ReplicatedStorage.ClassActionConfig)
local CommandCatalog = require(game.ReplicatedStorage.CommandCatalog)
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text if not ok then fails += 1 end end
local function tr(lang, text, want, label)
	local got = L.Translate(lang, text)
	check(got == want, ("%s [%s]: %s"):format(label, lang, tostring(got)))
end

-- PlayerActions.explain: เดิม `action .. "ไม่ได้ตอนนี้"` → แม่แบบเดียวกับ Deny
for _, verb in ipairs({ "กลิ้ง", "สไลด์" }) do
	check(verb .. "ไม่ได้ตอนนี้" == ("%sไม่ได้ตอนนี้"):format(verb), verb .. "ไม่ได้ตอนนี้ ไทยเหมือนเดิม")
end
tr("en", ("%sไม่ได้ตอนนี้"):format("กลิ้ง"), "Can't roll right now", "ถูกตรึง กลิ้งไม่ได้")
tr("ja", ("%sไม่ได้ตอนนี้"):format("สไลด์"), "今はスライディングできません", "ถูกตรึง สไลด์ไม่ได้")

-- Deny.Blocked: คำกริยาจากผู้เรียกแปลซ้อนในช่อง %s
tr("en", ("%sไม่ได้ขณะล้มอยู่ — รอคนมาช่วยหรือกดเกิดใหม่"):format("โจมตี"), "Can't attack while downed — wait for help or respawn", "ล้มอยู่ โจมตีไม่ได้")
tr("zh", ("%sไม่ได้ขณะมึนหัว"):format("ใช้สกิล"), "眩晕时无法使用技能", "มึนหัว ใช้สกิลไม่ได้")
tr("en", "สตามินาไม่พอกลิ้ง", "Not enough stamina to roll", "สตามินาไม่พอ")

-- ClassActions: คำถามฮีล (ชื่อคน + ป้ายฮีลที่มี % อยู่ในตัว) และผลลัพธ์
local small = ClassActionConfig.Heal.small
local question = ("%s ขอ%sให้คุณ (%d ทอง)"):format("Bob", small.label, small.cost)
check(question == "Bob ขอฮีลเล็ก 25%ให้คุณ (500 ทอง)", "คำถามฮีล ไทยเหมือนเดิม: " .. question)
tr("en", question, "Bob offers you Small heal 25% (500 coins)", "คำถามฮีล")
tr("zh", question, "Bob 想为你进行小治疗 25%（500 金币）", "คำถามฮีล")
local large = ClassActionConfig.Heal.large
tr("ja", ("%s (%d ทอง)"):format(large.label, large.cost), "大回復 100%（2000コイン）", "ฮีลสำเร็จ")
tr("en", ("%s ขอซ่อมของทั้งตัวให้คุณ (%d ทอง)"):format("Ana", 2500), "Ana offers to repair all your gear (2500 coins)", "คำถามซ่อม")
tr("en", ("โอนเงิน %d"):format(750), "Transferred 750 coins", "ให้เงินสำเร็จ")

-- ให้ของ: ชื่อไอเทม + ท้าย "(โอนรถให้ด้วย)" ซ้อนสองชั้นในแม่แบบเดียว
local keyTh, keyEn = IC.DisplayName("CarKey", nil, "th"), IC.DisplayName("CarKey", nil, "en")
local gave = ("ให้ %s x%d"):format(("%s (โอนรถให้ด้วย)"):format(keyTh), 1)
tr("en", gave, ("Handed over %s (vehicle transferred too) x1"):format(keyEn), "ให้กุญแจ+โอนรถ")
tr("en", ("ได้รับรถ %s เข้าโรงรถแล้ว"):format("CAR-1234"), "Vehicle CAR-1234 added to your garage", "ได้รับรถ")

-- ไคลเอนต์: `..` เดิม → แม่แบบ L (ไทยต้องตรงเดิม)
local term = ClassActionConfig.Arrest.jailTerms[1]
check("⛓ คุมขัง " .. term.label == L.T("th", "⛓ คุมขัง %s", term.label), "ปุ่มคุมขัง ไทยเหมือนเดิม")
check(L.T("en", "⛓ คุมขัง %s", term.label) == "⛓ Jail 5 min", "ปุ่มคุมขัง en: " .. L.T("en", "⛓ คุมขัง %s", term.label))
check(("%s — %d ทอง"):format(small.label, small.cost) == L.T("th", "%s — %d ทอง", small.label, small.cost), "ปุ่มเลือกฮีล ไทยเหมือนเดิม")
check(L.T("ja", "%s — %d ทอง", small.label, small.cost) == "小回復 25% — 500コイン", "ปุ่มเลือกฮีล ja")
check(L.T("en", "ยึด %d ชิ้น • ปรับ %d ทอง", 2, 300) == "Seize 2 items • Fine 300 coins", "สรุปการยึด en")

-- ข้อมูลอาชีพ: ชื่อ คำอธิบาย ความสามารถติดตัว ป้ายการกระทำ คำสั่ง — ทุกภาษามีคำแปล
local strings = {}
for _, class in pairs(ClassConfig.Classes) do table.insert(strings, class.name) table.insert(strings, class.blurb) end
for _, perk in pairs(ClassConfig.Perks) do table.insert(strings, perk.name) table.insert(strings, perk.blurb) end
for _, action in ipairs(ClassActionConfig.Actions) do table.insert(strings, action.label) end
for _, t in ipairs(ClassActionConfig.Arrest.jailTerms) do table.insert(strings, t.label) end
for _, cmd in ipairs(CommandCatalog.Commands) do
	table.insert(strings, cmd.desc)
	if cmd.args:find("[\224-\239]") then table.insert(strings, cmd.args) end -- เฉพาะที่มีไทย
end
local missingCount = 0
for _, s in ipairs(strings) do
	for _, lang in ipairs({ "en", "zh", "ja" }) do
		if L.Translate(lang, s) == s then missingCount += 1 out[#out + 1] = ("   ไม่มีคำแปล [%s] %s"):format(lang, s) end
	end
end
check(missingCount == 0, ("ข้อมูลอาชีพ/คำสั่ง %d ข้อความแปลครบสามภาษา"):format(#strings))
tr("ja", ClassConfig.DisplayName("Guard"), "衛兵", "ชื่ออาชีพ")
tr("zh", ClassConfig.Perks.Chef.name, "厨师才不会饿呢", "ชื่อความสามารถติดตัว")
check(L.T("th", "เลือกอาชีพ") == "เลือกอาชีพ", "ไทยไม่แปล")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
