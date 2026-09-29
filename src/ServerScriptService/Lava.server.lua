-- Lava.server: ยืนในลาวา = ไหม้ (ผู้ใช้กำหนด 2026-09-29 · ปล่องมังกรหลับ)
--
-- ลาวา = **Part ใดก็ได้ที่ติดแท็ก `WOLD_Lava`** (ต้องเปิด CanQuery) วันหลังอยากวางลาวาที่อื่นแค่ติดแท็ก ไม่ต้องแก้โค้ด
-- · ตัดสินจากจุดเท้าเทียบกับกรอบของ Part ลาวาในพิกัดของ Part เอง (ไม่ใช้ Touched ซึ่งพลาดบ่อยกับของที่ชนไม่ได้)
--   กล่องค้นหาของ Roblox เป็นกล่องแนวแกน แผ่นที่วางเฉียงจึงกินเกินลาวาที่มองเห็น — ใช้แค่คัดตัวเลือก (รีวิว 2026-09-29)
-- · ไหม้ `VitalsConfig.LavaBurnFraction` ของเลือดเต็มต่อวินาที ชนิด "burn" ข้ามเกราะ เลือดหมด = ล้มคลานตามปกติ
--   คนที่ล้มอยู่แล้ว/อมตะ/บัพเลือดไม่ลด ไม่โดน (กติกาเดิมของ Vitals) จึงคลานออกได้
-- · ข้อความเตือนเมื่อโดนไหม้จริง ห่างกันอย่างน้อย WARN_EVERY วิ (กติกา "อินเทอแร็กแล้วต้องไม่เงียบ" แต่ไม่รัว)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vitals = require(script.Parent.Vitals)
local VitalsConfig = require(ReplicatedStorage.VitalsConfig)
local Remotes = require(ReplicatedStorage.Remotes)

local TAG = "WOLD_Lava"
local TICK = 0.5
local WARN_EVERY = 8
-- กล่องคัดตัวเลือกรอบเท้า: ต่ำกว่าเท้า 1 ถึงเหนือเท้า 3
local BOX = Vector3.new(2, 4, 2)

local lastWarn = {}
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

-- เท้าอยู่ในแผ่นลาวาจริง: ในกรอบแนวราบของแผ่น และสูงไม่เกินผิวบน +1 / ไม่ต่ำกว่าผิวล่าง −3
-- (ลุยลาวาตื้นโดน · ยืนบนสะพาน/ลานที่สูงกว่าผิวลาวาไม่โดน)
local function inLava(root, humanoid)
	local feet = root.Position - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight, 0)
	for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(feet + Vector3.new(0, 1, 0)), BOX, overlap)) do
		local rel = part.CFrame:PointToObjectSpace(feet)
		local half = part.Size / 2
		if math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and rel.Y <= half.Y + 1 and rel.Y >= -half.Y - 3 then
			return true
		end
	end
	return false
end

Players.PlayerRemoving:Connect(function(player)
	lastWarn[player] = nil
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
				local hurt = Vitals.ApplyDamage(player, Vitals.MaxHP(player) * VitalsConfig.LavaBurnFraction * TICK, "burn")
				local now = os.clock()
				if hurt and now - (lastWarn[player] or -math.huge) >= WARN_EVERY then
					lastWarn[player] = now
					Remotes.SocialNotify:FireClient(player, "warn", "🔥 ลาวาร้อน! รีบออกไป")
				end
			end
		end
	end
end
