-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_badge_test.lua Server
--
-- ป้ายอีโมจิเหนือของที่พร้อมเก็บ (ผู้ใช้สั่ง 2026-09-23)
--
-- ⚠️ **เทสนี้ตรวจฝั่งเซิร์ฟเวอร์เท่านั้น** — ตัวป้ายถูกวาดโดย `IslandBadgeController` ซึ่งเป็น
-- LocalScript ที่มองไม่เห็นจากที่นี่ · สิ่งที่พิสูจน์ได้คือ **ข้อมูลที่ป้ายอ่าน** ครบและถูกต้องไหม
-- (ตัวป้ายเองต้องดูในดาต้าโมเดล Client: `node tools/lua.js <ไฟล์> Client`)
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local T = game:GetService("ServerStorage"):WaitForChild("IslandTest", 20)
local function A(op, ...) return T:Invoke(op, ...) end
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่น")
local C = require(game.ReplicatedStorage.IslandConfig)
local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
local out = {}

local CFG = assert(C.Badges, "ไม่มี IslandConfig.Badges")
assert(CFG.enabled, "ป้ายถูกปิดอยู่")

local t0 = os.clock()
while not A("Data") and os.clock() - t0 < 20 do task.wait(0.2) end
assert(A("Data"), "ข้อมูลเกาะไม่โหลด")

----------------------------------------------------------------- 1. จุดเก็บเกี่ยว: อีโมจิตามเครื่องมือ
local BY_TOOL = { pickaxe = CFG.pickaxe, axe = CFG.axe, shovel = CFG.shovel }
for _ = 1, 25 do A("NodeSpawnOnce") end
local tally, spentSkipped = {}, 0
for _, node in ipairs(CollectionService:GetTagged("WOLD_Node")) do
	if node:IsDescendantOf(workspace) and not node:GetAttribute("BornAt") then
		local cfg = GatherConfig.Nodes[node:GetAttribute("NodeKind")]
		local emoji = cfg and BY_TOOL[cfg.tool]
		if emoji then
			if node:GetAttribute("Spent") then spentSkipped += 1 else tally[emoji] = (tally[emoji] or 0) + 1 end
		end
	end
end
local bits = {}
for emoji, n in pairs(tally) do bits[#bits + 1] = emoji .. " x" .. n end
table.sort(bits)
assert(#bits > 0, "ต้องมีจุดเก็บเกี่ยวที่พร้อมอย่างน้อยหนึ่งแบบ")
table.insert(out, ("จุดเก็บเกี่ยวพร้อม: %s (ติดคูลดาวน์ %d จุด ป้ายต้องไม่ขึ้น)")
	:format(table.concat(bits, " "), spentSkipped))

----------------------------------------------------------------- 2. แปลงผัก: ธง Ripe
if (A("Count", player, "FarmPlot") or 0) < 1 then A("Grant", player, "FarmPlot", 1) end
local slot = assert(A("FindSlot", player, "FarmPlot"), "เสกแปลงไม่ได้")
local cx, cz
for x = -20, 20 do
	for z = -20, 20 do
		if A("CanPlaceAt", x, z, 2, 2, 0, "FarmPlot") then cx, cz = x, z break end
	end
	if cx then break end
end
assert(cx, "ไม่มีที่ว่างพอวางแปลง")
assert(A("Place", player, slot, cx, cz, 0))
local uid = A("Data").placed[#A("Data").placed].uid
local plot = assert(A("ModelOf", uid), "โมเดลแปลง")

A("Tick")
assert(plot:GetAttribute("Ripe") == nil, "แปลงว่างต้องไม่ติดธงสุก")
if (A("Count", player, C.SeedItem) or 0) < 1 then A("Grant", player, C.SeedItem, 1) end
assert(A("Plant", player, plot), "ปลูกไม่สำเร็จ")
A("Tick")
assert(plot:GetAttribute("Ripe") == nil, "เพิ่งปลูกต้องยังไม่สุก")
A("SetEntry", uid, "at", os.time() - 99999)
A("Tick")
assert(plot:GetAttribute("Ripe") == true, "สุกแล้วต้องติดธง Ripe ให้ป้าย " .. CFG.crop .. " ขึ้น")
table.insert(out, ("แปลงผัก: ว่าง/กำลังโต ไม่ติดธง · สุกแล้วติด Ripe → %s"):format(CFG.crop))

----------------------------------------------------------------- 3. สัตว์ในคอก: Grown + ไม่ Spent
local pen, penUid
for _, e in ipairs(A("Data").placed) do
	if e.id == C.PenItem then pen, penUid = A("ModelOf", e.uid), e.uid break end
end
if pen then
	local live = pen:FindFirstChild("Livestock")
	local grown, young = 0, 0
	for _, a in ipairs(live and live:GetChildren() or {}) do
		assert(a:GetAttribute("BornAt"), "สัตว์ต้องมี BornAt ให้ป้ายแยกออกจากหินได้")
		if a:GetAttribute("Grown") and not a:GetAttribute("Spent") then grown += 1 else young += 1 end
	end
	table.insert(out, ("คอกสัตว์: พร้อมเก็บ %d ตัว → %s · ยังไม่พร้อม %d ตัว")
		:format(grown, CFG.animal, young))
else
	table.insert(out, "คอกสัตว์: ไม่มีคอกบนเกาะ ข้ามข้อนี้")
end

----------------------------------------------------------------- 4. บอร์ดเควส: ธงรายคน
local boards = CollectionService:GetTagged("WOLD_QuestBoard")
assert(#boards > 0, "ต้องมีบอร์ดเควสบนเกาะ")

-- **สร้างเคสจริง ไม่ใช่แค่รายงานค่า** — ถือใบ "เก็บหิน 3 ก้อน" แล้วเสกหินให้ครบ ธงต้องพลิกเอง
local QT = game:GetService("ServerStorage"):WaitForChild("QuestTest", 20)
local function waitFlag(want)
	local t = os.clock()
	while os.clock() - t < 10 do
		if (player:GetAttribute("WOLD_QuestTurnIn") == true) == want then return true end
		task.wait(0.5)
	end
	return false
end

QT:Invoke("DropHeld", player, 0)
A("Revoke", player, "Stone", A("Count", player, "Stone") or 0)
assert(waitFlag(false), "ไม่มีงานถืออยู่ ธงต้องดับ")

QT:Invoke("AddHeld", player, { town = "MainGuild", kind = "gather", item = "Stone", need = 3, got = 0, day = 0 })
assert(waitFlag(false), "ถือใบแต่ของยังไม่ครบ ธงต้องยังดับ")
A("Grant", player, "Stone", 5)
assert(waitFlag(true), "ของครบแล้ว ธง WOLD_QuestTurnIn ต้องติด (ป้าย " .. CFG.quest .. " ขึ้นที่บอร์ด)")

QT:Invoke("DropHeld", player, 0)
A("Revoke", player, "Stone", A("Count", player, "Stone") or 0)
assert(waitFlag(false), "ทิ้งงานแล้วธงต้องดับตาม")
table.insert(out, ("บอร์ดเควส %d ป้าย · ไม่มีงาน→ดับ · ของไม่ครบ→ดับ · ครบ→ติด %s")
	:format(#boards, CFG.quest))

----------------------------------------------------------------- 5. ฟาร์มผิดกฎหมาย: คูลดาวน์ + สิทธิ์รายวัน
local farms = CollectionService:GetTagged("WOLD_Farm")
local ready, cooling = 0, 0
local now = workspace:GetServerTimeNow()
for _, node in ipairs(farms) do
	if node:IsDescendantOf(workspace) then
		local at = node:GetAttribute("FarmReadyAt")
		if not at or now >= at then ready += 1 else cooling += 1 end
	end
end
waited = os.clock()
while player:GetAttribute("WOLD_FarmDone") == nil and os.clock() - waited < 8 do task.wait(0.5) end
table.insert(out, ("ฟาร์มผิดกฎหมาย: พร้อม %d · คูลดาวน์ %d → %s · ใช้สิทธิ์วันนี้แล้ว: %s")
	:format(ready, cooling, CFG.farm, tostring(player:GetAttribute("WOLD_FarmDone") or "ยังไม่ใช้")))

----------------------------------------------------------------- เก็บของเทสคืน
A("SetEntry", uid, "crop", nil)
A("SetEntry", uid, "at", nil)
plot:SetAttribute("Ripe", nil)
assert(A("Pickup", player, uid), "เก็บแปลงที่เทสวางคืน")
A("Revoke", player, "FarmPlot", A("Count", player, "FarmPlot") or 0)
A("Revoke", player, C.SeedItem, A("Count", player, C.SeedItem) or 0)
A("NodeClear")
table.insert(out, "เก็บของเทสคืนครบ")
return table.concat(out, "\n")
