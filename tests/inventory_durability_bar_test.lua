-- node tools/lua.js tests/inventory_durability_bar_test.lua Edit
-- แถบความคงทนใต้รูปไอเทมในกระเป๋า (ผู้ใช้สั่ง 2026-09-29): เขียว · ต่ำกว่าครึ่ง = เหลือง · ไม่ถึง 5% = แดง ·
-- ของไม่มีความคงทน / ไม่มีวันพัง = ไม่มีแถบ · ของย้ายออก = แถบหาย
local clones = {}
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

-- โคลนทั้งชุด (Studio แคช require ข้ามการรัน) ทรงเดียวกับ inventory_gold_fx_test
local RS = game.ReplicatedStorage
local temp = Instance.new("Folder")
temp.Name = "DurBarTest_" .. math.random(1, 1e9)
temp.Parent = RS
for _, name in ipairs({ "ItemCatalog", "CraftConfig", "ShopConfig", "MailConfig", "PremiumConfig",
	"InventoryConfig", "FishingConfig", "SoundscapeConfig" }) do
	RS[name]:Clone().Parent = temp
end
local ui = Instance.new("Folder")
ui.Name = "UI"
ui.Parent = temp
for _, name in ipairs({ "InventoryGui", "ItemIcon", "UiSound", "Responsive" }) do
	RS.UI[name]:Clone().Parent = ui
end

local ok, err = pcall(function()
	local InventoryGui = require(ui.InventoryGui)
	local C = InventoryGui.DurabilityColours
	check(C ~= nil, "มีตารางสีแถบ")
	local gui = InventoryGui.new()
	gui:Render({ gold = 0, equipped = {}, hotbar = {}, slots = {
		{ id = "Sword", count = 1, durability = 120 }, -- 100% เขียว
		{ id = "Sword", count = 1, durability = 60 }, -- 50% ยังเขียว (ต่ำกว่าครึ่งถึงเหลือง)
		{ id = "Sword", count = 1, durability = 59 }, -- 49% เหลือง
		{ id = "Sword", count = 1, durability = 5 }, -- 4.2% แดง
		{ id = "LeatherArmor", count = 1, durability = 30 }, -- เกราะใช้ armor เป็นเพดาน = 50% เขียว
		{ id = "Egg", count = 3 }, -- ไม่มีความคงทน
		{ id = "GoldAxe", count = 1, durability = 100 }, -- ไม่มีวันพัง
	} })
	local function bar(i) return gui.slotButtons[i].durBar end
	check(bar(1) and bar(1).Visible and bar(1).Fill.BackgroundColor3 == C.good
		and math.abs(bar(1).Fill.Size.X.Scale - 1) < 1e-6, "เต็ม = เขียว เต็มแถบ")
	check(bar(2).Visible and bar(2).Fill.BackgroundColor3 == C.good, "ครึ่งพอดี = ยังเขียว")
	check(bar(3).Visible and bar(3).Fill.BackgroundColor3 == C.low, "ต่ำกว่าครึ่ง = เหลือง")
	check(bar(4).Visible and bar(4).Fill.BackgroundColor3 == C.critical, "ไม่ถึง 5% = แดง")
	check(bar(5).Visible and bar(5).Fill.BackgroundColor3 == C.good
		and math.abs(bar(5).Fill.Size.X.Scale - 0.5) < 1e-6, "เกราะ: เพดานจาก armor")
	check(not bar(6).Visible, "ของไม่มีความคงทน = ไม่มีแถบ")
	check(not bar(7).Visible, "ของไม่มีวันพัง = ไม่มีแถบ")

	gui:Render({ gold = 0, equipped = {}, hotbar = {}, slots = { false, { id = "Egg", count = 1 } } })
	check(not bar(1).Visible, "ช่องว่างหลังของย้ายออก = ไม่มีแถบค้าง")
	gui.gui:Destroy()
end)
check(ok, "รันจบ " .. tostring(err or ""))
temp:Destroy()
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
