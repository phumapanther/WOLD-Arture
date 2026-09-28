-- node tools/lua.js tests/social_market_test.lua Edit
-- หน้า "ราคากลาง" บนหินเวท (ผู้ใช้สั่ง 2026-09-28): บอกว่าราคาขึ้น/ลงจากรอบก่อนเท่าไหร่
-- ลูกศร ⬆ เขียว / ⬇ แดง + ส่วนต่าง · ราคาเก่าสีเทาเข้ม → ราคาใหม่สีทอง · ไม่เปลี่ยน = "คงที่"
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

-- ข้อความของแถวที่ชื่อนี้ รวมทุก TextLabel ในแถว
local function rowText(list, name)
	for _, row in ipairs(list:GetChildren()) do
		if row:IsA("Frame") then
			local texts, hit = {}, false
			for _, d in ipairs(row:GetDescendants()) do
				if d:IsA("TextLabel") then
					texts[#texts + 1] = d.Text
					if d.Text == name then hit = true end
				end
			end
			if hit then return table.concat(texts, " | ") end
		end
	end
	return nil
end

local SocialGui = fresh(game.ReplicatedStorage.UI.SocialGui)
local okNew, gui = pcall(SocialGui.new)
check(okNew, "สร้างหน้าหินเวทได้ใน Edit " .. (okNew and "" or tostring(gui)))
if okNew then
	gui:RenderMarket({ rerollIn = 600, prices = {
		{ id = "Shark", name = "ฉลาม", icon = "", price = 150, previous = 120 },
		{ id = "Diamond", name = "เพชร", icon = "", price = 100, previous = 120 },
		{ id = "Egg", name = "ไข่", icon = "", price = 4, previous = 4 },
		{ id = "Stone", name = "ก้อนหิน", icon = "", price = 1 }, -- เซิร์ฟรุ่นเก่าไม่ส่ง previous
	} })
	local up, down, same, old = rowText(gui.marketList, "ฉลาม"), rowText(gui.marketList, "เพชร"),
		rowText(gui.marketList, "ไข่"), rowText(gui.marketList, "ก้อนหิน")
	check(up and up:find("⬆") and up:find("+30", 1, true) and up:find("120") and up:find("150")
		and up:find("→"), "ขึ้น: ⬆ +30 · 120 → 150  [" .. tostring(up) .. "]")
	check(up and up:find("#4CD964", 1, true) ~= nil, "ขึ้น = สีเขียว")
	check(down and down:find("⬇") and down:find("-20", 1, true) and down:find("#FF5A5A", 1, true),
		"ลง: ⬇ -20 สีแดง  [" .. tostring(down) .. "]")
	check(up and up:find("#6E6E6E", 1, true) and up:find("#D8AC54", 1, true),
		"ราคาเก่าสีเทาเข้ม ราคาใหม่สีทอง")
	check(same and same:find("คงที่") and not same:find("⬆") and not same:find("⬇"), "ไม่เปลี่ยน = คงที่  [" .. tostring(same) .. "]")
	check(old and old:find("1") and not old:find("→"), "ไม่มีราคาเก่า = โชว์ราคาเดียว  [" .. tostring(old) .. "]")
	gui.gui:Destroy()
end

for _, c in ipairs(clones) do c:Destroy() end
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
