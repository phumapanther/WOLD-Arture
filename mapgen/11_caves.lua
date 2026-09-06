-- caves (phase 3): carve air balls along deterministic tunnel paths into the mountains, flat floors, chambers, decorations
--   Stonemark Mine (ore veins + cart rails), Crystal Cave (glowing hall), Sea Cave (west cliff beach, shipwreck)
--   gameplay hooks: OreVein tags (Mining/Ore), Zone "dungeon" at each entrance, RespawnPoint at the mine entrance
return L.runPhase("Caves", function(folder)
  L.requireFullScale()
  local Y, MAT, Terrain = L.LAYOUT, L.MAT, workspace.Terrain
  local function carve(path, r)                       -- air balls every 6 studs + a flat rock floor slab under the path
    for i = 1, #path - 1 do
      local a, b = path[i], path[i + 1]; local len = (b - a).Magnitude
      for s = 0, len, 6 do
        local p = a + (b - a).Unit * s
        Terrain:FillBall(p + Vector3.new(0, r * 0.4, 0), r, MAT.Air)
        Terrain:FillBlock(CFrame.new(p.X, p.Y - r * 0.6 - 2, p.Z), Vector3.new(r * 1.6, 4, r * 1.6), MAT.Rock)
      end
      task.wait()
    end
  end
  local function chamber(p, r)
    Terrain:FillBall(p + Vector3.new(0, r * 0.5, 0), r, MAT.Air)
    Terrain:FillBlock(CFrame.new(p.X, p.Y - 2, p.Z), Vector3.new(r * 1.8, 4, r * 1.8), MAT.Rock)
  end
  local function tunnel(ex, ez, tx, tz, rng, legs, down)   -- from the entrance toward (tx,tz), wandering; `down` = studs of descent per 100
    local ey = L.heightAt(ex, ez) + 1
    local path = { Vector3.new(ex, ey, ez) }
    local dx, dz = L.dirTo(ex, ez, tx, tz)
    local p = path[1]
    for _ = 1, legs do
      local a = math.atan2(dz, dx) + rng:NextNumber(-0.6, 0.6)
      local len = rng:NextNumber(60, 120)
      p = p + Vector3.new(math.cos(a) * len, -down * len / 100, math.sin(a) * len)
      path[#path + 1] = p
    end
    return path
  end
  local function entrance(m, name, x, z)              -- widen the mouth so it always breaks the surface, then hooks
    local y = L.heightAt(x, z)
    Terrain:FillBall(Vector3.new(x, y + 8, z), 22, MAT.Air)
    Terrain:FillBlock(CFrame.new(x, y - 3, z), Vector3.new(40, 6, 40), MAT.Rock)
    L.zone(m, name, "dungeon", x, y, z, 120, 160)
    L.sign(m, x + 18, y, z + 18, name, math.pi / 4)
  end
  local m = L.model(folder, "Caves")
  -- 1) Stonemark Mine
  do
    local mm = L.model(m, "Stonemark Mine"); local rng = Random.new(101)
    local ex, ez = L.toWorld(Y.caves["Stonemark Mine"]); local px, pz = L.toWorld(Y.peaks.second_NW)
    local main = tunnel(ex, ez, px, pz, rng, 4, 6); carve(main, 14); chamber(main[#main], 40)
    for b = 1, 2 do
      local br = tunnel(main[2 + b].X, main[2 + b].Z, px + b * 300, pz, rng, 3, 8); br[1] = main[2 + b]; carve(br, 11); chamber(br[#br], 28)
    end
    -- ore deposits: Creator Store ore prototypes (kind "ore") on the tunnel floors when installed, else embedded metal boxes
    for i = 1, 30 do
      local seg = rng:NextInteger(2, #main)
      local p = main[seg] + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10))
      local floorY = main[seg].Y - 14 * 0.6                                                     -- carve() floor level for r=14
      local ore = L.assetList("ore") and L.placeAsset(mm, "ore", p.X, floorY, p.Z, rng, 0.8, 1.4)
      if ore then L.tag(ore, "OreVein", { GatherType = "Mining", Resource = "Ore" })
      else
        local q = p + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(4, 12), rng:NextNumber(-4, 4))
        L.tag(L.box(mm, CFrame.new(q) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), Vector3.new(4, 3, 5), MAT.CorrodedMetal, L.C.rust, { name = "OreVein" }), "OreVein", { GatherType = "Mining", Resource = "Ore" })
      end
    end
    -- cave decor (stalagmites) along the tunnels
    if L.assetList("cave") then for i = 1, 16 do local seg = rng:NextInteger(2, #main); local p = main[seg] + Vector3.new(rng:NextNumber(-11, 11), 0, rng:NextNumber(-11, 11)); L.placeAsset(mm, "cave", p.X, main[seg].Y - 8.4, p.Z, rng, 0.5, 1.1) end end
    for i = 1, #main - 1 do
      L.rod(mm, main[i] - Vector3.new(0, 0.5, 0), main[i + 1] - Vector3.new(0, 0.5, 0), 0.3, MAT.Metal, L.C.iron, { cancollide = false })
      L.rod(mm, main[i] + Vector3.new(0, -0.5, 3), main[i + 1] + Vector3.new(0, -0.5, 3), 0.3, MAT.Metal, L.C.iron, { cancollide = false })
    end
    entrance(mm, "Stonemark Mine", ex, ez)
    L.spawnPoint(mm, "Stonemark Mine", ex + 12, L.heightAt(ex + 12, ez + 12), ez + 12)
    L.progress("mine"); task.wait()
  end
  -- 2) Crystal Cave
  do
    local mm = L.model(m, "Crystal Cave"); local rng = Random.new(202)
    local ex, ez = L.toWorld(Y.caves["Crystal Cave"]); local px, pz = L.toWorld(Y.peaks.main_NE)
    local path = tunnel(ex, ez, px, pz, rng, 3, 4); carve(path, 16)
    local hall = path[#path]; chamber(hall, 70)
    for i = 1, 24 do local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(10, 60)
      L.tag(L.crystal(mm, hall + Vector3.new(math.cos(a) * r, rng:NextNumber(0, 6), math.sin(a) * r), rng:NextNumber(3, 7)), "Crystal", { GatherType = "Mining", Resource = "Crystal" }) end
    for i = 1, 8 do local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(15, 45)
      L.crystal(mm, hall + Vector3.new(math.cos(a) * r, rng:NextNumber(20, 45), math.sin(a) * r), rng:NextNumber(4, 9)) end
    L.crystal(mm, hall + Vector3.new(0, 30, 0), 14)
    if L.assetList("cave") then for i = 1, 14 do local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(20, 62); L.placeAsset(mm, "cave", hall.X + math.cos(a) * r, hall.Y - 2, hall.Z + math.sin(a) * r, rng, 0.6, 1.6) end end
    if L.assetList("ore") then for i = 1, 10 do local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(12, 55); local o = L.placeAsset(mm, "ore", hall.X + math.cos(a) * r, hall.Y - 2, hall.Z + math.sin(a) * r, rng, 0.8, 1.3); if o then L.tag(o, "OreVein", { GatherType = "Mining", Resource = "Crystal" }) end end end
    entrance(mm, "Crystal Cave", ex, ez)
    L.progress("crystal cave"); task.wait()
  end
  -- 3) Sea Cave on the west cliff beach
  do
    local mm = L.model(m, "Sea Cave"); local rng = Random.new(303)
    local hx, hz = L.toWorld(Y.caves["Sea Cave"])
    local ex, ez = L.findShore(0, 0, hx, hz, L.HALF * 1.2)            -- walk from the island centre toward the hint until the water
    ex, ez = ex - (ex / math.abs(ex)) * 30, ez                          -- step 30 studs back inland from the waterline
    local path = tunnel(ex, ez, 0, 0, rng, 3, -2); carve(path, 18)
    local hall = path[#path]; chamber(hall, 45)
    Terrain:FillBlock(CFrame.new(hall.X, hall.Y - 3, hall.Z), Vector3.new(60, 6, 60), MAT.Water)   -- tide pool
    local wreck = L.model(mm, "Shipwreck")
    L.box(wreck, CFrame.new(hall + Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0.6, 0.25), Vector3.new(50, 10, 16), MAT.WoodPlanks, L.C.wood)
    L.rod(wreck, hall + Vector3.new(0, 8, 0), hall + Vector3.new(6, 40, 0), 1, MAT.Wood, L.C.wood)
    for i = 1, 6 do L.tag(L.cyl(wreck, CFrame.new(hall + Vector3.new(rng:NextNumber(-30, 30), 2, rng:NextNumber(-30, 30))), 2, 4, MAT.Wood, L.C.plank, { name = "Barrel" }), "SearchPoint", { GatherType = "Searching" }) end
    L.marker(mm, "FishingSpot", hall.X + 20, hall.Y, hall.Z + 20, { GatherType = "Fishing" })
    entrance(mm, "Sea Cave", ex, ez)
    L.progress("sea cave")
  end
end)
