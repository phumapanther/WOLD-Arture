-- node tools/lua.js tests/ray_through_test.lua Edit
-- สไนทะลุเพื่อน/ศพ (รีวิวจบงาน 2026-09-25): เพื่อนยืนขวางแนวยิง กระสุนต้องทะลุไปโดนศัตรูข้างหลัง
-- วางหุ่นสองตัวไว้สูงลิบเหนือแมพ (y 5000) ยิงตรงลงแนว -Z แล้วเก็บกวาดทุกครั้ง
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local RayThrough = fresh(game.ReplicatedStorage.RayThrough)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local root = Instance.new("Folder")
root.Name = "RayThroughTest"
root.Parent = workspace
local function dummy(name, z)
	local m = Instance.new("Model")
	m.Name = name
	Instance.new("Humanoid").Parent = m
	local p = Instance.new("Part")
	p.Anchored, p.Size, p.Position = true, Vector3.new(4, 4, 1), Vector3.new(0, 5000, z)
	p.Parent = m
	m.Parent = root
	return m
end
local friend = dummy("Friend", -10)
local enemy = dummy("Enemy", -20)

local function params()
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = {}
	return p
end
local origin, dir = Vector3.new(0, 5000, 0), Vector3.new(0, 0, -40)
local skipFriend = function(part) return part.Parent == friend and friend or nil end

local ok, err = pcall(function()
	local plain = RayThrough.Cast(origin, dir, params(), function() return nil end)
	check(plain and plain.Instance.Parent == friend, "ไม่ข้ามอะไร = ชนเพื่อนก่อน")
	local through = RayThrough.Cast(origin, dir, params(), skipFriend)
	check(through and through.Instance.Parent == enemy, "ข้ามเพื่อน = ทะลุไปโดนศัตรู")
	enemy:Destroy()
	local miss = RayThrough.Cast(origin, dir, params(), skipFriend)
	check(miss == nil, "ข้ามเพื่อนแล้วไม่มีอะไรข้างหลัง = ไม่โดน")
end)
root:Destroy()
if not ok then error(err) end

-- สไนเฉียดเป้า (QA 2026-09-26): ตำแหน่งมอนบนจอผู้ยิงช้ากว่าเซิร์ฟ ~1-3 สตัด → นับโดนถ้าอยู่ใกล้แนวยิง
check(type(RayThrough.NearestNear) == "function", "มีฟังก์ชัน NearestNear")
if type(RayThrough.NearestNear) == "function" then
	local o, u = Vector3.zero, Vector3.new(0, 0, -1)
	local near = { model = "A", position = Vector3.new(2, 0, -100) }
	local far = { model = "B", position = Vector3.new(1, 0, -300) }
	check(RayThrough.NearestNear(o, u, 500, { far, near }, 3) == near, "เฉียด: เลือกตัวที่ใกล้ตามแนวยิงก่อน")
	check(RayThrough.NearestNear(o, u, 200, { far }, 3) == nil, "เฉียด: เลยจุดที่กระสุนหยุด (กำแพง) = ไม่นับ")
	check(RayThrough.NearestNear(o, u, 500, { { model = "C", position = Vector3.new(6, 0, -50) } }, 3) == nil,
		"เฉียด: ห่างแนวยิงเกินรัศมี = ไม่นับ")
	check(RayThrough.NearestNear(o, u, 500, { { model = "D", position = Vector3.new(6, 0, -50), pad = 4 } }, 3) ~= nil,
		"เฉียด: บอสตัวใหญ่ (pad) นับระยะเผื่อเพิ่ม")
	check(RayThrough.NearestNear(o, u, 500, { { model = "E", position = Vector3.new(0, 0, 20) } }, 3) == nil,
		"เฉียด: อยู่ข้างหลังผู้ยิง = ไม่นับ")
	-- ตรวจเพิ่มหลังรีวิว: ตัวที่ใกล้สุดถูกปฏิเสธ (เพื่อน/ศพ/มองไม่เห็น) ต้องได้ตัวถัดไป ไม่ใช่เสียนัดทิ้ง
	local behind = { model = "F", position = Vector3.new(1, 0, -200) }
	local blocked = { model = "G", position = Vector3.new(1, 0, -100) }
	check(RayThrough.NearestNear(o, u, 500, { blocked, behind }, 3, function(c) return c ~= blocked end) == behind,
		"เฉียด: ตัวใกล้สุดถูกปฏิเสธ = ได้ตัวถัดไปตามแนวยิง")
	check(RayThrough.NearestNear(o, u, 500, { blocked }, 3, function() return false end) == nil,
		"เฉียด: ถูกปฏิเสธทุกตัว = ไม่โดน")
end

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
