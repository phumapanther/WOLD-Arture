-- 105_farm_corn.lua — ต้นแบบของใหม่ 2026-10-02: ต้นข้าวโพด · ต้นอ้อย (ในแปลง) · หุ่นฟางฝึกซ้อม (ของวางบนเกาะ)
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/105_farm_corn.lua --kit --no-lib
--
-- กติกาเดียวกับเฟส 102: ลง `ReplicatedStorage.WOLD_Placeables` · Root = PrimaryPart กึ่งกลางกล่องระดับฐาน · Footprint จากกล่องจริง ·
-- Anchored ทุกชิ้น · ติด `Manual = true` (เฟส 90 ไม่ลบ/ไม่สร้างทับ) · รันซ้ำ = สร้างสามชิ้นนี้ใหม่ ชิ้นอื่นไม่ถูกแตะ
--
-- ต้นพืชชื่อ `Crop_<ไอเทม>` (IslandPlots โคลนลงแปลงแล้ว ScaleTo ตามระยะโต) · ต้นพืชเดินทะลุได้ทุกชิ้น
-- หุ่นฟาง: ชิ้นลำตัวต้องชื่อ `HumanoidRootPart` — PlayerCombat.distanceToBody วัดจากชิ้นนี้ (IslandBuild ติดแท็ก WOLD_Dummy ตอนวาง)
local RS = game:GetService("ReplicatedStorage")
local C, MAT = K.C, K.MAT
local CELL = 4
local rgb = Color3.fromRGB

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[FarmCorn] " .. msg)
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

local SOFT = { cancollide = false }
local SPOTS = { { -1.0, -0.9 }, { 0.9, -0.8 }, { -0.8, 0.9 }, { 1.0, 0.9 }, { 0.05, 0.05 } }

---------------------------------------------------------------- ต้นข้าวโพด (ต้นสูง ใบยาวโค้ง ฝักเหลืองในเปลือกเขียว พู่ด้านบน)
proto("Crop_Corn", function(m)
	local STALK = rgb(104, 140, 66)
	local LEAF = rgb(86, 132, 58)
	local HUSK = rgb(150, 176, 92)
	local KERNEL = rgb(236, 196, 72)
	local TASSEL = rgb(206, 178, 110)
	for i, s in ipairs(SPOTS) do
		local h = 3.6 + (i % 3) * 0.35
		local base, top = Vector3.new(s[1], 0, s[2]), Vector3.new(s[1] + 0.05, h, s[2])
		K.rod(m, base, top, 0.12, MAT.Grass, STALK, SOFT)
		-- ใบยาวสามคู่ เอียงลงตามความยาว (ใบข้าวโพดห้อยปลาย)
		for j = 1, 3 do
			local y = h * (0.25 + j * 0.18)
			local yaw = K.yaw(i * 1.3 + j * 2.1)
			K.box(m, K.at(s[1], y, s[2]) * yaw * K.at(0.55, 0, 0) * K.roll(math.rad(-28)), Vector3.new(1.2, 0.05, 0.28),
				MAT.Grass, LEAF, SOFT)
		end
		-- ฝัก: เมล็ดเหลืองโผล่จากเปลือกเขียวครึ่งล่าง
		local cob = K.at(s[1] + 0.2, h * 0.55, s[2]) * K.yaw(i) * K.roll(math.rad(-18))
		K.cyl(m, cob, 0.2, 0.9, MAT.SmoothPlastic, KERNEL, SOFT)
		K.cyl(m, cob * K.at(0, -0.2, 0), 0.24, 0.6, MAT.Grass, HUSK, SOFT)
		-- พู่เกสรบนยอด
		for k = 0, 2 do
			K.rod(m, top, top + Vector3.new(math.cos(k * 2.1) * 0.35, 0.45, math.sin(k * 2.1) * 0.35), 0.04, MAT.Grass, TASSEL, SOFT)
		end
	end
end)
status("Crop_Corn")

---------------------------------------------------------------- ต้นอ้อย (ลำปล้องสีเขียวอมม่วง ข้อสีเข้ม ใบแคบยาวแตกจากยอด)
proto("Crop_Sugarcane", function(m)
	local CANE = rgb(122, 140, 74)
	local CANE_RED = rgb(128, 82, 96)
	local NODE = rgb(84, 70, 52)
	local LEAF = rgb(96, 150, 70)
	for i, s in ipairs(SPOTS) do
		-- กอละสองลำ สูงไม่เท่ากัน
		for n = 0, 1 do
			local ox, oz = s[1] + n * 0.28, s[2] - n * 0.2
			local h = 4.0 + ((i + n) % 3) * 0.4
			local colour = (i + n) % 2 == 0 and CANE or CANE_RED
			K.rod(m, Vector3.new(ox, 0, oz), Vector3.new(ox, h, oz), 0.11, MAT.SmoothPlastic, colour, SOFT)
			for y = 0.6, h - 0.3, 0.7 do -- ข้อปล้อง
				K.cyl(m, K.at(ox, y, oz), 0.14, 0.08, MAT.SmoothPlastic, NODE, SOFT)
			end
			for j = 0, 3 do -- ใบแคบยาวแตกจากยอด ห้อยออกรอบด้าน
				K.box(m, K.at(ox, h - 0.1, oz) * K.yaw(j * 1.57 + i) * K.at(0.6, 0, 0) * K.roll(math.rad(-35)),
					Vector3.new(1.4, 0.04, 0.16), MAT.Grass, LEAF, SOFT)
			end
		end
	end
end)
status("Crop_Sugarcane")

---------------------------------------------------------------- หุ่นฟางฝึกซ้อม (หน้าตาเดียวกับหุ่นในเกมหลัก + ฐานไม้ เป้าบนอก)
proto("TrainingDummy", function(m)
	local STRAW = rgb(198, 168, 82)
	local STRAW_LIGHT = rgb(214, 186, 104)
	local POST = rgb(104, 78, 48)
	local ARM = rgb(120, 92, 56)
	-- ฐานไม้กากบาทให้ยืนบนพื้นได้เอง (หุ่นเกมหลักปักลงดิน แต่ของวางบนเกาะต้องตั้งบนผิว)
	K.box(m, K.at(0, 0.2, 0), Vector3.new(3.0, 0.4, 0.6), MAT.WoodPlanks, POST)
	K.box(m, K.at(0, 0.2, 0), Vector3.new(0.6, 0.4, 3.0), MAT.WoodPlanks, POST)
	K.box(m, K.at(0, 2.1, 0), Vector3.new(0.8, 3.8, 0.8), MAT.Wood, POST, { name = "Post" })
	-- ลำตัว = ชิ้นที่ระบบตีวัดระยะ ต้องชื่อนี้
	K.box(m, K.at(0, 5.2, 0), Vector3.new(2.2, 3.2, 1.4), MAT.Grass, STRAW, { name = "HumanoidRootPart" })
	K.ball(m, K.at(0, 7.4, 0), 1.6, MAT.Grass, STRAW_LIGHT, { name = "Head" })
	for _, sign in ipairs({ -1, 1 }) do
		K.box(m, K.at(sign * 2.2, 6.0, 0), Vector3.new(2.4, 0.6, 0.6), MAT.Wood, ARM)
		K.ball(m, K.at(sign * 3.45, 6.0, 0), 0.7, MAT.Grass, STRAW_LIGHT, SOFT) -- ฟางทะลักปลายแขน
	end
	-- เชือกคาดเอว + เป้าแดงขาวบนอก (หันหน้า −Z)
	K.box(m, K.at(0, 4.4, 0), Vector3.new(2.3, 0.2, 1.5), MAT.Fabric, C.rope, SOFT)
	K.cylX(m, K.at(0, 5.6, -0.72) * K.yaw(math.rad(90)), 0.75, 0.06, MAT.SmoothPlastic, C.white, SOFT)
	K.cylX(m, K.at(0, 5.6, -0.76) * K.yaw(math.rad(90)), 0.5, 0.06, MAT.SmoothPlastic, C.paintRed, SOFT)
	K.cylX(m, K.at(0, 5.6, -0.80) * K.yaw(math.rad(90)), 0.22, 0.06, MAT.SmoothPlastic, C.white, SOFT)
end)

status(("เสร็จ — %s"):format(table.concat(built, " · ")), true)
return table.concat(built, "\n")
