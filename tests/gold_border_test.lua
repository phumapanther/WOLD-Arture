-- node tools/lua.js tests/gold_border_test.lua Edit   (เพลสไหนก็ได้ — ข้อมูลล้วน)
-- เฟส 2b (ผู้ใช้กำหนด 2026-09-26/27): ของขอบทอง + แสงสามสี ฟ้า 7% · ทอง 2.5% · แดง 0.5% (แดงเฉพาะของที่มีขอบทองได้)
-- ขอบทอง 10% · แสงทอง 40% · แสงแดงแน่นอน · สมุนไพรจากแปลงได้ จากพุ่มป่าไม่ได้ · โอน/ฝาก/ทิ้งไม่ได้ · ขายบนเกาะ 3 เท่า
-- โคลนทั้งชุดลงโฟลเดอร์ชั่วคราว: โมดูลพวกนี้ require พี่น้องด้วย script.Parent และ Edit แคช require ข้ามการรัน
local RS = game.ReplicatedStorage
local temp = Instance.new("Folder")
temp.Name = "GoldTest_" .. math.random(1, 1e9)
temp.Parent = RS
local NAMES = { "CraftConfig", "ShopConfig", "MailConfig", "PremiumConfig", "ItemCatalog", "IslandConfig", "GatherConfig", "GoldBorder" }
local missing = {}
for _, name in ipairs(NAMES) do
	local m = RS:FindFirstChild(name)
	if m then m:Clone().Parent = temp else missing[#missing + 1] = name end
end

local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end
local function near(value, target, tol) return math.abs(value - target) <= tol end

check(#missing == 0, "มีโมดูลครบ " .. table.concat(missing, ","))
local ok, err = pcall(function()
	local IslandConfig = require(temp.IslandConfig)
	local ItemCatalog = require(temp.ItemCatalog)
	local ShopConfig = require(temp.ShopConfig)
	local GoldBorder = require(temp.GoldBorder)

	-- แสงสามสี
	local function rates(canGold, n)
		local t = { blue = 0, gold = 0, red = 0 }
		for _ = 1, n do
			local g = IslandConfig.RollGlow(canGold)
			if g then t[g] += 1 end
		end
		return t.blue / n * 100, t.gold / n * 100, t.red / n * 100
	end
	local b, g, r = rates(true, 200000)
	check(near(b, 7, 0.3) and near(g, 2.5, 0.3) and near(r, 0.5, 0.3),
		("แสง (มีขอบทองได้) ฟ้า %.2f ทอง %.2f แดง %.2f"):format(b, g, r))
	b, g, r = rates(false, 200000)
	check(near(b, 7, 0.3) and near(g, 2.5, 0.3) and r == 0,
		("แสง (ต้นไม้/พุ่ม) ฟ้า %.2f ทอง %.2f แดง %.2f"):format(b, g, r))
	check(typeof(IslandConfig.Glow.colors.red) == "Color3", "มีสีแดง")
	check(IslandConfig.GlowYield("blue") == 2 and IslandConfig.GlowYield("red") == 2
		and IslandConfig.GlowYield("gold") == 1 and IslandConfig.GlowYield(nil) == 1, "ของ x2: ฟ้า/แดง")
	check(IslandConfig.GlowExp("gold") == 2 and IslandConfig.GlowExp("red") == 2
		and IslandConfig.GlowExp("blue") == 1 and IslandConfig.GlowExp(nil) == 1, "EXP x2: ทอง/แดง")

	-- ทอยขอบทอง
	local function goldRate(glow, n)
		local hit = 0
		for _ = 1, n do if GoldBorder.Roll(glow) then hit += 1 end end
		return hit / n * 100
	end
	check(goldRate("red", 1000) == 100, "แสงแดง = ขอบทองแน่นอน")
	local gg, gn = goldRate("gold", 100000), goldRate(nil, 100000)
	check(near(gg, 40, 1) and near(gn, 10, 1), ("ขอบทอง: แสงทอง %.1f%% · ปกติ %.1f%%"):format(gg, gn))

	-- ของไหนมีขอบทองได้
	for _, id in ipairs({ "Egg", "Milk", "Wool", "Leather", "Meat", "IronOre", "SilverOre", "GoldOre", "MagicOre", "Diamond", "Crystal" }) do
		check(GoldBorder.GatherItems[id] == true, id .. " (เก็บเกี่ยว) มีขอบทองได้")
	end
	for _, id in ipairs({ "Coal", "Stone", "Herb", "Wood", "Worm" }) do
		check(not GoldBorder.GatherItems[id], id .. " (เก็บเกี่ยว) ไม่มีขอบทอง")
	end
	for _, id in ipairs({ "Wheat", "Vegetable", "Herb", "MagicBranch" }) do
		check(GoldBorder.CropItems[id] == true, id .. " (แปลงผัก) มีขอบทองได้")
	end
	check(GoldBorder.NodeCanGold("Chicken") and GoldBorder.NodeCanGold("IronOre"), "โหนดไก่/สายเหล็ก แดงได้")
	check(not GoldBorder.NodeCanGold("Rock") and not GoldBorder.NodeCanGold("Coal")
		and not GoldBorder.NodeCanGold("Tree") and not GoldBorder.NodeCanGold("Herb"), "หิน/ถ่าน/ต้นไม้/พุ่ม แดงไม่ได้")

	-- ตัวตัดสินกลาง + ชื่อ
	check(ItemCatalog.IsGoldBorder({ gold = true }) and not ItemCatalog.IsGoldBorder(nil)
		and not ItemCatalog.IsGoldBorder({ kg = 3 }), "IsGoldBorder")
	check(ItemCatalog.DisplayName("Egg", { gold = true }):find("(ขอบทอง)", 1, true) ~= nil,
		"ชื่อ: " .. ItemCatalog.DisplayName("Egg", { gold = true }))

	-- โอน/ฝาก/ทิ้งไม่ได้ (Task 3)
	check(ItemCatalog.IsMailable("Egg", { gold = true }) == false, "ขอบทองส่งเมลไม่ได้")
	check(ItemCatalog.IsStorable("Egg", { gold = true }) == false, "ขอบทองฝากไม่ได้")
	check(ItemCatalog.IsDroppable("Egg", { gold = true }) == false, "ขอบทองทิ้งไม่ได้")
	check(ItemCatalog.IsMailable("Egg") == true and ItemCatalog.IsStorable("Egg") == true, "ไข่ธรรมดายังส่ง/ฝากได้")

	-- ขาย (Task 4)
	check(ShopConfig.GoldSellPrice and ShopConfig.GoldSellPrice(10, true) == 30
		and ShopConfig.GoldSellPrice(10, false) == nil, "ขายบนเกาะ 3 เท่า · ที่อื่นไม่รับ")
end)
check(ok, "รันจบ " .. tostring(err or ""))
temp:Destroy()
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
