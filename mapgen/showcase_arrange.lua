-- arrange whatever was inserted into WOLD.Showcase: strip scripts, anchor, fit to 60-stud cells near the temp spawn, label, report
return L.runPhase("ShowcaseArrange", function()
  local f = L.root():FindFirstChild("Showcase"); assert(f, "no Showcase folder")
  local bx, bz = L.placePos("Brasshaven"); local y = L.padY(bx, bz)
  local report, i = {}, 0
  for _, m in ipairs(f:GetChildren()) do
    if m:IsA("Model") or m:IsA("Folder") then
      i += 1
      local scripts, parts = 0, 0
      for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("LuaSourceContainer") then scripts += 1; d:Destroy() elseif d:IsA("Camera") then d:Destroy()
        elseif d:IsA("BasePart") then parts += 1; d.Anchored = true end
      end
      if m:IsA("Folder") then local mm = Instance.new("Model"); mm.Name = m.Name; for _, c in ipairs(m:GetChildren()) do c.Parent = mm end; mm.Parent = f; m:Destroy(); m = mm end
      if parts > 0 then
        local cf, size = m:GetBoundingBox()
        local col, row = (i - 1) % 6, math.floor((i - 1) / 6)
        local tx, tz = bx - 300 + col * 110, bz - 180 - row * 140
        local scale = math.min(1, 60 / math.max(size.X, size.Z, 1))
        m.WorldPivot = CFrame.new(cf.Position)
        if scale < 1 then m:ScaleTo(scale) end
        m:PivotTo(CFrame.new(tx, y + size.Y * scale / 2, tz))
        L.sign(f, tx, y, tz + 40, m.Name, 0)
        report[#report + 1] = ("%s parts=%d scripts_removed=%d size=%.0fx%.0fx%.0f scale=%.2f"):format(m.Name, parts, scripts, size.X, size.Y, size.Z, scale)
      else report[#report + 1] = m.Name .. " no parts" end
    end
  end
  L.root():SetAttribute("Showcase", table.concat(report, "\n"))
  L.progress("showcase arranged")
end)
