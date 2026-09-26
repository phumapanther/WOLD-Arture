-- VipGift: หุ่นฟางข้างจุดเกิดแรก (`Dummy_Spawn`) กด E รับ VIP ฟรี 30 วัน (ผู้ใช้สั่ง 2026-09-26)
--
-- กติกา: มี VIP อยู่ = รับไม่ได้ **และไม่เสียสิทธิ์** · บัญชีละครั้ง (ธง `VipGiftClaimed` ในโปรไฟล์ ซึ่งเป็นของทั้ง universe
-- จึงครั้งเดียวไม่ว่าเซิร์ฟไหน) · VIP หมดแล้วรับได้ถ้ายังไม่เคยรับ · แจกถาวร ปิดได้ที่ `Enabled`
--
-- ไม่มี Player ไม่มี remote — `VipGiftPrompt.server` ต่อปุ่ม · เทส `tests/vip_gift_test.lua`
-- อ่าน/เขียน VIP ผ่าน `Vip` เท่านั้น (กติกาของ Vip.lua)
local Vip = require(script.Parent.Vip)

local VipGift = {}

VipGift.Enabled = true
VipGift.Days = 30

-- คืน true หรือ false + เหตุผล: "closed" | "loading" | "claimed" | "active"
function VipGift.Check(data, now)
	if not VipGift.Enabled then return false, "closed" end
	if not data then return false, "loading" end
	if data.VipGiftClaimed == true then return false, "claimed" end
	if Vip.ActiveData(data, now) then return false, "active" end
	return true
end

-- ตัวเดียวที่เขียนโปรไฟล์: ผ่านด่านแล้วให้ VIP + ปั๊มธงในจังหวะเดียว (ไม่มี yield คั่น กดรัวก็ได้ครั้งเดียว)
function VipGift.Claim(data, now)
	local ok, reason = VipGift.Check(data, now)
	if not ok then return false, reason end
	if not Vip.GrantData(data, VipGift.Days, true, now) then return false, "active" end
	data.VipGiftClaimed = true
	return true
end

return VipGift
