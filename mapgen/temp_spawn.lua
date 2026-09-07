-- temp_spawn: stopgap SpawnLocation for channel servers to land players on, until Brasshaven (phase 5) provides
-- the real one. 00_setup.lua deletes the template's default SpawnLocation and nothing recreates it until phase 5,
-- so between now and then every channel server has zero SpawnLocations and SpawnSelector falls back to a
-- hardcoded, unverified Vector3.new(0, 50, 0). Placed at Brasshaven's future site so it's roughly where players
-- should end up anyway. Phase 5 (Brasshaven) must destroy WOLD.TempSpawn once it adds the real spawn.
return L.runPhase("TempSpawn", function(folder)
  local x, z = L.placePos("Brasshaven")
  local y = L.heightAt(x, z)

  local platform = Instance.new("Part")
  platform.Name = "Platform"
  platform.Anchored = true
  platform.Size = Vector3.new(24, 2, 24)
  platform.Position = Vector3.new(x, y + 1, z)
  platform.Material = Enum.Material.Cobblestone
  platform.Color = Color3.fromRGB(140, 138, 132)
  platform.Parent = folder

  local spawn = Instance.new("SpawnLocation")
  spawn.Name = "SpawnLocation"
  spawn.Anchored = true
  spawn.Size = Vector3.new(6, 1, 6)
  spawn.Position = Vector3.new(x, y + 2.5, z)
  spawn.Material = Enum.Material.Cobblestone
  spawn.Neutral = true
  spawn.Duration = 0
  spawn.Parent = folder

  print(("[WOLD] TempSpawn placed at %.0f, %.0f, %.0f"):format(x, y, z))
end)
