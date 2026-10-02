-- WOLD_PLACE=136992335889132 node tools/lua.js tests/craft_gui_busy_test.lua Edit   (เพลสไหนก็ได้)
-- หน้าต่างคราฟตอนเครื่องกำลังทำงาน (ผู้ใช้สั่ง 2026-10-02): แถวที่กำลังทำ = "กำลังทำ..." · แถวอื่น = "รอสักครู่" กดไม่ได้ ·
-- งานที่คืนมาหลังเข้าเกมใหม่ (สแนปช็อต busy ไม่มี index) ต้องล็อกทุกแถวด้วย — เดิมปุ่ม "ทำ" กลับมากดได้
local mirror = Instance.new("Folder")
mirror.Name = "CraftGuiMirror"
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

local gui
local ok, err = pcall(function()
	local CraftGui = require(mirror.UI.CraftGui)
	gui = CraftGui.new()
	local function recipe(index, name)
		return { index = index, tab = "bakery", name = name, icon = "", affordable = true, seconds = 300,
			materials = { { name = "ข้าว", icon = "", have = 9, need = 3 } } }
	end
	local function snap(busy)
		return { tabs = { { id = "bakery", name = "เตาอบ" } }, station = "bakery", title = "เตาอบ",
			recipes = { recipe(1, "แป้งสาลี"), recipe(2, "แป้งโด") }, busy = busy }
	end
	local function buttons()
		return gui.rows[1].button, gui.rows[2].button
	end

	gui:Show(snap(nil))
	local a, b = buttons()
	check(a.Text == "ทำ" and not a:GetAttribute("Busy"), "เครื่องว่าง = ปุ่ม \"ทำ\" กดได้")

	gui:Show(snap({ index = 1, remaining = 120, seconds = 300 }))
	a, b = buttons()
	check(a.Text == "กำลังทำ..." and a:GetAttribute("Busy"), "แถวที่กำลังทำ = \"กำลังทำ...\"")
	check(b.Text == "รอสักครู่" and b:GetAttribute("Busy"), "แถวอื่น = \"รอสักครู่\" กดไม่ได้: " .. b.Text)

	gui:Show(snap({ remaining = 120, seconds = 300 }))
	a, b = buttons()
	check(a:GetAttribute("Busy") and b:GetAttribute("Busy") and a.Text == "รอสักครู่" and b.Text == "รอสักครู่",
		"งานคืนมาหลังเข้าเกมใหม่ (ไม่มี index) = ทุกแถว \"รอสักครู่\": " .. a.Text .. " / " .. b.Text)

	gui:Show(snap(nil))
	a, b = buttons()
	check(a.Text == "ทำ" and not a:GetAttribute("Busy"), "งานจบแล้วเปิดใหม่ = กลับมาเป็น \"ทำ\"")
end)
if gui and gui.gui then gui.gui:Destroy() end
mirror:Destroy()
if not ok then fails += 1 out[#out + 1] = "ERROR " .. tostring(err) end
return ("%s — %d fail\n%s"):format(fails == 0 and "PASS" or "FAIL", fails, table.concat(out, "\n"))
