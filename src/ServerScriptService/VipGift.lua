-- VipGift: ของขวัญที่หุ่นฟางข้างจุดเกิดแรก (`Dummy_Spawn`) — สามอย่าง อย่างละครั้งต่อบัญชี (ผู้ใช้สั่ง 2026-09-27)
--
--   gems — **150 เพชร เฉพาะบัญชีใหม่** (ผู้ใช้เลือก) · ธง `NewbieGems` ตั้งพร้อมชุดเปิดตัว (`PlayerInventory`)
--          = บัญชีที่สร้างหลังอัปเดตนี้เท่านั้น บัญชีเก่าไม่มีธงจึงไม่ได้
--          · **รับได้หลังจบเควสเนื้อเรื่องเริ่มต้นแล้ว** (ผู้ใช้สั่ง 2026-09-28 · `GemsAfterChapter` = บท "ความทรงจำแรก")
--   vip  — VIP 30 วัน **เมื่อ Lv.5 ขึ้นไป** · มี VIP อยู่ = ทบ +30 วัน (ผู้ใช้สั่ง 2026-09-29 · เควส "เกาะลอยฟ้าแห่งความฝัน")
--   pass — **แบทเทิลพาสพรีเมียมของเดือนที่กดรับ ฟรี · บัญชีใหม่เท่านั้น** (ผู้ใช้สั่ง 2026-09-28 · กดได้เลย ไม่ต้องจบเควส)
--          เดือนนั้นปลดพรีเมียมเองไปแล้ว = รอเดือนถัดไป ไม่เสียสิทธิ์ (ไม่ให้ของขวัญเปล่า)
--   aura — **ออร่าสุ่ม 1 อัน** จากออร่าที่มีในเกมตอนนั้น เมื่อมี **เพื่อนในเกม 5 คนขึ้นไป**
--
-- กดทีเดียวรับทุกอย่างที่ถึงเงื่อนไขแล้ว · ธงอยู่ในโปรไฟล์ (ทั้ง universe = ครั้งเดียวไม่ว่าเซิร์ฟไหน) · ปิดทั้งหมดที่ `Enabled`
-- ไม่มี Player ไม่มี remote — ทั้งหมดมาเป็นเควสสีฟ้าของออฟาเรียน (`Story.server` TalkOforian · `VipGift.Quests`) · เทส `tests/vip_gift_test.lua`
-- อ่าน/เขียน VIP ผ่าน `Vip` เท่านั้น (กติกาของ Vip.lua)
local Vip = require(script.Parent.Vip)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)

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

-- คืน true หรือ false + เหตุผล: "closed" | "loading" | "claimed" | "level"
function VipGift.Check(data, now, level)
	if not VipGift.Enabled then return false, "closed" end
	if not data then return false, "loading" end
	if data.VipGiftClaimed == true then return false, "claimed" end
	if (tonumber(level) or 0) < VipGift.VipLevel then return false, "level" end
	return true
end

-- ผ่านด่านแล้วให้ VIP + ปั๊มธงในจังหวะเดียว (ไม่มี yield คั่น กดรัวก็ได้ครั้งเดียว)
function VipGift.Claim(data, now, level)
	local ok, reason = VipGift.Check(data, now, level)
	if not ok then return false, reason end
	if not Vip.GrantData(data, VipGift.Days, false, now) then return false, "loading" end
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
-- เควสสีฟ้าของออฟาเรียน เทพหุ่นฟาง (2026-09-29 · สเปก 2026-09-29-quest-log-oforian)
--------------------------------------------------------------------------------

-- ออร่าทุกชิ้นที่มีในเกมตอนนี้ (ผู้ใช้สั่ง "สุ่มออร่าที่มีในปัจจุบัน") — ออร่าใหม่เข้าสระเอง
function VipGift.AuraPool()
	local out = {}
	for id, item in pairs(ItemCatalog.Items) do
		if type(item) == "table" and item.kind == "aura" then out[#out + 1] = id end
	end
	table.sort(out)
	return out
end

-- แถวเควสที่ค้างอยู่ **คำนวณจากธงเดิมทั้งหมด** (ไม่มีที่เก็บใหม่ — สิทธิ์ของขวัญเดิมคือสิทธิ์เดียวกัน)
-- ก่อนถึงเงื่อนไขไม่มีแถวเลย (ผู้ใช้สั่ง "พอเวล 5 เควสเด้งทันที") ยกเว้นพาสที่ `waiting` รอเดือนหน้า
-- ลำดับ = ลำดับที่คุยแล้วได้ · **sky ท้ายสุดเสมอ** เพราะจบด้วยการวาป ของอย่างอื่นต้องได้ก่อน
function VipGift.Quests(data, now, level, friends, pool, hasPremium)
	local rows = {}
	if not VipGift.Enabled or not data then return rows end
	local passOk, passWhy = VipGift.CheckPass(data, hasPremium)
	if passOk then
		rows[#rows + 1] = { id = "newcomer", state = "active" }
	elseif passWhy == "owned" then
		rows[#rows + 1] = { id = "newcomer", state = "waiting", reason = "เดือนนี้ปลดพาสพรีเมียมแล้ว — กลับมารับเดือนหน้า" }
	end
	if VipGift.CheckGems(data) then rows[#rows + 1] = { id = "travel", state = "active" } end
	if VipGift.CheckAura(data, friends, pool) then rows[#rows + 1] = { id = "friends", state = "active" } end
	if VipGift.Check(data, now, level) then rows[#rows + 1] = { id = "sky", state = "active" } end
	return rows
end

return VipGift
