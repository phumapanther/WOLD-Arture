# แถบเควสรวม + เควสของออฟาเรียน + เกาะลอยฟ้า — แผนลงมือ

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** เควสทุกอย่างอยู่ในแถบเดียว (ทอง/ฟ้า/ขาว) จิ้มแล้วนำทาง · ของขวัญหุ่นฟางกลายเป็นเควสสีฟ้าของ "ออฟาเรียน เทพหุ่นฟาง" · Lv.5 รับ VIP → คัทซีนรถคาร์โก้ → วาปไปเกาะของตัวเอง

**Architecture:** เซิร์ฟเป็นคนประกอบแถว (Story.server = ทอง+ฟ้า ผ่าน `StoryState.rows` · Quests.server = ขาว ผ่าน `QuestLogBoard`) และเป็นคนหาเป้านำทาง (`QuestNav` เพราะ StreamingEnabled) · ไคลเอนต์ `QuestTrackerController` รวมด้วย `QuestLogRules.Merge` แล้ววาด `QuestTrackerGui` · สถานะเควสฟ้าคำนวณจากธงของขวัญเดิม (`VipGift.Quests`) ไม่มีที่เก็บใหม่

**Tech Stack:** Luau (Roblox) · ProfileStore · TeleportService (reserved server ผ่าน `Lobby/FarmRegistry`) · เทสด้วย `tools/offline-test.js` / `tools/lua.js <test> Edit`

**Spec:** `docs/superpowers/specs/2026-09-29-quest-log-oforian-design.md`

## Global Constraints

- ตอบผู้ใช้ภาษาไทย · **ผมไม่กด Play** ผู้ใช้เทสในเกมเอง · ห้ามแตะ `mapgen/90_island_placeables.lua` และ `assets/item-icons/สไน.png`
- ทุกครั้งที่แก้โค้ด: `bash tools/offline-check.sh <ไฟล์>` → `node tools/verify.js <default|farming|arena>.project.json --push` ครบสามเพลส แล้วรันซ้ำไม่ใส่ `--push` จน `mismatches 0`
- ห้ามใช้สัญลักษณ์ตัวอักษร ✦ ▶ ▾ ▲ (ฟอนต์ Roblox วาดเป็นกล่องเปล่า) — ใช้อีโมจิสีหรือ Frame
- ช่องทาง BindableEvent ฝั่งไคลเอนต์ห้ามอยู่ใน PlayerGui · ของที่อาจมาช้า (StreamingEnabled) ใช้ลูปถามใหม่ ห้ามผูกครั้งเดียว
- แถบเควส `DisplayOrder = 4` (ใต้ปุ่มมือถือ 5 และทุกหน้าต่าง 12+) · ขวาบน `(1,-12, 0,150)` · คอมเริ่มขยาย มือถือเริ่มย่อ
- ลำดับเควสฟ้าตอนคุย: newcomer → travel → friends → **sky ท้ายสุด** (มันจบด้วยการวาป) — ⚠️ สเปกเขียน "ลำดับตามตาราง" ซึ่งมี sky อันที่สอง · **Ruling:** sky ท้ายสุด ไม่งั้นของขวัญอื่นจะไม่ได้รับเพราะวาปไปก่อน
- commit บน main จบด้วย `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>` · add เฉพาะไฟล์ของงานนี้

## Review Focus

1. คุยกับออฟาเรียนตอนมีหลายเควสพร้อมกัน (รวม sky) — ของขวัญอื่นต้องได้ครบก่อน แล้วค่อยถามรับพร (เทสลำดับใน `vip_gift_test`)
2. กด "รับพร" ซ้ำ/กดตอนคัทซีนเล่นอยู่/โปรไฟล์ยังไม่โหลด — ต้องได้ VIP ครั้งเดียว วาปครั้งเดียว (`SkyOffered` + `InCutscene` + `SkyPending`)
3. จิ้มนำทางไปจุดที่ Navigation ปฏิเสธ (ในน้ำ/ไกลเกิน/ไม่มีจุดในแมพนี้) — ต้องมีข้อความ ไม่เงียบ
4. บัญชีเก่าที่รับของขวัญไปแล้ว (`VipGiftClaimed` ฯลฯ) — ต้องไม่มีเควสฟ้านั้นโผล่ (เทสใน `vip_gift_test`)
5. บทล็อกท้ายตาราง `Chapters` ต้องไม่ทำให้บทพูดจบของไลรา (`doneDialogue`) หายไป

---

### Task 1: กติกาแถบเควส (`QuestLogRules`)

**Files:**
- Create: `src/ReplicatedStorage/QuestLogRules.lua`
- Test: `tests/quest_log_rules_test.lua`

**Interfaces:**
- Produces: `QuestLogRules.Colors` · `Merge(storyRows, boardRows) -> rows` · `Dim(row)` · `DenyText(row)` · `Progress(row) -> "3/5"|nil` · `Signature(rows)` · `MainRow(chapter, step, got)` · `LockedRow(chapter)` · `SideRow(quest, def)` · `BoardRow(key, title, goal, got, need)`
- แถว = `{ key, color = "main"|"side"|"board", title, goal, need?, got?, state = "active"|"done"|"waiting"|"locked", reason? }`

- [ ] **Step 1: เขียนเทส**

```lua
-- node tools/offline-test.js tests/quest_log_rules_test.lua
-- แถบเควสรวม (สเปก 2026-09-29-quest-log-oforian): ทอง → ฟ้า → ขาว · ในสีเดียวกันของที่ทำได้ก่อนของที่ล็อก/รอ
local R = require(game.ReplicatedStorage.QuestLogRules)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local lyra = { id = "brasshaven", name = "ความทรงจำแรก" }
local main = R.MainRow(lyra, { goal = "นำเมือกสไลม์ไปให้ไลรา", need = 5 }, 7)
check(main.key == "story:brasshaven" and main.color == "main" and main.state == "active", "แถวเควสหลัก")
check(R.Progress(main) == "5/5", "ความคืบหน้าไม่เกินเป้า (มี 7 ต้องการ 5)")
local locked = R.LockedRow({ id = "saltmere", name = "เส้นทางสู่ซอลต์เมียร์", goal = "หาคำแนะนำจากเจ้าของฟาร์ม" })
check(locked.state == "locked" and R.Dim(locked) and R.DenyText(locked) == "เควสนี้ยังไม่เปิด", "แถวล็อก: จาง + ข้อความ")
local side = R.SideRow({ id = "newcomer", state = "waiting", reason = "รอเดือนหน้า" }, { title = "ของขวัญผู้มาใหม่", goal = "ไปพบออฟาเรียน" })
check(side.key == "side:newcomer" and R.Dim(side) and R.DenyText(side) == "รอเดือนหน้า", "แถวรอ: จาง + เหตุผลของตัวเอง")
local sky = R.SideRow({ id = "sky", state = "active" }, { title = "เกาะลอยฟ้าแห่งความฝัน", goal = "ไปพบออฟาเรียน" })
local b1 = R.BoardRow("Brasshaven|hunt|สไลม์เขียว", "สไลม์เขียว", "ล่าสไลม์ 5 ตัว", 2, 5)
local b2 = R.BoardRow("Brasshaven|gather|Wheat", "ข้าว", "เก็บข้าว 10", 10, 10)
check(b1.state == "active" and b2.state == "done" and b2.goal:find("ส่ง") ~= nil, "งานบอร์ดครบ = done + บอกให้กลับไปส่ง")
check(R.Progress({ need = nil }) == nil, "ไม่มีเป้าจำนวน = ไม่มีตัวนับ")

local rows = R.Merge({ side, locked, sky }, { b1, b2 })
local keys = {}
for _, r in ipairs(rows) do keys[#keys + 1] = r.key end
check(table.concat(keys, ",") == "story:saltmere,side:sky,side:newcomer,board:Brasshaven|hunt|สไลม์เขียว,board:Brasshaven|gather|Wheat",
	"เรียง ทอง → ฟ้า (ทำได้ก่อนรอ) → ขาว: " .. table.concat(keys, ","))
check(R.Merge(nil, nil)[1] == nil, "ไม่มีอะไร = รายการว่าง")
check(R.Signature({ b1 }) ~= R.Signature({ R.BoardRow("Brasshaven|hunt|สไลม์เขียว", "สไลม์เขียว", "ล่าสไลม์ 5 ตัว", 3, 5) }),
	"ความคืบหน้าเปลี่ยน = ลายเซ็นเปลี่ยน (ส่งใหม่)")
check(R.Colors.main ~= R.Colors.side and R.Colors.side ~= R.Colors.board, "สามสีต่างกัน")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
```

- [ ] **Step 2: รันให้เห็นว่าตก** — `node tools/offline-test.js tests/quest_log_rules_test.lua` · Expected: `require: ไม่ใช่ ModuleScript`

- [ ] **Step 3: เขียนโมดูล**

```lua
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
```

- [ ] **Step 4: รันเทส** — Expected: `PASS`
- [ ] **Step 5: commit** — `git add src/ReplicatedStorage/QuestLogRules.lua tests/quest_log_rules_test.lua` · `git commit -m "Quest log rules: merge story/side/board rows, colours, locked/waiting states"`

---

### Task 2: หาแหล่งของ/มอน/ปลา (`QuestNavRules` ข้อมูลล้วน + `QuestNav` ฝั่งเซิร์ฟ)

**Files:**
- Create: `src/ReplicatedStorage/QuestNavRules.lua` · `src/ServerScriptService/QuestNav.lua`
- Modify: `src/ReplicatedStorage/Remotes.lua` (เติม `"QuestLogBoard", "RequestQuestNav", "QuestNav"` ท้าย `EVENTS`)
- Test: `tests/quest_nav_rules_test.lua`

**Interfaces:**
- Produces: `QuestNavRules.NodeKindsFor(item) -> {NodeKind}` · `MobKindsFor(item) -> {MobKind}` · `MobKindsNamed(thaiName) -> {MobKind}` · `FishZones(item) -> {Vector2}`
- Produces: `QuestNav.Spawner(kinds, from)` · `Node(kinds, from)` · `ForItem(item, from)` · `FishZone(item, from)` · `Board(boardId, from)` · `Dummy()` · `ItemName(id)` · `Send(player, position|nil, label)` — ทุกตัวคืน `Vector3|nil`
- Remotes: `RequestQuestNav(key)` ไคลเอนต์→เซิร์ฟ · `QuestNav(position, label)` เซิร์ฟ→ไคลเอนต์ · `QuestLogBoard(rows)` เซิร์ฟ→ไคลเอนต์

- [ ] **Step 1: เขียนเทส**

```lua
-- node tools/offline-test.js tests/quest_nav_rules_test.lua
-- จิ้มเควสแล้วไปไหน (สเปก 2026-09-29): ของ → จุดเก็บที่ให้ของนั้นเป็นหลัก · ไม่มี → มอนที่ดรอป · ปลา → เขตตกปลา
local R = require(game.ReplicatedStorage.QuestNavRules)
local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end
local function has(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end

local wood = R.NodeKindsFor("WoodScrap")
check(has(wood, "Tree"), "ไม้ → ต้นไม้")
local iron = R.NodeKindsFor("IronOre")
local allIron = #iron > 0
for _, k in ipairs(iron) do if GatherConfig.Nodes[k].item ~= "IronOre" then allIron = false end end
check(allIron, "แร่เหล็ก → สายแร่เหล็กเท่านั้น (ไม่ใช่ก้อนหินที่มีโอกาส 1%)")
check(#R.NodeKindsFor("Slime") == 0, "เมือกไม่มีจุดเก็บ")
check(has(R.MobKindsFor("Slime"), "GreenSlime"), "เมือก → สไลม์เขียว")
local spider = R.MobKindsNamed("แมงมุมยักษ์")
check(#spider == 1 and spider[1] == "Spider", "ชื่อไทยมอน → ชนิด")
check(#R.MobKindsNamed("ไม่มีมอนนี้") == 0, "ชื่อที่ไม่มี = ว่าง")
check(#R.FishZones("Tanker") == 2, "ปลาประจำถิ่น → เขตของมัน + สระบนเกาะ (" .. #R.FishZones("Tanker") .. ")")
check(#R.FishZones("Fish") == 10, "ปลาธรรมดา → ทุกเขต")
check(#R.FishZones("NotAFish") == 0, "ไม่ใช่ปลา = ว่าง")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
```

- [ ] **Step 2: รันให้เห็นว่าตก** — Expected: `require: ไม่ใช่ ModuleScript`

- [ ] **Step 3: เขียน `QuestNavRules`**

```lua
-- QuestNavRules: เควสนี้ต้องไปหาอะไร (ข้อมูลล้วน อ่าน GatherConfig/FishingConfig · เทส tests/quest_nav_rules_test.lua)
-- ตัวหาตำแหน่งจริงอยู่ฝั่งเซิร์ฟ (`QuestNav`) — StreamingEnabled ทำให้ไคลเอนต์มองไม่เห็นของไกล
local GatherConfig = require(script.Parent.GatherConfig)
local FishingConfig = require(script.Parent.FishingConfig)

local QuestNavRules = {}
-- ของแถม/ของสุ่มที่โอกาสต่ำกว่านี้ไม่นับเป็น "แหล่ง" (ก้อนหินมีแร่ทุกชนิด 1% — ไม่ใช่ที่ที่ควรพาคนไปหาแร่)
QuestNavRules.MinChance = 0.2

local function sorted(t)
	table.sort(t)
	return t
end

-- ของหลักตรงก่อน · ไม่มีค่อยดู alt/bonus/roll ที่โอกาสถึงเกณฑ์
function QuestNavRules.NodeKindsFor(item)
	local primary, secondary = {}, {}
	for kind, node in pairs(GatherConfig.Nodes) do
		if node.item == item then
			primary[#primary + 1] = kind
		else
			local hit = (node.alt and node.alt.item == item and (node.alt.chance or 1) >= QuestNavRules.MinChance)
				or (node.bonus and node.bonus.item == item and (node.bonus.chance or 1) >= QuestNavRules.MinChance)
			if not hit and node.roll then
				for _, r in ipairs(node.roll) do
					if r.item == item and (r.chance or 0) >= QuestNavRules.MinChance then hit = true break end
				end
			end
			if hit then secondary[#secondary + 1] = kind end
		end
	end
	return sorted(#primary > 0 and primary or secondary)
end

-- มอนที่ดรอปของนี้ (ไม่นับบอส — บอสโลกไม่ใช่ที่ไปเก็บของส่งเควส)
function QuestNavRules.MobKindsFor(item)
	local out = {}
	for kind, mob in pairs(GatherConfig.Mobs) do
		if not mob.boss then
			for _, drop in ipairs(mob.drops or {}) do
				if drop.item == item then out[#out + 1] = kind break end
			end
		end
	end
	return sorted(out)
end

-- ชื่อไทย (ที่เควสเก็บ) → ชนิด
function QuestNavRules.MobKindsNamed(name)
	local out = {}
	for kind, mob in pairs(GatherConfig.Mobs) do
		if mob.name == name then out[#out + 1] = kind end
	end
	return sorted(out)
end

-- ปลาประจำถิ่น → เขตที่มีมัน · ปลาธรรมดา (อยู่ใน Loot) → ทุกเขต (ทุกเขตเป็นน้ำ) · อื่นๆ → ว่าง
function QuestNavRules.FishZones(item)
	local out = {}
	for _, zone in ipairs(FishingConfig.Zones) do
		for _, f in ipairs(zone.fish or {}) do
			if f.item == item then out[#out + 1] = zone.centre break end
		end
	end
	if #out > 0 then return out end
	for _, entry in ipairs(FishingConfig.Loot) do
		if entry.item == item then
			for _, zone in ipairs(FishingConfig.Zones) do out[#out + 1] = zone.centre end
			return out
		end
	end
	return out
end

return QuestNavRules
```

- [ ] **Step 4: รันเทส** — Expected: `PASS` (ถ้า `FishZones("Tanker")` ไม่ใช่ 2 ให้ดู `FishingConfig.Zones` แล้วแก้เลขในเทสตามข้อมูลจริง — Ruling ลงบันทึก)

- [ ] **Step 5: เขียน `QuestNav` (เซิร์ฟ) + remotes**

`src/ServerScriptService/QuestNav.lua`:

```lua
-- QuestNav: หา "จุดที่ใกล้ที่สุด" ให้แถบเควส (ฝั่งเซิร์ฟ — StreamingEnabled ทำให้ไคลเอนต์มองไม่เห็นสปอว์เนอร์/จุดเก็บที่อยู่ไกล)
-- กติกา "ของนี้มาจากไหน" อยู่ QuestNavRules (เทสได้) · ไฟล์นี้แค่เดินแท็กหาตำแหน่ง · ใช้ตอนจิ้มแถวเท่านั้น (ไม่ใช่ทุกเฟรม)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage.Remotes)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local QuestNavRules = require(game.ReplicatedStorage.QuestNavRules)

local QuestNav = {}

local function positionOf(inst)
	if inst:IsA("Model") then return inst:GetPivot().Position end
	if inst:IsA("BasePart") then return inst.Position end
	return nil
end

local function nearest(list, from, accept)
	local best, bestDistance
	for _, inst in ipairs(list) do
		if not accept or accept(inst) then
			local p = positionOf(inst)
			if p then
				local d = (p - from).Magnitude
				if not bestDistance or d < bestDistance then best, bestDistance = p, d end
			end
		end
	end
	return best
end

local function setOf(list)
	local s = {}
	for _, v in ipairs(list) do s[v] = true end
	return s
end

-- สปอว์เนอร์ของมอนชนิดนั้น (ข้ามสปอว์เนอร์อีเวนต์ — ว่างเปล่านอกอีเวนต์)
function QuestNav.Spawner(kinds, from)
	local want = setOf(kinds)
	return nearest(CollectionService:GetTagged("WOLD_Spawner"), from, function(s)
		return want[s:GetAttribute("MobKind")] == true and not s:GetAttribute("EventOnly")
	end)
end

-- จุดเก็บที่ยังไม่ถูกเก็บก่อน · ไม่มีเลยค่อยเอาที่ติดคูลดาวน์
function QuestNav.Node(kinds, from)
	local want = setOf(kinds)
	local nodes = CollectionService:GetTagged("WOLD_Node")
	return nearest(nodes, from, function(n) return want[n:GetAttribute("NodeKind")] == true and not n:GetAttribute("Spent") end)
		or nearest(nodes, from, function(n) return want[n:GetAttribute("NodeKind")] == true end)
end

function QuestNav.ForItem(item, from)
	local kinds = QuestNavRules.NodeKindsFor(item)
	local at = #kinds > 0 and QuestNav.Node(kinds, from) or nil
	if at then return at end
	local mobs = QuestNavRules.MobKindsFor(item)
	return #mobs > 0 and QuestNav.Spawner(mobs, from) or nil
end

-- ริมน้ำของเขตตกปลาที่ใกล้สุด — กลางเขตเป็นน้ำ และ Navigation ปฏิเสธจุดหมายในน้ำ
function QuestNav.Shore(centre)
	local params = RaycastParams.new()
	params.IgnoreWater = false
	params.FilterType = Enum.RaycastFilterType.Exclude
	local characters = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then characters[#characters + 1] = p.Character end
	end
	params.FilterDescendantsInstances = characters
	for radius = 30, 120, 15 do
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2
			local x, z = centre.X + math.cos(a) * radius, centre.Y + math.sin(a) * radius
			local hit = workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -4000, 0), params)
			if hit and hit.Material ~= Enum.Material.Water then return hit.Position end
		end
	end
	return nil
end

function QuestNav.FishZone(item, from)
	local best, bestDistance
	for _, c in ipairs(QuestNavRules.FishZones(item)) do
		local d = (Vector2.new(from.X, from.Z) - c).Magnitude
		if not bestDistance or d < bestDistance then best, bestDistance = c, d end
	end
	return best and QuestNav.Shore(best) or nil
end

-- บอร์ดของเมืองนั้น · ไม่มี (บนเกาะ = บอร์ดรวม) → บอร์ดที่ใกล้สุด
function QuestNav.Board(boardId, from)
	local boards = CollectionService:GetTagged("WOLD_QuestBoard")
	return nearest(boards, from, function(b) return b:GetAttribute("BoardId") == boardId end) or nearest(boards, from)
end

-- หุ่นฟางข้างจุดเกิดแรก = ออฟาเรียน
function QuestNav.Dummy()
	for _, d in ipairs(CollectionService:GetTagged("WOLD_Dummy")) do
		if d.Name == "Dummy_Spawn" then return positionOf(d) end
	end
	return nil
end

function QuestNav.ItemName(id)
	local item = ItemCatalog.Get(id)
	return item and item.name or tostring(id)
end

-- ส่งเป้าให้ไคลเอนต์ปักหมุด · หาไม่เจอ = บอก (ไม่เงียบ)
function QuestNav.Send(player, position, label)
	if position then
		Remotes.QuestNav:FireClient(player, position, label or "")
	else
		Remotes.SocialNotify:FireClient(player, "warn", ("ไม่มีจุด%s ในแมพนี้"):format(label and (" " .. label) or ""))
	end
end

return QuestNav
```

`src/ReplicatedStorage/Remotes.lua` — แทรกก่อน `}` ที่ปิด `EVENTS` (หลังบรรทัด `"RequestMail", "MailUpdate",`):

```lua
	-- แถบเควสรวม (2026-09-29): เซิร์ฟ → QuestLogBoard(แถวงานบอร์ด) · ไคลเอนต์ → RequestQuestNav(key) · เซิร์ฟ → QuestNav(ตำแหน่ง, ชื่อ)
	"QuestLogBoard", "RequestQuestNav", "QuestNav",
```

- [ ] **Step 6: ตรวจ + ดัน + รันเทสใน Studio** — `bash tools/offline-check.sh src/ReplicatedStorage/QuestNavRules.lua src/ServerScriptService/QuestNav.lua src/ReplicatedStorage/Remotes.lua` → ดันสามเพลส → `node tools/lua.js tests/quest_nav_rules_test.lua Edit` · Expected: `PASS`
- [ ] **Step 7: commit** — `git add src/ReplicatedStorage/QuestNavRules.lua src/ServerScriptService/QuestNav.lua src/ReplicatedStorage/Remotes.lua tests/quest_nav_rules_test.lua` · `git commit -m "Quest navigation: find item/mob/fish sources and nearest targets server-side"`

---

### Task 3: เควสฟ้าจากธงของขวัญเดิม (`VipGift.Quests` · VIP ทบเวลา)

**Files:**
- Modify: `src/ServerScriptService/VipGift.lua`
- Test: `tests/vip_gift_test.lua` (แก้ของเดิม)

**Interfaces:**
- Produces: `VipGift.Quests(data, now, level, friends, pool, hasPremium) -> { { id = "newcomer"|"travel"|"friends"|"sky", state = "active"|"waiting", reason? } }` (ลำดับ newcomer, travel, friends, sky) · `VipGift.AuraPool() -> {itemId}`
- Changes: `VipGift.Check` ไม่ปฏิเสธคนที่มี VIP อยู่ · `VipGift.Claim` ทบเวลา · **ลบ `VipGift.Summary`** (ไม่มีใครใช้หลัง Task 6)

- [ ] **Step 1: แก้เทสให้เป็นกติกาใหม่** (`tests/vip_gift_test.lua`)
  1. บรรทัด `check(select(2, can({ VipUntil = now + 60 })) == "active", "มี VIP อยู่ = รับไม่ได้")` → 
     `check(select(1, can({ VipUntil = now + 60 })) == true, "มี VIP อยู่ = ยังรับได้ (ทบ +30 วัน · ผู้ใช้สั่ง 2026-09-29)")`
  2. บล็อก `local busy = ...` ถึง `"มี VIP อยู่แล้วกด = ไม่เสียสิทธิ์ ไม่แตะวันหมดอายุ")` →
     ```lua
     local busy = { VipUntil = now + 100 }
     local okBusy = VipGift.Claim(busy, now, LV)
     check(okBusy == true and busy.VipGiftClaimed == true and busy.VipUntil == now + 100 + 30 * 86400,
     	"มี VIP อยู่แล้วรับ = ทบต่อท้ายเวลาที่เหลือ")
     ```
  3. สองบรรทัด `local waitList = VipGift.Summary(...)` + `check(#waitList ...)` →
     ```lua
     local earlyQuests = VipGift.Quests(early, now, 1, 0, {}, false)
     check(#earlyQuests == 1 and earlyQuests[1].id == "newcomer", "ยังไม่จบบท = ยังไม่มีเควสของขวัญการเดินทาง")
     ```
  4. สี่บรรทัด `local wait = VipGift.Summary(bought, ...)` ถึง `check(foundWait, ...)` →
     ```lua
     local qb = VipGift.Quests(bought, now, 1, 0, {}, true)
     check(qb[1] ~= nil and qb[1].id == "newcomer" and qb[1].state == "waiting" and (qb[1].reason or ""):find("เดือนหน้า") ~= nil,
     	"พาสเดือนนี้ปลดแล้ว = เควสรอเดือนหน้า")
     ```
  5. ทั้งบล็อก `----- ป้ายปุ่ม` (s0 ถึง s4) →
     ```lua
     ----------------------------------------------------------------- เควสสีฟ้าของออฟาเรียน (2026-09-29)
     local function ids(rows)
     	local t = {}
     	for _, r in ipairs(rows) do t[#t + 1] = r.id .. ":" .. r.state end
     	return table.concat(t, ",")
     end
     check(ids(VipGift.Quests({ NewbieGems = true, VipUntil = 0 }, now, 1, 0, POOL)) == "newcomer:active", "ผู้เล่นใหม่ Lv.1 = ของขวัญผู้มาใหม่อย่างเดียว")
     check(ids(VipGift.Quests({ NewbieGems = true, VipUntil = 0, Story = { ch = { brasshaven = { done = true } } } }, now, 1, 0, POOL))
     	== "newcomer:active,travel:active", "จบบทไลรา = ของขวัญการเดินทางโผล่")
     check(ids(VipGift.Quests({ NewbieGemsClaimed = true, NewbiePassClaimed = true, NewbieGems = true, VipUntil = 0 }, now, 6, 5, POOL))
     	== "friends:active,sky:active", "Lv.6 เพื่อน 5 = สายใยมิตรภาพ แล้วเกาะลอยฟ้าท้ายสุด (จบด้วยการวาป)")
     check(ids(VipGift.Quests({ VipUntil = now + 99 }, now, 5, 0, POOL)) == "sky:active", "บัญชีเก่ามี VIP อยู่ Lv.5 = ได้เควสเกาะ (ทบเวลา)")
     check(ids(VipGift.Quests({ NewbieGemsClaimed = true, VipGiftClaimed = true, FriendAuraClaimed = "Aura_A" }, now, 9, 9, POOL)) == "",
     	"รับของขวัญเดิมไปแล้ว = ไม่มีเควสฟ้าเลย")
     check(ids(VipGift.Quests({}, now, 4, 4, POOL)) == "", "บัญชีเก่า Lv.4 เพื่อน 4 = ยังไม่โผล่อะไร")
     check(#VipGift.Quests(nil, now, 9, 9, POOL) == 0, "โปรไฟล์ยังไม่โหลด = ไม่มีแถว")
     check(#VipGift.AuraPool() > 0, "สระออร่าจากแคตตาล็อกไม่ว่าง")
     ```

- [ ] **Step 2: รันให้เห็นว่าตก** — `node tools/lua.js tests/vip_gift_test.lua Edit` · Expected: fail (Quests เป็น nil)

- [ ] **Step 3: แก้ `VipGift.lua`**
  - เพิ่มบรรทัด require ต่อจาก `local Vip = require(script.Parent.Vip)`: `local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)`
  - หัวไฟล์: บรรทัด `--   vip  — VIP 30 วัน **เมื่อ Lv.5 ขึ้นไป** ... มี VIP อยู่ = รับไม่ได้และไม่เสียสิทธิ์` → `--   vip  — VIP 30 วัน **เมื่อ Lv.5 ขึ้นไป** · มี VIP อยู่ = ทบ +30 วัน (ผู้ใช้สั่ง 2026-09-29 · เควส "เกาะลอยฟ้าแห่งความฝัน")`
  - บรรทัด `-- ไม่มี Player ไม่มี remote — \`VipGiftPrompt.server\` ต่อปุ่มและส่งของ` → `-- ไม่มี Player ไม่มี remote — ทั้งหมดมาเป็นเควสสีฟ้าของออฟาเรียน (\`Story.server\` TalkOforian · \`VipGift.Quests\`)`
  - ใน `VipGift.Check`: ลบบรรทัด `if Vip.ActiveData(data, now) then return false, "active" end` และแก้คอมเมนต์เหตุผลเป็น `"closed" | "loading" | "claimed" | "level"`
  - ใน `VipGift.Claim`: `if not Vip.GrantData(data, VipGift.Days, true, now) then return false, "active" end` → `if not Vip.GrantData(data, VipGift.Days, false, now) then return false, "loading" end`
  - ลบทั้งหัวข้อ `-- ป้ายบนปุ่มของคนคนนี้` และฟังก์ชัน `VipGift.Summary` แล้ววางแทนด้วย:

```lua
--------------------------------------------------------------------------------
-- เควสสีฟ้าของออฟาเรียน เทพหุ่นฟาง (2026-09-29 · สเปก 2026-09-29-quest-log-oforian)
--------------------------------------------------------------------------------

-- ออร่าทุกชิ้นที่มีในเกมตอนนี้ (ผู้ใช้สั่ง "สุ่มออร่าที่มีในปัจจุบัน") — ออร่าใหม่เข้าสระเอง
function VipGift.AuraPool()
	local out = {}
	for id, item in pairs(ItemCatalog.Items) do
		if type(item) == "table" and item.kind == "aura" then out[#out + 1] = id end
	end
	table.sort(out)
	return out
end

-- แถวเควสที่ค้างอยู่ **คำนวณจากธงเดิมทั้งหมด** (ไม่มีที่เก็บใหม่ — สิทธิ์ของขวัญเดิมคือสิทธิ์เดียวกัน)
-- ก่อนถึงเงื่อนไขไม่มีแถวเลย (ผู้ใช้สั่ง "พอเวล 5 เควสเด้งทันที") ยกเว้นพาสที่ `waiting` รอเดือนหน้า
-- ลำดับ = ลำดับที่คุยแล้วได้ · **sky ท้ายสุดเสมอ** เพราะจบด้วยการวาป ของอย่างอื่นต้องได้ก่อน
function VipGift.Quests(data, now, level, friends, pool, hasPremium)
	local rows = {}
	if not VipGift.Enabled or not data then return rows end
	local passOk, passWhy = VipGift.CheckPass(data, hasPremium)
	if passOk then
		rows[#rows + 1] = { id = "newcomer", state = "active" }
	elseif passWhy == "owned" then
		rows[#rows + 1] = { id = "newcomer", state = "waiting", reason = "เดือนนี้ปลดพาสพรีเมียมแล้ว — กลับมารับเดือนหน้า" }
	end
	if VipGift.CheckGems(data) then rows[#rows + 1] = { id = "travel", state = "active" } end
	if VipGift.CheckAura(data, friends, pool) then rows[#rows + 1] = { id = "friends", state = "active" } end
	if VipGift.Check(data, now, level) then rows[#rows + 1] = { id = "sky", state = "active" } end
	return rows
end
```

- [ ] **Step 4: ดัน + รันเทส** — `bash tools/offline-check.sh src/ServerScriptService/VipGift.lua` → ดันสามเพลส → `node tools/lua.js tests/vip_gift_test.lua Edit` · Expected: `0 fail(s)`
- [ ] **Step 5: commit** — `git add src/ServerScriptService/VipGift.lua tests/vip_gift_test.lua` · `git commit -m "Scarecrow gifts become quest rows (VipGift.Quests); the Lv.5 VIP now stacks onto active VIP"`

> ⚠️ ระหว่าง Task 3 ถึง Task 6 ปุ่มหุ่นฟางเดิม (`VipGiftPrompt.server`) ยังเรียก `VipGift.Summary` — ห้าม push Task 3 เดี่ยวๆ ขึ้นเกมจริง (ผู้ใช้ไม่ publish ระหว่างนี้อยู่แล้ว) · Task 6 แทนไฟล์นั้น

---

### Task 4: ข้อมูลเรื่อง (`StoryConfig`)

**Files:**
- Modify: `src/ReplicatedStorage/StoryConfig.lua`
- Test: `tests/story_config_test.lua` (ใหม่)

**Interfaces:**
- Produces: `StoryConfig.Npcs.Oforian` · `StoryConfig.SideQuests[id] = { title, goal, dialogue }` · `StoryConfig.OforianIdle = "o_idle"` · Dialogues `o_idle o_newcomer o_travel o_friends o_sky island_welcome` · บทล็อก `saltmere` · `StoryConfig.SkyCutscene` · `StoryConfig.SkyTitle` `SkySubtitle` · `StoryConfig.Current(story) -> chapter, progress, lockedChapter`

- [ ] **Step 1: เขียนเทส**

```lua
-- node tools/offline-test.js tests/story_config_test.lua
-- ข้อมูลเรื่อง (2026-09-29): บทล็อกไม่เริ่ม · บทพูดของทุกเควสฟ้ามีจริง · คัทซีนรถมีครบทุกฉาก
local S = require(game.ReplicatedStorage.StoryConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local fresh = { ch = {} }
local ch, p, locked = S.Current(fresh)
check(ch and ch.id == "brasshaven" and p.step == 1 and locked == nil, "คนใหม่ = บทไลรา ขั้น 1")
local done = { ch = { brasshaven = { step = 5, done = true } } }
ch, p, locked = S.Current(done)
check(ch == nil and p == nil and locked and locked.id == "saltmere", "จบบทไลรา = ไม่มีบทเล่น + คืนบทล็อก")
check(done.ch.saltmere == nil, "บทล็อกไม่ถูกสร้างความคืบหน้า")
check(locked.goal == "หาคำแนะนำจากเจ้าของฟาร์มเพื่อเดินทางไปยังซอลต์เมียร์", "ข้อความบทล็อกตรงสเปก")
check(S.Npcs.Oforian and S.Npcs.Oforian.name == "ออฟาเรียน เทพหุ่นฟาง", "ชื่อเทพ")
for _, id in ipairs({ "newcomer", "travel", "friends", "sky" }) do
	local def = S.SideQuests[id]
	check(def and def.title ~= "" and S.Dialogues[def.dialogue] ~= nil, "เควสฟ้า " .. id .. " มีชื่อ + บทพูด")
end
check(S.SideQuests.sky.title == "เกาะลอยฟ้าแห่งความฝัน" and S.SideQuests.friends.title == "สายใยมิตรภาพ", "ชื่อเควสตรงที่ผู้ใช้อนุมัติ")
check(S.Dialogues[S.OforianIdle] ~= nil and S.Dialogues.island_welcome ~= nil, "บทพูดทักทาย + ต้อนรับบนเกาะ")
local shots = {}
for _, beat in ipairs(S.SkyCutscene) do shots[#shots + 1] = beat.shot end
check(table.concat(shots, ",") == "glow,truck,board,rise,clouds,flash,title", "คัทซีนรถ 7 ฉากตามสเปก")
local total = 0
for _, beat in ipairs(S.SkyCutscene) do total += beat.seconds end
check(total >= 20 and total <= 30, ("คัทซีนยาว ~25 วิ (%.1f)"):format(total))
check(S.Title("story_brasshaven") ~= nil, "ฉายาบทไลรายังหาเจอ (บทล็อกไม่มีฉายา ไม่ทำพัง)")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
```

- [ ] **Step 2: รันให้เห็นว่าตก** — Expected: error `Current` เป็น nil

- [ ] **Step 3: แก้ `StoryConfig.lua`**
  - `StoryConfig.Npcs` เพิ่ม: `Oforian = { name = "ออฟาเรียน เทพหุ่นฟาง", color = Color3.fromRGB(255, 214, 120) }, -- หุ่นฟางข้างจุดเกิดแรก (Dummy_Spawn) · ไม่ใช่ WOLD_StoryNpc`
  - `StoryConfig.Dialogues` เพิ่มท้ายตาราง (ก่อน `}` ปิด):

```lua
	-- ออฟาเรียน เทพหุ่นฟาง (2026-09-29 ผู้ใช้อนุมัติบทพูด)
	o_idle = {
		{ who = "Oforian", text = "ทุ่งนายังเขียวดีอยู่… เจ้าเองก็เติบโตต่อไปนะ" },
	},
	o_newcomer = {
		{ who = "Oforian", text = "ข้าคือออฟาเรียน ผู้เฝ้าทุ่งนาแห่งอาร์ตูร์มาตั้งแต่ก่อนเมืองนี้จะมีเครื่องจักรสักตัว" },
		{ who = "Oforian", text = "ผู้มาใหม่ทุกคนที่ผ่านหน้าข้าไป ข้าจะมอบพรเล็กๆ ติดตัวไว้เสมอ" },
		{ who = "Oforian", text = "รับม้วนพรแห่งฤดูกาลนี้ไป — ทุกครั้งที่เจ้าเติบโต มันจะตอบแทนเจ้า" },
	},
	o_sky = {
		{ who = "Oforian", text = "ข้าเฝ้ามองเจ้ามาตลอด ตั้งแต่วันแรกที่เจ้าหยิบจอบขึ้นมา" },
		{ who = "Oforian", text = "ห้าก้าวแห่งการเติบโต… น้อยคนนักจะเดินมาได้ไกลขนาดนี้โดยไม่หยุด" },
		{ who = "Oforian", text = "เหนือเมฆขึ้นไปมีเกาะที่เหล่าเทพใช้พักผ่อน — เกาะลอยฟ้าแห่งความฝัน" },
		{ who = "Oforian", text = "ข้าจะมอบสิทธิ์ให้เจ้าครอบครองมันสามสิบวัน ปลูก เลี้ยง สร้างมันตามใจเจ้า" },
	},
	o_travel = {
		{ who = "Oforian", text = "เจ้าช่วยไลราไขความลับของวงเวทได้แล้ว… ข่าวไปถึงหูข้าเร็วกว่าลมเสียอีก" },
		{ who = "Oforian", text = "การเดินทางของเจ้าเพิ่งเริ่ม รับนี่ไว้เป็นเสบียง — เพชรจากใต้รากทุ่งนาของข้า" },
	},
	o_friends = {
		{ who = "Oforian", text = "ข้าเห็นว่าเจ้าไม่ได้เดินทางคนเดียวอีกแล้ว" },
		{ who = "Oforian", text = "มิตรภาพเป็นสิ่งที่แม้แต่เทพก็สร้างเองไม่ได้ ข้าจึงอยากให้มันมีแสงให้คนอื่นเห็น" },
		{ who = "Oforian", text = "รับแสงนี้ไป ให้มันห้อมล้อมเจ้าทุกที่ที่เจ้าไป" },
	},
	island_welcome = {
		{ who = "Oforian", text = "(เสียงของออฟาเรียนลอยมากับลม) ที่นี่เป็นของเจ้าแล้ว ผู้เติบโต" },
		{ who = "Oforian", text = "ดินผืนนี้ตอบแทนคนที่ดูแลมัน — ปลูก เลี้ยง แล้วส่งผลผลิตไปกับรถคันนั้นเถิด" },
	},
```

  - `StoryConfig.Chapters` ต่อท้ายบทไลรา (ก่อน `}` ปิดตาราง):

```lua
	-- บทถัดไปแบบล็อก (2026-09-29): แถวทองจาง + 🔒 ให้รู้ว่ามีต่อ · วันที่เขียนบทจริง ถอด `locked` แล้วใส่ขั้น/NPC
	{
		id = "saltmere", town = "Saltmere", locked = true, name = "เส้นทางสู่ซอลต์เมียร์",
		goal = "หาคำแนะนำจากเจ้าของฟาร์มเพื่อเดินทางไปยังซอลต์เมียร์", steps = {},
	},
```

  - หลังตาราง `StoryConfig.Chapters` เพิ่ม:

```lua
-- เควสรองของออฟาเรียน (สีฟ้า) · ของ/ธง/ลำดับอยู่ที่ `VipGift.Quests` · ที่นี่คือชื่อกับบทพูด
StoryConfig.SideQuests = {
	newcomer = { title = "ของขวัญผู้มาใหม่", goal = "ไปพบออฟาเรียน เทพหุ่นฟาง ข้างจุดเกิด", dialogue = "o_newcomer" },
	travel = { title = "ของขวัญการเดินทาง", goal = "ไปพบออฟาเรียน เทพหุ่นฟาง ข้างจุดเกิด", dialogue = "o_travel" },
	friends = { title = "สายใยมิตรภาพ", goal = "ไปพบออฟาเรียน เทพหุ่นฟาง ข้างจุดเกิด", dialogue = "o_friends" },
	sky = { title = "เกาะลอยฟ้าแห่งความฝัน", goal = "ไปพบออฟาเรียน เทพหุ่นฟาง ข้างจุดเกิด", dialogue = "o_sky" },
}
StoryConfig.OforianIdle = "o_idle"

-- คัทซีนรถคาร์โก้ (~24.5 วิ · shot ที่ StoryController รู้จัก: glow truck board rise clouds flash title)
StoryConfig.SkyTitle = "เกาะลอยฟ้าแห่งความฝัน"
StoryConfig.SkySubtitle = "ของขวัญจากออฟาเรียน · 30 วัน"
StoryConfig.SkyCutscene = {
	{ shot = "glow", seconds = 3.5, who = "Oforian", text = "จงไปเถิด ผู้เติบโต…" },
	{ shot = "truck", seconds = 4.5, text = "ไอน้ำพวยพุ่ง ฟ้าแลบแปลบ — รถคันหนึ่งก่อตัวขึ้นจากแสง" },
	{ shot = "board", seconds = 2.5, text = "คุณก้าวขึ้นรถ…" },
	{ shot = "rise", seconds = 5, text = "รถลอยขึ้นเหนือหลังคาบราสเฮเวน" },
	{ shot = "clouds", seconds = 4, text = "ทะลุผ่านเมฆขึ้นไป…" },
	{ shot = "flash", seconds = 1 },
	{ shot = "title", seconds = 4, title = StoryConfig.SkyTitle, subtitle = StoryConfig.SkySubtitle },
}
```

  - ก่อน `function StoryConfig.Chapter(id)` เพิ่ม:

```lua
-- บทที่กำลังเล่น + ความคืบหน้า (สร้างให้ถ้ายังไม่มี) · เจอบทที่ `locked` = หยุด ไม่สร้างความคืบหน้า คืนเป็นค่าที่สาม (แถวล็อก)
function StoryConfig.Current(story)
	for _, ch in ipairs(StoryConfig.Chapters) do
		if ch.locked then return nil, nil, ch end
		local p = story.ch[ch.id]
		if type(p) ~= "table" then
			p = { step = 1, got = 0 }
			story.ch[ch.id] = p
		end
		if not p.done then return ch, p, nil end
	end
	return nil, nil, nil
end
```

- [ ] **Step 4: รันเทส** — `node tools/offline-test.js tests/story_config_test.lua` · Expected: `PASS`
- [ ] **Step 5: commit** — `git add src/ReplicatedStorage/StoryConfig.lua tests/story_config_test.lua` · `git commit -m "Story data: Oforian, four side quests, locked Saltmere chapter, cargo-truck cutscene beats"`

---

### Task 5: `Story.server` — แถวทอง/ฟ้า · คุยกับออฟาเรียน · รับพร → คัทซีน → วาป · นำทาง

**Files:**
- Modify: `src/ServerScriptService/Story.server.lua` · `src/ServerScriptService/StoryAccess.lua`

**Interfaces:**
- Consumes: `StoryConfig.Current/SideQuests/OforianIdle` (T4) · `VipGift.Quests/AuraPool/Claim*` (T3) · `QuestLogRules.MainRow/LockedRow/SideRow/Signature` (T1) · `QuestNav.*` + `Remotes.RequestQuestNav/QuestNav` (T2)
- Produces: `StoryState` มีฟิลด์ `rows` เสมอ (ทั้งตอนมีบทและตอน `done`) · `StoryAccess.TalkOforian(player)` · StoryPlay kinds ใหม่: `"newQuest"(title)` `"gift"({title, body})` `"skyOffer"` `"skyCutscene"({at})` `"skyFailed"(text)` · RequestStory actions ใหม่: `"sky_accept"` `"sky_warp"` · Admin `/story gifts` `/story welcome`
- ข้อมูลโปรไฟล์ใหม่: `Story.pop[key] = true` (ป้ายเควสใหม่ครั้งเดียว) · `Story.skyWelcome = true` (รอป้ายต้อนรับบนเกาะ)

- [ ] **Step 1: `StoryAccess.lua`** — ต่อท้ายก่อน `return`:

```lua
-- TalkOforian(player) — ปุ่ม "คุยกับออฟาเรียน" บนหุ่นฟาง (VipGiftPrompt.server เรียก · Story.server ตั้ง)
StoryAccess.TalkOforian = nil
```

- [ ] **Step 2: requires + ตัวแปร** — แทนบรรทัด `local StoryAccess = require(script.Parent.StoryAccess)` ด้วย:

```lua
local StoryAccess = require(script.Parent.StoryAccess)
local VipGift = require(script.Parent.VipGift)
local Vip = require(script.Parent.Vip)
local Friends = require(script.Parent.Friends)
local PremiumAccess = require(script.Parent.PremiumAccess)
local QuestNav = require(script.Parent.QuestNav)
local FarmRegistry = require(script.Parent.Lobby.FarmRegistry)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local QuestLogRules = require(game.ReplicatedStorage.QuestLogRules)
local QuestNavRules = require(game.ReplicatedStorage.QuestNavRules)
local TeleportService = game:GetService("TeleportService")
```

และหลัง `local LastPushed = {}` เพิ่ม:

```lua
local SkyOffered = {} -- [player] = true ระหว่างถามรับพร (กันยิง sky_accept เอง)
local SkyPending = {} -- [player] = token ระหว่างคัทซีนรถ (วาปครั้งเดียว)
local Warping = {} -- [player] = true ระหว่างรอ TeleportService (ไว้บอกตอนวาปไม่สำเร็จ)
local AURAS = VipGift.AuraPool()
local rng = Random.new()
```

- [ ] **Step 3: `current()` ใช้ตัวกลาง** — แทนทั้งฟังก์ชัน `local function current(s) ... end` ด้วย:

```lua
-- บทที่กำลังเล่น (บทแรกที่ยังไม่จบ) + ความคืบหน้า · ค่าที่สาม = บทล็อกถัดไป (StoryConfig.Current)
local function current(s)
	return StoryConfig.Current(s)
end
```

- [ ] **Step 4: แถว + ป้ายเควสใหม่** — ก่อน `local function stateOf(player)` เพิ่ม:

```lua
local function hasPremium(player)
	return PremiumAccess.HasPremiumPass ~= nil and PremiumAccess.HasPremiumPass(player) == true
end

local function friendCount(player)
	local state = Friends.Get(player)
	local n = 0
	for _ in pairs(state and state.friends or {}) do n += 1 end
	return n
end

local function sideQuestsOf(player)
	local data = ProfileAccess.Get(player)
	if not data then return {} end
	return VipGift.Quests(data, os.time(), Progression.GetLevel(player), friendCount(player), AURAS, hasPremium(player))
end

-- แถวทอง (บทที่เล่น หรือบทล็อก) + แถวฟ้า — ไคลเอนต์รวมกับงานบอร์ดเอง (QuestLogRules.Merge)
local function rowsOf(player, s)
	local rows = {}
	local ch, p, locked = current(s)
	if ch then
		local step = ch.steps[p.step]
		local got = p.got or 0
		if step.kind == "deliver" then got = Inventory.CountOf(player, step.item) end
		rows[#rows + 1] = QuestLogRules.MainRow(ch, step, got)
	elseif locked then
		rows[#rows + 1] = QuestLogRules.LockedRow(locked)
	end
	for _, q in ipairs(sideQuestsOf(player)) do
		rows[#rows + 1] = QuestLogRules.SideRow(q, StoryConfig.SideQuests[q.id])
	end
	return rows
end

-- เควสฟ้าโผล่ใหม่ = ข้อความ + เสียง ครั้งเดียวต่อเควส (แถวทองมีเสียงขึ้นขั้นของมันอยู่แล้ว)
local function announce(player, s, rows)
	if type(s.pop) ~= "table" then s.pop = {} end
	for _, row in ipairs(rows) do
		if row.color == "side" and row.state == "active" and not s.pop[row.key] then
			s.pop[row.key] = true
			Remotes.StoryPlay:FireClient(player, "newQuest", row.title)
		end
	end
end
```

แทนทั้ง `local function stateOf(player) ... end` ด้วย:

```lua
local function stateOf(player)
	local s = storyOf(player)
	if not s then return nil end
	local rows = rowsOf(player, s)
	local ch, p = current(s)
	if not ch then return { done = true, rows = rows } end
	local step = ch.steps[p.step]
	local got = p.got or 0
	if step.kind == "deliver" then got = Inventory.CountOf(player, step.item) end
	local npc = npcModel(ch.npc)
	return {
		chapter = ch.id, name = ch.name, step = p.step, steps = #ch.steps,
		kind = step.kind, goal = step.goal, need = step.need, got = got,
		npc = ch.npc, npcAt = npc and npc:GetPivot().Position or nil,
		target = step.kind == "reach" and markerOf(ch) or nil, radius = step.radius,
		-- ❗ เหนือหัว NPC: มีเรื่องให้คุยจริงตอนนี้
		ready = step.kind == "talk" or (step.kind == "deliver" and got >= (step.need or 0)),
		rows = rows,
	}
end
```

ในฟังก์ชัน `push` แทนสองบรรทัดแรกหลัง `if not state then return end`:

```lua
	local s = storyOf(player)
	if s then announce(player, s, state.rows or {}) end
	local key = (state.done and "done" or table.concat({ state.chapter, state.step, state.got or 0,
		tostring(state.ready), tostring(state.npcAt), tostring(state.target) }, "|"))
		.. "#" .. QuestLogRules.Signature(state.rows)
```

- [ ] **Step 5: บทพูดจบของไลราไม่หายเพราะบทล็อก** — ใน `talk()` แทนบล็อก

```lua
	if not ch then
		local last = StoryConfig.Chapters[#StoryConfig.Chapters]
		if last and last.npc == npcId then play(player, last.doneDialogue) end
		return
	end
```

ด้วย

```lua
	if not ch then
		-- บทล่าสุดที่เปิดแล้ว (ข้ามบทล็อกท้ายตาราง) เป็นคนพูดบทจบ
		for i = #StoryConfig.Chapters, 1, -1 do
			local last = StoryConfig.Chapters[i]
			if not last.locked then
				if last.npc == npcId then play(player, last.doneDialogue) end
				break
			end
		end
		return
	end
```

- [ ] **Step 6: ออฟาเรียน + รับพร + คัทซีนรถ + วาป** — ต่อจากฟังก์ชัน `startCutscene` (ก่อน `Remotes.RequestStory.OnServerEvent`) เพิ่ม:

```lua
--------------------------------------------------------------------------------
-- ออฟาเรียน เทพหุ่นฟาง (เควสสีฟ้า · 2026-09-29) — ปุ่มอยู่ VipGiftPrompt.server
--------------------------------------------------------------------------------

-- ให้ของของเควสหนึ่งอัน · คืนข้อความของที่ได้ หรือ nil (ไม่ผ่าน = ไม่เสียสิทธิ์ ตามกติกา VipGift)
local function giveSide(player, data, id)
	if id == "newcomer" then
		local ok = VipGift.ClaimPass(data, hasPremium(player), function()
			return PremiumAccess.GrantPremiumPass ~= nil and PremiumAccess.GrantPremiumPass(player) == true
		end)
		return ok and "🎫 แบทเทิลพาสพรีเมียมเดือนนี้ — เปิดที่เมนู ⋯ → 🎫 แบทเทิลพาส" or nil
	elseif id == "travel" then
		local ok = VipGift.ClaimGems(data, function(n)
			return PremiumAccess.AddGems ~= nil and PremiumAccess.AddGems(player, n) == true
		end)
		return ok and ("💎 %d เพชร"):format(VipGift.Gems) or nil
	elseif id == "friends" then
		local ok, auraId = VipGift.ClaimAura(data, friendCount(player), AURAS, rng, function(itemId)
			if not Inventory.HasRoomFor(player, itemId, 1) then return false end
			return Inventory.AddItem(player, itemId, 1) == true
		end)
		if ok then
			Inventory.Send(player)
			local item = ItemCatalog.Get(auraId)
			return ("✨ %s (ใส่ได้ที่กระเป๋า)"):format(item and item.name or auraId)
		end
		if auraId == "full" then
			Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม — เคลียร์ช่องแล้วกลับมาหาออฟาเรียน")
		end
	end
	return nil
end

StoryAccess.TalkOforian = function(player)
	if InCutscene[player] then return end
	local data = ProfileAccess.Get(player)
	if not data then
		return Remotes.SocialNotify:FireClient(player, "error", "ข้อมูลตัวละครยังโหลดไม่เสร็จ ลองใหม่อีกครั้ง")
	end
	local spoke = false
	for _, q in ipairs(sideQuestsOf(player)) do
		local def = StoryConfig.SideQuests[q.id]
		if q.state == "waiting" then
			if q.reason then Remotes.SocialNotify:FireClient(player, "warn", q.reason) end
		elseif q.id == "sky" then
			-- ท้ายสุดเสมอ (VipGift.Quests) · ให้ VIP ตอนกด "รับพร" ไม่ใช่ตอนคุย
			play(player, def.dialogue)
			SkyOffered[player] = true
			Remotes.StoryPlay:FireClient(player, "skyOffer")
			spoke = true
		else
			local got = giveSide(player, data, q.id)
			if got then
				play(player, def.dialogue)
				Remotes.StoryPlay:FireClient(player, "gift", { title = "🎁 " .. def.title, body = "ได้รับ " .. got })
				print(("[Oforian] %s (%d) ได้ %s"):format(player.Name, player.UserId, got))
				spoke = true
			end
		end
	end
	if not spoke then play(player, StoryConfig.OforianIdle) end
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	push(player, true)
end

local function skyFailed(player, text)
	Warping[player] = nil
	Remotes.StoryPlay:FireClient(player, "skyFailed", text or "วาปไม่สำเร็จ — เข้าเกาะได้จากล็อบบี้ แท็บฟาร์มมิ่ง")
end

-- ข้อยกเว้นเดียวของกฎ "เปลี่ยนโหมดผ่านล็อบบี้" (ผู้ใช้เลือก 2026-09-29): ครั้งเดียวตอนจบเควสเกาะลอยฟ้า
local function warpToIsland(player)
	if ServerConfig.FarmingPlaceId == 0 then return skyFailed(player) end
	local ok, code = pcall(FarmRegistry.GetOrCreate, player.UserId)
	if not ok or not code then
		warn("[Story] จองเกาะไม่สำเร็จ: " .. tostring(code))
		return skyFailed(player)
	end
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	Warping[player] = true
	local okTp, err = pcall(function()
		TeleportService:TeleportToPrivateServer(ServerConfig.FarmingPlaceId, code, { player })
	end)
	if not okTp then
		warn("[Story] วาปไม่สำเร็จ: " .. tostring(err))
		skyFailed(player)
	end
end

TeleportService.TeleportInitFailed:Connect(function(player)
	if Warping[player] then skyFailed(player) end
end)

local function startSkyCutscene(player)
	local token = os.clock()
	InCutscene[player] = token
	SkyPending[player] = token
	StatusEffects.SetRooted(player, true)
	Remotes.StoryPlay:FireClient(player, "skyCutscene", { at = QuestNav.Dummy() })
	task.delay(StoryConfig.CutsceneMaxSeconds, function()
		if SkyPending[player] == token then
			SkyPending[player] = nil
			endCutscene(player)
			warpToIsland(player)
		end
	end)
end
```

- [ ] **Step 7: actions ใหม่** — ใน `Remotes.RequestStory.OnServerEvent` เพิ่มก่อน `end)` ปิด:

```lua
	elseif action == "sky_accept" then
		if not SkyOffered[player] or InCutscene[player] then return end
		SkyOffered[player] = nil
		local data = ProfileAccess.Get(player)
		local s = storyOf(player)
		if not (data and s) or not VipGift.Claim(data, os.time(), Progression.GetLevel(player)) then
			return Remotes.SocialNotify:FireClient(player, "warn", "รับพรไม่ได้ตอนนี้ — ลองคุยกับออฟาเรียนอีกครั้ง")
		end
		Vip.Publish(player)
		s.skyWelcome = true
		if ProfileAccess.Flush then ProfileAccess.Flush(player) end
		print(("[Oforian] %s (%d) รับพรเกาะลอยฟ้า (VIP +%d วัน)"):format(player.Name, player.UserId, VipGift.Days))
		push(player, true)
		startSkyCutscene(player)
	elseif action == "sky_warp" then
		if not SkyPending[player] then return end
		SkyPending[player] = nil
		endCutscene(player)
		warpToIsland(player)
```

ใน `Players.PlayerRemoving` เพิ่ม `SkyOffered[player] = nil SkyPending[player] = nil Warping[player] = nil`

- [ ] **Step 8: นำทางของแถวทอง/ฟ้า** — ก่อนหัวข้อ `-- ปุ่มคุยบน NPC` เพิ่ม:

```lua
-- จิ้มแถวเควสทอง/ฟ้า = หาเป้าให้ (แถวบอร์ด "board:" เป็นของ Quests.server)
Remotes.RequestQuestNav.OnServerEvent:Connect(function(player, key)
	if type(key) ~= "string" then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local from = root.Position
	if key:sub(1, 5) == "side:" then
		return QuestNav.Send(player, QuestNav.Dummy(), StoryConfig.Npcs.Oforian.name)
	end
	if key:sub(1, 6) ~= "story:" then return end
	local s = storyOf(player)
	if not s then return end
	local ch, p = current(s)
	if not ch then return Remotes.SocialNotify:FireClient(player, "warn", "เควสนี้ยังไม่เปิด") end
	local step = ch.steps[p.step]
	local npc = npcModel(ch.npc)
	local npcAt = npc and npc:GetPivot().Position or nil
	local npcName = StoryConfig.Npcs[ch.npc] and StoryConfig.Npcs[ch.npc].name or ch.npc
	if step.kind == "talk" then
		QuestNav.Send(player, npcAt, npcName)
	elseif step.kind == "deliver" then
		if Inventory.CountOf(player, step.item) >= (step.need or 0) then
			QuestNav.Send(player, npcAt, npcName)
		else
			QuestNav.Send(player, QuestNav.ForItem(step.item, from), QuestNav.ItemName(step.item))
		end
	elseif step.kind == "hunt" then
		QuestNav.Send(player, QuestNav.Spawner(QuestNavRules.MobKindsNamed(step.mob), from), step.mob)
	elseif step.kind == "reach" then
		QuestNav.Send(player, markerOf(ch), step.goal)
	end
end)
```

- [ ] **Step 9: ลูป 0.5 วิส่งแถวใหม่แม้อยู่ขั้น reach** — ในลูปท้ายไฟล์ แทน `elseif s then\n\t\t\t\tpcall(push, player)\n\t\t\tend` ให้เป็นการเรียก `pcall(push, player)` ทุกคนที่มี `s` หลังเช็คขั้น reach:

```lua
			if step and step.kind == "reach" and not InCutscene[player] then
				... (ของเดิมทั้งก้อน ไม่แตะ)
			end
			if s then pcall(push, player) end
```

- [ ] **Step 10: คำสั่งเทส** — ใน `StoryAccess.Admin` เพิ่มก่อนบล็อก `if not ch then return "จบทุกบทแล้ว ...`:

```lua
	elseif sub == "gifts" then
		-- ทำให้บัญชีนี้เหมือนบัญชีใหม่ที่ยังไม่เคยรับของขวัญออฟาเรียน (ทดสอบเควสฟ้าทั้งสี่)
		local data = ProfileAccess.Get(player)
		data.NewbieGems = true
		data.NewbieGemsClaimed, data.NewbiePassClaimed, data.VipGiftClaimed, data.FriendAuraClaimed = nil, nil, nil, nil
		s.pop = nil
		push(player, true)
		return "ล้างธงของขวัญแล้ว — เควสฟ้าโผล่ตามเงื่อนไข (Lv.5 = เกาะลอยฟ้า · จบบทไลรา = การเดินทาง · เพื่อน 5 = มิตรภาพ)"
	elseif sub == "welcome" then
		s.skyWelcome = true
		return "ตั้งธงป้ายต้อนรับแล้ว — เข้าเกาะ (จากล็อบบี้) ครั้งถัดไปจะเห็น"
```

(ทั้งสองบรรทัดต้องอยู่ใน `if/elseif` เดียวกับ `cutscene`/`memory`/`reset` — ถ้าโครงเป็น `if ... end` แยกกัน ให้ต่อเป็น `elseif` ของสายนั้น)

- [ ] **Step 11: ข้อความจบบทชี้ไปหาออฟาเรียน** — ใน `complete()` ไม่ต้องแก้ตรรกะ (`gift` ยังคำนวณเหมือนเดิม) · ข้อความฝั่งไคลเอนต์แก้ใน Task 8

- [ ] **Step 12: ตรวจ + ดัน** — `bash tools/offline-check.sh src/ServerScriptService/Story.server.lua src/ServerScriptService/StoryAccess.lua` · Expected `OK` (ไม่มีตัวแปรใช้ก่อนประกาศ — `hasPremium/friendCount/sideQuestsOf/rowsOf/announce` ต้องอยู่เหนือ `stateOf`/`push`; `giveSide/skyFailed/warpToIsland/startSkyCutscene` อยู่เหนือ RequestStory handler) → ดันสามเพลส (Story.server self-gate เกาะ/สนาม)
- [ ] **Step 13: เทสข้อมูลที่แตะ** — `node tools/offline-test.js tests/story_config_test.lua` + `node tools/lua.js tests/vip_gift_test.lua Edit` · Expected: PASS ทั้งคู่
- [ ] **Step 14: commit** — `git add src/ServerScriptService/Story.server.lua src/ServerScriptService/StoryAccess.lua` · `git commit -m "Story server: gold/blue quest rows, Oforian talks, sky blessing cutscene and one-time warp, quest navigation"`

---

### Task 6: ปุ่มหุ่นฟาง = "คุยกับออฟาเรียน"

**Files:**
- Modify (เขียนใหม่ทั้งไฟล์): `src/ServerScriptService/VipGiftPrompt.server.lua`
- Delete: `src/StarterPlayerScripts/VipGiftController.client.lua` (+ ลบ instance ในสามเพลส)

**Interfaces:**
- Consumes: `StoryAccess.TalkOforian` (T5) · `StoryConfig.Npcs.Oforian` (T4)

- [ ] **Step 1: เขียน `VipGiftPrompt.server.lua` ใหม่**

```lua
-- VipGiftPrompt: ปุ่ม E "คุยกับออฟาเรียน" บนหุ่นฟางข้างจุดเกิดแรก (`Dummy_Spawn`) + ป้ายชื่อเหนือหัว (2026-09-29)
-- ของขวัญทั้งหมดมาเป็นเควสสีฟ้าของ "ออฟาเรียน เทพหุ่นฟาง" — กติกา `VipGift` · บทพูด/ให้ของ `Story.server` (TalkOforian)
-- ชื่อไฟล์เดิมคงไว้ (อยู่ใน denylist ของ farming/arena อยู่แล้ว) · เกมหลักเท่านั้น · ปุ่มโชว์ตลอด (ไม่มีเควส = บทพูดทักทาย)
local CollectionService = game:GetService("CollectionService")

local ServerConfig = require(script.Parent.ServerConfig)
if ServerConfig.IsLobby then return end

local StoryAccess = require(script.Parent.StoryAccess)
local StoryConfig = require(game.ReplicatedStorage.StoryConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local NAME = StoryConfig.Npcs.Oforian.name
local COLOR = StoryConfig.Npcs.Oforian.color

local function wire(dummy)
	if dummy.Name ~= "Dummy_Spawn" then return end
	local anchor = dummy.PrimaryPart or dummy:FindFirstChildWhichIsA("BasePart")
	if not anchor or anchor:FindFirstChild("VipGiftPrompt") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VipGiftPrompt"
	prompt.ActionText = "คุยกับออฟาเรียน"
	prompt.ObjectText = NAME
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		if StoryAccess.TalkOforian then
			StoryAccess.TalkOforian(player)
		else
			Remotes.SocialNotify:FireClient(player, "warn", "ออฟาเรียนยังไม่ตื่น ลองใหม่อีกครั้ง")
		end
	end)
	-- ป้ายชื่อเหนือหัว (สตัด: เล็กลงตามระยะ) · ❗ ของเควสฟ้าวาดฝั่งไคลเอนต์ (StoryController)
	local cf, size = dummy:GetBoundingBox()
	local tag = Instance.new("BillboardGui")
	tag.Name = "OforianTag"
	tag.Size = UDim2.fromScale(7, 1.1)
	tag.StudsOffsetWorldSpace = Vector3.new(0, (cf.Position.Y + size.Y / 2) - anchor.Position.Y + 0.9, 0)
	tag.MaxDistance = 90
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = COLOR
	label.TextStrokeTransparency = 0.4
	label.Text = NAME
	label.Parent = tag
	tag.Parent = anchor
end

-- ถามใหม่เรื่อยๆ (หุ่นถูกสร้างใหม่ได้ถ้ารันเฟส training_dummies ซ้ำ)
task.spawn(function()
	while true do
		for _, dummy in ipairs(CollectionService:GetTagged("WOLD_Dummy")) do
			wire(dummy)
		end
		task.wait(3)
	end
end)
```

- [ ] **Step 2: ลบตัวควบคุมป้ายเดิม** — `git rm src/StarterPlayerScripts/VipGiftController.client.lua` แล้วลบ instance ในสามเพลส (verify.js ไม่ลบให้) ด้วยไฟล์ชั่วคราว `tests/_rm_vipgift.lua`:

```lua
local s = game.StarterPlayer.StarterPlayerScripts:FindFirstChild("VipGiftController")
if s then s:Destroy() end
return "removed=" .. tostring(s ~= nil)
```

รัน `node tools/lua.js tests/_rm_vipgift.lua Edit` · `WOLD_PLACE=136992335889132 node tools/lua.js tests/_rm_vipgift.lua Edit` · `WOLD_PLACE=134798670267276 node tools/lua.js tests/_rm_vipgift.lua Edit` แล้วลบไฟล์ชั่วคราว

- [ ] **Step 3: ตรวจ + ดัน** — `bash tools/offline-check.sh src/ServerScriptService/VipGiftPrompt.server.lua` → ดันสามเพลส · Expected `mismatches 0`
- [ ] **Step 4: commit** — `git add src/ServerScriptService/VipGiftPrompt.server.lua src/StarterPlayerScripts/VipGiftController.client.lua` · `git commit -m "Scarecrow prompt becomes 'talk to Oforian' with a name tag; per-player gift label controller removed"`

---

### Task 7: งานบอร์ดเข้าแถบ + นำทาง (`Quests.server`)

**Files:**
- Modify: `src/ServerScriptService/Quests.server.lua`

**Interfaces:**
- Consumes: `QuestLogRules.BoardRow/Signature` (T1) · `QuestNav.*` `QuestNavRules.MobKindsNamed` (T2)
- Produces: `Remotes.QuestLogBoard:FireClient(player, rows)` (ส่งเมื่อเปลี่ยน) · `RequestQuestAction("log")` = ขอแถวใหม่ทั้งชุด · นำทางแถว `board:<questKey>`

- [ ] **Step 1: requires** — ต่อจาก `local Vip = require(game.ServerScriptService.Vip)`:

```lua
local QuestLogRules = require(game.ReplicatedStorage.QuestLogRules)
local QuestNavRules = require(game.ReplicatedStorage.QuestNavRules)
local QuestNav = require(game.ServerScriptService.QuestNav)
```

- [ ] **Step 2: แถว + ส่งเมื่อเปลี่ยน** — ต่อจากฟังก์ชัน `snapshot` (ก่อน `local function accept`):

```lua
-- แถบเควสรวม (2026-09-29): งานที่ถืออยู่เป็นแถวสีขาว · ส่งใหม่เฉพาะตอนลายเซ็นเปลี่ยน
local LastBoardRows = {}

local function boardRowsOf(player)
	local rows = {}
	for _, q in ipairs(activeOf(player) or {}) do
		local item = q.item and ItemCatalog.Get(q.item)
		local title = (q.kind == "hunt") and q.mob or (item and item.name or q.item)
		rows[#rows + 1] = QuestLogRules.BoardRow(questKey(q), title, QuestConfig.Describe(q, item and item.name),
			progressOf(player, q), q.need)
	end
	return rows
end

local function pushBoardRows(player)
	local rows = boardRowsOf(player)
	local sig = QuestLogRules.Signature(rows)
	if LastBoardRows[player] == sig then return end
	LastBoardRows[player] = sig
	Remotes.QuestLogBoard:FireClient(player, rows)
end
```

- [ ] **Step 3: เรียกตอนงานเปลี่ยน** — เพิ่ม `pushBoardRows(player)` เป็นบรรทัดสุดท้ายของ `accept`, `abandon`, `turnIn` (ต่อจาก `Remotes.QuestUpdate:FireClient(...)`) และใน `bump` ต่อจากบรรทัดที่เพิ่ม `got` · ในลูป 3 วิ (`publishTurnIn`) เพิ่ม `pcall(pushBoardRows, player)` ต่อจาก `pcall(publishTurnIn, player)`

- [ ] **Step 4: action "log"** — ในตัวรับ `Remotes.RequestQuestAction.OnServerEvent:Connect(function(player, action, index)` บรรทัดแรกของฟังก์ชัน:

```lua
	if action == "log" then
		LastBoardRows[player] = nil
		return pushBoardRows(player)
	end
```

- [ ] **Step 5: นำทางแถวบอร์ด** — ก่อนหัวข้อ `-- ปุ่มที่บอร์ด`:

```lua
-- จิ้มแถวงานบอร์ด = หาเป้าให้ (แถว "story:"/"side:" เป็นของ Story.server)
Remotes.RequestQuestNav.OnServerEvent:Connect(function(player, key)
	if type(key) ~= "string" or key:sub(1, 6) ~= "board:" then return end
	local wanted = key:sub(7)
	local quest
	for _, q in ipairs(activeOf(player) or {}) do
		if questKey(q) == wanted then quest = q break end
	end
	if not quest then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local from = root.Position
	if progressOf(player, quest) >= quest.need then
		return QuestNav.Send(player, QuestNav.Board(quest.board, from), "บอร์ดเควส")
	end
	if quest.kind == "hunt" then
		QuestNav.Send(player, QuestNav.Spawner(QuestNavRules.MobKindsNamed(quest.mob), from), quest.mob)
	elseif quest.kind == "fish" then
		QuestNav.Send(player, QuestNav.FishZone(quest.item, from), QuestNav.ItemName(quest.item))
	else
		QuestNav.Send(player, QuestNav.ForItem(quest.item, from), QuestNav.ItemName(quest.item))
	end
end)
```

- [ ] **Step 6: ล้างตอนออก** — หา `Players.PlayerRemoving` ในไฟล์ (ถ้ามี) เพิ่ม `LastBoardRows[player] = nil` · ถ้าไม่มี เพิ่มท้ายไฟล์ก่อนช่องเทส: `Players.PlayerRemoving:Connect(function(player) LastBoardRows[player] = nil end)`
- [ ] **Step 7: ตรวจ + ดัน + เทสบอร์ดเดิม** — `bash tools/offline-check.sh src/ServerScriptService/Quests.server.lua` (ระวังใช้ก่อนประกาศ: `pushBoardRows` ต้องอยู่เหนือ `accept`) → ดันสามเพลส → `WOLD_PLACE=136992335889132 node tools/lua.js tests/island_quest_test.lua Edit` · Expected PASS เหมือนเดิม (ถ้าเทสนั้นต้อง Play ให้ข้ามและจดลงบันทึก)
- [ ] **Step 8: commit** — `git add src/ServerScriptService/Quests.server.lua` · `git commit -m "Board quests feed the quest log and navigate to spawners, nodes, fishing shores and boards"`

---

### Task 8: แถบเควส (UI + ตัวควบคุม) + ป้าย/กล่องเลือกในเรื่อง

**Files:**
- Create: `src/ReplicatedStorage/UI/QuestTrackerGui.lua` · `src/StarterPlayerScripts/QuestTrackerController.client.lua`
- Modify: `src/ReplicatedStorage/UI/StoryGui.lua` (ถอด tracker · เพิ่ม `Choice` `White`) · `src/StarterPlayerScripts/StoryController.client.lua` (ถอด SetTracker · kinds ใหม่ · ❗ บนหุ่นฟาง) · `src/StarterPlayerScripts/SocialController.client.lua` (หมุดบนแผนที่ตามการนำทาง)
- Test: `tests/quest_tracker_gui_test.lua`

**Interfaces:**
- Consumes: `QuestLogRules` (T1) · `Remotes.QuestLogBoard/RequestQuestNav/QuestNav` (T2) · `StoryState.rows` + StoryPlay kinds (T5) · `Navigation.Active` (มีแล้ว)
- Produces: `QuestTrackerGui.new(parent)` · `:SetRows(rows, navKey)` · `:SetCollapsed(on)` · `.onTap(row)` · ฟิลด์เทส `.holder .list .buttons` · `StoryGui:Choice(question, yesText, noText, onPick)` · `StoryGui:White(on)`

- [ ] **Step 1: เขียนเทส GUI**

```lua
-- node tools/lua.js tests/quest_tracker_gui_test.lua Edit
-- แถบเควสรวม (2026-09-29): แถวตามลำดับ · สีตามชนิด · ล็อก = 🔒 · ย่อ/ขยาย · ไม่มีเควส = ซ่อน · อยู่ใต้หน้าต่าง
local RS = game.ReplicatedStorage
local temp = Instance.new("Folder")
temp.Name = "QuestTrackerTest_" .. math.random(1, 1e9)
temp.Parent = RS
RS.QuestLogRules:Clone().Parent = temp
local ui = Instance.new("Folder")
ui.Name = "UI"
ui.Parent = temp
for _, name in ipairs({ "QuestTrackerGui", "Responsive" }) do RS.UI[name]:Clone().Parent = ui end

local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local ok, err = pcall(function()
	local Rules = require(temp.QuestLogRules)
	local Gui = require(ui.QuestTrackerGui)
	local g = Gui.new(temp)
	check(g.gui.DisplayOrder == 4, "อยู่ใต้หน้าต่างทุกบาน (DisplayOrder 4)")
	g:SetCollapsed(false)
	local rows = Rules.Merge({
		Rules.LockedRow({ id = "saltmere", name = "เส้นทางสู่ซอลต์เมียร์", goal = "หาคำแนะนำ" }),
		Rules.SideRow({ id = "sky", state = "active" }, { title = "เกาะลอยฟ้าแห่งความฝัน", goal = "ไปพบออฟาเรียน" }),
	}, { Rules.BoardRow("B|hunt|x", "สไลม์เขียว", "ล่า 5", 2, 5) })
	g:SetRows(rows, "side:sky")
	check(#g.buttons == 3, "สามแถว")
	check(g.buttons[1].Title.Text:find("🔒", 1, true) == 1 and g.buttons[1].Title.TextColor3 == Rules.Colors.main, "แถวล็อกทอง + 🔒")
	check(g.buttons[2].Title.Text:find("🧭", 1, true) == 1 and g.buttons[2].Title.TextColor3 == Rules.Colors.side, "แถวที่นำทางอยู่มี 🧭 · สีฟ้า")
	check(g.buttons[3].Progress and g.buttons[3].Progress.Text == "2/5", "งานบอร์ดมีตัวนับ")
	check(g.holder.Visible and g.list.Visible, "ขยายอยู่ = เห็นรายการ")
	g:SetCollapsed(true)
	check(not g.list.Visible and g.header.Text:find("(3)", 1, true) ~= nil, "ย่อ = เหลือหัว (บอกจำนวน)")
	g:SetRows({}, nil)
	check(not g.holder.Visible, "ไม่มีเควส = ซ่อนทั้งแถบ")
	g.gui:Destroy()
end)
check(ok, "รันจบ " .. tostring(err or ""))
temp:Destroy()
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
```

- [ ] **Step 2: รันให้เห็นว่าตก** — (ดันเทสไม่ได้เพราะโมดูลยังไม่มี) `node tools/lua.js tests/quest_tracker_gui_test.lua Edit` · Expected: error หา `QuestTrackerGui` ไม่เจอ

- [ ] **Step 3: เขียน `QuestTrackerGui.lua`**

```lua
-- QuestTrackerGui: แถบเควสรวมมุมขวาบน (วาดอย่างเดียว · QuestTrackerController ต่อสาย · สเปก 2026-09-29-quest-log-oforian)
-- ทอง = เควสหลัก · ฟ้า = เควสรองของออฟาเรียน · ขาว = งานบอร์ด · 🔒 = ล็อก/รอ · 🧭 = กำลังนำทาง
-- DisplayOrder 4 = ใต้ปุ่มมือถือ (5) และทุกหน้าต่าง (12+) — ของเดิมอยู่ 900 ทับปุ่ม Q กับหน้าต่างฝั่งขวา (QA U1)
local Responsive = require(script.Parent.Responsive)
local QuestLogRules = require(script.Parent.Parent.QuestLogRules)

local QuestTrackerGui = {}
QuestTrackerGui.__index = QuestTrackerGui

local rgb = Color3.fromRGB
local PANEL = rgb(20, 22, 30)
local TEXT = rgb(240, 236, 226)
local MUTED = rgb(160, 162, 176)
local DONE = rgb(120, 220, 120)
local WIDTH, HEADER_H, ROW_H, GAP, MAX_LIST = 270, 28, 48, 4, 300

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

local function label(parent, name, text, size, color, align)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = text
	l.Parent = parent
	return l
end

function QuestTrackerGui.new(parent)
	local self = setmetatable({ rows = {}, buttons = {}, collapsed = Responsive.IsTouchOnly(), onTap = nil }, QuestTrackerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "WOLD_QuestLog"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4
	gui.Parent = parent
	self.gui = gui

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -12, 0, 150)
	holder.Size = UDim2.fromOffset(WIDTH, HEADER_H)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	Responsive.Scale(holder, 0.7)
	self.holder = holder

	local header = Instance.new("TextButton")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, HEADER_H)
	header.BackgroundColor3 = PANEL
	header.BackgroundTransparency = 0.2
	header.AutoButtonColor = true
	header.Font = Enum.Font.GothamBold
	header.TextSize = 14
	header.TextColor3 = QuestLogRules.Colors.main
	header.Text = ""
	header.Parent = holder
	corner(header, 8)
	header.Activated:Connect(function() self:SetCollapsed(not self.collapsed) end)
	self.header = header

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, HEADER_H + 4)
	list.Size = UDim2.new(1, 0, 0, 0)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = holder
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	self.list = list
	return self
end

function QuestTrackerGui:_layout()
	local n = #self.rows
	self.holder.Visible = n > 0
	self.header.Text = ("📜 เควส (%d)%s"):format(n, self.collapsed and "  · แตะเพื่อดู" or "")
	local listH = self.collapsed and 0 or math.min(n * (ROW_H + GAP), MAX_LIST)
	self.list.Visible = not self.collapsed
	self.list.Size = UDim2.new(1, 0, 0, listH)
	self.holder.Size = UDim2.fromOffset(WIDTH, HEADER_H + (self.collapsed and 0 or listH + 4))
end

function QuestTrackerGui:SetCollapsed(on)
	self.collapsed = on
	self:_layout()
end

function QuestTrackerGui:_row(row, order, navigating)
	local dim = QuestLogRules.Dim(row)
	local color = QuestLogRules.Colors[row.color] or TEXT
	local b = Instance.new("TextButton")
	b.Name = "Row_" .. order
	b.LayoutOrder = order
	b.AutoButtonColor = true
	b.Text = ""
	b.Size = UDim2.new(1, -6, 0, ROW_H)
	b.BackgroundColor3 = PANEL
	b.BackgroundTransparency = dim and 0.55 or 0.2
	b.Parent = self.list
	corner(b, 8)
	local stripe = Instance.new("Frame")
	stripe.Name = "Stripe"
	stripe.Position = UDim2.fromOffset(4, 5)
	stripe.Size = UDim2.new(0, 4, 1, -10)
	stripe.BackgroundColor3 = color
	stripe.BackgroundTransparency = dim and 0.6 or 0
	stripe.BorderSizePixel = 0
	stripe.Parent = b
	if navigating then
		local s = Instance.new("UIStroke")
		s.Color, s.Thickness = color, 1.5
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = b
	end
	local prefix = dim and "🔒 " or (navigating and "🧭 " or "")
	local title = label(b, "Title", prefix .. (row.title or ""), 14, color)
	title.Font = Enum.Font.GothamBold
	title.Position = UDim2.fromOffset(14, 4)
	title.Size = UDim2.new(1, -72, 0, 18)
	title.TextTransparency = dim and 0.35 or 0
	local goal = label(b, "Goal", row.goal or "", 12, dim and MUTED or TEXT)
	goal.Position = UDim2.fromOffset(14, 24)
	goal.Size = UDim2.new(1, -20, 0, 20)
	local progress = QuestLogRules.Progress(row)
	if progress then
		local p = label(b, "Progress", progress, 13, row.state == "done" and DONE or color, Enum.TextXAlignment.Right)
		p.Font = Enum.Font.GothamBold
		p.Position = UDim2.new(1, -60, 0, 4)
		p.Size = UDim2.fromOffset(52, 18)
	end
	b.Activated:Connect(function()
		if self.onTap then self.onTap(row) end
	end)
	return b
end

function QuestTrackerGui:SetRows(rows, navKey)
	self.rows = rows or {}
	for _, b in ipairs(self.buttons) do b:Destroy() end
	self.buttons = {}
	for i, row in ipairs(self.rows) do
		self.buttons[i] = self:_row(row, i, row.key == navKey)
	end
	self:_layout()
end

return QuestTrackerGui
```

- [ ] **Step 4: ดันโมดูล + รันเทส GUI** — ดันสามเพลส → `node tools/lua.js tests/quest_tracker_gui_test.lua Edit` · Expected: `PASS` (ถ้า `Responsive` require โมดูลอื่นแล้วโคลนไม่ครบ ให้เติมชื่อในลูปโคลนของเทส — Ruling ลงบันทึก)

- [ ] **Step 5: ตัวควบคุม `QuestTrackerController.client.lua`**

```lua
-- QuestTrackerController: แถบเควสรวม (2026-09-29) — รวมแถวทอง/ฟ้า (StoryState.rows จาก Story.server · เกมหลัก)
-- กับแถวขาว (QuestLogBoard จาก Quests.server · เกมหลัก + เกาะ) แล้ววาด · จิ้ม = ขอเป้าจากเซิร์ฟ (StreamingEnabled)
-- แล้วปักหมุดผ่าน Navigation.Active (คอมกด T เดินตามได้) · จิ้มแถวที่นำทางอยู่ซ้ำ = เลิก · ล็อก/รอ = บอกเหตุผล
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

while workspace:GetAttribute("IsLobby") == nil do task.wait(0.2) end
if workspace:GetAttribute("IsLobby") == true then return end
if workspace:GetAttribute("ArenaMode") == true then return end

local Remotes = require(ReplicatedStorage.Remotes)
local Navigation = require(ReplicatedStorage.Navigation)
local QuestLogRules = require(ReplicatedStorage.QuestLogRules)
local QuestTrackerGui = require(ReplicatedStorage.UI.QuestTrackerGui)
local UiSound = require(ReplicatedStorage.UI.UiSound)

local player = Players.LocalPlayer
local gui = QuestTrackerGui.new(player:WaitForChild("PlayerGui"))
local storyRows, boardRows = {}, {}
local navKey, pendingKey = nil, nil

local function toast(text)
	local channel = ReplicatedStorage:FindFirstChild("WOLD_Toast")
	if channel then channel:Fire(text) end
end

local function redraw()
	gui:SetRows(QuestLogRules.Merge(storyRows, boardRows), navKey)
end

Remotes.StoryState.OnClientEvent:Connect(function(state)
	storyRows = (type(state) == "table" and state.rows) or {}
	redraw()
end)

Remotes.QuestLogBoard.OnClientEvent:Connect(function(rows)
	boardRows = rows or {}
	redraw()
end)

gui.onTap = function(row)
	UiSound.Play("Click")
	if QuestLogRules.Dim(row) then return toast(QuestLogRules.DenyText(row)) end
	local nav = Navigation.Active
	if navKey == row.key and nav and nav:HasDestination() then
		nav:Clear()
		navKey = nil
		toast("เลิกนำทางแล้ว")
		return redraw()
	end
	pendingKey = row.key
	Remotes.RequestQuestNav:FireServer(row.key)
end

Remotes.QuestNav.OnClientEvent:Connect(function(position, label)
	local nav = Navigation.Active
	if not nav then return toast("แผนที่ยังไม่พร้อม ลองใหม่อีกครั้ง") end
	local ok, message = nav:SetDestination(position, label)
	if ok then
		navKey = pendingKey
		local hint = UserInputService.KeyboardEnabled and " — กด T เพื่อเดินอัตโนมัติ" or ""
		toast(("🧭 นำทางไป %s%s"):format(label ~= "" and label or "จุดหมาย", hint))
	else
		toast(message or "นำทางไปจุดนั้นไม่ได้")
	end
	redraw()
end)

-- หมุดหาย (ถึงแล้ว/ลบเอง) = แถวเลิกขึ้น 🧭
task.spawn(function()
	while true do
		task.wait(1)
		local nav = Navigation.Active
		if navKey and not (nav and nav:HasDestination()) then
			navKey = nil
			redraw()
		end
	end
end)

-- ขอแถวงานบอร์ดหลังจอโหลดจบ (สองครั้ง: เผื่อโปรไฟล์ยังโหลดไม่เสร็จรอบแรก)
task.spawn(function()
	while player:GetAttribute("WOLD_Loaded") ~= true do task.wait(0.25) end
	Remotes.RequestQuestAction:FireServer("log")
	task.wait(5)
	Remotes.RequestQuestAction:FireServer("log")
end)
```

- [ ] **Step 6: `StoryGui` ถอด tracker + เพิ่ม `Choice` / `White`**
  - ลบบรรทัดหัวไฟล์ `--   tracker   ป้ายเควสมุมขวา ...`
  - ลบทั้งบล็อก `----------------------------------------------------------------- tracker` (ตั้งแต่ `local trackerHolder` ถึง `self.tracker = trackerHolder`) และลบฟังก์ชัน `StoryGui:SetTracker` พร้อมหัวข้อ `-- tracker`
  - ต่อท้ายไฟล์ก่อน `return StoryGui`:

```lua
--------------------------------------------------------------------------------
-- กล่องเลือก (รับพรของออฟาเรียน) · จอขาวค้าง (ก่อนวาป)
--------------------------------------------------------------------------------
function StoryGui:Choice(question, yesText, noText, onPick)
	local panel = Instance.new("Frame")
	panel.Name = "Choice"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 150)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.05
	panel.ZIndex = 70
	panel.Parent = self.gui
	corner(panel, 14)
	stroke(panel, GOLD, 0.1, 2)
	Responsive.Scale(panel, 0.6)
	local q = label(panel, question, 18, GOLD, Enum.TextXAlignment.Center)
	q.Font = Enum.Font.GothamBold
	q.Position = UDim2.fromOffset(16, 16)
	q.Size = UDim2.new(1, -32, 0, 56)
	q.ZIndex = 71
	local done = false
	local function button(text, x, color, value)
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(x, 0, 1, -16)
		b.Size = UDim2.fromOffset(160, 44)
		b.BackgroundColor3 = color
		b.Font = Enum.Font.GothamBold
		b.TextSize = 18
		b.TextColor3 = rgb(24, 20, 12)
		b.Text = text
		b.ZIndex = 72
		b.Parent = panel
		corner(b, 10)
		b.Activated:Connect(function()
			if done then return end
			done = true
			UiSound.Play("Click")
			panel:Destroy()
			if onPick then onPick(value) end
		end)
	end
	button(yesText, 0.28, GOLD, true)
	button(noText, 0.72, rgb(150, 152, 164), false)
end

function StoryGui:White(on)
	self.cinema.Visible = on or self.cinema.Visible
	self.flash.Visible = on
	self.flash.BackgroundTransparency = 0
end
```

- [ ] **Step 7: `StoryController`**
  - ใน `Remotes.StoryState.OnClientEvent` ลบบรรทัด `gui:SetTracker(s)`
  - เพิ่ม require ต่อจาก `local UiSound = ...`: `local TeleportService = game:GetService("TeleportService")`
  - ใน `refreshMarks()` ต่อท้ายฟังก์ชัน (ก่อน `end` ปิด):

```lua
	-- ❗ เหนือออฟาเรียน (หุ่นฟางข้างจุดเกิด) ตอนมีเควสฟ้าพร้อมรับ
	local sideReady = false
	for _, row in ipairs(state and state.rows or {}) do
		if row.color == "side" and row.state == "active" then sideReady = true break end
	end
	for _, d in ipairs(CollectionService:GetTagged("WOLD_Dummy")) do
		if d.Name == "Dummy_Spawn" then
			local anchor = d:FindFirstChild("Head") or d.PrimaryPart
			if anchor then
				local cf, size = d:GetBoundingBox()
				local b = billboard(anchor, "OforianMark", "❗", (cf.Position.Y + size.Y / 2) - anchor.Position.Y + 2.4)
				b.Enabled = sideReady and not inCutscene
			end
		end
	end
```

  - ก่อนหัวข้อ `-- คำสั่งจากเซิร์ฟ` เพิ่มคัทซีนรถ (**Task 9 เติมเนื้อ `runSkyCutscene`** — ตอนนี้ใส่ตัวว่างที่ส่ง sky_warp ทันที ให้ระบบต่อกันครบก่อน):

```lua
local skyRestore = nil -- คืนหน้าจอตอนวาปไม่สำเร็จ
local function runSkyCutscene(info)
	Remotes.RequestStory:FireServer("sky_warp")
end
```

  - ใน `Remotes.StoryPlay.OnClientEvent` เพิ่มสาขาก่อน `end)`:

```lua
	elseif kind == "newQuest" then
		UiSound.Play("StoryStep")
		localToast(("📜 เควสใหม่: %s — แตะที่แถบเควสเพื่อนำทาง"):format(tostring(arg)), true)
	elseif kind == "gift" and type(arg) == "table" then
		afterTalking(function()
			UiSound.Play("ToastReward")
			gui:Banner(arg.title or "🎁", arg.body or "", 7)
		end)
	elseif kind == "skyOffer" then
		afterTalking(function()
			gui:Choice("รับพรจากออฟาเรียน แล้วเดินทางไปเกาะลอยฟ้าแห่งความฝัน?", "รับพร", "ไว้ก่อน", function(yes)
				if yes then Remotes.RequestStory:FireServer("sky_accept") end
			end)
		end)
	elseif kind == "skyCutscene" then
		task.spawn(runSkyCutscene, arg)
	elseif kind == "skyFailed" then
		if skyRestore then
			skyRestore()
			skyRestore = nil
		end
		localToast(tostring(arg))
```

  - ในสาขา `complete` แทน `if arg.gift then body ..= "\n🎁 ไปรับ 150 เพชรที่หุ่นฟางข้างจุดเกิดได้แล้ว" end` ด้วย `if arg.gift then body ..= "\n🎁 ออฟาเรียน เทพหุ่นฟางมีของขวัญการเดินทางให้ — ไปพบที่ข้างจุดเกิด" end`

- [ ] **Step 8: หมุดบนแผนที่ตามการนำทาง** — `SocialController.client.lua` ต่อจาก `Navigation.Active = nav ...`:

```lua
-- ทุกทางที่ปักหมุด (แผนที่ · แถบเควส · ปุ่มหาหม้อแปลง) = หมุดบนแผนที่ตรงกันเสมอ
nav.onChanged = function()
	map:SetWaypoint(nav.destination)
end
```

(ถ้า `map` ประกาศหลังบรรทัดนี้ ให้ย้ายสามบรรทัดนี้ไปหลังจุดที่ `map` ถูกสร้าง — ตรวจด้วย offline-check)

- [ ] **Step 9: ตรวจ + ดัน + เทส** — `bash tools/offline-check.sh src/ReplicatedStorage/UI/QuestTrackerGui.lua src/StarterPlayerScripts/QuestTrackerController.client.lua src/ReplicatedStorage/UI/StoryGui.lua src/StarterPlayerScripts/StoryController.client.lua src/StarterPlayerScripts/SocialController.client.lua` → ดันสามเพลส → `node tools/lua.js tests/quest_tracker_gui_test.lua Edit` · Expected: `PASS` · แล้วรัน `load_all_modules` ของสแครชแพด (ถ้ายังมี) หรือโคลน+require `StoryGui` กับ `QuestTrackerGui` ใน Edit ให้แน่ใจว่าโหลดขึ้น
- [ ] **Step 10: commit** — `git add src/ReplicatedStorage/UI/QuestTrackerGui.lua src/StarterPlayerScripts/QuestTrackerController.client.lua src/ReplicatedStorage/UI/StoryGui.lua src/StarterPlayerScripts/StoryController.client.lua src/StarterPlayerScripts/SocialController.client.lua tests/quest_tracker_gui_test.lua` · `git commit -m "Combined quest tracker (gold/blue/white, tap to navigate, under windows); Oforian mark, gift banner and blessing choice"`

---

### Task 9: รถคาร์โก้ในเพลสหลัก + คัทซีน

**Files:**
- Create: `tools/dump-model.js` · `assets/models-from-main/cargo_truck.lua` (สร้างโดยเครื่องมือ) · `mapgen/111_story_cargo_truck.lua`
- Modify: `src/StarterPlayerScripts/StoryController.client.lua` (เนื้อ `runSkyCutscene`)

**Interfaces:**
- Consumes: `StoryConfig.SkyCutscene/SkyTitle` (T4) · `StoryGui:White/Flash/TitleCard/Black/Caption/SetCinema` · RequestStory `"sky_warp"` (T5)
- Produces: `ReplicatedStorage.WOLD_Cutscene.CargoTruck` ในเพลสหลัก (WorldPivot = ก้นกลาง · ชนไม่ได้ · anchored)

- [ ] **Step 1: เครื่องมือดัมพ์** — `tools/dump-model.js`:

```js
// node tools/dump-model.js <placeId> "<Lua expression ของโมเดล>" <ชื่อไฟล์ใน assets/models-from-main> "<คำอธิบาย>"
// ดัมพ์ BasePart ทุกชิ้นเป็นแถวตัวเลขเทียบ "ก้นกลางกล่องครอบ" ของโมเดล (ทรงแถวเดียวกับ chests.lua)
// ทีละ 60 แถว เพราะ execute_luau ตัดผลลัพธ์ยาวทิ้งเงียบๆ
const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const [placeId, expr, outName, note] = process.argv.slice(2);
if (!placeId || !expr || !outName) {
  console.error('usage: node tools/dump-model.js <placeId> "<expr>" <outName> "<note>"');
  process.exit(1);
}
const root = path.join(__dirname, "..");
const tmp = path.join(root, "tests", "_dump_model_tmp.lua");
const CHUNK = 60;
function run(lua) {
  fs.writeFileSync(tmp, lua);
  const r = spawnSync(process.execPath, [path.join(root, "tools", "lua.js"), tmp, "Edit"],
    { env: { ...process.env, WOLD_PLACE: placeId }, encoding: "utf8", cwd: root });
  fs.unlinkSync(tmp);
  if (r.status !== 0) throw new Error(r.stderr || r.stdout);
  return r.stdout.trim();
}
const head = `local m = ${expr}
local cf, size = m:GetBoundingBox()
local base = CFrame.new(cf.Position - cf.UpVector * size.Y / 2) * cf.Rotation
local parts = {}
for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then parts[#parts + 1] = d end end
`;
const total = Number(run(head + "return tostring(#parts)").split("\n").pop());
if (!total) throw new Error("ไม่พบชิ้นส่วน");
const rows = [];
for (let offset = 0; offset < total; offset += CHUNK) {
  const out = run(head + `
local SHAPES = { [Enum.PartType.Ball] = 0, [Enum.PartType.Block] = 1, [Enum.PartType.Cylinder] = 2 }
local function r(v) return math.floor(v * 1000 + 0.5) / 1000 end
local out = {}
for i = ${offset} + 1, math.min(#parts, ${offset + CHUNK}) do
	local p = parts[i]
	local shape = p:IsA("WedgePart") and 9 or p:IsA("CornerWedgePart") and 10 or (p:IsA("Part") and SHAPES[p.Shape]) or 1
	local c = { base:ToObjectSpace(p.CFrame):GetComponents() }
	for k = 1, 12 do c[k] = r(c[k]) end
	local col = math.floor(p.Color.R * 255 + 0.5) * 65536 + math.floor(p.Color.G * 255 + 0.5) * 256 + math.floor(p.Color.B * 255 + 0.5)
	out[#out + 1] = ("{%q,%d,%s,%s,%s,%s,%d,%q,%s,%s,%d},"):format(p.Name, shape, r(p.Size.X), r(p.Size.Y), r(p.Size.Z),
		table.concat(c, ","), col, p.Material.Name, r(p.Transparency), r(p.Reflectance), p.CanCollide and 1 or 0)
end
return table.concat(out, "\\n")`);
  rows.push(...out.split("\n").filter((l) => l.startsWith("{")));
  console.log(`rows ${rows.length}/${total}`);
}
if (rows.length !== total) throw new Error(`ได้ ${rows.length} แถว จาก ${total}`);
const file = `-- ${note || outName}
-- ดัมพ์ด้วย tools/dump-model.js จากเพลส ${placeId} · ${expr} · ${total} ชิ้น
-- แถว: { ชื่อ, รูปทรง, กว้าง,สูง,ลึก, CFrame 12 ตัวเทียบก้นกลางกล่องครอบ, สี(0xRRGGBB), วัสดุ, โปร่งแสง, สะท้อน, ชนได้ }
-- รูปทรง: 0 Ball · 1 Block · 2 Cylinder · 9 Wedge · 10 CornerWedge
local ROWS = {
${rows.join("\n")}
}

local SHAPES = { [0] = Enum.PartType.Ball, [1] = Enum.PartType.Block, [2] = Enum.PartType.Cylinder }

-- สร้างโมเดล: จุดหมุน (WorldPivot) = ก้นกลาง → PivotTo(จุดบนพื้น) วางพอดีพื้น · ทุกชิ้น anchored
return function()
	local model = Instance.new("Model")
	for _, row in ipairs(ROWS) do
		local shape = row[2]
		local part = Instance.new(shape == 9 and "WedgePart" or shape == 10 and "CornerWedgePart" or "Part")
		part.Name = row[1]
		if shape ~= 9 and shape ~= 10 and SHAPES[shape] then part.Shape = SHAPES[shape] end
		part.Size = Vector3.new(row[3], row[4], row[5])
		part.CFrame = CFrame.new(row[6], row[7], row[8], row[9], row[10], row[11], row[12], row[13], row[14], row[15], row[16], row[17])
		part.Color = Color3.fromRGB(bit32.band(bit32.rshift(row[18], 16), 255), bit32.band(bit32.rshift(row[18], 8), 255), bit32.band(row[18], 255))
		local ok = pcall(function() part.Material = Enum.Material[row[19]] end)
		if not ok then part.Material = Enum.Material.Plastic end
		part.Transparency = row[20]
		part.Reflectance = row[21]
		part.CanCollide = row[22] == 1
		part.Anchored = true
		part.Parent = model
	end
	model.WorldPivot = CFrame.new()
	return model
end
`;
fs.writeFileSync(path.join(root, "assets", "models-from-main", outName + ".lua"), file);
console.log(`เขียน assets/models-from-main/${outName}.lua (${total} ชิ้น)`);
```

- [ ] **Step 2: ดัมพ์รถจากเพลสเกาะ** — `node tools/dump-model.js 136992335889132 "workspace.WOLD_Island.Fixed.Car_Cargo" cargo_truck "รถคาร์โก้บนเกาะ (Car_Cargo ที่ผู้ใช้วาง) — ใช้ในคัทซีนเกาะลอยฟ้า (เพลสหลัก)"` · Expected: `เขียน assets/models-from-main/cargo_truck.lua (249 ชิ้น)` · เปิดไฟล์ดูว่าแถวแรกๆ ถูกรูป

- [ ] **Step 3: เฟสติดตั้ง** — `mapgen/111_story_cargo_truck.lua`:

```lua
-- 111_story_cargo_truck: รถคาร์โก้สำหรับคัทซีน "เกาะลอยฟ้าแห่งความฝัน" (เพลสหลัก · 2026-09-29)
-- รัน: node tools/run-luau.js mapgen/111_story_cargo_truck.lua --no-lib --furniture
-- โมเดลคัดลอกจาก Car_Cargo บนเกาะ (assets/models-from-main/cargo_truck.lua) → ReplicatedStorage.WOLD_Cutscene.CargoTruck
-- ไคลเอนต์โคลนไปเล่นเองคนเดียว · ชนไม่ได้ · ReplicatedStorage มี $ignoreUnknownInstances Rojo จึงไม่ลบ
local RS = game:GetService("ReplicatedStorage")
local build = _G.WOLD_MAIN_MODELS and _G.WOLD_MAIN_MODELS.cargo_truck
if not build then error("ต้องรันด้วย --furniture") end
local folder = RS:FindFirstChild("WOLD_Cutscene")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WOLD_Cutscene"
	folder.Parent = RS
end
local old = folder:FindFirstChild("CargoTruck")
if old then old:Destroy() end
local truck = build()
truck.Name = "CargoTruck"
local n = 0
for _, p in ipairs(truck:GetDescendants()) do
	if p:IsA("BasePart") then
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		n += 1
	end
end
truck.Parent = folder
local _, size = truck:GetBoundingBox()
return ("CargoTruck %d ชิ้น · กว้าง %.1f สูง %.1f ยาว %.1f"):format(n, size.X, size.Y, size.Z)
```

รัน: `node tools/run-luau.js mapgen/111_story_cargo_truck.lua --no-lib --furniture` · Expected: `CargoTruck 249 ชิ้น · ... สูง 9.2 ...` (ขนาดราว 12.4 × 9.2 × 17.3 ตามที่วัดบนเกาะ)

- [ ] **Step 4: เนื้อคัทซีน** — แทนตัวว่าง `local function runSkyCutscene(info) ... end` ใน `StoryController` ด้วย:

```lua
-- คัทซีนรถคาร์โก้ (StoryConfig.SkyCutscene) → จอขาวค้าง → ให้เซิร์ฟวาป · ภาพทั้งหมดเป็นของเครื่องนี้
local function whiteVeil()
	local g = Instance.new("ScreenGui")
	g.Name = "WOLD_SkyVeil"
	g.IgnoreGuiInset = true
	g.DisplayOrder = 1000
	g.ResetOnSpawn = false
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	f.Parent = g
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.5)
	t.Size = UDim2.fromScale(0.8, 0.12)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(170, 130, 60)
	t.Text = StoryConfig.SkyTitle
	t.Parent = f
	return g
end

local skyRestore = nil -- คืนหน้าจอตอนวาปไม่สำเร็จ
local function runSkyCutscene(info)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (camera and hrp) then
		Remotes.RequestStory:FireServer("sky_warp")
		return
	end
	inCutscene = true
	local at = (info and info.at) or hrp.Position
	PhotoMode.Set(true)
	local touch = playerGui:FindFirstChild("TouchActionGui")
	local touchWas = touch and touch.Enabled
	if touch then touch.Enabled = false end
	gui:SetCinema(true)
	local cameraType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	local skipped = false
	local skipConn = gui.skipButton.Activated:Connect(function() skipped = true end)
	local playing = {}
	local function sfx(name)
		local sound = UiSound.Play(name)
		if sound then playing[#playing + 1] = sound end
	end
	local function wait(seconds)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and not skipped do RunService.RenderStepped:Wait() end
	end

	-- รถ: ข้างตัวผู้เล่น 10 สตัด บนพื้นจริง หันไปทางเดียวกับผู้เล่น
	local look = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	local right = look:Cross(Vector3.yAxis)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local spot = hrp.Position + right * 10
	local hit = workspace:Raycast(spot + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	local ground = hit and hit.Position or (spot - Vector3.new(0, 3, 0))
	local truckCf = CFrame.lookAt(ground, ground + look)
	local folder = ReplicatedStorage:FindFirstChild("WOLD_Cutscene")
	local proto = folder and folder:FindFirstChild("CargoTruck")
	local truck = proto and proto:Clone()
	local fades = {}
	if truck then
		for _, p in ipairs(truck:GetDescendants()) do
			if p:IsA("BasePart") then
				fades[p] = p.Transparency
				p.Transparency = 1
			end
		end
		truck:PivotTo(truckCf)
		truck.Parent = workspace
	end

	-- แสงทองของออฟาเรียน
	local glow = Instance.new("Part")
	glow.Anchored, glow.CanCollide, glow.CanQuery, glow.CanTouch = true, false, false, false
	glow.Transparency = 1
	glow.Size = Vector3.new(1, 1, 1)
	glow.Position = at + Vector3.new(0, 3, 0)
	glow.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 214, 120)
	light.Range = 18
	light.Brightness = 0
	light.Parent = glow
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 214, 120))
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = glow

	local function hideSelf(on)
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = on and 1 or 0 end
		end
	end

	-- รถลอยขึ้น + กล้องตาม (ใช้ทั้งฉาก rise และ clouds)
	local follow = nil -- "rise" | "clouds" | nil
	local riseStart = nil
	local followConn = RunService.RenderStepped:Connect(function()
		if not (truck and riseStart) then return end
		local k = os.clock() - riseStart
		truck:PivotTo(truckCf + Vector3.new(0, k * k * 6, 0))
		local pos = truck:GetPivot().Position
		if follow == "rise" then
			camera.CFrame = CFrame.lookAt(pos + look * 34 + right * 26 + Vector3.new(0, -6, 0), pos + Vector3.new(0, 4, 0))
		elseif follow == "clouds" then
			camera.CFrame = CFrame.lookAt(pos + Vector3.new(24, 70, 24), pos)
		end
	end)

	local c = ground + Vector3.new(0, 3, 0)
	local shots = {
		glow = function(beat)
			TweenService:Create(light, TweenInfo.new(1.5), { Brightness = 4 }):Play()
			emitter.Rate = 30
			sfx("CutMagic")
			tweenCamera(camera, CFrame.lookAt(at + right * 6 + look * 8 + Vector3.new(0, 4, 0), at + Vector3.new(0, 3, 0)),
				CFrame.lookAt(at + right * 10 + look * 14 + Vector3.new(0, 7, 0), at + Vector3.new(0, 3, 0)), beat.seconds)
		end,
		truck = function(beat)
			gui:Flash(0.5)
			sfx("CutFlash")
			sfx("CutRumble")
			for p, t in pairs(fades) do TweenService:Create(p, TweenInfo.new(2), { Transparency = t }):Play() end
			tweenCamera(camera, CFrame.lookAt(c + look * 22 + right * 14 + Vector3.new(0, 6, 0), c),
				CFrame.lookAt(c + look * 16 + right * 10 + Vector3.new(0, 4, 0), c), beat.seconds)
		end,
		board = function()
			gui:Black(true, 0.5)
			task.delay(0.8, function()
				hideSelf(true)
				if not skipped then gui:Black(false, 0.6) end
			end)
		end,
		rise = function()
			sfx("CutRumble")
			riseStart = os.clock()
			follow = "rise"
		end,
		clouds = function()
			follow = "clouds"
		end,
		flash = function(beat)
			gui:Flash(beat.seconds)
			sfx("CutFlash")
		end,
		title = function(beat)
			follow = nil
			gui:White(true)
			gui:TitleCard(beat.title, beat.subtitle)
			sfx("CutTitle")
		end,
	}

	for _, beat in ipairs(StoryConfig.SkyCutscene) do
		if skipped then break end
		gui:Caption(beat.text, beat.who)
		local fn = shots[beat.shot]
		if fn then pcall(fn, beat) end
		wait(beat.seconds or 3)
	end

	-- จบ/ข้าม: จอขาวค้าง (ต่อเนื่องไปถึงเกาะด้วย SetTeleportGui) แล้วให้เซิร์ฟวาป
	for _, sound in ipairs(playing) do
		if sound.Parent then
			TweenService:Create(sound, TweenInfo.new(0.6), { Volume = 0 }):Play()
			game:GetService("Debris"):AddItem(sound, 0.7)
		end
	end
	gui:White(true)
	local veil = whiteVeil()
	pcall(function() TeleportService:SetTeleportGui(veil) end)
	veil.Parent = playerGui
	followConn:Disconnect()
	skyRestore = function()
		inCutscene = false
		skipConn:Disconnect()
		hideSelf(false)
		if truck then truck:Destroy() end
		glow:Destroy()
		veil:Destroy()
		camera.CameraType = cameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or cameraType
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then camera.CameraSubject = humanoid end
		gui:White(false)
		gui:SetCinema(false)
		PhotoMode.Set(false)
		if touch and touchWas ~= nil then touch.Enabled = touchWas end
	end
	Remotes.RequestStory:FireServer("sky_warp")
end
```

(ลบบรรทัด `local skyRestore = nil` ตัวเก่าที่ Task 8 ใส่ไว้ก่อน — เหลือตัวเดียว)

- [ ] **Step 5: ตรวจ + ดัน** — `bash tools/offline-check.sh src/StarterPlayerScripts/StoryController.client.lua mapgen/111_story_cargo_truck.lua` → ดันสามเพลส · Expected `mismatches 0`
- [ ] **Step 6: commit** — `git add tools/dump-model.js assets/models-from-main/cargo_truck.lua mapgen/111_story_cargo_truck.lua src/StarterPlayerScripts/StoryController.client.lua` · `git commit -m "Sky-island cutscene: cargo truck copied from the island, rises through the clouds, white veil into the warp"`

---

### Task 10: ป้ายต้อนรับบนเกาะ

**Files:**
- Create: `src/ServerScriptService/Island/IslandWelcome.server.lua` · `src/StarterPlayerScripts/IslandWelcomeController.client.lua`
- Modify: `arena.project.json` (denylist สองไฟล์)

**Interfaces:**
- Consumes: `profile.Data.Story.skyWelcome` (T5) · `StoryConfig.Dialogues.island_welcome/SkyTitle/SkySubtitle` (T4) · `IslandAccess.IsOwner`
- Produces: RequestStory `"island_ready"` (ไคลเอนต์เกาะ) · StoryPlay `"welcome"`

- [ ] **Step 1: เซิร์ฟ**

```lua
-- IslandWelcome.server: ป้ายต้อนรับครั้งแรกบนเกาะ (เควส "เกาะลอยฟ้าแห่งความฝัน" · 2026-09-29)
-- ธง `Story.skyWelcome` ตั้งตอนกด "รับพร" (Story.server เกมหลัก) · ผูกกับธง ไม่ใช่กับการวาป — เข้าจากล็อบบี้ก็ได้ป้ายเหมือนกัน
-- เจ้าของเกาะเท่านั้น (ไปเกาะเพื่อนก่อน = ธงรอไว้เกาะตัวเอง) · Story.server ไม่รันบนเกาะ ช่อง RequestStory จึงว่างให้ใช้
local Players = game:GetService("Players")
local ServerConfig = require(script.Parent.Parent.ServerConfig)
if not ServerConfig.IsFarm then return end

local ProfileAccess = require(script.Parent.Parent.ProfileAccess)
local IslandAccess = require(script.Parent.IslandAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)

local Done = {}

Remotes.RequestStory.OnServerEvent:Connect(function(player, action)
	if action ~= "island_ready" or Done[player] then return end
	local data = ProfileAccess.Get(player)
	if not data then return end -- ไคลเอนต์ส่งซ้ำอีกรอบ
	if IslandAccess.IsOwner and not IslandAccess.IsOwner(player) then return end
	Done[player] = true
	local story = data.Story
	if type(story) == "table" and story.skyWelcome == true then
		story.skyWelcome = nil
		Remotes.StoryPlay:FireClient(player, "welcome")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Done[player] = nil
end)
```

- [ ] **Step 2: ไคลเอนต์**

```lua
-- IslandWelcomeController: ป้ายต้อนรับครั้งแรกบนเกาะ (เฉพาะเพลสเกาะ · StoryController ไม่รันบนเกาะ) — 2026-09-29
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

while workspace:GetAttribute("IsLobby") == nil do task.wait(0.2) end
if workspace:GetAttribute("IslandMode") ~= true then return end

local Remotes = require(ReplicatedStorage.Remotes)
local StoryConfig = require(ReplicatedStorage.StoryConfig)
local StoryGui = require(ReplicatedStorage.UI.StoryGui)
local UiSound = require(ReplicatedStorage.UI.UiSound)

local player = Players.LocalPlayer
local gui = nil
local shown = false

Remotes.StoryPlay.OnClientEvent:Connect(function(kind)
	if kind ~= "welcome" or shown then return end
	shown = true
	gui = gui or StoryGui.new(player:WaitForChild("PlayerGui"))
	UiSound.Play("CutTitle")
	gui:Banner("🏝️ " .. StoryConfig.SkyTitle, StoryConfig.SkySubtitle, 8)
	task.delay(1.5, function()
		gui:Say(StoryConfig.Dialogues.island_welcome)
	end)
end)

-- หลังจอโหลดจบ บอกเซิร์ฟ (ส่งซ้ำ: โปรไฟล์อาจยังโหลดไม่เสร็จ · เซิร์ฟตอบครั้งเดียว)
task.spawn(function()
	while player:GetAttribute("WOLD_Loaded") ~= true do task.wait(0.25) end
	for _ = 1, 6 do
		if shown then break end
		Remotes.RequestStory:FireServer("island_ready")
		task.wait(3)
	end
end)
```

(StoryGui ไม่มี tracker แล้วหลัง Task 8 — ใช้ได้บนเกาะโดยไม่มีของแปลกโผล่)

- [ ] **Step 3: denylist สนาม** — `arena.project.json` เติมในรายการ `globIgnorePaths` ตามรูปแบบเดิม: `"src/ServerScriptService/Island/IslandWelcome.server.lua",` (หลัง IslandPlots) และ `"src/StarterPlayerScripts/IslandWelcomeController.client.lua",` (หลัง IslandSeedController ระวังจุลภาคท้ายรายการ)
- [ ] **Step 4: ตรวจ + ดัน** — `bash tools/offline-check.sh src/ServerScriptService/Island/IslandWelcome.server.lua src/StarterPlayerScripts/IslandWelcomeController.client.lua` → `node -e "JSON.parse(require('fs').readFileSync('arena.project.json','utf8'))"` → ดันสามเพลส · Expected `mismatches 0`
- [ ] **Step 5: commit** — `git add src/ServerScriptService/Island/IslandWelcome.server.lua src/StarterPlayerScripts/IslandWelcomeController.client.lua arena.project.json` · `git commit -m "First arrival on the sky island: title banner and Oforian's welcome lines, owner only"`

---

### Task 11: ปิดงาน

- [ ] **Step 1: รันเทสทั้งชุดที่แตะ** — `node tools/offline-test.js tests/quest_log_rules_test.lua` · `tests/quest_nav_rules_test.lua` · `tests/story_config_test.lua` · `node tools/lua.js tests/vip_gift_test.lua Edit` · `tests/quest_tracker_gui_test.lua Edit` · `tests/auto_walk_test.lua Edit` · Expected: PASS ทุกตัว
- [ ] **Step 2: สามเพลสตรง** — `node tools/verify.js default.project.json` · `farming.project.json` · `arena.project.json` · Expected `mismatches 0` ทั้งสาม
- [ ] **Step 3: UI ทับกัน** — `bash tools/ui-audit/run.sh` ถ้าเครื่องมือยังใช้ได้ (ตาราง `SYN` อาจต้องเติมแถบใหม่) — ดูว่า `WOLD_QuestLog` ไม่ทับหน้าต่าง (อยู่ DO 4) · ใช้ไม่ได้ = จดไว้ให้ผู้ใช้ดูในเกม
- [ ] **Step 4: CLAUDE.md** — เพิ่มหัวข้อใหม่ใต้ "มอนบุกเกาะตอนกลางคืน…": แถบเควสรวม (สามสี · DO 4 · `QuestLogRules`/`QuestTrackerGui`/`QuestTrackerController` · นำทางผ่าน `QuestNav` ฝั่งเซิร์ฟ) · ออฟาเรียน (เควสฟ้าสี่อัน คำนวณจากธง VipGift · `TalkOforian` · VIP ทบ) · วาปครั้งเดียว (ข้อยกเว้นกฎล็อบบี้ · `FarmRegistry.GetOrCreate` + `TeleportToPrivateServer` ใน Story.server) · `Story.skyWelcome` · บทล็อก `saltmere` · คำสั่ง `/story gifts` `/story welcome` · เครื่องมือ `tools/dump-model.js` · ⚠️ `VipGift.Summary` ถูกลบ
- [ ] **Step 5: commit** — `git add CLAUDE.md` · `git commit -m "docs: quest log, Oforian quests and the sky-island warp"`
- [ ] **Step 6: สรุปให้ผู้ใช้เทส** (ภาษาไทย): `/story gifts` → คุยออฟาเรียนสี่เควส · `/level 5` (หรือคำสั่งที่มี) → เควสเกาะ → รับพร → คัทซีน → วาป (**ต้อง publish ทั้งเพลสหลักและเพลสเกาะ** — Studio บล็อก TeleportService) · จิ้มแถวทุกสีแล้วดูหมุด + กด T · แถวล็อกซอลต์เมียร์ · มือถือ: แถบเริ่มย่อ ไม่ทับปุ่ม Q
