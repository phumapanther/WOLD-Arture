-- animals (พอร์ตจากโรงงาน WOLD-Models/models/animals.lua) — **เฉพาะสัตว์เลี้ยงสองตัว**
--
-- ⚠️ **แก้รูปทรงที่โรงงาน แล้วคัดลอกกลับมาที่นี่** กติกาเดียวกับ weapon_base.lua → WeaponPrefabs
--
-- ต่างจากสัตว์ในคอกของเกาะ (กล่องนิ่งๆ 7-9 ชิ้นใน `90_island_placeables`) — สองตัวนี้เป็น **rig จริง**
-- มี Motor6D + Humanoid ท่าเดินคำนวณจากความเร็วของตัวเอง ไม่มีอนิเมชันอัปโหลดเลย
--
-- ⚠️ สคริปต์ `BeastGait` ที่ติดมากับโมเดลเขียน `Motor6D.Transform` ซึ่ง **ไม่ replicate** —
-- `ServerScriptService.BeastGait` (โมดูล คนละตัวกัน) ปิดสคริปต์นั้นแล้วทำแบบเดียวกันลง `C0`
-- ระบบสัตว์เลี้ยงจึงต้องเรียก `BeastGait.Attach` เสมอ ไม่ใช่ปล่อยให้สคริปต์ในโมเดลทำงานเอง
local C, MAT, NC = K.C, K.MAT, K.NC
local rgb = Color3.fromRGB

-- a detail part welded rigid to a limb: patches, manes, udders. Rigid, so it rides the animation.
local function onLimb(m, limb, cf, size, mat, color, name)
  local p = R.limbPart(m, name or "Detail", cf, size, mat, color)
  R.joint(limb, p, limb.CFrame, (name or "Detail") .. "Weld")
  return p
end


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
