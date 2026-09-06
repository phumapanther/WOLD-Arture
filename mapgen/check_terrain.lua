-- check_terrain: every place stands on solid ground; river vertices are water; spire height; isles above water
return L.runPhase("CheckTerrain", function()
  local fails = {}
  for name, p in pairs(L.LAYOUT.places) do
    local x, z = L.toWorld(p.pos); local h = L.heightAt(x, z)
    local m = L.materialAtPoint(x, h - 3, z)
    L.check(fails, m ~= Enum.Material.Water and m ~= Enum.Material.Air, ("%s ground is %s (h=%.0f)"):format(name, tostring(m), h))
  end
  local rm = L.LAYOUT.river_main
  for i = 2, #rm - 1 do
    local x, z = L.toWorld(rm[i]); local _, hs = L.riverAt(x, z)
    L.check(fails, L.materialAtPoint(x, hs - 2, z) == Enum.Material.Water, ("river vertex %d not water (hs=%.0f)"):format(i, hs))
  end
  local sx, sz = L.placePos("Spire of Eld"); local peak = L.heightAt(sx, sz)
  L.check(fails, peak > 1900 * L.VS and peak < 2300 * L.VS, ("peak %.0f"):format(peak))
  for _, isl in ipairs(L.isles) do local x, z = L.toWorld(isl.pos); L.check(fails, L.materialAtPoint(x, L.heightAt(x, z) - 3, z) ~= Enum.Material.Water, isl.name .. " isle ground") end
  L.progress(("terrain checks: %d fails; peak=%.0f"):format(#fails, peak))
  assert(#fails == 0, table.concat(fails, "\n"))
end)
