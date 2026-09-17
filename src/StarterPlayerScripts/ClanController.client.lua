-- ClanController: ต่อหน้าต่างสมาคมแคลนเข้ากับเซิร์ฟเวอร์
--
-- บางมาก เพราะเซิร์ฟเวอร์เป็นเจ้าของทุกอย่าง — แคลนอยู่ใน DataStore ร่วมกันทั้งเกม ไคลเอนต์เดาอะไรเองไม่ได้เลย
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local ClanGui = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("ClanGui"))

local player = Players.LocalPlayer
local gui = ClanGui.new()

local function act(action, a, b)
	Remotes.RequestClanAction:FireServer(action, a, b)
end

gui:On("create", function(name, blurb) act("create", name, blurb) end)
gui:On("join", function(clanId) act("join", clanId) end)
gui:On("leave", function() act("leave") end)
gui:On("donate", function(amount) act("donate", amount) end)
gui:On("distribute", function(amount, target) act("distribute", amount, target) end)
-- คลังแคลน: หน้าต่างของมันเองยังไม่ได้ทำ (รอบถัดไป) แต่ฝั่งเซิร์ฟเวอร์เก็บของได้แล้ว
-- บอกให้ชัดว่ายังไม่เปิด ดีกว่าปุ่มที่กดแล้วเงียบ
gui:On("openvault", function()
	act("refresh")
end)

Remotes.ClanUpdate.OnClientEvent:Connect(function(data)
	if gui:IsOpen() then
		gui:Render(data)
	else
		gui:Show(data)
	end
end)

player.CharacterRemoving:Connect(function()
	if gui:IsOpen() then gui:Hide() end
end)
