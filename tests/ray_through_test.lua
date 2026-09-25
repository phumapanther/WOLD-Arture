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

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
