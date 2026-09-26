-- VipGiftController: ซ่อนปุ่ม "รับ VIP" ที่หุ่นฟางจากคนที่รับไม่ได้ (มี VIP อยู่ / บัญชีนี้รับแล้ว) — รายคน
-- Enabled ที่ไคลเอนต์ตั้งไม่ replicate คนอื่นยังเห็นปุ่มตามสิทธิ์ของตัวเอง · เซิร์ฟเวอร์ตรวจซ้ำทุกครั้งที่กด
-- ลูป 0.5 วิ (กฎเหล็ก StreamingEnabled: ปุ่มกับแอตทริบิวต์มาถึงไม่พร้อมกัน)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

while true do
	local claimed = player:GetAttribute("WOLD_VipGiftClaimed")
	local vipUntil = player:GetAttribute("VipUntil")
	-- ยังไม่ประกาศ = โชว์ไว้ก่อน (ปุ่มเกินยังกดแล้วได้เหตุผล ปุ่มหายคือปริศนา)
	local show = true
	if claimed ~= nil and vipUntil ~= nil then
		show = claimed ~= true and vipUntil <= workspace:GetServerTimeNow()
	end
	for _, prompt in ipairs(CollectionService:GetTagged("WOLD_VipGiftPrompt")) do
		if prompt.Enabled ~= show then prompt.Enabled = show end
	end
	task.wait(0.5)
end
