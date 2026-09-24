-- Play (เพลสหลัก) → node tools/lua.js tests/mail_test.lua Server
--
-- กฎการส่ง/รับ/ลบของผู้เล่น ผ่าน ServerStorage.MailTest (sandbox ของ execute_luau ได้สำเนาโมดูลใหม่
-- ProfileAccess ที่มันเห็นจึงว่าง) · Transport ถูกสวมทุกครั้ง ไม่มีอะไรถูกส่งเข้า DataStore จริง
-- ⚠️ โปรไฟล์จริง: ทุกอย่างที่เสกเข้ากระเป๋า/กล่อง ถูกเก็บคืนตอนจบ
local Players = game:GetService("Players")
local T = assert(game:GetService("ServerStorage"):WaitForChild("MailTest", 10), "ไม่มีช่องเทส MailTest")
local function M(op, ...) return T:Invoke(op, ...) end
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่น")
local FRIEND = 1 -- userId ปลอม ช่องเทสใส่เป็นสหายชั่วคราว
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

M("ClearBox", player)
M("Revoke", player, "Silver", M("Count", player, "Silver"))
M("Grant", player, "Stone", 5)
M("Grant", player, "Silver", 1500)
local stone0, silver0 = M("Count", player, "Stone"), M("Count", player, "Silver")

-- 1. ส่งสำเร็จ: หักของ 3 + ค่าส่ง 500 · ข้อความผ่านตัวกรอง
local ok, msg, letter = M("Send", player, FRIEND, M("SlotOf", player, "Stone"), 3, "ฝากหิน", { friend = true, transport = "ok" })
check(ok == true, "ส่งสำเร็จ: " .. tostring(msg))
check(letter and letter.items[1].id == "Stone" and letter.items[1].count == 3 and letter.body ~= nil, "จดหมายมีหิน x3")
check(M("Count", player, "Stone") == stone0 - 3 and M("Count", player, "Silver") == silver0 - 500, "หักหิน 3 และซิลเวอร์ 500")

-- 2. ส่งล้ม: คืนทั้งหมด
local stone1, silver1 = M("Count", player, "Stone"), M("Count", player, "Silver")
ok, msg = M("Send", player, FRIEND, M("SlotOf", player, "Stone"), 1, "", { friend = true, transport = "fail" })
check(ok == false and M("Count", player, "Stone") == stone1 and M("Count", player, "Silver") == silver1, "ส่งล้ม คืนของและค่าส่ง: " .. tostring(msg))

-- 3. ของต้องห้าม
M("Grant", player, "Chemical", 1)
ok, msg = M("Send", player, FRIEND, M("SlotOf", player, "Chemical"), 1, "", { friend = true, transport = "ok" })
check(ok == false and M("Count", player, "Chemical") >= 1, "สารเคมีส่งไม่ได้: " .. tostring(msg))
M("Revoke", player, "Chemical", 1)

-- 4. ไม่ใช่สหาย
ok, msg = M("Send", player, FRIEND, M("SlotOf", player, "Stone"), 1, "", { friend = false, transport = "ok" })
check(ok == false and M("Count", player, "Stone") == stone1, "ไม่ใช่สหายส่งไม่ได้: " .. tostring(msg))

-- 5. กดรัว: ครั้งแรกค้าง (slow) ครั้งที่สองต้องถูกปฏิเสธ หักครั้งเดียว
local first, second = M("DoubleSend", player, FRIEND, M("SlotOf", player, "Stone"), 1)
check(first == true and second == false, "กดส่งซ้ำระหว่างรอ ถูกปฏิเสธ")
check(M("Count", player, "Stone") == stone1 - 1 and M("Count", player, "Silver") == silver1 - 500, "หักครั้งเดียว")

-- 6. ซิลเวอร์ไม่พอ
M("Revoke", player, "Silver", M("Count", player, "Silver"))
ok, msg = M("Send", player, FRIEND, M("SlotOf", player, "Stone"), 1, "", { friend = true, transport = "ok" })
check(ok == false, "ซิลเวอร์ไม่พอส่งไม่ได้: " .. tostring(msg))

-- 7. รับของ + เงิน + EXP · รับซ้ำไม่ได้
local stone2 = M("Count", player, "Stone")
local id = M("Put", player, { items = { { id = "Stone", count = 2 }, { id = "ของที่ถูกถอดแล้ว", count = 1 } }, gold = 10, exp = 5 })
ok, msg = M("Claim", player, id)
check(ok == true and M("Count", player, "Stone") == stone2 + 2, "รับหิน 2 (ข้ามไอเทมที่ไม่มีแล้ว): " .. tostring(msg))
check(M("Letter", player, id).claimed == true, "ติดธงรับแล้ว")
ok = M("Claim", player, id)
check(ok == false and M("Count", player, "Stone") == stone2 + 2, "รับซ้ำไม่ได้")
check(M("Remove", player, id) == true, "ลบฉบับที่รับแล้วได้")

-- 8. กระเป๋าไม่พอ: ปฏิเสธ เมลอยู่ครบ · ลบไม่ได้เพราะยังไม่รับ
local big = M("Put", player, { items = { { id = "Stone", count = 999999 } } })
ok, msg = M("Claim", player, big)
check(ok == false and M("Letter", player, big).claimed == false, "กระเป๋าไม่พอ เมลยังไม่ถูกรับ: " .. tostring(msg))
check(M("Remove", player, big) == false, "ลบเมลที่ยังไม่รับของไม่ได้")

-- 9. กล่องเต็ม: รอคิว → ลบหนึ่งฉบับ → ดึงเข้ากล่อง (ช่องเทสเก็บกล่องเดิมแล้วคืนให้เอง)
local full = M("FullBox", player)
check(full.heldBefore == 1 and full.processedBefore == false, "กล่องเต็ม: รอคิว ไม่ processed")
check(full.processedAfter == true and full.inBoxAfter == true, "ลบหนึ่งฉบับ: ดึงเข้ากล่อง")

-- 10. จำนวนเป็น NaN (ไคลเอนต์โกงส่ง 0/0 มาได้) — ต้องถูกปฏิเสธ ไม่งั้นช่องกลายเป็น NaN ที่ผ่านทุกด่าน = ปั๊มของ
M("Grant", player, "Silver", 1000)
local stone3 = M("Count", player, "Stone")
ok, msg = M("Send", player, FRIEND, M("SlotOf", player, "Stone"), 0 / 0, "", { friend = true, transport = "ok" })
check(ok == false and M("Count", player, "Stone") == stone3, "จำนวน NaN ถูกปฏิเสธ: " .. tostring(msg))

-- 11. ข้อความไทยยาวเกิน: ตัดที่ขอบตัวอักษร ไม่ใช่กลางไบต์ (ไทย 3 ไบต์ต่อตัว)
local long = string.rep("ก", 250)
ok, msg, letter = M("Send", player, FRIEND, M("SlotOf", player, "Stone"), 1, long, { friend = true, transport = "ok" })
check(ok == true and letter and utf8.len(letter.body) ~= nil, "ข้อความไทยยาวยังเป็น UTF-8 ที่ถูกต้อง: " .. tostring(msg))
check(letter and utf8.len(letter.body) <= 200, "ตัดเหลือไม่เกิน 200 ตัวอักษร")

-- เก็บกวาด
M("Revoke", player, "Silver", M("Count", player, "Silver"))
M("Put", player, nil, big) -- nil letter + id = ลบทิ้งแบบบังคับ
M("Revoke", player, "Stone", math.max(0, M("Count", player, "Stone") - (stone0 - 5)))

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
