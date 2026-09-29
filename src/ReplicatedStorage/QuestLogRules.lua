-- QuestLogRules: กติกาแถบเควสรวม (ข้อมูลล้วน · เทส tests/quest_log_rules_test.lua · สเปก 2026-09-29-quest-log-oforian)
-- แถว = { key, color = "main"|"side"|"board", title, goal, need?, got?, state = "active"|"done"|"waiting"|"locked", reason? }
-- key: "story:<chapter>" (Story.server) · "side:<id>" (Story.server) · "board:<questKey>" (Quests.server) — เจ้าของ prefix เป็นคนนำทาง
local QuestLogRules = {}

QuestLogRules.Colors = {
	main = Color3.fromRGB(232, 196, 110), -- ทอง = เควสหลัก
	side = Color3.fromRGB(110, 190, 255), -- ฟ้า = เควสรองของออฟาเรียน
	board = Color3.fromRGB(226, 228, 236), -- ขาว = งานบอร์ด
}
local ORDER = { main = 1, side = 2, board = 3 }

function QuestLogRules.Dim(row)
	return row.state == "locked" or row.state == "waiting"
end

function QuestLogRules.DenyText(row)
	return row.reason or "เควสนี้ยังไม่เปิด"
end

function QuestLogRules.Progress(row)
	if not row.need or row.need <= 0 then return nil end
	return ("%d/%d"):format(math.min(row.got or 0, row.need), row.need)
end

function QuestLogRules.Merge(storyRows, boardRows)
	local list = {}
	for i, row in ipairs(storyRows or {}) do list[#list + 1] = { row = row, n = i } end
	for i, row in ipairs(boardRows or {}) do list[#list + 1] = { row = row, n = 1000 + i } end
	table.sort(list, function(a, b)
		local ca, cb = ORDER[a.row.color] or 9, ORDER[b.row.color] or 9
		if ca ~= cb then return ca < cb end
		local da, db = QuestLogRules.Dim(a.row) and 1 or 0, QuestLogRules.Dim(b.row) and 1 or 0
		if da ~= db then return da < db end
		return a.n < b.n
	end)
	local rows = {}
	for i, e in ipairs(list) do rows[i] = e.row end
	return rows
end

-- ส่งใหม่เฉพาะตอนลายเซ็นเปลี่ยน (ทรงเดียวกับ LastPushed ของ Story.server)
function QuestLogRules.Signature(rows)
	local parts = {}
	for _, r in ipairs(rows or {}) do
		parts[#parts + 1] = table.concat({ r.key or "", r.state or "", tostring(r.got or ""), tostring(r.need or ""), r.goal or "" }, ":")
	end
	return table.concat(parts, "|")
end

-- ตัวสร้างแถว: ทุกแหล่งใช้ตัวเดียวกัน หน้าตาจึงตรงกันเสมอ
function QuestLogRules.MainRow(chapter, step, got)
	return { key = "story:" .. chapter.id, color = "main", title = chapter.name, goal = step.goal,
		need = step.need, got = got, state = "active" }
end

function QuestLogRules.LockedRow(chapter)
	return { key = "story:" .. chapter.id, color = "main", title = chapter.name, goal = chapter.goal, state = "locked" }
end

function QuestLogRules.SideRow(quest, def)
	return { key = "side:" .. quest.id, color = "side", title = def and def.title or quest.id,
		goal = def and def.goal or "", state = quest.state, reason = quest.reason }
end

function QuestLogRules.BoardRow(key, title, goal, got, need)
	local done = (got or 0) >= (need or 1)
	return { key = "board:" .. key, color = "board", title = title, got = got, need = need,
		goal = done and "ครบแล้ว — กลับไปส่งที่บอร์ดเควส" or goal, state = done and "done" or "active" }
end

return QuestLogRules
