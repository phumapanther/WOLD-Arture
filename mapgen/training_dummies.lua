-- training_dummies: straw practice dummies that award a little EXP on every punch. One beside the starting
-- spawn so a new player can find it immediately, the rest spread around the map.
--
-- Run with:  node tools/run-luau.js mapgen/training_dummies.lua
--
-- Each dummy is tagged WOLD_Dummy and carries a Humanoid, which is what the combat hitbox already looks for;
-- PlayerCombat awards the EXP, this file only builds them.
return L.runPhase("TrainingDummies", function(folder)
  local sx, sz = L.placePos("Brasshaven")

  -- One at the spawn, then four scattered. Offsets are in studs from the spawn, chosen to land on open ground
  -- around the map rather than at named settlements (which do not exist yet).
  local SPOTS = {
    { name = "Dummy_Spawn", dx = 18, dz = 12 },
    { name = "Dummy_North", dx = 60, dz = -900 },
    { name = "Dummy_East", dx = 1100, dz = 220 },
    { name = "Dummy_South", dx = -180, dz = 1250 },
    { name = "Dummy_West", dx = -1300, dz = -140 },
  }

  -- A dummy bobbing in the sea is useless, and the offsets above are eyeballed. If one lands in water, spiral
  -- outwards from it until dry ground turns up rather than silently dropping that dummy.
  local function findLand(x, z)
    if L.isLand(x, z) then return x, z end
    for radius = 200, 2000, 200 do
      for step = 0, 11 do
        local angle = math.rad(step * 30)
        local nx, nz = x + math.cos(angle) * radius, z + math.sin(angle) * radius
        if L.isLand(nx, nz) then return nx, nz end
      end
    end
    return nil
  end

  local built = 0
  for _, spot in ipairs(SPOTS) do
    local x, z = findLand(sx + spot.dx, sz + spot.dz)
    if x then
      -- The REAL surface, by raycast. L.heightAt returns the height the terrain generator was ASKED to
      -- write, and voxel terrain lands somewhere else -- measured up to 2.3 studs high, which sank every
      -- dummy's post into the ground. Falls back to heightAt if nothing is hit.
      -- Excludes only this phase's own folder, so the ray finds whatever the player would actually stand
      -- on -- the plaza floor at the spawn, bare terrain elsewhere. Excluding the whole WOLD folder would
      -- put the spawn dummy on the terrain UNDER the plaza, a stud deep in the stone.
      local probe = RaycastParams.new()
      probe.FilterType = Enum.RaycastFilterType.Exclude
      probe.FilterDescendantsInstances = { folder }
      local groundHit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -900, 0), probe)
      -- The surface itself, with NO offset. Adding 1.5 studs to keep the post clear of the terrain grass
      -- left all five dummies visibly hovering -- and on the plaza, whose stone floor the ray also finds,
      -- the spawn dummy hung 5 studs in the air. A post is meant to be driven INTO the ground; the base
      -- part below extends past this point, which covers the grass without lifting the model.
      local y = groundHit and groundHit.Position.Y or L.heightAt(x, z)

      local model = Instance.new("Model")
      model.Name = spot.name

      -- The post it stands on.
      local post = Instance.new("Part")
      post.Name = "Post"
      post.Anchored = true
      -- Long enough to REACH the body, and sunk a stud into the ground so it reads as driven in rather
      -- than balanced on the surface. The body's underside is at y+3.6, so a post spanning y-1 to y+3.8
      -- meets it with no gap -- the previous 4-stud post stopped at y+3 and left the whole scarecrow
      -- hanging visibly in the air above it.
      post.Size = Vector3.new(0.8, 4.8, 0.8)
      post.Position = Vector3.new(x, y + 1.4, z)
      post.Material = Enum.Material.Wood
      post.Color = Color3.fromRGB(104, 78, 48)
      post.Parent = model

      -- The straw body. This is the part the punch hitbox finds, so it is the PrimaryPart and holds the
      -- HumanoidRootPart name the combat code looks for on a target.
      local body = Instance.new("Part")
      body.Name = "HumanoidRootPart"
      body.Anchored = true
      body.Size = Vector3.new(2.2, 3.2, 1.4)
      body.Position = Vector3.new(x, y + 5.2, z)
      body.Material = Enum.Material.Grass
      body.Color = Color3.fromRGB(198, 168, 82)
      body.Parent = model

      local head = Instance.new("Part")
      head.Name = "Head"
      head.Anchored = true
      head.Shape = Enum.PartType.Ball
      head.Size = Vector3.new(1.6, 1.6, 1.6)
      head.Position = Vector3.new(x, y + 7.4, z)
      head.Material = Enum.Material.Grass
      head.Color = Color3.fromRGB(214, 186, 104)
      head.Parent = model

      -- Outstretched arms, so it reads as a target rather than a crate.
      for side, sign in pairs({ Left = -1, Right = 1 }) do
        local arm = Instance.new("Part")
        arm.Name = side .. "Arm"
        arm.Anchored = true
        arm.Size = Vector3.new(2.4, 0.6, 0.6)
        arm.Position = Vector3.new(x + sign * 2.2, y + 6.0, z)
        arm.Material = Enum.Material.Wood
        arm.Color = Color3.fromRGB(120, 92, 56)
        arm.Parent = model
      end

      -- A Humanoid makes it a legitimate target for anything that looks for one, and gives it a name tag.
      local humanoid = Instance.new("Humanoid")
      humanoid.MaxHealth = math.huge -- practice dummies never break
      humanoid.Health = math.huge
      humanoid.DisplayName = "หุ่นฟาง"
      humanoid.Parent = model

      model.PrimaryPart = body
      model:SetAttribute("WOLD_Dummy", true)
      model.Parent = folder
      game:GetService("CollectionService"):AddTag(model, "WOLD_Dummy")
      built += 1
    end
  end

  print(("[WOLD] built %d training dummies"):format(built))
end)
