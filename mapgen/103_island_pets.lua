-- 103_island_pets.lua: ต้นแบบสัตว์เลี้ยงเฟส 2d (ผู้ใช้อนุมัติ 2026-09-27) → ReplicatedStorage.WOLD_Placeables
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/103_island_pets.lua --kit --models --no-lib
--
-- สัตว์ฟาร์ม 8 (`models/animals.lua`) + มอน 13 (`models/monsters.lua` + สไลม์ใน `models/npcs.lua`) + สไลม์เขียวที่ปั้นที่นี่
-- **ทุกตัวสร้างที่ขนาดเต็มวัย** = สูงเท่าคน (FULL_HEIGHT) ด้านยาวสุดไม่เกิน MAX_SIDE — `IslandPets` ย่อเหลือ 30% ตอนวาง
-- แล้วขยายตามจำนวนครั้งที่ลูบ (`IslandConfig.PetSizeFraction`)
--
-- แอตทริบิวต์ที่ระบบอ่าน: `Pet` · `FullScale` (GetScale ตอนเต็มวัย) · `FullSize` (กล่องตอนเต็มวัย ไม่รวม Root) ·
-- `Footprint` (ช่องที่จองตอนวาง) · **`Manual = true`** — เฟส 90 ลบต้นแบบที่ไม่ใช่ Manual ทุกครั้งที่รัน
-- ถ้าไม่ติด สัตว์เลี้ยงทั้งชุดหายตอนมีคนรันเฟส 90 ซ้ำ (บทเรียนเดียวกับเครื่องคราฟเฟส 102)
--
-- หมา/แมวของเฟส 90 **ไม่สร้างใหม่** (ผู้เล่นมีอยู่แล้วและผู้ใช้เลือกให้นับเป็นโตเต็มวัย) — แค่เติม FullScale/FullSize
-- รันซ้ำได้ · `workspace:SetAttribute("PetsOnly", "Pet_Wolf")` = สร้างตัวเดียว
--
-- ⚠️ **ห้ามติดแท็ก `WOLD_Mob`** (ระบบต่อสู้ตีทุกอย่างที่มีแท็กนี้) · **ห้ามพกสคริปต์ในโมเดล** (SlimeController ดึงกลับจุดเกิด ·
-- NPCController เดินสุ่ม · BeastGait script เขียน Transform ที่ไม่ replicate) — `IslandPets` ขับการเดินเองทั้งหมด
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local CELL = 4
local FULL_HEIGHT = 5.2 -- สูงเท่าตัวละคร R15 มาตรฐาน (วัดแล้ว 5.18)
local MAX_SIDE = 8 -- แมงมุม/ม้าที่สูงเท่าคนจะยาวเกินเกาะ — หนีบด้านยาวไว้
local ONLY = workspace:GetAttribute("PetsOnly")
-- พรีวิว: `workspace:SetAttribute("PetsPreview", true)` = วางเรียงแถวใน workspace.PetPreview แทน (ไว้ถ่ายภาพ · **ลบทิ้งหลังดู**)
local PREVIEW = workspace:GetAttribute("PetsPreview") == true

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[Pets] " .. msg)
end

local folder = RS:FindFirstChild("WOLD_Placeables")
if not folder then folder = Instance.new("Folder"); folder.Name = "WOLD_Placeables"; folder.Parent = RS end
if PREVIEW then
	folder = workspace:FindFirstChild("PetPreview") or Instance.new("Folder")
	folder.Name = "PetPreview"
	folder.Parent = workspace
end
local previewIndex = 0

local function cells(studs) return math.max(1, math.ceil(studs / CELL - 0.05)) end

-- กล่องครอบของทุกชิ้นยกเว้น Root (Root คือหมุดล่องหนที่ระบบเกาะใช้วาง ไม่ใช่ตัวสัตว์)
local function bounds(m)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			local cf, h = p.CFrame, p.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local w = cf * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)
						lo = Vector3.new(math.min(lo.X, w.X), math.min(lo.Y, w.Y), math.min(lo.Z, w.Z))
						hi = Vector3.new(math.max(hi.X, w.X), math.max(hi.Y, w.Y), math.max(hi.Z, w.Z))
					end
				end
			end
		end
	end
	return lo, hi
end

-- ของตกแต่งของ kit ที่สัตว์เลี้ยงไม่ต้องมี: สคริปต์ · ปุ่ม · ป้ายชื่อลอย · แท็กทุกตัว
local function strip(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	for _, d in ipairs(m:GetDescendants()) do
		for _, tag in ipairs(CollectionService:GetTags(d)) do CollectionService:RemoveTag(d, tag) end
	end
	for _, tag in ipairs(CollectionService:GetTags(m)) do CollectionService:RemoveTag(m, tag) end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.NameDisplayDistance = 0
		hum.BreakJointsOnDeath = false
		if not hum:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = hum end
	end
end

-- R15 จาก `CreateHumanoidModelFromDescription` ข้อต่อเป็น AnimationConstraint ไม่ใช่ Motor6D (วัดแล้วที่บอส เฟส 82)
-- ท่าเดินมาตรฐานที่ `IslandPets` เล่นต้องการ Motor6D ชื่อมาตรฐาน · แขวนที่ Part1 ตามมาตรฐาน R15
local R15_JOINTS = {
	{ "LowerTorso", "HumanoidRootPart", "Root" }, { "UpperTorso", "LowerTorso", "Waist" },
	{ "Head", "UpperTorso", "Neck" },
	{ "LeftUpperArm", "UpperTorso", "LeftShoulder" }, { "LeftLowerArm", "LeftUpperArm", "LeftElbow" },
	{ "LeftHand", "LeftLowerArm", "LeftWrist" },
	{ "RightUpperArm", "UpperTorso", "RightShoulder" }, { "RightLowerArm", "RightUpperArm", "RightElbow" },
	{ "RightHand", "RightLowerArm", "RightWrist" },
	{ "LeftUpperLeg", "LowerTorso", "LeftHip" }, { "LeftLowerLeg", "LeftUpperLeg", "LeftKnee" },
	{ "LeftFoot", "LeftLowerLeg", "LeftAnkle" },
	{ "RightUpperLeg", "LowerTorso", "RightHip" }, { "RightLowerLeg", "RightUpperLeg", "RightKnee" },
	{ "RightFoot", "RightLowerLeg", "RightAnkle" },
}

local function directPart(m, name)
	local p = m:FindFirstChild(name)
	return p and p:IsA("BasePart") and p or nil
end

local function toMotor6D(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("AnimationConstraint") or d:IsA("BallSocketConstraint") then d:Destroy() end
	end
	local made = 0
	for _, joint in ipairs(R15_JOINTS) do
		local part, parent = directPart(m, joint[1]), directPart(m, joint[2])
		local has = false
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("Motor6D") and d.Part1 == part then has = true break end
		end
		if part and parent and not has then
			local motor = Instance.new("Motor6D")
			motor.Name = joint[3]
			motor.Part0 = parent
			motor.Part1 = part
			motor.C0 = parent.CFrame:ToObjectSpace(part.CFrame)
			motor.C1 = CFrame.new()
			motor.Parent = part
			made += 1
		end
	end
	return made
end

-- สไลม์ของโรงงานไม่มี Humanoid (สคริปต์ SlimeController ย้ายทั้งก้อนด้วย PivotTo) — สัตว์เลี้ยงต้องเดินด้วย MoveTo
-- ลูกบอลแกนกลาง (`Core`) กลายเป็น HumanoidRootPart ทรงเดียวกับสไลม์เขียวของ `Mobs.buildSlime` ที่เดินได้ในเกมจริง
-- ชิ้นอื่นเชื่อมเข้าแกนทั้งหมดและเดินทะลุได้ (ชนกับพื้นแค่ลูกบอลลูกเดียว ไม่สะดุด)
local function slimeRig(m, core)
	core.Name = "HumanoidRootPart"
	core.Parent = m
	core.CanCollide = true
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p ~= core and p.Name ~= "Root" then
			p.CanCollide = false
			p.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = core
			weld.Part1 = p
			weld.Parent = p
		end
	end
	local hum = Instance.new("Humanoid")
	hum.WalkSpeed = 5
	hum.UseJumpPower = true
	hum.JumpPower = 22
	hum.Parent = m
end

-- สไลม์เขียว: มอนตัวเดียวที่ไม่มีโมเดลในเกมหลัก (`Mobs.buildSlime` ปั้นลูกบอลสองลูก) — ปั้นให้เข้าชุดกับสไลม์โรงงาน
local function buildGreenSlime()
	local m = Instance.new("Model")
	m.Name = "Pet_GreenSlime"
	local jelly = Color3.fromRGB(96, 200, 104)
	local function ball(name, cf, d, color, mat, trans)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(d, d, d)
		p.CFrame = cf
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Transparency = trans or 0
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	local r = 1.8
	local c0 = CFrame.new(0, 0.4 + r, 0)
	local core = ball("Core", c0, r * 2, jelly, Enum.Material.Glass, 0.25)
	ball("Inner", c0 * CFrame.new(0, -0.2, 0), 2.2, jelly:Lerp(Color3.new(0, 0.25, 0), 0.35), Enum.Material.SmoothPlastic, 0.1)
	for i = 1, 4 do
		local a = math.rad(i * 90 + 45)
		ball("BlobDrop_" .. i, c0 * CFrame.new(math.cos(a) * r * 1.05, -r * 0.55, math.sin(a) * r * 1.05), r * 0.7, jelly,
			Enum.Material.Glass, 0.25)
	end
	for _, s in ipairs({ -1, 1 }) do
		local eye = ball("Eye", c0 * CFrame.new(0.62 * s, 0.45, -1.55), 0.62, Color3.fromRGB(24, 28, 30))
		ball("Glint", eye.CFrame * CFrame.new(0.1 * s, 0.14, -0.22), 0.2, Color3.new(1, 1, 1), Enum.Material.Neon)
	end
	-- แก้มชมพูเล็กๆ: ตัวที่ผู้เล่นเลี้ยงควรดูน่ารักกว่าตัวที่เจอในทุ่ง
	for _, s in ipairs({ -1, 1 }) do
		local cheek = Instance.new("Part")
		cheek.Name = "Cheek"
		cheek.Size = Vector3.new(0.46, 0.16, 0.08)
		cheek.CFrame = c0 * CFrame.new(1.05 * s, 0.02, -1.42) * CFrame.Angles(0, math.rad(28 * s), 0)
		cheek.Color = Color3.fromRGB(255, 150, 170)
		cheek.Material = Enum.Material.SmoothPlastic
		cheek.Parent = m
	end
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new()
	root.Transparency = 1
	root.Parent = m
	m.PrimaryPart = root
	return m, core
end

-- id → วิธีสร้าง · `r15` = แปลงข้อต่อ · `slime` = ทำ Humanoid ให้สไลม์ (Core เป็นลูกบอลแกนกลางในโมเดล Body)
local SPECIES = {
	{ id = "Pet_Chicken", builder = "Animal_Chicken" },
	{ id = "Pet_Duck", builder = "Animal_Duck" },
	{ id = "Pet_Pig", builder = "Animal_Pig" },
	{ id = "Pet_Goat", builder = "Animal_Goat" },
	{ id = "Pet_Sheep", builder = "Animal_Sheep" },
	{ id = "Pet_Cow", builder = "Animal_Cow" },
	{ id = "Pet_Deer", builder = "Animal_Deer" },
	{ id = "Pet_Horse", builder = "Animal_Horse" },
	{ id = "Pet_Bat", builder = "Monster_Bat" },
	{ id = "Pet_Boar", builder = "Monster_Boar" },
	{ id = "Pet_Wolf", builder = "Monster_Wolf" },
	{ id = "Pet_Spider", builder = "Monster_Spider" },
	{ id = "Pet_Skeleton", builder = "Monster_Skeleton", r15 = true },
	{ id = "Pet_Bandit", builder = "Monster_Bandit", r15 = true },
	{ id = "Pet_Ghoul", builder = "Monster_Ghoul", r15 = true },
	{ id = "Pet_ClockworkSentry", builder = "Monster_ClockworkSentry", r15 = true },
	{ id = "Pet_Wraith", builder = "Monster_Wraith", r15 = true },
	{ id = "Pet_StoneGolem", builder = "Monster_StoneGolem", r15 = true },
	{ id = "Pet_SteamSlime", builder = "Monster_SteamSlime", slime = true },
	{ id = "Pet_PlasmaSlime", builder = "Monster_PlasmaSlime", slime = true },
	{ id = "Pet_BioSlime", builder = "Monster_BioSlime", slime = true },
	{ id = "Pet_GreenSlime", green = true },
}

-- ฐานตัวสัตว์ลงที่ y = 0 กึ่งกลางกล่องที่ x/z = 0 (Root อยู่ตรงนั้น) แล้วขยาย/ย่อรอบ Root ให้สูงเท่าคน
local function finish(m, id)
	local root = m:FindFirstChild("Root")
	m.PrimaryPart = root
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true end
	end
	local lo, hi = bounds(m)
	root.CFrame = CFrame.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	m:PivotTo(CFrame.new())
	lo, hi = bounds(m)
	local size = hi - lo
	local s = math.min(FULL_HEIGHT / size.Y, MAX_SIDE / math.max(size.X, size.Z))
	m:ScaleTo(m:GetScale() * s)
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new()
	root.Transparency, root.CanCollide, root.CanQuery, root.CanTouch = 1, false, false, false
	lo, hi = bounds(m)
	size = hi - lo
	m.Name = id
	m:SetAttribute("Pet", true)
	m:SetAttribute("FullScale", m:GetScale())
	m:SetAttribute("FullSize", size)
	m:SetAttribute("Footprint", Vector2.new(cells(size.X), cells(size.Z)))
	m:SetAttribute("Manual", true)
	m.Parent = folder
	if PREVIEW then
		previewIndex += 1
		local at = workspace:GetAttribute("PetsPreviewAt") or Vector3.new(0, 200, 0)
		m:PivotTo(CFrame.new(at + Vector3.new(((previewIndex - 1) % 8) * 10, 0, math.floor((previewIndex - 1) / 8) * 12)))
	end
	local parts = 0
	for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then parts += 1 end end
	print(("[Pets] %-20s %2dx%-2d ช่อง  %.1f x %.1f x %.1f  สเกล %.2f  %d ชิ้น"):format(id, cells(size.X), cells(size.Z),
		size.X, size.Y, size.Z, m:GetScale(), parts))
end

status("start")
local made, failed = 0, {}
for _, spec in ipairs(SPECIES) do
	if not ONLY or ONLY == spec.id then
		local ok, err = pcall(function()
			local old = folder:FindFirstChild(spec.id)
			if old then old:Destroy() end
			local m
			if spec.green then
				local core
				m, core = buildGreenSlime()
				slimeRig(m, core)
			else
				m = K.place(spec.builder, workspace, CFrame.new())
				if not m then error("ไม่มี builder " .. spec.builder .. " (ลืม --models?)") end
				m.Parent = nil
				strip(m)
				if spec.r15 then toMotor6D(m) end
				if spec.slime then
					local core = m:FindFirstChild("Core", true)
					if not core then error("สไลม์ไม่มี Core") end
					slimeRig(m, core)
				end
			end
			strip(m)
			finish(m, spec.id)
		end)
		if ok then made += 1 else failed[#failed + 1] = spec.id .. ": " .. tostring(err) end
	end
end

-- หมา/แมวของเฟส 90: เติมข้อมูลเต็มวัยให้เท่านั้น (ตัวที่ผู้เล่นมีอยู่แล้วคือขนาดนี้)
for _, id in ipairs({ "Pet_Dog", "Pet_Cat" }) do
	local m = folder:FindFirstChild(id)
	if m and (not ONLY or ONLY == id) then
		-- สคริปต์ BeastGait ในโมเดลวิ่งทันทีที่ตัวโคลนลง workspace (ก่อน IslandPets ปิดให้) — ถอดทิ้งให้เหมือนตัวอื่น
		-- ป้ายชื่อของ kit ก็ถอดด้วย: IslandPets แขวนป้ายชื่อ + ความโต (PetTag) ให้ทุกตัวแบบเดียวกันแล้ว
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") then d:Destroy() end
		end
		local lo, hi = bounds(m)
		m:SetAttribute("FullScale", m:GetScale())
		m:SetAttribute("FullSize", hi - lo)
		m:SetAttribute("Pet", true)
		print(("[Pets] %-20s เติม FullScale %.2f FullSize %.1f x %.1f x %.1f"):format(id, m:GetScale(), hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z))
	elseif not m then
		warn("[Pets] ไม่มี " .. id .. " — รันเฟส 90 ก่อน")
	end
end

for _, f in ipairs(failed) do warn("[Pets] " .. f) end
status(("done %d ตัว · พัง %d"):format(made, #failed), true)
