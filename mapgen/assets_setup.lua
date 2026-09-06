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
    if kind ~= "rejected" and type(list) == "table" and list[1] and list[1].id then
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
            local nameOk = (not isBush) or ((size.Y >= 4 and size.Y < 18) and (math.max(size.X, size.Z) / size.Y) < 2.2)   -- bush = compact clump, not logs/hedges
            if kind == "ore" and m.Name:lower():find("ingot") then nameOk = false end                                      -- ore packs ship ingots too; deposits only
            local nParts = 0; for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then nParts += 1; d.Anchored = true; d.CanCollide = (kind == "rock" or kind == "ore" or kind == "cave") end end
            local maxParts = (kind == "ore" or kind == "cave") and 80 or 12
            local minHeight = (kind == "ore") and 1.5 or 3
            local maxDim = math.max(size.X, size.Y, size.Z)
            if kind == "ore" and maxDim > 14 then nameOk = false end                              -- deposits are hand-sized rocks, not boulders
            if kind == "cave" and (maxDim > 34 or math.min(size.X, size.Y, size.Z) < 1.5) then nameOk = false end   -- no giant slabs / paper-thin pieces
            if nameOk and nParts <= maxParts and size.Y > minHeight then
              m.Name = ("%s_%s_%d"):format(kind, a.id, kept + 1)
              local cf = m:GetBoundingBox()
              m.WorldPivot = CFrame.new(cf.Position)                            -- upright pivot at the bbox centre: PivotTo(yaw) can never tip the tree over
              m:SetAttribute("BaseOffset", size.Y / 2)                          -- pivot height above the model's lowest point
              m:SetAttribute("Height", size.Y); m:SetAttribute("Parts", nParts); m:SetAttribute("SourceId", a.id)
              m.Parent = kf; kept += 1
            end
          end
          report[#report + 1] = ("%s %s (%s): %d prototypes kept of %d"):format(kind, a.id, tostring(a.name), kept, #found)
          loaded:Destroy()
        end
        task.wait()
      end
    end
  end
  L.root():SetAttribute("AssetsReport", table.concat(report, "\n"))
  L.progress("assets ready: " .. table.concat(report, " | "))
end)
