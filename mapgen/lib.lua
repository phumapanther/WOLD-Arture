-- mapgen/lib.lua — shared library. Prepended by tools/run-luau.js after `local SCALE` and `local LAYOUT_JSON`.
-- Everything lives on table L to stay under Luau's 200-locals-per-function limit.
local HttpService = game:GetService("HttpService")
local Terrain = workspace.Terrain
local MAT = Enum.Material
local L = {}
L.SCALE = SCALE or 1
L.VS = math.sqrt(L.SCALE)                       -- vertical scale for miniature tests (1 at full scale)
L.LAYOUT = HttpService:JSONDecode(LAYOUT_JSON)
local Y = L.LAYOUT
L.HALF = Y.half_size_studs * L.SCALE
L.MAT = MAT

-- ---------- coordinates ----------
function L.toWorld(p) return p[1] * L.HALF, p[2] * L.HALF end
function L.toNorm(x, z) return x / L.HALF, z / L.HALF end
function L.pt(e) if type(e) == "table" then return e end; return Y.places[e].pos end
function L.placePos(name) return L.toWorld(Y.places[name].pos) end

-- ---------- math ----------
local function clamp01(t) return math.clamp(t, 0, 1) end
function L.sig(a) return 1 / (1 + math.exp(-math.clamp(a, -30, 30))) end
function L.gauss(u, v, c, s) local dx, dz = u - c[1], v - c[2]; return math.exp(-(dx * dx + dz * dz) / (2 * s * s)) end
function L.smooth(t) t = clamp01(t); return t * t * (3 - 2 * t) end
function L.fbm(u, v, seed)                       -- 4 octaves, ~[0,1], deterministic
  local s, a, f = 0, 0.5, 2
  for _ = 1, 4 do s += a * (math.noise(u * f + seed, v * f - seed * 1.7, seed * 0.37) + 0.5); a *= 0.5; f *= 2 end
  return clamp01(s / 0.9375)
end
function L.polyLen(pts) local s = 0; for i = 1, #pts - 1 do s += math.sqrt((pts[i + 1][1] - pts[i][1]) ^ 2 + (pts[i + 1][2] - pts[i][2]) ^ 2) end; return s end
function L.polyDist(pts, total, u, v)            -- nearest distance to polyline + fraction 0..1 along it
  local best, bestT, acc = math.huge, 0, 0
  for i = 1, #pts - 1 do
    local a, b = pts[i], pts[i + 1]
    local abx, abz = b[1] - a[1], b[2] - a[2]
    local len2 = abx * abx + abz * abz
    local t = len2 > 0 and math.clamp(((u - a[1]) * abx + (v - a[2]) * abz) / len2, 0, 1) or 0
    local d = math.sqrt((u - a[1] - abx * t) ^ 2 + (v - a[2] - abz * t) ^ 2)
    local segLen = math.sqrt(len2)
    if d < best then best = d; bestT = (acc + segLen * t) / total end
    acc += segLen
  end
  return best, bestT
end

-- ---------- isles + decorative rocks ----------
L.isles = {}
for name, isl in pairs(Y.isles) do L.isles[#L.isles + 1] = { name = name, pos = isl.pos, r = isl.r, top = 15, bump = 90 } end
do
  local rng = Random.new(Y.rocks.seed)
  local made = 0
  while made < Y.rocks.count do
    local a = rng:NextNumber(0, 2 * math.pi); local r = rng:NextNumber(Y.rocks.r_min, Y.rocks.r_max)
    local p = { math.cos(a) * r, math.sin(a) * r }
    local ok = true
    for _, isl in ipairs(L.isles) do if math.sqrt((p[1] - isl.pos[1]) ^ 2 + (p[2] - isl.pos[2]) ^ 2) < isl.r + 0.15 then ok = false end end
    if ok then made += 1; L.isles[#L.isles + 1] = { name = "Rock" .. made, pos = p, r = rng:NextNumber(0.012, 0.02), top = 8, bump = 15, rock = true } end
  end
end

-- ---------- base terrain height (studs) — same formula as render-map.py ----------
local bay, cl, fz, PH = Y.bay, Y.cliffs, Y.forest, Y.peak_height_studs
L.guards = {}                                     -- normalized positions that must be land (all places)
for _, p in pairs(Y.places) do L.guards[#L.guards + 1] = p.pos end
function L.base(u, v)
  local VS = L.VS
  local r = math.sqrt(u * u + v * v)
  local ang = math.deg(math.atan2(v, u))
  local n1, n2, n3 = L.fbm(u, v, 11), L.fbm(u, v, 23), L.fbm(u, v, 37)
  local rc = Y.coast_radius + Y.coast_noise * (2 * n1 - 1) - bay.depth * math.exp(-(ang - bay.angle_deg) ^ 2 / (2 * bay.sigma_deg ^ 2))
  local land = clamp01((rc - r) / 0.05)
  for _, g in ipairs(L.guards) do                 -- every settlement sits on land no matter what the coast noise does
    local dx, dz = u - g[1], v - g[2]; local d = math.sqrt(dx * dx + dz * dz)
    if d < 0.09 then land = math.max(land, clamp01((0.09 - d) / 0.03)) end
  end
  local plains = 20 + 40 * n2
  local fm = L.sig((fz.x_max - u) / 0.08) * L.sig((fz.z_abs_max - math.abs(v)) / 0.08) * (0.55 + 0.45 * n3)
  local mb = L.sig((Y.mountain_band_z - v) / 0.06)
  local ridge = math.exp(-(v + 0.60) ^ 2 / (2 * 0.07 ^ 2)) * L.sig((0.45 - math.abs(u)) / 0.05)
  local cliff = L.sig((r - cl.r_min) / 0.05) * math.exp(-(math.abs(ang) - cl.center_deg) ^ 2 / (2 * cl.sigma_deg ^ 2)) * 110
  local hl = plains + fm * 30 + mb * (250 + 330 * n3)
    + L.gauss(u, v, Y.peaks.main_NE, 0.10) * (PH.main_NE - 450) + L.gauss(u, v, Y.peaks.second_NW, 0.10) * (PH.second_NW - 450)
    + ridge * 380 + L.gauss(u, v, Y.crown_hill, 0.07) * Y.crown_hill_height_studs + cliff
  local h = land * hl + (1 - land) * Y.sea.seabed_y
  for _, isl in ipairs(L.isles) do
    local dx, dz = u - isl.pos[1], v - isl.pos[2]; local d = math.sqrt(dx * dx + dz * dz)
    if d < isl.r * 1.4 then
      local m = clamp01((isl.r * (0.85 + 0.3 * n1) - d) / 0.015)
      h = m * (isl.top + isl.bump * math.exp(-d * d / (2 * (isl.r * 0.5) ^ 2))) + (1 - m) * h
    end
  end
  return h * VS, fm, cliff * VS, land
end

-- ---------- rivers: surface height monotone downstream, valley carved into height ----------
local function buildRiver(pts, widths, mouthY)
  local R = { pts = pts, total = L.polyLen(pts), w0 = widths[1], w1 = widths[2], h = {}, cum = { 0 } }
  local prev = math.huge
  for i, p in ipairs(pts) do local hb = L.base(p[1], p[2]); R.h[i] = math.min(hb - 6 * L.VS, prev); prev = R.h[i] end
  R.h[#pts] = mouthY
  for i = #pts - 1, 1, -1 do if R.h[i] < R.h[i + 1] then R.h[i] = R.h[i + 1] end end
  for i = 2, #pts do R.cum[i] = R.cum[i - 1] + math.sqrt((pts[i][1] - pts[i - 1][1]) ^ 2 + (pts[i][2] - pts[i - 1][2]) ^ 2) end
  return R
end
local function riverSample(R, t)
  local s = t * R.total
  local i = 1; while i < #R.cum - 1 and R.cum[i + 1] < s do i += 1 end
  local f = (s - R.cum[i]) / math.max(R.cum[i + 1] - R.cum[i], 1e-9)
  return R.h[i] + (R.h[i + 1] - R.h[i]) * f, (R.w0 + (R.w1 - R.w0) * t) * L.VS
end
L.rivers = { buildRiver(Y.river_main, Y.river_width_studs.main, 0) }
do -- tributary ends where it meets the main river: inherit that surface height
  local last = Y.river_tributary[#Y.river_tributary]
  local _, t = L.polyDist(Y.river_main, L.rivers[1].total, last[1], last[2])
  local hs = riverSample(L.rivers[1], t)
  L.rivers[2] = buildRiver(Y.river_tributary, Y.river_width_studs.tributary, hs)
end
function L.river(u, v)                            -- -> dist(studs), surfaceY, width(studs)
  local best, hs, w
  for _, R in ipairs(L.rivers) do
    local d, t = L.polyDist(R.pts, R.total, u, v)
    if not best or d < best then best = d; hs, w = riverSample(R, t) end
  end
  return best * L.HALF, hs, w
end
L.VALLEY = 0.03                                   -- valley half-width, normalized (240 studs at full scale)
function L.sample(u, v)
  local h, fm, cliff, land = L.base(u, v)
  local d, hs, w = L.river(u, v)
  local valley = L.VALLEY * L.HALF
  if land > 0.5 and d < valley then
    local bank = hs + 1 * L.VS                    -- ground right at the water's edge, just above the surface
    if d <= w / 2 then                            -- parabolic bed: 10 deep in the middle, shallow at the edges
      local t = (2 * d / w) ^ 2; h = (hs - 10 * L.VS) + (bank - (hs - 10 * L.VS)) * t
    else h = bank + (math.max(h, hs + 3 * L.VS) - bank) * L.smooth((d - w / 2) / (valley - w / 2)) end
  end
  return h, fm, cliff, land, d, hs, w
end
function L.heightAt(x, z) return (L.sample(x / L.HALF, z / L.HALF)) end
function L.isLand(x, z) local _, _, _, land = L.base(x / L.HALF, z / L.HALF); return land > 0.5 end
function L.riverAt(x, z) local _, _, _, _, d, hs, w = L.sample(x / L.HALF, z / L.HALF); return d, hs, w end

-- ---------- terrain chunk writer ----------
function L.materialFor(h, yc, fm, cliff, slope, SNOW, MTN)
  if yc < h - 12 * L.VS then return MAT.Rock end
  if h < 4 * L.VS then return MAT.Sand end
  if h >= SNOW then return MAT.Snow end
  if cliff > 60 * L.VS then return MAT.Basalt end
  if h >= MTN or slope > 1.2 then return MAT.Rock end
  if fm > 0.5 then return MAT.LeafyGrass end
  return MAT.Grass
end
function L.writeChunk(x0, z0, n, waterCut)         -- x0,z0 multiples of 4; n columns (n*4 studs square); waterCut(x,z) -> true suppresses river water
  local HALF, VS = L.HALF, L.VS
  local H, FM, CL, RD, RH, RW = {}, {}, {}, {}, {}, {}
  local minH, maxH = math.huge, -math.huge
  for i = 1, n + 1 do
    H[i], FM[i], CL[i], RD[i], RH[i], RW[i] = {}, {}, {}, {}, {}, {}
    for k = 1, n + 1 do
      local h, fm, c, _, d, hs, w = L.sample((x0 + (i - 1) * 4) / HALF, (z0 + (k - 1) * 4) / HALF)   -- 7 returns: h, forest, cliff, land, riverDist, riverSurface, riverWidth
      H[i][k], FM[i][k], CL[i][k], RD[i][k], RH[i][k], RW[i][k] = h, fm, c, d, hs, w
      if h < minH then minH = h end; if h > maxH then maxH = h end
      if d <= w / 2 and hs > maxH then maxH = hs end
    end
  end
  local seabed = Y.sea.seabed_y * VS
  local y0 = math.floor(math.min(minH, seabed) / 4) * 4 - 4
  local y1 = math.ceil(math.max(maxH, 0) / 4) * 4 + 4
  local ny = (y1 - y0) / 4
  if ny * n * n > 1.5e6 and n > 16 then           -- tall mountain chunk: split into 4 to bound table size
    local half = n / 2
    for _, o in ipairs({ { 0, 0 }, { half, 0 }, { 0, half }, { half, half } }) do L.writeChunk(x0 + o[1] * 4, z0 + o[2] * 4, half, waterCut) end
    return
  end
  local SNOW, MTN = Y.snow_line_studs * VS, 250 * VS
  local mats, occ = table.create(n), table.create(n)
  for i = 1, n do
    mats[i], occ[i] = table.create(ny), table.create(ny)
    for j = 1, ny do mats[i][j], occ[i][j] = table.create(n), table.create(n) end
  end
  for i = 1, n do
    for k = 1, n do
      local h, fm, c = H[i][k], FM[i][k], CL[i][k]
      local slope = math.max(math.abs(H[i + 1][k] - h), math.abs(H[i][k + 1] - h)) / 4
      local d, hs, w = RD[i][k], RH[i][k], RW[i][k]
      local riverHere = d <= w / 2 and not (waterCut and waterCut(x0 + (i - 1) * 4, z0 + (k - 1) * 4))
      local waterTop = (h < 0) and 0 or (riverHere and hs or nil)
      for j = 1, ny do
        local ybot = y0 + (j - 1) * 4; local ytop = ybot + 4; local yc = ybot + 2
        local m, o
        if ytop <= h then m, o = L.materialFor(h, yc, fm, c, slope, SNOW, MTN), 1
        elseif ybot < h then m, o = L.materialFor(h, yc, fm, c, slope, SNOW, MTN), (h - ybot) / 4
        elseif waterTop and ybot < waterTop then m, o = MAT.Water, math.min((waterTop - ybot) / 4, 1)
        else m, o = MAT.Air, 0 end
        mats[i][j][k], occ[i][j][k] = m, o
      end
    end
  end
  Terrain:WriteVoxels(Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + n * 4, y1, z0 + n * 4)), 4, mats, occ)
end
function L.writeArea(cx, cz, rad, onProgress, waterMargin)   -- write all chunks near (cx,cz); river water suppressed within waterMargin of the edge
  local CH = Y.generator.terrain_chunk_studs; local n = CH / 4
  local waterCut = waterMargin and function(x, z) return math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2) > rad - waterMargin end or nil
  local jobs = {}
  for x = math.floor((cx - rad) / CH) * CH, math.ceil((cx + rad) / CH) * CH - CH, CH do
    for z = math.floor((cz - rad) / CH) * CH, math.ceil((cz + rad) / CH) * CH - CH, CH do
      local near = false
      for _, c in ipairs({ { x, z }, { x + CH, z }, { x, z + CH }, { x + CH, z + CH }, { x + CH / 2, z + CH / 2 } }) do
        if math.sqrt((c[1] - cx) ^ 2 + (c[2] - cz) ^ 2) < rad then near = true end
      end
      if near then jobs[#jobs + 1] = { x, z } end
    end
  end
  for i, j in ipairs(jobs) do
    L.writeChunk(j[1], j[2], n, waterCut)
    if i % 4 == 0 then if onProgress then onProgress(i, #jobs) end; task.wait() end
  end
  return #jobs
end
function L.seaSlab(x0, z0, x1, z1)                 -- seabed + water box with a thin sand rim so water never touches unwritten space (avoids water render spikes)
  local sb, deep = Y.sea.seabed_y * L.VS, Y.sea.deep_seabed_y * L.VS
  local cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
  Terrain:FillBlock(CFrame.new(cx, (sb + deep) / 2, cz), Vector3.new(w, sb - deep, d), MAT.Sand)
  Terrain:FillBlock(CFrame.new(cx, sb / 2, cz), Vector3.new(w, -sb, d), MAT.Water)
  for _, r in ipairs({ { x0 + 4, cz, 8, d }, { x1 - 4, cz, 8, d }, { cx, z0 + 4, w, 8 }, { cx, z1 - 4, w, 8 } }) do
    Terrain:FillBlock(CFrame.new(r[1], sb / 2 + 2, r[2]), Vector3.new(r[3], -sb + 4, r[4]), MAT.Sand)
  end
end

-- ---------- phase runner / progress / checks ----------
function L.root()
  local r = workspace:FindFirstChild(Y.generator.workspace_root)
  if not r then r = Instance.new("Folder"); r.Name = Y.generator.workspace_root; r.Parent = workspace end
  return r
end
function L.progress(msg) L.root():SetAttribute("Progress", msg); print("[WOLD] " .. msg) end
function L.runPhase(name, fn)
  local root = L.root()
  local old = root:FindFirstChild(name); if old then old:Destroy() end
  local folder = Instance.new("Folder"); folder.Name = name; folder.Parent = root
  root:SetAttribute("Status", "running"); root:SetAttribute("Phase", name); L.progress(name .. " start")
  task.spawn(function()
    local t0 = os.clock()
    local ok, err = pcall(fn, folder)
    if ok then root:SetAttribute("Status", "done"); L.progress(("%s done in %.0fs"):format(name, os.clock() - t0))
    else root:SetAttribute("Status", "error: " .. tostring(err)); warn("[WOLD] " .. name .. " ERROR " .. tostring(err)) end
  end)
  return "started " .. name
end
function L.check(list, cond, msg) if not cond then list[#list + 1] = msg end; return cond end
function L.materialAtPoint(x, y, z)
  local reg = Region3.new(Vector3.new(x - 2, y - 2, z - 2), Vector3.new(x + 2, y + 2, z + 2)):ExpandToGrid(4)
  return Terrain:ReadVoxels(reg, 4)[1][1][1]
end
function L.countParts(inst) local c = 0; for _, d in ipairs(inst:GetDescendants()) do if d:IsA("BasePart") then c += 1 end end; return c end
function L.requireFullScale() assert(L.SCALE == 1, "this phase must run at SCALE=1 (structures are not scaled)") end

-- ---------- palette + visual style ----------
local rgb = Color3.fromRGB
L.C = { stone = rgb(163, 162, 165), darkStone = rgb(99, 95, 98), brick = rgb(136, 72, 58), wood = rgb(86, 66, 54), plank = rgb(159, 124, 90),
  roofRed = rgb(160, 60, 50), roofBlue = rgb(70, 90, 140), roofGreen = rgb(80, 110, 80), plaster = rgb(222, 208, 190), brass = rgb(196, 150, 60),
  copper = rgb(150, 90, 60), iron = rgb(60, 60, 65), rust = rgb(120, 70, 40), crystal = rgb(120, 220, 255), leafDark = rgb(40, 90, 45),
  leafLight = rgb(70, 130, 60), trunk = rgb(80, 55, 35), sail = rgb(235, 230, 210), glass = rgb(150, 200, 220), sea = rgb(28, 70, 120) }
local function c3(t) return Color3.fromRGB(t[1], t[2], t[3]) end
function L.applyStyle()                           -- terrain material colors, water, lighting, atmosphere, clouds from layout.style
  local S = Y.style; if not S then return end
  for matName, c in pairs(S.terrain_colors or {}) do pcall(function() Terrain:SetMaterialColor(MAT[matName], c3(c)) end) end
  if S.water then
    Terrain.WaterColor = c3(S.water.color); Terrain.WaterTransparency = S.water.transparency
    Terrain.WaterWaveSize = S.water.wave_size; Terrain.WaterWaveSpeed = S.water.wave_speed; Terrain.WaterReflectance = S.water.reflectance
  end
  local Lighting = game:GetService("Lighting")
  if S.lighting then
    Lighting.ClockTime = S.lighting.clock_time; Lighting.Brightness = S.lighting.brightness; Lighting.ExposureCompensation = S.lighting.exposure
    Lighting.Ambient = c3(S.lighting.ambient); Lighting.OutdoorAmbient = c3(S.lighting.outdoor_ambient); Lighting.ShadowSoftness = S.lighting.shadow_softness
    Lighting.GlobalShadows = true
  end
  if S.atmosphere then
    local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
    atm.Density = S.atmosphere.density; atm.Offset = S.atmosphere.offset; atm.Color = c3(S.atmosphere.color); atm.Decay = c3(S.atmosphere.decay)
    atm.Glare = S.atmosphere.glare; atm.Haze = S.atmosphere.haze
  end
  if S.clouds then
    local cl = Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds", Terrain)
    cl.Enabled = S.clouds.enabled; cl.Cover = S.clouds.cover; cl.Density = S.clouds.density; cl.Color = c3(S.clouds.color)
  end
  if not Lighting:FindFirstChildOfClass("Sky") then Instance.new("Sky", Lighting) end
  Lighting.FogEnd = (S.fog_end_studs or Y.sea.fog_end_studs) * L.SCALE; Lighting.FogStart = Lighting.FogEnd * 0.5; Lighting.FogColor = c3(S.atmosphere and S.atmosphere.color or { 190, 205, 225 })
end

-- ---------- part primitives ----------
function L.yaw(a) return CFrame.Angles(0, a, 0) end
function L.part(parent, shape, cf, size, mat, color, opts)
  local p = Instance.new("Part")
  p.Shape = shape or Enum.PartType.Block
  p.Size = size; p.CFrame = cf
  p.Material = mat or MAT.SmoothPlastic; p.Color = color or L.C.stone
  p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
  if opts then
    if opts.name then p.Name = opts.name end
    if opts.cancollide == false then p.CanCollide = false end
    if opts.transparency then p.Transparency = opts.transparency end
  end
  p.Parent = parent
  return p
end
function L.box(parent, cf, size, mat, color, opts) return L.part(parent, Enum.PartType.Block, cf, size, mat, color, opts) end
function L.ball(parent, cf, size, mat, color, opts) return L.part(parent, Enum.PartType.Ball, cf, size, mat, color, opts) end
function L.cyl(parent, cf, radius, height, mat, color, opts)        -- vertical cylinder (Roblox cylinder axis is X -> roll 90°)
  return L.part(parent, Enum.PartType.Cylinder, cf * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(height, radius * 2, radius * 2), mat, color, opts)
end
function L.rod(parent, a, b, radius, mat, color, opts)              -- cylinder from point a to point b
  local len = (b - a).Magnitude
  local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)   -- X axis along a->b
  return L.part(parent, Enum.PartType.Cylinder, cf, Vector3.new(len, radius * 2, radius * 2), mat, color, opts)
end
function L.wedge(parent, cf, size, mat, color)
  local p = Instance.new("WedgePart"); p.Size = size; p.CFrame = cf; p.Material = mat or MAT.Slate; p.Color = color or L.C.roofRed
  p.Anchored = true; p.Parent = parent; return p
end
function L.model(parent, name) local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m end
function L.crystal(parent, pos, size, color)
  local p = L.box(parent, CFrame.new(pos) * CFrame.Angles(math.rad(35), math.rad(45), 0), Vector3.new(size, size * 2.2, size), MAT.Neon, color or L.C.crystal, { cancollide = false, name = "Crystal" })
  local light = Instance.new("PointLight"); light.Color = color or L.C.crystal; light.Range = size * 8; light.Brightness = 2; light.Parent = p
  return p
end
function L.findShore(x, z, dx, dz, maxDist)     -- walk from (x,z) along (dx,dz) until water; returns last land point
  local len = math.sqrt(dx * dx + dz * dz); dx, dz = dx / len, dz / len
  local lx, lz = x, z
  for s = 0, maxDist or 3000, 8 do
    local px, pz = x + dx * s, z + dz * s
    if L.heightAt(px, pz) < 1 then return lx, lz end
    lx, lz = px, pz
  end
  return lx, lz
end
function L.dirTo(x, z, tx, tz) local dx, dz = tx - x, tz - z; local l = math.sqrt(dx * dx + dz * dz); return dx / l, dz / l end

-- ---------- 2D geometry ----------
function L.segIntersect(p, p2, q, q2)
  local r = { p2[1] - p[1], p2[2] - p[2] }; local s = { q2[1] - q[1], q2[2] - q[2] }
  local den = r[1] * s[2] - r[2] * s[1]; if math.abs(den) < 1e-9 then return nil end
  local t = ((q[1] - p[1]) * s[2] - (q[2] - p[2]) * s[1]) / den
  local u = ((q[1] - p[1]) * r[2] - (q[2] - p[2]) * r[1]) / den
  if t >= 0 and t <= 1 and u >= 0 and u <= 1 then return { p[1] + r[1] * t, p[2] + r[2] * t }, r end
  return nil
end
function L.polyCrossings(poly, path)
  local out = {}
  for i = 1, #path - 1 do for j = 1, #poly do
    local pt, dir = L.segIntersect(path[i], path[i + 1], poly[j], poly[j % #poly + 1])
    if pt then out[#out + 1] = { pt = pt, dir = Vector3.new(dir[1], 0, dir[2]).Unit } end
  end end
  return out
end
function L.pointInPoly(poly, x, z)
  local inside, j = false, #poly
  for i = 1, #poly do
    local xi, zi, xj, zj = poly[i][1], poly[i][2], poly[j][1], poly[j][2]
    if ((zi > z) ~= (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi) + xi) then inside = not inside end
    j = i
  end
  return inside
end
function L.wallWorld() local out = {}; for i, p in ipairs(Y.capital.wall.polygon) do local x, z = L.toWorld(p); out[i] = { x, z } end; return out end
function L.roadWorld(road) local out = {}; for i, e in ipairs(road) do local x, z = L.toWorld(L.pt(e)); out[i] = { x, z } end; return out end
function L.padY(x, z) return math.floor(L.heightAt(x, z) / 4) * 4 end
function L.flattenRect(x, z, w, d, y, mat)        -- fill below y, clear above; skips river/water cells
  for cx = x - w / 2 + 4, x + w / 2 - 4, 8 do for cz = z - d / 2 + 4, z + d / 2 - 4, 8 do
    local rd, _, rw = L.riverAt(cx, cz)
    if rd > rw / 2 + 10 and L.heightAt(cx, cz) > 0 then
      Terrain:FillBlock(CFrame.new(cx, y - 8, cz), Vector3.new(8, 16, 8), mat or MAT.Ground)
      Terrain:FillBlock(CFrame.new(cx, y + 30, cz), Vector3.new(8, 60, 8), MAT.Air)
    end
  end end
end
function L.flattenDisc(x, z, r, y, mat)
  for cx = x - r + 4, x + r - 4, 8 do for cz = z - r + 4, z + r - 4, 8 do
    if (cx - x) ^ 2 + (cz - z) ^ 2 <= r * r then
      local rd, _, rw = L.riverAt(cx, cz)
      if rd > rw / 2 + 10 and L.heightAt(cx, cz) > 0 then
        Terrain:FillBlock(CFrame.new(cx, y - 8, cz), Vector3.new(8, 16, 8), mat or MAT.Ground)
        Terrain:FillBlock(CFrame.new(cx, y + 30, cz), Vector3.new(8, 60, 8), MAT.Air)
      end
    end
  end end
end

-- ---------- buildings ----------
function L.house(parent, x, y, z, w, d, floors, opts)
  opts = opts or {}
  local m = L.model(parent, opts.name or "House")
  local base = CFrame.new(x, y, z) * L.yaw(opts.yaw or 0)
  local fh = 10
  for f = 0, floors - 1 do
    local stone = (f == 0) or opts.stone
    L.box(m, base * CFrame.new(0, f * fh + fh / 2, 0), Vector3.new(w, fh, d), stone and MAT.Cobblestone or MAT.Plaster, stone and L.C.darkStone or L.C.plaster)
    if not stone then
      for s = -1, 1, 2 do
        L.box(m, base * CFrame.new(s * (w / 2 - 0.4), f * fh + fh / 2, 0), Vector3.new(0.8, fh, d + 0.4), MAT.Wood, L.C.wood, { cancollide = false })
        L.box(m, base * CFrame.new(0, f * fh + fh / 2, s * (d / 2 - 0.4)), Vector3.new(w + 0.4, fh, 0.8), MAT.Wood, L.C.wood, { cancollide = false })
      end
      L.box(m, base * CFrame.new(0, f * fh + 0.4, 0), Vector3.new(w + 0.4, 0.8, d + 0.4), MAT.Wood, L.C.wood, { cancollide = false })
    end
    for s = -1, 1, 2 do L.box(m, base * CFrame.new(s * w / 4, f * fh + 6, d / 2 + 0.2), Vector3.new(3, 3.5, 0.4), MAT.Glass, L.C.glass, { cancollide = false }) end
  end
  L.box(m, base * CFrame.new(0, 4, d / 2 + 0.3), Vector3.new(4, 8, 0.6), MAT.Wood, L.C.wood, { cancollide = false, name = "Door" })
  local rh, top, rc = 7, floors * fh, opts.roof or L.C.roofRed
  L.wedge(m, base * CFrame.new(0, top + rh / 2, d / 4), Vector3.new(w + 2, rh, d / 2 + 1), MAT.Slate, rc)
  L.wedge(m, base * CFrame.new(0, top + rh / 2, -d / 4) * CFrame.Angles(0, math.pi, 0), Vector3.new(w + 2, rh, d / 2 + 1), MAT.Slate, rc)
  L.cyl(m, base * CFrame.new(w / 3, top + rh / 2 + 2, 0), 1.2, rh + 4, MAT.Brick, L.C.brick)
  return m
end
function L.tower(parent, x, y, z, r, h, opts)
  opts = opts or {}
  local m = L.model(parent, opts.name or "Tower")
  L.cyl(m, CFrame.new(x, y + h / 2, z), r, h, MAT.Cobblestone, L.C.stone)
  if opts.roof == false then
    L.cyl(m, CFrame.new(x, y + h + 0.5, z), r + 1, 1, MAT.Cobblestone, L.C.darkStone)
    for i = 0, 7 do local a = i * math.pi / 4; L.box(m, CFrame.new(x + math.cos(a) * r, y + h + 2.5, z + math.sin(a) * r) * L.yaw(-a), Vector3.new(2, 3, 3), MAT.Cobblestone, L.C.stone, { cancollide = false }) end
  else
    for i = 1, 4 do L.cyl(m, CFrame.new(x, y + h + (i - 0.5) * 2.5, z), r * (1.15 - 0.25 * i), 2.5, MAT.Slate, opts.roofColor or L.C.roofRed) end
  end
  return m
end
function L.wallPath(parent, pts, h, t, opts)      -- pts: world {x,z} list; follows terrain; skips water & gaps
  opts = opts or {}
  local m = L.model(parent, opts.name or "Wall")
  local list = {}; for i, p in ipairs(pts) do list[i] = p end
  if opts.closed then list[#list + 1] = pts[1] end
  local since = 0
  for i = 1, #list - 1 do
    local a = Vector3.new(list[i][1], 0, list[i][2]); local b = Vector3.new(list[i + 1][1], 0, list[i + 1][2])
    local len = (b - a).Magnitude; local dir = (b - a).Unit; local yaw = math.atan2(-dir.Z, dir.X)
    local ha = L.heightAt(a.X, a.Z); if ha > 2 then L.tower(m, a.X, ha, a.Z, t * 1.8, h * 1.5, { roof = false }) end
    local s = 0
    while s < len do
      local seg = math.min(10, len - s)
      local p = a + dir * (s + seg / 2)
      local g = L.heightAt(p.X, p.Z)
      local gap = false
      for _, gp in ipairs(opts.gaps or {}) do if (Vector3.new(gp[1], 0, gp[2]) - p).Magnitude < gp[3] then gap = true end end
      if g > 2 and not gap then
        L.box(m, CFrame.new(p.X, g + h / 2 - 2, p.Z) * L.yaw(yaw), Vector3.new(seg + 0.2, h + 4, t), MAT.Cobblestone, L.C.stone)
        L.box(m, CFrame.new(p.X, g + h + 1, p.Z) * L.yaw(yaw) * CFrame.new(0, 0, t / 2 - 0.75), Vector3.new(seg * 0.5, 2, 1.5), MAT.Cobblestone, L.C.stone, { cancollide = false })
        since += seg
        if since >= (opts.towerSpacing or 250) then since = 0; L.tower(m, p.X, g, p.Z, t * 1.8, h * 1.5, { roof = false }) end
      end
      s += seg
    end
  end
  return m
end
function L.gate(parent, x, z, dir, width, h)
  local g = L.heightAt(x, z)
  local side = Vector3.new(-dir.Z, 0, dir.X).Unit
  for s = -1, 1, 2 do local p = Vector3.new(x, 0, z) + side * (width / 2 + 7) * s; L.tower(parent, p.X, g, p.Z, 8, h + 14, { roof = true, name = "GateTower" }) end
  L.box(parent, CFrame.new(x, g + h - 3, z) * L.yaw(math.atan2(-side.Z, side.X)), Vector3.new(width + 14, 8, 10), MAT.Cobblestone, L.C.darkStone, { name = "GateArch" })
  Terrain:FillBlock(CFrame.new(x, g - 1.5, z) * L.yaw(math.atan2(-dir.Z, dir.X)), Vector3.new(40, 3, width), MAT.Cobblestone)
end
function L.castle(parent, x, y, z, faceDir, opts)   -- curtain wall square with corner towers, main keep, great tower, gate facing faceDir (Vector3)
  opts = opts or {}
  local K = Y.capital.landmarks
  local s = opts.size or K.keep_wall_size
  local m = L.model(parent, opts.name or "Castle")
  local faceSide = math.abs(faceDir.X) > math.abs(faceDir.Z) and (faceDir.X > 0 and 2 or 4) or (faceDir.Z > 0 and 3 or 1)   -- 1 north(-z) 2 east 3 south 4 west
  local sides = { { CFrame.new(x, 0, z - s / 2), 0 }, { CFrame.new(x + s / 2, 0, z), math.pi / 2 }, { CFrame.new(x, 0, z + s / 2), 0 }, { CFrame.new(x - s / 2, 0, z), math.pi / 2 } }
  for i, sd in ipairs(sides) do
    local cf = sd[1] * L.yaw(sd[2])
    if i == faceSide then
      for hh = -1, 1, 2 do L.box(m, cf * CFrame.new(hh * (s / 4 + 6), y + 20, 0), Vector3.new(s / 2 - 12, 40, 8), MAT.Cobblestone, L.C.stone) end
      L.gate(m, cf.Position.X, cf.Position.Z, faceDir.Unit, 24, 34)
    else
      L.box(m, cf * CFrame.new(0, y + 20, 0), Vector3.new(s, 40, 8), MAT.Cobblestone, L.C.stone)
      for k = -s / 2 + 4, s / 2 - 4, 8 do L.box(m, cf * CFrame.new(k, y + 42, 0), Vector3.new(4, 4, 8.5), MAT.Cobblestone, L.C.stone, { cancollide = false }) end
    end
  end
  for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do L.tower(m, x + c[1] * s / 2, y, z + c[2] * s / 2, 14, K.keep_corner_tower_height, { roof = true, roofColor = L.C.roofBlue }) end
  local kw = s * 0.4
  L.box(m, CFrame.new(x, y + 55, z), Vector3.new(kw, 110, kw), MAT.Cobblestone, L.C.darkStone, { name = "MainKeep" })
  for i = 0, 5 do for s2 = -1, 1, 2 do L.box(m, CFrame.new(x + s2 * (kw / 2 + 0.3), y + 25 + i * 14, z - kw / 3 + (i % 3) * kw / 3), Vector3.new(0.6, 6, 3), MAT.Glass, L.C.glass, { cancollide = false }) end end
  L.box(m, CFrame.new(x, y + 6, z + kw / 2 + 0.4), Vector3.new(10, 12, 0.8), MAT.Wood, L.C.wood, { cancollide = false, name = "HallDoor" })
  L.tower(m, x, y, z, 20, K.keep_main_tower_height, { roof = true, roofColor = L.C.roofBlue, name = "GreatTower" })
  L.box(m, CFrame.new(x, y + K.keep_main_tower_height + 16, z), Vector3.new(0.5, 12, 8), MAT.Fabric, L.C.roofRed, { cancollide = false, name = "Banner" })
  return m
end
function L.sign(parent, x, y, z, text, yaw)
  L.box(parent, CFrame.new(x, y + 4, z), Vector3.new(0.8, 8, 0.8), MAT.Wood, L.C.wood)
  local board = L.box(parent, CFrame.new(x, y + 8, z) * L.yaw(yaw or 0), Vector3.new(14, 4, 0.6), MAT.WoodPlanks, L.C.plank, { name = "Sign" })
  for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
    local gui = Instance.new("SurfaceGui"); gui.Face = face; gui.Parent = board
    local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.TextScaled = true; lbl.Font = Enum.Font.Antique; lbl.TextColor3 = Color3.fromRGB(40, 30, 20); lbl.Parent = gui
  end
  return board
end
function L.chimney(parent, x, y, z, r, h, smoke)
  local c = L.cyl(parent, CFrame.new(x, y + h / 2, z), r, h, MAT.Brick, L.C.brick, { name = "Chimney" })
  if smoke then
    local att = Instance.new("Attachment"); att.CFrame = CFrame.new(h / 2, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2); att.Parent = c  -- part is rolled 90°: local X = world up
    local pe = Instance.new("ParticleEmitter"); pe.Texture = "rbxassetid://243660364"; pe.Rate = 6; pe.Lifetime = NumberRange.new(4, 7); pe.Speed = NumberRange.new(4, 8)
    pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, r * 1.5), NumberSequenceKeypoint.new(1, r * 6) })
    pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
    pe.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200)); pe.Acceleration = Vector3.new(1, 1.5, 0); pe.Parent = att
  end
  return c
end
function L.gear(parent, cf, r, teeth, thick, color)
  local m = L.model(parent, "Gear")
  L.part(m, Enum.PartType.Cylinder, cf, Vector3.new(thick, r * 2, r * 2), MAT.Metal, color or L.C.brass, { cancollide = false })
  for i = 0, teeth - 1 do local a = i * 2 * math.pi / teeth
    L.box(m, cf * CFrame.Angles(a, 0, 0) * CFrame.new(0, r + 1, 0), Vector3.new(thick, 2.5, r * 0.35), MAT.Metal, color or L.C.brass, { cancollide = false }) end
  return m
end
function L.pipeRun(parent, pts, radius, color, postEvery)   -- pts: list of Vector3; cylinders + sphere joints + stone posts to ground
  local m = L.model(parent, "Pipe")
  for i = 1, #pts - 1 do
    L.rod(m, pts[i], pts[i + 1], radius, MAT.Metal, color or L.C.brass, { cancollide = false })
    L.ball(m, CFrame.new(pts[i]), Vector3.new(radius * 2.6, radius * 2.6, radius * 2.6), MAT.Metal, L.C.copper, { cancollide = false })
    if postEvery then
      local len = (pts[i + 1] - pts[i]).Magnitude
      for s = 0, len, postEvery do local p = pts[i] + (pts[i + 1] - pts[i]).Unit * s; local g = L.heightAt(p.X, p.Z)
        if p.Y - g > 1 then L.box(m, CFrame.new(p.X, (p.Y + g) / 2, p.Z), Vector3.new(2, p.Y - g, 2), MAT.Cobblestone, L.C.darkStone) end end
    end
  end
  return m
end
function L.tree(parent, x, y, z, kind, s)         -- 2 parts per tree; kind: "pine" | "oak" | "palm"
  s = s or 1
  if kind == "pine" then
    L.cyl(parent, CFrame.new(x, y + 6 * s, z), 1.2 * s, 12 * s, MAT.Wood, L.C.trunk, { name = "Tree" })
    L.ball(parent, CFrame.new(x, y + 22 * s, z), Vector3.new(12 * s, 30 * s, 12 * s), MAT.Grass, L.C.leafDark, { cancollide = false })
  elseif kind == "palm" then
    L.cyl(parent, CFrame.new(x, y + 9 * s, z) * CFrame.Angles(0, 0, 0.12), 0.9 * s, 18 * s, MAT.Wood, L.C.trunk, { name = "Tree" })
    L.ball(parent, CFrame.new(x, y + 19 * s, z), Vector3.new(16 * s, 5 * s, 16 * s), MAT.Grass, L.C.leafLight, { cancollide = false })
  else
    L.cyl(parent, CFrame.new(x, y + 5 * s, z), 1.5 * s, 10 * s, MAT.Wood, L.C.trunk, { name = "Tree" })
    L.ball(parent, CFrame.new(x, y + 15 * s, z), Vector3.new(18 * s, 16 * s, 18 * s), MAT.Grass, L.C.leafLight, { cancollide = false })
  end
end
function L.pier(parent, x, z, dir, len, w, y)     -- planks on posts from (x,z) outward along dir (Vector3)
  local m = L.model(parent, "Pier")
  local yaw = math.atan2(-dir.Z, dir.X)
  L.box(m, CFrame.new(x + dir.X * len / 2, y, z + dir.Z * len / 2) * L.yaw(yaw), Vector3.new(len, 1.5, w), MAT.WoodPlanks, L.C.plank)
  for s = 0, len, 20 do for side = -1, 1, 2 do
    local p = Vector3.new(x, 0, z) + dir * s + Vector3.new(-dir.Z, 0, dir.X) * (w / 2 - 1) * side
    local bottom = math.min(L.heightAt(p.X, p.Z), -2)
    L.cyl(m, CFrame.new(p.X, (y + bottom) / 2, p.Z), 1, y - bottom, MAT.Wood, L.C.wood)
  end end
  return m
end
function L.boat(parent, x, y, z, yaw, len)
  local m = L.model(parent, "Boat"); local base = CFrame.new(x, y, z) * L.yaw(yaw)
  L.box(m, base * CFrame.new(0, 2, 0), Vector3.new(len, 4, len * 0.3), MAT.WoodPlanks, L.C.wood)
  L.wedge(m, base * CFrame.new(len / 2 + len * 0.08, 2, 0) * CFrame.Angles(0, -math.pi / 2, 0), Vector3.new(len * 0.3, 4, len * 0.16), MAT.WoodPlanks, L.C.wood)
  L.rod(m, (base * CFrame.new(0, 4, 0)).Position, (base * CFrame.new(0, 4 + len * 0.6, 0)).Position, 0.5, MAT.Wood, L.C.wood)
  L.box(m, base * CFrame.new(0, 4 + len * 0.35, 0), Vector3.new(0.3, len * 0.4, len * 0.25), MAT.Fabric, L.C.sail, { cancollide = false })
  return m
end

-- ---------- bridges ----------
function L.stoneBridge(m, x, z, dir, len, w, y, waterY, arches)
  local base = CFrame.new(x, 0, z) * L.yaw(math.atan2(-dir.Z, dir.X))
  L.box(m, base * CFrame.new(0, y - 1.5, 0), Vector3.new(len, 3, w), MAT.Cobblestone, L.C.stone, { name = "Deck" })
  for s = -1, 1, 2 do L.box(m, base * CFrame.new(0, y + 1.5, s * (w / 2 - 1)), Vector3.new(len, 3, 2), MAT.Cobblestone, L.C.darkStone) end
  local span = len / arches
  for i = 1, arches - 1 do
    local px = -len / 2 + i * span; local wp = base * CFrame.new(px, 0, 0)
    local bed = L.heightAt(wp.X, wp.Z) - 4
    L.box(m, base * CFrame.new(px, (y - 3 + bed) / 2, 0), Vector3.new(8, y - 3 - bed, w + 4), MAT.Cobblestone, L.C.darkStone)
  end
end
function L.trussBridge(m, x, z, dir, len, w, y, waterY)
  local base = CFrame.new(x, 0, z) * L.yaw(math.atan2(-dir.Z, dir.X))
  L.box(m, base * CFrame.new(0, y - 1, 0), Vector3.new(len, 2, w), MAT.DiamondPlate, L.C.iron, { name = "Deck" })
  for s = -1, 1, 2 do
    local zoff = s * (w / 2 - 0.5)
    L.box(m, base * CFrame.new(0, y + 12, zoff), Vector3.new(len, 1.2, 1.2), MAT.Metal, L.C.iron, { cancollide = false })
    for px = -len / 2, len / 2, 12 do
      L.box(m, base * CFrame.new(px, y + 6, zoff), Vector3.new(1, 12, 1), MAT.Metal, L.C.iron, { cancollide = false })
      if px + 12 <= len / 2 then L.rod(m, (base * CFrame.new(px, y, zoff)).Position, (base * CFrame.new(px + 12, y + 12, zoff)).Position, 0.4, MAT.Metal, L.C.rust, { cancollide = false }) end
    end
  end
  for i = 1, 2 do local px = -len / 2 + i * len / 3; local wp = base * CFrame.new(px, 0, 0); local bed = L.heightAt(wp.X, wp.Z) - 4
    L.box(m, base * CFrame.new(px, (y - 2 + bed) / 2, 0), Vector3.new(6, y - 2 - bed, w + 2), MAT.Cobblestone, L.C.darkStone) end
end
function L.drawBridge(m, x, z, dir, len, w, y, waterY)
  local base = CFrame.new(x, 0, z) * L.yaw(math.atan2(-dir.Z, dir.X))
  for s = -1, 1, 2 do
    L.box(m, base * CFrame.new(s * len / 4, y - 1, 0), Vector3.new(len / 2 - 1, 2, w), MAT.DiamondPlate, L.C.iron, { name = "Leaf" })
    local tp = base * CFrame.new(s * (len / 2 + 6), 0, 0); local g = L.heightAt(tp.X, tp.Z)
    L.box(m, base * CFrame.new(s * (len / 2 + 6), (g + y + 40) / 2, 0), Vector3.new(12, y + 40 - g, w + 8), MAT.Brick, L.C.brick, { name = "MachineTower" })
    L.gear(m, base * CFrame.new(s * (len / 2 + 6), y + 30, (w / 2 + 5)) * CFrame.Angles(0, 0, math.pi / 2), 6, 12, 1.5, L.C.brass)
    L.rod(m, (base * CFrame.new(s * (len / 2 + 6), y + 38, 0)).Position, (base * CFrame.new(s * len / 8, y, 0)).Position, 0.5, MAT.Metal, L.C.iron, { cancollide = false })
    L.chimney(m, tp.X, y + 40, tp.Z, 2, 12, true)
  end
end
function L.woodBridge(m, x, z, dir, len, w, y, waterY, logs)
  local base = CFrame.new(x, 0, z) * L.yaw(math.atan2(-dir.Z, dir.X))
  if logs then
    for zoff = -w / 2 + 1, w / 2 - 1, 2 do L.part(m, Enum.PartType.Cylinder, base * CFrame.new(0, y - 1, zoff), Vector3.new(len, 2, 2), MAT.Wood, L.C.trunk) end
  else
    for px = -len / 2 + 1, len / 2 - 1, 2.2 do L.box(m, base * CFrame.new(px, y - 0.5, 0), Vector3.new(2, 1, w), MAT.WoodPlanks, L.C.plank) end
  end
  for px = -len / 2, len / 2, 10 do for s = -1, 1, 2 do
    local pp = base * CFrame.new(px, 0, s * (w / 2 - 0.5)); local bed = L.heightAt(pp.X, pp.Z) - 2
    L.cyl(m, CFrame.new(pp.X, (y + 3 + bed) / 2, pp.Z), 0.7, y + 3 - bed, MAT.Wood, L.C.wood)
  end end
  for s = -1, 1, 2 do L.box(m, base * CFrame.new(0, y + 3, s * (w / 2 - 0.5)), Vector3.new(len, 0.6, 0.6), MAT.Wood, L.C.wood, { cancollide = false }) end
end
function L.bridge(parent, b)
  local x, z = L.toWorld(b.pos)
  local dir = Vector3.new(b.dir[1], 0, b.dir[2]).Unit
  local len = b.length
  local a = Vector3.new(x, 0, z) - dir * len / 2; local c = Vector3.new(x, 0, z) + dir * len / 2
  local _, hs = L.riverAt(x, z)
  local deckY = math.floor(math.max(L.heightAt(a.X, a.Z), L.heightAt(c.X, c.Z), hs + 10) / 4) * 4 + 2
  local m = L.model(parent, b.name)
  if b.type == "stone_arch" then L.stoneBridge(m, x, z, dir, len, 30, deckY, hs, b.arches or 3)
  elseif b.type == "iron_truss" then L.trussBridge(m, x, z, dir, len, 14, deckY, hs)
  elseif b.type == "mechanical_draw" then L.drawBridge(m, x, z, dir, len, 24, deckY, hs)
  else L.woodBridge(m, x, z, dir, len, b.type == "wood_log" and 10 or 8, deckY, hs, b.type == "wood_log") end
  for _, e in ipairs({ a, c }) do Terrain:FillBlock(CFrame.new(e.X, deckY - 4, e.Z), Vector3.new(36, 8, 36), MAT.Cobblestone) end  -- approach pads
  return m
end
function L.paintRoad(a, b, width, mat, skipFn)     -- paint a road strip on the terrain surface between world points a,b (Vector3, y ignored)
  local len = (b - a).Magnitude; if len < 1 then return end
  local dir = (b - a).Unit; local yaw = math.atan2(-dir.Z, dir.X)
  for s = 0, len, 4 do
    local p = a + dir * s
    local h = L.heightAt(p.X, p.Z); local d, _, w = L.riverAt(p.X, p.Z)
    if h > 1 and d > w / 2 + 6 and not (skipFn and skipFn(p)) then
      Terrain:FillBlock(CFrame.new(p.X, h - 1.5, p.Z) * L.yaw(yaw), Vector3.new(6, 3, width), mat)
    end
  end
end
