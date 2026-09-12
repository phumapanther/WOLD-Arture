-- Vehicle/Drive — ตัวขับเคลื่อน 3 แบบ ทำงานฝั่งเซิร์ฟเวอร์ทั้งหมด
--
-- อินพุตของคนขับไม่ต้องทำ RemoteEvent เอง: VehicleSeat ส่ง Throttle/Steer จากไคลเอนต์ที่นั่งอยู่
-- มาให้เซิร์ฟเวอร์เองอยู่แล้ว (W/S = ThrottleFloat, A/D = SteerFloat)
-- มีแค่ "ขึ้น/ลง" ของเรือเหาะที่ไม่มีในเบาะ จึงส่งผ่าน Attribute "Lift" ที่เซ็ตโดย VehicleService
--
-- Wheels : ล้อจริง + HingeConstraint (Motor ที่ล้อหลัง, Servo ที่ดุมล้อหน้า)
-- Float  : VectorForce พิกัดโลก = แรงลอย + แรงเดินหน้า + แรงต้าน, AlignOrientation คุมทิศ
-- Hover  : เหมือน Float แต่แทนแรงลอยด้วยสปริงรักษาระดับความสูง (targetY)
local Drive = {}
Drive.__index = Drive

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- ยิงเรย์ลงไปหาผิวน้ำ กรองเฉพาะ Terrain (IgnoreWater = false ถึงจะโดนน้ำ)
local WATER_RAY = RaycastParams.new()
WATER_RAY.FilterType = Enum.RaycastFilterType.Include
WATER_RAY.FilterDescendantsInstances = { workspace.Terrain }
WATER_RAY.IgnoreWater = false

function Drive.new(record)
  local self = setmetatable({}, Drive)
  self.record = record
  self.model = record.model
  self.hull = record.hull
  self.spec = record.spec
  self.mode = record.spec.drive
  self.seat = record.driveSeat
  self.yaw = select(2, record.hull.CFrame:ToOrientation())
  self.targetY = record.hull.Position.Y
  return self
end

function Drive:inputs()
  local throttle, steer, lift, occupied = 0, 0, 0, false

  -- ช่องสำหรับสคริปต์ทดสอบ: Vector3(throttle, steer, lift) บนตัวโมเดล = ขับโดยไม่ต้องมีคนนั่ง
  local forced = self.model:GetAttribute("TestInput")
  if forced then
    throttle, steer, lift, occupied = clamp(forced.X, -1, 1), clamp(forced.Y, -1, 1), clamp(forced.Z, -1, 1), true
  else
    local seat = self.seat
    occupied = seat ~= nil and seat.Occupant ~= nil
    if occupied then
      throttle = clamp(seat.ThrottleFloat, -1, 1)
      steer = clamp(seat.SteerFloat, -1, 1)
      lift = clamp(self.model:GetAttribute("Lift") or 0, -1, 1)
    end
  end

  -- พลังงานหมด = เครื่องดับ เหลือแต่หางเสือ (เลี้ยวได้ตอนไหล) และการลดระดับของเรือเหาะ
  if (self.record.fuel or 0) <= 0 then
    throttle = 0
    lift = math.min(lift, 0)
  end
  return throttle, steer, lift, occupied
end

-- เผาเชื้อเพลิงตามภาระเครื่อง แล้วส่งค่าให้ไคลเอนต์เป็นเปอร์เซ็นต์ (ปัดทีละ 1% กัน replicate ถี่)
function Drive:burn(occupied, dt)
  local spec = self.spec.fuel
  local rec = self.record
  if not spec or rec.fuel == nil then return end
  if occupied and rec.fuel > 0 then
    local load = spec.idle + spec.drive * math.abs(self._pubThrottle or 0)
    rec.fuel = math.max(0, rec.fuel - load * dt)
    if rec.fuel <= 0 and rec.onEmpty then rec.onEmpty(rec) end
  end
  local pct = math.floor(rec.fuel / spec.max * 100 + 0.5)
  if pct ~= self._pubFuel then
    self._pubFuel = pct
    self.model:SetAttribute("Fuel", pct)
  end
end

-- ชิ้นส่วนที่หมุน (ล้อพาย ใบพัด เฟือง) — มอเตอร์จริง ไม่ใช่อนิเมชัน
-- เร่งอยู่ = หมุนตามคันเร่ง, ปล่อยคันเร่ง = หมุนเอื่อยตามความเร็วที่ยังเหลือ แล้วค่อยๆ หยุดเอง
function Drive:spin(throttle, speed)
  local list = self.record.spinners
  if not list or #list == 0 then return end
  local drive = math.abs(throttle) > 0.05 and throttle or clamp(speed / 14, -1, 1)
  local rate = -drive * (self.spec.spinRate or 12)
  if math.abs((self._spin or 1e9) - rate) < 0.25 then return end   -- อย่าเขียนค่าลง constraint ทุกเฟรม
  self._spin = rate
  for _, s in ipairs(list) do
    s.motor.AngularVelocity = rate * (s.dir or 1)
  end
end

-- ค่าที่ฝั่งไคลเอนต์เอาไปทำเสียง/หน้าจอ ปัดหยาบๆ ให้ replicate เฉพาะตอนเปลี่ยนจริง
function Drive:publish(throttle, speed)
  local t = math.floor(throttle * 8 + 0.5) / 8
  if t ~= self._pubThrottle then
    self._pubThrottle = t
    self.model:SetAttribute("Throttle", t)
  end
  local v = math.floor(math.abs(speed))
  if v ~= self._pubSpeed then
    self._pubSpeed = v
    self.model:SetAttribute("Speed", v)
  end
end

-- ควันกับไฟในเตาแรงขึ้นตามคันเร่ง — ตัวบอกว่าเครื่องกำลังทำงานโดยไม่ต้องมีอนิเมชัน
function Drive:stoke(throttle)
  local want = math.abs(throttle)
  if math.abs((self._stoke or -1) - want) < 0.2 then return end
  self._stoke = want
  for _, d in ipairs(self.model:GetDescendants()) do
    if d:IsA("Smoke") then
      d.RiseVelocity = 4 + want * 14
      d.Opacity = 0.18 + want * 0.25
    elseif d.Name == "Firebox" and d:IsA("BasePart") then
      d.Transparency = 0.55 - want * 0.5
    end
  end
end

-- ---------------------------------------------------------------- ล้อ
function Drive:stepWheels(dt)
  local spec = self.spec
  local throttle, steer, _, occupied = self:inputs()
  local speed = self.hull.CFrame.LookVector:Dot(self.hull.AssemblyLinearVelocity)
  self:stoke(throttle)
  self:spin(throttle, speed)
  self:publish(throttle, speed)
  -- มุมเลี้ยวหรี่ลงตามความเร็ว: 26° ตอนคลานในลานจอด เหลือ ~12° ตอนวิ่งเต็มที่
  -- ล้อหน้าที่บิดสุดตอนวิ่งเร็วคือต้นเหตุของทั้งอาการส่ายและอาการพลิก
  local fade = clamp(math.abs(speed) / (spec.steerFadeSpeed or 42), 0, 1)
  local maxAngle = spec.steerAngle * (1 - fade * (1 - (spec.steerFade or 0.45)))
  for _, w in ipairs(self.record.wheels) do
    if w.servo then
      w.servo.TargetAngle = -steer * maxAngle
      -- ล้อหน้าหมุนฟรีตอนเร่ง แต่หน่วงเบาๆ ตอนถอนคันเร่ง ไม่งั้นล้อฟรีจะสะบัดตอนเลี้ยว
      w.motor.MotorMaxTorque = (math.abs(throttle) > 0.05) and 0 or spec.brakeTorque * (spec.frontBrake or 0.3)
      w.motor.AngularVelocity = 0
    else
      if occupied and math.abs(throttle) > 0.05 then
        w.motor.MotorMaxTorque = spec.torque
        w.motor.AngularVelocity = -throttle * spec.maxSpeed
      else
        w.motor.MotorMaxTorque = spec.brakeTorque * (occupied and 0.5 or 1)
        w.motor.AngularVelocity = 0
      end
    end
  end
end

-- ---------------------------------------------------------------- ร่วมกันของเรือ/เรือเหาะ
-- เลี้ยวคือการหมุน "ทิศเป้าหมาย" ทีละนิด แล้วปล่อยให้ AlignOrientation ลากตัวเรือตามไป
-- ผลพลอยได้คือเรือไม่มีทางพลิกคว่ำ ซึ่งเป็นสิ่งที่ผู้เล่นคาดหวังจากเรือโดยสาร
function Drive:steerYaw(steer, dt, speed)
  local spec = self.spec
  local factor = spec.minTurn + (1 - spec.minTurn) * clamp(math.abs(speed) / 12, 0, 1)
  self.yaw -= steer * spec.turnRate * factor * dt
end

-- ตั้งทิศเป้าหมายของลำ (หันซ้ายขวา + เชิด/ปักหัว) เขียนลง constraint เฉพาะตอนค่าขยับจริง
-- เพราะพร็อพเพอร์ตี้ของ constraint replicate ทุกครั้งที่เขียน ถ้าเขียนทุกเฟรมคือส่งข้ามเน็ต 60 ครั้ง/วินาที
function Drive:orient(pitch)
  pitch = pitch or 0
  if math.abs(pitch - (self._pitchSet or 9)) < 0.004 and math.abs(self.yaw - (self._yawSet or 9e9)) < 0.004 then return end
  self._pitchSet, self._yawSet = pitch, self.yaw
  self.record.rig.align.CFrame = CFrame.Angles(0, self.yaw, 0) * CFrame.Angles(pitch, 0, 0)
end

function Drive:planarForce(throttle, mass)
  local spec = self.spec
  local vel = self.hull.AssemblyLinearVelocity
  local flat = Vector3.new(vel.X, 0, vel.Z)
  local look = self.hull.CFrame.LookVector
  local dir = Vector3.new(look.X, 0, look.Z)
  if dir.Magnitude < 1e-3 then dir = Vector3.new(0, 0, -1) else dir = dir.Unit end
  local push = Vector3.zero
  if math.abs(throttle) > 0.05 and flat.Magnitude < spec.maxSpeed then
    push = dir * (throttle > 0 and throttle * spec.power or throttle * spec.power * spec.reverse) * mass
  end
  return push - flat * spec.drag * mass
end

-- ผิวน้ำอยู่ที่ระดับไหน และเป็นน้ำ terrain จริงหรือเปล่า (เช็กทุก 0.15 วิ ไม่ต้องทุกเฟรม)
--
-- วัดแล้ว: น้ำ terrain ของ Roblox **ไม่ได้ลอยเรือลำนี้ให้** (ปิดแรงของเราแล้วเรือจมนิ่งๆ 1 stud/s)
-- มันให้แค่แรงหน่วง เพราะกล่องชนตั้งความหนาแน่นไว้ 1.0 เท่าน้ำพอดี แรงลอยจึงเป็นหน้าที่ของสคริปต์นี้ล้วนๆ
-- ข้อดีของการยิงเรย์แทนการอ่านค่าคงที่: ใช้กับแมพจริงที่ผิวน้ำอยู่ระดับไหนก็ได้ ไม่ต้องตั้ง WaterLevel เอง
function Drive:waterSurface()
  local now = os.clock()
  if self._waterAt and now - self._waterAt < 0.15 then return self._waterY, self._waterTerrain end
  self._waterAt = now
  local hit = workspace:Raycast(self.hull.Position + Vector3.new(0, 60, 0), Vector3.new(0, -160, 0), WATER_RAY)
  if hit and hit.Material == Enum.Material.Water then
    self._waterY, self._waterTerrain = hit.Position.Y, true
  else
    self._waterY = self.model:GetAttribute("WaterLevel") or workspace:GetAttribute("WaterLevel") or 0
    self._waterTerrain = false
  end
  return self._waterY, self._waterTerrain
end

-- ---------------------------------------------------------------- เรือ
function Drive:stepFloat(dt)
  local spec, hull = self.spec, self.hull
  local throttle, steer, _, occupied = self:inputs()
  self:stoke(throttle)

  local mass = hull.AssemblyMass
  local g = workspace.Gravity
  local waterY = self:waterSurface()
  local depth = waterY - (hull.Position.Y - hull.Size.Y / 2)
  local vel = hull.AssemblyLinearVelocity
  local speed = hull.CFrame.LookVector:Dot(vel)

  self:spin(throttle, speed)
  self:publish(throttle, speed)

  local force = Vector3.zero
  if depth > 0 then
    -- ลอยนิ่งพอดีที่ depth = draft ลึกกว่านั้นดันขึ้น ตื้นกว่านั้นจม
    local lift = clamp(1 + spec.buoyancy * (depth - spec.draft) / spec.draft, 0, spec.maxLift or 1.8)
    local a = g * lift - vel.Y * spec.verticalDamp
    if vel.Y > 22 then a = math.min(a, 0) end        -- พุ่งขึ้นเร็วขนาดนี้แปลว่าเพี้ยนแล้ว อย่าเติมแรงอีก
    -- เพดานกว้างพอให้ "ตัวหน่วง" ทำงานได้เต็มที่ ถ้าบีบแคบไปตัวหน่วงจะโดนตัดตอนที่ต้องใช้ที่สุด
    force = Vector3.new(0, mass * clamp(a, -g * 4, g * 4), 0)
    force += self:planarForce(throttle, mass)
    if occupied then self:steerYaw(steer, dt, speed) end
  end
  self:orient(0)
  self.record.rig.force.Force = force
end

-- ---------------------------------------------------------------- เรือเหาะ
function Drive:stepHover(dt)
  local spec, hull = self.spec, self.hull
  local throttle, steer, lift, occupied = self:inputs()
  self:stoke(throttle)

  local mass = hull.AssemblyMass
  local g = workspace.Gravity
  local vel = hull.AssemblyLinearVelocity
  local speed = hull.CFrame.LookVector:Dot(vel)

  local empty = (self.record.fuel or 1) <= 0
  local aim = occupied and clamp(self.model:GetAttribute("Aim") or 0, -1, 1) or 0

  if occupied and math.abs(lift) > 0.05 then
    self.targetY = clamp(self.targetY + lift * spec.climbRate * dt, spec.minAlt, spec.maxAlt)
  end
  -- **บังคับด้วยมุมเล็งกล้อง**: ไต่/ดิ่งได้ก็ต่อเมื่อกำลังเดินหน้าอยู่ เหมือนเครื่องบินที่ต้องมีความเร็วก่อน
  -- อัตราไต่ = ความเร็วเดินหน้า × มุมเล็ง จอดนิ่งแล้วเงยกล้องจึงไม่ลอยขึ้นเอง (ใช้ R/F แทน)
  if not empty and math.abs(aim) > 0.04 and math.abs(speed) > 3 then
    self.targetY = clamp(self.targetY + speed * aim * (spec.aimClimb or 0.9) * dt, spec.minAlt, spec.maxAlt)
  end
  if empty then
    self.targetY = math.max(spec.minAlt, self.targetY - (spec.emptyDescent or 11) * dt)
  end
  -- ถ้าถูกดันจนหลุดจากระดับที่ตั้งไว้มาก (ชนภูเขา/โดนยก) ให้ยอมตามของจริงแทนที่จะดันสู้
  if math.abs(self.targetY - hull.Position.Y) > 60 then self.targetY = hull.Position.Y end

  self:spin(throttle, speed)
  self:publish(throttle, speed)

  local accel = clamp(g + spec.hoverP * (self.targetY - hull.Position.Y) - spec.hoverD * vel.Y, 0, g * 3)
  local force = Vector3.new(0, mass * accel, 0) + self:planarForce(throttle, mass)
  self.record.rig.force.Force = force
  if occupied then self:steerYaw(steer, dt, speed) end

  -- ท่าทางของลำ: ปักหัวลงตอนเชื้อเพลิงหมด นอกนั้นเชิดตามมุมเล็งเท่าที่มีความเร็วรองรับ
  local want = empty and -math.rad(spec.emptyPitch or 13)
    or math.rad(spec.aimPitch or 26) * aim * clamp(math.abs(speed) / 12, 0, 1)
  self.pitch = (self.pitch or 0) + (want - (self.pitch or 0)) * math.min(1, dt * 3)
  self:orient(self.pitch)
  self.model:SetAttribute("Altitude", math.floor(hull.Position.Y))
end

function Drive:step(dt)
  if not self.hull.Parent then return end
  if self.mode == "Wheels" then self:stepWheels(dt)
  elseif self.mode == "Float" then self:stepFloat(dt)
  else self:stepHover(dt) end
  self:burn(self.seat ~= nil and self.seat.Occupant ~= nil, dt)
end

return Drive
