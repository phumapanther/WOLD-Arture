-- StorageChestController: ต่อหน้าต่างหีบเก็บของเข้ากับเซิร์ฟเวอร์
--
-- บางมาก เพราะเซิร์ฟเวอร์เป็นเจ้าของทุกอย่าง: ไคลเอนต์ส่งแค่ "ใส่ช่องนี้" กับ "หยิบช่องนี้" แล้วรอภาพใหม่
-- ไม่เดาผลลัพธ์เอง ของในหีบเป็นสถานะร่วม คนอื่นอาจหยิบไปแล้วระหว่างที่เรากำลังกด
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local StorageChestGui = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("StorageChestGui"))

local player = Players.LocalPlayer
local gui = StorageChestGui.new()

-- ช่องกระเป๋าล่าสุดที่เซิร์ฟเวอร์ส่งมา ใช้วาดฝั่งขวา
local bagSlots = nil

gui:On("put", function(index, count)
	Remotes.RequestStorageChestPut:FireServer(index, count)
end)

gui:On("take", function(index, count)
	Remotes.RequestStorageChestTake:FireServer(index, count)
end)

gui:On("close", function()
	Remotes.RequestStorageChestClose:FireServer()
end)

Remotes.StorageChestOpen.OnClientEvent:Connect(function()
	gui:SetBag(bagSlots)
	gui:Show()
end)

Remotes.StorageChestUpdate.OnClientEvent:Connect(function(contents, slotCount)
	gui:SetChest(contents, slotCount)
	-- วาดกระเป๋าใหม่ด้วย: การใส่ของลงหีบเปลี่ยนกระเป๋าเราเสมอ
	gui:SetBag(bagSlots)
end)

-- กระเป๋าเปลี่ยนจากทางอื่น (กิน ทิ้ง เทรด) ระหว่างเปิดหีบอยู่ ก็ต้องวาดตาม
Remotes.InventoryUpdate.OnClientEvent:Connect(function(state)
	bagSlots = state and state.slots or nil
	if gui:IsOpen() then gui:SetBag(bagSlots) end
end)

-- ตายหรือเกิดใหม่ = ปิดหน้าต่างทิ้ง ไม่งั้นค้างอยู่หน้าจอโดยที่ตัวละครเดินไปไหนแล้วก็ไม่รู้
player.CharacterRemoving:Connect(function()
	if gui:IsOpen() then gui:Hide() end
end)
