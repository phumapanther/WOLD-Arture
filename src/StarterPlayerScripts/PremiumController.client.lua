-- PremiumController: ต่อหน้ารวมร้านพรีเมียม/กาชา/แบทเทิลพาสเข้ากับเซิร์ฟเวอร์
--
-- เปิดจากปุ่มในเมนูสามจุด (HudController ยิง BindableEvent WOLD_OpenPremium พร้อมชื่อแท็บ)
-- ทุกการกดส่งไปเซิร์ฟเวอร์ แล้ววาดใหม่จากภาพที่เซิร์ฟเวอร์ตอบ — ราคา/สระอ่านจาก PremiumConfig เอง
while workspace:GetAttribute("IsLobby") == nil do task.wait() end
if workspace:GetAttribute("IsLobby") then return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local PremiumGui = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("PremiumGui"))

local player = Players.LocalPlayer
local gui = PremiumGui.new()
local latest = { gems = 0 }

gui:On("buy", function(id) Remotes.RequestPremium:FireServer("buy", id) end)
gui:On("pull", function(banner, times) Remotes.RequestPremium:FireServer("pull", banner, times) end)
gui:On("claim", function(tier, track) Remotes.RequestPremium:FireServer("claim", tier, track) end)
gui:On("unlockpass", function() Remotes.RequestPremium:FireServer("unlockpass") end)
gui:On("buygems", function(index) Remotes.RequestPremium:FireServer("buygems", index) end)

Remotes.PremiumUpdate.OnClientEvent:Connect(function(data)
	-- /gems ส่งมาแค่ก้อนเล็ก { gems } ให้รวมกับภาพเดิม ไม่ให้สถานะพาสหาย
	for k, v in pairs(data) do latest[k] = v end
	if data.gacha then
		latest.gacha = nil
		if gui:IsOpen() then gui:ShowResults(data.gacha.results or {}) end
	end
	if gui:IsOpen() then gui:Render(latest) end
end)

local opener = player:WaitForChild("PlayerGui"):WaitForChild("WOLD_OpenPremium", 30)
if opener then
	opener.Event:Connect(function(tab)
		gui:Show(tab, latest)
		Remotes.RequestPremium:FireServer("refresh")
	end)
end

Remotes.RequestPremium:FireServer("refresh")
