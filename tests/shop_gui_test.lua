-- node tools/lua.js tests/shop_gui_test.lua Edit
-- เฟส 2a: หน้าร้านเกาะมี 5 แท็บ · สองปุ่มซื้อ 💎/💰 ทุกแถว · แท็บไม่เด้งกลับตอนหน้าต่างวาดใหม่หลังซื้อ ·
-- ร้านเกมหลัก (ไม่มีหมวด) หน้าตาเดิม: ไม่มีแท็บ ปุ่มซื้อปุ่มเดียว
-- Studio บล็อกการโคลนโมดูลเข้า ReplicatedStorage จาก execute_luau (2026-10-02) → โฟลเดอร์ Sandboxed ใน ServerStorage
local mirror = Instance.new("Folder")
mirror.Name = "ShopGuiMirror"
mirror.Sandboxed = true
mirror.Capabilities = SecurityCapabilities.new(Enum.SecurityCapability.Basic, Enum.SecurityCapability.CreateInstances,
	Enum.SecurityCapability.UI, Enum.SecurityCapability.RunServerScript, Enum.SecurityCapability.Input)
mirror.Parent = game.ServerStorage
game.ReplicatedStorage.UI:Clone().Parent = mirror
game.ReplicatedStorage.SoundscapeConfig:Clone().Parent = mirror -- UiSound อ่านจาก script.Parent.Parent

local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local function rows(list)
	local found = {}
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then found[#found + 1] = c end
	end
	return found
end

local ShopGui = require(mirror.UI.ShopGui)
local okNew, shop = pcall(ShopGui.new)
check(okNew, "สร้างหน้าร้านได้ใน Edit (ไม่ต้องมี LocalPlayer) " .. (okNew and "" or tostring(shop)))

if okNew then
	local cats = {
		{ id = "house", label = "บ้าน" }, { id = "decor", label = "ของตกแต่ง" }, { id = "utility", label = "ของใช้" },
		{ id = "animal", label = "สัตว์" }, { id = "farm", label = "เพาะปลูก" },
	}
	local island = {
		categories = cats, gold = 5000, gems = 10, rerollIn = 0, buys = {},
		sells = {
			{ index = 1, id = "House_StoneCottage", name = "กระท่อมหิน", icon = "", coins = 20000, gems = 80, category = "house" },
			{ index = 2, id = "Deco_Rock", name = "ก้อนหิน", icon = "", coins = 750, gems = 3, category = "decor" },
			{ index = 3, id = "Seed", name = "เมล็ด", icon = "", coins = 250, gems = 1, category = "farm", count = 3 },
		},
	}
	shop:Show(island)
	local tabs = shop.gui:FindFirstChild("Tabs", true)
	local tabButtons = 0
	if tabs then
		for _, c in ipairs(tabs:GetChildren()) do
			if c:IsA("TextButton") then tabButtons += 1 end
		end
	end
	check(tabs ~= nil and tabs.Visible and tabButtons == 5, ("แถบแท็บ 5 ปุ่ม (ได้ %d)"):format(tabButtons))

	local shown = rows(shop.sellList)
	check(#shown == 1 and shown[1].LayoutOrder == 1, ("แท็บแรก (บ้าน) โชว์แถวเดียว ได้ %d"):format(#shown))
	if shown[1] then
		check(shown[1]:FindFirstChild("BuyGems") ~= nil and shown[1]:FindFirstChild("BuyCoins") ~= nil,
			"แถวมีปุ่ม 💎 และ 💰")
		local g, c = shown[1]:FindFirstChild("BuyGems"), shown[1]:FindFirstChild("BuyCoins")
		check(g and g.Text:find("80") and c and c.Text:find("20,000"),
			("ปุ่มบอกราคา (💎 %s · 💰 %s)"):format(g and g.Text or "-", c and c.Text or "-"))
	end

	check(type(shop.SelectTab) == "function", "มี SelectTab")
	if shop.SelectTab then
		shop:SelectTab("decor")
		shown = rows(shop.sellList)
		check(#shown == 1 and shown[1].LayoutOrder == 2, "เลือกแท็บของตกแต่ง = เห็นก้อนหิน")
		shop:Show(island) -- เซิร์ฟเวอร์ส่งภาพใหม่หลังทุกการซื้อ
		shown = rows(shop.sellList)
		check(#shown == 1 and shown[1].LayoutOrder == 2, "วาดใหม่แล้วยังอยู่แท็บเดิม")
	end
	check(shop.purse.Text:find("💰") ~= nil and shop.purse.Text:find("💎") ~= nil,
		"กระเป๋าเงินบอกทั้งสองสกุล: " .. shop.purse.Text)

	-- ของที่ซื้อได้ขึ้นก่อนของ 🔒 ทุกแท็บ (ผู้ใช้สั่ง 2026-09-28: คอกสัตว์ตกไปล่างสุด ต้องเลื่อนหา)
	if shop.SelectTab then
		shop:SelectTab("animal")
		shop:Show({ categories = cats, gold = 0, gems = 0, rerollIn = 0, buys = {}, sells = {
			{ index = 5, id = "Pet_Wolf", name = "หมาป่า", icon = "", coins = 65000, gems = 260, category = "animal",
				lock = "🔒 ปลดที่เลเวลฟาร์ม 19" },
			{ index = 9, id = "AnimalPen", name = "คอกสัตว์", icon = "", coins = 15000, gems = 60, category = "animal" },
		} })
		shown = rows(shop.sellList)
		table.sort(shown, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		check(#shown == 2 and shown[1]:FindFirstChild("BuyCoins") ~= nil and shown[2]:FindFirstChild("Locked") ~= nil,
			"แถวที่ซื้อได้ (คอก index 9) อยู่เหนือแถว 🔒 (หมาป่า index 5)")
	end

	-- ร้านเกมหลัก: ไม่มีหมวด ไม่มีเพชร
	shop:Show({ gold = 100, rerollIn = 0, buys = {},
		sells = { { index = 1, id = "Bread", name = "ขนมปัง", icon = "", coins = 120 } } })
	tabs = shop.gui:FindFirstChild("Tabs", true)
	check(tabs == nil or not tabs.Visible, "ร้านเกมหลักไม่มีแท็บ")
	shown = rows(shop.sellList)
	check(#shown == 1 and shown[1]:FindFirstChild("Buy") ~= nil and shown[1]:FindFirstChild("BuyGems") == nil,
		"ร้านเกมหลักปุ่มซื้อปุ่มเดียว")
	check(shop.purse.Text == "เงิน 100", "กระเป๋าเงินร้านเกมหลักเหมือนเดิม: " .. shop.purse.Text)

	-- 2026-10-02 ผู้ใช้สั่ง: ราคาเกินเงินในกระเป๋า = ปุ่มแดง · แถวที่เต็มเพดาน = ปุ่ม "เต็ม" แทน 🔒
	local buyRow = rows(shop.sellList)[1]
	check(buyRow and buyRow.Buy:GetAttribute("Short") == true, "ร้านเกมหลัก: เงิน 100 ซื้อขนมปัง 120 = ปุ่มแดง")
	shop:Show({ gold = 500, rerollIn = 0, buys = {},
		sells = { { index = 1, id = "Bread", name = "ขนมปัง", icon = "", coins = 120 } } })
	buyRow = rows(shop.sellList)[1]
	check(buyRow and not buyRow.Buy:GetAttribute("Short"), "ร้านเกมหลัก: เงินพอ = ปุ่มสีปกติ")
	if shop.SelectTab then
		shop:SelectTab("house")
		shop:Show(island) -- เงิน 5,000 · เพชร 10
		local house = rows(shop.sellList)[1]
		check(house and house.BuyCoins:GetAttribute("Short") == true and house.BuyGems:GetAttribute("Short") == true,
			"กระท่อมหิน 20,000/💎80 เงินไม่พอทั้งสองสกุล = แดงทั้งสองปุ่ม")
		shop:SelectTab("decor")
		local rock = rows(shop.sellList)[1]
		check(rock and not rock.BuyCoins:GetAttribute("Short") and not rock.BuyGems:GetAttribute("Short"),
			"ก้อนหิน 750/💎3 เงินพอ = สีปกติทั้งสองปุ่ม")
		-- ช่องจำนวน: เงิน 5,000 ซื้อหิน 750 ได้ 6 ครั้ง (เพชร 10 ได้ 3) พิมพ์ 30 = เด้งเป็น 6
		local amount = rock and rock:FindFirstChildWhichIsA("TextBox")
		if amount then
			amount.Text = "30"
			task.wait()
			task.wait()
		end
		check(amount and amount.Text == "6", "พิมพ์ 30 ในช่องจำนวน = เด้งเป็น 6 (ซื้อได้สูงสุด): " .. tostring(amount and amount.Text))
		shop:SelectTab("animal")
		shop:Show({ categories = cats, gold = 0, gems = 0, rerollIn = 0, buys = {}, sells = {
			{ index = 9, id = "AnimalPen", name = "คอกสัตว์", icon = "", coins = 7500, gems = 30, category = "animal",
				lock = "🐄 คอกสัตว์เต็มแล้ว (2/2 คอก)", full = true },
			{ index = 5, id = "Pet_Wolf", name = "หมาป่า", icon = "", coins = 65000, gems = 260, category = "animal",
				lock = "🔒 ปลดที่เลเวลฟาร์ม 19" },
		} })
		local pen, wolf
		for _, r in ipairs(rows(shop.sellList)) do
			if r.LayoutOrder == 100009 then pen = r elseif r.LayoutOrder == 100005 then wolf = r end
		end
		check(pen and pen.Locked.Text == "เต็ม", "คอกเต็มเพดาน = ปุ่ม \"เต็ม\": " .. tostring(pen and pen.Locked.Text))
		check(wolf and wolf.Locked.Text == "🔒", "ยังไม่ปลดเลเวล = 🔒 เหมือนเดิม")
	end
	shop.gui:Destroy()
end

mirror:Destroy()
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
