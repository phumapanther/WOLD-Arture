local out = {}
local kx, kz = L.placePos("Ironcrest Keep")
local gx, gz = L.toWorld(L.LAYOUT.capital.districts.government.center)
local dx, dz = L.dirTo(kx, kz, gx, gz)
local function surfaceY(x, z)
  local reg = Region3.new(Vector3.new(x - 2, 0, z - 2), Vector3.new(x + 2, 400, z + 2)):ExpandToGrid(4)
  local mats, occ = workspace.Terrain:ReadVoxels(reg, 4)
  local top
  for j = 1, #mats[1] do local m = mats[1][j][1]; if m ~= Enum.Material.Air and m ~= Enum.Material.Water then top = (j - 1) * 4 + occ[1][j][1] * 4 end end
  return top
end
out[#out + 1] = ("keep padY=%d heightAt=%.1f surface=%s"):format(L.padY(kx, kz), L.heightAt(kx, kz), tostring(surfaceY(kx, kz)))
for _, dir in ipairs({ { dx, dz, "toGate" }, { -dx, -dz, "awayGate" }, { -dz, dx, "side" } }) do
  local row = {}
  for r = 0, 480, 40 do local x, z = kx + dir[1] * r, kz + dir[2] * r; row[#row + 1] = ("%d:%.0f/%s"):format(r, L.heightAt(x, z), tostring(surfaceY(x, z))) end
  out[#out + 1] = dir[3] .. " " .. table.concat(row, " ")
end
L.root():SetAttribute("Probe", table.concat(out, "\n"))
return L.runPhase("Probe", function() L.progress("probe done") end)
