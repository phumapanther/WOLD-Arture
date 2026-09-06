-- test yard (phase 0): a round test island cut from the real Brasshaven bay so every element can be judged at full scale
--   sea, beach, grass, river mouth, Crown Hill pad + castle, Crown Bridge + rail bridge, road, houses, pier, boat, trees, spawn
return L.runPhase("TestYard", function(folder)
  local Y, MAT = L.LAYOUT, L.MAT
  local Terrain = workspace.Terrain
  pcall(function() game:GetService("ChangeHistoryService"):SetEnabled(false) end)
  for _, n in ipairs({ "Baseplate", "MCP_Test", "SpawnLocation" }) do local o = workspace:FindFirstChild(n); if o then o:Destroy() end end
  workspace.StreamingEnabled = true
  Terrain:Clear()
  L.applyStyle()
  L.progress("style applied")

  local bx, bz = L.placePos("Brasshaven")
  local cx, cz, rad = bx - 400, bz - 600, 1800
  L.yard = { cx = cx, cz = cz, rad = rad }                 -- round island: terrain fades into the sea 400 studs before the edge
  L.seaSlab(cx - 3200, cz - 3200, cx + 3200, cz + 3200)
  L.progress("sea slab")
  local t0 = os.clock()
  local n = L.writeArea(cx, cz, rad, function(i, total) L.progress(("terrain %d/%d"):format(i, total)) end, 300)
  L.progress(("terrain %d chunks in %.0fs"):format(n, os.clock() - t0)); task.wait()

  -- castle on the Crown Hill pad (pad is part of the height function now: walkable skirt, no cliffs)
  local kx, kz = L.placePos("Ironcrest Keep"); local ky = L.padY(kx, kz)
  local gx, gz = L.toWorld(Y.capital.districts.government.center)
  L.castle(folder, kx, ky, kz, Vector3.new(gx - kx, 0, gz - kz), { name = "Ironcrest Keep" })
  L.progress("castle"); task.wait()

  -- bridges at the river mouth + road from market to keep
  L.bridge(folder, Y.bridges[1]); L.bridge(folder, Y.bridges[2])
  local road = L.roadWorld(Y.roads[6])
  for i = 1, #road - 1 do L.paintRoad(Vector3.new(road[i][1], 0, road[i][2]), Vector3.new(road[i + 1][1], 0, road[i + 1][2]), Y.road_style.other.width, MAT.Ground) end
  L.progress("bridges + road"); task.wait()

  -- houses on the market pad + spawn
  local mx, mz = L.toWorld(Y.capital.districts.market.center); local my = L.padY(mx, mz)
  Terrain:FillBlock(CFrame.new(mx, my - 1.5, mz), Vector3.new(260, 3, 260), MAT.Cobblestone)
  local hm = L.model(folder, "Houses"); local rng = Random.new(3)
  for i = 0, 5 do local a = i * math.pi / 3; L.house(hm, mx + math.cos(a) * 85, my, mz + math.sin(a) * 85, rng:NextInteger(26, 34), rng:NextInteger(22, 30), rng:NextInteger(2, 3), { yaw = math.atan2(-math.cos(a), -math.sin(a)), roof = ({ L.C.roofRed, L.C.roofBlue, L.C.roofGreen })[i % 3 + 1] }) end
  L.sign(hm, mx, my, mz + 30, "Brasshaven", 0)
  local sp = Instance.new("SpawnLocation"); sp.Size = Vector3.new(16, 1, 16); sp.Position = Vector3.new(mx, my + 0.5, mz); sp.Anchored = true
  sp.Material = MAT.Cobblestone; sp.Color = L.C.stone; sp.Neutral = true; sp.Duration = 0; sp.Name = "SpawnLocation"; sp.Parent = folder
  L.progress("houses + spawn"); task.wait()

  -- pier + boat at the bay shore, palms on the beach, mixed trees on the hill and near the houses
  local odx, odz = L.dirTo(0, 0, mx, mz)
  local shx, shz = L.findShore(mx, mz, odx, odz, 1500)
  L.pier(folder, shx, shz, Vector3.new(odx, 0, odz), 160, 20, 8)
  L.boat(folder, shx + odx * 120 + (-odz) * 18, 1, shz + odz * 120 + odx * 18, math.atan2(-odz, odx), 50)
  local trees = L.model(folder, "Trees")
  for i = 1, 16 do local p = Vector3.new(shx, 0, shz) + Vector3.new(-odz, 0, odx) * (i - 8) * 22 - Vector3.new(odx, 0, odz) * rng:NextNumber(12, 45)
    local h = L.heightAt(p.X, p.Z); if h > 1 and h < 7 then L.tree(trees, p.X, h, p.Z, "palm", rng:NextNumber(0.9, 1.2), i) end end
  local planted = 0
  for i = 1, 400 do
    local tx, tz = cx + rng:NextNumber(-1300, 1300), cz + rng:NextNumber(-1300, 1300)
    local dk = math.sqrt((tx - kx) ^ 2 + (tz - kz) ^ 2); local dm = math.sqrt((tx - mx) ^ 2 + (tz - mz) ^ 2)
    local rd, _, rw = L.riverAt(tx, tz); local h = L.heightAt(tx, tz)
    if dk > 330 and dm > 200 and rd > rw / 2 + 12 and h > 6 and L.polyDist(road, 1, tx, tz) > 20 then
      L.tree(trees, tx, h, tz, (rng:NextNumber() < 0.45) and "pine" or "oak", rng:NextNumber(0.9, 1.4), i); planted += 1
      if planted % 40 == 0 then task.wait() end
    end
  end
  -- a small grove right next to spawn so tree shapes can be judged up close
  for i = 1, 6 do local a = i * 1.05; L.tree(trees, mx + math.cos(a) * 150, L.heightAt(mx + math.cos(a) * 150, mz + math.sin(a) * 150), mz + math.sin(a) * 150, (i % 2 == 0) and "pine" or "oak", 1.2, 100 + i) end
  folder:SetAttribute("Shore", Vector3.new(shx, 0, shz)); folder:SetAttribute("KeepY", ky); folder:SetAttribute("MarketY", my); folder:SetAttribute("Trees", planted + 22)
  L.progress(("test yard done: keepY=%.0f marketY=%.0f trees=%d shore=(%.0f,%.0f)"):format(ky, my, planted + 22, shx, shz))
end)
