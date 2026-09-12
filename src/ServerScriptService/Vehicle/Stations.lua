-- Vehicle/Stations — จุดเรียกพาหนะสามจุด และปุ่มคุยกับบารอนเวน
--
-- ต่างจากโปรเจ็คต้นทางสองข้อ:
--
--   1. **ไม่ปั้นหุ่น NPC เอง** ต้นทางสร้างหุ่นพาร์ทไว้ทุกจุด เพราะเพลสทดสอบไม่มีใครอยู่เลย ที่นี่ NPC คือ
--      บารอนเวนตัวจริงที่ผู้ใช้วางไว้ในแมพ หาได้จากแท็ก WOLD_Npc + NpcKind = "vehicle" เหมือนที่ร้านค้ากับ
--      ช่างตีเหล็กหาคนของตัวเอง แต่ละจุดจึงเหลือแค่ "แท่นเรียก" กับ "ลานจอด"
--
--   2. **หาผิวจริงก่อนวางเสมอ** พิกัดใน Config เป็นค่าตั้งต้นที่อ่านมาจาก world-layout.json ซึ่งเป็นเส้น
--      อุดมคติ ไม่ใช่ภูมิประเทศที่เจนออกมาจริง บทเรียนจากต้นทาง (CLAUDE.md ของ WOLD-Vehicle) ตรงนี้แพงมาก:
--      ลานจอดยอดเขาเคยจมหินอยู่ 3 studs จนเรือเหาะไปเกยแล้วขับไม่ออก โดยที่ทุกอย่างอื่นทำงานถูกหมด
--
--      "ground" ยิงเรย์ลงตรงๆ · "shore" เดินออกจากใจกลางแมพจนพ้นแนวน้ำ · "peak" หาจุดสูงสุดในรัศมี
local CollectionService = game:GetService("CollectionService")

local K = require(game.ServerScriptService.Vehicle.Kit)
local Config = require(game.ReplicatedStorage.Vehicle.Config)

local MAT = Enum.Material
local Stations = {}
Stations.List = {}

-- ระดับน้ำทะเลของแมพ mapgen เติมน้ำจาก seabed ขึ้นมาถึง y = 0 พอดี (ดู L.seaSlab) ตั้ง Attribute ทับได้ถ้า
-- วันหนึ่งระดับน้ำเปลี่ยน
local function seaLevel()
	local set = workspace:GetAttribute("WaterLevel")
	return type(set) == "number" and set or 0
end

local function folder()
	local f = workspace:FindFirstChild(Config.StationFolder)
	if f then f:Destroy() end
	f = Instance.new("Folder")
	f.Name = Config.StationFolder
	f.Parent = workspace
	return f
end

--------------------------------------------------------------------------------
-- หาที่วางจริง
--------------------------------------------------------------------------------

-- ผิวดินจริงที่พิกัดนี้ (มองข้ามน้ำ และมองข้ามของที่ระบบพาหนะวางเอง) คืน nil ถ้าไม่เจออะไรเลย
local function groundAt(x, z, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(x, 3000, z), Vector3.new(0, -6000, 0), params)
	return hit and hit.Position.Y or nil
end

-- ริมฝั่ง: เดินออกจากใจกลางแมพไปทีละก้าว จนพื้นต่ำกว่าระดับน้ำ นั่นคือแนวชายฝั่ง
--
-- เดินออกจาก "ใจกลางแมพ" เพราะแผ่นดินของโลกนี้เป็นเกาะกลม การเดินออกจากศูนย์กลางจึงชนทะเลเสมอ ไม่ว่าพิกัด
-- ตั้งต้นจะคลาดไปทางไหน คืนค่าเป็นจุดบนบกจุดสุดท้าย กับจุดในน้ำจุดแรก
local function findShore(from, toward, range, ignore)
	local direction = (toward - from)
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 1 then return nil end
	direction = direction.Unit

	local water = seaLevel()
	local step = 20
	local lastLand = nil

	-- เริ่มจากจุดตั้งต้นแล้วเดินออก ถ้าจุดตั้งต้นอยู่ในน้ำอยู่แล้วก็ถอยเข้าหาฝั่งก่อน
	local start = toward
	local startGround = groundAt(start.X, start.Z, ignore)
	if startGround and startGround < water then
		for back = step, range, step do
			local p = start - direction * back
			local y = groundAt(p.X, p.Z, ignore)
			if y and y >= water then
				start = p
				break
			end
		end
	end

	for out = 0, range, step do
		local p = start + direction * out
		local y = groundAt(p.X, p.Z, ignore)
		if y then
			if y < water then
				-- จุดในน้ำจุดแรก กับพื้นดินจุดสุดท้ายก่อนหน้า
				return lastLand or Vector3.new(p.X, water, p.Z), Vector3.new(p.X, water, p.Z), direction
			end
			lastLand = Vector3.new(p.X, y, p.Z)
		end
	end
	return lastLand, nil, direction
end

-- ยอดเขา: จุดที่สูงที่สุดในตารางรอบพิกัดตั้งต้น ไม่เชื่อพิกัดยอดเขาในไฟล์ layout เพราะภูเขาสร้างจากทรงกระบอก
-- ซ้อนกัน ผิวจริงจึงยื่นออกมากกว่าเส้นกรวยอุดมคติเสมอ
local function findPeak(center, range, ignore)
	local best, bestY = nil, -math.huge
	local step = math.max(20, range / 12)
	for dx = -range, range, step do
		for dz = -range, range, step do
			local x, z = center.X + dx, center.Z + dz
			local y = groundAt(x, z, ignore)
			if y and y > bestY then
				best, bestY = Vector3.new(x, y, z), y
			end
		end
	end
	return best
end

--------------------------------------------------------------------------------
-- ของที่วาง
--------------------------------------------------------------------------------

-- แท่นเรียกพาหนะ: เสาทองเหลือง หน้าปัดวัดแรงดัน คันโยก ป้ายชื่อจุด
-- ทั้งแท่งชนอะไรไม่ได้เลยนอกจากฐาน — ของประดับข้างลานจอดที่ชนได้ = พาหนะที่เพิ่งเรียกออกมาติดคาที่
local function callPost(parent, cf, title)
	local C = K.C
	local m = K.model(parent, "CallPost")
	K.cyl(m, cf * CFrame.new(0, 0.3, 0), 1.5, 0.6, MAT.Slate, C.darkStone, { name = "Base" })
	K.cyl(m, cf * CFrame.new(0, 2.2, 0), 0.55, 3.4, MAT.Metal, C.brassDark, { name = "Column" })
	K.band(m, cf * CFrame.new(0, 3.4, 0), 0.62, 0.2)
	K.box(m, cf * CFrame.new(0, 4.3, 0), Vector3.new(2.2, 1.6, 1), MAT.Metal, C.brass, { name = "Head" })
	K.gauge(m, cf * CFrame.new(0, 4.3, -0.55) * K.yaw(math.pi / 2), 0.5, C.brassDark)
	K.rod(m, (cf * CFrame.new(0.9, 4.3, 0)).Position, (cf * CFrame.new(1.7, 5.1, 0)).Position, 0.12, MAT.Metal, C.iron, { cancollide = false })
	K.ball(m, cf * CFrame.new(1.7, 5.1, 0), 0.45, MAT.Metal, C.copper, { cancollide = false })
	K.sign(m, cf * CFrame.new(0, 6.2, 0), title, 5, 1.4, C.wood, C.brass)
	K.lantern(m, cf * CFrame.new(-1.9, 0.6, 0), 1.2, C.lamp)
	return m
end

-- ลานจอด: ผิวบนของลานอยู่ระดับเดียวกับจุดเกิดพาหนะพอดี (cf ที่ส่งมาถูกกดลง 0.6 แล้ว)
-- ท่าเรือไม่มีลานหิน — กลางน้ำใช้ทุ่นผูกเรือแทน
local function pad(parent, cf, vtype)
	local C = K.C
	local m = K.model(parent, "Pad")
	if vtype == "Boat" then
		-- ทุ่นวางเป็นสี่เหลี่ยมรอบที่จอด เว้นให้พ้นตัวเรือ (กว้าง 12 ยาว 30) ไม่งั้นเรือเกิดมาก็ชนทุ่นทันที
		for _, off in ipairs({ Vector3.new(16, 0, 26), Vector3.new(-16, 0, 26), Vector3.new(16, 0, -26), Vector3.new(-16, 0, -26) }) do
			local at = cf * CFrame.new(off.X, 0, off.Z)
			K.barrel(m, at, 1.6, 3, C.paintRed)
			K.lantern(m, at * CFrame.new(0, 3, 0), 1.4, C.lamp)
		end
		return m
	end
	local r = vtype == "Car" and 12 or 20
	K.cyl(m, cf * CFrame.new(0, 0.2, 0), r, 0.4, MAT.Slate, C.darkStone, { name = "Deck" })
	K.cyl(m, cf * CFrame.new(0, 0.45, 0), r * 0.82, 0.2, MAT.Metal, C.brassDark, { cancollide = false })
	K.cyl(m, cf * CFrame.new(0, 0.55, 0), r * 0.3, 0.2, MAT.Neon, C.lamp, { cancollide = false, transparency = 0.55 })
	for i = 0, 7 do
		local a = i * math.pi / 4
		K.box(m, cf * CFrame.new(math.cos(a) * r * 0.9, 0.6, math.sin(a) * r * 0.9) * K.yaw(-a),
			Vector3.new(1.6, 0.3, 0.5), MAT.Metal, C.brass, { cancollide = false })
		if i % 2 == 0 then K.lantern(m, cf * CFrame.new(math.cos(a) * r, 0.4, math.sin(a) * r), 1.4, C.crystal) end
	end
	return m
end

--------------------------------------------------------------------------------
-- บารอนเวน
--------------------------------------------------------------------------------

local NPC_TAG = "WOLD_Npc"
local NPC_KIND = "vehicle"

local function wireBaron(npc, onTalk)
	if npc:GetAttribute("NpcKind") ~= NPC_KIND then return end
	-- HumanoidRootPart ก่อน ด้วยเหตุผลเดียวกับที่ร้านค้าให้ไว้: โมเดล NPC ของคิทตั้ง PrimaryPart เป็นหมุด
	-- 1x1 ที่เท้า ปุ่มจึงไปโผล่อยู่กับพื้นข้างรองเท้า
	local anchor = npc:IsA("BasePart") and npc
		or (npc:IsA("Model") and (npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("UpperTorso")
			or npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart", true)))
	if not anchor then return end
	if anchor:FindFirstChild("VehiclePrompt") then return end

	local p = Instance.new("ProximityPrompt")
	p.Name = "VehiclePrompt"
	p.ActionText = "โรงรถ"
	p.ObjectText = npc:GetAttribute("NpcName") or "บารอนเวน"
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = 0
	p.MaxActivationDistance = Config.SummonRange
	p.RequiresLineOfSight = false
	p.Parent = anchor

	-- คุยกับบารอนเวนได้ทั้งโรงรถ ไม่จำกัดชนิด: station = nil แปลว่า "ทุกคันที่มีกุญแจ" ส่วนตอนเบิก
	-- VehicleMain จะเลือกลานจอดที่ตรงชนิดให้เอง (เรียกเรือขึ้นบกข้างตัว NPC คือเรือที่แล่นไม่ได้)
	p.Triggered:Connect(function(player) onTalk(player, nil) end)
end

--------------------------------------------------------------------------------

function Stations.build(onTalk)
	local root = folder()
	local list, preset = Config.stations()
	Stations.List = {}

	-- เรย์ต้องไม่ไปชนของที่เราเพิ่งวางเอง หรือพาหนะที่ถูกเรียกออกมาอยู่
	local ignore = { root }
	local spawned = workspace:FindFirstChild(Config.Folder)
	if spawned then table.insert(ignore, spawned) end

	local built = 0
	for _, info in ipairs(list) do
		local spec = Config.Types[info.vtype]
		local station = table.clone(info)

		----------------------------------------------------------------------
		-- หาที่จริง
		----------------------------------------------------------------------
		local postAt, spawnAt

		if info.surface == "shore" then
			local land, water = findShore(info.searchFrom or Vector3.new(0, 0, 0), info.pos,
				info.searchRange or 3000, ignore)
			if land then
				postAt = land
				-- ลานจอดอยู่ในน้ำ ถัดจากแนวฝั่งออกไป เรือต้องลงน้ำถึงจะแล่น
				local out = water and (water - land) or Vector3.new(0, 0, 0)
				local direction = out.Magnitude > 1 and out.Unit or Vector3.new(0, 0, 1)
				spawnAt = Vector3.new(land.X, seaLevel(), land.Z) + direction * 70
			end

		elseif info.surface == "peak" then
			local peak = findPeak(info.pos, info.searchRange or 600, ignore)
			if peak then
				postAt = peak
				-- ลานจอดอยู่ข้างยอด ไม่ใช่บนยอดพอดี: หัวเรือเหาะต้องเล็งไปทางที่โล่ง
				local aside = Vector3.new(peak.X, 0, peak.Z + 60)
				local y = groundAt(aside.X, aside.Z, ignore) or peak.Y
				spawnAt = Vector3.new(aside.X, math.max(y, peak.Y - 6), aside.Z)
			end

		else -- "ground"
			local y = groundAt(info.pos.X, info.pos.Z, ignore)
			if y then postAt = Vector3.new(info.pos.X, y, info.pos.Z) end
			local sy = groundAt(info.spawn.X, info.spawn.Z, ignore)
			if sy then spawnAt = Vector3.new(info.spawn.X, sy, info.spawn.Z) end
		end

		-- ไม่เจอผิวเลย (พิกัดอยู่นอกแมพ หรือแมพยังไม่ได้เจน) ใช้พิกัดตั้งต้นไปก่อนแล้วบอกใน Output
		-- ระบบยังทำงานต่อได้ แค่ของอยู่ผิดที่ ซึ่งดีกว่าระบบพาหนะทั้งระบบไม่สตาร์ต
		if not postAt then
			postAt = info.pos
			warn(("[VehicleStations] %s: หาผิวจริงไม่เจอที่ %d, %d — ใช้พิกัดในคอนฟิกไปก่อน")
				:format(info.id, info.pos.X, info.pos.Z))
		end
		spawnAt = spawnAt or (info.spawn and Vector3.new(info.spawn.X, postAt.Y, info.spawn.Z)) or postAt

		station.resolvedPos = postAt
		station.resolvedSpawn = spawnAt
		station.pos = postAt
		station.spawn = spawnAt

		----------------------------------------------------------------------
		-- วางของ
		----------------------------------------------------------------------
		local group = K.model(root, info.id)
		local postCF = CFrame.new(postAt) * CFrame.Angles(0, math.rad(info.face or 0), 0)
		local post = callPost(group, postCF, info.title)
		pad(group, CFrame.new(spawnAt) * CFrame.new(0, -0.6, 0), info.vtype)

		-- ของประดับทั้งหมดชนไม่ได้ เหลือแต่พื้นลานจอด: รถเลี้ยวสุดพวงมาลัยมีรัศมีวงเลี้ยวราว 40 studs
		-- ทุกอย่างในรัศมีนั้นคือสิ่งที่รถจะไปติด (เจอจริงตอนทดสอบ: รถวิ่งวนไปชนตัว NPC จนจอดนิ่ง)
		for _, d in ipairs(group:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "Deck" then d.CanCollide = false end
		end

		local head = post:FindFirstChild("Head") or post:FindFirstChildWhichIsA("BasePart", true)
		if head then
			local p = Instance.new("ProximityPrompt")
			p.Name = "CallPrompt"
			p.ActionText = "เรียก" .. spec.display
			p.ObjectText = info.title
			p.KeyboardKeyCode = Enum.KeyCode.E
			p.HoldDuration = 0
			p.MaxActivationDistance = Config.SummonRange
			p.RequiresLineOfSight = false
			p.Parent = head
			p.Triggered:Connect(function(player) onTalk(player, station) end)
		end

		group:SetAttribute("StationId", info.id)
		group:SetAttribute("VehicleType", info.vtype)
		Stations.List[info.id] = station
		built += 1
	end

	-- บารอนเวน: ผูกตัวที่มีอยู่แล้ว และเฝ้าไว้เผื่อถูกแท็กทีหลัง (มาจากการรัน mapgen/60_npc_setup.lua)
	for _, npc in ipairs(CollectionService:GetTagged(NPC_TAG)) do
		task.spawn(wireBaron, npc, onTalk)
	end
	CollectionService:GetInstanceAddedSignal(NPC_TAG):Connect(function(npc)
		task.spawn(wireBaron, npc, onTalk)
	end)

	print(("[VehicleStations] ตั้งจุดเรียก %d จุด (preset %s)"):format(built, preset))
	return Stations.List
end

function Stations.get(id)
	return Stations.List[id]
end

-- จุดของพาหนะชนิดนี้ ใช้ตอนเบิกจากบารอนเวน: เรือต้องไปโผล่ในน้ำ ไม่ใช่ข้างตัว NPC
function Stations.forType(vtype)
	for _, station in pairs(Stations.List) do
		if station.vtype == vtype then return station end
	end
	return nil
end

return Stations
