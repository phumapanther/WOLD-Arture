-- node tools/lua.js tests/quest_roll_test.lua Edit   (เพลสไหนก็ได้ — ข้อมูลล้วน)
-- บอร์ดเควสบราสเฮเวน (ผู้ใช้สั่ง 2026-09-27): วันละ 3 ใบ · มีงานสไลม์ (ล่าสไลม์ หรือ ส่งเมือกสไลม์) หนึ่งใบทุกวันเสมอ ·
-- สองใบนี้ไม่ออกพร้อมกันเด็ดขาด · บอร์ดเมืองอื่นไม่เปลี่ยน
local RS = game.ReplicatedStorage
local temp = Instance.new("Folder")
temp.Name = "QuestRollTest_" .. math.random(1, 1e9)
temp.Parent = RS
for _, name in ipairs({ "QuestConfig", "QuestRoll", "CraftConfig", "ShopConfig", "MailConfig", "PremiumConfig", "ItemCatalog",
	"GatherConfig" }) do
	RS[name]:Clone().Parent = temp
end
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local ok, err = pcall(function()
	local QuestConfig = require(temp.QuestConfig)
	local QuestRoll = require(temp.QuestRoll)
	local ItemCatalog = require(temp.ItemCatalog)
	local GatherConfig = require(temp.GatherConfig)

	local board
	for _, b in ipairs(QuestConfig.Boards) do if b.id == "Brasshaven" then board = b end end
	check(board ~= nil and board.mustHave == "slime", "มีบอร์ดบราสเฮเวน + กติกางานสไลม์")

	-- งานในคลังตรงกับที่ผู้ใช้สั่งครบ 12 อย่าง และของ/มอนมีอยู่จริง
	local want = { "gather:WoodScrap", "gather:Stone", "gather:IronOre", "gather:Crystal", "gather:Coal", "gather:Slime",
		"gather:Bone", "gather:Fiber", "gather:Herb", "hunt:โครงกระดูก", "hunt:สไลม์เขียว", "hunt:แมงมุมยักษ์" }
	local have, problems = {}, {}
	for _, spec in ipairs(board.pool) do
		local key = spec.kind .. ":" .. (spec.item or spec.mob)
		have[key] = true
		if spec.kind == "gather" and not ItemCatalog.Exists(spec.item) then problems[#problems + 1] = key .. ":ไม่มีไอเทม" end
		if spec.kind == "hunt" then
			local found = false
			for _, mob in pairs(GatherConfig.Mobs) do if mob.name == spec.mob then found = true end end
			if not found then problems[#problems + 1] = key .. ":ไม่มีมอนชื่อนี้" end
			if not QuestConfig.MobImages[spec.mob] then problems[#problems + 1] = key .. ":ไม่มีรูปบนใบประกาศ" end
		end
		if not (spec.min and spec.max and spec.min <= spec.max and spec.gold and spec.xp) then problems[#problems + 1] = key .. ":ตัวเลขเสีย" end
	end
	for _, key in ipairs(want) do if not have[key] then problems[#problems + 1] = key .. ":หายไป" end end
	check(#board.pool == 12 and #problems == 0, "คลังงาน 12 อย่างครบ ของ/มอนมีจริง " .. table.concat(problems, " | "))

	local slimeKeys = { ["gather:Slime"] = "ส่ง", ["hunt:สไลม์เขียว"] = "ล่า" }
	local rollProblems, seenSlime, seenOther, rolls = {}, {}, {}, 0
	for day = 20000, 20730 do
		for extra = 0, 3 do
			rolls += 1
			local quests = QuestRoll.Roll(board, day, extra)
			local slimes, dup = 0, {}
			for _, q in ipairs(quests) do
				local key = q.kind .. ":" .. (q.item or q.mob)
				if slimeKeys[key] then
					slimes += 1
					seenSlime[key] = (seenSlime[key] or 0) + 1
				else
					seenOther[key] = true
				end
				if dup[key] then rollProblems[#rollProblems + 1] = ("วัน %d:%s ซ้ำ"):format(day, key) end
				dup[key] = true
				if q.board ~= "Brasshaven" or q.need < 1 then rollProblems[#rollProblems + 1] = ("วัน %d:ใบเสีย"):format(day) end
			end
			if #quests ~= 3 then rollProblems[#rollProblems + 1] = ("วัน %d:%d ใบ"):format(day, #quests) end
			if slimes ~= 1 then rollProblems[#rollProblems + 1] = ("วัน %d รี %d:งานสไลม์ %d ใบ"):format(day, extra, slimes) end
			if #rollProblems > 5 then break end
		end
	end
	check(#rollProblems == 0, ("%d ชุด (2 ปี × รี 0-3): 3 ใบ · งานสไลม์ 1 ใบพอดีทุกชุด · ไม่มีใบซ้ำ %s"):format(rolls,
		table.concat(rollProblems, " | ")))
	local hunt, gather = seenSlime["hunt:สไลม์เขียว"] or 0, seenSlime["gather:Slime"] or 0
	check(hunt > rolls * 0.35 and gather > rolls * 0.35, ("ล่าสไลม์ %d ครั้ง · ส่งเมือก %d ครั้ง (ออกพอๆ กัน)"):format(hunt, gather))
	local others = 0
	for _ in pairs(seenOther) do others += 1 end
	check(others == 10, "งานอื่นอีก 10 อย่างได้ออกครบ " .. others)
	-- สุ่มซ้ำได้ผลเดิม (ทุกเซิร์ฟเห็นชุดเดียวกัน)
	local a, b = QuestRoll.Roll(board, 20100, 0), QuestRoll.Roll(board, 20100, 0)
	local same = #a == #b
	for i = 1, #a do
		if a[i].kind ~= b[i].kind or (a[i].item or a[i].mob) ~= (b[i].item or b[i].mob) or a[i].need ~= b[i].need then same = false end
	end
	check(same, "วันเดียวกันได้ชุดเดียวกันเสมอ")

	-- บอร์ดเมืองอื่น: 3 ใบ ไม่ซ้ำ ไม่มีกติกางานบังคับ
	local otherProblems = {}
	for _, b2 in ipairs(QuestConfig.Boards) do
		if b2.id ~= "Brasshaven" then
			if b2.mustHave then otherProblems[#otherProblems + 1] = b2.id .. ":มีงานบังคับ" end
			for day = 20000, 20060 do
				local qs = QuestRoll.Roll(b2, day, 0)
				local dup = {}
				for _, q in ipairs(qs) do
					local key = q.kind .. ":" .. (q.item or q.mob)
					if dup[key] then otherProblems[#otherProblems + 1] = b2.id .. ":ซ้ำ" end
					dup[key] = true
				end
				if #qs ~= 3 then otherProblems[#otherProblems + 1] = b2.id .. ":ไม่ครบ 3" end
			end
		end
	end
	check(#otherProblems == 0 and #QuestConfig.Boards == 7, "บอร์ดเมืองอื่นหกบอร์ดยังสุ่ม 3 ใบปกติ " .. table.concat(otherProblems, ","))
end)
check(ok, "ไม่มี error " .. tostring(err))
temp:Destroy()
return ("%s — %d fail\n%s"):format(fails == 0 and "PASS" or "FAIL", fails, table.concat(out, "\n"))
