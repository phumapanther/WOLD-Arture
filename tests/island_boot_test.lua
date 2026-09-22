-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_boot_test.lua Server
local ServerConfig = require(game.ServerScriptService.ServerConfig)
assert(ServerConfig.IsFarm == true, "IsFarm")
assert(ServerConfig.Mode == "Farming", "Mode=" .. tostring(ServerConfig.Mode))
assert(ServerConfig.IsLobby == false, "IsLobby")
assert(workspace:GetAttribute("IslandMode") == true, "IslandMode attr")
assert(game.ReplicatedStorage.Remotes:FindFirstChild("IslandPlace"), "IslandPlace remote")
local SpawnSelector = require(game.ReplicatedStorage.SpawnSelector)
assert((SpawnSelector.ResolvePosition(nil) - Vector3.new(0, 820, 0)).Magnitude < 1, "island spawn resolves to the SpawnLocation")
local p = game.Players:GetPlayers()[1]
local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
-- ผู้ใช้อาจเดินอยู่ระหว่างเทส เช็คแค่ว่ายังอยู่บนเกาะ (ไม่ใช่พิกัดเมืองหลักที่ y~60)
local flat = hrp and Vector2.new(hrp.Position.X, hrp.Position.Z).Magnitude or 9e9
assert(hrp and flat < 230 and hrp.Position.Y > 780, "on the island: " .. tostring(hrp and hrp.Position))
return "boot ok, owner=" .. tostring(ServerConfig.FarmOwnerId) .. " at " .. tostring(hrp.Position)
