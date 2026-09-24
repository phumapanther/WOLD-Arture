-- node tools/lua.js tests/mail_config_test.lua Edit
--
-- กฎ "ของชิ้นนี้ส่งทางเมลได้ไหม" ตามที่ผู้ใช้กำหนด 2026-09-24 (ดู docs/superpowers/specs/2026-09-24-mail-design.md)
-- ส่งได้ = วัตถุดิบ · ส่งไม่ได้ = ผิดกฎหมาย / กดใช้ได้ / คราฟได้ / Insignia / Silver / ของประจำตำแหน่ง / กุญแจ
--
-- โคลนโมดูลก่อน require: Edit mode แคช require ข้ามการรัน แก้ไฟล์แล้วจะได้ของเก่า
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local RS = game.ReplicatedStorage
local MailConfig = fresh(RS.MailConfig)
local ItemCatalog = fresh(RS.ItemCatalog)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

check(MailConfig.Fee == 500 and MailConfig.FeeItem == "Silver", "ค่าส่ง 500 ซิลเวอร์")
check(MailConfig.BoxSize == 50, "กล่องจุ 50")

for _, id in ipairs({ "Stone", "IronOre", "Coal", "Herb", "Axe" }) do
	check(ItemCatalog.IsMailable(id) == true, id .. " ส่งได้")
end
for _, id in ipairs({ "HealthPotion", "Bread", "Chest_Gold", "Greatsword", "Sword", "Chemical", "GearSpare",
	"Blueprint", "Silver", "Insignia", "CarKey", "Spatula", "ClanRing", "ไม่มีจริง" }) do
	check(ItemCatalog.IsMailable(id) == false, id .. " ส่งไม่ได้")
end

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
