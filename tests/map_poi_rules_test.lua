-- node tools/offline-test.js tests/map_poi_rules_test.lua   (หรือ node tools/lua.js tests/map_poi_rules_test.lua Edit)
-- แผนที่ v2 (2026-10-02): หมวดหมุด · อีโมจิทุกชนิด · ซูมขั้นต่ำ · กรอง · รวมกลุ่มสายแร่
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
local R, MapConfig = fresh(RS.MapPoiRules), fresh(RS.MapConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

-- 1. หมวด: ครบ 10 · id ไม่ซ้ำ · มีอีโมจิ · ไม่มีสัญลักษณ์ตัวอักษรที่ขึ้นกล่องเปล่าในเกมจริง
local BAD = { "★", "◆", "▲", "✦", "●", "♞" }
local function clean(s)
	if type(s) ~= "string" or s == "" then return false end
	for _, b in ipairs(BAD) do if s:find(b, 1, true) then return false end end
	return true
end
local ids = {}
for _, c in ipairs(R.Categories) do
	check(not ids[c.id] and clean(c.emoji) and type(c.label) == "string" and type(c.minZoom) == "number", "หมวด " .. tostring(c.id))
	ids[c.id] = c
end
for _, id in ipairs({ "city", "village", "landmark", "dungeon", "station", "mine", "fishing", "monster", "quest", "npc" }) do
	check(ids[id] ~= nil, "มีหมวด " .. id)
end
check(R.Category("city").minZoom <= MapConfig.MinZoom and R.Category("npc").minZoom > R.Category("mine").minZoom,
	"ซูมไกลเห็นเมือง · NPC ต้องซูมเข้ามากกว่าเหมือง")

-- 2. ทุกสถานที่ใน MapConfig ได้หมวด + อีโมจิ
for _, p in ipairs(MapConfig.Places) do
	check(R.PlaceKinds[p.kind] ~= nil, "ชนิดสถานที่มีจริง " .. tostring(p.kind))
	local cat, emoji = R.ForPlace(p)
	check(ids[cat] ~= nil and clean(emoji), ("สถานที่ %s → %s %s"):format(p.th or p.name, tostring(cat), tostring(emoji)))
end
check(select(1, R.ForPlace(MapConfig.Find("Brasshaven"))) == "city" and select(1, R.ForPlace(MapConfig.Find("Goldmeadow"))) == "village",
	"บราสเฮเวน = เมือง · โกลด์เมโดว์ = หมู่บ้าน")

-- 3. อีโมจิตามชนิดหมุดจากเซิร์ฟ
for _, kind in ipairs({ "shop", "smith", "bank", "vehicle", "guild" }) do
	check(clean(R.NpcEmoji[kind]), "NPC " .. kind)
end
check(clean(R.NpcEmoji.lyra) and clean(R.NpcEmoji.oforian), "ไลรา · ออฟาเรียน")
for _, t in ipairs({ "Car", "Boat", "Airship" }) do check(clean(R.StationEmoji[t]), "สถานี " .. t) end
for _, e in ipairs({ R.Emoji.boss, R.Emoji.monster, R.Emoji.quest, R.Emoji.fishing, R.Emoji.mine }) do
	check(clean(e), "อีโมจิหมุด " .. tostring(e))
end
for _, kind in ipairs({ "IronOre", "Crystal", "MagicOre", "Coal", "DiamondOre", "SilverOre", "GoldOre" }) do
	check(type(R.OreNames[kind]) == "string", "ชื่อแร่ " .. kind)
end

-- 4. กรอง + ซูม
check(R.Visible("npc", 3, {}) and not R.Visible("npc", 2.9, {}), "NPC โผล่ที่ซูม 3")
check(R.Visible("city", MapConfig.MinZoom, {}), "เมืองเห็นตั้งแต่ซูมไกลสุด")
check(not R.Visible("city", 5, { city = false }) and R.Visible("city", 5, { npc = false }), "ปิดหมวด = ซ่อนเฉพาะหมวดนั้น")
check(not R.Visible("nope", 5, {}), "หมวดที่ไม่รู้จัก = ไม่โชว์")

-- 5. รวมกลุ่มสายแร่
local ores = {
	{ x = 0, z = 0, kind = "IronOre" }, { x = 100, z = 50, kind = "IronOre" }, { x = 200, z = 0, kind = "Crystal" },
	{ x = 5000, z = 5000, kind = "GoldOre" },
}
local groups = R.ClusterOres(ores, 250)
check(#groups == 2, "สองกลุ่ม (ห่าง 5000 แยกกัน) ได้ " .. #groups)
local big = groups[1].count == 3 and groups[1] or groups[2]
check(big.count == 3 and big.kinds.IronOre == 2 and big.kinds.Crystal == 1, "กลุ่มใหญ่ เหล็ก 2 คริสตัล 1")
check(math.abs(big.x - 100) < 1e-6 and math.abs(big.z - 50 / 3) < 1e-6, "ตำแหน่งกลุ่ม = ค่าเฉลี่ย")
local label = R.MineLabel(big)
check(label:find("เหล็ก", 1, true) and label:find("คริสตัล", 1, true), "ป้ายเหมืองบอกชนิดแร่: " .. label)
check(#R.ClusterOres({}, 250) == 0, "ไม่มีแร่ = ไม่มีกลุ่ม")

-- 6. Build: ของดิบที่เซิร์ฟสแกนได้ → หมุด
local pins = R.Build({
	npcs = { { kind = "shop", name = "บาร์นาบี", x = 1, y = 2, z = 3 }, { kind = "weird", name = "ใครสักคน", x = 0, y = 0, z = 0 } },
	story = { { id = "Lyra", name = "ไลรา", x = 5, y = 0, z = 5 } },
	oforian = { x = 9, y = 0, z = 9 },
	spawners = {
		{ kind = "Skeleton", name = "โครงกระดูก", x = 100, y = 0, z = 100 },
		{ kind = "SteamSlime", name = "บอยลี่", event = "slime", x = 200, y = 0, z = 200 },
		{ kind = "Forgewarden", name = "ฟอร์จวอร์เดน", event = "worldboss", x = 300, y = 0, z = 300 },
	},
	ores = { { kind = "IronOre", x = 0, y = 10, z = 0 }, { kind = "Coal", x = 50, y = 30, z = 0 } },
	boards = { { id = "Brasshaven", name = "บราสเฮเวน", x = 7, y = 0, z = 7 } },
	stations = { { id = "TownGarage", vtype = "Car", title = "โรงรถไอน้ำ", x = 8, y = 0, z = 8 },
		{ id = "HarbourDock", vtype = "Boat", title = "ท่าเรือ", x = 8, y = 0, z = 9 } },
	fishing = { { id = "BrasshavenBay", name = "อ่าวบราสเฮเวน", fish = "เรือบรรทุก", x = 4, y = 0, z = 4 } },
})
local byCat, ids, allOk = {}, {}, true
for _, p in ipairs(pins) do
	byCat[p.cat] = byCat[p.cat] or {}
	table.insert(byCat[p.cat], p)
	if ids[p.id] or not R.Category(p.cat) or not clean(p.emoji) or type(p.label) ~= "string"
		or type(p.x) ~= "number" or type(p.y) ~= "number" or type(p.z) ~= "number" then allOk = false end
	ids[p.id] = true
end
check(allOk, "ทุกหมุดมี id ไม่ซ้ำ · หมวดที่รู้จัก · อีโมจิ · ชื่อ · พิกัดครบ")
check(#(byCat.npc or {}) == 4, "NPC 2 + ไลรา + ออฟาเรียน = 4 หมุด")
local shop = byCat.npc and byCat.npc[1]
check(shop and shop.emoji == "🛒" and shop.label:find("บาร์นาบี", 1, true) and shop.label:find("ร้าน", 1, true), "ร้าน = 🛒 + ชื่อบทบาท + ชื่อคน")
local unknownOk = false
for _, p in ipairs(byCat.npc or {}) do if p.label:find("ใครสักคน", 1, true) and p.emoji == R.Emoji.npc then unknownOk = true end end
check(unknownOk, "NPC ชนิดที่ไม่รู้จัก = 🧑")
check(#(byCat.monster or {}) == 1 and byCat.monster[1].label == "โครงกระดูก", "สปอว์เนอร์ปกติ 1 หมุด · สปอว์เนอร์อีเวนต์สไลม์ถูกข้าม")
check(#(byCat.dungeon or {}) == 1 and byCat.dungeon[1].emoji == R.Emoji.boss, "จุดเกิดบอสโลก = 💀 หมวดถ้ำ/บอส")
check(#(byCat.mine or {}) == 1 and math.abs(byCat.mine[1].y - 20) < 1e-6, "สายแร่สองจุดใกล้กัน = หมุดเดียว ความสูงเฉลี่ย")
check(#(byCat.quest or {}) == 1 and byCat.quest[1].label:find("บราสเฮเวน", 1, true), "บอร์ดเควสบอกชื่อเมือง")
check(#(byCat.station or {}) == 2 and byCat.station[1].emoji == "🚂" and byCat.station[2].emoji == "⚓", "สถานีตามชนิดพาหนะ")
check(#(byCat.fishing or {}) == 1 and byCat.fishing[1].label:find("เรือบรรทุก", 1, true), "จุดตกปลาบอกชื่อปลา")
check(#R.Build({}) == 0, "ไม่มีข้อมูล = ไม่มีหมุด (ไม่ล้ม)")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
