-- world setup (phase 1): wipe template/test objects, root + Manual folders, streaming, visual style, far sea plane
return L.runPhase("Setup", function(folder)
  local Y, MAT = L.LAYOUT, L.MAT
  for _, n in ipairs({ "Baseplate", "MCP_Test", "SpawnLocation" }) do local o = workspace:FindFirstChild(n); if o then o:Destroy() end end
  local yard = L.root():FindFirstChild("TestYard"); if yard then yard:Destroy() end          -- phase 0 is over
  L.manualFolder()
  pcall(function() game:GetService("ChangeHistoryService"):SetEnabled(false) end)          -- huge terrain writes must not fill undo history; re-enabled in 90_verify
  workspace.StreamingEnabled = true
  workspace.StreamingMinRadius = Y.generator.streaming.min_radius
  workspace.StreamingTargetRadius = Y.generator.streaming.target_radius
  L.applyStyle()
  -- far sea: Part tiles from the terrain-water extent out to the part-sea extent (Part max 2048 per axis)
  local inner, outer, T = Y.sea.terrain_water_extent_studs * L.SCALE, Y.sea.part_sea_extent_studs * L.SCALE, 2048 * L.SCALE
  local n = 0
  for x = -outer, outer - T, T do for z = -outer, outer - T, T do
    if not (x + T <= inner and x >= -inner and z + T <= inner and z >= -inner) then
      L.box(folder, CFrame.new(x + T / 2, -2, z + T / 2), Vector3.new(T, 4, T), MAT.Glass, L.C.sea, { name = "Sea", transparency = 0.15 })
      n += 1
    end
  end end
  L.progress(("setup done: %d sea tiles, streaming %d/%d"):format(n, workspace.StreamingMinRadius, workspace.StreamingTargetRadius))
end)
