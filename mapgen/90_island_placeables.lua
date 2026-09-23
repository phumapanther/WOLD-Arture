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
	-- โอ๊กจริงจากชุดเดียวกับแมพหลัก · ย่อ 0.5 เพราะต้นจริงสูงราว 40 studs ซึ่งใหญ่เกินสวนบนเกาะ
	if borrowAsset(m, "oak", 1, 7) then return end
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



---------------------------------------------------------------- ยืมโมเดลจริงจากเกมหลัก
--
-- **ต้นไม้ พุ่มไม้ ก้อนหิน ใช้ของชุดเดียวกับแมพหลัก** (ผู้ใช้ทักว่าของเกาะดูเหมือนสร้างใหม่ 2026-09-22)
-- ไม่ใช่กล่องที่ปั้นเอง — `ServerStorage.WOLD_Assets.<kind>` คือชุดที่ผู้ใช้อนุมัติไว้ตั้งแต่ 2026-09-06
-- (พุ่ม Foliage Pack · หินมอส Mossy rock pack · โอ๊ก/สนจริง) ติดตั้งด้วย `mapgen/assets_setup.lua`
--
-- คืน false เมื่อไม่มีชุดโมเดล — `proto` ที่เรียกจะตกไปใช้ของที่ปั้นเองแทน จึงยังได้ของครบเสมอ
local ASSETS = game:GetService("ServerStorage"):FindFirstChild("WOLD_Assets")

local function borrowAsset(m, kind, index, scale)
	local folder = ASSETS and ASSETS:FindFirstChild(kind)
	if not folder then return false end
	local picks = folder:GetChildren()
	if #picks == 0 then return false end
	table.sort(picks, function(a, b) return a.Name < b.Name end)
	local src = picks[((index - 1) % #picks) + 1]

	-- ย้ายชิ้นส่วนเข้ามาในต้นแบบของเรา แล้ววางฐานไว้ที่ y = 0 (กติกาของทุกต้นแบบในไฟล์นี้)
	-- **`scale` คือ "อยากให้กว้างกี่ studs" ไม่ใช่ตัวคูณ** — โมเดลจาก Creator Store ขนาดต่างกันมาก
	-- (หินมอสก้อนหนึ่งกว้าง 32 studs อีกก้อน 6) ตัวคูณตายตัวจึงให้ผลคนละเรื่องทุกก้อน
	local clone = src:Clone()
	if scale and clone:IsA("Model") then
		local _, raw = clone:GetBoundingBox()
		local widest = math.max(raw.X, raw.Z)
		if widest > 0.1 then
			pcall(function() clone:ScaleTo(scale / widest) end)
		end
	end
	-- ⚠️ **ต้องย้ายมาที่จุดกำเนิดก่อน** ต้นแบบใน `WOLD_Assets` เก็บพิกัดโลกเดิมของมันไว้ (โมเดลที่
	-- InsertService โหลดมาอยู่ที่ไหนก็ได้) — ถ้าไม่ย้าย กล่องครอบจะกินตั้งแต่จุดกำเนิดไปถึงตรงนั้น
	-- แล้ว Footprint กลายเป็นพันช่อง (วัดจริงรอบแรก: ก้อนหิน 1290x432 ช่อง กว้าง 2,580 studs)
	local cf, size = clone:GetBoundingBox()
	local okMove = pcall(function()
		clone:PivotTo(clone:GetPivot() * cf:Inverse() * CFrame.new(0, size.Y / 2, 0))
	end)
	if not okMove then clone:Destroy(); return false end

	-- แล้วค่อยวางฐานที่ y = 0 ตามกติกาของทุกต้นแบบในไฟล์นี้
	local lowest = math.huge
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then lowest = math.min(lowest, d.Position.Y - d.Size.Y / 2) end
	end
	if lowest == math.huge then clone:Destroy(); return false end
	local ok2 = pcall(function() clone:PivotTo(clone:GetPivot() + Vector3.new(0, -lowest, 0)) end)
	if not ok2 then clone:Destroy(); return false end

	for _, c in ipairs(clone:GetChildren()) do c.Parent = m end
	clone:Destroy()
	return true
end

-- ยืมโมเดล **จากเพลสหลักจริงๆ** (ผู้ใช้สั่ง 2026-09-22: "ใช้โมเดลเดียวกันกับเกมส์หลักเลย")
--
-- ต่างจาก `borrowAsset` ที่หยิบจาก `WOLD_Assets` (ของ Creator Store ที่โหลดเข้าเพลสเกาะได้เอง) —
-- เตา ตู้เย็น ตู้ยา เครื่องกลั่น ฯลฯ ถูกวางมือไว้ในเพลสหลัก **ไม่มีทางมาถึงเกาะเองเลย** จึงถูกคัดลอก
-- ออกมาเป็นตัวเลขเก็บไว้ที่ `assets/models-from-main/furniture.lua` (รันเฟสด้วย `--furniture`)
--
-- ⚠️ **ย่อ 0.6 เท่ากับบ้าน** เฟอร์นิเจอร์พวกนี้ปั้นตามสเกลเมืองหลัก (ประตู 12x18) ส่วนบ้านบนเกาะย่อ
-- 0.6 อยู่แล้ว — ไม่ย่อตามก็จะได้เตาสูงกว่าประตูบ้านที่มันต้องไปตั้งอยู่ข้างใน
local MAIN_MODEL_SCALE = 0.6

local function borrowMain(m, name)
	local build = _G.WOLD_MAIN_MODELS and _G.WOLD_MAIN_MODELS.furniture
	if not build then return false end
	local src = build(name, MAIN_MODEL_SCALE)
	if not src then return false end
	for _, c in ipairs(src:GetChildren()) do c.Parent = m end
	src:Destroy()
	return true
end

---------------------------------------------------------------- ของตกแต่งชิ้นเล็ก (ผู้ใช้สั่ง 2026-09-22)
-- ก้อนหิน พุ่ม ตอไม้ โคมตั้งพื้น ป้าย บ่อน้ำ — ของเล็กๆ ที่เอาไว้ "โรย" ให้เกาะไม่ว่างเปล่า
-- ส่วนใหญ่ 1x1 ช่อง ราคาถูกกว่าของใหญ่มาก เพราะตั้งใจให้ซื้อทีละหลายชิ้น

proto("Deco_Rock", function(m)
	if borrowAsset(m, "rock", 1, 3.2) then return end
	-- กองหินเล็ก — เอียงคนละมุม ไม่ให้ดูเป็นลูกบาศก์วางเรียง
	K.box(m, K.at(0, 0.75, 0) * K.yaw(0.4) * K.pitch(0.12), Vector3.new(2.6, 1.5, 2.2), MAT.Slate, C.stone)
	K.box(m, K.at(0.9, 0.5, -0.7) * K.yaw(-0.9), Vector3.new(1.4, 1.0, 1.3), MAT.Slate, C.darkStone)
	K.box(m, K.at(-0.8, 0.4, 0.8) * K.yaw(1.2) * K.pitch(-0.2), Vector3.new(1.1, 0.8, 1.0), MAT.Slate, C.stone)
end)

proto("Deco_RockBig", function(m)
	if borrowAsset(m, "rock", 3, 6.5) then return end
	-- หินก้อนใหญ่ 2x2 — เป็นจุดเด่นกลางสนาม ไม่ใช่ของโรย
	K.box(m, K.at(0, 1.9, 0) * K.yaw(0.3) * K.pitch(0.08), Vector3.new(5.2, 3.8, 4.6), MAT.Slate, C.stone)
	K.box(m, K.at(1.9, 0.9, 1.2) * K.yaw(-0.7), Vector3.new(2.4, 1.8, 2.2), MAT.Slate, C.darkStone)
	K.box(m, K.at(-1.6, 0.7, -1.4) * K.yaw(1.1), Vector3.new(2.0, 1.4, 1.8), MAT.Slate, C.darkStone)
	K.ball(m, K.at(0.4, 3.6, -0.6), 2.0, MAT.Grass, C.moss, { cancollide = false })
end)

proto("Deco_Bush", function(m)
	if borrowAsset(m, "bush", 1, 4) then return end
	K.ball(m, K.at(0, 1.3, 0), 3.0, MAT.Grass, C.moss, { cancollide = false })
	K.ball(m, K.at(1.0, 1.0, 0.6), 2.1, MAT.Grass, C.grass, { cancollide = false })
	K.ball(m, K.at(-0.9, 1.1, -0.7), 2.3, MAT.Grass, C.moss, { cancollide = false })
end)

proto("Deco_Stump", function(m)
	K.cyl(m, K.at(0, 0.8, 0), 1.5, 1.6, MAT.Wood, C.wood)
	K.cyl(m, K.at(0, 1.62, 0), 1.35, 0.12, MAT.Wood, C.oak, { cancollide = false })
	K.box(m, K.at(1.6, 0.25, 0.9) * K.yaw(0.5), Vector3.new(2.2, 0.5, 0.5), MAT.Wood, C.wood)
end)

proto("Deco_Lantern", function(m)
	-- โคมตั้งพื้นเตี้ย ต่างจาก Deco_Lamp ที่เป็นเสาสูง — วางตามทางเดินได้ถี่กว่า
	K.cyl(m, K.at(0, 0.2, 0), 0.9, 0.4, MAT.Metal, C.iron)
	K.cyl(m, K.at(0, 1.1, 0), 0.22, 1.8, MAT.Metal, C.iron)
	local glass = K.box(m, K.at(0, 2.4, 0), Vector3.new(1.2, 1.4, 1.2), MAT.Glass, C.lamp, { transparency = 0.35 })
	K.box(m, K.at(0, 3.25, 0), Vector3.new(1.5, 0.3, 1.5), MAT.Metal, C.brass)
	local light = Instance.new("PointLight")
	light.Color = C.lamp
	light.Range = 18
	light.Brightness = 1.4
	light.Parent = glass
end)

proto("Deco_Signpost", function(m)
	K.cyl(m, K.at(0, 2.0, 0), 0.22, 4.0, MAT.Wood, C.plankDark)
	K.box(m, K.at(0.9, 3.4, 0), Vector3.new(2.6, 0.9, 0.18), MAT.Wood, C.plank)
	K.box(m, K.at(-0.8, 2.5, 0), Vector3.new(2.2, 0.8, 0.18), MAT.Wood, C.plank)
end)

proto("Deco_Well", function(m)
	-- บ่อน้ำ 2x2 ของตกแต่งกลางลาน ไม่ได้ใช้งานจริง
	for i = 0, 11 do
		local a = i * math.pi / 6
		K.box(m, K.at(math.cos(a) * 2.0, 0.9, math.sin(a) * 2.0) * K.yaw(-a),
			Vector3.new(0.7, 1.8, 1.1), MAT.Cobblestone, C.stone)
	end
	K.cyl(m, K.at(0, 0.5, 0), 1.7, 0.2, MAT.Water, C.glass, { cancollide = false, transparency = 0.3 })
	for _, x in ipairs({ -2.0, 2.0 }) do
		K.box(m, K.at(x, 3.2, 0), Vector3.new(0.3, 3.0, 0.3), MAT.Wood, C.plankDark)
	end
	K.box(m, K.at(0, 4.9, 0), Vector3.new(5.2, 0.35, 3.4), MAT.Wood, C.plank)
	K.cyl(m, K.at(0, 4.3, 0) * K.roll(math.pi / 2), 0.28, 3.4, MAT.Wood, C.wood)
end)

---------------------------------------------------------------- เฟอร์นิเจอร์ในบ้าน (ผู้ใช้สั่ง 2026-09-22)
--
-- **ชื่อโมเดลคือสิ่งที่ทำให้มันใช้งานได้จริง ห้ามเปลี่ยน**
--
-- `CraftStations.server` กับ `StorageChests.server` หาที่ทำงานของมันจาก **ชื่อโมเดล** (ตาราง `STATIONS`
-- และ `STORAGE`) ไม่ใช่จากแท็กหรือแอตทริบิวต์ — ต้นแบบชื่อ `Stove` จึงกลายเป็นเตาทำอาหารที่ใช้ได้จริง
-- ทันทีที่ถูกวางลงโลก โดยไม่ต้องเขียนโค้ดเชื่อมอะไรเลย
--
-- ตู้เย็น/ตู้ยาต้องมี `StorageSlots`/`StorageAccepts`/`StorageClass` ติดมาด้วย — ใส่ใน builder เพราะ
-- `IslandBuild` โคลนต้นแบบทั้งก้อน แอตทริบิวต์จึงติดไปเอง

proto("Stove", function(m)
	if borrowMain(m, "Stove") then return end
	-- ช่องไฟต้องชื่อ FireboxHearth — CraftStations จุดไฟที่ชิ้นนั้นตอนทำอาหาร
	K.box(m, K.at(0, 1.6, 0), Vector3.new(5.0, 3.2, 3.0), MAT.Cobblestone, C.darkStone)
	K.box(m, K.at(0, 3.4, 0), Vector3.new(5.4, 0.4, 3.4), MAT.Metal, C.iron)
	local hearth = K.box(m, K.at(0, 1.2, -1.4), Vector3.new(3.0, 1.8, 0.4), MAT.Metal, C.coal)
	hearth.Name = "FireboxHearth"
	K.cyl(m, K.at(-1.2, 4.0, 0), 0.9, 0.8, MAT.Metal, C.steel)
	K.cyl(m, K.at(1.2, 4.0, 0), 0.7, 0.6, MAT.Metal, C.brass)
	K.box(m, K.at(2.2, 5.6, 0), Vector3.new(0.9, 4.4, 0.9), MAT.Metal, C.iron)
end)

proto("SteamBlender", function(m)
	if borrowMain(m, "SteamBlender") then return end
	K.box(m, K.at(0, 0.5, 0), Vector3.new(3.0, 1.0, 2.6), MAT.Metal, C.brassDark)
	local jar = K.cyl(m, K.at(0, 2.4, 0), 1.1, 2.8, MAT.Glass, C.glass, { transparency = 0.45 })
	jar.Name = "Jar"
	K.cyl(m, K.at(0, 3.9, 0), 1.2, 0.5, MAT.Metal, C.brass)
	K.cyl(m, K.at(1.5, 1.6, 0) * K.roll(math.pi / 2), 0.3, 1.2, MAT.Metal, C.copper)
	K.box(m, K.at(-1.6, 1.4, 0), Vector3.new(0.5, 1.6, 0.5), MAT.Metal, C.iron)
end)

proto("AlchemyStill", function(m)
	if borrowMain(m, "AlchemyStill") then return end
	K.cyl(m, K.at(0, 1.4, 0), 1.6, 2.8, MAT.Metal, C.copper)
	K.cyl(m, K.at(0, 3.1, 0), 1.0, 0.8, MAT.Metal, C.brass)
	-- ท่อขด ให้ดูเป็นเครื่องกลั่น ไม่ใช่ถังเปล่า
	for i = 1, 5 do
		local a = i * 1.1
		K.cyl(m, K.at(math.cos(a) * 1.9, 3.6 + i * 0.42, math.sin(a) * 1.9) * K.roll(math.pi / 2),
			0.22, 1.4, MAT.Metal, C.copper, { cancollide = false })
	end
	K.cyl(m, K.at(1.9, 0.9, 0), 0.8, 1.6, MAT.Glass, C.crystal, { transparency = 0.4 })
	K.box(m, K.at(0, 0.2, 0), Vector3.new(4.0, 0.4, 4.0), MAT.Slate, C.darkStone)
end)

proto("IceBox", function(m)
	if borrowMain(m, "IceBox") then
		m:SetAttribute("StorageSlots", 25)
		m:SetAttribute("StorageAccepts", "food")
		m:SetAttribute("StorageClass", "Chef")
		return
	end
	K.box(m, K.at(0, 2.2, 0), Vector3.new(3.2, 4.4, 2.4), MAT.Metal, C.white)
	K.box(m, K.at(0, 3.3, -1.25), Vector3.new(2.8, 2.0, 0.2), MAT.Metal, C.steel)
	K.box(m, K.at(0, 1.2, -1.25), Vector3.new(2.8, 1.8, 0.2), MAT.Metal, C.steel)
	K.cyl(m, K.at(1.1, 3.3, -1.45) * K.roll(math.pi / 2), 0.12, 0.9, MAT.Metal, C.brass)
	K.cyl(m, K.at(1.1, 1.2, -1.45) * K.roll(math.pi / 2), 0.12, 0.9, MAT.Metal, C.brass)
	m:SetAttribute("StorageSlots", 25)
	m:SetAttribute("StorageAccepts", "food")
	m:SetAttribute("StorageClass", "Chef")
end)

proto("ApothecaryCabinet", function(m)
	if borrowMain(m, "ApothecaryCabinet") then
		m:SetAttribute("StorageSlots", 25)
		m:SetAttribute("StorageAccepts", "medicine")
		m:SetAttribute("StorageClass", "Priest")
		return
	end
	K.box(m, K.at(0, 2.4, 0), Vector3.new(3.4, 4.8, 1.8), MAT.Wood, C.plankDark)
	for _, y in ipairs({ 1.2, 2.4, 3.6 }) do
		K.box(m, K.at(0, y, -0.95), Vector3.new(3.0, 0.15, 0.2), MAT.Wood, C.oak, { cancollide = false })
		for _, x in ipairs({ -0.9, 0, 0.9 }) do
			K.cyl(m, K.at(x, y + 0.45, -0.85), 0.24, 0.8, MAT.Glass, C.crystal,
				{ cancollide = false, transparency = 0.35 })
		end
	end
	m:SetAttribute("StorageSlots", 25)
	m:SetAttribute("StorageAccepts", "medicine")
	m:SetAttribute("StorageClass", "Priest")
end)

---------------------------------------------------------------- ฟาร์มผิดกฎหมาย (ผู้ใช้สั่ง — ตั้งในบ้านได้)
--
-- ชื่อต้องตรงกับ `FarmConfig`/`IllegalFarm.server` เหมือนกัน — `DistillSet` `Reactor` `Boxs`
-- วางแล้วเป็นจุดฟาร์มจริง (กฎของมันเองยังใช้: คูลดาวน์ 30 นาที ต้องมีคนในเซิร์ฟครบ ทหารยามฟาร์มไม่ได้)

proto("DistillSet", function(m)
	if borrowMain(m, "DistillSet") then return end
	K.box(m, K.at(0, 0.3, 0), Vector3.new(4.4, 0.6, 3.2), MAT.Metal, C.iron)
	K.cyl(m, K.at(-1.2, 2.0, 0), 1.2, 3.0, MAT.Metal, C.verdigris)
	K.cyl(m, K.at(1.3, 1.5, 0), 0.9, 2.2, MAT.Glass, C.crystal, { transparency = 0.4 })
	K.cyl(m, K.at(0, 3.2, 0) * K.roll(math.pi / 2), 0.2, 2.4, MAT.Metal, C.copper, { cancollide = false })
	K.cyl(m, K.at(-1.2, 3.8, 0), 0.5, 0.8, MAT.Metal, C.brass)
end)

proto("Reactor", function(m)
	if borrowMain(m, "Reactor") then return end
	K.cyl(m, K.at(0, 2.0, 0), 1.8, 4.0, MAT.Metal, C.steel)
	K.cyl(m, K.at(0, 4.2, 0), 2.0, 0.5, MAT.Metal, C.brassDark)
	K.box(m, K.at(0, 2.2, -1.9), Vector3.new(1.6, 1.6, 0.3), MAT.Glass, C.ember, { transparency = 0.3 })
	for i = 0, 3 do
		local a = i * math.pi / 2 + 0.4
		K.cyl(m, K.at(math.cos(a) * 2.1, 1.0, math.sin(a) * 2.1), 0.28, 2.0, MAT.Metal, C.copper)
	end
	K.box(m, K.at(0, 0.25, 0), Vector3.new(4.6, 0.5, 4.6), MAT.Metal, C.iron)
end)

proto("Boxs", function(m)
	if borrowMain(m, "Boxs") then return end
	K.crate(m, K.at(-1.0, 0, -0.8), 2.6, C.oak)
	K.crate(m, K.at(1.2, 0, 0.9), 2.4, C.wood)
	K.crate(m, K.at(0.2, 2.5, -0.4), 2.2, C.plankDark)
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
		-- **โมเดลจริงจากเกมหลัก** (ผู้ใช้สั่ง 2026-09-22) — ของที่ปั้นเองข้างล่างเหลือไว้เป็นตัวสำรอง
		-- เผื่อรันเฟสโดยไม่ใส่ `--furniture` (ซึ่งเป็นตัวที่ฝัง `animals.lua` เข้ามา)
		local build = _G.WOLD_MAIN_MODELS and _G.WOLD_MAIN_MODELS.animals
		local real = build and build(name)
		if real then
			for _, c in ipairs(real:GetChildren()) do c.Parent = m end
			real:Destroy()
			return
		end
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


---------------------------------------------------------------- สัตว์เลี้ยง (ผู้ใช้สั่ง 2026-09-22)
--
-- **ไม่ใช่สัตว์ฟาร์ม** สัตว์ในคอกข้างบนเป็นกล่องนิ่งๆ ที่กด E เก็บผลผลิตแล้วหายไป ส่วนสองตัวนี้เป็น
-- **rig จริงจากโรงงาน** (`models/animals.lua` → `R.quad`) มี Motor6D + Humanoid เดินได้ลื่นจริง
-- ลูบหัวได้ (E) อุ้มย้ายที่ได้ (F) และให้บัพกับทั้งฟาร์มขณะอยู่บนเกาะ
--
-- ⚠️ **ห้ามผ่าน `finish()` แบบของอื่น** — `finish` สั่ง `Anchored = true` ทุกชิ้น ซึ่งจะตรึงสัตว์
-- ไว้กับที่ถาวร เดินไม่ได้เลย · ต้องปล่อยให้ Humanoid คุมการเคลื่อนที่เอง
for _, name in ipairs({ "Dog", "Cat" }) do
	local id = "Pet_" .. name
	if not keep[id] then
		local built = K.place("Animal_" .. name, folder, CFrame.new())
		if built then
			built.Name = id
			-- **ย่อลง** โรงงานปั้นตามสเกลเมืองหลัก (หมาสูง 11.5 studs = สูงกว่าตัวละคร ~5.5 สองเท่า)
			-- 0.45 ได้หมาสูงราว 5 studs = แค่เอวคน ซึ่งคือขนาดที่คำว่า "สัตว์เลี้ยง" หมายถึง
			-- `BeastGait` คูณระยะยกตัวกับจังหวะก้าวด้วย GetScale() ให้เอง จึงไม่ต้องแก้แอตทริบิวต์
			built:ScaleTo(0.45)
			-- ปุ่มตกแต่งของ kit ออก (ระบบสัตว์เลี้ยงใส่ปุ่ม E/F ของมันเอง) แต่ **ไม่แตะ Anchored**
			for _, d in ipairs(built:GetDescendants()) do
				if d:IsA("ProximityPrompt") then d:Destroy() end
			end
			-- Footprint ยังต้องมี ระบบวางของใช้หาขนาดช่อง — คิดจากกล่องจริงเหมือนของอื่น
			local _, size = built:GetBoundingBox()
			built:SetAttribute("Footprint", Vector2.new(cells(size.X), cells(size.Z)))
			built:SetAttribute("Pet", true)
			print(("[Placeables] %-20s %2dx%-2d ช่อง (rig เดินได้ %d ชิ้น)")
				:format(id, cells(size.X), cells(size.Z), K.countParts(built)))
		else
			warn("[Placeables] ไม่มี builder Animal_" .. name .. " (ลืม --models?)")
		end
	end
end

---------------------------------------------------------------- ของป่าจากเกมหลัก (ผู้ใช้สั่ง 2026-09-23)
--
-- "เอามาทำขายเป็นของตกแต่งที่วางได้และเก็บได้แบบหินและพุ่มไม้และต้นไม้แบบของอันอื่นด้วย
--  ที่เก็บแล้วต้องรอวันใหม่ถึงจะเก็บได้อีก"
--
-- **ไม่ปั้นใหม่ ไม่คัดลอกข้อมูลใหม่** — โมเดลชุดนี้ถูกเตรียมไว้แล้วที่ `ServerStorage.WOLD_IslandNodes`
-- โดยเฟส 100 (ต้นไม้/หิน/พุ่มจาก Creator Store · สายแร่จาก `assets/models-from-main/ores.lua`)
-- ตรงนี้แค่หยิบแบบแรกของแต่ละชนิดมาเป็นต้นแบบของวาง **จึงต้องรันเฟส 100 ก่อนเฟสนี้**
local nodeProtos = game:GetService("ServerStorage"):FindFirstChild("WOLD_IslandNodes")
if not nodeProtos then
	status("⚠ ไม่มี WOLD_IslandNodes — รัน mapgen/100_island_nodes.lua ก่อน แล้วรันเฟสนี้ซ้ำ")
else
	for _, kind in ipairs({ "Rock", "Herb", "Tree", "Coal", "IronOre", "SilverOre", "Crystal", "GoldOre", "MagicOre", "DiamondOre" }) do
		local id = "Wild_" .. kind
		local src = nodeProtos:FindFirstChild(kind)
		src = src and src:GetChildren()[1]
		if keep[id] then
			print("[Placeables] " .. id .. " แก้มือไว้ (Manual) — คงเดิม")
		elseif not src then
			warn("[Placeables] ไม่มีต้นแบบ WOLD_IslandNodes." .. kind)
		else
			local m = src:Clone()
			m.Name = id
			-- ⚠️ ต้นแบบของเฟส 100 ไม่มีชิ้น `Root` แต่ `finish` สร้างให้เอง (และตั้ง Footprint จากกล่องจริง)
			finish(m)
		end
	end
end

status(("done: %d ต้นแบบใน ReplicatedStorage.WOLD_Placeables"):format(#folder:GetChildren()), true)
