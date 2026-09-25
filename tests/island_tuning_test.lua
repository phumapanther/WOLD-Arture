-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_tuning_test.lua Server
--
-- รอบปรับค่าตามที่ผู้ใช้สั่ง 2026-09-23 (แปดข้อ): โมเดลจมดิน · เวลาสัตว์รายชนิด · โซนแร่ช้าลง ·
-- ผืนดินทีละ 1-3 ทุกชั่วโมง · หน้าต่างคอกบอกเวลา · ราคา · เมล็ดติดมือ · ผักโตช้าลง
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local T = game:GetService("ServerStorage"):WaitForChild("IslandTest", 20)
local function A(op, ...) return T:Invoke(op, ...) end
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่น")
local C = require(game.ReplicatedStorage.IslandConfig)
local ShopConfig = require(game.ReplicatedStorage.ShopConfig)
local IslandGrid = require(game.ReplicatedStorage.IslandGrid)
local out = {}

local t0 = os.clock()
while not A("Data") and os.clock() - t0 < 20 do task.wait(0.2) end
assert(A("Data"), "ข้อมูลเกาะไม่โหลด")

----------------------------------------------------------------- 1. โมเดลต้องไม่จมดิน
A("NodeClear")
for _ = 1, 25 do A("NodeSpawnOnce") end
local folder = assert(workspace.WOLD_Island:FindFirstChild("Nodes"), "โฟลเดอร์ Nodes")
local worst, worstName, checked = 0, "?", 0
for _, m in ipairs(folder:GetChildren()) do
	local cf, size = m:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	local cx, cz = IslandGrid.cellOf(cf.Position.X, cf.Position.Z)
	local ground = IslandGrid.surfaceAt(cx, cz)
	if ground then
		checked += 1
		local sunk = ground - bottom -- บวก = จม · ลบ = ลอย
		if math.abs(sunk) > math.abs(worst) then worst, worstName = sunk, m.Name end
	end
end
assert(checked > 0, "ต้องวัดได้อย่างน้อยหนึ่งจุด")
-- เผื่อไว้ 1.5 สตัด: ผิวเทอร์เรนใต้โมเดลกว้างๆ ไม่ได้เรียบเท่ากันทุกมุม
assert(math.abs(worst) <= 1.5,
	("โมเดลยังจม/ลอยอยู่ %.2f สตัด (%s) จาก %d จุด"):format(worst, worstName, checked))
table.insert(out, ("โมเดลนั่งบนผิวดิน: วัด %d จุด เพี้ยนมากสุด %.2f สตัด (%s)"):format(checked, worst, worstName))
A("NodeClear")

----------------------------------------------------------------- 2. เวลาสัตว์รายชนิด 15-45 นาที
local lo, hi = math.huge, 0
for _, a in ipairs(C.PenAnimals) do
	local secs = C.PenHarvestFor(a.kind)
	assert(secs, "ไม่มีเวลาของ " .. a.kind)
	lo, hi = math.min(lo, secs), math.max(hi, secs)
end
assert(lo >= 15 * 60 and hi <= 45 * 60, ("ต้องอยู่ในช่วง 15-45 นาที ได้ %d-%d"):format(lo / 60, hi / 60))
assert(lo ~= hi, "แต่ละชนิดต้องไม่เท่ากัน")
assert(C.PenHarvestFor("Chicken") < C.PenHarvestFor("Horse"), "ไก่ต้องรอสั้นกว่าม้า")
table.insert(out, ("เวลาเก็บผลผลิตสัตว์: %d-%d นาที (ไก่ %d · ม้า %d)")
	:format(lo / 60, hi / 60, C.PenHarvestFor("Chicken") / 60, C.PenHarvestFor("Horse") / 60))

----------------------------------------------------------------- 3. โซนแร่ 30 นาทีขึ้นไป ทีละ 1-2
assert(C.MineEverySeconds >= 30 * 60, ("โซนแร่ต้อง 30 นาทีขึ้นไป ได้ %d"):format(C.MineEverySeconds / 60))
assert(C.MinePerRoundMin == 1 and C.MinePerRoundMax == 2, "ต้องเกิดทีละ 1-2 ก้อน")
table.insert(out, ("โซนแร่: ทุก %d นาที · ทีละ %d-%d ก้อน (เพดาน %d)")
	:format(C.MineEverySeconds / 60, C.MinePerRoundMin, C.MinePerRoundMax, C.MineMax))

----------------------------------------------------------------- 4. ผืนดิน 1-3 ชิ้นทุกชั่วโมง
local NS = C.NodeSpawn
assert(NS.everySeconds >= 60 * 60, ("ผืนดินต้องทุกหนึ่งชั่วโมง ได้ %d นาที"):format(NS.everySeconds / 60))
assert(NS.perRoundMin == 1 and NS.perRoundMax == 3, "ต้องเกิดทีละ 1-3 ชิ้น")
table.insert(out, ("ผืนดิน: ทุก %d นาที · ทีละ %d-%d ชิ้น (เพดาน %d)")
	:format(NS.everySeconds / 60, NS.perRoundMin, NS.perRoundMax, NS.max))

----------------------------------------------------------------- 5. หน้าต่างคอกบอกเวลารายตัว
local pen, penUid, penPlacedHere
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
	penPlacedHere = true
end

local function entryOf()
	for _, e in ipairs(A("Data").placed) do if e.uid == penUid then return e end end
end
local hadHerd = entryOf().herd
for _, a in ipairs(pen:FindFirstChild("Livestock"):GetChildren()) do a:Destroy() end
A("SetEntry", penUid, "herd", nil)
A("SetEntry", penUid, "animal", nil)

A("Grant", player, "gold", 5000)
assert(A("PenBuy", player, pen, "Chicken", 2))
local live = pen:FindFirstChild("Livestock"):GetChildren()
assert(#live == 2, "ต้องมีไก่ 2 ตัว")

-- ตัวหนึ่งยังโตไม่เสร็จ · อีกตัวโตแล้วแต่ติดคูลดาวน์
live[1]:SetAttribute("ReadyAt", os.time() + 300)
live[2]:SetAttribute("ReadyAt", os.time() - 10)
live[2]:SetAttribute("Grown", true)
live[2]:SetAttribute("Spent", true)
live[2]:SetAttribute("ReadyAgainAt", os.time() + 120)
local snap = A("PenSnapshot", pen)
local states = {}
for _, g in ipairs(snap.growing or {}) do states[g.state] = g end
assert(states.grow, "ต้องมีสถานะ 'กำลังโต'")
assert(states.cool, "ต้องมีสถานะ 'รอคูลดาวน์' — นี่คือสิ่งที่ผู้ใช้ขอ")
assert(states.cool.secondsLeft > 100 and states.cool.secondsLeft <= 120,
	("เวลาที่เหลือต้องราว 120 วิ ได้ %s"):format(tostring(states.cool.secondsLeft)))
assert(states.cool.progress > 0 and states.cool.progress < 1, "ความคืบหน้าคูลดาวน์ต้องอยู่ระหว่าง 0-1")
table.insert(out, ("หน้าต่างคอก: กำลังโต %d วิ · เก็บได้อีกใน %d วิ (%d%%)")
	:format(states.grow.secondsLeft, states.cool.secondsLeft, math.floor(states.cool.progress * 100)))

-- คูลดาวน์ที่ตั้งให้สัตว์ต้องเป็นของชนิดนั้นจริง
assert(live[1]:GetAttribute("RespawnSeconds") == C.PenHarvestFor("Chicken"),
	"คูลดาวน์บนตัวสัตว์ต้องเป็นของไก่")
table.insert(out, ("ไก่ได้คูลดาวน์ %d นาทีติดตัวจริง"):format(live[1]:GetAttribute("RespawnSeconds") / 60))

for _, a in ipairs(pen:FindFirstChild("Livestock"):GetChildren()) do a:Destroy() end
A("SetEntry", penUid, "herd", hadHerd)
A("SetEntry", penUid, "animal", nil)
if penPlacedHere then
	assert(A("Pickup", player, penUid), "เก็บคอกที่เทสวางคืน")
	A("Revoke", player, C.PenItem, A("Count", player, C.PenItem) or 0)
end

----------------------------------------------------------------- 6. ราคา
local price = {}
for _, row in ipairs(ShopConfig.IslandSells) do
	if not price[row.id] then price[row.id] = row.price end
end
assert(price.Seed >= 100 and price.Seed < 1000, ("เมล็ดต้องหลักร้อย ได้ %d"):format(price.Seed))
assert(price.AnimalPen >= 10000, ("คอกต้องหลักหมื่น ได้ %d"):format(price.AnimalPen))
assert(price.MineZone >= 10000, ("โซนแร่ต้องหลักหมื่น ได้ %d"):format(price.MineZone))
table.insert(out, ("ราคา: เมล็ด %d · คอก %d · โซนแร่ %d"):format(price.Seed, price.AnimalPen, price.MineZone))

----------------------------------------------------------------- 7. เมล็ดติดมากับการเก็บเกี่ยว
local SB = assert(C.SeedBonus, "ไม่มี IslandConfig.SeedBonus")
if (A("Count", player, "FarmPlot") or 0) < 1 then A("Grant", player, "FarmPlot", 1) end
local slot = assert(A("FindSlot", player, "FarmPlot"), "เสกแปลงไม่ได้")
local cx, cz
for x = -20, 20 do
	for z = -20, 20 do
		if A("CanPlaceAt", x, z, 3, 3, 0, "FarmPlot") then cx, cz = x, z break end
	end
	if cx then break end
end
assert(cx, "ไม่มีที่ว่างพอวางแปลง")
assert(A("Place", player, slot, cx, cz, 0))
local uid = A("Data").placed[#A("Data").placed].uid
local plot = assert(A("ModelOf", uid), "โมเดลแปลง")

A("Revoke", player, C.SeedItem, A("Count", player, C.SeedItem) or 0)
local gained, rounds = 0, 40
for _ = 1, rounds do
	A("Grant", player, C.SeedItem, 1)
	assert(A("Plant", player, plot), "ปลูกไม่สำเร็จ")
	A("SetEntry", uid, "crop", "Wheat")
	A("SetEntry", uid, "at", os.time() - 99999)
	A("SetEntry", uid, "glow", false) -- กันแสงฟ้าคูณเมล็ดจนวัดเพี้ยน (แสงอยู่ในโปรไฟล์แปลง)
	A("Tick")
	local before = A("Count", player, C.SeedItem) or 0
	assert(A("Harvest", player, plot))
	gained += (A("Count", player, C.SeedItem) or 0) - before
end
assert(gained > 0, "เก็บ 40 ครั้งต้องได้เมล็ดติดมาบ้าง")
table.insert(out, ("เมล็ดติดมือ: เก็บ %d ครั้งได้ %d เมล็ด (ตั้งไว้ %d%% ครั้งละ %d-%d)")
	:format(rounds, gained, SB.chance * 100, SB.min, SB.max))

----------------------------------------------------------------- 8. ผักโตช้าลง 10-35 นาที
local slowest, fastest = 0, math.huge
for _, c in ipairs(C.Crops) do
	if c.item ~= "MagicBranch" then
		fastest = math.min(fastest, c.seconds)
		slowest = math.max(slowest, c.seconds)
	end
end
assert(fastest >= 10 * 60, ("พืชที่เร็วสุดต้องไม่ต่ำกว่า 10 นาที ได้ %d"):format(fastest / 60))
assert(slowest >= 35 * 60, ("พืชที่ช้าสุดต้อง 35 นาทีขึ้นไป ได้ %d"):format(slowest / 60))
local bits = {}
for _, c in ipairs(C.Crops) do bits[#bits + 1] = ("%s %d"):format(c.item, c.seconds / 60) end
table.insert(out, "เวลาโตของพืช (นาที): " .. table.concat(bits, " · "))

----------------------------------------------------------------- เก็บของเทสคืน
A("SetEntry", uid, "crop", nil)
A("SetEntry", uid, "at", nil)
plot:SetAttribute("Ripe", nil)
assert(A("Pickup", player, uid), "เก็บแปลงที่เทสวางคืน")
A("Revoke", player, "FarmPlot", A("Count", player, "FarmPlot") or 0)
A("Revoke", player, C.SeedItem, A("Count", player, C.SeedItem) or 0)
A("Revoke", player, "Wheat", A("Count", player, "Wheat") or 0)
A("Revoke", player, "Worm", A("Count", player, "Worm") or 0)
A("NodeClear")
table.insert(out, "เก็บของเทสคืนครบ")
return table.concat(out, "\n")
