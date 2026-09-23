-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_wild_test.lua Server
--
-- ของป่าจากเกมหลัก (ผู้ใช้สั่ง 2026-09-23): "เอามาทำขายเป็นของตกแต่งที่วางได้และเก็บได้แบบหินและ
-- พุ่มไม้และต้นไม้แบบของอันอื่นด้วย ที่เก็บแล้วต้องรอวันใหม่ถึงจะเก็บได้อีก"
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local T = game:GetService("ServerStorage"):WaitForChild("IslandTest", 20)
local function A(op, ...) return T:Invoke(op, ...) end
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่น")
local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local ShopConfig = require(game.ReplicatedStorage.ShopConfig)
local QuestConfig = require(game.ReplicatedStorage.QuestConfig)
local out = {}

local ID, KIND = "Wild_Rock", "Rock"

----------------------------------------------------------------- ของอยู่ครบสามที่: แคตตาล็อก ร้าน ต้นแบบ
local protos = game.ReplicatedStorage:WaitForChild("WOLD_Placeables", 10)
local missing = {}
-- `Wild_Pine` เป็นต้นไม้ แต่ชื่อไม่ตรงกับ NodeKind — ต้องบอกคู่ไว้ตรงนี้ด้วย
local WILD = {
	Wild_Rock = "Rock", Wild_Herb = "Herb", Wild_Tree = "Tree", Wild_Pine = "Tree",
	Wild_Coal = "Coal", Wild_IronOre = "IronOre", Wild_SilverOre = "SilverOre",
	Wild_Crystal = "Crystal", Wild_GoldOre = "GoldOre", Wild_MagicOre = "MagicOre",
	Wild_DiamondOre = "DiamondOre",
}
local variants = {}
for id, kind in pairs(WILD) do
	if not ItemCatalog.Get(id) then missing[#missing + 1] = id .. "(แคตตาล็อก)" end
	if not protos:FindFirstChild(id) then missing[#missing + 1] = id .. "(ต้นแบบ)" end
	if not GatherConfig.Nodes[kind] then missing[#missing + 1] = id .. "(NodeKind)" end
	local sold = false
	for _, row in ipairs(ShopConfig.IslandSells) do if row.id == id then sold = true end end
	if not sold then missing[#missing + 1] = id .. "(ร้าน)" end

	-- แบบสำรอง: `<id>__2`, `__3` ... (ผู้ใช้สั่ง 2026-09-23 ให้ขายทุกแบบที่สุ่มเกิดบนผืนดิน)
	local n = 1
	while protos:FindFirstChild(id .. "__" .. (n + 1)) do n += 1 end
	variants[id] = n
end
assert(#missing == 0, "ขาด: " .. table.concat(missing, " "))
assert(variants.Wild_Tree > 1 and variants.Wild_Herb > 1 and variants.Wild_Rock > 1,
	"ต้นไม้/พุ่ม/หิน ต้องมีหลายแบบให้สุ่ม")
table.insert(out, ("ของป่า 11 ชนิดครบทุกที่ · หลายแบบ: ต้นโอ๊ก %d · ต้นสน %d · พุ่ม %d · หิน %d")
	:format(variants.Wild_Tree, variants.Wild_Pine, variants.Wild_Herb, variants.Wild_Rock))

----------------------------------------------------------------- วางแล้วต้องเป็นจุดเก็บเกี่ยวรายวัน
if (A("Count", player, ID) or 0) < 1 then A("Grant", player, ID, 1) end
local slot = assert(A("FindSlot", player, ID), "เสกของไม่ได้")
local cx, cz
for x = -20, 20 do
	for z = -20, 20 do
		if A("CanPlaceAt", x, z, 2, 2, 0, ID) then cx, cz = x, z break end
	end
	if cx then break end
end
assert(cx, "ไม่มีที่ว่าง")
assert(A("Place", player, slot, cx, cz, 0))
local uid = A("Data").placed[#A("Data").placed].uid
local model = assert(A("ModelOf", uid), "โมเดล")
local function entry()
	for _, e in ipairs(A("Data").placed) do if e.uid == uid then return e end end
end

assert(model:GetAttribute("NodeKind") == KIND, "NodeKind ต้องเป็น " .. KIND)
assert(model:GetAttribute("DailyNode") == true, "ต้องติดธงรายวัน")
assert(model:GetAttribute("NoFade") == true, "ของตกแต่งต้องไม่จางค้างทั้งวัน")
assert(model:GetAttribute("RespawnSeconds") == nil, "รายวันต้องไม่ใช้คูลดาวน์ 30 นาทีของตกแต่งธรรมดา")
assert(CollectionService:HasTag(model, "WOLD_Node"), "ต้องติดแท็กให้ Gathering เห็น")
table.insert(out, ("วาง %s ที่ (%d,%d) → NodeKind=%s รายวัน ไม่จาง"):format(ID, cx, cz, KIND))

----------------------------------------------------------------- เก็บได้ด้วยอุปกรณ์เดียวกับเกมหลัก
local cfg = GatherConfig.Nodes[KIND]
local possible = { [cfg.item] = true }
for _, e in ipairs(cfg.roll or {}) do possible[e.item] = true end
local function bagTotal()
	local n = 0
	for id in pairs(possible) do n += (A("Count", player, id) or 0) end
	return n
end
if not A("FindSlot", player, "Pickaxe") then A("Grant", player, "Pickaxe", 1) end
A("Equip", player, assert(A("FindSlot", player, "Pickaxe"), "เสกอีเต้อไม่ได้"))

-- **จุดที่เก็บไปเมื่อวาน ต้องไม่ถูกล็อก** — นี่คือสภาพที่เซิร์ฟเวอร์เห็นตอนบูตใหม่ (ตราวันอยู่ในโปรไฟล์
-- แต่คูลดาวน์ในหน่วยความจำตายไปกับเซิร์ฟเก่า) · ตั้งก่อนเก็บ จะได้ไม่ปนกับคูลดาวน์ของรอบนี้
local today = QuestConfig.DayNumber()
model:SetAttribute("HarvestedDay", today - 1)
task.wait() -- สัญญาณแอตทริบิวต์ของ Roblox เป็น deferred: ค่าลงโปรไฟล์ในเฟรมถัดไป ไม่ใช่ทันที
assert(entry().day == today - 1, "โปรไฟล์ต้องตามวันบนโหนด")

local before = bagTotal()
assert(A("Gather", player, model) == true, "ตราของเมื่อวานต้องไม่ล็อก เก็บได้เลย")
local gained = bagTotal() - before
assert(gained > 0, "ต้องได้ของเข้ากระเป๋า")
assert(model.Parent ~= nil, "ของตกแต่งต้องยังอยู่ ไม่ใช่หายไปแบบจุดที่สุ่มโผล่")

----------------------------------------------------------------- เก็บแล้วต้องรอวันใหม่ และรอดข้ามรีสตาร์ท
assert(model:GetAttribute("HarvestedDay") == today, "ต้องปั๊มวันที่เก็บไว้บนตัวโหนด")
task.wait()
assert(entry().day == today, "**และต้องลงโปรไฟล์ด้วย** ไม่งั้นออก-เข้าเกมใหม่ก็เก็บได้อีกรอบ")
assert(A("Gather", player, model) ~= true, "วันเดียวกันต้องเก็บซ้ำไม่ได้")
table.insert(out, ("ตราเมื่อวานไม่ล็อก → เก็บได้ %d ชิ้น → ล็อกถึงวันใหม่ (จดวัน %d ทั้งบนโหนดและในโปรไฟล์)"):format(gained, today))

----------------------------------------------------------------- เก็บไปแล้ววันนี้ ย้ายไม่ได้
local canPick, why = A("Pickup", player, uid)
assert(not canPick and why == "harvestedtoday", "ต้องห้ามย้าย ได้ " .. tostring(why))
table.insert(out, "เก็บเกี่ยวแล้ววันนี้ → เก็บคืนกระเป๋าไม่ได้ (กันวางใหม่แล้วเก็บรัวๆ)")

----------------------------------------------------------------- ของตกแต่งชุดเดิมก็รายวันแล้ว
-- ผู้ใช้แจ้ง 2026-09-23: "หิน พุ่มไม้ ตอไม้ พอออกเชิฟเข้าใหม่ มันรีแล้วเก็บได้อีกครั้ง"
-- เดิมใช้คูลดาวน์ 30 นาทีที่อยู่ในหน่วยความจำเซิร์ฟเวอร์ — เกาะปิดตามเจ้าของ ออกแล้วเข้าใหม่จึงรีเซ็ตเสมอ
for _, id in ipairs({ "Deco_Rock", "Deco_Bush", "Deco_Stump" }) do
	if (A("Count", player, id) or 0) < 1 then A("Grant", player, id, 1) end
	local s2 = assert(A("FindSlot", player, id), "เสก " .. id .. " ไม่ได้")
	local dx, dz
	for x = -20, 20 do
		for z = -20, 20 do
			if A("CanPlaceAt", x, z, 2, 2, 0, id) then dx, dz = x, z break end
		end
		if dx then break end
	end
	assert(dx, "ไม่มีที่ว่างพอวาง " .. id)
	assert(A("Place", player, s2, dx, dz, 0))
	local u = A("Data").placed[#A("Data").placed].uid
	local m = assert(A("ModelOf", u), "โมเดล " .. id)
	assert(m:GetAttribute("DailyNode") == true, id .. " ต้องเป็นจุดรายวัน")
	assert(m:GetAttribute("RespawnSeconds") == nil, id .. " ต้องไม่ใช้คูลดาวน์ 30 นาทีแล้ว")
	assert(A("Pickup", player, u), "เก็บ " .. id .. " คืน")
	A("Revoke", player, id, A("Count", player, id) or 0)
end
table.insert(out, "ของตกแต่งเดิม (หิน พุ่ม ตอไม้) เป็นจุดรายวันแล้ว — ตราวันอยู่ในโปรไฟล์ รอดข้ามรีสตาร์ท")

----------------------------------------------------------------- เก็บของเทสคืน
model:SetAttribute("HarvestedDay", nil)
assert(A("Pickup", player, uid), "วันที่ยังไม่ได้เก็บ ต้องย้ายได้")
A("Revoke", player, ID, A("Count", player, ID) or 0)
A("Revoke", player, "Pickaxe", A("Count", player, "Pickaxe") or 0)
for id in pairs(possible) do
	local n = A("Count", player, id) or 0
	if n > 0 then A("Revoke", player, id, n) end
end
table.insert(out, "เก็บของเทสคืนครบ")
return table.concat(out, "\n")
