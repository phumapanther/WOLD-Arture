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

-- ล้อเดียววงใหญ่ คนนั่งอยู่ข้างใน — ทรงของ The Bizarre Monowheel
--
-- ล้อเป็นทรงกลมไม่ใช่ทรงกระบอก: ทรงกระบอกที่ตั้งตะแคงจะล้มทันทีที่หยุด และการกันไม่ให้ล้มต้องใช้ตัวช่วย
-- อีกชุด ส่วนทรงกลมกลิ้งได้ทุกทางและไม่มีทิศที่ "ล้ม" ได้เลย ซึ่งเหมาะกับของที่ต้องขี่ง่ายที่สุด
local function build()
	local model = Instance.new("Model")
	model.Name = "Monowheel"

	local wheel = Instance.new("Part")
	wheel.Name = "Wheel"
	wheel.Shape = Enum.PartType.Ball
	wheel.Size = Vector3.new(WHEEL_RADIUS * 2, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2)
	wheel.Color = Color3.fromRGB(58, 52, 48)
	wheel.Material = Enum.Material.Metal
	wheel.CustomPhysicalProperties = PhysicalProperties.new(1.2, 0.6, 0.2, 1, 1)
	wheel.CanCollide = true
	wheel.Massless = false
	wheel.Transparency = 0.35 -- โปร่งพอให้เห็นคนนั่งข้างใน
	wheel.Parent = model
	model.PrimaryPart = wheel

	-- ยางรอบนอกกับซี่ล้อ ติดไปกับล้อ ไม่มีมวลและไม่ชน
	local tyre = part(model, "Tyre", Vector3.new(WHEEL_RADIUS * 2.1, WHEEL_RADIUS * 2.1, 1.1),
		wheel.CFrame, Color3.fromRGB(28, 26, 26), Enum.Material.SmoothPlastic)
	tyre.Shape = Enum.PartType.Cylinder
	tyre.CFrame = wheel.CFrame * CFrame.Angles(0, 0, math.rad(90))

	for i = 1, 6 do
		local angle = (i - 1) * (math.pi / 3)
		local spoke = part(model, "Spoke", Vector3.new(0.3, WHEEL_RADIUS * 1.9, 0.3),
			wheel.CFrame * CFrame.Angles(angle, 0, 0), Color3.fromRGB(150, 130, 90), Enum.Material.Metal)
		spoke.CFrame = wheel.CFrame * CFrame.Angles(angle, 0, 0)
	end

	-- โครงที่นั่งข้างใน แขวนอยู่ต่ำกว่าแกนล้อ เพื่อให้จุดศูนย์ถ่วงอยู่ล่างและตัวไม่พลิก
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriveSeat"
	seat.Size = Vector3.new(2.2, 0.4, 2.4)
	seat.CFrame = wheel.CFrame * CFrame.new(0, -1.1, 0)
	seat.Color = Color3.fromRGB(96, 66, 44)
	seat.Material = Enum.Material.Fabric
	seat.CanCollide = false
	seat.Massless = false
	-- ตัวขับเคลื่อนในตัวของ VehicleSeat ไม่ได้ใช้ เราคุมด้วย VectorForce เอง
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.Parent = model

	local handle = part(model, "Handlebar", Vector3.new(3, 0.25, 0.25),
		seat.CFrame * CFrame.new(0, 1.2, -1), Color3.fromRGB(150, 130, 90))
	handle.CFrame = seat.CFrame * CFrame.new(0, 1.2, -1)

	-- เชื่อมทุกชิ้นเข้ากับล้อ ยกเว้นล้อเอง
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= wheel then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = wheel
			weld.Part1 = d
			weld.Parent = wheel
		end
	end

	return model, seat, wheel
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

	local model, seat, wheel = build()
	model:PivotTo(where)
	model.Parent = folder()
	-- เจ้าของ เพื่อให้คนอื่นเรียกของเราไม่ได้ และเพื่อให้รู้ว่าใครขับอยู่
	model:SetAttribute("OwnerUserId", player.UserId)

	Live[player] = { model = model, seat = seat, wheel = wheel }
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
		local model, seat, wheel = entry.model, entry.seat, entry.wheel
		if not model.Parent or not wheel.Parent then
			Live[player] = nil
		else
			local rider = seat.Occupant
			if rider then
				local throttle = seat.Throttle
				local steer = seat.Steer

				-- หันตัวก่อน แล้วค่อยดันไปข้างหน้า ทิศจึงเป็นทิศที่คนขับเพิ่งเลือก ไม่ใช่ทิศของเฟรมก่อน
				if steer ~= 0 then
					local turn = -steer * TURN_SPEED * dt
					wheel.CFrame = wheel.CFrame * CFrame.Angles(0, turn, 0)
				end

				-- ความเร็วแนวราบตอนนี้ เทียบกับเพดาน: ใกล้เพดานแล้วก็หยุดดัน ไม่งั้นมันจะไหลเลยไปเรื่อยๆ
				local flat = wheel.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
				local headroom = math.clamp(1 - flat.Magnitude / TOP_SPEED, 0, 1)
				local push = wheel.CFrame.LookVector * (throttle * ACCEL_FORCE * headroom)
				wheel.AssemblyLinearVelocity = flat + Vector3.new(0, wheel.AssemblyLinearVelocity.Y, 0)
				wheel:ApplyImpulse(push * dt)
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
