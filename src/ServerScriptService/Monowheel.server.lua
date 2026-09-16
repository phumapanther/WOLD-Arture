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
local WHEEL_RADIUS = 3.2

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

-- ล้อเดียววงใหญ่ คนนั่งอยู่ข้างใน — ทรงของ The Bizarre Monowheel ตามรูปที่ผู้ใช้ส่งมา
--
-- **ล้อเป็นทรงกระบอกตั้งขึ้น ไม่ใช่ลูกบอล** ลูกบอลกลิ้งได้ทุกทิศซึ่งง่ายกับฟิสิกส์ แต่หน้าตาผิดไปคนละอย่าง
-- ราคาที่ต้องจ่ายคือทรงกระบอกล้มได้ จึงต้องมีตัวพยุงให้ตั้งตรง (AlignOrientation ข้างล่าง) ซึ่งเป็นวิธี
-- เดียวกับที่รถมอเตอร์ไซค์ในเกมอื่นใช้
--
-- โครงที่นั่งไม่ได้เชื่อมติดล้อ แต่ **แขวนด้วยบานพับ (HingeConstraint)** ที่แกนกลาง ล้อจึงหมุนรอบตัวเอง
-- ได้จริงในขณะที่คนขับยังนั่งตรง เหมือนของจริงในรูป ถ้าเชื่อมติดกัน คนขับจะหมุนตีลังกาไปกับล้อ
local function build()
	local model = Instance.new("Model")
	model.Name = "Monowheel"

	-- ยางรอบนอก: ทรงกระบอกวางตะแคงให้หน้ายางแตะพื้น
	--
	-- ทรงกระบอกของ Roblox ยาวตามแกน X โดยธรรมชาติ หมุน 90 องศารอบแกน Z จึงได้ล้อที่ "ตั้ง" อยู่
	local wheel = Instance.new("Part")
	wheel.Name = "Wheel"
	wheel.Shape = Enum.PartType.Cylinder
	wheel.Size = Vector3.new(1.6, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2) -- หนา 1.6 เส้นผ่านศูนย์กลางเต็ม
	wheel.CFrame = CFrame.Angles(0, 0, math.rad(90))
	wheel.Color = Color3.fromRGB(48, 44, 42)
	wheel.Material = Enum.Material.Pebble
	-- ยางเกาะถนน: แรงเสียดทานสูง เด้งต่ำ
	wheel.CustomPhysicalProperties = PhysicalProperties.new(1.1, 2.0, 0.1, 2, 1)
	wheel.CanCollide = true
	wheel.Massless = false
	wheel.Parent = model
	model.PrimaryPart = wheel

	-- ขอบล้อทองเหลืองด้านใน ให้เห็นเป็นวงซ้อนแบบในรูป
	local rim = part(model, "Rim", Vector3.new(1.8, WHEEL_RADIUS * 1.62, WHEEL_RADIUS * 1.62),
		wheel.CFrame, Color3.fromRGB(176, 138, 68), Enum.Material.Metal)
	rim.Shape = Enum.PartType.Cylinder
	rim.CFrame = wheel.CFrame

	local innerRim = part(model, "InnerRim", Vector3.new(1.9, WHEEL_RADIUS * 1.32, WHEEL_RADIUS * 1.32),
		wheel.CFrame, Color3.fromRGB(96, 92, 88), Enum.Material.Metal)
	innerRim.Shape = Enum.PartType.Cylinder
	innerRim.CFrame = wheel.CFrame

	-- เฟืองสองตัวบนขอบ พอให้อ่านออกว่าเป็นเครื่องจักรไอน้ำ ไม่ได้ทำครบทุกซี่เพราะมองไม่ทันตอนขี่อยู่แล้ว
	for _, spec in ipairs({ { 0.9, 1.1 }, { 2.4, 0.8 } }) do
		local angle, size = spec[1], spec[2]
		local gear = part(model, "Gear", Vector3.new(0.4, size * 2, size * 2),
			wheel.CFrame, Color3.fromRGB(150, 130, 90), Enum.Material.Metal)
		gear.Shape = Enum.PartType.Cylinder
		gear.CFrame = wheel.CFrame
			* CFrame.Angles(math.rad(90), 0, 0)
			* CFrame.new(math.cos(angle) * WHEEL_RADIUS * 0.74, 0, math.sin(angle) * WHEEL_RADIUS * 0.74)
			* CFrame.Angles(0, 0, math.rad(90))
	end

	-- ทุกชิ้นของ "ล้อ" เชื่อมติดล้อ หมุนไปด้วยกัน
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= wheel then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = wheel
			weld.Part1 = d
			weld.Parent = wheel
		end
	end

	----------------------------------------------------------------------------
	-- โครงที่นั่ง: แยกชิ้นจากล้อ แขวนด้วยบานพับ
	----------------------------------------------------------------------------

	-- **ที่นั่งต้อง CanCollide = true** ไม่งั้นไม่มีใครนั่งได้เลย
	--
	-- Seat ของ Roblox จับคนนั่งจากการ "แตะ" ถ้าปิดการชน ก็ไม่มีอะไรมาแตะ ปุ่มนั่งจึงไม่ขึ้นและกด E ไม่ติด
	-- ซึ่งเป็นอาการที่ผู้ใช้เจอเป๊ะ
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriveSeat"
	seat.Size = Vector3.new(2, 0.5, 2.6)
	seat.CFrame = CFrame.new(0, -0.9, 0)
	seat.Color = Color3.fromRGB(122, 84, 52)
	seat.Material = Enum.Material.Wood
	seat.CanCollide = true
	seat.Massless = false
	-- ตัวขับเคลื่อนในตัวของ VehicleSeat ไม่ได้ใช้ เราคุมด้วยแรงเอง
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.Parent = model

	-- แฮนด์คู่หน้า ตามรูป
	for _, side in ipairs({ -0.75, 0.75 }) do
		local grip = part(model, "Grip", Vector3.new(0.26, 1.1, 0.26),
			seat.CFrame * CFrame.new(side, 1.15, -1.25), Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
		grip.CFrame = seat.CFrame * CFrame.new(side, 1.15, -1.25)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = seat
		weld.Part1 = grip
		weld.Parent = seat
	end

	-- ถ่วงน้ำหนักไว้ใต้แกน: จุดศูนย์ถ่วงที่อยู่ต่ำคือสิ่งที่ทำให้โครงห้อยตรงเองแทนที่จะแกว่งไปมา
	local ballast = part(model, "Ballast", Vector3.new(1.6, 0.6, 2),
		seat.CFrame * CFrame.new(0, -1.1, 0), Color3.fromRGB(96, 92, 88), Enum.Material.Metal, false)
	ballast.CFrame = seat.CFrame * CFrame.new(0, -1.1, 0)
	local bweld = Instance.new("WeldConstraint")
	bweld.Part0 = seat
	bweld.Part1 = ballast
	bweld.Parent = seat

	-- บานพับที่แกนล้อ: ล้อหมุนได้อิสระ โครงที่นั่งไม่หมุนตาม
	local a0 = Instance.new("Attachment")
	a0.Name = "AxleWheel"
	-- แกนของทรงกระบอกคือแกน X ของตัวมันเอง บานพับจึงต้องชี้ไปทางนั้น
	a0.CFrame = CFrame.new()
	a0.Parent = wheel

	local a1 = Instance.new("Attachment")
	a1.Name = "AxleFrame"
	a1.CFrame = CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90))
	a1.Parent = seat

	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0 = a0
	hinge.Attachment1 = a1
	hinge.LimitsEnabled = false
	hinge.Parent = wheel

	-- ตัวพยุงให้ล้อตั้งตรง ไม่ล้มซ้ายขวา
	--
	-- นี่คือราคาของการใช้ทรงกระบอกแทนลูกบอล: ต้องมีอะไรบอกว่า "อย่าล้ม" ตั้ง Responsiveness ไม่สูงมาก
	-- เพื่อให้ยังเอียงตอนเลี้ยวได้บ้าง ไม่ใช่แข็งทื่อเหมือนติดราง
	local upright = Instance.new("Attachment")
	upright.Name = "Upright"
	upright.Parent = wheel

	local align = Instance.new("AlignOrientation")
	align.Attachment0 = upright
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.PrimaryAxisOnly = false
	-- ล็อกเฉพาะการเอียงซ้ายขวา ปล่อยให้หมุนตามแกนล้อได้อิสระ
	align.RigidityEnabled = false
	align.Responsiveness = 18
	align.MaxTorque = 120000
	align.Parent = wheel
	-- ทิศเป้าหมายถูกตั้งใหม่ทุกเฟรมในลูปหลัก ให้ตั้งตรงแต่ยังหันไปทางที่คนขับเลี้ยว

	return model, seat, wheel, align
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
			return CFrame.new(Vector3.new(x, hit.Position.Y + WHEEL_RADIUS + 0.5, z))
		end
	end
	return nil
end

local function spawnFor(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return false, "ยังไม่มีตัวละคร" end

	local where = spotNear(root)
	if not where then return false, "ไม่มีที่ว่างพอ" end

	local model, seat, wheel, align = build()
	model:PivotTo(where)
	model.Parent = folder()
	-- เจ้าของ เพื่อให้คนอื่นเรียกของเราไม่ได้ และเพื่อให้รู้ว่าใครขับอยู่
	model:SetAttribute("OwnerUserId", player.UserId)

	Live[player] = { model = model, seat = seat, wheel = wheel, align = align, heading = 0 }
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

			if throttle ~= 0 then
				local forward = facing.LookVector
				local flat = wheel.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
				-- ใกล้เพดานแล้วหยุดดัน ไม่งั้นจะไหลเลยความเร็วที่ตั้งไว้ไปเรื่อยๆ
				local headroom = math.clamp(1 - flat.Magnitude / TOP_SPEED, 0, 1)
				wheel:ApplyImpulse(forward * (throttle * ACCEL_FORCE * headroom * dt))
			else
				-- ปล่อยคันเร่ง = หน่วงให้หยุดเอง ไม่ใช่ไหลไปจนชนอะไรสักอย่าง
				local flat = wheel.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
				if flat.Magnitude > 0.5 then
					wheel:ApplyImpulse(-flat.Unit * math.min(flat.Magnitude, 6) * wheel.AssemblyMass * dt * 2)
				end
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
