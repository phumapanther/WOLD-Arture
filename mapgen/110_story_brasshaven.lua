-- 110_story_brasshaven.lua: ฉากของบทแรก "ผู้มากับแสงวิบวับ" ในเพลสหลัก (ผู้ใช้อนุมัติร่าง 2026-09-27 · docs/story/01-brasshaven.md)
--
--     node tools/run-luau.js mapgen/110_story_brasshaven.lua --kit --models --no-lib
--
-- วางสามอย่างลง `workspace.WOLD.Story` — **ลากย้ายได้ทุกชิ้นใน Studio** รันซ้ำแล้วไม่ย้ายกลับ (ของที่มีอยู่แล้วคงตำแหน่งเดิม):
--   MagicCircle        วงเวทโบราณ (วงหิน รูนเรืองแสง 3 ชั้น เสาหิน 12 ต้น ท่อไอน้ำ 2 ท่อ) แท็ก `WOLD_MagicCircle`
--                      หาที่ราบว่างใกล้จุดเกิดเอง (ยิงเรย์) · มีอยู่แล้ว = สร้างใหม่ที่เดิม · `Manual = true` = ไม่แตะเลย
--                      ชิ้นชื่อ `Rune*` + แอตทริบิวต์ `Ring` = รูนที่คัทซีนทำให้สว่างทีละวง · `Steam` = อนุภาคไอน้ำ
--   Mechanic_Lyra      ไลรา (โมเดลจากโรงงาน models/npcs.lua) ยืนข้างวงหันหน้าเข้าวง · แท็ก `WOLD_StoryNpc` + `StoryNpc = "Lyra"`
--                      ถอดสคริปต์เดินสุ่ม + ปุ่มตกแต่ง (Story.server ใส่ปุ่ม "คุย" เอง) · ตรึง HumanoidRootPart
--   Memory_Brasshaven  หมุดจุดหมายขั้นที่ 4 (ล่องหน) ที่อนุสาวรีย์/น้ำพุ/หอนาฬิกาที่ใกล้กลางเมืองที่สุด · แท็ก `WOLD_StoryMarker`
--                      + `Chapter = "brasshaven"` · หาไม่เจอ = กลางเมือง (QuestConfig Brasshaven.where)
-- ⚠️ เพลสหลักเท่านั้น (88774255487951) · ไม่ใช่ของโรงงาน WOLD-Models
if game.PlaceId ~= 88774255487951 then return "REFUSED: ฉากเนื้อเรื่องอยู่เพลสหลักเท่านั้น" end

local CollectionService = game:GetService("CollectionService")
local TOWN_CENTER = Vector3.new(2080, 48, 3760)
local CIRCLE_RADIUS = 9
local RUNE = Color3.fromRGB(126, 214, 232)
local STONE = Color3.fromRGB(96, 96, 104)
local BRASS = Color3.fromRGB(176, 136, 70)

local root = workspace:FindFirstChild("WOLD") or Instance.new("Folder")
root.Name = "WOLD"
root.Parent = workspace
local folder = root:FindFirstChild("Story") or Instance.new("Folder")
folder.Name = "Story"
folder.Parent = root

local function params()
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { folder }
	for _, name in ipairs({ "WOLD_Mobs", "WOLD_Vehicles" }) do
		local f = workspace:FindFirstChild(name)
		if f then exclude[#exclude + 1] = f end
	end
	p.FilterDescendantsInstances = exclude
	p.RespectCanCollide = true -- กล่องโซนหมู่บ้านล่องหนสูง 200 สตัดไม่ใช่พื้น (บทเรียนจุดเรียกพาหนะ)
	return p
end

local function groundAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, TOWN_CENTER.Y + 300, z), Vector3.new(0, -700, 0), params())
	return hit and hit.Position.Y, hit
end

-- จุดเกิดของเมือง (SpawnLocation ที่ใกล้กลางเมืองสุด หรือแท่นชั่วคราว)
local function spawnPoint()
	local best, bestD
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") then
			local dist = (d.Position - TOWN_CENTER).Magnitude
			if not bestD or dist < bestD then best, bestD = d.Position, dist end
		end
	end
	if best and bestD < 600 then return best end
	local temp = root:FindFirstChild("TempSpawn")
	return temp and temp:GetPivot().Position or TOWN_CENTER
end

-- ราบพอ + ไม่มีของชนได้ขวางในวง
local function spotOk(x, z)
	local y = groundAt(x, z)
	if not y then return nil end
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local yy = groundAt(x + math.cos(a) * (CIRCLE_RADIUS + 1), z + math.sin(a) * (CIRCLE_RADIUS + 1))
		if not yy or math.abs(yy - y) > 1.6 then return nil end
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { folder, workspace.Terrain }
	overlap.RespectCanCollide = true
	local blocking = workspace:GetPartBoundsInBox(CFrame.new(x, y + 5, z),
		Vector3.new(CIRCLE_RADIUS * 2 + 4, 8, CIRCLE_RADIUS * 2 + 4), overlap)
	if #blocking > 0 then return nil end
	return y
end

local function findSpot(near)
	for r = 18, 90, 6 do
		for i = 0, 23 do
			local a = i / 24 * math.pi * 2
			local x, z = near.X + math.cos(a) * r, near.Z + math.sin(a) * r
			local y = spotOk(x, z)
			if y then return Vector3.new(x, y, z) end
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- วงเวท
--------------------------------------------------------------------------------
local function part(parent, name, size, cf, color, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	p.CanTouch = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function cylinderUp(parent, name, cf, radius, height, color, material, collide)
	local p = part(parent, name, Vector3.new(height, radius * 2, radius * 2), cf * CFrame.Angles(0, 0, math.rad(90)), color, material, collide)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function buildCircle(center)
	local m = Instance.new("Model")
	m.Name = "MagicCircle"
	local base = cylinderUp(m, "Base", CFrame.new(center + Vector3.new(0, 0.1, 0)), CIRCLE_RADIUS, 0.6, STONE, Enum.Material.Slate, true)
	cylinderUp(m, "Inlay", CFrame.new(center + Vector3.new(0, 0.42, 0)), CIRCLE_RADIUS - 0.8, 0.06, Color3.fromRGB(70, 70, 80), Enum.Material.Slate)
	cylinderUp(m, "RuneCore", CFrame.new(center + Vector3.new(0, 0.47, 0)), 1.2, 0.05, RUNE, Enum.Material.Neon):SetAttribute("Ring", 0)
	-- รูนสามวง: ขีดเรืองแสงวางรอบวง
	for ring, spec in ipairs({ { r = 3, n = 14 }, { r = 5.4, n = 22 }, { r = 7.5, n = 30 } }) do
		for i = 1, spec.n do
			local a = i / spec.n * math.pi * 2
			local pos = center + Vector3.new(math.cos(a) * spec.r, 0.47, math.sin(a) * spec.r)
			local rune = part(m, "Rune", Vector3.new(0.18, 0.05, (i % 3 == 0) and 0.9 or 0.55),
				CFrame.lookAt(pos, center + Vector3.new(0, 0.47, 0)) * CFrame.Angles(0, (i % 2) * 0.35, 0), RUNE, Enum.Material.Neon)
			rune:SetAttribute("Ring", ring)
		end
	end
	-- เสาหินจารึกรอบวง 12 ต้น แผ่นรูนหันเข้าหากลาง
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		local pos = center + Vector3.new(math.cos(a) * (CIRCLE_RADIUS + 0.6), 1.6, math.sin(a) * (CIRCLE_RADIUS + 0.6))
		local cf = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
		part(m, "Standing", Vector3.new(1.2, 3.4 + (i % 3) * 0.5, 0.8), cf, STONE, Enum.Material.Slate, true)
		part(m, "RuneStone", Vector3.new(0.5, 1, 0.06), cf * CFrame.new(0, 0.4, -0.43), RUNE, Enum.Material.Neon):SetAttribute("Ring", 4)
	end
	-- ท่อไอน้ำเก่าสองข้าง พ่นไอเป็นระยะ
	for _, side in ipairs({ -1, 1 }) do
		local foot = center + Vector3.new(side * (CIRCLE_RADIUS + 3.2), 0, 0)
		cylinderUp(m, "Pipe", CFrame.new(foot + Vector3.new(0, 3.2, 0)), 0.55, 6.4, BRASS, Enum.Material.Metal, true)
		cylinderUp(m, "PipeRing", CFrame.new(foot + Vector3.new(0, 5.6, 0)), 0.7, 0.3, Color3.fromRGB(110, 90, 60), Enum.Material.Metal)
		local cap = cylinderUp(m, "PipeCap", CFrame.new(foot + Vector3.new(0, 6.5, 0)), 0.45, 0.3, Color3.fromRGB(90, 80, 70), Enum.Material.Metal)
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(0, 0, 0)
		att.Parent = cap
		local steam = Instance.new("ParticleEmitter")
		steam.Name = "Steam"
		steam.Color = ColorSequence.new(Color3.fromRGB(230, 232, 236))
		steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.2) })
		steam.Lifetime = NumberRange.new(2, 3)
		steam.Speed = NumberRange.new(3, 5)
		steam.SpreadAngle = Vector2.new(12, 12)
		steam.EmissionDirection = Enum.NormalId.Right -- แกน X ของทรงกระบอกที่หมุนตั้ง = ขึ้นฟ้า
		steam.Rate = 1.5
		steam.Parent = att
	end
	local glow = Instance.new("PointLight")
	glow.Color = RUNE
	glow.Range = 18
	glow.Brightness = 1.2
	glow.Shadows = false
	glow.Parent = base
	m.PrimaryPart = base
	m.WorldPivot = CFrame.new(center)
	m.Parent = folder
	CollectionService:AddTag(m, "WOLD_MagicCircle")
	return m
end

local circle = folder:FindFirstChild("MagicCircle")
local center
if circle and circle:GetAttribute("Manual") then
	center = circle:GetPivot().Position
else
	if circle then
		center = circle:GetPivot().Position
		circle:Destroy()
	else
		center = findSpot(spawnPoint())
		assert(center, "หาที่ราบว่างสำหรับวงเวทใกล้จุดเกิดไม่เจอ (รัศมี 90) — วางโมเดลชื่อ MagicCircle เองแล้วรันซ้ำ")
	end
	circle = buildCircle(center)
end

--------------------------------------------------------------------------------
-- ไลรา
--------------------------------------------------------------------------------
local lyra = folder:FindFirstChild("Mechanic_Lyra")
if not lyra then
	-- ยืนนอกวงฝั่งที่หันไปทางจุดเกิด หันหน้าเข้าหาวง
	local toward = (spawnPoint() - center) * Vector3.new(1, 0, 1)
	toward = toward.Magnitude > 1 and toward.Unit or Vector3.new(0, 0, 1)
	local at = center + toward * (CIRCLE_RADIUS + 5)
	local y = groundAt(at.X, at.Z) or center.Y
	at = Vector3.new(at.X, y, at.Z)
	-- โมเดลหันหน้า -Z → lookAt ให้ -Z ชี้เข้ากลางวง
	lyra = K.place("Mechanic_Lyra", folder, CFrame.lookAt(at, Vector3.new(center.X, y, center.Z)))
	assert(lyra, "ไม่มี builder Mechanic_Lyra (ลืม --kit --models?)")
end
for _, d in ipairs(lyra:GetDescendants()) do
	if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy()
	elseif d:IsA("ProximityPrompt") and d.Name ~= "StoryPrompt" then d:Destroy()
	elseif d:IsA("BillboardGui") and d.Name == "NameTag" then d.MaxDistance = 40 end
end
local hrp = lyra:FindFirstChild("HumanoidRootPart")
if hrp then hrp.Anchored = true end
lyra:SetAttribute("StoryNpc", "Lyra")
CollectionService:AddTag(lyra, "WOLD_StoryNpc")

--------------------------------------------------------------------------------
-- หมุดความทรงจำ (ขั้นที่ 4)
--------------------------------------------------------------------------------
local marker = folder:FindFirstChild("Memory_Brasshaven")
if not marker then
	local best, bestD
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and not d:IsDescendantOf(folder) then
			local n = d.Name:lower()
			if n:find("monument") or n:find("statue") or n:find("fountain") or n:find("clocktower") or n:find("clock_tower") then
				local ok, pivot = pcall(d.GetPivot, d)
				if ok then
					local dist = (pivot.Position - TOWN_CENTER).Magnitude
					if dist < 400 and (not bestD or dist < bestD) then best, bestD = d, dist end
				end
			end
		end
	end
	local at
	if best then
		local cf, size = best:GetBoundingBox()
		local out = (TOWN_CENTER - cf.Position) * Vector3.new(1, 0, 1)
		out = out.Magnitude > 1 and out.Unit or Vector3.new(0, 0, 1)
		local p = cf.Position + out * (math.max(size.X, size.Z) / 2 + 6)
		at = Vector3.new(p.X, groundAt(p.X, p.Z) or cf.Position.Y, p.Z)
	else
		at = Vector3.new(TOWN_CENTER.X, groundAt(TOWN_CENTER.X, TOWN_CENTER.Z) or TOWN_CENTER.Y, TOWN_CENTER.Z)
	end
	marker = Instance.new("Part")
	marker.Name = "Memory_Brasshaven"
	marker.Size = Vector3.new(3, 0.4, 3)
	marker.Position = at + Vector3.new(0, 0.2, 0)
	marker.Transparency = 1
	marker.Anchored = true
	marker.CanCollide, marker.CanQuery, marker.CanTouch = false, false, false
	marker.Parent = folder
	marker:SetAttribute("Near", best and best:GetFullName() or "กลางเมือง (หาอนุสาวรีย์ไม่เจอ)")
end
marker:SetAttribute("Chapter", "brasshaven")
CollectionService:AddTag(marker, "WOLD_StoryMarker")

local lp = lyra:GetPivot().Position
return ("วงเวท (%.0f, %.1f, %.0f) · ไลรา (%.0f, %.1f, %.0f) · หมุดความทรงจำ (%.0f, %.1f, %.0f) ใกล้ %s"):format(
	center.X, center.Y, center.Z, lp.X, lp.Y, lp.Z, marker.Position.X, marker.Position.Y, marker.Position.Z,
	tostring(marker:GetAttribute("Near")))
