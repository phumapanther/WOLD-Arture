-- castle_parts — modular castle components that tile together.
--
-- THE MODULE CONTRACT, which is what makes these assemblable:
--   * a curtain wall section is MOD (64) long along X, WALL_T (14) thick along Z, and its walkway
--     deck is at WALL_H (40). The outer face is at -Z, the inner (courtyard) face at +Z.
--   * every piece is built base at y = 0, centred on x = 0 / z = 0, front (outer face) toward -Z,
--     so a run of wall is just the same piece repeated every 64 studs along X.
--   * towers are centred on a wall joint and are wider than the wall, so they read as straddling it.
--   * each model carries attributes ModuleW / ModuleD / WallH / Kind so an assembly script can chain
--     them without hard-coded numbers. See Castle_Assembly for a worked run.
--
-- from the reference script: its city main pipes used Size(4, length, 4) on a Cylinder, which runs
-- along its own X, so they came out as discs up to 250 studs across. K.pipe routes them properly.
K.SET = "castleparts"
K.SLOT = 170
K.PER_ROW = 3
K.ORIGIN = Vector3.new(0, 0, 1400)

local C = K.C
local MAT = K.MAT
local rgb = Color3.fromRGB

local MOD = 64          -- wall module length along X
local WALL_T = 14       -- wall thickness along Z
local WALL_H = 40       -- height of the walkway deck
local ST = 26           -- storey height inside towers and gatehouses
local DOOR_W, DOOR_H = 12, 18

local STONE = rgb(150, 146, 138)
local STONE_DARK = rgb(112, 108, 102)
local BRASS = rgb(205, 140, 45)

local function glow(part, color, range, brightness)
  local l = Instance.new("PointLight")
  l.Color = color or C.lamp; l.Range = range or 24; l.Brightness = brightness or 1.4; l.Parent = part
  return l
end
local function smoke(part, color, size)
  local s = Instance.new("Smoke")
  s.Size = size or 6; s.RiseVelocity = 8; s.Opacity = 0.2; s.Color = color or rgb(104, 102, 98); s.Parent = part
  return s
end
local function steamJet(part, rate)
  local e = Instance.new("ParticleEmitter")
  e.Name = "SteamJet"
  e.Color = ColorSequence.new(rgb(226, 234, 242))
  e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 5) })
  e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.42), NumberSequenceKeypoint.new(1, 1) })
  e.Lifetime = NumberRange.new(2, 3.6); e.Rate = rate or 12
  e.Speed = NumberRange.new(4, 8); e.SpreadAngle = Vector2.new(14, 14)
  e.EmissionDirection = Enum.NormalId.Top; e.Parent = part
  return e
end

-- coursed stone: a face built from blocks of uneven length so it does not read as one slab.
-- openings ({ x, w, sill, h } in the face's own frame) are left bare, or the facing plasters over
-- the doors and arrow slits cut through the wall behind it.
local function coursedFace(m, cf, w, h, thick, seed, base, name, openings)
  local rng = Random.new(seed)
  local g = K.model(m, name or "Face")
  local function clear(x0, x1, y0, y1)
    for _, o in ipairs(openings or {}) do
      if x1 > o.x - o.w / 2 - 1 and x0 < o.x + o.w / 2 + 1
        and y1 > (o.sill or 0) - 0.5 and y0 < (o.sill or 0) + o.h + 0.5 then return false end
    end
    return true
  end
  local y = 0
  while y < h - 0.1 do
    local course = math.min(3 + rng:NextNumber() * 1.6, h - y)
    local x = -w / 2
    while x < w / 2 - 0.1 do
      local bw = math.min(5 + rng:NextNumber() * 7, w / 2 - x)
      local tint = base:Lerp(rng:NextNumber() > 0.5 and C.white or C.black, rng:NextNumber() * 0.13)
      if clear(x, x + bw, y, y + course) then
        K.box(g, cf * CFrame.new(x + bw / 2, y + course / 2, 0), Vector3.new(bw * 0.985, course * 0.97, thick), MAT.Rock, tint, { name = "Stone" })
      end
      x += bw
    end
    y += course
  end
  return g
end

-- weathering: moss at the foot, water staining below a spout, a crack or two
local function weather(m, cf, w, h, seed)
  local rng = Random.new(seed)
  local g = K.model(m, "Weathering")
  for i = 1, math.floor(w / 9) do
    local x = -w / 2 + rng:NextNumber() * w
    K.box(g, cf * CFrame.new(x, rng:NextNumber() * 3, -0.35), Vector3.new(3 + rng:NextNumber() * 6, 1.4 + rng:NextNumber() * 3, 0.5),
      MAT.Grass, C.moss:Lerp(C.black, rng:NextNumber() * 0.35), { name = "Moss", cancollide = false })
  end
  for i = 1, 2 do
    local x = -w / 2 + rng:NextNumber() * w
    K.box(g, cf * CFrame.new(x, h * 0.4, -0.34), Vector3.new(1.6 + rng:NextNumber() * 2, h * 0.7, 0.4),
      MAT.Rock, STONE_DARK:Lerp(C.black, 0.3), { name = "Stain", cancollide = false })
  end
  return g
end

-- ============================================ 1. curtain wall, straight module
-- outer face battered at the foot, arcaded on the inside, machicolated at the top,
-- with a stair up to the walkway at one end so a run of wall is climbable
local function wallStraight(m, opts)
  opts = opts or {}
  local len = opts.len or MOD
  local outer = -WALL_T / 2

  -- battered plinth: the wall foot leans out, which is what makes stonework read as heavy
  K.box(m, CFrame.new(0, 3, 0), Vector3.new(len, 6, WALL_T + 5), MAT.Rock, STONE_DARK, { name = "Batter" })
  K.wedge(m, CFrame.new(0, 8.4, outer - 2.4) * K.pitch(math.pi) * K.yaw(math.pi), Vector3.new(len, 5, 3), MAT.Rock, STONE_DARK)

  K.box(m, CFrame.new(0, WALL_H / 2 + 3, 0), Vector3.new(len, WALL_H - 6, WALL_T), MAT.Rock, STONE, { name = "Core" })
  coursedFace(m, CFrame.new(0, 6, outer - 0.6), len, WALL_H - 6, 1.4, opts.seed or 7, STONE, "OuterFace")
  coursedFace(m, CFrame.new(0, 6, WALL_T / 2 + 0.6) * K.yaw(math.pi), len, WALL_H - 6, 1.4, (opts.seed or 7) + 31, STONE:Lerp(C.black, 0.06), "InnerFace")
  weather(m, CFrame.new(0, 6, outer - 1.2), len, WALL_H - 6, opts.seed or 7)

  K.box(m, CFrame.new(0, WALL_H - 8, outer - 1.4), Vector3.new(len, 2, 3.4), MAT.Sandstone, STONE:Lerp(C.white, 0.14), { name = "StringCourse" })

  -- arcade of relieving arches on the courtyard side: the wall reads hollow, and it is
  for i = 0, math.floor(len / 16) - 1 do
    local x = -len / 2 + 8 + i * 16
    K.archOpening(m, CFrame.new(x, 0, WALL_T / 2 + 0.9), 11, 13, 2.2, MAT.Rock, STONE:Lerp(C.black, 0.12))
    K.box(m, CFrame.new(x, 9, WALL_T / 2 + 1.2), Vector3.new(11, 18, 1), MAT.Rock, STONE_DARK:Lerp(C.black, 0.25), { name = "ArcadeRecess", cancollide = false })
  end

  -- arrow slits at uneven spacing: an even row is the strongest tell of a generated wall
  for _, t in ipairs({ 0.13, 0.31, 0.44, 0.66, 0.86 }) do
    K.arrowSlit(m, CFrame.new(-len / 2 + len * t, 24, outer - 1.1), { stone = STONE })
  end

  -- machicolated head, walkway, and the two parapets (outer tall, inner low)
  K.machicolation(m, CFrame.new(0, WALL_H - 5, outer), len, { color = STONE })
  K.box(m, CFrame.new(0, WALL_H, 0), Vector3.new(len, 2, WALL_T + 7), MAT.Slate, STONE_DARK, { name = "Walkway" })
  for i = 0, math.floor(len / 8) do
    K.box(m, CFrame.new(-len / 2 + i * 8, WALL_H + 4.6, outer - 2.4), Vector3.new(4.6, 7.2, 3), MAT.Rock, STONE, { name = "Merlon" })
  end
  K.box(m, CFrame.new(0, WALL_H + 2.4, outer - 2.4), Vector3.new(len, 2.8, 3), MAT.Rock, STONE, { name = "OuterParapetBase" })
  -- the inner parapet, broken where the stair arrives. It used to run past the head of the flight
  -- as one unbroken box, so you climbed 40 studs and met a wall: the walkway was never reachable.
  local stairTop = -len / 2 + 6 + (WALL_H + 1) * 1.05
  for _, seg in ipairs({ { -len / 2, stairTop - 13 }, { stairTop + 3, len / 2 } }) do
    local segW = math.min(seg[2], len / 2) - math.max(seg[1], -len / 2)
    if segW > 0.5 then
      K.box(m, CFrame.new((math.max(seg[1], -len / 2) + math.min(seg[2], len / 2)) / 2, WALL_H + 2.6, WALL_T / 2 + 2.4),
        Vector3.new(segW, 5.2, 2.6), MAT.Rock, STONE:Lerp(C.black, 0.08), { name = "InnerParapet" })
    end
  end

  -- Stair up to the walkway. It runs ALONG the wall on the courtyard side, not into it: the first
  -- version climbed toward -Z from z = 29 and ploughed through the wall core and the inner arcade,
  -- which a walk test caught and no screenshot showed.
  local stairZ = WALL_T / 2 + 9
  K.stairFlight(m, CFrame.new(-len / 2 + 6, 0, stairZ) * K.yaw(math.pi / 2), 10, WALL_H + 1, MAT.Rock, STONE_DARK, { railColor = C.iron })
  K.box(m, CFrame.new(-len / 2 + 6 + 21, WALL_H / 2 - 2, stairZ + 6.4), Vector3.new(44, WALL_H - 4, 2.4), MAT.Rock, STONE_DARK, { name = "StairSpine" })

  -- steampunk service: a brass main clipped to the inner face, a drain spout on the outer
  K.pipe(m, {
    Vector3.new(-len / 2, 30, WALL_T / 2 + 2.2), Vector3.new(len / 2, 30, WALL_T / 2 + 2.2),
  }, 1.6, C.copper, { name = "WallMain" })
  for i = 0, math.floor(len / 22) do
    local x = -len / 2 + 11 + i * 22
    K.cyl(m, CFrame.new(x, 26, WALL_T / 2 + 2.2), 0.7, 8, MAT.Metal, C.brassDark, { name = "Standpipe" })
    K.valveWheel(m, CFrame.new(x, 33, WALL_T / 2 + 3.4) * K.yaw(math.pi / 2), 1.8, 5)
  end
  local spout = K.cylX(m, CFrame.new(len * 0.22, WALL_H - 11, outer - 3.4) * K.pitch(math.rad(70)) * K.yaw(math.pi / 2), 1.1, 5, MAT.Metal, C.verdigris, { name = "Gargoyle" })
  K.ball(m, CFrame.new(len * 0.22, WALL_H - 9.4, outer - 2.6), 2.6, MAT.Slate, STONE:Lerp(C.black, 0.28), { name = "GargoyleHead", cancollide = false })
  for _, x in ipairs({ -len * 0.3, len * 0.34 }) do
    K.lampPost(m, CFrame.new(x, WALL_H + 2, WALL_T / 2 + 1), 12, rgb(255, 198, 130))
  end
  K.attrs(m, { Kind = "wall", ModuleW = len, ModuleD = WALL_T, WallH = WALL_H })
end
K.build("Castle_WallStraight", nil, function(m) wallStraight(m) end)

-- ================================================== 2. curtain wall, corner bastion
-- turns the run 90 degrees: takes a wall on -X and hands one off on +Z
local function wallCorner(m)
  local S = MOD * 0.72
  K.box(m, CFrame.new(0, 3, 0), Vector3.new(S + 6, 6, S + 6), MAT.Rock, STONE_DARK, { name = "Batter" })
  K.box(m, CFrame.new(0, WALL_H / 2 + 3, 0), Vector3.new(S, WALL_H - 6, S), MAT.Rock, STONE, { name = "Core" })
  for _, e in ipairs({ { 0, -S / 2 - 0.6, 0 }, { -S / 2 - 0.6, 0, -math.pi / 2 }, { 0, S / 2 + 0.6, math.pi }, { S / 2 + 0.6, 0, math.pi / 2 } }) do
    coursedFace(m, CFrame.new(e[1], 6, e[2]) * K.yaw(e[3]), S, WALL_H - 6, 1.4, 51 + e[1] + e[2], STONE, "Face")
  end
  weather(m, CFrame.new(0, 6, -S / 2 - 1.2), S, WALL_H - 6, 12)
  -- the corner itself is chamfered, which is how real bastions shed a battering ram
  for _, d in ipairs({ { -1, -1 }, { 1, -1 } }) do
    K.box(m, CFrame.new(d[1] * S / 2, WALL_H / 2 + 3, d[2] * S / 2) * K.yaw(math.rad(45)), Vector3.new(10, WALL_H - 6, 10), MAT.Rock, STONE:Lerp(C.white, 0.06), { name = "Chamfer" })
  end
  K.machicolation(m, CFrame.new(0, WALL_H - 5, -S / 2), S, { color = STONE })
  K.machicolation(m, CFrame.new(-S / 2, WALL_H - 5, 0) * K.yaw(-math.pi / 2), S, { color = STONE })
  -- the stair climbs to the deck (42, not 40), starts a little clear of the bastion and tops out
  -- INSIDE its footprint -- it used to overshoot the corner and arrive past the edge of the deck --
  -- and the parapet is broken where it arrives
  local cornerFoot = -S / 2 - 5
  local cornerTop = cornerFoot + (WALL_H + 2) * 1.05
  K.roofBattlement(m, CFrame.new(0, WALL_H + 2, 0), S, S,
    { color = STONE_DARK, merlon = 7.2, step = 8, overhang = 3.5, gaps = { back = { at = cornerTop - 3, w = 15 } } })
  K.stairFlight(m, CFrame.new(cornerFoot, 0, S / 2 + 9) * K.yaw(math.pi / 2), 10, WALL_H + 2, MAT.Rock, STONE_DARK, { railColor = C.iron })
  -- no landing needed: the flight now tops out level with the deck and its own edge is half a stud
  -- from the deck edge, so the parapet gap above is the whole of what was missing
  for _, t in ipairs({ 0.2, 0.5, 0.78 }) do
    K.arrowSlit(m, CFrame.new(-S / 2 + S * t, 24, -S / 2 - 1.1), { stone = STONE })
    K.arrowSlit(m, CFrame.new(-S / 2 - 1.1, 24, -S / 2 + S * t) * K.yaw(-math.pi / 2), { stone = STONE })
  end
  local brazier = K.cyl(m, CFrame.new(0, WALL_H + 6, 0), 4, 7, MAT.Metal, C.iron, { name = "SignalBrazier" })
  local fire = K.box(m, CFrame.new(0, WALL_H + 10.4, 0), Vector3.new(6, 2.4, 6), MAT.Neon, C.ember, { name = "SignalFire", cancollide = false })
  glow(fire, C.ember, 60, 3)
  K.attrs(m, { Kind = "corner", ModuleW = S, ModuleD = S, WallH = WALL_H })
end
K.build("Castle_WallCorner", nil, function(m) wallCorner(m) end)

-- ======================================================== 3. gatehouse module
-- a walk-through gate: barbican passage, portcullis on a steam winch, murder holes above,
-- guard rooms either side with their own floors and stairs
local function wallGate(m)
  local W, D, H = 84, 44, WALL_H + ST
  local pass = 20        -- clear width of the passage

  K.box(m, CFrame.new(0, 3, 0), Vector3.new(W + 6, 6, D + 6), MAT.Rock, STONE_DARK, { name = "Batter" })
  -- The two gate towers flanking the passage. Each is FOUR WALLS around a room stack, not a solid
  -- block of stone with rooms drawn inside it -- which is what they were, so the guard rooms, their
  -- beds and their stairs were all buried and there was no way in.
  local TW = 4                                        -- gate tower wall thickness
  for _, s in ipairs({ -1, 1 }) do
    local cx = s * (pass / 2 + 16)
    local wx = cx - s * 6                             -- the stair well, against the passage wall
    local fx = cx + s * 6                             -- the half of the room that is left to live in
    local hi = H - 6                                  -- the tower's own height, from y = 6
    local slits = {}
    for f = 0, 2 do
      table.insert(slits, { x = -8, w = 3.6, h = 9, sill = f * ST + 8 })
      table.insert(slits, { x = 8, w = 3.6, h = 9, sill = f * ST + 8 })
    end
    K.wallRun(m, CFrame.new(cx, 6, -(D / 2 - TW / 2)), 32, hi, TW, MAT.Rock, STONE, slits, { name = "GateTower" })
    K.wallRun(m, CFrame.new(cx, 6, D / 2 - TW / 2) * K.yaw(math.pi), 32, hi, TW, MAT.Rock, STONE, {}, { name = "GateTower" })
    K.wallRun(m, CFrame.new(cx + s * (16 - TW / 2), 6, 0) * K.yaw(s * math.pi / 2), D, hi, TW, MAT.Rock, STONE, {}, { name = "GateTower" })
    K.wallRun(m, CFrame.new(cx - s * (16 - TW / 2), 6, 0) * K.yaw(-s * math.pi / 2), D, hi, TW, MAT.Rock, STONE,
      { { x = 0, w = DOOR_W - 2, h = DOOR_H, sill = 0 } }, { name = "GateTower" })
    coursedFace(m, CFrame.new(cx, 6, -D / 2 - 0.6), 32, H - 6, 1.4, 71 + s * 13, STONE, "Face", slits)
    coursedFace(m, CFrame.new(cx, 6, D / 2 + 0.6) * K.yaw(math.pi), 32, H - 6, 1.4, 91 + s * 13, STONE:Lerp(C.black, 0.05), "Face")
    weather(m, CFrame.new(cx, 6, -D / 2 - 1.2), 32, H - 6, 71 + s * 13)
    -- three floors of guard room, each reachable
    for f = 0, 2 do
      local y = 6 + f * ST
      K.floorSlab(m, CFrame.new(cx, y, 0), 24, D - 8, MAT.WoodPlanks, C.plankDark,
        { name = "GuardFloor", hole = f > 0 and { x = -s * 6, z = 0.5, w = 11, d = 30 } or nil })
      if f < 2 then
        K.stairFlight(m, CFrame.new(wx, y, -12), 9, ST, MAT.Rock, STONE_DARK, { railColor = C.iron, open = true, run = 24 })
      end
      if f > 0 then
        K.railing(m, CFrame.new(wx, y, -14.6), 11, 5, C.iron, MAT.Metal)
      end
      K.arrowSlit(m, CFrame.new(cx - 8, y + 8, -D / 2 - 1.1), { stone = STONE })
      K.arrowSlit(m, CFrame.new(cx + 8, y + 8, -D / 2 - 1.1), { stone = STONE })
      if f == 0 then
        K.table(m, CFrame.new(fx, y, 12), 9, 8, 5, C.oak)
        K.chair(m, CFrame.new(fx, y, 5) * K.yaw(math.pi))
        K.shelf(m, CFrame.new(cx + s * 11, y, -10) * K.yaw(-s * math.pi / 2), 12, 14, 4, C.plankDark, 4)
      elseif f == 1 then
        K.bed(m, CFrame.new(fx, y, -8), 8, 14, C.wood, C.canvas)
        K.bed(m, CFrame.new(fx, y, 9), 8, 14, C.wood, C.canvas)
        K.chest(m, CFrame.new(cx + s * 11, y, 17), 3)
      else
        for i = 0, 3 do K.crate(m, CFrame.new(cx + s * (3 + (i % 2) * 8), y, -14 + math.floor(i / 2) * 10), 5) end
      end
      K.chain(m, Vector3.new(fx, y + ST - 1, 0), Vector3.new(fx, y + ST - 5, 0), 3, 0.2)
      K.lantern(m, CFrame.new(fx, y + ST - 9, 0), 4)
      -- only the ground floor has a door: above it the passage-side wall faces the gate vault
      if f == 0 then
        K.autoDoor(m, CFrame.new(cx - s * 14.6, y, 0) * K.yaw(-s * math.pi / 2), DOOR_W - 2, DOOR_H, { color = C.wood, single = true })
      end
    end
  end
  -- the passage: barrel vaulted, portcullis at the outer end, murder holes overhead
  K.box(m, CFrame.new(0, WALL_H + ST / 2 + 3, 0), Vector3.new(pass + 4, ST - 6, D), MAT.Rock, STONE, { name = "OverGate" })
  K.roofBarrel(m, CFrame.new(0, ST + 2, 0), pass + 2, D, 9, MAT.Rock, STONE:Lerp(C.black, 0.1), 9)
  K.archOpening(m, CFrame.new(0, 0, -D / 2 - 1), pass, ST, 3.4, MAT.Rock, STONE:Lerp(C.white, 0.1))
  K.archOpening(m, CFrame.new(0, 0, D / 2 + 1) * K.yaw(math.pi), pass, ST, 3.4, MAT.Rock, STONE:Lerp(C.white, 0.1))
  for i = 0, 5 do                                    -- murder holes in the vault
    K.box(m, CFrame.new(-8 + (i % 3) * 8, ST + 1.4, -12 + math.floor(i / 3) * 20), Vector3.new(3, 1.2, 3), MAT.SmoothPlastic, C.black, { name = "MurderHole", cancollide = false })
  end
  K.box(m, CFrame.new(0, ST + 6, -D / 2 + 4), Vector3.new(pass + 8, 2.4, 2), MAT.Metal, C.brassDark, { name = "PortcullisRail" })
  for i = 0, 9 do
    K.cyl(m, CFrame.new(-pass / 2 + 1 + i * (pass - 2) / 9, ST + 11, -D / 2 + 4), 0.5, 9, MAT.Metal, C.iron, { name = "Bar", cancollide = false })
  end
  K.box(m, CFrame.new(0, ST + 16, -D / 2 + 4), Vector3.new(pass, 1.4, 1.4), MAT.Metal, C.iron, { name = "PortcullisBeam" })
  -- the winch that lifts it, in the left tower, driven off a boiler
  local wx = -(pass / 2 + 16)
  K.gear(m, CFrame.new(wx + 8, ST + 16, -D / 2 + 4), 6, 20, 1.8, BRASS)
  K.gear(m, CFrame.new(wx + 8, ST + 25, -D / 2 + 4), 3.4, 12, 1.8, C.copper)
  K.chain(m, Vector3.new(wx + 8, ST + 21, -D / 2 + 4), Vector3.new(-pass / 2 + 2, ST + 16, -D / 2 + 4), 8, 0.3)
  K.boiler(m, CFrame.new(wx, WALL_H + 8, 10), 5, 20, { bands = 3, rivets = 14, firebox = true })
  K.pipe(m, { Vector3.new(wx, WALL_H + 18, 10), Vector3.new(wx, WALL_H + 22, -6), Vector3.new(wx + 8, ST + 26, -D / 2 + 6) }, 1.2, C.copper)
  K.valveWheel(m, CFrame.new(wx + 6, WALL_H + 12, 10), 2.8, 5)

  -- the fighting top: walkway across, machicolations, banners, and a bell
  K.box(m, CFrame.new(0, H, 0), Vector3.new(W + 6, 2.4, D + 8), MAT.Slate, STONE_DARK, { name = "GateWalk" })
  K.machicolation(m, CFrame.new(0, H - 5, -D / 2 - 1), W + 4, { color = STONE, projection = 4.4, height = 6 })
  for _, sz in ipairs({ -1, 1 }) do
    for i = 0, math.floor((W + 6) / 8) do
      K.box(m, CFrame.new(-(W + 6) / 2 + i * 8, H + 5, sz * (D / 2 + 3.4)), Vector3.new(4.6, 7.6, 3), MAT.Rock, STONE, { name = "Merlon" })
    end
  end
  -- the two gate towers are deliberately capped differently: a spire on the west, a fighting
  -- platform with a stair turret on the east. two matching pyramids read as one roof, not two towers.
  K.banner(m, CFrame.new(-(pass / 2 + 16), H + 2, -D / 2 - 1), 9, 18, rgb(148, 40, 44), 26)
  K.roofPyramid(m, CFrame.new(-(pass / 2 + 16), H + 2, 6), 28, D - 10, 22, MAT.Slate, C.slateRoof, 1.6)
  K.roofBattlement(m, CFrame.new(pass / 2 + 16, H + 3, 6), 28, D - 10, { color = STONE_DARK, merlon = 7.4, step = 8, overhang = 2.4 })
  -- the stair turret hangs off the OUTSIDE corner: inside the tower it was a stone column standing
  -- in the guard room
  K.cyl(m, CFrame.new(pass / 2 + 34, H / 2 + 8, D / 2 + 2), 7, H + 14, MAT.Rock, STONE:Lerp(C.white, 0.05), { name = "StairTurret" })
  K.roofCone(m, CFrame.new(pass / 2 + 34, H + 22, D / 2 + 2), 8.4, 13, MAT.Slate, C.slateRoof, 8)
  K.banner(m, CFrame.new(pass / 2 + 16, H + 10, -D / 2 - 1), 8, 15, rgb(60, 74, 130), 22)
  local bell = K.ball(m, CFrame.new(0, H + 12, 6), 7, MAT.Metal, BRASS, { name = "GateBell", cancollide = false })
  glow(bell, rgb(255, 214, 140), 40, 1.6)
  K.sign(m, CFrame.new(0, ST + 20, -D / 2 - 2.4), "ประตูเมือง", 26, 6.4, rgb(42, 40, 42), rgb(238, 214, 152))
  K.attrs(m, { Kind = "gate", ModuleW = W, ModuleD = D, WallH = WALL_H, Passage = pass })
end
K.build("Castle_WallGate", nil, function(m) wallGate(m) end)

-- ==================================================== 4. round tower (drum tower)
-- four floors, a stair winding up one side, arrow slits, conical roof, steam vent
local function towerRound(m)
  local R, FLOORS = 24, 4
  local H = FLOORS * ST
  local WT = 4.5                 -- shell thickness; the room inside is what is left
  local IN = R - WT              -- clear inner radius, 19.5
  local DECK = IN - 0.1
  -- the well: one straight flight per floor, west of centre, and the same cut in every floor above
  -- The well is only as wide as the flight, so the deck comes right up to the stair's east side:
  -- you step off the top tread sideways onto the floor instead of into a hole.
  local SX, WELL = -7, { x = -7, z = 0.5, w = 11, d = 30 }
  -- the plinth stops just under the ground floor -- 8 studs of it stood proud of the deck and
  -- filled the whole room with solid rock to shin height
  K.cyl(m, CFrame.new(0, 3, 0), R + 4, 6, MAT.Rock, STONE_DARK, { name = "Batter" })

  -- The shell is a RING, not a solid drum: a door on the courtyard side and a slit per floor per
  -- face, so the rooms drawn inside it can actually be walked into.
  local openings = { { a = math.pi / 2, w = DOOR_W, h = DOOR_H, sill = 0 } }
  for f = 0, FLOORS - 1 do
    for k = -1, 1 do
      table.insert(openings, { a = math.pi + k * 0.7 + f * math.pi / 2, w = 3.4, h = 9, sill = f * ST + 8 })
    end
  end
  K.drumShell(m, CFrame.new(0, 6, 0), R, H, WT, 36, STONE, openings)
  -- coursed stone as a ring of staves so the drum is not one smooth tube. The facing skips whatever
  -- the shell left open, or it renders the doorway and every arrow slit as blank wall.
  local segs = 36
  local function faced(a, y0, y1)
    for _, o in ipairs(openings) do
      local off = math.abs((a - o.a + math.pi) % (2 * math.pi) - math.pi) * R
      if off < o.w / 2 + 1.5 and y1 > 6 + (o.sill or 0) - 0.5 and y0 < 6 + (o.sill or 0) + o.h + 0.5 then return false end
    end
    return true
  end
  for i = 0, segs - 1 do
    local a = i * 2 * math.pi / segs
    local rng = Random.new(i * 7 + 3)
    local arc = 2 * math.pi * R / segs
    local y = 6
    while y < H + 4 do
      local course = math.min(3.4 + rng:NextNumber() * 1.8, H + 6 - y)
      if faced(a, y, y + course) then
        K.box(m, CFrame.new(math.cos(a) * (R + 0.7), y + course / 2, math.sin(a) * (R + 0.7)) * K.yaw(math.pi / 2 - a),
          Vector3.new(arc * 1.1, course * 0.96, 1.6), MAT.Rock, STONE:Lerp(rng:NextNumber() > 0.5 and C.white or C.black, rng:NextNumber() * 0.12),
          { name = "Stone", cancollide = false })
      end
      y += course
    end
  end
  for i = 1, 3 do K.band(m, CFrame.new(0, 6 + i * ST, 0), R + 1.6, 2.4, STONE:Lerp(C.white, 0.16)) end
  -- the doorway's own dressing, and a threshold to walk in over
  K.archOpening(m, CFrame.new(0, 6, R - WT / 2), DOOR_W, DOOR_H, 2.6, MAT.Rock, STONE:Lerp(C.white, 0.1))
  K.box(m, CFrame.new(0, 6.4, R - 1), Vector3.new(DOOR_W + 4, 0.8, 8), MAT.Rock, STONE_DARK, { name = "Threshold" })

  -- floors, each with the stairwell cut and a room on it
  for f = 0, FLOORS - 1 do
    local y = 6 + f * ST
    -- One straight well, west of the door, repeated on every floor: the flight climbs from
    -- z = -13 to z = +14, and the floor ABOVE carries the matching hole. The first version turned
    -- the flight a quarter per floor, which looked right on paper and ran its top out through the
    -- shell -- which was solid then, so nothing showed. Now the shell is a room, so it would.
    K.roundFloor(m, CFrame.new(0, y, 0), DECK, f > 0 and WELL or nil, MAT.WoodPlanks, C.plankDark)
    if f < FLOORS then                      -- the last flight climbs to the fighting deck itself
      K.stairFlight(m, CFrame.new(SX, y, -12), 9, ST, MAT.Rock, STONE_DARK, { railColor = C.iron, open = true, run = 24 })
    end
    if f > 0 then
      -- railed at the foot end only: the head of the flight is where people step off
      K.railing(m, CFrame.new(WELL.x, y, WELL.z - WELL.d / 2 + 0.1), WELL.w, 5, C.iron, MAT.Metal)
    end
    for k = -1, 1 do
      local sa = math.pi + k * 0.7 + f * math.pi / 2
      K.arrowSlit(m, CFrame.new(math.cos(sa) * (R - WT + 0.4), y + 8, math.sin(sa) * (R - WT + 0.4)) * K.yaw(math.pi / 2 - sa), { stone = STONE })
    end
    K.chain(m, Vector3.new(11, y + ST - 1, 0), Vector3.new(11, y + ST - 5, 0), 3, 0.2)
    K.lantern(m, CFrame.new(11, y + ST - 9, 0), 4)
    -- every room east of the well, and inside the drum: nothing may reach further than IN studs out
    if f == 0 then
      K.table(m, CFrame.new(8, y, 3), 12, 9, 5.2, C.oak)
      K.chair(m, CFrame.new(8, y, 11) * K.yaw(math.pi))
      K.fireplace(m, CFrame.new(5, y, 14) * K.yaw(math.pi), 13, 16, C.darkStone)
      K.barrel(m, CFrame.new(13, y, -9), 2.8, 6)
    elseif f == 1 then
      for _, bz in ipairs({ -8, 8 }) do K.bed(m, CFrame.new(7, y, bz), 8, 15, C.wood, C.canvas) end
      K.chest(m, CFrame.new(14, y, 0), 3)
    elseif f == 2 then
      for i = 0, 3 do
        K.box(m, CFrame.new(1 + i * 3.6, y + 6, 10), Vector3.new(2.4, 12, 5), MAT.WoodPlanks, C.plankDark, { name = "ArmourRack" })
        K.box(m, CFrame.new(1 + i * 3.6, y + 8, 7.4), Vector3.new(1.4, 7, 4), MAT.Metal, C.steel, { name = "Breastplate", cancollide = false })
      end
      K.crate(m, CFrame.new(13, y, -11), 5)
    else
      K.counter(m, CFrame.new(6, y, -11), 12, 5, 6.4, C.plankDark)
      K.shelf(m, CFrame.new(14, y, 0) * K.yaw(-math.pi / 2), 14, 14, 4, C.plankDark, 4)
    end
  end

  -- fighting deck under a conical roof, and the steam plant that serves the wall main
  K.roofBattlement(m, CFrame.new(0, H + 6, 0), R * 1.7, R * 1.7, { color = STONE_DARK, merlon = 7.4, step = 8, overhang = 3, hole = WELL })
  K.roofCone(m, CFrame.new(0, H + 14, 0), R * 0.82, 26, MAT.Slate, C.slateRoof, 12)
  K.banner(m, CFrame.new(R * 0.5, H + 8, -R * 0.5), 8, 16, rgb(148, 40, 44), 24)
  local vent = K.cyl(m, CFrame.new(-R * 0.45, H + 10, R * 0.4), 2.4, 14, MAT.Metal, C.verdigris, { name = "SteamVent" })
  steamJet(vent, 14)
  K.pipe(m, { Vector3.new(-R * 0.45, H + 4, R * 0.4), Vector3.new(-R * 0.8, 30, R * 0.8), Vector3.new(-R * 0.9, 8, R * 0.95) }, 1.4, C.copper)
  K.attrs(m, { Kind = "towerRound", ModuleW = R * 2, ModuleD = R * 2, WallH = WALL_H, Floors = FLOORS })
end
K.build("Castle_TowerRound", nil, function(m) towerRound(m) end)

-- ==================================================== 5. square tower (keep tower)
-- deliberately different from the drum: taller, flat battlemented top, corner turret on one
-- corner only, and a projecting latrine shaft on the back. asymmetry is the point.
local function towerSquare(m)
  local S, FLOORS = 40, 4
  local H = FLOORS * ST
  local WT = 4                                    -- wall thickness; the room inside is S - 2*WT
  local IN = S / 2 - WT                           -- inner face, 16 studs from the centre
  local SX, WELL = -8, { x = -8, z = 0.5, w = 11, d = 30 }
  K.box(m, CFrame.new(0, 3, 0), Vector3.new(S + 8, 6, S + 8), MAT.Rock, STONE_DARK, { name = "Batter" })

  -- Four walls, not one block. The tower used to be a solid cube of stone with four furnished
  -- floors modelled inside it: right from the outside, and unenterable.
  local slits = {}
  for f = 0, FLOORS - 1 do
    for _, t in ipairs({ 0.28, 0.62 }) do
      table.insert(slits, { x = -S / 2 + S * t, w = 3.6, h = 9, sill = f * ST + 8 })
    end
  end
  K.wallRun(m, CFrame.new(0, 6, -(S / 2 - WT / 2)), S, H, WT, MAT.Rock, STONE, slits, { name = "Front" })
  K.wallRun(m, CFrame.new(-(S / 2 - WT / 2), 6, 0) * K.yaw(-math.pi / 2), S, H, WT, MAT.Rock, STONE, slits, { name = "Left" })
  K.wallRun(m, CFrame.new(S / 2 - WT / 2, 6, 0) * K.yaw(math.pi / 2), S, H, WT, MAT.Rock, STONE, {}, { name = "Right" })
  K.wallRun(m, CFrame.new(0, 6, S / 2 - WT / 2) * K.yaw(math.pi), S, H, WT, MAT.Rock, STONE,
    { { x = 0, w = DOOR_W, h = DOOR_H, sill = 0 } }, { name = "Back" })
  K.archOpening(m, CFrame.new(0, 6, S / 2 - WT / 2), DOOR_W, DOOR_H, 2.6, MAT.Rock, STONE:Lerp(C.white, 0.1))
  K.box(m, CFrame.new(0, 6.4, S / 2 + 2), Vector3.new(DOOR_W + 4, 0.8, 8), MAT.Rock, STONE_DARK, { name = "Threshold" })

  -- the facing, with the door and the slits left bare on the faces they are cut into
  local door = { { x = 0, w = DOOR_W, h = DOOR_H, sill = 0 } }
  for _, e in ipairs({ { 0, -S / 2 - 0.7, 0, slits }, { 0, S / 2 + 0.7, math.pi, door },
                       { -S / 2 - 0.7, 0, -math.pi / 2, slits }, { S / 2 + 0.7, 0, math.pi / 2, nil } }) do
    coursedFace(m, CFrame.new(e[1], 6, e[2]) * K.yaw(e[3]), S, H, 1.6, 131 + e[1] * 3 + e[2], STONE, "Face", e[4])
  end
  weather(m, CFrame.new(0, 6, -S / 2 - 1.4), S, H, 17)
  for _, sx in ipairs({ -1, 1 }) do                     -- pilaster buttresses, uneven widths
    K.box(m, CFrame.new(sx * (S / 2 - 3), H / 2 + 6, -S / 2 - 2), Vector3.new(sx > 0 and 9 or 7, H, 4.4), MAT.Rock, STONE:Lerp(C.white, 0.08), { name = "Buttress" })
  end

  for f = 0, FLOORS - 1 do
    local y = 6 + f * ST
    -- the well sits west of centre and the hole is cut in the floor the flight ARRIVES at, so the
    -- ground floor stays solid and the deck reaches the stair's east side to step off onto
    K.floorSlab(m, CFrame.new(0, y, 0), IN * 2, IN * 2, MAT.WoodPlanks, C.plankDark,
      { name = "TowerFloor", hole = f > 0 and WELL or nil })
    if f < FLOORS then                      -- the last flight climbs to the fighting deck itself
      K.stairFlight(m, CFrame.new(SX, y, -12), 9, ST, MAT.Rock, STONE_DARK, { railColor = C.iron, open = true, run = 24 })
    end
    if f > 0 then
      K.railing(m, CFrame.new(WELL.x, y, WELL.z - WELL.d / 2 + 0.1), WELL.w, 5, C.iron, MAT.Metal)
    end
    for _, t in ipairs({ 0.28, 0.62 }) do
      K.arrowSlit(m, CFrame.new(-S / 2 + S * t, y + 8, -S / 2 - 1.3), { stone = STONE })
      K.arrowSlit(m, CFrame.new(-S / 2 - 1.3, y + 8, -S / 2 + S * t) * K.yaw(-math.pi / 2), { stone = STONE })
    end
    K.chain(m, Vector3.new(8, y + ST - 1, 0), Vector3.new(8, y + ST - 5, 0), 3, 0.2)
    K.lantern(m, CFrame.new(8, y + ST - 9, 0), 4)
    if f == 0 then
      K.fireplace(m, CFrame.new(IN - 2, y, 0) * K.yaw(-math.pi / 2), 14, 17, C.darkStone)
      K.table(m, CFrame.new(5, y, 2), 10, 10, 5.2, C.oak)
      for _, x in ipairs({ -1, 11 }) do
        K.box(m, CFrame.new(x, y + 2.9, 2), Vector3.new(3.4, 0.8, 9), MAT.WoodPlanks, C.plankDark, { name = "Bench" })
      end
      K.rug(m, CFrame.new(5, y + 0.1, 2), 18, 14, rgb(112, 44, 48))
    elseif f == 1 then
      for _, bz in ipairs({ -8, 8 }) do K.bed(m, CFrame.new(7, y, bz), 8, 15, C.wood, C.canvas) end
      K.chest(m, CFrame.new(14, y, 0), 3)
      K.shelf(m, CFrame.new(IN - 1, y, -12) * K.yaw(math.pi / 2), 10, 14, 4, C.plankDark, 4)
    elseif f == 2 then
      K.counter(m, CFrame.new(4, y, IN - 3) * K.yaw(math.pi), 20, 5, 6.4, C.plankDark)
      K.table(m, CFrame.new(6, y, 0), 10, 10, 5.2, C.plank)
      for i = 0, 3 do K.barrel(m, CFrame.new(2 + (i % 2) * 9, y, -9 - math.floor(i / 2) * 5), 2.6, 6, i % 2 == 0 and C.wood or C.oak) end
    else
      for i = 0, 5 do K.crate(m, CFrame.new(1 + (i % 3) * 6, y, -12 + math.floor(i / 3) * 24), 5.4) end
      K.box(m, CFrame.new(8, y + 14, 0), Vector3.new(1.2, 1.2, 24), MAT.Wood, C.wood, { name = "HoistBeam", cancollide = false })
      K.chain(m, Vector3.new(8, y + 13.4, 0), Vector3.new(8, y + 5, 0), 7, 0.24)
    end
  end

  -- latrine shaft corbelled off the back wall: small, ugly, and exactly the sort of detail
  -- that makes stonework read as built rather than modelled
  K.box(m, CFrame.new(S * 0.28, H * 0.62, S / 2 + 3.4), Vector3.new(9, 14, 7), MAT.Rock, STONE:Lerp(C.black, 0.1), { name = "LatrineShaft" })
  for i = 0, 2 do
    K.wedge(m, CFrame.new(S * 0.28 - 3 + i * 3, H * 0.62 - 8, S / 2 + 5.4), Vector3.new(2.6, 4, 6), MAT.Rock, STONE)
  end
  K.box(m, CFrame.new(S * 0.28, H * 0.62 - 6.6, S / 2 + 6.8), Vector3.new(2.6, 1.4, 2.6), MAT.SmoothPlastic, C.black, { name = "Chute", cancollide = false })

  -- flat fighting top, with a stair turret on ONE corner only
  K.roofBattlement(m, CFrame.new(0, H + 6, 0), S, S, { color = STONE_DARK, merlon = 8, step = 8.5, overhang = 3.4, hole = WELL })
  -- corbelled off the OUTSIDE of the corner. Standing on the inside, it used to be a stone column
  -- through the middle of the stairwell.
  local tx, tz = -(S / 2 + 2), S / 2 + 2
  K.cyl(m, CFrame.new(tx, H / 2 + 6, tz), 8, H + 16, MAT.Rock, STONE:Lerp(C.white, 0.05), { name = "StairTurret" })
  K.roofCone(m, CFrame.new(tx, H + 22, tz), 9.4, 14, MAT.Slate, C.slateRoof, 8)
  for f = 0, FLOORS do K.arrowSlit(m, CFrame.new(tx - 7.6, 14 + f * ST, tz) * K.yaw(-math.pi / 2), { stone = STONE }) end
  K.banner(m, CFrame.new(S / 2 - 7, H + 8, -S / 2 + 7), 9, 18, rgb(60, 74, 130), 26)
  local chim = K.box(m, CFrame.new(-6, H + 20, S / 2 - 2), Vector3.new(8, 26, 7), MAT.Rock, STONE:Lerp(C.black, 0.16), { name = "Chimney" })
  K.box(m, CFrame.new(-6, H + 34, S / 2 - 2), Vector3.new(10, 2, 9), MAT.Slate, C.darkStone, { name = "ChimneyCap" })
  smoke(chim, rgb(112, 110, 106), 8)
  K.attrs(m, { Kind = "towerSquare", ModuleW = S, ModuleD = S, WallH = WALL_H, Floors = FLOORS })
end
K.build("Castle_TowerSquare", nil, function(m) towerSquare(m) end)

-- ============================================================ 6. roof type kit
-- six roofs on identical stub walls, so a shape can be picked by looking rather than guessing
K.build("Castle_RoofKit", nil, function(m)
  local W, D, H = 34, 26, 16
  local kinds = {
    { "จั่ว gable", function(cf) K.roofGable(m, cf, W, D, 16, MAT.RoofShingles, rgb(126, 74, 58), 3) end },
    { "ปั้นหยา hip", function(cf) K.roofHip(m, cf, W, D, 15, MAT.RoofShingles, rgb(118, 96, 70), 3) end },
    { "พีระมิด pyramid", function(cf) K.roofPyramid(m, cf, W, D, 18, MAT.Slate, C.slateRoof, 3) end },
    { "แมนซาร์ด mansard", function(cf) K.roofMansard(m, cf, W, D, 20, MAT.Slate, rgb(86, 92, 100), 3) end },
    { "โค้ง barrel", function(cf) K.roofBarrel(m, cf, W, D, 14, MAT.Metal, C.verdigris, 10) end },
    { "ใบเสมา battlement", function(cf) K.roofBattlement(m, cf, W, D, { color = STONE_DARK, merlon = 7, step = 7.5, overhang = 2.6 }) end },
  }
  for i, kind in ipairs(kinds) do
    local x = (i - 3.5) * (W + 16)
    local o = CFrame.new(x, 0, 0)
    K.box(m, o * CFrame.new(0, -1, 0), Vector3.new(W + 6, 2, D + 6), MAT.Cobblestone, C.darkStone, { name = "Plinth" })
    K.floorSlab(m, o, W, D, MAT.WoodPlanks, C.plankDark)
    K.wallRun(m, o * CFrame.new(0, 0, -D / 2), W, H, 2, MAT.Rock, STONE, { { x = 0, w = 12, h = 14 } }, { name = "Front" })
    K.wallRun(m, o * CFrame.new(0, 0, D / 2) * K.yaw(math.pi), W, H, 2, MAT.Rock, STONE, {}, { name = "Back" })
    K.wallRun(m, o * CFrame.new(-W / 2, 0, 0) * K.yaw(-math.pi / 2), D, H, 2, MAT.Rock, STONE, { { x = 0, w = 8, h = 9, sill = 4 } }, { name = "Left" })
    K.wallRun(m, o * CFrame.new(W / 2, 0, 0) * K.yaw(math.pi / 2), D, H, 2, MAT.Rock, STONE, { { x = 0, w = 8, h = 9, sill = 4 } }, { name = "Right" })
    kind[2](o * CFrame.new(0, H, 0))
    K.sign(m, o * CFrame.new(0, 3, -D / 2 - 4.4), kind[1], W - 4, 5, rgb(40, 40, 44), rgb(238, 226, 196))
    K.lantern(m, o * CFrame.new(0, H - 9, 0), 4)
  end
end)

-- ==================================================== 7. a worked assembly run
-- proof that the modules tile: corner, three wall sections, a gate, three more, another corner,
-- with drum towers straddling two of the joints. this is the pattern an assembly script follows.
K.build("Castle_Assembly", { pad = false }, function(m)
  local x = 0
  local function put(builder, dx, kind)
    local sub = K.model(m, kind)
    builder(sub)
    sub.WorldPivot = CFrame.new(0, 0, 0)
    sub:PivotTo(CFrame.new(x + dx, 0, 0))
    return sub
  end
  local S = MOD * 0.72
  put(wallCorner, S / 2, "Corner_W"); x += S
  for i = 1, 3 do put(function(sub) wallStraight(sub) end, MOD / 2, "Wall_" .. i); x += MOD end
  put(towerRound, 0, "Tower_A")                    -- straddles the joint, no advance
  put(wallGate, 84 / 2, "Gate"); x += 84
  put(towerRound, 0, "Tower_B")
  for i = 4, 6 do put(function(sub) wallStraight(sub) end, MOD / 2, "Wall_" .. i); x += MOD end
  put(towerSquare, 20, "Tower_Keep"); x += 40
  put(wallCorner, S / 2, "Corner_E")
  K.attrs(m, { Kind = "assembly", RunLength = x + S })
end)
