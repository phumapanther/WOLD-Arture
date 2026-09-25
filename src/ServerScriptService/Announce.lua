-- Announce: ประกาศข้ามเซิร์ฟ (ผู้ใช้สั่ง 2026-09-25 — ระบบที่ 2 ของชุด MMO เอาแค่ประกาศ ไม่ทำแชทแคลน)
--
-- ประกาศสามอย่าง: ยึดเมืองได้ · ปลดความสำเร็จระดับตำนาน · ตีบวก +8 ขึ้นไปสำเร็จ → แถบเลื่อนบนสุดของจอทุกเซิร์ฟ
-- ส่งผ่าน MessagingService หัวข้อเดียว · ตัวรับอยู่ที่ GlobalAnnounce.server (ทุกเซิร์ฟ รวมเซิร์ฟที่ส่งเอง)
local MessagingService = game:GetService("MessagingService")
local TextService = game:GetService("TextService")
local Remotes = require(game.ReplicatedStorage.Remotes)

local Announce = {}

Announce.Topic = "WOLD_Announce"
Announce.MaxLength = 160

-- ข้อความที่ **ผู้เล่นพิมพ์เอง** (ชื่อแคลน) ต้องผ่านตัวกรองของ Roblox ก่อนไปโผล่ทุกเซิร์ฟ · yield · ล้ม = nil (ไม่ประกาศ)
-- ชื่อที่แสดง (DisplayName) กับข้อความที่เกมเขียนเองไม่ต้องกรอง
function Announce.Filter(text, fromUserId)
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, fromUserId, Enum.TextFilterContext.PublicChat)
			:GetNonChatStringForBroadcastAsync()
	end)
	return ok and result or nil
end

-- ประกาศไปทุกเซิร์ฟ · `kind` = "town" | "legend" | "enhance" (สีของแถบ) · ไม่ yield ผู้เรียก
function Announce.Global(text, kind)
	if type(text) ~= "string" or text == "" then return end
	local payload = { text = text:sub(1, Announce.MaxLength * 3), kind = kind or "info" }
	task.spawn(function()
		local ok, err = pcall(MessagingService.PublishAsync, MessagingService, Announce.Topic, payload)
		if not ok then
			-- ส่งข้ามเซิร์ฟไม่ได้ (โควตา/บริการล่ม) อย่างน้อยเซิร์ฟนี้ยังเห็น
			warn("[Announce] PublishAsync ล้ม:", err)
			Remotes.GlobalAnnounce:FireAllClients(payload.text, payload.kind)
		end
	end)
end

return Announce
