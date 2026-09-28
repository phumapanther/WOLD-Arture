-- PvpRankPublisher.server: แร็งก์ PVP ของคนในเซิร์ฟนี้ → แอตทริบิวต์บนตัวผู้เล่น (เฟส 3 · เกมหลัก + เกาะ)
--
-- `WOLD_PvpTier` (ขั้น 1-6 · ไม่มี = ไม่เคยเล่นแร็งก์) · `WOLD_PvpPoints` — อ่านจาก PvpRankStore (DataStore คีย์ของตัวเอง)
-- ใช้ที่: ฉายาแร็งก์ (`Achievements` — เลือกได้เฉพาะขั้นปัจจุบัน หายเมื่อแร็งก์เปลี่ยน) · กรอบการ์ดโปรไฟล์ (PlayerSocial)
-- แต้มเปลี่ยนแค่ในเพลสสนาม และทุกคนกลับจากสนามผ่านล็อบบี้แล้วเข้าเซิร์ฟใหม่ = อ่านตอนเข้า + ทุก 10 นาที (จบซีซันกลางเซสชัน) พอ
local Players = game:GetService("Players")

local ServerConfig = require(script.Parent.ServerConfig)
if ServerConfig.IsLobby or ServerConfig.IsArena then return end

local PvpRankStore = require(script.Parent.PvpRankStore)
local PvpRankConfig = require(game.ReplicatedStorage.PvpRankConfig)

local function refresh(player)
	-- แร็งก์ล็อกอยู่ = ไม่มีฉายา/กรอบแร็งก์ (ล้างแอตทริบิวต์ ทั้งสองระบบอ่านจากตรงนี้)
	if not PvpRankConfig.Enabled then
		player:SetAttribute("WOLD_PvpTier", nil)
		player:SetAttribute("WOLD_PvpPoints", nil)
		return
	end
	local r = PvpRankStore.Read(player.UserId)
	if not r or not player.Parent then return end
	local tier = r.played and PvpRankConfig.TierIndex(r.p) or nil
	if player:GetAttribute("WOLD_PvpTier") ~= tier then player:SetAttribute("WOLD_PvpTier", tier) end
	if player:GetAttribute("WOLD_PvpPoints") ~= (r.played and r.p or nil) then
		player:SetAttribute("WOLD_PvpPoints", r.played and r.p or nil)
	end
end

local function watch(player)
	task.spawn(function()
		while player.Parent do
			pcall(refresh, player)
			task.wait(600)
		end
	end)
end

Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do watch(player) end
