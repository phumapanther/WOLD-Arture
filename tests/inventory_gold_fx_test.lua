-- node tools/lua.js tests/inventory_gold_fx_test.lua Edit
-- ช่องของขอบทองในกระเป๋า (ผู้ใช้เลือก 2026-09-27 "แสงวิ่งรอบกรอบ + ประกาย"): แสงวิ่ง (UIGradient บนกรอบ) +
-- พื้นเรืองทอง + ประกายสองจุด · ไม่มีตัวอักษรสัญลักษณ์ที่มุม · ช่องธรรมดาไม่มี · ของย้ายออก = ล้างหมด ·
-- วาดซ้ำไม่สร้างซ้อน
local clones = {}
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	clones[#clones + 1] = copy
	local ok, result = pcall(require, copy)
	assert(ok, result)
	return result
end
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local function fx(entry)
	local sparkles = 0
	for _, c in ipairs(entry.button:GetChildren()) do
		if c.Name == "GoldSparkle" then sparkles += 1 end
	end
	return sparkles, entry.stroke:FindFirstChildOfClass("UIGradient") ~= nil
end

-- โคลนทั้งชุดลงโฟลเดอร์ชั่วคราว (ทุกตัว require กันด้วย script.Parent) — Studio แคช require ข้ามการรัน
-- โคลนแค่ InventoryGui จะได้ ItemCatalog ตัวเก่าที่ยังไม่มี IsGoldBorder
local RS = game.ReplicatedStorage
local temp = Instance.new("Folder")
temp.Name = "GoldFxTest_" .. math.random(1, 1e9)
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
	local gui = InventoryGui.new()
	local function render(slots)
		gui:Render({ slots = slots, equipped = {}, gold = 0, hotbar = {} })
	end
	render({ { id = "Egg", count = 1, meta = { gold = true } }, { id = "Egg", count = 3 } })
	local goldEntry, plainEntry = gui.slotButtons[1], gui.slotButtons[2]
	local s1, g1 = fx(goldEntry)
	check(s1 == 2 and g1, ("ช่องทอง: ประกาย %d จุด · แสงวิ่ง %s"):format(s1, tostring(g1)))
	check(goldEntry.count.Text == "", "ไม่มีตัวอักษรสัญลักษณ์ที่มุม (เดิม ✦ ขึ้นเป็นกล่องเปล่า)")
	check(goldEntry.button.BackgroundColor3 ~= plainEntry.button.BackgroundColor3, "พื้นช่องทองต่างจากช่องธรรมดา")
	local s2, g2 = fx(plainEntry)
	check(s2 == 0 and not g2, "ช่องธรรมดาไม่มีเอฟเฟกต์")

	render({ { id = "Egg", count = 1, meta = { gold = true } }, { id = "Egg", count = 3 } })
	s1 = fx(goldEntry)
	check(s1 == 2, "วาดซ้ำไม่สร้างประกายซ้อน (ได้ " .. s1 .. ")")

	render({ false, { id = "Egg", count = 3 } })
	s1, g1 = fx(goldEntry)
	check(s1 == 0 and not g1 and goldEntry.button.BackgroundColor3 == plainEntry.button.BackgroundColor3,
		"ของย้ายออก = ล้างเอฟเฟกต์ พื้นคืนปกติ")
	gui.gui:Destroy()
end)
check(ok, "รันจบ " .. tostring(err or ""))
for _, c in ipairs(clones) do c:Destroy() end
temp:Destroy()
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
