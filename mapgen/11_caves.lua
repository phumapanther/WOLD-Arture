-- caves (phase 3): a short lit trunk from each entrance, then a branching maze of worm-burrow tunnels wandering deep under the mountain,
--   plus one big cavern at the end of each trunk. Ore/crystal/stalagmite decor sits on the tunnel walls and ceilings, never the floor.
--   Stonemark Mine (ore veins + cart rails on the trunk), Crystal Cave (glowing hall + crystal-studded tendrils), Sea Cave (west cliff, shipwreck)
--   gameplay hooks: OreVein/Crystal tags (Mining), Zone "dungeon" at each entrance, RespawnPoint at the mine entrance
return L.runPhase("Caves", function(folder)
  L.requireFullScale()
  local Y, MAT, Terrain = L.LAYOUT, L.MAT, workspace.Terrain
  local HttpService = game:GetService("HttpService")

  -- ---------- shared carving primitives ----------
  local function carveSegments(segs)                  -- segs: {a=Vector3, b=Vector3, r=number}; air balls every 6 studs + a flat rock floor
    for _, s in ipairs(segs) do
      local len = (s.b - s.a).Magnitude
      if len > 0.5 then
        local dir = (s.b - s.a).Unit
        for t = 0, len, 6 do
          local p = s.a + dir * t
          Terrain:FillBall(p + Vector3.new(0, s.r * 0.4, 0), s.r, MAT.Air)
          Terrain:FillBlock(CFrame.new(p.X, p.Y - s.r * 0.6 - 2, p.Z), Vector3.new(s.r * 1.6, 4, s.r * 1.6), MAT.Rock)
        end
      end
    end
  end
  local function pathToSegs(path, r) local segs = {}; for i = 1, #path - 1 do segs[#segs + 1] = { a = path[i], b = path[i + 1], r = r } end; return segs end
  local function carve(path, r) carveSegments(pathToSegs(path, r)); task.wait() end
  local function chamber(p, r)                        -- big single cavern; stays under at least 8 studs of rock (shrinks to the available cover)
    local cover = L.heightAt(p.X, p.Z) - p.Y
    r = math.max(14, math.min(r, (cover - 8) / 1.5))
    Terrain:FillBall(p + Vector3.new(0, r * 0.5, 0), r, MAT.Air)
    Terrain:FillBlock(CFrame.new(p.X, p.Y - 2, p.Z), Vector3.new(r * 1.8, 4, r * 1.8), MAT.Rock)
    return r
  end
  local function carvePockets(pockets) for _, c in ipairs(pockets) do chamber(c.pos, c.r) end end   -- small maze bubbles, same cover rule as the big hall

  -- ---------- branching maze: worm-burrow tunnels wandering under the mountain, deep, never breaching the surface ----------
  local function growMaze(rng, seeds, opts)
    -- seeds: {{pos=Vector3, dir=Vector3 horizontal unit}, ...}; opts: maxSegments, segMin/Max, wander(rad), dive(studs/100 forward),
    --        r0, rMin, rMax, branchChance, maxGen, chamberChance, chamberMax, minCover
    local segments, pockets, stack = {}, {}, {}
    for _, s in ipairs(seeds) do stack[#stack + 1] = { pos = s.pos, dir = s.dir, r = opts.r0, gen = 0 } end
    local n = 0
    while #stack > 0 and n < opts.maxSegments do
      local idx = rng:NextInteger(1, #stack)
      local cur = table.remove(stack, idx)             -- random pick: the walk spreads through the whole volume instead of racing to one depth
      n += 1
      local len = rng:NextNumber(opts.segMin, opts.segMax)
      local ang = math.atan2(cur.dir.Z, cur.dir.X) + rng:NextNumber(-opts.wander, opts.wander)
      local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
      local nxt = cur.pos + dir * len - Vector3.new(0, opts.dive * len / 100, 0)
      local minY = L.heightAt(nxt.X, nxt.Z) - cur.r - opts.minCover
      if nxt.Y > minY then nxt = Vector3.new(nxt.X, minY, nxt.Z) end   -- clamp: never closer than r+minCover to the real surface here
      segments[#segments + 1] = { a = cur.pos, b = nxt, r = cur.r }
      if rng:NextNumber() < opts.chamberChance then
        pockets[#pockets + 1] = { pos = nxt, r = math.min(opts.chamberMax, cur.r * rng:NextNumber(1.6, 2.2)) }
      end
      local nr = math.clamp(cur.r * rng:NextNumber(0.9, 1.05), opts.rMin, opts.rMax)
      if cur.gen < opts.maxGen and rng:NextNumber() < opts.branchChance then
        for i = 1, 2 do
          local bang = ang + (i == 1 and 1 or -1) * rng:NextNumber(0.6, 1.4)
          stack[#stack + 1] = { pos = nxt, dir = Vector3.new(math.cos(bang), 0, math.sin(bang)), r = nr * 0.85, gen = cur.gen + 1 }
        end
      else
        stack[#stack + 1] = { pos = nxt, dir = dir, r = nr, gen = cur.gen }
      end
      if n % 5 == 0 then task.wait() end
    end
    return segments, pockets
  end

  -- ---------- wall-hugging decor spot: on the tunnel wall or ceiling, biased away from the floor ----------
  local function wallSpot(seg, t, rng)
    local p = seg.a + (seg.b - seg.a) * t
    local ballCenter = p + Vector3.new(0, seg.r * 0.4, 0)
    local dv = seg.b - seg.a; if dv.Magnitude < 0.5 then dv = Vector3.new(1, 0, 0) end
    local side = Vector3.new(-dv.Unit.Z, 0, dv.Unit.X)
    local theta = rng:NextNumber(0, 2 * math.pi)
    if math.sin(theta) < -0.25 then theta += math.pi end   -- flip out of the bottom arc: result is wall-to-ceiling, never the floor
    local offset = (side * math.cos(theta) + Vector3.new(0, 1, 0) * math.sin(theta)) * seg.r * rng:NextNumber(0.72, 0.9)
    return ballCenter + offset
  end
  local function randomWallSpot(segs, rng) local seg = segs[rng:NextInteger(1, #segs)]; return wallSpot(seg, rng:NextNumber(0.08, 0.92), rng) end
  local function scatterOre(mm, segs, rng, count, resource, scaleMin, scaleMax)
    for i = 1, count do
      local p = randomWallSpot(segs, rng)
      local ore = L.assetList("ore") and L.placeAsset(mm, "ore", p.X, p.Y, p.Z, rng, scaleMin, scaleMax)
      if ore then L.tag(ore, "OreVein", { GatherType = "Mining", Resource = resource })
      else L.tag(L.box(mm, CFrame.new(p) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), Vector3.new(2, 1.5, 2.5), MAT.CorrodedMetal, L.C.rust, { name = "OreVein" }), "OreVein", { GatherType = "Mining", Resource = resource }) end
      if i % 10 == 0 then task.wait() end
    end
  end
  local function scatterCaveDecor(mm, segs, rng, count, scaleMin, scaleMax)
    if not L.assetList("cave") then return end
    for i = 1, count do local p = randomWallSpot(segs, rng); L.placeAsset(mm, "cave", p.X, p.Y, p.Z, rng, scaleMin, scaleMax) end
  end
  local function keepClearOfHall(seeds, hallPos, hallR)   -- a maze seed inside the big hall (or seeded AT it) can drop a rock floor slab through the open cavern;
    local margin = hallR + 20                             -- push any such seed out past the hall wall first so its own tunnel/pockets start outside it
    local out = {}
    for _, sd in ipairs(seeds) do
      local d = sd.pos - hallPos
      if d.Magnitude < margin then
        d = (d.Magnitude < 1) and sd.dir * margin or d.Unit * margin
        out[#out + 1] = { pos = hallPos + d, dir = sd.dir }
      else
        out[#out + 1] = sd
      end
    end
    return out
  end

  -- ---------- trunk: the one lit path from the mouth, used for rails/spawn/camera probes; deep and level at the threshold ----------
  local function tunnel(ex, ez, tx, tz, rng, legs, down, r)
    local ey = L.heightAt(ex, ez) + 1
    local path = { Vector3.new(ex, ey, ez) }
    local dx, dz = L.dirTo(ex, ez, tx, tz)
    local p = path[1] + Vector3.new(dx * 50, 0, dz * 50)
    path[#path + 1] = p
    for _ = 1, legs do
      local a = math.atan2(dz, dx) + rng:NextNumber(-0.6, 0.6)
      local len = rng:NextNumber(60, 120)
      p = p + Vector3.new(math.cos(a) * len, -down * len / 100, math.sin(a) * len)
      p = Vector3.new(p.X, math.min(p.Y, L.heightAt(p.X, p.Z) - r - 8), p.Z)
      path[#path + 1] = p
    end
    return path
  end
  local function savePath(m, path) local t = {}; for i, p in ipairs(path) do t[i] = { math.floor(p.X), math.floor(p.Y), math.floor(p.Z) } end; m:SetAttribute("Path", HttpService:JSONEncode(t)) end
  local function entrance(m, name, x, z, dx, dz)      -- open mouth: air balls stepping inward and downward along the first leg, lit by two torches, zone + sign
    local y = L.heightAt(x, z)
    for s = -10, 50, 10 do Terrain:FillBall(Vector3.new(x + dx * s, y + 10 - math.max(0, s) * 0.12, z + dz * s), 16, MAT.Air) end
    Terrain:FillBlock(CFrame.new(x + dx * 20, y - 3, z + dz * 20) * L.yaw(math.atan2(-dz, dx)), Vector3.new(70, 6, 36), MAT.Rock)
    local side = Vector3.new(-dz, 0, dx)
    for sgn = -1, 1, 2 do
      local tp = Vector3.new(x, y, z) + side * 13 * sgn - Vector3.new(dx, 0, dz) * 4
      L.cyl(m, CFrame.new(tp.X, y + 4, tp.Z), 0.5, 8, MAT.Wood, L.C.wood, { name = "TorchPost" })
      local flame = L.ball(m, CFrame.new(tp.X, y + 8.6, tp.Z), Vector3.new(1.6, 2.2, 1.6), MAT.Neon, Color3.fromRGB(255, 170, 60), { cancollide = false, name = "Torch" })
      local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(255, 180, 90); light.Range = 40; light.Brightness = 2; light.Parent = flame
    end
    L.zone(m, name, "dungeon", x, y, z, 120, 160)
    L.sign(m, x + side.X * 22, y, z + side.Z * 22, name, math.atan2(-dx, dz))
  end

  local m = L.model(folder, "Caves")

  -- 1) Stonemark Mine: deepest, most branching network (the "labyrinth")
  do
    local mm = L.model(m, "Stonemark Mine"); local rng = Random.new(101)
    local ex, ez = L.toWorld(Y.caves["Stonemark Mine"]); local px, pz = L.toWorld(Y.peaks.second_NW)
    L.writeArea(ex, ez, 620)
    local main = tunnel(ex, ez, px, pz, rng, 5, 16, 14); carve(main, 14)
    local hallR = chamber(main[#main], 95)                                                     -- one big cavern at the end of the trunk
    local seeds = {}
    for i = 3, #main - 1 do
      local d = (main[i + 1] - main[i]); if d.Magnitude < 1 then d = Vector3.new(1, 0, 0) end
      seeds[#seeds + 1] = { pos = main[i], dir = d.Unit }
    end
    for a = 0, 2 do local ang = a * 2 * math.pi / 3; seeds[#seeds + 1] = { pos = main[#main], dir = Vector3.new(math.cos(ang), 0, math.sin(ang)) } end
    seeds = keepClearOfHall(seeds, main[#main], hallR)
    local mazeSegs, mazePockets = growMaze(rng, seeds, {
      maxSegments = 44, segMin = 40, segMax = 85, wander = 1.0, dive = 9,
      r0 = 10, rMin = 6, rMax = 13, branchChance = 0.42, maxGen = 3, chamberChance = 0.13, chamberMax = 30, minCover = 10,
    })
    carveSegments(mazeSegs); carvePockets(mazePockets)
    local decorPool = mazeSegs; for i = 3, #main - 1 do decorPool[#decorPool + 1] = { a = main[i], b = main[i + 1], r = 14 } end
    scatterOre(mm, decorPool, rng, 40, "Ore", 0.28, 0.5)
    scatterCaveDecor(mm, decorPool, rng, 16, 0.35, 0.7)
    for i = 1, #main - 1 do
      L.rod(mm, main[i] - Vector3.new(0, 0.5, 0), main[i + 1] - Vector3.new(0, 0.5, 0), 0.3, MAT.Metal, L.C.iron, { cancollide = false })
      L.rod(mm, main[i] + Vector3.new(0, -0.5, 3), main[i + 1] + Vector3.new(0, -0.5, 3), 0.3, MAT.Metal, L.C.iron, { cancollide = false })
    end
    local ddx, ddz = L.dirTo(ex, ez, px, pz)
    entrance(mm, "Stonemark Mine", ex, ez, ddx, ddz); savePath(mm, main)
    mm:SetAttribute("MazeSegments", #mazeSegs)
    L.spawnPoint(mm, "Stonemark Mine", ex - ddx * 30, L.heightAt(ex - ddx * 30, ez - ddz * 30), ez - ddz * 30)
    L.progress(("mine: hall r=%.0f maze segs=%d"):format(hallR, #mazeSegs)); task.wait()
  end

  -- 2) Crystal Cave: one grand luminous hall plus crystal-studded tendrils radiating from it
  do
    local mm = L.model(m, "Crystal Cave"); local rng = Random.new(202)
    local ex, ez = L.toWorld(Y.caves["Crystal Cave"]); local px, pz = L.toWorld(Y.peaks.main_NE)
    L.writeArea(ex, ez, 620)
    local path = tunnel(ex, ez, px, pz, rng, 4, 26, 16); carve(path, 16)
    local hall = path[#path]; local hallR = chamber(hall, 140)                                 -- the biggest single cavern on the island
    for i = 1, 12 do local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(10, hallR * 0.85)     -- floating crystals in the open hall (never on the floor)
      L.tag(L.crystal(mm, hall + Vector3.new(math.cos(a) * r, rng:NextNumber(0, 3), math.sin(a) * r), rng:NextNumber(2.5, 5)), "Crystal", { GatherType = "Mining", Resource = "Crystal" }) end
    for i = 1, 4 do local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(15, 40)
      L.crystal(mm, hall + Vector3.new(math.cos(a) * r, rng:NextNumber(22, 40), math.sin(a) * r), rng:NextNumber(3, 6)) end
    L.crystal(mm, hall + Vector3.new(0, 30, 0), 10)
    local seeds = {}
    for i = 2, #path - 1 do local d = (path[i + 1] - path[i]); if d.Magnitude < 1 then d = Vector3.new(1, 0, 0) end; seeds[#seeds + 1] = { pos = path[i], dir = d.Unit } end
    for a = 0, 4 do local ang = a * 2 * math.pi / 5; seeds[#seeds + 1] = { pos = hall, dir = Vector3.new(math.cos(ang), 0, math.sin(ang)) } end
    seeds = keepClearOfHall(seeds, hall, hallR)
    local mazeSegs, mazePockets = growMaze(rng, seeds, {
      maxSegments = 34, segMin = 35, segMax = 70, wander = 1.05, dive = 12,
      r0 = 11, rMin = 7, rMax = 14, branchChance = 0.36, maxGen = 2, chamberChance = 0.2, chamberMax = 36, minCover = 10,
    })
    carveSegments(mazeSegs); carvePockets(mazePockets)
    local decorPool = mazeSegs
    scatterOre(mm, decorPool, rng, 20, "Crystal", 0.3, 0.55)
    scatterCaveDecor(mm, decorPool, rng, 14, 0.4, 0.8)
    for _, c in ipairs(mazePockets) do if rng:NextNumber() < 0.6 then L.crystal(mm, c.pos + Vector3.new(0, c.r * 0.3, 0), rng:NextNumber(3, 6)) end end
    local ddx, ddz = L.dirTo(ex, ez, px, pz)
    entrance(mm, "Crystal Cave", ex, ez, ddx, ddz); savePath(mm, path)
    mm:SetAttribute("MazeSegments", #mazeSegs)
    L.progress(("crystal cave: hall r=%.0f maze segs=%d"):format(hallR, #mazeSegs)); task.wait()
  end

  -- 3) Sea Cave on the west cliff beach: shorter, a couple of tendrils, still deeper and less linear than before
  do
    local mm = L.model(m, "Sea Cave"); local rng = Random.new(303)
    local hx, hz = L.toWorld(Y.caves["Sea Cave"])
    L.writeArea(hx, hz, 620)
    local ex, ez = L.findShore(0, 0, hx, hz, L.HALF * 1.2)
    local path = tunnel(ex, ez, 0, 0, rng, 4, 16, 14); carve(path, 14)
    local hall = path[#path]; local hallR = chamber(hall, 55)
    local seeds = {}
    for i = 2, #path - 1 do local d = (path[i + 1] - path[i]); if d.Magnitude < 1 then d = Vector3.new(1, 0, 0) end; seeds[#seeds + 1] = { pos = path[i], dir = d.Unit } end
    seeds = keepClearOfHall(seeds, hall, hallR)
    local mazeSegs, mazePockets = growMaze(rng, seeds, {
      maxSegments = 16, segMin = 30, segMax = 55, wander = 1.0, dive = 7,
      r0 = 9, rMin = 6, rMax = 10, branchChance = 0.3, maxGen = 2, chamberChance = 0.15, chamberMax = 20, minCover = 8,
    })
    carveSegments(mazeSegs); carvePockets(mazePockets)
    scatterOre(mm, mazeSegs, rng, 10, "Ore", 0.28, 0.5)
    Terrain:FillBlock(CFrame.new(hall.X, hall.Y - 2, hall.Z), Vector3.new(36, 4, 36), MAT.Water)   -- tide pool
    local wreck = L.model(mm, "Shipwreck")
    L.box(wreck, CFrame.new(hall + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0.6, 0.2), Vector3.new(34, 7, 11), MAT.WoodPlanks, L.C.wood)
    L.rod(wreck, hall + Vector3.new(0, 6, 0), hall + Vector3.new(4, 24, 0), 0.8, MAT.Wood, L.C.wood)
    for i = 1, 6 do L.tag(L.cyl(wreck, CFrame.new(hall + Vector3.new(rng:NextNumber(-20, 20), 2, rng:NextNumber(-20, 20))), 2, 4, MAT.Wood, L.C.plank, { name = "Barrel" }), "SearchPoint", { GatherType = "Searching" }) end
    L.marker(mm, "FishingSpot", hall.X + 20, hall.Y, hall.Z + 20, { GatherType = "Fishing" })
    local ddx, ddz = L.dirTo(ex, ez, 0, 0)
    entrance(mm, "Sea Cave", ex, ez, ddx, ddz); savePath(mm, path)
    mm:SetAttribute("MazeSegments", #mazeSegs)
    L.progress(("sea cave: maze segs=%d"):format(#mazeSegs))
  end
end)
