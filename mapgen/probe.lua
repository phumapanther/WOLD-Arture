-- full-scale terrain report: heights at places/peaks, sea check, and parts/voxel stats
local out = {}
for _, name in ipairs({ "Brasshaven", "Ironcrest Keep", "Goldmeadow", "Cogsworth", "Stonemark", "Elderwood", "Saltmere", "Astravale", "Spire of Eld" }) do
  local x, z = L.placePos(name); out[#out + 1] = ("%-15s h=%5.0f  (%6.0f, %6.0f)"):format(name, L.heightAt(x, z), x, z)
end
local px, pz = L.toWorld(L.LAYOUT.peaks.second_NW); out[#out + 1] = ("second peak h=%.0f"):format(L.heightAt(px, pz))
for _, isl in ipairs(L.isles) do if not isl.rock then local x, z = L.toWorld(isl.pos); out[#out + 1] = ("%-20s h=%.0f"):format(isl.name, L.heightAt(x, z)) end end
out[#out + 1] = ("sea at (0, 12000): h=%.0f  material=%s"):format(L.heightAt(0, 12000), tostring(L.materialAtPoint(0, -2, 12000)))
out[#out + 1] = ("parts in WOLD: %d"):format(L.countParts(L.root()))
L.root():SetAttribute("Probe", table.concat(out, "\n"))
return L.runPhase("Probe", function() L.progress("report done") end)
