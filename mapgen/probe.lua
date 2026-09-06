-- probe estuary: along the last river segment, sample heights across the channel
local out = {}
local pts = L.LAYOUT.river_main
local a = pts[#pts - 1]; local b = pts[#pts]
for _, frac in ipairs({ 0.6, 0.75, 0.9, 1.0 }) do
  local u, v = a[1] + (b[1] - a[1]) * frac, a[2] + (b[2] - a[2]) * frac
  local dx, dz = (b[1] - a[1]), (b[2] - a[2]); local len = math.sqrt(dx * dx + dz * dz); local px, pz = -dz / len, dx / len   -- perpendicular (normalized units)
  local row = {}
  for _, off in ipairs({ -240, -160, -100, -60, 0, 60, 100, 160, 240 }) do
    local uu, vv = u + px * off / L.HALF, v + pz * off / L.HALF
    local h, fm, cl, land, d, hs, w = L.sample(uu, vv)
    local nat = L.base(uu, vv)
    local _, _, _, est = L.river(uu, vv)
    row[#row + 1] = ("%d:h%.0f/n%.0f/l%.2f/e%.2f/w%.0f"):format(off, h, nat, land, est or -1, w)
  end
  out[#out + 1] = ("frac %.2f hs=%.1f  %s"):format(frac, select(6, L.sample(u, v)), table.concat(row, "  "))
end
L.root():SetAttribute("Probe", table.concat(out, "\n"))
return L.runPhase("Probe", function() L.progress("probe done") end)
