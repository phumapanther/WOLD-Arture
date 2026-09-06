-- roof check: materials in the column above each hall centre; mouth camera material; natural vs actual surface
local HttpService = game:GetService("HttpService")
local out = {}
local caves = L.root().Caves.Caves
local function col(x, y0, z, n)  -- materials from y0 upward in 4-stud steps, compact string
  local s = {}
  for i = 0, n - 1 do local m = L.materialAtPoint(x, y0 + i * 4, z); s[#s + 1] = ({ [Enum.Material.Air] = ".", [Enum.Material.Water] = "~", [Enum.Material.Snow] = "S", [Enum.Material.Rock] = "R", [Enum.Material.Grass] = "G", [Enum.Material.Basalt] = "B", [Enum.Material.Sand] = "s" })[m] or "?" end
  return table.concat(s)
end
for _, m in ipairs(caves:GetChildren()) do
  local js = m:GetAttribute("Path")
  if js then
    local pts = HttpService:JSONDecode(js); local a, b, last = pts[1], pts[2], pts[#pts]
    local dx, dz = b[1] - a[1], b[3] - a[3]; local len = math.sqrt(dx * dx + dz * dz); dx, dz = dx / len, dz / len
    local camx, camz = a[1] - dx * 40, a[3] - dz * 40
    out[#out + 1] = ("%s: hall y=%d natural above=%.0f column(hall.y-8 .. +120)=%s"):format(m.Name, last[2], L.heightAt(last[1], last[3]), col(last[1], last[2] - 8, last[3], 32))
    out[#out + 1] = ("   mouth y=%d natural=%.0f | outside cam (%d,%d,%d) natural=%.0f material=%s | column at mouth=%s"):format(a[2], L.heightAt(a[1], a[3]), camx, a[2] + 8, camz, L.heightAt(camx, camz), tostring(L.materialAtPoint(camx, a[2] + 8, camz)):gsub("Enum.Material.", ""), col(a[1], a[2] - 8, a[3], 12))
  end
end
L.root():SetAttribute("Probe", table.concat(out, "\n"))
return L.runPhase("Probe", function() L.progress("roof probe") end)
