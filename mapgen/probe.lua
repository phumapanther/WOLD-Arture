-- mouth continuity: walk the river centreline from the forced-zero vertex to the mouth and report surface material/height; also the shelf 130 studs each side
local out = {}
local pts = L.LAYOUT.river_main
local a, b = pts[#pts - 1], pts[#pts]
local function surf(x, z)
  local reg = Region3.new(Vector3.new(x - 2, -60, z - 2), Vector3.new(x + 2, 80, z + 2)):ExpandToGrid(4)
  local mats, occ = workspace.Terrain:ReadVoxels(reg, 4)
  local top, mat
  for j = 1, #mats[1] do local m = mats[1][j][1]; if m ~= Enum.Material.Air then top = -60 + (j - 1) * 4 + occ[1][j][1] * 4; mat = m end end
  return top, mat
end
local dx, dz = b[1] - a[1], b[2] - a[2]; local len = math.sqrt(dx * dx + dz * dz); local px, pz = -dz / len, dx / len
local landBar = 0
for f = 0, 1, 0.1 do
  local u, v = a[1] + dx * f, a[2] + dz * f
  local row = {}
  for _, off in ipairs({ -130, 0, 130 }) do
    local x, z = (u + px * off / L.HALF) * L.HALF, (v + pz * off / L.HALF) * L.HALF
    local top, mat = surf(x, z)
    local name = tostring(mat):gsub("Enum.Material.", "")
    if off == 0 and mat ~= Enum.Material.Water then landBar += 1 end
    row[#row + 1] = ("%d:%s@%.0f"):format(off, name, top or -99)
  end
  out[#out + 1] = ("f=%.1f h=%.0f %s"):format(f, L.heightAt(u * L.HALF, v * L.HALF), table.concat(row, " "))
end
out[#out + 1] = ("centreline non-water samples: %d (0 = mouth open)"):format(landBar)
L.root():SetAttribute("Probe", table.concat(out, "\n"))
return L.runPhase("Probe", function() L.progress("probe done") end)
