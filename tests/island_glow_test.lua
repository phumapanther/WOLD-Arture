-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_glow_test.lua Server
--
-- ของเรืองแสง (ผู้ใช้สั่ง 2026-09-23): "แสงสีทอง EXP ×2 · แสงสีฟ้า วัตถุดิบ ×2"
-- และต้นเวทมนตร์ในแปลงผักที่ให้กิ่ง/แร่เวทมนตร์
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local T = game:GetService("ServerStorage"):WaitForChild("IslandTest", 20)
local function A(op, ...) return T:Invoke(op, ...) end
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่น")
local C = require(game.ReplicatedStorage.IslandConfig)
local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
local out = {}

local G = assert(C.Glow, "ไม่มี IslandConfig.Glow")

local t0 = os.clock()
while not A("Data") and os.clock() - t0 < 20 do task.wait(0.2) end
assert(A("Data"), "ข้อมูลเกาะไม่โหลด")

-- ⚠️ **อ่าน EXP ผ่านช่องเทส ไม่ใช่ `require(Progression)`** — sandbox ของ `execute_luau` คืนสำเนาใหม่
-- ที่ตาราง States ว่าง เลขที่ได้จึงเป็นศูนย์เสมอทั้งก่อนและหลัง (เสียเวลาไปหนึ่งรอบเพราะข้อนี้)
local function exp() return (A("Exp", player)) end

----------------------------------------------------------------- 1. การทอย
local tally = { gold = 0, blue = 0, none = 0 }
for _ = 1, 4000 do
	local t = C.RollGlow()
	tally[t or "none"] += 1
end
assert(tally.gold > 0 and tally.blue > 0, "ต้องทอยได้ทั้งสองสี")
local litRate = (tally.gold + tally.blue) / 4000
assert(math.abs(litRate - G.chance) < 0.03, ("อัตราเรืองแสงเพี้ยน: %.3f ควรราว %.2f"):format(litRate, G.chance))
table.insert(out, ("ทอย 4000 ครั้ง: ทอง %d · ฟ้า %d · ไม่ติด %d (อัตรา %.1f%% ตั้งไว้ %.0f%%)")
	:format(tally.gold, tally.blue, tally.none, litRate * 100, G.chance * 100))

----------------------------------------------------------------- เตรียมแปลง
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

local function plantAs(item, tone)
	if (A("Count", player, C.SeedItem) or 0) < 1 then A("Grant", player, C.SeedItem, 1) end
	assert(A("Plant", player, plot), "ปลูกไม่สำเร็จ")
	A("SetEntry", uid, "crop", item) -- บังคับชนิดแทนการทอย
	A("SetEntry", uid, "at", os.time() - 99999) -- สุกทันที
	A("SetEntry", uid, "glow", tone or false) -- แสงอยู่ในโปรไฟล์ (false = ทอยแล้วไม่ติด) · Tick คืนแอตทริบิวต์ให้
	A("Tick")
end

----------------------------------------------------------------- 2. ทอยแสงตอนสุก ไม่ใช่ตอนหยอด (ผู้ใช้สั่ง 2026-09-25)
local rolled = 0
for _ = 1, 60 do
	if (A("Count", player, C.SeedItem) or 0) < 1 then A("Grant", player, C.SeedItem, 1) end
	A("Plant", player, plot)
	assert(plot:GetAttribute("Glow") == nil, "หยอดเมล็ดแล้วต้องยังไม่มีแสง (แสงขึ้นตอนสุก)")
	A("SetEntry", uid, "at", os.time() - 99999)
	A("Tick")
	if plot:GetAttribute("Glow") then rolled += 1 end
	A("SetEntry", uid, "crop", nil)
	A("SetEntry", uid, "at", nil)
	A("SetEntry", uid, "glow", nil)
	plot:SetAttribute("Glow", nil)
end
assert(rolled > 0, "สุก 60 ครั้งต้องติดแสงอย่างน้อยหนึ่ง")
table.insert(out, ("สุก 60 ครั้ง → ติดแสง %d ครั้ง (หยอดเมล็ดไม่ทอย)"):format(rolled))

----------------------------------------------------------------- 3. แสงฟ้า: ผัก ×2
A("Revoke", player, "Wheat", A("Count", player, "Wheat") or 0)
local plain, lit = 0, 0
for _ = 1, 12 do
	plantAs("Wheat", nil)
	local before = A("Count", player, "Wheat") or 0
	assert(A("Harvest", player, plot))
	plain += (A("Count", player, "Wheat") or 0) - before
end
for _ = 1, 12 do
	plantAs("Wheat", "blue")
	local before = A("Count", player, "Wheat") or 0
	assert(A("Harvest", player, plot))
	lit += (A("Count", player, "Wheat") or 0) - before
end
assert(lit >= plain * 1.8, ("แสงฟ้าต้องได้ราวสองเท่า: ปกติ %d · เรืองแสง %d"):format(plain, lit))
assert(plot:GetAttribute("Glow") == nil, "เก็บแล้วธงต้องถูกล้าง")
table.insert(out, ("แสงฟ้า: ข้าว 12 รอบปกติ %d เมล็ด · 12 รอบเรืองแสง %d เมล็ด (×%.2f)")
	:format(plain, lit, lit / math.max(1, plain)))
A("Revoke", player, "Wheat", A("Count", player, "Wheat") or 0)

----------------------------------------------------------------- 4. แสงทอง: EXP ×2
plantAs("Wheat", nil)
local e0 = exp()
assert(A("Harvest", player, plot))
local gainPlain = exp() - e0
plantAs("Wheat", "gold")
e0 = exp()
assert(A("Harvest", player, plot))
local gainGold = exp() - e0
local _, level = A("Exp", player)
assert(gainPlain > 0,
	("แปลงผักต้องให้ EXP ฐาน ไม่งั้นแสงทองไปคูณศูนย์ (เลเวลตอนนี้ %s — ตันแล้วจะไม่ได้ EXP)"):format(tostring(level)))
assert(gainGold == gainPlain * G.exp, ("EXP ต้องเป็นสองเท่า: ปกติ %d · ทอง %d"):format(gainPlain, gainGold))
table.insert(out, ("แสงทอง: EXP ปกติ %d → เรืองแสง %d (×%d)"):format(gainPlain, gainGold, G.exp))
A("Revoke", player, "Wheat", A("Count", player, "Wheat") or 0)

----------------------------------------------------------------- 5. ต้นเวทมนตร์
local magic
for _, c in ipairs(C.Crops) do if c.item == "MagicBranch" then magic = c end end
assert(magic, "ต้องมีต้นเวทมนตร์ใน IslandConfig.Crops")
assert(magic.bonus and magic.bonus.item == "MagicOre", "ต้องมีของแถมเป็นแร่เวทมนตร์")
local protos = game.ReplicatedStorage:FindFirstChild("WOLD_Placeables")
assert(protos and protos:FindFirstChild("Crop_MagicBranch"), "ต้องมีโมเดล Crop_MagicBranch")

A("Revoke", player, "MagicBranch", A("Count", player, "MagicBranch") or 0)
A("Revoke", player, "MagicOre", A("Count", player, "MagicOre") or 0)
for _ = 1, 20 do
	plantAs("MagicBranch", nil)
	assert(A("Harvest", player, plot))
end
local branch = A("Count", player, "MagicBranch") or 0
local ore = A("Count", player, "MagicOre") or 0
assert(branch >= 20, ("เก็บ 20 ครั้งต้องได้กิ่งอย่างน้อย 20 ได้ %d"):format(branch))
assert(ore > 0, "ต้องได้แร่เวทมนตร์ติดมาบ้าง")
-- โมเดลจริงต้องถูกปลูกลงแปลง ไม่ใช่แค่ตัวเลข
plantAs("MagicBranch", nil)
local crop = plot:FindFirstChild("Crop")
assert(crop, "ต้องมีโมเดลพืชในแปลง")
table.insert(out, ("ต้นเวทมนตร์ (น้ำหนัก %d · %d นาที): 20 รอบได้กิ่ง %d · แร่ %d · โมเดล %d ชิ้น")
	:format(magic.weight, magic.seconds / 60, branch, ore, #crop:GetDescendants()))
assert(A("Harvest", player, plot))
A("Revoke", player, "MagicBranch", A("Count", player, "MagicBranch") or 0)
A("Revoke", player, "MagicOre", A("Count", player, "MagicOre") or 0)

----------------------------------------------------------------- 6. แร่เรืองแสง: ของ ×2
A("NodeClear")
for _ = 1, 30 do A("NodeSpawnOnce") end
-- ⚠️ **เลือกจากโฟลเดอร์ `Nodes` เท่านั้น** ไม่ใช่จากแท็กทั้งเกาะ — ของตกแต่งที่ผู้ใช้วางไว้ก็ติดแท็ก
-- เหมือนกัน และอาจติดคูลดาวน์รายวันอยู่ ทำให้เทสฟ้องว่า "เก็บไม่สำเร็จ" โดยที่ระบบถูกต้อง
local target
for _, node in ipairs(workspace.WOLD_Island.Nodes:GetChildren()) do
	local cfg = GatherConfig.Nodes[node:GetAttribute("NodeKind")]
	if cfg and cfg.tool == "pickaxe" and not node:GetAttribute("Spent") then
		target = node
		break
	end
end
assert(target, "ต้องมีจุดที่ใช้อีเต้อ")
if not A("FindSlot", player, "Pickaxe") then A("Grant", player, "Pickaxe", 1) end
A("Equip", player, assert(A("FindSlot", player, "Pickaxe")))

local cfg = GatherConfig.Nodes[target:GetAttribute("NodeKind")]
local possible = { [cfg.item] = true }
for _, e in ipairs(cfg.roll or {}) do possible[e.item] = true end
local function bagTotal()
	local n = 0
	for id in pairs(possible) do n += (A("Count", player, id) or 0) end
	return n
end
target:SetAttribute("Glow", "blue")
-- ตรึงจำนวนฐานไว้ ผลลัพธ์จะได้ไม่ปนกับการสุ่ม min/max
target:SetAttribute("YieldMin", 2)
target:SetAttribute("YieldMax", 2)
local before = bagTotal()
assert(A("Gather", player, target) == true, "เก็บไม่สำเร็จ")
local got = bagTotal() - before
assert(got >= 4, ("แสงฟ้าต้องได้ 4 ชิ้นจากฐาน 2 ได้ %d"):format(got))
table.insert(out, ("แร่เรืองแสงฟ้า: ฐานตรึงไว้ 2 ชิ้น → ได้ %d ชิ้น"):format(got))

----------------------------------------------------------------- เก็บของเทสคืน
A("Unequip", player, "weapon")
A("Revoke", player, "Pickaxe", A("Count", player, "Pickaxe") or 0)
for id in pairs(possible) do
	local n = A("Count", player, id) or 0
	if n > 0 then A("Revoke", player, id, n) end
end
A("NodeClear")
A("SetEntry", uid, "crop", nil)
A("SetEntry", uid, "at", nil)
assert(A("Pickup", player, uid), "เก็บแปลงที่เทสวางคืน")
A("Revoke", player, "FarmPlot", A("Count", player, "FarmPlot") or 0)
A("Revoke", player, C.SeedItem, A("Count", player, C.SeedItem) or 0)
table.insert(out, "เก็บของเทสคืนครบ")
return table.concat(out, "\n")
