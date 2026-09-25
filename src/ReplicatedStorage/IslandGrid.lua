-- IslandGrid: ตรรกะตารางของเกาะล้วนๆ ไม่แตะ Instance — ไคลเอนต์ใช้ระบายสี ghost เซิร์ฟเวอร์ใช้ตัดสินจริง
-- ทั้งสองฝั่งต้องคิดเหมือนกันเป๊ะ จึงอยู่ไฟล์เดียว
--
-- ระบบพิกัด: ช่อง (cx, cz) เป็นจำนวนเต็ม ช่อง (0,0) คือช่องที่มุมล่างซ้ายแตะ Center · ช่องกว้าง Cell studs
-- footprint (w, d) = จำนวนช่องตามแกน X และ Z ของโมเดลตอน r = 0 · r = 0..3 หมุนทีละ 90° · (x, z) ของชิ้นที่วาง
-- = ช่องที่ค่า cx/cz น้อยที่สุดที่มันกิน
local Config = require(script.Parent.IslandConfig)

local IslandGrid = {}
local CELL = Config.Cell

function IslandGrid.cellOf(worldX, worldZ)
	return math.floor((worldX - Config.Center.X) / CELL), math.floor((worldZ - Config.Center.Z) / CELL)
end

-- กึ่งกลางช่อง
function IslandGrid.worldOf(cx, cz)
	return Config.Center.X + (cx + 0.5) * CELL, Config.Center.Z + (cz + 0.5) * CELL
end

function IslandGrid.key(cx, cz)
	return cx .. "," .. cz
end

function IslandGrid.footprintOf(w, d, r)
	if r % 2 == 1 then return d, w end
	return w, d
end

function IslandGrid.cellsOf(x, z, w, d, r)
	local fw, fd = IslandGrid.footprintOf(w, d, r)
	local cells = {}
	for i = 0, fw - 1 do
		for j = 0, fd - 1 do
			table.insert(cells, IslandGrid.key(x + i, z + j))
		end
	end
	return cells
end

-- วงรีของเกาะ หดเข้ามาจากขอบ EdgeMargin
function IslandGrid.inBounds(cx, cz)
	local wx, wz = IslandGrid.worldOf(cx, cz)
	local dx, dz = wx - Config.Center.X, wz - Config.Center.Z
	local rx = Config.Radius - Config.EdgeMargin
	local rz = rx * Config.Oval
	return (dx * dx) / (rx * rx) + (dz * dz) / (rz * rz) <= 1
end

-- zones = { { x = worldX, z = worldZ, radius = studs }, ... }
function IslandGrid.blocked(cx, cz, zones)
	local wx, wz = IslandGrid.worldOf(cx, cz)
	for _, zone in ipairs(zones or {}) do
		local dx, dz = wx - zone.x, wz - zone.z
		if dx * dx + dz * dz < zone.radius * zone.radius then return true end
	end
	return false
end

-- ช่องนี้เป็นผืนดินปลูกผักไหม — ยิงเรย์ลง Terrain แล้วดูวัสดุ
--
-- **ถามผิวจริงทุกครั้ง ไม่จำเป็นกรอบสี่เหลี่ยมไว้** ผู้ใช้ระบายดินรูปไหนก็ได้และขยายทีหลังได้
-- โดยไม่มีเลขไหนต้องตามแก้ · ใช้ได้ทั้งสองฝั่ง (เรย์เป็น read-only)
-- ผิวดินของช่องนี้: คืนความสูงกับวัสดุ (nil = ไม่มีพื้น เช่นนอกเกาะ)
function IslandGrid.surfaceAt(cx, cz)
	local wx, wz = IslandGrid.worldOf(cx, cz)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(wx, Config.Center.Y + 80, wz), Vector3.new(0, -300, 0), params)
	if not hit then return nil end
	return hit.Position.Y, hit.Material
end

-- ชิ้นนี้เป็นของตกแต่งที่ผู้ใช้ตรึงไว้หรือเปล่า
--
-- ถามจาก **ที่อยู่** (อยู่ใน WOLD_Island.Fixed ไหม) ไม่ใช่จากชื่อหรือรูปทรง — ผู้ใช้เพิ่มของตกแต่งเองได้
-- เรื่อยๆ แค่ลากเข้าโฟลเดอร์นั้น ระบบก็กันให้เองโดยไม่ต้องแก้โค้ด
local FixedFolder
function IslandGrid.isFixedDecor(part)
	-- อ่านโฟลเดอร์ใหม่ทุกครั้งที่หายไป (กฎเหล็ก StreamingEnabled: อย่าจำ reference ไว้ตั้งแต่บูต)
	if not FixedFolder or not FixedFolder.Parent then
		local island = workspace:FindFirstChild("WOLD_Island")
		FixedFolder = island and island:FindFirstChild("Fixed")
	end
	if not FixedFolder then return false end
	return part:IsDescendantOf(FixedFolder)
end

-- มีอะไรตั้งอยู่บนช่องนี้ไหม — กล่องสูงจากผิวดินขึ้นไป ClearanceHeight
--
-- **ของตกแต่งที่ผู้ใช้ตรึงไว้ (WOLD_Island.Fixed) กันหมด ไม่สนว่าชนได้หรือไม่**
--
-- เดิมนับเฉพาะชิ้นที่ `CanCollide` ซึ่งพลาดสองเคสที่เจอจริงบนเกาะ (2026-09-22):
--   1. พุ่มหญ้า/แผ่นหญ้าที่มองเห็นแต่เดินทะลุได้ (`Tuft` `Turf` — 2,966 จาก 4,249 ชิ้นเป็นแบบนี้)
--      → ปลูกบ้านทับพุ่มหญ้าได้ ภาพทะลุกัน
--   2. **ที่ดินในกรอบกำแพงที่ผู้ใช้ล้อมไว้ไม่ให้เข้า** — ghost เดินตามเมาส์ซึ่งข้ามกำแพงไปได้
--      วางของเข้าไปได้ แต่คนเดินเข้าไปเก็บคืนไม่ได้ = ของติดอยู่ข้างในถาวร (วัดได้ 117 ช่อง)
--
-- ของในโฟลเดอร์ `Fixed` คือของที่ผู้ใช้ตั้งใจให้อยู่ตรงนั้นถาวร จึงถือว่าที่ตรงนั้นมีเจ้าของแล้วทั้งก้อน
-- ส่วนของอย่างอื่น (ตัวละคร ของที่ตกอยู่ ghost) ยังใช้กฎเดิม
--
-- **กิ่งไม้/ใบไม้เหนือหัวไม่นับ** กล่องสูงแค่ ClearanceHeight จากผิวดิน ปลูกใต้ร่มไม้จึงยังทำได้ตามเดิม
-- ghost ของไคลเอนต์ + โมเดลที่กำลังถูกย้าย · สร้างทีละตัว: `{ nil, x }` เป็นตารางมีรู Roblox จะอ่านไม่เห็น x
-- (ฝั่งเซิร์ฟเวอร์ไม่มี IslandGhost เลย ตัวแรกจึงเป็น nil เสมอ)
local function excludeList(ignore)
	local list = {}
	local ghost = workspace:FindFirstChild("IslandGhost")
	if ghost then table.insert(list, ghost) end
	if ignore then table.insert(list, ignore) end
	return list
end

function IslandGrid.obstructed(cx, cz, ignore)
	local y = IslandGrid.surfaceAt(cx, cz)
	if not y then return true end
	local wx, wz = IslandGrid.worldOf(cx, cz)
	local size = Vector3.new(Config.Cell - 0.6, Config.ClearanceHeight, Config.Cell - 0.6)
	local at = CFrame.new(wx, y + Config.ClearanceHeight / 2 - 0.4, wz)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList(ignore)
	-- **ไม่จำกัด MaxParts แล้ว** ช่องที่มีแต่ใบไม้บางๆ หกชิ้นแรกอาจเป็นใบไม้ทั้งหมด แล้วชิ้นที่กันจริง
	-- ไม่เคยถูกมองเห็น — เดิมตั้งไว้ 6 เพื่อความเร็ว แต่ตอนนี้ต้องดูให้ครบถึงจะตัดสินถูก
	params.MaxParts = 60
	for _, part in ipairs(workspace:GetPartBoundsInBox(at, size, params)) do
		if part.CanQuery then
			if IslandGrid.isFixedDecor(part) then return true end
			if part.CanCollide and part.Transparency < 1 then
				-- ตัวละครกับของที่ตกอยู่ไม่ใช่สิ่งกีดขวางถาวร
				local model = part:FindFirstAncestorOfClass("Model")
				if not (model and model:FindFirstChildOfClass("Humanoid")) then return true end
			end
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- ช่องที่เดินไปถึงได้จริง
--------------------------------------------------------------------------------

-- **วางได้ ≠ ที่ว่าง** ของที่ผู้ใช้ล้อมกำแพงไว้ไม่ให้เข้า ข้างในยังเป็นหญ้าโล่งที่ไม่มีอะไรตั้งอยู่
-- `obstructed` จึงตอบว่าว่าง และ ghost ก็วางได้ — เพราะ ghost เดินตามเมาส์ซึ่งข้ามกำแพงไปได้
-- แต่ **คนเดินเข้าไปเก็บคืนไม่ได้** ของจึงติดอยู่ข้างในถาวร (วัดบนเกาะจริง 2026-09-22: 93 ช่อง)
--
-- กฎที่ใช้: วางได้เฉพาะช่องที่ **เดินจากจุดเกิดไปถึงได้** เติมสีจากจุดเกิดทีละช่อง ข้ามช่องที่มีชิ้น
-- ชนได้ขวางเหนือระดับก้าวขึ้นไป — กำแพงสูง 19 studs จึงตัดข้างในออกจากแผนที่โดยอัตโนมัติ
-- และถ้าผู้ใช้เปิดประตูหรือรื้อกำแพงเมื่อไหร่ ข้างในก็กลับมาวางได้เองโดยไม่ต้องแก้โค้ด
--
-- **คิดครั้งเดียวแล้วเก็บไว้** ผังของตายตัวแทบไม่เปลี่ยนระหว่างเล่น และ ghost ถามทุกเฟรม —
-- คิดใหม่ทุกครั้งคือ flood fill หลายพันช่องต่อเฟรม · หมดอายุตามเวลา ไม่ใช่ตามเหตุการณ์ เพราะผู้ใช้
-- ลากของเข้าออกใน Studio ได้ตลอดโดยไม่มีสัญญาณอะไรบอก
local REACH_TTL = 10
local STEP_UP = 2.5 -- สูงกว่านี้ถือว่าปีนไม่ขึ้น (humanoid ก้าวได้ 2 studs)
local HEAD_ROOM = 3.0
local reachSet, reachAt = nil, -math.huge

-- ช่องนี้เดินผ่านได้ไหม (ไม่ใช่ "วางของได้ไหม" — ทางเดินหินกับสะพานเดินผ่านได้แต่วางของไม่ได้)
local function walkable(cx, cz, ignore)
	local y = IslandGrid.surfaceAt(cx, cz)
	if not y then return false end
	local wx, wz = IslandGrid.worldOf(cx, cz)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList(ignore)
	params.MaxParts = 40
	-- กล่องช่วงลำตัว: เหนือระดับที่ก้าวข้ามได้ ขึ้นไปถึงหัว
	local at = CFrame.new(wx, y + STEP_UP + HEAD_ROOM / 2, wz)
	for _, part in ipairs(workspace:GetPartBoundsInBox(at, Vector3.new(CELL - 0.6, HEAD_ROOM, CELL - 0.6), params)) do
		if part.CanCollide and part.CanQuery then
			local model = part:FindFirstAncestorOfClass("Model")
			if not (model and model:FindFirstChildOfClass("Humanoid")) then return false end
		end
	end
	return true
end

local function spawnCell()
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if not spawn then return nil end
	return IslandGrid.cellOf(spawn.Position.X, spawn.Position.Z)
end

local function buildReach(ignore)
	local sx, sz = spawnCell()
	if not sx then return nil end
	local seen = { [IslandGrid.key(sx, sz)] = true }
	local queue, head = { { sx, sz } }, 1
	while head <= #queue do
		local c = queue[head]; head += 1
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local nx, nz = c[1] + d[1], c[2] + d[2]
			local k = IslandGrid.key(nx, nz)
			if not seen[k] and IslandGrid.inBounds(nx, nz) and walkable(nx, nz, ignore) then
				seen[k] = true
				queue[#queue + 1] = { nx, nz }
			end
		end
	end
	return seen
end

-- เดินไปถึงช่องนี้ได้ไหม · **หาจุดเกิดไม่เจอ = ตอบว่าได้** ความไม่แน่ใจเอนไปทาง "วางได้"
-- เหมือนกฎเดียวกับปุ่มคลังเมือง: ของที่วางเกินยังเก็บคืนได้ ส่วนของที่วางไม่ได้คือปริศนา
-- ผังช่องที่เดินถึง **โดยทำเหมือนของชิ้น `ignore` ไม่อยู่** — ใช้ตอนย้าย/หมุนของที่วางแล้ว (ของขวางช่องของตัวเอง
-- เสมอ ถ้าไม่ยกออกจากการคิด การหมุนอยู่กับที่จะตอบว่า "เดินเข้าไปไม่ได้") · คิดใหม่ทุกครั้ง ~30 ms: เรียกครั้งเดียวต่อการย้าย
function IslandGrid.reachSet(ignore)
	return buildReach(ignore)
end

function IslandGrid.reachable(cx, cz, reach)
	if reach then return reach[IslandGrid.key(cx, cz)] == true end
	if os.clock() - reachAt > REACH_TTL then
		reachSet, reachAt = buildReach(), os.clock()
	end
	if not reachSet then return true end
	return reachSet[IslandGrid.key(cx, cz)] == true
end

function IslandGrid.isSoil(cx, cz)
	local _, material = IslandGrid.surfaceAt(cx, cz)
	return material == Config.SoilMaterial
end

-- occupied = { ["cx,cz"] = uid } · `itemId` บอกว่าของชิ้นนี้ต้องการดินหรือห้ามอยู่บนดิน (nil = ไม่สนใจดิน)
-- `ignore` = โมเดลที่กำลังถูกย้าย (ไม่นับเป็นสิ่งกีดขวางของตัวเอง) · `reach` = ผลของ reachSet(ignore) ที่คิดไว้แล้ว
-- (ghost ถามทุกเฟรม ส่งมาเองจะได้ไม่คิด flood fill ใหม่ทุกเฟรม · ไม่ส่งแต่มี ignore = คิดให้ครั้งเดียวต่อการเรียก)
-- ตอบ ok, reason โดย reason เป็นคำสั้นๆ ให้คนเรียกแปลเป็นข้อความเอง
function IslandGrid.canPlace(occupied, zones, x, z, w, d, r, itemId, ignore, reach)
	if ignore and not reach then reach = buildReach(ignore) or nil end
	local fw, fd = IslandGrid.footprintOf(w, d, r)
	local wantSoil = itemId ~= nil and Config.SoilOnly[itemId] == true
	local careSoil = itemId ~= nil
	local lo, hi = math.huge, -math.huge
	for i = 0, fw - 1 do
		for j = 0, fd - 1 do
			local cx, cz = x + i, z + j
			if not IslandGrid.inBounds(cx, cz) then return false, "edge" end
			if IslandGrid.blocked(cx, cz, zones) then return false, "blocked" end
			if occupied[IslandGrid.key(cx, cz)] then return false, "occupied" end
			local y, material = IslandGrid.surfaceAt(cx, cz)
			if not y then return false, "edge" end -- ไม่มีพื้นใต้ช่องนี้ = นอกเกาะ
			-- พื้นต้องเป็นหญ้า (หรือดินสำหรับแปลงผัก) — น้ำ หิน ทราย ทางเดิน วางไม่ได้ (ผู้ใช้สั่ง)
			if not Config.BuildMaterials[material] then return false, "badground" end
			lo, hi = math.min(lo, y), math.max(hi, y)
			if careSoil then
				local soil = material == Config.SoilMaterial
				if wantSoil and not soil then return false, "needsoil" end
				if not wantSoil and soil then return false, "onsoil" end
			end
			-- ช่องนี้ว่างจริงไหม: มีโมเดล/ชิ้นส่วนอะไรตั้งอยู่เหนือมันหรือเปล่า (ของที่ผู้ใช้วางไว้ในแมพ
			-- ไม่ได้อยู่ในตาราง `occupied` ซึ่งรู้จักแต่ของที่ผู้เล่นวางผ่านระบบ)
			if IslandGrid.obstructed(cx, cz, ignore) then return false, "obstructed" end
			-- ล้อมกำแพงไว้ไม่ให้เข้า = วางไม่ได้ ไม่งั้นของติดอยู่ข้างในถาวร
			if not IslandGrid.reachable(cx, cz, reach) then return false, "unreachable" end
		end
	end
	-- พื้นต้องราบพอ ไม่งั้นของไปเกาะหน้าผาแล้วจมครึ่งตัว (โมเดลวางตามความสูงกึ่งกลาง footprint จุดเดียว)
	if hi - lo > Config.MaxSlope then return false, "steep" end
	return true
end

-- กึ่งกลาง footprint ในพิกัดโลก (ต้นแบบมี pivot ที่กึ่งกลางฐาน จึงวางที่นี่ได้ตรงๆ)
function IslandGrid.centreOf(x, z, w, d, r)
	local fw, fd = IslandGrid.footprintOf(w, d, r)
	return Config.Center.X + (x + fw / 2) * CELL, Config.Center.Z + (z + fd / 2) * CELL
end

function IslandGrid.pivotFor(x, z, w, d, r, groundY)
	local wx, wz = IslandGrid.centreOf(x, z, w, d, r)
	return CFrame.new(wx, groundY, wz) * CFrame.Angles(0, r * math.pi / 2, 0)
end

-- ช่องมุมที่ทำให้กึ่งกลาง footprint อยู่ใต้ตัวชี้ (ghost ตามเมาส์ด้วยกึ่งกลาง ไม่ใช่มุม)
function IslandGrid.anchorFor(worldX, worldZ, w, d, r)
	local fw, fd = IslandGrid.footprintOf(w, d, r)
	local cx = math.floor((worldX - Config.Center.X) / CELL - fw / 2 + 0.5)
	local cz = math.floor((worldZ - Config.Center.Z) / CELL - fd / 2 + 0.5)
	return cx, cz
end

return IslandGrid
