-- VehicleSound — เสียงเครื่องจักรของพาหนะทุกคันที่อยู่ในโลก
--
-- **ทำงานฝั่งไคลเอนต์ล้วน** Sound ทุกตัวสร้างในเครื่องผู้เล่นเอง ไม่ replicate ไปไหน
-- เซิร์ฟเวอร์จึงไม่ต้องยิงค่าความดัง/พิตช์ข้ามเน็ตทุกเฟรม (ซึ่งจะกินแบนด์วิดท์มหาศาล)
-- ข้อมูลที่ใช้มีแค่สองอย่างที่ replicate อยู่แล้ว: Attribute "Throttle" กับความเร็วจริงของกล่องชน
--
-- เสียงซ้อนกันสามชั้น ปรับไฟล์/ค่าทุกตัวได้ที่ Config.Sound ที่เดียว
--   drone  ลมหึ่งต่อเนื่อง พิตช์ขึ้นตามกำลังเครื่อง
--   wash   เสียงน้ำ/ลมปะทะ ดังตามความเร็ว (เรือกับเรือเหาะเท่านั้น)
--   pulse  จังหวะฉึกฉักของเครื่องไอน้ำ ยิงถี่ขึ้นตามกำลังเครื่อง สลับไฟล์ไปมาให้ไม่ซ้ำหู
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ล็อบบี้ไม่มีระบบพาหนะ และ Net.get() ฝั่งไคลเอนต์จะยืนรอโฟลเดอร์ที่ไม่มีวันมา
while workspace:GetAttribute("IsLobby") == nil do
  task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local Config = require(game.ReplicatedStorage.Vehicle.Config)
local Net = require(game.ReplicatedStorage.Vehicle.Net)

local SOUND = Config.Sound
if not (SOUND and SOUND.enabled) then
  warn("[VehicleSound] Config.Sound.enabled = false — ระบบเสียงพาหนะปิดอยู่")
  return
end

-- หมายเหตุสำหรับอนาคต: ถ้าเสียงดังใน Studio แต่เงียบในเกมที่ publish แล้ว **อย่าหาสาเหตุในไฟล์นี้**
-- Studio เล่นเสียงส่วนตัวของเจ้าของบัญชีได้เพราะล็อกอินอยู่ ส่วนเซิร์ฟเวอร์จริงเป็นคนละตัวตนและถูกปฏิเสธ
-- ต้องไปกด "ให้สิทธิ์เสียงกับเกมนี้" ที่ Creator Dashboard เป็นรายไฟล์ (ดู assets/sounds/README.md)

local rigs = {}                                  -- model -> rig
local warned = {}                                -- model -> เตือนไปแล้ว (กันลูปพ่นซ้ำทุกครึ่งวินาที)

local function lerp(a, b, t) return a + (b - a) * t end
local function pick(pair, t)
  if type(pair) ~= "table" then return pair or 0 end
  return lerp(pair[1], pair[2], t)
end

local function newSound(parent, id, looped)
  local s = Instance.new("Sound")
  s.SoundId = id
  s.Looped = looped or false
  s.Volume = 0
  s.RollOffMode = Enum.RollOffMode.InverseTapered
  s.RollOffMinDistance = 14
  s.RollOffMaxDistance = SOUND.maxDistance
  s.Parent = parent
  return s
end

local function build(model)
  if rigs[model] then return end
  local vtype = model:GetAttribute("VehicleType")
  local conf = vtype and SOUND.types[vtype]
  local hull = model.PrimaryPart or model:FindFirstChild("Hull")
  if not (conf and hull) then
    -- ยังไม่พร้อม ไม่ใช่พัง: ลูปข้างล่างถามใหม่ทุกครึ่งวินาที และ Attribute กับชิ้นส่วนอาจ stream มาไม่พร้อมกัน
    -- เตือนครั้งเดียวต่อโมเดล ไม่งั้นจะท่วม Output ทุกครึ่งวินาที
    if not warned[model] then
      warned[model] = true
      warn(("[VehicleSound] ยังสร้างเสียงให้ %s ไม่ได้ — VehicleType=%s (รู้จัก=%s) hull=%s")
        :format(model.Name, tostring(vtype), tostring(conf ~= nil), tostring(hull ~= nil)))
    end
    return
  end
  warned[model] = nil

  local rig = { model = model, hull = hull, conf = conf, nextPulse = 0, turn = 1, lastThrottle = 0, pulses = {} }
  if conf.drone then rig.drone = newSound(hull, conf.drone.id, true) end
  if conf.wash then rig.wash = newSound(hull, conf.wash.id, true) end
  if conf.pulse then
    for i, id in ipairs(conf.pulse.ids) do rig.pulses[i] = newSound(hull, id, false) end
  end
  if conf.horn then rig.horn = newSound(hull, conf.horn.id, false) end
  if conf.vent then rig.vent = newSound(hull, conf.vent.id, false) end
  -- เสียงวนลูปสองตัวนี้ต้องเริ่มเล่นทันทีและเล่นค้างไว้ตลอด (ลูปหลักปรับแค่ Volume/PlaybackSpeed)
  --
  -- **Play() บนเสียงที่ Roblox ยังโหลดไม่เสร็จจะไม่เกิดอะไรขึ้น และไม่มีการลองใหม่** ไฟล์ engine_drone ยาว
  -- 2 วินาที กว่าจะโหลดเสร็จก็ผ่านเฟรมนี้ไปแล้ว — และเพราะเสียงเริ่มที่ Volume = 0 เสมอ ความล้มเหลวนี้จึง
  -- เงียบสนิท ไม่มีอะไรบอก นี่คือสาเหตุที่เสียงเครื่องยนต์ไม่ดังเลยทั้งที่ id ถูกและไฟล์โหลดได้
  --
  -- บทเรียนเดียวกับเสียงคราฟ (UiSound.Loop) แก้ด้วยการเล่นซ้ำตอนโหลดเสร็จ ถ้าโหลดเสร็จอยู่แล้วจะไม่ทำงาน
  local function startLoop(sound)
    if not sound then return end
    sound:Play()
    if not sound.IsLoaded then
      sound.Loaded:Once(function()
        -- เช็ค Parent เผื่อพาหนะถูกเก็บไปก่อนเสียงจะโหลดเสร็จ
        if sound.Parent and not sound.IsPlaying then sound:Play() end
      end)
    end
  end
  startLoop(rig.drone)
  startLoop(rig.wash)
  rigs[model] = rig
end

local function drop(model)
  local rig = rigs[model]
  if not rig then return end
  for _, s in ipairs({ rig.drone, rig.wash, rig.horn, rig.vent }) do
    if s then s:Destroy() end
  end
  for _, s in ipairs(rig.pulses) do s:Destroy() end
  rigs[model] = nil
end

local function watchFolder(folder)
  for _, m in ipairs(folder:GetChildren()) do task.defer(build, m) end
  folder.ChildAdded:Connect(function(m) task.delay(0.15, build, m) end)
  folder.ChildRemoved:Connect(drop)
end

-- โฟลเดอร์พาหนะถูกสร้างตอน "มีคนเรียกพาหนะคันแรกของเซิร์ฟเวอร์" ไม่ใช่ตอนเซิร์ฟเวอร์สตาร์ต — ซึ่งอาจเป็น
-- ชั่วโมงหลังผู้เล่นเข้าเกม
--
-- **นี่คือสาเหตุที่รถไม่มีเสียงในเกมจริง** ของเดิมใช้ `WaitForChild(Config.Folder, 60)` ซึ่งรอแค่ 60 วินาที
-- แล้วคืน nil เงียบๆ ระบบเสียงก็ตายไปทั้งรอบ ในเพลสทดสอบของโปรเจ็คต้นทางไม่เคยเจอ เพราะที่นั่นเรียกรถ
-- ภายในไม่กี่วินาทีหลังกด Play เสมอ
--
-- ไม่มีเส้นตายอีกแล้ว: ถ้ายังไม่มีโฟลเดอร์ก็นั่งฟัง ChildAdded ไว้ เกิดเมื่อไหร่ก็เริ่มเมื่อนั้น
-- **ถามซ้ำทุกครึ่งวินาที ไม่ใช่ผูก event ครั้งเดียว**
--
-- เพลสนี้เปิด StreamingEnabled ซึ่งแปลว่าโฟลเดอร์ ตัวโมเดล และ Attribute ของมันมาถึงไคลเอนต์คนละรอบ ห่างกัน
-- ได้เป็นวินาที และเป็นคนละลำดับทุกครั้ง ของเดิมผูก `workspace.ChildAdded` ครั้งเดียว ถ้าโฟลเดอร์มาถึงก่อน
-- สคริปต์จะรัน (หรือ event ไม่ยิงเพราะ streaming) ก็จะไม่มีอะไรมาปลุกมันอีกเลยทั้งรอบ — เสียงเงียบสนิท
--
-- **ใน Studio ไม่เจอ** เพราะทุกอย่างอยู่ในเครื่องเดียวกันและมาถึงพร้อมกันเสมอ นี่คือเหตุผลที่ Studio มีเสียง
-- แต่เกมจริงไม่มี
--
-- บทเรียนเดียวกับนาฬิกาฟาร์มบนมือถือ (ดู CLAUDE.md): ทุกเวอร์ชันของ "ผูกครั้งเดียวตอนต้น" จะแพ้จังหวะกับ
-- บางโหนดเสมอ และเป็นคนละโหนดทุกรอบ ลูปที่ถามใหม่เรื่อยๆ ไม่มีจังหวะให้แพ้
local watched = nil

task.spawn(function()
  while true do
    local folder = workspace:FindFirstChild(Config.Folder)
    if folder and folder ~= watched then
      watched = folder
      watchFolder(folder)
    end
    -- โมเดลที่ stream เข้ามาทีหลัง (หรือมาถึงตอนที่ยังไม่มี VehicleType) ก็ถูกเก็บในรอบถัดไป
    -- build() กันการสร้างซ้ำอยู่แล้วด้วย `if rigs[model] then return end`
    if watched then
      for _, m in ipairs(watched:GetChildren()) do
        if not rigs[m] then build(m) end
      end
    end
    task.wait(0.5)
  end
end)

-- ---------------------------------------------------------------- ลูปหลัก
RunService.Heartbeat:Connect(function(dt)
  local camera = workspace.CurrentCamera
  local ear = camera and camera.CFrame.Position
  local fade = math.min(1, dt * (SOUND.fade or 7))
  local now = os.clock()

  for model, rig in pairs(rigs) do
    if not rig.hull.Parent or not model.Parent then
      drop(model)
    else
      local far = ear and (ear - rig.hull.Position).Magnitude > SOUND.maxDistance
      local throttle = math.abs(model:GetAttribute("Throttle") or 0)
      local speed = rig.hull.AssemblyLinearVelocity.Magnitude
      -- "กำลังเครื่อง" ไม่ใช่คันเร่งอย่างเดียว — ไหลอยู่ด้วยความเร็วสูงก็ยังมีเสียงลม
      local load = math.clamp(throttle * 0.78 + math.clamp(speed / 45, 0, 1) * 0.35, 0, 1)
      local conf = rig.conf
      local gain = far and 0 or (SOUND.master or 0.6)

      if rig.drone then
        rig.drone.PlaybackSpeed = lerp(rig.drone.PlaybackSpeed, pick(conf.drone.pitch, load), fade)
        rig.drone.Volume = lerp(rig.drone.Volume, pick(conf.drone.volume, load) * gain, fade)
      end
      if rig.wash then
        local wet = math.clamp(speed / 40, 0, 1)
        rig.wash.PlaybackSpeed = lerp(rig.wash.PlaybackSpeed, pick(conf.wash.pitch, wet), fade)
        rig.wash.Volume = lerp(rig.wash.Volume, pick(conf.wash.volume, wet) * gain, fade)
      end

      -- จังหวะฉึกฉัก: ยิงเป็นครั้งๆ ตามอัตราที่คำนวณ ไม่ใช่ลูปต่อเนื่อง จะได้เร่งจังหวะได้จริง
      if #rig.pulses > 0 and not far and now >= rig.nextPulse then
        local rate = pick(conf.pulse.rate, load)
        rig.nextPulse = now + 1 / math.max(rate, 0.5)
        local s = rig.pulses[rig.turn]
        rig.turn = rig.turn % #rig.pulses + 1
        s.PlaybackSpeed = pick(conf.pulse.pitch, load) * (0.96 + math.random() * 0.08)
        s.Volume = pick(conf.pulse.volume, load) * gain * (speed < 1 and throttle < 0.05 and 0.45 or 1)
        s.TimePosition = 0
        s:Play()
      end

      -- ไอน้ำพ่นตอนถอนคันเร่งขณะยังวิ่งอยู่
      if rig.vent and not far and rig.lastThrottle > 0.3 and throttle < 0.05 and speed > 6 then
        rig.vent.PlaybackSpeed = conf.vent.pitch or 1.8
        rig.vent.Volume = (conf.vent.volume or 0.4) * gain
        rig.vent.TimePosition = 0
        rig.vent:Play()
        if conf.vent.length then
          task.delay(conf.vent.length, function() if rig.vent then rig.vent:Stop() end end)
        end
      end
      rig.lastThrottle = throttle
    end
  end
end)

-- ---------------------------------------------------------------- หวูด
--
-- **Net.get() ต้องอยู่ตรงนี้ ห้ามย้ายขึ้นไปบนหัวไฟล์เด็ดขาด**
--
-- มันรอโฟลเดอร์ VehicleNet นาน 30 วินาทีแล้ว `assert` ทิ้งถ้าไม่มา ซึ่งจะ **ฆ่าทั้งสคริปต์** — เดิมเรียกไว้
-- บรรทัดที่ 22 ก่อนโค้ดเสียงทั้งหมด ผลคือเสียงเครื่อง เสียงบูสต์ เสียงแตร ไม่ดังสักอย่างเดียว ทั้งที่ไฟล์
-- เสียงกับ id ถูกต้องหมด
--
-- โฟลเดอร์นั้นเซิร์ฟเวอร์สร้างตอนระบบพาหนะบูต ถ้าเซิร์ฟเวอร์บูตช้ากว่าไคลเอนต์ 30 วินาที (หรือระบบพาหนะ
-- error ตอนบูต) ระบบเสียงก็ตายทั้งรอบ
--
-- ย้ายมาไว้ใน task.spawn ท้ายไฟล์แทน: เสียงเครื่องยนต์ทำงานทันทีโดยไม่ต้องรออะไร ส่วนแตรเป็นของแถมที่
-- ต่อเมื่อเน็ตพร้อม ถ้าไม่พร้อมก็เสียแค่แตร ไม่ใช่เสียทั้งระบบ
task.spawn(function()
  local ok, net = pcall(Net.get)
  if not ok or not net then
    warn("[VehicleSound] ต่อ VehicleNet ไม่ได้ — เสียงแตรจะไม่ดัง (เสียงเครื่องยนต์ยังทำงานปกติ)")
    return
  end
  net.Signal.OnClientEvent:Connect(function(msg)
    if type(msg) ~= "table" or msg.action ~= "Horn" then return end
    for model, rig in pairs(rigs) do
      if model:GetAttribute("Plate") == msg.plate and rig.horn then
        rig.horn.PlaybackSpeed = rig.conf.horn.pitch or 0.4
        rig.horn.Volume = (rig.conf.horn.volume or 0.8) * (SOUND.master or 0.6)
        rig.horn.TimePosition = 0
        rig.horn:Play()
      end
    end
  end)
end)
