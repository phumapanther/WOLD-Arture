-- WorldSound: เสียงในโลกที่คนรอบๆ ได้ยินตามระยะ (QA 2026-09-28 · "อินเทอแร็กอะไรแล้วต้องไม่เงียบ")
--
-- `WorldSound.At(name, where, volumeScale, maxDistance)` — `name` = ชื่อใน `SoundscapeConfig.Interface`
-- `where` = Vector3 หรือ BasePart/Model · ส่ง **เฉพาะคนที่ยืนในระยะ** (บทเรียนเสียงเท้า: ยิงถึงทุกคนในเซิร์ฟ
-- = รีโมต+Sound ท่วมมือถือ) · ฝั่งไคลเอนต์เล่นผ่าน `UiSound.PlayAt` (`WorldSoundController`)
local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage.Remotes)

local WorldSound = {}

local DEFAULT_DISTANCE = 60

local function positionOf(where)
	if typeof(where) == "Vector3" then return where end
	if typeof(where) ~= "Instance" then return nil end
	if where:IsA("BasePart") then return where.Position end
	if where:IsA("Model") then return where:GetPivot().Position end
	return nil
end

function WorldSound.At(name, where, volumeScale, maxDistance)
	local position = positionOf(where)
	if not position or type(name) ~= "string" then return end
	maxDistance = maxDistance or DEFAULT_DISTANCE
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - position).Magnitude <= maxDistance + 10 then
			Remotes.WorldSound:FireClient(player, name, position, volumeScale or 1, maxDistance)
		end
	end
end

return WorldSound
