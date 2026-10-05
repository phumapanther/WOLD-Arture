-- node tools/offline-test.js tests/locale_p2_story_test.lua
-- หลายภาษาเฟส 2 กลุ่ม story (เนื้อเรื่อง · บอร์ดเควส · แถบเควส · ออฟาเรียน · ความสำเร็จ): ไทยเหมือนเดิมทุกไบต์ + ย้อนแปลได้ทั้งประโยค
local L = require(game.ReplicatedStorage.Locale)
local QuestConfig = require(game.ReplicatedStorage.QuestConfig)
local QuestLogRules = require(game.ReplicatedStorage.QuestLogRules)
local StoryConfig = require(game.ReplicatedStorage.StoryConfig)
local AchievementConfig = require(game.ReplicatedStorage.AchievementConfig)
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text if not ok then fails += 1 end end
local function tr(lang, text, want, label)
	local got = L.Translate(lang, text)
	check(got == want, label .. ": " .. tostring(got))
end
local function has(lang, thai) return L.T(lang, thai) ~= thai end

-- QuestNav.Send: เดิม ("ไม่มีจุด%s ในแมพนี้"):format(label and (" " .. label) or "") → สองแม่แบบ
for _, label in ipairs({ "หมาป่า", "", false }) do
	local lab = label or nil
	local old = ("ไม่มีจุด%s ในแมพนี้"):format(lab and (" " .. lab) or "")
	local new = lab and ("ไม่มีจุด %s ในแมพนี้"):format(lab) or "ไม่มีจุด ในแมพนี้"
	check(old == new, "ไม่มีจุด ไทยเท่าเดิม (" .. tostring(label) .. ")")
end
tr("en", "ไม่มีจุด หมาป่า ในแมพนี้", "No Wolf spot on this map", "ไม่มีจุด en")
tr("en", "ไม่มีจุด ในแมพนี้", "No such spot on this map", "ไม่มีจุด (ไม่มีชื่อ) en")

-- Achievements: "แร็งก์" .. name / "ฉายาเมือง · จบบท " .. name → แม่แบบ
check(("แร็งก์%s"):format("โกลด์") == "แร็งก์" .. "โกลด์", "ฉายาแร็งก์ ไทยเท่าเดิม")
check(("ฉายาเมือง · จบบท %s"):format("ความทรงจำแรก") == "ฉายาเมือง · จบบท " .. "ความทรงจำแรก", "โน้ตฉายาเมือง ไทยเท่าเดิม")
tr("ja", "ฉายาเมือง · จบบท ความทรงจำแรก", "町の称号 · 章「最初の記憶」クリア", "โน้ตฉายาเมือง ja")

-- Story.server ของขวัญ: body เดิม "ได้รับ " .. got → แม่แบบ · ชื่อเควสไคลเอนต์เติม 🎁 เอง
local aura = "✨ " .. "ออร่าน้ำแข็ง" .. " (ใส่ได้ที่กระเป๋า)"
check(("✨ %s (ใส่ได้ที่กระเป๋า)"):format("ออร่าน้ำแข็ง") == aura, "ออร่าจากเพื่อน ไทยเท่าเดิม")
check(("ได้รับ %s"):format(aura) == "ได้รับ " .. aura, "body ของขวัญ ไทยเท่าเดิม")
tr("en", "ได้รับ " .. aura, "Received ✨ Frost Aura (equip it from your bag)", "ของขวัญออร่า en (แม่แบบซ้อน)")
tr("zh", "ได้รับ 💎 150 เพชร", "获得 💎 150 钻石", "ของขวัญเพชร zh")
check("🎁 " .. L.Translate("ja", "ของขวัญผู้มาใหม่") == "🎁 新人への贈り物", "หัวป้ายของขวัญ ja")

-- StoryController ป้ายจบบท: เดิมต่อ "\nได้ฉายา ..." ด้วย :format → "\n" .. L(...) · ภาษาไทยต้องเท่าเดิม
local oldBody = "+500 EXP · +2,000 เหรียญ" .. ("\nได้ฉายา \"%s\" — เลือกใช้ได้ในสมุดสะสม"):format("ผู้ตื่นแห่งบราสเฮเวน")
	.. "\n🎁 ออฟาเรียน เทพหุ่นฟางมีของขวัญการเดินทางให้ — ไปพบที่ข้างจุดเกิด"
local newBody = "+500 EXP · " .. L.T("th", "+%s เหรียญ", "2,000") .. "\n" .. L.T("th", "ได้ฉายา \"%s\" — เลือกใช้ได้ในสมุดสะสม", "ผู้ตื่นแห่งบราสเฮเวน")
	.. "\n" .. L.T("th", "🎁 ออฟาเรียน เทพหุ่นฟางมีของขวัญการเดินทางให้ — ไปพบที่ข้างจุดเกิด")
check(oldBody == newBody, "ป้ายจบบท ไทยเท่าเดิม")
check(L.T("en", "ได้ฉายา \"%s\" — เลือกใช้ได้ในสมุดสะสม", "ผู้ตื่นแห่งบราสเฮเวน") == "Title \"Awakened of Brasshaven\" earned — equip it in the Collection Book",
	"ได้ฉายา en (ชื่อฉายาแปลเป็นอาร์กิวเมนต์)")

-- QuestTrackerController นำทาง: เดิม ("🧭 นำทางไป %s%s") + hint → แม่แบบละแบบ
for _, keyboard in ipairs({ true, false }) do
	local hint = keyboard and " — กด T เพื่อเดินอัตโนมัติ" or ""
	local old = ("🧭 นำทางไป %s%s"):format("โครงกระดูก", hint)
	local new = keyboard and ("🧭 นำทางไป %s — กด T เพื่อเดินอัตโนมัติ"):format("โครงกระดูก") or ("🧭 นำทางไป %s"):format("โครงกระดูก")
	check(old == new, "นำทาง ไทยเท่าเดิม (คีย์บอร์ด=" .. tostring(keyboard) .. ")")
end
tr("en", "🧭 นำทางไป โครงกระดูก — กด T เพื่อเดินอัตโนมัติ", "🧭 Navigating to Skeleton — press T to auto-walk", "นำทาง en")
tr("ja", "🧭 นำทางไป จุดหมาย", "🧭 目的地へ案内中", "นำทางไม่มีชื่อ ja")

-- QuestBoardGui / QuestTrackerGui: หัวกระดาน · บรรทัดรับได้ · หัวแถบเควส (เดิม format สองชั้น) ไทยเท่าเดิม
check(("กระดานงาน — %s%s"):format("บราสเฮเวน", " 🔒") == L.T("th", "กระดานงาน — %s", "บราสเฮเวน") .. " 🔒", "หัวกระดาน ไทยเท่าเดิม")
check(("%s · รับได้ %d/%d งาน%s"):format("เมืองหลวง", 1, 3, (" · สุ่มใหม่ไปแล้ว %d ครั้ง"):format(2))
	== L.T("th", "%s · รับได้ %d/%d งาน", "เมืองหลวง", 1, 3) .. L.T("th", " · สุ่มใหม่ไปแล้ว %d ครั้ง", 2), "บรรทัดรับได้ ไทยเท่าเดิม")
check(("📜 เควส (%d)%s"):format(4, "  · แตะเพื่อดู") == L.T("th", "📜 เควส (%d)  · แตะเพื่อดู", 4), "หัวแถบเควส ไทยเท่าเดิม")
check(L.T("en", "%s · รับได้ %d/%d งาน", "เมืองหลวง", 1, 3) == "Capital · Accepted 1/3 jobs", "บรรทัดรับได้ en")
check(L.T("zh", "กระดานงาน — %s", "ซอลต์เมียร์") == "任务布告板 — 盐湖镇", "หัวกระดาน zh")

-- งานบอร์ด: คำอธิบายจาก QuestConfig.Describe ย้อนแปลทั้งประโยค (ชื่อมอน/ไอเทมแปลซ้อน)
local hunt = QuestConfig.Describe({ kind = "hunt", mob = "โครงกระดูก", need = 3 })
check(hunt == "ล่าโครงกระดูก 3 ตัว", "Describe hunt ไทยเดิม")
tr("en", hunt, "Hunt Skeleton x3", "Describe hunt en")
tr("zh", QuestConfig.Describe({ kind = "hunt", mob = "แมงมุมยักษ์", need = 5 }), "猎杀巨型蜘蛛 5只", "Describe hunt zh")
local wood = { en = L.T("en", "เศษไม้"), ja = L.T("ja", "เศษไม้") }
check(wood.en ~= "เศษไม้", "ชื่อไอเทม เศษไม้ มีคำแปล")
tr("ja", QuestConfig.Describe({ kind = "gather", item = "WoodScrap", need = 15 }, "เศษไม้"), ("%sを15個納品"):format(wood.ja), "Describe gather ja")
tr("en", "ยังขาดอีก 2 — " .. QuestConfig.Describe({ kind = "gather", item = "WoodScrap", need = 15 }, "เศษไม้"),
	("2 more to go — Deliver %s x15"):format(wood.en), "ยังขาดอีก (ซ้อน Describe) en")
tr("en", QuestLogRules.BoardRow("k", "เศษไม้", "x", 15, 15).goal, "Done — return to the quest board", "แถวบอร์ดครบแล้ว en")

-- ข้อความเซิร์ฟ Quests/Achievements ทั้งประโยค
tr("en", "ส่งงานสำเร็จ +40 ซิลเวอร์ +500 เหรียญ +60 EXP", "Job complete +40 Silver +500 coins +60 EXP", "ส่งงานสำเร็จ en")
tr("ja", "สุ่มงานใหม่แล้ว 3 ใบ (-25 เพชร)", "依頼を3件引き直しました（-25ジェム）", "สุ่มงานใหม่ ja")
tr("en", "🏆 Bob ปลดความสำเร็จตำนาน \"ตำนาน\"", "🏆 Bob unlocked the legendary achievement \"Legend\"", "ประกาศตำนาน en")
tr("zh", "🏆 ปลดความสำเร็จ \"นักล่า\" — ฆ่ามอนรวม 1,000 ตัว · ได้ฉายา + เพชร 30", "🏆 解锁成就“猎人”——累计击杀1,000只怪物 · 获得称号 + 30 钻石", "ปลดความสำเร็จ zh")
tr("ja", "📜 เควสใหม่: ของขวัญผู้มาใหม่ — แตะที่แถบเควสเพื่อนำทาง", "📜 新クエスト：新人への贈り物 — クエストバーをタップで案内", "เควสใหม่ ja")
-- ฉายาเหนือหัว (TitleTagController Show(WOLD_Title)) + แถบประกาศข้ามเซิร์ฟ (AnnounceController Show)
tr("en", "ไลรา (Lyra)", "Lyra", "ป้ายชื่อไลรา en (ไม่ใช่ Lyra (Lyra))")
check(L.Translate("ja", "หัวแดง") ~= "หัวแดง", "ฉายาหัวแดง ja มีคำแปล")
tr("ja", ("🏆 %s ปลดความสำเร็จตำนาน \"%s\""):format("Bob", AchievementConfig.List[1].title),
	L.T("ja", "🏆 %s ปลดความสำเร็จตำนาน \"%s\"", "Bob", AchievementConfig.List[1].title), "ประกาศตำนาน ja (ชื่อฉายาแปลซ้อน)")
tr("en", "รออีก 12 วินาที", "Wait 12 more seconds", "รออีก %.0f en")

-- ข้อมูลทั้งหมดในคอนฟิกมีคำแปลครบสามภาษา
local missing = {}
local function need(thai, where)
	if type(thai) ~= "string" or thai == "" then return end
	for _, lang in ipairs({ "en", "zh", "ja" }) do
		if not has(lang, thai) then missing[#missing + 1] = lang .. " " .. where .. ": " .. thai end
	end
end
for id, lines in pairs(StoryConfig.Dialogues) do
	for _, line in ipairs(lines) do need(line.text, "Dialogues." .. id) end
end
for _, list in ipairs({ StoryConfig.Cutscene, StoryConfig.SkyCutscene, StoryConfig.Memories.m1 }) do
	for _, beat in ipairs(list) do need(beat.text, "beat") need(beat.title ~= "WOLD ARTURE" and beat.title or nil, "beat.title") need(beat.subtitle, "beat.subtitle") end
end
for _, ch in ipairs(StoryConfig.Chapters) do
	need(ch.name, "chapter") need(ch.goal, "chapter.goal") need(ch.title and ch.title.text, "chapter.title")
	for _, step in ipairs(ch.steps) do need(step.goal, "step") end
end
for _, q in pairs(StoryConfig.SideQuests) do need(q.title, "side") need(q.goal, "side.goal") end
for _, npc in pairs(StoryConfig.Npcs) do need(npc.name, "npc") end
for _, b in ipairs(QuestConfig.Boards) do
	need(b.name, "board") need(b.blurb, "blurb")
	for _, spec in ipairs(b.pool) do need(spec.mob, "pool.mob") end
end
for _, def in ipairs(AchievementConfig.List) do need(def.title, "ach") need(def.desc, "ach.desc") end
need(AchievementConfig.Special.marked.title, "marked")
-- ป้ายชื่อไลราในโลก (models/npcs.lua R.nametag) — StoryController แปลบนเครื่องผู้เล่น
need("ไลรา (Lyra)", "Lyra NameTag") need("[วิศวกรนาฬิกาจักรกลและมิติ]", "Lyra NameTag role")
check(#missing == 0, "คอนฟิกแปลครบ" .. (#missing > 0 and (" — ขาด " .. table.concat(missing, " | ")) or ""))

print(table.concat(out, "\n"))
print(fails == 0 and "PASS" or ("FAIL " .. fails))
