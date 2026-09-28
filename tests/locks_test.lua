-- node tools/lua.js tests/locks_test.lua Edit   (เพลสไหนก็ได้ — ข้อมูลล้วน)
-- ล็อกที่ผู้ใช้สั่ง 2026-09-28: แร็งก์ยังไม่เปิด · หน้าคราฟโชว์แต่ 🔒 (กับดัก+กระสุน โล่ ดาบใหญ่ สไน เรือ เรือเหาะ) ·
-- เลเวลฟาร์มตันที่ 20 ไปก่อน · ร้านสนามยังขายของเดิมครบ (ไม่ได้สั่งล็อก)
local RS = game.ReplicatedStorage
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end
local Craft = fresh(RS.CraftConfig)
local Rank = fresh(RS.PvpRankConfig)
local Farm = fresh(RS.FarmLevelConfig)
local Arena = fresh(RS.ArenaConfig)
local Catalog = fresh(RS.ItemCatalog)

local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

check(Rank.Enabled == false and Rank.LockedText == "แร็งก์ยังไม่เปิด", "แร็งก์ล็อก · ข้อความ \"แร็งก์ยังไม่เปิด\"")

local WANT = { "Trap", "TrapAmmo_Slow", "TrapAmmo_Stun", "TrapAmmo_Knock", "TrapAmmo_Blast",
	"Shield", "Greatsword", "Sniper", "BoatKey", "AirshipKey" }
for _, id in ipairs(WANT) do
	local shown, allClosed = 0, true
	for _, r in ipairs(Craft.Recipes) do
		if r.id == id then
			shown += 1
			if not Craft.IsClosed(r) then allClosed = false end
		end
	end
	check(shown > 0 and allClosed, ("%s โชว์ในหน้าคราฟ %d แถว · ล็อกทุกแถว"):format(id, shown))
end
local vehicleTab = {}
for _, r in ipairs(Craft.Recipes) do
	if r.tab == "vehicle" then vehicleTab[r.id] = true end
end
check(vehicleTab.BoatKey and vehicleTab.AirshipKey and vehicleTab.CarKey, "หน้าพาหนะมีรถ เรือ เรือเหาะ")
check(not Craft.IsClosed({ id = "CarKey" }) and not Craft.IsClosed({ id = "Sword" }) and not Craft.IsClosed({ id = "Pistol" }),
	"ของอื่นยังคราฟได้ (รถ ดาบ ปืน)")
local last = Craft.Recipes[#Craft.Recipes]
check(last.id == "AirshipKey" and Craft.Recipes[#Craft.Recipes - 1].id == "BoatKey", "สูตรเรือ/เรือเหาะต่อท้ายตาราง")
for _, r in ipairs(Craft.Recipes) do
	if r.id == "BoatKey" or r.id == "AirshipKey" then
		local ok = true
		for material in pairs(r.cost) do if not Catalog.Items[material] then ok = false end end
		check(ok, r.id .. " วัสดุมีจริงทุกชิ้น")
	end
end

check(Farm.Ceiling() == 20 and Farm.MaxLevel == 50, "ฟาร์มตัน Lv20 · ตารางยังยาว 50")
check(Farm.LevelFromExp(Farm.ExpForLevel(30)) == 20, "EXP ถึง Lv30 ก็ยังเป็น Lv20")

for _, id in ipairs({ "Shield", "Greatsword", "Sniper", "TrapSmall", "TrapMedium", "TrapLarge" }) do
	check(Arena.ShopEntry(id) ~= nil, "ร้านสนามยังขาย " .. id)
end

return ("%s — %d fail\n%s"):format(fails == 0 and "PASS" or "FAIL", fails, table.concat(out, "\n"))
