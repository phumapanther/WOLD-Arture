-- terrain (phase 2): clear, sea slab with sand rim, then the island and every isle chunk by chunk (rivers + pads are part of the height function)
return L.runPhase("Terrain", function()
  local Y = L.LAYOUT
  L.yard = nil
  workspace.Terrain:Clear()
  local ext = Y.sea.terrain_water_extent_studs * L.SCALE
  L.seaSlab(-ext, -ext, ext, ext)
  L.progress("sea slab")
  local t0 = os.clock()
  local R = (Y.coast_radius + Y.coast_noise + 0.02) * L.HALF
  local n = L.writeArea(0, 0, R, function(i, total) L.progress(("island %d/%d  %.0fs"):format(i, total, os.clock() - t0)) end)
  for _, isl in ipairs(L.isles) do
    local x, z = L.toWorld(isl.pos)
    n += L.writeArea(x, z, isl.r * 1.5 * L.HALF)
  end
  L.progress(("terrain %d chunks in %.0fs (SCALE %.3f)"):format(n, os.clock() - t0, L.SCALE))
end)
