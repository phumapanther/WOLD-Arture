-- พอร์ตจากโรงงาน WOLD-Models/models/monsters.lua (2026-09-27 เฟส 2d สัตว์เลี้ยง) — **แก้รูปทรงที่โรงงานแล้วคัดลอกกลับมา**
-- โกเลมหินใช้จานสีหิน/สีต่อก้อนของ modelkit/stone.lua ในโรงงาน ซึ่งรีโปนี้ไม่มี จึงใส่เท่าที่ใช้ไว้ตรงนี้
K.SC = K.SC or { granite = Color3.fromRGB(126, 124, 128) }
K.stint = K.stint or function(rng, base, amt)
  return base:Lerp(rng:NextNumber() > 0.5 and K.C.white or K.C.black, rng:NextNumber() * (amt or 0.14))
end

-- monsters — the hostile cast. Three rig families, picked by what the creature actually is:
--   * upright and roughly human  -> R.new (real R15, stock Roblox animation ids)
--   * four legs                  -> R.quad (procedural gait, modelkit/beast.lua)
--   * eight legs / wings         -> R.spider / R.bird
--
-- Nothing here is scaled past what HumanoidDescription allows, so a "big" monster is made big with
-- PLATING rather than with a scale field Roblox would quietly clamp back to 1.05.
--
-- Combat hooks live on attributes (Damage, AttackRange, AggroRange, Faction) rather than in code:
-- the game systems in WOLD-Arture read those, and nothing here depends on them existing.
K.SET = "monsters"
K.SLOT = 40
K.PER_ROW = 5
K.ORIGIN = Vector3.new(0, 0, 8300)

local C, MAT = K.C, K.MAT
local rgb = Color3.fromRGB

local BONE = rgb(226, 220, 200)
local ROT = rgb(104, 126, 92)

local function stats(m, t) K.attrs(m, t) end

local function onLimb(m, limb, cf, size, mat, color, name)
  local p = R.limbPart(m, name or "Detail", cf, size, mat, color)
  R.joint(limb, p, limb.CFrame, (name or "Detail") .. "Weld")
  return p
end

-- ============================================================ 1. skeleton warrior
K.build("Monster_Skeleton", nil, function(m)
  R.new(m, { skin = BONE, shirt = BONE, pants = BONE, face = false, health = 45, walkSpeed = 8, width = 0.85, proportion = 1 })
  R.paint(m, R.LIMBS, BONE, MAT.Slate)
  -- the skull: two black sockets and a jaw line do more than any amount of geometry
  R.attach(m, "Head", function(g, H)
    for _, sx in ipairs({ -1, 1 }) do
      local socket = K.box(g, H * CFrame.new(sx * 0.28, 0.12, -0.56), Vector3.new(0.34, 0.3, 0.18), MAT.SmoothPlastic, C.black, { name = "Socket" })
      K.ball(g, socket.CFrame * CFrame.new(0, 0, -0.04), 0.16, MAT.Neon, rgb(120, 220, 255), { name = "Spark" })
    end
    K.box(g, H * CFrame.new(0, -0.34, -0.5), Vector3.new(0.7, 0.14, 0.3), MAT.Slate, BONE:Lerp(C.black, 0.15), { name = "Jaw" })
    for i = -2, 2 do
      K.box(g, H * CFrame.new(i * 0.13, -0.24, -0.56), Vector3.new(0.09, 0.16, 0.1), MAT.Slate, BONE, { name = "Tooth" })
    end
  end, "Skull")
  -- a ribcage over the torso, which is what stops a bone-coloured R15 reading as a pale person
  R.attach(m, "UpperTorso", function(g, T)
    K.box(g, T * CFrame.new(0, 0, 0), Vector3.new(0.34, 1.6, 0.34), MAT.Slate, BONE:Lerp(C.black, 0.1), { name = "Spine" })
    for i = 0, 4 do
      local y = 0.55 - i * 0.3
      for _, sx in ipairs({ -1, 1 }) do
        K.box(g, T * CFrame.new(sx * 0.42, y, 0) * K.roll(sx * 0.12), Vector3.new(0.7, 0.14, 0.9), MAT.Slate, BONE, { name = "Rib" })
      end
    end
  end, "Ribs")
  -- ท่าถือดาบ: ด้ามอยู่ในฝ่ามือ ปลายชี้ขึ้น **เอนไปข้างหน้า 17° และกางออกข้างตัว 8°**
  --
  -- ตัวเลขเดียวกับเฟส `mapgen/86_repin_held_gear.lua` ในเกมหลัก ซึ่งเป็นตัวที่จัดท่าให้โมเดลที่อยู่ในเพลสแล้ว
  -- **`K.pitch` ค่าบวกเอนไปข้างหลัง** (UpVector = (0, cos t, +sin t) และด้านหน้าของโมเดลคือ -Z) ค่าลบจึงคือเอนหน้า
  -- ของเดิมเป็น `pitch(72)` = ดาบนอนชี้ไปข้างหลังเกือบขนานพื้น ซึ่งคืออาการที่ผู้ใช้ส่งภาพมาให้ดู
  R.attach(m, "RightHand", function(g, HD)
    local grip = K.box(g, HD * CFrame.new(0.2, -0.1, -0.45) * K.pitch(math.rad(-17)) * K.roll(math.rad(-8)), Vector3.new(0.22, 1.3, 0.22), MAT.Wood, C.leather, { name = "Grip" })
    K.box(g, grip.CFrame * CFrame.new(0, 0.75, 0), Vector3.new(0.9, 0.24, 0.26), MAT.Metal, C.rust, { name = "Guard" })
    K.box(g, grip.CFrame * CFrame.new(0, 3.1, 0), Vector3.new(0.95, 4.4, 0.26), MAT.Metal, rgb(146, 142, 132), { name = "Blade" })
    K.box(g, grip.CFrame * CFrame.new(0, 3.1, 0), Vector3.new(0.3, 3.6, 0.3), MAT.Metal, rgb(110, 106, 100), { name = "Fuller" })
    K.wedge(g, grip.CFrame * CFrame.new(0, 5.7, 0.13) * K.pitch(math.pi), Vector3.new(0.95, 1.1, 0.26), MAT.Metal, rgb(146, 142, 132))
  end, "RustedSword")
  -- โล่รัดอยู่กับ **ท่อนแขนล่าง** ด้านนอก ทรงเดียวกับโล่ที่ผู้เล่นถือ (`GRIP.Shield` ใน WeaponVisuals ของเกมหลัก)
  -- ไม่ใช่แผ่นที่ลอยอยู่หน้าฝ่ามือ · yaw +90° พลิกหน้าโล่ (-Z ของแผ่น) ให้ไปชี้ -X = ด้านนอกของแขนซ้าย
  -- และความกว้างของใบไปวางตามแนวหน้า-หลัง ซึ่งเป็นทรงของโล่ที่รัดแขนจริง
  R.attach(m, "LeftLowerArm", function(g, LA)
    local sh = K.box(g, LA * CFrame.new(-0.73, 0.15, 0) * K.yaw(math.rad(90)), Vector3.new(2.6, 3.4, 0.3), MAT.Wood, C.plankDark, { name = "Shield" })
    K.box(g, sh.CFrame * CFrame.new(0, 0, -0.2), Vector3.new(2.2, 0.3, 0.16), MAT.Metal, C.rust, { name = "Band" })
    K.ball(g, sh.CFrame * CFrame.new(0, 0, -0.3), 0.8, MAT.Metal, C.rust, { name = "Boss" })
  end, "Shield")
  R.controller(m, { wander = 14, walkSpeed = 8, wanderMin = 3, wanderMax = 7 })
  R.nametag(m, "โครงกระดูก", "อันเดด", rgb(220, 230, 255))
  stats(m, { Damage = 12, AttackRange = 7, AggroRange = 40, Faction = "undead", Tier = 1 })
end)

-- ============================================================ 2. giant spider
K.build("Monster_Spider", nil, function(m)
  R.spider(m, {
    kind = "spider", color = rgb(38, 34, 40), abdomenColor = rgb(28, 24, 30),
    legColor = rgb(30, 27, 33), eyeColor = rgb(255, 96, 60), stripe = rgb(214, 60, 48),
    body = { len = 5, w = 4.4, h = 2.8 }, abdomen = { d = 7.5, back = 0.95, lift = 0.9 },
    legs = { pairs = 4, upper = 5.4, lower = 6.4, r = 0.46, rise = 5.6, fan = 0.7, swing = 0.45, fold = 0.5 },
    walkSpeed = 12, health = 70,
  })
  R.beastController(m, { wander = 24, walkSpeed = 12, strideRate = 1.1, bob = 0.08, wanderMin = 2, wanderMax = 5 })
  R.nametag(m, "แมงมุมยักษ์", "สัตว์ร้าย", rgb(255, 140, 110), m:FindFirstChild("Torso"))
  stats(m, { Damage = 16, AttackRange = 8, AggroRange = 55, Faction = "beast", Tier = 2 })
end)

-- ============================================================ 3. wolf
K.build("Monster_Wolf", nil, function(m)
  local coat = rgb(92, 92, 98)
  local _, hum, P = R.quad(m, {
    kind = "wolf", color = coat, belly = rgb(156, 156, 160), legColor = rgb(74, 74, 80),
    body = { len = 9, w = 3.8, h = 4.2 },
    legs = { upper = 3.2, lower = 3, r = 0.55, hoof = 0.6, swing = 0.72, fold = 0.9 },
    neck = { len = 2.4, r = 1.4, reach = 2, rise = 1.4 },
    head = { len = 3.6, w = 2.2, h = 2.2, snout = 1.8 }, snoutColor = rgb(58, 58, 64),
    ears = { len = 1.8, w = 0.4, d = 1.3, up = true }, earColor = rgb(66, 66, 72),
    tail = { len = 5, r = 0.62, segs = 4, droop = 0.35, swing = 0.3, tuft = rgb(58, 58, 64) },
    hoofColor = rgb(40, 40, 46), walkSpeed = 14, health = 80,
  })
  for _, sx in ipairs({ -1, 1 }) do
    onLimb(m, P.head, P.head.CFrame * CFrame.new(sx * 0.55, 0.3, -1.2), Vector3.new(0.34, 0.26, 0.22), MAT.Neon, rgb(255, 196, 60), "Eye")
    onLimb(m, P.head, P.head.CFrame * CFrame.new(sx * 0.5, -0.75, -2.4) * K.pitch(0.3), Vector3.new(0.24, 0.7, 0.24), MAT.Slate, BONE, "Fang")
  end
  for i = 0, 5 do                                -- hackles raised down the spine: the threat display
    onLimb(m, P.torso, CFrame.new(0, 9.6, -3.4 + i * 1.3) * K.pitch(-0.25),
      Vector3.new(0.3, 1.5 - math.abs(i - 2.5) * 0.22, 0.9), MAT.Fabric, rgb(58, 58, 64), "Hackle")
  end
  R.beastController(m, { wander = 30, walkSpeed = 14, strideRate = 0.9, bob = 0.16, wanderMin = 2, wanderMax = 6 })
  R.nametag(m, "หมาป่า", "สัตว์ร้าย", rgb(200, 210, 230), P.head)
  stats(m, { Damage = 18, AttackRange = 8, AggroRange = 60, Faction = "beast", Tier = 2 })
end)

-- ============================================================ 4. bandit
K.build("Monster_Bandit", nil, function(m)
  R.new(m, { skin = rgb(214, 168, 132), shirt = rgb(64, 56, 50), pants = rgb(48, 42, 38), health = 60, walkSpeed = 9 })
  R.hair(m, "wild", rgb(52, 38, 28))
  R.attach(m, "Head", function(g, H)
    K.box(g, H * CFrame.new(0, -0.2, -0.54), Vector3.new(1.18, 0.5, 0.22), MAT.Fabric, C.paintRed, { name = "Mask" })
    K.box(g, H * CFrame.new(0, 0.5, 0), Vector3.new(1.3, 0.5, 1.3), MAT.Fabric, rgb(70, 60, 52), { name = "Bandana" })
  end, "Mask")
  R.attach(m, "UpperTorso", function(g, T)
    K.box(g, T * CFrame.new(0, 0.1, -0.55), Vector3.new(1.9, 1.7, 0.24), MAT.Leather, C.leather, { name = "Jerkin" })
    for _, sx in ipairs({ -1, 1 }) do
      K.box(g, T * CFrame.new(sx * 0.3, 0.1, 0) * K.roll(sx * 0.5), Vector3.new(0.3, 2.4, 1.5), MAT.Leather, rgb(72, 52, 38), { name = "Strap" })
    end
    K.box(g, T * CFrame.new(0, -0.9, 0), Vector3.new(2.1, 0.5, 1.4), MAT.Leather, rgb(58, 42, 32), { name = "Belt" })
  end, "Kit")
  R.attach(m, "RightHand", function(g, HD)
    local haft = K.box(g, HD * CFrame.new(0, -0.1, -0.45) * K.pitch(math.rad(75)), Vector3.new(0.24, 2.6, 0.24), MAT.Wood, C.wood, { name = "Haft" })
    K.wedge(g, haft.CFrame * CFrame.new(0.55, 1.15, 0) * K.yaw(math.pi / 2), Vector3.new(0.24, 1.1, 1.3), MAT.Metal, rgb(150, 150, 156))
    K.box(g, haft.CFrame * CFrame.new(0.15, 1.15, 0), Vector3.new(0.6, 1.1, 0.3), MAT.Metal, rgb(120, 120, 128), { name = "AxeHead" })
  end, "HandAxe")
  R.controller(m, { wander = 16, walkSpeed = 9 })
  R.nametag(m, "โจรป่า", "มนุษย์", rgb(255, 140, 120))
  stats(m, { Damage = 20, AttackRange = 7, AggroRange = 45, Faction = "bandit", Tier = 2 })
end)

-- ============================================================ 5. ghoul
K.build("Monster_Ghoul", nil, function(m)
  R.new(m, { skin = ROT, shirt = rgb(78, 74, 62), pants = rgb(62, 58, 50), face = false, health = 55, walkSpeed = 6 })
  R.paint(m, { "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }, ROT, MAT.Sand)
  R.eyes(m, { color = rgb(255, 240, 190) })
  R.attach(m, "Head", function(g, H)
    K.box(g, H * CFrame.new(0, -0.36, -0.46), Vector3.new(0.8, 0.26, 0.4), MAT.SmoothPlastic, ROT:Lerp(C.black, 0.4), { name = "Maw" })
    for i = -1, 1 do
      K.box(g, H * CFrame.new(i * 0.22, -0.3, -0.54) * K.pitch(0.2), Vector3.new(0.12, 0.3, 0.12), MAT.Slate, BONE, { name = "Tooth" })
    end
    for _, sx in ipairs({ -1, 1 }) do            -- sunken cheeks
      K.box(g, H * CFrame.new(sx * 0.42, -0.08, -0.42), Vector3.new(0.2, 0.5, 0.3), MAT.Sand, ROT:Lerp(C.black, 0.28), { name = "Hollow" })
    end
  end, "Maw")
  -- rags rather than clothes: strips hanging off the torso read as rot without a texture
  R.attach(m, "UpperTorso", function(g, T)
    for i = -2, 2 do
      K.box(g, T * CFrame.new(i * 0.38, -0.9 - math.abs(i) * 0.2, -0.55) * K.roll(i * 0.08),
        Vector3.new(0.34, 1.6 - math.abs(i) * 0.3, 0.12), MAT.Fabric, rgb(86, 82, 70), { name = "Rag" })
    end
    K.box(g, T * CFrame.new(0, 0.3, -0.55), Vector3.new(1.2, 0.9, 0.2), MAT.Sand, ROT:Lerp(C.black, 0.25), { name = "OpenRibs" })
  end, "Rags")
  R.controller(m, { wander = 10, walkSpeed = 6, wanderMin = 5, wanderMax = 11 })
  R.nametag(m, "ปีศาจซาก", "อันเดด", rgb(160, 220, 150))
  stats(m, { Damage = 15, AttackRange = 6, AggroRange = 35, Faction = "undead", Tier = 2 })
end)

-- ============================================================ 6. stone golem
-- HumanoidDescription clamps HeightScale to about 1.05, so a golem cannot be made big by asking
-- for a big rig. It is made big by ARMOURING one: slabs standing off every limb roughly double the
-- silhouette, and the stock R15 walk still drives it.
K.build("Monster_StoneGolem", nil, function(m)
  local stone, core = K.SC.granite, rgb(255, 140, 50)
  R.new(m, { skin = stone, shirt = stone, pants = stone, face = false, health = 260, walkSpeed = 5, width = 1.1, height = 1.05 })
  R.paint(m, R.LIMBS, stone, MAT.Rock)
  local plates = {
    { "UpperTorso", CFrame.new(0, 0.1, 0), Vector3.new(2.5, 1.9, 1.4) },
    { "LowerTorso", CFrame.new(0, 0, 0), Vector3.new(2.3, 0.9, 1.3) },
    { "LeftUpperArm", CFrame.new(-0.3, 0, 0), Vector3.new(1.35, 1.5, 1.35) },
    { "RightUpperArm", CFrame.new(0.3, 0, 0), Vector3.new(1.35, 1.5, 1.35) },
    { "LeftLowerArm", CFrame.new(-0.3, 0, 0), Vector3.new(1.25, 1.3, 1.25) },
    { "RightLowerArm", CFrame.new(0.3, 0, 0), Vector3.new(1.25, 1.3, 1.25) },
    { "LeftHand", CFrame.new(0, -0.15, 0), Vector3.new(1.5, 0.95, 1.5) },
    { "RightHand", CFrame.new(0, -0.15, 0), Vector3.new(1.5, 0.95, 1.5) },
    { "LeftUpperLeg", CFrame.new(-0.18, 0, 0), Vector3.new(1.4, 1.7, 1.4) },
    { "RightUpperLeg", CFrame.new(0.18, 0, 0), Vector3.new(1.4, 1.7, 1.4) },
    { "LeftLowerLeg", CFrame.new(0, 0, 0), Vector3.new(1.3, 1.5, 1.3) },
    { "RightLowerLeg", CFrame.new(0, 0, 0), Vector3.new(1.3, 1.5, 1.3) },
    { "Head", CFrame.new(0, 0.05, 0), Vector3.new(1.5, 1.3, 1.5) },
  }
  -- pauldrons ride OUTBOARD of the shoulders: that overhang is where the mass reads from
  for _, sx in ipairs({ -1, 1 }) do
    plates[#plates + 1] = { sx < 0 and "LeftUpperArm" or "RightUpperArm", CFrame.new(sx * 0.35, 0.62, 0), Vector3.new(1.7, 0.9, 1.6) }
  end
  local rng = Random.new(901)
  for _, pl in ipairs(plates) do
    R.attach(m, pl[1], function(g, L)
      K.box(g, L * pl[2] * K.yaw((rng:NextNumber() - 0.5) * 0.2) * K.roll((rng:NextNumber() - 0.5) * 0.14),
        pl[3], MAT.Rock, K.stint(rng, stone, 0.18), { name = "Plate" })
    end, "Plate_" .. pl[1])
  end
  R.attach(m, "UpperTorso", function(g, T)       -- the heart the players are meant to aim at
    local heart = K.ball(g, T * CFrame.new(0, 0.2, -0.72), 0.55, MAT.Neon, core, { name = "Core" })
    local l = Instance.new("PointLight"); l.Color = core; l.Range = 24; l.Brightness = 2.4; l.Parent = heart
    for i = 0, 2 do                              -- a few thin cracks; eight thick ones read as a sticker
      K.box(g, T * CFrame.new(0, 0.2, -0.74) * K.roll(0.4 + i * 1.1), Vector3.new(1.5, 0.1, 0.14), MAT.Neon, core, { name = "Crack" })
    end
  end, "Core")
  R.attach(m, "Head", function(g, H)
    for _, sx in ipairs({ -1, 1 }) do
      K.box(g, H * CFrame.new(sx * 0.36, 0.16, -1.05), Vector3.new(0.42, 0.24, 0.22), MAT.Neon, core, { name = "Eye" })
    end
  end, "Eyes")
  R.controller(m, { wander = 12, walkSpeed = 5, wanderMin = 6, wanderMax = 13 })
  R.nametag(m, "โกเลมหิน", "อสูรกาย", rgb(255, 160, 80))
  stats(m, { Damage = 40, AttackRange = 10, AggroRange = 50, Faction = "construct", Tier = 4 })
end)

-- ============================================================ 7. bat
K.build("Monster_Bat", nil, function(m)
  local fur = rgb(58, 44, 48)
  local _, hum = R.bird(m, {
    kind = "bat", color = fur, headColor = fur,
    len = 2.6, w = 2.4, h = 2.4, legLen = 1, wing = 1.2, flap = 0.9,
    beak = rgb(64, 50, 54), foot = rgb(70, 58, 60), tailColor = fur,
    walkSpeed = 3, health = 25,
  })
  local head, body = m:FindFirstChild("Head"), m:FindFirstChild("Torso")
  -- membrane wings: three struts and a skin per side, hung off R.bird's wing stub so they flap
  for _, sx in ipairs({ -1, 1 }) do
    local w = m:FindFirstChild("Wing" .. (sx < 0 and "L" or "R"))
    if w then
      w.Transparency = 1
      for i = 0, 2 do
        local len = 6 - i * 1.2
        onLimb(m, w, w.CFrame * CFrame.new(sx * len / 2, 0.1, -1 + i * 1.3) * K.yaw(sx * (0.25 - i * 0.25)),
          Vector3.new(len, 0.22, 0.22), MAT.Slate, rgb(44, 34, 38), "Strut")
      end
      onLimb(m, w, w.CFrame * CFrame.new(sx * 3.1, 0, 0.3), Vector3.new(6, 0.14, 3.6), MAT.SmoothPlastic, rgb(72, 48, 56), "Membrane")
    end
  end
  for _, sx in ipairs({ -1, 1 }) do
    onLimb(m, head, head.CFrame * CFrame.new(sx * 0.6, 1.1, 0.2) * K.roll(sx * 0.25), Vector3.new(0.24, 2.2, 1.2), MAT.SmoothPlastic, rgb(76, 58, 62), "Ear")
    onLimb(m, head, head.CFrame * CFrame.new(sx * 0.35, 0.1, -0.85), Vector3.new(0.3, 0.26, 0.2), MAT.Neon, rgb(255, 90, 70), "Eye")
    onLimb(m, head, head.CFrame * CFrame.new(sx * 0.25, -0.55, -0.7) * K.pitch(0.25), Vector3.new(0.18, 0.5, 0.18), MAT.Slate, BONE, "Fang")
  end
  R.beastController(m, { wander = 18, walkSpeed = 3, strideRate = 2.2, bob = 0.3, wanderMin = 2, wanderMax = 5 })
  R.nametag(m, "ค้างคาว", "สัตว์ร้าย", rgb(220, 160, 180), head)
  stats(m, { Damage = 8, AttackRange = 6, AggroRange = 40, Faction = "beast", Tier = 1 })
end)

-- ============================================================ 8. boar
K.build("Monster_Boar", nil, function(m)
  local hide = rgb(76, 62, 52)
  local _, hum, P = R.quad(m, {
    kind = "boar", color = hide, belly = rgb(96, 80, 66), legColor = rgb(56, 46, 40),
    body = { len = 9, w = 5, h = 5.4 },
    legs = { upper = 2.2, lower = 2.1, r = 0.7, hoof = 0.7, swing = 0.6, fold = 0.8 },
    neck = { len = 1.2, r = 2, reach = 1, rise = 0.2 },
    head = { len = 3.8, w = 2.8, h = 2.8, snout = 1.6 }, snoutColor = rgb(60, 50, 44),
    ears = { len = 1.2, w = 0.4, d = 1.2, up = true },
    -- tusks are horns aimed forward and up, so the same chain builder does them
    horns = { len = 2, r = 0.3, out = 0.35, fwd = 1.1, curve = 0.2, rise = 1.1, segs = 3, color = BONE },
    tail = { len = 1.6, r = 0.28, segs = 3, droop = -0.3, swing = 0.6, tuft = rgb(48, 40, 34) },
    hoofColor = rgb(34, 30, 28), walkSpeed = 15, health = 110,
  })
  for i = 0, 6 do                                -- bristled ridge from the skull to the shoulders
    onLimb(m, P.torso, CFrame.new(0, 8.3, -3.6 + i * 1.1) * K.pitch(-0.35),
      Vector3.new(0.3, 2.2 - math.abs(i - 1) * 0.22, 0.8), MAT.Fabric, rgb(40, 34, 30), "Bristle")
  end
  for _, sx in ipairs({ -1, 1 }) do
    onLimb(m, P.head, P.head.CFrame * CFrame.new(sx * 0.7, 0.5, -1), Vector3.new(0.3, 0.24, 0.2), MAT.Neon, rgb(230, 90, 50), "Eye")
  end
  R.beastController(m, { wander = 22, walkSpeed = 15, strideRate = 1.05, bob = 0.22, wanderMin = 3, wanderMax = 7 })
  R.nametag(m, "หมูป่า", "สัตว์ร้าย", rgb(235, 150, 100), P.head)
  stats(m, { Damage = 24, AttackRange = 7, AggroRange = 45, Faction = "beast", Tier = 3 })
end)

-- ============================================================ 9. wraith
-- no legs at all: the R15 legs go invisible and a robe skirt takes their place, so the thing
-- glides. Roblox's walk animation still drives the arms and the robe rides along.
K.build("Monster_Wraith", nil, function(m)
  local cloth, glow = rgb(52, 56, 78), rgb(120, 210, 255)
  R.new(m, { skin = rgb(30, 32, 44), shirt = cloth, pants = cloth, face = false, health = 90, walkSpeed = 7 })
  R.paint(m, R.LIMBS, cloth, MAT.Fabric)
  for _, n in ipairs({ "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }) do
    local p = m:FindFirstChild(n); if p then p.Transparency = 1 end
  end
  R.attach(m, "LowerTorso", function(g, T)
    for i = 0, 6 do                              -- the skirt: wider and thinner as it falls away
      local t = i / 6
      K.box(g, T * CFrame.new(0, -0.6 - t * 3.2, 0), Vector3.new(2.2 + t * 1.9, 0.7, 1.8 + t * 1.5),
        MAT.Fabric, cloth:Lerp(C.black, t * 0.55), { name = "Robe", transparency = t * 0.55 })
    end
  end, "Robe")
  R.attach(m, "Head", function(g, H)
    K.box(g, H * CFrame.new(0, 0.28, 0.1), Vector3.new(1.5, 1.1, 1.5), MAT.Fabric, cloth:Lerp(C.black, 0.3), { name = "Hood" })
    K.box(g, H * CFrame.new(0, -0.05, -0.62), Vector3.new(1.2, 1.1, 0.28), MAT.SmoothPlastic, C.black, { name = "Void" })
    for _, sx in ipairs({ -1, 1 }) do
      local eye = K.ball(g, H * CFrame.new(sx * 0.25, 0.06, -0.7), 0.3, MAT.Neon, glow, { name = "Eye" })
      local l = Instance.new("PointLight"); l.Color = glow; l.Range = 16; l.Brightness = 2; l.Parent = eye
    end
  end, "Hood")
  R.attach(m, "RightHand", function(g, HD)
    local staff = K.box(g, HD * CFrame.new(0, 0.6, -0.4) * K.pitch(math.rad(84)), Vector3.new(0.2, 7, 0.2), MAT.Wood, rgb(44, 40, 48), { name = "Staff" })
    local orb = K.ball(g, staff.CFrame * CFrame.new(0, 3.6, 0), 1.1, MAT.Neon, glow, { name = "Orb" })
    local l = Instance.new("PointLight"); l.Color = glow; l.Range = 26; l.Brightness = 2.2; l.Parent = orb
  end, "Staff")
  R.controller(m, { wander = 18, walkSpeed = 7, wanderMin = 4, wanderMax = 9 })
  R.nametag(m, "ภูตเร่ร่อน", "วิญญาณ", glow)
  stats(m, { Damage = 26, AttackRange = 26, AggroRange = 55, Faction = "spirit", Tier = 3, Ranged = true })
end)

-- ============================================================ 10. clockwork sentry
K.build("Monster_ClockworkSentry", nil, function(m)
  local plate, lens = rgb(150, 112, 54), rgb(255, 170, 60)
  R.new(m, { skin = plate, shirt = rgb(96, 82, 54), pants = rgb(80, 70, 50), face = false, health = 150, walkSpeed = 7 })
  R.paint(m, R.LIMBS, plate, MAT.Metal)
  R.attach(m, "Head", function(g, H)
    K.cyl(g, H * CFrame.new(0, 0.1, 0), 0.72, 1.3, MAT.Metal, plate, { name = "Drum" })
    K.band(g, H * CFrame.new(0, 0.62, 0), 0.78, 0.2, C.brassDark)
    local eye = K.cyl(g, H * CFrame.new(0, 0.12, -0.75) * K.pitch(math.pi / 2), 0.34, 0.3, MAT.Neon, lens, { name = "Lens" })
    local l = Instance.new("PointLight"); l.Color = lens; l.Range = 22; l.Brightness = 2; l.Parent = eye
    K.gear(g, H * CFrame.new(0.7, 0.2, 0.2), 0.4, 10, 0.14, C.brass)
  end, "Head")
  R.attach(m, "UpperTorso", function(g, T)
    K.boiler(g, T * CFrame.new(0, 0.1, 0.7), 0.85, 2.4, { bands = 3, rivets = 10 })
    K.smokestack(g, T * CFrame.new(0.45, 1, 0.7), 0.24, 1.6, { smoke = true })
    K.gauge(g, T * CFrame.new(0, 0.4, -0.95) * K.yaw(math.pi / 2), 0.4)
    K.gear(g, T * CFrame.new(-0.85, 0.3, 0), 0.55, 12, 0.2, C.brassDark)
    K.gear(g, T * CFrame.new(0.85, 0.3, 0), 0.55, 12, 0.2, C.brassDark)
    K.rivetRing(g, T * CFrame.new(0, -0.7, -0.9) * K.yaw(math.pi / 2), 0.7, 8, 0.08, C.brassDark)
  end, "Engine")
  R.attach(m, "RightHand", function(g, HD)
    K.cyl(g, HD * CFrame.new(0, -0.5, -0.2) * K.pitch(math.pi / 2), 0.42, 3.4, MAT.Metal, C.brassDark, { name = "Cannon" })
    K.band(g, HD * CFrame.new(0, -0.5, -1.4) * K.pitch(math.pi / 2), 0.5, 0.3, C.brass)
    K.cyl(g, HD * CFrame.new(0, -0.5, -2) * K.pitch(math.pi / 2), 0.26, 0.4, MAT.Neon, lens, { name = "Muzzle" })
  end, "SteamCannon")
  R.attach(m, "LeftHand", function(g, HD)
    K.box(g, HD * CFrame.new(-0.15, -0.1, -0.4), Vector3.new(2.4, 3, 0.4), MAT.Metal, plate, { name = "Buckler" })
    K.rivetRing(g, HD * CFrame.new(-0.15, -0.1, -0.62) * K.yaw(math.pi / 2), 0.9, 8, 0.1, C.brassDark)
  end, "Buckler")
  R.controller(m, { wander = 16, walkSpeed = 7, wanderMin = 4, wanderMax = 8 })
  R.nametag(m, "ทหารจักรกล", "เครื่องจักร", lens)
  stats(m, { Damage = 30, AttackRange = 34, AggroRange = 60, Faction = "construct", Tier = 4, Ranged = true })
end)
