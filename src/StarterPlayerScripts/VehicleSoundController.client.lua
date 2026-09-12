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
local net = Net.get()

local SOUND = Config.Sound
if not (SOUND and SOUND.enabled) then return end

local rigs = {}                                  -- model -> rig

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
  if not (conf and hull) then return end

  local rig = { model = model, hull = hull, conf = conf, nextPulse = 0, turn = 1, lastThrottle = 0, pulses = {} }
  if conf.drone then rig.drone = newSound(hull, conf.drone.id, true) end
  if conf.wash then rig.wash = newSound(hull, conf.wash.id, true) end
  if conf.pulse then
    for i, id in ipairs(conf.pulse.ids) do rig.pulses[i] = newSound(hull, id, false) end
  end
  if conf.horn then rig.horn = newSound(hull, conf.horn.id, false) end
  if conf.vent then rig.vent = newSound(hull, conf.vent.id, false) end
  if rig.drone then rig.drone:Play() end
  if rig.wash then rig.wash:Play() end
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

task.spawn(function()
  local folder = workspace:FindFirstChild(Config.Folder) or workspace:WaitForChild(Config.Folder, 60)
  if folder then watchFolder(folder) end
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
