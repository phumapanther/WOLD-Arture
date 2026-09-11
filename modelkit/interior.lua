-- interior — extends K with the pieces a building needs to be lived in rather than looked at:
-- walls that have real holes in them, floors with joists, stairs, railings, and furniture.
-- loaded straight after kit.lua in the same chunk, so it just adds to K.

-- a wall run along the frame's local X, base at the frame's origin, thickness along local Z.
-- openings = { { x = 0, w = 5, h = 8, sill = 0 }, ... } — the wall is split into piers, aprons
-- and lintels around them, so doors and windows are holes you can walk and see through.
function K.wallRun(parent, cf, w, h, d, mat, color, openings, opts)
  local m = K.model(parent, (opts and opts.name) or "Wall")
  local list = {}
  for _, o in ipairs(openings or {}) do
    list[#list + 1] = { x = o.x, w = o.w, h = o.h, sill = o.sill or 0 }
  end
  table.sort(list, function(a, b) return a.x < b.x end)
  local cursor = -w / 2
  local function pier(x0, x1)
    local seg = x1 - x0
    if seg > 0.02 then K.box(m, cf * CFrame.new(x0 + seg / 2, h / 2, 0), Vector3.new(seg, h, d), mat, color, { name = "Pier" }) end
  end
  for _, o in ipairs(list) do
    pier(cursor, o.x - o.w / 2)
    if o.sill > 0.02 then
      K.box(m, cf * CFrame.new(o.x, o.sill / 2, 0), Vector3.new(o.w, o.sill, d), mat, color, { name = "Apron" })
    end
    local top = o.sill + o.h
    if h - top > 0.02 then
      K.box(m, cf * CFrame.new(o.x, (top + h) / 2, 0), Vector3.new(o.w, h - top, d), mat, color, { name = "Lintel" })
    end
    cursor = o.x + o.w / 2
  end
  pier(cursor, w / 2)
  return m
end

-- floor deck with joists under it, so an upper storey reads as built rather than floating
function K.floorSlab(parent, cf, w, d, mat, color, opts)
  opts = opts or {}
  local m = K.model(parent, opts.name or "Floor")
  K.box(m, cf * CFrame.new(0, -0.35, 0), Vector3.new(w, 0.7, d), mat or K.MAT.WoodPlanks, color or K.C.plank, { name = "Deck" })
  local n = math.max(2, math.floor(d / 5))
  for i = 0, n do
    K.box(m, cf * CFrame.new(0, -1.05, -d / 2 + d * i / n), Vector3.new(w, 0.7, 0.7), K.MAT.Wood,
      (color or K.C.plank):Lerp(K.C.black, 0.35), { name = "Joist", cancollide = false })
  end
  return m
end

-- straight flight climbing along the frame's local +Z; each step is one solid block
function K.stairsRun(parent, cf, width, rise, run, steps, mat, color)
  local m = K.model(parent, "Stairs")
  for i = 1, steps do
    local y = rise * i / steps
    K.box(m, cf * CFrame.new(0, y / 2, run * (i - 0.5) / steps), Vector3.new(width, y, run / steps * 1.02),
      mat or K.MAT.WoodPlanks, color or K.C.plankDark, { name = "Step" })
  end
  return m
end

function K.railing(parent, cf, len, h, color, mat)
  local m = K.model(parent, "Railing")
  local col = color or K.C.wood
  local n = math.max(2, math.floor(len / 2.4))
  for i = 0, n do
    K.box(m, cf * CFrame.new(-len / 2 + len * i / n, h / 2, 0), Vector3.new(0.3, h, 0.3), mat or K.MAT.Wood, col, { name = "Baluster", cancollide = false })
  end
  K.box(m, cf * CFrame.new(0, h, 0), Vector3.new(len, 0.38, 0.5), mat or K.MAT.Wood, col, { name = "Rail" })
  K.box(m, cf * CFrame.new(0, h * 0.45, 0), Vector3.new(len, 0.22, 0.34), mat or K.MAT.Wood, col, { name = "MidRail", cancollide = false })
  return m
end

-- dormer poking out of a roof slope, facing local -Z
function K.dormer(parent, cf, w, h, d, wallMat, wallCol, roofMat, roofCol)
  local m = K.model(parent, "Dormer")
  K.box(m, cf * CFrame.new(0, h / 2, 0), Vector3.new(w, h, d), wallMat or K.MAT.Plaster, wallCol or K.C.plaster, { name = "Cheeks" })
  K.window(m, cf * CFrame.new(0, h * 0.55, -d / 2 - 0.1), w * 0.5, h * 0.45, K.C.wood, true)
  K.roofGable(m, cf * CFrame.new(0, h, 0), w + 1, d + 1, w * 0.5, roofMat or K.MAT.RoofShingles, roofCol or K.C.slateRoof, 0.4)
  return m
end

-- ---------- furniture ----------
function K.table(parent, cf, w, d, h, color, mat)
  local m = K.model(parent, "Table")
  local col = color or K.C.plank
  K.box(m, cf * CFrame.new(0, h, 0), Vector3.new(w, 0.45, d), mat or K.MAT.WoodPlanks, col, { name = "Top" })
  for _, sx in ipairs({ -1, 1 }) do
    for _, sz in ipairs({ -1, 1 }) do
      K.box(m, cf * CFrame.new(sx * (w / 2 - 0.6), h / 2, sz * (d / 2 - 0.6)), Vector3.new(0.5, h, 0.5), K.MAT.Wood, col:Lerp(K.C.black, 0.3), { name = "Leg" })
    end
  end
  K.box(m, cf * CFrame.new(0, h * 0.45, 0), Vector3.new(w - 1.2, 0.3, 0.4), K.MAT.Wood, col:Lerp(K.C.black, 0.3), { name = "Stretcher", cancollide = false })
  return m
end

function K.chair(parent, cf, color, mat)
  local m = K.model(parent, "Chair")
  local col = color or K.C.plankDark
  K.box(m, cf * CFrame.new(0, 1.7, 0), Vector3.new(2.2, 0.35, 2.2), mat or K.MAT.WoodPlanks, col, { name = "Seat" })
  K.box(m, cf * CFrame.new(0, 3, 1), Vector3.new(2.2, 2.6, 0.3), mat or K.MAT.WoodPlanks, col, { name = "Back" })
  for _, sx in ipairs({ -1, 1 }) do
    for _, sz in ipairs({ -1, 1 }) do
      K.box(m, cf * CFrame.new(sx * 0.85, 0.85, sz * 0.85), Vector3.new(0.3, 1.7, 0.3), K.MAT.Wood, col:Lerp(K.C.black, 0.3), { name = "Leg" })
    end
  end
  return m
end

function K.bed(parent, cf, w, len, color, cloth)
  local m = K.model(parent, "Bed")
  local col = color or K.C.wood
  K.box(m, cf * CFrame.new(0, 1.4, 0), Vector3.new(w, 0.5, len), K.MAT.WoodPlanks, col, { name = "Base" })
  K.box(m, cf * CFrame.new(0, 2, 0.6), Vector3.new(w - 0.5, 0.8, len - 2.4), K.MAT.Fabric, cloth or K.C.canvas, { name = "Mattress" })
  K.box(m, cf * CFrame.new(0, 2.3, 1.4), Vector3.new(w - 0.4, 0.5, len * 0.5), K.MAT.Fabric, (cloth or K.C.canvas):Lerp(K.C.paintRed, 0.5), { name = "Blanket", cancollide = false })
  K.box(m, cf * CFrame.new(0, 2.5, -len / 2 + 1.4), Vector3.new(w - 1.4, 0.6, 1.8), K.MAT.Fabric, K.C.white, { name = "Pillow", cancollide = false })
  K.box(m, cf * CFrame.new(0, 2.4, -len / 2 - 0.15), Vector3.new(w, 2.6, 0.4), K.MAT.Wood, col:Lerp(K.C.black, 0.25), { name = "Headboard" })
  K.box(m, cf * CFrame.new(0, 1.8, len / 2 + 0.15), Vector3.new(w, 1.4, 0.4), K.MAT.Wood, col:Lerp(K.C.black, 0.25), { name = "Footboard" })
  for _, sx in ipairs({ -1, 1 }) do
    for _, sz in ipairs({ -1, 1 }) do
      K.box(m, cf * CFrame.new(sx * (w / 2 - 0.4), 0.6, sz * (len / 2 - 0.4)), Vector3.new(0.6, 1.2, 0.6), K.MAT.Wood, col:Lerp(K.C.black, 0.3), { name = "Post" })
    end
  end
  return m
end

function K.shelf(parent, cf, w, h, d, color, levels, fill)
  local m = K.model(parent, "Shelf")
  local col = color or K.C.plankDark
  local n = levels or 4
  for _, sx in ipairs({ -1, 1 }) do
    K.box(m, cf * CFrame.new(sx * (w / 2 - 0.2), h / 2, 0), Vector3.new(0.4, h, d), K.MAT.Wood, col, { name = "Upright" })
  end
  K.box(m, cf * CFrame.new(0, h / 2, d / 2 - 0.15), Vector3.new(w, h, 0.3), K.MAT.WoodPlanks, col:Lerp(K.C.black, 0.2), { name = "Back", cancollide = false })
  local rng = Random.new(math.floor(math.abs(cf.X) * 13 + math.abs(cf.Z) * 7 + h))
  for i = 1, n do
    local y = h * i / (n + 1)
    K.box(m, cf * CFrame.new(0, y, 0), Vector3.new(w - 0.6, 0.3, d), K.MAT.WoodPlanks, col, { name = "Board" })
    if fill ~= false then
      local slots = math.max(2, math.floor(w / 1.8))
      for j = 0, slots - 1 do
        if rng:NextNumber() > 0.28 then
          local x = -w / 2 + 0.9 + j * (w - 1.8) / math.max(1, slots - 1)
          local kind = rng:NextInteger(1, 3)
          if kind == 1 then
            K.box(m, cf * CFrame.new(x, y + 0.9, rng:NextNumber() * 0.5 - 0.25) * K.yaw(rng:NextNumber()),
              Vector3.new(0.5, 1.4, 0.9), K.MAT.Wood, K.C.oak:Lerp(K.C.black, rng:NextNumber() * 0.4), { name = "Book", cancollide = false })
          elseif kind == 2 then
            K.cyl(m, cf * CFrame.new(x, y + 0.15, 0), 0.45, 1.2, K.MAT.Glass, K.C.glass, { name = "Jar", transparency = 0.35, cancollide = false })
          else
            K.box(m, cf * CFrame.new(x, y + 0.6, 0) * K.yaw(rng:NextNumber() * 0.6), Vector3.new(1.1, 0.9, 1.1), K.MAT.WoodPlanks, K.C.oak, { name = "Box", cancollide = false })
          end
        end
      end
    end
  end
  return m
end

function K.chest(parent, cf, s, color)
  local m = K.model(parent, "Chest")
  local col = color or K.C.oak
  K.box(m, cf * CFrame.new(0, s * 0.3, 0), Vector3.new(s * 1.6, s * 0.6, s), K.MAT.WoodPlanks, col, { name = "Body" })
  K.box(m, cf * CFrame.new(0, s * 0.68, 0), Vector3.new(s * 1.64, s * 0.2, s * 1.04), K.MAT.WoodPlanks, col:Lerp(K.C.black, 0.2), { name = "Lid" })
  for _, sx in ipairs({ -0.55, 0.55 }) do
    K.box(m, cf * CFrame.new(s * 1.6 * sx, s * 0.4, 0), Vector3.new(0.2, s * 0.9, s * 1.04), K.MAT.Metal, K.C.iron, { name = "Band", cancollide = false })
  end
  K.box(m, cf * CFrame.new(0, s * 0.42, -s / 2 - 0.1), Vector3.new(s * 0.3, s * 0.3, 0.2), K.MAT.Metal, K.C.brass, { name = "Lock", cancollide = false })
  return m
end

function K.counter(parent, cf, w, d, h, color, mat)
  local m = K.model(parent, "Counter")
  local col = color or K.C.plankDark
  K.box(m, cf * CFrame.new(0, h - 0.25, 0), Vector3.new(w, 0.5, d + 0.6), mat or K.MAT.WoodPlanks, col:Lerp(K.C.plank, 0.4), { name = "Top" })
  K.box(m, cf * CFrame.new(0, (h - 0.5) / 2, 0), Vector3.new(w - 0.4, h - 0.5, d), mat or K.MAT.WoodPlanks, col, { name = "Front" })
  for i = 0, math.floor(w / 3) do
    K.box(m, cf * CFrame.new(-w / 2 + 0.6 + i * 3, (h - 0.5) / 2, -d / 2 - 0.12), Vector3.new(0.35, h - 0.7, 0.25), K.MAT.Wood, col:Lerp(K.C.black, 0.35), { name = "Rib", cancollide = false })
  end
  return m
end

function K.fireplace(parent, cf, w, h, color, lit)
  local m = K.model(parent, "Fireplace")
  local col = color or K.C.darkStone
  K.box(m, cf * CFrame.new(0, h / 2, 0.6), Vector3.new(w, h, 2), K.MAT.Cobblestone, col, { name = "Back" })
  for _, sx in ipairs({ -1, 1 }) do
    K.box(m, cf * CFrame.new(sx * (w / 2 - 1), h * 0.4, -0.5), Vector3.new(2, h * 0.8, 2.4), K.MAT.Cobblestone, col, { name = "Jamb" })
  end
  K.box(m, cf * CFrame.new(0, h * 0.8, -0.5), Vector3.new(w, h * 0.2, 2.4), K.MAT.Cobblestone, col:Lerp(K.C.black, 0.2), { name = "Hood" })
  K.box(m, cf * CFrame.new(0, h * 0.92, -0.9), Vector3.new(w + 1.2, 0.6, 3.2), K.MAT.Wood, K.C.wood, { name = "Mantel" })
  if lit ~= false then
    local fire = K.box(m, cf * CFrame.new(0, 0.7, -0.2), Vector3.new(math.max(1.5, w - 4), 1.2, 1.8), K.MAT.Neon, K.C.ember, { name = "Fire", cancollide = false })
    local l = Instance.new("PointLight"); l.Color = K.C.ember; l.Range = 26; l.Brightness = 0.96; l.Parent = fire
    for i = 0, 3 do
      K.rod(m, (cf * CFrame.new(-1.4 + i * 0.9, 0.3, -0.9)).Position, (cf * CFrame.new(-0.6 + i * 0.6, 1.5, 0.2)).Position, 0.22, K.MAT.Wood, K.C.wood, { name = "Log", cancollide = false })
    end
  end
  return m
end

function K.rug(parent, cf, w, d, color)
  local m = K.model(parent, "Rug")
  K.box(m, cf, Vector3.new(w, 0.14, d), K.MAT.Carpet, color or K.C.paintRed, { name = "Field", cancollide = false })
  K.box(m, cf * CFrame.new(0, 0.02, 0), Vector3.new(w - 1.6, 0.16, d - 1.6), K.MAT.Carpet, (color or K.C.paintRed):Lerp(K.C.canvas, 0.45), { name = "Inner", cancollide = false })
  return m
end
