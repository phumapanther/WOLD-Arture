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
gui:On("buyvip", function() Remotes.RequestPremium:FireServer("buyvip") end)

Remotes.PremiumUpdate.OnClientEvent:Connect(function(data)
	-- /gems ส่งมาแค่ก้อนเล็ก { gems } ให้รวมกับภาพเดิม ไม่ให้สถานะพาสหาย
	for k, v in pairs(data) do latest[k] = v end
	if data.gacha then
		latest.gacha = nil
		if gui:IsOpen() then gui:ShowResults(data.gacha.results or {}) end
	end
	if gui:IsOpen() then gui:Render(latest) end
end)

-- **หน้าต่างนี้เป็นเจ้าของ BindableEvent เอง ไม่ใช่รอให้ HudController สร้างให้**
--
-- ของเดิมคือ `WaitForChild("WOLD_OpenPremium", 30)` ซึ่งเงียบสนิทเมื่อหมดเวลา (`if opener then`) — ถ้า
-- HudController ไปถึงบรรทัดที่สร้างช้ากว่า 30 วิ (เกมจริงโหลดนานกว่า Studio มาก) หน้าจอนี้จะไม่ผูกอะไรเลย
-- ปุ่มทั้งสามในเมนูสามจุดกดแล้วจึงไม่มีอะไรขึ้น **และไม่มี error ให้เห็น** — อาการเดียวกับกฎเหล็ก
-- StreamingEnabled ใน CLAUDE.md
--
-- ทรงที่ใช้ได้จริงในเกมนี้คือทรงเดียวกับ `WOLD_ToggleInventory`/`WOLD_RequestAction`: **เจ้าของหน้าต่าง
-- สร้างช่องทาง ฝั่งที่กดปุ่มไปหยิบตอนกด** (`FindFirstChild` ตอนคลิก) ไม่มีใครต้องรอใคร
local pg = player:WaitForChild("PlayerGui")
local opener = pg:FindFirstChild("WOLD_OpenPremium")
if not opener then
	opener = Instance.new("BindableEvent")
	opener.Name = "WOLD_OpenPremium"
	opener.Parent = pg
end
opener.Event:Connect(function(tab)
	gui:Show(tab, latest)
	Remotes.RequestPremium:FireServer("refresh")
end)

Remotes.RequestPremium:FireServer("refresh")
