-- VipGiftController: ปุ่มของขวัญที่หุ่นฟาง **รายคน** (2026-09-27: 150 เพชรบัญชีใหม่ · VIP ที่ Lv.5 · ออร่าเมื่อมีเพื่อน 5 คน)
-- ป้าย = สิ่งที่คนนี้กดแล้วได้เลย ("รับ 150 เพชร + VIP 30 วัน") หรือ "ดูของขวัญ" ถ้ายังติดเงื่อนไข (กดแล้วบอกว่าขาดอะไร)
-- **ซ่อนเมื่อไม่เหลืออะไรให้รับอีกแล้ว** · Enabled/ActionText ที่ไคลเอนต์ตั้งไม่ replicate คนอื่นเห็นปุ่มตามสิทธิ์ของตัวเอง
-- เซิร์ฟเวอร์ตรวจซ้ำทุกครั้งที่กด · ลูป 0.5 วิ (กฎเหล็ก StreamingEnabled: ปุ่มกับแอตทริบิวต์มาถึงไม่พร้อมกัน)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

while true do
	local left = player:GetAttribute("WOLD_GiftLeft")
	local text = player:GetAttribute("WOLD_GiftText")
	-- ยังไม่ประกาศ = โชว์ไว้ก่อน (ปุ่มเกินยังกดแล้วได้เหตุผล ปุ่มหายคือปริศนา)
	local show = left == nil or left > 0
	for _, prompt in ipairs(CollectionService:GetTagged("WOLD_VipGiftPrompt")) do
		if prompt.Enabled ~= show then prompt.Enabled = show end
		if type(text) == "string" and prompt.ActionText ~= text then prompt.ActionText = text end
	end
	task.wait(0.5)
end
