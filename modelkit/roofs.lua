-- roofs — the roof shapes a town needs beyond a plain gable, all in the same idiom:
-- cf is the eaves line at the top of the walls, w runs along X, d along Z, h is the rise.
-- loaded after interior2.lua, so it just adds to K.
--
-- a WedgePart's tall face is its own +Z and it slopes down toward -Z, which is why every piece
-- below is yawed rather than positioned by hand: the yaw is what points the tall face at the ridge.

-- hip roof: slopes on all four sides, ridge along Z, shorter than the plan so the ends slope in
function K.roofHip(parent, cf, w, d, h, mat, color, overhang)
  local m = K.model(parent, "HipRoof")
  local o = overhang or 0
  local W, D = w + o * 2, d + o * 2
  local ridge = math.max(D * 0.2, D - W)          -- the flat part of the ridge; the rest hips in
  local hipRun = (D - ridge) / 2
  for _, s in ipairs({ -1, 1 }) do                -- the two long slopes, cut back by the hips
    K.wedge(m, cf * CFrame.new(s * W / 4, h / 2, 0) * K.yaw(s > 0 and -math.pi / 2 or math.pi / 2),
      Vector3.new(ridge, h, W / 2), mat, color)
  end
  for _, s in ipairs({ -1, 1 }) do                -- the two hip ends
    K.wedge(m, cf * CFrame.new(0, h / 2, s * (ridge / 2 + hipRun / 2)) * K.yaw(s > 0 and math.pi or 0),
      Vector3.new(W, h, hipRun), mat, color)
  end
  K.box(m, cf * CFrame.new(0, h, 0), Vector3.new(1.4, 1.4, ridge), mat, color:Lerp(K.C.black, 0.2), { name = "RidgeCap", cancollide = false })
  return m
end

-- pyramid roof: a hip with no ridge at all, for square towers
function K.roofPyramid(parent, cf, w, d, h, mat, color, overhang)
  local m = K.model(parent, "PyramidRoof")
  local o = overhang or 0
  local W, D = w + o * 2, d + o * 2
  for _, s in ipairs({ -1, 1 }) do
    K.wedge(m, cf * CFrame.new(s * W / 4, h / 2, 0) * K.yaw(s > 0 and -math.pi / 2 or math.pi / 2), Vector3.new(D * 0.02, h, W / 2), mat, color)
    K.wedge(m, cf * CFrame.new(0, h / 2, s * D / 4) * K.yaw(s > 0 and math.pi or 0), Vector3.new(W, h, D / 2), mat, color)
  end
  K.ball(m, cf * CFrame.new(0, h + 0.6, 0), 2.4, K.MAT.Metal, K.C.brassDark, { name = "Finial", cancollide = false })
  return m
end

-- mansard: a steep lower pitch to a shallow upper one, so the attic is a real room
function K.roofMansard(parent, cf, w, d, h, mat, color, overhang)
  local m = K.model(parent, "MansardRoof")
  local o = overhang or 0
  local W, D = w + o * 2, d + o * 2
  local lowH, upH = h * 0.62, h * 0.38
  local inset = W * 0.22
  for _, s in ipairs({ -1, 1 }) do                -- steep lower slopes, long sides
    K.wedge(m, cf * CFrame.new(s * (W / 2 - inset / 2), lowH / 2, 0) * K.yaw(s > 0 and -math.pi / 2 or math.pi / 2),
      Vector3.new(D, lowH, inset), mat, color)
  end
  for _, s in ipairs({ -1, 1 }) do                -- steep lower slopes, ends
    K.wedge(m, cf * CFrame.new(0, lowH / 2, s * (D / 2 - inset / 2)) * K.yaw(s > 0 and math.pi or 0),
      Vector3.new(W - inset * 2, lowH, inset), mat, color)
  end
  K.box(m, cf * CFrame.new(0, lowH + 0.4, 0), Vector3.new(W - inset * 1.6, 0.8, D - inset * 1.6), mat, color:Lerp(K.C.black, 0.15), { name = "Break" })
  K.roofHip(m, cf * CFrame.new(0, lowH + 0.8, 0), W - inset * 2, D - inset * 2, upH, mat, color, 0.6)
  return m
end

-- shed roof: one slope, for lean-tos and outbuildings. falls toward -Z.
function K.roofShed(parent, cf, w, d, h, mat, color, overhang)
  local m = K.model(parent, "ShedRoof")
  local o = overhang or 0
  K.wedge(m, cf * CFrame.new(0, h / 2, 0) * K.yaw(math.pi), Vector3.new(w + o * 2, h, d + o * 2), mat, color)
  return m
end

-- barrel vault: stepped courses approximating a half cylinder, ridge along Z
function K.roofBarrel(parent, cf, w, d, h, mat, color, steps)
  local m = K.model(parent, "BarrelRoof")
  local n = steps or 9
  for i = 0, n - 1 do
    local t0, t1 = i / n, (i + 1) / n
    local y = h * math.sin(t0 * math.pi / 2)
    local half = (w / 2) * math.cos(t0 * math.pi / 2)
    local rise = h * math.sin(t1 * math.pi / 2) - y
    K.box(m, cf * CFrame.new(0, y + rise / 2, 0), Vector3.new(half * 2, math.max(rise, 0.6), d), mat, color, { name = "Course" })
  end
  return m
end

-- a battlemented flat top: deck, parapet and crenellations. what a fighting tower has
-- instead of a roof. returns the deck height so a stair can be aimed at it.
function K.roofBattlement(parent, cf, w, d, opts)
  opts = opts or {}
  local m = K.model(parent, "Battlement")
  local mat = opts.mat or K.MAT.Slate
  local col = opts.color or K.C.darkStone
  local step = opts.step or 7
  local merlon = opts.merlon or 5
  local over = opts.overhang or 2
  -- the deck, with an optional hatch for a stair arriving from the floor below: without one the
  -- fighting top of a tower is a place only the roof can see
  if opts.hole then
    K.floorSlab(m, cf, w + over * 2, d + over * 2, mat, col, { name = "Deck", hole = opts.hole })
  else
    K.box(m, cf * CFrame.new(0, -1, 0), Vector3.new(w + over * 2, 2, d + over * 2), mat, col, { name = "Deck" })
  end
  local function run(len, at, yaw, gap)
    local segs = { { -len / 2, len / 2 } }
    if gap then segs = { { -len / 2, gap.at - gap.w / 2 }, { gap.at + gap.w / 2, len / 2 } } end
    for _, s in ipairs(segs) do
      local L = s[2] - s[1]
      if L > 0.5 then
        K.box(m, cf * CFrame.new(at.X, merlon * 0.3, at.Z) * K.yaw(yaw) * CFrame.new((s[1] + s[2]) / 2, 0, 0),
          Vector3.new(L, merlon * 0.6, 2.4), mat, col, { name = "Parapet" })
      end
    end
    for i = 0, math.floor(len / step) do
      local x = -len / 2 + i * step
      if not (gap and math.abs(x - gap.at) < gap.w / 2 + step * 0.3) then
        K.box(m, cf * CFrame.new(at.X, merlon * 0.5, at.Z) * K.yaw(yaw) * CFrame.new(x, 0, 0),
          Vector3.new(step * 0.55, merlon, 2.4), mat, col, { name = "Merlon", cancollide = false })
      end
    end
  end
  local W, D = w + over * 2, d + over * 2
  -- opts.gaps names the sides a stair arrives at, so the parapet does not fence off its own head
  local gaps = opts.gaps or {}
  run(W, Vector3.new(0, 0, -D / 2 + 1.2), 0, gaps.front)
  run(W, Vector3.new(0, 0, D / 2 - 1.2), 0, gaps.back)
  run(D, Vector3.new(-W / 2 + 1.2, 0, 0), math.pi / 2, gaps.left)
  run(D, Vector3.new(W / 2 - 1.2, 0, 0), math.pi / 2, gaps.right)
  return m
end

-- machicolations: the boxed-out top of a wall with drop holes, carried on corbels
function K.machicolation(parent, cf, len, opts)
  opts = opts or {}
  local m = K.model(parent, "Machicolation")
  local mat = opts.mat or K.MAT.Sandstone
  local col = opts.color or K.C.stone
  local proj = opts.projection or 3.5
  local h = opts.height or 5
  K.box(m, cf * CFrame.new(0, h / 2, -proj / 2), Vector3.new(len, h, proj), mat, col, { name = "Box" })
  local n = math.max(2, math.floor(len / 5))
  for i = 0, n do
    local x = -len / 2 + len * i / n
    K.wedge(m, cf * CFrame.new(x, -1.6, -proj + 0.6) * K.yaw(math.pi), Vector3.new(2.2, 3.2, proj), mat, col:Lerp(K.C.white, 0.1))
  end
  for i = 0, n - 1 do                             -- the drop holes between corbels
    local x = -len / 2 + len * (i + 0.5) / n
    K.box(m, cf * CFrame.new(x, 0.2, -proj + 1), Vector3.new(2.4, 1, 2), K.MAT.SmoothPlastic, K.C.black, { name = "Hole", cancollide = false })
  end
  return m
end

-- an arrow slit cut into a wall face: the outer slot, the splayed inner embrasure
function K.arrowSlit(parent, cf, opts)
  opts = opts or {}
  local m = K.model(parent, "ArrowSlit")
  local col = opts.color or K.C.black
  local h = opts.height or 6
  K.box(m, cf, Vector3.new(0.9, h, 1.2), K.MAT.SmoothPlastic, col, { name = "Slot", cancollide = false })
  K.box(m, cf * CFrame.new(0, -h / 2 + 1, 0), Vector3.new(3, 1.4, 1.2), K.MAT.SmoothPlastic, col, { name = "Foot", cancollide = false })
  if opts.frame ~= false then
    for _, s in ipairs({ -1, 1 }) do
      K.box(m, cf * CFrame.new(s * 1.6, 0, 0.4), Vector3.new(1.4, h + 2, 1.6), opts.mat or K.MAT.Sandstone,
        (opts.stone or K.C.stone):Lerp(K.C.white, 0.12), { name = "Jamb", cancollide = false })
    end
  end
  return m
end

-- a pointed arch opening: two leaning slabs plus a keystone, for gates and arcades
function K.archOpening(parent, cf, w, h, thick, mat, color)
  local m = K.model(parent, "Arch")
  local rise = w * 0.55
  local n = 7
  for i = 0, n - 1 do
    local t0, t1 = i / n, (i + 1) / n
    for _, s in ipairs({ -1, 1 }) do
      local x0 = s * (w / 2) * math.cos(t0 * math.pi / 2)
      local y0 = h + rise * math.sin(t0 * math.pi / 2)
      local x1 = s * (w / 2) * math.cos(t1 * math.pi / 2)
      local y1 = h + rise * math.sin(t1 * math.pi / 2)
      K.rod(m, (cf * CFrame.new(x0, y0, 0)).Position, (cf * CFrame.new(x1, y1, 0)).Position,
        thick / 2, mat, color, { name = "Voussoir", cancollide = false })
    end
  end
  K.box(m, cf * CFrame.new(0, h + rise, 0), Vector3.new(thick * 1.2, thick * 1.4, thick), mat, color:Lerp(K.C.white, 0.12), { name = "Keystone", cancollide = false })
  return m
end
