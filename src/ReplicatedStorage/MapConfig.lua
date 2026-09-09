-- MapConfig: the world map's contents, taken from docs/design/world-layout.json.
--
-- Coordinates are the SAME normalized [-1..1] pair the layout file uses, times HalfSize to reach studs. That
-- is deliberate: the map and the terrain generator read one set of numbers, so a village that moves in the
-- world moves on the map too, rather than drifting apart.
--
-- Roblox world axes: X is the layout's first value, Z the second. Y is height and the map ignores it.
local MapConfig = {}

MapConfig.HalfSize = 8000 -- half the world's width in studs; [-1,1] maps onto [-8000, 8000]

-- Zoom limits for the map screen. 1 shows the whole world.
MapConfig.MinZoom = 1
MapConfig.MaxZoom = 6
MapConfig.ZoomStep = 0.5

-- Water sits under everything; the coast is drawn as an island on top of it.
MapConfig.SeaColor = Color3.fromRGB(38, 62, 92)
MapConfig.LandColor = Color3.fromRGB(74, 92, 62)
MapConfig.SandColor = Color3.fromRGB(122, 116, 84)
MapConfig.MountainColor = Color3.fromRGB(96, 96, 104)
MapConfig.ForestColor = Color3.fromRGB(52, 76, 50)
MapConfig.RiverColor = Color3.fromRGB(64, 108, 150)
MapConfig.RoadColor = Color3.fromRGB(146, 124, 92)
MapConfig.GridColor = Color3.fromRGB(210, 200, 170)

-- Ground colours, keyed by the material the terrain generator chose. Colouring by height instead had the
-- map disagreeing with the world: it painted 19% of the island as rock and snow when the generator had made
-- most of that slope grass, because it decides using slope and forest cover as well as height.
MapConfig.Materials = {
	g = Color3.fromRGB(104, 132, 76),  -- grass
	f = Color3.fromRGB(66, 96, 58),    -- forest
	r = Color3.fromRGB(132, 128, 122), -- rock
	s = Color3.fromRGB(238, 240, 246), -- snow
	d = Color3.fromRGB(196, 180, 132), -- sand
	b = Color3.fromRGB(72, 68, 74),    -- basalt cliff
}

function MapConfig.ColorFor(code)
	return MapConfig.Materials[code] or MapConfig.Materials.g
end

-- Everywhere worth naming. `kind` picks the marker's colour and glyph.
MapConfig.Places = {
	{ name = "Brasshaven", th = "บราสเฮเวน", pos = { 0.26, 0.47 }, kind = "capital" },
	{ name = "Ironcrest Keep", th = "ปราสาทไอรอนเครสต์", pos = { 0.22, 0.26 }, kind = "castle" },
	{ name = "Goldmeadow", th = "โกลด์เมโดว์", pos = { -0.12, 0.12 }, kind = "farm" },
	{ name = "Cogsworth", th = "ค็อกส์เวิร์ธ", pos = { 0.1, -0.14 }, kind = "engineer" },
	{ name = "Stonemark", th = "สโตนมาร์ก", pos = { -0.12, -0.42 }, kind = "mine" },
	{ name = "Elderwood", th = "เอลเดอร์วูด", pos = { -0.5, 0.02 }, kind = "lumber" },
	{ name = "Saltmere", th = "ซอลต์เมียร์", pos = { -0.45, 0.62 }, kind = "fishing" },
	{ name = "Astravale", th = "แอสตราเวล", pos = { 0.48, -0.42 }, kind = "mage" },
	{ name = "Spire of Eld", th = "หอเวทเอลด์", pos = { 0.45, -0.6 }, kind = "spire" },
	{ name = "Stonemark Mine", th = "เหมืองสโตนมาร์ก", pos = { -0.14, -0.5 }, kind = "cave" },
	{ name = "Crystal Cave", th = "ถ้ำคริสตัล", pos = { 0.4, -0.65 }, kind = "cave" },
	{ name = "Sea Cave", th = "ถ้ำทะเล", pos = { -0.84, 0.1 }, kind = "cave" },
}

MapConfig.Kinds = {
	capital = { color = Color3.fromRGB(226, 178, 84), glyph = "\226\152\133", size = 12 }, -- ★
	castle = { color = Color3.fromRGB(198, 198, 210), glyph = "\226\153\158", size = 10 },
	farm = { color = Color3.fromRGB(180, 196, 100), glyph = "\226\151\143", size = 8 },
	engineer = { color = Color3.fromRGB(196, 148, 96), glyph = "\226\151\143", size = 8 },
	mine = { color = Color3.fromRGB(160, 156, 150), glyph = "\226\151\143", size = 8 },
	lumber = { color = Color3.fromRGB(120, 168, 108), glyph = "\226\151\143", size = 8 },
	fishing = { color = Color3.fromRGB(110, 168, 200), glyph = "\226\151\143", size = 8 },
	mage = { color = Color3.fromRGB(170, 138, 220), glyph = "\226\151\143", size = 8 },
	spire = { color = Color3.fromRGB(196, 160, 236), glyph = "\226\150\178", size = 10 },
	cave = { color = Color3.fromRGB(140, 132, 124), glyph = "\226\151\134", size = 7 },
}

-- The river, as the layout file records it: a polyline in the same normalized space.
MapConfig.River = {
	{ 0.12, -0.62 }, { 0.14, -0.48 }, { 0.18, -0.32 }, { 0.2, -0.16 }, { 0.22, 0 },
	{ 0.24, 0.16 }, { 0.26, 0.3 }, { 0.28, 0.42 }, { 0.3, 0.54 }, { 0.32, 0.66 },
}

-- Roads between the places, by name, so they follow whatever the places do.
MapConfig.Roads = {
	{ "Brasshaven", "Ironcrest Keep" },
	{ "Brasshaven", "Goldmeadow" },
	{ "Goldmeadow", "Elderwood" },
	{ "Goldmeadow", "Cogsworth" },
	{ "Cogsworth", "Stonemark" },
	{ "Cogsworth", "Astravale" },
	{ "Astravale", "Spire of Eld" },
	{ "Brasshaven", "Saltmere" },
}

-- Studs per grid square, so the grid means something rather than being decoration.
MapConfig.GridStuds = 2000

-- world position -> normalized [-1..1]
function MapConfig.ToNormalized(x, z)
	return x / MapConfig.HalfSize, z / MapConfig.HalfSize
end

-- normalized -> world studs
function MapConfig.ToWorld(nx, nz)
	return nx * MapConfig.HalfSize, nz * MapConfig.HalfSize
end

function MapConfig.Find(name)
	for _, place in ipairs(MapConfig.Places) do
		if place.name == name then return place end
	end
	return nil
end

return MapConfig
