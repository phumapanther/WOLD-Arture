-- node tools/lua.js tests/sniper_config_test.lua Edit
-- ข้อมูลของสไน/แถบดีเลย์/ร้าน PVP ตามสเปก docs/superpowers/specs/2026-09-25-sniper-design.md
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
local ItemCatalog = fresh(RS.ItemCatalog)
local CombatConfig = fresh(RS.CombatConfig)
local CraftConfig = fresh(RS.CraftConfig)
local ArenaConfig = fresh(RS.ArenaConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local item = ItemCatalog.Items.Sniper
check(item and item.kind == "weapon" and item.icon ~= "", "ไอเทม Sniper เป็นอาวุธ มีไอคอน")
local w = CombatConfig.Weapons.Sniper
check(w and not w.quickDraw and w.scope and w.manaCost == 1, "สไน: คลิกแรกส่องสโคป คลิกสองยิง · มานา 1")
check(w and w.idleTimeout >= 15, "สไน: ส่องค้างได้นาน (ไม่หลุดสโคปเองใน 4 วิ)")
check(w and w.pierceFraction == 0.5 and w.mobDamage == 150, "สไน: คน 50% · มอน 150")
local a = w and w.attacks[1]
check(a and a.windup < 0.3 and a.projectile and a.projectile.kind == "hitscan", "สไน: คลิกสองยิงทันที (ไม่มีแถบ) hitscan")
check(CombatConfig.Sounds.Sniper and CombatConfig.Sounds.Sniper.cast == "rbxassetid://101482767943742", "เสียงยิงสไน")

local recipe
for _, r in ipairs(CraftConfig.Recipes or CraftConfig) do
	if type(r) == "table" and r.id == "Sniper" and r.tab == "weapon" then recipe = r end
end
check(recipe ~= nil, "สูตรคราฟสไนที่ช่างตีเหล็ก")
for id in pairs(recipe and recipe.cost or {}) do
	check(ItemCatalog.Items[id] ~= nil, "วัสดุ " .. id .. " มีจริง")
end

-- แถบดีเลย์: ท่าที่รอ >= 0.3 วิ เท่านั้น
check(CombatConfig.ChargeBarMinSeconds == 0.3, "เกณฑ์แถบ 0.3 วิ")
local function charged(id)
	return CombatConfig.Weapons[id].attacks[1].windup >= CombatConfig.ChargeBarMinSeconds
end
for _, id in ipairs({ "Greatsword", "Pistol", "Bow" }) do check(charged(id), id .. " มีแถบ") end
for _, id in ipairs({ "Sword", "Staff", "Spellbook", "Fists" }) do check(not charged(id), id .. " ไม่มีแถบ") end

-- ร้าน PVP
local sn, gs = ArenaConfig.ShopEntry("Sniper"), ArenaConfig.ShopEntry("Greatsword")
check(sn and sn.price == 3000 and sn.size == "large" and sn.row == "ranged" and sn.fillMana == true, "ร้าน: สไน 3,000 ใหญ่ มานาเต็ม")
check(gs and gs.price == 3000 and gs.size == "large", "ร้าน: ดาบใหญ่ 3,000 ใหญ่")
local sizes = { Sword = "small", Shield = "medium", Pistol = "small", Bow = "medium", Staff = "medium", Spellbook = "medium" }
for id, size in pairs(sizes) do
	check(ArenaConfig.ShopEntry(id).size == size, ("ร้าน: %s = %s"):format(id, size))
end
for _, e in ipairs(ArenaConfig.Shop) do
	if e.slot == "weapon" then check(ArenaConfig.SizeOrder[e.size] ~= nil, e.id .. " มีขนาด") end
end
check(ArenaConfig.HeadshotMultiplier and ArenaConfig.HeadshotMultiplier > 1, "ยิงหัวแรงกว่า")
check(ArenaConfig.MultiKillSeconds == 10 and ArenaConfig.KillSound == "rbxassetid://107279082816485", "คิลต่อเนื่อง 10 วิ + เสียงคิล")

local remotes = RS.Remotes.Source
check(remotes:find("\"RequestUnscope\"") and remotes:find("\"ArenaKillBanner\""), "remote ใหม่สองตัว (เลิกส่อง · แบนเนอร์คิล)")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
