-- Deny: บอกผู้เล่นว่า "ทำไม่ได้เพราะอะไร" แทนการเงียบ (QA 2026-09-28 · ผู้ใช้สั่ง "อินเทอแร็กอะไรแล้วต้องไม่เงียบ")
--
-- `Deny.Blocked(player, action)` คืนข้อความเหตุผลถ้าตอนนี้ทำไม่ได้เพราะสถานะตัวละคร (ล้ม มึน เซ ถูกยิงล้ม ถูกจับ ถูกอุ้ม
-- กำลังใช้ของ) หรือ nil ถ้าไม่ติดอะไร · `Deny.Tell(player, text)` ส่งข้อความ ไม่เกิน 1 ข้อความ/1.5 วิต่อคน (กดรัวไม่ถล่มจอ)
-- ข้อความมีเสียงปฏิเสธ (ToastController) ในตัว · เซิร์ฟเวอร์เท่านั้น
local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage.Remotes)
local Vitals = require(script.Parent.Vitals)
local StatusEffects = require(script.Parent.StatusEffects)
local Consuming = require(script.Parent.Consuming)

local Deny = {}
local Last = {}

function Deny.Tell(player, text)
	if not text then return end
	local now = os.clock()
	if now - (Last[player] or -10) < 1.5 then return end
	Last[player] = now
	Remotes.SocialNotify:FireClient(player, "warn", text)
end

-- `action` = คำกริยาสั้นๆ เช่น "โจมตี" "ใช้ของ" "กลิ้ง"
function Deny.Blocked(player, action)
	action = action or "ทำ"
	if Vitals.IsDowned(player) then return ("%sไม่ได้ขณะล้มอยู่ — รอคนมาช่วยหรือกดเกิดใหม่"):format(action) end
	if player:GetAttribute("WOLD_Arrested") then return ("%sไม่ได้ขณะถูกจับกุม"):format(action) end
	if StatusEffects.IsKnockedDown(player) then return ("%sไม่ได้ขณะล้มลงพื้น"):format(action) end
	if StatusEffects.IsDizzy(player) then return ("%sไม่ได้ขณะมึนหัว"):format(action) end
	if StatusEffects.IsStaggered(player) then return ("%sไม่ได้ขณะเสียหลัก"):format(action) end
	if not StatusEffects.CanFight(player) then return ("%sไม่ได้ตอนนี้"):format(action) end
	if Consuming.IsConsuming(player) then return "กำลังใช้ของอยู่ รอให้เสร็จก่อน" end
	return nil
end

Players.PlayerRemoving:Connect(function(player) Last[player] = nil end)

return Deny
