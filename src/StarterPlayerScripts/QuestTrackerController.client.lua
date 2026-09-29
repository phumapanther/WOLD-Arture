-- QuestTrackerController: แถบเควสรวม (2026-09-29) — รวมแถวทอง/ฟ้า (StoryState.rows จาก Story.server · เกมหลัก)
-- กับแถวขาว (QuestLogBoard จาก Quests.server · เกมหลัก + เกาะ) แล้ววาด · จิ้ม = ขอเป้าจากเซิร์ฟ (StreamingEnabled)
-- แล้วปักหมุดผ่าน Navigation.Active (คอมกด T เดินตามได้) · จิ้มแถวที่นำทางอยู่ซ้ำ = เลิก · ล็อก/รอ = บอกเหตุผล
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

while workspace:GetAttribute("IsLobby") == nil do task.wait(0.2) end
if workspace:GetAttribute("IsLobby") == true then return end
if workspace:GetAttribute("ArenaMode") == true then return end

local Remotes = require(ReplicatedStorage.Remotes)
local Navigation = require(ReplicatedStorage.Navigation)
local QuestLogRules = require(ReplicatedStorage.QuestLogRules)
local QuestTrackerGui = require(ReplicatedStorage.UI.QuestTrackerGui)
local UiSound = require(ReplicatedStorage.UI.UiSound)

local player = Players.LocalPlayer
local gui = QuestTrackerGui.new(player:WaitForChild("PlayerGui"))
local storyRows, boardRows = {}, {}
local navKey, pendingKey = nil, nil

local function toast(text)
	local channel = ReplicatedStorage:FindFirstChild("WOLD_Toast")
	if channel then channel:Fire(text) end
end

local function redraw()
	gui:SetRows(QuestLogRules.Merge(storyRows, boardRows), navKey)
end

Remotes.StoryState.OnClientEvent:Connect(function(state)
	storyRows = (type(state) == "table" and state.rows) or {}
	redraw()
end)

Remotes.QuestLogBoard.OnClientEvent:Connect(function(rows)
	boardRows = rows or {}
	redraw()
end)

gui.onTap = function(row)
	UiSound.Play("Click")
	if QuestLogRules.Dim(row) then return toast(QuestLogRules.DenyText(row)) end
	local nav = Navigation.Active
	if navKey == row.key and nav and nav:HasDestination() then
		nav:Clear()
		navKey = nil
		toast("เลิกนำทางแล้ว")
		return redraw()
	end
	pendingKey = row.key
	Remotes.RequestQuestNav:FireServer(row.key)
end

Remotes.QuestNav.OnClientEvent:Connect(function(position, label)
	local nav = Navigation.Active
	if not nav then return toast("แผนที่ยังไม่พร้อม ลองใหม่อีกครั้ง") end
	local ok, message = nav:SetDestination(position, label)
	if ok then
		navKey = pendingKey
		local hint = UserInputService.KeyboardEnabled and " — กด T เพื่อเดินอัตโนมัติ" or ""
		toast(("🧭 นำทางไป %s%s"):format(label ~= "" and label or "จุดหมาย", hint))
	else
		toast(message or "นำทางไปจุดนั้นไม่ได้")
	end
	redraw()
end)

-- หมุดหาย (ถึงแล้ว/ลบเอง) = แถวเลิกขึ้น 🧭
task.spawn(function()
	while true do
		task.wait(1)
		local nav = Navigation.Active
		if navKey and not (nav and nav:HasDestination()) then
			navKey = nil
			redraw()
		end
	end
end)

-- ขอแถวงานบอร์ดหลังจอโหลดจบ (สองครั้ง: เผื่อโปรไฟล์ยังโหลดไม่เสร็จรอบแรก)
task.spawn(function()
	while player:GetAttribute("WOLD_Loaded") ~= true do task.wait(0.25) end
	Remotes.RequestQuestAction:FireServer("log")
	task.wait(5)
	Remotes.RequestQuestAction:FireServer("log")
end)
