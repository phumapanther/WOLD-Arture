-- node tools/lua.js tests/slot_codec_test.lua Edit
-- บั๊ก 2026-09-25: ของกระเป๋า VIP (ช่อง 37+) หายหลังออกเข้าเซิร์ฟใหม่
-- ต้นเหตุ: DataStore เก็บเป็น JSON · ตารางช่องที่มีของตั้งแต่ช่อง 1 ถูกเข้ารหัสเป็น array แล้ว **ตัดทิ้งทุกช่องหลังรูแรก**
-- (วัดแล้ว: {1,2,3,37,38} → ["a","b","c"]) · เทสนี้วนผ่าน JSON จริงแบบเดียวกับที่ DataStore ทำ
local HttpService = game:GetService("HttpService")

local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local SlotCodec = fresh(game.ServerScriptService.SlotCodec)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local function roundTrip(slots)
	local json = HttpService:JSONEncode(SlotCodec.ForSave(slots))
	return SlotCodec.FromSave(HttpService:JSONDecode(json))
end

local bag = {
	[1] = { id = "Stone", count = 5 }, [2] = { id = "Wood", count = 3 }, [3] = { id = "Herb", count = 1 },
	[7] = { id = "IronOre", count = 2 }, -- ของหลังรูในกระเป๋าหลัก
	[37] = { id = "FarmPlot", count = 1 }, [40] = { id = "Seed", count = 9 }, -- กระเป๋า VIP
}
local back = roundTrip(bag)
check(back[37] and back[37].id == "FarmPlot", "ช่อง VIP 37 รอดการเซฟ")
check(back[40] and back[40].count == 9, "ช่อง VIP 40 รอดการเซฟ")
check(back[7] and back[7].id == "IronOre", "ของหลังรูในกระเป๋าหลักรอด")
check(back[1] and back[1].id == "Stone" and back[3].id == "Herb", "ช่อง 1-3 รอด")
check(back["37"] == nil, "คีย์กลับมาเป็นตัวเลข ไม่ใช่สตริง")

-- เซฟเก่า (array ที่ถูกตัดไปแล้ว หรือ object คีย์สตริง) ต้องโหลดได้เหมือนเดิม
local legacyArray = SlotCodec.FromSave(HttpService:JSONDecode('[{"id":"Stone","count":1},{"id":"Wood","count":2}]'))
check(legacyArray[2] and legacyArray[2].id == "Wood", "เซฟเก่าแบบ array ยังโหลดได้")
local legacyObject = SlotCodec.FromSave(HttpService:JSONDecode('{"2":{"id":"Wood","count":2},"37":{"id":"Seed","count":1}}'))
check(legacyObject[37] and legacyObject[37].id == "Seed", "เซฟเก่าแบบ object ยังโหลดได้")
check(next(SlotCodec.FromSave(nil)) == nil, "ไม่มีเซฟ = กระเป๋าว่าง")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
