-- TownVaultController: หน้าต่างคลังเมือง + **การซ่อนปุ่มที่คนนี้ใช้ไม่ได้**
--
-- ProximityPrompt มี `Enabled` ตัวเดียวสำหรับผู้เล่นทุกคน การซ่อนรายคนจึงทำได้ทางเดียวคือให้ไคลเอนต์
-- ปิดของตัวเอง (คุณสมบัติที่ไคลเอนต์เขียนไม่ replicate กลับ) — ทรงเดียวกับที่ `GatherController`
-- ซ่อนปุ่มเก็บของที่ต้องใช้เครื่องมือซึ่งคนนั้นไม่ได้ถือ
--
-- กติกาที่ผู้ใช้กำหนด (2026-09-19) อ่านจากสองค่า: แคลนของเราบนตัว Player กับเจ้าของเมืองบนโมเดล
--
--   ไม่มีแคลน               → ไม่เห็นปุ่มอะไรเลย
--   มีแคลน แต่ไม่ได้ถือเมือง → เห็นแค่ [E] ยึดเมือง
--   อยู่แคลนที่ถือเมืองอยู่   → เห็นแค่ [F] คลังเมือง
--
-- **นี่คือการซ่อน ไม่ใช่การกันสิทธิ์** เซิร์ฟเวอร์ตรวจซ้ำทุกครั้งที่มีคนกด (`TownVault.server`)
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage.Remotes)
local TownVaultGui = require(game.ReplicatedStorage.UI.TownVaultGui)

local player = Players.LocalPlayer
local gui = TownVaultGui.new()

local currentTown = nil -- เมืองที่หน้าต่างกำลังเปิดอยู่
local bagSlots = nil

gui:On("put", function(bagIndex)
	if currentTown then Remotes.RequestTownVault:FireServer("put", currentTown, bagIndex, 1) end
end)

gui:On("take", function(index)
	if currentTown then Remotes.RequestTownVault:FireServer("take", currentTown, index) end
end)

gui:On("close", function()
	if currentTown then Remotes.RequestTownVault:FireServer("close", currentTown) end
	currentTown = nil
end)

Remotes.TownVaultUpdate.OnClientEvent:Connect(function(data)
	if not data then return end
	currentTown = data.townId
	if gui:IsOpen() then
		gui:SetVault(data)
		gui:SetBag(bagSlots)
	else
		gui:Show(data, bagSlots)
	end
end)

Remotes.InventoryUpdate.OnClientEvent:Connect(function(state)
	bagSlots = state and state.slots or nil
	if gui:IsOpen() then gui:SetBag(bagSlots) end
end)

player.CharacterRemoving:Connect(function()
	if gui:IsOpen() then gui:Hide() end
end)

--------------------------------------------------------------------------------
-- ซ่อน/โชว์ปุ่มที่อนุสาวรีย์
--
-- อ่านจาก **ตัวปุ่มเอง** ผ่านแท็ก `WOLD_TownPrompt` ไม่ใช่ไล่หาโมเดล `Landmark_*` ในแมพ:
-- ภายใต้ StreamingEnabled โมเดลมาถึงคนละรอบและการค้นหาจากชื่อได้คำตอบไม่แน่นอน ส่วนแท็กมากับตัวปุ่ม
-- ซึ่งเป็นสิ่งเดียวกับที่เราจะเปิด/ปิด
--
-- **ทุกความไม่แน่ใจต้องเอนไปทาง "โชว์" ไม่ใช่ "ซ่อน"** — ค่าที่ยังไม่ถูกประกาศเป็น nil (ต่างจาก `""`
-- ที่แปลว่า "ไม่มีแคลน"/"ไม่มีใครถือเมือง") เจอ nil เมื่อไหร่ปล่อยปุ่มไว้อย่างนั้น ไม่แตะ: ปุ่มที่ขึ้นเกิน
-- ยังกดแล้วโดนเซิร์ฟเวอร์ปฏิเสธพร้อมเหตุผล ส่วนปุ่มที่หายไปทั้งเกมคือสิ่งที่ไม่มีใครเดาถูกว่าเกิดอะไรขึ้น
--------------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local PROMPT_TAG = "WOLD_TownPrompt"

-- เตือนครั้งเดียวต่อสาเหตุ ลง F9 — ถ้าวันหน้าปุ่มเพี้ยนอีก จะได้รู้ทันทีว่าค่าไหนหาย ไม่ต้องเดา
local warned = {}
local function warnOnce(key, message)
	if warned[key] then return end
	warned[key] = true
	warn("[TownVault] " .. message)
end

local function refreshTownPrompts()
	local raw = player:GetAttribute("ClanId")
	if raw == nil then
		warnOnce("clan", "ยังไม่มีแอตทริบิวต์ ClanId บนตัวผู้เล่น (Clans.server ยังไม่ประกาศ) — ปล่อยปุ่มไว้ตามเดิม")
		return
	end
	local myClan = raw ~= "" and raw or nil

	for _, prompt in ipairs(CollectionService:GetTagged(PROMPT_TAG)) do
		if prompt:IsA("ProximityPrompt") and prompt.Parent then
			local owner = prompt:GetAttribute("OwnerClanId")
			if owner == nil then
				warnOnce("owner", ("ปุ่ม %s ยังไม่มีแอตทริบิวต์ OwnerClanId — ปล่อยไว้ตามเดิม"):format(prompt.Name))
			else
				if owner == "" then owner = nil end
				local isOwner = myClan ~= nil and owner ~= nil and myClan == owner
				if prompt.Name == "CapturePrompt" then
					-- ไม่มีแคลน = ยึดไม่ได้อยู่แล้ว · เจ้าของเมืองก็ไม่ต้องยึดเมืองตัวเอง
					prompt.Enabled = myClan ~= nil and not isOwner
				elseif prompt.Name == "TownVaultPrompt" then
					prompt.Enabled = isOwner
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		refreshTownPrompts()
		task.wait(1)
	end
end)

-- ปุ่มที่เพิ่งสตรีมเข้ามาได้คำตอบทันที ไม่ต้องรอรอบลูปถัดไป
CollectionService:GetInstanceAddedSignal(PROMPT_TAG):Connect(function()
	task.defer(refreshTownPrompts)
end)

-- เข้า/ออกแคลนแล้วปุ่มต้องสลับทันที ไม่ใช่รอถึงวินาทีถัดไป
player:GetAttributeChangedSignal("ClanId"):Connect(refreshTownPrompts)
