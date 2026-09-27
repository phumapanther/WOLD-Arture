-- BlockGuard.server: รับ "ยก/ปล่อยการ์ด" จากไคลเอนต์ — **สนาม PVP เท่านั้น** (ผู้ใช้เลือก 2026-09-27 ตาม roadmap:
-- เกมหลักคลิกขวาค้าง = หมุนกล้อง) · จังหวะปัด/ลดดาเมจอยู่ `Blocking` · ตัวเลข `ArenaConfig.Block`
--
-- ยกการ์ดไม่ได้ตอน: ล้ม/มึน/เซ/ถูกจับ/ถูกอุ้ม (`StatusEffects.CanFight`) · ล้มคลาน · กินยา · กลิ้ง/สไลด์ (`WOLD_Acting`) ·
-- ถือสไน (คลิกขวา = เลิกส่อง) · ลูป 0.1 วิปล่อยการ์ดให้เองเมื่อเงื่อนไขไหนหลุดระหว่างยกอยู่ (โดนล้ม กดกลิ้ง เปลี่ยนเป็นสไน)
local Players = game:GetService("Players")

local ServerConfig = require(script.Parent.ServerConfig)
if not ServerConfig.IsArena then return end

local Blocking = require(script.Parent.Blocking)
local StatusEffects = require(script.Parent.StatusEffects)
local Vitals = require(script.Parent.Vitals)
local Inventory = require(script.Parent.Inventory)
local Consuming = require(script.Parent.Consuming)
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

-- ยกได้ไหมตอนนี้ · คืนค่าที่สอง = ถือโล่ (ลดมากกว่า จังหวะกว้างกว่า)
local function canBlock(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	if Vitals.IsDowned(player) or not StatusEffects.CanFight(player) then return false end
	if Consuming.IsConsuming(player) then return false end
	if player:GetAttribute("WOLD_Acting") then return false end
	local _, entry = Inventory.EquippedWeapon(player)
	local spec = entry and CombatConfig.Weapons[entry.id]
	if spec and spec.scope then return false end
	return true, entry ~= nil and entry.id == "Shield"
end

Remotes.RequestBlock.OnServerEvent:Connect(function(player, on)
	if on == true then
		local ok, shield = canBlock(player)
		if ok then Blocking.Set(player, true, shield) end
	else
		Blocking.Set(player, false)
	end
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function() Blocking.Clear(player) end)
end)
for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function() Blocking.Clear(player) end)
end
Players.PlayerRemoving:Connect(function(player) Blocking.Clear(player) end)

task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			if Blocking.IsBlocking(player) and not canBlock(player) then Blocking.Set(player, false) end
		end
		task.wait(0.1)
	end
end)
