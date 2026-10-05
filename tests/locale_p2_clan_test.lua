-- node tools/offline-test.js tests/locale_p2_clan_test.lua
-- หลายภาษาเฟส 2 กลุ่มแคลน: ข้อความเซิร์ฟที่เปลี่ยนจาก `..` เป็นแม่แบบเดียว ต้องได้ไทยเท่าเดิมทุกไบต์ และย้อนแปลได้
local L = require(game.ReplicatedStorage.Locale)
local ClanConfig = require(game.ReplicatedStorage.ClanConfig)
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text if not ok then fails += 1 end end
local function tr(lang, text, want, label)
	local got = L.Translate(lang, text)
	check(got == want, label .. ": " .. tostring(got))
end

-- TownBuyers: ใบขาย 4 แบบ (เดิมต่อท้ายด้วย `..`)
local name, count, total, bonus, taxed = "ข้าว", 3, 45, math.floor(ClanConfig.HomeSellBonus * 100), 4
local function oldNote(home, tax)
	local note = ("ขาย %s x%d ได้ %d เหรียญ"):format(name, count, total)
	if home then note = note .. (" (+%d%% คนในแคลน)"):format(bonus) end
	if tax > 0 then note = note .. (" · ภาษี %d ซิลเวอร์เข้าคลังแคลน"):format(tax) end
	return note
end
local both = ("ขาย %s x%d ได้ %d เหรียญ (+%d%% คนในแคลน) · ภาษี %d ซิลเวอร์เข้าคลังแคลน"):format(name, count, total, bonus, taxed)
check(both == oldNote(true, taxed), "ขาย บ้าน+ภาษี ไทยเท่าเดิม")
check(("ขาย %s x%d ได้ %d เหรียญ (+%d%% คนในแคลน)"):format(name, count, total, bonus) == oldNote(true, 0), "ขาย บ้าน ไทยเท่าเดิม")
check(("ขาย %s x%d ได้ %d เหรียญ · ภาษี %d ซิลเวอร์เข้าคลังแคลน"):format(name, count, total, taxed) == oldNote(false, taxed), "ขาย ภาษี ไทยเท่าเดิม")
tr("en", both, "Sold Grain x3 for 45 coins (+25% clan member) · 4 Silver tax to the clan treasury", "ขาย บ้าน+ภาษี (อังกฤษ)")
tr("en", oldNote(false, 0), "Sold Grain x3 for 45 coins", "ขายเปล่า (อังกฤษ)")

-- TownCapture: ยึดเมือง + ปล่อยเมืองเดิม (เดิม message .. " (ปล่อย…)")
local oldCapture = ("แคลน %s ยึด%sได้แล้ว"):format("Wolves", "ซอลต์เมียร์") .. (" (ปล่อย%s)"):format("โกลด์เมโดว์")
local newCapture = ("แคลน %s ยึด%sได้แล้ว (ปล่อย%s)"):format("Wolves", "ซอลต์เมียร์", "โกลด์เมโดว์")
check(newCapture == oldCapture, "ยึดเมือง+ปล่อย ไทยเท่าเดิม")
tr("en", newCapture, "Clan Wolves captured Saltmere (released Goldmeadow)", "ยึดเมือง+ปล่อย (อังกฤษ)")
tr("ja", ("แคลน %s ยึด%sได้แล้ว"):format("Wolves", "แอสตราเวล"), "クラン Wolves がアストラヴェイルを支配しました", "ยึดเมือง (ญี่ปุ่น)")

-- ประกาศข้ามเซิร์ฟ (Announce.Global) — AnnounceController แสดงผ่าน Locale.Show
check(L.Show("🏰 แคลน Wolves ยึดซอลต์เมียร์ได้แล้ว") ~= nil, "Show ประกาศยึดเมืองไม่พัง")
tr("en", ("🏰 แคลน %s ยึด%sได้แล้ว"):format("Wolves", "ซอลต์เมียร์"), "🏰 Clan Wolves captured Saltmere", "ประกาศยึดเมือง (อังกฤษ)")
tr("zh", ("🏰 แคลน %s ยึด%sได้แล้ว"):format("Wolves", "ซอลต์เมียร์"), "🏰 公会 Wolves 占领了盐湖镇", "ประกาศยึดเมือง (จีน)")

-- ยึดไม่ได้: เหตุผลซ้อนแม่แบบอีกชั้น (เดิม "ยึดไม่ได้: " .. why)
local why = ("รออีก %d ชม. %d นาที"):format(11, 5)
check(("ยึดไม่ได้: %s"):format(why) == "ยึดไม่ได้: " .. why, "ยึดไม่ได้ ไทยเท่าเดิม")
tr("en", ("ยึดไม่ได้: %s"):format(why), "Can't capture: Wait 11 h 5 min", "ยึดไม่ได้ + เหตุผลซ้อน (อังกฤษ)")
tr("zh", ("ยึดไม่ได้: %s"):format(("ต้องมีคนในเซิร์ฟ %d (ตอนนี้ %d)"):format(15, 4)), "无法占领：服务器需 15 人（现在 4）", "ยึดไม่ได้ คนไม่ครบ (จีน)")

-- ป้ายปุ่มอนุสาวรีย์ (PromptStackController ใช้ Show)
tr("en", ("%s — แคลน %s"):format("ซอลต์เมียร์", "Wolves"), "Saltmere — clan Wolves", "ObjectText เมือง+แคลน")

-- Clans: ชื่อสำรองสมาชิก (เดิม "ผู้เล่น " .. id) + ตำแหน่งจาก ClanConfig
check(("ผู้เล่น %s"):format("123") == "ผู้เล่น " .. "123", "ชื่อสำรอง ไทยเท่าเดิม")
tr("ja", "ผู้เล่น 123", "プレイヤー 123", "ชื่อสำรอง (ญี่ปุ่น)")
for _, role in ipairs(ClanConfig.Roles) do
	check(L.Translate("en", role.name) ~= role.name, "ตำแหน่งมีคำแปล: " .. role.name .. " → " .. L.Translate("en", role.name))
end
tr("zh", ("แจกจ่าย %d ซิลเวอร์ ให้ %d คน (เหลือ %d)"):format(300, 3, 50), "分发 300 银币给 3 人（剩余 50）", "แจกจ่าย (จีน)")

-- หน้าต่างฝั่งไคลเอนต์: ชื่อเมืองไทยที่ส่งเป็นอาร์กิวเมนต์ของ L แปลด้วย
check(L.T("en", "คลังเมือง — %s · แคลน %s", "ซอลต์เมียร์", "Wolves") == "Town vault — Saltmere · clan Wolves", "หัวคลังเมือง (อังกฤษ)")
check(L.T("th", "คลังเมือง — %s · แคลน %s", "ซอลต์เมียร์", "Wolves") == "คลังเมือง — ซอลต์เมียร์" .. " · แคลน " .. "Wolves", "หัวคลังเมือง ไทยเท่าเดิม")
check(L.T("ja", "พ่อค้า%s", "สโตนมาร์ก") == "ストーンマークの商人", "หัวพ่อค้าเมือง (ญี่ปุ่น)")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
