-- test yard (phase 0): real slices of the island so every element can be judged at full scale before generating everything
--   patch A: Brasshaven bay (sea, beach, grass, river mouth, Crown Hill) + castle, bridges, road, houses, trees, pier
--   patch B: Spire of Eld peak (rock, snow)
return L.runPhase("TestYard", function(folder)
  local Y, MAT = L.LAYOUT, L.MAT
  local Terrain = workspace.Terrain
  pcall(function() game:GetService("ChangeHistoryService"):SetEnabled(false) end)
  for _, n in ipairs({ "Baseplate", "MCP_Test" }) do local o = workspace:FindFirstChild(n); if o then o:Destroy() end end
  workspace.StreamingEnabled = true
  Terrain:Clear()
  L.applyStyle()
  L.progress("style applied")

  -- sea slab only around the two patches
  local bx, bz = L.placePos("Brasshaven"); local sx, sz = L.placePos("Spire of Eld")
  L.seaSlab(-400, -6400, 6400, 6400)
  L.progress("sea slab")

  local t0 = os.clock()
  local nA = L.writeArea(bx - 400, bz - 600, 1700, function(i, n) L.progress(("bay terrain %d/%d"):format(i, n)) end, 350)
  local nB = L.writeArea(sx, sz, 700, function(i, n) L.progress(("peak terrain %d/%d"):format(i, n)) end, 200)
  L.progress(("terrain %d chunks in %.0fs"):format(nA + nB, os.clock() - t0)); task.wait()

  -- castle on Crown Hill facing Crown Plaza
  local kx, kz = L.placePos("Ironcrest Keep"); local ky = L.padY(kx, kz)
  local gx, gz = L.toWorld(Y.capital.districts.government.center)
  L.flattenDisc(kx, kz, 260, ky, MAT.Ground)
  L.castle(folder, kx, ky, kz, Vector3.new(gx - kx, 0, gz - kz), { name = "Ironcrest Keep" })
  L.progress("castle"); task.wait()

  -- bridges at the river mouth + road from market to keep
  L.bridge(folder, Y.bridges[1]); L.bridge(folder, Y.bridges[2])
  local road = L.roadWorld(Y.roads[6])
  for i = 1, #road - 1 do L.paintRoad(Vector3.new(road[i][1], 0, road[i][2]), Vector3.new(road[i + 1][1], 0, road[i + 1][2]), Y.road_style.other.width, MAT.Ground) end
  L.progress("bridges + road"); task.wait()

  -- houses near the market center, on a small flattened pad
  local mx, mz = L.toWorld(Y.capital.districts.market.center); local my = L.padY(mx, mz)
  L.flattenDisc(mx, mz, 120, my, MAT.Cobblestone)
  local hm = L.model(folder, "Houses"); local rng = Random.new(3)
  for i = 0, 5 do local a = i * math.pi / 3; L.house(hm, mx + math.cos(a) * 80, my, mz + math.sin(a) * 80, rng:NextInteger(26, 34), rng:NextInteger(22, 30), rng:NextInteger(2, 3), { yaw = math.atan2(-math.cos(a), -math.sin(a)), roof = ({ L.C.roofRed, L.C.roofBlue, L.C.roofGreen })[i % 3 + 1] }) end
  L.sign(hm, mx, my, mz, "Brasshaven", 0)
  L.progress("houses"); task.wait()

  -- pier + boat at the bay shore, palms on the beach, mixed trees near the keep
  local odx, odz = L.dirTo(0, 0, mx, mz)
  local shx, shz = L.findShore(mx, mz, odx, odz, 1500)
  L.pier(folder, shx, shz, Vector3.new(odx, 0, odz), 160, 20, 8)
  L.boat(folder, shx + odx * 120 + (-odz) * 18, 1, shz + odz * 120 + odx * 18, math.atan2(-odz, odx), 50)
  local trees = L.model(folder, "Trees")
  for i = 1, 14 do local p = Vector3.new(shx, 0, shz) + Vector3.new(-odz, 0, odx) * (i - 7) * 24 - Vector3.new(odx, 0, odz) * rng:NextNumber(10, 40)
    local h = L.heightAt(p.X, p.Z); if h > 1 and h < 7 then L.tree(trees, p.X, h - 0.5, p.Z, "palm", rng:NextNumber(0.9, 1.2)) end end
  for i = 1, 60 do local tx, tz = kx + rng:NextNumber(-700, 700), kz + rng:NextNumber(-700, 700)
    local d = math.sqrt((tx - kx) ^ 2 + (tz - kz) ^ 2); local rd, _, rw = L.riverAt(tx, tz); local h = L.heightAt(tx, tz)
    if d > 330 and rd > rw / 2 + 10 and h > 6 then L.tree(trees, tx, h - 0.5, tz, rng:NextNumber() < 0.5 and "pine" or "oak", rng:NextNumber(0.9, 1.4)) end end
  L.progress("pier + trees"); task.wait()

  -- a few crystals at the peak so the magic look can be judged
  local py = L.heightAt(sx, sz)
  for i = 0, 5 do local a = i * math.pi / 3; L.crystal(folder, Vector3.new(sx + math.cos(a) * 30, py + 20 + math.sin(a * 2) * 4, sz + math.sin(a) * 30), 5) end
  L.crystal(folder, Vector3.new(sx, py + 34, sz), 12)
  folder:SetAttribute("Shore", Vector3.new(shx, 0, shz)); folder:SetAttribute("KeepY", ky); folder:SetAttribute("MarketY", my); folder:SetAttribute("PeakY", py)
  L.progress(("test yard done: keepY=%.0f marketY=%.0f peakY=%.0f shore=(%.0f,%.0f)"):format(ky, my, py, shx, shz))
end)
