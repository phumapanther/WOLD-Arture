-- report cave entrances (world coords + ground height) and part counts so screenshots can be aimed
local out = {}
local f = L.root():FindFirstChild("Caves")
if f then
  local caves = f:FindFirstChild("Caves")
  for _, m in ipairs((caves or f):GetChildren()) do
    if m:IsA("Model") then
      local parts = L.countParts(m)
      local zone = m:FindFirstChild("Zone_" .. m.Name)
      local zp = zone and zone.Position or Vector3.new()
      out[#out + 1] = ("%s parts=%d entrance=(%.0f, %.0f, %.0f)"):format(m.Name, parts, zp.X, L.heightAt(zp.X, zp.Z), zp.Z)
    end
  end
end
local ss = game:GetService("ServerStorage"):FindFirstChild("WOLD_Assets")
if ss then for _, k in ipairs(ss:GetChildren()) do out[#out + 1] = ("prototypes %s: %d"):format(k.Name, #k:GetChildren()) end end
L.root():SetAttribute("Probe", table.concat(out, "\n"))
return L.runPhase("Probe", function() L.progress("cave probe done") end)
