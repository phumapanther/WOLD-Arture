-- IslandWelcomeController: ป้ายต้อนรับครั้งแรกบนเกาะ (เฉพาะเพลสเกาะ · StoryController ไม่รันบนเกาะ) — 2026-09-29
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

while workspace:GetAttribute("IsLobby") == nil do task.wait(0.2) end
if workspace:GetAttribute("IslandMode") ~= true then return end

local Remotes = require(ReplicatedStorage.Remotes)
local StoryConfig = require(ReplicatedStorage.StoryConfig)
local StoryGui = require(ReplicatedStorage.UI.StoryGui)
local UiSound = require(ReplicatedStorage.UI.UiSound)

local player = Players.LocalPlayer
local gui = nil
local shown = false

Remotes.StoryPlay.OnClientEvent:Connect(function(kind)
	if kind ~= "welcome" or shown then return end
	shown = true
	gui = gui or StoryGui.new(player:WaitForChild("PlayerGui"))
	UiSound.Play("CutTitle")
	gui:Banner("🏝️ " .. StoryConfig.SkyTitle, StoryConfig.SkySubtitle, 8)
	task.delay(1.5, function()
		gui:Say(StoryConfig.Dialogues.island_welcome)
	end)
end)

-- หลังจอโหลดจบ บอกเซิร์ฟ (ส่งซ้ำ: โปรไฟล์อาจยังโหลดไม่เสร็จ · เซิร์ฟตอบครั้งเดียว)
task.spawn(function()
	while player:GetAttribute("WOLD_Loaded") ~= true do task.wait(0.25) end
	for _ = 1, 6 do
		if shown then break end
		Remotes.RequestStory:FireServer("island_ready")
		task.wait(3)
	end
end)
