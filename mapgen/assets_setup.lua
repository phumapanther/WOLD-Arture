-- assets_setup: load the approved Creator Store models listed in layout.nature.assets with InsertService,
-- strip scripts, split packs into single prototypes, measure base offsets, store under ServerStorage.WOLD_Assets.<kind>
return L.runPhase("AssetsSetup", function()
  local Y = L.LAYOUT
  local SS = game:GetService("ServerStorage")
  local IS = game:GetService("InsertService")
  local root = SS:FindFirstChild("WOLD_Assets"); if root then root:Destroy() end
  root = Instance.new("Folder"); root.Name = "WOLD_Assets"; root.Parent = SS
  local report = {}
  local function hasParts(inst) for _, d in ipairs(inst:GetDescendants()) do if d:IsA("BasePart") then return true end end; return false end
  local function directParts(inst) for _, c in ipairs(inst:GetChildren()) do if c:IsA("BasePart") then return true end end; return false end
  local function protos(container, out)              -- recursive: a Model that directly owns parts is one prototype; otherwise descend
    for _, c in ipairs(container:GetChildren()) do
      if c:IsA("Model") then
        if directParts(c) or #c:GetChildren() == 0 then if hasParts(c) then out[#out + 1] = c end
        else
          local sub = {}; protos(c, sub)
          if #sub == 0 and hasParts(c) then out[#out + 1] = c else for _, s in ipairs(sub) do out[#out + 1] = s end end
        end
      elseif c:IsA("Folder") then protos(c, out)
      elseif c:IsA("BasePart") then local m = Instance.new("Model"); c.Parent = m; m.Parent = container; out[#out + 1] = m end
    end
  end
  for kind, list in pairs(Y.nature.assets) do
    if type(list) == "table" and list[1] and list[1].id then
      local kf = Instance.new("Folder"); kf.Name = kind; kf.Parent = root
      for _, a in ipairs(list) do
        local ok, loaded = pcall(function() return IS:LoadAsset(tonumber(a.id)) end)
        if not ok then report[#report + 1] = ("%s %s LOAD FAILED: %s"):format(kind, a.id, tostring(loaded))
        else
          for _, d in ipairs(loaded:GetDescendants()) do if d:IsA("LuaSourceContainer") or d:IsA("Camera") then d:Destroy() end end
          local found = {}; protos(loaded, found)
          local kept = 0
          for _, m in ipairs(found) do
            local _, size = m:GetBoundingBox()
            local isBush = kind == "bush"
            local nameOk = (not isBush) or (m.Name:lower():find("bush") ~= nil) or (size.Y < 16 and size.X > 4)
            local nParts = 0; for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then nParts += 1; d.Anchored = true; d.CanCollide = (kind == "rock") end end
            if nameOk and nParts <= 12 and size.Y > 3 then
              m.Name = ("%s_%s_%d"):format(kind, a.id, kept + 1)
              local cf = m:GetBoundingBox(); local bottom = cf.Position.Y - size.Y / 2
              m:SetAttribute("BaseOffset", m:GetPivot().Position.Y - bottom)   -- pivot height above the model's lowest point
              m:SetAttribute("Height", size.Y); m:SetAttribute("Parts", nParts); m:SetAttribute("SourceId", a.id)
              m.Parent = kf; kept += 1
            end
          end
          report[#report + 1] = ("%s %s (%s): %d prototypes kept of %d"):format(kind, a.id, a.name, kept, #found)
          loaded:Destroy()
        end
        task.wait()
      end
    end
  end
  L.root():SetAttribute("AssetsReport", table.concat(report, "\n"))
  L.progress("assets ready: " .. table.concat(report, " | "))
end)
