-- kit_showcase — every modelkit piece on its own display pad, at a size that reads from the camera.
-- purpose: pick pieces apart one at a time and tune them. Not a game asset.
-- clear with: node tools/model.js clear
K.SET = "kit"        -- own slot numbering, own patch of ground
K.SLOT = 90          -- tighter grid than the default 160: these are components, not vehicles
K.PER_ROW = 6

local C = K.C
local MAT = K.MAT

-- a low plinth so each piece has something to stand on
local function plinth(m, w, d, h)
  K.box(m, CFrame.new(0, (h or 1) / 2, 0), Vector3.new(w or 20, h or 1, d or 20), MAT.Slate, C.darkStone, { name = "Plinth" })
  return h or 1
end
-- upright post, returns the top y
local function post(m, x, z, h, r)
  K.cyl(m, CFrame.new(x, h / 2, z), r or 0.6, h, MAT.Metal, C.iron, { name = "Post" })
  return h
end

-- 1 ----------------------------------------------------------------- gears
K.build("Gear", nil, function(m)
  local y = plinth(m, 34, 16, 1)
  K.gear(m, CFrame.new(-8, y + 9, 0) * K.yaw(math.pi / 2), 8, 16, 1.6)
  K.gear(m, CFrame.new(4.4, y + 9, 0) * K.yaw(math.pi / 2), 5, 12, 1.6, C.copper)
  K.gear(m, CFrame.new(12.6, y + 9, 0) * K.yaw(math.pi / 2), 3.2, 9, 1.6, C.steel)
  K.cylX(m, CFrame.new(-8, y + 9, 0), 0.5, 6, MAT.Metal, C.iron, { name = "Shaft" })
end)

-- 2 ---------------------------------------------------------------- boiler
K.build("Boiler", nil, function(m)
  local y = plinth(m, 22, 22, 1)
  K.boiler(m, CFrame.new(0, y + 10, 0), 5, 18, { bands = 3, rivets = 12, firebox = true })
  K.gauge(m, CFrame.new(0, y + 15, -5.2) * K.yaw(math.pi / 2), 1.6)
  K.valveWheel(m, CFrame.new(5.6, y + 12, 0), 2.2, 5)
end)

-- 3 ------------------------------------------------------------ smokestack
K.build("Smokestack", nil, function(m)
  local y = plinth(m, 18, 18, 1)
  K.smokestack(m, CFrame.new(0, y, 0), 2.6, 24, { smoke = true })
  K.smokestack(m, CFrame.new(-7, y, 0), 1.4, 14, { color = C.rust, cap = C.brass })
end)

-- 4 ------------------------------------------------------------------ pipe
K.build("Pipe", nil, function(m)
  local y = plinth(m, 40, 16, 1)
  K.pipe(m, {
    Vector3.new(-17, y + 3, 0), Vector3.new(-17, y + 14, 0), Vector3.new(-4, y + 14, 0),
    Vector3.new(-4, y + 7, 0), Vector3.new(9, y + 7, 0), Vector3.new(9, y + 16, 0), Vector3.new(17, y + 16, 0),
  }, 1.1)
  K.valveWheel(m, CFrame.new(-4, y + 10.5, 0) * K.yaw(math.pi / 2), 2, 4)
  post(m, -17, 0, y + 3, 0.8); post(m, 9, 0, y + 7, 0.8)
end)

-- 5 ----------------------------------------------------------- valve wheel
K.build("ValveWheel", nil, function(m)
  local y = plinth(m, 20, 14, 1)
  K.cyl(m, CFrame.new(0, y + 5, 0), 1.4, 10, MAT.Metal, C.iron, { name = "Stand" })
  K.valveWheel(m, CFrame.new(0, y + 11, 0) * K.pitch(math.pi / 2) * K.yaw(math.pi / 2), 5, 5)   -- lying flat, seen from above
  K.valveWheel(m, CFrame.new(-8, y + 6, 0) * K.yaw(math.pi / 2), 3.5, 6, C.copper)              -- upright, facing front
end)

-- 6 ----------------------------------------------------------------- gauge
K.build("Gauge", nil, function(m)
  local y = plinth(m, 22, 12, 1)
  K.box(m, CFrame.new(0, y + 7, 2), Vector3.new(20, 14, 1.2), MAT.Metal, C.brassDark, { name = "Panel" })
  K.rivetRing(m, CFrame.new(0, y + 7, 1.3) * K.yaw(math.pi / 2), 8.5, 12, 0.35)
  K.gauge(m, CFrame.new(-6, y + 8, 1.2) * K.yaw(math.pi / 2), 3.2)
  K.gauge(m, CFrame.new(1.5, y + 9, 1.2) * K.yaw(math.pi / 2), 2.2, C.copper)
  K.gauge(m, CFrame.new(6.5, y + 5, 1.2) * K.yaw(math.pi / 2), 2.6)
end)

-- 7 -------------------------------------------------------------- porthole
K.build("Porthole", nil, function(m)
  local y = plinth(m, 26, 10, 1)
  K.box(m, CFrame.new(0, y + 9, 1.6), Vector3.new(26, 18, 1.4), MAT.WoodPlanks, C.plankDark, { name = "HullPanel" })
  K.porthole(m, CFrame.new(-7, y + 9, 0.6) * K.yaw(math.pi / 2), 4.5)
  K.porthole(m, CFrame.new(6, y + 9, 0.6) * K.yaw(math.pi / 2), 3, { color = C.copper })
  K.rivets(m, Vector3.new(-12, y + 17, 0.6), Vector3.new(12, y + 17, 0.6), 13, 0.4)
end)

-- 8 ------------------------------------------------------------- propeller
K.build("Propeller", nil, function(m)
  local y = plinth(m, 26, 16, 1)
  K.box(m, CFrame.new(0, y + 6, 4), Vector3.new(5, 10, 8), MAT.Metal, C.iron, { name = "Housing" })
  K.propeller(m, CFrame.new(0, y + 11, -1) * K.yaw(math.pi / 2), 9, 4)
  K.propeller(m, CFrame.new(-11, y + 6, 0) * K.yaw(math.pi / 2), 4.5, 6, C.copper)
end)

-- 9 ----------------------------------------------------------- paddle wheel
K.build("PaddleWheel", nil, function(m)
  local y = plinth(m, 26, 22, 1)
  K.paddleWheel(m, CFrame.new(0, y + 10, 0), 9, 8, 10)
  for _, x in ipairs({ -6.4, 6.4 }) do                                   -- A-frame mounts instead of bare posts
    K.rod(m, Vector3.new(x, y, -6), Vector3.new(x, y + 10, 0), 0.7, MAT.Metal, C.iron, { name = "Leg" })
    K.rod(m, Vector3.new(x, y, 6), Vector3.new(x, y + 10, 0), 0.7, MAT.Metal, C.iron, { name = "Leg" })
    K.ball(m, CFrame.new(x, y + 10, 0), 2.2, MAT.Metal, C.brassDark, { name = "Bearing" })
  end
end)

-- 10 ---------------------------------------------------------------- spring
K.build("Spring", nil, function(m)
  local y = plinth(m, 24, 12, 1)
  K.spring(m, Vector3.new(-8, y, 0), Vector3.new(-8, y + 14, 0), 2.2, 5)
  K.spring(m, Vector3.new(0, y, 0), Vector3.new(0, y + 14, 0), 1.4, 9, C.brass)
  K.spring(m, Vector3.new(8, y, 0), Vector3.new(8, y + 9, 0), 2.8, 4, C.copper)
  for _, x in ipairs({ -8, 0, 8 }) do K.cyl(m, CFrame.new(x, y + 0.4, 0), 3, 0.8, MAT.Metal, C.iron, { name = "Cap" }) end
end)

-- 11 ----------------------------------------------------------------- chain
K.build("Chain", nil, function(m)
  local y = plinth(m, 30, 12, 1)
  post(m, -12, 0, y + 18, 0.8); post(m, 12, 0, y + 18, 0.8)
  K.chain(m, Vector3.new(-12, y + 18, 0), Vector3.new(0, y + 11, 0), 7, 0.35)
  K.chain(m, Vector3.new(0, y + 11, 0), Vector3.new(12, y + 18, 0), 7, 0.35)
  K.chain(m, Vector3.new(0, y + 11, 0), Vector3.new(0, y + 2, 0), 5, 0.3, C.brassDark)
  K.crate(m, CFrame.new(0, y, 0), 4)
end)

-- 12 ---------------------------------------------------------------- rivets
K.build("Rivets", nil, function(m)
  local y = plinth(m, 30, 12, 1)
  K.box(m, CFrame.new(0, y + 9, 2), Vector3.new(30, 18, 1.4), MAT.Metal, C.copper, { name = "Plate" })
  K.rivets(m, Vector3.new(-13, y + 16, 1.2), Vector3.new(13, y + 16, 1.2), 14, 0.45)
  K.rivets(m, Vector3.new(-13, y + 2, 1.2), Vector3.new(13, y + 2, 1.2), 14, 0.45)
  K.rivetRing(m, CFrame.new(-7, y + 9, 1.2) * K.yaw(math.pi / 2), 5, 14, 0.45)
  K.rivetRing(m, CFrame.new(7, y + 9, 1.2) * K.yaw(math.pi / 2), 3, 8, 0.6, C.iron)
  K.band(m, CFrame.new(0, y + 9, 6), 4, 20, C.brassDark)                    -- hoop shown lying along Z
end)

-- 13 --------------------------------------------------------------- lantern
K.build("Lantern", nil, function(m)
  local y = plinth(m, 28, 14, 1)
  post(m, -9, 0, y + 12, 0.5); post(m, 0, 0, y + 16, 0.5); post(m, 9, 0, y + 10, 0.5)
  K.lantern(m, CFrame.new(-9, y + 12, 0), 5)
  K.lantern(m, CFrame.new(0, y + 16, 0), 3.5, C.crystal)
  K.lantern(m, CFrame.new(9, y + 10, 0), 4, C.ember)
end)

-- 14 ------------------------------------------------------------ plank deck
K.build("Deck", nil, function(m)
  K.plankFloor(m, CFrame.new(0, 0.3, 0), 30, 30, 2.4)
  K.box(m, CFrame.new(0, 0.3, -15.4), Vector3.new(31, 0.9, 0.8), MAT.Wood, C.wood, { name = "Trim" })
  K.box(m, CFrame.new(0, 0.3, 15.4), Vector3.new(31, 0.9, 0.8), MAT.Wood, C.wood, { name = "Trim" })
  K.plankFloor(m, CFrame.new(0, 6, -8) * K.pitch(math.pi / 2), 14, 12, 2, C.oak)   -- a wall of the same planks, upright
end)

-- 15 ----------------------------------------------------------------- crate
K.build("Crate", nil, function(m)
  plinth(m, 26, 20, 0.6)
  K.crate(m, CFrame.new(-7, 0.6, 0), 8)
  K.crate(m, CFrame.new(1.5, 0.6, -2), 6, C.wood)
  K.crate(m, CFrame.new(1.6, 6.6, -2) * K.yaw(0.3), 5)
  K.crate(m, CFrame.new(9, 0.6, 3), 5, C.plankDark)
end)

-- 16 ---------------------------------------------------------------- barrel
K.build("Barrel", nil, function(m)
  plinth(m, 26, 20, 0.6)
  K.barrel(m, CFrame.new(-8, 0.6, 0), 3, 8)
  K.barrel(m, CFrame.new(0, 0.6, -3), 2.2, 6, C.oak)
  K.barrel(m, CFrame.new(8, 0.6, 2), 3.4, 9, C.plankDark)
  K.barrel(m, CFrame.new(-1, 0.6, 6) * K.roll(math.pi / 2), 2.6, 7)     -- lying on its side
end)

-- 17 ------------------------------------------------------------------ sign
K.build("Sign", nil, function(m)
  local y = plinth(m, 30, 10, 1)
  post(m, -11, 0, y + 20, 0.7); post(m, 11, 0, y + 20, 0.7)
  K.box(m, CFrame.new(0, y + 20, 0), Vector3.new(23, 0.8, 0.8), MAT.Metal, C.iron, { name = "Bar" })
  K.chain(m, Vector3.new(-8, y + 20, 0), Vector3.new(-8, y + 16.5, 0), 3, 0.2)
  K.chain(m, Vector3.new(8, y + 20, 0), Vector3.new(8, y + 16.5, 0), 3, 0.2)
  K.sign(m, CFrame.new(0, y + 12, 0), "BRASSHAVEN", 20, 8)
  K.lantern(m, CFrame.new(-11, y + 20, 0), 3)
end)

-- 18 ------------------------------------------------------------ primitives
K.build("Primitives", nil, function(m)
  local y = plinth(m, 62, 18, 1)
  local step, x0 = 8, -28
  local function label(i, text)                                          -- nameplate on the front edge, reading toward the front camera
    K.sign(m, CFrame.new(x0 + step * i, y + 1.6, -6.6), text, 7.4, 2.4, C.darkStone, C.white)
  end
  K.box(m, CFrame.new(x0 + step * 0, y + 3, 0), Vector3.new(6, 6, 6), MAT.SmoothPlastic, C.paintBlue);                label(0, "box")
  K.ball(m, CFrame.new(x0 + step * 1, y + 3, 0), 6, MAT.SmoothPlastic, C.paintRed);                                   label(1, "ball")
  K.cyl(m, CFrame.new(x0 + step * 2, y + 3.5, 0), 3, 7, MAT.SmoothPlastic, C.paintGreen);                             label(2, "cyl")
  K.cylX(m, CFrame.new(x0 + step * 3, y + 3, 0), 2.6, 7, MAT.SmoothPlastic, C.brass);                                 label(3, "cylX")
  K.rod(m, Vector3.new(x0 + step * 4 - 2.5, y + 0.6, 0), Vector3.new(x0 + step * 4 + 2.5, y + 7, 0), 1, MAT.Metal, C.steel); label(4, "rod")
  K.wedge(m, CFrame.new(x0 + step * 5, y + 3, 0) * K.yaw(math.pi), Vector3.new(6, 6, 6), MAT.Wood, C.plank);          label(5, "wedge")
  K.cwedge(m, CFrame.new(x0 + step * 6, y + 3, 0), Vector3.new(6, 6, 6), MAT.Wood, C.oak);                            label(6, "cwedge")
  K.box(m, CFrame.new(x0 + step * 7, y + 3, 0), Vector3.new(6, 6, 6), MAT.Glass, C.glass, { transparency = 0.5, reflectance = 0.2 }); label(7, "glass")
end)
