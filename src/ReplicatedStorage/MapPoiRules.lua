-- MapPoiRules: กติกาล้วนของหมุดบนแผนที่ v2 (2026-10-02) — หมวด · อีโมจิ · ซูมขั้นต่ำ · กรอง · รวมกลุ่มสายแร่
-- ทั้ง MapPoi.server (ประกอบหมุดจากของจริงในแมพ) และ MapGui (วาด/กรอง) ถามที่นี่ที่เดียว · เทส tests/map_poi_rules_test.lua
-- อีโมจิสีเท่านั้น: สัญลักษณ์ตัวอักษร (★ ◆ ▲ ✦) ขึ้นกล่องเปล่าในเกมจริง
local MapPoiRules = {}

-- ลำดับ = ลำดับปุ่มในแถบกรอง · minZoom = ซูมขั้นต่ำที่หมุดหมวดนี้โผล่ (ซูมไกลสุดของแผนที่คือ 1/1.3)
MapPoiRules.Categories = {
	{ id = "city", emoji = "🏰", label = "เมือง/ปราสาท", minZoom = 0 },
	{ id = "village", emoji = "🏡", label = "หมู่บ้าน", minZoom = 0 },
	{ id = "landmark", emoji = "🗿", label = "แลนด์มาร์ก", minZoom = 0 },
	{ id = "dungeon", emoji = "⚔️", label = "ถ้ำ/บอส", minZoom = 0 },
	{ id = "station", emoji = "⚓", label = "สถานีพาหนะ", minZoom = 0 },
	{ id = "mine", emoji = "⛏️", label = "เหมืองแร่", minZoom = 1.5 },
	{ id = "fishing", emoji = "🎣", label = "จุดตกปลา", minZoom = 1.5 },
	{ id = "monster", emoji = "👾", label = "จุดเกิดมอน", minZoom = 2 },
	{ id = "quest", emoji = "📜", label = "บอร์ดเควส", minZoom = 2 },
	{ id = "npc", emoji = "🧑", label = "NPC บริการ", minZoom = 3 },
}
local byId = {}
for _, c in ipairs(MapPoiRules.Categories) do byId[c.id] = c end

function MapPoiRules.Category(id)
	return byId[id]
end

-- สถานที่ใน MapConfig.Places: kind → หมวด + อีโมจิ (แลนด์มาร์กแต่ละที่มีอีโมจิของตัวเองตามชื่อ)
local PLACE_KIND = { -- ชนิดสถานที่ที่ MapConfig.Places ใช้ได้ (เทสตรวจ)
	capital = { "city", "🏰" }, castle = { "city", "🏰" },
	farm = { "village", "🏡" }, engineer = { "village", "🏡" }, mine = { "village", "🏡" },
	lumber = { "village", "🏡" }, fishing = { "village", "🏡" }, mage = { "village", "🏡" },
	cave = { "dungeon", "⚔️" }, volcano = { "landmark", "🌋" }, landmark = { "landmark", "🗿" },
}
local PLACE_EMOJI = {
	["Wyrmsleep Crater"] = "🌋", ["World Tree"] = "🌳", ["Hermit Tower"] = "🗼",
	["Runestone Forest"] = "💠", ["Foundry"] = "🔥",
}

MapPoiRules.PlaceKinds = PLACE_KIND
function MapPoiRules.ForPlace(place)
	local rule = PLACE_KIND[place.kind] or { "landmark", "🗿" }
	return rule[1], PLACE_EMOJI[place.name] or rule[2]
end

-- NpcKind (แท็ก WOLD_Npc) + NPC เนื้อเรื่อง
MapPoiRules.NpcEmoji = {
	shop = "🛒", smith = "⚒️", bank = "🏦", vehicle = "🔑", guild = "🛡️",
	lyra = "🔧", oforian = "🌾",
}
MapPoiRules.NpcRole = { shop = "ร้าน", smith = "ช่างตีเหล็ก", bank = "ธนาคาร/คลัง", vehicle = "โรงรถ", guild = "สมาคม" }
MapPoiRules.StationEmoji = { Car = "🚂", Boat = "⚓", Airship = "🎈" }
MapPoiRules.Emoji = { boss = "💀", monster = "👾", quest = "📜", fishing = "🎣", mine = "⛏️", npc = "🧑" }

MapPoiRules.OreNames = {
	IronOre = "เหล็ก", SilverOre = "เงิน", GoldOre = "ทอง", MagicOre = "แร่เวท",
	DiamondOre = "เพชร", Crystal = "คริสตัล", Coal = "ถ่านหิน",
}

-- filters[id] == false = ผู้เล่นปิดหมวดนั้น (nil = เปิด · เริ่มเปิดทุกหมวด)
function MapPoiRules.Visible(categoryId, zoom, filters)
	local c = byId[categoryId]
	if not c then return false end
	if filters and filters[categoryId] == false then return false end
	return zoom >= c.minZoom
end

-- รวมสายแร่ที่อยู่ใกล้กันเป็นหมุดเดียว: จุดที่ห่างจากศูนย์กลางกลุ่มไม่เกิน radius เข้ากลุ่มนั้น
-- list = { {x, z, kind}, ... } → { {x, z, count, kinds = { [kind] = n }}, ... } (x/z = ค่าเฉลี่ย)
-- ponytail: O(จุด × กลุ่ม) ไล่ตามลำดับ — แร่ทั้งแมพ ~100 จุด ไม่ต้องมีกริดค้นหา
function MapPoiRules.ClusterOres(list, radius)
	local groups = {}
	local r2 = radius * radius
	for _, ore in ipairs(list) do
		local home
		for _, g in ipairs(groups) do
			local dx, dz = ore.x - g.x, ore.z - g.z
			if dx * dx + dz * dz <= r2 then home = g break end
		end
		if home then
			home.sx += ore.x
			home.sy += ore.y or 0
			home.sz += ore.z
			home.count += 1
			home.x, home.y, home.z = home.sx / home.count, home.sy / home.count, home.sz / home.count
		else
			home = { x = ore.x, y = ore.y or 0, z = ore.z, sx = ore.x, sy = ore.y or 0, sz = ore.z, count = 1, kinds = {} }
			groups[#groups + 1] = home
		end
		home.kinds[ore.kind] = (home.kinds[ore.kind] or 0) + 1
	end
	for _, g in ipairs(groups) do g.sx, g.sy, g.sz = nil, nil, nil end
	return groups
end

-- "เหมือง: เหล็ก · คริสตัล" เรียงจากชนิดที่มีมากสุด
function MapPoiRules.MineLabel(group)
	local kinds = {}
	for kind, n in pairs(group.kinds) do kinds[#kinds + 1] = { kind, n } end
	table.sort(kinds, function(a, b)
		if a[2] ~= b[2] then return a[2] > b[2] end
		return a[1] < b[1]
	end)
	local names = {}
	for _, k in ipairs(kinds) do names[#names + 1] = MapPoiRules.OreNames[k[1]] or k[1] end
	return "เหมือง: " .. table.concat(names, " · ")
end

-- ของดิบที่ MapPoi.server สแกนได้ → หมุด { id, cat, emoji, label, x, y, z }
-- src = { npcs, story, oforian, spawners, ores, boards, stations, fishing } (ทุกช่องว่างได้) · ฟิลด์ดูที่ MapPoi.server
-- สปอว์เนอร์อีเวนต์: บอสโลก = 💀 หมวดถ้ำ/บอส · อีเวนต์อื่น (สไลม์กลายพันธุ์) ว่างเปล่านอกอีเวนต์ จึงไม่ปัก
MapPoiRules.OreClusterRadius = 250
function MapPoiRules.Build(src)
	local pins = {}
	local function add(prefix, cat, emoji, label, at)
		pins[#pins + 1] = { id = prefix .. ":" .. #pins + 1, cat = cat, emoji = emoji, label = label, x = at.x, y = at.y or 0, z = at.z }
	end
	for _, n in ipairs(src.npcs or {}) do
		local role = MapPoiRules.NpcRole[n.kind]
		add("npc", "npc", MapPoiRules.NpcEmoji[n.kind] or MapPoiRules.Emoji.npc, role and (role .. " " .. n.name) or n.name, n)
	end
	for _, n in ipairs(src.story or {}) do
		add("story", "npc", MapPoiRules.NpcEmoji[string.lower(n.id)] or MapPoiRules.Emoji.npc, n.name, n)
	end
	if src.oforian then add("oforian", "npc", MapPoiRules.NpcEmoji.oforian, "ออฟาเรียน เทพหุ่นฟาง", src.oforian) end
	for _, s in ipairs(src.spawners or {}) do
		if s.event == "worldboss" then
			add("boss", "dungeon", MapPoiRules.Emoji.boss, "บอสโลก: " .. s.name, s)
		elseif not s.event then
			add("mob", "monster", MapPoiRules.Emoji.monster, s.name, s)
		end
	end
	for _, g in ipairs(MapPoiRules.ClusterOres(src.ores or {}, MapPoiRules.OreClusterRadius)) do
		add("mine", "mine", MapPoiRules.Emoji.mine, MapPoiRules.MineLabel(g), g)
	end
	for _, b in ipairs(src.boards or {}) do
		add("board", "quest", MapPoiRules.Emoji.quest, "บอร์ดเควส " .. b.name, b)
	end
	for _, s in ipairs(src.stations or {}) do
		add("station", "station", MapPoiRules.StationEmoji[s.vtype] or MapPoiRules.Emoji.npc, s.title, s)
	end
	for _, f in ipairs(src.fishing or {}) do
		add("fish", "fishing", MapPoiRules.Emoji.fishing, f.fish and (f.name .. " · " .. f.fish) or f.name, f)
	end
	return pins
end

return MapPoiRules
