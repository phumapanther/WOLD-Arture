-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_yield_test.lua Server
--
-- เพดานวัตถุดิบบนเกาะ (ผู้ใช้สั่ง 2026-09-23): "ควรได้ 1-5 ไม่เกิน 5 ทุกชนิด ผักกับแร่ก็เช่นกัน
-- จะได้เกินก็ต่อเมื่อมีบัพเรืองแสงจนได้ ×2"
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local T = game:GetService("ServerStorage"):WaitForChild("IslandTest", 20)
local function A(op, ...) return T:Invoke(op, ...) end
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่น")
local C = require(game.ReplicatedStorage.IslandConfig)
local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
local out = {}

local CAP = assert(C.YieldCap, "ไม่มี IslandConfig.YieldCap")

local t0 = os.clock()
while not A("Data") and os.clock() - t0 < 20 do task.wait(0.2) end
assert(A("Data"), "ข้อมูลเกาะไม่โหลด")

----------------------------------------------------------------- 1. ตัวเลขในคอนฟิกต้องไม่เกินเพดาน
local worst, worstName = 0, "?"
-- ผลผลิตสัตว์สุ่มถ่วงน้ำหนัก 1-5 ทุกชนิด (2026-09-25) — เพดานคือเลขสูงสุดที่มีน้ำหนัก
for n, w in pairs(C.PenYieldWeights) do
	if w > 0 and n > worst then worst, worstName = n, "ทุกชนิด" end
end
assert(worst <= CAP, ("ผลผลิตสัตว์ในคอนฟิกเกินเพดาน: %s ได้ถึง %d"):format(worstName, worst))
for _, crop in ipairs(C.Crops) do
	assert(crop.max <= CAP, ("พืช %s ในคอนฟิกเกินเพดาน (%d)"):format(crop.item, crop.max))
end
table.insert(out, ("คอนฟิก: ผลผลิตสัตว์สูงสุด %d (%s) · พืชสูงสุด %d · เพดาน %d")
	:format(worst, worstName, (function()
		local m = 0
		for _, c in ipairs(C.Crops) do m = math.max(m, c.max) end
		return m
	end)(), CAP))

----------------------------------------------------------------- 2. เพดานบังคับจริงตอนเก็บ แม้คอนฟิกจะเพี้ยน
-- ตั้ง YieldMin/YieldMax บนโหนดให้เกินเพดานไปเลย แล้วดูว่าของที่ได้ยังไม่เกิน
A("NodeClear")
for _ = 1, 25 do A("NodeSpawnOnce") end
local folder = workspace.WOLD_Island.Nodes
local function pickNode()
	for _, m in ipairs(folder:GetChildren()) do
		local cfg = GatherConfig.Nodes[m:GetAttribute("NodeKind")]
		if cfg and cfg.tool == "pickaxe" and not m:GetAttribute("Spent") then return m, cfg end
	end
end
if not A("FindSlot", player, "Pickaxe") then A("Grant", player, "Pickaxe", 1) end
A("Equip", player, assert(A("FindSlot", player, "Pickaxe"), "เสกอีเต้อไม่ได้"))

local function bagOf(cfg)
	local ids = { [cfg.item] = true }
	for _, e in ipairs(cfg.roll or {}) do ids[e.item] = true end
	local n = 0
	for id in pairs(ids) do n += (A("Count", player, id) or 0) end
	return n, ids
end

local overCap, rounds = 0, 0
local biggest = 0
for _ = 1, 10 do
	local node, cfg = pickNode()
	if not node then break end
	-- คอนฟิกเพี้ยนสุดขั้ว: สั่งให้จุดนี้ให้ 20 ชิ้น
	node:SetAttribute("YieldMin", 20)
	node:SetAttribute("YieldMax", 20)
	node:SetAttribute("Glow", nil) -- ปิดแสงก่อน วัดเพดานล้วนๆ
	local before = bagOf(cfg)
	if A("Gather", player, node) == true then
		rounds += 1
		local got = bagOf(cfg) - before
		biggest = math.max(biggest, got)
		if got > CAP then overCap += 1 end
	end
	task.wait(0.1)
end
assert(rounds > 0, "ต้องเก็บได้อย่างน้อยหนึ่งครั้ง")
assert(overCap == 0, ("มี %d ครั้งที่ได้เกินเพดาน (มากสุด %d)"):format(overCap, biggest))
table.insert(out, ("แร่: สั่งให้จุดละ 20 ชิ้น เก็บ %d ครั้ง → ได้มากสุด %d ชิ้น (เพดาน %d)")
	:format(rounds, biggest, CAP))

----------------------------------------------------------------- 3. แสงฟ้าเท่านั้นที่เกินได้
-- จุดที่ใช้ไปข้างบนหายไปแล้ว (`OneShot`) — เสกเพิ่มก่อน
for _ = 1, 20 do A("NodeSpawnOnce") end
local node, cfg = pickNode()
assert(node, "ต้องมีจุดเหลือให้ทดสอบแสง")
node:SetAttribute("YieldMin", 20)
node:SetAttribute("YieldMax", 20)
node:SetAttribute("Glow", "blue")
local before = bagOf(cfg)
assert(A("Gather", player, node) == true, "เก็บไม่สำเร็จ")
local lit = bagOf(cfg) - before
assert(lit == CAP * C.Glow.yield,
	("แสงฟ้าต้องได้ %d (เพดาน %d ×%d) ได้ %d"):format(CAP * C.Glow.yield, CAP, C.Glow.yield, lit))
table.insert(out, ("แสงฟ้า: เพดาน %d ×%d = %d ชิ้น — ทางเดียวที่เกิน 5 ได้"):format(CAP, C.Glow.yield, lit))

----------------------------------------------------------------- 4. สัตว์ในคอก
local pen, penUid, placedHere
for _, e in ipairs(A("Data").placed) do
	if e.id == C.PenItem then pen, penUid = A("ModelOf", e.uid), e.uid break end
end
if not pen then
	if (A("Count", player, C.PenItem) or 0) < 1 then A("Grant", player, C.PenItem, 1) end
	local slot = assert(A("FindSlot", player, C.PenItem), "เสกคอกไม่ได้")
	local cx, cz
	for x = -20, 20 do
		for z = -20, 20 do
			if A("CanPlaceAt", x, z, 6, 6, 0, C.PenItem) then cx, cz = x, z break end
		end
		if cx then break end
	end
	assert(cx, "ไม่มีที่ว่างพอวางคอก")
	assert(A("Place", player, slot, cx, cz, 0))
	penUid = A("Data").placed[#A("Data").placed].uid
	pen = A("ModelOf", penUid)
	placedHere = true
end
local function entryOf()
	for _, e in ipairs(A("Data").placed) do if e.uid == penUid then return e end end
end
local hadHerd = entryOf().herd
for _, a in ipairs(pen.Livestock:GetChildren()) do a:Destroy() end
A("SetEntry", penUid, "herd", nil)
A("SetEntry", penUid, "animal", nil)

A("Grant", player, "gold", 8000)
assert(A("PenBuy", player, pen, "Cow", 1)) -- วัวคือชนิดที่เคยให้ถึง 7
local cow = pen.Livestock:GetChildren()[1]
assert(cow:GetAttribute("YieldMax") <= CAP,
	("วัวต้องได้ไม่เกิน %d ตั้งไว้ %s"):format(CAP, tostring(cow:GetAttribute("YieldMax"))))

A("Revoke", player, "Milk", A("Count", player, "Milk") or 0)
local most = 0
for _ = 1, 8 do
	cow:SetAttribute("ReadyAt", os.time() - 1)
	cow:SetAttribute("Grown", true)
	cow:SetAttribute("Spent", nil)
	cow:SetAttribute("ReadyAgainAt", nil)
	cow:SetAttribute("Glow", nil)
	local before = A("Count", player, "Milk") or 0
	if A("Gather", player, cow) == true then
		most = math.max(most, (A("Count", player, "Milk") or 0) - before)
	end
	task.wait(0.1)
end
assert(most > 0 and most <= CAP, ("นมที่ได้ต้องไม่เกิน %d ได้ %d"):format(CAP, most))
table.insert(out, ("วัว: รีดนม 8 ครั้ง ได้มากสุด %d (เพดาน %d · เดิมตั้งไว้ถึง 7)"):format(most, CAP))
A("Revoke", player, "Milk", A("Count", player, "Milk") or 0)

----------------------------------------------------------------- 5. แปลงผัก
if (A("Count", player, "FarmPlot") or 0) < 1 then A("Grant", player, "FarmPlot", 1) end
local slot = assert(A("FindSlot", player, "FarmPlot"), "เสกแปลงไม่ได้")
local px, pz
for x = -20, 20 do
	for z = -20, 20 do
		if A("CanPlaceAt", x, z, 3, 3, 0, "FarmPlot") then px, pz = x, z break end
	end
	if px then break end
end
assert(px, "ไม่มีที่ว่างพอวางแปลง")
assert(A("Place", player, slot, px, pz, 0))
local plotUid = A("Data").placed[#A("Data").placed].uid
local plot = assert(A("ModelOf", plotUid), "โมเดลแปลง")

A("Revoke", player, "Wheat", A("Count", player, "Wheat") or 0)
local cropMost = 0
for _ = 1, 10 do
	if (A("Count", player, C.SeedItem) or 0) < 1 then A("Grant", player, C.SeedItem, 1) end
	assert(A("Plant", player, plot))
	A("SetEntry", plotUid, "crop", "Wheat")
	A("SetEntry", plotUid, "at", os.time() - 99999)
	A("SetEntry", plotUid, "glow", false) -- ปิดแสง (อยู่ในโปรไฟล์แปลง ไม่ใช่แอตทริบิวต์แล้ว)
	A("Tick")
	local before = A("Count", player, "Wheat") or 0
	assert(A("Harvest", player, plot))
	cropMost = math.max(cropMost, (A("Count", player, "Wheat") or 0) - before)
end
assert(cropMost <= CAP, ("ผักที่ได้ต้องไม่เกิน %d ได้ %d"):format(CAP, cropMost))
table.insert(out, ("แปลงผัก: เก็บ 10 ครั้ง ได้มากสุด %d (เพดาน %d)"):format(cropMost, CAP))

----------------------------------------------------------------- เก็บของเทสคืน
A("Unequip", player, "weapon")
A("Revoke", player, "Pickaxe", A("Count", player, "Pickaxe") or 0)
for _, id in ipairs({ "Stone", "Coal", "IronOre", "SilverOre", "GoldOre", "MagicOre", "DiamondOre", "Crystal", "Wheat", "Worm", "Milk" }) do
	local n = A("Count", player, id) or 0
	if n > 0 then A("Revoke", player, id, n) end
end
A("SetEntry", plotUid, "crop", nil)
A("SetEntry", plotUid, "at", nil)
assert(A("Pickup", player, plotUid), "เก็บแปลงคืน")
A("Revoke", player, "FarmPlot", A("Count", player, "FarmPlot") or 0)
A("Revoke", player, C.SeedItem, A("Count", player, C.SeedItem) or 0)
for _, a in ipairs(pen.Livestock:GetChildren()) do a:Destroy() end
A("SetEntry", penUid, "herd", hadHerd)
A("SetEntry", penUid, "animal", nil)
if placedHere then
	assert(A("Pickup", player, penUid), "เก็บคอกคืน")
	A("Revoke", player, C.PenItem, A("Count", player, C.PenItem) or 0)
end
A("NodeClear")
table.insert(out, "เก็บของเทสคืนครบ")
return table.concat(out, "\n")
