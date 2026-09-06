-- measure and line up AssetTest2 packs west/north of spawn; strip any scripts; anchor everything
local out = {}
local f = workspace.WOLD.AssetTest2
local mx, mz = L.toWorld(L.LAYOUT.capital.districts.market.center); local my = L.padY(mx, mz)
local order = { "Pine_A", "Spruce_B", "Spruce_C", "Palm_A", "Palm_B", "Palm_C", "TreeBushPack", "FoliagePack", "RockPack_A", "MossyRocks" }
for i, name in ipairs(order) do
  local m = f:FindFirstChild(name)
  if m then
    local parts, scripts = 0, 0
    for _, d in ipairs(m:GetDescendants()) do
      if d:IsA("BasePart") then parts += 1; d.Anchored = true end
      if d:IsA("LuaSourceContainer") then scripts += 1; d:Destroy() end
    end
    if m:IsA("Folder") then local mm = Instance.new("Model"); mm.Name = "Pack"; for _, c in ipairs(m:GetChildren()) do c.Parent = mm end; mm.Parent = m; m = mm end
    local cf, size = m:GetBoundingBox()
    local tx, tz = mx - 420 + ((i - 1) % 5) * 130, mz - 300 - math.floor((i - 1) / 5) * 160
    local delta = Vector3.new(tx, my + size.Y / 2, tz) - cf.Position
    for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.CFrame = d.CFrame + delta end end
    local kids = {}; for _, c in ipairs(m:GetChildren()) do kids[#kids + 1] = c.ClassName end
    out[#out + 1] = ("%s parts=%d scripts_removed=%d size=%.0fx%.0fx%.0f children=%d at (%d,%d)"):format(name, parts, scripts, size.X, size.Y, size.Z, #m:GetChildren(), tx, tz)
  end
end
L.root():SetAttribute("Probe", table.concat(out, "\n"))
return L.runPhase("Probe", function() L.progress("assets placed") end)
