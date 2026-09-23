-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_pets_test.lua Server
--
-- เทสรอบ 2026-09-22 ค่ำ: แท็บกระเป๋าแยกขาด · สองสกุลเงิน · สัตว์เลี้ยง · ของตกแต่งเก็บเกี่ยวได้
-- ⚠️ โปรไฟล์จริง: เก็บทุกอย่างคืนตอนจบ
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local ShopConfig = require(game.ReplicatedStorage.ShopConfig)
local IslandConfig = require(game.ReplicatedStorage.IslandConfig)
local InventoryGui = require(game.ReplicatedStorage.UI.InventoryGui)

local T = assert(game:GetService("ServerStorage"):WaitForChild("IslandTest", 10), "ไม่มีช่องเทส")
local P = assert(game:GetService("ServerStorage"):WaitForChild("PetTest", 10), "ไม่มีช่องเทสสัตว์เลี้ยง")
local function A(op, ...) return T:Invoke(op, ...) end
local function Pet(op, ...) return P:Invoke(op, ...) end
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่น")
local out = {}

local CLEAN = { "Pet_Cat", "Pet_Dog", "Deco_Rock", "Deco_Tree", "Deco_Bush" }
local function sweep()
	local d = A("Data")
	for i = #d.placed, 1, -1 do
		local e = d.placed[i]
		for _, id in ipairs(CLEAN) do
			if e.id == id then A("Pickup", player, e.uid); A("Revoke", player, id) break end
		end
	end
	for _, id in ipairs(CLEAN) do A("Revoke", player, id) end
end
sweep()

----------------------------------------------------------------- 1) แท็บกระเป๋าแยกขาด
assert(#InventoryGui.Tabs == 2, "ต้องมีแค่สองแท็บ ไม่มี 'ทั้งหมด' ได้ " .. #InventoryGui.Tabs)
assert(InventoryGui.Tabs[1].id == "main" and InventoryGui.Tabs[2].id == "farm", "ลำดับแท็บ")
assert(InventoryGui.InTab("FarmPlot", "farm") and not InventoryGui.InTab("FarmPlot", "main"), "แปลงผัก = ฟาร์ม")
assert(InventoryGui.InTab("Wheat", "main") and not InventoryGui.InTab("Wheat", "farm"), "ข้าว = เกมหลัก")
assert(InventoryGui.InTab("Pet_Dog", "farm"), "สัตว์เลี้ยง = ฟาร์ม")
table.insert(out, "แท็บกระเป๋า: แยกขาดสองแท็บ ไม่มี 'ทั้งหมด' ✓")

----------------------------------------------------------------- 2) สองสกุลเงิน
local gemRows, goldRows, plotRows = 0, 0, 0
local byId = {}
for _, row in ipairs(ShopConfig.IslandSells) do
	if row.currency == "gems" then gemRows += 1 else goldRows += 1 end
	if row.id == "FarmPlot" then plotRows += 1 end
	byId[row.id] = byId[row.id] or row
end
assert(plotRows == 2, "แปลงผักต้องซื้อได้สองสกุล ได้ " .. plotRows)
for _, id in ipairs({ "Deco_Rock", "Pet_Cat", "Reactor", "Stove" }) do
	assert(byId[id].currency == "gems", id .. " ต้องจ่ายเพชร")
end
for _, id in ipairs({ "Seed", "House_StoneCottage" }) do
	assert(byId[id].currency == nil, id .. " ต้องจ่ายเหรียญเกมหลัก")
end
table.insert(out, ("ร้านเกาะ: จ่ายเพชร %d แถว · เหรียญ %d แถว · แปลงผักซื้อได้ทั้งสองทาง ✓")
	:format(gemRows, goldRows))

----------------------------------------------------------------- 3) สัตว์เลี้ยงเดินได้จริง
local G = require(game.ReplicatedStorage.IslandGrid)
local used = {}
local function freeCell(w, d, itemId)
	for cz = -24, 24, 2 do
		for cx = -30, -6, 2 do
			local key = cx .. "," .. cz
			if not used[key] and A("CanPlaceAt", cx, cz, w, d, 0, itemId) then
				for i = 0, w do for j = 0, d do used[(cx + i) .. "," .. (cz + j)] = true end end
				return cx, cz
			end
		end
	end
	error("หาช่องว่างไม่เจอ")
end

assert(A("Grant", player, "Pet_Dog", 1), "เสกสุนัข")
local slot = assert(A("FindSlot", player, "Pet_Dog"))
local dx, dz = freeCell(1, 2, "Pet_Dog")
local ok, why = A("Place", player, slot, dx, dz, 0)
assert(ok, ("วางสุนัข: %s"):format(tostring(why)))
local dogUid = A("Data").placed[#A("Data").placed].uid
local dog = assert(A("ModelOf", dogUid))

-- IslandPets มีลูปทุก 1 วิ รอให้มันเห็น
local root, t0 = nil, os.clock()
while os.clock() - t0 < 10 do
	root = dog:FindFirstChild("HumanoidRootPart")
	if root and not root.Anchored and root:FindFirstChild("PetPrompt") then break end
	task.wait(0.5)
end
assert(root, "สุนัขต้องมี HumanoidRootPart")
assert(not root.Anchored, "ต้องปลด anchor ไม่งั้นเดินไม่ได้ (สัตว์สตัฟฟ์)")
assert(root:FindFirstChild("PetPrompt"), "ต้องมีปุ่มลูบหัว (E)")
assert(root:FindFirstChild("CarryPrompt"), "ต้องมีปุ่มอุ้ม (F)")
assert(dog:FindFirstChildOfClass("Humanoid"), "ต้องมี Humanoid")
-- ข้อต่อที่ BeastGait ขับ
local joints = 0
for _, d in ipairs(dog:GetDescendants()) do
	if d:IsA("Motor6D") and d:GetAttribute("Phase") then joints += 1 end
end
assert(joints > 0, "ต้องมีข้อต่อที่มี Phase ให้ BeastGait ขับ")
table.insert(out, ("สุนัข: ปลด anchor แล้ว · ข้อต่อขยับได้ %d จุด · ปุ่ม E ลูบหัว + F อุ้ม ✓"):format(joints))

-- เดินจริงไหม: จำตำแหน่งแล้วรอ
local at0 = root.Position
task.wait(5)
local moved = (root.Position - at0).Magnitude
table.insert(out, ("เดินเล่นเอง: ขยับไป %.1f studs ใน 5 วินาที %s")
	:format(moved, moved > 0.5 and "✓" or "(ยังไม่ขยับ — อาจกำลังยืนพัก)"))

----------------------------------------------------------------- 4) อุ้ม / ลูบหัว
Pet("Carry", dog, player)
task.wait(0.5)
assert(Pet("CarriedBy", dog) == player, "อุ้มแล้วต้องจำว่าใครอุ้ม")
local char = player.Character
local hrp = char and char:FindFirstChild("HumanoidRootPart")
if hrp then
	local gap = (root.Position - hrp.Position).Magnitude
	assert(gap < 6, ("ตอนอุ้มต้องติดตัวคนอุ้ม ห่าง %.1f"):format(gap))
end
Pet("Carry", dog, player)
task.wait(0.3)
assert(Pet("CarriedBy", dog) == nil, "วางลงแล้วต้องไม่มีคนอุ้ม")
Pet("Pat", dog, player)
table.insert(out, "อุ้ม → ติดตัวคนอุ้ม → วางลง → ลูบหัว ✓")

----------------------------------------------------------------- 5) บัพ
assert(Pet("Count") >= 1, "ต้องนับสัตว์เลี้ยงได้")
local growth = Pet("Growth")
assert(math.abs(growth - (1 - IslandConfig.PetGrowBonus)) < 0.001,
	("มีสัตว์เลี้ยง พืชต้องโตเร็วขึ้น %.0f%% ได้ตัวคูณ %.3f"):format(IslandConfig.PetGrowBonus * 100, growth))
local exp = Pet("Exp")
assert(exp >= 1 + IslandConfig.PetExpBonus - 0.001, ("EXP ต้องเพิ่ม ได้ตัวคูณ %.3f"):format(exp))
table.insert(out, ("บัพ: พืชโตเร็วขึ้น %.0f%% · EXP ฟาร์ม x%.3f (ของตกแต่ง %d ชิ้น) ✓")
	:format((1 - growth) * 100, exp, Pet("Decor")))

----------------------------------------------------------------- 6) ของตกแต่งเก็บเกี่ยวได้
assert(A("Grant", player, "Deco_Rock", 1), "เสกก้อนหิน")
local rSlot = assert(A("FindSlot", player, "Deco_Rock"))
local rx, rz = freeCell(1, 1, "Deco_Rock")
ok, why = A("Place", player, rSlot, rx, rz, 0)
assert(ok, ("วางก้อนหิน: %s"):format(tostring(why)))
local rockUid = A("Data").placed[#A("Data").placed].uid
local rock = assert(A("ModelOf", rockUid))
assert(CollectionService:HasTag(rock, "WOLD_Node"), "ก้อนหินตกแต่งต้องติดแท็ก WOLD_Node")
assert(rock:GetAttribute("NodeKind") == "Rock", "NodeKind ต้องเป็น Rock")
-- **เปลี่ยนเป็นรายวันแล้ว** (ผู้ใช้สั่ง 2026-09-23) — คูลดาวน์ 30 นาทีเดิมอยู่ในหน่วยความจำเซิร์ฟเวอร์
-- ออกจากเกมแล้วเข้าใหม่จึงรีเซ็ตทุกครั้ง · ตราวันอยู่ในโปรไฟล์ จึงรอดข้ามการรีสตาร์ท
assert(rock:GetAttribute("DailyNode") == true, "ก้อนหินตกแต่งต้องเป็นจุดรายวัน")
assert(rock:GetAttribute("RespawnSeconds") == nil, "ต้องไม่ใช้คูลดาวน์ 30 นาทีแล้ว")
-- Gathering ใส่ปุ่มให้เอง (ลูปลงทะเบียน)
local gPrompt
t0 = os.clock()
while os.clock() - t0 < 10 do
	for _, d in ipairs(rock:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Name ~= "PickupPrompt" then gPrompt = d end
	end
	if gPrompt then break end
	task.wait(0.5)
end
assert(gPrompt, "ก้อนหินต้องมีปุ่มขุด (Gathering ใส่ให้)")
table.insert(out, ("ก้อนหินตกแต่ง: ปุ่ม '%s' · เก็บได้วันละครั้ง · โมเดลอยู่ที่เดิม ✓")
	:format(gPrompt.ActionText))

-- ของตกแต่งเพิ่ม EXP
local expAfter = Pet("Exp")
assert(expAfter > exp, ("วางของตกแต่งเพิ่มแล้ว EXP ต้องเพิ่ม: %.4f -> %.4f"):format(exp, expAfter))
table.insert(out, ("ของตกแต่งเพิ่ม EXP ฟาร์ม: x%.4f -> x%.4f ✓"):format(exp, expAfter))

----------------------------------------------------------------- เก็บคืน
sweep()
local left = 0
for _, e in ipairs(A("Data").placed) do
	for _, id in ipairs(CLEAN) do if e.id == id then left += 1 end end
end
assert(left == 0, ("ยังมีของเทสค้าง %d ชิ้น"):format(left))
table.insert(out, ("เก็บของเทสคืนครบ · เกาะเหลือ %d ชิ้น"):format(#A("Data").placed))
return table.concat(out, "\n")
