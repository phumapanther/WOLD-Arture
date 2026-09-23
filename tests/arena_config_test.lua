-- node tools/lua.js tests/arena_config_test.lua Edit
--
-- ตรวจตัวเลขของโหมด PVP ว่ายังตรงกับสเปกที่ผู้ใช้เขียนไว้ 2026-09-23 — **รันได้ในเพลสไหนก็ได้**
-- เพราะทุกอย่างที่ตรวจอยู่ใน ReplicatedStorage ซึ่งทั้งสามเพลสใช้ชุดเดียวกัน (ไม่ต้องรอเพลสสนาม)
--
-- เทสนี้ไม่ได้ตรวจว่าแมตช์เดินถูกไหม — อันนั้นต้องเล่นจริง · มันกันเรื่องที่พังเงียบที่สุดแทน:
-- ราคาที่ขยับโดยไม่มีใครตั้งใจ ไอเทมที่ถูกเปลี่ยนชื่อจนร้านชี้ไปที่ของที่ไม่มีอยู่ และหีบที่ไม่มีจริง
local ArenaConfig = require(game.ReplicatedStorage.ArenaConfig)
local ChestConfig = require(game.ReplicatedStorage.ChestConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local out = {}
local fails = 0

local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

----------------------------------------------------------------- 1. ราคาตรงตามสเปก
-- ตารางนี้คัดลอกมาจากข้อความที่ผู้ใช้เขียน ไม่ได้อ่านจาก ArenaConfig — ถ้าสองฝั่งไม่ตรงกันคือมีคนขยับ
local WANT = {
	Sword = 250, Greatsword = 1500, Shield = 1500,
	Pistol = 500, Bow = 1000, Staff = 1000, Spellbook = 1000,
	LeatherArmor = 250, ChainmailArmor = 500, PlateArmor = 1000,
	HealthPotion = 200, GreatPotion = 500, FirstAidKit = 1000, Water = 50,
}
local seen = {}
for _, entry in ipairs(ArenaConfig.Shop) do
	seen[entry.id] = true
	check(WANT[entry.id] == entry.price,
		("ราคา %s = %s (สเปก %s)"):format(entry.id, tostring(entry.price), tostring(WANT[entry.id])))
	check(ItemCatalog.Items[entry.id] ~= nil, ("%s มีอยู่ในแคตตาล็อก"):format(entry.id))
	check(entry.slot == "weapon" or entry.slot == "armor" or entry.slot == "use",
		("%s อยู่ช่องที่ร้านรู้จัก (%s)"):format(entry.id, tostring(entry.slot)))
end
for id in pairs(WANT) do
	check(seen[id] == true, ("ร้านมี %s ขาย"):format(id))
end

----------------------------------------------------------------- 2. ปืนต้องมี 16 นัด
local pistol = ArenaConfig.ShopEntry("Pistol")
check(pistol and pistol.ammo == 16, "ปืนมากับกระสุน 16 นัด")
check(ItemCatalog.Items.Bullet ~= nil, "มีไอเทมกระสุนให้แจก")

----------------------------------------------------------------- 3. เศรษฐกิจ
local E = ArenaConfig.Economy
check(E.start == 800, ("ซิลเวอร์เริ่มต้น %d (สเปก 800)"):format(E.start))
check(E.roundWin > E.roundLoss, "ชนะรอบได้มากกว่าแพ้รอบ")
check(E.perKill > 0 and E.roundTopFragger > 0, "มีโบนัสคิลและโบนัสคนฆ่าเยอะสุด")
check(E.cap > E.start, "เพดานสะสมสูงกว่าเงินตั้งต้น")

----------------------------------------------------------------- 4. กติกาแมตช์
check(ArenaConfig.RoundsToWin == 3, "ชนะ 3 รอบก่อน = ชนะแมตช์")
check(ArenaConfig.TeamSize == 3 and ArenaConfig.MatchPlayers == 6, "3v3 รวม 6 คน")
check(ArenaConfig.MaxRounds > ArenaConfig.RoundsToWin, "เพดานรอบสูงกว่าจำนวนรอบที่ต้องชนะ")
check(ArenaConfig.Bots.searchSeconds == 180, "เติมบอทเมื่อค้นหาครบ 3 นาที")
check(ArenaConfig.Phase.buyFirst >= ArenaConfig.Phase.buy, "ช่วงซื้อของรอบแรกยาวกว่าหรือเท่ารอบอื่น")

----------------------------------------------------------------- 5. หีบรางวัล
for rank, tier in pairs(ArenaConfig.Rewards.chestByRank) do
	check(ItemCatalog.Items[tier] ~= nil, ("อันดับ %d ได้ %s ซึ่งมีอยู่จริง"):format(rank, tier))
	check(ChestConfig.Chests[tier] ~= nil, ("%s มีตารางดรอปของตัวเอง"):format(tier))
end
check(ChestConfig.Chests.Chest_Magic ~= nil, "หีบเวทมนตร์ถูกเพิ่มเป็นระดับที่ห้า")
check(ItemCatalog.Items.Chest_Magic ~= nil, "หีบเวทมนตร์อยู่ในแคตตาล็อก")
local inOrder = false
for _, tier in ipairs(ChestConfig.Order) do
	if tier == "Chest_Magic" then inOrder = true end
end
check(inOrder, "หีบเวทมนตร์อยู่ใน ChestConfig.Order (คำสั่งแอดมินจึงแจกได้)")

----------------------------------------------------------------- 6. แมพ
local ids = {}
for _, map in ipairs(ArenaConfig.Maps) do
	check(ids[map.id] == nil, ("แมพ %s ไม่ซ้ำชื่อ"):format(map.id))
	ids[map.id] = map.origin
end
check(#ArenaConfig.Maps >= 2, "มีแมพให้สุ่มอย่างน้อยสองด่าน")
for a, originA in pairs(ids) do
	for b, originB in pairs(ids) do
		if a ~= b then
			check((originA - originB).Magnitude > 1000,
				("แมพ %s กับ %s อยู่ห่างกันพอ (%d สตัด)"):format(a, b, (originA - originB).Magnitude))
		end
	end
end

----------------------------------------------------------------- 7. คะแนนจัดอันดับ
local star = ArenaConfig.Score({ kills = 10, deaths = 1, assists = 2, damage = 4000 })
local dud = ArenaConfig.Score({ kills = 0, deaths = 8, assists = 0, damage = 200 })
check(star > dud, "คนทำผลงานดีได้คะแนนมากกว่าคนที่ไม่ทำอะไร")
local killer = ArenaConfig.Score({ kills = 5, deaths = 0, assists = 0, damage = 1000 })
local hitter = ArenaConfig.Score({ kills = 0, deaths = 0, assists = 0, damage = 4000 })
check(killer > hitter, "คิลหนักกว่าดาเมจล้วน")

----------------------------------------------------------------- 8. ปืน/ธนูในสนามต้องไม่ใช่ของจับกุม
local overrides = ArenaConfig.CombatOverrides
check(overrides.Pistol and overrides.Pistol.damage > 0, "ปืนในสนามทำดาเมจจริง")
check(overrides.Pistol and overrides.Pistol.effect == false, "ปืนในสนามไม่ล้มคน 5 วินาที")

out[#out + 1] = fails == 0 and ("ผ่านทั้งหมด %d ข้อ"):format(#out) or ("ตก %d ข้อ"):format(fails)
return table.concat(out, "\n")
