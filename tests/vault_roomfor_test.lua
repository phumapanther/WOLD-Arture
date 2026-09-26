-- node tools/lua.js tests/vault_roomfor_test.lua Edit
-- QA 2026-09-26: Inventory.AddItem เป็น "ทั้งหมดหรือไม่เอาเลย" โดยถาม Vault.RoomFor ก่อนส่งส่วนเกินเข้าคลัง
-- ถ้า RoomFor ตอบไม่ตรงกับที่ Deposit ลงได้จริง การให้ของจะกลับมาเป็น "ได้ครึ่งเดียว" = ปั๊มของอีก
-- เทสนี้ตรึงว่า RoomFor == (Deposit ลงครบไหม) ทุกกรณี: คลังว่าง · กองเติม · เต็มพอดี · เกินหนึ่งชิ้น · ของมี meta
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local Vault = fresh(game.ServerScriptService.Vault)
local ItemCatalog = fresh(game.ReplicatedStorage.ItemCatalog)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local stack = ItemCatalog.StackSize("Stone")

-- สร้างคลังใหม่ที่เหลือที่ว่าง `freeSlots` ช่อง (ที่เหลืออัดด้วยดาบ) และมีหิน `partial` ก้อนในช่องแรก
local function vaultWith(freeSlots, partial)
	local player = {}
	Vault.Add(player, nil)
	local fill = Vault.SlotCount - freeSlots - (partial > 0 and 1 or 0)
	for _ = 1, fill do Vault.Deposit(player, "Sword", 1, 50, { enhance = 1 }) end
	if partial > 0 then Vault.Deposit(player, "Stone", partial) end
	return player
end

-- RoomFor ต้องตอบเหมือนกับที่ Deposit ลงได้จริงเป๊ะ (ลองบนสำเนาแยก ไม่ให้ RoomFor ไปแตะคลังที่ถาม)
local function agrees(freeSlots, partial, id, count, meta, label)
	local asked = vaultWith(freeSlots, partial)
	local said = Vault.RoomFor(asked, id, count, meta)
	local tried = vaultWith(freeSlots, partial)
	local placed = Vault.Deposit(tried, id, count, 50, meta)
	check(said == (placed >= count), ("%s: RoomFor=%s · Deposit ลง %d/%d"):format(label, tostring(said), placed, count))
	Vault.Remove(asked)
	Vault.Remove(tried)
end

agrees(Vault.SlotCount, 0, "Stone", stack * 3, nil, "คลังว่าง 3 กอง")
agrees(0, 0, "Stone", 1, nil, "คลังเต็ม ไม่มีกองให้เติม")
agrees(0, stack - 5, "Stone", 5, nil, "คลังเต็มแต่เติมกองเดิมได้พอดี 5")
agrees(0, stack - 5, "Stone", 6, nil, "คลังเต็ม เติมกองได้ 5 ขอ 6")
agrees(2, 0, "Stone", stack * 2, nil, "ว่าง 2 ช่อง ขอ 2 กองพอดี")
agrees(2, 0, "Stone", stack * 2 + 1, nil, "ว่าง 2 ช่อง ขอเกิน 1")
agrees(1, 0, "Sword", 1, { enhance = 5 }, "ของมี meta ว่าง 1 ช่อง")
agrees(0, stack - 5, "Sword", 1, { enhance = 5 }, "ของมี meta ไม่เติมกองของคนอื่น")

-- ถามแล้วต้องไม่แตะของ
local player = vaultWith(3, 10)
local before = 0
for _, slot in pairs(Vault.Get(player).slots) do before += (slot and slot.count or 0) end
Vault.RoomFor(player, "Stone", 50)
local after = 0
for _, slot in pairs(Vault.Get(player).slots) do after += (slot and slot.count or 0) end
check(before == after, "RoomFor ไม่แตะของในคลัง")
check(Vault.RoomFor({}, "Stone", 1) == false, "ผู้เล่นที่ไม่มีคลัง = ไม่มีที่")
Vault.Remove(player)

out[#out + 1] = fails == 0 and ("ผ่านทั้งหมด %d ข้อ"):format(#out) or ("ตก %d ข้อ"):format(fails)
return table.concat(out, "\n")
