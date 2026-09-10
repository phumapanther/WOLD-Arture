-- castle — the two big pieces the curtain wall encloses: the keep and the great hall.
--
-- both are at character scale: storey height 26, doorways 12 x 18, every floor reachable by a
-- stair through a cut stairwell. massing is asymmetric on purpose — an L plan, a forebuilding
-- carrying the entry stair up to the first floor the way a real keep does, three corner turrets
-- rather than four, a chapel apse on one flank only, a kitchen wing with its own ridge.
K.SET = "castle"
K.SLOT = 260
K.PER_ROW = 2
K.ORIGIN = Vector3.new(0, 0, 1800)

local C = K.C
local MAT = K.MAT
local rgb = Color3.fromRGB
local ST = 26
local DOOR_W, DOOR_H = 12, 18
local WIN_W, WIN_H, SILL = 9, 12, 8

local STONE = rgb(154, 150, 142)
local STONE_DARK = rgb(112, 108, 102)
local BRASS = rgb(205, 140, 45)

local function glow(part, color, range, brightness)
  local l = Instance.new("PointLight")
  l.Color = color or C.lamp; l.Range = range or 26; l.Brightness = brightness or 1.5; l.Parent = part
  return l
end
local function smoke(part, color, size)
  local s = Instance.new("Smoke")
  s.Size = size or 7; s.RiseVelocity = 9; s.Opacity = 0.22; s.Color = color or rgb(104, 102, 98); s.Parent = part
  return s
end
local function steamJet(part, rate)
  local e = Instance.new("ParticleEmitter")
  e.Name = "SteamJet"
  e.Color = ColorSequence.new(rgb(226, 234, 242))
  e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 7) })
  e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
  e.Lifetime = NumberRange.new(2.4, 4.4); e.Rate = rate or 16
  e.Speed = NumberRange.new(6, 12); e.SpreadAngle = Vector2.new(16, 16)
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
local function coursedFace(m, cf, w, h, thick, seed, base)
  local rng = Random.new(seed)
  local g = K.model(m, "Face")
  local y = 0
  while y < h - 0.1 do
    local course = math.min(3.2 + rng:NextNumber() * 1.8, h - y)
    local x = -w / 2
    while x < w / 2 - 0.1 do
      local bw = math.min(6 + rng:NextNumber() * 8, w / 2 - x)
      K.box(g, cf * CFrame.new(x + bw / 2, y + course / 2, 0), Vector3.new(bw * 0.985, course * 0.97, thick), MAT.Rock,
        base:Lerp(rng:NextNumber() > 0.5 and C.white or C.black, rng:NextNumber() * 0.12), { name = "Stone", cancollide = false })
      x += bw
    end
    y += course
  end
  return g
end
local function ceilingLamps(m, cf, xs, zs, size, color)
  for _, x in ipairs(xs) do
    for _, z in ipairs(zs) do
      K.chain(m, (cf * CFrame.new(x, 0, z)).Position, (cf * CFrame.new(x, -5, z)).Position, 4, 0.24)
      K.lantern(m, cf * CFrame.new(x, -10, z), size or 5, color)
    end
  end
end
-- a candle-ring chandelier, for rooms too big for a single lantern
local function chandelier(m, cf, r, candles, color)
  local g = K.model(m, "Chandelier")
  K.chain(g, (cf * CFrame.new(0, 10, 0)).Position, (cf * CFrame.new(0, 0, 0)).Position, 6, 0.3)
  for i = 0, 23 do
    local a0, a1 = i * math.pi / 12, (i + 1) * math.pi / 12
    K.rod(g, (cf * CFrame.new(math.cos(a0) * r, 0, math.sin(a0) * r)).Position,
             (cf * CFrame.new(math.cos(a1) * r, 0, math.sin(a1) * r)).Position, 0.5, MAT.Metal, C.brassDark, { name = "Hoop", cancollide = false })
  end
  for i = 0, (candles or 10) - 1 do
    local a = i * 2 * math.pi / (candles or 10)
    local p = cf * CFrame.new(math.cos(a) * r, 1.6, math.sin(a) * r)
    K.cyl(g, p, 0.5, 3.2, MAT.SmoothPlastic, C.canvas, { name = "Candle", cancollide = false })
    local f = K.ball(g, p * CFrame.new(0, 2.2, 0), 1.4, MAT.Neon, color or C.lamp, { name = "Flame", cancollide = false })
    if i % 3 == 0 then glow(f, color or C.lamp, 30, 1.2) end
  end
  return g
end

-- ================================================================ 1. the keep
-- L plan: a main block with a forebuilding on the front carrying the entry stair to the first
-- floor, a kitchen wing off the back, a chapel apse on the east flank, and three turrets.
local function keep(m)
  local W, D = 96, 74
  local FLOORS = 4
  local H = FLOORS * ST

  K.box(m, CFrame.new(0, -2, 0), Vector3.new(W + 26, 4, D + 26), MAT.Cobblestone, C.darkStone, { name = "Plinth" })
  -- battered plinth, then the shell
  K.box(m, CFrame.new(0, 5, 0), Vector3.new(W + 8, 10, D + 8), MAT.Rock, STONE_DARK, { name = "Batter" })
  for _, e in ipairs({ { 0, -(D + 8) / 2 - 1.6, 0, W + 8 }, { 0, (D + 8) / 2 + 1.6, math.pi, W + 8 },
                       { -(W + 8) / 2 - 1.6, 0, -math.pi / 2, D + 8 }, { (W + 8) / 2 + 1.6, 0, math.pi / 2, D + 8 } }) do
    K.wedge(m, CFrame.new(e[1], 11.6, e[2]) * K.yaw(e[3]) * K.pitch(math.pi) * K.yaw(math.pi), Vector3.new(e[4], 5, 4), MAT.Rock, STONE_DARK)
  end

  K.floorSlab(m, CFrame.new(0, 10, 0), W, D, MAT.Slate, STONE_DARK, { name = "UndercroftFloor" })
  walls4(m, CFrame.new(0, 10, 0), W, D, ST, 5, MAT.Rock, STONE,
    { { x = -18, w = DOOR_W + 4, h = DOOR_H }, win(14, 12), win(34, 12) },
    { { x = 10, w = DOOR_W + 6, h = DOOR_H + 2 }, win(-26, 12) },
    { win(-14, 12), win(14, 12) }, { win(0, 12) }, "Under")
  coursedFace(m, CFrame.new(0, 10, -D / 2 - 2.8), W, ST, 1.6, 11, STONE)

  -- forebuilding: the grand stair up the outside to the first floor, as a real keep has
  local fo = CFrame.new(-W / 2 + 22, 0, -D / 2 - 20)
  K.box(m, fo * CFrame.new(0, 5, 0), Vector3.new(40, 10, 40), MAT.Rock, STONE_DARK, { name = "ForeBatter" })
  walls4(m, fo * CFrame.new(0, 10, 0), 36, 36, ST + 8, 4, MAT.Rock, STONE:Lerp(C.white, 0.04),
    -- the back wall carries the high doorway the stair arrives at: without it the grand stair
    -- climbed a whole storey and finished against the inside of the forebuilding's own wall
    { { x = 0, w = 16, h = 22 } }, { { x = 0, w = DOOR_W + 4, h = DOOR_H, sill = ST } },
    { win(0, 12) }, { win(0, 12) }, "Fore")
  K.archOpening(m, fo * CFrame.new(0, 10, -18.4), 16, 22, 3.4, MAT.Rock, STONE:Lerp(C.white, 0.12))
  K.floorSlab(m, fo * CFrame.new(0, 10, 0), 34, 34, MAT.Slate, C.stone, { name = "ForeFloor" })
  K.stairFlight(m, fo * CFrame.new(0, 10, -13), 14, ST, MAT.Rock, STONE_DARK, { railColor = C.iron, run = 28 })
  K.roofBattlement(m, fo * CFrame.new(0, ST + 20, 0), 36, 36, { color = STONE_DARK, merlon = 8, step = 9, overhang = 3.4 })
  K.machicolation(m, fo * CFrame.new(0, ST + 13, -18), 40, { color = STONE, projection = 4.6, height = 6 })
  K.banner(m, fo * CFrame.new(-13, ST + 22, -14), 9, 18, rgb(148, 40, 44), 26)

  -- the four storeys above the undercroft
  local holes = {}
  for f = 1, FLOORS do
    local y = 10 + f * ST
    local sx = (f % 2 == 1) and (W / 2 - 16) or (-W / 2 + 16)     -- the stair alternates ends
    -- centred on z rather than set back to -6: at -6 the foot of every flight stood inside a corner
    -- turret, which is a solid stone column from the ground up
    local h = { x = sx, z = 0, w = 15, d = 36 }
    holes[f] = h
    -- floor 1 is solid: the forebuilding stair arrives there from outside. every floor above it
    -- carries the hole for the flight arriving from the floor below, not the one leaving it.
    K.floorSlab(m, CFrame.new(0, y, 0), W, D, MAT.WoodPlanks, C.plankDark,
      { name = "Floor" .. f, hole = f > 1 and holes[f - 1] or nil })
    if f < FLOORS then
      K.stairFlight(m, CFrame.new(h.x, y, h.z - 15), 11, ST, MAT.Rock, STONE_DARK, { railColor = C.iron, run = 28, open = true })
    end
    if f > 1 then
      local hb = holes[f - 1]
      K.railing(m, CFrame.new(hb.x, y, hb.z - hb.d / 2 + 0.4), hb.w, 5, C.iron, MAT.Metal)
    end
    local hh = (f == FLOORS) and ST - 4 or ST
    -- floor 1 takes a doorway where the forebuilding stair arrives; the rest are windows
    local frontWall = f == 1
      and { { x = -26, w = DOOR_W + 4, h = DOOR_H }, win(6), win(30) }
      or { win(-30), win(-8), win(14), win(36) }
    walls4(m, CFrame.new(0, y, 0), W, D, hh, 5, MAT.Rock, STONE,
      frontWall, { win(-24), win(2), win(28) },
      { win(-16), win(12) }, { win(-10), win(16) }, "F" .. f)
    coursedFace(m, CFrame.new(0, y, -D / 2 - 2.8), W, hh, 1.6, 20 + f * 7, STONE)
  end
  -- the bridge from the forebuilding stair head into that doorway: it used to stop five studs
  -- short of the keep wall, at first-floor height, facing blank stone. It starts where the flight
  -- ends -- laid over the treads it swallows them.
  K.box(m, CFrame.new(-26, 10 + ST - 1, -D / 2 - 1), Vector3.new(18, 2, 8), MAT.Slate, STONE_DARK, { name = "ForeBridge" })
  for _, s in ipairs({ -1, 1 }) do
    K.railing(m, CFrame.new(-26 + s * 8.4, 10 + ST, -D / 2 - 1) * K.yaw(math.pi / 2), 8, 5, C.iron, MAT.Metal)
  end

  -- ground floor: the undercroft — stores, well, the boiler house door
  for i = 0, 5 do
    K.box(m, CFrame.new(-W / 2 + 12 + i * 14, 10 + ST / 2, 0), Vector3.new(4.4, ST, D - 10), MAT.Rock, STONE:Lerp(C.black, 0.08), { name = "VaultPier" })
    K.roofBarrel(m, CFrame.new(-W / 2 + 12 + i * 14, 10 + ST - 8, 0), 13, D - 10, 8, MAT.Rock, STONE:Lerp(C.black, 0.12), 7)
  end
  for i = 0, 7 do K.barrel(m, CFrame.new(-W / 2 + 20 + (i % 4) * 9, 10, -18 + math.floor(i / 4) * 30), 3, 7, i % 2 == 0 and C.wood or C.oak) end
  for i = 0, 5 do K.crate(m, CFrame.new(10 + (i % 3) * 9, 10, 20 + math.floor(i / 3) * 9), 6) end
  K.cyl(m, CFrame.new(30, 12, 0), 6, 4, MAT.Cobblestone, C.stone, { name = "WellRim" })
  K.cyl(m, CFrame.new(30, 14.2, 0), 4.6, 0.5, MAT.Glass, rgb(64, 110, 150), { name = "WellWater", transparency = 0.35, cancollide = false })
  ceilingLamps(m, CFrame.new(0, 10 + ST - 2, 0), { -30, 0, 30 }, { -18, 18 }, 4)

  -- first floor: the great hall of the keep, two storeys tall at the east end
  local y1 = 10 + ST
  K.fireplace(m, CFrame.new(-26, y1, D / 2 - 4) * K.yaw(math.pi), 26, 22, C.darkStone)
  K.fireplace(m, CFrame.new(26, y1, D / 2 - 4) * K.yaw(math.pi), 22, 20, C.darkStone)
  K.table(m, CFrame.new(-6, y1, 6), 58, 13, 5.4, C.oak)
  for _, z in ipairs({ -2, 14 }) do
    K.box(m, CFrame.new(-6, y1 + 3, z), Vector3.new(56, 0.9, 4), MAT.WoodPlanks, C.plankDark, { name = "Bench" })
    K.box(m, CFrame.new(-6, y1 + 1.5, z), Vector3.new(55, 3, 0.9), MAT.Wood, C.wood, { name = "BenchLeg" })
  end
  K.box(m, CFrame.new(-W / 2 + 16, y1 + 1.5, -18), Vector3.new(30, 3, 26), MAT.Slate, C.stone, { name = "Dais" })
  K.table(m, CFrame.new(-W / 2 + 16, y1 + 3, -18), 26, 9, 5.4, C.oak)
  K.chair(m, CFrame.new(-W / 2 + 16, y1 + 3, -26) * K.yaw(math.pi))
  K.rug(m, CFrame.new(-6, y1 + 0.2, 6), 66, 34, rgb(108, 40, 46))
  chandelier(m, CFrame.new(-20, y1 + ST - 12, 4), 9, 12)
  chandelier(m, CFrame.new(18, y1 + ST - 12, 4), 7, 10)
  for _, x in ipairs({ -34, -10, 14, 38 }) do
    K.box(m, CFrame.new(x, y1 + 14, -D / 2 + 4), Vector3.new(10, 20, 0.6), MAT.Fabric, rgb(96, 56, 108), { name = "Tapestry", cancollide = false })
  end
  -- screens passage: a low partition between the entry and the hall, as every hall has
  K.box(m, CFrame.new(-W / 2 + 34, y1 + 9, -6), Vector3.new(3, 18, 32), MAT.WoodPlanks, C.plankDark, { name = "Screen" })
  K.autoDoor(m, CFrame.new(-W / 2 + 34, y1, 10) * K.yaw(math.pi / 2), DOOR_W, DOOR_H, { color = C.wood })

  -- second floor: solar and presence chamber, split by a partition
  local y2 = y1 + ST
  K.box(m, CFrame.new(6, y2 + ST / 2, 0), Vector3.new(3, ST, D - 12), MAT.Rock, STONE:Lerp(C.black, 0.1), { name = "CrossWall" })
  K.autoDoor(m, CFrame.new(6, y2, 14) * K.yaw(math.pi / 2), DOOR_W, DOOR_H, { color = C.wood })
  K.fireplace(m, CFrame.new(-26, y2, D / 2 - 4) * K.yaw(math.pi), 20, 20, C.darkStone)
  K.table(m, CFrame.new(-22, y2, 0), 24, 12, 5.4, C.oak)
  K.chair(m, CFrame.new(-22, y2, 9) * K.yaw(math.pi))
  K.chair(m, CFrame.new(-34, y2, -8))
  K.shelf(m, CFrame.new(-W / 2 + 5, y2, -14) * K.yaw(-math.pi / 2), 28, 18, 4.4, C.plankDark, 5)
  K.rug(m, CFrame.new(-22, y2 + 0.2, 0), 30, 22, rgb(64, 58, 100))
  -- the lord's bed and chest sit WEST of the stair well (x 24..40 on this floor), not in it
  K.bed(m, CFrame.new(16, y2, 12) * K.yaw(math.pi), 12, 20, C.oak, rgb(120, 60, 70))
  K.chest(m, CFrame.new(19, y2, -12), 4)
  K.counter(m, CFrame.new(20, y2, D / 2 - 4) * K.yaw(math.pi), 20, 5, 6.6, C.plankDark)
  ceilingLamps(m, CFrame.new(0, y2 + ST - 2, 0), { -28, 24 }, { -14, 14 }, 5)

  -- third floor: bedchambers off a corridor
  local y3 = y2 + ST
  -- three bedchambers, not four: the outer bays stood in the stair well arriving from the second
  -- floor (x -40..-24) and on the flight leaving for the fourth (x 26..38)
  for i = 0, 2 do
    local x = -16 + i * 16
    K.box(m, CFrame.new(x - 8, y3 + ST / 2, 8), Vector3.new(2.4, ST, D - 26), MAT.WoodPlanks, C.plankDark, { name = "Partition" })
    K.bed(m, CFrame.new(x, y3, 18) * K.yaw(math.pi), 10, 17, C.wood, C.canvas)
    K.chest(m, CFrame.new(x, y3, 2), 3.4)
    K.lantern(m, CFrame.new(x, y3 + ST - 10, 10), 4)
  end
  ceilingLamps(m, CFrame.new(0, y3 + ST - 2, -D / 2 + 12), { -20, 20 }, { 0 }, 4)

  -- fourth floor: garrison and stores under the roof
  local y4 = y3 + ST
  for i = 0, 7 do K.bed(m, CFrame.new(-38 + (i % 4) * 12, y4, -14 + math.floor(i / 4) * 34) * K.yaw(math.pi), 8, 15, C.plankDark, C.canvas) end
  -- stores stacked clear of the stair well, which lands on this floor at x 24..40
  for i = 0, 5 do K.crate(m, CFrame.new(6 + (i % 2) * 9, y4, -18 + math.floor(i / 2) * 12), 6) end
  ceilingLamps(m, CFrame.new(0, y4 + ST - 6, 0), { -24, 24 }, { 0 }, 4)

  -- roof: battlemented walk, three turrets (not four), and the great chimney stack.
  -- ROOF is the top of the fourth storey's walls, not H + 12: at H + 12 the deck slab lay across
  -- the fourth floor itself, so the last flight climbed into two studs of stone and the garrison
  -- floor was sealed.
  local ROOF = 10 + FLOORS * ST + (ST - 4) + 2
  K.roofBattlement(m, CFrame.new(0, ROOF, 0), W, D, { color = STONE_DARK, merlon = 9, step = 9.5, overhang = 4 })
  local turrets = { { -W / 2 + 8, -D / 2 + 8, 11, 30 }, { W / 2 - 8, -D / 2 + 8, 10, 22 }, { -W / 2 + 8, D / 2 - 8, 11, 26 } }
  for i, t in ipairs(turrets) do
    K.cyl(m, CFrame.new(t[1], (ROOF + t[4]) / 2, t[2]), t[3], ROOF + t[4], MAT.Rock, STONE:Lerp(C.white, 0.04), { name = "Turret" .. i })
    K.roofCone(m, CFrame.new(t[1], ROOF + t[4], t[2]), t[3] * 1.1, t[3] * 1.5, MAT.Slate, C.slateRoof, 10)
    for f = 1, FLOORS do K.arrowSlit(m, CFrame.new(t[1], 14 + f * ST, t[2] - t[3] - 0.6), { stone = STONE }) end
    if i == 1 then K.banner(m, CFrame.new(t[1], ROOF + t[4] + t[3] * 1.5, t[2]), 10, 20, rgb(148, 40, 44), 28) end
  end
  local stack = K.box(m, CFrame.new(-26, ROOF + 22, D / 2 + 2), Vector3.new(16, 48, 13), MAT.Rock, STONE:Lerp(C.black, 0.18), { name = "GreatStack" })
  K.box(m, CFrame.new(-26, ROOF + 47, D / 2 + 2), Vector3.new(19, 2.4, 16), MAT.Slate, C.darkStone, { name = "StackCap" })
  smoke(stack, rgb(110, 108, 104), 11)
  K.box(m, CFrame.new(26, ROOF + 14, D / 2 + 2), Vector3.new(11, 32, 10), MAT.Rock, STONE:Lerp(C.black, 0.14), { name = "Stack2" })

  -- chapel apse: a half-round projection on the east flank, one flank only
  local ao = CFrame.new(W / 2 + 12, 10, 14)
  K.cyl(m, ao * CFrame.new(0, ST, 0), 18, ST * 2, MAT.Rock, STONE:Lerp(C.white, 0.06), { name = "Apse" })
  K.roofCone(m, ao * CFrame.new(0, ST * 2, 0), 19, 22, MAT.Metal, C.verdigris, 10)
  for _, a in ipairs({ -0.6, 0, 0.6 }) do
    local wx, wz = math.cos(a) * 18.4, math.sin(a) * 18.4
    K.window(m, ao * CFrame.new(wx, ST * 0.7, wz) * K.yaw(math.pi / 2 - a), 7, 16, C.brassDark, true)
  end
  K.floorSlab(m, ao, 34, 34, MAT.CeramicTiles, rgb(206, 198, 182), { name = "ChapelFloor" })
  for i = 0, 3 do
    K.box(m, ao * CFrame.new(-7, 2.6, -8 + i * 6), Vector3.new(11, 0.8, 3.4), MAT.WoodPlanks, C.plankDark, { name = "Pew" })
    K.box(m, ao * CFrame.new(7, 2.6, -8 + i * 6), Vector3.new(11, 0.8, 3.4), MAT.WoodPlanks, C.plankDark, { name = "Pew" })
  end
  K.box(m, ao * CFrame.new(0, 3, 12), Vector3.new(14, 6, 6), MAT.Marble, rgb(226, 222, 210), { name = "Altar" })
  local sun = K.gear(m, ao * CFrame.new(0, 16, 12) * K.roll(math.pi / 2), 6, 16, 1.4, BRASS)
  glow(K.ball(m, ao * CFrame.new(0, 16, 12), 4, MAT.Neon, rgb(255, 226, 160), { name = "Sanctus", cancollide = false }), rgb(255, 226, 160), 40, 2)
  chandelier(m, ao * CFrame.new(0, ST * 1.6, 0), 8, 10, rgb(255, 232, 180))

  -- kitchen wing off the back, lower ridge, its own huge chimney
  local ko = CFrame.new(18, 0, D / 2 + 26)
  K.box(m, ko * CFrame.new(0, 4, 0), Vector3.new(52, 8, 46), MAT.Rock, STONE_DARK, { name = "KitchenBatter" })
  K.floorSlab(m, ko * CFrame.new(0, 8, 0), 48, 42, MAT.Slate, rgb(122, 118, 112), { name = "KitchenFloor" })
  walls4(m, ko * CFrame.new(0, 8, 0), 48, 42, ST + 10, 4, MAT.Rock, STONE,
    { { x = -8, w = DOOR_W + 4, h = DOOR_H } }, { { x = 8, w = DOOR_W + 6, h = DOOR_H } },
    { win(-10, 14), win(10, 14) }, { win(0, 14) }, "Kitchen")
  K.roofGable(m, ko * CFrame.new(0, ST + 18, 0), 48, 42, 22, MAT.Slate, C.slateRoof, 4)
  K.fireplace(m, ko * CFrame.new(-14, 8, 18) * K.yaw(math.pi), 24, 22, C.darkStone)
  K.box(m, ko * CFrame.new(-14, 32, 16), Vector3.new(28, 10, 12), MAT.Metal, C.iron, { name = "ExtractHood" })
  local kstack = K.box(m, ko * CFrame.new(-14, ST + 34, 18), Vector3.new(14, 42, 12), MAT.Rock, STONE:Lerp(C.black, 0.22), { name = "KitchenStack" })
  smoke(kstack, rgb(118, 114, 108), 10)
  K.cylX(m, ko * CFrame.new(-14, 17, 12) * K.yaw(math.pi / 2), 0.5, 20, MAT.Metal, C.iron, { name = "SpitRod" })
  K.cyl(m, ko * CFrame.new(-14, 17, 12) * K.roll(math.pi / 2), 3.4, 8, MAT.Fabric, rgb(168, 96, 72), { name = "Roast", cancollide = false })
  for _, x in ipairs({ 4, 16 }) do
    K.box(m, ko * CFrame.new(x, 14, 16), Vector3.new(11, 14, 11), MAT.Brick, rgb(148, 100, 84), { name = "Oven" })
    local mouth = K.box(m, ko * CFrame.new(x, 13, 10.4), Vector3.new(6, 5.4, 0.8), MAT.Neon, C.ember, { name = "OvenMouth", cancollide = false })
    glow(mouth, C.ember, 26, 2)
  end
  for _, p in ipairs({ { -6, -6 }, { 8, -6 }, { -6, 4 } }) do
    K.table(m, ko * CFrame.new(p[1], 8, p[2]), 16, 9, 5.4, C.plank)
  end
  K.counter(m, ko * CFrame.new(18, 8, -12) * K.yaw(math.pi / 2), 18, 5, 6.4, C.plankDark)
  K.box(m, ko * CFrame.new(-6, 26, -2), Vector3.new(24, 0.8, 7), MAT.Metal, C.iron, { name = "PotRack" })
  for i = 0, 5 do
    local x, z = -15 + i * 4.4, -4 + (i % 2) * 5
    K.chain(m, (ko * CFrame.new(x, 26, z)).Position, (ko * CFrame.new(x, 21, z)).Position, 3, 0.2)
    if i % 2 == 0 then K.cyl(m, ko * CFrame.new(x, 19, z), 2.4, 4, MAT.Metal, C.copper, { name = "HangingPot", cancollide = false })
    else K.cylX(m, ko * CFrame.new(x, 20, z) * K.roll(math.pi / 2), 2.8, 0.6, MAT.Metal, C.iron, { name = "Pan", cancollide = false }) end
  end
  K.shelf(m, ko * CFrame.new(-21, 8, 4) * K.yaw(-math.pi / 2), 18, 20, 4.4, C.plankDark, 5)
  ceilingLamps(m, ko * CFrame.new(0, ST + 16, 0), { -12, 12 }, { -10, 8 }, 5)

  -- steam plant against the west flank: boilers feeding the keep's mains
  local bo = CFrame.new(-W / 2 - 18, 0, 10)
  K.box(m, bo * CFrame.new(0, 4, 0), Vector3.new(34, 8, 44), MAT.Cobblestone, C.darkStone, { name = "PlantBase" })
  for i = 0, 1 do
    K.boiler(m, bo * CFrame.new(-7 + i * 14, 22, -10 + i * 18), 7, 30, { bands = 4, rivets = 16, firebox = true })
    K.gauge(m, bo * CFrame.new(-7 + i * 14, 30, -18 + i * 18) * K.yaw(math.pi / 2), 3.4)
  end
  K.valveWheel(m, bo * CFrame.new(2, 26, 4), 4, 5)
  K.pipe(m, { (bo * CFrame.new(-7, 38, -10)).Position, (bo * CFrame.new(-7, 46, 6)).Position,
              (bo * CFrame.new(14, 46, 6)).Position, CFrame.new(-W / 2 + 2, 10 + ST * 2, 6).Position }, 2, C.copper)
  local vent = K.smokestack(m, bo * CFrame.new(0, 38, 14), 4, 34, { smoke = true, color = C.rust })
  steamJet(vent:FindFirstChild("Stack") or vent, 18)
  for i = 0, 3 do K.gear(m, bo * CFrame.new(-12 + i * 8, 14, 20) * K.yaw(math.pi / 2), 4 + i % 2, 14, 1.2, i % 2 == 0 and BRASS or C.copper) end

  K.autoDoor(m, CFrame.new(-18, 10, -D / 2 - 2.6), DOOR_W + 4, DOOR_H, { color = C.wood })
  K.sign(m, fo * CFrame.new(0, ST + 6, -18.6), "ปราสาทหลวง", 30, 7, rgb(42, 40, 42), rgb(240, 216, 154))
  for _, p in ipairs({ { -W / 2 - 6, -D / 2 - 34 }, { W / 2 + 6, -D / 2 - 34 } }) do
    K.lampPost(m, CFrame.new(p[1], 0, p[2]), 22, rgb(255, 200, 130))
  end
  K.attrs(m, { Kind = "keep", Floors = FLOORS })
end
K.build("Castle_Keep", nil, function(m) keep(m) end)

-- ========================================================== 2. the great hall
-- one enormous room: open to a trussed roof, minstrel gallery over the screens passage,
-- dais at the far end, kitchen pass-through, and a bay window off one flank only
local function greatHall(m)
  local W, D, H = 108, 54, 46
  K.box(m, CFrame.new(0, -2, 0), Vector3.new(W + 24, 4, D + 24), MAT.Cobblestone, C.darkStone, { name = "Plinth" })
  K.box(m, CFrame.new(0, 4, 0), Vector3.new(W + 8, 8, D + 8), MAT.Rock, STONE_DARK, { name = "Batter" })
  K.floorSlab(m, CFrame.new(0, 8, 0), W, D, MAT.Slate, rgb(134, 130, 124), { name = "HallFloor" })
  walls4(m, CFrame.new(0, 8, 0), W, D, H, 5, MAT.Rock, STONE,
    { { x = -34, w = DOOR_W + 8, h = DOOR_H + 4 }, win(-8, 20), win(14, 20), win(38, 20) },
    { win(-30, 20), win(-6, 20), win(20, 20), { x = 44, w = DOOR_W, h = DOOR_H } },
    { win(-12, 20), win(12, 20) }, { { x = 0, w = 22, h = 30, sill = 14 } }, "Hall")
  coursedFace(m, CFrame.new(0, 8, -D / 2 - 2.8), W, H, 1.6, 41, STONE)
  coursedFace(m, CFrame.new(0, 8, D / 2 + 2.8) * K.yaw(math.pi), W, H, 1.6, 43, STONE:Lerp(C.black, 0.05))

  -- buttresses at uneven spacing, taller on the windward side
  for _, t in ipairs({ 0.12, 0.3, 0.52, 0.72, 0.9 }) do
    local x = -W / 2 + W * t
    K.box(m, CFrame.new(x, 8 + H * 0.46, -D / 2 - 4.4), Vector3.new(8, H * 0.92, 6), MAT.Rock, STONE:Lerp(C.white, 0.07), { name = "Buttress" })
    K.wedge(m, CFrame.new(x, 8 + H * 0.92, -D / 2 - 4.4) * K.pitch(math.pi) * K.yaw(math.pi), Vector3.new(8, 7, 6), MAT.Rock, STONE:Lerp(C.white, 0.07))
    K.box(m, CFrame.new(x, 8 + H * 0.36, D / 2 + 4.4), Vector3.new(7, H * 0.72, 6), MAT.Rock, STONE:Lerp(C.white, 0.05), { name = "Buttress" })
  end

  K.roofGable(m, CFrame.new(0, 8 + H, 0), W, D, 34, MAT.Slate, C.slateRoof, 5)
  -- hammerbeam trusses: the thing that makes a hall read as a hall
  for i = 0, 6 do
    local z = -D / 2 + 6 + i * (D - 12) / 6
    K.box(m, CFrame.new(0, 8 + H - 2, z), Vector3.new(W - 8, 2.4, 2.6), MAT.Wood, C.wood, { name = "TieBeam", cancollide = false })
    K.rod(m, Vector3.new(-W / 2 + 4, 8 + H, z), Vector3.new(0, 8 + H + 32, z), 1.2, MAT.Wood, C.wood, { name = "Rafter", cancollide = false })
    K.rod(m, Vector3.new(W / 2 - 4, 8 + H, z), Vector3.new(0, 8 + H + 32, z), 1.2, MAT.Wood, C.wood, { name = "Rafter", cancollide = false })
    for _, s in ipairs({ -1, 1 }) do
      K.rod(m, Vector3.new(s * (W / 2 - 4), 8 + H - 12, z), Vector3.new(s * (W / 2 - 22), 8 + H - 1, z), 1, MAT.Wood, C.wood, { name = "Brace", cancollide = false })
      K.box(m, CFrame.new(s * (W / 2 - 14), 8 + H - 1.4, z), Vector3.new(18, 2, 2.4), MAT.Wood, C.wood, { name = "Hammerbeam", cancollide = false })
    end
  end

  -- screens passage and minstrel gallery over it
  K.box(m, CFrame.new(-W / 2 + 26, 8 + 11, 0), Vector3.new(3.4, 22, D - 10), MAT.WoodPlanks, C.plankDark, { name = "Screen" })
  K.autoDoor(m, CFrame.new(-W / 2 + 26, 8, 14) * K.yaw(math.pi / 2), DOOR_W, DOOR_H, { color = C.wood })
  K.autoDoor(m, CFrame.new(-W / 2 + 26, 8, -14) * K.yaw(math.pi / 2), DOOR_W, DOOR_H, { color = C.wood })
  -- the gallery, with the stairwell cut in it: it used to be an unbroken deck, so the flight below
  -- climbed into its underside and the musicians' gallery could not be reached
  K.floorSlab(m, CFrame.new(-W / 2 + 13, 8 + 24, 0), 26, D - 10, MAT.WoodPlanks, C.plank,
    { name = "Gallery", hole = { x = -5, z = -6, w = 12, d = 30 } })
  K.railing(m, CFrame.new(-W / 2 + 26, 8 + 24, 0) * K.yaw(math.pi / 2), D - 10, 5, C.wood)
  K.stairFlight(m, CFrame.new(-W / 2 + 8, 8, -D / 2 + 8), 10, 24, MAT.WoodPlanks, C.plankDark, { railColor = C.wood, run = 26 })
  for i = 0, 2 do K.chair(m, CFrame.new(-W / 2 + 16, 8 + 24, -8 + i * 8) * K.yaw(-math.pi / 2)) end

  -- dais, high table, long tables down the body of the hall
  K.box(m, CFrame.new(W / 2 - 20, 9.6, 0), Vector3.new(34, 3.2, D - 14), MAT.Slate, rgb(146, 140, 132), { name = "Dais" })
  K.table(m, CFrame.new(W / 2 - 20, 11.2, 0), 30, 11, 5.6, C.oak)
  K.chair(m, CFrame.new(W / 2 - 10, 11.2, 0) * K.yaw(-math.pi / 2))
  for i = 0, 3 do K.chair(m, CFrame.new(W / 2 - 26, 11.2, -12 + i * 8) * K.yaw(math.pi / 2)) end
  for _, x in ipairs({ -14, 12 }) do
    K.table(m, CFrame.new(x, 8, 0), 22, 12, 5.4, C.plank)
    for _, z in ipairs({ -8, 8 }) do
      K.box(m, CFrame.new(x, 11, z), Vector3.new(21, 0.9, 4), MAT.WoodPlanks, C.plankDark, { name = "Bench" })
      K.box(m, CFrame.new(x, 9.5, z), Vector3.new(20, 3, 0.9), MAT.Wood, C.wood, { name = "BenchLeg" })
    end
  end
  K.rug(m, CFrame.new(0, 8.2, 0), 60, 26, rgb(104, 38, 44))
  K.fireplace(m, CFrame.new(-4, 8, D / 2 - 5) * K.yaw(math.pi), 30, 26, C.darkStone)
  local hstack = K.box(m, CFrame.new(-4, 8 + H + 32, D / 2 + 3), Vector3.new(18, 46, 14), MAT.Rock, STONE:Lerp(C.black, 0.2), { name = "HallStack" })
  smoke(hstack, rgb(112, 110, 106), 10)
  for _, x in ipairs({ -30, 0, 30 }) do chandelier(m, CFrame.new(x, 8 + H - 10, 0), 11, 14) end
  for _, x in ipairs({ -22, 4, 30 }) do
    K.box(m, CFrame.new(x, 8 + 26, -D / 2 + 4), Vector3.new(16, 26, 0.7), MAT.Fabric, rgb(92, 52, 104), { name = "Tapestry", cancollide = false })
  end
  for i = 0, 5 do
    K.cylX(m, CFrame.new(-40 + i * 16, 8 + 30, D / 2 - 4) * K.yaw(math.pi / 2), 4, 0.7, MAT.Metal, rgb(150, 40, 44), { name = "Shield", cancollide = false })
    K.cylX(m, CFrame.new(-40 + i * 16, 8 + 30, D / 2 - 4.5) * K.yaw(math.pi / 2), 1.1, 0.5, MAT.Metal, BRASS, { name = "ShieldBoss", cancollide = false })
  end

  -- oriel bay window off the east flank only
  local bo = CFrame.new(W / 2 + 12, 8, 0)
  K.box(m, bo * CFrame.new(0, 12, 0), Vector3.new(24, 30, 30), MAT.Rock, STONE:Lerp(C.white, 0.06), { name = "BayShell" })
  K.floorSlab(m, bo, 22, 28, MAT.Slate, rgb(140, 136, 130), { name = "BayFloor" })
  for _, sz in ipairs({ -1, 0, 1 }) do
    K.box(m, bo * CFrame.new(11.4, 16, sz * 10), Vector3.new(1.4, 26, 1.4), MAT.Rock, STONE:Lerp(C.white, 0.14), { name = "Mullion" })
  end
  K.box(m, bo * CFrame.new(11.4, 16, 0), Vector3.new(0.5, 24, 28), MAT.Glass, C.glass, { name = "BayGlass", transparency = 0.4, cancollide = false })
  K.roofHip(m, bo * CFrame.new(0, 30, 0), 26, 32, 14, MAT.Metal, C.verdigris, 2)
  K.table(m, bo * CFrame.new(-2, 0, 0), 12, 10, 5.4, C.oak)
  K.chair(m, bo * CFrame.new(-2, 0, 8) * K.yaw(math.pi))
  chandelier(m, bo * CFrame.new(0, 24, 0), 6, 8)

  -- kitchen pass-through hatch on the back wall by the screens
  K.box(m, CFrame.new(-W / 2 + 44, 8 + 8, D / 2 - 2.6), Vector3.new(16, 10, 2), MAT.Wood, C.wood, { name = "ServeryHatch" })
  K.counter(m, CFrame.new(-W / 2 + 44, 8, D / 2 - 6) * K.yaw(math.pi), 16, 5, 6.6, C.plankDark)

  K.autoDoor(m, CFrame.new(-W / 2 + 34, 8, -D / 2 - 2.6), DOOR_W + 8, DOOR_H + 4, { color = C.wood })
  K.sign(m, CFrame.new(-W / 2 + 34, 8 + DOOR_H + 8, -D / 2 - 3.4), "ท้องพระโรง", 28, 7, rgb(42, 40, 42), rgb(240, 216, 154))
  K.lampPost(m, CFrame.new(-W / 2 + 18, 0, -D / 2 - 16), 22, rgb(255, 200, 130))
  K.lampPost(m, CFrame.new(-W / 2 + 50, 0, -D / 2 - 16), 22, rgb(255, 200, 130))
  K.attrs(m, { Kind = "greatHall" })
end
K.build("Castle_GreatHall", nil, function(m) greatHall(m) end)
