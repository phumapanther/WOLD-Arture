-- Vehicle/Chassis — ชิ้นส่วนฟิสิกส์ของพาหนะ
--
-- กติกาเดียวที่ทั้งสามชนิดใช้ร่วมกัน: **มวลทั้งคันอยู่ที่กล่องชนใบเดียว (Hull)**
-- ของสวยงามทุกชิ้นเป็น Massless + CanCollide=false เชื่อมติด Hull ด้วย WeldConstraint
-- เพิ่มลูกเล่นบนตัวถังได้ไม่จำกัดโดยที่การขับไม่เปลี่ยนเลย ซึ่งเป็นเหตุผลเดียวที่รถทรงนี้ขับไหว
local PhysicsService = game:GetService("PhysicsService")

local Chassis = {}

local PHYS = PhysicalProperties.new

-- ล้อกับตัวถังเป็นคนละ assembly (ต่อกันด้วย HingeConstraint ไม่ใช่ weld) → Roblox ให้มันชนกันเอง
-- พอขอบล้อเฉี่ยวกล่องชนแค่เศษ stud เดียว แรงเสียดทานตรงนั้นก็ล็อกล้อจนรถไม่ขยับ
-- กลุ่มการชนนี้คือสิ่งที่ทำให้รถวิ่งได้จริง อย่าถอดออกเวลาปรับทรงตัวถัง
local GROUPS_READY = false
local function ensureGroups()
  if GROUPS_READY then return end
  GROUPS_READY = true
  pcall(function() PhysicsService:RegisterCollisionGroup("VehicleBody") end)
  pcall(function() PhysicsService:RegisterCollisionGroup("VehicleWheel") end)
  pcall(function()
    PhysicsService:CollisionGroupSetCollidable("VehicleBody", "VehicleWheel", false)
    PhysicsService:CollisionGroupSetCollidable("VehicleWheel", "VehicleWheel", false)
  end)
end

-- กล่องชนที่ถือมวลทั้งคัน: มองไม่เห็น แต่เป็นตัวที่ชนพื้นจริง
function Chassis.hull(model, cf, size, density, name)
  ensureGroups()
  local p = Instance.new("Part")
  p.Name = name or "Hull"
  p.Size = size
  p.CFrame = cf
  p.Transparency = 1
  p.CanCollide = true
  p.Anchored = false
  p.TopSurface = Enum.SurfaceType.Smooth
  p.BottomSurface = Enum.SurfaceType.Smooth
  p.CustomPhysicalProperties = PHYS(density or 0.7, 0.4, 0.2, 1, 1)
  p.CollisionGroup = "VehicleBody"
  p.Parent = model
  model.PrimaryPart = p
  return p
end

-- ปลดยึดทุกชิ้นแล้วเชื่อมติด Hull  (ข้ามชิ้นที่ตั้ง Attribute "NoWeld" ไว้ เช่น ล้อกับดุม)
function Chassis.finalize(model, hull)
  for _, d in ipairs(model:GetDescendants()) do
    if d:IsA("BasePart") and d ~= hull and not d:GetAttribute("NoWeld") then
      d.Anchored = false
      d.Massless = true
      if d:GetAttribute("Collide") ~= true then d.CanCollide = false end
      d.CanQuery = false
      local w = Instance.new("WeldConstraint")
      w.Part0 = hull
      w.Part1 = d
      w.Parent = hull
    end
  end
  hull.Anchored = false
  return model
end

-- ที่นั่ง: คนขับเป็น VehicleSeat (Throttle/Steer ถูกส่งจากไคลเอนต์ให้เซิร์ฟเวอร์เอง ไม่ต้องทำ Remote)
function Chassis.seat(model, hull, cf, kind, name)
  local seat = Instance.new(kind == "driver" and "VehicleSeat" or "Seat")
  seat.Name = name or (kind == "driver" and "DriveSeat" or "PassengerSeat")
  seat.Size = Vector3.new(2.6, 1, 2.4)
  seat.CFrame = cf
  seat.Transparency = 1
  seat.CanCollide = false
  seat.Anchored = false
  seat.TopSurface = Enum.SurfaceType.Smooth
  seat.BottomSurface = Enum.SurfaceType.Smooth
  seat:SetAttribute("NoWeld", true)     -- เชื่อมเองด้านล่าง (ต้องไม่ถูกตั้ง Massless ทับ)
  seat:SetAttribute("SeatKind", kind)
  if seat:IsA("VehicleSeat") then
    seat.MaxSpeed = 0                   -- ตัวขับเคลื่อนในตัวของ VehicleSeat ไม่ได้ใช้ เราคุมเอง
    seat.Torque = 0
    seat.TurnSpeed = 0
  end
  seat.Parent = model
  local w = Instance.new("WeldConstraint")
  w.Part0 = hull
  w.Part1 = seat
  w.Parent = hull
  return seat
end

-- ---------------------------------------------------------------- ล้อ (รถเท่านั้น)
-- โครง: Hull --Servo(แกนตั้ง)--> Hub --Motor(แกนนอน)--> Wheel
-- ล้อหลังไม่มี Hub ต่อ Motor เข้ากับ Hull ตรงๆ
local function attach(part, cf, name)
  local a = Instance.new("Attachment")
  a.Name = name
  a.CFrame = cf
  a.Parent = part
  return a
end

-- spec ที่รับคือ **สเปกทั้งคันไม่ใช่แค่ตาราง wheel** เพราะค่าของเซอร์โว (แรงบิด องศา ความเร็วหมุนพวงมาลัย)
-- อยู่ระดับคัน ไม่ใช่ระดับล้อ — เคยส่งแค่ spec.wheel เข้ามาแล้วค่าพวกนี้เป็น nil เงียบๆ ใช้ดีฟอลต์หมด
function Chassis.wheel(model, hull, offset, spec, steerable)
  local w = spec.wheel
  local radius, width = w.radius, w.width
  local wheelCF = hull.CFrame * CFrame.new(offset)

  local wheel = Instance.new("Part")
  wheel.Name = "Wheel"
  wheel.Shape = Enum.PartType.Cylinder
  -- ทรงกระบอกของ Roblox วางยาวตามแกน X ของตัวเอง → ไม่ต้องหมุน แกนหมุนก็ชี้ออกข้างรถพอดี
  wheel.Size = Vector3.new(width, radius * 2, radius * 2)
  wheel.CFrame = wheelCF
  wheel.Anchored = false
  wheel.CanCollide = true
  wheel.Color = Color3.fromRGB(38, 34, 32)
  wheel.Material = Enum.Material.Metal
  -- frictionWeight สูงๆ ทำให้ยางเกาะจนล้อหน้าสะบัด: ปล่อยให้พื้นมีส่วนกำหนดแรงเสียดทานด้วย
  wheel.CustomPhysicalProperties = PHYS(w.density, w.friction, 0, w.frictionWeight or 8, 1)
  wheel.CollisionGroup = "VehicleWheel"
  wheel:SetAttribute("NoWeld", true)
  wheel.Parent = model

  local anchorPart, anchorCF = hull, CFrame.new(offset)
  local servo
  if steerable then
    -- ดุมต้อง **มีมวลจริง** ห้าม Massless: เซอร์โวดันของที่ไม่มีมวลไม่ได้ ล้อจะสะบัดไปมาทันที
    local hub = Instance.new("Part")
    hub.Name = "Hub"
    hub.Size = Vector3.new(1.1, 1.1, 1.1)
    hub.CFrame = wheelCF
    hub.Transparency = 1
    hub.CanCollide = false
    hub.CanQuery = false
    hub.Massless = false
    hub.Anchored = false
    hub.CustomPhysicalProperties = PHYS(w.hubDensity or 6, 0.3, 0, 1, 1)
    hub.CollisionGroup = "VehicleWheel"
    hub:SetAttribute("NoWeld", true)
    hub.Parent = model

    -- แกนของ HingeConstraint = แกน X ของ Attachment0 → หมุน 90 องศารอบ Z เพื่อให้แกนชี้ขึ้นฟ้า
    local up = CFrame.Angles(0, 0, math.pi / 2)
    servo = Instance.new("HingeConstraint")
    servo.Name = "Steer"
    servo.Attachment0 = attach(hull, CFrame.new(offset) * up, "SteerBase")
    servo.Attachment1 = attach(hub, up, "SteerHub")
    servo.ActuatorType = Enum.ActuatorType.Servo
    servo.ServoMaxTorque = spec.servoTorque or 200000
    servo.AngularSpeed = spec.steerSpeed or 4
    servo.TargetAngle = 0
    servo.LimitsEnabled = true
    servo.UpperAngle = spec.steerAngle or 26
    servo.LowerAngle = -(spec.steerAngle or 26)
    servo.Parent = hull

    anchorPart, anchorCF = hub, CFrame.new()
  end

  local motor = Instance.new("HingeConstraint")
  motor.Name = "Drive"
  motor.Attachment0 = attach(anchorPart, anchorCF, "AxleBase")
  motor.Attachment1 = attach(wheel, CFrame.new(), "AxleWheel")
  motor.ActuatorType = Enum.ActuatorType.Motor
  motor.MotorMaxTorque = 0
  motor.MotorMaxAcceleration = spec.maxAccel or 120
  motor.AngularVelocity = 0
  motor.Parent = anchorPart

  return { wheel = wheel, motor = motor, servo = servo }
end

-- ---------------------------------------------------------------- ชิ้นส่วนที่หมุนได้
-- ล้อพาย ใบพัด เฟืองข้างรถ: หมุนจริงด้วยมอเตอร์ ไม่ใช่อนิเมชันหลอก
-- หลักการเดียวกับล้อรถ — ต้องเป็น assembly แยกจากตัวถัง ต่อด้วย HingeConstraint แบบ Motor
-- แกนหมุน = **แกน X ของ cf ที่ส่งมา** ตรงกับกติกาของ K.paddleWheel / K.propeller / K.gear พอดี
--
-- ดุม (hub) เป็นชิ้นเดียวที่มีมวลจริง ของสวยงามที่เชื่อมกับมันเป็น Massless ทั้งหมด
-- โมเมนต์ความเฉื่อยจึงเกือบศูนย์ มอเตอร์สั่งหยุด/เร่งได้ทันทีโดยไม่ดึงตัวถังให้โคลง
-- **ต้องเรียกหลัง Chassis.finalize เท่านั้น** ไม่งั้นชิ้นส่วนจะถูกเชื่อมติดตัวถังไปแล้ว หมุนไม่ได้
function Chassis.spinner(model, hull, cf, opts, build)
  opts = opts or {}
  local hub = Instance.new("Part")
  hub.Name = (opts.name or "Spinner") .. "Hub"
  hub.Size = Vector3.new(1.2, 1.2, 1.2)
  hub.CFrame = cf
  hub.Transparency = 1
  hub.CanCollide = false
  hub.CanQuery = false
  hub.Anchored = false
  hub.CustomPhysicalProperties = PHYS(1, 0.3, 0, 1, 1)
  hub.CollisionGroup = "VehicleWheel"
  hub:SetAttribute("NoWeld", true)
  hub.Parent = model

  local motor = Instance.new("HingeConstraint")
  motor.Name = "Spin"
  motor.Attachment0 = attach(hull, hull.CFrame:ToObjectSpace(cf), "SpinBase")
  motor.Attachment1 = attach(hub, CFrame.new(), "SpinHub")
  motor.ActuatorType = Enum.ActuatorType.Motor
  motor.MotorMaxTorque = opts.torque or 9000
  motor.MotorMaxAcceleration = opts.accel or 60
  motor.AngularVelocity = 0
  motor.Parent = hull

  local group = Instance.new("Model")
  group.Name = opts.name or "Spinner"
  group.Parent = model
  build(group)
  for _, d in ipairs(group:GetDescendants()) do
    if d:IsA("BasePart") then
      d.Anchored = false
      d.Massless = true
      d.CanCollide = false
      d.CanQuery = false
      d.CollisionGroup = "VehicleWheel"
      d:SetAttribute("NoWeld", true)
      local w = Instance.new("WeldConstraint")
      w.Part0 = hub
      w.Part1 = d
      w.Parent = hub
    end
  end
  return { hub = hub, motor = motor, dir = opts.dir or 1, name = opts.name }
end

-- ---------------------------------------------------------------- แรงแบบเรือ/เรือเหาะ
-- VectorForce ตัวเดียวพิกัดโลก (ลอยตัว + เดินหน้า + แรงต้าน รวมกันเป็นเวกเตอร์เดียว)
-- AlignOrientation คุมทิศ: ตัวเรือไม่มีทางพลิกคว่ำ และการเลี้ยวคือการหมุนเป้าหมายทีละนิด
function Chassis.forceRig(hull, opts)
  opts = opts or {}
  local a = attach(hull, CFrame.new(), "ForceAttach")

  local force = Instance.new("VectorForce")
  force.Name = "Drive"
  force.Attachment0 = a
  force.RelativeTo = Enum.ActuatorRelativeTo.World
  force.ApplyAtCenterOfMass = true
  force.Force = Vector3.zero
  force.Parent = hull

  local align = Instance.new("AlignOrientation")
  align.Name = "Level"
  align.Attachment0 = a
  align.Mode = Enum.OrientationAlignmentMode.OneAttachment
  align.RigidityEnabled = false
  align.MaxTorque = opts.torque or 900000
  align.MaxAngularVelocity = opts.angularVelocity or 2.2
  align.Responsiveness = opts.responsiveness or 22
  align.CFrame = hull.CFrame - hull.CFrame.Position
  align.Parent = hull

  return { attachment = a, force = force, align = align }
end

return Chassis
