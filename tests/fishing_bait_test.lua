-- node tools/offline-test.js tests/fishing_bait_test.lua   (หรือ node tools/lua.js tests/fishing_bait_test.lua Edit)
-- หนอน (ผู้ใช้สั่ง 2026-10-02): กองละ 40 · พกได้กองเดียว (ที่เกินเข้าคลัง) · ตกหมด 40 ตัวเฉลี่ย 15-18 นาที
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end
local RS = game.ReplicatedStorage
local ItemCatalog, FishingConfig = fresh(RS.ItemCatalog), fresh(RS.FishingConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local worm = ItemCatalog.Get(FishingConfig.BaitItem)
check(worm and worm.stackSize == 40, "หนอนกองละ 40 (ได้ " .. tostring(worm and worm.stackSize) .. ")")
check(ItemCatalog.BagLimit(FishingConfig.BaitItem) == 40, "พกหนอนได้กองเดียว = 40 ตัว ที่เกินเข้าคลัง")

-- เวลาต่อตัว = สุ่มเลขเต็ม Min..Max วินาที (Fishing.server) · เฉลี่ย (Min+Max)/2
local avg = (FishingConfig.MinSeconds + FishingConfig.MaxSeconds) / 2
local minutes = 40 / FishingConfig.BaitPerCatch * avg / 60
check(minutes >= 15 and minutes <= 18, ("หนอน 40 ตัวตกหมดเฉลี่ย %.1f นาที (ต้อง 15-18)"):format(minutes))

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
