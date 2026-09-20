-- Vip.lua: ใครเป็น VIP อยู่ และเหลืออีกกี่วัน — คำตอบอยู่ที่นี่ที่เดียว
--
-- ผู้ใช้กำหนด 2026-09-20: **ขายด้วยเพชรในหน้าร้านแคช** (ไม่ใช่ Game Pass โรบัค) และเป็นแบบมีวันหมดอายุ
-- ต่ออายุได้ เวลาทบกัน · ตัวเลขทั้งหมดอยู่ใน `PremiumConfig.Vip`
--
-- **ทั้งเกมต้องถามผ่านไฟล์นี้ ห้ามอ่าน `profile.VipUntil` เอง** — วันที่เปลี่ยนวิธีขาย (เพิ่ม Game Pass
-- เป็นทางที่สอง หรือแจก VIP ให้แอดมิน) จะได้แก้ที่เดียว ไม่ใช่ไล่แก้ทุกที่ที่เคยเช็ค
--
-- อ่านจากโปรไฟล์ในหน่วยความจำ ไม่แตะ DataStore — และเพราะโปรไฟล์เป็นของทั้ง universe เซิร์ฟล็อบบี้
-- กับเซิร์ฟเกาะจึงเห็นคำตอบเดียวกันโดยไม่ต้องส่งอะไรหากัน
local Players = game:GetService("Players")
local ProfileAccess = require(script.Parent.ProfileAccess)
local PremiumConfig = require(game.ReplicatedStorage.PremiumConfig)

local Vip = {}

-- เวลาหมดอายุ (os.time) · 0 = ไม่เคยซื้อ/หมดแล้ว
function Vip.Until(player)
	local data = ProfileAccess.Get(player)
	return (data and tonumber(data.VipUntil)) or 0
end

function Vip.Has(player)
	return Vip.Until(player) > os.time()
end

-- วินาทีที่เหลือ (0 = ไม่ได้เป็น VIP) — หน้าร้านเอาไปโชว์ว่าเหลือกี่วัน
function Vip.SecondsLeft(player)
	return math.max(0, Vip.Until(player) - os.time())
end

-- ต่ออายุ: **ทบจากเวลาที่เหลือ ไม่ใช่นับใหม่จากวันนี้** คนที่ซื้อซ้ำก่อนหมดอายุจึงไม่เสียวันที่จ่ายไปแล้ว
-- คืนเวลาหมดอายุใหม่ หรือ nil ถ้าเขียนโปรไฟล์ไม่ได้ (ยังโหลดไม่เสร็จ/ออกเกมไปแล้ว)
function Vip.Grant(player, days)
	local data = ProfileAccess.Get(player)
	if not data then return nil end
	local base = math.max(os.time(), tonumber(data.VipUntil) or 0)
	data.VipUntil = base + math.floor((days or 0) * 86400)
	Vip.Publish(player)
	return data.VipUntil
end

-- ถามแทนคนที่ **ไม่ได้อยู่ในเซิร์ฟนี้** หรืออยู่แต่โปรไฟล์ไม่ได้โหลด (ล็อบบี้) — ยิง DataStore หนึ่งครั้ง
-- ใช้ตอนล็อบบี้วาดแถวโหมดฟาร์มมิ่ง · อย่าเรียกถี่ ให้แคชผลไว้ฝั่งผู้เรียก
function Vip.PeekAsync(userId)
	if not ProfileAccess.PeekAsync then return false, 0 end
	local data = ProfileAccess.PeekAsync(userId)
	local until_ = (data and tonumber(data.VipUntil)) or 0
	return until_ > os.time(), until_
end

-- ประกาศไว้บนตัว Player ให้ไคลเอนต์ทุกเครื่องอ่านได้ (ทรงเดียวกับ `ClanId` ของระบบแคลน)
-- ใช้กับหน้าจอที่ต้องรู้สถานะ VIP โดยไม่ต้องถามเซิร์ฟเวอร์ — เช่นแถวโหมดฟาร์มมิ่งในล็อบบี้
--
-- ส่งเป็น "เวลาหมดอายุ" ไม่ใช่ true/false: 0 แปลว่าไม่ใช่ VIP · เลขอื่นเอาไปคำนวณวันที่เหลือได้เลย
function Vip.Publish(player)
	player:SetAttribute("VipUntil", Vip.Until(player))
end

-- ลูปเดียวที่ดูความจริงตอนนี้ ด้วยเหตุผลเดียวกับ `Clans.server`: VIP หมดอายุเองระหว่างเล่นได้
-- และซื้อจากเซิร์ฟอื่นก็ได้ ผูกกับเหตุการณ์ไหนก็พลาดทางที่เหลือ
task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			Vip.Publish(player)
		end
		task.wait(10)
	end
end)

return Vip
