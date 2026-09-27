-- 102_farm_machines.lua — ต้นแบบของใหม่เฟส 2c: เตาอบขนมปัง · โต๊ะช่างเหล็ก · กี่ทอผ้าไอน้ำ · ต้นฝ้ายในแปลง
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/102_farm_machines.lua --kit --no-lib
--
-- สร้างลง `ReplicatedStorage.WOLD_Placeables` ตามกติกาเดียวกับเฟส 90 (Root = PrimaryPart กึ่งกลางกล่องระดับฐาน ·
-- Footprint จากกล่องจริง · Anchored ทุกชิ้น · หน้าเครื่องหัน −Z) แล้วติด `Manual = true` — เฟส 90 เห็นธงนี้แล้ว
-- ไม่ลบ/ไม่สร้างทับ (ทรงเดียวกับเฟส 101) · รันไฟล์นี้ซ้ำ = สร้างสี่ชิ้นนี้ใหม่ (ชิ้นอื่นไม่ถูกแตะ)
--
-- ชื่อที่ระบบใช้: `FireboxHearth` ในเตาอบ = ที่ `CraftStations.lightFire` จุดไฟตอนอบ · ชื่อต้นแบบตรงกับไอเทม
-- (`IslandBuild` ห่อด้วย Model ลูกชื่อเดิมให้ CraftStations หาเจอ)
local RS = game:GetService("ReplicatedStorage")
local C, MAT = K.C, K.MAT
local CELL = 4
local rgb = Color3.fromRGB

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[FarmMachines] " .. msg)
end

local folder = RS:FindFirstChild("WOLD_Placeables")
assert(folder, "ไม่มี ReplicatedStorage.WOLD_Placeables (รันเฟส 90 ก่อน)")

local function cells(studs) return math.max(1, math.ceil(studs / CELL - 0.05)) end

local built = {}
local function proto(name, fn)
	local old = folder:FindFirstChild(name)
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = name
	fn(m)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.Anchored = true
	root.Parent = m
	m.PrimaryPart = root
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end
	local cf, size = m:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	root.CFrame = CFrame.new(cf.Position.X, bottom, cf.Position.Z)
	m:SetAttribute("Footprint", Vector2.new(cells(size.X), cells(size.Z)))
	m:SetAttribute("Manual", true)
	m.Parent = folder
	built[#built + 1] = ("%s %dx%d ช่อง (%.1f x %.1f x %.1f) %d ชิ้น"):format(name, cells(size.X), cells(size.Z),
		size.X, size.Y, size.Z, K.countParts(m))
end

status("start")

---------------------------------------------------------------- เตาอบขนมปัง (อิฐ โดม ปากเตาเหล็ก ปล่อง)
proto("BakeryOven", function(m)
	local BREAD = rgb(206, 150, 84)
	-- ฐานหิน + ตัวเตาอิฐ + โดม
	K.box(m, K.at(0, 0.6, 0), Vector3.new(6.4, 1.2, 5.2), MAT.Slate, C.darkStone)
	K.box(m, K.at(0, 2.5, 0.2), Vector3.new(5.6, 2.6, 4.6), MAT.Brick, C.brick, { name = "Body" })
	K.ball(m, K.at(0, 3.9, 0.3), 4.7, MAT.Brick, C.brick, { name = "Dome" })
	-- ขอบบนตัวเตา (เส้นหินกันร้าว)
	K.box(m, K.at(0, 3.85, 0.2), Vector3.new(5.8, 0.25, 4.8), MAT.Slate, C.stone, { cancollide = false })
	-- ปากเตา: ช่องมืด + ไฟข้างใน (จุดไฟจริงโดย CraftStations ที่ชิ้น FireboxHearth)
	K.box(m, K.at(0, 2.3, -2.14), Vector3.new(2.3, 1.7, 0.1), MAT.SmoothPlastic, C.black, { cancollide = false, name = "Mouth" })
	K.box(m, K.at(0, 1.62, -2.3), Vector3.new(1.8, 0.3, 0.3), MAT.Metal, C.coal, { cancollide = false, name = "FireboxHearth" })
	K.box(m, K.at(0, 1.82, -2.26), Vector3.new(1.6, 0.12, 0.22), MAT.Neon, C.ember, { cancollide = false, name = "Embers" })
	-- กรอบปากเตาทองเหลือง (โค้งด้วยสามแท่ง) + หมุดย้ำ
	for _, x in ipairs({ -1.3, 1.3 }) do
		K.box(m, K.at(x, 2.25, -2.25), Vector3.new(0.3, 1.9, 0.25), MAT.Metal, C.brassDark, { cancollide = false })
	end
	K.box(m, K.at(0, 3.25, -2.25), Vector3.new(2.9, 0.3, 0.25), MAT.Metal, C.brassDark, { cancollide = false })
	K.rivets(m, Vector3.new(-1.2, 3.25, -2.4), Vector3.new(1.2, 3.25, -2.4), 5, 0.09, C.brass)
	-- บานประตูเหล็กเปิดค้างข้างปาก (บานพับซ้าย)
	K.box(m, K.at(-2.05, 2.3, -2.55) * K.yaw(math.rad(-70)), Vector3.new(1.4, 1.6, 0.12), MAT.Metal, C.iron, { cancollide = false, name = "Door" })
	K.cylX(m, K.at(-1.75, 2.3, -2.95) * K.yaw(math.rad(-70)), 0.12, 0.35, MAT.Metal, C.brass, { cancollide = false })
	-- ชั้นวางหน้าเตา + ขนมปังที่เพิ่งอบ
	K.box(m, K.at(0, 1.3, -2.95), Vector3.new(5.4, 0.25, 0.9), MAT.WoodPlanks, C.plank)
	-- ก้อนขนมปัง = ทรงกระบอกนอน (Ball ของ Roblox ยืดไม่ได้ ถูกบังคับให้กลมเสมอ)
	for i, x in ipairs({ -2.1, -1.4, 1.4, 2.1 }) do
		K.cylX(m, K.at(x, 1.66, -2.95) * K.yaw(math.rad(90 + i * 12)), 0.25, 0.8, MAT.Sand, BREAD, { cancollide = false })
	end
	-- ปล่อง + วาล์ว + เกจ (ไอน้ำร้อนของเตา)
	K.smokestack(m, K.at(1.7, 5.0, 1.4), 0.42, 2.0, { color = C.iron })
	K.pipe(m, { Vector3.new(1.7, 5.4, 1.4), Vector3.new(2.9, 5.4, 1.4), Vector3.new(2.9, 3.4, 1.4) }, 0.13, C.copper)
	K.gauge(m, K.at(3.0, 3.2, -0.6), 0.4, C.brass)
	K.valveWheel(m, K.at(3.05, 2.4, 0.6), 0.45, 5, C.brass)
	-- พายไม้ตักขนมปังพิงข้างเตา
	K.rod(m, Vector3.new(-3.3, 0.2, -1.2), Vector3.new(-2.9, 4.2, -1.4), 0.08, MAT.Wood, C.oak, { cancollide = false })
	K.box(m, CFrame.lookAt(Vector3.new(-3.35, 0.55, -1.18), Vector3.new(-2.9, 4.2, -1.4)) * K.pitch(math.rad(90)),
		Vector3.new(0.8, 0.9, 0.06), MAT.Wood, C.oak, { cancollide = false })
end)
status("BakeryOven")

---------------------------------------------------------------- โต๊ะช่างเหล็ก (ทั่ง ปากกาจับ เตาหลอมเล็ก ที่แขวนเครื่องมือ)
proto("MetalBench", function(m)
	-- ขาโต๊ะ + พื้นโต๊ะหนา + ชั้นล่าง
	for _, x in ipairs({ -3.0, 3.0 }) do
		for _, z in ipairs({ -1.3, 1.3 }) do
			K.box(m, K.at(x, 1.4, z), Vector3.new(0.5, 2.8, 0.5), MAT.Wood, C.wood)
		end
	end
	K.box(m, K.at(0, 3.05, 0), Vector3.new(7.0, 0.5, 3.4), MAT.WoodPlanks, C.oak, { name = "Top" })
	K.box(m, K.at(0, 0.75, 0), Vector3.new(6.4, 0.3, 2.9), MAT.WoodPlanks, C.plankDark)
	-- มุมเหล็กหุ้มขอบโต๊ะ + หมุด
	for _, x in ipairs({ -3.45, 3.45 }) do
		K.box(m, K.at(x, 3.05, 0), Vector3.new(0.14, 0.56, 3.5), MAT.Metal, C.iron, { cancollide = false })
	end
	K.rivets(m, Vector3.new(-3.2, 3.05, -1.75), Vector3.new(3.2, 3.05, -1.75), 8, 0.08, C.brass)
	-- เหล็กแท่งกองบนชั้นล่าง
	for i = 0, 2 do
		K.box(m, K.at(-1.2 + i * 0.7, 1.05 + (i == 1 and 0.28 or 0), 0.2), Vector3.new(0.6, 0.28, 1.2), MAT.Metal, C.steel, { cancollide = false })
	end
	K.box(m, K.at(1.4, 1.05, 0.2), Vector3.new(0.6, 0.28, 1.2), MAT.Metal, rgb(200, 204, 214), { cancollide = false })
	-- ทั่ง (ฝั่งซ้าย): ตีน · เอว · หน้าทั่ง · เขา
	K.box(m, K.at(-1.9, 3.5, 0), Vector3.new(1.2, 0.4, 0.9), MAT.Metal, C.iron)
	K.box(m, K.at(-1.9, 3.85, 0), Vector3.new(0.7, 0.3, 0.6), MAT.Metal, C.iron)
	K.box(m, K.at(-1.9, 4.2, 0), Vector3.new(1.6, 0.4, 0.8), MAT.Metal, C.steel, { name = "Anvil" })
	K.wedge(m, K.at(-0.8, 4.2, 0) * K.yaw(math.rad(-90)), Vector3.new(0.8, 0.4, 0.7), MAT.Metal, C.steel, { cancollide = false })
	-- ค้อนวางบนโต๊ะ
	K.rod(m, Vector3.new(0.1, 3.42, -0.9), Vector3.new(1.3, 3.42, -0.6), 0.08, MAT.Wood, C.oak, { cancollide = false })
	K.box(m, K.at(0.05, 3.5, -0.92) * K.yaw(math.rad(14)), Vector3.new(0.35, 0.35, 0.7), MAT.Metal, C.iron, { cancollide = false })
	-- ปากกาจับชิ้นงาน (หน้าโต๊ะขวา) + เกลียว + ด้ามหมุน
	K.box(m, K.at(2.5, 3.55, -1.45), Vector3.new(0.8, 0.5, 0.35), MAT.Metal, C.iron)
	K.box(m, K.at(2.5, 3.55, -2.0), Vector3.new(0.8, 0.5, 0.25), MAT.Metal, C.iron, { cancollide = false })
	K.rod(m, Vector3.new(2.5, 3.45, -1.3), Vector3.new(2.5, 3.45, -2.5), 0.08, MAT.Metal, C.steel, { cancollide = false })
	K.rod(m, Vector3.new(2.05, 3.45, -2.5), Vector3.new(2.95, 3.45, -2.5), 0.06, MAT.Metal, C.brass, { cancollide = false })
	-- เตาหลอมเล็ก (หลังขวา) + ถ่านแดง + เครื่องเป่าลมหนัง
	K.box(m, K.at(2.3, 3.7, 0.85), Vector3.new(1.4, 0.8, 1.2), MAT.Slate, C.darkStone, { name = "Forge" })
	K.box(m, K.at(2.3, 4.12, 0.85), Vector3.new(1.0, 0.1, 0.8), MAT.Neon, C.ember, { cancollide = false, name = "Coals" })
	K.box(m, K.at(3.2, 3.6, 1.1) * K.roll(math.rad(12)), Vector3.new(0.6, 0.4, 0.8), MAT.Fabric, C.leather, { cancollide = false })
	-- แผงแขวนเครื่องมือด้านหลัง + คีม + ตะไบ
	for _, x in ipairs({ -3.0, 1.2 }) do
		K.box(m, K.at(x, 4.2, 1.55), Vector3.new(0.25, 2.1, 0.25), MAT.Wood, C.wood, { cancollide = false })
	end
	K.box(m, K.at(-0.9, 4.75, 1.6), Vector3.new(4.4, 1.1, 0.15), MAT.WoodPlanks, C.plank, { cancollide = false })
	for i, x in ipairs({ -2.4, -1.6, -0.8, 0.0 }) do
		local len = 0.7 + (i % 2) * 0.2
		K.rod(m, Vector3.new(x, 5.15, 1.5), Vector3.new(x + 0.12, 5.15 - len, 1.48), 0.05, MAT.Metal, i % 2 == 0 and C.steel or C.iron, { cancollide = false })
	end
	-- เฟืองประดับข้างโต๊ะ (สตีมพังก์)
	K.gear(m, K.at(3.6, 2.0, 0) , 0.7, 10, 0.2, C.brass)
end)
status("MetalBench")

---------------------------------------------------------------- กี่ทอผ้าไอน้ำ (โครงไม้ ผ้าบนกี่ ด้ายยืน หม้อไอน้ำเล็ก)
proto("Loom", function(m)
	-- เสาสี่ต้น + คานบน + คานผ้า (หน้า) + คานด้ายยืน (หลัง)
	for _, x in ipairs({ -2.9, 2.9 }) do
		for _, z in ipairs({ -1.5, 1.5 }) do
			K.box(m, K.at(x, 2.6, z), Vector3.new(0.4, 5.2, 0.4), MAT.Wood, C.oak)
		end
		K.box(m, K.at(x, 0.4, 0), Vector3.new(0.45, 0.4, 3.6), MAT.Wood, C.wood) -- ตีนกี่
		K.box(m, K.at(x, 4.95, 0), Vector3.new(0.4, 0.35, 3.4), MAT.Wood, C.wood, { cancollide = false })
	end
	K.cylX(m, K.at(0, 5.05, 0), 0.22, 6.2, MAT.Wood, C.plankDark, { cancollide = false, name = "TopBeam" })
	K.cylX(m, K.at(0, 2.6, -1.55), 0.28, 6.0, MAT.Wood, C.plank, { name = "BreastBeam" })
	K.cylX(m, K.at(0, 2.2, 1.55), 0.34, 6.0, MAT.Wood, C.plank, { cancollide = false, name = "WarpBeam" })
	-- ผ้าที่ทอเสร็จแล้วม้วนอยู่บนคานหน้า (ลายทางสามสี) + ผ้าที่กำลังทอ
	K.cylX(m, K.at(0, 2.6, -1.55), 0.42, 5.2, MAT.Fabric, rgb(170, 70, 60), { cancollide = false, name = "ClothRoll" })
	local slope = CFrame.lookAt(Vector3.new(0, 2.85, -1.2), Vector3.new(0, 3.55, 0.3))
	K.box(m, slope * CFrame.new(0, 0, -0.8), Vector3.new(5.2, 0.05, 1.7), MAT.Fabric, C.canvas, { cancollide = false, name = "Cloth" })
	for i, col in ipairs({ C.paintRed, C.paintBlue, C.brass }) do
		K.box(m, slope * CFrame.new(0, 0.03, -0.2 - i * 0.45), Vector3.new(5.2, 0.05, 0.14), MAT.Fabric, col, { cancollide = false })
	end
	-- ตะกอ (กรอบกลาง) + ด้ายยืนจากคานหลังขึ้นตะกอ
	K.box(m, K.at(0, 3.75, 0.35), Vector3.new(5.6, 0.18, 0.18), MAT.Wood, C.wood, { cancollide = false })
	K.box(m, K.at(0, 4.55, 0.35), Vector3.new(5.6, 0.18, 0.18), MAT.Wood, C.wood, { cancollide = false })
	for i = 0, 10 do
		local x = -2.5 + i * 0.5
		K.rod(m, Vector3.new(x, 2.45, 1.4), Vector3.new(x, 3.75, 0.35), 0.03, MAT.Fabric, C.white, { cancollide = false })
		K.rod(m, Vector3.new(x, 3.75, 0.35), Vector3.new(x, 4.55, 0.35), 0.025, MAT.Metal, C.steel, { cancollide = false })
	end
	-- กระสวย
	K.box(m, K.at(-0.6, 3.1, -0.4), Vector3.new(1.3, 0.2, 0.3), MAT.Wood, C.plankDark, { cancollide = false, name = "Shuttle" })
	-- ม้านั่งช่างทอ
	K.box(m, K.at(0, 1.45, -2.7), Vector3.new(3.0, 0.3, 0.9), MAT.WoodPlanks, C.plank)
	for _, x in ipairs({ -1.3, 1.3 }) do
		K.box(m, K.at(x, 0.65, -2.7), Vector3.new(0.3, 1.3, 0.7), MAT.Wood, C.wood, { cancollide = false })
	end
	-- หม้อไอน้ำเล็กขับกี่ (ข้างขวา) + ปล่อง + ท่อขึ้นคานบน + เฟือง + วาล์ว
	K.boiler(m, K.at(3.95, 1.45, 0.6), 0.75, 2.1, { color = C.copper, bands = 2, rivets = 8, name = "Boiler" })
	K.box(m, K.at(3.95, 0.2, 0.6), Vector3.new(1.8, 0.4, 1.8), MAT.Slate, C.darkStone, { name = "BoilerBase" })
	K.smokestack(m, K.at(3.95, 2.6, 0.6), 0.25, 1.4, { color = C.iron })
	K.pipe(m, { Vector3.new(3.95, 2.2, 0.0), Vector3.new(3.95, 4.7, 0.0), Vector3.new(3.1, 4.7, 0.0) }, 0.12, C.copper)
	K.gear(m, K.at(3.12, 3.6, -0.6), 0.75, 12, 0.2, C.brass)
	K.gear(m, K.at(3.12, 2.75, 0.45), 0.45, 8, 0.2, C.brassDark)
	K.valveWheel(m, K.at(4.75, 1.6, 0.6), 0.35, 5, C.brass)
	K.gauge(m, K.at(3.95, 2.1, -0.2) * K.yaw(math.rad(90)), 0.28, C.brass)
	-- ไหมพรมกับด้ายม้วนบนพื้นข้างกี่
	for i, col in ipairs({ C.white, rgb(200, 90, 80), rgb(96, 130, 190) }) do
		K.ball(m, K.at(-3.6, 0.4, -1.2 + i * 0.75), 0.7, MAT.Fabric, col, { cancollide = false })
	end
end)
status("Loom")

---------------------------------------------------------------- ต้นฝ้ายในแปลง (1x1 · โตตามระยะด้วย ScaleTo)
proto("Crop_Cotton", function(m)
	local STEM = rgb(92, 120, 64)
	local LEAF = rgb(78, 118, 58)
	local POD = rgb(122, 92, 60)
	local spots = { { -1.0, -0.9 }, { 0.9, -0.8 }, { -0.8, 0.9 }, { 1.0, 0.9 }, { 0.05, 0.05 } }
	for i, s in ipairs(spots) do
		local h = 2.5 + (i % 3) * 0.3
		local base, top = Vector3.new(s[1], 0, s[2]), Vector3.new(s[1] + 0.1, h, s[2] - 0.05)
		K.rod(m, base, top, 0.08, MAT.Grass, STEM, { cancollide = false })
		-- ใบสองใบ
		-- ใบกว้างเอียงหงายหน้าให้เห็นผิวใบ (บางเฉียบแล้วมองจากข้างจะเหลือแต่เส้น)
		K.box(m, K.at(s[1] + 0.38, h * 0.45, s[2]) * K.yaw(i) * K.roll(math.rad(-22)), Vector3.new(0.85, 0.08, 0.6), MAT.Grass, LEAF, { cancollide = false })
		K.box(m, K.at(s[1] - 0.38, h * 0.62, s[2]) * K.yaw(i) * K.roll(math.rad(22)), Vector3.new(0.85, 0.08, 0.6), MAT.Grass, LEAF, { cancollide = false })
		-- ปุยฝ้ายสามลูกในกลีบแตก
		for j = 0, 2 do
			local a = j * 2.1 + i
			local p = top + Vector3.new(math.cos(a) * 0.22, 0.05 + j * 0.08, math.sin(a) * 0.22)
			K.ball(m, CFrame.new(p), 0.55, MAT.Fabric, C.white, { cancollide = false })
		end
		K.box(m, CFrame.new(top + Vector3.new(0, -0.18, 0)), Vector3.new(0.5, 0.18, 0.5), MAT.Grass, POD, { cancollide = false })
	end
end)

status(("เสร็จ — %s"):format(table.concat(built, " · ")), true)
return table.concat(built, "\n")
