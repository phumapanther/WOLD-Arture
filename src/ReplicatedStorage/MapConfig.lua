-- MapConfig: the world map's contents, taken from docs/design/world-layout.json.
--
-- Coordinates are the SAME normalized [-1..1] pair the layout file uses, times HalfSize to reach studs. That
-- is deliberate: the map and the terrain generator read one set of numbers, so a village that moves in the
-- world moves on the map too, rather than drifting apart.
--
-- Roblox world axes: X is the layout's first value, Z the second. Y is height and the map ignores it.
local MapConfig = {}

MapConfig.HalfSize = 8000 -- half the world's width in studs; [-1,1] maps onto [-8000, 8000]

-- Zoom limits for the map screen. 1 shows the whole world edge to edge.
--
-- Out to 0.77 rather than stopping at 1, so the island can be seen whole with sea around it instead of
-- jammed against the frame -- the "another 30% further out" the user asked for (1 / 1.3).
--
-- In to 12 rather than 6: twice as close as before. That is only worth having because the terrain is now
-- sampled finely enough to have something to show at that range -- see MapTerrain and MapGui:buildTerrain,
-- which swaps in the fine grid once the zoom is past DETAIL_ZOOM. Raising this without that would magnify
-- the same squares, which is not detail, it is just bigger squares.
MapConfig.MinZoom = 1 / 1.3
MapConfig.MaxZoom = 12
MapConfig.ZoomStep = 0.5

-- Past this zoom the map redraws its ground from every sampled cell instead of every third one. Chosen so
-- the swap happens while the player is already deliberately zoomed in, not on the first notch.
MapConfig.DetailZoom = 2.5
-- How many sampled cells one drawn square covers at each of the two levels.
MapConfig.CoarseStep = 3

-- Water sits under everything; the coast is drawn as an island on top of it.
MapConfig.SeaColor = Color3.fromRGB(38, 62, 92)
MapConfig.LandColor = Color3.fromRGB(74, 92, 62)
MapConfig.SandColor = Color3.fromRGB(122, 116, 84)
MapConfig.MountainColor = Color3.fromRGB(96, 96, 104)
MapConfig.ForestColor = Color3.fromRGB(52, 76, 50)
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
	{ name = "Stonemark Mine", th = "เหมืองสโตนมาร์ก", pos = { -0.14, -0.5 }, kind = "cave" },
	{ name = "Sea Cave", th = "ถ้ำทะเล", pos = { -0.84, 0.1 }, kind = "cave" },
	-- แลนด์มาร์ก (ผู้ใช้สั่ง 2026-09-29) · พิกัดวัดจากของจริงในเพลสหลัก · เทส wyrmsleep_config_test
	-- ลบ "หอเวทเอลด์" (ไม่เคยถูกสร้าง ยืนตรงปล่อง) กับ "ถ้ำคริสตัล" (ไม่มีอะไรเหลือในเพลส) ออกแล้ว
	{ name = "Wyrmsleep Crater", th = "ปล่องมังกรหลับ", pos = { 0.40625, -0.60625 }, kind = "volcano" }, -- WyrmsleepConfig.Center
	{ name = "Foundry", th = "เตาหลอม", pos = { -0.1326, 0.6646 }, kind = "landmark" }, -- WOLD.BossSpawns.Foundry · บอสฟอร์จวอร์เดน
	{ name = "Runestone Forest", th = "ป่าหินเวท", pos = { -0.0875, -0.145 }, kind = "landmark" }, -- กลุ่ม Ore_Magic ยักษ์
	{ name = "World Tree", th = "ต้นไม้โลก", pos = { -0.5188, 0.3075 }, kind = "landmark" }, -- GreatTree_Yggdrasil
	{ name = "Hermit Tower", th = "หอคอยสันโดษ", pos = { 0.1983, 0.0298 }, kind = "landmark" }, -- Ruin_TowerTall
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
	cave = { color = Color3.fromRGB(140, 132, 124), glyph = "\226\151\134", size = 7 },
	volcano = { color = Color3.fromRGB(236, 96, 44), glyph = "\226\150\178", size = 10 }, -- ▲
	landmark = { color = Color3.fromRGB(226, 196, 120), glyph = "\226\151\134", size = 8 }, -- ◆
}

-- The river and the roads used to be drawn here: two polylines copied out of the design document. Both are
-- gone at the user's request, and the reason they had to go is the same reason they looked wrong -- neither
-- exists in the world. The roads phase has never been run, and the river was a straight blue line between
-- design points, so the map was promising paths and water that a player walking there would not find. What
-- is left is the ground as it was actually sampled, and the places worth naming.

-- แผนที่ v2 (2026-10-02): รูปพื้นโลก 2x2 แผ่น [แถว][คอลัมน์] แถวบน = ขอบ -Z วาดจากโลกจริง
-- (tools/build-map-image.js → tools/render-map.py → upload) · ว่าง = MapGui วาดพื้นจาก MapTerrain แบบเดิม
-- แมพเปลี่ยนเมื่อไหร่: รันสองตัวนั้น อัปโหลด world_<r>_<c>.png แล้วแก้เลขสี่ตัวนี้
MapConfig.Tiles = {
	{ "rbxassetid://116155269535746", "rbxassetid://128567406012767" },
	{ "rbxassetid://82009149988465", "rbxassetid://118644319309557" },
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
