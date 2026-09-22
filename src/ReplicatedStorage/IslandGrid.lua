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

-- occupied = { ["cx,cz"] = uid } · ตอบ ok, reason โดย reason เป็นคำสั้นๆ ให้คนเรียกแปลเป็นข้อความเอง
function IslandGrid.canPlace(occupied, zones, x, z, w, d, r)
	local fw, fd = IslandGrid.footprintOf(w, d, r)
	for i = 0, fw - 1 do
		for j = 0, fd - 1 do
			local cx, cz = x + i, z + j
			if not IslandGrid.inBounds(cx, cz) then return false, "edge" end
			if IslandGrid.blocked(cx, cz, zones) then return false, "blocked" end
			if occupied[IslandGrid.key(cx, cz)] then return false, "occupied" end
		end
	end
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
