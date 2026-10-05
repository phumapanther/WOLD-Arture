-- PartyController: คำถาม "เข้าตี้ไหม" และแถบเลือด/ความหิวของเพื่อนร่วมตี้
--
-- ไม่ตัดสินอะไรเลย: คำเชิญมาจากเซิร์ฟเวอร์ คำตอบส่งกลับไปให้เซิร์ฟเวอร์ตัดสิน และสถานะตี้ที่วาดบนจอ
-- ก็เป็นภาพที่เซิร์ฟเวอร์ส่งมาทั้งก้อน ไคลเอนต์ไม่เคยเดาว่าใครอยู่ในตี้
--
-- หน้าต่างถาม-ตอบยืม `ClassActionGui:AskConsent` ซึ่งเป็นทรงเดียวกันเป๊ะ (คำถาม สองปุ่ม นาฬิกาที่ตอบ
-- "ไม่" ให้เองเมื่อหมดเวลา) — สร้างสำเนาของตัวเองแทนการไปยืมของ ClassActionController เพราะสองระบบ
-- ไม่ควรต้องรู้จักกัน และหน้าต่างมันถูกซ่อนอยู่จนกว่าจะถูกเรียกใช้อยู่แล้ว
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local Players = game:GetService("Players")
local ClassActionGui = require(game.ReplicatedStorage.UI.ClassActionGui)
local PartyGui = require(game.ReplicatedStorage.UI.PartyGui)
local Remotes = require(game.ReplicatedStorage.Remotes)
local UiSound = require(game.ReplicatedStorage.UI.UiSound)
local L = require(game.ReplicatedStorage.Locale).L

local party = PartyGui.new()
local ask = ClassActionGui.new()

party:OnLeave(function()
	Remotes.RequestPartyAction:FireServer("leave")
end)

Remotes.PartyStateChanged.OnClientEvent:Connect(function(members)
	party:SetMembers(members)
end)

-- คำเชิญหนึ่งใบต่อหนึ่งหน้าต่าง: ใบที่มาทีหลังทับใบเดิม (AskConsent ใช้แผงเดียวกัน) ซึ่งถูกแล้ว —
-- ใบเก่าหมดอายุเองที่เซิร์ฟเวอร์อยู่ดี และการมีหน้าต่างซ้อนกันสองบานคือสิ่งที่ไม่มีใครตอบถูก
Remotes.PartyInvite.OnClientEvent:Connect(function(fromUserId, fromName, seconds)
	UiSound.Play("Notification")
	ask:AskConsent(nil, seconds, L("%s ชวนคุณเข้าตี้", fromName), function(agreed)
		Remotes.RequestPartyAction:FireServer(agreed and "accept" or "decline", fromUserId)
	end)
end)

-- ตัวละครเกิดใหม่ไม่ได้ทำให้หลุดตี้ (สถานะอยู่ที่เซิร์ฟเวอร์) แต่ขอภาพใหม่ไว้ก่อนเผื่อแถบเพี้ยน
-- ระหว่างจอมืด — ขอผ่าน "leave" ไม่ได้ จึงใช้การส่งคำขอที่ไม่มีผลข้างเคียง
Players.LocalPlayer.CharacterAdded:Connect(function()
	Remotes.RequestPartyAction:FireServer("refresh")
end)
