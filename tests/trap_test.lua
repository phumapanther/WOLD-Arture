-- node tools/lua.js tests/trap_test.lua Edit   (เพลสไหนก็ได้ — ข้อมูลล้วน + เรย์บนแผ่นทดสอบชั่วคราว)
-- กับดัก (เฟส 3): สูตรตามที่ผู้ใช้อนุมัติ · กระสุน 4 แบบ · ร้านสนาม 3 ขนาด (ไม่มีลมกระแทก) · เลือกกระสุน ·
-- วิถีเขวี้ยง (ใกล้สุด/ไกลสุด · ยิ่งแรงยิ่งไกล · ตกบนผิวจริง) · ของสนามไม่หลุดออกนอกสนาม
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
local T = fresh(RS.TrapConfig)
local Catalog = fresh(RS.ItemCatalog)
local Combat = fresh(RS.CombatConfig)
local Craft = fresh(RS.CraftConfig)
local Arena = fresh(RS.ArenaConfig)

local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

-- กระสุน
local kinds = {}
for _, a in ipairs(T.Ammo) do kinds[#kinds + 1] = a.kind end
check(table.concat(kinds, ",") == "slow,stun,knockdown,damage", "กระสุน 4 แบบ หนืด/ช็อต/ลม/ระเบิด")
local blast = T.AmmoById.TrapAmmo_Blast
check(blast.damage == 35 and blast.mobDamage == 80, "ระเบิด: คน 35 · มอน 80")
check(T.AmmoById.TrapAmmo_Slow.factor == 0.5 and T.AmmoById.TrapAmmo_Slow.seconds == 3, "หนืด: ช้า 50% 3 วิ")
check(T.AmmoById.TrapAmmo_Stun.seconds == 1.5 and T.AmmoById.TrapAmmo_Knock.seconds == 2, "ช็อต 1.5 วิ · ลมกระแทก 2 วิ")
check(T.MaxPerOwner == 3 and T.LifeSeconds == 60, "ค้างได้ 3 อันต่อคน · 60 วิ")
for _, a in ipairs(T.Ammo) do
	local item = Catalog.Items[a.id]
	check(item ~= nil and item.kind == "junk", "มีในแคตตาล็อก: " .. a.id)
end

-- ตัวกับดัก
for id, trap in pairs(T.Traps) do
	local item = Catalog.Items[id]
	local spec = Combat.Weapons[id]
	check(item and item.kind == "weapon" and item.unbreakable == true and not item.skill, "อาวุธไม่สึก ไม่มีสกิล: " .. id)
	check(spec and spec.trap == true, "CombatConfig รู้ว่าเป็นกับดัก (ระบบตีข้าม): " .. id)
	if trap.fixedAmmo then
		check(item.arenaOnly == true and item.prefab == "Trap", "ของสนาม · รูปทรงกับดักเดียวกัน: " .. id)
	end
end

-- สูตร (ผู้ใช้อนุมัติ 2026-09-27)
local function recipe(id, tab)
	for _, r in ipairs(Craft.Recipes) do
		if r.id == id and r.tab == tab then return r end
	end
end
local function costIs(r, want)
	if not r then return false end
	for k, v in pairs(want) do if r.cost[k] ~= v then return false end end
	for k in pairs(r.cost) do if want[k] == nil then return false end end
	return true
end
local trapR = recipe("Trap", "weapon")
check(trapR and trapR.chance == 0.5 and trapR.gold == 8000 and costIs(trapR,
	{ IronOre = 15, GearSpare = 6, Chemical = 4, Coal = 15, Blueprint = 2, WoodScrap = 10, Silver = 500 }), "สูตรกับดัก 50% 8,000")
check(costIs(recipe("Trap", "unlucky"), { Insignia = 15 }), "คนดวงซวย: เหรียญ 15")
check(costIs(recipe("TrapAmmo_Slow", "misc"), { Slime = 10, Herb = 5, IronOre = 2 }) and recipe("TrapAmmo_Slow", "misc").yields == 5, "หนืด ×5")
check(costIs(recipe("TrapAmmo_Stun", "misc"), { Crystal = 3, GearSpare = 2, Coal = 4, IronOre = 2 }), "ช็อต")
check(costIs(recipe("TrapAmmo_Knock", "misc"), { Chemical = 2, Coal = 5, Stone = 10, IronOre = 2 }), "ลมกระแทก")
check(costIs(recipe("TrapAmmo_Blast", "misc"), { Chemical = 3, Coal = 6, IronOre = 4, Bone = 6 }) and recipe("TrapAmmo_Blast", "misc").yields == 4, "ระเบิด ×4")
-- ต่อท้ายเท่านั้น: สูตรกับดักอยู่หลังสูตรเกาะชิ้นสุดท้าย
local lastIsland, firstTrap = 0, math.huge
for i, r in ipairs(Craft.Recipes) do
	if r.station == "loom" then lastIsland = i end
	if r.id == "Trap" or r.id:match("^TrapAmmo_") then firstTrap = math.min(firstTrap, i) end
end
check(firstTrap > lastIsland, "สูตรกับดักต่อท้ายตาราง (ลำดับคือเลขที่ไคลเอนต์ส่ง)")

-- ร้านสนาม
local prices, noKnock = {}, true
for _, e in ipairs(Arena.Shop) do
	if e.row == "trap" then
		prices[#prices + 1] = e.id .. "=" .. e.price
		check(Catalog.Items[e.ammoItem] ~= nil and e.ammo > 0, "กระสุนติดมาจริง: " .. e.id)
		check(T.Traps[e.id] and T.Traps[e.id].fixedAmmo == e.ammoItem, "ขนาดกับกระสุนตรงกับ TrapConfig: " .. e.id)
		if e.ammoItem == "TrapAmmo_Knock" then noKnock = false end
	end
end
table.sort(prices)
check(table.concat(prices, " ") == "TrapLarge=2000 TrapMedium=1250 TrapSmall=500", "ราคาสนาม 500/1250/2000 " .. table.concat(prices, " "))
check(noKnock, "สนามไม่มีลมกระแทก")
check(Arena.AmmoItemOf(Arena.ShopEntry("Pistol")) == "Bullet" and Arena.AmmoItemOf(Arena.ShopEntry("Sword")) == nil,
	"ปืนยังกินกระสุนปืน · ดาบไม่กินกระสุน")
check(#Arena.AmmoItems() == 4, "กระสุนที่ร้านแจก 4 ชนิด (ปืน + กับดัก 3)")

-- เลือกกระสุน
local bag = { false, { id = "TrapAmmo_Stun", count = 3 }, { id = "TrapAmmo_Blast", count = 2 }, false }
local a1, n1 = T.SelectedAmmo("Trap", nil, bag)
check(a1 and a1.id == "TrapAmmo_Stun" and n1 == 3, "ยังไม่เลือก = ชนิดแรกที่มี (ตามลำดับหนืด→ระเบิด)")
local a2, n2 = T.SelectedAmmo("Trap", { ammo = "TrapAmmo_Blast" }, bag)
check(a2 and a2.id == "TrapAmmo_Blast" and n2 == 2, "เลือกระเบิดไว้ = ระเบิด")
local a3, n3 = T.SelectedAmmo("Trap", { ammo = "TrapAmmo_Slow" }, bag)
check(a3 and a3.id == "TrapAmmo_Slow" and n3 == 0, "เลือกหนืดแต่หมด = ไม่เดาเปลี่ยนเป็นชนิดอื่น")
local a4 = T.SelectedAmmo("Trap", nil, { false, false })
check(a4 == nil, "ไม่มีกระสุนเลย = nil")
local a5 = T.SelectedAmmo("TrapLarge", { ammo = "TrapAmmo_Slow" }, bag)
check(a5 and a5.id == "TrapAmmo_Blast", "กับดักสนามใช้กระสุนติดตัวเสมอ")

-- วิถี: แผ่นพื้นชั่วคราวไกลจากแมพ
local floor = Instance.new("Part")
floor.Anchored = true
floor.Size = Vector3.new(400, 2, 400)
floor.Position = Vector3.new(50000, 4000, 50000)
floor.Parent = workspace
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { floor }
local origin = floor.Position + Vector3.new(0, 1 + 3, 0)
local look = Vector3.new(0, 0, -1)
local function range(power)
	local r = T.Simulate(origin, T.Velocity(look, power), params)
	return (Vector3.new(r.position.X, 0, r.position.Z) - Vector3.new(origin.X, 0, origin.Z)).Magnitude, r
end
local near, rNear = range(0)
local mid = range(0.5)
local far, rFar = range(1)
floor:Destroy()
check(not rNear.fell and not rFar.fell and math.abs(rFar.position.Y - (floor.Position.Y + 1)) < 0.2, "ตกบนผิวแผ่นจริง")
check(near > 3 and near < 15 and far > 25 and far < 70 and near < mid and mid < far,
	("ยิ่งแรงยิ่งไกล: %.1f < %.1f < %.1f สตัด"):format(near, mid, far))
local up = T.Velocity(Vector3.new(0, 1, 0), 1)
check(math.deg(math.asin(up.Unit.Y)) <= T.MaxPitchDegrees + 0.01, "มองฟ้าสุด = เงยได้ไม่เกินเพดาน")

return ("%s — %d fail\n%s"):format(fails == 0 and "PASS" or "FAIL", fails, table.concat(out, "\n"))
