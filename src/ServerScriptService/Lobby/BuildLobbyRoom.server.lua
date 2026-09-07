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
local tempSpawn = workspace:FindFirstChild("WOLD"):FindFirstChild("TempSpawn")
if tempSpawn then
	local spawn = tempSpawn:FindFirstChildWhichIsA("SpawnLocation")
	if spawn then spawn.Enabled = false end
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
