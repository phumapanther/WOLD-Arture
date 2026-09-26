-- node tools/lua.js tests/vip_gift_test.lua Edit
-- หุ่นฟางจุดเกิดแจก VIP 30 วัน (ผู้ใช้สั่ง 2026-09-26): มี VIP อยู่รับไม่ได้ (ไม่เสียสิทธิ์) · บัญชีละครั้ง ·
-- VIP หมดแล้วรับได้ถ้ายังไม่เคยรับ · แจกถาวร
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
local function can(data)
	local ok, reason = VipGift.Check(data, now)
	return ok, reason
end

check(VipGift.Days == 30, "แจก 30 วัน")
check(select(1, can({ VipUntil = 0 })) == true, "ไม่เคยมี VIP ไม่เคยรับ = รับได้")
check(select(1, can({})) == true, "โปรไฟล์ใหม่เอี่ยม (ไม่มีฟิลด์) = รับได้")
check(select(2, can(nil)) == "loading", "โปรไฟล์ยังไม่โหลด = รับไม่ได้ (จดธงไม่ได้)")
check(select(2, can({ VipUntil = now + 60 })) == "active", "มี VIP อยู่ = รับไม่ได้")
check(select(2, can({ VipGiftClaimed = true, VipUntil = 0 })) == "claimed", "รับไปแล้ว = รับไม่ได้อีก")
check(select(1, can({ VipUntil = now - 60 })) == true, "VIP หมดอายุแล้ว ยังไม่เคยรับ = รับได้")
check(select(2, can({ VipGiftClaimed = true, VipUntil = now + 60 })) == "claimed",
	"รับแล้วและ VIP ยังเหลือ = บอกว่ารับแล้ว (เหตุผลที่ถาวรกว่า)")

-- Claim = ตัวเดียวที่เขียนโปรไฟล์: ได้ VIP ทบจากเวลาที่เหลือ + ปั๊มธง · ครั้งที่สองต้องไม่ได้อะไร
local data = { VipUntil = 0 }
local ok = VipGift.Claim(data, now)
check(ok == true and data.VipGiftClaimed == true, "รับครั้งแรก: สำเร็จ + ปั๊มธง")
check(data.VipUntil == now + 30 * 86400, "VIP หมดอายุอีก 30 วันพอดี")
local before = data.VipUntil
local again, reason = VipGift.Claim(data, now + 31 * 86400)
check(again == false and reason == "claimed" and data.VipUntil == before, "รับซ้ำหลัง VIP หมด = ไม่ได้ และไม่แตะวันหมดอายุ")

local busy = { VipUntil = now + 100 }
local okBusy = VipGift.Claim(busy, now)
check(okBusy == false and busy.VipGiftClaimed == nil and busy.VipUntil == now + 100,
	"มี VIP อยู่แล้วกด = ไม่เสียสิทธิ์ ไม่แตะวันหมดอายุ")

return ("%s\n%d fail(s)"):format(table.concat(out, "\n"), fails)
