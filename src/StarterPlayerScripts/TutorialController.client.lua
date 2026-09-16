-- TutorialController: เปิดปุ่มสอนเล่นให้ผู้เล่นในเซิร์ฟเวอร์ช่อง
--
-- ไม่มีอะไรมากกว่า "สร้างมันขึ้นมา" เพราะสมุดไม่ต้องคุยกับเซิร์ฟเวอร์เลย — เนื้อหาทั้งหมดอยู่ใน
-- TutorialConfig ซึ่ง replicate ถึงไคลเอนต์อยู่แล้ว
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local TutorialGui = require(game.ReplicatedStorage.UI.TutorialGui)
TutorialGui.new()
