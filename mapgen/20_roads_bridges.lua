-- roads + bridges (phase 4): recolor the terrain surface along layout polylines (stopping at the city wall), then the 5 bridges with stairs
--   gameplay hooks: FishingSpot markers at every bridge bank, SearchPoint crates at road junctions outside settlements
return L.runPhase("Roads", function(folder)
  L.requireFullScale()
  local Y, MAT = L.LAYOUT, L.MAT
  local wall = L.wallWorld()
  local mainSet = {}; for _, n in ipairs(Y.road_style.main_route) do mainSet[n] = true end
  local rng = Random.new(20)
  for ri, road in ipairs(Y.roads) do
    local pts = L.roadWorld(road)
    local isMain = true
    for _, e in ipairs(road) do if type(e) == "string" and not mainSet[e] then isMain = false end end
    local style = isMain and Y.road_style.main or Y.road_style.other
    local mat = MAT[style.material]
    for i = 1, #pts - 1 do
      local a = Vector3.new(pts[i][1], 0, pts[i][2]); local b = Vector3.new(pts[i + 1][1], 0, pts[i + 1][2])
      local bothIn = L.pointInPoly(wall, a.X, a.Z) and L.pointInPoly(wall, b.X, b.Z)
      L.paintRoad(a, b, style.width, mat, function(p) return (not bothIn) and L.pointInPoly(wall, p.X, p.Z) end)   -- inter-town roads stop at the wall
      L.progress(("road %d/%d seg %d"):format(ri, #Y.roads, i)); task.wait()
    end
    -- a crate or two at each intermediate waypoint (search points for the gathering system)
    for i = 2, #pts - 1 do
      local h = L.heightAt(pts[i][1], pts[i][2])
      if h > 2 and not L.pointInPoly(wall, pts[i][1], pts[i][2]) then
        local c = L.box(folder, CFrame.new(pts[i][1] + 14, h + 2, pts[i][2] + 6) * L.yaw(rng:NextNumber(0, 3)), Vector3.new(4, 4, 4), MAT.WoodPlanks, L.C.plank, { name = "Crate" })
        L.tag(c, "SearchPoint", { GatherType = "Searching" })
      end
    end
  end
  for _, b in ipairs(Y.bridges) do
    local m = L.bridge(folder, b)
    local x, z = L.toWorld(b.pos); local dir = Vector3.new(b.dir[1], 0, b.dir[2]).Unit; local side = Vector3.new(-dir.Z, 0, dir.X)
    for s = -1, 1, 2 do                                                   -- fishing spots on both banks beside the bridge
      local p = Vector3.new(x, 0, z) + dir * (b.length / 2 + 12) * s + side * 20
      L.marker(m, "FishingSpot", p.X, L.heightAt(p.X, p.Z), p.Z, { GatherType = "Fishing" })
    end
    L.progress("bridge " .. b.name); task.wait()
  end
end)
