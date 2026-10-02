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
local PLACE_KIND = {
	capital = { "city", "🏰" }, castle = { "city", "🏰" },
	farm = { "village", "🏡" }, engineer = { "village", "🏡" }, mine = { "village", "🏡" },
	lumber = { "village", "🏡" }, fishing = { "village", "🏡" }, mage = { "village", "🏡" },
	cave = { "dungeon", "⚔️" }, volcano = { "landmark", "🌋" }, landmark = { "landmark", "🗿" },
}
local PLACE_EMOJI = {
	["Wyrmsleep Crater"] = "🌋", ["World Tree"] = "🌳", ["Hermit Tower"] = "🗼",
	["Runestone Forest"] = "💠", ["Foundry"] = "🔥",
}

function MapPoiRules.ForPlace(place)
	local rule = PLACE_KIND[place.kind] or { "landmark", "🗿" }
	return rule[1], PLACE_EMOJI[place.name] or rule[2]
end

-- NpcKind (แท็ก WOLD_Npc) + NPC เนื้อเรื่อง
MapPoiRules.NpcEmoji = {
	shop = "🛒", smith = "⚒️", bank = "🏦", vehicle = "🔑", guild = "🛡️",
	lyra = "🔧", oforian = "🌾",
}
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
			home.sz += ore.z
			home.count += 1
			home.x, home.z = home.sx / home.count, home.sz / home.count
		else
			home = { x = ore.x, z = ore.z, sx = ore.x, sz = ore.z, count = 1, kinds = {} }
			groups[#groups + 1] = home
		end
		home.kinds[ore.kind] = (home.kinds[ore.kind] or 0) + 1
	end
	for _, g in ipairs(groups) do g.sx, g.sz = nil, nil end
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

return MapPoiRules
