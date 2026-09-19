-- Vehicle/Models — ตัวถังสตีมพังก์ทั้งสามชนิด
--
-- พิกัดท้องถิ่นเหมือนทุกโปรเจ็คในชุด WOLD: ฐานอยู่ที่ y = 0, กึ่งกลางที่ x = 0, **หน้า = -Z**
-- ทุกฟังก์ชันคืน Model ที่ยังไม่ได้ PivotTo ไปไหน มี Hull เป็น PrimaryPart และเชื่อมทุกชิ้นแล้ว
local K = require(game.ServerScriptService.Vehicle.Kit)
local Chassis = require(game.ServerScriptService.Vehicle.Chassis)

local MAT = Enum.Material
local Models = {}

local function detail(model) local f = Instance.new("Folder"); f.Name = "Detail"; f.Parent = model; return f end

--------------------------------------------------------------------------------
-- ตัวช่วยทำผิวโค้ง (ใช้กับตัวถังรถ)
--------------------------------------------------------------------------------
-- ปั้นที่โรงงาน `WOLD-Models/models/vehicles.lua` แล้วคัดลอกตัวเลขมาตรงๆ — แก้ที่นั่นแล้วย้ายกลับมาที่นี่
--
-- **กฎที่ได้มาจากรอบที่พัง: หนึ่งผิว = กล่องบางแถวเดียวเรียงชนกันตามเส้นโค้ง**
-- ห้ามเอาทรงตันหลายชิ้นซ้อนทับกันเพื่อฝืนให้โค้ง (เคยทำแล้วได้ผิวมั่ว เห็นรอยเสียดสีทั่วคัน)
-- ของที่ทับผิวได้มีแค่ของที่เป็นคนละชิ้นจริงๆ — คิ้ว หมุด มือจับ ไฟ กระจก
local function bulgeRadius(w, h) return (w * w / 4 + h * h) / (2 * h) end

-- ส่วนโค้งในระนาบ Y-Z (บังโคลน ท้ายรถ ยอดกระจัง) กล่องกว้าง `width` ตามแกน X
local function arcYZ(d, x, yc, zc, r, fromDeg, toDeg, n, width, thick, mat, col, name)
  local step = math.rad(toDeg - fromDeg) / n
  for i = 0, n - 1 do
    local a = math.rad(fromDeg) + step * (i + 0.5)
    K.box(d, CFrame.new(x, yc + math.sin(a) * r, zc + math.cos(a) * r) * K.pitch(-(a + math.pi / 2)),
      Vector3.new(width, thick, math.abs(step) * r + thick * 1.6), mat, col, { name = name, cancollide = false })
  end
end

-- ผิวโค้งขวางลำตัว (หลังคา ฝากระโปรง) แล้วยืดยาว `len` ตามแกน Z
local function domeXY(d, xc, crownY, z, w, h, len, thick, mat, col, name)
  local r = bulgeRadius(w, h)
  local half = math.asin(math.min(1, (w / 2) / r))
  local n = math.max(7, math.ceil(half * 2 / math.rad(9)))
  local step = half * 2 / n
  local cy = crownY - r
  for i = 0, n - 1 do
    local a = math.pi / 2 - half + step * (i + 0.5)
    K.box(d, CFrame.new(xc + math.cos(a) * r, cy + math.sin(a) * r, z) * K.roll(a - math.pi / 2),
      Vector3.new(step * r + thick * 1.6, thick, len), mat, col, { name = name, cancollide = false })
  end
end

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

  -- ---------------------------------------------------------------- เปลือกรถธรรมดา (ทรงโค้ง)
  -- สัดส่วนอิงล้อรัศมี 2.2: ล้อสูง 4.4 บนรถยาว ~15 = 0.29 ซึ่งอยู่ในช่วงรถจริง (0.25-0.30)
  -- ถ้าวันไหนเปลี่ยนรัศมีล้อใน Config ต้องกลับมาปรับ ROCKER/BELT/ROOF ที่นี่ด้วย ไม่งั้นบังโคลนจะไม่ตรงล้อ
  local BRASS, BRASS_DARK = Color3.fromRGB(198, 158, 78), Color3.fromRGB(138, 104, 42)
  local COPPER = Color3.fromRGB(172, 106, 60)
  local BODY_C, BODY_DARK = Color3.fromRGB(146, 108, 64), Color3.fromRGB(104, 76, 44)
  local FENDER_C = Color3.fromRGB(62, 46, 32)
  local IRON, STEEL = Color3.fromRGB(58, 58, 64), Color3.fromRGB(126, 130, 138)
  local WOOD_C = Color3.fromRGB(122, 84, 52)
  local GLASS_C = Color3.fromRGB(158, 200, 216)
  local RUNE, GEM = Color3.fromRGB(58, 92, 146), Color3.fromRGB(72, 150, 226)
  local LEATHER, LEATHER_D = Color3.fromRGB(74, 50, 36), Color3.fromRGB(52, 34, 24)

  local WHEEL_Y, WHEEL_R = 1.9, spec.wheel.radius
  local AX_F, AX_R, TRACK = spec.axles.front, spec.axles.rear, spec.axles.track
  -- **กว้างและสูงกว่ารอบแรก** — ทดสอบในเกมจริงแล้วเบียดกันและหัวทะลุหลังคา (ผู้ใช้ 2026-09-19)
  -- ตัวละคร R15 กว้างราว 2 studs ที่นั่งเดิมห่างกัน 2.6 จึงไหล่ชนกัน · หลังคาเดิมสูงจากเบาะ 3.4
  -- ซึ่งไม่พอสำหรับคนที่ตัวโตขึ้นตามเลเวล (`ProgressionConfig.ScaleForLevel`) หัวเลยโผล่พ้นหลังคา
  local HALF, HALF_CAB = 3.8, 3.4
  local ROCKER, BELT, ROOF = 1.75, 5.0, 8.7
  local NOSE, TAIL = -7.6, 7.4
  local CAB_F, CAB_R = -2.4, 4.4

  -- โครงล่าง
  for _, x in ipairs({ -2.6, 2.6 }) do
    K.box(d, CFrame.new(x, 1.2, 0), Vector3.new(0.55, 0.45, 13.4), MAT.Metal, IRON, { name = "Rail", cancollide = false })
  end
  K.cylX(d, CFrame.new(0, WHEEL_Y, AX_R), 0.3, 8.6, MAT.Metal, STEEL, { name = "AxleRear", cancollide = false })
  K.cylX(d, CFrame.new(0, WHEEL_Y, AX_F), 0.28, 8.6, MAT.Metal, STEEL, { name = "AxleFront", cancollide = false })

  -- เปลือกตัวถัง: พื้น แก้มข้างเอียงเข้า คิ้วเอว เส้นแบ่งประตู มือจับ
  K.box(d, CFrame.new(0, ROCKER, 0), Vector3.new(HALF * 2, 0.4, 13.6), MAT.Metal, BODY_DARK, { name = "Rocker", cancollide = false })
  for _, sd in ipairs({ 1, -1 }) do
    K.box(d, CFrame.new(sd * HALF, (ROCKER + BELT) / 2, -0.1) * K.roll(-sd * K.deg(4)),
      Vector3.new(0.4, BELT - ROCKER, 13.2), MAT.Metal, BODY_C, { name = "Side", cancollide = false })
    K.box(d, CFrame.new(sd * (HALF - 0.02), BELT + 0.1, -0.1), Vector3.new(0.5, 0.22, 13.2), MAT.Metal, BRASS_DARK, { name = "BeltTrim", cancollide = false })
    for _, z in ipairs({ -1.15, 2.05 }) do
      K.box(d, CFrame.new(sd * (HALF + 0.04), (ROCKER + BELT) / 2, z), Vector3.new(0.1, BELT - ROCKER - 0.2, 0.12), MAT.Metal, BODY_DARK, { name = "DoorGap", cancollide = false })
    end
    for _, z in ipairs({ -0.5, 2.7 }) do
      K.box(d, CFrame.new(sd * (HALF + 0.12), BELT - 0.55, z), Vector3.new(0.14, 0.16, 0.6), MAT.Metal, BRASS, { name = "DoorHandle", cancollide = false })
    end
  end

  -- ฝากระโปรง + หลังคา (ผิวโค้งแถวเดียว)
  domeXY(d, 0, BELT + 1.05, -4.85, HALF * 2 - 0.9, 0.95, 5.2, 0.32, MAT.Metal, BODY_C, "Hood")
  for _, sd in ipairs({ 1, -1 }) do
    K.box(d, CFrame.new(sd * (HALF - 0.45), BELT + 0.3, -4.85) * K.roll(-sd * K.deg(7)),
      Vector3.new(0.34, 1.3, 5.2), MAT.Metal, BODY_C, { name = "HoodSide", cancollide = false })
    K.rivets(d, Vector3.new(sd * (HALF - 0.6), BELT + 0.95, -7.2), Vector3.new(sd * (HALF - 0.6), BELT + 0.95, -2.5), 8, 0.08, BRASS_DARK)
  end
  K.box(d, CFrame.new(0, BELT + 1.14, -4.85), Vector3.new(0.18, 0.16, 5.2), MAT.Metal, BRASS, { name = "HoodSpine", cancollide = false })
  domeXY(d, 0, ROOF, (CAB_F + CAB_R) / 2, HALF_CAB * 2, 0.5, CAB_R - CAB_F, 0.28, MAT.Metal, BODY_C, "Roof")

  -- เสา กระจก กรอบกระจกหน้า ที่ปัดน้ำฝน
  for _, sd in ipairs({ 1, -1 }) do
    for _, z in ipairs({ CAB_F, 1.0, CAB_R }) do
      K.box(d, CFrame.new(sd * HALF_CAB, (BELT + ROOF) / 2, z), Vector3.new(0.34, ROOF - BELT, 0.42), MAT.Metal, BODY_C, { name = "Pillar", cancollide = false })
    end
    K.box(d, CFrame.new(sd * HALF_CAB, (BELT + ROOF) / 2, (CAB_F + 1.0) / 2),
      Vector3.new(0.14, ROOF - BELT - 0.55, 1.0 - CAB_F - 0.45), MAT.Glass, GLASS_C, { name = "WindowFront", transparency = 0.42 })
    K.box(d, CFrame.new(sd * HALF_CAB, (BELT + ROOF) / 2, (1.0 + CAB_R) / 2),
      Vector3.new(0.14, ROOF - BELT - 0.55, CAB_R - 1.0 - 0.45), MAT.Glass, GLASS_C, { name = "WindowRear", transparency = 0.42 })
  end
  K.box(d, CFrame.new(0, (BELT + ROOF) / 2 + 0.12, CAB_F - 0.1) * K.pitch(K.deg(-14)),
    Vector3.new(HALF_CAB * 2 - 0.5, ROOF - BELT - 0.25, 0.14), MAT.Glass, GLASS_C, { name = "Windshield", transparency = 0.38 })
  K.box(d, CFrame.new(0, (BELT + ROOF) / 2 + 0.1, CAB_R + 0.1),
    Vector3.new(HALF_CAB * 2 - 0.5, ROOF - BELT - 0.55, 0.14), MAT.Glass, GLASS_C, { name = "RearWindow", transparency = 0.42 })
  K.box(d, CFrame.new(0, ROOF - 0.18, CAB_F - 0.22) * K.pitch(K.deg(-14)), Vector3.new(HALF_CAB * 2 - 0.4, 0.2, 0.2), MAT.Metal, BRASS_DARK, { name = "ScreenFrame", cancollide = false })
  K.box(d, CFrame.new(-0.7, BELT + 1.35, CAB_F - 0.3) * K.roll(K.deg(24)), Vector3.new(0.08, 0.9, 0.08), MAT.Metal, IRON, { name = "Wiper", cancollide = false })

  -- ท้ายรถโค้งลง
  arcYZ(d, 0, BELT - 0.3, 5.4, 1.75, 4, 86, 9, HALF * 2 - 0.4, 0.32, MAT.Metal, BODY_C, "TailCurve")
  K.box(d, CFrame.new(0, (ROCKER + BELT) / 2, TAIL - 0.35), Vector3.new(HALF * 2 - 0.4, BELT - ROCKER, 0.4), MAT.Metal, BODY_C, { name = "TailPanel", cancollide = false })

  -- หน้ารถ: กระจังโล่ ซี่ทองเหลือง ยอดโค้ง อัญมณี ไฟกลมบนก้าน กันชน
  K.box(d, CFrame.new(0, (ROCKER + BELT) / 2 + 0.75, NOSE + 0.35) * K.pitch(K.deg(7)),
    Vector3.new(3.1, BELT - ROCKER + 1.3, 0.4), MAT.Metal, BRASS, { name = "Grille", cancollide = false })
  for i = 0, 7 do
    K.box(d, CFrame.new(0, 2.6 + i * 0.4, NOSE + 0.16), Vector3.new(2.6, 0.13, 0.12), MAT.Metal, BRASS_DARK, { name = "GrilleBar", cancollide = false })
  end
  arcYZ(d, 0, BELT + 0.45, NOSE + 0.35, 0.8, -58, 58, 6, 3.1, 0.28, MAT.Metal, BRASS, "GrilleCrown")
  K.ball(d, CFrame.new(0, BELT + 1.2, NOSE + 0.45), 0.42, MAT.Neon, GEM, { name = "GrilleGem" })
  for _, sd in ipairs({ 1, -1 }) do
    K.rod(d, Vector3.new(sd * 2.2, BELT - 0.3, NOSE + 1.0), Vector3.new(sd * 2.45, BELT + 0.45, NOSE + 1.0), 0.11, MAT.Metal, BRASS, { cancollide = false })
    K.ball(d, CFrame.new(sd * 2.45, BELT + 0.78, NOSE + 0.95), 0.88, MAT.Metal, BRASS, { name = "LampBody", cancollide = false })
    K.cylX(d, CFrame.new(sd * 2.45, BELT + 0.78, NOSE + 0.55) * K.yaw(math.pi / 2), 0.35, 0.16, MAT.Neon, Color3.fromRGB(255, 232, 170), { name = "LampGlass", cancollide = false })
    K.rod(d, Vector3.new(sd * (HALF - 0.1), BELT + 0.3, CAB_F + 0.1), Vector3.new(sd * (HALF + 0.55), BELT + 0.6, CAB_F + 0.1), 0.07, MAT.Metal, BRASS, { cancollide = false })
    K.cylX(d, CFrame.new(sd * (HALF + 0.62), BELT + 0.66, CAB_F + 0.1) * K.yaw(math.pi / 2), 0.26, 0.1, MAT.Glass, GLASS_C, { name = "Mirror", cancollide = false })
  end
  K.box(d, CFrame.new(0, ROCKER + 0.5, NOSE - 0.15), Vector3.new(5.6, 0.34, 0.28), MAT.Metal, BRASS_DARK, { name = "BumperFront", cancollide = false })
  K.box(d, CFrame.new(0, ROCKER + 0.5, TAIL), Vector3.new(5.6, 0.34, 0.28), MAT.Metal, BRASS_DARK, { name = "BumperRear", cancollide = false })

  -- บังโคลนคลุมยางเกือบครึ่งวง + บันไดข้าง
  for _, sd in ipairs({ 1, -1 }) do
    for _, z in ipairs({ AX_F, AX_R }) do
      arcYZ(d, sd * TRACK, WHEEL_Y, z, WHEEL_R + 0.45, 8, 172, 14, 2.7, 0.3, MAT.Metal, FENDER_C, "Fender")
    end
    K.box(d, CFrame.new(sd * 3.95, ROCKER + 0.15, -0.2), Vector3.new(1.4, 0.26, 5.0), MAT.Wood, WOOD_C, { name = "RunningBoard", cancollide = false })
    K.box(d, CFrame.new(sd * 4.62, ROCKER + 0.3, -0.2), Vector3.new(0.18, 0.4, 5.0), MAT.Metal, BRASS_DARK, { name = "BoardEdge", cancollide = false })
  end

  -- เครื่องไอน้ำข้างตัวถัง + ปล่อง + ท่อไอเสีย
  K.boiler(d, CFrame.new(3.85, 3.6, 1.6) * K.pitch(math.pi / 2), 0.75, 4.0, { bands = 3, color = COPPER })
  K.pipe(d, { Vector3.new(3.85, 3.6, -0.5), Vector3.new(3.85, 3.7, -3.4), Vector3.new(3.1, 4.6, -4.8), Vector3.new(2.2, 5.2, -5.6) }, 0.2, COPPER)
  K.gauge(d, CFrame.new(4.3, 4.6, 0.6) * K.yaw(math.pi / 2), 0.42, BRASS)
  K.valveWheel(d, CFrame.new(4.3, 3.5, 3.3) * K.yaw(math.pi / 2), 0.46, 5, BRASS)
  K.smokestack(d, CFrame.new(-2.5, ROOF - 0.3, CAB_R + 1.0), 0.34, 1.7, { smoke = true })
  K.pipe(d, { Vector3.new(-2.2, 1.35, 0), Vector3.new(-2.2, 1.25, 5.2), Vector3.new(-2.4, 1.45, TAIL - 0.2) }, 0.16, IRON)

  -- ห้องโดยสาร — **เบาะต้องคร่อม VehicleSeat จริงที่สร้างทีหลังในฟังก์ชันนี้**
  -- คนขับ (-1.3, 3.8, -0.6) · ผู้โดยสารหน้า (1.3, 3.8, -0.6) · ผู้โดยสารหลัง (0, 3.8, 2.2)
  local function carSeat(x, z, w)
    K.box(d, CFrame.new(x, 3.74, z), Vector3.new(w, 0.32, 1.45), MAT.Fabric, LEATHER, { name = "SeatCushion", cancollide = false })
    K.box(d, CFrame.new(x, 3.58, z), Vector3.new(w + 0.12, 0.18, 1.55), MAT.Fabric, LEATHER_D, { name = "SeatBase", cancollide = false })
    K.box(d, CFrame.new(x, 4.52, z + 0.78) * K.pitch(K.deg(-9)), Vector3.new(w, 1.5, 0.3), MAT.Fabric, LEATHER, { name = "SeatBack", cancollide = false })
    for i = -1, 1 do
      K.box(d, CFrame.new(x + i * w * 0.27, 3.91, z), Vector3.new(0.07, 0.06, 1.35), MAT.Fabric, LEATHER_D, { name = "SeatSeam", cancollide = false })
    end
  end
  carSeat(-1.75, -0.6, 1.7)
  carSeat(1.75, -0.6, 1.7)
  carSeat(0, 2.3, 4.2)
  K.box(d, CFrame.new(0, 4.62, CAB_F + 0.3), Vector3.new(HALF_CAB * 2 - 0.4, 0.7, 0.45), MAT.Wood, WOOD_C, { name = "Dashboard", cancollide = false })
  K.box(d, CFrame.new(0, 5.0, CAB_F + 0.3), Vector3.new(HALF_CAB * 2 - 0.4, 0.14, 0.5), MAT.Metal, BRASS_DARK, { name = "DashTrim", cancollide = false })
  for _, gx in ipairs({ -2.2, -1.4, 1.6 }) do
    K.gauge(d, CFrame.new(gx, 4.66, CAB_F + 0.55) * K.yaw(math.pi / 2), 0.3, BRASS)
  end
  K.valveWheel(d, CFrame.new(-1.75, 4.6, -1.62) * K.yaw(math.pi / 2) * K.roll(K.deg(-20)), 0.62, 4, BRASS)
  K.rod(d, Vector3.new(-1.75, 4.6, -1.62), Vector3.new(-1.75, 4.35, CAB_F + 0.2), 0.1, MAT.Metal, BRASS_DARK, { cancollide = false })
  K.ball(d, CFrame.new(-1.75, 4.6, -1.62), 0.2, MAT.Neon, GEM, { name = "HornBoss" })
  K.rod(d, Vector3.new(-0.15, 3.6, -1.1), Vector3.new(-0.05, 4.5, -0.9), 0.07, MAT.Metal, BRASS, { cancollide = false })
  K.ball(d, CFrame.new(-0.05, 4.58, -0.9), 0.22, MAT.Wood, WOOD_C, { name = "GearKnob", cancollide = false })
  for _, px in ipairs({ -2.2, -1.65 }) do
    K.box(d, CFrame.new(px, 3.5, CAB_F + 0.05) * K.pitch(K.deg(-22)), Vector3.new(0.24, 0.32, 0.1), MAT.Metal, IRON, { name = "Pedal", cancollide = false })
  end
  K.plankFloor(d, CFrame.new(0, 3.5, 1.0), HALF_CAB * 2 - 0.5, 6.0, 0.9, WOOD_C)
  K.cylX(d, CFrame.new(0, ROOF - 0.5, CAB_F + 0.35) * K.yaw(math.pi / 2), 0.22, 0.09, MAT.Glass, GLASS_C, { name = "RearViewMirror", cancollide = false })

  -- ลายสลักข้างตัวถัง
  for _, sd in ipairs({ 1, -1 }) do
    K.box(d, CFrame.new(sd * (HALF + 0.14), (ROCKER + BELT) / 2 + 0.2, 0.55), Vector3.new(0.08, 1.2, 2.6), MAT.Metal, RUNE, { name = "RunePanel", cancollide = false })
    K.ball(d, CFrame.new(sd * (HALF + 0.18), (ROCKER + BELT) / 2 + 0.2, 0.55), 0.28, MAT.Neon, GEM, { name = "EyeGem" })
  end

  -- ลังท้ายรถ = ช่องเก็บของ (จุดที่ ProximityPrompt เปิดท้ายไปเกาะ) — ห้ามลบ มีคนอ้างถึงใน return
  local trunk = K.crate(d, CFrame.new(0, ROCKER + 0.9, 6.5), 2.0, WOOD_C)
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
    -- **ระยะห่างที่นั่งคือสิ่งที่ตัดสินว่าตัวเบียดกันไหม** เดิม x = ±1.3 (ห่าง 2.6) ตัวละครกว้าง ~2
    -- ไหล่จึงชนกัน · ขยับเป็น ±1.75 (ห่าง 3.5) และเลื่อนแถวหลังถอยจาก 2.2 เป็น 2.3 ให้เข่าพ้นพนักหน้า
    Chassis.seat(m, hull, hull.CFrame * CFrame.new(-1.75, 1.6, -0.6), "driver"),
    Chassis.seat(m, hull, hull.CFrame * CFrame.new(1.75, 1.6, -0.6), "passenger", "PassengerSeat1"),
    Chassis.seat(m, hull, hull.CFrame * CFrame.new(0, 1.6, 2.3), "passenger", "PassengerSeat2"),
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
