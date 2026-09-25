-- node tools/lua.js tests/enhance_config_test.lua Edit
-- ตีบวก +1..+10 ตามสเปก docs/superpowers/specs/2026-09-24-enhance-design.md (ตัวเลขทั้งหมดผู้ใช้กำหนด)
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
local EnhanceConfig = fresh(RS.EnhanceConfig)
local ItemCatalog = fresh(RS.ItemCatalog)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end
local function near(a, b) return math.abs(a - b) < 1e-6 end

check(EnhanceConfig.MaxLevel == 10 and #EnhanceConfig.Levels == 10, "10 ขั้น")
local chances = { 1, 0.95, 0.90, 0.80, 0.70, 0.60, 0.50, 0.40, 0.30, 0.20 }
for n, c in ipairs(chances) do
	check(near(EnhanceConfig.Levels[n].chance, c), ("+%d โอกาส %d%%"):format(n, c * 100))
end
check(near(EnhanceConfig.Bonus(5), 0.15) and near(EnhanceConfig.Bonus(10), 0.55), "โบนัส +5 = 15% · +10 = 55%")
check(near(EnhanceConfig.Bonus(6), 0.23) and near(EnhanceConfig.Bonus(1), 0.03) and EnhanceConfig.Bonus(0) == 0, "โบนัส +1 = 3% · +6 = 23% · +0 = 0")
check(EnhanceConfig.Levels[1].cost.Silver == 1000 and EnhanceConfig.Levels[10].cost.Silver == 10000, "ซิลเวอร์ 1,000 → 10,000")
check(EnhanceConfig.Levels[10].cost.Diamond == 5 and EnhanceConfig.Levels[10].cost.Blueprint == 3, "+10 เพชร 5 แบบแปลน 3")
for n, level in ipairs(EnhanceConfig.Levels) do
	for id in pairs(level.cost) do
		check(ItemCatalog.Items[id] ~= nil, ("+%d วัสดุ %s มีจริง"):format(n, id))
	end
end
for _, id in ipairs({ "Sword", "Bow", "Staff", "Spellbook", "Greatsword", "Shield", "Pistol" }) do
	check(EnhanceConfig.Weapons[id] == true, id .. " ตีบวกได้")
end
for _, id in ipairs({ "Sniper", "Axe", "Pickaxe", "FishingRod", "Fists" }) do
	check(not EnhanceConfig.Weapons[id], id .. " ตีบวกไม่ได้")
end
check(near(EnhanceConfig.MultiplierFor({ id = "Sword", meta = { enhance = 6 } }), 1.23), "ดาบ +6 = ดาเมจ ×1.23")
check(EnhanceConfig.MultiplierFor({ id = "Sniper", meta = { enhance = 6 } }) == 1, "สไนไม่มีโบนัส")
check(EnhanceConfig.MultiplierFor(nil) == 1 and EnhanceConfig.MultiplierFor({ id = "Sword" }) == 1, "มือเปล่า/ไม่มีขั้น = ×1")
check(EnhanceConfig.LevelOf({ enhance = "x" }) == 0 and EnhanceConfig.LevelOf({ enhance = 99 }) == 10
	and EnhanceConfig.LevelOf(nil) == 0 and EnhanceConfig.LevelOf({ enhance = 0 / 0 }) == 0, "ขั้นค่าแปลก = 0 / เพดาน 10")
check(ItemCatalog.DisplayName("Sword", { enhance = 7 }) == "ดาบ +7", "ชื่อ \"ดาบ +7\" ได้: " .. ItemCatalog.DisplayName("Sword", { enhance = 7 }))
local withSkin = ItemCatalog.DisplayName("Sword", { enhance = 3, skin = "Skin_Sword_Ember" })
check(withSkin:find("^ดาบ %+3 %(") ~= nil, "ขั้นคู่สกิน: " .. withSkin)
check(EnhanceConfig.AnnounceFrom == 8, "ตีบวก +8 ขึ้นไป = ประกาศข้ามเซิร์ฟ")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
