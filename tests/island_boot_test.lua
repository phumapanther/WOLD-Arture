-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_boot_test.lua Server
local ServerConfig = require(game.ServerScriptService.ServerConfig)
assert(ServerConfig.IsFarm == true, "IsFarm")
assert(ServerConfig.Mode == "Farming", "Mode=" .. tostring(ServerConfig.Mode))
assert(ServerConfig.IsLobby == false, "IsLobby")
assert(workspace:GetAttribute("IslandMode") == true, "IslandMode attr")
assert(game.ReplicatedStorage.Remotes:FindFirstChild("IslandPlace"), "IslandPlace remote")
local SpawnSelector = require(game.ReplicatedStorage.SpawnSelector)
-- ⚠️ **เทียบกับ SpawnLocation ตัวจริง ไม่ใช่พิกัดตายตัว** ผู้ใช้ลากย้ายจุดเกิดในสตูดิโอได้ตลอด
-- (ย้ายไปแล้วจริง: เคยอยู่ (0,820,0) ตอนนี้อยู่ (38,812,112)) — เทสที่ฝังพิกัดไว้จะพังทุกครั้งที่เขาแต่งเกาะ
local spawnLoc = assert(workspace:FindFirstChildWhichIsA("SpawnLocation", true), "ไม่มี SpawnLocation บนเกาะ")
local resolved = SpawnSelector.ResolvePosition(nil)
local off = resolved - spawnLoc.Position
assert(math.abs(off.X) < 1 and math.abs(off.Z) < 1 and off.Y > 0 and off.Y < 6,
	("จุดเกิดต้องอยู่เหนือ SpawnLocation — ได้ %s เทียบกับ %s"):format(tostring(resolved), tostring(spawnLoc.Position)))
local p = game.Players:GetPlayers()[1]
local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
-- ผู้ใช้อาจเดินอยู่ระหว่างเทส เช็คแค่ว่ายังอยู่บนเกาะ (ไม่ใช่พิกัดเมืองหลักที่ y~60)
local flat = hrp and Vector2.new(hrp.Position.X, hrp.Position.Z).Magnitude or 9e9
assert(hrp and flat < 230 and hrp.Position.Y > 780, "on the island: " .. tostring(hrp and hrp.Position))
return "boot ok, owner=" .. tostring(ServerConfig.FarmOwnerId) .. " at " .. tostring(hrp.Position)
