-- village — the landmark buildings, sized so a Roblox character can run and jump inside them.
--
-- scale: storey height 26 (a character is ~5.5 tall and jumps ~7.5, so this is roughly four
-- times head height), doorways 12 x 18 on swinging auto-doors, windows 9 x 11 on a 7 stud sill.
-- footprints are about double what they were, and every upper floor has a stairwell cut through
-- it so the flight below has headroom and you can actually walk up.
--
-- no ground, no terrain: buildings only, each on its own pad. front faces -Z.
K.SET = "vlm"
K.SLOT = 190
K.PER_ROW = 3
K.ORIGIN = Vector3.new(0, 0, 600)

local C = K.C
local MAT = K.MAT
local rgb = Color3.fromRGB
local BRASS = rgb(205, 140, 45)
local ST = 26                    -- floor to ceiling
local DOOR_W, DOOR_H = 12, 18
local WIN_W, WIN_H, SILL = 9, 11, 7

local function glow(part, color, range, brightness)
  local l = Instance.new("PointLight")
  l.Color = color or C.lamp; l.Range = range or 26; l.Brightness = brightness or 1.5; l.Parent = part
  return l
end
local function smoke(part, color, size)
  local s = Instance.new("Smoke")
  s.Size = size or 6; s.RiseVelocity = 8; s.Opacity = 0.22; s.Color = color or rgb(104, 102, 98); s.Parent = part
  return s
end
local function steamJet(part, rate, color)
  local e = Instance.new("ParticleEmitter")
  e.Name = "SteamJet"
  e.Color = ColorSequence.new(color or rgb(226, 234, 242))
  e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 4) })
  e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
  e.Lifetime = NumberRange.new(1.6, 3); e.Rate = rate or 10
  e.Speed = NumberRange.new(3, 6); e.SpreadAngle = Vector2.new(12, 12)
  e.EmissionDirection = Enum.NormalId.Top; e.Parent = part
  return e
end
local function plinth(m, w, d, h)
  K.box(m, CFrame.new(0, -(h or 2) / 2, 0), Vector3.new(w, h or 2, d), MAT.Cobblestone, C.darkStone, { name = "Plinth" })
end
local function walls4(m, o, w, d, h, thick, mat, col, front, back, left, right, tag)
  K.wallRun(m, o * CFrame.new(0, 0, -d / 2), w, h, thick, mat, col, front, { name = (tag or "") .. "Front" })
  K.wallRun(m, o * CFrame.new(0, 0, d / 2) * K.yaw(math.pi), w, h, thick, mat, col, back, { name = (tag or "") .. "Back" })
  K.wallRun(m, o * CFrame.new(-w / 2, 0, 0) * K.yaw(-math.pi / 2), d, h, thick, mat, col, left, { name = (tag or "") .. "Left" })
  K.wallRun(m, o * CFrame.new(w / 2, 0, 0) * K.yaw(math.pi / 2), d, h, thick, mat, col, right, { name = (tag or "") .. "Right" })
end
local function crenellate(m, cf, len, step, size, mat, col)
  for i = 0, math.floor(len / step) do
    K.box(m, cf * CFrame.new(-len / 2 + i * step, size / 2, 0), Vector3.new(step * 0.55, size, size * 0.8), mat, col, { name = "Merlon", cancollide = false })
  end
end
local function win(x, sill) return { x = x, w = WIN_W, h = WIN_H, sill = sill or SILL } end
-- one flight plus the stairwell hole the floor above needs. x/z are in the same local frame
-- the floor slab above is drawn in, so the hole lands exactly over the flight.
local function flight(m, x, y, z, width, rise, mat, col, railCol)
  local run = K.stairFlight(m, CFrame.new(x, y, z), width, rise, mat, col, { railColor = railCol })
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

-- ================================================ 1. กองอัศวิน — the garrison
-- keep + gatehouse thrown forward + round stair tower behind + a prison block wing
local function garrison(m)
  local W, D = 64, 46
  plinth(m, W + 80, D + 96, 2.2)
  local stone = rgb(168, 164, 154)

  -- ---- keep: three storeys
  K.floorSlab(m, CFrame.new(0, 0, 0), W, D, MAT.Slate, C.stone, { name = "HallFloor" })
  walls4(m, CFrame.new(0, 0, 0), W, D, ST, 3, MAT.Sandstone, stone,
    { { x = -10, w = DOOR_W + 4, h = DOOR_H + 2 }, win(14), win(26) },
    { win(-22), { x = 12, w = DOOR_W, h = DOOR_H } },
    { win(-10), win(10) }, { { x = 0, w = DOOR_W, h = DOOR_H } }, "G")
  local hole1 = flight(m, W / 2 - 13, 0, -D / 2 + 6, 11, ST, MAT.Sandstone, stone, C.iron)
  K.floorSlab(m, CFrame.new(0, ST, 0), W, D, MAT.WoodPlanks, C.plankDark, { name = "BarrackFloor", hole = hole1 })
  K.railing(m, CFrame.new(hole1.x, ST, hole1.z + hole1.d / 2 - 0.5), hole1.w, 5, C.iron, MAT.Metal)
  walls4(m, CFrame.new(0, ST, 0), W, D, ST, 3, MAT.Sandstone, stone,
    { win(-24), win(-8), win(8), win(24) }, { win(-18), win(18) }, { win(0) }, { win(0) }, "F1")
  local hole2 = flight(m, -W / 2 + 13, ST, -D / 2 + 6, 11, ST, MAT.WoodPlanks, C.plankDark)
  K.floorSlab(m, CFrame.new(0, ST * 2, 0), W, D, MAT.WoodPlanks, C.plankDark, { name = "CaptainFloor", hole = hole2 })
  K.railing(m, CFrame.new(hole2.x, ST * 2, hole2.z + hole2.d / 2 - 0.5), hole2.w, 5, C.iron, MAT.Metal)
  walls4(m, CFrame.new(0, ST * 2, 0), W, D, ST - 4, 3, MAT.Sandstone, stone,
    { win(-14, 6), win(14, 6) }, { win(0, 6) }, { win(0, 6) }, {}, "F2")

  K.box(m, CFrame.new(0, ST * 3 - 4, 0), Vector3.new(W + 4, 2, D + 4), MAT.Slate, C.darkStone, { name = "Walk" })
  for _, sz in ipairs({ -1, 1 }) do crenellate(m, CFrame.new(0, ST * 3 - 3, sz * (D / 2 + 1.6)), W + 4, 7, 4.6, MAT.Sandstone, stone) end
  for _, sx in ipairs({ -1, 1 }) do crenellate(m, CFrame.new(sx * (W / 2 + 1.6), ST * 3 - 3, 0) * K.yaw(math.pi / 2), D + 4, 7, 4.6, MAT.Sandstone, stone) end

  -- ---- round stair tower behind, climbing to the battlement
  local so = CFrame.new(W / 2 - 8, 0, D / 2 + 13)
  K.cyl(m, so * CFrame.new(0, ST * 1.6, 0), 13, ST * 3.2, MAT.Sandstone, stone:Lerp(C.black, 0.06), { name = "StairTower" })
  K.roofCone(m, so * CFrame.new(0, ST * 3.2, 0), 14.6, 16, MAT.Slate, C.slateRoof, 9)
  for i = 0, 2 do
    K.window(m, so * CFrame.new(0, 9 + i * ST, -12.9), 4, 7, C.iron, true)
    -- the tower is only 26 across, so the flight gets an explicit short run and the landing
    -- hole is placed over where it actually ends. all three climb the same way, not alternating.
    K.stairFlight(m, so * CFrame.new(0, i * ST, -10), 9, ST, MAT.Sandstone, stone, { railColor = C.iron, run = 21 })
    K.floorSlab(m, so * CFrame.new(0, (i + 1) * ST, 0), 24, 24, MAT.Slate, C.stone,
      { name = "Landing", hole = { x = 0, z = 1, w = 13, d = 28 } })
  end

  -- ---- gatehouse wing thrown forward on the left
  local go = CFrame.new(-W / 2 + 8, 0, -D / 2 - 17)
  K.floorSlab(m, go, 34, 30, MAT.Slate, C.stone, { name = "GateFloor" })
  walls4(m, go, 34, 30, ST + 8, 3, MAT.Sandstone, stone:Lerp(C.white, 0.05),
    { { x = 0, w = 18, h = 24 } }, { { x = 0, w = 18, h = 24 } },
    { win(-4, 9) }, { { x = 6, w = DOOR_W + 2, h = DOOR_H } }, "Gate")
  K.box(m, go * CFrame.new(0, ST + 8, 0), Vector3.new(38, 2, 34), MAT.Slate, C.darkStone, { name = "GateWalk" })
  crenellate(m, go * CFrame.new(0, ST + 9, -17), 38, 7, 4.6, MAT.Sandstone, stone)
  crenellate(m, go * CFrame.new(0, ST + 9, 17), 38, 7, 4.6, MAT.Sandstone, stone)
  for _, sx in ipairs({ -1, 1 }) do crenellate(m, go * CFrame.new(sx * 19, ST + 9, 0) * K.yaw(math.pi / 2), 34, 7, 4.6, MAT.Sandstone, stone) end
  K.box(m, go * CFrame.new(0, 25.4, -15.4), Vector3.new(22, 2.4, 1.6), MAT.Metal, C.brassDark, { name = "PortcullisRail" })
  for i = 0, 9 do K.cyl(m, go * CFrame.new(-8.8 + i * 1.96, 29, -15.6), 0.4, 7, MAT.Metal, C.iron, { name = "Bar", cancollide = false }) end
  K.box(m, go * CFrame.new(0, 32.6, -15.6), Vector3.new(21, 1, 1), MAT.Metal, C.iron, { name = "PortcullisBeam" })
  K.gear(m, go * CFrame.new(-13, 32.8, -16), 4.4, 16, 1.2, BRASS)
  K.gear(m, go * CFrame.new(-13, 39, -16), 2.6, 10, 1.2, C.copper)
  K.chain(m, (go * CFrame.new(-13, 36, -16)).Position, (go * CFrame.new(-8, 32.8, -15.6)).Position, 7, 0.26)
  K.boiler(m, go * CFrame.new(-12, ST + 14, 8), 3.6, 14, { bands = 3, firebox = true })
  K.valveWheel(m, go * CFrame.new(-7.4, ST + 17, 8), 2.4, 5)

  -- ---- turrets: only the left one carries a spire
  local tl = CFrame.new(-W / 2 - 2, 0, -D / 2 - 2)
  K.cyl(m, tl * CFrame.new(0, ST * 1.9, 0), 11, ST * 3.8, MAT.Sandstone, stone, { name = "TurretL" })
  K.roofCone(m, tl * CFrame.new(0, ST * 3.8, 0), 13, 20, MAT.Slate, C.slateRoof, 10)
  K.banner(m, tl * CFrame.new(0, ST * 3.8 + 20, 0), 8, 16, rgb(150, 40, 44), 22)
  for i = 0, 2 do K.window(m, tl * CFrame.new(0, 10 + i * ST, -10.9), 3.4, 8, C.iron, true) end
  local tr = CFrame.new(W / 2 + 2, 0, -D / 2 - 2)
  K.cyl(m, tr * CFrame.new(0, ST * 1.5, 0), 10, ST * 3, MAT.Sandstone, stone, { name = "TurretR" })
  K.box(m, tr * CFrame.new(0, ST * 3, 0), Vector3.new(24, 2, 24), MAT.Slate, C.darkStone, { name = "TurretRDeck" })
  for i = 0, 3 do
    local a = i * math.pi / 2
    crenellate(m, tr * CFrame.new(math.cos(a) * 11, ST * 3 + 1, math.sin(a) * 11) * K.yaw(math.pi / 2 - a), 24, 6, 4.4, MAT.Sandstone, stone)
  end

  -- ---- prison block: its own wing, one tall storey, four communal cells
  local po = CFrame.new(W / 2 + 34, 0, 12)
  local PW, PD, PH = 48, 42, 30
  K.floorSlab(m, po, PW, PD, MAT.Slate, rgb(104, 100, 96), { name = "PrisonFloor" })
  walls4(m, po, PW, PD, PH, 3.4, MAT.Rock, rgb(126, 122, 116),
    { { x = -12, w = DOOR_W + 2, h = DOOR_H } },
    { { x = -14, w = 6, h = 6, sill = 21 }, { x = 0, w = 6, h = 6, sill = 21 }, { x = 14, w = 6, h = 6, sill = 21 } },
    { { x = 0, w = DOOR_W, h = DOOR_H } },
    { { x = -12, w = 6, h = 6, sill = 21 }, { x = 12, w = 6, h = 6, sill = 21 } }, "Prison")
  K.roofGable(m, po * CFrame.new(0, PH, 0), PW, PD, 15, MAT.Slate, C.slateRoof, 3)
  K.autoDoor(m, po * CFrame.new(-12, 0, -PD / 2 - 1.6), DOOR_W + 2, DOOR_H, { color = C.iron, mat = MAT.Metal })
  for _, x in ipairs({ -14, 0, 14 }) do K.bars(m, po * CFrame.new(x, 21, PD / 2 + 1.4), 6, 6, { spacing = 1.6 }) end

  local cellW, cellD = 10.5, 16
  for i = 0, 3 do
    local cx = -PW / 2 + 7 + i * (cellW + 1.6)
    local co = po * CFrame.new(cx, 0, PD / 2 - cellD / 2 - 1.8)
    K.box(m, co * CFrame.new(-cellW / 2 - 0.8, PH / 2, 0), Vector3.new(1.6, PH, cellD), MAT.Rock, rgb(112, 108, 104), { name = "CellWall" })
    if i == 3 then K.box(m, co * CFrame.new(cellW / 2 + 0.8, PH / 2, 0), Vector3.new(1.6, PH, cellD), MAT.Rock, rgb(112, 108, 104), { name = "CellWall" }) end
    K.bars(m, co * CFrame.new(-cellW * 0.3, 0, -cellD / 2), cellW * 0.4, 21, { spacing = 1.8 })
    K.cellDoor(m, co * CFrame.new(cellW * 0.24, 0, -cellD / 2), cellW * 0.46, 19)
    K.box(m, co * CFrame.new(0, 25, -cellD / 2), Vector3.new(cellW, PH - 21, 1.2), MAT.Rock, rgb(112, 108, 104), { name = "CellHead" })
    for _, s in ipairs({ -1, 1 }) do
      K.box(m, co * CFrame.new(s * (cellW / 2 - 2.8), 5, 2.4), Vector3.new(4.8, 1, 11), MAT.WoodPlanks, C.plankDark, { name = "Bunk" })
      K.box(m, co * CFrame.new(s * (cellW / 2 - 2.8), 6.1, 2.4), Vector3.new(4.4, 1.2, 10), MAT.Fabric, C.thatch, { name = "Straw", cancollide = false })
      K.box(m, co * CFrame.new(s * (cellW / 2 - 2.8), 13, 2.4), Vector3.new(4.8, 1, 11), MAT.WoodPlanks, C.plankDark, { name = "BunkUpper" })
      K.box(m, co * CFrame.new(s * (cellW / 2 - 2.8), 14.1, 2.4), Vector3.new(4.4, 1.2, 10), MAT.Fabric, C.thatch, { name = "Straw", cancollide = false })
      K.cyl(m, co * CFrame.new(s * (cellW / 2 - 2.8), 9.5, -3), 0.35, 9, MAT.Metal, C.iron, { name = "BunkPost", cancollide = false })
    end
    K.barrel(m, co * CFrame.new(0, 0, -cellD / 2 + 3.4), 1.5, 3, C.iron)
    K.box(m, co * CFrame.new(0, 0.4, 5), Vector3.new(7, 0.6, 7), MAT.Fabric, C.thatch:Lerp(C.black, 0.2), { name = "FloorStraw", cancollide = false })
    K.lantern(m, co * CFrame.new(0, 21, 0), 3, rgb(255, 190, 120))
  end
  K.counter(m, po * CFrame.new(14, 0, -PD / 2 + 9) * K.yaw(math.pi), 18, 5, 6.5, C.plankDark)
  K.table(m, po * CFrame.new(-4, 0, -PD / 2 + 10), 12, 8, 5, C.oak)
  K.chair(m, po * CFrame.new(-4, 0, -PD / 2 + 17) * K.yaw(math.pi))
  K.chair(m, po * CFrame.new(-11, 0, -PD / 2 + 10))
  K.cyl(m, po * CFrame.new(18, 3, 2), 3, 6, MAT.Metal, C.iron, { name = "Brazier" })
  local bfire = K.box(m, po * CFrame.new(18, 6.6, 2), Vector3.new(4.4, 1.6, 4.4), MAT.Neon, C.ember, { name = "BrazierFire", cancollide = false })
  glow(bfire, C.ember, 40, 2.6)
  K.box(m, po * CFrame.new(20, 15, -PD / 2 + 2.6), Vector3.new(9, 9, 0.6), MAT.WoodPlanks, C.plankDark, { name = "KeyBoard" })
  for i = 0, 4 do K.cyl(m, po * CFrame.new(16.4 + i * 1.8, 16, -PD / 2 + 2.1), 0.8, 0.35, MAT.Metal, BRASS, { name = "KeyRing", cancollide = false }) end
  ceilingLamps(m, po * CFrame.new(0, PH - 1, 0), { -14, 14 }, { -10, 8 }, 4, rgb(255, 196, 130))
  K.sign(m, po * CFrame.new(-12, DOOR_H + 6, -PD / 2 - 2.8), "อาคารนักโทษ", 22, 5.4, rgb(40, 38, 40), rgb(228, 208, 160))

  -- ---- keep interiors
  K.autoDoor(m, CFrame.new(-10, 0, -D / 2 - 1.8), DOOR_W + 4, DOOR_H + 2, { color = C.wood })
  K.fireplace(m, CFrame.new(-22, 0, D / 2 - 3) * K.yaw(math.pi), 20, 20, C.darkStone)
  local chim = K.box(m, CFrame.new(-22, ST * 3 + 12, D / 2 + 2), Vector3.new(10, ST * 3, 8), MAT.Sandstone, stone:Lerp(C.black, 0.15), { name = "HallChimney" })
  K.box(m, CFrame.new(-22, ST * 3 + 40, D / 2 + 2), Vector3.new(12, 2, 10), MAT.Slate, C.darkStone, { name = "ChimneyCap" })
  smoke(chim, rgb(112, 110, 106), 8)
  K.table(m, CFrame.new(0, 0, 4), 40, 11, 5.2, C.plank)
  for _, z in ipairs({ -4.6, 12.6 }) do
    K.box(m, CFrame.new(0, 2.9, z), Vector3.new(38, 0.7, 3.4), MAT.WoodPlanks, C.plankDark, { name = "Bench" })
    K.box(m, CFrame.new(0, 1.45, z), Vector3.new(37, 2.9, 0.7), MAT.Wood, C.wood, { name = "BenchLeg" })
  end
  K.rug(m, CFrame.new(0, 0.1, 4), 46, 22, rgb(112, 44, 48))
  for i = 0, 4 do
    local z = -14 + i * 7
    K.box(m, CFrame.new(W / 2 - 4, 6, z), Vector3.new(2.4, 12, 5), MAT.WoodPlanks, C.plankDark, { name = "ArmourRack" })
    K.box(m, CFrame.new(W / 2 - 6, 8, z), Vector3.new(1.4, 7, 4), MAT.Metal, C.steel, { name = "Breastplate", cancollide = false })
    K.ball(m, CFrame.new(W / 2 - 6, 12.6, z), 3, MAT.Metal, C.steel, { name = "Helm", cancollide = false })
  end
  for i = 0, 6 do
    local z = -18 + i * 6
    K.cyl(m, CFrame.new(-W / 2 + 3.4, 9, z), 0.3, 18, MAT.Wood, C.plankDark, { name = "Spear", cancollide = false })
    K.wedge(m, CFrame.new(-W / 2 + 3.4, 19, z) * K.yaw(math.pi / 2), Vector3.new(0.5, 3, 1.6), MAT.Metal, C.steel)
  end
  ceilingLamps(m, CFrame.new(0, ST - 1, 0), { -18, 0, 18 }, { -10, 10 }, 4)
  for i = 0, 4 do                                    -- five bunks a side; the sixth used to sit in the stairwell
    local x = -26 + i * 9
    K.bed(m, CFrame.new(x, ST, -D / 2 + 12), 8, 15, C.wood, C.canvas)
    K.bed(m, CFrame.new(x, ST, D / 2 - 12) * K.yaw(math.pi), 8, 15, C.wood, C.canvas)
    K.chest(m, CFrame.new(x + 6, ST, -D / 2 + 12), 3)
    K.chest(m, CFrame.new(x + 6, ST, D / 2 - 12), 3)
  end
  ceilingLamps(m, CFrame.new(0, ST * 2 - 1, 0), { -16, 16 }, { 0 }, 4)
  K.table(m, CFrame.new(-8, ST * 2, 0), 20, 13, 5.2, C.oak)
  K.box(m, CFrame.new(-8, ST * 2 + 5.6, 0), Vector3.new(19, 0.3, 12), MAT.Fabric, C.canvas, { name = "MapCloth", cancollide = false })
  K.chair(m, CFrame.new(-8, ST * 2, 10) * K.yaw(math.pi))
  K.chair(m, CFrame.new(-18, ST * 2, -6))
  K.shelf(m, CFrame.new(16, ST * 2, D / 2 - 2.6) * K.yaw(math.pi), 22, 16, 4, C.plankDark, 4)
  K.bed(m, CFrame.new(22, ST * 2, -10) * K.yaw(-math.pi / 2), 8, 15, C.oak)
  K.rug(m, CFrame.new(-8, ST * 2 + 0.1, 0), 26, 18, rgb(70, 60, 96))
  ceilingLamps(m, CFrame.new(0, ST * 3 - 5, 0), { -10, 10 }, { 0 }, 4)

  -- ---- training yard
  K.box(m, CFrame.new(6, 0.4, -D / 2 - 42), Vector3.new(64, 0.8, 38), MAT.Ground, C.soil, { name = "Yard" })
  for i = 0, 2 do
    local x = -2 + i * 13
    K.cyl(m, CFrame.new(x, 6, -D / 2 - 46), 1.4, 12, MAT.Wood, C.plankDark, { name = "DummyPost" })
    K.box(m, CFrame.new(x, 12.6, -D / 2 - 46), Vector3.new(9, 2, 2), MAT.Fabric, C.thatch, { name = "DummyArms" })
    K.ball(m, CFrame.new(x, 15, -D / 2 - 46), 4, MAT.Fabric, C.thatch, { name = "DummyHead" })
  end
  K.box(m, CFrame.new(28, 4.4, -D / 2 - 36), Vector3.new(14, 1, 2.4), MAT.Wood, C.wood, { name = "RackTop" })
  for _, s in ipairs({ -1, 1 }) do K.box(m, CFrame.new(28 + s * 6, 2.2, -D / 2 - 36), Vector3.new(1, 4.4, 2), MAT.Wood, C.wood, { name = "RackLeg" }) end
  for i = 0, 5 do
    local x = 22 + i * 2.4
    K.box(m, CFrame.new(x, 8, -D / 2 - 36), Vector3.new(0.5, 8, 0.5), MAT.Wood, C.plankDark, { name = "Haft", cancollide = false })
    K.wedge(m, CFrame.new(x, 12.6, -D / 2 - 36) * K.yaw(math.pi / 2), Vector3.new(0.6, 3, 1.8), MAT.Metal, C.steel)
  end
  K.sign(m, go * CFrame.new(0, ST + 13, -17.6), "กองอัศวิน", 26, 6.4, rgb(44, 40, 42), rgb(238, 214, 152))
  K.lampPost(m, CFrame.new(-W / 2 - 20, 0, -D / 2 - 38), 18, rgb(255, 200, 130))
  K.lampPost(m, CFrame.new(W / 2 + 16, 0, -D / 2 - 38), 18, rgb(255, 200, 130))
end
K.build("Village_Knights", nil, function(m) garrison(m) end)

-- =================================================== 2. โรงหมอ — the clinic
local function clinic(m)
  local W, D = 56, 44
  plinth(m, W + 44, D + 36, 2)
  local plaster, beam = C.plaster, rgb(96, 118, 96)

  K.floorSlab(m, CFrame.new(0, 0, 0), W, D, MAT.CeramicTiles, rgb(226, 224, 216), { name = "WardFloor" })
  walls4(m, CFrame.new(0, 0, 0), W, D, ST, 2.4, MAT.Plaster, plaster,
    { { x = -12, w = DOOR_W + 2, h = DOOR_H }, win(8), win(22) },
    { win(-18), win(0), win(18) },
    { win(-12), win(6) }, { { x = 4, w = DOOR_W, h = DOOR_H }, win(-14) }, "G")
  local hole = flight(m, W / 2 - 12, 0, -D / 2 + 7, 11, ST, MAT.WoodPlanks, C.plankDark)
  K.floorSlab(m, CFrame.new(0, ST, 0), W, D, MAT.WoodPlanks, C.plank, { name = "UpperFloor", hole = hole })
  K.railing(m, CFrame.new(hole.x, ST, hole.z + hole.d / 2 - 0.5), hole.w, 5, C.wood)
  walls4(m, CFrame.new(0, ST, 0), W, D, ST - 2, 2.4, MAT.Plaster, plaster,
    { win(-18), win(-2), win(14) }, { win(-10), win(12) }, { win(0) }, { win(0) }, "F1")
  K.timberWall(m, CFrame.new(0, 0, -D / 2 - 1.3), W, ST, 0.5, plaster, beam)
  K.timberWall(m, CFrame.new(0, ST, -D / 2 - 1.3), W, ST - 2, 0.5, plaster, beam)
  K.timberWall(m, CFrame.new(-W / 2 - 1.3, ST, 0) * K.yaw(-math.pi / 2), D, ST - 2, 0.5, plaster, beam)
  K.timberWall(m, CFrame.new(W / 2 + 1.3, ST, 0) * K.yaw(math.pi / 2), D, ST - 2, 0.5, plaster, beam)
  K.roofGable(m, CFrame.new(0, ST * 2 - 2, 0), W, D, 22, MAT.Slate, beam:Lerp(C.black, 0.25), 4)
  K.dormer(m, CFrame.new(-14, ST * 2 + 2, -D / 2 + 7), 13, 10, 12, MAT.Plaster, plaster, MAT.Slate, beam:Lerp(C.black, 0.25))
  K.dormer(m, CFrame.new(10, ST * 2 + 2, -D / 2 + 7), 11, 9, 11, MAT.Plaster, plaster, MAT.Slate, beam:Lerp(C.black, 0.25))

  -- patient hall: twelve beds behind curtain rails, wide aisle down the middle
  K.autoDoor(m, CFrame.new(-12, 0, -D / 2 - 1.4), DOOR_W + 2, DOOR_H, { color = beam })
  for i = 0, 5 do
    local z = -D / 2 + 9 + i * 6.4
    for _, s in ipairs({ -1, 1 }) do
      K.bed(m, CFrame.new(s * (W / 2 - 10), 0, z) * K.yaw(s > 0 and -math.pi / 2 or math.pi / 2), 8, 15, C.white, rgb(206, 220, 226))
      K.box(m, CFrame.new(s * (W / 2 - 3.4), 2.6, z), Vector3.new(4, 5.2, 4), MAT.WoodPlanks, C.plankDark, { name = "Nightstand" })
      local vial = K.cyl(m, CFrame.new(s * (W / 2 - 3.4), 6.2, z), 0.8, 2.2, MAT.Neon, rgb(150, 230, 180), { name = "Draught", cancollide = false })
      glow(vial, rgb(150, 230, 180), 8, 0.8)
      if i < 5 then
        K.box(m, CFrame.new(s * (W / 2 - 10), 15, z + 3.2), Vector3.new(15, 0.4, 0.4), MAT.Metal, C.brassDark, { name = "CurtainRail", cancollide = false })
        K.box(m, CFrame.new(s * (W / 2 - 10), 10, z + 3.2), Vector3.new(14, 10, 0.2), MAT.Fabric, rgb(198, 214, 208), { name = "Curtain", cancollide = false })
      end
    end
  end
  K.table(m, CFrame.new(0, 0, D / 2 - 11), 16, 9, 5.4, C.white, MAT.SmoothPlastic)
  K.box(m, CFrame.new(0, 6, D / 2 - 11), Vector3.new(15, 0.4, 8), MAT.Fabric, C.white, { name = "Sheet", cancollide = false })
  K.counter(m, CFrame.new(16, 0, D / 2 - 3) * K.yaw(math.pi), 24, 5, 6.4, C.plankDark)
  K.shelf(m, CFrame.new(16, 0, D / 2 - 1.4) * K.yaw(math.pi), 24, 16, 3.6, C.plankDark, 5)
  for i = 0, 8 do
    local v = K.cyl(m, CFrame.new(6 + i * 2.4, 7, D / 2 - 6), 0.8, 2.8, MAT.Neon,
      ({ rgb(120, 255, 140), rgb(140, 200, 255), rgb(255, 170, 90), rgb(210, 130, 255), rgb(120, 255, 140), rgb(255, 220, 120), rgb(150, 255, 220), rgb(255, 140, 170), rgb(180, 255, 120) })[i + 1],
      { name = "Vial", cancollide = false })
    glow(v, v.Color, 9, 1)
  end
  K.rug(m, CFrame.new(0, 0.1, 0), 20, 34, rgb(84, 108, 96))
  ceilingLamps(m, CFrame.new(0, ST - 1, 0), { -16, 0, 16 }, { -10, 10 }, 4, rgb(196, 255, 220))

  K.table(m, CFrame.new(-14, ST, -4), 16, 10, 5.2, C.oak)
  K.chair(m, CFrame.new(-14, ST, 5) * K.yaw(math.pi))
  K.chair(m, CFrame.new(-24, ST, -12))
  K.shelf(m, CFrame.new(-W / 2 + 3, ST, 4) * K.yaw(-math.pi / 2), 26, 15, 4, C.plankDark, 4)
  for i = 0, 2 do K.bed(m, CFrame.new(14, ST, -12 + i * 9) * K.yaw(-math.pi / 2), 8, 15, C.white, rgb(206, 220, 226)) end
  for i = 0, 4 do
    local x = -8 + i * 7
    K.box(m, CFrame.new(x, ST + 18, 12), Vector3.new(0.6, 0.6, 18), MAT.Wood, C.wood, { name = "DryRail", cancollide = false })
    for j = 0, 5 do
      K.box(m, CFrame.new(x, ST + 15, 5 + j * 3), Vector3.new(2.2, 5, 2.2), MAT.Grass, rgb(96, 140, 78), { name = "HerbBunch", cancollide = false })
    end
  end
  K.rug(m, CFrame.new(-14, ST + 0.1, -4), 24, 18, rgb(96, 118, 96))
  ceilingLamps(m, CFrame.new(0, ST * 2 - 3, 0), { -12, 12 }, { 0 }, 4, rgb(210, 255, 230))

  local so = CFrame.new(W / 2 + 19, 0, 4)
  K.floorSlab(m, so, 32, 28, MAT.Slate, C.stone, { name = "StillFloor" })
  walls4(m, so, 32, 28, ST + 10, 2.4, MAT.Brick, rgb(150, 126, 108),
    { { x = -6, w = DOOR_W, h = DOOR_H }, win(10, 12) },
    { win(0, 12) }, { { x = 0, w = DOOR_W, h = DOOR_H } }, { win(-8, 12), win(8, 12) }, "Still")
  K.roofGable(m, so * CFrame.new(0, ST + 10, 0), 32, 28, 14, MAT.Metal, C.verdigris, 3)
  K.autoDoor(m, so * CFrame.new(-6, 0, -15.4), DOOR_W, DOOR_H, { color = C.verdigris, mat = MAT.Metal })
  K.boiler(m, so * CFrame.new(-7, 11, 5), 5.4, 22, { bands = 4, rivets = 14, firebox = true })
  K.spring(m, (so * CFrame.new(-7, 22.5, 5)).Position, (so * CFrame.new(-7, 30, 5)).Position, 3, 5, C.copper)
  K.pipe(m, { (so * CFrame.new(-7, 30, 5)).Position, (so * CFrame.new(8, 30, 5)).Position, (so * CFrame.new(8, 14, 5)).Position }, 1, C.copper)
  K.valveWheel(m, so * CFrame.new(-0.6, 14, 5), 3, 5)
  K.gauge(m, so * CFrame.new(-7, 18, -0.5) * K.yaw(math.pi / 2), 2.8)
  local vent = K.cyl(m, so * CFrame.new(-7, ST + 16, 5), 2.4, 12, MAT.Metal, C.verdigris, { name = "StillVent" })
  steamJet(vent, 12)
  K.counter(m, so * CFrame.new(9, 0, -10) * K.yaw(math.pi), 18, 5, 6.4, C.plankDark)
  K.shelf(m, so * CFrame.new(14, 0, 6) * K.yaw(-math.pi / 2), 22, 16, 4, C.plankDark, 5)
  for i = 0, 3 do K.barrel(m, so * CFrame.new(-13, 0, -9 + i * 5), 2.6, 6, i % 2 == 0 and C.wood or C.oak) end
  ceilingLamps(m, so * CFrame.new(0, ST + 8, 0), { -8, 8 }, { 0 }, 4)

  for i = 0, 3 do
    K.box(m, CFrame.new(-W / 2 - 12, 2.6, -14 + i * 10), Vector3.new(12, 5.2, 8), MAT.WoodPlanks, C.plankDark, { name = "HerbBed" })
    for j = 0, 4 do
      K.box(m, CFrame.new(-W / 2 - 16 + j * 2.4, 7.4, -14 + i * 10) * CFrame.Angles(0, math.rad(j * 40), math.rad(5)),
        Vector3.new(1.2, 5, 1.2), MAT.Grass, rgb(84, 140, 74), { name = "Herb", cancollide = false })
    end
  end
  K.sign(m, CFrame.new(-12, ST + 3, -D / 2 - 2.6), "โรงหมอ", 22, 5.6, rgb(48, 58, 48), rgb(196, 244, 196))
  K.lampPost(m, CFrame.new(-W / 2 - 9, 0, -D / 2 - 12), 17, rgb(160, 255, 200))
  K.lampPost(m, CFrame.new(W / 2 + 9, 0, -D / 2 - 12), 17, rgb(160, 255, 200))
end
K.build("Village_Clinic", nil, function(m) clinic(m) end)

-- ================================================== 3. โรงเตี๊ยม — the tavern
local function tavern(m)
  local W, D = 56, 46
  plinth(m, W + 62, D + 54, 2)
  local brick = rgb(146, 84, 68)

  K.floorSlab(m, CFrame.new(0, 0, 0), W, D, MAT.WoodPlanks, C.plankDark, { name = "Taproom" })
  walls4(m, CFrame.new(0, 0, 0), W, D, ST, 2.6, MAT.Brick, brick,
    { { x = -10, w = DOOR_W + 2, h = DOOR_H }, win(10), win(24) },
    { { x = -20, w = DOOR_W, h = DOOR_H }, win(6), win(20) },
    { win(-10), win(10) }, { { x = 0, w = DOOR_W, h = DOOR_H } }, "G")
  local hole1 = flight(m, W / 2 - 12, 0, -D / 2 + 7, 11, ST, MAT.WoodPlanks, C.plankDark)
  local o1 = CFrame.new(0, ST, -2.5)
  K.box(m, CFrame.new(0, ST - 0.9, -2.5), Vector3.new(W + 5, 1.4, D + 6), MAT.Wood, C.wood, { name = "Jetty" })
  K.floorSlab(m, o1, W + 4, D + 5, MAT.WoodPlanks, C.plank,
    { name = "GuestFloor", hole = { x = hole1.x, z = hole1.z + 2.5, w = hole1.w, d = hole1.d } })
  K.railing(m, o1 * CFrame.new(hole1.x, 0, hole1.z + 2.5 + hole1.d / 2 - 0.5), hole1.w, 5, C.wood)
  walls4(m, o1, W + 4, D + 5, ST - 2, 2, MAT.Plaster, C.plaster,
    { win(-22), win(-8), win(8), win(22) }, { win(-14), win(14) },
    { { x = 4, w = DOOR_W, h = DOOR_H } }, { win(-4) }, "F1")
  K.timberWall(m, o1 * CFrame.new(0, 0, -(D + 5) / 2 - 1.1), W + 4, ST - 2, 0.5, C.plaster, C.wood)
  K.timberWall(m, o1 * CFrame.new(-(W + 4) / 2 - 1.1, 0, 0) * K.yaw(-math.pi / 2), D + 5, ST - 2, 0.5, C.plaster, C.wood)
  K.timberWall(m, o1 * CFrame.new((W + 4) / 2 + 1.1, 0, 0) * K.yaw(math.pi / 2), D + 5, ST - 2, 0.5, C.plaster, C.wood)

  local hole2 = flight(m, -W / 2 + 12, ST, -D / 2 + 7, 11, ST - 2, MAT.WoodPlanks, C.plankDark)
  local o2 = CFrame.new(2.5, ST * 2 - 2, -1)
  K.box(m, o2 * CFrame.new(0, -0.9, 0), Vector3.new(W + 8, 1.4, D + 5), MAT.Wood, C.wood, { name = "Jetty2" })
  K.floorSlab(m, o2, W + 7, D + 4, MAT.WoodPlanks, C.plank,
    { name = "AtticFloor", hole = { x = hole2.x - 2.5, z = hole2.z + 1, w = hole2.w, d = hole2.d } })
  walls4(m, o2, W + 7, D + 4, ST - 6, 2, MAT.Plaster, C.plaster,
    { win(-18, 5), win(0, 5), win(18, 5) }, { win(0, 5) }, {}, {}, "F2")
  K.timberWall(m, o2 * CFrame.new(0, 0, -(D + 4) / 2 - 1.1), W + 7, ST - 6, 0.5, C.plaster, C.wood)
  K.roofGable(m, o2 * CFrame.new(0, ST - 6, 0), W + 7, D + 4, 22, MAT.RoofShingles, rgb(122, 70, 58), 4)
  K.dormer(m, o2 * CFrame.new(-14, ST - 3, -(D + 4) / 2 + 7), 12, 10, 11, MAT.Plaster, C.plaster, MAT.RoofShingles, rgb(122, 70, 58))

  K.box(m, CFrame.new(0, ST - 1, -D / 2 - 11), Vector3.new(W + 4, 1.6, 20), MAT.WoodPlanks, C.plankDark, { name = "GalleryDeck" })
  K.railing(m, CFrame.new(0, ST, -D / 2 - 20.4), W + 4, 5, C.wood)
  for _, x in ipairs({ -24, -8, 8, 24 }) do
    K.cyl(m, CFrame.new(x, ST / 2 - 1, -D / 2 - 20), 1.2, ST - 2, MAT.Wood, C.wood, { name = "GalleryPost" })
    K.wedge(m, CFrame.new(x + 3, ST - 5, -D / 2 - 20) * K.yaw(-math.pi / 2), Vector3.new(1.6, 4, 5), MAT.Wood, C.wood)
  end
  K.stairFlight(m, CFrame.new(W / 2 + 11, 0, -D / 2 - 14) * K.yaw(math.pi / 2), 11, ST, MAT.WoodPlanks, C.plankDark, { railColor = C.wood })
  K.autoDoor(m, o1 * CFrame.new(4, 0, -(D + 5) / 2 - 1.2), DOOR_W, DOOR_H, { color = C.wood })

  -- ---- kitchen wing
  local ko = CFrame.new(-W / 2 - 23, 0, 8)
  local KW, KD, KH = 42, 36, 30
  K.floorSlab(m, ko, KW, KD, MAT.Slate, rgb(122, 118, 112), { name = "KitchenFloor" })
  walls4(m, ko, KW, KD, KH, 2.6, MAT.Brick, brick:Lerp(C.black, 0.12),
    { { x = -6, w = DOOR_W, h = DOOR_H }, win(12, 10) },
    { win(-10, 10), win(10, 10) },
    { win(-8, 10), win(8, 10) }, { { x = 6, w = DOOR_W + 4, h = DOOR_H } }, "Kitchen")
  K.roofGable(m, ko * CFrame.new(0, KH, 0), KW, KD, 16, MAT.RoofShingles, rgb(122, 70, 58), 3)
  K.autoDoor(m, ko * CFrame.new(-6, 0, -KD / 2 - 1.4), DOOR_W, DOOR_H, { color = C.wood })
  K.autoDoor(m, ko * CFrame.new(6, 0, KD / 2 + 1.4) * K.yaw(math.pi), DOOR_W + 4, DOOR_H, { color = C.wood })

  K.fireplace(m, ko * CFrame.new(-12, 0, KD / 2 - 3) * K.yaw(math.pi), 20, 18, C.darkStone)
  K.box(m, ko * CFrame.new(-12, 21, KD / 2 - 5), Vector3.new(24, 8, 10), MAT.Metal, C.iron, { name = "ExtractHood" })
  local kchim = K.box(m, ko * CFrame.new(-12, KH + 14, KD / 2 - 3), Vector3.new(11, 34, 9), MAT.Brick, brick:Lerp(C.black, 0.25), { name = "KitchenChimney" })
  K.box(m, ko * CFrame.new(-12, KH + 32, KD / 2 - 3), Vector3.new(13, 2, 11), MAT.Brick, C.darkStone, { name = "ChimneyCap" })
  smoke(kchim, rgb(118, 114, 108), 9)
  K.cylX(m, ko * CFrame.new(-12, 9, KD / 2 - 8) * K.yaw(math.pi / 2), 0.4, 17, MAT.Metal, C.iron, { name = "SpitRod" })
  K.cyl(m, ko * CFrame.new(-12, 9, KD / 2 - 8) * K.roll(math.pi / 2), 2.6, 6, MAT.Fabric, rgb(168, 96, 72), { name = "Roast", cancollide = false })
  for _, s in ipairs({ -1, 1 }) do
    K.box(m, ko * CFrame.new(-12 + s * 8.6, 5, KD / 2 - 8), Vector3.new(1, 10, 1), MAT.Metal, C.iron, { name = "SpitStand" })
  end
  K.gear(m, ko * CFrame.new(-3.2, 9, KD / 2 - 8) * K.yaw(math.pi / 2), 2.2, 12, 0.6, BRASS)

  for _, x in ipairs({ 6, 16 }) do
    K.box(m, ko * CFrame.new(x, 6, KD / 2 - 5), Vector3.new(9, 12, 9), MAT.Brick, brick:Lerp(C.black, 0.18), { name = "Oven" })
    K.cyl(m, ko * CFrame.new(x, 12, KD / 2 - 5), 4.5, 9, MAT.Brick, brick:Lerp(C.black, 0.18), { name = "OvenDome" })
    local mouth = K.box(m, ko * CFrame.new(x, 6, KD / 2 - 9.6), Vector3.new(5, 4.5, 0.6), MAT.Neon, C.ember, { name = "OvenMouth", cancollide = false })
    glow(mouth, C.ember, 22, 1.8)
    K.box(m, ko * CFrame.new(x, 3.2, KD / 2 - 11.4), Vector3.new(6, 0.6, 3), MAT.Metal, C.iron, { name = "OvenLedge" })
    K.pipe(m, { (ko * CFrame.new(x, 17, KD / 2 - 5)).Position, (ko * CFrame.new(x, KH - 4, KD / 2 - 5)).Position }, 0.9, C.iron)
  end

  K.box(m, ko * CFrame.new(-KW / 2 + 5, 4, -4), Vector3.new(8, 8, 18), MAT.Metal, C.coal, { name = "Range" })
  for i = 0, 2 do
    K.cyl(m, ko * CFrame.new(-KW / 2 + 5, 9.6, -10 + i * 6), 2.2, 3.4, MAT.Metal, C.iron, { name = "Pot" })
    K.cylX(m, ko * CFrame.new(-KW / 2 + 5, 11.4, -10 + i * 6) * K.yaw(math.pi / 2), 0.25, 5.6, MAT.Metal, C.brassDark, { name = "PotHandle", cancollide = false })
    local f = K.box(m, ko * CFrame.new(-KW / 2 + 1.2, 4, -10 + i * 6), Vector3.new(0.6, 3.4, 4), MAT.Neon, C.ember, { name = "RangeFire", cancollide = false })
    glow(f, C.ember, 16, 1.4)
  end
  K.pipe(m, { (ko * CFrame.new(-KW / 2 + 5, 8, 5)).Position, (ko * CFrame.new(-KW / 2 + 5, KH - 4, 5)).Position }, 0.8, C.iron)
  for _, p in ipairs({ { -4, -8 }, { -4, 4 }, { 10, -6 } }) do
    K.table(m, ko * CFrame.new(p[1], 0, p[2]), 14, 8, 5.4, C.plank)
    for j = 0, 2 do
      K.box(m, ko * CFrame.new(p[1] - 4 + j * 4, 5.9, p[2]), Vector3.new(2.6, 0.6, 2.6), MAT.WoodPlanks, C.oak, { name = "Board", cancollide = false })
    end
  end
  K.cyl(m, ko * CFrame.new(14, 2.6, 6), 4, 5.2, MAT.Wood, C.plankDark, { name = "ButcherBlock" })
  K.box(m, ko * CFrame.new(14, 5.8, 6), Vector3.new(3.4, 0.5, 1.6), MAT.Metal, C.steel, { name = "Cleaver", cancollide = false })
  K.counter(m, ko * CFrame.new(KW / 2 - 6, 0, -8) * K.yaw(math.pi / 2), 16, 5, 6.4, C.plankDark)
  K.box(m, ko * CFrame.new(KW / 2 - 6, 6.4, -8), Vector3.new(5, 1.4, 8), MAT.Metal, C.steel, { name = "SinkBasin" })
  K.cyl(m, ko * CFrame.new(KW / 2 - 6, 9, -12), 0.5, 5, MAT.Metal, C.brassDark, { name = "PumpStand" })
  K.cylX(m, ko * CFrame.new(KW / 2 - 6, 11, -10.4) * K.yaw(math.pi / 2), 0.4, 3.4, MAT.Metal, BRASS, { name = "Spout" })
  K.box(m, ko * CFrame.new(KW / 2 - 4.4, 12.2, -12) * K.roll(math.rad(-18)), Vector3.new(4.4, 0.5, 0.7), MAT.Metal, BRASS, { name = "PumpHandle" })
  K.box(m, ko * CFrame.new(-4, 20, -2), Vector3.new(20, 0.7, 6), MAT.Metal, C.iron, { name = "PotRack" })
  for i = 0, 5 do
    local x, z = -13 + i * 3.6, -4 + (i % 2) * 4
    K.chain(m, (ko * CFrame.new(x, 20, z)).Position, (ko * CFrame.new(x, 16, z)).Position, 3, 0.16)
    if i % 3 == 0 then
      K.cyl(m, ko * CFrame.new(x, 14.4, z), 1.8, 3, MAT.Metal, C.copper, { name = "HangingPot", cancollide = false })
    elseif i % 3 == 1 then
      K.cylX(m, ko * CFrame.new(x, 15.4, z) * K.roll(math.pi / 2), 2.2, 0.5, MAT.Metal, C.iron, { name = "Pan", cancollide = false })
    else
      K.cyl(m, ko * CFrame.new(x, 14.8, z), 0.9, 3.4, MAT.Metal, BRASS, { name = "Ladle", cancollide = false })
    end
  end
  K.shelf(m, ko * CFrame.new(-KW / 2 + 3, 0, 12) * K.yaw(-math.pi / 2), 16, 18, 4, C.plankDark, 5)
  K.shelf(m, ko * CFrame.new(KW / 2 - 3, 0, 10) * K.yaw(math.pi / 2), 16, 18, 4, C.plankDark, 5)
  for i = 0, 3 do
    K.barrel(m, ko * CFrame.new(-16 + i * 5, 0, -KD / 2 + 6), 2.4, 6, i % 2 == 0 and C.wood or C.oak)
    K.box(m, ko * CFrame.new(2 + i * 4, 2.4, -KD / 2 + 5) * K.yaw(i * 0.4), Vector3.new(4, 5, 4), MAT.Fabric, C.canvas, { name = "Sack" })
  end
  ceilingLamps(m, ko * CFrame.new(0, KH - 2, 0), { -10, 10 }, { -8, 8 }, 4)

  -- ---- taproom
  K.autoDoor(m, CFrame.new(-10, 0, -D / 2 - 1.4), DOOR_W + 2, DOOR_H, { color = C.wood })
  K.counter(m, CFrame.new(-W / 2 + 15, 0, D / 2 - 5) * K.yaw(math.pi), 30, 6, 6.6, C.plankDark)
  K.shelf(m, CFrame.new(-W / 2 + 15, 0, D / 2 - 2) * K.yaw(math.pi), 30, 15, 3.6, C.plankDark, 4)
  for i = 0, 4 do
    K.barrel(m, CFrame.new(-W / 2 + 5 + i * 6, 8, D / 2 - 9) * K.roll(math.pi / 2), 2.8, 6, i % 2 == 0 and C.oak or C.wood)
    K.cylX(m, CFrame.new(-W / 2 + 5 + i * 6, 8, D / 2 - 12.4) * K.yaw(math.pi / 2), 0.3, 1.8, MAT.Metal, BRASS, { name = "Tap", cancollide = false })
  end
  K.box(m, CFrame.new(-W / 2 + 15, 5, D / 2 - 13), Vector3.new(30, 1, 4), MAT.Wood, C.wood, { name = "BarrelRack" })
  K.fireplace(m, CFrame.new(W / 2 - 9, 0, D / 2 - 3) * K.yaw(math.pi), 18, 17, C.darkStone)
  for i, p in ipairs({ { -18, -12 }, { 2, -12 }, { 20, -8 }, { -8, 4 }, { 14, 8 }, { -20, 8 } }) do
    K.table(m, CFrame.new(p[1], 0, p[2]), 11, 11, 5.4, C.plank)
    for j = 0, 3 do
      local a = j * math.pi / 2 + i * 0.3
      K.chair(m, CFrame.new(p[1] + math.cos(a) * 8.5, 0, p[2] + math.sin(a) * 8.5) * K.yaw(math.pi / 2 - a + math.pi))
    end
    K.cyl(m, CFrame.new(p[1] + 2, 6, p[2] - 1.4), 0.9, 1.8, MAT.Metal, BRASS, { name = "Tankard", cancollide = false })
  end
  K.rug(m, CFrame.new(0, 0.1, -2), 34, 24, rgb(120, 66, 58))
  ceilingLamps(m, CFrame.new(0, ST - 1, 0), { -18, 0, 18 }, { -10, 10 }, 4)

  for i = 0, 3 do
    local x = -21 + i * 14
    K.box(m, o1 * CFrame.new(x - 7, (ST - 2) / 2, 6), Vector3.new(0.8, ST - 2, D - 8), MAT.WoodPlanks, C.plankDark, { name = "Partition" })
    K.bed(m, o1 * CFrame.new(x, 0, 12) * K.yaw(math.pi), 8, 15, C.wood, C.canvas)
    K.chest(m, o1 * CFrame.new(x, 0, -2), 3)
    K.table(m, o1 * CFrame.new(x + 4, 0, 2), 5, 5, 4.4, C.plank)
    K.lantern(m, o1 * CFrame.new(x, ST - 10, 6), 3.4)
  end
  for i = 0, 2 do K.bed(m, o2 * CFrame.new(-16 + i * 16, 0, 8) * K.yaw(math.pi), 7, 14, C.plankDark, C.canvas) end
  K.crate(m, o2 * CFrame.new(-22, 0, -8), 5)
  K.barrel(m, o2 * CFrame.new(20, 0, -6), 2.4, 5.4)
  ceilingLamps(m, o2 * CFrame.new(0, ST - 8, 0), { -12, 12 }, { 0 }, 3.4)

  local arm = K.box(m, CFrame.new(-W / 2 + 4, ST * 2 - 8, -D / 2 - 23), Vector3.new(1, 1, 10), MAT.Metal, C.iron, { name = "SignArm" })
  K.chain(m, arm.CFrame.Position + Vector3.new(0, 0, -4.4), arm.CFrame.Position + Vector3.new(0, -4, -4.4), 4, 0.24)
  K.sign(m, CFrame.new(-W / 2 + 4, ST * 2 - 17, -D / 2 - 27.4), "โรงเตี๊ยม", 17, 6.4, rgb(58, 38, 28), rgb(246, 210, 132))
  for _, p in ipairs({ { -24, -D / 2 - 32 }, { -2, -D / 2 - 37 }, { 20, -D / 2 - 30 } }) do
    K.cyl(m, CFrame.new(p[1], 5.4, p[2]), 5.5, 1, MAT.WoodPlanks, C.plank, { name = "GardenTable" })
    K.cyl(m, CFrame.new(p[1], 2.7, p[2]), 1, 5.4, MAT.Wood, C.wood, { name = "TableLeg" })
    for _, s in ipairs({ -1, 1 }) do
      K.box(m, CFrame.new(p[1], 3.2, p[2] + s * 8), Vector3.new(12, 0.8, 3), MAT.WoodPlanks, C.plankDark, { name = "Bench" })
      K.box(m, CFrame.new(p[1], 1.6, p[2] + s * 8), Vector3.new(11, 3.2, 0.8), MAT.Wood, C.wood, { name = "BenchLeg" })
    end
  end
  K.lampPost(m, CFrame.new(-W / 2 - 7, 0, -D / 2 - 26), 18, rgb(255, 198, 124))
  K.lampPost(m, CFrame.new(W / 2 + 7, 0, -D / 2 - 26), 18, rgb(255, 198, 124))
end
K.build("Village_Tavern", nil, function(m) tavern(m) end)

-- ================================================== 4. โรงช่าง — the workshop
local function workshop(m)
  local W, D, H = 58, 48, 44
  plinth(m, W + 56, D + 40, 2)
  local brick = rgb(140, 84, 66)

  K.floorSlab(m, CFrame.new(0, 0, 0), W, D, MAT.Slate, rgb(96, 94, 92), { name = "ForgeFloor" })
  walls4(m, CFrame.new(0, 0, 0), W, D, H, 3, MAT.Brick, brick,
    { { x = -4, w = 30, h = 26 }, win(24, 30) },
    { win(-16, 30), { x = 14, w = DOOR_W + 2, h = DOOR_H } },
    { win(-10, 30), win(10, 30) }, { win(-6, 30), { x = 16, w = DOOR_W + 2, h = DOOR_H } }, "Hall")
  K.roofGable(m, CFrame.new(0, H, 0), W, D, 22, MAT.Metal, rgb(122, 92, 64), 4)
  for i = 0, 4 do
    local z = -D / 2 + 5 + i * (D - 10) / 4
    K.box(m, CFrame.new(0, H - 1, z), Vector3.new(W - 5, 1.4, 1.6), MAT.Metal, C.iron, { name = "TieBeam", cancollide = false })
    K.rod(m, Vector3.new(-W / 2 + 2.5, H, z), Vector3.new(0, H + 21, z), 0.7, MAT.Metal, C.iron, { name = "Rafter", cancollide = false })
    K.rod(m, Vector3.new(W / 2 - 2.5, H, z), Vector3.new(0, H + 21, z), 0.7, MAT.Metal, C.iron, { name = "Rafter", cancollide = false })
  end

  local MZ = 26
  K.floorSlab(m, CFrame.new(W / 2 - 11, MZ, 0), 22, D - 8, MAT.DiamondPlate, C.steel, { name = "MezzR" })
  K.floorSlab(m, CFrame.new(-4, MZ, D / 2 - 9), W - 26, 18, MAT.DiamondPlate, C.steel, { name = "MezzB" })
  K.railing(m, CFrame.new(W / 2 - 22, MZ, 0) * K.yaw(math.pi / 2), D - 8, 5, C.iron, MAT.Metal)
  K.railing(m, CFrame.new(-4, MZ, D / 2 - 18), W - 26, 5, C.iron, MAT.Metal)
  for _, p in ipairs({ { W / 2 - 22, -16 }, { W / 2 - 22, 8 }, { -16, D / 2 - 18 }, { 6, D / 2 - 18 } }) do
    K.cyl(m, CFrame.new(p[1], MZ / 2, p[2]), 1.2, MZ, MAT.Metal, C.iron, { name = "Column" })
  end
  K.stairFlight(m, CFrame.new(W / 2 - 11, 0, -D / 2 + 6), 11, MZ, MAT.Metal, C.steel, { railColor = C.iron })

  K.box(m, CFrame.new(-W / 2 + 13, 4, D / 2 - 12), Vector3.new(22, 8, 16), MAT.Cobblestone, C.darkStone, { name = "ForgeBase" })
  local fire = K.box(m, CFrame.new(-W / 2 + 13, 8.4, D / 2 - 12), Vector3.new(17, 1.4, 11), MAT.Neon, rgb(255, 118, 26), { name = "ForgeFire", cancollide = false })
  glow(fire, rgb(255, 118, 26), 70, 3.8)
  K.box(m, CFrame.new(-W / 2 + 13, 22, D / 2 - 12), Vector3.new(23, 12, 17), MAT.Metal, C.iron, { name = "ForgeHood" })
  local chim = K.cyl(m, CFrame.new(-W / 2 + 13, 44, D / 2 - 12), 4, 32, MAT.Metal, C.iron, { name = "ForgeChimney" })
  K.cyl(m, CFrame.new(-W / 2 + 13, 61, D / 2 - 12), 5.4, 2, MAT.Metal, C.brassDark, { name = "ChimneyCap" })
  smoke(chim, rgb(78, 76, 74), 10)

  local eng = CFrame.new(-W / 2 + 10, 0, -8)
  K.boiler(m, eng * CFrame.new(0, 13, 0), 6, 24, { bands = 4, rivets = 16, firebox = true })
  K.gauge(m, eng * CFrame.new(0, 20, -6.4) * K.yaw(math.pi / 2), 3)
  K.valveWheel(m, eng * CFrame.new(6.8, 16, 0), 3.4, 5)
  K.gear(m, eng * CFrame.new(10, 11, 0), 8, 20, 2, BRASS)
  K.gear(m, eng * CFrame.new(10, 22.5, 0), 4, 12, 2, C.copper)
  K.cyl(m, eng * CFrame.new(10, 11, 0) * K.roll(math.pi / 2), 0.9, 16, MAT.Metal, C.steel, { name = "Shaft" })
  K.spring(m, (eng * CFrame.new(2.4, 25, 6)).Position, (eng * CFrame.new(2.4, 33, 6)).Position, 2.4, 5)
  K.pipe(m, { (eng * CFrame.new(0, 25, 0)).Position, (eng * CFrame.new(0, 31, 8)).Position, (eng * CFrame.new(6, 31, 22)).Position, (eng * CFrame.new(7, 22, 28)).Position }, 1.2, C.copper)
  K.box(m, eng * CFrame.new(6, 14, 22) * K.pitch(math.rad(14)), Vector3.new(7, 7, 13), MAT.Leather, C.leather, { name = "Bellows" })

  for i, p in ipairs({ { 4, 8 }, { 18, -4 } }) do
    K.cyl(m, CFrame.new(p[1], 2, p[2]), 3.6, 4, MAT.Wood, C.plankDark, { name = "AnvilStump" })
    local anvil = K.box(m, CFrame.new(p[1], 6.4, p[2]), Vector3.new(9, 3.6, 4.6), MAT.Metal, rgb(52, 54, 60), { name = "Anvil" })
    K.box(m, CFrame.new(p[1], 4.4, p[2]), Vector3.new(4.6, 3.6, 3.6), MAT.Metal, rgb(46, 48, 54), { name = "AnvilWaist" })
    if i == 1 then
      local ingot = K.box(m, anvil.CFrame * CFrame.new(1, 2.1, 0), Vector3.new(4.4, 0.9, 1.8), MAT.Neon, rgb(255, 110, 30), { name = "HotIngot", cancollide = false })
      glow(ingot, rgb(255, 110, 30), 26, 2)
    end
  end
  K.barrel(m, CFrame.new(12, 0, 15), 3.6, 7.4)
  K.counter(m, CFrame.new(20, 0, D / 2 - 5) * K.yaw(math.pi), 26, 6, 6.6, C.plankDark)
  K.shelf(m, CFrame.new(W / 2 - 4, 0, 10) * K.yaw(-math.pi / 2), 22, 18, 4, C.plankDark, 5)
  local board = K.box(m, CFrame.new(-6, 14, D / 2 - 2.4), Vector3.new(28, 14, 0.8), MAT.WoodPlanks, C.plankDark, { name = "ToolBoard" })
  for i = 0, 7 do
    local x = -12 + i * 3.4
    K.box(m, board.CFrame * CFrame.new(x, 2, -0.8), Vector3.new(0.5, 7, 0.5), MAT.Wood, C.wood, { name = "ToolHaft", cancollide = false })
    K.box(m, board.CFrame * CFrame.new(x, 6.2, -1.2), Vector3.new(3.2, 2.2, 1.6), MAT.Metal, C.steel, { name = "ToolHead", cancollide = false })
  end
  for i = 0, 6 do K.cyl(m, CFrame.new(-W / 2 + 5 + i * 1.6, 13, -D / 2 + 7) * K.roll(math.rad(6 + i)), 0.6, 26, MAT.Metal, C.steel, { name = "BarStock", cancollide = false }) end
  for i = 0, 3 do K.crate(m, CFrame.new(W / 2 - 18 + (i % 2) * 8, MZ, -14 + math.floor(i / 2) * 9), 6) end
  ceilingLamps(m, CFrame.new(0, H - 2, 0), { -14, 12 }, { -12, 10 }, 5)

  K.box(m, CFrame.new(-4, 27, -D / 2 - 2), Vector3.new(58, 1.6, 2), MAT.Metal, C.iron, { name = "DoorRail" })
  K.box(m, CFrame.new(-27, 13, -D / 2 - 1.6), Vector3.new(15, 26, 1.2), MAT.WoodPlanks, C.plankDark, { name = "SlideDoorA" })
  K.box(m, CFrame.new(16, 13, -D / 2 - 3.2), Vector3.new(15, 26, 1.2), MAT.WoodPlanks, C.plankDark, { name = "SlideDoorB" })
  for _, x in ipairs({ -33, -21, 10, 22 }) do
    K.cylX(m, CFrame.new(x, 26.4, -D / 2 - (x < 0 and 1.6 or 3.2)) * K.yaw(math.pi / 2), 0.9, 0.8, MAT.Metal, BRASS, { name = "DoorRoller", cancollide = false })
  end

  -- office annex: two storeys, its own stair and stairwell
  local ao = CFrame.new(-W / 2 - 17, 0, -6)
  K.floorSlab(m, ao, 28, 26, MAT.WoodPlanks, C.plankDark, { name = "OfficeFloor" })
  walls4(m, ao, 28, 26, 22, 2, MAT.WoodPlanks, rgb(122, 90, 60),
    { { x = -5, w = DOOR_W, h = DOOR_H }, { x = 8, w = 8, h = 9, sill = 7 } },
    { { x = 0, w = 8, h = 9, sill = 7 } }, { { x = 0, w = 8, h = 9, sill = 7 } },
    { { x = 4, w = DOOR_W, h = DOOR_H } }, "Office")
  K.stairFlight(m, ao * CFrame.new(9, 0, -9), 9, 22, MAT.WoodPlanks, C.plankDark, { railColor = C.wood })
  K.floorSlab(m, ao * CFrame.new(0, 22, 0), 28, 26, MAT.WoodPlanks, C.plank,
    { name = "OfficeUpper", hole = { x = 9, z = 9, w = 13, d = 38 } })
  walls4(m, ao * CFrame.new(0, 22, 0), 28, 26, 20, 2, MAT.Plaster, C.plaster,
    { { x = -7, w = 8, h = 9, sill = 7 }, { x = 7, w = 8, h = 9, sill = 7 } },
    { { x = 0, w = 8, h = 9, sill = 7 } }, { { x = 0, w = 8, h = 9, sill = 7 } }, {}, "OfficeU")
  K.timberWall(m, ao * CFrame.new(0, 22, -14), 28, 20, 0.5, C.plaster, C.wood)
  K.roofGable(m, ao * CFrame.new(0, 42, 0), 28, 26, 13, MAT.RoofShingles, rgb(104, 70, 58), 3)
  K.autoDoor(m, ao * CFrame.new(-5, 0, -14.2), DOOR_W, DOOR_H, { color = C.wood })
  K.table(m, ao * CFrame.new(-6, 0, 4), 14, 9, 5.2, C.oak)
  K.chair(m, ao * CFrame.new(-6, 0, 12) * K.yaw(math.pi))
  K.shelf(m, ao * CFrame.new(-11, 0, -3) * K.yaw(-math.pi / 2), 18, 14, 4, C.plankDark, 4)
  K.bed(m, ao * CFrame.new(-7, 22, 5) * K.yaw(math.pi / 2), 8, 14, C.wood)
  K.chest(m, ao * CFrame.new(-8, 22, -7), 3)
  ceilingLamps(m, ao * CFrame.new(0, 20, 0), { 0 }, { 0 }, 3.6)
  ceilingLamps(m, ao * CFrame.new(0, 40, 0), { -6 }, { 0 }, 3.4)
  local ochim = K.box(m, ao * CFrame.new(-9, 48, 6), Vector3.new(5, 20, 5), MAT.Brick, brick:Lerp(C.black, 0.2), { name = "OfficeChimney" })
  smoke(ochim, rgb(112, 110, 106), 5)

  K.box(m, CFrame.new(W / 2 + 16, 4, 10), Vector3.new(24, 8, 24), MAT.WoodPlanks, C.plankDark, { name = "CoalBunker" })
  K.box(m, CFrame.new(W / 2 + 16, 9, 10), Vector3.new(22, 4, 22), MAT.Slate, C.coal, { name = "Coal", cancollide = false })
  K.cyl(m, CFrame.new(W / 2 + 8, 22, -D / 2 - 5), 1.8, 44, MAT.Metal, C.iron, { name = "CraneMast" })
  K.box(m, CFrame.new(W / 2 - 4, 42, -D / 2 - 5), Vector3.new(28, 2, 2.4), MAT.Metal, C.iron, { name = "CraneJib" })
  K.chain(m, Vector3.new(W / 2 - 14, 41, -D / 2 - 5), Vector3.new(W / 2 - 14, 18, -D / 2 - 5), 12, 0.34)
  K.box(m, CFrame.new(W / 2 - 14, 15.6, -D / 2 - 5), Vector3.new(5, 5, 5), MAT.Metal, C.iron, { name = "CraneHook" })
  K.sign(m, CFrame.new(-4, H + 5, -D / 2 - 3.6), "โรงช่าง", 24, 6.2, rgb(46, 38, 32), rgb(248, 194, 112))
  K.lampPost(m, CFrame.new(-W / 2 - 36, 0, -D / 2 - 10), 17, rgb(255, 176, 112))
  K.lampPost(m, CFrame.new(W / 2 + 22, 0, -D / 2 - 12), 17, rgb(255, 176, 112))
end
K.build("Village_Workshop", nil, function(m) workshop(m) end)

-- ========================================== 5. หอนาฬิกาไอน้ำ — the clock tower
local function clockTower(m)
  plinth(m, 56, 56, 2)
  local stone = rgb(172, 168, 158)
  K.box(m, CFrame.new(0, 1.6, 0), Vector3.new(48, 3.2, 48), MAT.Cobblestone, C.stone, { name = "Steps" })
  K.box(m, CFrame.new(0, 4.4, 0), Vector3.new(40, 2.4, 40), MAT.Cobblestone, C.darkStone, { name = "Plinth2" })

  local base, y0 = 30, 5.6
  K.floorSlab(m, CFrame.new(0, y0, 0), base, base, MAT.Slate, C.stone, { name = "Floor" })
  K.wallRun(m, CFrame.new(0, y0, -base / 2), base, ST + 4, 3, MAT.Sandstone, stone, { { x = 0, w = 14, h = 20 } }, { name = "F" })
  K.wallRun(m, CFrame.new(0, y0, base / 2) * K.yaw(math.pi), base, ST + 4, 3, MAT.Sandstone, stone, { { x = 0, w = 14, h = 20 } }, { name = "B" })
  K.wallRun(m, CFrame.new(-base / 2, y0, 0) * K.yaw(-math.pi / 2), base, ST + 4, 3, MAT.Sandstone, stone, { { x = 0, w = 14, h = 20 } }, { name = "L" })
  K.wallRun(m, CFrame.new(base / 2, y0, 0) * K.yaw(math.pi / 2), base, ST + 4, 3, MAT.Sandstone, stone, { win(0, 8) }, { name = "R" })

  local y1 = y0 + ST + 4
  K.stairFlight(m, CFrame.new(-9, y0, -11), 9, ST + 4, MAT.Sandstone, stone, { railColor = C.iron })
  K.floorSlab(m, CFrame.new(0, y1, 0), base, base, MAT.WoodPlanks, C.plankDark, { name = "Landing", hole = { x = -9, z = 12, w = 13, d = 36 } })
  K.cyl(m, CFrame.new(0, y1 + 20, 0), 13, 40, MAT.Sandstone, stone, { name = "Shaft" })
  for i = 1, 5 do K.band(m, CFrame.new(0, y1 + i * 7, 0), 13.6, 1.6, C.brassDark) end
  K.stairFlight(m, CFrame.new(-5, y1, -9), 8, 22, MAT.WoodPlanks, C.plankDark, { railColor = C.iron })
  K.floorSlab(m, CFrame.new(0, y1 + 22, 0), 24, 24, MAT.WoodPlanks, C.plankDark, { name = "ClockFloor", hole = { x = -5, z = 10, w = 12, d = 32 } })

  local cy = y1 + 40
  K.box(m, CFrame.new(0, cy - 9, 0), Vector3.new(32, 18, 32), MAT.Sandstone, stone:Lerp(C.white, 0.06), { name = "ClockStage" })
  for i = 0, 3 do
    local a = i * math.pi / 2
    K.gauge(m, CFrame.new(math.cos(a) * 16.2, cy - 9, math.sin(a) * 16.2) * K.yaw(math.pi / 2 - a), 6.4, BRASS)
  end
  K.box(m, CFrame.new(0, cy, 0), Vector3.new(40, 2, 40), MAT.Slate, C.darkStone, { name = "Gallery" })
  for _, e in ipairs({ { 0, -19, 0 }, { 0, 19, 0 }, { -19, 0, math.pi / 2 }, { 19, 0, math.pi / 2 } }) do
    K.railing(m, CFrame.new(e[1], cy + 1, e[2]) * K.yaw(e[3]), 38, 5, C.iron, MAT.Metal)
  end
  K.roofCone(m, CFrame.new(0, cy + 1, 0), 18, 22, MAT.Metal, C.verdigris, 11)
  local bell = K.ball(m, CFrame.new(0, cy + 27, 0), 8, MAT.Metal, BRASS, { name = "Bell", cancollide = false })
  glow(bell, rgb(255, 214, 140), 44, 1.8)

  for i, g in ipairs({ { 24, 6, 18 }, { 34, 4, 12 }, { 44, 5.4, 15 } }) do
    K.gear(m, CFrame.new(-9, y0 + g[1], -9) * K.yaw(math.rad(45)), g[2], g[3], 1.4, i % 2 == 0 and C.copper or BRASS)
  end
  K.chain(m, Vector3.new(6, cy - 16, 0), Vector3.new(6, 14, 0), 22, 0.36)
  K.box(m, CFrame.new(6, 12, 0), Vector3.new(4.4, 7, 4.4), MAT.Metal, C.iron, { name = "ClockWeight" })
  K.pipe(m, { Vector3.new(11, 10, 11), Vector3.new(11, cy - 16, 11), Vector3.new(5, cy - 12, 5) }, 1, C.copper)
  local vent = K.cyl(m, CFrame.new(11, cy - 7, 11), 1.6, 6, MAT.Metal, C.brassDark, { name = "Vent" })
  steamJet(vent, 10)

  K.table(m, CFrame.new(8, y0, 7), 12, 8, 5.2, C.oak)
  K.chair(m, CFrame.new(8, y0, 14) * K.yaw(math.pi))
  K.shelf(m, CFrame.new(12.6, y0, -4) * K.yaw(-math.pi / 2), 16, 14, 4, C.plankDark, 4)
  ceilingLamps(m, CFrame.new(0, y1 - 2, 0), { 4 }, { 4 }, 4)
  for _, a in ipairs({ math.rad(45), math.rad(135), math.rad(225), math.rad(315) }) do
    K.lampPost(m, CFrame.new(math.cos(a) * 25, 3.2, math.sin(a) * 25), 16, rgb(255, 200, 140))
  end
  K.sign(m, CFrame.new(0, y0 + 21, -base / 2 - 2), "จัตุรัสกลางหมู่บ้าน", 20, 5, rgb(46, 44, 46), rgb(238, 218, 162))
end
K.build("Village_ClockTower", nil, function(m) clockTower(m) end)
