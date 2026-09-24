-- node tools/lua.js tests/mail_core_test.lua Edit
--
-- ตรรกะกล่องจดหมายล้วนๆ บนตาราง data ปลอม ไม่แตะโปรไฟล์จริง ไม่แตะ DataStore (Transport ถูกสวมแทน)
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local Mail = fresh(game.ServerScriptService.Mail)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

-- Send: เติม kind/id/at แล้วยื่นให้ Transport
local sentTo, sentLetter
Mail.Transport = function(userId, letter) sentTo, sentLetter = userId, letter return true end
check(Mail.Send(123, { fromName = "เทส", items = {} }) == true, "Send คืน true")
check(sentTo == 123 and sentLetter.kind == "mail", "Transport ได้ userId และ kind=mail")
check(type(sentLetter.id) == "string" and #sentLetter.id > 10 and type(sentLetter.at) == "number", "มี id และ at")
Mail.Transport = function() return false end
check(Mail.Send(123, {}) == false, "Transport ล้ม = Send คืน false")

-- Deliver ลงกล่อง
local player, data = {}, {}
local called = 0
local function spy() called += 1 end
check(Mail.Deliver(player, data, { id = "a", items = { { id = "Stone", count = "3" } }, gold = 5 }, spy) == true, "Deliver เข้ากล่อง")
check(called == 1 and #Mail.Box(data) == 1, "processed ถูกเรียก กล่องมี 1")
local _, a = Mail.Find(data, "a")
check(a and a.items[1].count == 3 and a.gold == 5 and a.claimed == false, "sanitize: count เป็นตัวเลข gold ติดมา")
check(Mail.HasAttachment(a) and Mail.Unread(data) == 1, "มีของแนบ ยังไม่อ่าน 1")

-- id ซ้ำ = ไม่เพิ่ม แต่ปล่อยคิว
Mail.Deliver(player, data, { id = "a" }, spy)
check(called == 2 and #Mail.Box(data) == 1, "id ซ้ำ: processed แต่ไม่ซ้ำในกล่อง")

-- ของเสีย = ทิ้ง (ไม่งั้นค้างคิวตลอดไป)
check(Mail.Deliver(player, data, "ขยะ", spy) == true and called == 3 and #Mail.Box(data) == 1, "ข้อความเสียถูกทิ้ง")

-- กล่องเต็ม = รอคิว ไม่เรียก processed
for i = 2, 50 do Mail.Deliver(player, data, { id = "f" .. i }, function() end) end
check(#Mail.Box(data) == 50, "เติมจนเต็ม 50")
local lateCalled = false
check(Mail.Deliver(player, data, { id = "late" }, function() lateCalled = true end) == false, "เต็มแล้ว Deliver คืน false")
check(lateCalled == false and Mail.HeldCount(player) == 1 and not Mail.Find(data, "late"), "รอคิว ไม่ processed ไม่อยู่ในกล่อง")

-- ลบหนึ่งฉบับแล้ว Drain = ดึงเข้ากล่อง
table.remove(Mail.Box(data), 1)
Mail.Drain(player, data)
check(lateCalled == true and Mail.HeldCount(player) == 0 and Mail.Find(data, "late") ~= nil, "Drain ดึงคิวเข้ากล่อง")
check(#Mail.Box(data) == 50, "ยัง 50 พอดี")

-- Forget ล้างคิว (คนออกเกม — ProfileStore ยังเก็บข้อความที่ไม่ processed ไว้ให้รอบหน้า)
Mail.Deliver(player, data, { id = "late2" }, function() end)
Mail.Forget(player)
check(Mail.HeldCount(player) == 0, "Forget ล้างคิวในหน่วยความจำ")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
