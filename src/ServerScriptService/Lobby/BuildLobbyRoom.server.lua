-- BuildLobbyRoom: idempotent. An enclosed hall with a spawn point, themed to match the rest of the game.
-- Lobby-only: this used to run in every server, which planted a second SpawnLocation (this room's) inside every
-- Reserved channel server too. SpawnSelector just grabs the first SpawnLocation it finds, so players joining a
-- channel could land in this windowless stone box floating at y=1000 instead of on the real map. The lobby is the
-- only server that ever shows the channel-select screen, so it's the only one that needs this room to exist.
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsLobby then return end

-- mapgen/temp_spawn.lua bakes a SpawnLocation into the place file itself (it's a generation-time script, not a
-- per-server one, so it can't check IsLobby) at real map coordinates. That SpawnLocation is baked into every
-- server including the lobby, so Roblox's own respawn picks it over LobbySpawn below and drops players back on
-- the open map mid-lobby-session. Disable it here, lobby-only, until Brasshaven replaces it for real.
-- Every SpawnLocation the MAP bakes into the place file, not just TempSpawn by name. This used to look for
-- TempSpawn alone, which broke the day FirstTown deleted it and provided its own spawn under the gazebo:
-- that one stayed enabled in the lobby, so any respawn there dropped the player onto the open map at
-- 2080,49,3760 instead of keeping them in the room.
--
-- Anything under the generated world is a map spawn by definition, so the rule is the folder rather than
-- any particular name -- a spawn added by a future phase is covered without editing this again.
local world = workspace:FindFirstChild("WOLD")
if world then
	for _, d in ipairs(world:GetDescendants()) do
		if d:IsA("SpawnLocation") then d.Enabled = false end
	end
end

local existing = workspace:FindFirstChild("LobbyRoom")
if existing then return end

--------------------------------------------------------------------------------
-- ขนาด (ผู้ใช้สั่ง 2026-09-23: "ขยายห้อง lobby ให้ใหญ่กว่านี้ พอที่จะจุคนได้สัก 30 คน")
--------------------------------------------------------------------------------
--
-- ของเดิม 40x40 สตัด = 1,600 ตร.สตัด · สามสิบคนได้พื้นที่คนละ 53 ตร.สตัด ซึ่งแคบกว่าลิฟต์
-- ตอนนี้ **120x120** = 14,400 ตร.สตัด · คนละ 480 ตร.สตัด เดินหลบกันได้สบาย และเพดานสูงพอ
-- ให้ห้องไม่รู้สึกเหมือนกล่อง (30 สตัด ≈ หกเท่าความสูงตัวละคร)
local HALF = 60 -- ครึ่งความกว้างห้อง
local WALL_H = 30 -- ความสูงกำแพง
local ORIGIN = Vector3.new(0, 1000, 0) -- ลอยเหนือเกาะจริง ไม่ชนกับการเจนแมพ

local STONE = Color3.fromRGB(163, 162, 165)
local STONE_DARK = Color3.fromRGB(122, 121, 126)
local WOOD = Color3.fromRGB(86, 66, 54)
local DARK_WOOD = Color3.fromRGB(58, 42, 32)
local CLOTH = Color3.fromRGB(96, 58, 52)
local BRASS = Color3.fromRGB(178, 142, 74)
local COPPER = Color3.fromRGB(150, 98, 62)
local GLASS_TEAL = Color3.fromRGB(126, 196, 196)

-- **ล็อบบี้ตรึงแสงไว้ ไม่ต้องมีกลางวัน-กลางคืน** (ผู้ใช้สั่ง 2026-09-23 ให้ตกแต่งให้สวย)
--
-- ห้องนี้ปิดมิดชิดลอยอยู่ที่ y=1000 แต่ `Lighting.Ambient` ยังเป็นของทั้งเซิร์ฟ — ตกกลางคืนเมื่อไหร่
-- ห้องก็มืดเป็นสีน้ำเงินทั้งห้อง (เห็นชัดในภาพที่ถ่ายรอบแรก) · ล็อบบี้เป็นหน้าเมนู ไม่ใช่ที่ที่เวลามีความหมาย
-- · `DayNight.server` ข้ามล็อบบี้แล้ว (มันเขียนทับทุก 0.25 วิ ตั้งตรงนี้อย่างเดียวจะหายในเสี้ยววินาที)
local Lighting = game:GetService("Lighting")
Lighting.ClockTime = 14
Lighting.Brightness = 2.5
-- ⚠️ **แอมเบียนต์ต้องอุ่น** — ห้องปิดไม่มีแสงแดดส่องเข้ามา สีที่เห็นทั้งห้องจึงมาจากแอมเบียนต์ล้วนๆ
-- เทากลาง (96,92,98) ทำให้หินอ่านเป็นสีน้ำเงินทั้งห้องเหมือนกลางคืน (ถ่ายเทียบแล้ว)
Lighting.Ambient = Color3.fromRGB(128, 114, 98)
Lighting.OutdoorAmbient = Color3.fromRGB(138, 124, 106)
Lighting.FogEnd = 100000
-- หมอกของบรรยากาศทำให้ห้องขุ่นเป็นฝ้า — ในห้องปิดมันไม่ได้ให้ระยะอะไร มีแต่บังของ
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then atmosphere.Density = 0 end

local room = Instance.new("Folder")
room.Name = "LobbyRoom"
room.Parent = workspace

local function part(size, pos, color, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.Cobblestone
	p.Parent = room
	return p
end

-- ของตกแต่งต้องไม่ขวางทางและไม่ขวางจุดเกิด: คนที่เกิดอยู่ในตู้หนังสือคือคนที่ติดอยู่ตรงนั้น
local function prop(size, pos, color, material, rotation)
	local p = part(size, pos, color, material)
	p.CanCollide = false
	if rotation then p.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotation), 0) end
	return p
end

--------------------------------------------------------------------------------
-- เปลือกห้อง
--------------------------------------------------------------------------------
local W = HALF * 2

part(Vector3.new(W, 1, W), ORIGIN, STONE) -- พื้น
part(Vector3.new(W, WALL_H, 2), ORIGIN + Vector3.new(0, WALL_H / 2, HALF), STONE)
part(Vector3.new(W, WALL_H, 2), ORIGIN + Vector3.new(0, WALL_H / 2, -HALF), STONE)
part(Vector3.new(2, WALL_H, W), ORIGIN + Vector3.new(HALF, WALL_H / 2, 0), STONE)
part(Vector3.new(2, WALL_H, W), ORIGIN + Vector3.new(-HALF, WALL_H / 2, 0), STONE)
part(Vector3.new(W, 1, W), ORIGIN + Vector3.new(0, WALL_H, 0), WOOD, Enum.Material.WoodPlanks) -- เพดาน

-- ลายพื้น: ขอบหินเข้มรอบห้อง กับวงกลางใต้แท่นเกิด — พื้นเรียบสีเดียว 120 สตัดอ่านเหมือนลานจอดรถ
prop(Vector3.new(W - 16, 0.06, W - 16), ORIGIN + Vector3.new(0, 0.53, 0), STONE_DARK, Enum.Material.Slate)
prop(Vector3.new(W - 20, 0.08, W - 20), ORIGIN + Vector3.new(0, 0.56, 0), STONE, Enum.Material.Slate)

-- เสาตามผนังทั้งสี่ด้าน + คานบนหัวเสา ให้ผนังยาว 120 สตัดมีจังหวะ ไม่ใช่แผ่นเดียวยาวๆ
for _, side in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
	for step = -2, 2 do
		local along = step * 22
		local x = side[1] ~= 0 and side[1] * (HALF - 2) or along
		local z = side[2] ~= 0 and side[2] * (HALF - 2) or along
		prop(Vector3.new(3, WALL_H - 1, 3), ORIGIN + Vector3.new(x, (WALL_H - 1) / 2, z), STONE_DARK, Enum.Material.Slate)
		prop(Vector3.new(4, 1.2, 4), ORIGIN + Vector3.new(x, WALL_H - 1.4, z), STONE, Enum.Material.Slate)
	end
end

-- หน้าต่างโค้ง: กระจกเรืองแสงบนผนัง ให้ห้องมีแหล่งแสงที่มองเห็นได้ ไม่ใช่สว่างมาจากไหนไม่รู้
for _, side in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
	for step = -1, 1 do
		local along = step * 22 + 11
		local x = side[1] ~= 0 and side[1] * (HALF - 1.2) or along
		local z = side[2] ~= 0 and side[2] * (HALF - 1.2) or along
		local wide = side[1] ~= 0 and Vector3.new(0.5, 11, 6) or Vector3.new(6, 11, 0.5)
		local pane = prop(Vector3.new(wide.X, wide.Y, wide.Z), ORIGIN + Vector3.new(x, 16, z), GLASS_TEAL, Enum.Material.Neon)
		pane.Transparency = 0.35
		local light = Instance.new("PointLight")
		light.Color = GLASS_TEAL
		light.Range = 22
		light.Brightness = 1.1
		light.Parent = pane
		-- ⚠️ **กรอบต้องเป็นสี่แท่งล้อม ไม่ใช่กล่องทึบใบเดียว** — กล่องที่ใหญ่กว่าบานกระจกและอยู่จุดเดียวกัน
		-- จะกลืนบานไปทั้งใบ (ถ่ายภาพรอบแรกแล้วไม่เห็นหน้าต่างสักบาน ทั้งที่โค้ดสร้างครบ)
		local onX = side[1] ~= 0 -- ผนังฝั่งซ้าย-ขวา: บานหันตามแกน X
		local centre = ORIGIN + Vector3.new(x, 16, z)
		local bars = onX and {
			{ Vector3.new(0, 6.2, 0), Vector3.new(0.7, 0.6, 7.2) },
			{ Vector3.new(0, -6.2, 0), Vector3.new(0.7, 0.6, 7.2) },
			{ Vector3.new(0, 0, 3.3), Vector3.new(0.7, 12.4, 0.6) },
			{ Vector3.new(0, 0, -3.3), Vector3.new(0.7, 12.4, 0.6) },
		} or {
			{ Vector3.new(0, 6.2, 0), Vector3.new(7.2, 0.6, 0.7) },
			{ Vector3.new(0, -6.2, 0), Vector3.new(7.2, 0.6, 0.7) },
			{ Vector3.new(3.3, 0, 0), Vector3.new(0.6, 12.4, 0.7) },
			{ Vector3.new(-3.3, 0, 0), Vector3.new(0.6, 12.4, 0.7) },
		}
		for _, bar in ipairs(bars) do
			prop(bar[2], centre + bar[1], COPPER, Enum.Material.Metal)
		end
	end
end

--------------------------------------------------------------------------------
-- แท่นเกิดกลางห้อง
--------------------------------------------------------------------------------
-- ยกเป็นแท่นสามชั้นแทนแผ่นแบนๆ — สามสิบคนที่เกิดพร้อมกันจะได้กระจายลงบันไดแทนที่จะซ้อนกันเป็นกอง
-- และมันทำให้กลางห้องเป็น "ที่" ไม่ใช่พื้นว่าง
for i, step in ipairs({ { 30, 0.6 }, { 24, 1.2 }, { 18, 1.8 } }) do
	part(Vector3.new(step[1], 0.6, step[1]), ORIGIN + Vector3.new(0, step[2], 0),
		i == 3 and STONE or STONE_DARK, Enum.Material.Slate)
end

local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
-- 16x16: จุดเกิดเล็กๆ กับคนสามสิบคนแปลว่าทุกคนโผล่ทับกันแล้วกระเด็น
spawn.Size = Vector3.new(16, 0.4, 16)
spawn.Position = ORIGIN + Vector3.new(0, 2.3, 0)
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Transparency = 1 -- ตัวแท่นข้างบนคือสิ่งที่มองเห็น อันนี้แค่หมุด
spawn.CanCollide = false
spawn.Parent = room

-- เตาไฟทองเหลืองสี่มุมของแท่น: แหล่งแสงหลักของห้อง
for _, corner in ipairs({ { 12, 12 }, { -12, 12 }, { 12, -12 }, { -12, -12 } }) do
	local base = ORIGIN + Vector3.new(corner[1], 0, corner[2])
	prop(Vector3.new(1.2, 5, 1.2), base + Vector3.new(0, 3, 0), COPPER, Enum.Material.Metal)
	prop(Vector3.new(3.4, 1.4, 3.4), base + Vector3.new(0, 5.8, 0), BRASS, Enum.Material.Metal)
	local flame = prop(Vector3.new(2.2, 1.6, 2.2), base + Vector3.new(0, 6.6, 0),
		Color3.fromRGB(255, 176, 84), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 186, 120)
	light.Range = 34
	light.Brightness = 2.2
	light.Parent = flame
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 0
	fire.Parent = flame
end

--------------------------------------------------------------------------------
-- ของตกแต่ง
--------------------------------------------------------------------------------
-- ทุกชิ้นเป็นการตกแต่งล้วน: anchored, เดินทะลุได้, และสร้างจาก Part ล้วนๆ จึงไม่มีทางหายแบบที่
-- `WOLD_Weapons` เคยหาย (ไม่พึ่งแอสเซทหรือโฟลเดอร์ที่สคริปต์อื่นลบทิ้งได้)

-- คบไฟตามผนัง
for _, spot in ipairs({
	{ Vector3.new(-(HALF - 2.5), 10, -33), 90 }, { Vector3.new(-(HALF - 2.5), 10, 0), 90 }, { Vector3.new(-(HALF - 2.5), 10, 33), 90 },
	{ Vector3.new(HALF - 2.5, 10, -33), -90 }, { Vector3.new(HALF - 2.5, 10, 0), -90 }, { Vector3.new(HALF - 2.5, 10, 33), -90 },
	{ Vector3.new(-33, 10, -(HALF - 2.5)), 0 }, { Vector3.new(33, 10, -(HALF - 2.5)), 0 },
	{ Vector3.new(-33, 10, HALF - 2.5), 180 }, { Vector3.new(33, 10, HALF - 2.5), 180 },
}) do
	prop(Vector3.new(0.5, 0.5, 1.4), ORIGIN + spot[1], BRASS, Enum.Material.Metal, spot[2])
	local flame = prop(Vector3.new(0.8, 1.1, 0.8), ORIGIN + spot[1] + Vector3.new(0, 1, 0),
		Color3.fromRGB(255, 176, 84), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 186, 120)
	light.Range = 20
	light.Brightness = 1.5
	light.Parent = flame
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 0
	fire.Parent = flame
end

-- ธงผ้าห้อยจากคาน — ของที่ทำให้ผนังหินสูง 30 สตัดไม่ว่างเปล่า
local BANNER_TINTS = {
	Color3.fromRGB(122, 58, 50), Color3.fromRGB(58, 78, 104),
	Color3.fromRGB(92, 96, 60), Color3.fromRGB(104, 76, 118),
}
for i, spot in ipairs({
	{ Vector3.new(-(HALF - 1.4), 20, -16), 0.6 }, { Vector3.new(-(HALF - 1.4), 20, 16), 0.6 },
	{ Vector3.new(HALF - 1.4, 20, -16), 0.6 }, { Vector3.new(HALF - 1.4, 20, 16), 0.6 },
	{ Vector3.new(-16, 20, -(HALF - 1.4)), 0 }, { Vector3.new(16, 20, -(HALF - 1.4)), 0 },
	{ Vector3.new(-16, 20, HALF - 1.4), 0 }, { Vector3.new(16, 20, HALF - 1.4), 0 },
}) do
	local vertical = spot[2] > 0
	local size = vertical and Vector3.new(0.3, 14, 7) or Vector3.new(7, 14, 0.3)
	prop(size, ORIGIN + spot[1], BANNER_TINTS[(i - 1) % #BANNER_TINTS + 1], Enum.Material.Fabric)
	local rodSize = vertical and Vector3.new(0.4, 0.4, 8) or Vector3.new(8, 0.4, 0.4)
	prop(rodSize, ORIGIN + spot[1] + Vector3.new(0, 7.2, 0), BRASS, Enum.Material.Metal)
end

-- ท่อไอน้ำกับเฟืองตามผนัง — ธีมสตีมพังก์ของเกม ไม่ใช่ปราสาทเปล่าๆ
for _, side in ipairs({ -1, 1 }) do
	prop(Vector3.new(1.1, 1.1, W - 10), ORIGIN + Vector3.new(side * (HALF - 3.5), 25, 0), COPPER, Enum.Material.Metal)
	for step = -2, 2 do
		prop(Vector3.new(1.5, 1.5, 1.5), ORIGIN + Vector3.new(side * (HALF - 3.5), 25, step * 22), BRASS, Enum.Material.Metal)
	end
	for _, z in ipairs({ -40, 0, 40 }) do
		local gear = prop(Vector3.new(0.6, 6, 6), ORIGIN + Vector3.new(side * (HALF - 2.6), 25, z), BRASS, Enum.Material.Metal)
		gear.Shape = Enum.PartType.Cylinder
		gear.CFrame = CFrame.new(ORIGIN + Vector3.new(side * (HALF - 2.6), 25, z))
		prop(Vector3.new(0.8, 2, 2), ORIGIN + Vector3.new(side * (HALF - 2.4), 25, z), COPPER, Enum.Material.Metal)
	end
end

-- ตู้หนังสือ: แผ่นหลังกับชั้น แล้วเรียงสันหนังสือ ให้อ่านเป็นหนังสือ ไม่ใช่แผ่นไม้สีน้ำตาล
local function bookshelf(origin, rotation)
	local function at(offset)
		local a = math.rad(rotation or 0)
		local dx = offset.X * math.cos(a) - offset.Z * math.sin(a)
		local dz = offset.X * math.sin(a) + offset.Z * math.cos(a)
		return origin + Vector3.new(dx, offset.Y, dz)
	end
	prop(Vector3.new(10, 12, 1.6), at(Vector3.new(0, 6, 0)), DARK_WOOD, Enum.Material.Wood, rotation)
	for shelf = 0, 3 do
		prop(Vector3.new(9.6, 0.3, 1.8), at(Vector3.new(0, 1.8 + shelf * 2.8, 0)), WOOD, Enum.Material.Wood, rotation)
		local palette = {
			Color3.fromRGB(122, 58, 50), Color3.fromRGB(58, 78, 104), Color3.fromRGB(92, 96, 60),
			Color3.fromRGB(104, 76, 118), Color3.fromRGB(140, 112, 62),
		}
		local x, i = -4.4, 0
		while x < 4.4 do
			i += 1
			local width = 0.34 + ((shelf + i) % 3) * 0.14
			local height = 1.7 + ((shelf * 3 + i) % 4) * 0.14
			prop(Vector3.new(width, height, 1.2),
				at(Vector3.new(x, 1.8 + shelf * 2.8 + height / 2 + 0.15, 0)),
				palette[(shelf * 5 + i) % #palette + 1], Enum.Material.SmoothPlastic, rotation)
			x += width + 0.1
		end
	end
end
bookshelf(ORIGIN + Vector3.new(-30, 0, -(HALF - 1.6)), 0)
bookshelf(ORIGIN + Vector3.new(-16, 0, -(HALF - 1.6)), 0)
bookshelf(ORIGIN + Vector3.new(16, 0, -(HALF - 1.6)), 0)
bookshelf(ORIGIN + Vector3.new(30, 0, -(HALF - 1.6)), 0)

-- ตู้เสื้อผ้า: มีบานประตูกับมือจับ จะได้ไม่ใช่แค่กล่อง
local function wardrobe(origin, rotation)
	prop(Vector3.new(8, 13, 3.4), origin + Vector3.new(0, 6.5, 0), DARK_WOOD, Enum.Material.Wood, rotation)
	prop(Vector3.new(3.6, 10, 0.3), origin + Vector3.new(-2, 6.6, 1.8), WOOD, Enum.Material.Wood, rotation)
	prop(Vector3.new(3.6, 10, 0.3), origin + Vector3.new(2, 6.6, 1.8), WOOD, Enum.Material.Wood, rotation)
	prop(Vector3.new(0.4, 0.4, 0.4), origin + Vector3.new(-0.6, 6.6, 2.1), BRASS, Enum.Material.Metal)
	prop(Vector3.new(0.4, 0.4, 0.4), origin + Vector3.new(0.6, 6.6, 2.1), BRASS, Enum.Material.Metal)
	prop(Vector3.new(8.6, 0.7, 3.8), origin + Vector3.new(0, 13.2, 0), WOOD, Enum.Material.Wood, rotation)
end
wardrobe(ORIGIN + Vector3.new(-46, 0, HALF - 3), 0)
wardrobe(ORIGIN + Vector3.new(46, 0, HALF - 3), 0)

-- โต๊ะยาวสองตัวพร้อมม้านั่งกับตะเกียง — ที่ให้คนไปยืนคุยกันระหว่างรอ
local function longTable(centre, rotation)
	local function at(offset)
		local a = math.rad(rotation)
		local dx = offset.X * math.cos(a) - offset.Z * math.sin(a)
		local dz = offset.X * math.sin(a) + offset.Z * math.cos(a)
		return centre + Vector3.new(dx, offset.Y, dz)
	end
	prop(Vector3.new(18, 0.6, 5), at(Vector3.new(0, 4.4, 0)), WOOD, Enum.Material.Wood, rotation)
	for _, leg in ipairs({ Vector3.new(-8, 2.2, -2), Vector3.new(8, 2.2, -2), Vector3.new(-8, 2.2, 2), Vector3.new(8, 2.2, 2) }) do
		prop(Vector3.new(0.7, 4.4, 0.7), at(leg), DARK_WOOD, Enum.Material.Wood, rotation)
	end
	for _, z in ipairs({ -4.6, 4.6 }) do
		prop(Vector3.new(17, 0.5, 2.2), at(Vector3.new(0, 2.6, z)), WOOD, Enum.Material.Wood, rotation)
		prop(Vector3.new(0.6, 2.4, 2), at(Vector3.new(-7, 1.4, z)), DARK_WOOD, Enum.Material.Wood, rotation)
		prop(Vector3.new(0.6, 2.4, 2), at(Vector3.new(7, 1.4, z)), DARK_WOOD, Enum.Material.Wood, rotation)
	end
	local lantern = prop(Vector3.new(1.4, 1.8, 1.4), at(Vector3.new(0, 5.6, 0)),
		Color3.fromRGB(255, 208, 140), Enum.Material.Neon, rotation)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 214, 150)
	light.Range = 20
	light.Brightness = 1.6
	light.Parent = lantern
end
longTable(ORIGIN + Vector3.new(-38, 0, -18), 90)
longTable(ORIGIN + Vector3.new(38, 0, -18), 90)
longTable(ORIGIN + Vector3.new(-38, 0, 18), 90)
longTable(ORIGIN + Vector3.new(38, 0, 18), 90)

-- พรมทางเดินจากประตูฝั่งใต้เข้าหาแท่นกลาง
prop(Vector3.new(12, 0.1, 34), ORIGIN + Vector3.new(0, 0.6, 38), CLOTH, Enum.Material.Fabric)
prop(Vector3.new(9, 0.12, 31), ORIGIN + Vector3.new(0, 0.63, 38), Color3.fromRGB(122, 74, 66), Enum.Material.Fabric)

-- ลังกับถังตามมุมห้อง
for _, spot in ipairs({
	{ Vector3.new(52, 1.8, 52), 20 }, { Vector3.new(-52, 1.8, 52), -15 },
	{ Vector3.new(52, 1.8, -52), 8 }, { Vector3.new(-52, 1.8, -52), -28 },
	{ Vector3.new(47, 1.8, 54), 40 }, { Vector3.new(-47, 1.8, -54), 12 },
}) do
	prop(Vector3.new(3.6, 3.6, 3.6), ORIGIN + spot[1], WOOD, Enum.Material.WoodPlanks, spot[2])
	prop(Vector3.new(3.8, 0.35, 3.8), ORIGIN + spot[1] + Vector3.new(0, 1.9, 0), DARK_WOOD, Enum.Material.Wood, spot[2])
end
