-- node tools/lua.js tests/vault_take_test.lua Edit
-- บั๊กปั๊มของ (รีวิว 2026-09-25): เบิกของจากคลังตอนกระเป๋าเต็ม → AddItem ล้นกลับเข้าคลังผ่าน Overflow
-- แล้วคืน false → Take ไม่หักช่องเดิม = คลิกหนึ่งครั้งของเพิ่มหนึ่งชิ้น
-- กระเป๋าปลอมทำแบบเดียวกับของจริงเป๊ะ: เต็ม · AddItem ล้นเข้าคลัง (Vault.Deposit) แล้วคืน false
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
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local player = {} -- คลังใช้ตัวผู้เล่นเป็นแค่กุญแจตาราง
local fullBag = {
	HasRoomFor = function() return false end,
	AddItem = function(p, id, count, durability, meta)
		Vault.Deposit(p, id, count, durability, meta) -- ล้นเข้าคลังแบบที่ Inventory.Overflow ทำ
		return false
	end,
}
local function total(id)
	local n = 0
	for _, slot in pairs(Vault.Get(player).slots) do
		if slot and slot.id == id then n += slot.count or 1 end
	end
	return n
end

Vault.Add(player, nil)
Vault.Deposit(player, "Stone", 5)
Vault.Deposit(player, "Sword", 1, 50, { enhance = 7 })
for _ = 1, 3 do Vault.Take(player, fullBag, 1, 1) end
check(total("Stone") == 5, ("หินในคลังยัง 5 ไม่งอก (ได้ %d)"):format(total("Stone")))
local swordIndex
for index, slot in pairs(Vault.Get(player).slots) do
	if slot and slot.id == "Sword" then swordIndex = index end
end
local ok = Vault.Take(player, fullBag, swordIndex)
check(ok == false and total("Sword") == 1, ("ดาบ +7 ไม่งอก (ได้ %d)"):format(total("Sword")))
Vault.Remove(player)

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
