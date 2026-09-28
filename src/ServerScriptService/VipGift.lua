-- VipGift: ของขวัญที่หุ่นฟางข้างจุดเกิดแรก (`Dummy_Spawn`) — สามอย่าง อย่างละครั้งต่อบัญชี (ผู้ใช้สั่ง 2026-09-27)
--
--   gems — **150 เพชร เฉพาะบัญชีใหม่** (ผู้ใช้เลือก) · ธง `NewbieGems` ตั้งพร้อมชุดเปิดตัว (`PlayerInventory`)
--          = บัญชีที่สร้างหลังอัปเดตนี้เท่านั้น บัญชีเก่าไม่มีธงจึงไม่ได้
--          · **รับได้หลังจบเควสเนื้อเรื่องเริ่มต้นแล้ว** (ผู้ใช้สั่ง 2026-09-28 · `GemsAfterChapter` = บท "ความทรงจำแรก")
--   vip  — VIP 30 วัน **เมื่อ Lv.5 ขึ้นไป** (เดิม 2026-09-26 แจกทุกคนทันที) · มี VIP อยู่ = รับไม่ได้และไม่เสียสิทธิ์
--   pass — **แบทเทิลพาสพรีเมียมของเดือนที่กดรับ ฟรี · บัญชีใหม่เท่านั้น** (ผู้ใช้สั่ง 2026-09-28 · กดได้เลย ไม่ต้องจบเควส)
--          เดือนนั้นปลดพรีเมียมเองไปแล้ว = รอเดือนถัดไป ไม่เสียสิทธิ์ (ไม่ให้ของขวัญเปล่า)
--   aura — **ออร่าสุ่ม 1 อัน** จากออร่าที่มีในเกมตอนนั้น เมื่อมี **เพื่อนในเกม 5 คนขึ้นไป**
--
-- กดทีเดียวรับทุกอย่างที่ถึงเงื่อนไขแล้ว · ธงอยู่ในโปรไฟล์ (ทั้ง universe = ครั้งเดียวไม่ว่าเซิร์ฟไหน) · ปิดทั้งหมดที่ `Enabled`
-- ไม่มี Player ไม่มี remote — `VipGiftPrompt.server` ต่อปุ่มและส่งของ · เทส `tests/vip_gift_test.lua`
-- อ่าน/เขียน VIP ผ่าน `Vip` เท่านั้น (กติกาของ Vip.lua)
local Vip = require(script.Parent.Vip)

local VipGift = {}

VipGift.Enabled = true
VipGift.Days = 30
VipGift.VipLevel = 5
VipGift.Gems = 150
VipGift.FriendsForAura = 5
-- บทเนื้อเรื่องที่ต้องจบก่อนรับเพชร (id ใน StoryConfig.Chapters · ความคืบหน้าอยู่ profile.Data.Story.ch[id].done)
VipGift.GemsAfterChapter = "brasshaven"
VipGift.GemsAfterName = "ความทรงจำแรก"

local function chapterDone(data)
	local story = type(data) == "table" and data.Story
	local ch = type(story) == "table" and type(story.ch) == "table" and story.ch[VipGift.GemsAfterChapter]
	return type(ch) == "table" and ch.done == true
end

--------------------------------------------------------------------------------
-- VIP
--------------------------------------------------------------------------------

-- คืน true หรือ false + เหตุผล: "closed" | "loading" | "claimed" | "level" | "active"
function VipGift.Check(data, now, level)
	if not VipGift.Enabled then return false, "closed" end
	if not data then return false, "loading" end
	if data.VipGiftClaimed == true then return false, "claimed" end
	if (tonumber(level) or 0) < VipGift.VipLevel then return false, "level" end
	if Vip.ActiveData(data, now) then return false, "active" end
	return true
end

-- ผ่านด่านแล้วให้ VIP + ปั๊มธงในจังหวะเดียว (ไม่มี yield คั่น กดรัวก็ได้ครั้งเดียว)
function VipGift.Claim(data, now, level)
	local ok, reason = VipGift.Check(data, now, level)
	if not ok then return false, reason end
	if not Vip.GrantData(data, VipGift.Days, true, now) then return false, "active" end
	data.VipGiftClaimed = true
	return true
end

--------------------------------------------------------------------------------
-- เพชรผู้มาใหม่
--------------------------------------------------------------------------------

-- "closed" | "loading" | "claimed" | "notnew" | "story" (ยังไม่จบเควสเนื้อเรื่องเริ่มต้น — รอได้ ไม่เสียสิทธิ์)
function VipGift.CheckGems(data)
	if not VipGift.Enabled then return false, "closed" end
	if not data then return false, "loading" end
	if data.NewbieGemsClaimed == true then return false, "claimed" end
	if data.NewbieGems ~= true then return false, "notnew" end
	if not chapterDone(data) then return false, "story" end
	return true
end

-- `addGems(n)` คืน true เมื่อเข้าบัญชีแล้ว · ปั๊มธงก่อนให้ (ให้ไม่ผ่าน = ถอดธงคืน)
function VipGift.ClaimGems(data, addGems)
	local ok, reason = VipGift.CheckGems(data)
	if not ok then return false, reason end
	data.NewbieGemsClaimed = true
	if not addGems(VipGift.Gems) then
		data.NewbieGemsClaimed = nil
		return false, "error"
	end
	return true
end

--------------------------------------------------------------------------------
-- แบทเทิลพาสพรีเมียมผู้มาใหม่
--------------------------------------------------------------------------------

-- `hasPremium` = พาสเดือนนี้ปลดพรีเมียมอยู่แล้วไหม · "closed" | "loading" | "claimed" | "notnew" | "owned"
function VipGift.CheckPass(data, hasPremium)
	if not VipGift.Enabled then return false, "closed" end
	if not data then return false, "loading" end
	if data.NewbiePassClaimed == true then return false, "claimed" end
	if data.NewbieGems ~= true then return false, "notnew" end -- ธงบัญชีใหม่ตัวเดียวกับเพชร
	if hasPremium then return false, "owned" end
	return true
end

-- `grant()` คืน true เมื่อปลดแล้ว · ปั๊มธงหลังปลดสำเร็จเท่านั้น
function VipGift.ClaimPass(data, hasPremium, grant)
	local ok, reason = VipGift.CheckPass(data, hasPremium)
	if not ok then return false, reason end
	if not grant() then return false, "error" end
	data.NewbiePassClaimed = true
	return true
end

--------------------------------------------------------------------------------
-- ออร่าจากเพื่อน
--------------------------------------------------------------------------------

-- "closed" | "loading" | "claimed" | "friends" | "none" (ยังไม่มีออร่าในเกม)
function VipGift.CheckAura(data, friends, pool)
	if not VipGift.Enabled then return false, "closed" end
	if not data then return false, "loading" end
	if data.FriendAuraClaimed then return false, "claimed" end
	if not pool or #pool == 0 then return false, "none" end
	if (tonumber(friends) or 0) < VipGift.FriendsForAura then return false, "friends" end
	return true
end

-- `give(id)` คืน true เมื่อเข้ากระเป๋าแล้ว (กระเป๋าเต็ม = false = ยังไม่เสียสิทธิ์) · จดชิ้นที่ได้ไว้ในธง
function VipGift.ClaimAura(data, friends, pool, rng, give)
	local ok, reason = VipGift.CheckAura(data, friends, pool)
	if not ok then return false, reason end
	local id = pool[rng:NextInteger(1, #pool)]
	if not give(id) then return false, "full" end
	data.FriendAuraClaimed = id
	return true, id
end

--------------------------------------------------------------------------------
-- ป้ายบนปุ่มของคนคนนี้
--------------------------------------------------------------------------------

-- `hasPremium` (ไม่บังคับ) = พาสเดือนนี้ปลดพรีเมียมอยู่แล้วไหม
-- { ready = { "150 เพชร", ... }, waiting = { "VIP 30 วัน (Lv.5 · ตอนนี้ Lv.2)", ... } }
-- ready = กดแล้วได้เลย · waiting = ยังรับได้ในอนาคต (บอกว่าติดอะไร) · ที่รับไปแล้ว/ไม่มีสิทธิ์ถาวรไม่อยู่ในทั้งสองรายการ
function VipGift.Summary(data, now, level, friends, pool, hasPremium)
	local ready, waiting = {}, {}
	if not VipGift.Enabled or not data then return { ready = ready, waiting = waiting } end
	local gemsOk, gemsWhy = VipGift.CheckGems(data)
	if gemsOk then
		ready[#ready + 1] = ("%d เพชร"):format(VipGift.Gems)
	elseif gemsWhy == "story" then
		waiting[#waiting + 1] = ("%d เพชร (จบเควสเนื้อเรื่อง \"%s\" กับไลราก่อน)"):format(VipGift.Gems, VipGift.GemsAfterName)
	end
	local passOk, passWhy = VipGift.CheckPass(data, hasPremium)
	if passOk then
		ready[#ready + 1] = "แบทเทิลพาสพรีเมียม"
	elseif passWhy == "owned" then
		waiting[#waiting + 1] = "แบทเทิลพาสพรีเมียม (เดือนนี้ปลดแล้ว — รับได้เดือนถัดไป)"
	end
	local vipOk, vipWhy = VipGift.Check(data, now, level)
	local vipName = ("VIP %d วัน"):format(VipGift.Days)
	if vipOk then
		ready[#ready + 1] = vipName
	elseif vipWhy == "level" then
		waiting[#waiting + 1] = ("%s (ต้อง Lv.%d · ตอนนี้ Lv.%d)"):format(vipName, VipGift.VipLevel, tonumber(level) or 1)
	elseif vipWhy == "active" then
		waiting[#waiting + 1] = ("%s (รับได้หลัง VIP ที่มีอยู่หมด)"):format(vipName)
	end
	local auraOk, auraWhy = VipGift.CheckAura(data, friends, pool)
	if auraOk then
		ready[#ready + 1] = "ออร่าสุ่ม"
	elseif auraWhy == "friends" then
		waiting[#waiting + 1] = ("ออร่าสุ่ม (ต้องมีเพื่อน %d คน · ตอนนี้ %d)"):format(VipGift.FriendsForAura, tonumber(friends) or 0)
	end
	return { ready = ready, waiting = waiting }
end

return VipGift
