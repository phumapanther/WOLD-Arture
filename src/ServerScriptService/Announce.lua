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

-- ข้อความส่วนตัว (นกพิราบ) — กรองแบบแชทส่วนตัวให้ผู้รับคนนั้น · ล้ม = nil (ไม่ส่ง)
function Announce.FilterFor(text, fromUserId, toUserId)
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, fromUserId, Enum.TextFilterContext.PrivateChat)
			:GetChatForUserAsync(toUserId)
	end)
	return ok and result or nil
end

-- ตัดข้อความให้ไม่เกิน `maxBytes` ที่ขอบตัวอักษร — ไทย 3 ไบต์ต่อตัว `:sub` เฉยๆ ผ่ากลางตัวอักษรแล้ว UTF-8 เสีย
-- ซึ่งตัวกรองของ Roblox ปฏิเสธ (โพสต์ไทยยาวๆ จะถูกปัดตกทั้งที่ไม่ได้ผิดอะไร)
function Announce.Trim(text, maxBytes)
	if #text <= maxBytes then return text end
	text = text:sub(1, maxBytes)
	while #text > 0 and not utf8.len(text) do text = text:sub(1, -2) end
	return text
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
