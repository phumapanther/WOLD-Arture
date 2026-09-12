-- Vehicle/Config — ค่ากลางของระบบพาหนะ ที่ทั้งเซิร์ฟเวอร์และไคลเอนต์อ่านร่วมกัน
--
-- ยกมาจากโปรเจ็ค WOLD-Vehicle (2026-09-12) ตัวเลขฟิสิกส์ทั้งหมดผ่านการทดสอบจริงมาแล้วสามรอบ
-- **อย่าแก้ค่าฟิสิกส์โดยไม่อ่าน `WOLD-Vehicle/CLAUDE.md` ก่อน** — ค่าหลายตัวเป็นผลของบั๊กที่กว่าจะแก้ได้ใช้เวลานาน
-- (ล้อส่าย เรือดีดขึ้นฟ้า เรือเหาะเกยหิน) ที่นั่นบันทึกไว้ว่าตัวไหนแก้อะไร
-- ตัวเลขทุกตัวปรับได้จากที่นี่ที่เดียว ส่วนค่าที่อยากจูนสดตอนเล่นให้ใส่เป็น Attribute บนตัวโมเดล
local Config = {}

Config.Version = "0.1.0"
Config.Folder = "SpawnedVehicles"      -- โฟลเดอร์ใน Workspace ที่พาหนะที่เรียกออกมาอยู่
Config.StationFolder = "VehicleStations"

-- ---------------------------------------------------------------- พาหนะ 3 ชนิด
-- prefix  = ตัวหน้าทะเบียน (CAR-1234 / SEA-1234 / AIR-1234)
-- seats   = จำนวนที่นั่งซ้อน (ไม่รวมคนขับ) — โจทย์กำหนดอย่างน้อย 1
-- trunk   = จำนวนช่องเก็บของท้ายพาหนะ
Config.Types = {
  Car = {
    display = "รถไอน้ำ", prefix = "CAR", icon = "🚂",
    seats = 2, trunk = 12, price = 0,
    drive = "Wheels",
    serverOwned = false,               -- รถให้เครื่องคนขับจำลองเอง (พวงมาลัย/คันเร่งตอบสนองทันมือ)
    -- โครงรถ
    hull = Vector3.new(6.6, 2.6, 14),  -- กล่องชนที่ถือมวลทั้งคัน (ชิ้นตกแต่งเป็น Massless)
    hullDensity = 0.7,
    ride = 1.9,                        -- ความสูงจากพื้นถึงกึ่งกลางล้อ
    wheel = { radius = 2.2, width = 1.3, density = 2.6, friction = 1.5,
              frictionWeight = 8, hubDensity = 6 },   -- friction เกิน 2 ไม่ได้ Roblox จะ clamp แล้วเตือนรัวๆ
    axles = { front = -4.6, rear = 4.2, track = 4.35 },   -- ระยะตามแกน Z (หน้า = -Z) และครึ่งช่วงล้อ
    maxSpeed = 24,                     -- rad/s ที่ล้อหมุน (วิ่งจริงราว 35 stud/s)
    torque = 26000,
    brakeTorque = 46000,
    steerAngle = 26,                   -- องศา (มุมล้อหน้าสูงสุดตอนอยู่กับที่)
    steerSpeed = 4,                    -- rad/s ที่ล้อหน้าหมุนตามพวงมาลัย
    servoTorque = 200000,              -- แรงบิดที่ยึดล้อหน้าไว้กับมุมเป้าหมาย น้อยไป = ล้อสะบัด
    steerFade = 0.45,                  -- ที่ความเร็วสูงเหลือมุมเลี้ยวเท่านี้ของค่าเต็ม (กันพลิก/ส่าย)
    steerFadeSpeed = 42,               -- stud/s ที่ถือว่า "เร็วเต็ม" ในการหรี่มุมเลี้ยว
    fuel = { max = 100, idle = 0.25, drive = 1.8 },   -- เต็มถังวิ่งได้ราว 8 นาทีถ้าเหยียบตลอด
    frontBrake = 0.3,                  -- ล้อหน้าหน่วงเบาๆ ตอนไม่เร่ง กันล้อฟรีสะบัดตอนเลี้ยว
    spinRate = 14,                     -- rad/s ของเฟืองข้างตัวถังตอนเร่งเต็ม
  },
  Boat = {
    display = "เรือไอน้ำ", prefix = "SEA", icon = "🚢",
    seats = 3, trunk = 18, price = 0,
    drive = "Float",
    serverOwned = true,                -- ดูคำอธิบายที่ VehicleService.own()
    hull = Vector3.new(12, 4, 30),
    hullDensity = 1.0,
    draft = 2.0,                       -- ความลึกที่จมเมื่อลอยนิ่ง
    -- สปริงแรงลอย: buoyancy คือความแข็ง verticalDamp คือความหนืด
    -- ของเดิม (2.6 / 2.2) คือสปริงแข็งมากที่แทบไม่มีตัวหน่วง (ζ ≈ 0.07) เรือเลยสะสมพลังงานจนดีดขึ้นฟ้า
    -- ชุดนี้ให้ ω ≈ 8.9 rad/s, ζ ≈ 0.79 — เด้งครั้งเดียวแล้วนิ่ง
    buoyancy = 0.8,
    verticalDamp = 20,                 -- ตัวหน่วงต้องแรงกว่าที่คิดมาก น้ำจริงหนืดกว่าสปริงเปล่าเยอะ
    maxLift = 1.8,                     -- เพดานแรงลอย (เท่าของ g) — ตอนจมมิดห้ามดันแรงจนกระโดดพ้นน้ำ
    power = 26,                        -- แรงเดินหน้า (stud/s^2)
    reverse = 0.45,
    drag = 0.55,
    turnRate = 0.9,                    -- rad/s ตอนความเร็วเต็ม
    minTurn = 0.35,                    -- คูณกับ turnRate ตอนอยู่กับที่ (พายเรือหมุนตัวได้)
    maxSpeed = 70,
    spinRate = 7,                      -- rad/s ของล้อพายตอนเร่งเต็ม
    fuel = { max = 140, idle = 0.3, drive = 1.5 },
  },
  Airship = {
    display = "เรือเหาะ", prefix = "AIR", icon = "🎈",
    seats = 4, trunk = 24, price = 0,
    drive = "Hover",
    serverOwned = true,
    hull = Vector3.new(10, 4, 26),    -- กล่องชน = ตัวกระเช้า ส่วนบอลลูนเป็นของตกแต่งไร้มวล
    hullDensity = 0.35,
    power = 22,
    reverse = 0.5,
    drag = 0.42,
    turnRate = 0.7,
    minTurn = 1,                       -- เรือเหาะหมุนตัวอยู่กับที่ได้เต็มที่
    climbRate = 26,                    -- stud/s ตอนกด R (ขึ้น) / F (ลง)
    -- บังคับด้วยการเล็งกล้อง: เดินหน้าอยู่แล้วเงยกล้อง = ไต่ขึ้น ก้มกล้อง = ดิ่งลง
    aimClimb = 0.9,                    -- ตัวคูณ "ความเร็วเดินหน้า × มุมเล็ง" เป็นอัตราไต่
    aimPitch = 26,                     -- องศาที่ลำเรือเชิดหัว/ปักหัวตามมุมเล็ง
    emptyDescent = 11,                 -- stud/s ที่ร่อนลงตอนเชื้อเพลิงหมด
    emptyPitch = 13,                   -- องศาปักหัวลงตอนเชื้อเพลิงหมด
    hoverP = 9,                        -- สปริงรักษาระดับความสูง
    hoverD = 5,
    minAlt = 6, maxAlt = 900,
    maxSpeed = 90,
    spinRate = 8,                      -- rad/s ของใบพายข้างลำตอนเร่งเต็ม
    -- เรือเหาะกินพลังงานตอนอยู่เฉยๆ ด้วย เพราะต้องเผาไฟค้างระดับความสูงไว้
    fuel = { max = 160, idle = 0.9, drive = 1.6 },
  },
}

-- ---------------------------------------------------------------- จุดเรียกพาหนะ
-- เลือกชุดพิกัดด้วย Attribute "VehiclePreset" บน Workspace (ไม่ตั้ง = Arture)
-- ชุด Testbed ของเพลสทดสอบไม่ได้ยกมา — มันอิงภูมิประเทศที่ตัวติดตั้งของโปรเจ็คนั้นสร้างเอง
Config.Presets = {
  -- พิกัดจริงในเกมหลัก อ้างอิงจาก docs/design/world-layout.json (Brasshaven = เมืองหลวง อยู่ที่ 2080, 3760)
  --
  -- **พิกัด x/z เป็นค่าตั้งต้น ส่วน y ไม่ได้ใช้เลย** — ตัวสร้างสถานียิงเรย์หาผิวจริงเสมอ ตามบทเรียนของ
  -- โปรเจ็คต้นทาง ("อย่าเชื่อตัวเลขที่ตั้งใจไว้ ให้ยิงเรย์ลงมาเช็กผิวจริงก่อน" — ลานจอดยอดเขาเคยจมหิน 3 studs
  -- จนเรือเหาะไปเกยแล้วขยับไม่ออก)
  --
  -- `surface` บอกวิธีหาที่วางจริง:
  --   "ground" ยิงเรย์ลงตรงๆ         (จุดรถ — ข้างจุดเกิดผู้เล่น)
  --   "shore"  เดินออกจากใจกลางแมพจนเจอน้ำ แล้ววางท่าไว้ริมฝั่ง ลานจอดอยู่ในน้ำ (จุดเรือ)
  --   "peak"   หาจุดสูงสุดในรัศมีที่กำหนด                                  (จุดเรือเหาะ — ยอดเขา)
  Arture = {
    { id = "TownGarage", vtype = "Car", title = "โรงรถไอน้ำบราสส์เฮเวน", surface = "ground",
      pos = Vector3.new(2180, 0, 3760), face = 180, spawn = Vector3.new(2230, 0, 3760), spawnFace = 90 },
    { id = "HarbourDock", vtype = "Boat", title = "ท่าเรือไอน้ำ", surface = "shore",
      -- ทิศออกจากใจกลางแมพผ่านเมืองหลวง คือทางที่จะไปเจอทะเลของอ่าว
      pos = Vector3.new(2600, 0, 4700), face = 0, spawn = Vector3.new(2600, 0, 4700), spawnFace = 0,
      searchFrom = Vector3.new(2080, 0, 3760), searchRange = 4000 },
    { id = "PeakMooring", vtype = "Airship", title = "ลานจอดเรือเหาะยอดเขา", surface = "peak",
      -- ยอดเขาหลัก main_NE ของ world-layout (0.45, -0.6) × 8000 studs
      pos = Vector3.new(3600, 0, -4800), face = 0, spawn = Vector3.new(3600, 0, -4740), spawnFace = 0,
      searchRange = 700 },
  },
}

function Config.stations()
  local preset = workspace:GetAttribute("VehiclePreset") or "Arture"
  return Config.Presets[preset] or Config.Presets.Arture, preset
end

-- ---------------------------------------------------------------- ของที่เก็บได้
-- ตารางไอเทมทดสอบของโปรเจ็คต้นทางถูกตัดทิ้งแล้ว: ในเกมหลักท้ายพาหนะใช้ **ItemCatalog + Inventory ของเกม**
-- ตรงๆ ทุกอย่างที่ใส่กระเป๋าได้ก็ยัดท้ายรถได้ และของในท้ายก็มีน้ำหนัก/ไอคอน/ชื่อชุดเดียวกับในกระเป๋า
--
-- ช่องเก็บของท้ายพาหนะนับเป็น "ชนิดของ" (`trunk` ของแต่ละชนิดพาหนะ) ไม่ใช่ช่องกระเป๋า และกองละไม่เกิน
-- stackSize ของไอเทมนั้นตาม ItemCatalog

-- ---------------------------------------------------------------- เสียง
-- เสียงเครื่องจักรสังเคราะห์จากไฟล์ที่ติดมากับตัว Roblox (rbxasset:// ไม่ต้องอัปโหลด ไม่มีวันโดนลบ)
-- ซ้อนกันสามชั้น: drone = ลมหึ่งต่อเนื่อง · wash = เสียงน้ำ/ลมตามความเร็ว · pulse = จังหวะฉึกฉักของเครื่องไอน้ำ
--
-- **จะเปลี่ยนเป็นเสียงจริงทีหลัง แก้แค่ค่า id ในตารางนี้ที่เดียว** ใส่ "rbxassetid://123456789" ได้เลย
-- ค่าคู่ { a, b } อ่านว่า "ตอนเดินเบา → ตอนเร่งเต็ม" ระบบไล่ค่าระหว่างสองอันนี้ให้เอง
Config.Sound = {
  enabled = true,
  master = 0.6,                        -- ดังรวมทุกเสียง
  fade = 7,                            -- ความเร็วที่เสียงไล่เข้าหาค่าเป้าหมาย (ต่อวินาที)
  maxDistance = 340,
  types = {
    Car = {
      drone = { id = "rbxasset://sounds/action_falling.mp3", pitch = { 0.26, 0.62 }, volume = { 0.10, 0.38 } },
      pulse = { ids = { "rbxasset://sounds/bass.wav", "rbxasset://sounds/metal.ogg" },
                rate = { 2.2, 8.5 }, pitch = { 0.75, 1.3 }, volume = { 0.22, 0.46 } },
      horn  = { id = "rbxasset://sounds/electronicpingshort.wav", pitch = 0.42, volume = 0.85 },
      vent  = { id = "rbxasset://sounds/action_falling.mp3", pitch = 1.9, volume = 0.45, length = 0.9 },
    },
    Boat = {
      drone = { id = "rbxasset://sounds/action_falling.mp3", pitch = { 0.20, 0.44 }, volume = { 0.12, 0.36 } },
      wash  = { id = "rbxasset://sounds/action_swim.mp3", pitch = { 0.65, 1.1 }, volume = { 0, 0.4 } },
      pulse = { ids = { "rbxasset://sounds/bass.wav", "rbxasset://sounds/impact_water.mp3" },
                rate = { 1.6, 5 }, pitch = { 0.55, 0.95 }, volume = { 0.26, 0.5 } },
      horn  = { id = "rbxasset://sounds/electronicpingshort.wav", pitch = 0.3, volume = 1 },
      vent  = { id = "rbxasset://sounds/action_falling.mp3", pitch = 1.7, volume = 0.45, length = 1.2 },
    },
    Airship = {
      drone = { id = "rbxasset://sounds/Rocket whoosh 01.wav", pitch = { 0.3, 0.75 }, volume = { 0.14, 0.42 } },
      wash  = { id = "rbxasset://sounds/action_falling.mp3", pitch = { 0.5, 0.95 }, volume = { 0.06, 0.26 } },
      pulse = { ids = { "rbxasset://sounds/metal.ogg", "rbxasset://sounds/bass.wav" },
                rate = { 3, 9.5 }, pitch = { 0.9, 1.4 }, volume = { 0.16, 0.34 } },
      horn  = { id = "rbxasset://sounds/electronicpingshort.wav", pitch = 0.36, volume = 0.95 },
      vent  = { id = "rbxasset://sounds/action_falling.mp3", pitch = 2.1, volume = 0.4, length = 0.8 },
    },
  },
}

-- ---------------------------------------------------------------- พลังงาน
Config.FuelPerCoal = 25                -- ถ่านหิน 1 ชิ้นเติมได้เท่านี้หน่วย (ไอเทม Coal ใน ItemCatalog)
Config.FreeFuel = false                -- ในเกมจริงต้องมีถ่านหินถึงจะเติมได้
Config.LowFuel = 0.2                   -- ต่ำกว่านี้ถือว่าใกล้หมด เตือนคนขับ

Config.MaxVehiclesPerType = 3          -- ทะเบียนที่คนหนึ่งถือได้ต่อชนิด
Config.SummonRange = 28                -- ต้องอยู่ใกล้ NPC เท่านี้ถึงสั่งงานได้
Config.TrunkRange = 18                 -- ระยะเปิดท้ายพาหนะ
Config.AutoDespawn = 900               -- วินาที ที่ไม่มีคนแตะแล้วพาหนะหายเอง (0 = ไม่หาย)
Config.FreeRegister = true             -- จดทะเบียนคันใหม่ฟรี (ค่าใช้จ่ายอยู่ที่การเบิก/ฝากแทน)

-- ---------------------------------------------------------------- ค่าเบิก / ค่าฝาก
-- โจทย์ของผู้ใช้: "เบิกฝากรถได้ แต่เสียเงินค่าเบิก และถ้ารถอยู่ห่างจาก NPC มาก็เสียตังเบิกหรือฝากมากขึ้นด้วย"
--
-- ระยะที่คิดเงินคือระยะจาก **บารอนเวน (NPC)** ไปยังสิ่งที่กำลังทำ:
--   เบิก  → ระยะจาก NPC ไปลานจอดที่พาหนะจะโผล่  (เรียกเรือลงทะเลอีกฝั่งเมืองย่อมแพงกว่าเรียกรถหน้าโรงรถ)
--   ฝาก  → ระยะจาก NPC ไปตัวพาหนะที่จอดอยู่จริง (ทิ้งรถไว้กลางเขาแล้วสั่งเก็บ ย่อมแพงกว่าขับกลับมาเอง)
--
-- ค่าบริการไม่คิดตามระยะทั้งหมด แต่คิดหลังหักระยะฟรีก้อนแรก ไม่งั้นการเบิกที่หน้าโรงรถเองก็ยังเสียหลายร้อย
Config.Fee = {
  Retrieve = 120,                      -- ค่าเบิกพื้นฐาน
  Stow = 80,                           -- ค่าฝากพื้นฐาน
  FreeStuds = 120,                     -- ระยะแรกที่ไม่คิดเพิ่ม
  PerStud = 0.35,                      -- เหรียญต่อ 1 stud ที่เกินระยะฟรี
  Max = 4000,                          -- เพดาน กันค่าบริการข้ามแมพ 16,000 studs พุ่งเป็นหมื่น
}

-- คิดค่าบริการจากระยะ (studs) ทั้งฝั่งเบิกและฝั่งฝากใช้สูตรเดียวกัน ต่างแค่ค่าพื้นฐาน
-- คืนค่าเป็นจำนวนเต็มเสมอ เพราะเงินในเกมเป็นจำนวนเต็ม
function Config.feeFor(kind, studs)
  local fee = Config.Fee
  local base = (kind == "stow") and fee.Stow or fee.Retrieve
  local extra = math.max(0, (tonumber(studs) or 0) - fee.FreeStuds) * fee.PerStud
  return math.min(fee.Max, math.floor(base + extra + 0.5))
end

return Config
