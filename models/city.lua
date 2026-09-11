-- city — the building types that fill the ground inside the curtain wall. Four types, and they
-- share nothing but scale: a packed tenement, a merchant's house round a yard, a guildhall over
-- an open market arcade, and a foundry. Each is walk-in and each has a different way up.
--
-- character scale as everywhere else: storey 26, doorway 12 x 18, window 9 x 12 on a sill of 8.
K.SET = "city"
K.SLOT = 190
K.PER_ROW = 2
K.ORIGIN = Vector3.new(0, 0, 2200)

local C = K.C
local MAT = K.MAT
local rgb = Color3.fromRGB
local ST = 26
local DOOR_W, DOOR_H = 12, 18
local WIN_W, WIN_H, SILL = 9, 12, 8

local STONE = rgb(146, 142, 134)
local STONE_DARK = rgb(110, 106, 100)
local BRASS = rgb(205, 140, 45)

local function glow(part, color, range, brightness)
  local l = Instance.new("PointLight")
  l.Color = color or C.lamp; l.Range = range or 26; l.Brightness = brightness or 0.56; l.Parent = part
  return l
end
local function smoke(part, color, size)
  local s = Instance.new("Smoke")
  s.Size = size or 6; s.RiseVelocity = 8; s.Opacity = 0.22; s.Color = color or rgb(104, 102, 98); s.Parent = part
  return s
end
local function steamJet(part, rate)
  local e = Instance.new("ParticleEmitter")
  e.Name = "SteamJet"
  e.Color = ColorSequence.new(rgb(226, 234, 242))
  e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 6) })
  e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
  e.Lifetime = NumberRange.new(2, 4); e.Rate = rate or 14
  e.Speed = NumberRange.new(5, 10); e.SpreadAngle = Vector2.new(15, 15)
  e.EmissionDirection = Enum.NormalId.Top; e.Parent = part
  return e
end
local function win(x, sill) return { x = x, w = WIN_W, h = WIN_H, sill = sill or SILL } end
local function walls4(m, o, w, d, h, thick, mat, col, front, back, left, right, tag)
  K.wallRun(m, o * CFrame.new(0, 0, -d / 2), w, h, thick, mat, col, front, { name = (tag or "") .. "Front" })
  K.wallRun(m, o * CFrame.new(0, 0, d / 2) * K.yaw(math.pi), w, h, thick, mat, col, back, { name = (tag or "") .. "Back" })
  K.wallRun(m, o * CFrame.new(-w / 2, 0, 0) * K.yaw(-math.pi / 2), d, h, thick, mat, col, left, { name = (tag or "") .. "Left" })
  K.wallRun(m, o * CFrame.new(w / 2, 0, 0) * K.yaw(math.pi / 2), d, h, thick, mat, col, right, { name = (tag or "") .. "Right" })
end
local function ceilingLamps(m, cf, xs, zs, size, color)
  for _, x in ipairs(xs) do
    for _, z in ipairs(zs) do
      K.chain(m, (cf * CFrame.new(x, 0, z)).Position, (cf * CFrame.new(x, -4, z)).Position, 3, 0.2)
      K.lantern(m, cf * CFrame.new(x, -9, z), size or 4, color)
    end
  end
end
-- washing strung between two points: the detail that says people live here
local function washing(m, a, b, n, seed)
  local g = K.model(m, "Washing")
  local rng = Random.new(seed or 3)
  K.rod(g, a, b, 0.16, MAT.Metal, C.rope, { name = "Line", cancollide = false })
  for i = 1, n do
    local t = i / (n + 1)
    local p = a:Lerp(b, t) - Vector3.new(0, 0.4, 0)
    local w, h = 3 + rng:NextNumber() * 4, 4 + rng:NextNumber() * 5
    K.box(g, CFrame.new(p - Vector3.new(0, h / 2, 0)) * K.yaw(rng:NextNumber() * 0.3), Vector3.new(w, h, 0.3), MAT.Fabric,
      ({ C.canvas, rgb(180, 196, 210), rgb(196, 172, 150), rgb(150, 170, 150) })[rng:NextInteger(1, 4)], { name = "Cloth", cancollide = false })
  end
  return g
end

-- ============================================================ 1. the tenement
-- five storeys on a narrow plot, reached by an external gallery stair up the side; shopfront
-- at street level, washing across the front, a cluster of flues instead of one chimney
K.build("City_Tenement", nil, function(m)
  local W, D = 42, 34
  local FLOORS = 5
  K.box(m, CFrame.new(0, -1.5, 0), Vector3.new(W + 12, 3, D + 12), MAT.Cobblestone, C.darkStone, { name = "Plinth" })

  -- ground: stone shop, open to the street
  K.floorSlab(m, CFrame.new(0, 0, 0), W, D, MAT.Slate, rgb(128, 124, 118), { name = "ShopFloor" })
  walls4(m, CFrame.new(0, 0, 0), W, D, ST, 2.6, MAT.Brick, rgb(140, 96, 78),
    { { x = -7, w = 18, h = 20 }, { x = 13, w = 11, h = 12, sill = 7 } },
    { { x = 6, w = DOOR_W, h = DOOR_H } }, { win(-4) }, { win(4) }, "G")
  K.autoDoor(m, CFrame.new(6, 0, D / 2 + 1.4) * K.yaw(math.pi), DOOR_W, DOOR_H, { color = C.wood })

  -- four timber storeys above, each jettied a little further out over the street
  local floors = {}
  for f = 1, FLOORS - 1 do
    local jut = f * 1.8
    local o = CFrame.new(0, ST * f, -jut)
    floors[f] = o
    K.box(m, o * CFrame.new(0, -0.9, 0), Vector3.new(W + jut + 3, 1.6, D + jut + 3), MAT.Wood, C.wood, { name = "Jetty" .. f })
    for _, s in ipairs({ -1, 1 }) do
      K.wedge(m, o * CFrame.new(s * (W / 2 - 3), -4, -(D + jut) / 2 + 1) * K.yaw(math.pi), Vector3.new(4, 5, 5), MAT.Wood, C.wood)
    end
    K.floorSlab(m, o, W + jut, D + jut, MAT.WoodPlanks, C.plank, { name = "Floor" .. f })
    -- the flat's door is on the WEST wall, which is the side the gallery runs along. It used to be
    -- on the back wall, where nothing reaches it: the stair and its gallery are on the flank.
    walls4(m, o, W + jut, D + jut, ST, 2, MAT.Plaster, C.plaster:Lerp(C.thatch, 0.1 * f),
      { win(-12), win(2), win(16) }, { win(6), win(-12) },
      { { x = -12, w = DOOR_W, h = DOOR_H } }, { win(0) }, "F" .. f)
    K.timberWall(m, o * CFrame.new(0, 0, -(D + jut) / 2 - 1.1), W + jut, ST, 0.5, C.plaster, C.wood)
    K.autoDoor(m, o * CFrame.new(-(W + jut) / 2 - 1.2, 0, -12) * K.yaw(-math.pi / 2), DOOR_W, DOOR_H, { color = C.wood })
    -- one room per floor: bed, table, hearthless brazier, a chest
    K.bed(m, o * CFrame.new(-12, 0, 9) * K.yaw(math.pi), 8, 15, C.wood, C.canvas)
    K.table(m, o * CFrame.new(2, 0, 0), 12, 8, 5, C.plank)
    K.chair(m, o * CFrame.new(2, 0, 7) * K.yaw(math.pi))
    K.chest(m, o * CFrame.new(14, 0, -6), 3)
    K.shelf(m, o * CFrame.new((W + jut) / 2 - 3, 0, -4) * K.yaw(math.pi / 2), 14, 14, 4, C.plankDark, 4)
    local br = K.cyl(m, o * CFrame.new(13, 0, 10), 2.6, 5, MAT.Metal, C.iron, { name = "Brazier" })
    local fire = K.box(m, o * CFrame.new(13, 3.4, 10), Vector3.new(3.4, 1.6, 3.4), MAT.Neon, C.ember, { name = "BrazierFire", cancollide = false })
    glow(fire, C.ember, 22, 1.6)
    ceilingLamps(m, o * CFrame.new(0, ST - 1, 0), { -8, 10 }, { 0 }, 4)
  end

  -- The way up is OUTSIDE: one flight per storey up the west flank, all running the same way, with
  -- a gallery at each level joining the head of one flight to the foot of the next.
  --
  -- Two things were wrong. Every landing sat six studs SHORT of where its flight topped out, so the
  -- last treads climbed into the underside of the landing; and the flights alternated direction,
  -- which reads like a switchback but needs sixty studs of length per storey and only gave the
  -- flight below five studs of headroom. Same direction, stacked, with open treads: 23 studs clear.
  local FROM, RUN = 8, 24
  for f = 0, FLOORS - 2 do
    local y = ST * f
    local zL = FROM - RUN - 6                    -- the landing, beyond the head of the flight
    K.stairFlight(m, CFrame.new(-W / 2 - 16, y, FROM) * K.yaw(math.pi), 10, ST,
      MAT.WoodPlanks, C.plankDark, { railColor = C.wood, run = RUN, open = true })
    K.box(m, CFrame.new(-W / 2 - 16, y + ST - 0.8, zL), Vector3.new(12, 1.6, 12), MAT.WoodPlanks, C.plankDark, { name = "Landing" })
    K.railing(m, CFrame.new(-W / 2 - 22, y + ST, zL) * K.yaw(math.pi / 2), 12, 5, C.wood)
    -- the gallery is what the flat doors open onto, so it has to be wide enough to stand on and to
    -- reach from the landing back to the foot of the next flight
    K.box(m, CFrame.new(-W / 2 - 7.5, y + ST - 0.7, 0), Vector3.new(7, 1.4, D + 8), MAT.WoodPlanks, C.plankDark, { name = "Gallery" })
    K.box(m, CFrame.new(-W / 2 - 13, y + ST - 0.7, zL + 3), Vector3.new(4, 1.4, 6), MAT.WoodPlanks, C.plankDark, { name = "GalleryLink" })
    K.railing(m, CFrame.new(-W / 2 - 10.7, y + ST, 0) * K.yaw(math.pi / 2), D + 8, 5, C.wood)
  end
  -- the gallery and its landings stand on posts rather than on nothing
  local top = ST * (FLOORS - 1)
  for _, p in ipairs({ { -W / 2 - 21, FROM - RUN - 3 }, { -W / 2 - 21, FROM - RUN - 9 },
                       { -W / 2 - 10.7, -14 }, { -W / 2 - 10.7, 2 }, { -W / 2 - 10.7, 16 } }) do
    K.box(m, CFrame.new(p[1], top / 2, p[2]), Vector3.new(2, top, 2), MAT.Wood, C.wood, { name = "GalleryPost" })
  end
  -- a cluster of flues, not one chimney: five hearths need five
  for i = 0, 4 do
    local x, z = -14 + i * 7, D / 2 - 4 + (i % 2) * 3
    local h = 20 + (i % 3) * 8
    local f = K.box(m, CFrame.new(x, ST * (FLOORS - 1) + h / 2, z), Vector3.new(4.4, h, 4.4), MAT.Brick, rgb(132, 88, 72):Lerp(C.black, 0.1 * (i % 3)), { name = "Flue" })
    K.box(m, CFrame.new(x, ST * (FLOORS - 1) + h + 1, z), Vector3.new(5.6, 1.4, 5.6), MAT.Brick, C.darkStone, { name = "FlueCap" })
    if i % 2 == 0 then smoke(f, rgb(112, 110, 106), 4) end
  end
  K.roofMansard(m, floors[FLOORS - 1] * CFrame.new(0, ST, 0), W + (FLOORS - 1) * 1.8, D + (FLOORS - 1) * 1.8, 22, MAT.Slate, rgb(84, 90, 98), 3)
  K.dormer(m, floors[FLOORS - 1] * CFrame.new(-10, ST + 4, -(D + 7) / 2 + 6), 12, 10, 11, MAT.Plaster, C.plaster, MAT.Slate, rgb(84, 90, 98))

  -- street level: awning, counter, goods, and the washing overhead
  K.box(m, CFrame.new(-7, ST - 3, -D / 2 - 8), Vector3.new(22, 1, 16), MAT.Fabric, rgb(150, 76, 58), { name = "Awning" })
  for _, x in ipairs({ -17, 3 }) do K.cyl(m, CFrame.new(x, (ST - 3) / 2, -D / 2 - 15), 0.7, ST - 3, MAT.Metal, C.iron, { name = "AwningPost" }) end
  K.counter(m, CFrame.new(-7, 0, -D / 2 + 6), 20, 5, 6.4, C.plankDark)
  K.shelf(m, CFrame.new(-W / 2 + 3, 0, 6) * K.yaw(-math.pi / 2), 20, 16, 4, C.plankDark, 5)
  for i = 0, 3 do K.crate(m, CFrame.new(11 + (i % 2) * 7, 0, 2 + math.floor(i / 2) * 7), 5.4) end
  K.barrel(m, CFrame.new(16, 0, -8), 2.8, 6)
  washing(m, Vector3.new(-W / 2 - 4, ST * 2 + 14, -D / 2 - 6), Vector3.new(W / 2 + 6, ST * 3 + 10, -D / 2 - 9), 5, 11)
  washing(m, Vector3.new(-W / 2 - 2, ST * 3 + 12, -D / 2 - 4), Vector3.new(W / 2 + 4, ST * 2 + 16, -D / 2 - 7), 4, 23)
  K.sign(m, CFrame.new(-W / 2 + 2, ST - 8, -D / 2 - 9.4), "ห้องเช่า", 13, 5.4, rgb(56, 40, 30), rgb(240, 206, 140))
  K.lampPost(m, CFrame.new(W / 2 + 6, 0, -D / 2 - 10), 18, rgb(255, 198, 124))
end)

-- ==================================================== 2. the merchant's house
-- a warehouse floor with cart doors and a hoist, a counting room over it, living rooms above
-- that, all wrapped round a small courtyard with a gallery
K.build("City_MerchantHouse", nil, function(m)
  local W, D = 74, 62
  local YW, YD = 26, 22        -- the courtyard void
  K.box(m, CFrame.new(0, -1.5, 0), Vector3.new(W + 14, 3, D + 14), MAT.Cobblestone, C.darkStone, { name = "Plinth" })

  -- the plan is a ring: four ranges round a yard. the yard is what makes it a merchant's house.
  local function range(o, w, d, h, y, tag, front, back, left, right, mat, col)
    K.floorSlab(m, o * CFrame.new(0, y, 0), w, d, MAT.WoodPlanks, C.plankDark, { name = tag .. "Floor" })
    walls4(m, o * CFrame.new(0, y, 0), w, d, h, 2.4, mat, col, front, back, left, right, tag)
  end
  -- ground: warehouse ranges on three sides, cart entry on the front
  K.floorSlab(m, CFrame.new(0, 0, 0), W, D, MAT.Slate, rgb(126, 122, 116), { name = "YardFloor" })
  walls4(m, CFrame.new(0, 0, 0), W, D, ST, 3, MAT.Brick, rgb(144, 100, 82),
    { { x = -14, w = 22, h = 22 }, win(16) },
    { win(-18), { x = 14, w = DOOR_W, h = DOOR_H } },
    { win(-14), win(14) }, { win(0), { x = 18, w = DOOR_W, h = DOOR_H } }, "G")
  -- the courtyard void: a well of open air through the middle of the block
  K.box(m, CFrame.new(0, ST / 2, 4), Vector3.new(YW, ST, YD), MAT.SmoothPlastic, C.white, { name = "YardVoid", transparency = 1, cancollide = false })
  K.cyl(m, CFrame.new(0, 2, 4), 5, 4, MAT.Cobblestone, C.stone, { name = "YardWell" })
  K.cyl(m, CFrame.new(0, 4.2, 4), 3.8, 0.5, MAT.Glass, rgb(64, 110, 150), { name = "WellWater", transparency = 0.35, cancollide = false })
  for _, s in ipairs({ -1, 1 }) do
    K.box(m, CFrame.new(s * 5, 9, 4), Vector3.new(1.2, 14, 1.2), MAT.Wood, C.wood, { name = "WellPost" })
  end
  K.cylX(m, CFrame.new(0, 15.4, 4), 0.9, 11, MAT.Wood, C.wood, { name = "Windlass" })
  K.chain(m, Vector3.new(0, 15, 4), Vector3.new(0, 6, 4), 8, 0.22)

  -- warehouse fittings in the ranges
  K.autoDoor(m, CFrame.new(-14, 0, -D / 2 - 1.6), 22, 22, { color = C.plankDark })
  for i = 0, 9 do
    K.crate(m, CFrame.new(-W / 2 + 8 + (i % 5) * 9, 0, -D / 2 + 8 + math.floor(i / 5) * 9), 6.4)
  end
  -- the barrel range stands north of the stair, not on it
  for i = 0, 5 do K.barrel(m, CFrame.new(W / 2 - 9, 0, 8 + i * 4), 3, 7, i % 2 == 0 and C.wood or C.oak) end
  for i = 0, 3 do
    K.box(m, CFrame.new(-W / 2 + 6, 4 + i * 5.5, 18), Vector3.new(8, 1, 22), MAT.WoodPlanks, C.plankDark, { name = "StorageRack" })
  end
  -- the hoist: a beam through the front wall at first-floor level, with a sack on the hook
  K.box(m, CFrame.new(-14, ST + 8, -D / 2 - 9), Vector3.new(2.4, 2.4, 20), MAT.Wood, C.wood, { name = "HoistBeam" })
  K.gear(m, CFrame.new(-14, ST + 8, -D / 2 + 2) * K.yaw(math.pi / 2), 4.4, 16, 1.4, BRASS)
  K.chain(m, Vector3.new(-14, ST + 7, -D / 2 - 17), Vector3.new(-14, 14, -D / 2 - 17), 9, 0.26)
  K.box(m, CFrame.new(-14, 11, -D / 2 - 17), Vector3.new(7, 8, 7), MAT.Fabric, C.canvas, { name = "HoistedSack" })

  -- first floor: counting room and offices, with the gallery round the yard
  local y1 = ST
  -- the yard void AND the stairwell coming up the east range: the flight used to climb into the
  -- underside of this deck
  K.floorSlab(m, CFrame.new(0, y1, 0), W, D, MAT.WoodPlanks, C.plank,
    { name = "Floor1", holes = { { x = 0, z = 4, w = YW, d = YD }, { x = W / 2 - 12, z = -10, w = 13, d = 30 } } })
  K.railing(m, CFrame.new(0, y1, 4 - YD / 2 - 0.6), YW, 5, C.wood)
  K.railing(m, CFrame.new(0, y1, 4 + YD / 2 + 0.6), YW, 5, C.wood)
  K.railing(m, CFrame.new(-YW / 2 - 0.6, y1, 4) * K.yaw(math.pi / 2), YD, 5, C.wood)
  K.railing(m, CFrame.new(YW / 2 + 0.6, y1, 4) * K.yaw(math.pi / 2), YD, 5, C.wood)
  walls4(m, CFrame.new(0, y1, 0), W, D, ST, 2.4, MAT.Plaster, C.plaster,
    { win(-24), win(-4), win(16), win(32) }, { win(-20), win(0), win(20) },
    { win(-16), win(12) }, { win(-12), win(16) }, "F1")
  K.timberWall(m, CFrame.new(0, y1, -D / 2 - 1.4), W, ST, 0.5, C.plaster, C.wood)
  K.stairFlight(m, CFrame.new(W / 2 - 12, 0, -D / 2 + 8), 11, ST, MAT.WoodPlanks, C.plankDark, { railColor = C.wood, run = 26 })
  -- the counting room sits clear of the flight coming up the west range
  K.table(m, CFrame.new(-8, y1, -18), 20, 11, 5.4, C.oak)
  K.chair(m, CFrame.new(-8, y1, -9) * K.yaw(math.pi))
  K.chair(m, CFrame.new(-18, y1, -24))
  K.shelf(m, CFrame.new(-W / 2 + 3, y1, -6) * K.yaw(-math.pi / 2), 24, 18, 4.4, C.plankDark, 5)
  K.counter(m, CFrame.new(22, y1, -D / 2 + 5), 22, 5, 6.6, C.plankDark)
  for i = 0, 4 do K.chest(m, CFrame.new(16 + i * 8, y1, D / 2 - 7), 3.4) end
  K.rug(m, CFrame.new(-8, y1 + 0.2, -18), 26, 20, rgb(70, 62, 100))
  ceilingLamps(m, CFrame.new(0, y1 + ST - 1, 0), { -24, 24 }, { -20, 22 }, 4)

  -- second floor: the family's rooms, the yard now roofed over with glass
  local y2 = y1 + ST
  K.floorSlab(m, CFrame.new(0, y2, 0), W, D, MAT.WoodPlanks, C.plank,
    { name = "Floor2", holes = { { x = 0, z = 4, w = YW - 8, d = YD - 8 },
                                 { x = -W / 2 + 12, z = -10, w = 13, d = 30 } } })
  K.railing(m, CFrame.new(0, y2, 4 - (YD - 8) / 2 - 0.6), YW - 8, 5, C.wood)
  K.railing(m, CFrame.new(0, y2, 4 + (YD - 8) / 2 + 0.6), YW - 8, 5, C.wood)
  walls4(m, CFrame.new(0, y2, 0), W, D, ST - 4, 2.4, MAT.Plaster, C.plaster,
    { win(-20, 6), win(2, 6), win(24, 6) }, { win(-16, 6), win(16, 6) }, { win(0, 6) }, { win(0, 6) }, "F2")
  K.timberWall(m, CFrame.new(0, y2, -D / 2 - 1.4), W, ST - 4, 0.5, C.plaster, C.wood)
  K.stairFlight(m, CFrame.new(-W / 2 + 12, y1, -D / 2 + 8), 11, ST, MAT.WoodPlanks, C.plankDark, { railColor = C.wood, run = 26 })
  K.fireplace(m, CFrame.new(-22, y2, D / 2 - 4) * K.yaw(math.pi), 20, 18, C.darkStone)
  K.bed(m, CFrame.new(-26, y2, -16) * K.yaw(math.pi / 2), 11, 18, C.oak, rgb(120, 62, 72))
  K.bed(m, CFrame.new(24, y2, -16) * K.yaw(-math.pi / 2), 9, 16, C.wood, C.canvas)
  K.table(m, CFrame.new(0, y2, -22), 16, 10, 5.2, C.plank)
  K.chest(m, CFrame.new(28, y2, 16), 3.4)
  K.rug(m, CFrame.new(0, y2 + 0.2, -22), 22, 16, rgb(112, 60, 58))
  ceilingLamps(m, CFrame.new(0, y2 + ST - 5, 0), { -20, 20 }, { -18, 18 }, 4)

  -- roof: hipped over the ranges, glazed over the yard, one big stack off centre
  K.roofHip(m, CFrame.new(0, y2 + ST - 4, 0), W, D, 24, MAT.RoofShingles, rgb(122, 78, 62), 4)
  for _, sz in ipairs({ -1, 1 }) do
    K.box(m, CFrame.new(0, y2 + ST - 3, 4 + sz * 7), Vector3.new(YW - 6, 0.6, 3), MAT.Metal, C.brassDark, { name = "GlassBar" })
  end
  K.box(m, CFrame.new(0, y2 + ST - 3.2, 4), Vector3.new(YW - 6, 0.5, YD - 6), MAT.Glass, C.glass, { name = "YardGlazing", transparency = 0.45, cancollide = false })
  local stack = K.box(m, CFrame.new(-22, y2 + ST + 12, D / 2 - 2), Vector3.new(12, 34, 10), MAT.Brick, rgb(128, 84, 70):Lerp(C.black, 0.15), { name = "Stack" })
  K.box(m, CFrame.new(-22, y2 + ST + 30, D / 2 - 2), Vector3.new(14, 2, 12), MAT.Brick, C.darkStone, { name = "StackCap" })
  smoke(stack, rgb(114, 112, 108), 7)
  K.dormer(m, CFrame.new(18, y2 + ST + 1, -D / 2 + 8), 13, 10, 12, MAT.Plaster, C.plaster, MAT.RoofShingles, rgb(122, 78, 62))

  local arm = K.box(m, CFrame.new(-W / 2 + 4, ST - 4, -D / 2 - 6), Vector3.new(1.2, 1.2, 12), MAT.Metal, C.iron, { name = "SignArm" })
  K.chain(m, arm.CFrame.Position + Vector3.new(0, 0, -5), arm.CFrame.Position + Vector3.new(0, -5, -5), 4, 0.24)
  K.sign(m, CFrame.new(-W / 2 + 4, ST - 15, -D / 2 - 11), "ห้างพ่อค้า", 15, 6, rgb(52, 38, 30), rgb(242, 208, 138))
  K.lampPost(m, CFrame.new(W / 2 + 6, 0, -D / 2 - 8), 18, rgb(255, 198, 124))
end)

-- ========================================================== 3. the guildhall
-- an open arcaded market floor at street level with the hall above it, reached by a broad
-- external stair; a bell turret on one corner and a clock face on the front
K.build("City_Guildhall", nil, function(m)
  local W, D = 82, 52
  K.box(m, CFrame.new(0, -1.5, 0), Vector3.new(W + 18, 3, D + 18), MAT.Cobblestone, C.darkStone, { name = "Plinth" })

  -- ground floor is an open arcade: piers only, no walls. the market happens under the hall.
  K.floorSlab(m, CFrame.new(0, 0, 0), W, D, MAT.Slate, rgb(132, 128, 122), { name = "MarketFloor" })
  local bays = 6
  for i = 0, bays do
    local x = -W / 2 + W * i / bays
    for _, sz in ipairs({ -1, 1 }) do
      K.box(m, CFrame.new(x, ST / 2, sz * (D / 2 - 3)), Vector3.new(7, ST, 7), MAT.Rock, STONE, { name = "Pier" })
    end
    if i < bays then
      local xm = x + W / bays / 2
      for _, sz in ipairs({ -1, 1 }) do
        K.archOpening(m, CFrame.new(xm, 0, sz * (D / 2 - 3)), W / bays - 8, ST - 8, 3, MAT.Rock, STONE:Lerp(C.white, 0.1))
      end
    end
  end
  for _, sx in ipairs({ -1, 1 }) do
    K.box(m, CFrame.new(sx * (W / 2 - 3), ST / 2, 0), Vector3.new(7, ST, D - 6), MAT.Rock, STONE, { name = "EndWall" })
  end
  K.box(m, CFrame.new(0, ST - 1.4, 0), Vector3.new(W + 4, 3, D + 4), MAT.Rock, STONE_DARK, { name = "HallPlinth" })
  -- market stalls between the piers
  for i = 0, 4 do
    local x = -W / 2 + 12 + i * 14
    K.counter(m, CFrame.new(x, 0, -6), 12, 5, 6.4, C.plankDark)
    K.box(m, CFrame.new(x, 12, -6), Vector3.new(14, 0.6, 9), MAT.Fabric, ({ rgb(150, 76, 58), rgb(80, 110, 140), rgb(140, 130, 80) })[i % 3 + 1], { name = "StallAwning" })
    for _, z in ipairs({ 8, 14 }) do K.crate(m, CFrame.new(x, 0, z), 5) end
    K.barrel(m, CFrame.new(x + 6, 0, 2), 2.4, 5.4)
  end
  ceilingLamps(m, CFrame.new(0, ST - 3, 0), { -28, 0, 28 }, { -12, 12 }, 4)

  -- the hall above: one big room, trussed, with a gallery at one end only
  local y1 = ST
  local HH = 34
  K.floorSlab(m, CFrame.new(0, y1, 0), W, D, MAT.WoodPlanks, C.plank, { name = "HallFloor" })
  walls4(m, CFrame.new(0, y1, 0), W, D, HH, 3, MAT.Plaster, C.plaster,
    { win(-30, 10), win(-10, 10), win(10, 10), win(30, 10) },
    { win(-24, 10), { x = 0, w = DOOR_W, h = DOOR_H }, win(24, 10) },
    { win(0, 10) }, { win(0, 10) }, "Hall")
  K.timberWall(m, CFrame.new(0, y1, -D / 2 - 1.7), W, HH, 0.6, C.plaster, C.wood)
  K.timberWall(m, CFrame.new(-W / 2 - 1.7, y1, 0) * K.yaw(-math.pi / 2), D, HH, 0.6, C.plaster, C.wood)
  K.roofGable(m, CFrame.new(0, y1 + HH, 0), W, D, 26, MAT.RoofShingles, rgb(112, 72, 60), 5)
  for i = 0, 5 do
    local z = -D / 2 + 6 + i * (D - 12) / 5
    K.box(m, CFrame.new(0, y1 + HH - 2, z), Vector3.new(W - 8, 2, 2.4), MAT.Wood, C.wood, { name = "TieBeam", cancollide = false })
    K.rod(m, Vector3.new(-W / 2 + 4, y1 + HH, z), Vector3.new(0, y1 + HH + 25, z), 1, MAT.Wood, C.wood, { name = "Rafter", cancollide = false })
    K.rod(m, Vector3.new(W / 2 - 4, y1 + HH, z), Vector3.new(0, y1 + HH + 25, z), 1, MAT.Wood, C.wood, { name = "Rafter", cancollide = false })
  end
  -- broad external stair up the front to the hall door, with the landing BEYOND the head of the
  -- flight rather than laid across its last treads
  K.stairFlight(m, CFrame.new(0, 0, -D / 2 - 30), 20, ST, MAT.Rock, STONE_DARK, { railColor = C.iron, run = 26 })
  K.box(m, CFrame.new(0, y1 - 1.2, -D / 2 - 1), Vector3.new(24, 2.4, 6), MAT.Rock, STONE_DARK, { name = "Landing" })
  K.autoDoor(m, CFrame.new(0, y1, -D / 2 - 1.8), DOOR_W + 6, DOOR_H + 4, { color = C.wood })
  -- the gallery stair used to sit at x = W/2 - 9, which put its outer half inside the end wall,
  -- and the gallery had no stairwell so the flight ran into its underside. A walk test found both.
  K.floorSlab(m, CFrame.new(W / 2 - 14, y1 + 20, 0), 26, D - 8, MAT.WoodPlanks, C.plank,
    { name = "Gallery", hole = { x = -4, z = 2, w = 20, d = 36 } })
  K.railing(m, CFrame.new(W / 2 - 27, y1 + 20, 0) * K.yaw(math.pi / 2), D - 8, 5, C.wood)
  K.stairFlight(m, CFrame.new(W / 2 - 18, y1, -D / 2 + 8), 10, 20, MAT.WoodPlanks, C.plankDark, { railColor = C.wood })
  -- the guild's furniture: a long board, a lectern, chests of records, banners of trades
  K.table(m, CFrame.new(-8, y1, 0), 46, 13, 5.6, C.oak)
  for _, z in ipairs({ -9, 9 }) do
    K.box(m, CFrame.new(-8, y1 + 3, z), Vector3.new(44, 0.9, 4), MAT.WoodPlanks, C.plankDark, { name = "Bench" })
    K.box(m, CFrame.new(-8, y1 + 1.5, z), Vector3.new(43, 3, 0.9), MAT.Wood, C.wood, { name = "BenchLeg" })
  end
  K.box(m, CFrame.new(-W / 2 + 12, y1 + 1.4, 0), Vector3.new(16, 2.8, 20), MAT.Slate, rgb(140, 136, 130), { name = "Dais" })
  K.table(m, CFrame.new(-W / 2 + 12, y1 + 2.8, 0), 14, 9, 5.4, C.oak)
  K.chair(m, CFrame.new(-W / 2 + 12, y1 + 2.8, 8) * K.yaw(math.pi))
  K.fireplace(m, CFrame.new(18, y1, D / 2 - 4) * K.yaw(math.pi), 22, 20, C.darkStone)
  for i = 0, 4 do K.chest(m, CFrame.new(-24 + i * 12, y1, D / 2 - 8), 3.6) end
  K.rug(m, CFrame.new(-8, y1 + 0.2, 0), 52, 24, rgb(64, 78, 108))
  for i = 0, 4 do
    K.box(m, CFrame.new(-28 + i * 14, y1 + 20, -D / 2 + 4), Vector3.new(11, 20, 0.6), MAT.Fabric,
      ({ rgb(148, 44, 48), rgb(58, 84, 132), rgb(72, 108, 76), rgb(150, 118, 48), rgb(104, 62, 120) })[i + 1], { name = "TradeBanner", cancollide = false })
  end
  for _, x in ipairs({ -24, 4, 30 }) do
    K.chain(m, Vector3.new(x, y1 + HH - 2, 0), Vector3.new(x, y1 + HH - 8, 0), 4, 0.24)
    K.lantern(m, CFrame.new(x, y1 + HH - 14, 0), 5)
  end

  -- The bell tower, standing forward of the front-left corner with the clock face on the street.
  --
  -- Two things put it here. It was a solid 18-stud block of stone with a 30-stud flight modelled
  -- through it, which fits nowhere: the stair began on top of the dais, ran into the tower and
  -- ended inside the wall. And a tower inside the hall's own footprint is a tower with the gable
  -- roof through the middle of it, which no amount of hollowing fixes. So: four walls, entered
  -- from the street at ground level, climbed by a spiral round a newel -- the only stair that fits
  -- a turret this narrow.
  local tx, tz = -W / 2 + 8, -(D / 2 + 10)
  local TOP = y1 + HH + 26
  K.box(m, CFrame.new(tx, -1.5, tz), Vector3.new(24, 3, 24), MAT.Cobblestone, C.darkStone, { name = "TurretPlinth" })
  local slits = {}
  for i = 1, 4 do table.insert(slits, { x = 0, w = 3.4, h = 9, sill = i * 16 }) end
  K.wallRun(m, CFrame.new(tx - 7.5, 0, tz) * K.yaw(-math.pi / 2), 18, TOP, 3, MAT.Rock, STONE, slits, { name = "BellTurret" })
  K.wallRun(m, CFrame.new(tx + 7.5, 0, tz) * K.yaw(math.pi / 2), 18, TOP, 3, MAT.Rock, STONE, slits, { name = "BellTurret" })
  K.wallRun(m, CFrame.new(tx, 0, tz + 7.5) * K.yaw(math.pi), 18, TOP, 3, MAT.Rock, STONE, {}, { name = "BellTurret" })
  K.wallRun(m, CFrame.new(tx, 0, tz - 7.5), 18, TOP, 3, MAT.Rock, STONE,
    { { x = 0, w = 10, h = DOOR_H, sill = 0 } }, { name = "BellTurret" })
  K.archOpening(m, CFrame.new(tx, 0, tz - 7.5), 10, DOOR_H, 2.4, MAT.Rock, STONE:Lerp(C.white, 0.1))
  for i = 1, 3 do K.band(m, CFrame.new(tx, i * TOP / 4, tz), 10, 2, STONE:Lerp(C.white, 0.16)) end
  K.gauge(m, CFrame.new(tx, y1 + HH + 4, tz - 9.4) * K.yaw(math.pi / 2), 6.4, BRASS)
  K.spiralStair(m, CFrame.new(tx, 0, tz), 5.4, TOP, MAT.Rock, STONE_DARK, { newel = 1.4, advance = 1.6 })
  -- the deck is a ring: the hatch takes the whole span between the walls, which is where the
  -- spiral arrives
  K.roofBattlement(m, CFrame.new(tx, TOP, tz), 18, 18,
    { color = STONE_DARK, merlon = 6.6, step = 7, overhang = 2.6, hole = { x = 0, z = 0, w = 12, d = 12 } })
  -- an open belfry over it: a capped roof at deck height would have been a lid two studs above the
  -- head of anyone climbing out
  for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
    K.box(m, CFrame.new(tx + c[1] * 6.4, TOP + 4, tz + c[2] * 6.4), Vector3.new(2, 8, 2), MAT.Rock, STONE, { name = "BelfryPost" })
  end
  K.roofPyramid(m, CFrame.new(tx, TOP + 8, tz), 15, 15, 16, MAT.Metal, C.verdigris, 1.4)
  K.box(m, CFrame.new(tx, TOP + 7.4, tz), Vector3.new(14, 1.4, 1.4), MAT.Wood, C.wood, { name = "BellBeam" })
  local bell = K.ball(m, CFrame.new(tx, TOP + 4.6, tz), 6, MAT.Metal, BRASS, { name = "GuildBell", cancollide = false })
  glow(bell, rgb(255, 214, 140), 36, 1.6)
  K.sign(m, CFrame.new(0, y1 - 8, -D / 2 - 6.4), "หอสมาคมช่าง", 26, 6.4, rgb(44, 42, 46), rgb(238, 220, 160))
  K.lampPost(m, CFrame.new(-16, 0, -D / 2 - 34), 18, rgb(255, 200, 130))
  K.lampPost(m, CFrame.new(16, 0, -D / 2 - 34), 18, rgb(255, 200, 130))
end)

-- ============================================================ 4. the foundry
-- the steampunk one: a tall casting hall with a travelling crane, two furnaces, a coal yard,
-- and the biggest stack in the city. the office is a lean-to bolted on the side.
K.build("City_Foundry", nil, function(m)
  local W, D, H = 88, 60, 52
  K.box(m, CFrame.new(0, -1.5, 0), Vector3.new(W + 34, 3, D + 22), MAT.Concrete, C.darkStone, { name = "Plinth" })
  local brick = rgb(126, 78, 62)

  K.floorSlab(m, CFrame.new(0, 0, 0), W, D, MAT.Concrete, rgb(96, 94, 92), { name = "CastingFloor" })
  walls4(m, CFrame.new(0, 0, 0), W, D, H, 3.4, MAT.Brick, brick,
    { { x = -18, w = 34, h = 30 }, { x = 22, w = 11, h = 14, sill = 32 } },
    { { x = -24, w = 11, h = 14, sill = 32 }, { x = 0, w = 11, h = 14, sill = 32 }, { x = 24, w = DOOR_W + 4, h = DOOR_H } },
    { { x = -14, w = 11, h = 14, sill = 32 }, { x = 14, w = 11, h = 14, sill = 32 } },
    { { x = -10, w = 11, h = 14, sill = 32 }, { x = 16, w = DOOR_W + 4, h = DOOR_H } }, "Hall")
  K.roofGable(m, CFrame.new(0, H, 0), W, D, 26, MAT.Metal, rgb(118, 90, 64), 5)
  -- a clerestory ridge vent: the row of little roofs a real foundry has to let heat out
  for i = 0, 6 do
    local z = -D / 2 + 6 + i * (D - 12) / 6
    K.box(m, CFrame.new(0, H + 20, z), Vector3.new(16, 8, 5), MAT.Metal, C.iron, { name = "RidgeVent" })
    K.roofShed(m, CFrame.new(0, H + 24, z), 18, 6, 4, MAT.Metal, C.rust, 1)
    K.box(m, CFrame.new(0, H - 2, z), Vector3.new(W - 6, 2, 3), MAT.Metal, C.iron, { name = "TieBeam", cancollide = false })
    K.rod(m, Vector3.new(-W / 2 + 3, H, z), Vector3.new(0, H + 25, z), 1.2, MAT.Metal, C.iron, { name = "Rafter", cancollide = false })
    K.rod(m, Vector3.new(W / 2 - 3, H, z), Vector3.new(0, H + 25, z), 1.2, MAT.Metal, C.iron, { name = "Rafter", cancollide = false })
  end

  -- travelling crane on rails down both walls
  for _, sx in ipairs({ -1, 1 }) do
    K.box(m, CFrame.new(sx * (W / 2 - 5), 34, 0), Vector3.new(4, 3, D - 8), MAT.Metal, C.steel, { name = "CraneRail" })
    for i = 0, 4 do
      K.cyl(m, CFrame.new(sx * (W / 2 - 5), 17, -D / 2 + 8 + i * (D - 16) / 4), 1.6, 34, MAT.Metal, C.iron, { name = "CraneColumn" })
    end
  end
  K.box(m, CFrame.new(0, 37, -6), Vector3.new(W - 8, 4, 8), MAT.Metal, C.steel, { name = "CraneGirder" })
  K.box(m, CFrame.new(-8, 40, -6), Vector3.new(14, 7, 11), MAT.Metal, C.brassDark, { name = "CraneTrolley" })
  K.chain(m, Vector3.new(-8, 36, -6), Vector3.new(-8, 16, -6), 12, 0.34)
  K.box(m, CFrame.new(-8, 13, -6), Vector3.new(9, 6, 9), MAT.Metal, C.iron, { name = "CraneHook" })
  K.gear(m, CFrame.new(-2, 40, -6) * K.yaw(math.pi / 2), 5, 18, 1.6, BRASS)

  -- two furnaces, deliberately different: a squat cupola and a tall blast stack
  local f1 = CFrame.new(-W / 2 + 18, 0, D / 2 - 16)
  K.cyl(m, f1 * CFrame.new(0, 15, 0), 12, 30, MAT.Brick, brick:Lerp(C.black, 0.25), { name = "Cupola" })
  for i = 1, 3 do K.band(m, f1 * CFrame.new(0, i * 8, 0), 12.6, 2.4, C.rust) end
  local mouth1 = K.box(m, f1 * CFrame.new(0, 8, -12.4), Vector3.new(9, 8, 1), MAT.Neon, rgb(255, 132, 30), { name = "FurnaceMouth", cancollide = false })
  glow(mouth1, rgb(255, 132, 30), 70, 3.6)
  local st1 = K.cyl(m, f1 * CFrame.new(0, H * 0.7, 0), 6, H * 0.8, MAT.Metal, C.iron, { name = "CupolaStack" })
  smoke(st1, rgb(74, 72, 70), 10)

  local f2 = CFrame.new(W / 2 - 20, 0, D / 2 - 18)
  K.box(m, f2 * CFrame.new(0, 20, 0), Vector3.new(26, 40, 24), MAT.Brick, brick:Lerp(C.black, 0.32), { name = "BlastFurnace" })
  local mouth2 = K.box(m, f2 * CFrame.new(0, 9, -12.4), Vector3.new(13, 10, 1), MAT.Neon, rgb(255, 150, 40), { name = "TapHole", cancollide = false })
  glow(mouth2, rgb(255, 150, 40), 80, 4)
  K.box(m, f2 * CFrame.new(0, 42, 0), Vector3.new(30, 6, 28), MAT.Metal, C.iron, { name = "FurnaceHood" })
  for i = 0, 2 do
    K.boiler(m, f2 * CFrame.new(-20 + i * 20, 12, 16), 5, 24, { bands = 3, rivets = 14, firebox = i == 1 })
  end
  K.pipe(m, { (f2 * CFrame.new(-20, 26, 16)).Position, (f2 * CFrame.new(-20, 34, 4)).Position,
              (f2 * CFrame.new(0, 34, -2)).Position, (f2 * CFrame.new(0, 20, -10)).Position }, 2.2, C.copper)
  K.valveWheel(m, f2 * CFrame.new(-13, 20, 12), 4, 5)
  K.gauge(m, f2 * CFrame.new(0, 26, -12.8) * K.yaw(math.pi / 2), 4)

  -- the great stack, off centre and slightly out of plumb
  local stack = K.cyl(m, CFrame.new(W / 2 - 8, 70, D / 2 + 8) * K.roll(math.rad(-1.6)), 9, 140, MAT.Brick, brick:Lerp(C.black, 0.2), { name = "GreatStack" })
  for i = 1, 7 do K.band(m, CFrame.new(W / 2 - 8, i * 18, D / 2 + 8), 9.6, 2.4, C.rust) end
  K.cyl(m, CFrame.new(W / 2 - 8, 141, D / 2 + 8), 11, 3, MAT.Metal, C.brassDark, { name = "StackCap" })
  smoke(stack, rgb(66, 64, 62), 16)
  local vent = K.cyl(m, CFrame.new(W / 2 - 22, 58, D / 2 + 6), 3.4, 20, MAT.Metal, C.verdigris, { name = "ReliefVent" })
  steamJet(vent, 20)

  -- casting floor: sand moulds, ladles, ingot stacks, bar stock, a quench pit
  for i = 0, 5 do
    K.box(m, CFrame.new(-26 + (i % 3) * 16, 1, -14 + math.floor(i / 3) * 16), Vector3.new(13, 2, 13), MAT.Sand, rgb(150, 132, 104), { name = "MouldBed" })
    if i % 2 == 0 then
      local hot = K.box(m, CFrame.new(-26 + (i % 3) * 16, 2.2, -14 + math.floor(i / 3) * 16), Vector3.new(9, 0.8, 9), MAT.Neon, rgb(255, 120, 30), { name = "PouredMetal", cancollide = false })
      glow(hot, rgb(255, 120, 30), 30, 2.4)
    end
  end
  K.cyl(m, CFrame.new(6, 5, 16), 6, 10, MAT.Metal, C.iron, { name = "Ladle" })
  K.cylX(m, CFrame.new(6, 9, 16) * K.yaw(math.pi / 2), 0.9, 18, MAT.Metal, C.brassDark, { name = "LadleYoke" })
  local pit = K.box(m, CFrame.new(28, 0.6, 10), Vector3.new(16, 2, 12), MAT.Metal, C.steel, { name = "QuenchPit" })
  K.box(m, CFrame.new(28, 1.5, 10), Vector3.new(15, 0.5, 11), MAT.Glass, rgb(88, 148, 188), { name = "QuenchWater", transparency = 0.4, cancollide = false })
  for i = 0, 11 do
    K.box(m, CFrame.new(-W / 2 + 8 + (i % 4) * 5, 1 + math.floor(i / 4) * 2, -D / 2 + 8), Vector3.new(4.4, 2, 9), MAT.Metal, C.steel:Lerp(C.black, 0.2), { name = "Ingot" })
  end
  for i = 0, 7 do K.cyl(m, CFrame.new(W / 2 - 10 + (i % 4) * 2, 14, -D / 2 + 10) * K.roll(math.rad(4 + i)), 0.9, 28, MAT.Metal, C.steel, { name = "BarStock", cancollide = false }) end
  ceilingLamps(m, CFrame.new(0, H - 3, 0), { -26, 0, 26 }, { -16, 16 }, 6, rgb(255, 214, 170))

  -- big sliding doors on the front, one rolled clear
  K.box(m, CFrame.new(-18, 31, -D / 2 - 2.4), Vector3.new(66, 2, 2.4), MAT.Metal, C.iron, { name = "DoorRail" })
  K.box(m, CFrame.new(-44, 15, -D / 2 - 2), Vector3.new(17, 30, 1.4), MAT.Metal, C.rust, { name = "SlideDoorA" })
  K.box(m, CFrame.new(2, 15, -D / 2 - 3.6), Vector3.new(17, 30, 1.4), MAT.Metal, C.rust, { name = "SlideDoorB" })
  for _, x in ipairs({ -51, -37, -5, 9 }) do
    K.cylX(m, CFrame.new(x, 30.4, -D / 2 - (x < -20 and 2 or 3.6)) * K.yaw(math.pi / 2), 1, 0.9, MAT.Metal, BRASS, { name = "DoorRoller", cancollide = false })
  end

  -- office lean-to on the west flank, two low floors with its own stair
  local ao = CFrame.new(-W / 2 - 15, 0, -8)
  K.floorSlab(m, ao, 26, 30, MAT.WoodPlanks, C.plankDark, { name = "OfficeFloor" })
  walls4(m, ao, 26, 30, 22, 2, MAT.Brick, brick:Lerp(C.white, 0.08),
    { { x = -4, w = DOOR_W, h = DOOR_H }, { x = 8, w = 8, h = 9, sill = 7 } },
    { { x = 0, w = 8, h = 9, sill = 7 } }, { { x = -6, w = 8, h = 9, sill = 7 }, { x = 8, w = 8, h = 9, sill = 7 } }, {}, "Office")
  K.stairFlight(m, ao * CFrame.new(8, 0, -11), 9, 22, MAT.WoodPlanks, C.plankDark, { railColor = C.wood, run = 24 })
  K.floorSlab(m, ao * CFrame.new(0, 22, 0), 26, 30, MAT.WoodPlanks, C.plank,
    { name = "OfficeUpper", hole = { x = 8, z = 10, w = 12, d = 34 } })
  walls4(m, ao * CFrame.new(0, 22, 0), 26, 30, 20, 2, MAT.Plaster, C.plaster,
    { { x = -6, w = 8, h = 9, sill = 6 }, { x = 7, w = 8, h = 9, sill = 6 } },
    { { x = 0, w = 8, h = 9, sill = 6 } }, { { x = 0, w = 8, h = 9, sill = 6 } }, {}, "OfficeU")
  K.roofShed(m, ao * CFrame.new(0, 42, 0), 28, 32, 10, MAT.Metal, C.rust, 2)
  K.autoDoor(m, ao * CFrame.new(-4, 0, -16.2), DOOR_W, DOOR_H, { color = C.wood })
  K.table(m, ao * CFrame.new(-4, 0, 4), 14, 9, 5.2, C.oak)
  K.chair(m, ao * CFrame.new(-4, 0, 12) * K.yaw(math.pi))
  K.shelf(m, ao * CFrame.new(-10, 0, -4) * K.yaw(-math.pi / 2), 20, 16, 4, C.plankDark, 5)
  K.table(m, ao * CFrame.new(-4, 22, 0), 16, 10, 5.2, C.plank)
  for i = 0, 2 do K.chair(m, ao * CFrame.new(-10 + i * 6, 22, 8) * K.yaw(math.pi)) end
  ceilingLamps(m, ao * CFrame.new(0, 20, 0), { 0 }, { 0 }, 4)
  ceilingLamps(m, ao * CFrame.new(0, 40, 0), { -4 }, { 0 }, 4)

  -- coal yard on the east, with a tipping wagon on rails
  K.box(m, CFrame.new(W / 2 + 20, 5, 4), Vector3.new(34, 10, 36), MAT.WoodPlanks, C.plankDark, { name = "CoalBunker" })
  K.box(m, CFrame.new(W / 2 + 20, 11, 4), Vector3.new(31, 4, 33), MAT.Slate, C.coal, { name = "Coal", cancollide = false })
  for _, sz in ipairs({ -1, 1 }) do
    K.box(m, CFrame.new(W / 2 + 20, 0.6, 4 + sz * 6), Vector3.new(50, 1.2, 2), MAT.Metal, C.rust, { name = "Rail" })
  end
  local wagon = K.box(m, CFrame.new(W / 2 - 2, 5, 4), Vector3.new(14, 8, 12), MAT.CorrodedMetal, C.rust, { name = "CoalWagon" })
  K.box(m, CFrame.new(W / 2 - 2, 9.4, 4), Vector3.new(12, 2, 10), MAT.Slate, C.coal, { name = "WagonLoad", cancollide = false })
  for _, sx in ipairs({ -1, 1 }) do
    for _, sz in ipairs({ -1, 1 }) do
      K.cylX(m, CFrame.new(W / 2 - 2 + sx * 5, 1.8, 4 + sz * 6) * K.yaw(math.pi / 2), 1.8, 1.4, MAT.Metal, C.iron, { name = "Wheel" })
    end
  end
  K.sign(m, CFrame.new(-18, 34, -D / 2 - 3.4), "โรงหลอมเหล็ก", 30, 7, rgb(40, 36, 34), rgb(248, 190, 108))
  K.lampPost(m, CFrame.new(-W / 2 - 32, 0, -D / 2 - 6), 18, rgb(255, 176, 112))
  K.lampPost(m, CFrame.new(W / 2 + 8, 0, -D / 2 - 8), 18, rgb(255, 176, 112))
end)
