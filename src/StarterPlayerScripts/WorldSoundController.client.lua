-- เล่นเสียงในโลกที่เซิร์ฟเวอร์สั่ง (`WorldSound.At`) ตรงจุดนั้น ได้ยินตามระยะ (QA 2026-09-28)
-- ชื่อเสียงต้องอยู่ใน `SoundscapeConfig.Interface` — ชื่อที่ไม่มี = เงียบ (UiSound ข้ามให้เอง)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Remotes)
local UiSound = require(ReplicatedStorage.UI.UiSound)

Remotes.WorldSound.OnClientEvent:Connect(function(name, position, volumeScale, maxDistance)
	if type(name) ~= "string" or typeof(position) ~= "Vector3" then return end
	UiSound.PlayAt(name, position, tonumber(volumeScale) or 1, tonumber(maxDistance))
end)
