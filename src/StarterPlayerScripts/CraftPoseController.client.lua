-- CraftPoseController: ท่าทำงานที่เตา เครื่องปั่น และเครื่องต้มยา
--
-- คู่กับ ConsumeController: เซิร์ฟเวอร์เป็นคนตัดสินว่าใครกำลังทำอะไรและนานแค่ไหน ที่นี่แค่วาดให้ทุกคนเห็น
-- ท่าอยู่ใน `WorkPoses` เพราะกล่องปฐมพยาบาลใช้เครื่องเดียวกันนี้เล่นท่าพันแผล
--
-- **ยิงมาหาทุกไคลเอนต์ ไม่ใช่เฉพาะคนคราฟ** คนที่เดินผ่านครัวจึงเห็นเชฟยืนคนหม้ออยู่จริงๆ
local Players = game:GetService("Players")

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local Remotes = require(game.ReplicatedStorage.Remotes)
local WorkPoses = require(game.ReplicatedStorage.WorkPoses)

-- ชื่อสถานี → ชุดท่า
local POSES = {
	stove = "stove",
	blender = "blender",
	still = "still",
}

-- ไกลแค่ไหนถึงถือว่า "ไม่ได้ยืนทำอยู่แล้ว" กว้างกว่าระยะที่หน้าต่างปิดตัว (16) เล็กน้อย เพื่อไม่ให้ท่ากะพริบ
-- ตอนขยับตัวอยู่ข้างเครื่อง
local WORK_RANGE = 18

local active = {} -- [player] = handle

local function stop(player)
	local handle = active[player]
	if not handle then return end
	active[player] = nil
	handle:Stop()
end

local function start(player, station, seconds, position)
	stop(player)
	local kind = POSES[station]
	local character = player.Character
	if not kind or not character then return end

	-- เดินออกจากเครื่อง = หยุดขยับ (แต่เวลายังเดิน อาหารยังสุกต่อ) กลับมาก็คนหม้อต่อ
	-- ไม่มีพิกัดเครื่องส่งมา (เครื่องหลุด stream ตอนนั้นพอดี) ให้เล่นไปเลย ดีกว่าไม่เล่นอะไร
	local shouldRun = position and function()
		local root = character:FindFirstChild("HumanoidRootPart")
		return root ~= nil and (root.Position - position).Magnitude <= WORK_RANGE
	end or nil

	local handle = WorkPoses.Play(character, kind, seconds, shouldRun)
	if handle then active[player] = handle end
end

Remotes.CraftPoseChanged.OnClientEvent:Connect(function(player, station, seconds, position)
	if not player then return end
	if station then
		start(player, station, seconds, position)
	else
		stop(player)
	end
end)

-- ริกใหม่ไม่มีท่าให้เก็บ ข้อต่อที่มันเขียนอยู่หายไปแล้ว (เหมือน ConsumeController)
local function watch(player)
	player.CharacterRemoving:Connect(function() stop(player) end)
end

Players.PlayerRemoving:Connect(stop)
for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end
Players.PlayerAdded:Connect(watch)
