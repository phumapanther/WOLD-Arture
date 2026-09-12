-- Vehicle/Models — ตัวถังสตีมพังก์ทั้งสามชนิด
--
-- พิกัดท้องถิ่นเหมือนทุกโปรเจ็คในชุด WOLD: ฐานอยู่ที่ y = 0, กึ่งกลางที่ x = 0, **หน้า = -Z**
-- ทุกฟังก์ชันคืน Model ที่ยังไม่ได้ PivotTo ไปไหน มี Hull เป็น PrimaryPart และเชื่อมทุกชิ้นแล้ว
local K = require(game.ServerScriptService.Vehicle.Kit)
local Chassis = require(game.ServerScriptService.Vehicle.Chassis)

local MAT = Enum.Material
local Models = {}

local function detail(model) local f = Instance.new("Folder"); f.Name = "Detail"; f.Parent = model; return f end

local function railRun(m, y, x, z0, z1, color)                    -- ราวกันตก: คานบนกับเสาห้าต้น
  K.rod(m, Vector3.new(x, y, z0), Vector3.new(x, y, z1), 0.12, MAT.Metal, color, { cancollide = false })
  for i = 0, 4 do
    local z = z0 + (z1 - z0) * i / 4
    K.rod(m, Vector3.new(x, y - 1.5, z), Vector3.new(x, y, z), 0.11, MAT.Metal, color, { cancollide = false })
  end
end

-- ---------------------------------------------------------------- รถไอน้ำ
function Models.Car(spec)
  local C = K.C
  local m = Instance.new("Model")
  m.Name = "SteamCar"
  local hull = Chassis.hull(m, CFrame.new(0, spec.ride + 0.3, 0), spec.hull, spec.hullDensity)
  local d = detail(m)

  -- โครงล่าง: คานเหล็กสองเส้นกับเพลา
  for _, x in ipairs({ -2.6, 2.6 }) do
    K.box(d, CFrame.new(x, 1.5, 0), Vector3.new(0.6, 0.5, 13), MAT.Metal, C.iron, { cancollide = false })
  end
  K.cylX(d, CFrame.new(0, 1.9, spec.axles.rear), 0.3, 8.6, MAT.Metal, C.steel, { cancollide = false })
  K.cylX(d, CFrame.new(0, 1.9, spec.axles.front), 0.28, 8.6, MAT.Metal, C.steel, { cancollide = false })

  -- พื้นห้องโดยสารกับตัวถัง
  K.plankFloor(d, CFrame.new(0, 3.3, 0.5), 6, 10, 1.4, C.plank)
  K.box(d, CFrame.new(0, 4.2, -3.4), Vector3.new(6.2, 1.8, 3.6), MAT.Metal, C.paintGreen, { cancollide = false, name = "Cowl" })
  K.box(d, CFrame.new(0, 5.2, -3.4), Vector3.new(5.4, 0.4, 3.2), MAT.Metal, C.brass, { cancollide = false })
  for _, x in ipairs({ -3.15, 3.15 }) do                          -- แผงข้างบานประตู
    K.box(d, CFrame.new(x, 4.1, 0.6), Vector3.new(0.35, 1.7, 7), MAT.Metal, C.paintGreen, { cancollide = false })
    K.rivets(d, Vector3.new(x, 4.85, -2.6), Vector3.new(x, 4.85, 3.6), 9, 0.11, C.brass)
  end
  K.box(d, CFrame.new(0, 4.1, 4.3), Vector3.new(6.2, 1.7, 0.4), MAT.Metal, C.paintGreen, { cancollide = false })

  -- หม้อไอน้ำท้ายรถ + ปล่อง
  K.boiler(d, CFrame.new(0, 5.1, 5.6), 1.7, 3.4, { firebox = true, bands = 2, color = C.copper })
  K.smokestack(d, CFrame.new(0, 6.8, 5.6), 0.5, 2.4, { smoke = true })
  K.pipe(d, { Vector3.new(0, 4.2, 4.2), Vector3.new(0, 4.6, 2.2), Vector3.new(-1.6, 4.6, -2.4), Vector3.new(-1.6, 4.4, -4.4) }, 0.22, C.copper)
  K.valveWheel(d, CFrame.new(1.9, 5.6, 5.2) * K.yaw(math.pi / 2), 0.8, 5, C.brass)
  K.gauge(d, CFrame.new(-1.5, 5.0, -2.0) * K.yaw(math.pi / 2), 0.45, C.brass)

  -- พวงมาลัยวาล์ว + เบาะหนัง (ที่นั่งจริงสร้างทีหลัง ตรงนี้เป็นของตกแต่ง)
  K.valveWheel(d, CFrame.new(-1.3, 4.7, -2.2) * K.yaw(math.pi / 2) * K.pitch(math.rad(-25)), 0.85, 6, C.brassDark)
  K.box(d, CFrame.new(-1.3, 3.9, -0.6), Vector3.new(2.2, 0.4, 2.2), MAT.Fabric, C.leather, { cancollide = false })
  K.box(d, CFrame.new(1.3, 3.9, -0.6), Vector3.new(2.2, 0.4, 2.2), MAT.Fabric, C.leather, { cancollide = false })
  K.box(d, CFrame.new(0, 3.9, 2.2), Vector3.new(5, 0.4, 2.2), MAT.Fabric, C.leather, { cancollide = false })
  K.box(d, CFrame.new(0, 4.7, 3.3), Vector3.new(5, 2, 0.4), MAT.Fabric, C.leather, { cancollide = false })

  -- โคมหน้า บังโคลน กันชน
  for _, x in ipairs({ -2.3, 2.3 }) do
    K.lantern(d, CFrame.new(x, 4.9, -5.1), 1.1, C.lamp)
    K.wedge(d, CFrame.new(x * 1.3, 3.2, spec.axles.front) * K.yaw(math.pi), Vector3.new(2.6, 1, 5.2), MAT.Metal, C.brassDark, { cancollide = false })
    K.wedge(d, CFrame.new(x * 1.3, 3.2, spec.axles.rear), Vector3.new(2.6, 1, 5.2), MAT.Metal, C.brassDark, { cancollide = false })
  end
  K.box(d, CFrame.new(0, 3.0, -6.9), Vector3.new(6.6, 0.5, 0.5), MAT.Metal, C.brass, { cancollide = false })
  K.rivets(d, Vector3.new(-3, 3.0, -6.9), Vector3.new(3, 3.0, -6.9), 7, 0.12, C.brassDark)

  -- ลังท้ายรถ = ช่องเก็บของ (จุดที่ ProximityPrompt เปิดท้ายไปเกาะ)
  local trunk = K.crate(d, CFrame.new(0, 3.5, 6.4), 2.4, C.oak)
  trunk.Name = "TrunkLid"

  Chassis.finalize(m, hull)

  -- ล้อ: คู่หลังเป็นตัวขับ คู่หน้าเลี้ยว
  local wheels = {}
  for _, side in ipairs({ -1, 1 }) do
    wheels[#wheels + 1] = Chassis.wheel(m, hull, Vector3.new(side * spec.axles.track, -0.3, spec.axles.rear), spec, false)
    wheels[#wheels + 1] = Chassis.wheel(m, hull, Vector3.new(side * spec.axles.track, -0.3, spec.axles.front), spec, true)
  end
  -- ซี่ล้อทองเหลือง เชื่อมติดวงล้อแต่ละวง (หมุนไปกับล้อจริง)
  for _, w in ipairs(wheels) do
    local wheel = w.wheel
    local sp = Instance.new("Model"); sp.Name = "Spokes"; sp.Parent = wheel
    for i = 0, 7 do
      local a = i * math.pi / 4
      local p = K.box(sp, wheel.CFrame * CFrame.Angles(a, 0, 0) * CFrame.new(0, spec.wheel.radius * 0.5, 0),
        Vector3.new(spec.wheel.width * 0.5, spec.wheel.radius, 0.22), MAT.Metal, C.brass, { cancollide = false })
      p.Anchored = false
      p.Massless = true
      p.CanQuery = false
      local weld = Instance.new("WeldConstraint"); weld.Part0 = wheel; weld.Part1 = p; weld.Parent = wheel
    end
  end

  -- เฟืองส่งกำลังข้างตัวถัง หมุนตามความเร็วรถ
  local spinners = {}
  for _, x in ipairs({ -3.4, 3.4 }) do
    local at = CFrame.new(x, 2.6, 1.6)
    spinners[#spinners + 1] = Chassis.spinner(m, hull, at,
      { name = x < 0 and "GearLeft" or "GearRight", torque = 4000 },
      function(g) K.gear(g, at, 1.1, 12, 0.3, C.brass) end)
  end

  local seats = {
    Chassis.seat(m, hull, hull.CFrame * CFrame.new(-1.3, 1.6, -0.6), "driver"),
    Chassis.seat(m, hull, hull.CFrame * CFrame.new(1.3, 1.6, -0.6), "passenger", "PassengerSeat1"),
    Chassis.seat(m, hull, hull.CFrame * CFrame.new(0, 1.6, 2.2), "passenger", "PassengerSeat2"),
  }
  return m, { seats = seats, wheels = wheels, spinners = spinners, trunkPart = trunk:FindFirstChildWhichIsA("BasePart") }
end

-- ---------------------------------------------------------------- เรือไอน้ำ
function Models.Boat(spec)
  local C = K.C
  local m = Instance.new("Model")
  m.Name = "SteamBoat"
  local hull = Chassis.hull(m, CFrame.new(0, 2, 0), spec.hull, spec.hullDensity)
  local d = detail(m)

  -- ตัวเรือ: ท้องเรือ + หัวเรือลิ่ม + กราบเรือ
  K.box(d, CFrame.new(0, 1.6, 1), Vector3.new(11, 3.2, 26), MAT.Wood, C.wood, { cancollide = false, name = "HullBody" })
  K.wedge(d, CFrame.new(0, 1.6, -14.5) * K.yaw(math.pi), Vector3.new(11, 3.2, 5), MAT.Wood, C.wood, { cancollide = false, name = "Bow" })
  K.box(d, CFrame.new(0, 3.4, -15.6), Vector3.new(1.4, 2.6, 3.4), MAT.Metal, C.brass, { cancollide = false, name = "Prow" })
  K.plankFloor(d, CFrame.new(0, 3.9, 0), 10.4, 28, 1.6, C.plank)
  for _, x in ipairs({ -5.3, 5.3 }) do
    K.box(d, CFrame.new(x, 4.5, 0), Vector3.new(0.5, 1.4, 28), MAT.Wood, C.plankDark, { cancollide = false })
    K.rivets(d, Vector3.new(x, 5.1, -13), Vector3.new(x, 5.1, 13), 14, 0.13, C.brass)
    K.porthole(d, CFrame.new(x, 2.6, -6) * K.yaw(math.pi / 2), 0.8)
    K.porthole(d, CFrame.new(x, 2.6, -2) * K.yaw(math.pi / 2), 0.8)
    railRun(d, 6.2, x, -12, 12, C.brassDark)
  end

  -- ห้องเครื่อง: หม้อไอน้ำคู่ + ปล่องคู่
  K.box(d, CFrame.new(0, 5.3, 7.5), Vector3.new(8, 2.6, 8), MAT.Wood, C.plankDark, { cancollide = false, name = "EngineHouse" })
  K.box(d, CFrame.new(0, 6.7, 7.5), Vector3.new(8.6, 0.4, 8.6), MAT.Metal, C.brassDark, { cancollide = false })
  for _, x in ipairs({ -1.9, 1.9 }) do
    K.boiler(d, CFrame.new(x, 8.3, 7.5), 1.5, 2.8, { firebox = true, color = C.copper })
    K.smokestack(d, CFrame.new(x, 9.7, 7.5), 0.6, 4.2, { smoke = true })
  end
  K.pipe(d, { Vector3.new(-1.9, 6.9, 5.5), Vector3.new(-1.9, 5.6, 3.5), Vector3.new(1.9, 5.6, 3.5), Vector3.new(1.9, 6.9, 5.5) }, 0.26, C.copper)
  K.valveWheel(d, CFrame.new(0, 6.0, 3.3) * K.yaw(math.pi / 2), 1.1, 6, C.brass)
  K.gauge(d, CFrame.new(-2.6, 6.1, 3.4) * K.yaw(math.pi / 2), 0.5, C.brass)

  -- แขนยึดล้อพาย (ตัวล้อสร้างทีหลัง finalize เพราะต้องหมุนได้)
  for _, x in ipairs({ -6.4, 6.4 }) do
    K.box(d, CFrame.new(x * 0.86, 5.4, 6.5), Vector3.new(1.6, 0.5, 7), MAT.Metal, C.brassDark, { cancollide = false })
    K.cylX(d, CFrame.new(x * 0.92, 2.4, 6.5), 0.45, 1.6, MAT.Metal, C.iron, { cancollide = false, name = "PaddleBearing" })
  end

  -- หัวเรือ: พวงมาลัย โคม ลัง สมอ
  K.valveWheel(d, CFrame.new(0, 5.6, -9.4) * K.yaw(math.pi / 2) * K.pitch(math.rad(-20)), 1.3, 8, C.oak)
  K.box(d, CFrame.new(0, 4.6, -9.4), Vector3.new(1.6, 1.2, 0.6), MAT.Wood, C.plankDark, { cancollide = false })
  K.lantern(d, CFrame.new(0, 4.3, -13.6), 1.4, C.lamp)
  for _, x in ipairs({ -3.4, 3.4 }) do K.lantern(d, CFrame.new(x, 4.3, 12.4), 1.2, C.ember) end
  K.crate(d, CFrame.new(-3.2, 4.1, 11.4), 2.2, C.oak)
  local trunk = K.barrel(d, CFrame.new(3.2, 4.1, 11.4), 1.3, 2.6, C.wood)
  trunk.Name = "TrunkHatch"
  K.chain(d, Vector3.new(-4.6, 4.2, -12.4), Vector3.new(-4.6, 1.4, -14.2), 8, 0.13, C.iron)

  Chassis.finalize(m, hull)

  -- ล้อพายสองข้าง หมุนจริงด้วยมอเตอร์ (แกน X ของ cf = แกนเพลา)
  local spinners = {}
  for _, x in ipairs({ -6.4, 6.4 }) do
    local at = CFrame.new(x, 2.4, 6.5)
    spinners[#spinners + 1] = Chassis.spinner(m, hull, at,
      { name = x < 0 and "PaddleLeft" or "PaddleRight", torque = 14000 },
      function(g) K.paddleWheel(g, at, 3.2, 2.2, 8) end)
  end

  local seats = {
    Chassis.seat(m, hull, hull.CFrame * CFrame.new(0, 2.1, -7.4), "driver"),
    Chassis.seat(m, hull, hull.CFrame * CFrame.new(-2.6, 2.1, -3.4), "passenger", "PassengerSeat1"),
    Chassis.seat(m, hull, hull.CFrame * CFrame.new(2.6, 2.1, -3.4), "passenger", "PassengerSeat2"),
    Chassis.seat(m, hull, hull.CFrame * CFrame.new(0, 2.1, 0.6), "passenger", "PassengerSeat3"),
  }
  return m, { seats = seats, spinners = spinners, trunkPart = trunk:FindFirstChildWhichIsA("BasePart") }
end


-- ---------------------------------------------------------------- เรือเหาะ (เรือบอลลูน)
-- ทรงที่ผู้ใช้เลือก: **ลำเรือไม้จริงแขวนใต้บอลลูนกลม** ไม่ใช่เซปเปลินโครงแข็ง
-- ตัวที่ทำให้อ่านออกว่าเป็นบอลลูนคือ *ตาข่ายเชือก* ที่คลุมลูก ไม่ใช่รูปทรงลูกอย่างเดียว
-- และตัวที่ทำให้อ่านออกว่าเป็น *เรือ* คือหัวเรือแหลม เสาหัวเรือ ใบพายข้าง และหางเสือท้ายลำ

-- โปรไฟล์รัศมีของลูกบอลลูนจากล่างขึ้นบน (สัดส่วนของรัศมีสูงสุด) — ทรงหยดน้ำกลับหัว
local BALLOON = { 0.16, 0.40, 0.63, 0.81, 0.93, 1.00, 1.00, 0.96, 0.89, 0.78, 0.62, 0.40 }

local function profileAt(t)                                       -- t = 0 ก้นลูก, 1 ยอดลูก
  local x = math.clamp(t, 0, 1) * (#BALLOON - 1) + 1
  local i = math.floor(x)
  local f = x - i
  local a = BALLOON[math.min(i, #BALLOON)]
  local b = BALLOON[math.min(i + 1, #BALLOON)]
  return a + (b - a) * f
end

local function balloon(parent, base, height, radius, color)
  local m = K.model(parent, "Balloon")
  local rings = 18

  -- ผิวจริงของลูกคือ *เส้นรอบนอกของกลุ่มลูกกลมที่ซ้อนกัน* ไม่ใช่เส้นโปรไฟล์ที่ใช้วางลูก
  -- ลูกกลมแต่ละใบพองออกทุกทิศ ผิวจริงจึงอยู่นอกเส้นโปรไฟล์เสมอ
  -- ถ้าวางเชือกตามเส้นโปรไฟล์ เชือกจะจมอยู่ในลูกจนมองไม่เห็น (ลองมาแล้ว เห็นแค่ห่วงกลางลูก)
  local centres = {}
  for i = 0, rings do
    local t = i / rings
    centres[#centres + 1] = { y = height * t, r = radius * profileAt(t) }
  end
  local function surfaceAt(y)
    local best = 0
    for _, c in ipairs(centres) do
      local dy = y - c.y
      if math.abs(dy) < c.r then best = math.max(best, math.sqrt(c.r * c.r - dy * dy)) end
    end
    return best
  end

  for _, c in ipairs(centres) do
    if c.r > 0.4 then
      K.ball(m, CFrame.new(base + Vector3.new(0, c.y, 0)), c.r * 2, MAT.Fabric, color, { cancollide = false })
    end
  end

  -- ตาข่ายเชือก: สิ่งที่ทำให้อ่านออกว่าเป็น "บอลลูน" ไม่ใช่แค่ลูกกลมสีขาว
  -- เส้นตามยาวไล่จากปากลูกขึ้นไปบรรจบกันที่ยอด + ห่วงรัดตามขวางอีก 5 วง
  local rope = K.C.leather
  local yTop = centres[#centres].y + centres[#centres].r
  local yBase = 0
  local segs = 10
  for s = 0, 9 do
    local a = s * math.pi / 5
    local prev
    for i = 0, segs do
      local y = yBase + (yTop - yBase) * (i / segs)
      local r = surfaceAt(y) + 0.18
      local p = base + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
      if prev then K.rod(m, prev, p, 0.13, MAT.Fabric, rope, { cancollide = false }) end
      prev = p
    end
  end
  for _, f in ipairs({ 0.12, 0.3, 0.5, 0.7, 0.88 }) do
    local y = yBase + (yTop - yBase) * f
    local r = surfaceAt(y) + 0.18
    local prev
    for i = 0, 14 do
      local a = i * math.pi / 7
      local p = base + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
      if prev then K.rod(m, prev, p, 0.12, MAT.Fabric, rope, { cancollide = false }) end
      prev = p
    end
  end

  -- ปากลูกบอลลูน + เตาไฟที่พ่นขึ้นไปในลูก
  K.cyl(m, CFrame.new(base + Vector3.new(0, 0.4, 0)), radius * 0.2, 1.2, MAT.Metal, K.C.brassDark, { cancollide = false, name = "Mouth" })
  local flame = K.cyl(m, CFrame.new(base + Vector3.new(0, 0.8, 0)), radius * 0.13, 1.6, MAT.Neon, K.C.ember, { cancollide = false, name = "Firebox" })
  local light = Instance.new("PointLight")
  light.Color = K.C.ember
  light.Range = 26
  light.Brightness = 2
  light.Parent = flame
  return m
end

function Models.Airship(spec)
  local C = K.C
  local m = Instance.new("Model")
  m.Name = "SteamAirship"
  local hull = Chassis.hull(m, CFrame.new(0, 2, 0), spec.hull, spec.hullDensity)
  local d = detail(m)

  -- ---- ลำเรือไม้ ----
  K.box(d, CFrame.new(0, 1.7, 1), Vector3.new(9, 3.2, 20), MAT.Wood, C.oak, { cancollide = false, name = "HullBody" })
  K.wedge(d, CFrame.new(0, 1.7, -10.5) * K.yaw(math.pi), Vector3.new(9, 3.2, 5), MAT.Wood, C.oak, { cancollide = false, name = "Bow" })
  -- หัวเรือต้องสอบเข้าหากันเมื่อมองจากบน ไม่ใช่แค่ลาดลงเมื่อมองจากข้าง
  -- ลิ่มของ Roblox ลาดตามแกน Y อย่างเดียว จึงเติมแผ่นกราบเฉียงสองแผ่นให้บรรจบกันที่หัว
  for _, side in ipairs({ -1, 1 }) do
    K.box(d, CFrame.new(side * 2.5, 2.1, -10.6) * CFrame.Angles(0, side * math.rad(26), 0),
      Vector3.new(0.7, 3.6, 7), MAT.Wood, C.oak, { cancollide = false, name = "BowPlank" })
  end
  K.box(d, CFrame.new(0, 0.6, 1), Vector3.new(5.5, 1.2, 19), MAT.Wood, C.plankDark, { cancollide = false, name = "Keel" })
  K.plankFloor(d, CFrame.new(0, 3.4, 0), 8.4, 23, 1.5, C.plank)

  for _, x in ipairs({ -4.3, 4.3 }) do                            -- กราบเรือ + ราวไม้
    K.box(d, CFrame.new(x, 4.2, 0), Vector3.new(0.5, 1.5, 23), MAT.Wood, C.plankDark, { cancollide = false })
    K.rivets(d, Vector3.new(x, 4.9, -10), Vector3.new(x, 4.9, 10), 11, 0.12, C.brass)
    railRun(d, 5.9, x, -9, 10, C.brass)
    K.porthole(d, CFrame.new(x, 2.4, -4) * K.yaw(math.pi / 2), 0.7)
    K.lantern(d, CFrame.new(x, 3.6, 9.5), 1.1, C.lamp)
  end

  -- หัวเรือ: เสาหัวเรือยื่นออกไปพร้อมโคม และหัวเรือทองเหลือง
  K.box(d, CFrame.new(0, 3.2, -12.6), Vector3.new(1.2, 2.2, 2.6), MAT.Metal, C.brass, { cancollide = false, name = "Prow" })
  K.rod(d, Vector3.new(0, 3.8, -12.4), Vector3.new(0, 5.4, -18.5), 0.3, MAT.Wood, C.oak, { cancollide = false, name = "Bowsprit" })
  K.lantern(d, CFrame.new(0, 5.4, -18.5), 1.2, C.lamp)
  K.rod(d, Vector3.new(0, 5.4, -18.5), Vector3.new(0, 8.5, -10), 0.12, MAT.Fabric, C.rope, { cancollide = false })

  -- ท้ายเรือ: ดาดฟ้ายกและหางเสือไม้
  K.box(d, CFrame.new(0, 4.4, 9.5), Vector3.new(7.4, 1.4, 5), MAT.Wood, C.plankDark, { cancollide = false, name = "SternDeck" })
  railRun(d, 6.6, -3.4, 8, 11.5, C.brass)
  railRun(d, 6.6, 3.4, 8, 11.5, C.brass)
  K.box(d, CFrame.new(0, 2.2, 12.4), Vector3.new(0.5, 4.4, 3.2), MAT.Wood, C.oak, { cancollide = false, name = "Rudder" })
  K.rod(d, Vector3.new(0, 4.6, 12.2), Vector3.new(0, 5.4, 10.4), 0.18, MAT.Metal, C.brassDark, { cancollide = false, name = "Tiller" })

  -- ---- เครื่องไอน้ำกลางลำ ----
  K.box(d, CFrame.new(0, 4.6, 5.5), Vector3.new(6.4, 1.4, 6), MAT.Wood, C.plankDark, { cancollide = false, name = "EngineHouse" })
  K.boiler(d, CFrame.new(0, 6.4, 5.5), 1.5, 2.8, { firebox = true, color = C.copper })
  K.smokestack(d, CFrame.new(0, 7.8, 5.5), 0.5, 2.4, { smoke = true })
  K.pipe(d, { Vector3.new(0, 5.2, 3), Vector3.new(-2.2, 4.4, 3), Vector3.new(-4.6, 3.4, 4.4) }, 0.22, C.copper)
  K.pipe(d, { Vector3.new(0, 5.2, 3), Vector3.new(2.2, 4.4, 3), Vector3.new(4.6, 3.4, 4.4) }, 0.22, C.copper)
  K.gauge(d, CFrame.new(-1.8, 5.4, 3.2) * K.yaw(math.pi / 2), 0.45, C.brass)

  -- แขนยึดใบพายข้างลำ (ตัวใบพายสร้างหลัง finalize เพราะต้องหมุน)
  for _, x in ipairs({ -5.4, 5.4 }) do
    K.box(d, CFrame.new(x * 0.86, 3.4, 4.6), Vector3.new(2.2, 0.5, 5), MAT.Metal, C.brassDark, { cancollide = false })
    K.cylX(d, CFrame.new(x * 0.93, 2.6, 4.6), 0.42, 1.4, MAT.Metal, C.iron, { cancollide = false, name = "PaddleBearing" })
  end

  -- พวงมาลัยเรือหน้าเบาะคนขับ
  K.valveWheel(d, CFrame.new(0, 5.1, -7.6) * K.yaw(math.pi / 2) * K.pitch(math.rad(-18)), 1.2, 8, C.oak)
  K.box(d, CFrame.new(0, 4.2, -7.6), Vector3.new(1.6, 1.4, 0.6), MAT.Wood, C.plankDark, { cancollide = false })
  local trunk = K.crate(d, CFrame.new(-2.6, 3.6, 8.4), 2.1, C.oak)
  trunk.Name = "TrunkCrate"

  -- ---- บอลลูน + สายแขวน ----
  -- ลูกบอลลูนทรงกลมป้อม กว้างกว่าสูง (ทรงไข่ตั้งอ่านเป็นบอลลูนลมร้อนไม่ออก)
  -- แขวนสูงพ้นดาดฟ้าราว 7 studs เพื่อให้ "เชือกสาว" มีที่ให้เห็น — ถ้าลูกนั่งทับลำเรือจะดูเป็นก้อนเดียว
  local base = Vector3.new(0, 13, -0.5)
  balloon(d, base, 12, 11, C.canvas)
  K.box(d, CFrame.new(0, 12.2, -0.5), Vector3.new(5.5, 0.9, 13), MAT.Wood, C.oak, { cancollide = false, name = "Yoke" })
  for _, x in ipairs({ -3.8, 3.8 }) do
    for _, z in ipairs({ -7, -0.5, 6 }) do
      K.rod(d, Vector3.new(x, 4.6, z), Vector3.new(x * 0.45, 12.8, z * 0.5 - 0.2), 0.16, MAT.Fabric, C.leather, { cancollide = false })
    end
  end
  K.chain(d, Vector3.new(0, 5.4, -9.5), Vector3.new(0, 13.4, -5), 7, 0.14, C.iron)

  Chassis.finalize(m, hull)

  -- ใบพายข้างลำ หมุนจริงด้วยมอเตอร์ (แกน X ของ cf = แกนเพลา)
  local spinners = {}
  for _, x in ipairs({ -5.4, 5.4 }) do
    local at = CFrame.new(x, 2.6, 4.6)
    spinners[#spinners + 1] = Chassis.spinner(m, hull, at,
      { name = x < 0 and "PaddleLeft" or "PaddleRight", torque = 12000 },
      function(g) K.paddleWheel(g, at, 2.8, 1.8, 8) end)
  end

  local seats = {
    Chassis.seat(m, hull, hull.CFrame * CFrame.new(0, 1.7, -5.6), "driver"),
    Chassis.seat(m, hull, hull.CFrame * CFrame.new(-2.4, 1.7, -1.6), "passenger", "PassengerSeat1"),
    Chassis.seat(m, hull, hull.CFrame * CFrame.new(2.4, 1.7, -1.6), "passenger", "PassengerSeat2"),
    Chassis.seat(m, hull, hull.CFrame * CFrame.new(-2.4, 1.7, 2.4), "passenger", "PassengerSeat3"),
    Chassis.seat(m, hull, hull.CFrame * CFrame.new(2.4, 1.7, 2.4), "passenger", "PassengerSeat4"),
  }
  return m, { seats = seats, spinners = spinners, trunkPart = trunk:FindFirstChildWhichIsA("BasePart") }
end

return Models
