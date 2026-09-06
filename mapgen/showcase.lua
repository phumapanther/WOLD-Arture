-- showcase: load candidate Creator Store models (ores / cave decor), strip scripts, line them up near the temp spawn with labels
return L.runPhase("Showcase", function(folder)
  local IS = game:GetService("InsertService")
  local list = {
    { "119276025950987", "LowPolyOrePack" }, { "70453542706041", "OresIngotsPack" }, { "8141387917", "OrePackGems" }, { "13804973252", "TripleOrePack" },
    { "12816466572", "IronOre_A" }, { "5380514482", "IronOre_B" }, { "8596606684", "IronOre_C" }, { "97290005011332", "IronOreVein" },
    { "97188749566404", "CaveRockPackVEGA" }, { "107885898472710", "StalagmiteMoss" }, { "104162414374468", "CaveCrystalMine" }, { "123104212512297", "CrystalFormation" },
  }
  local bx, bz = L.placePos("Brasshaven"); local y = L.padY(bx, bz)
  local report = {}
  for i, a in ipairs(list) do
    local ok, loaded = pcall(function() return IS:LoadAsset(tonumber(a[1])) end)
    if not ok then report[#report + 1] = a[2] .. " FAILED " .. tostring(loaded)
    else
      local scripts = 0
      for _, d in ipairs(loaded:GetDescendants()) do if d:IsA("LuaSourceContainer") then scripts += 1; d:Destroy() elseif d:IsA("Camera") then d:Destroy() end end
      local m = Instance.new("Model"); m.Name = a[2]
      for _, c in ipairs(loaded:GetChildren()) do c.Parent = m end
      loaded:Destroy()
      local parts = 0; for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then parts += 1; d.Anchored = true end end
      if parts > 0 then
        local cf, size = m:GetBoundingBox()
        local col, row = (i - 1) % 6, math.floor((i - 1) / 6)
        local tx, tz = bx - 300 + col * 110, bz - 180 - row * 140
        local scale = math.min(1, 60 / math.max(size.X, size.Z, 1))          -- big packs shrink to fit a 60-stud cell
        m.WorldPivot = CFrame.new(cf.Position)
        if scale < 1 then m:ScaleTo(scale) end
        m:PivotTo(CFrame.new(tx, y + size.Y * scale / 2, tz))
        m.Parent = folder
        L.sign(folder, tx, y, tz + 40, a[2], 0)
        report[#report + 1] = ("%s parts=%d scripts=%d size=%.0fx%.0fx%.0f scale=%.2f"):format(a[2], parts, scripts, size.X, size.Y, size.Z, scale)
      else m:Destroy(); report[#report + 1] = a[2] .. " no parts" end
    end
    task.wait()
  end
  L.root():SetAttribute("Showcase", table.concat(report, "\n"))
  L.progress("showcase ready")
end)
