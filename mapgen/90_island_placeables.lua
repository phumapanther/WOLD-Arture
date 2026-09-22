-- 90_island_placeables.lua: ต้นแบบของวางบนเกาะฟาร์ม → ReplicatedStorage.WOLD_Placeables (ไคลเอนต์โคลนทำ ghost ได้)
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/90_island_placeables.lua --kit --models --no-lib
--
-- กติกาทุกต้นแบบ: Root = PrimaryPart ที่ "กึ่งกลางกล่อง ระดับฐาน" (ไม่ใช่จุดกำเนิดของ modelkit เฉยๆ — บ้านหลายหลัง
-- ไม่สมมาตร) · แอตทริบิวต์ Footprint (Vector2 ช่อง) คำนวณจากกล่องจริง เป็นแหล่งเดียวของขนาด · ทุกชิ้น Anchored
-- · ไม่มี ProximityPrompt ตกแต่งของ kit ติดมา (ระบบใส่ปุ่มของมันเอง)
local RS = game:GetService("ReplicatedStorage")
local CELL = 4
local C, MAT = K.C, K.MAT
local rgbPink = Color3.fromRGB(226, 158, 158) -- หมู (จานสีของ kit ไม่มีชมพู)

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[Placeables] " .. msg)
end

-- ต้นแบบที่ผู้ใช้แก้มือในโชว์รูมแล้ว adopt (เฟส 92) ติด Manual=true — รันเฟสนี้ซ้ำจะไม่ทับ (กติกาเดิมของโปรเจ็ค)
local folder = RS:FindFirstChild("WOLD_Placeables")
if not folder then folder = Instance.new("Folder"); folder.Name = "WOLD_Placeables"; folder.Parent = RS end
local keep = {}
for _, m in ipairs(folder:GetChildren()) do
	if m:GetAttribute("Manual") then keep[m.Name] = true else m:Destroy() end
end

local function cells(studs) return math.max(1, math.ceil(studs / CELL - 0.05)) end

-- ปิดท้ายทุกต้นแบบ: ย้าย Root ไปกึ่งกลางกล่อง ตั้ง Footprint ล้างปุ่ม/สคริปต์ของ kit
local function finish(m)
	local root = m:FindFirstChild("Root")
	if not root then
		root = Instance.new("Part"); root.Name = "Root"; root.Size = Vector3.new(1, 1, 1)
		root.Transparency = 1; root.CanCollide = false; root.Anchored = true; root.Massless = true
		root.CFrame = CFrame.new(); root.Parent = m
	end
	root.CanQuery = false; root.CanTouch = false
	m.PrimaryPart = root
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
		if d:IsA("ProximityPrompt") or d:IsA("LocalScript") then d:Destroy() end
	end
	local cf, size = m:GetBoundingBox()
	root.CFrame = CFrame.new(cf.Position.X, 0, cf.Position.Z)
	m:SetAttribute("Footprint", Vector2.new(cells(size.X), cells(size.Z)))
	m.Parent = folder
	print(("[Placeables] %-20s %2dx%-2d ช่อง (%.1f x %.1f x %.1f) %d ชิ้น"):format(m.Name, cells(size.X), cells(size.Z), size.X, size.Y, size.Z, K.countParts(m)))
end

local function proto(name, fn)
	if keep[name] then print("[Placeables] " .. name .. " แก้มือไว้ (Manual) — คงเดิม"); return end
	local m = Instance.new("Model"); m.Name = name
	fn(m)
	finish(m)
end

status("start")

---------------------------------------------------------------- แปลงดิน 2x2 (ชิ้น Soil ให้พืชเกาะ)
proto("FarmPlot", function(m)
	K.box(m, K.at(0, 0.3, 0), Vector3.new(7.6, 0.6, 7.6), MAT.Ground, C.soil, { name = "Soil" })
	for _, s in ipairs({ { 0, 3.8 }, { 0, -3.8 } }) do
		K.box(m, K.at(s[1], 0.45, s[2]), Vector3.new(7.9, 0.9, 0.3), MAT.Wood, C.plankDark)
	end
	for _, s in ipairs({ { 3.8, 0 }, { -3.8, 0 } }) do
		K.box(m, K.at(s[1], 0.45, s[2]), Vector3.new(0.3, 0.9, 7.9), MAT.Wood, C.plankDark)
	end
end)

---------------------------------------------------------------- รั้ว 1x1 (ทอดยาวตาม X หมุน 90° = ตาม Z)
proto("Deco_Fence", function(m)
	for _, x in ipairs({ -1.8, 1.8 }) do
		K.box(m, K.at(x, 1.6, 0), Vector3.new(0.35, 3.2, 0.35), MAT.Wood, C.plankDark)
	end
	K.box(m, K.at(0, 2.5, 0), Vector3.new(3.9, 0.3, 0.2), MAT.Wood, C.plank)
	K.box(m, K.at(0, 1.3, 0), Vector3.new(3.9, 0.3, 0.2), MAT.Wood, C.plank)
end)

---------------------------------------------------------------- โคมไฟ 1x1 · ม้านั่ง 2x1 · กระถาง 1x1
proto("Deco_Lamp", function(m) K.lampPost(m, CFrame.new(), 7, C.lamp) end)

proto("Deco_Bench", function(m)
	K.box(m, K.at(0, 1.5, 0), Vector3.new(7.4, 0.3, 1.6), MAT.Wood, C.plank)
	K.box(m, K.at(0, 2.6, -0.7), Vector3.new(7.4, 1.2, 0.25), MAT.Wood, C.plank)
	for _, x in ipairs({ -3.2, 3.2 }) do
		K.box(m, K.at(x, 0.7, 0), Vector3.new(0.4, 1.4, 1.4), MAT.Metal, C.iron)
	end
end)

proto("Deco_FlowerPot", function(m)
	K.cyl(m, K.at(0, 0.6, 0), 1.1, 1.2, MAT.Slate, C.brick)
	K.cyl(m, K.at(0, 1.3, 0), 0.95, 0.2, MAT.Ground, C.soil, { cancollide = false })
	for i, col in ipairs({ C.paintRed, C.lamp, C.white }) do
		local a = i * 2.1
		K.ball(m, K.at(math.cos(a) * 0.5, 2.0, math.sin(a) * 0.5), 0.9, MAT.Grass, col, { cancollide = false })
	end
end)

---------------------------------------------------------------- ต้นไม้ 2x2 · ลัง · ถัง · แผ่นทางเดิน
proto("Deco_Tree", function(m)
	K.cyl(m, K.at(0, 3, 0), 0.7, 6, MAT.Wood, C.wood)
	K.ball(m, K.at(0, 8, 0), 6.5, MAT.Grass, C.moss, { cancollide = false })
	K.ball(m, K.at(1.8, 6.5, 1.2), 4.2, MAT.Grass, C.grass, { cancollide = false })
	K.ball(m, K.at(-1.6, 7, -1.4), 4.6, MAT.Grass, C.moss, { cancollide = false })
end)

proto("Deco_Crate", function(m) K.crate(m, CFrame.new(), 3.2, C.oak) end)
proto("Deco_Barrel", function(m) K.barrel(m, CFrame.new(), 1.5, 3.4, C.wood) end)
proto("Deco_PathTile", function(m)
	K.box(m, K.at(0, 0.15, 0), Vector3.new(3.9, 0.3, 3.9), MAT.Cobblestone, C.stone)
end)

---------------------------------------------------------------- บ้าน 5 แบบจาก modelkit (K.place ใส่ Root ที่จุดกำเนิดให้ finish ย้ายไปกึ่งกลาง)
-- modelkit ปั้นบ้านตามสเกลเมืองหลัก (ประตู 12x18 เพดาน 26) กระท่อมหินจึงกว้าง 98 studs = 25 ช่อง กินเกาะไปหนึ่งในสี่
-- ย่อเหลือ 0.6: ประตู 7x11 ยังเดินเข้าได้สบาย (ตัวละครสูง ~5.5) กระท่อม 59x46 = 15x12 ช่อง — ค่านี้ Claude ตั้ง จูนได้ที่เดียว
local HOUSE_SCALE = 0.6
for _, name in ipairs({ "House_StoneCottage", "House_Roundhouse", "House_Longhouse", "House_PipeWorker", "House_Townhouse" }) do
	local m = not keep[name] and K.place(name, folder, CFrame.new())
	if keep[name] then
		print("[Placeables] " .. name .. " แก้มือไว้ (Manual) — คงเดิม")
	elseif m then
		m:ScaleTo(HOUSE_SCALE)
		finish(m)
	else
		warn("[Placeables] ไม่มี builder ชื่อ " .. name)
	end
end

---------------------------------------------------------------- คอกสัตว์ 5x5 ช่อง (รั้วรอบ + ประตู + รางอาหาร)
proto("AnimalPen", function(m)
	local S = 20 -- กว้าง 20 studs = 5 ช่อง
	local half = S / 2
	-- รั้วสี่ด้าน เว้นช่องประตูกว้าง 6 ตรงกลางด้านหน้า (-Z)
	local function rail(cx, cz, len, along)
		local size = along == "x" and Vector3.new(len, 0.3, 0.25) or Vector3.new(0.25, 0.3, len)
		K.box(m, K.at(cx, 2.4, cz), size, MAT.Wood, C.plank)
		K.box(m, K.at(cx, 1.2, cz), size, MAT.Wood, C.plank)
	end
	rail(0, half, S, "x")                       -- หลัง
	rail(-half, 0, S, "z")                      -- ซ้าย
	rail(half, 0, S, "z")                       -- ขวา
	rail(-(half + 3) / 2 - 1.5, -half, half - 3, "x") -- หน้า ซ้ายประตู
	rail((half + 3) / 2 + 1.5, -half, half - 3, "x")  -- หน้า ขวาประตู
	for _, c in ipairs({ { -half, -half }, { half, -half }, { -half, half }, { half, half }, { -3, -half }, { 3, -half } }) do
		K.box(m, K.at(c[1], 1.7, c[2]), Vector3.new(0.5, 3.4, 0.5), MAT.Wood, C.plankDark)
	end
	-- รางอาหารมุมหนึ่ง + จุดแขวนปุ่ม (ระบบหาชื่อ PenAnchor)
	K.box(m, K.at(half - 4, 0.9, half - 4), Vector3.new(5, 1.2, 2), MAT.WoodPlanks, C.oak)
	K.box(m, K.at(half - 4, 1.6, half - 4), Vector3.new(4.4, 0.6, 1.4), MAT.Ground, C.thatch)
	local anchor = K.box(m, K.at(0, 1.5, -half), Vector3.new(1, 1, 1), MAT.SmoothPlastic, C.brass, { name = "PenAnchor", transparency = 1, cancollide = false })
	anchor.CanQuery = false
end)

---------------------------------------------------------------- โซนแร่ 5x5 ช่อง (ลานหินมีหมุดมุม)
proto("MineZone", function(m)
	local S = 20
	local half = S / 2
	K.box(m, K.at(0, 0.2, 0), Vector3.new(S, 0.4, S), MAT.Slate, C.darkStone, { name = "Floor" })
	-- หมุดหินสี่มุม บอกขอบเขตโซนให้เห็นชัดโดยไม่กั้นทาง
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local x, z = c[1] * (half - 1.5), c[2] * (half - 1.5)
		K.box(m, K.at(x, 1.4, z), Vector3.new(1.8, 2.8, 1.8), MAT.Rock, C.stone)
		K.box(m, K.at(x, 3.0, z), Vector3.new(1.1, 0.6, 1.1), MAT.Metal, C.brass)
	end
	-- รางเหล็กพาดกลางลาน ให้ดูเป็นเหมืองสตีมพังก์ ไม่ใช่แค่แผ่นเทา
	for _, dz in ipairs({ -2.2, 2.2 }) do
		K.box(m, K.at(0, 0.55, dz), Vector3.new(S - 4, 0.3, 0.5), MAT.Metal, C.rust)
	end
	for i = -3, 3 do
		K.box(m, K.at(i * 2.4, 0.5, 0), Vector3.new(0.6, 0.25, 5.4), MAT.Wood, C.plankDark)
	end
	local anchor = K.box(m, K.at(0, 1.5, -half), Vector3.new(1, 1, 1), MAT.SmoothPlastic, C.brass, { name = "MineAnchor", transparency = 1, cancollide = false })
	anchor.CanQuery = false
end)

---------------------------------------------------------------- สัตว์ในคอก 8 ชนิด (ทรงกล่อง แก้ในโชว์รูมได้)
-- ตัวเล็ก ๆ พอให้แยกออกจากกัน — ระบบคอกโคลนไปวางในคอกแล้วติดแท็ก WOLD_Node ให้กด E ได้ตามเกมหลัก
local ANIMALS = {
	-- ชื่อ, สีตัว, สีหัว, ยาว, สูง, กว้าง, มีเขา/หงอน
	{ "Chicken", C.white, C.paintRed, 1.6, 1.4, 1.2, "comb" },
	{ "Duck", C.white, C.lamp, 1.8, 1.4, 1.3, "bill" },
	{ "Pig", rgbPink, rgbPink, 2.8, 1.8, 1.6, nil },
	{ "Goat", C.plaster, C.plaster, 2.6, 2.0, 1.4, "horn" },
	{ "Sheep", C.sail, C.leather, 2.8, 2.0, 1.8, nil },
	{ "Cow", C.white, C.black, 3.6, 2.4, 1.9, "horn" },
	{ "Deer", C.leather, C.leather, 3.0, 2.4, 1.5, "antler" },
	{ "Horse", C.wood, C.wood, 3.8, 2.8, 1.7, nil },
}
for _, a in ipairs(ANIMALS) do
	local name, body, head, len, tall, wide, extra = a[1], a[2], a[3], a[4], a[5], a[6], a[7]
	proto("Animal_" .. name, function(m)
		local legH = tall * 0.38
		K.box(m, K.at(0, legH + tall * 0.3, 0), Vector3.new(wide, tall * 0.6, len), MAT.SmoothPlastic, body, { name = "Body" })
		K.box(m, K.at(0, legH + tall * 0.62, -len / 2 - wide * 0.3), Vector3.new(wide * 0.8, tall * 0.5, wide * 0.7), MAT.SmoothPlastic, head, { name = "Head" })
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			K.box(m, K.at(c[1] * wide * 0.32, legH / 2, c[2] * len * 0.3), Vector3.new(wide * 0.22, legH, wide * 0.22), MAT.SmoothPlastic, head)
		end
		if extra == "horn" or extra == "antler" then
			for _, sx in ipairs({ -1, 1 }) do
				K.box(m, K.at(sx * wide * 0.25, legH + tall * 0.9, -len / 2 - wide * 0.2), Vector3.new(0.18, tall * 0.3, 0.18), MAT.SmoothPlastic, C.plaster)
			end
		elseif extra == "comb" then
			K.box(m, K.at(0, legH + tall * 0.92, -len / 2 - wide * 0.3), Vector3.new(0.16, 0.4, 0.5), MAT.SmoothPlastic, C.paintRed)
		elseif extra == "bill" then
			K.box(m, K.at(0, legH + tall * 0.6, -len / 2 - wide * 0.72), Vector3.new(wide * 0.5, 0.22, 0.6), MAT.SmoothPlastic, C.lamp)
		end
	end)
end

---------------------------------------------------------------- พืช 3 ชนิด (ทรงเต็มโต ระบบ ScaleTo ตามระยะ)
proto("Crop_Wheat", function(m)
	for i = 1, 9 do
		local a, r = i * 0.7, 0.8 + (i % 3) * 0.6
		K.cyl(m, K.at(math.cos(a) * r, 1.4, math.sin(a) * r), 0.12, 2.8, MAT.Grass, C.thatch, { cancollide = false })
		K.ball(m, K.at(math.cos(a) * r, 2.9, math.sin(a) * r), 0.5, MAT.Grass, C.lamp, { cancollide = false })
	end
end)
proto("Crop_Vegetable", function(m)
	for i = 1, 5 do
		local a, r = i * 1.26, i == 5 and 0 or 1.6
		K.ball(m, K.at(math.cos(a) * r, 0.9, math.sin(a) * r), 1.8, MAT.Grass, C.paintGreen, { cancollide = false })
	end
end)
proto("Crop_Herb", function(m)
	for i = 1, 7 do
		local a, r = i * 0.9, 0.6 + (i % 2) * 1.0
		K.box(m, K.at(math.cos(a) * r, 1.0, math.sin(a) * r) * K.yaw(a), Vector3.new(0.6, 2.0, 0.15), MAT.Grass, C.verdigris, { cancollide = false })
	end
end)

status(("done: %d ต้นแบบใน ReplicatedStorage.WOLD_Placeables"):format(#folder:GetChildren()), true)
