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
  local function chamber(p, r)                        -- hall stays under at least 8 studs of rock: shrink the radius if the cover is thin
    local cover = L.heightAt(p.X, p.Z) - p.Y
    r = math.max(14, math.min(r, (cover - 8) / 1.5))
    Terrain:FillBall(p + Vector3.new(0, r * 0.5, 0), r, MAT.Air)
    Terrain:FillBlock(CFrame.new(p.X, p.Y - 2, p.Z), Vector3.new(r * 1.8, 4, r * 1.8), MAT.Rock)
    return r
  end
  local HttpService = game:GetService("HttpService")
  local function tunnel(ex, ez, tx, tz, rng, legs, down, r)   -- from the entrance toward (tx,tz): first leg straight and level (a real mouth), then wandering; `down` = studs of descent per 100
    local ey = L.heightAt(ex, ez) + 1
    local path = { Vector3.new(ex, ey, ez) }
    local dx, dz = L.dirTo(ex, ez, tx, tz)
    local p = path[1] + Vector3.new(dx * 50, 0, dz * 50)
    path[#path + 1] = p
    for _ = 1, legs do
      local a = math.atan2(dz, dx) + rng:NextNumber(-0.6, 0.6)
      local len = rng:NextNumber(60, 120)
      p = p + Vector3.new(math.cos(a) * len, -down * len / 100, math.sin(a) * len)
      p = Vector3.new(p.X, math.min(p.Y, L.heightAt(p.X, p.Z) - (r or 14) - 8), p.Z)   -- never closer than r+8 to the surface: tunnels stay underground
      path[#path + 1] = p
    end
    return path
  end
  local function savePath(m, path)                    -- so probes/cameras/gameplay can find the tunnel: Attribute Path = JSON [[x,y,z],...]
    local t = {}; for i, p in ipairs(path) do t[i] = { math.floor(p.X), math.floor(p.Y), math.floor(p.Z) } end
    m:SetAttribute("Path", HttpService:JSONEncode(t))
  end
  local function entrance(m, name, x, z, dx, dz)      -- open mouth: air balls stepping inward and downward along the first leg, lit by two torches, zone + sign
    local y = L.heightAt(x, z)
    for s = -10, 50, 10 do Terrain:FillBall(Vector3.new(x + dx * s, y + 10 - math.max(0, s) * 0.12, z + dz * s), 16, MAT.Air) end
    Terrain:FillBlock(CFrame.new(x + dx * 20, y - 3, z + dz * 20) * L.yaw(math.atan2(-dz, dx)), Vector3.new(70, 6, 36), MAT.Rock)   -- level threshold floor
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
  -- 1) Stonemark Mine
  do
    local mm = L.model(m, "Stonemark Mine"); local rng = Random.new(101)
    local ex, ez = L.toWorld(Y.caves["Stonemark Mine"]); local px, pz = L.toWorld(Y.peaks.second_NW)
    L.writeArea(ex, ez, 620)                                              -- repair: rewrite the natural terrain here so re-runs carve from a clean hill
    local main = tunnel(ex, ez, px, pz, rng, 4, 14, 14); carve(main, 14); chamber(main[#main], 40)
    for b = 1, 2 do
      local br = tunnel(main[2 + b].X, main[2 + b].Z, px + b * 300, pz, rng, 3, 8, 11); br[1] = main[2 + b]; carve(br, 11); chamber(br[#br], 28)
    end
    -- ore deposits: Creator Store ore prototypes (kind "ore") on the tunnel floors when installed, else embedded metal boxes
    local function sideSpot(seg, dist)                                                          -- a point beside the tunnel wall (never in the walkway)
      local a, b = main[seg], main[math.min(seg + 1, #main)]
      local d = (b - a); if d.Magnitude < 1 then d = Vector3.new(1, 0, 0) end; d = Vector3.new(d.X, 0, d.Z).Unit
      local side = Vector3.new(-d.Z, 0, d.X) * dist * (rng:NextNumber() < 0.5 and -1 or 1)
      return a + d * rng:NextNumber(0, (b - a).Magnitude) + side
    end
    for i = 1, 30 do
      local seg = rng:NextInteger(3, #main - 1)                                                  -- from the second bend inward: the mouth stays clear
      local p = sideSpot(seg, rng:NextNumber(7, 10))
      local floorY = main[seg].Y - 14 * 0.6                                                     -- carve() floor level for r=14
      local ore = L.assetList("ore") and L.placeAsset(mm, "ore", p.X, floorY, p.Z, rng, 0.45, 0.9)
      if ore then L.tag(ore, "OreVein", { GatherType = "Mining", Resource = "Ore" })
      else
        local q = p + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(4, 12), rng:NextNumber(-4, 4))
        L.tag(L.box(mm, CFrame.new(q) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), Vector3.new(4, 3, 5), MAT.CorrodedMetal, L.C.rust, { name = "OreVein" }), "OreVein", { GatherType = "Mining", Resource = "Ore" })
      end
    end
    -- cave decor (stalagmites) along the tunnels
    if L.assetList("cave") then for i = 1, 12 do local seg = rng:NextInteger(3, #main - 1); local p = sideSpot(seg, rng:NextNumber(8, 11)); L.placeAsset(mm, "cave", p.X, main[seg].Y - 8.4, p.Z, rng, 0.4, 0.8) end end
    for i = 1, #main - 1 do
      L.rod(mm, main[i] - Vector3.new(0, 0.5, 0), main[i + 1] - Vector3.new(0, 0.5, 0), 0.3, MAT.Metal, L.C.iron, { cancollide = false })
      L.rod(mm, main[i] + Vector3.new(0, -0.5, 3), main[i + 1] + Vector3.new(0, -0.5, 3), 0.3, MAT.Metal, L.C.iron, { cancollide = false })
    end
    local ddx, ddz = L.dirTo(ex, ez, px, pz)
    entrance(mm, "Stonemark Mine", ex, ez, ddx, ddz); savePath(mm, main)
    L.spawnPoint(mm, "Stonemark Mine", ex - ddx * 30, L.heightAt(ex - ddx * 30, ez - ddz * 30), ez - ddz * 30)
    L.progress("mine"); task.wait()
  end
  -- 2) Crystal Cave
  do
    local mm = L.model(m, "Crystal Cave"); local rng = Random.new(202)
    local ex, ez = L.toWorld(Y.caves["Crystal Cave"]); local px, pz = L.toWorld(Y.peaks.main_NE)
    L.writeArea(ex, ez, 620)
    local path = tunnel(ex, ez, px, pz, rng, 3, 22, 16); carve(path, 16)
    local hall = path[#path]; local hallR = chamber(hall, 70)
    for i = 1, 12 do local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(10, hallR * 0.85)
      L.tag(L.crystal(mm, hall + Vector3.new(math.cos(a) * r, rng:NextNumber(0, 3), math.sin(a) * r), rng:NextNumber(2.5, 5)), "Crystal", { GatherType = "Mining", Resource = "Crystal" }) end
    for i = 1, 4 do local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(15, 40)
      L.crystal(mm, hall + Vector3.new(math.cos(a) * r, rng:NextNumber(22, 40), math.sin(a) * r), rng:NextNumber(3, 6)) end
    L.crystal(mm, hall + Vector3.new(0, 30, 0), 10)
    if L.assetList("cave") then for i = 1, 8 do local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(hallR * 0.4, hallR * 0.9); L.placeAsset(mm, "cave", hall.X + math.cos(a) * r, hall.Y - 2, hall.Z + math.sin(a) * r, rng, 0.5, 1.0) end end
    if L.assetList("ore") then for i = 1, 8 do local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(8, hallR * 0.8); local o = L.placeAsset(mm, "ore", hall.X + math.cos(a) * r, hall.Y - 2, hall.Z + math.sin(a) * r, rng, 0.8, 1.2); if o then L.tag(o, "OreVein", { GatherType = "Mining", Resource = "Crystal" }) end end end
    local ddx, ddz = L.dirTo(ex, ez, px, pz)
    entrance(mm, "Crystal Cave", ex, ez, ddx, ddz); savePath(mm, path)
    L.progress("crystal cave"); task.wait()
  end
  -- 3) Sea Cave on the west cliff beach
  do
    local mm = L.model(m, "Sea Cave"); local rng = Random.new(303)
    local hx, hz = L.toWorld(Y.caves["Sea Cave"])
    L.writeArea(hx, hz, 620)
    local ex, ez = L.findShore(0, 0, hx, hz, L.HALF * 1.2)            -- last land point walking from the island centre toward the west coast (waterline)
    local path = tunnel(ex, ez, 0, 0, rng, 3, 12, 14); carve(path, 14)  -- mouth at the waterline, tunnel dives under the cliff plateau
    local hall = path[#path]; chamber(hall, 30)
    Terrain:FillBlock(CFrame.new(hall.X, hall.Y - 2, hall.Z), Vector3.new(36, 4, 36), MAT.Water)   -- tide pool
    local wreck = L.model(mm, "Shipwreck")
    L.box(wreck, CFrame.new(hall + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0.6, 0.2), Vector3.new(34, 7, 11), MAT.WoodPlanks, L.C.wood)
    L.rod(wreck, hall + Vector3.new(0, 6, 0), hall + Vector3.new(4, 24, 0), 0.8, MAT.Wood, L.C.wood)
    for i = 1, 6 do L.tag(L.cyl(wreck, CFrame.new(hall + Vector3.new(rng:NextNumber(-20, 20), 2, rng:NextNumber(-20, 20))), 2, 4, MAT.Wood, L.C.plank, { name = "Barrel" }), "SearchPoint", { GatherType = "Searching" }) end
    L.marker(mm, "FishingSpot", hall.X + 20, hall.Y, hall.Z + 20, { GatherType = "Fishing" })
    local ddx, ddz = L.dirTo(ex, ez, 0, 0)
    entrance(mm, "Sea Cave", ex, ez, ddx, ddz); savePath(mm, path)
    L.progress("sea cave")
  end
end)
