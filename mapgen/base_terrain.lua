-- base_terrain: standalone "bare island" generator (visual style + sea + island + isles), no buildings.
-- Used two ways: `node tools/run-luau.js mapgen/base_terrain.lua` on any open place, or bundled into dist/arture-base-terrain.lua
-- (tools/bundle.js) to paste into a Script in ServerScriptService of another project and press Run.
return L.runPhase("BaseTerrain", function()
  local Y = L.LAYOUT
  L.yard = nil
  for _, n in ipairs({ "Baseplate", "MCP_Test" }) do local o = workspace:FindFirstChild(n); if o then o:Destroy() end end
  pcall(function() game:GetService("ChangeHistoryService"):SetEnabled(false) end)
  workspace.StreamingEnabled = true
  L.applyStyle()
  workspace.Terrain:Clear()
  local ext = Y.sea.terrain_water_extent_studs * L.SCALE
  L.seaSlab(-ext, -ext, ext, ext)
  L.progress("sea slab")
  local t0 = os.clock()
  local R = (Y.coast_radius + Y.coast_noise + 0.02) * L.HALF
  local n = L.writeArea(0, 0, R, function(i, total) L.progress(("island %d/%d  %.0fs"):format(i, total, os.clock() - t0)) end)
  for _, isl in ipairs(L.isles) do local x, z = L.toWorld(isl.pos); n += L.writeArea(x, z, isl.r * 1.5 * L.HALF) end
  local sp = Instance.new("SpawnLocation"); sp.Name = "BaseSpawn"; sp.Size = Vector3.new(16, 1, 16)
  local bx, bz = L.placePos("Brasshaven"); sp.Position = Vector3.new(bx, L.heightAt(bx, bz) + 0.5, bz); sp.Anchored = true; sp.Neutral = true; sp.Duration = 0; sp.Parent = L.root()
  pcall(function() game:GetService("ChangeHistoryService"):SetEnabled(true) end)
  L.progress(("base terrain done: %d chunks in %.0fs"):format(n, os.clock() - t0))
end)
