-- npcs — 12 Steampunk / Magitech characters on real Roblox rigs.
-- the nine people are R15 rigs (Motor6D joints, Humanoid + Animator) so they play the standard
-- idle/walk animation tracks and wander on their own; every hat, pack and tool is welded to a limb
-- so it rides along. The three slimes have no skeleton, so they bob and hop by moving their body model.
--
-- corrections carried over from the original Command Bar draft:
--   * Enum.Material.Copper does not exist in Roblox — copper is MAT.Metal with a copper Color
--   * a Cylinder part runs along its own X axis, so K.cyl / K.cylX place brims, tanks and dials
--
-- ground props (anvil, cargo crate) stay anchored on purpose: the NPC walks away, the stall does not.
K.SET = "npc"
K.SLOT = 22
K.PER_ROW = 3
K.ORIGIN = Vector3.new(0, 0, 300)

local C = K.C
local MAT = K.MAT
local rgb = Color3.fromRGB

local function steam(part, color, rate)
  local e = Instance.new("ParticleEmitter")
  e.Name = "SteamEmitter"
  e.Color = ColorSequence.new(color or rgb(220, 230, 240))
  e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.9) })
  e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.8, 0.8), NumberSequenceKeypoint.new(1, 1) })
  e.Lifetime = NumberRange.new(1, 1.8); e.Rate = rate or 10
  e.Speed = NumberRange.new(1.5, 3); e.SpreadAngle = Vector2.new(15, 15)
  e.EmissionDirection = Enum.NormalId.Top; e.Parent = part
  return e
end

local function glow(part, color, range, brightness)
  local l = Instance.new("PointLight")
  l.Color = color; l.Range = range or 6; l.Brightness = brightness or 1.6; l.Parent = part
  return l
end

local function pedestal(m, r)
  K.cyl(m, CFrame.new(0, 0.2, 0), r or 1.7, 0.4, MAT.Slate, rgb(45, 45, 52), { name = "Pedestal" })
end

-- =================================================================== MERCHANTS
K.build("Merchant_Barnaby", nil, function(m)
  pedestal(m)
  R.new(m, { baseY = 0.4, skin = rgb(240, 195, 160), shirt = rgb(130, 85, 50), pants = rgb(70, 50, 40) })
  R.hair(m, "short", rgb(120, 82, 44))

  R.attach(m, "Head", function(g, H)
    K.cyl(g, H * CFrame.new(0, 0.52, 0), 0.66, 0.22, MAT.Leather, rgb(90, 55, 30), { name = "PilotCapBrim" })
    K.cyl(g, H * CFrame.new(0, 0.68, 0), 0.44, 0.34, MAT.Leather, rgb(78, 46, 24), { name = "PilotCapCrown" })
    local goggles = K.box(g, H * CFrame.new(0, 0.2, -0.6), Vector3.new(1.12, 0.32, 0.34), MAT.Metal, rgb(190, 140, 40), { name = "Goggles" })
    K.box(g, goggles.CFrame * CFrame.new(0, 0, -0.16), Vector3.new(0.9, 0.22, 0.08), MAT.Neon, rgb(0, 220, 255), { name = "Lens" })
  end, "PilotGear")

  R.attach(m, "UpperTorso", function(g, T)
    local pack = K.box(g, T * CFrame.new(0, 0.05, 0.72), Vector3.new(1.3, 1.4, 0.7), MAT.Metal, rgb(180, 120, 50), { name = "SteamPack" })
    K.band(g, pack.CFrame * CFrame.new(0, 0.35, 0) * K.roll(math.pi / 2), 0.72, 1.36)
    local chimney = K.cyl(g, pack.CFrame * CFrame.new(0.42, 1.1, 0), 0.16, 0.9, MAT.Metal, rgb(140, 90, 30), { name = "Chimney" })
    steam(chimney, rgb(240, 240, 250))
    local balloon = K.ball(g, T * CFrame.new(0, 3.6, 0.5), 2.2, MAT.SmoothPlastic, rgb(180, 50, 40), { name = "MiniBalloon" })
    glow(balloon, rgb(255, 150, 80), 9, 1.4)
    K.rod(g, (T * CFrame.new(0, 2.5, 0.5)).Position, pack.CFrame.Position + Vector3.new(0, 0.7, 0), 0.08, MAT.Metal, C.rope, { name = "BalloonLine" })
  end, "BalloonPack")

  local crate = K.box(m, CFrame.new(-2.4, 1.1, 0.6), Vector3.new(1.8, 1.4, 1.4), MAT.WoodPlanks, rgb(120, 80, 40), { name = "CargoBox" })
  K.gear(m, crate.CFrame * CFrame.new(0, 0, -0.8) * K.yaw(math.pi / 2), 0.45, 8, 0.2, rgb(220, 160, 50))

  R.nametag(m, "บาร์นาบี (Barnaby)", "พ่อค้าเร่บอลลูนไอน้ำ", rgb(255, 180, 80))
  R.prompt(m, "เปิดร้านค้าบอลลูน", "บาร์นาบี")
  R.controller(m, { wander = 3, walkSpeed = 6 })
end)

K.build("Merchant_Zael", nil, function(m)
  pedestal(m)
  R.new(m, { baseY = 0.4, skin = rgb(220, 210, 230), shirt = rgb(35, 30, 60), pants = rgb(25, 20, 45), height = 1.03 })

  R.attach(m, "Head", function(g, H)
    K.ball(g, H * CFrame.new(0, 0.16, 0.1), 1.42, MAT.Fabric, rgb(45, 35, 80), { name = "ArcaneHood" })
    K.box(g, H * CFrame.new(0, 0.06, -0.62), Vector3.new(0.92, 0.18, 0.1), MAT.Neon, rgb(180, 70, 255), { name = "Visor" })
  end, "Hood")

  R.attach(m, "LeftUpperArm", function(g, A)
    local pau = K.box(g, A * CFrame.new(-0.1, 0.5, 0), Vector3.new(1.05, 0.6, 1.15), MAT.Metal, rgb(190, 160, 80), { name = "ManaPauldron" })
    local core = K.ball(g, pau.CFrame * CFrame.new(0, 0.34, 0), 0.44, MAT.Neon, rgb(200, 80, 255), { name = "ManaCore" })
    glow(core, rgb(200, 80, 255), 8, 2)
  end, "Pauldron")

  R.attach(m, "UpperTorso", function(g, T)
    local tray = K.box(g, T * CFrame.new(0, -0.25, -1.5) * K.pitch(math.rad(25)), Vector3.new(2.2, 0.1, 1.3), MAT.ForceField, rgb(100, 50, 255), { name = "HoloDisplay", transparency = 0.5 })
    for i, col in ipairs({ rgb(255, 60, 120), rgb(0, 220, 255), rgb(160, 255, 60) }) do
      local crys = K.box(g, tray.CFrame * CFrame.new((i - 2) * 0.65, 0.45, 0) * CFrame.Angles(math.rad(15), math.rad(30 * i), 0),
        Vector3.new(0.32, 0.75, 0.32), MAT.Neon, col, { name = "Crystal_" .. i })
      glow(crys, col, 5, 2)
    end
  end, "HoloTray")

  R.nametag(m, "ซาเอล (Zael)", "พ่อค้าคริสตัลมิติเวทมนตร์", rgb(140, 100, 255))
  R.prompt(m, "สำรวจวัตถุโบราณ", "ซาเอล")
  R.controller(m, { wander = 2, walkSpeed = 5 })
end)

K.build("Merchant_Grick", nil, function(m)
  pedestal(m)
  R.new(m, { baseY = 0.4, skin = rgb(190, 180, 160), shirt = rgb(60, 65, 55), pants = rgb(45, 45, 40), height = 0.95, face = false })
  R.hair(m, "short", rgb(70, 66, 56))

  R.attach(m, "Head", function(g, H)
    K.box(g, H * CFrame.new(0, -0.12, -0.6), Vector3.new(0.86, 0.66, 0.5), MAT.Metal, rgb(150, 110, 40), { name = "GasMask" })
    for _, s in ipairs({ -1, 1 }) do
      K.cylX(g, H * CFrame.new(0.44 * s, -0.18, -0.52) * K.yaw(math.pi / 2), 0.2, 0.34, MAT.Metal, rgb(50, 50, 50), { name = "Filter" })
    end
    K.cylX(g, H * CFrame.new(0, -0.04, -0.78) * K.yaw(math.pi / 2), 0.13, 0.2, MAT.Glass, rgb(120, 200, 120), { name = "MaskLens", transparency = 0.35 })
  end, "Mask")

  R.attach(m, "UpperTorso", function(g, T)
    local tank = K.cyl(g, T * CFrame.new(0, 0.1, 0.7), 0.5, 1.7, MAT.CorrodedMetal, rgb(90, 120, 90), { name = "ChemTank" })
    K.band(g, tank.CFrame * CFrame.new(0, 0.5, 0), 0.55, 0.14, C.rust)
    K.band(g, tank.CFrame * CFrame.new(0, -0.5, 0), 0.55, 0.14, C.rust)
    steam(tank, rgb(100, 255, 100), 6)
    for i, col in ipairs({ rgb(80, 255, 80), rgb(255, 120, 0) }) do
      local v = K.cyl(g, T * CFrame.new((i == 1 and -0.75 or 0.75), -0.6, -0.5), 0.16, 0.8, MAT.Neon, col, { name = "BioVial" .. i })
      glow(v, col, 4, 1)
    end
  end, "ChemRig")

  R.nametag(m, "กริค (Grick)", "พ่อค้าตลาดมืดอะไหล่พิษ", rgb(120, 255, 120))
  R.prompt(m, "ซื้อขายสารเคมีและอะไหล่", "กริค")
  R.controller(m, { wander = 4, walkSpeed = 7 })
end)

-- ==================================================================== TYCOONS
K.build("Baron_Vane", nil, function(m)
  pedestal(m)
  R.new(m, { baseY = 0.4, skin = rgb(250, 210, 180), shirt = rgb(120, 20, 30), pants = rgb(30, 30, 35), height = 1.06 })
  R.hair(m, "short", rgb(52, 48, 46))
  R.beard(m, rgb(58, 54, 52))

  R.attach(m, "Head", function(g, H)
    K.cyl(g, H * CFrame.new(0, 0.56, 0), 1.02, 0.14, MAT.Fabric, rgb(30, 30, 35), { name = "TopHatBrim" })
    K.cyl(g, H * CFrame.new(0, 1.22, 0), 0.62, 1.3, MAT.Fabric, rgb(25, 25, 30), { name = "TopHatCrown" })
    K.cyl(g, H * CFrame.new(0, 0.7, 0), 0.65, 0.22, MAT.Metal, rgb(225, 180, 50), { name = "GoldBand" })
  end, "TopHat")

  R.paint(m, { "RightUpperArm", "RightLowerArm", "RightHand" }, rgb(220, 175, 55), MAT.Metal)
  R.attach(m, "RightLowerArm", function(g, A)
    K.cyl(g, A * CFrame.new(0.42, 0, 0), 0.17, 1.2, MAT.Metal, rgb(180, 120, 40), { name = "SteamPiston" })
    K.rivets(g, (A * CFrame.new(0, 0.45, -0.36)).Position, (A * CFrame.new(0, -0.45, -0.36)).Position, 4, 0.09, C.brassDark)
  end, "ClockworkArm")

  R.attach(m, "LeftHand", function(g, HD)
    local cane = K.box(g, HD * CFrame.new(0, -1.2, -0.15), Vector3.new(0.16, 3.2, 0.16), MAT.Wood, rgb(35, 30, 25), { name = "CaneShaft" })
    local skull = K.ball(g, cane.CFrame * CFrame.new(0, 1.7, 0), 0.6, MAT.Neon, rgb(255, 40, 70), { name = "RubySkull" })
    glow(skull, rgb(255, 40, 70), 8, 2)
  end, "Cane")

  R.nametag(m, "ลอร์ด เวย์น (Lord Vane)", "เถ้าแก่โรงหลอมมานาและรถจักร", rgb(255, 80, 80))
  R.prompt(m, "เจรจาสัมปทานเหมือง", "ลอร์ด เวย์น")
  R.controller(m, { wander = 2, walkSpeed = 5 })
end)

K.build("Madam_Aurelia", nil, function(m)
  pedestal(m)
  R.new(m, { baseY = 0.4, skin = rgb(250, 225, 210), shirt = rgb(220, 220, 230), pants = rgb(200, 160, 50), height = 1.02, width = 0.95 })
  R.hair(m, "bun", rgb(206, 168, 92))

  R.attach(m, "Head", function(g, H)
    K.gear(g, H * CFrame.new(0, 0.62, 0) * K.roll(math.pi / 2), 0.66, 12, 0.16, rgb(235, 185, 50))
    local mono = K.cylX(g, H * CFrame.new(0.28, 0.12, -0.62) * K.yaw(math.pi / 2), 0.19, 0.1, MAT.Neon, rgb(0, 240, 255), { name = "CyberMonocle" })
    glow(mono, rgb(0, 240, 255), 5, 1.5)
  end, "Tiara")

  R.attach(m, "UpperTorso", function(g, T)
    local cape = K.box(g, T * CFrame.new(0, -0.7, 0.6) * K.pitch(math.rad(8)), Vector3.new(2, 3, 0.14), MAT.Glass, rgb(215, 175, 55), { name = "HoloCape", transparency = 0.32 })
    K.rivets(g, (cape.CFrame * CFrame.new(-0.9, 1.4, 0)).Position, (cape.CFrame * CFrame.new(0.9, 1.4, 0)).Position, 5, 0.1, rgb(235, 185, 50))
    local drone = K.box(g, T * CFrame.new(-2.1, 1.6, 0.4), Vector3.new(1, 1, 1), MAT.Metal, rgb(210, 160, 45), { name = "VaultDrone" })
    local dcore = K.ball(g, drone.CFrame, 0.5, MAT.Neon, rgb(0, 255, 230), { name = "DroneCore" })
    glow(dcore, rgb(0, 255, 230), 9, 2)
    for _, s in ipairs({ -1, 1 }) do
      K.box(g, drone.CFrame * CFrame.new(0.85 * s, 0.18, 0) * K.roll(math.rad(-20 * s)), Vector3.new(1.2, 0.09, 0.5), MAT.Metal, rgb(230, 200, 90), { name = "Wing" })
    end
  end, "CapeAndDrone")

  R.nametag(m, "มาดาม โอเรเลีย (Madam Aurelia)", "ประธานสภาธนาคารรูนควอนตัม", rgb(255, 220, 90))
  R.prompt(m, "เข้าใช้ตู้เซฟเวทมนตร์", "มาดาม โอเรเลีย")
  R.controller(m, { wander = 2, walkSpeed = 5 })
end)

K.build("Don_Tiberius", nil, function(m)
  pedestal(m)
  R.new(m, { baseY = 0.4, skin = rgb(215, 180, 150), shirt = rgb(40, 40, 48), pants = rgb(30, 30, 35), width = 1.14, height = 1.04 })
  R.hair(m, "short", rgb(30, 28, 28))
  R.beard(m, rgb(34, 32, 32))

  R.attach(m, "UpperTorso", function(g, T)
    K.box(g, T * CFrame.new(0, 0.85, 0), Vector3.new(3, 0.7, 1.6), MAT.Leather, rgb(75, 45, 30), { name = "HeavyShoulder" })
    local reactor = K.ball(g, T * CFrame.new(0, 0.2, -0.52), 0.62, MAT.Neon, rgb(150, 0, 255), { name = "ChestReactor" })
    glow(reactor, rgb(150, 0, 255), 9, 2)
  end, "Coat")

  R.attach(m, "Head", function(g, H)
    local pipe = K.cylX(g, H * CFrame.new(0.3, -0.24, -0.66) * K.yaw(math.rad(115)) * K.roll(math.rad(10)), 0.08, 0.8, MAT.Wood, rgb(180, 130, 60), { name = "ManaPipe" })
    steam(pipe, rgb(190, 120, 255), 5)
  end, "Pipe")

  R.paint(m, { "RightUpperArm", "RightLowerArm" }, rgb(50, 50, 60), MAT.DiamondPlate)
  R.attach(m, "RightHand", function(g, HD)
    K.box(g, HD * CFrame.new(0, -0.05, 0), Vector3.new(1.05, 0.9, 1.05), MAT.Metal, rgb(200, 140, 40), { name = "PowerGlove" })
  end, "Glove")

  R.nametag(m, "ดอน ไทบีเรียส (Don Tiberius)", "เจ้าพ่อนายทุนตลาดมืดจักรกล", rgb(180, 90, 255))
  R.prompt(m, "เข้าร่วมงานประมูลลับ", "ดอน ไทบีเรียส")
  R.controller(m, { wander = 2, walkSpeed = 5 })
end)

-- ================================================================== CRAFTSMEN
K.build("Blacksmith_Brannoc", nil, function(m)
  pedestal(m)
  R.new(m, { baseY = 0.4, skin = rgb(210, 160, 130), shirt = rgb(55, 40, 35), pants = rgb(40, 35, 30), width = 1.12, height = 1.04 })
  R.hair(m, "wild", rgb(84, 50, 32))
  R.beard(m, rgb(84, 50, 32), nil, true)

  R.attach(m, "Head", function(g, H)
    local mask = K.box(g, H * CFrame.new(0, 0.42, -0.54), Vector3.new(1.24, 0.36, 0.44), MAT.Metal, rgb(160, 90, 40), { name = "WeldMask" })
    local lit = K.box(g, mask.CFrame * CFrame.new(0, 0, -0.22), Vector3.new(0.86, 0.18, 0.08), MAT.Neon, rgb(255, 150, 0), { name = "GoggleGlow" })
    glow(lit, rgb(255, 150, 0), 6, 1.2)
  end, "WeldMask")

  R.attach(m, "UpperTorso", function(g, T)
    K.box(g, T * CFrame.new(0, -0.35, -0.56), Vector3.new(1.9, 2, 0.22), MAT.Leather, rgb(95, 60, 35), { name = "SmithApron" })
  end, "Apron")

  -- the hammer stands upright in the fist, head at the top, so it never swings through the body
  R.attach(m, "RightHand", function(g, HD)
    local handle = K.box(g, HD * CFrame.new(0, -0.85, -0.1), Vector3.new(0.22, 2, 0.22), MAT.Wood, rgb(80, 55, 40), { name = "HammerHandle" })
    local hhead = K.box(g, handle.CFrame * CFrame.new(0, -1.1, 0), Vector3.new(1, 0.85, 1.5), MAT.Metal, rgb(80, 85, 90), { name = "HammerPistonHead" })
    local magma = K.box(g, hhead.CFrame, Vector3.new(1.35, 0.34, 0.38), MAT.Neon, rgb(255, 85, 0), { name = "MagmaCore" })
    glow(magma, rgb(255, 85, 0), 9, 2)
    steam(hhead, rgb(255, 160, 100), 8)
  end, "Hammer")

  local anvil = K.box(m, CFrame.new(-2.7, 1.2, -0.6), Vector3.new(2, 1.4, 1.6), MAT.Metal, rgb(50, 52, 58), { name = "Anvil" })
  K.box(m, CFrame.new(-2.7, 0.55, -0.6), Vector3.new(1.2, 0.9, 1), MAT.Metal, rgb(44, 46, 52), { name = "AnvilBase" })
  local ingot = K.box(m, anvil.CFrame * CFrame.new(0, 0.85, 0), Vector3.new(1, 0.3, 0.5), MAT.Neon, rgb(255, 100, 20), { name = "HotIngot", cancollide = false })
  glow(ingot, rgb(255, 100, 20), 8, 1.6)

  R.nametag(m, "แบรนนอค (Brannoc)", "ช่างตีเหล็กเตาหลอมลาวาเทคโน", rgb(255, 120, 40))
  R.prompt(m, "ตีบวกและหลอมอาวุธ", "แบรนนอค")
  R.controller(m, { wander = 3, walkSpeed = 6 })
end)

K.build("Mechanic_Lyra", nil, function(m)
  pedestal(m)
  R.new(m, { baseY = 0.4, skin = rgb(245, 205, 185), shirt = rgb(40, 75, 110), pants = rgb(60, 50, 45), height = 0.95, width = 0.94 })
  R.hair(m, "ponytail", rgb(168, 96, 44))

  R.attach(m, "Head", function(g, H)
    local band = K.box(g, H * CFrame.new(0, 0.2, -0.58), Vector3.new(1.18, 0.44, 0.4), MAT.Metal, rgb(200, 160, 60), { name = "MagnifierGoggles" })
    local big = K.cylX(g, band.CFrame * CFrame.new(-0.3, 0, -0.24) * K.yaw(math.pi / 2), 0.19, 0.26, MAT.Neon, rgb(0, 255, 200), { name = "BigLens" })
    K.cylX(g, band.CFrame * CFrame.new(0.26, 0, -0.22) * K.yaw(math.pi / 2), 0.12, 0.22, MAT.Neon, rgb(0, 200, 255), { name = "SmallLens" })
    glow(big, rgb(0, 255, 200), 5, 1.4)
  end, "Goggles")

  R.attach(m, "UpperTorso", function(g, T)
    local pack = K.box(g, T * CFrame.new(0, 0.1, 0.62), Vector3.new(1.3, 1.5, 0.6), MAT.Metal, rgb(180, 140, 70), { name = "SubArmPack" })
    for _, s in ipairs({ -1, 1 }) do
      local arm = K.box(g, pack.CFrame * CFrame.new(0.85 * s, 1, -0.4) * CFrame.Angles(math.rad(-40), math.rad(-30 * s), 0),
        Vector3.new(0.26, 1.5, 0.26), MAT.Metal, rgb(150, 150, 160), { name = "MechArm" })
      if s < 0 then
        K.box(g, arm.CFrame * CFrame.new(0, 0.85, 0), Vector3.new(0.18, 0.65, 0.36), MAT.Metal, rgb(220, 180, 50), { name = "WrenchTool" })
      else
        local torch = K.cyl(g, arm.CFrame * CFrame.new(0, 0.85, 0), 0.14, 0.7, MAT.Neon, rgb(0, 200, 255), { name = "BlowTorch" })
        glow(torch, rgb(0, 200, 255), 6, 1.6)
      end
    end
  end, "SubArms")

  R.attach(m, "LeftHand", function(g, HD)
    K.cylX(g, HD * CFrame.new(0, -0.3, -0.35) * K.pitch(math.rad(60)) * K.yaw(math.pi / 2), 0.46, 0.1, MAT.Metal, rgb(240, 200, 60), { name = "Astrolabe" })
    K.gear(g, HD * CFrame.new(0, -0.3, -0.42) * K.pitch(math.rad(60)) * K.yaw(math.pi / 2), 0.3, 10, 0.07, rgb(200, 160, 50))
  end, "Astrolabe")

  R.nametag(m, "ไลรา (Lyra)", "วิศวกรนาฬิกาจักรกลและมิติ", rgb(70, 180, 255))
  R.prompt(m, "ซ่อมแซมและปรับจูนอุปกรณ์", "ไลรา")
  R.controller(m, { wander = 4, walkSpeed = 8 })
end)

K.build("Gunsmith_Jax", nil, function(m)
  pedestal(m)
  R.new(m, { baseY = 0.4, skin = rgb(230, 190, 160), shirt = rgb(45, 55, 50), pants = rgb(35, 40, 42), height = 0.99 })
  R.hair(m, "short", rgb(40, 36, 34))

  R.attach(m, "Head", function(g, H)
    K.cyl(g, H * CFrame.new(0, 0.56, 0) * K.roll(math.rad(14)), 0.68, 0.3, MAT.Fabric, rgb(50, 70, 60), { name = "Beret" })
    local sensor = K.ball(g, H * CFrame.new(-0.3, 0.12, -0.62), 0.26, MAT.Neon, rgb(0, 255, 120), { name = "TargetSensor" })
    glow(sensor, rgb(0, 255, 120), 5, 1.5)
  end, "Beret")

  R.attach(m, "RightHand", function(g, HD)
    local gun = K.box(g, HD * CFrame.new(0.05, 0.15, -1) * K.pitch(math.rad(-12)), Vector3.new(0.36, 0.68, 2.8), MAT.Metal, rgb(150, 110, 50), { name = "RifleBody" })
    local coil = K.cyl(g, gun.CFrame * CFrame.new(0, 0.18, -1.6) * K.pitch(math.pi / 2), 0.22, 1.3, MAT.Neon, rgb(0, 230, 255), { name = "TeslaCoil" })
    glow(coil, rgb(0, 230, 255), 8, 2)
    K.box(g, gun.CFrame * CFrame.new(0, -0.08, 1.6), Vector3.new(0.32, 0.62, 1), MAT.Wood, rgb(80, 50, 30), { name = "RifleStock" })
  end, "Rifle")

  R.attach(m, "UpperTorso", function(g, T)
    local power = K.box(g, T * CFrame.new(0, 0.05, 0.66), Vector3.new(1.4, 1.6, 0.7), MAT.Metal, rgb(70, 75, 80), { name = "BatteryPack" })
    local cell = K.cyl(g, power.CFrame, 0.26, 1.2, MAT.Neon, rgb(0, 220, 255), { name = "PlasmaCell" })
    glow(cell, rgb(0, 220, 255), 7, 1.8)
  end, "Battery")

  R.nametag(m, "แจ็กซ์ (Jax)", "ช่างสรรพาวุธบีมเวทมนตร์", rgb(0, 230, 255))
  R.prompt(m, "สร้างและทดสอบปืนเวท", "แจ็กซ์")
  R.controller(m, { wander = 4, walkSpeed = 7 })
end)

-- ===================================================================== SLIMES
-- the jelly lives in a "Body" child so SlimeController can bob and hop it while the pedestal stays put
local function slimeBody(m, size, jelly, mat, trans)
  K.cyl(m, CFrame.new(0, 0.2, 0), size * 0.62, 0.4, MAT.Slate, rgb(35, 35, 40), { name = "Pedestal" })
  local body = K.model(m, "Body")
  local r = size / 2
  local C0 = CFrame.new(0, 0.4 + r, 0)
  local core = K.ball(body, C0, size, mat, jelly, { name = "Core", transparency = trans })
  body.PrimaryPart = core
  for i = 1, 4 do
    local a = math.rad(i * 90)
    K.ball(body, C0 * CFrame.new(math.cos(a) * r * 1.1, -r * 0.5, math.sin(a) * r * 1.1), size * 0.4, mat, jelly,
      { name = "BlobDrop_" .. i, transparency = trans, cancollide = false })
  end
  return body, core, C0, r
end

K.build("Monster_SteamSlime", nil, function(m)
  local body, core, C0, r = slimeBody(m, 3.6, rgb(240, 150, 40), MAT.Glass, 0.3)

  local inner = K.ball(body, C0, 1.9, MAT.Metal, rgb(180, 110, 40), { name = "InnerBoiler", cancollide = false })
  glow(inner, rgb(255, 120, 20), 12, 2.5)
  K.band(body, C0, 1.0, 2.0, C.brassDark)
  local chimney = K.cyl(body, C0 * CFrame.new(0, r + 0.6, 0), 0.4, 2, MAT.Metal, rgb(140, 95, 35), { name = "SteamChimney" })
  K.cyl(body, C0 * CFrame.new(0, r + 1.6, 0), 0.55, 0.3, MAT.Metal, C.brassDark, { name = "ChimneyCap" })
  steam(chimney, rgb(255, 230, 200), 20)

  for _, s in ipairs({ -1, 1 }) do
    local eye = K.cylX(body, C0 * CFrame.new(0.75 * s, 0.45, -1.62) * K.yaw(math.pi / 2 + math.rad(-15 * s)), 0.42, 0.36, MAT.Metal, rgb(230, 180, 60), { name = "GaugeEye", cancollide = false })
    K.cylX(body, eye.CFrame * CFrame.new(-0.2, 0, 0), 0.32, 0.1, MAT.SmoothPlastic, rgb(255, 255, 240), { name = "Dial", cancollide = false })
    K.box(body, eye.CFrame * CFrame.new(-0.27, 0.11, 0) * CFrame.Angles(math.rad(30), 0, 0), Vector3.new(0.05, 0.28, 0.05), MAT.SmoothPlastic, C.black, { name = "Needle", cancollide = false })
  end

  R.nametag(m, "บอยลี่ สไลม์ไอน้ำ (Boilie)", "มอนสเตอร์จักรกลอุณหภูมิสูง", rgb(255, 160, 50), core)
  R.prompt(m, "ต่อสู้ / เก็บสะเก็ดไอน้ำ", "บอยลี่", core)
  R.slimeController(m, { wander = 5, hopEvery = 3, hopHeight = 1.5 })
end)

K.build("Monster_PlasmaSlime", nil, function(m)
  local body, core, C0, r = slimeBody(m, 3.6, rgb(30, 160, 255), MAT.Glass, 0.3)

  local cube = K.box(body, C0 * CFrame.Angles(math.rad(45), math.rad(45), 0), Vector3.new(1.4, 1.4, 1.4), MAT.Neon, rgb(0, 255, 255), { name = "PlasmaCoreCube", cancollide = false })
  glow(cube, rgb(0, 255, 255), 15, 3)
  local sp = Instance.new("Sparkles"); sp.SparkleColor = rgb(0, 255, 255); sp.Parent = cube

  local function ring(cf, rad, thick, color, trans)
    local g = K.model(body, "Ring")
    for i = 0, 23 do
      local a0, a1 = i * math.pi / 12, (i + 1) * math.pi / 12
      K.rod(g, (cf * CFrame.new(math.cos(a0) * rad, 0, math.sin(a0) * rad)).Position,
               (cf * CFrame.new(math.cos(a1) * rad, 0, math.sin(a1) * rad)).Position,
        thick, MAT.Neon, color, { cancollide = false, transparency = trans })
    end
  end
  ring(C0 * CFrame.Angles(math.rad(72), 0, math.rad(18)), 2.4, 0.09, rgb(150, 0, 255), 0.35)
  ring(C0 * CFrame.Angles(math.rad(-64), math.rad(50), math.rad(-24)), 2.1, 0.07, rgb(0, 220, 255), 0.45)

  for _, s in ipairs({ -1, 1 }) do
    local eye = K.box(body, C0 * CFrame.new(0.7 * s, 0.5, -1.6) * K.roll(math.rad(20 * -s)), Vector3.new(0.6, 0.2, 0.2), MAT.Neon, rgb(0, 255, 255), { name = "CyberEye", cancollide = false })
    glow(eye, rgb(0, 255, 255), 4, 1.2)
  end

  R.nametag(m, "โวลต์ สไลม์พลาสมา (Volt)", "มอนสเตอร์แกนพลังงานควอนตัม", rgb(0, 230, 255), core)
  R.prompt(m, "กักเก็บประจุพลังงาน", "โวลต์", core)
  R.slimeController(m, { wander = 6, hopEvery = 2.4, hopHeight = 2.2, hopTime = 0.55 })
end)

K.build("Monster_BioSlime", nil, function(m)
  local body, core, C0, r = slimeBody(m, 3.8, rgb(80, 240, 50), MAT.Glass, 0.2)

  K.gear(body, C0 * CFrame.new(-0.4, 0, 0.2) * CFrame.Angles(math.rad(30), math.rad(20), 0) * K.yaw(math.pi / 2), 0.6, 10, 0.3, rgb(150, 100, 40))
  K.cyl(body, C0 * CFrame.new(0.5, -0.2, -0.3) * CFrame.Angles(math.rad(-25), math.rad(45), 0), 0.25, 1.8, MAT.Metal, rgb(90, 95, 100), { name = "SubmergedPipe", cancollide = false })
  K.box(body, C0 * CFrame.new(1.7, 0.3, 0) * K.roll(math.rad(-15)), Vector3.new(0.2, 1.6, 1.6), MAT.DiamondPlate, rgb(80, 85, 90), { name = "ScrapShield", cancollide = false })
  steam(core, rgb(120, 255, 80), 12)

  for _, s in ipairs({ -1, 1 }) do
    local eye = K.ball(body, C0 * CFrame.new(0.7 * s, 0.4, -1.7), 0.5, MAT.Neon, rgb(255, 240, 40), { name = "ToxicEye", cancollide = false })
    glow(eye, rgb(255, 240, 40), 5, 1.4)
  end
  local third = K.ball(body, C0 * CFrame.new(0, 0.9, -1.6), 0.4, MAT.Neon, rgb(255, 50, 50), { name = "ToxicEyeCenter", cancollide = false })
  glow(third, rgb(255, 50, 50), 5, 1.6)

  R.nametag(m, "กังก์ สไลม์กรดชีวะ (Gunk)", "มอนสเตอร์ของเสียกัมมันตรังสี", rgb(100, 255, 80), core)
  R.prompt(m, "เก็บตัวอย่างพิษ", "กังก์", core)
  R.slimeController(m, { wander = 4, hopEvery = 3.6, hopHeight = 1.2, hopTime = 0.85 })
end)
