-- ClanController: ต่อหน้าต่างสมาคมแคลนเข้ากับเซิร์ฟเวอร์
--
-- บางมาก เพราะเซิร์ฟเวอร์เป็นเจ้าของทุกอย่าง — แคลนอยู่ใน DataStore ร่วมกันทั้งเกม ไคลเอนต์เดาอะไรเองไม่ได้เลย
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local ClanGui = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("ClanGui"))
local ClanVaultGui = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("ClanVaultGui"))

local player = Players.LocalPlayer
local gui = ClanGui.new()
local vault = ClanVaultGui.new()

-- ช่องกระเป๋าล่าสุด ใช้วาดฝั่งขวาของคลัง
local bagSlots = nil
-- แคลนล่าสุด เก็บไว้เพราะคลังเปิดคนละหน้าต่างกับหน้าแคลน
local lastClan = nil

local function act(action, a, b)
	Remotes.RequestClanAction:FireServer(action, a, b)
end

gui:On("create", function(name, blurb) act("create", name, blurb) end)
gui:On("join", function(clanId) act("join", clanId) end)
gui:On("cancelapply", function() act("cancelapply") end)
gui:On("approve", function(userId) act("approve", userId) end)
gui:On("reject", function(userId) act("reject", userId) end)
gui:On("leave", function() act("leave") end)
gui:On("disband", function() act("disband") end)
gui:On("donate", function(amount) act("donate", amount) end)
gui:On("distribute", function(amount, target) act("distribute", amount, target) end)
-- คลังแคลน: หน้าต่างของมันเองยังไม่ได้ทำ (รอบถัดไป) แต่ฝั่งเซิร์ฟเวอร์เก็บของได้แล้ว
-- บอกให้ชัดว่ายังไม่เปิด ดีกว่าปุ่มที่กดแล้วเงียบ
gui:On("openvault", function()
	if lastClan then
		vault:Show(lastClan, bagSlots)
	end
end)

vault:On("put", function(bagIndex)
	act("vaultput", bagIndex, 1)
end)

vault:On("take", function(index)
	act("vaulttake", index)
end)

-- ปิดคลังแล้วขอภาพใหม่ หน้าแคลนจะได้โชว์จำนวนช่องที่ถูกต้อง
vault:On("close", function()
	act("refresh")
end)

Remotes.ClanUpdate.OnClientEvent:Connect(function(data)
	lastClan = data and data.mine or nil
	if gui:IsOpen() then
		gui:Render(data)
	elseif not vault:IsOpen() then
		-- เปิดหน้าแคลนเฉพาะตอนที่ยังไม่มีหน้าต่างของแคลนเปิดอยู่ — ไม่งั้นการวาดคลังใหม่หลังหยิบของ
		-- จะเด้งหน้าแคลนขึ้นมาทับคลังที่กำลังใช้อยู่
		gui:Show(data)
	end
	-- คลังเปิดอยู่ก็วาดใหม่ทันที ของที่เพิ่งหยิบ/ใส่จะได้เห็นผล
	if vault:IsOpen() then
		vault:SetVault(lastClan)
		vault:SetBag(bagSlots)
	end
end)

-- กระเป๋าเปลี่ยนจากทางอื่นระหว่างเปิดคลังอยู่ ก็ต้องวาดตาม
Remotes.InventoryUpdate.OnClientEvent:Connect(function(state)
	bagSlots = state and state.slots or nil
	if vault:IsOpen() then vault:SetBag(bagSlots) end
end)

player.CharacterRemoving:Connect(function()
	if gui:IsOpen() then gui:Hide() end
	if vault:IsOpen() then vault:Hide() end
end)
