-- node tools/lua.js tests/island_shop_prices_test.lua Edit
-- เฟส 2a (ผู้ใช้กำหนด 2026-09-26/27): ร้านเกาะทุกชิ้นสองราคา 1 เพชร = 250 เหรียญ ปัดขึ้น ขั้นต่ำ 1 · 5 หมวด ·
-- ของร้านเกาะส่งเมลไม่ได้ทั้งร้านรวมเมล็ด
-- โคลนทั้งชุดลงโฟลเดอร์ชั่วคราว: ItemCatalog require พี่น้องด้วย script.Parent ถ้าโคลนตัวเดียว มันจะได้ ShopConfig
-- ตัวที่ Edit แคชไว้ (ของเก่า) แทนตัวที่เพิ่งดันขึ้น
local RS = game.ReplicatedStorage
local temp = Instance.new("Folder")
temp.Name = "PriceTest_" .. math.random(1, 1e9)
temp.Parent = RS
for _, name in ipairs({ "CraftConfig", "ShopConfig", "MailConfig", "PremiumConfig", "ItemCatalog" }) do
	RS[name]:Clone().Parent = temp
end
local okLoad, err = pcall(function()
	return require(temp.ShopConfig), require(temp.ItemCatalog)
end)
local ShopConfig, ItemCatalog
if okLoad then ShopConfig, ItemCatalog = require(temp.ShopConfig), require(temp.ItemCatalog) end
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end
check(okLoad, "โหลดโมดูล" .. (okLoad and "" or " " .. tostring(err)))
if okLoad then
	check(ShopConfig.GemRate == 250, "1 เพชร = 250 เหรียญ")
	check(type(ShopConfig.PricesOf) == "function" and type(ShopConfig.PriceFor) == "function"
		and type(ShopConfig.GemsFor) == "function", "มีฟังก์ชันราคา")
	local cats, seen = {}, {}
	for _, c in ipairs(ShopConfig.IslandCategories or {}) do cats[c.id] = 0 end
	check(#(ShopConfig.IslandCategories or {}) == 5, "5 หมวด")
	if ShopConfig.PricesOf then
		local byId, plotRows = {}, 0
		for _, row in ipairs(ShopConfig.IslandSells) do
			local coins, gems = ShopConfig.PricesOf(row)
			check(cats[row.category] ~= nil, row.id .. " มีหมวด (" .. tostring(row.category) .. ")")
			if cats[row.category] then cats[row.category] += 1 end
			check(type(coins) == "number" and coins > 0 and coins % 1 == 0, row.id .. " มีราคาเหรียญ")
			check(type(gems) == "number" and gems >= 1 and gems % 1 == 0, row.id .. " มีราคาเพชร")
			if row.coins and not row.gems then check(gems == math.max(1, math.ceil(row.coins / 250)), row.id .. " เพชรปัดขึ้น") end
			if row.gems and not row.coins then check(coins == row.gems * 250, row.id .. " เหรียญ = เพชร x250") end
			check(row.price == nil and row.currency == nil, row.id .. " ไม่ใช้ price/currency แบบเก่า")
			if row.id == "FarmPlot" then plotRows += 1 end
			byId[row.id] = { coins, gems }
			seen[row.id] = true
		end
		for id, n in pairs(cats) do check(n > 0, "หมวด " .. id .. " มีของ") end
		check(plotRows == 1, "แปลงดินแถวเดียว (สองราคาในแถวเดียว)")
		local function is(id, coins, gems)
			local p = byId[id]
			check(p and p[1] == coins and p[2] == gems,
				("%s = 💰%d / 💎%d (ได้ %s)"):format(id, coins, gems, p and (p[1] .. "/" .. p[2]) or "ไม่มี"))
		end
		is("Seed", 250, 1)
		is("FarmPlot", 10000, 40)
		is("Wild_DiamondOre", 62500, 250)
		is("House_StoneCottage", 20000, 80)
		is("AnimalPen", 15000, 60)
		is("MineZone", 30000, 120)
		is("Pet_Cat", 62500, 250)
		check(ShopConfig.GemsFor(400) == 2 and ShopConfig.GemsFor(3000) == 12 and ShopConfig.GemsFor(1) == 1,
			"สัตว์คอก 400 = 2 เพชร · 3000 = 12 · 1 = 1")
		local main = ShopConfig.Sells[1]
		local c, g = ShopConfig.PricesOf(main)
		check(c == main.price and g == nil, "ร้านเกมหลักยังเหรียญอย่างเดียว")
		check(ShopConfig.PriceFor(main, "gems") == nil, "ขอเพชรกับแถวร้านเกมหลัก = ไม่มีราคา")
		check(ShopConfig.PriceFor(main, "coins") == main.price and ShopConfig.PriceFor(main, nil) == main.price,
			"ขอเหรียญ/ไม่ระบุ = ราคาเดิม")
		check(ShopConfig.PriceFor({ id = "X", coins = 500 }, "gems") == 2, "PriceFor เพชรคำนวณให้")
		for id in pairs(seen) do
			check(ItemCatalog.IsMailable(id) == false, id .. " ส่งเมลไม่ได้")
		end
		check(ItemCatalog.IsMailable("Stone") == true, "วัตถุดิบทั่วไปยังส่งได้")
	end
end
temp:Destroy()
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
