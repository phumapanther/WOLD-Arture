-- node tools/lua.js tests/mail_putown_test.lua Edit
-- Mail.PutOwn: ใส่จดหมายลงกล่องตัวเองตรงๆ (ตีบวกคืนอาวุธตอนกระเป๋าเต็ม) — ขั้นตีบวก/ความคงทนต้องรอดครบ
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end
local Mail = fresh(game.ServerScriptService.Mail)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local data = {}
local ok = Mail.PutOwn({}, data, { fromName = "ช่างตีเหล็ก", subject = "คืนอาวุธ",
	items = { { id = "Sword", count = 1, durability = 37, meta = { enhance = 7, skin = "Skin_Sword_Ember" } } } })
local letter = Mail.Box(data)[1]
check(ok == true and letter ~= nil, "ลงกล่องแล้ว")
check(letter and type(letter.id) == "string" and letter.claimed == false and letter.read == false, "มี id ยังไม่รับ ยังไม่อ่าน")
local item = letter and letter.items[1]
check(item and item.id == "Sword" and item.durability == 37, "ของ+ความคงทนครบ")
check(item and item.meta and item.meta.enhance == 7 and item.meta.skin == "Skin_Sword_Ember", "ขั้น +7 และสกินรอด")
check(Mail.HasAttachment(letter), "นับว่ามีของแนบ (กดรับได้)")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
