-- Monowheel.server.lua: จักรยานล้อเดียวที่ทุกคนมีติดตัวตั้งแต่เริ่ม
--
-- **จงใจไม่เข้าระบบพาหนะเดิม** ตามที่ผู้ใช้เลือก ไม่มีกุญแจ ไม่มีทะเบียน ไม่มีโรงรถ ไม่มีเชื้อเพลิง ไม่มี
-- ความคงทน ไม่มีค่าเบิก — ของแจกฟรีที่กดเรียกแล้วขี่ได้เลย ระบบพาหนะเดิมมีขั้นตอนเหล่านั้นเพราะรถเป็นของ
-- ที่ต้องหามา ส่วนอันนี้คือของที่ทุกคนมีอยู่แล้ว การยัดมันเข้าไปจะทำให้ทั้งสองระบบอธิบายยากขึ้นทั้งคู่
--
-- กดไอเทมครั้งแรก = เรียกออกมาข้างตัว กดอีกครั้ง = หายไป หนึ่งคนมีได้คันเดียว
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local MonowheelAccess = require(game.ServerScriptService.MonowheelAccess)

--------------------------------------------------------------------------------
-- ตัวเลข
--------------------------------------------------------------------------------

-- เร็วเท่าวิ่งเต็มสปีดของเกม (PlayerMovement SPEED.Run = 24) ตามที่ผู้ใช้สั่ง
--
-- จับคู่กับความเร็ววิ่งเพราะจักรยานที่ช้ากว่าการวิ่งคือของที่ไม่มีใครใช้ และที่เร็วกว่ามากก็ทำให้การวิ่ง
-- ไม่มีความหมาย ค่านี้คือ "เท่ากันพอดี" โดยตั้งใจ
local TOP_SPEED = 24
local ACCEL_FORCE = 22000   -- แรงที่ใช้ไล่ไปถึงความเร็วนั้น
local TURN_SPEED = 2.6      -- เรเดียน/วินาที ตอนเลี้ยวสุดพวงมาลัย

-- **ขนาดวัดจากตัวละครจริง ไม่ได้เดา** — Monster_Skeleton (R15 สัดส่วนเดียวกับผู้เล่น) สูง 5.69 studs
-- คนนั่งพับตัวลงเหลือสูงราว 3.4 และขายื่นไปหน้าราว 2.6 วงในจึงต้องกว้างอย่างน้อย 8.4 ถึงจะโอบคนได้จริง
-- ของเดิมรัศมี 3.2 (ล้อกว้าง 6.4) เล็กกว่าตัวคนนั่งเสียอีก ซึ่งเป็นอาการที่ผู้ใช้เห็นในรูป
local INNER_RADIUS = 4.2    -- ขอบในของวง = ช่องที่คนนั่งอยู่
local TYRE_THICK = 1.3      -- ความหนาของยาง
local WHEEL_RADIUS = INNER_RADIUS + TYRE_THICK  -- 5.5 → ล้อกว้าง 11 studs
local WHEEL_WIDTH = 2.2     -- หน้ายาง กว้างพอให้ตั้งอยู่ได้เองบ้าง
local RING_SEGMENTS = 16    -- จำนวนชิ้นที่เอามาวางเป็นวง

local FOLDER_NAME = "WOLD_Monowheels"

local function folder()
	local f = workspace:FindFirstChild(FOLDER_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = workspace
	end
	return f
end

-- [player] = { model, seat, wheel }
local Live = {}

--------------------------------------------------------------------------------
-- โมเดล
--------------------------------------------------------------------------------

local function part(parent, name, size, cf, colour, material, massless)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.Metal
	p.Anchored = false
	p.CanCollide = false
	p.Massless = massless ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- ล้อเดียววงใหญ่ คนนั่งอยู่ "ข้างใน" วง — ทรงของ The Bizarre Monowheel ตามรูปที่ผู้ใช้ส่งมา
--
-- **วงต้องกลวงจริง** ของเดิมใช้ทรงกระบอกซ้อนกันสามชั้น ซึ่งตันหมดทุกชั้น ตรงกลางจึงทึบและคนไปนั่งอยู่
-- "หน้า" ล้อแทนที่จะอยู่ในวง — Roblox ไม่มีทรงวงแหวน วิธีเดียวคือ **วางชิ้นส่วนเรียงเป็นวง** 16 ชิ้น
-- รอบแกน แต่ละชิ้นเอียงตามมุมของตัวเอง พอเรียงครบรอบก็อ่านเป็นวงกลมที่มีรูตรงกลาง
--
-- ล้อชนพื้นด้วยชิ้นส่วนยางพวกนี้เอง ไม่มีทรงกระบอกซ่อนอยู่ข้างใน — ถ้ามี มันจะเป็นลูกกลิ้งตันที่บังรู
--
-- โครงที่นั่งไม่ได้เชื่อมติดล้อ แต่ **แขวนด้วยบานพับ (HingeConstraint)** ที่แกนกลาง ล้อจึงหมุนรอบตัวเอง
-- ได้จริงในขณะที่คนขับยังนั่งตรง เหมือนของจริงในรูป ถ้าเชื่อมติดกัน คนขับจะหมุนตีลังกาไปกับล้อ
local function build()
	local model = Instance.new("Model")
	model.Name = "Monowheel"

	-- แกนกลาง: ชิ้นเล็กๆ ที่มองไม่เห็น ทำหน้าที่เป็น "ตัวล้อ" ให้ชิ้นส่วนวงแหวนทุกชิ้นเชื่อมติด
	--
	-- ต้องมีชิ้นกลางเพราะวงแหวนไม่มีชิ้นไหนอยู่ตรงแกนเลย แต่บานพับต้องยึดกับบางอย่างที่อยู่ตรงแกนพอดี
	local hub = Instance.new("Part")
	hub.Name = "Wheel"
	hub.Shape = Enum.PartType.Ball
	hub.Size = Vector3.new(0.6, 0.6, 0.6)
	hub.CFrame = CFrame.new()
	hub.Transparency = 1
	hub.CanCollide = false
	hub.CanQuery = false
	hub.Massless = false
	hub.Parent = model
	model.PrimaryPart = hub

	-- วงยาง: ชิ้นส่วนเรียงรอบแกน แต่ละชิ้นยาวพอให้ชนชิ้นข้างเคียงจนดูต่อเนื่อง
	--
	-- ความยาวของคอร์ดที่รองรับมุม θ คือ 2R·sin(θ/2) คูณเผื่อไว้นิดให้ชิ้นซ้อนกันเล็กน้อย ไม่งั้นจะเห็น
	-- ร่องระหว่างชิ้นตอนล้อหมุน
	--
	-- **ต้องหมุนรอบแกน X เท่านั้น** `CFrame.Angles(angle, 0, 0)` วางวงไว้ในระนาบ Y-Z ซึ่งเป็นล้อที่กลิ้ง
	-- ไปทางหน้า-หลัง ตรงกับทิศที่ที่นั่งหันไป (-Z) และตรงกับแกนที่บานพับหมุน (แกน X ของ Attachment)
	--
	-- ของเดิมใช้ `CFrame.Angles(0, 0, angle)` = หมุนรอบแกน Z ซึ่งวางวงไว้ในระนาบ X-Y — ล้อตั้งขวางทาง
	-- กลิ้งไปทางซ้าย-ขวา ผลคือสามอาการพร้อมกัน: คนนั่งหันข้างล้อ · เรียกออกมาแล้ววางผิดทิศ · และพอออกแรง
	-- บานพับก็บังคับให้วงตีลังกาข้างจนล้มลงไปนอน สามอาการนี้มีต้นเหตุเดียวคือแกนนี้แกนเดียว
	local step = math.pi * 2 / RING_SEGMENTS
	local chord = 2 * WHEEL_RADIUS * math.sin(step / 2) * 1.06
	local midR = INNER_RADIUS + TYRE_THICK / 2

	for i = 1, RING_SEGMENTS do
		local angle = (i - 1) * step
		local seg = Instance.new("Part")
		seg.Name = "Tyre"
		-- หน้ายางกว้างไปตามแกน X (ซ้าย-ขวา) ความหนาอยู่แนวรัศมี ความยาวไปตามเส้นรอบวง
		seg.Size = Vector3.new(WHEEL_WIDTH, TYRE_THICK, chord)
		-- วางที่ระยะ midR จากแกน แล้วหมุนให้ด้านยาวของชิ้นวางไปตามเส้นรอบวง
		seg.CFrame = CFrame.Angles(angle, 0, 0) * CFrame.new(0, midR, 0)
		seg.Color = Color3.fromRGB(48, 44, 42)
		seg.Material = Enum.Material.Pebble
		-- ยางเกาะถนน: แรงเสียดทานสูง เด้งต่ำ
		seg.CustomPhysicalProperties = PhysicalProperties.new(1.1, 2.0, 0.1, 2, 1)
		seg.CanCollide = true
		seg.Massless = false
		seg.TopSurface = Enum.SurfaceType.Smooth
		seg.BottomSurface = Enum.SurfaceType.Smooth
		seg.Parent = model
	end

	-- ขอบทองเหลืองด้านใน: วงที่สองที่บางกว่า ให้เห็นเป็นวงซ้อนแบบในรูป และเป็นขอบของ "รู"
	local rimR = INNER_RADIUS + 0.22
	local rimChord = 2 * rimR * math.sin(step / 2) * 1.06
	for i = 1, RING_SEGMENTS do
		local angle = (i - 1) * step + step / 2
		local seg = part(model, "Rim", Vector3.new(WHEEL_WIDTH + 0.5, 0.45, rimChord),
			CFrame.new(), Color3.fromRGB(176, 138, 68), Enum.Material.Metal)
		seg.CFrame = CFrame.Angles(angle, 0, 0) * CFrame.new(0, rimR, 0)
	end

	-- ซี่ล้อ 4 ซี่จากแกนออกไปขอบ ให้อ่านออกว่าเป็นล้อ ไม่ใช่ห่วงลอยๆ
	--
	-- **อยู่ชิดด้านข้าง ไม่ได้พาดกลางวง** จึงไม่ขวางทางคนนั่ง ซึ่งเป็นเหตุผลเดียวที่วงนี้ยังกลวงอยู่
	for i = 1, 4 do
		local angle = (i - 1) * (math.pi / 2) + math.pi / 4
		local spoke = part(model, "Spoke", Vector3.new(0.34, INNER_RADIUS, 0.34),
			CFrame.new(), Color3.fromRGB(120, 112, 104), Enum.Material.Metal)
		spoke.CFrame = CFrame.Angles(angle, 0, 0)
			* CFrame.new(WHEEL_WIDTH / 2 + 0.22, INNER_RADIUS / 2, 0)
	end

	-- เฟืองสองตัวบนขอบ พอให้อ่านออกว่าเป็นเครื่องจักรไอน้ำ ไม่ได้ทำครบทุกซี่เพราะมองไม่ทันตอนขี่อยู่แล้ว
	for _, spec in ipairs({ { 0.9, 1.0 }, { 2.4, 0.75 } }) do
		local angle, size = spec[1], spec[2]
		local gear = part(model, "Gear", Vector3.new(0.4, size * 2, size * 2),
			CFrame.new(), Color3.fromRGB(150, 130, 90), Enum.Material.Metal)
		gear.Shape = Enum.PartType.Cylinder
		-- ทรงกระบอกยาวตามแกน X ของตัวเองอยู่แล้ว = หน้าเฟืองหันออกด้านข้างพอดี ไม่ต้องหมุนเพิ่ม
		gear.CFrame = CFrame.Angles(angle, 0, 0)
			* CFrame.new(WHEEL_WIDTH / 2 + 0.3, midR, 0)
	end

	-- ทุกชิ้นของ "ล้อ" เชื่อมติดแกนกลาง หมุนไปด้วยกัน
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= hub then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hub
			weld.Part1 = d
			weld.Parent = hub
		end
	end

	----------------------------------------------------------------------------
	-- โครงที่นั่ง: แยกชิ้นจากล้อ แขวนด้วยบานพับ
	----------------------------------------------------------------------------

	-- **ที่นั่งต้อง CanCollide = true** ไม่งั้นไม่มีใครนั่งได้เลย
	--
	-- Seat ของ Roblox จับคนนั่งจากการ "แตะ" ถ้าปิดการชน ก็ไม่มีอะไรมาแตะ ปุ่มนั่งจึงไม่ขึ้นและกด E ไม่ติด
	--
	-- **ตำแหน่ง** ของเดิมวางที่ y = -0.9 ซึ่งเกือบกลางแกน คนจึงโผล่พ้นวงไปนั่งอยู่หน้าล้อตามที่ผู้ใช้เห็น
	-- ตอนนี้วางต่ำลงไปที่ก้นวง (60% ของรัศมีวงใน) — คนนั่งจะอยู่ในวงจริง หัวไม่ชนขอบบน เท้าไม่ทะลุขอบล่าง
	local seatY = -INNER_RADIUS * 0.60
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriveSeat"
	seat.Size = Vector3.new(2, 0.4, 2)
	seat.CFrame = CFrame.new(0, seatY, 0)
	seat.Color = Color3.fromRGB(122, 84, 52)
	seat.Material = Enum.Material.Wood
	seat.CanCollide = true
	seat.Massless = false
	-- ตัวขับเคลื่อนในตัวของ VehicleSeat ไม่ได้ใช้ เราคุมด้วยแรงเอง
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.Parent = model

	-- พนักพิงเตี้ยๆ ด้านหลัง กันคนไหลหลุดตอนเร่ง และบอกทิศว่าหน้าอยู่ทางไหน
	local back = part(model, "SeatBack", Vector3.new(2, 1.2, 0.3),
		CFrame.new(), Color3.fromRGB(122, 84, 52), Enum.Material.Wood)
	back.CFrame = seat.CFrame * CFrame.new(0, 0.7, 1.0)
	local backWeld = Instance.new("WeldConstraint")
	backWeld.Part0 = seat
	backWeld.Part1 = back
	backWeld.Parent = seat

	-- แฮนด์คู่หน้า ตามรูป วางให้อยู่ระดับมือคนนั่ง
	for _, side in ipairs({ -0.85, 0.85 }) do
		local grip = part(model, "Grip", Vector3.new(0.26, 1.0, 0.26),
			CFrame.new(), Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
		grip.CFrame = seat.CFrame * CFrame.new(side, 1.0, -1.5)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = seat
		weld.Part1 = grip
		weld.Parent = seat
	end

	-- ถ่วงน้ำหนักไว้ใต้ที่นั่ง: จุดศูนย์ถ่วงที่อยู่ต่ำคือสิ่งที่ทำให้โครงห้อยตรงเองแทนที่จะแกว่งไปมา
	local ballast = part(model, "Ballast", Vector3.new(1.6, 0.6, 1.8),
		CFrame.new(), Color3.fromRGB(96, 92, 88), Enum.Material.Metal, false)
	ballast.CFrame = seat.CFrame * CFrame.new(0, -0.7, 0)
	local bweld = Instance.new("WeldConstraint")
	bweld.Part0 = seat
	bweld.Part1 = ballast
	bweld.Parent = seat

	-- บานพับที่แกนล้อ: ล้อหมุนได้อิสระ โครงที่นั่งไม่หมุนตาม
	--
	-- HingeConstraint หมุนรอบ **แกน X ของ Attachment** เสมอ ทั้งสองฝั่งจึงตั้ง CFrame เปล่าไว้ (ต่างกัน
	-- แค่ตำแหน่ง) แกน X จึงตรงกันพอดี = แกนซ้าย-ขวาของรถ ซึ่งเป็นแกนที่ล้อต้องหมุนรอบ
	local a0 = Instance.new("Attachment")
	a0.Name = "AxleWheel"
	a0.CFrame = CFrame.new()
	a0.Parent = hub

	local a1 = Instance.new("Attachment")
	a1.Name = "AxleFrame"
	-- จากที่นั่งขึ้นไปหาแกน: ระยะเท่ากับที่ที่นั่งอยู่ต่ำกว่าแกนพอดี
	a1.CFrame = CFrame.new(0, -seatY, 0)
	a1.Parent = seat

	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0 = a0
	hinge.Attachment1 = a1
	hinge.LimitsEnabled = false
	hinge.Parent = hub

	-- ตัวพยุงให้ตั้งตรง ไม่ล้มซ้ายขวา
	--
	-- นี่คือราคาของการใช้วงแหวนแทนลูกบอล: ต้องมีอะไรบอกว่า "อย่าล้ม" ตั้ง Responsiveness ไม่สูงมาก
	-- เพื่อให้ยังเอียงตอนเลี้ยวได้บ้าง ไม่ใช่แข็งทื่อเหมือนติดราง
	--
	-- **พยุงที่โครงที่นั่ง ไม่ใช่ที่ล้อ** ถ้าไปพยุงล้อ = สั่งไม่ให้ล้อหมุน ซึ่งขัดกับบานพับโดยตรง
	-- (ของเดิมพยุงที่ล้อ แล้วบานพับกับตัวพยุงก็ออกแรงสู้กันอยู่ทั้งเวลา)
	local upright = Instance.new("Attachment")
	upright.Name = "Upright"
	upright.Parent = seat

	local align = Instance.new("AlignOrientation")
	align.Attachment0 = upright
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.RigidityEnabled = false
	align.Responsiveness = 18
	align.MaxTorque = 160000
	align.Parent = seat
	-- ทิศเป้าหมายถูกตั้งใหม่ทุกเฟรมในลูปหลัก ให้ตั้งตรงแต่ยังหันไปทางที่คนขับเลี้ยว

	return model, seat, hub, align
end

--------------------------------------------------------------------------------
-- เรียก / เก็บ
--------------------------------------------------------------------------------

local function despawn(player)
	local entry = Live[player]
	if not entry then return false end
	Live[player] = nil
	if entry.model and entry.model.Parent then entry.model:Destroy() end
	return true
end

-- ที่ว่างรอบตัว: สุ่มมุมแล้วหาพื้นจริง เหมือนหีบสมบัติกับมอน
local function spotNear(root)
	for attempt = 1, 10 do
		local angle = math.random() * math.pi * 2
		local reach = 6 + attempt
		local x = root.Position.X + math.cos(angle) * reach
		local z = root.Position.Z + math.sin(angle) * reach
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { folder(), root.Parent }
		params.IgnoreWater = true
		local hit = workspace:Raycast(Vector3.new(x, root.Position.Y + 60, z), Vector3.new(0, -400, 0), params)
		if hit then
			-- **ต้องคืนทิศมาด้วย ไม่ใช่แค่ตำแหน่ง** ของเดิมคืน CFrame.new(ตำแหน่ง) เปล่าๆ ซึ่งหันไปทาง -Z
			-- ของโลกเสมอ ไม่ว่าคนเรียกจะหันไปทางไหน จักรยานจึงวางขวางทางทุกครั้งที่เรียก
			--
			-- หันไปทางเดียวกับคนเรียก แต่ตัดแกน Y ทิ้ง (เงยหน้า/ก้มหน้าไม่ควรทำให้จักรยานเอียง)
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			local heading = math.atan2(-look.X, -look.Z)
			local at = Vector3.new(x, hit.Position.Y + WHEEL_RADIUS + 0.5, z)
			return CFrame.new(at) * CFrame.Angles(0, heading, 0), heading
		end
	end
	return nil
end

local function spawnFor(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return false, "ยังไม่มีตัวละคร" end

	local where, heading = spotNear(root)
	if not where then return false, "ไม่มีที่ว่างพอ" end

	local model, seat, wheel, align = build()
	model:PivotTo(where)
	model.Parent = folder()
	-- เจ้าของ เพื่อให้คนอื่นเรียกของเราไม่ได้ และเพื่อให้รู้ว่าใครขับอยู่
	model:SetAttribute("OwnerUserId", player.UserId)

	-- **heading ต้องตรงกับทิศที่วางจริง** ถ้าปล่อยเป็น 0 ลูปขับจะสั่ง AlignOrientation ให้หันกลับไป -Z
	-- ของโลกทันทีในเฟรมแรก = จักรยานสะบัดตัวเองทิ้งทันทีที่เรียกออกมา
	Live[player] = { model = model, seat = seat, wheel = wheel, align = align, heading = heading or 0 }
	return true
end

-- กดไอเทม: ไม่มีอยู่ = เรียก, มีอยู่ = เก็บ
function MonowheelAccess.Toggle(player)
	if despawn(player) then return true, "เก็บจักรยานแล้ว" end
	local ok, why = spawnFor(player)
	return ok, ok and "เรียกจักรยานแล้ว" or why
end

--------------------------------------------------------------------------------
-- ขับ
--------------------------------------------------------------------------------

-- แรงขับกับการเลี้ยวคำนวณใหม่ทุกเฟรม จาก Throttle/Steer ที่ VehicleSeat เติมให้เองเมื่อคนขับกดปุ่มเดิน
-- (ไม่ต้องมี Remote เลย เอนจิ้นส่งค่าสองตัวนี้ให้เซิร์ฟเวอร์อยู่แล้ว)
RunService.Heartbeat:Connect(function(dt)
	for player, entry in pairs(Live) do
		local model, seat, wheel, align = entry.model, entry.seat, entry.wheel, entry.align
		if not model.Parent or not wheel.Parent then
			Live[player] = nil
		else
			local throttle = seat.Occupant and seat.Throttle or 0
			local steer = seat.Occupant and seat.Steer or 0

			-- ทิศที่หันอยู่ เก็บเป็นมุมของเราเอง ไม่ได้อ่านจากล้อ
			--
			-- **อ่านจากล้อไม่ได้** เพราะล้อหมุนรอบแกนตัวเองตลอดเวลาที่วิ่ง LookVector ของมันจึงชี้มั่วไป
			-- เรื่อยตามการกลิ้ง ไม่ใช่ทิศที่รถกำลังไป
			if steer ~= 0 then
				entry.heading = entry.heading - steer * TURN_SPEED * dt
			end
			local facing = CFrame.Angles(0, entry.heading, 0)

			-- พยุงให้ตั้งตรงและหันไปทางที่เลี้ยว ทำทุกเฟรมเพราะทิศเปลี่ยนได้ทุกเฟรม
			align.CFrame = facing

			-- **ดันที่โครงที่นั่ง ไม่ใช่ที่ล้อ**
			--
			-- บานพับแบ่งจักรยานออกเป็นสองก้อนที่ขยับแยกกันได้ (assembly ล้อ กับ assembly โครง+คนขับ)
			-- ถ้าดันที่ล้ออย่างเดียว ล้อจะวิ่งออกไปแล้วลากโครงตามทีหลัง — สั่นและช้า ดันที่โครงซึ่งเป็นก้อน
			-- ที่มีทั้งน้ำหนักคนขับและตุ้มถ่วง แล้วล้อจะถูกลากไปด้วยผ่านบานพับ ซึ่งเป็นทิศทางที่ถูกของแรง
			local body = seat
			local flat = body.AssemblyLinearVelocity * Vector3.new(1, 0, 1)

			if throttle ~= 0 then
				local forward = facing.LookVector
				-- ใกล้เพดานแล้วหยุดดัน ไม่งั้นจะไหลเลยความเร็วที่ตั้งไว้ไปเรื่อยๆ
				local headroom = math.clamp(1 - flat.Magnitude / TOP_SPEED, 0, 1)
				body:ApplyImpulse(forward * (throttle * ACCEL_FORCE * headroom * dt))
			elseif flat.Magnitude > 0.5 then
				-- ปล่อยคันเร่ง = หน่วงให้หยุดเอง ไม่ใช่ไหลไปจนชนอะไรสักอย่าง
				body:ApplyImpulse(-flat.Unit * math.min(flat.Magnitude, 6) * body.AssemblyMass * dt * 2)
			end
		end
	end
end)

-- ตายหรือออกจากเกม จักรยานหายไปด้วย ไม่งั้นแมพจะเต็มไปด้วยล้อที่ไม่มีเจ้าของ
Players.PlayerRemoving:Connect(despawn)
Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function() despawn(player) end)
end)
for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterRemoving:Connect(function() despawn(player) end)
end
