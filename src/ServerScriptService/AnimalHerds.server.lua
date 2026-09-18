-- AnimalHerds.server.lua: ทำให้สัตว์ฟาร์มอยู่กันเป็นฝูง 5-12 ตัว ฟาร์มแล้วหายไป เกิดใหม่ใน 60 วิ
--
-- **ทำตอนเซิร์ฟเวอร์รัน ไม่ใช่เฟส mapgen** เพราะ sandbox ของ Studio MCP ย้ายสคริปต์ (BeastGait และ
-- Animate ที่อยู่ในตัวสัตว์) เข้าที่ไหนไม่ได้เลย การโคลนสัตว์จากเครื่องมือจึง error ทุกครั้ง
--
-- ผลพลอยได้ที่ดีกว่า: ฝูงถูกสร้างใหม่ทุกครั้งที่เซิร์ฟเวอร์เปิด ตำแหน่งจึงไม่เหมือนเดิมเป๊ะทุกรอบ
-- และไม่มีสัตว์โคลนค้างอยู่ในไฟล์เพลสให้บวมขึ้นเรื่อยๆ
local CollectionService = game:GetService("CollectionService")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local NODE_TAG = "WOLD_Node"

-- ชนิด -> จำนวนในฝูง
local HERDS = {
	Chicken = { min = 8, max = 12 },
	Duck = { min = 6, max = 10 },
	Pig = { min = 5, max = 9 },
	Sheep = { min = 7, max = 12 },
	Goat = { min = 5, max = 9 },
	Cow = { min = 5, max = 8 },
	Horse = { min = 5, max = 8 },
	Deer = { min = 5, max = 9 },
}

-- รัศมีที่ฝูงกระจาย ผู้ใช้กำหนด 25 สตัดทุกชนิด
local SPREAD = 25

-- สัตว์ทุกตัวย่อครึ่งหนึ่ง ผู้ใช้กำหนด — ย่อที่ต้นแบบครั้งเดียว ตัวโคลนได้ขนาดตามไป
local SCALE = 0.5

local FOLDER_NAME = "WOLD_Herds"
local TEMPLATE_FOLDER = "WOLD_HerdTemplates"

local GatherConfig = require(game.ReplicatedStorage.GatherConfig)

local function folder()
	local f = workspace:FindFirstChild(FOLDER_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = workspace
	end
	return f
end

-- พื้นจริงตรงจุดนั้น
--
-- **ต้องกัน Zone_* ออก** กล่องโซนหมู่บ้านลอยอยู่เหนือพื้นราวร้อยสตัดและตอบ raycast ด้วย — บทเรียน
-- เดียวกับตอนวางบอร์ดเควส ซึ่งรอบแรกไปตั้งอยู่บนหลังคาล่องหน
local function groundAt(x, z, fromY)
	local ignore = { workspace:FindFirstChild("WOLD_Mobs"), folder() }
	for _ = 1, 8 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		params.IgnoreWater = true
		local hit = workspace:Raycast(Vector3.new(x, fromY + 200, z), Vector3.new(0, -800, 0), params)
		if not hit then return nil end
		if not hit.Instance.Name:match("^Zone_") then return hit.Position.Y end
		ignore[#ignore + 1] = hit.Instance
	end
	return nil
end

--------------------------------------------------------------------------------
-- ขนาดและท่าเดิน
--------------------------------------------------------------------------------

local function shrink(animal)
	if animal:GetAttribute("HerdScale") == SCALE then return end
	animal:ScaleTo(SCALE)
	-- ค่าที่ท่าเดินอ่านเป็นสตัด ต้องย่อตาม ไม่งั้นตัวเล็กแต่ลอยสูงเท่าเดิม
	animal:SetAttribute("BaseHipHeight", (animal:GetAttribute("BaseHipHeight") or 2) * SCALE)
	animal:SetAttribute("Bob", (animal:GetAttribute("Bob") or 0.12) * SCALE)
	animal:SetAttribute("HerdScale", SCALE)
end

-- ท่าเดินคิดจากโค้ดเหมือน BeastGait ที่ติดมากับโมเดล แต่เขียนลง **C0 ไม่ใช่ Transform**
--
-- BeastGait ในโมเดลรันบนเซิร์ฟเวอร์และเขียน Motor6D.Transform ซึ่ง**ไม่ส่งไปไคลเอนต์** — ใน Studio
-- เห็นขาขยับเพราะอยู่โปรเซสเดียวกัน แต่ในเกมจริงสัตว์ทุกตัวยืนแข็งทั้งที่เดินอยู่ ("สัตว์ไม่ขยับขา")
-- C0 ส่งไปไคลเอนต์ปกติ บทเรียนเดียวกับขาแมงมุมใน MobMotion
--
-- จึงปิด BeastGait แล้วทำเองที่นี่ทั้งท่าเดินและการเดินเล่น อ่านแอตทริบิวต์ชุดเดียวกับที่โมเดลมีอยู่แล้ว
-- (Phase/Swing/Fold/Axis/Idle บนข้อต่อ · WalkSpeed/WanderRadius/WanderMin/WanderMax/StrideRate/Bob บนตัว)
local Gaits = {} -- [model] = { humanoid, root, joints, phase, rate, bob, hip }

local function axisCF(axis, a)
	if axis == "Y" then return CFrame.Angles(0, a, 0) end
	if axis == "Z" then return CFrame.Angles(0, 0, a) end
	return CFrame.Angles(a, 0, 0)
end

local function animate(animal)
	if Gaits[animal] then return end
	local humanoid = animal:FindFirstChildOfClass("Humanoid")
	local root = animal:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end

	local gait = animal:FindFirstChild("BeastGait", true)
	if gait and gait:IsA("BaseScript") then gait.Enabled = false end

	local joints = {}
	for _, d in ipairs(animal:GetDescendants()) do
		if d:IsA("Motor6D") and d:GetAttribute("Phase") then
			joints[#joints + 1] = { j = d, rest = d.C0 }
		end
	end
	humanoid.WalkSpeed = animal:GetAttribute("WalkSpeed") or humanoid.WalkSpeed
	Gaits[animal] = {
		humanoid = humanoid, root = root, joints = joints, phase = math.random() * math.pi * 2,
		-- ขาสั้นลงครึ่งหนึ่งต้องก้าวถี่ขึ้นเท่าตัวถึงจะดูเดินด้วยความเร็วเดิม
		rate = (animal:GetAttribute("StrideRate") or 0.55) / SCALE,
		bob = animal:GetAttribute("Bob") or 0.06,
		hip = animal:GetAttribute("BaseHipHeight") or humanoid.HipHeight,
	}

	-- เดินเล่นรอบบ้าน บ้าน = จุดที่ยืนอยู่ตอนเริ่ม
	local radius = animal:GetAttribute("WanderRadius") or 0
	if radius > 0 then
		local home = root.Position
		task.spawn(function()
			while animal.Parent and humanoid.Health > 0 do
				task.wait(math.random(animal:GetAttribute("WanderMin") or 4, animal:GetAttribute("WanderMax") or 9))
				local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * radius
				humanoid:MoveTo(home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
				humanoid.MoveToFinished:Wait()
			end
		end)
	end
end

game:GetService("RunService").Heartbeat:Connect(function(dt)
	for animal, g in pairs(Gaits) do
		if not animal.Parent then
			Gaits[animal] = nil
		else
			local vel = g.root.AssemblyLinearVelocity
			local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
			-- ยืนนิ่งก็ยังขยับช้าๆ คือการหายใจ
			g.phase += dt * (speed > 0.4 and speed * g.rate + 1 or 1.1)
			local drive = math.clamp(speed / 8, 0, 1)
			for _, e in ipairs(g.joints) do
				local j = e.j
				local amp = (j:GetAttribute("Swing") or 0) * drive + (j:GetAttribute("Idle") or 0) * (1 - drive)
				local s = math.sin(g.phase + (j:GetAttribute("Phase") or 0))
				local a = s * amp
				local fold = j:GetAttribute("Fold")
				if fold then a += math.max(0, -s) * fold * drive end
				j.C0 = e.rest * axisCF(j:GetAttribute("Axis") or "X", a)
			end
			g.humanoid.HipHeight = g.hip + math.sin(g.phase * 2) * g.bob * drive
		end
	end
end)

-- สัตว์ที่ยืนอยู่ในโลกตอนนี้ของชนิดนั้น (เฉพาะในโฟลเดอร์ฝูง ต้นแบบย้ายออกไปแล้ว)
local function liveHerd(kind)
	local found = {}
	for _, a in ipairs(folder():GetChildren()) do
		if a:GetAttribute("NodeKind") == kind then found[#found + 1] = a end
	end
	return found
end

-- ต้นแบบที่ผู้ใช้วางไว้ ยังอยู่ใน workspace (ยังไม่ได้ย้ายเป็นแม่พิมพ์)
local function prototypeOf(kind)
	for _, n in ipairs(CollectionService:GetTagged(NODE_TAG)) do
		if n:GetAttribute("NodeKind") == kind and n:IsDescendantOf(workspace) and not n:IsDescendantOf(folder()) then
			return n
		end
	end
	return nil
end

local Templates = {} -- [kind] = โมเดลแม่พิมพ์ใน ServerStorage
local Wanted = {}    -- [kind] = จำนวนที่ฝูงนี้ควรมี

-- วางสัตว์หนึ่งตัวจากแม่พิมพ์ลงรอบบ้านของฝูง
local function spawnOne(kind)
	local template = Templates[kind]
	if not template then return false end
	local origin = template:GetAttribute("HerdHome")
	if not origin then return false end

	for _ = 1, 12 do
		local angle = math.random() * math.pi * 2
		-- sqrt กระจายทั่วพื้นที่ ไม่กระจุกตรงกลาง
		local dist = math.sqrt(math.random()) * SPREAD
		local x = origin.X + math.cos(angle) * dist
		local z = origin.Z + math.sin(angle) * dist
		local y = groundAt(x, z, origin.Y)

		-- ระดับใกล้เคียงต้นแบบเท่านั้น กันไม่ให้ไปโผล่ก้นหุบเขาหรือบนหลังคา
		if y and math.abs(y - origin.Y) < 25 then
			local clone = template:Clone()
			-- หันคนละทาง ฝูงจะได้ไม่ดูเหมือนแถวทหาร
			clone:PivotTo(CFrame.new(Vector3.new(x, y, z))
				* CFrame.Angles(0, math.random() * math.pi * 2, 0))
			clone:SetAttribute("Spent", nil)
			-- ป้ายบอก Gathering ว่าตัวนี้เก็บแล้วหายไป (แล้วฝูงเติมตัวใหม่ให้เอง) และบอกไคลเอนต์ว่า
			-- ฟาร์มออโต้มือเปล่าเล็งตัวนี้ได้
			clone:SetAttribute("HerdAnimal", true)
			clone.Parent = folder()
			animate(clone)
			return true
		end
	end
	return false
end

-- ตั้งฝูงของชนิดนี้ครั้งแรก: เอาต้นแบบไปเป็นแม่พิมพ์ แล้ววางฝูงเต็มจำนวน
--
-- **ต้นแบบย้ายออกจากโลกไปเป็นแม่พิมพ์ใน ServerStorage** สัตว์ที่เห็นทุกตัวจึงเป็นตัวโคลนที่ลบทิ้งได้
-- ตอนถูกฟาร์ม — ถ้าต้นแบบยังยืนอยู่ในฝูง มันจะเป็นตัวเดียวที่ฟาร์มแล้วไม่หาย และเป็นตัวที่ลบไม่ได้
-- เพราะฝูงต้องใช้มันโคลน
local function setup(kind, spec)
	local proto = prototypeOf(kind)
	if not proto then return 0 end

	shrink(proto)
	local stale = proto:FindFirstChild("GatherAnchor")
	if stale then stale:Destroy() end
	proto:SetAttribute("HerdHome", proto:GetPivot().Position)
	proto:SetAttribute("Spent", nil)

	local store = game.ServerStorage:FindFirstChild(TEMPLATE_FOLDER)
	if not store then
		store = Instance.new("Folder")
		store.Name = TEMPLATE_FOLDER
		store.Parent = game.ServerStorage
	end
	proto.Parent = store
	Templates[kind] = proto

	Wanted[kind] = math.random(spec.min, spec.max)
	local made = 0
	for _ = 1, Wanted[kind] do
		if spawnOne(kind) then made += 1 else break end
	end
	return made
end

-- ตัวที่หายไป (ถูกฟาร์ม) เกิดใหม่หลังครบเวลาเดียวกับจุดเก็บของอื่น
local function watchRespawns()
	folder().ChildRemoved:Connect(function(child)
		local kind = child:GetAttribute("NodeKind")
		if not kind or not Templates[kind] then return end
		task.delay(GatherConfig.RespawnSeconds, function()
			if #liveHerd(kind) < (Wanted[kind] or 0) then spawnOne(kind) end
		end)
	end)
end

--------------------------------------------------------------------------------

-- รอให้สัตว์ต้นแบบมาถึงก่อน
--
-- **ลูปถามใหม่ ไม่ใช่ทำครั้งเดียวตอนบูต** กฎเหล็กของโปรเจ็ค: เพลสเปิด StreamingEnabled โมเดลกับแท็ก
-- มาถึงคนละรอบ ทำครั้งเดียวตอนเริ่มจะเจอสัตว์ไม่ครบ และเป็นคนละชนิดทุกครั้งที่เปิดเซิร์ฟ
task.spawn(function()
	watchRespawns()
	local done = {}
	for _ = 1, 60 do
		task.wait(0.5)
		local remaining = 0
		for kind, spec in pairs(HERDS) do
			if not done[kind] then
				if prototypeOf(kind) then
					local made = setup(kind, spec)
					done[kind] = true
					if made > 0 then
						print(("[Herds] %s %d ตัว"):format(kind, made))
					end
				else
					remaining += 1
				end
			end
		end
		if remaining == 0 then return end
	end
end)
