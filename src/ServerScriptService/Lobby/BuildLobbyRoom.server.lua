-- BuildLobbyRoom: idempotent. A small enclosed room with a spawn point, themed to match the rest of the game.
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

local STONE = Color3.fromRGB(163, 162, 165)
local WOOD = Color3.fromRGB(86, 66, 54)
local room = Instance.new("Folder")
room.Name = "LobbyRoom"
room.Parent = workspace

local ORIGIN = Vector3.new(0, 1000, 0) -- far above the real island so it never collides with map generation

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

part(Vector3.new(40, 1, 40), ORIGIN, STONE) -- floor
part(Vector3.new(40, 20, 1), ORIGIN + Vector3.new(0, 10, 20), STONE) -- walls
part(Vector3.new(40, 20, 1), ORIGIN + Vector3.new(0, 10, -20), STONE)
part(Vector3.new(1, 20, 40), ORIGIN + Vector3.new(20, 10, 0), STONE)
part(Vector3.new(1, 20, 40), ORIGIN + Vector3.new(-20, 10, 0), STONE)
part(Vector3.new(40, 1, 40), ORIGIN + Vector3.new(0, 20, 0), WOOD, Enum.Material.WoodPlanks) -- ceiling

local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = ORIGIN + Vector3.new(0, 1, 0)
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Material = Enum.Material.Cobblestone
spawn.Parent = room

--------------------------------------------------------------------------------
-- Furnishing
--------------------------------------------------------------------------------
-- The room was four walls and a floor, which reads as a placeholder rather than a place. Everything below is
-- decoration only: anchored, non-colliding where it would otherwise snag a player, and built from parts so
-- there is no dependency on assets that could go missing the way the weapon prefabs did.

local DARK_WOOD = Color3.fromRGB(58, 42, 32)
local CLOTH = Color3.fromRGB(96, 58, 52)
local BRASS = Color3.fromRGB(178, 142, 74)

-- Decoration must never block movement or the spawn: a player who spawns inside a bookshelf is stuck.
local function prop(size, pos, color, material, rotation)
	local p = part(size, pos, color, material)
	p.CanCollide = false
	if rotation then p.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotation), 0) end
	return p
end

-- Wall torches, which also give the room some light to look at rather than flat ambient.
for _, spot in ipairs({
	{ Vector3.new(-19, 8, -8), 90 }, { Vector3.new(-19, 8, 8), 90 },
	{ Vector3.new(19, 8, -8), -90 }, { Vector3.new(19, 8, 8), -90 },
}) do
	local bracket = prop(Vector3.new(0.4, 0.4, 1.2), ORIGIN + spot[1], BRASS, Enum.Material.Metal, spot[2])
	local flame = prop(Vector3.new(0.6, 0.9, 0.6), ORIGIN + spot[1] + Vector3.new(0, 0.8, 0),
		Color3.fromRGB(255, 176, 84), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 186, 120)
	light.Range = 18
	light.Brightness = 1.6
	light.Parent = flame
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 0
	fire.Parent = flame
end

-- Hung paintings: a frame with a canvas inset, in the game's own colours.
local function painting(pos, rotation, tint)
	prop(Vector3.new(0.3, 5, 7), pos, DARK_WOOD, Enum.Material.Wood, rotation)
	local inner = prop(Vector3.new(0.2, 4.2, 6.2), pos + Vector3.new(rotation == 0 and 0.1 or 0, 0, 0),
		tint, Enum.Material.SmoothPlastic, rotation)
	return inner
end
painting(ORIGIN + Vector3.new(-19.3, 11, -6), 0, Color3.fromRGB(64, 86, 108))
painting(ORIGIN + Vector3.new(-19.3, 11, 6), 0, Color3.fromRGB(88, 72, 56))
painting(ORIGIN + Vector3.new(19.3, 11, 0), 0, Color3.fromRGB(72, 64, 92))

-- A bookshelf against the back wall, with rows of spines so it reads as books rather than a brown slab.
local function bookshelf(origin)
	prop(Vector3.new(8, 10, 1.4), origin + Vector3.new(0, 5, 0), DARK_WOOD, Enum.Material.Wood)
	for shelf = 0, 3 do
		prop(Vector3.new(7.6, 0.3, 1.6), origin + Vector3.new(0, 1.6 + shelf * 2.4, 0),
			WOOD, Enum.Material.Wood)
		-- Spines in varied widths and colours; the seed keeps every server's shelf identical.
		local x = -3.4
		local palette = {
			Color3.fromRGB(122, 58, 50), Color3.fromRGB(58, 78, 104), Color3.fromRGB(92, 96, 60),
			Color3.fromRGB(104, 76, 118), Color3.fromRGB(140, 112, 62),
		}
		local i = 0
		while x < 3.4 do
			i += 1
			local width = 0.3 + ((shelf + i) % 3) * 0.12
            local height = 1.5 + ((shelf * 3 + i) % 4) * 0.12
			prop(Vector3.new(width, height, 1.1),
				origin + Vector3.new(x, 1.6 + shelf * 2.4 + height / 2 + 0.15, 0),
				palette[(shelf * 5 + i) % #palette + 1], Enum.Material.SmoothPlastic)
			x += width + 0.08
		end
	end
end
bookshelf(ORIGIN + Vector3.new(-9, 0, -19.2))
bookshelf(ORIGIN + Vector3.new(9, 0, -19.2))

-- A wardrobe, with doors and handles so it is not just a box.
local function wardrobe(origin, rotation)
	prop(Vector3.new(7, 11, 3), origin + Vector3.new(0, 5.5, 0), DARK_WOOD, Enum.Material.Wood, rotation)
	prop(Vector3.new(3.2, 8.4, 0.3), origin + Vector3.new(-1.75, 5.6, 1.6), WOOD, Enum.Material.Wood, rotation)
	prop(Vector3.new(3.2, 8.4, 0.3), origin + Vector3.new(1.75, 5.6, 1.6), WOOD, Enum.Material.Wood, rotation)
	prop(Vector3.new(0.4, 0.4, 0.4), origin + Vector3.new(-0.5, 5.6, 1.9), BRASS, Enum.Material.Metal)
	prop(Vector3.new(0.4, 0.4, 0.4), origin + Vector3.new(0.5, 5.6, 1.9), BRASS, Enum.Material.Metal)
	prop(Vector3.new(7.6, 0.6, 3.4), origin + Vector3.new(0, 11.2, 0), WOOD, Enum.Material.Wood, rotation)
end
wardrobe(ORIGIN + Vector3.new(0, 0, -18), 0)

-- A rug under the spawn pad, and a couple of crates and barrels so the corners are not empty.
local rug = prop(Vector3.new(16, 0.1, 12), ORIGIN + Vector3.new(0, 0.55, 4), CLOTH,
	Enum.Material.Fabric)
prop(Vector3.new(14, 0.12, 10), ORIGIN + Vector3.new(0, 0.6, 4), Color3.fromRGB(122, 74, 66),
	Enum.Material.Fabric)

for _, spot in ipairs({
	{ Vector3.new(16, 1.5, 16), 20 }, { Vector3.new(-16, 1.5, 16), -15 },
	{ Vector3.new(16.5, 1.5, -15), 8 },
}) do
	prop(Vector3.new(3, 3, 3), ORIGIN + spot[1], WOOD, Enum.Material.WoodPlanks, spot[2])
	prop(Vector3.new(3.2, 0.3, 3.2), ORIGIN + spot[1] + Vector3.new(0, 1.6, 0), DARK_WOOD,
		Enum.Material.Wood, spot[2])
end

-- A table with a lantern, to give the room a centre of interest away from the spawn pad.
prop(Vector3.new(7, 0.5, 4), ORIGIN + Vector3.new(-13, 4.2, 0), WOOD, Enum.Material.Wood)
for _, leg in ipairs({ Vector3.new(-3, 2, -1.5), Vector3.new(3, 2, -1.5),
	Vector3.new(-3, 2, 1.5), Vector3.new(3, 2, 1.5) }) do
	prop(Vector3.new(0.5, 4, 0.5), ORIGIN + Vector3.new(-13, 0, 0) + leg, DARK_WOOD, Enum.Material.Wood)
end
local lantern = prop(Vector3.new(1.2, 1.6, 1.2), ORIGIN + Vector3.new(-13, 5.3, 0),
	Color3.fromRGB(255, 208, 140), Enum.Material.Neon)
local lanternLight = Instance.new("PointLight")
lanternLight.Color = Color3.fromRGB(255, 214, 150)
lanternLight.Range = 16
lanternLight.Brightness = 1.4
lanternLight.Parent = lantern
