local HttpService = game:GetService("HttpService")
local out = {}
local caves = L.root().Caves.Caves
for _, m in ipairs(caves:GetChildren()) do
  local js = m:GetAttribute("Path")
  if js then
    local pts = HttpService:JSONDecode(js)
    local a, b, last, prev = pts[1], pts[2], pts[#pts], pts[#pts - 1]
    local dx, dz = b[1] - a[1], b[3] - a[3]; local len = math.sqrt(dx * dx + dz * dz); dx, dz = dx / len, dz / len
    local hx, hz = last[1] - prev[1], last[3] - prev[3]; local hl = math.sqrt(hx * hx + hz * hz); hx, hz = hx / hl, hz / hl
    out[#out + 1] = ("%s|maze=%s|mouth %d %d %d %d %d %d|hall %d %d %d %d %d %d|hallTop %d %d %d %d %d %d"):format(
      m.Name, tostring(m:GetAttribute("MazeSegments")),
      a[1] - dx * 40, a[2] + 8, a[3] - dz * 40, b[1], b[2] + 3, b[3],
      last[1] - hx * 30, last[2] + 14, last[3] - hz * 30, last[1], last[2] + 10, last[3],
      last[1], last[2] + 80, last[3], last[1], last[2] + 5, last[3])
  end
end
L.root():SetAttribute("Probe", table.concat(out, "\n"))
return L.runPhase("Probe", function() L.progress("cave cams v3") end)
