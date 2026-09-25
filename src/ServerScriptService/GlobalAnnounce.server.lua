-- GlobalAnnounce.server: รับประกาศข้ามเซิร์ฟ (Announce.Global) แล้วส่งต่อให้ทุกคนในเซิร์ฟนี้
-- รันทุกเพลส (หลัก เกาะ สนาม ล็อบบี้) — "ทุกเซิร์ฟเห็น" ตามที่ผู้ใช้สั่ง · ห่อ pcall: บริการล่มแล้วเซิร์ฟต้องบูตต่อได้
local MessagingService = game:GetService("MessagingService")
local Announce = require(game.ServerScriptService.Announce)
local Remotes = require(game.ReplicatedStorage.Remotes)

local ok, err = pcall(function()
	MessagingService:SubscribeAsync(Announce.Topic, function(message)
		local data = message and message.Data
		if type(data) ~= "table" or type(data.text) ~= "string" then return end
		Remotes.GlobalAnnounce:FireAllClients(data.text, type(data.kind) == "string" and data.kind or "info")
	end)
end)
if not ok then warn("[GlobalAnnounce] สมัครรับประกาศไม่ได้:", err) end
