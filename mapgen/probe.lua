-- cave probe: for each cave, cameras from the saved path + air check along the first two legs at head height
local HttpService = game:GetService("HttpService")
local out = {}
local caves = L.root().Caves.Caves
for _, m in ipairs(caves:GetChildren()) do
  local js = m:GetAttribute("Path")
  if js then
    local pts = HttpService:JSONDecode(js)
    local air, total = 0, 0
    for i = 1, 2 do
      local a, b = pts[i], pts[i + 1]
      for t = 0, 1, 0.1 do
        local x, y, z = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
        total += 1; if L.materialAtPoint(x, y + 3, z) == Enum.Material.Air then air += 1 end
      end
    end
    local a, b, last, prev = pts[1], pts[2], pts[#pts], pts[#pts - 1]
    local dx, dz = b[1] - a[1], b[3] - a[3]; local len = math.sqrt(dx * dx + dz * dz); dx, dz = dx / len, dz / len
    local hx, hz = last[1] - prev[1], last[3] - prev[3]; local hl = math.sqrt(hx * hx + hz * hz); hx, hz = hx / hl, hz / hl
    out[#out + 1] = ("%s|air %d/%d|mouth %d %d %d %d %d %d|hall %d %d %d %d %d %d|ground at mouth %.0f"):format(m.Name, air, total,
      a[1] - dx * 40, a[2] + 8, a[3] - dz * 40, b[1], b[2] + 3, b[3],
      last[1] - hx * 26, last[2] + 10, last[3] - hz * 26, last[1], last[2] + 6, last[3], L.heightAt(a[1], a[3]))
  end
end
L.root():SetAttribute("Probe", table.concat(out, "\n"))
return L.runPhase("Probe", function() L.progress("cave probe") end)
