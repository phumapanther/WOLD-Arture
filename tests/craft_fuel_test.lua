-- node tools/offline-test.js tests/craft_fuel_test.lua   (หรือ node tools/lua.js tests/craft_fuel_test.lua Edit)
-- เชื้อเพลิงเครื่องคราฟบนเกาะ (ผู้ใช้สั่ง 2026-10-02): ถ่านหิน 16 ก้อน = 100% = ทำงานได้ 2 ชั่วโมง · กินตามเวลาทำ ·
-- หักตอนกดทำ ไม่พอ = ทำไม่ได้ · ทุกเครื่องคราฟบนเกาะ เกมหลักไม่เกี่ยว
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end
local F = fresh(game.ReplicatedStorage.CraftFuel)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

check(F.Item == "Coal" and F.ItemsToFill == 16 and F.FullSeconds == 7200, "ถ่านหิน 16 ก้อน = เต็ม = 2 ชั่วโมง")
check(F.SecondsPerItem == 450, "ถ่าน 1 ก้อน = 7.5 นาที")
for _, s in ipairs({ "bakery", "metal", "loom", "stove", "blender", "still" }) do
	check(F.Uses(s, true), "เครื่องบนเกาะใช้เชื้อเพลิง: " .. s)
end
check(not F.Uses("stove", false) and not F.Uses(nil, true), "เกมหลัก/ช่างตีเหล็ก ไม่ใช้เชื้อเพลิง")

check(F.Cost(5 * 60) == 300 and F.Cost(45 * 60) == 2700, "กินเท่าเวลาทำ (วินาที)")
check(F.CostPercent(5 * 60) == 5 and F.CostPercent(45 * 60) == 38, "เนย 5 นาที ≈ 5% · ข้าวโพดอบเนย 45 นาที ≈ 38% (ปัดขึ้น)")
check(F.Percent(0) == 0 and F.Percent(7200) == 100 and F.Percent(3600) == 50, "เปอร์เซ็นต์ 0 / 100 / 50")

check(F.Room(0) == 16 and F.Room(7200) == 0, "ถังว่างเติมได้ 16 ก้อน · เต็มแล้วเติมไม่ได้")
check(F.Room(7000) == 1, "เหลือที่ไม่ถึงก้อน = ยังเติมได้ 1 ก้อน (เต็มพอดี)")
check(F.Add(0, 16) == 7200 and F.Add(7000, 1) == 7200 and F.Add(0, 1) == 450, "เติมแล้วไม่เกิน 100%")
check(F.Enough(900, 300) and not F.Enough(900, 901), "พอ / ไม่พอ")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
