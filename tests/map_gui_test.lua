-- WOLD_PLACE=88774255487951 node tools/lua.js tests/map_gui_test.lua Edit
-- แผนที่ v2 (2026-10-02): พื้นเป็นรูป 2x2 · หมุดสถานที่คงที่ · SetPois แทนชุดเดิม · ซูมขั้นต่ำ/กรอง · ขอบทองหมุดนำทาง ·
-- แตะหมุด = poi ไม่ใช่ปักหมุดพื้น · แตะปุ่มกรองไม่ทะลุลงแผนที่ · หมุดขนาดคงที่ทุกซูม
-- Studio บล็อกการย้ายโมดูลเข้า ReplicatedStorage จาก execute_luau → โคลนเข้าโฟลเดอร์ Sandboxed ใน ServerStorage
local mirror = Instance.new("Folder")
mirror.Name = "MapGuiMirror"
mirror.Sandboxed = true
mirror.Capabilities = SecurityCapabilities.new(Enum.SecurityCapability.Basic, Enum.SecurityCapability.CreateInstances,
	Enum.SecurityCapability.UI, Enum.SecurityCapability.RunServerScript, Enum.SecurityCapability.Input)
mirror.Parent = game.ServerStorage
local RS = game.ReplicatedStorage
for _, name in ipairs({ "MapConfig", "MapTerrain", "MapPoiRules", "Locale", "ItemCatalog", "CraftConfig", "ShopConfig", "MailConfig", "PremiumConfig" }) do RS[name]:Clone().Parent = mirror end -- MapGui แปลชื่อแร่ (ระบบหลายภาษา 2026-10-05)
RS.UI:Clone().Parent = mirror

local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local map
local ok, err = pcall(function()
	local MapGui = require(mirror.UI.MapGui)
	local MapConfig = require(mirror.MapConfig)
	map = MapGui.new()
	local tiles = 0
	for _, c in ipairs(map.canvas:GetChildren()) do if c.Name == "LandTile" then tiles += 1 end end
	check(tiles == 4, "พื้นเป็นรูป 4 แผ่น ได้ " .. tiles)
	local land = 0
	for _, c in ipairs(map.canvas:GetChildren()) do if c.Name == "Land" then land += 1 end end
	check(land == 0, "ไม่วาดพื้นแบบ Frame เมื่อมีรูป")
	map:Zoom(MapConfig.DetailZoom) -- ข้ามเกณฑ์ความละเอียด: ต้องไม่สร้างแผ่นซ้ำ
	tiles = 0
	for _, c in ipairs(map.canvas:GetChildren()) do if c.Name == "LandTile" then tiles += 1 end end
	check(tiles == 4, "ซูมข้ามเกณฑ์ไม่สร้างรูปซ้ำ")
	map.zoom = 1

	check(#map.pins == #MapConfig.Places, ("หมุดสถานที่ %d/%d"):format(#map.pins, #MapConfig.Places))
	map:SetPois({
		{ id = "npc:1", cat = "npc", emoji = "🛒", label = "ร้าน บาร์นาบี", x = 2135, y = 46, z = 3864 },
		{ id = "mine:1", cat = "mine", emoji = "⛏️", label = "เหมือง: เหล็ก", x = 1210, y = 54, z = 2919 },
		{ id = "mob:1", cat = "monster", emoji = "👾", label = "โครงกระดูก", x = 0, y = 0, z = 0 },
		{ id = "bad", cat = "nope", emoji = "?", label = "x", x = 0, z = 0 },
		"garbage",
	})
	check(#map.pins == #MapConfig.Places + 3, "SetPois รับ 3 หมุดถูกต้อง ทิ้งของเสีย")
	map:SetPois({ { id = "npc:1", cat = "npc", emoji = "🛒", label = "ร้าน บาร์นาบี", x = 2135, y = 46, z = 3864 } })
	check(#map.pins == #MapConfig.Places + 1, "SetPois รอบใหม่แทนชุดเดิม หมุดสถานที่อยู่ต่อ")
	local npc, city
	for _, p in ipairs(map.pins) do
		if p.data.cat == "npc" then npc = p end
		if p.data.cat == "city" and not city then city = p end
	end

	map:apply()
	check(city.frame.Visible and not npc.frame.Visible, "ซูม 1: เห็นเมือง ไม่เห็น NPC")
	local size1 = city.frame.Size
	map.zoom = 3
	map:apply()
	check(npc.frame.Visible, "ซูม 3: NPC โผล่")
	check(city.frame.Size == size1, "หมุดขนาดคงที่ทุกซูม")
	map.filters.city = false
	map:apply()
	check(not city.frame.Visible and npc.frame.Visible, "ปิดหมวดเมือง = ซ่อนเฉพาะเมือง")
	map.filters.city = nil

	map:SetWaypoint(Vector3.new(2135, 46, 3864))
	check(npc.stroke.Thickness == 3 and city.stroke.Thickness == 1, "หมุดที่นำทางอยู่ = ขอบทองหนา")
	map:SetWaypoint(nil)
	check(npc.stroke.Thickness == 1, "เลิกนำทาง = ขอบกลับปกติ")

	-- แตะจริงต้องมีเลย์เอาต์: แขวนไว้ที่ StarterGui ชั่วคราว (ถูกลบตอนจบ)
	map.gui.Parent = game.StarterGui
	map.gui.Enabled = true
	map.zoom = 3
	map.offset = Vector2.new(0, 0)
	-- เลื่อนให้ NPC อยู่กลางจอ
	local scale = (map:canvasSize() / map.baseSize) * map.zoom
	map.offset = Vector2.new(-npc.nx * map.baseSize / 2 * scale, -npc.nz * map.baseSize / 2 * scale)
	map:apply()
	task.wait(0.1)
	local centre = npc.frame.AbsolutePosition + npc.frame.AbsoluteSize / 2
	local got = {}
	map:On("poi", function(data) got.poi = data end)
	map:On("pin", function(at) got.pin = at end)
	map:On("unpin", function() got.unpin = true end)
	map:pinAt(Vector3.new(centre.X + 3, centre.Y + 3, 0))
	check(got.poi and got.poi.id == "npc:1" and not got.pin, "แตะหมุด = poi (ไม่ปักหมุดพื้นซ้อน)")
	got = {}
	map:SetWaypoint(Vector3.new(2135, 46, 3864))
	map:pinAt(Vector3.new(centre.X, centre.Y, 0))
	check(got.unpin and not got.poi, "แตะหมุดที่นำทางอยู่ซ้ำ = ยกเลิก")
	map:SetWaypoint(nil)
	got = {}
	local first = map.filterButtons.city.button
	local fb = first.AbsolutePosition + first.AbsoluteSize / 2
	map:pinAt(Vector3.new(fb.X, fb.Y, 0))
	check(not got.poi and not got.pin and map:overFilters(Vector3.new(fb.X, fb.Y, 0)), "แตะปุ่มกรองไม่ทะลุลงแผนที่")
	local below = map.lastFilterButton.AbsolutePosition + map.lastFilterButton.AbsoluteSize + Vector2.new(-10, 30)
	check(not map:overFilters(Vector3.new(below.X, below.Y, 0)) or map.viewport.AbsoluteSize.Y < 420,
		"ใต้ปุ่มกรองยังแตะแผนที่ได้")
	map:hover(Vector3.new(centre.X, centre.Y, 0))
	check(map.tooltip.Visible and map.tooltip.Text == "ร้าน บาร์นาบี", "ชี้เมาส์ที่หมุดย่อย = ชื่อลอย")

	-- รีวิว: หมุดตรงกับจุดบนรูปพื้น (คณิตเดียวกับ canvas) ทุกซูม
	for _, z in ipairs({ 1, 3, 12 }) do
		map.zoom = z
		local s = (map:canvasSize() / map.baseSize) * map.zoom
		map.offset = Vector2.new(-npc.nx * map.baseSize / 2 * s, -npc.nz * map.baseSize / 2 * s)
		map:apply()
		task.wait(0.05)
		local want = map.canvas.AbsolutePosition + Vector2.new((npc.nx + 1) / 2, (npc.nz + 1) / 2) * map.canvas.AbsoluteSize
		local c = npc.frame.AbsolutePosition + npc.frame.AbsoluteSize / 2
		check((want - c).Magnitude < 1.5, ("ซูม %d: หมุดตรงกับพื้น (ห่าง %.2f px)"):format(z, (want - c).Magnitude))
		-- รูปพื้นซ้อนกันไม่เกิน 1 px บนจอ (เดิม +1 หน่วย canvas ถูกซูมขยายเป็นหลายสิบ px = รูปเลื่อนจากหมุด)
		local tile = map.canvas:FindFirstChild("LandTile")
		check(tile.Size.X.Scale == 0.5 and tile.Size.X.Offset * s <= 1.01, ("ซูม %d: แผ่นรูปซ้อนกัน %.2f px"):format(z, tile.Size.X.Offset * s))
	end

	-- รีวิว: จุด "คุณอยู่ที่นี่" ต้องอยู่เหนือหมุด ไม่จมใต้หมุดเมือง
	check(map.youPin.Parent == map.pinLayer and map.youPin.ZIndex > npc.frame.ZIndex + 1, "จุดคุณอยู่ที่นี่อยู่บนหมุด")

	-- รีวิว: นำทางอยู่ที่ร้าน แตะหมุดธนาคารที่อยู่ใกล้ๆ = ไปธนาคาร (ไม่ใช่ยกเลิก)
	map:SetPois({
		{ id = "npc:1", cat = "npc", emoji = "🛒", label = "ร้าน บาร์นาบี", x = 2135, y = 46, z = 3864 },
		{ id = "npc:2", cat = "npc", emoji = "🏦", label = "ธนาคาร", x = 2175, y = 46, z = 3864 },
	})
	local bank
	for _, p in ipairs(map.pins) do if p.data.id == "npc:2" then bank = p end end
	map.zoom = 3
	local s3 = (map:canvasSize() / map.baseSize) * map.zoom
	map.offset = Vector2.new(-bank.nx * map.baseSize / 2 * s3, -bank.nz * map.baseSize / 2 * s3)
	map:apply()
	map:SetWaypoint(Vector3.new(2135, 46, 3864))
	task.wait(0.05)
	got = {}
	local bc = bank.frame.AbsolutePosition + bank.frame.AbsoluteSize / 2
	map:pinAt(Vector3.new(bc.X, bc.Y, 0))
	check(got.poi and got.poi.id == "npc:2" and not got.unpin, "แตะหมุดอื่นใกล้จุดหมาย = นำทางไปหมุดนั้น")
end)
if map then map.gui:Destroy() end
mirror:Destroy()
if not ok then fails += 1 out[#out + 1] = "ERROR " .. tostring(err) end
return ("%s — %d fail\n%s"):format(fails == 0 and "PASS" or "FAIL", fails, table.concat(out, "\n"))
