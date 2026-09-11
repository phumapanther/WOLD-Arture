-- modelkit — standalone part-builder for WOLD Arture model design
-- conventions for every model:
--   * built in local space around the origin: base sits on y = 0, centred on x = 0 / z = 0
--   * forward = -Z (matches CFrame.LookVector), width along X, height along +Y
--   * every part Anchored; the runner parks the finished Model on a slot of the workshop grid
local K = {}
local MAT = Enum.Material
local SHAPE = Enum.PartType
local rgb = Color3.fromRGB
K.MAT, K.SHAPE = MAT, SHAPE

K.C = {
  brass = rgb(196, 150, 60), brassDark = rgb(140, 104, 38), copper = rgb(168, 96, 56), verdigris = rgb(84, 140, 120),
  iron = rgb(60, 60, 65), steel = rgb(120, 124, 130), rust = rgb(120, 70, 40), coal = rgb(32, 32, 34),
  wood = rgb(86, 66, 54), plank = rgb(159, 124, 90), plankDark = rgb(110, 82, 58), oak = rgb(133, 102, 66),
  leather = rgb(92, 60, 40), canvas = rgb(214, 200, 168), sail = rgb(235, 230, 210), rope = rgb(168, 146, 108),
  glass = rgb(150, 200, 220), lamp = rgb(255, 214, 140), crystal = rgb(120, 220, 255), ember = rgb(255, 120, 40),
  stone = rgb(163, 162, 165), darkStone = rgb(99, 95, 98), paintRed = rgb(150, 56, 48), paintBlue = rgb(58, 86, 128),
  paintGreen = rgb(72, 104, 78), white = rgb(240, 238, 232), black = rgb(24, 24, 26),
  plaster = rgb(222, 208, 190), thatch = rgb(178, 148, 88), moss = rgb(65, 105, 50), brick = rgb(136, 72, 58),
  grass = rgb(86, 128, 62), soil = rgb(96, 74, 52), slateRoof = rgb(78, 84, 92),
}

-- ---------- rotation shorthands ----------
function K.yaw(a) return CFrame.Angles(0, a, 0) end
function K.pitch(a) return CFrame.Angles(a, 0, 0) end
function K.roll(a) return CFrame.Angles(0, 0, a) end
function K.at(x, y, z) return CFrame.new(x, y, z) end
function K.deg(d) return math.rad(d) end

-- ---------- primitives ----------
function K.part(parent, shape, cf, size, mat, color, opts)
  local p = Instance.new("Part")
  p.Shape = shape or SHAPE.Block
  p.Size = size; p.CFrame = cf
  p.Material = mat or MAT.SmoothPlastic; p.Color = color or K.C.steel
  p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
  if opts then
    if opts.name then p.Name = opts.name end
    if opts.cancollide == false then p.CanCollide = false end
    if opts.transparency then p.Transparency = opts.transparency end
    if opts.reflectance then p.Reflectance = opts.reflectance end
    if opts.massless then p.Massless = true end
  end
  p.Parent = parent
  return p
end
function K.box(parent, cf, size, mat, color, opts) return K.part(parent, SHAPE.Block, cf, size, mat, color, opts) end
function K.ball(parent, cf, d, mat, color, opts) return K.part(parent, SHAPE.Ball, cf, Vector3.new(d, d, d), mat, color, opts) end
function K.cyl(parent, cf, radius, height, mat, color, opts)   -- upright cylinder (Roblox cylinder axis is X, so roll 90 deg)
  return K.part(parent, SHAPE.Cylinder, cf * K.roll(math.pi / 2), Vector3.new(height, radius * 2, radius * 2), mat, color, opts)
end
function K.cylX(parent, cf, radius, len, mat, color, opts)     -- cylinder lying along the frame's own X axis
  return K.part(parent, SHAPE.Cylinder, cf, Vector3.new(len, radius * 2, radius * 2), mat, color, opts)
end
function K.rod(parent, a, b, radius, mat, color, opts)         -- cylinder spanning point a to point b
  local len = (b - a).Magnitude
  if len < 1e-3 then return nil end
  local cf = CFrame.lookAt((a + b) / 2, b) * K.yaw(math.pi / 2)
  return K.part(parent, SHAPE.Cylinder, cf, Vector3.new(len, radius * 2, radius * 2), mat, color, opts)
end
function K.wedge(parent, cf, size, mat, color, opts)
  local p = Instance.new("WedgePart"); p.Size = size; p.CFrame = cf
  p.Material = mat or MAT.Wood; p.Color = color or K.C.plank; p.Anchored = true
  if opts then
    if opts.name then p.Name = opts.name end
    if opts.cancollide == false then p.CanCollide = false end
    if opts.transparency then p.Transparency = opts.transparency end
  end
  p.Parent = parent; return p
end
function K.cwedge(parent, cf, size, mat, color, opts)
  local p = Instance.new("CornerWedgePart"); p.Size = size; p.CFrame = cf
  p.Material = mat or MAT.Wood; p.Color = color or K.C.plank; p.Anchored = true
  if opts and opts.name then p.Name = opts.name end
  if opts and opts.cancollide == false then p.CanCollide = false end
  p.Parent = parent; return p
end
function K.model(parent, name) local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m end

-- ---------- steampunk greebles ----------
function K.rivets(parent, a, b, n, r, color)                   -- a line of rivet heads from a to b
  local m = K.model(parent, "Rivets")
  for i = 0, n - 1 do
    local t = n == 1 and 0.5 or i / (n - 1)
    K.ball(m, CFrame.new(a:Lerp(b, t)), (r or 0.35) * 2, MAT.Metal, color or K.C.brassDark, { cancollide = false, massless = true })
  end
  return m
end
function K.rivetRing(parent, cf, radius, n, r, color)          -- rivets around the cf's XY plane
  local m = K.model(parent, "RivetRing")
  for i = 0, n - 1 do
    local a = i * 2 * math.pi / n
    K.ball(m, cf * CFrame.new(math.cos(a) * radius, math.sin(a) * radius, 0), (r or 0.35) * 2, MAT.Metal, color or K.C.brassDark, { cancollide = false, massless = true })
  end
  return m
end
function K.band(parent, cf, radius, thick, color)              -- reinforcing hoop around an upright cylinder
  return K.cyl(parent, cf, radius, thick, MAT.Metal, color or K.C.brassDark, { cancollide = false, name = "Band" })
end
function K.gear(parent, cf, r, teeth, thick, color)            -- gear facing the cf's own X axis
  local m = K.model(parent, "Gear")
  K.cylX(m, cf, r, thick, MAT.Metal, color or K.C.brass, { cancollide = false })
  K.cylX(m, cf, r * 0.22, thick * 1.4, MAT.Metal, K.C.iron, { cancollide = false, name = "Hub" })
  local tw = math.max(0.3, r * 0.3)
  for i = 0, teeth - 1 do
    local a = i * 2 * math.pi / teeth
    K.box(m, cf * CFrame.Angles(a, 0, 0) * CFrame.new(0, r + r * 0.11, 0), Vector3.new(thick, r * 0.24, tw), MAT.Metal, color or K.C.brass, { cancollide = false })
  end
  return m
end
function K.pipe(parent, pts, radius, color, opts)              -- rods with ball joints through a list of Vector3
  local m = K.model(parent, (opts and opts.name) or "Pipe")
  for i = 1, #pts - 1 do
    K.rod(m, pts[i], pts[i + 1], radius, MAT.Metal, color or K.C.copper, { cancollide = false })
    K.ball(m, CFrame.new(pts[i]), radius * 2.6, MAT.Metal, color or K.C.brassDark, { cancollide = false })
  end
  K.ball(m, CFrame.new(pts[#pts]), radius * 2.6, MAT.Metal, color or K.C.brassDark, { cancollide = false })
  return m
end
function K.boiler(parent, cf, r, h, opts)                      -- riveted upright tank with hoops and end caps
  opts = opts or {}
  local m = K.model(parent, opts.name or "Boiler")
  local col = opts.color or K.C.copper
  K.cyl(m, cf, r, h, MAT.Metal, col, { cancollide = false })
  K.cyl(m, cf * CFrame.new(0, h / 2, 0), r * 1.06, r * 0.28, MAT.Metal, K.C.brassDark, { cancollide = false, name = "CapTop" })
  K.cyl(m, cf * CFrame.new(0, -h / 2, 0), r * 1.06, r * 0.28, MAT.Metal, K.C.brassDark, { cancollide = false, name = "CapBase" })
  local bands = opts.bands or 2
  for i = 1, bands do
    local y = -h / 2 + h * i / (bands + 1)
    K.band(m, cf * CFrame.new(0, y, 0), r * 1.05, r * 0.16)
    K.rivetRing(m, cf * CFrame.new(0, y, 0) * K.pitch(math.pi / 2), r * 1.02, opts.rivets or 10, r * 0.07)
  end
  if opts.firebox then
    K.box(m, cf * CFrame.new(0, -h / 2 + r * 0.5, -r * 0.98), Vector3.new(r * 0.9, r * 0.9, r * 0.2), MAT.Neon, K.C.ember, { cancollide = false, name = "Firebox" })
  end
  return m
end
function K.valveWheel(parent, cf, r, spokes, color)            -- hand wheel facing the cf's own X axis
  local m = K.model(parent, "ValveWheel")
  local col = color or K.C.brass
  local n = spokes or 5
  K.cylX(m, cf, r * 0.16, r * 0.5, MAT.Metal, K.C.iron, { cancollide = false, name = "Stem" })
  for i = 0, n - 1 do
    local a = i * 2 * math.pi / n
    K.box(m, cf * CFrame.Angles(a, 0, 0) * CFrame.new(0, r / 2, 0), Vector3.new(r * 0.14, r, r * 0.14), MAT.Metal, col, { cancollide = false })
  end
  for i = 0, 23 do                                              -- rim built from short chords
    local a0, a1 = i * math.pi / 12, (i + 1) * math.pi / 12
    K.rod(m, (cf * CFrame.new(0, math.cos(a0) * r, math.sin(a0) * r)).Position,
             (cf * CFrame.new(0, math.cos(a1) * r, math.sin(a1) * r)).Position, r * 0.1, MAT.Metal, col, { cancollide = false })
  end
  return m
end
function K.porthole(parent, cf, r, opts)                       -- glass disc + brass ring, faces the cf's own X axis
  opts = opts or {}
  local m = K.model(parent, opts.name or "Porthole")
  K.cylX(m, cf, r, 0.3, MAT.Glass, opts.glass or K.C.glass, { cancollide = false, transparency = 0.55, reflectance = 0.2, name = "Glass" })
  for i = 0, 23 do
    local a0, a1 = i * math.pi / 12, (i + 1) * math.pi / 12
    K.rod(m, (cf * CFrame.new(0, math.cos(a0) * r, math.sin(a0) * r)).Position,
             (cf * CFrame.new(0, math.cos(a1) * r, math.sin(a1) * r)).Position, r * 0.13, MAT.Metal, opts.color or K.C.brass, { cancollide = false })
  end
  K.rivetRing(m, cf * K.yaw(math.pi / 2), r * 1.05, opts.rivets or 8, r * 0.08)
  return m
end
function K.gauge(parent, cf, r, color)                         -- pressure dial facing the cf's own X axis
  local m = K.model(parent, "Gauge")
  K.cylX(m, cf, r, r * 0.35, MAT.Metal, color or K.C.brass, { cancollide = false, name = "Case" })
  K.cylX(m, cf * CFrame.new(r * 0.22, 0, 0), r * 0.82, r * 0.1, MAT.SmoothPlastic, K.C.white, { cancollide = false, name = "Face" })
  K.box(m, cf * CFrame.new(r * 0.3, r * 0.3, 0) * CFrame.Angles(math.rad(35), 0, 0), Vector3.new(r * 0.08, r * 0.7, r * 0.08), MAT.SmoothPlastic, K.C.black, { cancollide = false, name = "Needle" })
  return m
end
function K.smokestack(parent, cf, r, h, opts)                  -- funnel with a flared cap; base at the cf origin
  opts = opts or {}
  local m = K.model(parent, opts.name or "Smokestack")
  local col = opts.color or K.C.iron
  local body = K.cyl(m, cf * CFrame.new(0, h / 2, 0), r, h, MAT.Metal, col, { cancollide = false, name = "Stack" })
  K.cyl(m, cf * CFrame.new(0, h, 0), r * 1.35, r * 0.5, MAT.Metal, opts.cap or K.C.brassDark, { cancollide = false, name = "Cap" })
  K.band(m, cf * CFrame.new(0, h * 0.45, 0), r * 1.1, r * 0.25)
  if opts.smoke then
    local s = Instance.new("Smoke"); s.Size = r * 2; s.RiseVelocity = 6; s.Opacity = 0.25; s.Color = rgb(90, 90, 95); s.Parent = body
  end
  return m
end
function K.lantern(parent, cf, s, color)                       -- caged glass lamp, base at the cf origin
  local m = K.model(parent, "Lantern")
  K.cyl(m, cf * CFrame.new(0, s * 0.5, 0), s * 0.42, s, MAT.Glass, K.C.glass, { cancollide = false, transparency = 0.5, name = "Glass" })
  local flame = K.cyl(m, cf * CFrame.new(0, s * 0.5, 0), s * 0.2, s * 0.6, MAT.Neon, color or K.C.lamp, { cancollide = false, name = "Flame" })
  K.cyl(m, cf, s * 0.5, s * 0.16, MAT.Metal, K.C.brassDark, { cancollide = false, name = "Base" })
  K.cyl(m, cf * CFrame.new(0, s, 0), s * 0.5, s * 0.16, MAT.Metal, K.C.brassDark, { cancollide = false, name = "Top" })
  for i = 0, 3 do
    local a = i * math.pi / 2
    K.box(m, cf * CFrame.new(math.cos(a) * s * 0.42, s * 0.5, math.sin(a) * s * 0.42), Vector3.new(s * 0.08, s, s * 0.08), MAT.Metal, K.C.brassDark, { cancollide = false })
  end
  local l = Instance.new("PointLight"); l.Color = color or K.C.lamp; l.Range = s * 10; l.Brightness = 1.6; l.Parent = flame
  return m
end
function K.propeller(parent, cf, r, blades, color)             -- spins about the cf's own X axis
  local m = K.model(parent, "Propeller")
  local n = blades or 4
  K.cylX(m, cf, r * 0.16, r * 0.4, MAT.Metal, K.C.iron, { cancollide = false, name = "Hub" })
  for i = 0, n - 1 do
    local a = i * 2 * math.pi / n
    K.box(m, cf * CFrame.Angles(a, 0, 0) * CFrame.new(0, r / 2, 0) * CFrame.Angles(0, 0, math.rad(20)),
      Vector3.new(r * 0.1, r, r * 0.34), MAT.Metal, color or K.C.brass, { cancollide = false, name = "Blade" })
  end
  return m
end
function K.paddleWheel(parent, cf, r, w, blades)               -- side paddle wheel about the cf's own X axis
  local m = K.model(parent, "PaddleWheel")
  local n = blades or 8
  K.cylX(m, cf, r * 0.14, w * 1.2, MAT.Metal, K.C.iron, { cancollide = false, name = "Axle" })
  for _, side in ipairs({ -w / 2, w / 2 }) do
    for i = 0, 23 do
      local a0, a1 = i * math.pi / 12, (i + 1) * math.pi / 12
      K.rod(m, (cf * CFrame.new(side, math.cos(a0) * r, math.sin(a0) * r)).Position,
               (cf * CFrame.new(side, math.cos(a1) * r, math.sin(a1) * r)).Position, r * 0.07, MAT.Metal, K.C.brassDark, { cancollide = false })
    end
  end
  for i = 0, n - 1 do
    local a = i * 2 * math.pi / n
    K.box(m, cf * CFrame.Angles(a, 0, 0) * CFrame.new(0, r * 0.82, 0), Vector3.new(w, r * 0.4, 0.5), MAT.Wood, K.C.plankDark, { cancollide = false, name = "Paddle" })
    K.rod(m, (cf * CFrame.Angles(a, 0, 0) * CFrame.new(-w / 2, 0, 0)).Position,
             (cf * CFrame.Angles(a, 0, 0) * CFrame.new(-w / 2, r, 0)).Position, r * 0.06, MAT.Metal, K.C.brassDark, { cancollide = false })
  end
  return m
end
function K.spring(parent, a, b, r, coils, color)               -- coil approximated with short rods
  local m = K.model(parent, "Spring")
  local up = (b - a)
  local c = coils or 6
  local n = c * 8
  local side = up.Unit:Cross(Vector3.new(0, 0, 1))
  if side.Magnitude < 0.1 then side = up.Unit:Cross(Vector3.new(1, 0, 0)) end
  side = side.Unit
  local other = up.Unit:Cross(side).Unit
  local prev
  for i = 0, n do
    local t = i / n
    local ang = t * c * 2 * math.pi
    local p = a:Lerp(b, t) + side * math.cos(ang) * r + other * math.sin(ang) * r
    if prev then K.rod(m, prev, p, r * 0.18, MAT.Metal, color or K.C.steel, { cancollide = false }) end
    prev = p
  end
  return m
end
function K.chain(parent, a, b, links, r, color)
  local m = K.model(parent, "Chain")
  for i = 0, links - 1 do
    K.rod(m, a:Lerp(b, i / links), a:Lerp(b, (i + 1) / links), r or 0.15, MAT.Metal, color or K.C.iron, { cancollide = false })
  end
  return m
end
function K.plankFloor(parent, cf, w, d, plankW, color, mat)    -- deck of planks running along Z, centred on cf
  local m = K.model(parent, "Deck")
  local n = math.max(1, math.floor(w / (plankW or 2)))
  local pw = w / n
  local base = color or K.C.plank
  for i = 0, n - 1 do
    local x = -w / 2 + pw * (i + 0.5)
    local tint = (i % 2 == 0) and base or base:Lerp(K.C.plankDark, 0.35)
    K.box(m, cf * CFrame.new(x, 0, 0), Vector3.new(pw * 0.94, 0.4, d), mat or MAT.WoodPlanks, tint, { name = "Plank" })
  end
  return m
end
function K.crate(parent, cf, s, color)
  local m = K.model(parent, "Crate")
  K.box(m, cf * CFrame.new(0, s / 2, 0), Vector3.new(s, s, s), MAT.WoodPlanks, color or K.C.oak)
  for _, e in ipairs({ Vector3.new(0, 0, 1), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) }) do
    K.box(m, cf * CFrame.new(e.X * s / 2, s / 2, e.Z * s / 2), Vector3.new(e.X ~= 0 and 0.2 or s, s * 0.16, e.Z ~= 0 and 0.2 or s), MAT.Metal, K.C.iron, { cancollide = false })
  end
  return m
end
function K.barrel(parent, cf, r, h, color)
  local m = K.model(parent, "Barrel")
  K.cyl(m, cf * CFrame.new(0, h / 2, 0), r, h, MAT.WoodPlanks, color or K.C.wood)
  K.band(m, cf * CFrame.new(0, h * 0.22, 0), r * 1.05, h * 0.1)
  K.band(m, cf * CFrame.new(0, h * 0.78, 0), r * 1.05, h * 0.1)
  return m
end
function K.sign(parent, cf, text, w, h, color, textColor)      -- board reading out of its own -Z face, like every model's front
  local m = K.model(parent, "Sign")
  local b = K.box(m, cf, Vector3.new(w, h, 0.4), MAT.Wood, color or K.C.wood, { name = "Board" })
  local g = Instance.new("SurfaceGui"); g.Face = Enum.NormalId.Front; g.CanvasSize = Vector2.new(w * 50, h * 50); g.Parent = b
  local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1
  t.Text = text; t.TextScaled = true; t.Font = Enum.Font.Garamond; t.TextColor3 = textColor or K.C.brass; t.Parent = g
  return m
end

-- ---------- buildings ----------
-- A gable roof as a SHELL: two sloped slabs and a triangle closing each end.
--
-- It used to be two solid wedges, which fills the whole attic with stone: a loft laid at the eaves
-- line had its beds inside the roof and no way to stand up in it. Same shape from outside, hollow
-- underneath, which is what a roof is.
function K.roofGable(parent, cf, w, d, h, mat, color, overhang, thick)
  local m = K.model(parent, "Roof")
  local o = overhang or 0
  local W, D = w + o * 2, d + o * 2
  local t = thick or 1.8
  local slope = math.sqrt((W / 2) ^ 2 + h ^ 2)
  local ang = math.atan2(h, W / 2)
  for _, s in ipairs({ -1, 1 }) do
    K.box(m, cf * CFrame.new(s * W / 4, h / 2, 0) * CFrame.Angles(0, 0, -s * ang) * CFrame.new(0, t / 2, 0),
      Vector3.new(slope, t, D), mat, color, { name = "Slope" })
    for _, sz in ipairs({ -1, 1 }) do              -- the gable ends, so the attic is closed
      K.wedge(m, cf * CFrame.new(s * W / 4, h / 2, sz * (D / 2 - 0.9)) * K.yaw(-s * math.pi / 2),
        Vector3.new(1.8, h, W / 2), mat, color, { name = "GableEnd" })
    end
  end
  return m
end
-- stepped cone, the shape a thatched or shingled round roof reads as
function K.roofCone(parent, cf, r, h, mat, color, steps)
  local m = K.model(parent, "ConeRoof")
  local n = steps or 7
  for i = 0, n - 1 do
    local t0, t1 = i / n, (i + 1) / n
    K.cyl(m, cf * CFrame.new(0, h * (t0 + t1) / 2, 0), r * (1 - t0 * 0.94), h / n * 1.08, mat, color, { name = "Course" })
  end
  K.cyl(m, cf * CFrame.new(0, h, 0), r * 0.1, h * 0.12, mat, color, { name = "Peak" })
  return m
end
-- window in the -Z face of cf: frame, mullions and glass that can be lit from inside
function K.window(parent, cf, w, h, frameColor, lit)
  local m = K.model(parent, "Window")
  local fc = frameColor or K.C.wood
  K.box(m, cf, Vector3.new(w + 0.5, h + 0.5, 0.5), MAT.Wood, fc, { name = "Frame" })
  local glass = K.box(m, cf * CFrame.new(0, 0, -0.12), Vector3.new(w, h, 0.3),
    lit and MAT.Neon or MAT.Glass, lit and K.C.lamp or K.C.glass,
    { name = "Glass", cancollide = false, transparency = lit and 0 or 0.5 })
  K.box(m, cf * CFrame.new(0, 0, -0.2), Vector3.new(0.18, h, 0.2), MAT.Wood, fc, { name = "Mullion", cancollide = false })
  K.box(m, cf * CFrame.new(0, 0, -0.2), Vector3.new(w, 0.18, 0.2), MAT.Wood, fc, { name = "Mullion", cancollide = false })
  if lit then
    local l = Instance.new("PointLight"); l.Color = K.C.lamp; l.Range = 14; l.Brightness = 1.1; l.Parent = glass
  end
  return m
end
-- doorway in the -Z face of cf, base at the cf origin
function K.doorway(parent, cf, w, h, color, mat)
  local m = K.model(parent, "Door")
  local c = color or K.C.wood
  K.box(m, cf * CFrame.new(0, h / 2, 0), Vector3.new(w, h, 0.4), mat or MAT.WoodPlanks, c, { name = "Leaf" })
  K.box(m, cf * CFrame.new(-w / 2 - 0.25, h / 2, 0.1), Vector3.new(0.5, h + 0.5, 0.7), MAT.Wood, c:Lerp(K.C.black, 0.3), { name = "Jamb" })
  K.box(m, cf * CFrame.new(w / 2 + 0.25, h / 2, 0.1), Vector3.new(0.5, h + 0.5, 0.7), MAT.Wood, c:Lerp(K.C.black, 0.3), { name = "Jamb" })
  K.box(m, cf * CFrame.new(0, h + 0.35, 0.1), Vector3.new(w + 1.4, 0.6, 0.7), MAT.Wood, c:Lerp(K.C.black, 0.3), { name = "Lintel" })
  K.ball(m, cf * CFrame.new(w * 0.3, h * 0.5, -0.28), 0.35, MAT.Metal, K.C.brass, { name = "Handle", cancollide = false })
  K.rivets(m, (cf * CFrame.new(-w * 0.35, h * 0.2, -0.24)).Position, (cf * CFrame.new(w * 0.35, h * 0.2, -0.24)).Position, 4, 0.12, K.C.brassDark)
  return m
end
-- plastered panel crossed by dark timbers, the medieval half-timbered look
function K.timberWall(parent, cf, w, h, d, plaster, beam)
  local m = K.model(parent, "TimberWall")
  local pc, bc = plaster or K.C.plaster, beam or K.C.wood
  K.box(m, cf * CFrame.new(0, h / 2, 0), Vector3.new(w, h, d), MAT.Plaster, pc, { name = "Panel" })
  local t = 0.6
  for _, x in ipairs({ -w / 2 + t / 2, w / 2 - t / 2 }) do
    K.box(m, cf * CFrame.new(x, h / 2, -d / 2 - 0.05), Vector3.new(t, h, 0.35), MAT.Wood, bc, { name = "Post", cancollide = false })
  end
  for _, y in ipairs({ t / 2, h - t / 2 }) do
    K.box(m, cf * CFrame.new(0, y, -d / 2 - 0.05), Vector3.new(w, t, 0.35), MAT.Wood, bc, { name = "Rail", cancollide = false })
  end
  local diag = math.sqrt(w * w + h * h)
  for _, sgn in ipairs({ 1, -1 }) do
    K.box(m, cf * CFrame.new(0, h / 2, -d / 2 - 0.05) * K.roll(sgn * math.atan2(h, w)), Vector3.new(diag, t * 0.7, 0.3), MAT.Wood, bc, { name = "Brace", cancollide = false })
  end
  return m
end
function K.lampPost(parent, cf, h, color)
  local m = K.model(parent, "LampPost")
  K.cyl(m, cf * CFrame.new(0, h / 2, 0), 0.32, h, MAT.Metal, K.C.iron, { name = "Post" })
  K.cyl(m, cf * CFrame.new(0, 0.3, 0), 0.75, 0.6, MAT.Metal, K.C.iron, { name = "Foot" })
  K.lantern(m, cf * CFrame.new(0, h, 0), 2.4, color)
  return m
end
function K.banner(parent, cf, w, h, color, poleH)
  local m = K.model(parent, "Banner")
  local ph = poleH or h + 6
  K.cyl(m, cf * CFrame.new(0, ph / 2, 0), 0.28, ph, MAT.Metal, K.C.iron, { name = "Pole" })
  K.ball(m, cf * CFrame.new(0, ph, 0), 0.9, MAT.Metal, K.C.brass, { name = "Finial", cancollide = false })
  K.box(m, cf * CFrame.new(0, ph - h / 2 - 1, 0.3), Vector3.new(w, h, 0.16), MAT.Fabric, color or K.C.paintRed, { name = "Cloth", cancollide = false })
  K.box(m, cf * CFrame.new(0, ph - 1, 0.3), Vector3.new(w + 0.6, 0.3, 0.4), MAT.Metal, K.C.brassDark, { name = "Crossbar", cancollide = false })
  return m
end

-- ---------- helpers ----------
function K.tag(inst, tagName, attrs)
  game:GetService("CollectionService"):AddTag(inst, tagName)
  if attrs then for k, v in pairs(attrs) do inst:SetAttribute(k, v) end end
  return inst
end
function K.attrs(inst, t) for k, v in pairs(t) do inst:SetAttribute(k, v) end; return inst end
function K.mirrorX(parent, source)                             -- clone a group mirrored across x = 0
  local c = source:Clone(); c.Name = source.Name .. "_M"; c.Parent = parent
  for _, d in ipairs(c:GetDescendants()) do
    if d:IsA("BasePart") then
      local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = d.CFrame:GetComponents()
      d.CFrame = CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
    end
  end
  return c
end
function K.arrayAlong(a, b, n, fn)                             -- call fn(pos, i, t) at n points from a to b
  for i = 0, n - 1 do
    local t = n == 1 and 0.5 or i / (n - 1)
    fn(a:Lerp(b, t), i, t)
  end
end
function K.countParts(inst)
  local c = 0
  for _, d in ipairs(inst:GetDescendants()) do if d:IsA("BasePart") then c += 1 end end
  return c
end

-- ---------- workshop runner ----------
K.ROOT_NAME = "MODELKIT"
K.SLOT = 160          -- studs between display slots
K.BASE_Y = 8          -- grid sits above the baseplate so pads never z-fight with it
K.PER_ROW = 5
K.SET = "default"     -- each set numbers its own slots from 0, so sets never fight over the grid
K.ORIGIN = Vector3.new(0, 0, 0)   -- where this set's grid starts; give every set its own patch of ground

function K.root()
  local r = workspace:FindFirstChild(K.ROOT_NAME)
  if not r then r = Instance.new("Folder"); r.Name = K.ROOT_NAME; r.Parent = workspace end
  return r
end
function K.progress(msg) K.root():SetAttribute("Progress", msg); print("[MODELKIT] " .. msg) end

-- neutral studio lighting so colours and materials read true in screenshots
function K.setupLighting()
  local L = game:GetService("Lighting")
  L.ClockTime = 14; L.GeographicLatitude = 12
  L.Brightness = 2.2; L.ExposureCompensation = 0
  L.Ambient = rgb(72, 72, 76); L.OutdoorAmbient = rgb(126, 128, 134)
  L.EnvironmentDiffuseScale = 0.45; L.EnvironmentSpecularScale = 0.55
  L.GlobalShadows = true; L.ShadowSoftness = 0.3
  L.FogEnd = 100000
  local atm = L:FindFirstChildOfClass("Atmosphere"); if atm then atm:Destroy() end
  if not L:FindFirstChildOfClass("Sky") then Instance.new("Sky", L) end
end

local function slotIndex(root, name)                           -- stable slot per model name; reuse the one already assigned
  local key = "Order_" .. K.SET
  local order = root:GetAttribute(key)
  local list = order and string.split(order, "|") or {}
  for i, n in ipairs(list) do if n == name then return i - 1 end end
  table.insert(list, name)
  root:SetAttribute(key, table.concat(list, "|"))
  return #list - 1
end
function K.slotCFrame(i)
  local col, row = i % K.PER_ROW, math.floor(i / K.PER_ROW)
  return CFrame.new(K.ORIGIN.X + col * K.SLOT, K.BASE_Y + K.ORIGIN.Y, K.ORIGIN.Z + row * K.SLOT)
end
local function makePad(root, i, name)
  local pads = root:FindFirstChild("Pads")
  if not pads then pads = Instance.new("Folder"); pads.Name = "Pads"; pads.Parent = root end
  local old = pads:FindFirstChild("Pad_" .. name); if old then old:Destroy() end
  local m = Instance.new("Model"); m.Name = "Pad_" .. name; m.Parent = pads
  local cf = K.slotCFrame(i)
  local w = K.SLOT * 0.72
  K.box(m, cf * CFrame.new(0, -0.5, 0), Vector3.new(w, 1, w), MAT.Concrete, rgb(70, 72, 76), { name = "Pad" })
  K.box(m, cf * CFrame.new(0, -0.4, 0), Vector3.new(w, 0.2, 2), MAT.SmoothPlastic, rgb(120, 122, 128), { name = "AxisZ", cancollide = false })
  K.box(m, cf * CFrame.new(0, -0.4, 0), Vector3.new(2, 0.2, w), MAT.SmoothPlastic, rgb(120, 122, 128), { name = "AxisX", cancollide = false })
  K.box(m, cf * CFrame.new(0, -0.35, -w * 0.40), Vector3.new(w * 0.14, 0.3, w * 0.16), MAT.Neon, rgb(90, 200, 255), { name = "FrontMark", cancollide = false })  -- -Z is the model's front
  local sw = math.clamp(w * 0.78, 8, 40)                                                       -- nameplate scales with the pad
  K.sign(m, cf * CFrame.new(0, sw * 0.2, w * 0.48), name, sw, sw * 0.26, rgb(26, 26, 30), rgb(238, 226, 196))  -- reads toward the pad front
  return m
end

-- when REGISTER_ONLY is set, K.build only files the builder away under K.builders instead of
-- raising it on the workshop grid. that is how a mapgen phase reuses the same model files to put
-- buildings on real plots: load the model files, then call K.place for the ones it wants.
K.builders = {}
K.REGISTER_ONLY = false

-- raise a registered model into `parent` and set it down on `cf`: base at cf, front along cf's -Z
-- True only while K.place is running a builder, so a builder can tell the difference between being made for
-- the world and being made for the showcase. The showcase seats each model on a dark disc; out in the world
-- that disc is a black plate stuck to the model's feet, following it around.
--
-- REGISTER_ONLY cannot answer this: it is true while the builders are being FILED AWAY and false again by
-- the time one of them actually runs, so a builder reading it during a place always sees false.
K.IN_WORLD = false

function K.place(name, parent, cf)
  local b = K.builders[name]
  if not b then warn("[MODELKIT] no builder named " .. tostring(name)); return nil end
  local m = Instance.new("Model")
  m.Name = name
  K.IN_WORLD = true
  local ok, err = pcall(b.fn, m)
  K.IN_WORLD = false
  if not ok then warn("[MODELKIT] " .. name .. " failed: " .. tostring(err)); m:Destroy(); return nil end
  local anchor = Instance.new("Part")
  anchor.Name = "Root"; anchor.Size = Vector3.new(1, 1, 1); anchor.CFrame = CFrame.new(0, 0, 0)
  anchor.Transparency = 1; anchor.CanCollide = false; anchor.Anchored = true; anchor.Massless = true
  anchor.Parent = m
  m.PrimaryPart = anchor
  m.Parent = parent
  m:PivotTo(cf)
  K.attrs(m, { Kit = true, Parts = K.countParts(m) })
  return m
end

-- build one model: K.build("Name", { pad = false }, function(m) ... end)
function K.build(name, opts, fn)
  opts = opts or {}
  if K.REGISTER_ONLY then K.builders[name] = { opts = opts, fn = fn }; return end
  local root = K.root()
  K.setupLighting()
  root:SetAttribute("Status", "running")
  root:SetAttribute("Model", name)
  K.progress(name .. " start")
  local ok, err = pcall(function()
    local i = slotIndex(root, name)
    local old = root:FindFirstChild(name); if old then old:Destroy() end
    if opts.pad ~= false then makePad(root, i, name) end
    local m = Instance.new("Model"); m.Name = name
    fn(m)
    local anchor = Instance.new("Part")                        -- pivot handle at the base centre
    anchor.Name = "Root"; anchor.Size = Vector3.new(1, 1, 1); anchor.CFrame = CFrame.new(0, 0, 0)
    anchor.Transparency = 1; anchor.CanCollide = false; anchor.Anchored = true; anchor.Massless = true
    anchor.Parent = m
    m.PrimaryPart = anchor
    m.Parent = root
    m.WorldPivot = CFrame.new(0, 0, 0)
    local _, size = m:GetBoundingBox()
    m:PivotTo(K.slotCFrame(i))
    K.attrs(m, { Kit = true, Set = K.SET, Slot = i, Parts = K.countParts(m), SizeX = size.X, SizeY = size.Y, SizeZ = size.Z })
    K.progress(("%s done - %d parts, %.0f x %.0f x %.0f"):format(name, K.countParts(m), size.X, size.Y, size.Z))
  end)
  if ok then root:SetAttribute("Status", "done")
  else root:SetAttribute("Status", "error: " .. tostring(err)); warn("[MODELKIT] " .. name .. " ERROR " .. tostring(err)) end
end

return K
