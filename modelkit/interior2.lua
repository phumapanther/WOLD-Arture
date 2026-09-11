-- interior2 — floors with stairwell holes, self-computing stair flights, and doors that
-- open when you run into them. loaded after interior.lua and overrides K.floorSlab.
--
-- scale note: interiors here are sized for a Roblox character, not a real person. an R15
-- character is ~5.5 studs tall and jumps ~7.5, so a 26 stud ceiling is the "room to run and
-- jump" height, and a doorway is 12 x 18 so two players can run through it side by side.

-- A floor deck with any number of holes cut in it -- a courtyard void AND a stairwell, which is
-- what a house with a yard and a stair needs. The deck is laid as whole rectangles left over after
-- each hole is subtracted, so cutting a second hole costs a handful of parts rather than a grid.
-- opts.hole is the single-hole shorthand; opts.holes takes a list. Both are { x, z, w, d }.
function K.floorSlab(parent, cf, w, d, mat, color, opts)
  opts = opts or {}
  local m = K.model(parent, opts.name or "Floor")
  local material = mat or K.MAT.WoodPlanks
  local col = color or K.C.plank
  local rects = { { -w / 2, w / 2, -d / 2, d / 2 } }
  local holes = opts.holes or (opts.hole and { opts.hole }) or {}
  for _, h in ipairs(holes) do
    local hx0, hx1, hz0, hz1 = h.x - h.w / 2, h.x + h.w / 2, h.z - h.d / 2, h.z + h.d / 2
    local out = {}
    for _, r in ipairs(rects) do
      if hx0 >= r[2] or hx1 <= r[1] or hz0 >= r[4] or hz1 <= r[3] then
        table.insert(out, r)
      else
        if r[3] < hz0 then table.insert(out, { r[1], r[2], r[3], hz0 }) end
        if hz1 < r[4] then table.insert(out, { r[1], r[2], hz1, r[4] }) end
        local z0, z1 = math.max(r[3], hz0), math.min(r[4], hz1)
        if r[1] < hx0 then table.insert(out, { r[1], hx0, z0, z1 }) end
        if hx1 < r[2] then table.insert(out, { hx1, r[2], z0, z1 }) end
      end
    end
    rects = out
  end
  for _, r in ipairs(rects) do
    local bw, bd = r[2] - r[1], r[4] - r[3]
    if bw > 0.05 and bd > 0.05 then
      local cx, cz = (r[1] + r[2]) / 2, (r[3] + r[4]) / 2
      K.box(m, cf * CFrame.new(cx, -0.4, cz), Vector3.new(bw, 0.8, bd), material, col, { name = "Deck" })
      local n = math.max(1, math.floor(bd / 6))
      for i = 0, n do
        K.box(m, cf * CFrame.new(cx, -1.25, r[3] + bd * i / n), Vector3.new(bw, 0.9, 0.9), K.MAT.Wood,
          col:Lerp(K.C.black, 0.35), { name = "Joist", cancollide = false })
      end
    end
  end
  for _, h in ipairs(holes) do
    K.box(m, cf * CFrame.new(h.x, 0.15, h.z + h.d / 2 - 0.3), Vector3.new(h.w, 0.5, 0.6), K.MAT.Wood,
      col:Lerp(K.C.black, 0.4), { name = "WellTrim", cancollide = false })
  end
  return m
end

-- one flight, steps worked out from the rise so nothing is ever too steep to walk up.
-- climbs along the frame's local +Z. returns the run it used.
function K.stairFlight(parent, cf, width, rise, mat, color, opts)
  opts = opts or {}
  local stepRise = opts.stepRise or 1.15
  local steps = math.max(2, math.ceil(rise / stepRise))
  -- 45 degrees. steeper than a real stair, but a Roblox humanoid steps up anything under 2 studs
  -- and a 1.35 run needs 35 studs of floor for one storey, which no room this size can spare.
  local run = opts.run or rise * 1.05
  local m = K.model(parent, opts.name or "Stairs")
  -- A step is normally a solid column from the flight's base plane to its own tread, which reads as
  -- cut stone and is right for a flight standing on the ground. Where flights STACK in a well --
  -- the same well on every floor of a tower -- that column is a slab of rock filling the space the
  -- flight below has to climb out into: the last five treads of every flight were unusable. Passing
  -- open = true makes each tread its own slab, so the soffit steps up with the flight, the way the
  -- underside of a real stair does.
  local tread = rise / steps + 1.6
  for i = 1, steps do
    local y = rise * i / steps
    local t = opts.open and math.min(y, tread) or y
    K.box(m, cf * CFrame.new(0, y - t / 2, run * (i - 0.5) / steps), Vector3.new(width, t, run / steps * 1.04),
      mat or K.MAT.WoodPlanks, color or K.C.plankDark, { name = "Step" })
  end
  if opts.rails ~= false then
    for _, s in ipairs({ -1, 1 }) do
      local rc = opts.railColor or K.C.wood
      for i = 0, steps, 2 do
        local y = rise * i / steps
        K.box(m, cf * CFrame.new(s * (width / 2 - 0.4), y + 2.6, run * i / steps), Vector3.new(0.45, 5.2, 0.45),
          K.MAT.Wood, rc, { name = "Baluster", cancollide = false })
      end
      K.rod(m, (cf * CFrame.new(s * (width / 2 - 0.4), 5.2, 0)).Position,
               (cf * CFrame.new(s * (width / 2 - 0.4), rise + 5.2, run)).Position, 0.4, K.MAT.Wood, opts.railColor or K.C.wood, { name = "Handrail", cancollide = false })
    end
  end
  return run
end
-- A spiral stair winding round a newel, for a turret too narrow to take a straight flight: an
-- 18-stud bell tower cannot hold a 36-stud run, and a stair modelled straight through it just ends
-- up buried in the wall. Climbs by `advance` studs of arc per step at the walking radius, which is
-- what keeps the treads walkable rather than merely drawn.
-- Returns the number of steps and the angle it finished at, so a landing can be aimed at the head.
function K.spiralStair(parent, cf, radius, rise, mat, color, opts)
  opts = opts or {}
  local inner = opts.newel or 1.6
  local steps = math.max(4, math.ceil(rise / (opts.stepRise or 1.15)))
  local tread = opts.tread or (rise / steps + 1.4)
  local rm = (inner + radius) / 2                        -- the radius a person actually walks at
  local dA = (opts.dir or 1) * (opts.advance or 1.5) / rm
  local start = opts.start or 0
  local m = K.model(parent, opts.name or "Stairs")
  m:SetAttribute("Spiral", true)
  K.cyl(m, cf * CFrame.new(0, rise / 2, 0), inner, rise + 2, mat or K.MAT.Rock, color or K.C.stone, { name = "Newel" })
  for i = 1, steps do
    local y = rise * i / steps
    local a = start + (i - 1) * dA
    K.box(m, cf * CFrame.new(0, y - tread / 2, 0) * K.yaw(a) * CFrame.new(rm, 0, 0),
      Vector3.new(radius - inner, tread, math.abs(dA) * rm * 1.4), mat or K.MAT.Rock, color or K.C.stone, { name = "Step" })
  end
  return steps, start + (steps - 1) * dA
end


-- A drum wall with a room inside it: a ring of collidable staves rather than one solid cylinder.
--
-- The first towers were a single stone cylinder with the floors and furniture modelled INSIDE it.
-- From the outside that is indistinguishable from this; from the inside it is a rock, and a walk
-- test found beds, stairs and lanterns all buried in solid stone with no way in.
--
-- openings are { a = angle in radians, w = clear width in studs, h = height, sill = height off the floor }
-- `base` is the frame at the foot of the wall, so a tower can stand anywhere, not just at the
-- model's own origin. `mat` defaults to Rock.
function K.drumShell(m, base, r, h, thick, segs, col, openings, name, mat)
  local g = K.model(m, name or "Shell")
  local mid = r - thick / 2                      -- the staves' own centreline
  local arc = 2 * math.pi * mid / segs
  for i = 0, segs - 1 do
    local a = i * 2 * math.pi / segs
    local cuts = {}
    for _, o in ipairs(openings or {}) do
      local off = math.abs((a - o.a + math.pi) % (2 * math.pi) - math.pi) * mid
      if off < o.w / 2 then table.insert(cuts, o) end
    end
    table.sort(cuts, function(p, q) return (p.sill or 0) < (q.sill or 0) end)
    local cf = base * CFrame.new(math.cos(a) * mid, 0, math.sin(a) * mid) * K.yaw(math.pi / 2 - a)
    local function seg(y, height, tag)
      if height > 0.15 then
        K.box(g, cf * CFrame.new(0, y + height / 2, 0), Vector3.new(arc * 1.06, height, thick), mat or K.MAT.Rock, col, { name = tag })
      end
    end
    -- stone between the openings on this stave, from the floor up
    local cursor = 0
    for _, o in ipairs(cuts) do
      local sill = o.sill or 0
      seg(cursor, sill - cursor, cursor == 0 and "Course" or "Apron")
      cursor = math.max(cursor, sill + o.h)
    end
    seg(cursor, h - cursor, cursor == 0 and "Course" or "Lintel")
  end
  return g
end

-- A floor that fills a round tower, with the stairwell cut out of it.
-- K.floorSlab is square, and a square deck big enough to live on pokes out through a drum wall,
-- so this lays the deck as strips clipped to the circle instead.
function K.roundFloor(m, cf, r, hole, mat, col, name)
  local g = K.model(m, name or "TowerFloor")
  local strips = 22
  local dz = 2 * r / strips
  for i = 0, strips - 1 do
    local z0, z1 = -r + i * dz, -r + (i + 1) * dz
    local edge = math.max(math.abs(z0), math.abs(z1))       -- measure the chord at the strip's tightest end
    local half = math.sqrt(math.max(r * r - edge * edge, 0))
    local zc = (z0 + z1) / 2
    local function band(x0, x1)
      if x1 - x0 > 0.6 then
        K.box(g, cf * CFrame.new((x0 + x1) / 2, -0.4, zc), Vector3.new(x1 - x0, 0.8, dz * 1.02), mat or K.MAT.WoodPlanks,
          col or K.C.plankDark, { name = "Deck" })
        K.box(g, cf * CFrame.new((x0 + x1) / 2, -1.25, zc), Vector3.new(x1 - x0, 0.9, 0.9), K.MAT.Wood,
          (col or K.C.plankDark):Lerp(K.C.black, 0.35), { name = "Joist", cancollide = false })
      end
    end
    if half > 0.5 then
      if hole and zc > hole.z - hole.d / 2 and zc < hole.z + hole.d / 2 then
        band(-half, math.min(hole.x - hole.w / 2, half))
        band(math.max(hole.x + hole.w / 2, -half), half)
      else
        band(-half, half)
      end
    end
  end
  return g
end

-- ---------- doors that swing open when a character runs into them ----------
local DOOR_SCRIPT = [==[
-- AutoDoor — swings open when a Humanoid touches the sensor, closes again once nobody is near.
-- attributes on the model: CloseAfter (seconds). each moving part carries SwingDeg + HingeX/HingeZ.
local TweenService = game:GetService("TweenService")
local door = script.Parent
local sensor = door:WaitForChild("Sensor")

local leaves = {}
for _, d in ipairs(door:GetDescendants()) do
	if d:IsA("BasePart") and d:GetAttribute("SwingDeg") then
		leaves[#leaves + 1] = { part = d, closed = d.CFrame }
	end
end

local isOpen, lastTouch = false, 0
local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function setOpen(state)
	if isOpen == state then return end
	isOpen = state
	for _, L in ipairs(leaves) do
		local off = Vector3.new(L.part:GetAttribute("HingeX") or 0, 0, L.part:GetAttribute("HingeZ") or 0)
		local hinge = L.closed * CFrame.new(off)
		local goal = L.closed
		if state then
			goal = hinge * CFrame.Angles(0, math.rad(L.part:GetAttribute("SwingDeg")), 0) * hinge:Inverse() * L.closed
		end
		TweenService:Create(L.part, info, { CFrame = goal }):Play()
	end
end

sensor.Touched:Connect(function(hit)
	if hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid") then
		lastTouch = os.clock()
		setOpen(true)
	end
end)

task.spawn(function()
	while door.Parent do
		task.wait(0.4)
		if isOpen and os.clock() - lastTouch > (door:GetAttribute("CloseAfter") or 2.5) then setOpen(false) end
	end
end)
]==]

-- a doorway whose leaves swing out of the way. cf is the centre of the opening at floor level,
-- the door sits in the frame's XY plane and opens toward -Z.
function K.autoDoor(parent, cf, w, h, opts)
  opts = opts or {}
  local m = K.model(parent, opts.name or "AutoDoor")
  local col = opts.color or K.C.wood
  local mat = opts.mat or K.MAT.WoodPlanks
  local thick = opts.thick or 0.8
  local dark = col:Lerp(K.C.black, 0.3)

  K.box(m, cf * CFrame.new(-w / 2 - 0.8, h / 2, 0), Vector3.new(1.6, h + 1.6, thick + 2.4), K.MAT.Wood, dark, { name = "Jamb" })
  K.box(m, cf * CFrame.new(w / 2 + 0.8, h / 2, 0), Vector3.new(1.6, h + 1.6, thick + 2.4), K.MAT.Wood, dark, { name = "Jamb" })
  K.box(m, cf * CFrame.new(0, h + 0.8, 0), Vector3.new(w + 3.2, 1.6, thick + 2.4), K.MAT.Wood, dark, { name = "Lintel" })

  -- every moving piece records where its hinge is, measured in the door frame's own X
  local function moving(part, partX, hingeX, swing)
    K.attrs(part, { SwingDeg = swing, HingeX = hingeX - partX, HingeZ = 0 })
    return part
  end
  -- hingeSide says which edge of the leaf is nailed to the frame, -1 for its left edge and 1 for its
  -- right, and it is deliberately a separate argument from swing. tying the two together is what made
  -- double doors flap like butterfly wings: asking for a hinge on the far left edge used to force a
  -- positive swing, so the left leaf turned one way while the right leaf turned the other.
  local function leaf(centreX, lw, swing, hingeSide)
    local hingeX = centreX + hingeSide * lw / 2
    moving(K.box(m, cf * CFrame.new(centreX, h / 2, 0), Vector3.new(lw, h, thick), mat, col, { name = "Leaf" }), centreX, hingeX, swing)
    for _, f in ipairs({ 0.24, 0.76 }) do
      moving(K.box(m, cf * CFrame.new(centreX, h * f, -thick * 0.6), Vector3.new(lw * 0.94, 1, 0.4), K.MAT.Metal, K.C.iron, { name = "Band", cancollide = false }), centreX, hingeX, swing)
    end
    local hx = centreX - hingeSide * lw * 0.36     -- the handle belongs on the free edge, away from the hinge
    moving(K.ball(m, cf * CFrame.new(hx, h * 0.46, -thick * 0.9), 1, K.MAT.Metal, K.C.brass, { name = "Handle", cancollide = false }), hx, hingeX, swing)
  end

  if opts.single or w < 9 then
    local swing = opts.swing or -95
    leaf(0, w, swing, swing > 0 and -1 or 1)
  else
    -- a real double door hangs its leaves on the two far outer edges and swings them both the same way,
    -- out through the opening. the old code derived the hinge from the swing sign, so both hinges landed
    -- on the inner edges where the leaves meet and the pair flapped open like butterfly wings. now that
    -- the hinge edge is chosen separately, the two rotation signs are opposite on purpose: a rotation
    -- about the left edge and the mirrored rotation about the right edge carry both leaves out to -Z.
    leaf(-w / 4, w / 2 - 0.1, 95, -1)
    leaf(w / 4, w / 2 - 0.1, -95, 1)
  end

  K.box(m, cf * CFrame.new(0, h / 2, 0), Vector3.new(w + 3, h, 12), K.MAT.SmoothPlastic, K.C.white,
    { name = "Sensor", transparency = 1, cancollide = false })
  local s = Instance.new("Script")
  s.Name = "AutoDoor"
  s.Source = DOOR_SCRIPT
  s.Parent = m
  K.attrs(m, { CloseAfter = opts.closeAfter or 2.5 })
  return m
end

-- a barred cell door: same swing behaviour, iron bars instead of planks
function K.cellDoor(parent, cf, w, h, opts)
  opts = opts or {}
  local m = K.autoDoor(parent, cf, w, h, { name = opts.name or "CellDoor", color = K.C.iron, mat = K.MAT.Metal, thick = 0.5, single = true, swing = opts.swing or -95, closeAfter = opts.closeAfter or 4 })
  local leafPart
  for _, d in ipairs(m:GetDescendants()) do if d.Name == "Leaf" then leafPart = d end end
  if leafPart then
    leafPart.Transparency = 1
    leafPart.CanCollide = false
    local n = math.max(3, math.floor(w / 2))
    for i = 0, n do
      local x = -w / 2 + w * i / n
      local bar = K.cyl(m, leafPart.CFrame * CFrame.new(x, 0, 0), 0.32, h - 1, K.MAT.Metal, K.C.iron, { name = "Bar" })
      K.attrs(bar, { SwingDeg = leafPart:GetAttribute("SwingDeg"), HingeX = (leafPart:GetAttribute("HingeX") or 0) - x, HingeZ = 0 })
    end
    for _, f in ipairs({ 0.2, 0.8 }) do
      local rail = K.box(m, leafPart.CFrame * CFrame.new(0, (f - 0.5) * (h - 2), 0), Vector3.new(w, 0.7, 0.5), K.MAT.Metal, K.C.iron, { name = "CrossRail" })
      K.attrs(rail, { SwingDeg = leafPart:GetAttribute("SwingDeg"), HingeX = leafPart:GetAttribute("HingeX") or 0, HingeZ = 0 })
    end
  end
  return m
end

-- a run of vertical bars filling an opening: cell fronts, window grilles
function K.bars(parent, cf, w, h, opts)
  opts = opts or {}
  local m = K.model(parent, opts.name or "Bars")
  local n = math.max(2, math.floor(w / (opts.spacing or 2.2)))
  for i = 0, n do
    K.cyl(m, cf * CFrame.new(-w / 2 + w * i / n, h / 2, 0), opts.r or 0.32, h, K.MAT.Metal, opts.color or K.C.iron, { name = "Bar" })
  end
  for _, f in ipairs({ 0.25, 0.75 }) do
    K.box(m, cf * CFrame.new(0, h * f, 0), Vector3.new(w, 0.7, 0.5), K.MAT.Metal, opts.color or K.C.iron, { name = "CrossRail", cancollide = false })
  end
  return m
end
