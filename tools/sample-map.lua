-- sample-map.lua: one BAND of rows for the world-map IMAGE (แผนที่ v2 · 2026-10-02), driven by tools/build-map-image.js.
-- คนละตัวกับ sample-terrain.lua (กริด 360 ที่ MapTerrain ใช้กันปักหมุดกลางน้ำ) — ตัวนี้ละเอียดกว่า และวัดสิ่งก่อสร้างด้วย
--
-- ต่อช่อง (กริด N x N ทั่วโลก 16,000 สตัด):
--   ผิวเทอร์เรน: วัสดุ + ความสูง (ชนน้ำ = ผิวน้ำ) · ก้นน้ำ: เรย์ข้ามน้ำ → ความลึก
--   สิ่งก่อสร้าง: เรย์ชน Part ที่ไม่ใช่เทอร์เรน/ต้นไม้-หิน-พุ่ม (WOLD.Gather)/สายแร่ (WOLD.Mineral)/ของล่องหน → สี + สูงจากพื้น
--
-- ส่งกลับเป็นข้อความ (execute_luau ตัดที่ 100KB): บรรทัดแรก header แล้วแถวคั่นด้วย ";"
--   แถว = 4 ตัวอักษรต่อช่อง (เทอร์เรน 24 บิต: วัสดุ 4 · ความสูง+64 12 · ความลึก 8) ทั้งแถว
--          ตามด้วย "|" + รายการสิ่งก่อสร้าง 6 ตัวต่อช่องที่มี (gx-1 12 บิต · สี 4-4-4 + สูงจากพื้น 8 บิต + 4 บิตว่าง)
local N = 1024    -- __N__
local FROM = 1    -- __FROM__
local TO = 8      -- __TO__

local HALF = 8000
local STEP = (HALF * 2) / N
local TOP = 5000 -- เหนือยอดสูงสุด (ปล่องมังกรหลับ ~2,260) เผื่อไว้เยอะ

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local CH = {}
for i = 1, 64 do CH[i - 1] = B64:sub(i, i) end
local function enc(v, chars)
	local s = table.create(chars)
	for i = chars, 1, -1 do
		s[i] = CH[v % 64]
		v = v // 64
	end
	return table.concat(s)
end

-- รหัสวัสดุต้องตรงกับ MATERIALS ใน tools/render-map.py
local MAT = { Water = 0, Grass = 1, LeafyGrass = 2, Rock = 3, Snow = 4, Sand = 5, Basalt = 6, Ground = 7, Mud = 8,
	Limestone = 9, Slate = 10, Cobblestone = 11, Pavement = 12, Brick = 13, Ice = 14 }
local OTHER = 15

local terrain = RaycastParams.new()
terrain.FilterType = Enum.RaycastFilterType.Include
terrain.FilterDescendantsInstances = { workspace.Terrain }
terrain.IgnoreWater = false
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
floorParams.FilterDescendantsInstances = { workspace.Terrain }
floorParams.IgnoreWater = true

local exclude = { workspace.Terrain }
local wold = workspace:FindFirstChild("WOLD")
for _, name in ipairs({ "Gather", "Mineral" }) do
	local f = wold and wold:FindFirstChild(name)
	if f then exclude[#exclude + 1] = f end
end
local structure = RaycastParams.new()
structure.FilterType = Enum.RaycastFilterType.Exclude
structure.FilterDescendantsInstances = exclude
structure.IgnoreWater = true

-- สิ่งก่อสร้างบนผิว: ข้ามของล่องหน และของลอยสูงผิดปกติ (พร็อพแร่ค้างที่ y 2,859) ด้วยการเพิ่มเข้า filter แล้วยิงใหม่
-- ชนต่ำกว่าผิว = ของใต้ดิน/ใต้น้ำ (ถ้ำ) ไม่นับ
local function structureAt(x, z, ground)
	for _ = 1, 8 do
		local hit = workspace:Raycast(Vector3.new(x, TOP, z), Vector3.new(0, -(TOP - ground + 2), 0), structure)
		if not hit then return nil end
		local part = hit.Instance
		local above = hit.Position.Y - ground
		if above < -2 then return nil end
		if part.Transparency < 0.9 and above <= 400 then
			local c = part.Color
			local color = math.floor(c.R * 15 + 0.5) * 256 + math.floor(c.G * 15 + 0.5) * 16 + math.floor(c.B * 15 + 0.5)
			return color, math.clamp(math.floor(above + 0.5), 0, 255)
		end
		structure:AddToFilter(part)
	end
	return nil
end

local rows = {}
local land, water, miss, built = 0, 0, 0, 0
for gz = FROM, TO do
	local z = -HALF + (gz - 0.5) * STEP
	local cells, extra = table.create(N), {}
	for gx = 1, N do
		local x = -HALF + (gx - 0.5) * STEP
		local hit = workspace:Raycast(Vector3.new(x, TOP, z), Vector3.new(0, -(TOP + 600), 0), terrain)
		local mat, y, depth = OTHER, 0, 0
		if hit then
			y = hit.Position.Y
			mat = MAT[hit.Material.Name] or OTHER
			if mat == 0 then
				water += 1
				local floor = workspace:Raycast(hit.Position, Vector3.new(0, -600, 0), floorParams)
				depth = floor and math.clamp(math.floor(y - floor.Position.Y + 0.5), 0, 255) or 255
			else
				land += 1
			end
			local color, above = structureAt(x, z, y)
			if color then
				built += 1
				extra[#extra + 1] = enc(gx - 1, 2) .. enc(color * 4096 + above * 16, 4)
			end
		else
			miss += 1
		end
		cells[gx] = enc(mat * 1048576 + math.clamp(math.floor(y + 64.5), 0, 4095) * 256 + depth, 4)
	end
	rows[#rows + 1] = table.concat(cells) .. (#extra > 0 and "|" .. table.concat(extra) or "")
	task.wait()
end

return ("BAND %d %d %d land=%d water=%d miss=%d built=%d\n%s"):format(N, FROM, TO, land, water, miss, built,
	table.concat(rows, ";"))
