-- node tools/lua.js tests/story_test.lua Edit   (เพลสไหนก็ได้ — ข้อมูลล้วน)
-- เนื้อเรื่องบทแรก "ผู้มากับแสงวิบวับ" (ผู้ใช้อนุมัติร่าง 2026-09-27) + ล็อกบอร์ดเควสเมือง:
-- ขั้นครบ 5 ตามร่าง · บทพูดทุกตัวที่อ้างมีจริง · ของ/มอนที่ขอมีจริง · คัทซีน ~30 วิ · กติกาล็อกบอร์ด
local RS = game.ReplicatedStorage
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end
local S = fresh(RS.StoryConfig)
local Q = fresh(RS.QuestConfig)
local Catalog = fresh(RS.ItemCatalog)
local Gather = fresh(RS.GatherConfig)

local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local ch = S.Chapter("brasshaven")
check(ch ~= nil and ch.town == "Brasshaven" and ch.npc == "Lyra", "บทบราสเฮเวน · NPC ไลรา")
local kinds = {}
for _, step in ipairs(ch.steps) do kinds[#kinds + 1] = step.kind end
check(table.concat(kinds, ",") == "talk,deliver,hunt,reach,talk", "5 ขั้นตามร่าง: คุย/ส่งของ/ล่า/ไปจุดหมาย/คุย " .. table.concat(kinds, ","))
check(ch.steps[2].item == "Slime" and ch.steps[2].need == 5 and Catalog.Items.Slime ~= nil, "ขั้น 2 เมือกสไลม์ 5 ก้อน")
local mobNames = {}
for _, m in pairs(Gather.Mobs) do mobNames[m.name] = true end
check(ch.steps[3].mob == "โครงกระดูก" and ch.steps[3].need == 3 and mobNames["โครงกระดูก"], "ขั้น 3 ล่าโครงกระดูก 3 (ชื่อตรง GatherConfig)")
check(S.Memories[ch.steps[4].memory] ~= nil, "ขั้น 4 มีภาพความทรงจำ")
check(ch.reward.exp == 500 and ch.reward.gold == 2000, "รางวัล EXP 500 · 2,000 เหรียญ")
check(ch.title.id:sub(1, 6) == "story_" and ch.title.text == "ผู้ตื่นแห่งบราสเฮเวน", "ฉายาเมือง ผู้ตื่นแห่งบราสเฮเวน (id story_*)")
check(S.Title(ch.title.id) == ch.title, "หาฉายาจาก id ได้ (Achievements ใช้)")

-- บทพูดที่อ้างถึงมีจริงทุกตัว + คนพูดมีชื่อ
local refs = { ch.doneDialogue }
for _, step in ipairs(ch.steps) do
	for _, key in ipairs({ "dialogue", "wait", "after" }) do
		if step[key] then refs[#refs + 1] = step[key] end
	end
end
for _, id in ipairs(refs) do
	local lines = S.Dialogues[id]
	local speakersOk = lines ~= nil and #lines > 0
	for _, line in ipairs(lines or {}) do
		if line.who and not S.Npcs[line.who] then speakersOk = false end
		if type(line.text) ~= "string" or line.text == "" then speakersOk = false end
	end
	check(speakersOk, "บทพูด " .. id .. " มีจริงและคนพูดรู้จัก")
end

-- คัทซีน
local total, known = 0, true
local SHOTS = { black = true, rooftops = true, descend = true, flash = true, wake = true, lyra = true, lyraClose = true, title = true }
for _, beat in ipairs(S.Cutscene) do
	total += beat.seconds or 0
	if not SHOTS[beat.shot] then known = false end
end
check(total >= 24 and total <= 36, ("คัทซีนยาว ~30 วิ (%.1f)"):format(total))
check(known and #S.Cutscene == 8, "8 ช็อตตามร่าง ชื่อมุมกล้องที่ StoryController รู้จักทั้งหมด")
check(S.CutsceneMaxSeconds > total, "เพดานปลดตรึงตัวยาวกว่าคัทซีน")

-- ล็อกบอร์ดเมือง
check(Q.TownOpen("Brasshaven", false, nil) == true, "บราสเฮเวนเปิดให้สายฟรีตั้งแต่แรก")
local lockedAll = true
for _, b in ipairs(Q.Boards) do
	if b.id ~= "Brasshaven" and Q.TownOpen(b.id, false, {}) then lockedAll = false end
	if not Q.TownOpen(b.id, true, nil) then lockedAll = false end
end
check(lockedAll, "เมืองอื่นล็อกสายฟรีทั้งหมด · VIP เปิดทุกเมือง")
check(Q.TownOpen("Saltmere", false, { Saltmere = true }) == true, "จบบทเมืองไหน = ปลดบอร์ดเมืองนั้น")
check(type(Q.LockedText) == "string" and Q.LockedText:find("VIP") ~= nil, "ข้อความล็อกบอก VIP")

return ("%s — %d fail\n%s"):format(fails == 0 and "PASS" or "FAIL", fails, table.concat(out, "\n"))
