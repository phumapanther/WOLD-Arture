-- PlayerStatusEffects.server.lua: drives the status-effect timers and clears them across respawns. All the
-- logic lives in StatusEffects.lua (a module, because combat and movement both reach it); this only wires it
-- to the game's lifecycle, the same split as Vitals/PlayerVitals.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local StatusEffects = require(game.ServerScriptService.StatusEffects)
local Remotes = require(game.ReplicatedStorage.Remotes)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)

if ServerConfig.IsLobby then return end

PlayerJoin.Each(function(player)
	player.CharacterAdded:Connect(function(character)
		-- A fresh rig never inherits an old effect.
		StatusEffects.ClearFor(player)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then humanoid.PlatformStand = false end
		Remotes.StatusChanged:FireAllClients(player, "knockdown", false)
		Remotes.StatusChanged:FireAllClients(player, "slow", false)
		-- The stars go with the old body; the new one starts clean and able to jump.
		Remotes.StatusChanged:FireAllClients(player, "dizzy", false)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	StatusEffects.ClearFor(player)
end)

RunService.Heartbeat:Connect(function()
	StatusEffects.Tick()
end)

-- 🐌 ของหนักเกินขีด (ช้าลง) · 🔧 ของที่ใส่/ถือใกล้พัง (ผู้ใช้สั่ง 2026-09-29) — ถามความจริงใหม่ทุกครึ่งวิ
-- ไม่ผูกกับเหตุการณ์ (หยิบของ · ขาย · สึก · ซ่อม · เปลี่ยนชุด · เกิดใหม่) ซึ่งมีหลายทางเกินจะไล่ครบ
local Inventory = require(game.ServerScriptService.Inventory)
local InventoryConfig = require(game.ReplicatedStorage.InventoryConfig)
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local state = Inventory.Get(player)
			if state then
				StatusEffects.SetHeavy(player, Inventory.SpeedMultiplier(player) < 1)
				StatusEffects.SetWorn(player, InventoryConfig.AnyWorn(state.equipped))
			end
		end
	end
end)
