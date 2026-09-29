-- Lava.server: ยืนในลาวา = ไหม้ (ผู้ใช้กำหนด 2026-09-29 · ปล่องมังกรหลับ)
--
-- ลาวา = **Part ใดก็ได้ที่ติดแท็ก `WOLD_Lava`** (ต้องเปิด CanQuery) วันหลังอยากวางลาวาที่อื่นแค่ติดแท็ก ไม่ต้องแก้โค้ด
-- · ตัดสินจากกล่องรอบเท้าชนกล่องของ Part ลาวา (ไม่ใช้ Touched ซึ่งพลาดบ่อยกับของที่ชนไม่ได้)
-- · ไหม้ `VitalsConfig.LavaBurnFraction` ของเลือดเต็มต่อวินาที ชนิด "burn" ข้ามเกราะ เลือดหมด = ล้มคลานตามปกติ
--   คนที่ล้มอยู่แล้วไม่โดนซ้ำ (กติกาเดิมของ Vitals) จึงคลานออกได้
-- · เข้าลาวาครั้งแรกของแต่ละรอบขึ้นข้อความเตือน (กติกา "อินเทอแร็กแล้วต้องไม่เงียบ")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vitals = require(script.Parent.Vitals)
local VitalsConfig = require(ReplicatedStorage.VitalsConfig)
local Remotes = require(ReplicatedStorage.Remotes)

local TAG = "WOLD_Lava"
local TICK = 0.5
-- กล่องรอบเท้า: ต่ำกว่าเท้า 1 ถึงเหนือเท้า 3 — ลุยลาวาตื้นก็โดน ยืนบนสะพานเหนือลาวาไม่โดน
local BOX = Vector3.new(2, 4, 2)

local warned = {}
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function inLava(root, humanoid)
	local feet = root.Position - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight, 0)
	return #workspace:GetPartBoundsInBox(CFrame.new(feet + Vector3.new(0, 1, 0)), BOX, overlap) > 0
end

Players.PlayerRemoving:Connect(function(player)
	warned[player] = nil
end)

while true do
	task.wait(TICK)
	local lava = CollectionService:GetTagged(TAG)
	if #lava > 0 then
		overlap.FilterDescendantsInstances = lava
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 and inLava(root, humanoid) then
				Vitals.ApplyDamage(player, Vitals.MaxHP(player) * VitalsConfig.LavaBurnFraction * TICK, "burn")
				if not warned[player] then
					warned[player] = true
					Remotes.SocialNotify:FireClient(player, "warn", "🔥 ลาวาร้อน! รีบออกไป")
				end
			else
				warned[player] = nil
			end
		end
	end
end
