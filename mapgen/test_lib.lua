-- self-test for lib.lua: land/sea/peak/river sanity at known layout points
return L.runPhase("LibTest", function()
  local fails = {}
  local bx, bz = L.placePos("Brasshaven")
  L.check(fails, L.isLand(bx, bz), "Brasshaven must be land")
  L.check(fails, L.heightAt(bx, bz) > 4 * L.VS, "Brasshaven height > 4")
  L.check(fails, not L.isLand(L.HALF * 1.6, 0), "far east must be sea")
  L.check(fails, L.heightAt(L.HALF * 1.6, 0) < 0, "far east height < 0")
  local sx, sz = L.placePos("Spire of Eld")
  local peak = L.heightAt(sx, sz) / L.VS
  L.check(fails, peak > 1800 and peak < 2300, ("Spire height %.0f expected 1800..2300"):format(peak))
  for name, _ in pairs(L.LAYOUT.places) do local x, z = L.placePos(name); L.check(fails, L.isLand(x, z), name .. " must be land") end
  local rx, rz = L.toWorld(L.LAYOUT.river_main[5])
  local d, hs, w = L.riverAt(rx, rz)
  L.check(fails, d < 1, ("river vertex dist %.1f should be ~0"):format(d))
  L.check(fails, L.heightAt(rx, rz) < hs, "river bed below surface")
  L.check(fails, L.heightAt(rx + w, rz) > hs, "river bank above surface")
  for _, isl in ipairs(L.isles) do local x, z = L.toWorld(isl.pos); L.check(fails, L.heightAt(x, z) > 5 * L.VS, isl.name .. " isle must be above water") end
  print(("[WOLD] test_lib: Spire=%.0f Brasshaven=%.0f river(d=%.1f hs=%.1f w=%.0f)"):format(peak, L.heightAt(bx, bz), d, hs, w))
  L.progress(("test_lib: Spire=%.0f Brasshaven=%.0f riverSurface=%.1f fails=%d"):format(peak, L.heightAt(bx, bz), hs, #fails))
  assert(#fails == 0, "test_lib failed:\n" .. table.concat(fails, "\n"))
end)
