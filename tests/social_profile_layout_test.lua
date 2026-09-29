-- node tools/lua.js tests/social_profile_layout_test.lua Edit
-- หน้าโปรไฟล์บนหินเวท: ปุ่ม "แสดงการ์ดโปรไฟล์" ต้องไม่ทับแถวข้อมูล (ผู้ใช้เจอ 2026-09-29 — ทับแถวเพศ/แร็งก์ PVP)
-- ตรวจจากตำแหน่งที่เขียนไว้ (Offset ของแกน Y) เพราะหน้านี้วางลูกด้วยพิกัดตรงๆ ไม่มี layout
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

local SocialGui = fresh(game.ReplicatedStorage.UI.SocialGui)
local okNew, gui = pcall(SocialGui.new)
check(okNew, "สร้างหน้าหินเวทได้ใน Edit " .. (okNew and "" or tostring(gui)))
if okNew then
	local page = gui.screens.profile
	-- แถบของลูกทุกตัวที่เป็นแถวเต็มความกว้าง (ข้อมูล · แร็งก์ · ปุ่ม · หมายเหตุ)
	local spans = {}
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("GuiObject") and child.Size.X.Scale == 1 and child.Position.Y.Scale == 0 then
			local top = child.Position.Y.Offset
			local name = child:IsA("TextButton") and child.Text ~= "" and child.Text
				or child.Name ~= "Frame" and child.Name ~= "TextLabel" and child.Name
				or (child:IsA("TextLabel") and child.Text) or child.ClassName
			spans[#spans + 1] = { name = name, top = top, bottom = top + child.Size.Y.Offset }
		end
	end
	table.sort(spans, function(a, b) return a.top < b.top end)
	for i = 2, #spans do
		local a, b = spans[i - 1], spans[i]
		check(b.top >= a.bottom, ("%s (%d-%d) ไม่ทับ %s (%d-%d)"):format(
			tostring(b.name), b.top, b.bottom, tostring(a.name), a.top, a.bottom))
	end
	local last = spans[#spans]
	check(page.CanvasSize.Y.Offset >= last.bottom, ("เลื่อนได้ถึงแถวสุดท้าย (แคนวาส %d ≥ %d)"):format(
		page.CanvasSize.Y.Offset, last.bottom))
	gui.gui:Destroy()
end

for _, c in ipairs(clones) do c:Destroy() end
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
