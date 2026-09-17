-- TownBuyerController: ต่อหน้าต่างพ่อค้าประจำเมืองเข้ากับเซิร์ฟเวอร์
--
-- บางมาก เซิร์ฟเวอร์เป็นเจ้าของราคาและการกรองของทั้งหมด — ราคาขึ้นกับว่าแคลนไหนยึดเมืองอยู่
-- ซึ่งไคลเอนต์ไม่มีทางรู้เอง
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local TownBuyerGui = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("TownBuyerGui"))

local player = Players.LocalPlayer
local gui = TownBuyerGui.new()

gui:On("sell", function(index, amount)
	Remotes.RequestTownSell:FireServer("sell", index, amount)
end)

gui:On("close", function()
	Remotes.RequestTownSell:FireServer("close")
end)

Remotes.TownBuyerUpdate.OnClientEvent:Connect(function(data)
	if gui:IsOpen() then
		gui:Render(data)
	else
		gui:Show(data)
	end
end)

-- กระเป๋าเปลี่ยนจากทางอื่นระหว่างเปิดอยู่ ก็ขอภาพใหม่
--
-- ไม่ได้วาดเองจาก InventoryUpdate เพราะหน้านี้โชว์เฉพาะของที่เมืองนี้รับซื้อ ซึ่งเป็นการกรองที่
-- เซิร์ฟเวอร์ทำ ไคลเอนต์ทำเองไม่ได้
Remotes.InventoryUpdate.OnClientEvent:Connect(function()
	if gui:IsOpen() then
		Remotes.RequestTownSell:FireServer("refresh")
	end
end)

player.CharacterRemoving:Connect(function()
	if gui:IsOpen() then gui:Hide() end
end)
