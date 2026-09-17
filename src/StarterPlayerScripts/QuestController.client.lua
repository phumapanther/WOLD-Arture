-- QuestController: ต่อกระดานงานเข้ากับเซิร์ฟเวอร์
--
-- บางมาก เพราะเซิร์ฟเวอร์เป็นเจ้าของทุกอย่าง: ไคลเอนต์ส่งแค่ "กดปุ่มไหนของงานที่เท่าไหร่" แล้วรอภาพใหม่
-- ไม่เดาผลลัพธ์เอง — ความคืบหน้าของงานเก็บของนับจากกระเป๋าจริงบนเซิร์ฟเวอร์
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local QuestBoardGui = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("QuestBoardGui"))

local player = Players.LocalPlayer
local gui = QuestBoardGui.new()

gui:On("accept", function(index)
	Remotes.RequestQuestAction:FireServer("accept", index)
end)

gui:On("turnin", function(index)
	Remotes.RequestQuestAction:FireServer("turnin", index)
end)

gui:On("abandon", function(index)
	Remotes.RequestQuestAction:FireServer("abandon", index)
end)

gui:On("close", function()
	Remotes.RequestQuestAction:FireServer("close", 1)
end)

Remotes.QuestUpdate.OnClientEvent:Connect(function(data)
	if gui:IsOpen() then
		gui:Render(data)
	else
		gui:Show(data)
	end
end)

-- ความคืบหน้าเปลี่ยนได้ตลอดขณะเปิดอยู่ (ฆ่ามอน เก็บของ) จึงถามใหม่เรื่อยๆ
--
-- **ถามเฉพาะตอนเปิด** ปิดแล้วไม่ถาม ไม่งั้นทุกคนในเซิร์ฟเวอร์จะยิงคำขอทุกวินาทีตลอดเวลา
task.spawn(function()
	while true do
		task.wait(1)
		if gui:IsOpen() then
			Remotes.RequestQuestAction:FireServer("refresh", 1)
		end
	end
end)

-- ตายหรือเกิดใหม่ = ปิดหน้าต่าง ไม่งั้นค้างอยู่หน้าจอทั้งที่เดินออกมาไกลแล้ว
player.CharacterRemoving:Connect(function()
	if gui:IsOpen() then gui:Hide() end
end)
