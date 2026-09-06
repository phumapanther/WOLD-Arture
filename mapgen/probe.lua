-- read cave paths and compute camera positions: mouth (looking in) and hall (looking around)
local HttpService = game:GetService("HttpService")
local out = {}
local caves = L.root().Caves.Caves
for _, m in ipairs(caves:GetChildren()) do
  local js = m:GetAttribute("Path")
  if js then
    local pts = HttpService:JSONDecode(js)
    local a, b, last = pts[1], pts[2], pts[#pts]
    local dx, dz = b[1] - a[1], b[3] - a[3]; local len = math.sqrt(dx * dx + dz * dz); dx, dz = dx / len, dz / len
    -- mouth camera: 30 studs outside, 6 up, looking at the first bend; hall camera: 20 studs before the last point looking at it
    local prev = pts[#pts - 1]
    local hx, hz = last[1] - prev[1], last[3] - prev[3]; local hl = math.sqrt(hx * hx + hz * hz); hx, hz = hx / hl, hz / hl
    out[#out + 1] = ("%s|mouth %d %d %d %d %d %d|hall %d %d %d %d %d %d|pts=%d"):format(m.Name,
      a[1] - dx * 30, a[2] + 6, a[3] - dz * 30, b[1], b[2] + 2, b[3],
      last[1] - hx * 30, last[2] + 12, last[3] - hz * 30, last[1], last[2] + 8, last[3], #pts)
  end
end
L.root():SetAttribute("Probe", table.concat(out, "\n"))
return L.runPhase("Probe", function() L.progress("cave cams") end)
