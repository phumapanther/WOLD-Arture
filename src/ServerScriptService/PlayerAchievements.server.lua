-- PlayerAchievements.server: ลูปปลดความสำเร็จ + ประกาศฉายาบนหัว + รับการเลือกฉายา
-- (สเปก docs/superpowers/specs/2026-09-25-achievements-design.md)
--
-- **ลูปถามใหม่ทุก 2 วิ ไม่ผูกกับเหตุการณ์** — สถิติมาจากหลายระบบ (มอน ปลา เลเวล ตีบวก ข้อความจากสนาม/บอส)
-- ผูกทีละเหตุการณ์คือการลืมสักที่แล้วปลดไม่ขึ้น ส่วนหัวแดงหมดเวลาเองโดยไม่มีสัญญาณบอก ต้องถามอยู่ดี
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby or ServerConfig.IsArena then return end

local Achievements = require(game.ServerScriptService.Achievements)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)

local TICK = 2

-- ฉายาบนหัวประกาศเป็นแอตทริบิวต์บนตัวผู้เล่น (TitleTagController ของทุกเครื่องวาดเอง) · เขียนเฉพาะตอนเปลี่ยน
local function publish(player)
	local text, color = Achievements.DisplayTitle(player)
	if player:GetAttribute("WOLD_Title") ~= text then player:SetAttribute("WOLD_Title", text) end
	if player:GetAttribute("WOLD_TitleColor") ~= color then player:SetAttribute("WOLD_TitleColor", color) end
end

local function tick(player)
	if not ProfileAccess.Get(player) then return end
	for _, def in ipairs(Achievements.Check(player)) do
		Remotes.SocialNotify:FireClient(player, "info",
			("🏆 ปลดความสำเร็จ \"%s\" — %s · ได้ฉายา + เพชร %d"):format(def.title, def.desc, def.gems))
	end
	publish(player)
end

task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			local ok, err = pcall(tick, player)
			if not ok then warn("[Achievements]", player.Name, err) end
		end
		task.wait(TICK)
	end
end)

-- เลือกฉายา ("" = ไม่ใช้) แล้วส่งภาพสมุดสะสมใหม่ให้ปุ่มเปลี่ยนตาม
Remotes.RequestTitle.OnServerEvent:Connect(function(player, id)
	if id ~= nil and type(id) ~= "string" then return end
	if not Achievements.SetTitle(player, id) then
		return Remotes.SocialNotify:FireClient(player, "warn", "ยังใช้ฉายานี้ไม่ได้")
	end
	publish(player)
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	if Achievements.OnChanged then Achievements.OnChanged(player) end
end)
