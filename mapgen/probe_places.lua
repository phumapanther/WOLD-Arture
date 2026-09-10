local r = L.root()
local out = {}
for _, n in ipairs({ "Elderwood", "Heartland", "Setup" }) do
  local f = r:FindFirstChild(n)
  if f then
    local kids = f:GetChildren()
    local sample = {}
    for i = 1, math.min(6, #kids) do
      local k = kids[i]
      sample[#sample + 1] = ("%s<%s,%d>"):format(k.Name, k.ClassName, #k:GetChildren())
    end
    out[#out + 1] = ("%s: %d children -> %s"):format(n, #kids, table.concat(sample, " "))
  end
end
-- river geometry at Cogsworth
local cx, cz = L.placePos("Cogsworth")
local rows = {}
for dz = -300, 300, 100 do
  local row = {}
  for dx = -300, 300, 100 do
    local d, hs, w = L.riverAt(cx + dx, cz + dz)
    row[#row + 1] = (d <= w / 2) and "~" or (d < w / 2 + 60 and "." or "#")
  end
  rows[#rows + 1] = table.concat(row)
end
out[#out + 1] = "Cogsworth river map (x -300..300 left-right, z -300..300 top-down):\n" .. table.concat(rows, "\n")
-- shore near Saltmere
local sx, sz = L.placePos("Saltmere")
local lx, lz = L.findShore(sx, sz, 0, 1, 2000)
out[#out + 1] = ("Saltmere shore going +z: (%d,%d) dist=%d"):format(lx, lz, math.sqrt((lx-sx)^2 + (lz-sz)^2))
local lx2, lz2 = L.findShore(sx, sz, -0.7, 0.7, 2000)
out[#out + 1] = ("Saltmere shore going -x+z: (%d,%d) dist=%d"):format(lx2, lz2, math.sqrt((lx2-sx)^2 + (lz2-sz)^2))
return table.concat(out, "\n")
