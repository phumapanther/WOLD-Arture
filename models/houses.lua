-- houses — five house types that share a world but not a template, at the same room scale as
-- the landmarks: storey height 26, doorways 12 x 18 on swinging auto-doors, windows 9 x 11.
-- every upper floor has a stairwell cut through it, so the flight below has headroom.
--
-- massing is deliberately asymmetric: a wing at a different height, a lean-to bolted on one
-- side, a chimney off the gable, a stair on the outside.
K.SET = "houses"
K.SLOT = 150
K.PER_ROW = 3
K.ORIGIN = Vector3.new(0, 0, 1000)

local C = K.C
local MAT = K.MAT
local rgb = Color3.fromRGB
local ST = 26
local DOOR_W, DOOR_H = 12, 18
local WIN_W, WIN_H, SILL = 9, 11, 7

local function glow(part, color, range, brightness)
  local l = Instance.new("PointLight")
  l.Color = color or C.lamp; l.Range = range or 26; l.Brightness = brightness or 0.56; l.Parent = part
  return l
end
local function smoke(part, color, size)
  local s = Instance.new("Smoke")
  s.Size = size or 6; s.RiseVelocity = 7; s.Opacity = 0.2; s.Color = color or rgb(104, 102, 98); s.Parent = part
  return s
end
local function steamJet(part, rate)
  local e = Instance.new("ParticleEmitter")
  e.Name = "SteamJet"
  e.Color = ColorSequence.new(rgb(226, 234, 242))
  e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.4) })
  e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
  e.Lifetime = NumberRange.new(1.4, 2.6); e.Rate = rate or 9
  e.Speed = NumberRange.new(3, 5); e.SpreadAngle = Vector2.new(12, 12)
  e.EmissionDirection = Enum.NormalId.Top; e.Parent = part
  return e
end
local function plinth(m, w, d, h, mat, col)
  K.box(m, CFrame.new(0, -(h or 2) / 2, 0), Vector3.new(w, h or 2, d), mat or MAT.Cobblestone, col or C.darkStone, { name = "Plinth" })
end
local function walls4(m, o, w, d, h, thick, mat, col, front, back, left, right, tag)
  K.wallRun(m, o * CFrame.new(0, 0, -d / 2), w, h, thick, mat, col, front, { name = (tag or "") .. "Front" })
  K.wallRun(m, o * CFrame.new(0, 0, d / 2) * K.yaw(math.pi), w, h, thick, mat, col, back, { name = (tag or "") .. "Back" })
  K.wallRun(m, o * CFrame.new(-w / 2, 0, 0) * K.yaw(-math.pi / 2), d, h, thick, mat, col, left, { name = (tag or "") .. "Left" })
  K.wallRun(m, o * CFrame.new(w / 2, 0, 0) * K.yaw(math.pi / 2), d, h, thick, mat, col, right, { name = (tag or "") .. "Right" })
end
local function win(x, sill) return { x = x, w = WIN_W, h = WIN_H, sill = sill or SILL } end
local function flight(m, x, y, z, width, rise, mat, col, opts)
  local run = K.stairFlight(m, CFrame.new(x, y, z), width, rise, mat, col, opts)
  return { x = x, z = z + run / 2 + 3, w = width + 4, d = run + 8 }
end
local function ceilingLamps(m, cf, xs, zs, size, color)
  for _, x in ipairs(xs) do
    for _, z in ipairs(zs) do
      K.chain(m, (cf * CFrame.new(x, 0, z)).Position, (cf * CFrame.new(x, -4, z)).Position, 3, 0.2)
      K.lantern(m, cf * CFrame.new(x, -8, z), size or 4, color)
    end
  end
end

-- a round wall built from staves, with angular gaps left for doors and windows
local function drum(m, cf, r, h, mat, color, skip, segs)
  local n = segs or 36
  local g = K.model(m, "Drum")
  for i = 0, n - 1 do
    local a = i * 2 * math.pi / n
    local cut
    for _, s in ipairs(skip or {}) do
      local da = math.abs(((a - s.a + math.pi) % (2 * math.pi)) - math.pi)
      if da <= s.span / 2 then cut = s end
    end
    local arc = 2 * math.pi * r / n
    local function seg(y0, y1)
      if y1 - y0 < 0.05 then return end
      K.box(g, cf * CFrame.new(math.cos(a) * r, (y0 + y1) / 2, math.sin(a) * r) * K.yaw(math.pi / 2 - a),
        Vector3.new(arc * 1.12, y1 - y0, 2.4), mat, color, { name = "Stave" })
    end
    if cut then
      seg(0, cut.sill or 0)
      seg((cut.sill or 0) + cut.top, h)
    else
      seg(0, h)
    end
  end
  return g
end

-- ============================================== 1. เรือนกลม — the roundhouse
K.build("House_Roundhouse", nil, function(m)
  local R, H = 27, ST * 2
  plinth(m, R * 2.6, R * 2.6, 2)
  local wood = rgb(116, 80, 48)

  K.floorSlab(m, CFrame.new(0, 0, 0), R * 2, R * 2, MAT.WoodPlanks, C.plankDark)
  drum(m, CFrame.new(0, 0, 0), R, H, MAT.Wood, wood, {
    { a = -math.pi / 2, span = 0.56, sill = 0, top = DOOR_H + 1 },
    { a = math.rad(25), span = 0.38, sill = SILL, top = WIN_H },
    { a = math.rad(150), span = 0.38, sill = SILL, top = WIN_H },
    { a = math.rad(255), span = 0.38, sill = SILL, top = WIN_H },
    { a = math.rad(40), span = 0.38, sill = SILL + ST, top = WIN_H },
    { a = math.rad(200), span = 0.38, sill = SILL + ST, top = WIN_H },
    { a = math.rad(300), span = 0.38, sill = SILL + ST, top = WIN_H },
  })
  for _, y in ipairs({ 4, ST - 1, H - 3 }) do K.band(m, CFrame.new(0, y, 0), R * 1.04, 1.6, C.brassDark) end

  -- nearer the middle and shorter: out at half the radius the head of the flight, and its whole
  -- outer edge, stood outside the drum wall
  local hole = flight(m, R * 0.3, 0, -6, 11, ST, MAT.WoodPlanks, C.plankDark, { railColor = C.wood, run = 22 })
  K.floorSlab(m, CFrame.new(0, ST, 0), R * 1.9, R * 1.9, MAT.WoodPlanks, C.plank, { name = "UpperFloor", hole = hole })
  K.railing(m, CFrame.new(hole.x, ST, hole.z + hole.d / 2 - 0.5), hole.w, 5, C.wood)
  K.roofCone(m, CFrame.new(0, H, 0), R * 1.14, 20, MAT.Grass, C.moss, 16)
  K.roofCone(m, CFrame.new(0, H + 20, 0), R * 0.18, 5, MAT.Metal, C.brassDark, 3)

  -- annex drum, shorter, grafted on one side
  local ax, az = R * 1.06, R * 0.72
  drum(m, CFrame.new(ax, 0, az), 14, ST + 6, MAT.Wood, rgb(128, 92, 56), {
    { a = math.rad(205), span = 0.72, sill = 0, top = DOOR_H },   -- open passage through to the main room
    { a = math.rad(270), span = 0.52, sill = 0, top = DOOR_H },   -- the annex has its own front door
    { a = math.rad(20), span = 0.44, sill = SILL, top = WIN_H },
  }, 24)
  K.floorSlab(m, CFrame.new(ax, 0, az), 26, 26, MAT.WoodPlanks, C.plankDark, { name = "AnnexFloor" })
  K.roofCone(m, CFrame.new(ax, ST + 6, az), 16.5, 13, MAT.Grass, C.moss:Lerp(C.thatch, 0.3), 11)
  K.band(m, CFrame.new(ax, 4, az), 14.5, 1.4, C.brassDark)

  -- covered porch on brass posts joining the two drums
  K.box(m, CFrame.new(R * 0.55, ST - 2, -R * 0.42), Vector3.new(26, 1.2, 22), MAT.WoodPlanks, C.plankDark, { name = "PorchRoof" })
  for _, px in ipairs({ R * 0.02, R * 1.08 }) do
    K.cyl(m, CFrame.new(px, (ST - 2) / 2, -R * 0.86), 1.1, ST - 2, MAT.Metal, C.brass, { name = "PorchPost" })
    K.gear(m, CFrame.new(px, ST - 6, -R * 0.86) * K.yaw(math.pi / 2), 2.2, 10, 0.6, C.brassDark)
  end
  K.plankFloor(m, CFrame.new(R * 0.55, 0.3, -R * 0.42), 26, 22, 3, C.plankDark)

  K.autoDoor(m, CFrame.new(0, 0, -R - 1.4), DOOR_W, DOOR_H + 1, { color = C.wood })
  K.autoDoor(m, CFrame.new(ax, 0, az - 15.4), DOOR_W - 2, DOOR_H, { color = C.wood, single = true })   -- on the annex front, not across the stairs

  -- interiors
  K.fireplace(m, CFrame.new(-R * 0.5, 0, R * 0.58) * K.yaw(math.rad(200)), 18, 18, C.darkStone)
  K.table(m, CFrame.new(-5, 0, 4), 16, 9, 5.2, C.plank)
  K.chair(m, CFrame.new(-14, 0, 4) * K.yaw(math.pi / 2))
  K.chair(m, CFrame.new(4, 0, 4) * K.yaw(-math.pi / 2))
  K.chair(m, CFrame.new(-5, 0, -3) * K.yaw(math.pi))
  K.counter(m, CFrame.new(-R * 0.64, 0, -8) * K.yaw(math.pi / 2), 22, 5, 6.4, C.plankDark)
  K.shelf(m, CFrame.new(-R * 0.68, 0, 8) * K.yaw(math.pi / 2), 18, 15, 4, C.plankDark, 4)   -- was standing in the stairwell
  K.rug(m, CFrame.new(-5, 0.1, 4), 26, 18, rgb(132, 62, 58))
  K.barrel(m, CFrame.new(ax - 6, 0, az + 6), 2.6, 6)
  K.crate(m, CFrame.new(ax + 5, 0, az - 4), 6)
  K.table(m, CFrame.new(ax, 0, az), 12, 8, 5, C.oak)
  ceilingLamps(m, CFrame.new(0, ST - 1, 0), { -14, -2 }, { -6, 8 }, 4)   -- kept clear of the stairwell at x 8..19
  K.bed(m, CFrame.new(-11, ST, -12) * K.yaw(math.pi), 8, 15, C.wood)
  K.bed(m, CFrame.new(-11, ST, 8) * K.yaw(math.pi), 8, 15, C.oak)
  K.chest(m, CFrame.new(6, ST, -14), 3)
  K.shelf(m, CFrame.new(14, ST, -4) * K.yaw(-math.pi / 2), 14, 12, 3.4, C.plankDark, 4)
  ceilingLamps(m, CFrame.new(0, H - 2, 0), { -8, 8 }, { 0 }, 4)

  K.gear(m, CFrame.new(-R * 0.6, H + 7, R * 0.5) * K.yaw(math.rad(220)), 6, 14, 1.6, rgb(205, 140, 45))
  local vent = K.cyl(m, CFrame.new(R * 0.35, H + 12, R * 0.35), 2.2, 14, MAT.Metal, rgb(205, 140, 45), { name = "SteamVent" })
  K.cyl(m, CFrame.new(R * 0.35, H + 19.5, R * 0.35), 3, 1.4, MAT.Metal, C.brassDark, { name = "VentCap" })
  steamJet(vent, 12)
  K.pipe(m, { Vector3.new(R * 0.35, H + 5, R * 0.35), Vector3.new(R * 0.92, H * 0.6, R * 0.56), Vector3.new(R * 0.96, 2, R * 0.6) }, 1.1, C.copper)
  K.lampPost(m, CFrame.new(-R * 0.8, 0, -R * 0.95), 17, rgb(255, 200, 140))
end)

-- ============================================= 2. เรือนแถวสูง — the townhouse
K.build("House_Townhouse", nil, function(m)
  local W, D = 36, 30
  plinth(m, W + 22, D + 16, 2)

  K.floorSlab(m, CFrame.new(0, 0, 0), W, D, MAT.WoodPlanks, C.plankDark, { name = "ShopFloor" })
  walls4(m, CFrame.new(0, 0, 0), W, D, ST, 2.2, MAT.Brick, C.brick,
    { { x = -7, w = 14, h = 19 }, { x = 10, w = 11, h = 12, sill = 6 } },
    { { x = 4, w = DOOR_W, h = DOOR_H } }, { win(-5) }, { win(5) }, "G")
  -- a shorter run: at 27 the head of the flight reached the back wall, the first-floor wall above it
  -- and the fireplace on that floor, all within a stud of each other
  local hole1 = flight(m, W / 2 - 10, 0, -D / 2 + 3, 10, ST, MAT.WoodPlanks, C.plankDark, { railColor = C.wood, run = 22 })

  local W2, D2 = W + 6, D + 6
  local o1 = CFrame.new(-1.6, ST, -1.6)
  -- the jetty is a floor too, so it carries the same stairwell hole: it used to be a solid slab
  -- under the hole in the deck above it, which is what the flight actually hit
  K.floorSlab(m, CFrame.new(-1.6, ST, -1.6), W2 + 2, D2 + 2, MAT.Wood, C.wood,
    { name = "Jetty1", hole = { x = hole1.x + 1.6, z = hole1.z + 1.6, w = hole1.w, d = hole1.d } })
  for _, s in ipairs({ -1, 1 }) do
    K.wedge(m, CFrame.new(s * (W / 2 - 2), ST - 3.4, -D / 2 - 3) * K.yaw(math.pi), Vector3.new(4, 4, 5), MAT.Wood, C.wood)
  end
  K.floorSlab(m, o1, W2, D2, MAT.WoodPlanks, C.plank,
    { name = "Floor1", hole = { x = hole1.x + 1.6, z = hole1.z + 1.6, w = hole1.w, d = hole1.d } })
  K.railing(m, o1 * CFrame.new(hole1.x + 1.6, 0, hole1.z + 1.6 + hole1.d / 2 - 0.5), hole1.w, 5, C.wood)
  walls4(m, o1, W2, D2, ST, 2, MAT.Plaster, C.plaster,
    { win(-12), win(0), win(12) }, { { x = 0, w = DOOR_W, h = DOOR_H } }, { win(-4) }, {}, "F1")
  K.timberWall(m, o1 * CFrame.new(0, 0, -D2 / 2 - 1.1), W2, ST, 0.5, C.plaster, C.wood)
  K.timberWall(m, o1 * CFrame.new(-W2 / 2 - 1.1, 0, 0) * K.yaw(-math.pi / 2), D2, ST, 0.5, C.plaster, C.wood)

  -- the rise is ST: the second floor is a full storey up, and at ST - 4 the flight stopped four
  -- studs under it with nothing to climb
  local hole2 = flight(m, -W / 2 + 10, ST, -D / 2 + 3, 10, ST, MAT.WoodPlanks, C.plankDark, { railColor = C.wood, run = 24 })
  local W3, D3 = W2 + 5, D2
  local o2 = CFrame.new(1.2, ST * 2, -3.2)
  K.floorSlab(m, o2, W3 + 2, D3 + 2, MAT.Wood, C.wood,
    { name = "Jetty2", hole = { x = hole2.x - 1.2, z = hole2.z + 3.2, w = hole2.w, d = hole2.d } })
  K.floorSlab(m, o2, W3, D3, MAT.WoodPlanks, C.plank,
    { name = "Floor2", hole = { x = hole2.x - 1.2, z = hole2.z + 3.2, w = hole2.w, d = hole2.d } })
  walls4(m, o2, W3, D3, ST - 4, 2, MAT.Plaster, C.plaster,
    { win(-14, 6), win(0, 6), win(14, 6) }, { win(0, 6) }, { win(0, 6) }, {}, "F2")
  K.timberWall(m, o2 * CFrame.new(0, 0, -D3 / 2 - 1.1), W3, ST - 4, 0.5, C.plaster, C.wood)
  K.roofGable(m, o2 * CFrame.new(0, ST - 4, 0), W3, D3, 18, MAT.RoofShingles, rgb(96, 70, 62), 4)
  K.dormer(m, o2 * CFrame.new(-9, ST - 1, -D3 / 2 + 6), 12, 9, 11, MAT.Plaster, C.plaster, MAT.RoofShingles, rgb(96, 70, 62))

  local chim = K.box(m, CFrame.new(W3 / 2 + 3, ST * 1.7, 6) * K.roll(math.rad(-4)), Vector3.new(8, ST * 3.4, 8), MAT.Brick, C.brick:Lerp(C.black, 0.2), { name = "Chimney" })
  K.box(m, CFrame.new(W3 / 2 + 1.6, ST * 3.4 + 2, 6), Vector3.new(10, 2, 10), MAT.Brick, C.darkStone, { name = "ChimneyCap" })
  smoke(chim, rgb(110, 108, 104), 6)

  K.stairFlight(m, CFrame.new(-W / 2 - 9, 0, D / 2 + 4) * K.yaw(math.pi), 10, ST, MAT.Cobblestone, C.stone, { railColor = C.iron })
  K.autoDoor(m, o1 * CFrame.new(0, 0, D2 / 2 + 1.2) * K.yaw(math.pi), DOOR_W, DOOR_H, { color = C.wood })

  K.box(m, CFrame.new(-7, ST - 3, -D / 2 - 7), Vector3.new(20, 1, 14), MAT.Fabric, rgb(150, 76, 58), { name = "Awning" })
  for _, x in ipairs({ -16, 2 }) do K.cyl(m, CFrame.new(x, (ST - 3) / 2, -D / 2 - 13), 0.7, ST - 3, MAT.Metal, C.iron, { name = "AwningPost" }) end
  K.counter(m, CFrame.new(-7, 0, -D / 2 + 6), 20, 5, 6.4, C.plankDark)
  K.shelf(m, CFrame.new(-W / 2 + 3, 0, 5) * K.yaw(-math.pi / 2), 22, 16, 4, C.plankDark, 4)
  K.crate(m, CFrame.new(11, 0, -2), 6)
  K.barrel(m, CFrame.new(15, 0, 6), 2.8, 6.4)
  local arm = K.box(m, CFrame.new(-W / 2 + 1, ST - 2, -D / 2 - 4), Vector3.new(1, 1, 10), MAT.Metal, C.iron, { name = "SignArm" })
  K.chain(m, arm.CFrame.Position + Vector3.new(0, 0, -4.4), arm.CFrame.Position + Vector3.new(0, -4, -4.4), 4, 0.24)
  K.sign(m, CFrame.new(-W / 2 + 1, ST - 11, -D / 2 - 8.4), "ร้านค้า", 13, 5.6, rgb(58, 40, 30), rgb(240, 206, 140))
  ceilingLamps(m, CFrame.new(0, ST - 1, 0), { -8, 8 }, { 0 }, 4)

  K.table(m, o1 * CFrame.new(-5, 0, 4), 16, 9, 5.2, C.plank)
  K.chair(m, o1 * CFrame.new(-13, 0, 4) * K.yaw(math.pi / 2))
  K.chair(m, o1 * CFrame.new(3, 0, 4) * K.yaw(-math.pi / 2))
  K.fireplace(m, o1 * CFrame.new(12, 0, D2 / 2 - 3) * K.yaw(math.pi), 16, 16, C.brick:Lerp(C.black, 0.25))
  K.rug(m, o1 * CFrame.new(-5, 0.1, 4), 24, 18, rgb(74, 68, 110))
  K.shelf(m, o1 * CFrame.new(-W2 / 2 + 3, 0, -6) * K.yaw(-math.pi / 2), 16, 14, 4, C.plankDark, 4)
  ceilingLamps(m, o1 * CFrame.new(0, ST - 1, 0), { -8, 8 }, { 0 }, 4)

  K.bed(m, o2 * CFrame.new(-12, 0, 6) * K.yaw(math.pi / 2), 8, 15, C.wood)
  K.bed(m, o2 * CFrame.new(12, 0, 6) * K.yaw(-math.pi / 2), 7, 14, C.oak)
  K.chest(m, o2 * CFrame.new(0, 0, -6), 3)
  K.table(m, o2 * CFrame.new(0, 0, 4), 7, 7, 4.6, C.plank)
  ceilingLamps(m, o2 * CFrame.new(0, ST - 5, 0), { 0 }, { 0 }, 3.6)
end)

-- ============================================== 3. เรือนยาว — the longhouse
K.build("House_Longhouse", nil, function(m)
  local W, D, H = 78, 38, 30
  plinth(m, W + 60, D + 60, 2)

  K.floorSlab(m, CFrame.new(0, 0, 0), W, D, MAT.Slate, C.stone, { name = "HallFloor" })
  K.wallRun(m, CFrame.new(0, 0, -D / 2), W, 10, 3, MAT.Cobblestone, C.stone,
    { { x = -14, w = DOOR_W + 2, h = DOOR_H }, win(12), win(30), win(-32) }, { name = "FrontBase" })
  K.wallRun(m, CFrame.new(0, 10, -D / 2), W, H - 10, 2.6, MAT.Wood, rgb(104, 74, 50),
    { { x = -14, w = DOOR_W + 2, h = 8 }, { x = 12, w = WIN_W, h = 8 }, { x = 30, w = WIN_W, h = 8 }, { x = -32, w = WIN_W, h = 8 } }, { name = "FrontUpper" })
  K.wallRun(m, CFrame.new(0, 0, D / 2) * K.yaw(math.pi), W, H, 3, MAT.Cobblestone, C.stone,
    { win(-24), win(24) }, { name = "Back" })
  K.wallRun(m, CFrame.new(-W / 2, 0, 0) * K.yaw(-math.pi / 2), D, H, 3, MAT.Cobblestone, C.stone, { win(0, 9) }, { name = "Left" })
  K.wallRun(m, CFrame.new(W / 2, 0, 0) * K.yaw(math.pi / 2), D, H, 3, MAT.Cobblestone, C.stone,
    { { x = -6, w = DOOR_W + 2, h = DOOR_H } }, { name = "Right" })
  K.roofGable(m, CFrame.new(0, H, 0), W, D, 20, MAT.Grass, C.thatch, 4)
  for i = 0, 5 do
    local z = -D / 2 + 4 + i * (D - 8) / 5
    K.box(m, CFrame.new(0, H - 1.4, z), Vector3.new(W - 4, 1.4, 1.6), MAT.Wood, C.wood, { name = "TieBeam", cancollide = false })
    K.rod(m, Vector3.new(-W / 2 + 2, H, z), Vector3.new(0, H + 19, z), 0.7, MAT.Wood, C.wood, { name = "Rafter", cancollide = false })
    K.rod(m, Vector3.new(W / 2 - 2, H, z), Vector3.new(0, H + 19, z), 0.7, MAT.Wood, C.wood, { name = "Rafter", cancollide = false })
  end
  K.autoDoor(m, CFrame.new(-14, 0, -D / 2 - 1.8), DOOR_W + 2, DOOR_H, { color = C.wood })
  K.box(m, CFrame.new(-14, ST, -D / 2 - 7), Vector3.new(20, 1, 14), MAT.Grass, C.thatch, { name = "PorchHood" })
  for _, x in ipairs({ -22, -6 }) do K.cyl(m, CFrame.new(x, ST / 2, -D / 2 - 12.4), 0.9, ST, MAT.Wood, C.wood, { name = "PorchPost" }) end

  -- byre wing at right angles, its own ridge, hay loft over it
  local BW, BD = 38, 32
  local bo = CFrame.new(W / 2 + BW / 2 - 6, 0, D / 2 + BD / 2 - 8)
  K.floorSlab(m, bo, BW, BD, MAT.Ground, C.soil, { name = "ByreFloor" })
  walls4(m, bo, BW, BD, ST, 2.6, MAT.WoodPlanks, rgb(112, 82, 56),
    { { x = 0, w = 18, h = 20 } }, { win(0, 8) }, {}, { win(0, 8) }, "Byre")
  local bhole = flight(m, bo.X + 13, 0, bo.Z - BD / 2 + 5, 10, ST, MAT.WoodPlanks, C.plankDark, { railColor = C.wood, run = 22 })   -- one tread short of the byre back wall at 27
  K.floorSlab(m, bo * CFrame.new(0, ST, 3), BW - 3, BD - 12, MAT.WoodPlanks, C.plank,
    { name = "HayLoft", hole = { x = bhole.x - bo.X, z = bhole.z - bo.Z - 3, w = bhole.w, d = bhole.d } })
  K.roofGable(m, bo * CFrame.new(0, ST + 8, 0), BW, BD, 14, MAT.Grass, C.thatch:Lerp(C.black, 0.15), 3)
  K.wallRun(m, bo * CFrame.new(0, ST, -BD / 2), BW, 8, 2.2, MAT.WoodPlanks, rgb(112, 82, 56), { { x = 0, w = 10, h = 8 } }, { name = "LoftGable" })
  K.box(m, bo * CFrame.new(0, ST + 9, -BD / 2 - 6), Vector3.new(1.2, 1.2, 12), MAT.Wood, C.wood, { name = "HoistBeam" })
  K.chain(m, (bo * CFrame.new(0, ST + 8.4, -BD / 2 - 10)).Position, (bo * CFrame.new(0, ST - 4, -BD / 2 - 10)).Position, 10, 0.26)
  K.box(m, bo * CFrame.new(0, ST - 7, -BD / 2 - 10), Vector3.new(6, 5, 6), MAT.Fabric, C.thatch, { name = "HayBale" })
  for _, s in ipairs({ -1, 1 }) do
    K.box(m, bo * CFrame.new(s * 4.6, 10, -BD / 2 - 0.4) * K.yaw(s < 0 and math.rad(-34) or 0), Vector3.new(9, 20, 1), MAT.WoodPlanks, C.plankDark, { name = "ByreDoor" })
  end
  for i = 0, 2 do K.box(m, bo * CFrame.new(-BW / 2 + 8 + i * 10, 5, 6), Vector3.new(0.8, 10, 16), MAT.WoodPlanks, C.plankDark, { name = "StallDivider" }) end
  K.box(m, bo * CFrame.new(0, 2.4, BD / 2 - 6), Vector3.new(BW - 10, 4.8, 4.4), MAT.Wood, C.wood, { name = "Trough" })
  K.box(m, bo * CFrame.new(0, 5, BD / 2 - 6), Vector3.new(BW - 12, 1, 3.4), MAT.Grass, C.thatch, { name = "Feed", cancollide = false })
  -- four bales: the last two were stacked on the head of the loft stair
  for i = 0, 3 do K.box(m, bo * CFrame.new(-12 + i * 5, ST + 2.4, 4) * K.yaw(i * 0.3), Vector3.new(7, 5, 7), MAT.Fabric, C.thatch, { name = "LoftHay" }) end
  ceilingLamps(m, bo * CFrame.new(0, ST - 1, -8), { -8, 8 }, { 0 }, 4)

  -- hall interior: central hearth, long table, sleeping alcoves along the back
  K.fireplace(m, CFrame.new(0, 0, D / 2 - 3.4) * K.yaw(math.pi), 20, 18, C.darkStone)
  local chim = K.box(m, CFrame.new(0, H + 16, D / 2 + 1), Vector3.new(9, 30, 7), MAT.Cobblestone, C.darkStone, { name = "Chimney" })
  smoke(chim, rgb(112, 110, 106), 7)
  K.table(m, CFrame.new(-8, 0, 2), 40, 11, 5.2, C.plank)
  for _, z in ipairs({ -6, 10 }) do
    K.box(m, CFrame.new(-8, 2.9, z), Vector3.new(38, 0.8, 3.4), MAT.WoodPlanks, C.plankDark, { name = "Bench" })
    K.box(m, CFrame.new(-8, 1.45, z), Vector3.new(37, 2.9, 0.8), MAT.Wood, C.wood, { name = "BenchLeg" })
  end
  for i = 0, 2 do
    local x = -28 + i * 22
    K.box(m, CFrame.new(x, 0, D / 2 - 9), Vector3.new(18, 1, 14), MAT.WoodPlanks, C.plankDark, { name = "AlcoveFloor" })
    K.bed(m, CFrame.new(x, 1, D / 2 - 9) * K.yaw(math.pi), 8, 15, C.wood, C.canvas)
    K.box(m, CFrame.new(x - 9.4, 13, D / 2 - 9), Vector3.new(1, 26, 14), MAT.WoodPlanks, C.plankDark, { name = "AlcovePartition" })
  end
  K.shelf(m, CFrame.new(-W / 2 + 4, 0, -8) * K.yaw(-math.pi / 2), 20, 15, 4, C.plankDark, 4)
  K.counter(m, CFrame.new(-W / 2 + 12, 0, D / 2 - 3) * K.yaw(math.pi), 16, 5, 6.4, C.plankDark)
  for i = 0, 2 do K.barrel(m, CFrame.new(W / 2 - 8 - i * 6, 0, -10), 2.8, 6.4, i % 2 == 0 and C.wood or C.oak) end
  K.crate(m, CFrame.new(W / 2 - 10, 0, 8), 6)
  K.rug(m, CFrame.new(-8, 0.1, 2), 46, 22, rgb(120, 92, 62))
  ceilingLamps(m, CFrame.new(0, H - 2, 0), { -26, -8, 10, 28 }, { -4 }, 4)
  K.lampPost(m, CFrame.new(-W / 2 - 10, 0, -D / 2 - 12), 17, rgb(255, 206, 150))
end)

-- ========================================== 4. เรือนช่างท่อ — the pipe-worker's
K.build("House_PipeWorker", nil, function(m)
  local W, D, LIFT = 42, 34, 20
  plinth(m, W + 30, D + 30, 2, MAT.Concrete, C.darkStone)

  for _, sx in ipairs({ -1, 1 }) do
    for _, sz in ipairs({ -1, 1 }) do
      local x, z = sx * (W / 2 - 3), sz * (D / 2 - 3)
      K.rod(m, Vector3.new(x * 1.4, 0, z * 1.4), Vector3.new(x, LIFT, z), 1.5, MAT.Metal, C.iron, { name = "Leg" })
      K.box(m, CFrame.new(x * 1.4, 1, z * 1.4), Vector3.new(5, 2, 5), MAT.Metal, C.brassDark, { name = "Footplate" })
    end
    K.rod(m, Vector3.new(sx * (W / 2 - 3) * 1.4, 1, -(D / 2 - 3) * 1.4), Vector3.new(sx * (W / 2 - 3), LIFT - 1, (D / 2 - 3)), 0.6, MAT.Metal, C.steel, { name = "Brace" })
    K.rod(m, Vector3.new(sx * (W / 2 - 3) * 1.4, 1, (D / 2 - 3) * 1.4), Vector3.new(sx * (W / 2 - 3), LIFT - 1, -(D / 2 - 3)), 0.6, MAT.Metal, C.steel, { name = "Brace" })
  end

  local o = CFrame.new(0, LIFT, 0)
  K.box(m, o * CFrame.new(0, -1.6, 0), Vector3.new(W + 3, 2.4, D + 3), MAT.Metal, C.iron, { name = "Underframe" })
  K.floorSlab(m, o, W, D, MAT.DiamondPlate, C.steel, { name = "Deck" })
  local copper = rgb(168, 104, 62)
  walls4(m, o, W, D, ST, 2, MAT.Metal, copper,
    { { x = -10, w = DOOR_W, h = DOOR_H }, { x = 10, w = 13, h = 12, sill = 6 } },
    { win(-8) }, { win(6) }, {}, "Box")
  for _, y in ipairs({ 1.6, ST - 1.6 }) do
    K.rivets(m, (o * CFrame.new(-W / 2, y, -D / 2 - 1.2)).Position, (o * CFrame.new(W / 2, y, -D / 2 - 1.2)).Position, 12, 0.36, C.brassDark)
    K.rivets(m, (o * CFrame.new(-W / 2, y, D / 2 + 1.2)).Position, (o * CFrame.new(W / 2, y, D / 2 + 1.2)).Position, 12, 0.36, C.brassDark)
    K.rivets(m, (o * CFrame.new(-W / 2 - 1.2, y, -D / 2)).Position, (o * CFrame.new(-W / 2 - 1.2, y, D / 2)).Position, 10, 0.36, C.brassDark)
    K.rivets(m, (o * CFrame.new(W / 2 + 1.2, y, -D / 2)).Position, (o * CFrame.new(W / 2 + 1.2, y, D / 2)).Position, 10, 0.36, C.brassDark)
  end
  for _, sx in ipairs({ -1, 1 }) do
    for _, sz in ipairs({ -1, 1 }) do
      K.box(m, o * CFrame.new(sx * (W / 2 + 0.5), ST / 2, sz * (D / 2 + 0.5)), Vector3.new(2.6, ST, 2.6), MAT.Metal, C.brassDark, { name = "CornerStrap" })
    end
  end
  K.autoDoor(m, o * CFrame.new(-10, 0, -D / 2 - 1.4), DOOR_W, DOOR_H, { color = copper, mat = MAT.Metal })

  local bay = CFrame.new(W / 2 + 5, LIFT + 3, -D / 2 + 9)
  K.box(m, bay * CFrame.new(0, -1, 0), Vector3.new(13, 2, 17), MAT.Metal, C.iron, { name = "BayFloor" })
  K.box(m, bay * CFrame.new(0, 10, 0), Vector3.new(13.6, 1.6, 17.6), MAT.Metal, C.brassDark, { name = "BayRoof" })
  for _, sz in ipairs({ -1, 0, 1 }) do
    K.box(m, bay * CFrame.new(6, 4.6, sz * 6.4), Vector3.new(0.9, 18, 0.9), MAT.Metal, C.brass, { name = "BayMullion" })
  end
  K.box(m, bay * CFrame.new(6, 4.6, 0), Vector3.new(0.4, 17, 17), MAT.Glass, C.glass, { name = "BayGlass", transparency = 0.42, cancollide = false })
  K.box(m, bay * CFrame.new(0, 4.6, -8.3), Vector3.new(13, 17, 0.4), MAT.Glass, C.glass, { name = "BayGlass", transparency = 0.42, cancollide = false })
  K.rod(m, (bay * CFrame.new(5, -1.4, 0)).Position, (o * CFrame.new(W / 2 - 2, -2, -D / 2 + 9)).Position, 0.6, MAT.Metal, C.steel, { name = "BayStrut" })

  -- Getting onto the catwalk: the landing used to sit across the head of the first flight, and the
  -- second flight climbed straight through the catwalk deck to finish a stud above it. Each flight
  -- now tops out level with what it arrives at, and the catwalk has the hatch it needs.
  K.stairFlight(m, CFrame.new(-W / 2 - 11, 0, D / 2 + 6) * K.yaw(math.pi), 10, 12, MAT.Metal, C.steel, { railColor = C.iron })
  K.box(m, CFrame.new(-W / 2 - 11, 11.4, D / 2 - 12.1), Vector3.new(11, 1.2, 11), MAT.DiamondPlate, C.steel, { name = "Landing" })
  K.stairFlight(m, CFrame.new(-W / 2 - 11, 12, D / 2 - 14) * K.yaw(math.pi / 2), 10, LIFT - 12, MAT.Metal, C.steel, { railColor = C.iron })
  K.railing(m, CFrame.new(-W / 2 - 16.5, 11.4, D / 2 - 12.1) * K.yaw(math.pi / 2), 11, 5, C.iron, MAT.Metal)
  K.floorSlab(m, CFrame.new(-W / 2 - 5, LIFT, 2), 14, 12, MAT.DiamondPlate, C.steel,
    { name = "Catwalk", hole = { x = -2, z = 1, w = 10, d = 6 } })
  K.railing(m, CFrame.new(-W / 2 - 5, LIFT, -4), 14, 5, C.iron, MAT.Metal)

  K.boiler(m, o * CFrame.new(W / 2 + 10, -6, 8), 5, 20, { bands = 3, rivets = 12, firebox = true })
  K.cyl(m, CFrame.new(W / 2 + 10, 3, 8), 5.6, 6, MAT.Cobblestone, C.darkStone, { name = "BoilerBase" })
  K.pipe(m, { (o * CFrame.new(W / 2 + 10, 5, 8)).Position, (o * CFrame.new(W / 2 + 10, 10, 8)).Position, (o * CFrame.new(W / 2 - 2, 10, 8)).Position }, 1.1, C.copper)
  K.valveWheel(m, o * CFrame.new(W / 2 + 16, -2, 8), 2.8, 5)
  K.gauge(m, o * CFrame.new(W / 2 + 10, 1, 2.6) * K.yaw(math.pi / 2), 2.4)
  K.smokestack(m, o * CFrame.new(W / 2 + 10, 5, 8), 2, 18, { smoke = true })

  K.box(m, o * CFrame.new(0, ST, 0), Vector3.new(W + 2.4, 1.6, D + 2.4), MAT.DiamondPlate, C.steel, { name = "RoofDeck" })
  K.railing(m, o * CFrame.new(0, ST + 0.8, -D / 2 - 0.8), W, 5, C.iron, MAT.Metal)
  K.railing(m, o * CFrame.new(0, ST + 0.8, D / 2 + 0.8), W, 5, C.iron, MAT.Metal)
  local tank = K.cyl(m, o * CFrame.new(-11, ST + 8, 7), 7, 13, MAT.Metal, C.rust, { name = "WaterTank" })
  for i = 1, 2 do K.band(m, o * CFrame.new(-11, ST + 4 + i * 5, 7), 7.3, 1, C.brassDark) end
  K.rivetRing(m, o * CFrame.new(-11, ST + 6, 7) * K.pitch(math.pi / 2), 7.2, 14, 0.4)
  K.cyl(m, o * CFrame.new(13, ST + 7, -5), 0.5, 14, MAT.Metal, C.iron, { name = "VanePole" })
  K.propeller(m, o * CFrame.new(13, ST + 14, -5) * K.yaw(math.pi / 2), 5, 4, C.brass)

  K.counter(m, o * CFrame.new(-6, 0, D / 2 - 4) * K.yaw(math.pi), 26, 5, 6.4, C.plankDark)
  K.shelf(m, o * CFrame.new(-W / 2 + 3, 0, -4) * K.yaw(-math.pi / 2), 20, 15, 4, C.plankDark, 4)
  K.bed(m, o * CFrame.new(W / 2 - 7, 0, -D / 2 + 10) * K.yaw(-math.pi / 2), 8, 15, C.iron, C.canvas)
  local stove = K.cyl(m, o * CFrame.new(11, 0, D / 2 - 6), 3.4, 9, MAT.Metal, C.coal, { name = "Stove" })
  local sfire = K.box(m, o * CFrame.new(11, 3, D / 2 - 9.6), Vector3.new(3.4, 2.6, 0.5), MAT.Neon, C.ember, { name = "StoveFire", cancollide = false })
  glow(sfire, C.ember, 30, 2)
  K.pipe(m, { (o * CFrame.new(11, 9, D / 2 - 6)).Position, (o * CFrame.new(11, ST + 6, D / 2 - 6)).Position }, 0.9, C.iron)
  K.table(m, o * CFrame.new(3, 0, -3), 13, 9, 5.2, C.plank)
  K.chair(m, o * CFrame.new(3, 0, 5) * K.yaw(math.pi))
  K.chest(m, o * CFrame.new(-16, 0, -D / 2 + 6), 3)
  K.rug(m, o * CFrame.new(3, 0.1, -3), 20, 15, rgb(80, 96, 110))
  ceilingLamps(m, o * CFrame.new(0, ST - 1, 0), { -10, 10 }, { -6, 6 }, 4)
end)

-- ============================================ 5. เรือนหิน — the stone cottage
K.build("House_StoneCottage", nil, function(m)
  local W, D = 50, 40
  plinth(m, W + 46, D + 34, 2)
  local wall = rgb(150, 146, 138)

  K.floorSlab(m, CFrame.new(0, 0, 0), W, D, MAT.Slate, C.stone, { name = "Floor" })
  walls4(m, CFrame.new(0, 0, 0), W, D, ST + 2, 3, MAT.Rock, wall,
    { { x = -9, w = DOOR_W, h = DOOR_H }, { x = 10, w = 13, h = 12, sill = 6 }, win(-22) },
    { win(-14), { x = 11, w = DOOR_W, h = DOOR_H } },
    { win(0) }, { win(-8), win(8) }, "G")
  for _, sx in ipairs({ -1, 1 }) do
    for i = 0, 6 do
      K.box(m, CFrame.new(sx * (W / 2 - 0.6), 2 + i * 4, -D / 2 + 1), Vector3.new(4.4, 3.4, 4.4), MAT.Rock, wall:Lerp(C.white, 0.18), { name = "Quoin", cancollide = false })
    end
  end
  -- toward the ridge and shorter: against the wall the loft has no headroom at all, and the roof
  -- slope came down onto the last five treads
  local hole = flight(m, 12, 0, -8, 10, ST + 2, MAT.WoodPlanks, C.plankDark, { railColor = C.wood, run = 24 })
  K.floorSlab(m, CFrame.new(0, ST + 2, 4), W - 4, D - 12, MAT.WoodPlanks, C.plank, { name = "Loft", hole = { x = hole.x, z = hole.z - 4, w = hole.w, d = hole.d } })
  K.railing(m, CFrame.new(hole.x, ST + 2, hole.z + hole.d / 2 - 0.5), hole.w, 5, C.wood)
  K.roofGable(m, CFrame.new(0, ST + 2, 0), W, D, 20, MAT.Slate, C.slateRoof, 4)
  K.dormer(m, CFrame.new(-11, ST + 5, -D / 2 + 7), 13, 10, 12, MAT.Rock, wall, MAT.Slate, C.slateRoof)
  K.autoDoor(m, CFrame.new(-9, 0, -D / 2 - 2), DOOR_W, DOOR_H, { color = C.wood })

  local cx = -W / 2 - 4.4
  K.box(m, CFrame.new(cx, 16, 6), Vector3.new(9, 32, 15), MAT.Rock, wall:Lerp(C.black, 0.12), { name = "StackBase" })
  local stack = K.box(m, CFrame.new(cx, 42, 6), Vector3.new(6.4, 22, 9), MAT.Rock, wall:Lerp(C.black, 0.16), { name = "Stack" })
  K.box(m, CFrame.new(cx, 53.4, 6), Vector3.new(8.4, 2, 11), MAT.Rock, C.darkStone, { name = "StackCap" })
  smoke(stack, rgb(116, 114, 110), 7)

  local sx0 = W / 2 + 12
  K.box(m, CFrame.new(sx0, 0.3, 4), Vector3.new(24, 1, 30), MAT.Ground, C.soil, { name = "ShedFloor" })
  for _, z in ipairs({ -9, 4, 17 }) do K.cyl(m, CFrame.new(sx0 + 10, 9, z), 1.1, 18, MAT.Wood, C.wood, { name = "ShedPost" }) end
  K.box(m, CFrame.new(sx0 + 10, 18.4, 4), Vector3.new(2, 1.2, 30), MAT.Wood, C.wood, { name = "ShedPlate" })
  K.wedge(m, CFrame.new(sx0, 19, 4) * K.yaw(-math.pi / 2), Vector3.new(30, 7, 24), MAT.Wood, C.plankDark)
  for i = 0, 29 do
    local row, col = i % 6, math.floor(i / 6)
    K.cylX(m, CFrame.new(sx0 - 6 + col * 2.6, 1.8 + row * 2.4, -6 + (i % 3) * 0.8) * K.yaw(math.pi / 2 + (i % 4) * 0.02),
      1.1, 15 - (i % 3) * 2, MAT.Wood, C.wood:Lerp(C.plank, (i % 5) / 6), { name = "Log", cancollide = false })
  end
  K.cyl(m, CFrame.new(sx0 + 4, 1.8, 14), 3.4, 3.6, MAT.Wood, C.plankDark, { name = "ChoppingBlock" })
  K.box(m, CFrame.new(sx0 + 4, 4.4, 14), Vector3.new(5, 4, 1.6), MAT.Metal, C.iron, { name = "AxeHead", cancollide = false })
  K.cyl(m, CFrame.new(sx0 + 4, 7.4, 14) * K.roll(math.rad(20)), 0.5, 7, MAT.Wood, C.wood, { name = "AxeHaft", cancollide = false })

  K.cyl(m, CFrame.new(-W / 2 - 14, 3, -D / 2 - 10), 6, 6, MAT.Cobblestone, C.stone, { name = "WellRim" })
  K.cyl(m, CFrame.new(-W / 2 - 14, 5.8, -D / 2 - 10), 4.6, 0.5, MAT.Glass, rgb(70, 120, 160), { name = "WellWater", transparency = 0.35, cancollide = false })
  for _, s in ipairs({ -1, 1 }) do K.box(m, CFrame.new(-W / 2 - 14 + s * 5.4, 11, -D / 2 - 10), Vector3.new(1.2, 16, 1.2), MAT.Wood, C.wood, { name = "WellPost" }) end
  K.cylX(m, CFrame.new(-W / 2 - 14, 17.4, -D / 2 - 10), 0.9, 11, MAT.Wood, C.wood, { name = "Windlass" })
  K.roofGable(m, CFrame.new(-W / 2 - 14, 18.6, -D / 2 - 10), 14, 14, 6, MAT.Grass, C.thatch, 2)
  K.chain(m, Vector3.new(-W / 2 - 14, 17, -D / 2 - 10), Vector3.new(-W / 2 - 14, 8.4, -D / 2 - 10), 8, 0.24)
  K.barrel(m, CFrame.new(-W / 2 - 14, 6.2, -D / 2 - 10), 2.2, 3.6, C.oak)

  for _, x in ipairs({ 10, -22 }) do
    K.box(m, CFrame.new(x, 5.4, -D / 2 - 2.6), Vector3.new(12, 2.4, 3), MAT.WoodPlanks, C.plankDark, { name = "FlowerBox" })
    for j = 0, 4 do
      K.ball(m, CFrame.new(x - 4 + j * 2, 7.6, -D / 2 - 2.6), 2.2, MAT.Grass,
        ({ rgb(198, 82, 92), rgb(230, 190, 90), rgb(150, 110, 200), rgb(198, 82, 92), rgb(120, 190, 110) })[j + 1], { name = "Bloom", cancollide = false })
    end
  end

  K.fireplace(m, CFrame.new(-W / 2 + 4, 0, 6) * K.yaw(-math.pi / 2), 18, 18, C.darkStone)
  -- the room sits west of the stair: the board and its chairs used to stand on the flight
  K.table(m, CFrame.new(-6, 0, 2), 18, 11, 5.2, C.plank)
  K.chair(m, CFrame.new(-16, 0, 2) * K.yaw(math.pi / 2))
  K.chair(m, CFrame.new(4, 0, 2) * K.yaw(-math.pi / 2))
  K.chair(m, CFrame.new(-6, 0, -7) * K.yaw(math.pi))
  K.shelf(m, CFrame.new(-6, 0, D / 2 - 2.4) * K.yaw(math.pi), 22, 16, 4, C.plankDark, 4)
  K.counter(m, CFrame.new(-16, 0, D / 2 - 3) * K.yaw(math.pi), 18, 5, 6.4, C.plankDark)
  K.rug(m, CFrame.new(-6, 0.1, 2), 26, 20, rgb(120, 70, 66))
  K.barrel(m, CFrame.new(W / 2 - 6, 0, 14), 2.6, 6)
  ceilingLamps(m, CFrame.new(0, ST + 1, 0), { -10, 10 }, { -4, 8 }, 4)
  K.bed(m, CFrame.new(-8, ST + 2, 8) * K.yaw(math.pi / 2), 8, 15, C.wood)
  K.bed(m, CFrame.new(-8, ST + 2, -4) * K.yaw(math.pi / 2), 7, 14, C.oak)
  K.chest(m, CFrame.new(-16, ST + 2, 12), 3)   -- off the head of the loft stair
  ceilingLamps(m, CFrame.new(0, ST + 16, 4), { -6 }, { 0 }, 3.6)
  K.lampPost(m, CFrame.new(-W / 2 - 4, 0, -D / 2 - 14), 17, rgb(255, 204, 148))
end)
