-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_decor_test.lua Server
--
-- เทสของที่เพิ่มรอบ 2026-09-22: ของตกแต่งชิ้นเล็ก · เฟอร์นิเจอร์ใช้งานได้จริง · ฟาร์มเถื่อนบนเกาะ
-- ⚠️ โปรไฟล์จริง: เก็บทุกอย่างที่เทสวางคืนตอนจบ
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local ShopConfig = require(game.ReplicatedStorage.ShopConfig)
local PremiumConfig = require(game.ReplicatedStorage.PremiumConfig)

local T = assert(game:GetService("ServerStorage"):WaitForChild("IslandTest", 10), "ไม่มีช่องเทส")
local function A(op, ...) return T:Invoke(op, ...) end
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่น")
local out = {}

----------------------------------------------------------------- ราคา VIP
assert(PremiumConfig.Vip.price == 150, "VIP ต้อง 150 เพชร ได้ " .. PremiumConfig.Vip.price)
table.insert(out, ("VIP %d เพชร / %d วัน ✓"):format(PremiumConfig.Vip.price, PremiumConfig.Vip.days))

----------------------------------------------------------------- ต้นแบบครบและอยู่ในร้าน
local NEW = {
	"Deco_Rock", "Deco_RockBig", "Deco_Bush", "Deco_Stump", "Deco_Lantern", "Deco_Signpost", "Deco_Well",
	"Stove", "SteamBlender", "AlchemyStill", "IceBox", "ApothecaryCabinet",
	"DistillSet", "Reactor", "Boxs",
}
local protos = game.ReplicatedStorage:WaitForChild("WOLD_Placeables")
local inShop = {}
for _, row in ipairs(ShopConfig.IslandSells) do inShop[row.id] = row.price end
for _, id in ipairs(NEW) do
	assert(protos:FindFirstChild(id), "ไม่มีต้นแบบ " .. id)
	local item = ItemCatalog.Get(id)
	assert(item and item.kind == "placeable", id .. " ต้องเป็น placeable ใน ItemCatalog")
	assert(inShop[id], id .. " ต้องมีขายในร้านเกาะ")
	assert(item.spot, id .. " ต้องบอกว่าในบ้าน/นอกบ้าน")
end
table.insert(out, ("ของใหม่ %d ชิ้น: มีต้นแบบ + อยู่ในแคตตาล็อก + มีราคาในร้านครบ ✓"):format(#NEW))

----------------------------------------------------------------- ป้ายในบ้าน/นอกบ้าน
local inCount, outCount = 0, 0
for _, id in ipairs(NEW) do
	local spot = ItemCatalog.Get(id).spot
	if spot == "in" then inCount += 1 elseif spot == "out" then outCount += 1 end
end
assert(ItemCatalog.Get("Stove").spot == "in", "เตาต้องเป็นของในบ้าน")
assert(ItemCatalog.Get("Deco_Rock").spot == "out", "ก้อนหินต้องเป็นของนอกบ้าน")
table.insert(out, ("ป้ายบอกที่ตั้ง: ในบ้าน %d · นอกบ้าน %d · ได้ทั้งคู่ %d ✓")
	:format(inCount, outCount, #NEW - inCount - outCount))

----------------------------------------------------------------- วางเตาแล้วใช้งานได้จริง
-- หาช่องว่างเอง เกาะเปลี่ยนรูปได้
local G = require(game.ReplicatedStorage.IslandGrid)
-- **ถามด้วย itemId จริง** ไม่งั้นได้ช่องที่เป็นผืนดิน ซึ่งวางได้แต่แปลงผัก (เหตุ "onsoil")
-- และต้องจำช่องที่ใช้ไปแล้ว เพราะของชิ้นก่อนหน้ายังยืนอยู่ตอนหาช่องถัดไป
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

-- **กวาดของเทสที่ค้างจากรอบก่อนทิ้งก่อนเริ่ม** เทสที่พังกลางคันทิ้งของไว้ทั้งบนเกาะและในกระเป๋า
-- ซึ่งทำให้รอบถัดไปพังตั้งแต่ Grant (กระเป๋าเต็ม) แล้วไล่หาสาเหตุผิดทาง
do
	local stale = A("Data")
	for i = #stale.placed, 1, -1 do
		local e = stale.placed[i]
		for _, id in ipairs(NEW) do
			if e.id == id then A("Pickup", player, e.uid); A("Revoke", player, id) break end
		end
	end
	for _, id in ipairs(NEW) do A("Revoke", player, id) end
end

local before = #A("Data").placed
assert(A("Grant", player, "Stove", 1), "เสกเตา")
local slot = assert(A("FindSlot", player, "Stove"), "หาเตาในกระเป๋า")
local sx, sz = freeCell(2, 1, "Stove")
local ok, why = A("Place", player, slot, sx, sz, 0)
assert(ok, ("วางเตา: %s"):format(tostring(why)))
local stoveUid = A("Data").placed[#A("Data").placed].uid
local stove = assert(A("ModelOf", stoveUid), "หาโมเดลเตา")

-- ชื่อต้นแบบต้องรอดมาเป็นลูก ไม่งั้น CraftStations มองไม่เห็น
local inner = stove:FindFirstChild("Stove", true)
assert(inner, "โมเดลที่วางต้องมีลูกชื่อ Stove (CraftStations หาจากชื่อ)")
assert(inner:FindFirstChild("FireboxHearth", true), "เตาต้องมี FireboxHearth")
-- ปุ่มมาจาก CraftStations ซึ่งมีลูปถามใหม่
local prompt
local t0 = os.clock()
while os.clock() - t0 < 10 do
	for _, d in ipairs(stove:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Name ~= "PickupPrompt" then prompt = d end
	end
	if prompt then break end
	task.wait(0.5)
end
assert(prompt, "เตาที่วางต้องมีปุ่มทำอาหาร (CraftStations ใส่ให้)")
table.insert(out, ("เตาที่ซื้อมาวาง: ปุ่ม '%s' ขึ้นจริง ✓"):format(prompt.ActionText))

----------------------------------------------------------------- ตู้เย็น: แอตทริบิวต์ต้องตามไป
assert(A("Grant", player, "IceBox", 1), "เสกตู้เย็น")
local iceSlot = assert(A("FindSlot", player, "IceBox"))
local ix, iz = freeCell(1, 1, "IceBox")
ok, why = A("Place", player, iceSlot, ix, iz, 0)
assert(ok, ("วางตู้เย็น: %s"):format(tostring(why)))
local iceUid = A("Data").placed[#A("Data").placed].uid
local ice = assert(A("ModelOf", iceUid))
local iceInner = assert(ice:FindFirstChild("IceBox", true), "ต้องมีลูกชื่อ IceBox")
assert(iceInner:GetAttribute("StorageAccepts") == "food",
	"ตู้เย็นต้องรับเฉพาะอาหาร ได้ " .. tostring(iceInner:GetAttribute("StorageAccepts")))
table.insert(out, "ตู้เย็นที่วาง: StorageAccepts=food ตามไปด้วย ✓")

----------------------------------------------------------------- ฟาร์มเถื่อนบนเกาะ
assert(A("Grant", player, "Reactor", 1), "เสกเตาปฏิกรณ์")
local rSlot = assert(A("FindSlot", player, "Reactor"))
local rx, rz = freeCell(2, 2, "Reactor")
ok, why = A("Place", player, rSlot, rx, rz, 0)
assert(ok, ("วางเตาปฏิกรณ์: %s"):format(tostring(why)))
local rUid = A("Data").placed[#A("Data").placed].uid
local reactor = assert(A("ModelOf", rUid))
local rInner = assert(reactor:FindFirstChild("Reactor", true), "ต้องมีลูกชื่อ Reactor")
assert(CollectionService:HasTag(rInner, "WOLD_Farm"), "ต้องติดแท็ก WOLD_Farm ตอนวาง")
local fPrompt
t0 = os.clock()
while os.clock() - t0 < 10 do
	for _, d in ipairs(reactor:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Name ~= "PickupPrompt" then fPrompt = d end
	end
	if fPrompt then break end
	task.wait(0.5)
end
assert(fPrompt, "เตาปฏิกรณ์ต้องมีปุ่มฟาร์ม (IllegalFarm ใส่ให้ — ถ้าไม่มีแปลว่ายังถูกกันออกจากเกาะ)")
table.insert(out, ("ฟาร์มเถื่อนบนเกาะ: ปุ่ม '%s' ขึ้นจริง (วันละครั้งต่อจุด) ✓"):format(fPrompt.ActionText))

----------------------------------------------------------------- เวลาเดิน
local Lighting = game:GetService("Lighting")
local t1 = Lighting.ClockTime
task.wait(3)
local t2 = Lighting.ClockTime
assert(math.abs(t2 - t1) > 0.001, "เวลาต้องเดิน (DayNight.server)")
table.insert(out, ("เวลาบนเกาะเดินจริง: %.2f น. -> %.2f น. · กลางคืน=%s ✓")
	:format(t1, t2, tostring(workspace:GetAttribute("WOLD_IsNight"))))

----------------------------------------------------------------- เก็บคืน
--
-- **เก็บตามชนิด ไม่ใช่ตามจำนวนที่นับไว้ตอนต้น** ถ้ารอบก่อนพังกลางคัน ของจะค้างอยู่และ `before` ก็สูงตาม
-- ไปด้วย การเก็บ "เฉพาะที่เกินจาก before" จึงทิ้งของรอบก่อนไว้ตลอดกาล (เจอจริง 2026-09-22: ค้าง 5 ชิ้น)
--
-- และต้อง **ล้างกระเป๋าด้วย** ไม่งั้นรอบถัดไปเสกของไม่ได้เพราะกระเป๋าเต็มจากของที่ Grant มาทุกรอบ
local TESTY = {}
for _, id in ipairs(NEW) do TESTY[id] = true end
-- **คืนของออกจากกระเป๋าหลังเก็บทุกชิ้น** ของที่เก็บขึ้นมาไปกินช่องกระเป๋า พอเต็มแล้วชิ้นถัดไปจะเก็บ
-- ไม่ได้ (เหตุ "full") แล้วค้างอยู่บนเกาะ — ล้างทีเดียวตอนจบจึงช้าไปหนึ่งก้าวเสมอ
local d = A("Data")
for i = #d.placed, 1, -1 do
	local e = d.placed[i]
	if TESTY[e.id] then
		A("Pickup", player, e.uid)
		A("Revoke", player, e.id)
	end
end
local left = 0
for _, e in ipairs(A("Data").placed) do if TESTY[e.id] then left += 1 end end
assert(left == 0, ("ยังมีของเทสค้างบนเกาะ %d ชิ้น"):format(left))
table.insert(out, ("เก็บของเทสคืนครบ · เกาะเหลือ %d ชิ้น (ของผู้ใช้)"):format(#A("Data").placed))
return table.concat(out, "\n")
