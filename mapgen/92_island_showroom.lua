-- 92_island_showroom.lua: โชว์รูมของวางบนเกาะ — เอาต้นแบบทุกตัวใน ReplicatedStorage.WOLD_Placeables มาเรียงบนแท่น
-- ใน workspace ให้ดู/แก้ใน Studio ได้ แล้วส่งของที่แก้กลับเข้าระบบ
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/92_island_showroom.lua --no-lib
--
-- สามโหมด ตั้งแอตทริบิวต์บน workspace ก่อนรัน (ไม่ตั้ง = สร้างโชว์รูม):
--   (ไม่ตั้งอะไร)          สร้าง/สร้างใหม่ workspace.WOLD_Island.Showroom จากต้นแบบปัจจุบัน
--   ShowroomAdopt = true   เอาโมเดลในโชว์รูม (ที่ผู้ใช้แก้แล้ว) ไปแทนต้นแบบใน WOLD_Placeables + ติด Manual=true
--                          (เฟส 90 รันซ้ำจะไม่ทับตัวที่ติด Manual) — ชื่อโมเดลในโชว์รูม = id ของไอเทม ห้ามเปลี่ยน
--   ShowroomErase = true   ลบโชว์รูมทิ้ง
--
-- โชว์รูมลอยอยู่ไกลจากเกาะ (ORIGIN) ผู้เล่นมองไม่เห็น · ไม่แตะ WOLD_Island.Placed/Fixed
local RS = game:GetService("ReplicatedStorage")
local CELL = 4
local ORIGIN = Vector3.new(0, 1400, -900)
local GAP = 12

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[Showroom] " .. msg)
end

local island = workspace:FindFirstChild("WOLD_Island")
if not island then island = Instance.new("Folder"); island.Name = "WOLD_Island"; island.Parent = workspace end
local protos = RS:FindFirstChild("WOLD_Placeables")
assert(protos, "ไม่มี ReplicatedStorage.WOLD_Placeables — รันเฟส 90 ก่อน")

local function cells(studs) return math.max(1, math.ceil(studs / CELL - 0.05)) end

-- เหมือน finish ของเฟส 90: Root ที่กึ่งกลางกล่องระดับฐาน + Footprint จากกล่องจริง (โมเดลที่แก้มือแล้วอาจโตขึ้น/หดลง)
local function normalize(m)
	local root = m:FindFirstChild("Root")
	if not root then
		root = Instance.new("Part"); root.Name = "Root"; root.Size = Vector3.new(1, 1, 1)
		root.Transparency = 1; root.CanCollide = false; root.Anchored = true; root.Massless = true
		root.CFrame = m:GetPivot(); root.Parent = m
	end
	root.CanQuery = false; root.CanTouch = false
	m.PrimaryPart = root
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
		if d:IsA("ProximityPrompt") or d:IsA("LocalScript") or d:IsA("BillboardGui") then d:Destroy() end
	end
	m:PivotTo(CFrame.new()) -- กลับมาที่จุดกำเนิดตามทิศของ Root (โชว์รูมวางทุกตัวหันทิศเดิม)
	local cf, size = m:GetBoundingBox()
	root.CFrame = CFrame.new(cf.Position.X, 0, cf.Position.Z)
	m:SetAttribute("Footprint", Vector2.new(cells(size.X), cells(size.Z)))
	return size
end

--------------------------------------------------------------------------------
-- ลบ
--------------------------------------------------------------------------------
if workspace:GetAttribute("ShowroomErase") == true then
	local old = island:FindFirstChild("Showroom")
	if old then old:Destroy() end
	workspace:SetAttribute("ShowroomErase", nil)
	status("done: ลบโชว์รูมแล้ว", true)
	return
end

--------------------------------------------------------------------------------
-- adopt: โชว์รูม → ต้นแบบ
--------------------------------------------------------------------------------
if workspace:GetAttribute("ShowroomAdopt") == true then
	local show = island:FindFirstChild("Showroom")
	assert(show, "ไม่มีโชว์รูมให้ adopt")
	local n = 0
	for _, m in ipairs(show:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("ShowroomItem") then
			local copy = m:Clone()
			copy:SetAttribute("ShowroomItem", nil)
			local size = normalize(copy)
			copy:SetAttribute("Manual", true)
			local old = protos:FindFirstChild(copy.Name)
			if old then old:Destroy() end
			copy.Parent = protos
			n += 1
			print(("[Showroom] adopt %-20s %2dx%-2d ช่อง (%.1f x %.1f x %.1f)"):format(copy.Name, cells(size.X), cells(size.Z), size.X, size.Y, size.Z))
		end
	end
	workspace:SetAttribute("ShowroomAdopt", nil)
	status(("done: adopt %d ต้นแบบ (ติด Manual แล้ว เฟส 90 จะไม่ทับ)"):format(n), true)
	return
end

--------------------------------------------------------------------------------
-- สร้างโชว์รูม
--------------------------------------------------------------------------------
local old = island:FindFirstChild("Showroom")
if old then old:Destroy() end
local show = Instance.new("Folder"); show.Name = "Showroom"; show.Parent = island

local names = {}
for _, m in ipairs(protos:GetChildren()) do table.insert(names, m.Name) end
table.sort(names, function(a, b)
	local wa, wb = protos[a]:GetAttribute("Footprint"), protos[b]:GetAttribute("Footprint")
	local sa, sb = (wa and wa.X or 1) * (wa and wa.Y or 1), (wb and wb.X or 1) * (wb and wb.Y or 1)
	if sa ~= sb then return sa < sb end
	return a < b
end)

-- แถวเดียวเรียงจากเล็กไปใหญ่ ระยะห่างตาม footprint จริง
local totalWidth = 0
local widths = {}
for _, name in ipairs(names) do
	local fp = protos[name]:GetAttribute("Footprint") or Vector2.new(1, 1)
	widths[name] = fp.X * CELL
	totalWidth += widths[name] + GAP
end

local pad = Instance.new("Part")
pad.Name = "Floor"
pad.Anchored = true
pad.Size = Vector3.new(totalWidth + 40, 2, 120)
pad.CFrame = CFrame.new(ORIGIN - Vector3.new(0, 1, 0))
pad.Material = Enum.Material.Slate
pad.Color = Color3.fromRGB(70, 70, 76)
pad.Parent = show

local x = ORIGIN.X - totalWidth / 2
for _, name in ipairs(names) do
	local proto = protos[name]
	local fp = proto:GetAttribute("Footprint") or Vector2.new(1, 1)
	x += widths[name] / 2
	local m = proto:Clone()
	m:SetAttribute("ShowroomItem", true)
	m:PivotTo(CFrame.new(x, ORIGIN.Y, ORIGIN.Z))
	m.Parent = show

	-- ป้ายชื่อลอยเหนือหัว: id · ขนาดช่อง · Manual ถ้าเคยแก้มือ
	local _, size = m:GetBoundingBox()
	local tag = Instance.new("BillboardGui")
	tag.Name = "ShowLabel"
	tag.Size = UDim2.new(0, 220, 0, 44)
	tag.StudsOffsetWorldSpace = Vector3.new(0, size.Y + 3, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 400
	tag.Adornee = m.PrimaryPart
	tag.Parent = m.PrimaryPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	label.TextColor3 = Color3.fromRGB(240, 230, 200)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = ("%s\n%dx%d ช่อง%s"):format(name, fp.X, fp.Y, proto:GetAttribute("Manual") and " · Manual" or "")
	label.Parent = tag

	x += widths[name] / 2 + GAP
end

-- ป้ายวิธีใช้บนแท่น
local sign = Instance.new("Part")
sign.Name = "HowTo"
sign.Anchored = true
sign.Size = Vector3.new(60, 14, 1)
-- ปลายซ้ายของแถว หันหน้า (+Z หลังหมุน 180°) มาทางคนดูที่ยืนหน้าแท่น ไม่บังโมเดล
sign.CFrame = CFrame.new(ORIGIN + Vector3.new(-totalWidth / 2 - 45, 8, 0)) * CFrame.Angles(0, math.pi, 0)
sign.Color = Color3.fromRGB(30, 28, 34)
sign.Parent = show
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Front
gui.CanvasSize = Vector2.new(1200, 280)
gui.Parent = sign
local text = Instance.new("TextLabel")
text.Size = UDim2.new(1, 0, 1, 0)
text.BackgroundTransparency = 1
text.TextColor3 = Color3.fromRGB(240, 230, 200)
text.Font = Enum.Font.Gotham
text.TextScaled = true
text.TextWrapped = true
text.Text = "โชว์รูมของวางบนเกาะ — แก้โมเดลตรงนี้ได้เลย (ห้ามเปลี่ยนชื่อโมเดล)\nแก้เสร็จ: workspace:SetAttribute(\"ShowroomAdopt\", true) แล้วรัน mapgen/92_island_showroom.lua\nลบโชว์รูม: ShowroomErase = true"
text.Parent = gui

status(("done: โชว์รูม %d ตัวที่ %s (ยาว %.0f studs)"):format(#names, tostring(ORIGIN), totalWidth), true)
