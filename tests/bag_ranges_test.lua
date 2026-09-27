-- node tools/lua.js tests/bag_ranges_test.lua Edit
-- ช่วงช่องกระเป๋า (หลัก/VIP) + ห้องรับของตอนเทรด (QA 2026-09-26: กระเป๋า VIP เต็มแล้วเทรดไม่ได้เลย)
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local BagRanges = fresh(game.ServerScriptService.BagRanges)
local Cfg = require(game.ReplicatedStorage.InventoryConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local mf, mt = BagRanges.For("Wheat")
check(mf == 1 and mt == Cfg.SlotCount, "ของเกมหลักอยู่ช่องหลัก")
local vf, vt = BagRanges.For("FarmPlot")
check(vf == Cfg.VipSlotStart and vt == Cfg.VipSlotEnd, "ของวางบนเกาะอยู่ช่อง VIP")

local full = {}
for i = 1, Cfg.SlotCount do full[i] = { id = "Stone", count = 1 } end
check(BagRanges.SwapFits(full, {}, { { id = "FarmPlot" } }) == true, "กระเป๋าหลักเต็ม รับของ VIP ได้")
check(BagRanges.SwapFits(full, {}, { { id = "Wheat" } }) == false, "กระเป๋าหลักเต็ม รับของหลักไม่ได้")
check(BagRanges.SwapFits(full, { { id = "Stone" } }, { { id = "Wheat" } }) == true,
	"ให้ของหลักหนึ่งช่อง รับของหลักหนึ่งช่องได้")

local vipFull = {}
for i = Cfg.VipSlotStart, Cfg.VipSlotEnd do vipFull[i] = { id = "FarmPlot", count = 1 } end
check(BagRanges.SwapFits(vipFull, {}, { { id = "Wheat" } }) == true, "กระเป๋า VIP เต็ม ไม่ขวางการรับของหลัก (บั๊กเดิม)")
check(BagRanges.SwapFits(vipFull, { { id = "Wheat" } }, { { id = "FarmPlot" } }) == false,
	"ให้ของหลักไม่ได้ปลดช่อง VIP")

-- เฟส 2b: ของขอบทองอยู่กระเป๋า VIP เสมอ (ไข่ธรรมดาอยู่ช่องหลัก) · กระเป๋า VIP 36 ช่อง (37-72)
local gf, gt = BagRanges.For("Egg", { gold = true })
check(gf == vf and gt == vt, "ไข่ขอบทองอยู่ช่อง VIP")
check((BagRanges.For("Egg")) == 1, "ไข่ธรรมดาอยู่ช่องหลัก")
local FreshCfg = fresh(game.ReplicatedStorage.InventoryConfig)
check(FreshCfg.VipSlotCount == 36 and FreshCfg.VipSlotEnd == 72,
	("กระเป๋า VIP 36 ช่อง 37-72 (ได้ %d ช่อง ถึง %d)"):format(FreshCfg.VipSlotCount, FreshCfg.VipSlotEnd))
check(BagRanges.SwapFits(vipFull, {}, { { id = "Egg", meta = { gold = true } } }) == false,
	"กระเป๋า VIP เต็ม รับไข่ขอบทองไม่ได้")
check(BagRanges.SwapFits(full, {}, { { id = "Egg", meta = { gold = true } } }) == true,
	"กระเป๋าหลักเต็ม ยังรับไข่ขอบทองได้ (มันไปช่อง VIP)")

return ("%s\n%d fail(s)"):format(table.concat(out, "\n"), fails)
