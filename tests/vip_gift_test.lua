-- node tools/lua.js tests/vip_gift_test.lua Edit
-- ของขวัญหุ่นฟางจุดเกิด (ผู้ใช้สั่ง 2026-09-27 · เดิม 2026-09-26 แจก VIP ทุกคน):
--   150 เพชร เฉพาะบัญชีใหม่ · VIP 30 วัน เมื่อ Lv.5 (มี VIP อยู่รับไม่ได้ ไม่เสียสิทธิ์) · ออร่าสุ่มเมื่อมีเพื่อน 5 คน · อย่างละครั้ง
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local VipGift = fresh(game.ServerScriptService.VipGift)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local now = 2000000000
local LV = 5
local function can(data, level)
	local ok, reason = VipGift.Check(data, now, level or LV)
	return ok, reason
end

----------------------------------------------------------------- VIP
check(VipGift.Days == 30 and VipGift.VipLevel == 5 and VipGift.Gems == 150 and VipGift.FriendsForAura == 5,
	"ตัวเลข: VIP 30 วันที่ Lv.5 · 150 เพชร · เพื่อน 5 คน")
check(select(1, can({ VipUntil = 0 })) == true, "Lv.5 ไม่เคยมี VIP ไม่เคยรับ = รับได้")
check(select(2, can({ VipUntil = 0 }, 4)) == "level" and select(2, VipGift.Check({}, now, nil)) == "level", "ต่ำกว่า Lv.5 (หรือไม่รู้เลเวล) = ยังรับ VIP ไม่ได้")
check(select(1, can({}, 30)) == true, "เลเวลสูงกว่า 5 ก็รับได้")
check(select(2, can(nil)) == "loading", "โปรไฟล์ยังไม่โหลด = รับไม่ได้ (จดธงไม่ได้)")
check(select(2, can({ VipUntil = now + 60 })) == "active", "มี VIP อยู่ = รับไม่ได้")
check(select(2, can({ VipGiftClaimed = true, VipUntil = 0 })) == "claimed", "รับไปแล้ว = รับไม่ได้อีก")
check(select(1, can({ VipUntil = now - 60 })) == true, "VIP หมดอายุแล้ว ยังไม่เคยรับ = รับได้")
check(select(2, can({ VipGiftClaimed = true, VipUntil = now + 60 })) == "claimed",
	"รับแล้วและ VIP ยังเหลือ = บอกว่ารับแล้ว (เหตุผลที่ถาวรกว่า)")

local data = { VipUntil = 0 }
local lowOk = VipGift.Claim(data, now, 3)
check(lowOk == false and data.VipGiftClaimed == nil and data.VipUntil == 0, "Lv.3 กด = ไม่ได้ VIP และไม่เสียสิทธิ์")
local ok = VipGift.Claim(data, now, LV)
check(ok == true and data.VipGiftClaimed == true, "Lv.5 รับครั้งแรก: สำเร็จ + ปั๊มธง")
check(data.VipUntil == now + 30 * 86400, "VIP หมดอายุอีก 30 วันพอดี")
local before = data.VipUntil
local again, reason = VipGift.Claim(data, now + 31 * 86400, LV)
check(again == false and reason == "claimed" and data.VipUntil == before, "รับซ้ำหลัง VIP หมด = ไม่ได้ และไม่แตะวันหมดอายุ")
local busy = { VipUntil = now + 100 }
local okBusy = VipGift.Claim(busy, now, LV)
check(okBusy == false and busy.VipGiftClaimed == nil and busy.VipUntil == now + 100,
	"มี VIP อยู่แล้วกด = ไม่เสียสิทธิ์ ไม่แตะวันหมดอายุ")

----------------------------------------------------------------- 150 เพชร
local added = 0
local function adder(n) added += n return true end
check(select(2, VipGift.CheckGems({})) == "notnew" and select(2, VipGift.CheckGems({ StarterKit = true })) == "notnew",
	"บัญชีเก่า (ไม่มีธงบัญชีใหม่) = ไม่ได้เพชร")
local newbie = { NewbieGems = true }
check(VipGift.ClaimGems(newbie, adder) == true and added == 150 and newbie.NewbieGemsClaimed == true, "บัญชีใหม่กด = ได้ 150 เพชร + ปั๊มธง")
local twice = VipGift.ClaimGems(newbie, adder)
check(twice == false and added == 150, "กดซ้ำ = ไม่ได้อีก")
local failing = { NewbieGems = true }
local failOk = VipGift.ClaimGems(failing, function() return false end)
check(failOk == false and failing.NewbieGemsClaimed == nil, "เข้าบัญชีไม่สำเร็จ = ไม่เสียสิทธิ์")

----------------------------------------------------------------- ออร่าจากเพื่อน
local POOL = { "Aura_A", "Aura_B", "Aura_C" }
local rng = Random.new(3)
local given = {}
local function give(id) given[#given + 1] = id return true end
check(select(2, VipGift.CheckAura({}, 4, POOL)) == "friends", "เพื่อน 4 คน = ยังไม่ได้")
check(select(2, VipGift.CheckAura({}, 5, {})) == "none", "ยังไม่มีออร่าในเกม = ไม่ได้ (ไม่พัง)")
local friendsData = {}
local aOk, aId = VipGift.ClaimAura(friendsData, 5, POOL, rng, give)
check(aOk == true and table.find(POOL, aId) ~= nil and friendsData.FriendAuraClaimed == aId and #given == 1,
	"เพื่อน 5 คน = ได้ออร่าหนึ่งอันจากสระ " .. tostring(aId))
check(select(2, VipGift.ClaimAura(friendsData, 9, POOL, rng, give)) == "claimed" and #given == 1, "ได้แล้วกดซ้ำ = ไม่ได้อีก")
local fullData = {}
local fOk, fWhy = VipGift.ClaimAura(fullData, 6, POOL, rng, function() return false end)
check(fOk == false and fWhy == "full" and fullData.FriendAuraClaimed == nil, "กระเป๋าเต็ม = ไม่เสียสิทธิ์")
local seen = {}
for _ = 1, 200 do
	local d = {}
	local _, id = VipGift.ClaimAura(d, 5, POOL, rng, function() return true end)
	seen[id] = true
end
check(seen.Aura_A and seen.Aura_B and seen.Aura_C, "สุ่มได้ครบทุกออร่าในสระ")

----------------------------------------------------------------- ป้ายปุ่ม
local s1 = VipGift.Summary({ NewbieGems = true, VipUntil = 0 }, now, 1, 0, POOL)
check(#s1.ready == 1 and s1.ready[1] == "150 เพชร" and #s1.waiting == 2, "ผู้เล่นใหม่ Lv.1: รับเพชรได้ · VIP กับออร่ารออยู่")
local s2 = VipGift.Summary({ NewbieGemsClaimed = true, NewbieGems = true, VipUntil = 0 }, now, 6, 5, POOL)
check(#s2.ready == 2 and #s2.waiting == 0, "Lv.6 เพื่อน 5: รับ VIP + ออร่าพร้อมกัน")
local s3 = VipGift.Summary({ NewbieGemsClaimed = true, VipGiftClaimed = true, FriendAuraClaimed = "Aura_A" }, now, 9, 9, POOL)
check(#s3.ready == 0 and #s3.waiting == 0, "รับครบแล้ว = ไม่เหลืออะไร (ปุ่มซ่อน)")
local s4 = VipGift.Summary({ VipUntil = now + 99 }, now, 10, 1, POOL)
check(#s4.ready == 0 and #s4.waiting == 2 and s4.waiting[1]:find("หลัง VIP", 1, true), "บัญชีเก่ามี VIP อยู่: รอ VIP หมด + รอเพื่อน")

return ("%s\n%d fail(s)"):format(table.concat(out, "\n"), fails)
