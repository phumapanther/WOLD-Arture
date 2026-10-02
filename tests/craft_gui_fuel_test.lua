-- WOLD_PLACE=136992335889132 node tools/lua.js tests/craft_gui_fuel_test.lua Edit   (เพลสไหนก็ได้)
-- แถบเชื้อเพลิงในหน้าต่างคราฟ (ผู้ใช้สั่ง 2026-10-02): มีเฉพาะเครื่องที่ต้องเติมถ่าน · บอก % · สูตรที่เชื้อเพลิงไม่พอกดไม่ได้
-- และบอก ⛽ เป็นสีแดง · ช่องเติมถ่านเด้งเป็นจำนวนที่เติมได้จริง (ถ่านที่มี / ที่ว่างในถัง)
local mirror = Instance.new("Folder")
mirror.Name = "CraftFuelMirror"
mirror.Sandboxed = true
mirror.Capabilities = SecurityCapabilities.new(Enum.SecurityCapability.Basic, Enum.SecurityCapability.CreateInstances,
	Enum.SecurityCapability.UI, Enum.SecurityCapability.RunServerScript, Enum.SecurityCapability.Input)
mirror.Parent = game.ServerStorage
game.ReplicatedStorage.UI:Clone().Parent = mirror
for _, m in ipairs(game.ReplicatedStorage:GetChildren()) do
	if m:IsA("ModuleScript") and m.Name ~= "Remotes" then m:Clone().Parent = mirror end
end

local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local gui
local ok, err = pcall(function()
	local CraftGui = require(mirror.UI.CraftGui)
	gui = CraftGui.new()
	local function recipe(index, name, seconds)
		return { index = index, tab = "bakery", name = name, icon = "", affordable = true, seconds = seconds,
			materials = { { name = "ข้าว", icon = "", have = 9, need = 3 } } }
	end
	local function snap(fuel)
		return { tabs = { { id = "bakery", name = "เตาอบ" } }, station = "bakery", title = "เตาอบ",
			recipes = { recipe(1, "เนย", 300), recipe(2, "ข้าวโพดอบเนย", 2700) }, fuel = fuel }
	end

	gui:Show(snap({ amount = 900, coal = 5 })) -- 12.5% · ถ่าน 5 ก้อน
	check(gui.fuelStrip and gui.fuelStrip.Visible, "เครื่องบนเกาะ = มีแถบเชื้อเพลิง")
	check(gui.fuelText and gui.fuelText.Text:find("12%", 1, true), "บอกเปอร์เซ็นต์: " .. tostring(gui.fuelText and gui.fuelText.Text))
	local butter, corn = gui.rows[1], gui.rows[2]
	check(butter.button.AutoButtonColor == true and butter.odds.Text:find("⛽", 1, true), "เนย 5 นาที เชื้อเพลิงพอ = กดได้ · บอก ⛽")
	check(corn.button.AutoButtonColor == false and corn.odds.Text:find("38%", 1, true),
		"ข้าวโพดอบเนย 45 นาที ต้องใช้ 38% มี 12% = กดไม่ได้: " .. corn.odds.Text)
	gui.fuelBox.Text = "30"
	task.wait()
	task.wait()
	check(gui.fuelBox.Text == "5", "พิมพ์ 30 = เด้งเป็นถ่านที่มี 5: " .. gui.fuelBox.Text)

	gui:Show(snap({ amount = 7000, coal = 40 })) -- เหลือที่ 1 ก้อน
	gui.fuelBox.Text = "30"
	task.wait()
	task.wait()
	check(gui.fuelBox.Text == "1", "ถังเกือบเต็ม = เติมได้แค่ 1 ก้อน: " .. gui.fuelBox.Text)

	-- ปุ่มเร่ง (2026-10-02): โผล่เฉพาะตอนเครื่องนี้ทำงานอยู่และมีเชื้อเพลิง
	local busySnap = snap({ amount = 900, coal = 5 })
	busySnap.busy = { index = 1, remaining = 200, seconds = 300 }
	gui:Show(busySnap)
	check(gui.boostButton and gui.boostButton.Visible, "เครื่องทำงาน + มีเชื้อเพลิง = มีปุ่มเร่ง")
	local emptySnap = snap({ amount = 0, coal = 5 })
	emptySnap.busy = { index = 1, remaining = 200, seconds = 300 }
	gui:Show(emptySnap)
	check(gui.boostButton and not gui.boostButton.Visible, "ไม่มีเชื้อเพลิง = ไม่มีปุ่มเร่ง")
	gui:Show(snap({ amount = 900, coal = 5 }))
	check(gui.boostButton and not gui.boostButton.Visible, "เครื่องว่าง = ไม่มีปุ่มเร่ง")

	-- 💎 เสร็จทันที (2026-10-02): ทุกเครื่องที่มีงานเหลือ ≥ 10 วิ · ราคาตามเวลาที่เหลือ (1 เพชร / 5 นาที)
	check(gui.instantButton and not gui.instantButton.Visible, "เครื่องว่าง = ไม่มีปุ่มเสร็จทันที")
	local long = snap(nil) -- เกมหลัก (ไม่มีเชื้อเพลิง) ก็มี
	long.busy = { index = 2, remaining = 2700, seconds = 2700 }
	gui:Show(long)
	check(gui.instantButton and gui.instantButton.Visible and gui.instantButton.Text:find("9", 1, true),
		"เหลือ 45 นาที = 💎 9: " .. tostring(gui.instantButton and gui.instantButton.Text))
	local hammer = snap(nil) -- ค้อนช่างตีเหล็ก 2.5 วิ ไม่ต้องมีปุ่มเพชร
	hammer.busy = { index = 1, remaining = 2, seconds = 2.5 }
	gui:Show(hammer)
	check(gui.instantButton and not gui.instantButton.Visible, "เหลือ 2 วิ = ไม่มีปุ่มเสร็จทันที")

	gui:Show(snap(nil))
	check(not gui.fuelStrip.Visible, "เครื่องที่ไม่ใช้เชื้อเพลิง (ช่างตีเหล็ก/เกมหลัก) = ไม่มีแถบ")
	check(not gui.rows[2].odds.Text:find("⛽", 1, true) and gui.rows[2].button.AutoButtonColor == true,
		"ไม่มีเชื้อเพลิงในสแนปช็อต = แถวไม่บอก ⛽ และไม่ถูกล็อก")
end)
if gui and gui.gui then gui.gui:Destroy() end
mirror:Destroy()
if not ok then fails += 1 out[#out + 1] = "ERROR " .. tostring(err) end
return ("%s — %d fail\n%s"):format(fails == 0 and "PASS" or "FAIL", fails, table.concat(out, "\n"))
