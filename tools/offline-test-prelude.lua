-- offline-test-prelude.lua: ตัวจำลอง Roblox ขนาดเล็กสำหรับ tools/offline-test.js (อ่านหัวไฟล์นั้นก่อน)
-- จำลองเท่าที่เทสข้อมูลล้วนใช้ · ขาดอะไรเติมตรงนี้ · **ไม่ใช่ Roblox จริง** ผลที่ต่างจาก Studio = สงสัยไฟล์นี้ก่อน

--------------------------------------------------------------------------------
-- Vector3 / Vector2
--------------------------------------------------------------------------------
local V = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end
V.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then return vec(0 / 0, 0 / 0, 0 / 0) end
		return vec(v.X / m, v.Y / m, v.Z / m)
	end
	return rawget(V, k)
end
function V.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V.Cross(a, b) return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V.Lerp(a, b, t) return vec(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end
function V.FuzzyEq(a, b, eps) eps = eps or 1e-5 return (a - b).Magnitude <= eps end
V.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__mul = function(a, b)
	if type(a) == "number" then return vec(b.X * a, b.Y * a, b.Z * a) end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V.__div = function(a, b)
	if type(b) == "number" then return vec(a.X / b, a.Y / b, a.Z / b) end
	return vec(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
V.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V.__tostring = function(v) return ("%g, %g, %g"):format(v.X, v.Y, v.Z) end
V.__type = "Vector3"
Vector3 = { new = vec }
Vector3.zero, Vector3.one = vec(0, 0, 0), vec(1, 1, 1)
Vector3.xAxis, Vector3.yAxis, Vector3.zAxis = vec(1, 0, 0), vec(0, 1, 0), vec(0, 0, 1)
local V2 = {}
local function vec2(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end
V2.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y) return vec2(v.X / m, v.Y / m) end
	return rawget(V2, k)
end
V2.__add = function(a, b) return vec2(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return vec2(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b)
	if type(a) == "number" then return vec2(b.X * a, b.Y * a) end
	if type(b) == "number" then return vec2(a.X * b, a.Y * b) end
	return vec2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b) if type(b) == "number" then return vec2(a.X / b, a.Y / b) end return vec2(a.X / b.X, a.Y / b.Y) end
V2.__unm = function(a) return vec2(-a.X, -a.Y) end
V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
function V2.Dot(a, b) return a.X * b.X + a.Y * b.Y end
function V2.Lerp(a, b, t) return vec2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end
Vector2 = { new = vec2 }
Vector2.zero, Vector2.one = vec2(0, 0), vec2(1, 1)

-- Random.new(seed): ตัวสุ่มกำหนดผลได้ (LCG) — ไม่ใช่อัลกอริทึมเดียวกับ Roblox ตัวเลขจึงต่างกัน แต่กำหนดผลได้เหมือนกัน
local R = {}
R.__index = R
function R:_next()
	self.s = (self.s * 1103515245 + 12345) % 2147483648
	return self.s / 2147483648
end
function R:NextNumber(lo, hi)
	local x = self:_next()
	if lo then return lo + (hi - lo) * x end
	return x
end
function R:NextInteger(lo, hi) return lo + math.floor(self:_next() * (hi - lo + 1)) end
function R:Shuffle(t) for i = #t, 2, -1 do local j = self:NextInteger(1, i) t[i], t[j] = t[j], t[i] end end
function R:Clone() return setmetatable({ s = self.s }, R) end
Random = { new = function(seed) return setmetatable({ s = math.floor(math.abs(seed or os.time())) % 2147483648 }, R) end }

--------------------------------------------------------------------------------
-- CFrame (แค่การเลื่อนตำแหน่ง — การหมุนถูกทิ้ง พอสำหรับคอนฟิกที่แค่สร้างค่า)
--------------------------------------------------------------------------------
local CF = {}
local function cf(pos) return setmetatable({ Position = pos or vec(0, 0, 0) }, CF) end
CF.__index = function(c, k)
	if k == "LookVector" then return vec(0, 0, -1) end
	if k == "UpVector" then return vec(0, 1, 0) end
	if k == "RightVector" then return vec(1, 0, 0) end
	if k == "X" then return c.Position.X elseif k == "Y" then return c.Position.Y elseif k == "Z" then return c.Position.Z end
	return rawget(CF, k)
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then return cf(a.Position + b.Position) end
	return a.Position + b
end
CF.__add = function(a, b) return cf(a.Position + b) end
CF.__sub = function(a, b) return cf(a.Position - b) end
function CF.Inverse(c) return cf(-c.Position) end
function CF.Lerp(a, b, t) return cf(a.Position:Lerp(b.Position, t)) end
function CF.ToWorldSpace(a, b) return a * b end
CFrame = {
	new = function(x, y, z) if type(x) == "table" then return cf(x) end return cf(vec(x, y, z)) end,
	Angles = function() return cf() end,
	fromEulerAnglesXYZ = function() return cf() end,
	fromEulerAnglesYXZ = function() return cf() end,
	fromAxisAngle = function() return cf() end,
	fromMatrix = function(p) return cf(p) end,
	lookAt = function(p) return cf(p) end,
	identity = cf(),
}

--------------------------------------------------------------------------------
-- ค่าอื่นๆ ที่คอนฟิกแค่สร้าง
--------------------------------------------------------------------------------
local C3 = {}
C3.__index = C3
C3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
local function c3(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end
function C3.Lerp(a, b, t) return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
function C3.ToHex(c) return ("%02X%02X%02X"):format(c.R * 255, c.G * 255, c.B * 255) end
Color3 = {
	new = c3,
	fromRGB = function(r, g, b) return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end,
	fromHSV = function(h, s, v) return c3(v, v, v) end,
	fromHex = function() return c3(1, 1, 1) end,
}
local function plain(kind) return { new = function(...) return { __kind = kind, ... } end } end
ColorSequence, NumberSequence = plain("ColorSequence"), plain("NumberSequence")
ColorSequenceKeypoint, NumberSequenceKeypoint = plain("ColorSequenceKeypoint"), plain("NumberSequenceKeypoint")
NumberRange, TweenInfo, Rect, UDim = plain("NumberRange"), plain("TweenInfo"), plain("Rect"), plain("UDim")
BrickColor = plain("BrickColor")
UDim2 = { new = function(...) return { ... } end, fromOffset = function(x, y) return { 0, x, 0, y } end,
	fromScale = function(x, y) return { x, 0, y, 0 } end }
PhysicalProperties = plain("PhysicalProperties")
DateTime = { now = function() return { UnixTimestamp = os.time(), UnixTimestampMillis = os.time() * 1000 } end }

local enumCache = {}
Enum = setmetatable({}, { __index = function(_, group)
	enumCache[group] = enumCache[group] or setmetatable({}, { __index = function(t, name)
		local item = { Name = name, EnumType = group }
		rawset(t, name, item)
		return item
	end })
	return enumCache[group]
end })

task = {
	wait = function() return 0 end, spawn = function(f, ...) return f(...) end,
	defer = function(f, ...) return f(...) end, delay = function() end,
}
warn = function(...) print("WARN", ...) end
tick = os.clock
typeof = function(v)
	local mt = getmetatable(v)
	if mt == V then return "Vector3" elseif mt == CF then return "CFrame" elseif mt == C3 then return "Color3" end
	if type(v) == "table" and rawget(v, "__isInstance") then return "Instance" end
	return type(v)
end

--------------------------------------------------------------------------------
-- instance tree
--------------------------------------------------------------------------------
local Inst = {}
local Methods = {}
local parts = {} -- Part ที่อยู่ใต้ workspace (เรย์ชนได้)

local function newInstance(className, name)
	local o = { __isInstance = true, __props = { ClassName = className, Name = name or className }, __children = {}, __attrs = {} }
	return setmetatable(o, Inst)
end

Inst.__index = function(o, k)
	local props = rawget(o, "__props")
	if k == "CFrame" and props.Position then return CFrame.new(props.Position) end
	local v = props[k]
	if v ~= nil then return v end
	if Methods[k] then return Methods[k] end
	for _, child in ipairs(rawget(o, "__children")) do
		if child.Name == k then return child end
	end
	return nil
end
Inst.__newindex = function(o, k, v)
	if k == "Parent" then
		local old = o.__props.Parent
		if old then
			local list = rawget(old, "__children")
			for i, c in ipairs(list) do if c == o then table.remove(list, i) break end end
		end
		o.__props.Parent = v
		if v then table.insert(rawget(v, "__children"), o) end
		return
	end
	if k == "CFrame" then o.__props.Position = v.Position return end
	o.__props[k] = v
end
Inst.__tostring = function(o) return o.__props.Name end

function Methods.IsA(o, class) return o.ClassName == class or (class == "BasePart" and (o.ClassName == "Part")) or class == "Instance" end
function Methods.GetChildren(o) return table.clone(rawget(o, "__children")) end
function Methods.GetDescendants(o)
	local out = {}
	local function walk(x) for _, c in ipairs(rawget(x, "__children")) do out[#out + 1] = c walk(c) end end
	walk(o)
	return out
end
function Methods.FindFirstChild(o, name)
	for _, c in ipairs(rawget(o, "__children")) do if c.Name == name then return c end end
	return nil
end
Methods.WaitForChild = Methods.FindFirstChild
function Methods.FindFirstChildOfClass(o, class)
	for _, c in ipairs(rawget(o, "__children")) do if c.ClassName == class then return c end end
	return nil
end
function Methods.IsDescendantOf(o, anc)
	local p = o.Parent
	while p do if p == anc then return true end p = p.Parent end
	return false
end
function Methods.GetAttribute(o, k) return rawget(o, "__attrs")[k] end
function Methods.SetAttribute(o, k, v) rawget(o, "__attrs")[k] = v end
function Methods.GetAttributes(o) return table.clone(rawget(o, "__attrs")) end
function Methods.Destroy(o) o.Parent = nil end
function Methods.Clone(o)
	local copy = newInstance(o.ClassName, o.Name)
	for k, v in pairs(o.__props) do if k ~= "Parent" then copy.__props[k] = v end end
	for k, v in pairs(rawget(o, "__attrs")) do rawget(copy, "__attrs")[k] = v end
	for _, c in ipairs(rawget(o, "__children")) do Methods.Clone(c).Parent = copy end
	return copy
end
function Methods.GetFullName(o)
	local names, p = {}, o
	while p do table.insert(names, 1, p.Name) p = p.Parent end
	return table.concat(names, ".")
end

-- require: ประเมินซอร์สใหม่ต่อ ModuleScript หนึ่งตัว (สำเนาที่โคลน = ประเมินใหม่ เหมือน Studio)
local required = setmetatable({}, { __mode = "k" })
require = function(mod)
	if type(mod) ~= "table" or not rawget(mod, "__isInstance") then error("require: ไม่ใช่ ModuleScript (" .. tostring(mod) .. ")") end
	if required[mod] ~= nil then return required[mod] end
	local src = mod.__props.__source
	if not src then error("require: " .. mod.Name .. " ไม่มีซอร์ส") end
	local chunk, err = loadstring("local script = ...\n" .. src, "=" .. mod:GetFullName())
	if not chunk then error(err) end
	local result = chunk(mod)
	required[mod] = result
	return result
end

--------------------------------------------------------------------------------
-- บริการ
--------------------------------------------------------------------------------
local stubMeta = { __index = function(t, k)
	local f = function() return nil end
	rawset(t, k, f)
	return f
end }
local services = {}
game = newInstance("DataModel", "game")
local function service(name, class)
	local s = newInstance(class or name, name)
	s.Parent = game
	services[name] = s
	return s
end
service("ReplicatedStorage")
service("ServerScriptService")
service("ServerStorage")
workspace = service("Workspace")
services.Workspace = workspace
local terrain = newInstance("Terrain", "Terrain")
terrain.Parent = workspace
function Methods.GetServerTimeNow() return os.time() end

local RunService = setmetatable({ IsStudio = function() return true end, IsServer = function() return true end,
	IsClient = function() return false end }, stubMeta)
local Players = setmetatable({ GetPlayers = function() return {} end }, stubMeta)
local CollectionService = setmetatable({ GetTagged = function() return {} end }, stubMeta)
function Methods.GetService(_, name)
	if services[name] then return services[name] end
	if name == "RunService" then return RunService end
	if name == "Players" then return Players end
	if name == "CollectionService" then return CollectionService end
	return setmetatable({}, stubMeta)
end

Instance = { new = function(class, parent)
	local o = newInstance(class)
	if class == "Part" then
		o.__props.Size = vec(4, 1, 2)
		o.__props.Position = vec(0, 0, 0)
		parts[o] = true
	end
	if parent then o.Parent = parent end
	return o
end }

RaycastParams = { new = function() return { FilterType = Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {},
	RespectCanCollide = false, IgnoreWater = false } end }
OverlapParams = RaycastParams

-- เรย์ชนกล่องแนวแกนของ Part ที่อยู่ใต้ workspace (ไม่หมุน)
function Methods.Raycast(_, origin, dir, params)
	local list = params and params.FilterDescendantsInstances or {}
	local function listed(p)
		for _, x in ipairs(list) do if x == p or p:IsDescendantOf(x) then return true end end
		return false
	end
	local include = params and params.FilterType == Enum.RaycastFilterType.Include
	local best, bestT, bestN
	for p in pairs(parts) do
		if p:IsDescendantOf(workspace) and (include == listed(p)) then
			local lo, hi = p.Position - p.Size / 2, p.Position + p.Size / 2
			local tmin, tmax, normal = 0, 1, nil
			local ok = true
			for _, axis in ipairs({ "X", "Y", "Z" }) do
				local o, d = origin[axis], dir[axis]
				if math.abs(d) < 1e-12 then
					if o < lo[axis] or o > hi[axis] then ok = false break end
				else
					local t1, t2 = (lo[axis] - o) / d, (hi[axis] - o) / d
					local n = vec(axis == "X" and -1 or 0, axis == "Y" and -1 or 0, axis == "Z" and -1 or 0)
					if t1 > t2 then t1, t2 = t2, t1 n = -n end
					if t1 > tmin then tmin, normal = t1, n end
					tmax = math.min(tmax, t2)
					if tmin > tmax then ok = false break end
				end
			end
			if ok and normal and (not bestT or tmin < bestT) then best, bestT, bestN = p, tmin, normal end
		end
	end
	if not best then return nil end
	return { Instance = best, Position = origin + dir * bestT, Normal = bestN, Distance = dir.Magnitude * bestT,
		Material = Enum.Material.Plastic }
end

--------------------------------------------------------------------------------
-- ตัวโหลดไฟล์ + ตัวรันเทส (เรียกจากบันเดิลที่ offline-test.js สร้าง)
--------------------------------------------------------------------------------
function __define(serviceName, pathList, source)
	local parent = services[serviceName]
	for i = 1, #pathList - 1 do
		local folder = parent:FindFirstChild(pathList[i])
		if not folder then
			folder = newInstance("Folder", pathList[i])
			folder.Parent = parent
		end
		parent = folder
	end
	local mod = newInstance("ModuleScript", pathList[#pathList])
	mod.__props.__source = source
	mod.Parent = parent
end

function __runTest(source, name)
	local chunk, err = loadstring(source, "=" .. name)
	if not chunk then print("ERROR " .. tostring(err)) return end
	local ok, result = pcall(chunk)
	print(ok and tostring(result) or ("ERROR " .. tostring(result)))
end
