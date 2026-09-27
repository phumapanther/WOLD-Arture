-- animals (พอร์ตจากโรงงาน WOLD-Models/models/animals.lua) — สัตว์เลี้ยงทั้ง 10 ชนิด (หมา แมว + สัตว์ฟาร์ม 8 ชนิดของเฟส 2d พอร์ตเพิ่ม 2026-09-27)
--
-- ⚠️ **แก้รูปทรงที่โรงงาน แล้วคัดลอกกลับมาที่นี่** กติกาเดียวกับ weapon_base.lua → WeaponPrefabs
--
-- ต่างจากสัตว์ในคอกของเกาะ (กล่องนิ่งๆ 7-9 ชิ้นใน `90_island_placeables`) — ทุกตัวเป็น **rig จริง**
-- มี Motor6D + Humanoid ท่าเดินคำนวณจากความเร็วของตัวเอง ไม่มีอนิเมชันอัปโหลดเลย
--
-- ⚠️ สคริปต์ `BeastGait` ที่ติดมากับโมเดลเขียน `Motor6D.Transform` ซึ่ง **ไม่ replicate** —
-- `ServerScriptService.BeastGait` (โมดูล คนละตัวกัน) ปิดสคริปต์นั้นแล้วทำแบบเดียวกันลง `C0`
-- ระบบสัตว์เลี้ยงจึงต้องเรียก `BeastGait.Attach` เสมอ ไม่ใช่ปล่อยให้สคริปต์ในโมเดลทำงานเอง
-- retune without rebuilding: WalkSpeed / WanderRadius / StrideRate / Bob on the model, and
-- Swing / Fold / Phase on any individual Motor6D.
K.SET = "animals"
K.SLOT = 34
K.PER_ROW = 5
K.ORIGIN = Vector3.new(0, 0, 7800)

local C, MAT, NC = K.C, K.MAT, K.NC
local rgb = Color3.fromRGB

-- a detail part welded rigid to a limb: patches, manes, udders. Rigid, so it rides the animation.
local function onLimb(m, limb, cf, size, mat, color, name)
  local p = R.limbPart(m, name or "Detail", cf, size, mat, color)
  R.joint(limb, p, limb.CFrame, (name or "Detail") .. "Weld")
  return p
end

-- ============================================================ 1. cow
K.build("Animal_Cow", nil, function(m)
  local hide, spot = rgb(238, 234, 226), rgb(46, 42, 44)
  local _, hum, P = R.quad(m, {
    kind = "cow", color = hide, belly = rgb(224, 218, 208), legColor = hide,
    body = { len = 13, w = 6.4, h = 6.2 },
    legs = { upper = 3.6, lower = 3.4, r = 0.95, hoof = 1, swing = 0.42, fold = 0.6 },
    neck = { len = 3.4, r = 2, reach = 3.4, rise = 2.2 },
    head = { len = 4.2, w = 3.2, h = 3.2, snout = 1.6 }, snoutColor = rgb(214, 170, 168),
    ears = { len = 1.2, w = 0.5, d = 2, up = false },
    horns = { len = 3.4, r = 0.6, curve = 0.9, back = 0.1, segs = 3, color = rgb(226, 216, 190) },
    tail = { len = 6, r = 0.42, segs = 4, droop = 0.7, tuft = spot },
    walkSpeed = 4, health = 120,
  })
  -- the patches are the whole point of a cow, but they have to lie ON the hide: the first pass put
  -- them at the torso's own centre height and they hung under the belly like slabs of shadow.
  -- torso centre is y = 10.7, half-width 3.2, so a patch is a thin slab just proud of x = +-3.2.
  local patches = { { -1, 11.4, -3.4, 3.6, 4.6 }, { 1, 9.6, 1.6, 3.4, 4.2 }, { -1, 9.4, 3.8, 2.6, 2.8 }, { 1, 12, -1, 2.4, 3.4 } }
  for _, s in ipairs(patches) do
    onLimb(m, P.torso, CFrame.new(s[1] * 3.25, s[2], s[3]), Vector3.new(0.34, s[4], s[5]), MAT.SmoothPlastic, spot, "Patch")
  end
  onLimb(m, P.torso, CFrame.new(0, 13.9, -1.6), Vector3.new(4.4, 0.34, 5), MAT.SmoothPlastic, spot, "Patch")
  onLimb(m, P.head, P.head.CFrame * CFrame.new(0, 1.65, 0.4), Vector3.new(3.3, 0.3, 2.2), MAT.SmoothPlastic, spot, "Patch")
  -- udder slung under the belly between the back legs
  onLimb(m, P.torso, CFrame.new(0, 7.2, 3), Vector3.new(3.4, 2.2, 3), MAT.SmoothPlastic, rgb(226, 176, 174), "Udder")
  for _, sx in ipairs({ -1, 1 }) do
    onLimb(m, P.torso, CFrame.new(sx * 0.9, 5.9, 3), Vector3.new(0.5, 1.4, 0.5), MAT.SmoothPlastic, rgb(226, 176, 174), "Teat")
  end
  onLimb(m, P.neck, P.neck.CFrame * CFrame.new(0, -2.1, 0), Vector3.new(4, 0.5, 4), MAT.Leather, C.leather, "Collar")
  onLimb(m, P.neck, P.neck.CFrame * CFrame.new(0, -3, 0), Vector3.new(1.8, 2, 1.6), MAT.Metal, C.brass, "Bell")
  R.beastController(m, { wander = 12, walkSpeed = 4, strideRate = 0.6, bob = 0.16 })
  R.nametag(m, "วัวนม", "ปศุสัตว์", rgb(240, 230, 210), P.head)
end)

-- ============================================================ 2. pig
K.build("Animal_Pig", nil, function(m)
  local skin = rgb(226, 158, 158)
  local _, hum, P = R.quad(m, {
    kind = "pig", color = skin, belly = rgb(238, 190, 188), legColor = skin,
    body = { len = 9.5, w = 5.4, h = 5.2 },
    -- short legs and a barrel body: a pig is a cow with the legs taken out
    legs = { upper = 1.9, lower = 1.8, r = 0.85, hoof = 0.8, swing = 0.55, fold = 0.75 },
    neck = { len = 1.4, r = 1.9, reach = 1.2, rise = 0.5 },
    head = { len = 3.2, w = 2.9, h = 2.6, snout = 1.4 }, snoutColor = rgb(238, 176, 176),
    ears = { len = 1.4, w = 0.4, d = 1.6, back = 0.5 },
    tail = { len = 2, r = 0.3, segs = 3, droop = -0.2, swing = 0.5 },
    walkSpeed = 5, health = 70,
  })
  for _, sx in ipairs({ -1, 1 }) do              -- snout nostrils, the tell that reads at any distance
    onLimb(m, P.head, P.head.CFrame * CFrame.new(sx * 0.5, -0.42, -2.5), Vector3.new(0.4, 0.4, 0.3), MAT.SmoothPlastic, rgb(150, 92, 94), "Nostril")
  end
  onLimb(m, P.torso, CFrame.new(0, 6.6, -1), Vector3.new(5.5, 1.4, 5), MAT.SmoothPlastic, rgb(206, 138, 140), "Back")
  R.beastController(m, { wander = 10, walkSpeed = 5, strideRate = 0.85, bob = 0.2 })
  R.nametag(m, "หมู", "ปศุสัตว์", rgb(245, 200, 200), P.head)
end)

-- ============================================================ 3. sheep
K.build("Animal_Sheep", nil, function(m)
  local wool, face = rgb(238, 236, 228), rgb(54, 50, 52)
  local _, hum, P = R.quad(m, {
    kind = "sheep", color = wool, belly = wool, legColor = face,
    body = { len = 9, w = 5.4, h = 5.4 }, woolly = true, fleece = wool,
    legs = { upper = 2.6, lower = 2.6, r = 0.6, hoof = 0.7, swing = 0.5, fold = 0.7 },
    neck = { len = 2.2, r = 1.3, reach = 1.8, rise = 1.6 },
    head = { len = 2.8, w = 2.2, h = 2.4, snout = 1 }, color2 = face,
    ears = { len = 1.1, w = 0.4, d = 1.5, back = 0.3 }, earColor = face,
    tail = { len = 1.6, r = 0.5, segs = 2, droop = 0.6 },
    walkSpeed = 5, health = 60,
  })
  -- the head is the bare bit: paint it after the fact rather than adding a spec field for it
  P.head.Color = face
  for _, p in ipairs(m:GetChildren()) do
    if p:IsA("BasePart") and (p.Name == "Snout" or p.Name == "Ear") then p.Color = face end
  end
  onLimb(m, P.head, P.head.CFrame * CFrame.new(0, 1.3, 0.5), Vector3.new(2.6, 1.4, 2.2), MAT.Fabric, wool, "Forelock")
  R.beastController(m, { wander = 11, walkSpeed = 5, strideRate = 0.8, bob = 0.15 })
  R.nametag(m, "แกะ", "ปศุสัตว์", rgb(245, 245, 235), P.head)
end)

-- ============================================================ 4. horse
K.build("Animal_Horse", nil, function(m)
  local coat, dark = rgb(120, 78, 48), rgb(46, 34, 28)
  local _, hum, P = R.quad(m, {
    kind = "horse", color = coat, belly = rgb(140, 96, 62), legColor = coat,
    body = { len = 14, w = 5.6, h = 6.4 },
    legs = { upper = 5, lower = 4.6, r = 0.85, hoof = 1, swing = 0.55, fold = 0.65 },
    neck = { len = 5, r = 1.9, reach = 3.2, rise = 4.4 },
    head = { len = 4.4, w = 2.3, h = 2.8, snout = 1.4 },
    ears = { len = 1.6, w = 0.4, d = 1, up = true },
    tail = { len = 7, r = 0.55, segs = 4, droop = 0.85, swing = 0.3, tuft = dark },
    hoofColor = rgb(38, 34, 32), walkSpeed = 9, health = 140,
  })
  -- mane down the neck: a horse without one reads as a very long dog
  for i = 0, 6 do
    local t = i / 6
    onLimb(m, P.neck, P.neck.CFrame * CFrame.new(0, 1.5, (t - 0.5) * 5.2) * K.roll(0.1),
      Vector3.new(0.5, 1.9 - t * 0.5, 1.1), MAT.Fabric, dark, "Mane")
  end
  onLimb(m, P.head, P.head.CFrame * CFrame.new(0, 1.5, 0.9), Vector3.new(0.5, 1.6, 1.4), MAT.Fabric, dark, "Forelock")
  onLimb(m, P.head, P.head.CFrame * CFrame.new(0, 0.5, -1.7), Vector3.new(2.4, 1, 0.9), MAT.SmoothPlastic, rgb(236, 232, 226), "Blaze")
  R.beastController(m, { wander = 22, walkSpeed = 9, strideRate = 0.5, bob = 0.2 })
  R.nametag(m, "ม้า", "พาหนะ", rgb(230, 190, 140), P.head)
end)

-- ============================================================ 5. chicken
K.build("Animal_Chicken", nil, function(m)
  local _, hum = R.bird(m, {
    kind = "chicken", color = rgb(238, 232, 220), headColor = rgb(238, 232, 220),
    len = 3.4, w = 2.8, h = 3.2, legLen = 1.6, wing = 1.6, flap = 0.4,
    comb = rgb(190, 56, 52), beak = rgb(226, 176, 60), foot = rgb(216, 168, 70),
    tailColor = rgb(200, 190, 176), walkSpeed = 5, health = 12,
  })
  local body = m:FindFirstChild("Torso")
  for i = 0, 2 do                                -- tail feathers fanned, which is what says "chicken"
    local f = R.limbPart(m, "Feather", body.CFrame * CFrame.new((i - 1) * 0.5, 2, 2.2) * K.pitch(-0.9 - i * 0.1) * K.roll((i - 1) * 0.25),
      Vector3.new(0.3, 0.35, 2.6), MAT.SmoothPlastic, rgb(178, 168, 152))
    R.joint(body, f, body.CFrame, "FeatherWeld")
  end
  R.beastController(m, { wander = 8, walkSpeed = 5, strideRate = 1.3, bob = 0.1 })
  R.nametag(m, "ไก่", "สัตว์เลี้ยง", rgb(245, 235, 215), m:FindFirstChild("Head"))
end)

-- ============================================================ 6. goat
K.build("Animal_Goat", nil, function(m)
  local coat = rgb(198, 186, 164)
  local _, hum, P = R.quad(m, {
    kind = "goat", color = coat, belly = rgb(214, 204, 186), legColor = rgb(120, 104, 84),
    body = { len = 8.4, w = 4.4, h = 4.6 },
    legs = { upper = 3, lower = 2.8, r = 0.55, hoof = 0.7, swing = 0.55, fold = 0.75 },
    neck = { len = 2.6, r = 1.2, reach = 2, rise = 2.2 },
    head = { len = 3, w = 2, h = 2.2, snout = 1.1 },
    ears = { len = 1.5, w = 0.4, d = 1.6, back = 0.7 },
    -- swept straight back and up, not curled forward like a cow's
    horns = { len = 3, r = 0.35, curve = 0.25, back = 0.9, segs = 3, color = rgb(120, 108, 92) },
    tail = { len = 1.4, r = 0.35, segs = 2, droop = -0.5 },
    walkSpeed = 7, health = 55,
  })
  onLimb(m, P.head, P.head.CFrame * CFrame.new(0, -1.2, 1.2) * K.pitch(0.4), Vector3.new(0.7, 1.8, 0.6), MAT.Fabric, coat:Lerp(C.black, 0.25), "Beard")
  R.beastController(m, { wander = 14, walkSpeed = 7, strideRate = 0.85, bob = 0.14 })
  R.nametag(m, "แพะ", "ปศุสัตว์", rgb(230, 220, 200), P.head)
end)

-- ============================================================ 7. dog
K.build("Animal_Dog", nil, function(m)
  local coat = rgb(150, 106, 64)
  local _, hum, P = R.quad(m, {
    kind = "dog", color = coat, belly = rgb(206, 178, 140), legColor = coat,
    body = { len = 7.6, w = 3.4, h = 3.6 },
    legs = { upper = 2.4, lower = 2.2, r = 0.5, hoof = 0.6, swing = 0.65, fold = 0.85 },
    neck = { len = 2, r = 1.1, reach = 1.4, rise = 1.6 },
    head = { len = 2.8, w = 1.9, h = 2, snout = 1.4 }, snoutColor = rgb(48, 42, 40),
    ears = { len = 1.6, w = 0.4, d = 1.4, back = 0.4 }, earColor = rgb(112, 78, 46),
    -- a high, fast-wagging tail: the one gesture that makes a dog read as friendly
    tail = { len = 3.4, r = 0.42, segs = 3, droop = -0.55, swing = 0.75 },
    hoofColor = rgb(48, 42, 40), walkSpeed = 11, health = 45,
  })
  onLimb(m, P.head, P.head.CFrame * CFrame.new(0, -0.1, -1.9), Vector3.new(0.6, 0.5, 0.4), MAT.SmoothPlastic, C.black, "Nose")
  onLimb(m, P.torso, CFrame.new(0, 5.1, -2.4), Vector3.new(3.5, 1.2, 2.6), MAT.SmoothPlastic, rgb(232, 220, 200), "Bib")
  onLimb(m, P.neck, P.neck.CFrame, Vector3.new(2.6, 2.6, 0.8), MAT.Fabric, C.paintRed, "Collar")
  R.beastController(m, { wander = 20, walkSpeed = 11, strideRate = 1, bob = 0.14, wanderMin = 3, wanderMax = 6 })
  R.nametag(m, "สุนัข", "สัตว์เลี้ยง", rgb(240, 200, 150), P.head)
end)

-- ============================================================ 8. cat
K.build("Animal_Cat", nil, function(m)
  local coat = rgb(86, 80, 84)
  local _, hum, P = R.quad(m, {
    kind = "cat", color = coat, belly = rgb(196, 190, 184), legColor = coat,
    body = { len = 5.2, w = 2.2, h = 2.4 },
    legs = { upper = 1.7, lower = 1.6, r = 0.34, hoof = 0.4, swing = 0.7, fold = 0.95 },
    neck = { len = 1.2, r = 0.8, reach = 0.9, rise = 0.9 },
    head = { len = 1.7, w = 1.7, h = 1.6, snout = 0.7 }, snoutColor = rgb(214, 168, 164),
    ears = { len = 1.1, w = 0.35, d = 1, up = true },
    -- long, high, and slow-waving: the cat silhouette lives in the tail
    tail = { len = 5.5, r = 0.3, segs = 5, droop = -0.6, swing = 0.4 },
    walkSpeed = 8, health = 25,
  })
  for i = 0, 3 do                                -- tabby stripes
    onLimb(m, P.torso, CFrame.new(0, 4.1, -2 + i * 1.3), Vector3.new(2.3, 1.2, 0.5), MAT.SmoothPlastic, rgb(48, 44, 48), "Stripe")
  end
  for _, sx in ipairs({ -1, 1 }) do
    onLimb(m, P.head, P.head.CFrame * CFrame.new(sx * 0.5, -0.1, -0.9), Vector3.new(1.8, 0.06, 0.06) , MAT.SmoothPlastic, rgb(230, 226, 220), "Whisker")
  end
  R.beastController(m, { wander = 14, walkSpeed = 8, strideRate = 1.1, bob = 0.1, wanderMin = 5, wanderMax = 12 })
  R.nametag(m, "แมว", "สัตว์เลี้ยง", rgb(200, 195, 200), P.head)
end)

-- ============================================================ 9. deer
K.build("Animal_Deer", nil, function(m)
  local coat = rgb(154, 108, 66)
  local _, hum, P = R.quad(m, {
    kind = "deer", color = coat, belly = rgb(226, 210, 186), legColor = rgb(132, 92, 56),
    body = { len = 9.5, w = 4.2, h = 5 },
    legs = { upper = 4.4, lower = 4.2, r = 0.5, hoof = 0.7, swing = 0.6, fold = 0.7 },
    neck = { len = 4, r = 1.2, reach = 2.2, rise = 3.6 },
    head = { len = 3.2, w = 1.9, h = 2, snout = 1.2 },
    ears = { len = 2, w = 0.4, d = 1.6, up = true },
    tail = { len = 1.4, r = 0.5, segs = 2, droop = -0.3, tuft = rgb(240, 236, 228) },
    hoofColor = rgb(44, 38, 34), walkSpeed = 13, health = 50,
  })
  -- antlers: the beam plus three tines a side, built off the head so they ride every head movement
  local bone = rgb(198, 182, 150)
  for _, sx in ipairs({ -1, 1 }) do
    local base = P.head.CFrame * CFrame.new(sx * 0.7, 1.1, 0.5)
    for i = 0, 2 do
      onLimb(m, P.head, base * CFrame.new(sx * i * 0.45, 1.1 + i * 1.1, -i * 0.25) * K.roll(sx * 0.22),
        Vector3.new(0.36, 1.3, 0.36), MAT.Slate, bone, "AntlerBeam")
    end
    for i = 0, 2 do
      onLimb(m, P.head, base * CFrame.new(sx * (0.5 + i * 0.4), 1.4 + i * 1.1, -0.4 - i * 0.3) * K.roll(sx * 0.9) * K.pitch(-0.4),
        Vector3.new(0.3, 1.5 - i * 0.25, 0.3), MAT.Slate, bone, "Tine")
    end
  end
  for i = 0, 5 do                                -- dappled flank spots
    onLimb(m, P.torso, CFrame.new(0, 7.2 - (i % 2) * 1.3, -3 + i * 1.2), Vector3.new(4.3, 0.7, 0.7), MAT.SmoothPlastic, rgb(236, 224, 204), "Spot")
  end
  R.beastController(m, { wander = 26, walkSpeed = 13, strideRate = 0.7, bob = 0.22, wanderMin = 3, wanderMax = 7 })
  R.nametag(m, "กวาง", "สัตว์ป่า", rgb(220, 180, 140), P.head)
end)

-- ============================================================ 10. duck
K.build("Animal_Duck", nil, function(m)
  local _, hum = R.bird(m, {
    kind = "duck", color = rgb(226, 222, 210), headColor = rgb(56, 98, 72),
    len = 3.8, w = 2.6, h = 2.6, legLen = 1.1, wing = 1.5, flap = 0.3,
    beak = rgb(232, 178, 62), foot = rgb(232, 160, 52),
    tailColor = rgb(196, 190, 176), walkSpeed = 4, health = 12,
  })
  local head = m:FindFirstChild("Head")
  local body = m:FindFirstChild("Torso")
  -- a duck's bill is flat and wide; R.bird's default is a pointed beak, so replace it
  local beak = m:FindFirstChild("Beak")
  if beak then beak.Size = Vector3.new(1.5, 0.32, 1.8) end
  local ring = R.limbPart(m, "NeckRing", head.CFrame * CFrame.new(0, -0.9, 0.3), Vector3.new(2, 0.5, 2), MAT.SmoothPlastic, rgb(236, 234, 226))
  R.joint(head, ring, head.CFrame, "RingWeld")
  for _, sx in ipairs({ -1, 1 }) do              -- a speculum patch on each wing
    local w = m:FindFirstChild("Wing" .. (sx < 0 and "L" or "R"))
    if w then
      local patch = R.limbPart(m, "Speculum", w.CFrame * CFrame.new(0, 0.25, 0), Vector3.new(1.5, 0.16, 1.6), MAT.SmoothPlastic, rgb(70, 96, 150))
      R.joint(w, patch, w.CFrame, "SpeculumWeld")
    end
  end
  R.beastController(m, { wander = 7, walkSpeed = 4, strideRate = 1.4, bob = 0.18 })
  R.nametag(m, "เป็ด", "สัตว์เลี้ยง", rgb(235, 230, 215), head)
end)
