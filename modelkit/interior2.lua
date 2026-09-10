-- interior2 — floors with stairwell holes, self-computing stair flights, and doors that
-- open when you run into them. loaded after interior.lua and overrides K.floorSlab.
--
-- scale note: interiors here are sized for a Roblox character, not a real person. an R15
-- character is ~5.5 studs tall and jumps ~7.5, so a 26 stud ceiling is the "room to run and
-- jump" height, and a doorway is 12 x 18 so two players can run through it side by side.

-- floor deck with joists under it. opts.hole = { x = 0, z = 0, w = 12, d = 20 } leaves a
-- stairwell opening, built as four bands around it so the hole is a real gap.
function K.floorSlab(parent, cf, w, d, mat, color, opts)
  opts = opts or {}
  local m = K.model(parent, opts.name or "Floor")
  local material = mat or K.MAT.WoodPlanks
  local col = color or K.C.plank
  local function band(x0, x1, z0, z1)
    local bw, bd = x1 - x0, z1 - z0
    if bw < 0.05 or bd < 0.05 then return end
    K.box(m, cf * CFrame.new((x0 + x1) / 2, -0.4, (z0 + z1) / 2), Vector3.new(bw, 0.8, bd), material, col, { name = "Deck" })
    local n = math.max(1, math.floor(bd / 6))
    for i = 0, n do
      K.box(m, cf * CFrame.new((x0 + x1) / 2, -1.25, z0 + bd * i / n), Vector3.new(bw, 0.9, 0.9), K.MAT.Wood,
        col:Lerp(K.C.black, 0.35), { name = "Joist", cancollide = false })
    end
  end
  local h = opts.hole
  if not h then
    band(-w / 2, w / 2, -d / 2, d / 2)
  else
    local hx0, hx1 = h.x - h.w / 2, h.x + h.w / 2
    local hz0, hz1 = h.z - h.d / 2, h.z + h.d / 2
    band(-w / 2, hx0, -d / 2, d / 2)
    band(hx1, w / 2, -d / 2, d / 2)
    band(math.max(-w / 2, hx0), math.min(w / 2, hx1), -d / 2, hz0)
    band(math.max(-w / 2, hx0), math.min(w / 2, hx1), hz1, d / 2)
    K.box(m, cf * CFrame.new(h.x, 0.15, hz1 - 0.3), Vector3.new(h.w, 0.5, 0.6), K.MAT.Wood, col:Lerp(K.C.black, 0.4), { name = "WellTrim", cancollide = false })
  end
  return m
end

-- one flight, steps worked out from the rise so nothing is ever too steep to walk up.
-- climbs along the frame's local +Z. returns the run it used.
function K.stairFlight(parent, cf, width, rise, mat, color, opts)
  opts = opts or {}
  local stepRise = opts.stepRise or 1.15
  local steps = math.max(2, math.ceil(rise / stepRise))
  -- 45 degrees. steeper than a real stair, but a Roblox humanoid steps up anything under 2 studs
  -- and a 1.35 run needs 35 studs of floor for one storey, which no room this size can spare.
  local run = opts.run or rise * 1.05
  local m = K.model(parent, opts.name or "Stairs")
  for i = 1, steps do
    local y = rise * i / steps
    K.box(m, cf * CFrame.new(0, y / 2, run * (i - 0.5) / steps), Vector3.new(width, y, run / steps * 1.04),
      mat or K.MAT.WoodPlanks, color or K.C.plankDark, { name = "Step" })
  end
  if opts.rails ~= false then
    for _, s in ipairs({ -1, 1 }) do
      local rc = opts.railColor or K.C.wood
      for i = 0, steps, 2 do
        local y = rise * i / steps
        K.box(m, cf * CFrame.new(s * (width / 2 - 0.4), y + 2.6, run * i / steps), Vector3.new(0.45, 5.2, 0.45),
          K.MAT.Wood, rc, { name = "Baluster", cancollide = false })
      end
      K.rod(m, (cf * CFrame.new(s * (width / 2 - 0.4), 5.2, 0)).Position,
               (cf * CFrame.new(s * (width / 2 - 0.4), rise + 5.2, run)).Position, 0.4, K.MAT.Wood, opts.railColor or K.C.wood, { name = "Handrail", cancollide = false })
    end
  end
  return run
end

-- ---------- doors that swing open when a character runs into them ----------
local DOOR_SCRIPT = [==[
-- AutoDoor — swings open when a Humanoid touches the sensor, closes again once nobody is near.
-- attributes on the model: CloseAfter (seconds). each moving part carries SwingDeg + HingeX/HingeZ.
local TweenService = game:GetService("TweenService")
local door = script.Parent
local sensor = door:WaitForChild("Sensor")

local leaves = {}
for _, d in ipairs(door:GetDescendants()) do
	if d:IsA("BasePart") and d:GetAttribute("SwingDeg") then
		leaves[#leaves + 1] = { part = d, closed = d.CFrame }
	end
end

local isOpen, lastTouch = false, 0
local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function setOpen(state)
	if isOpen == state then return end
	isOpen = state
	for _, L in ipairs(leaves) do
		local off = Vector3.new(L.part:GetAttribute("HingeX") or 0, 0, L.part:GetAttribute("HingeZ") or 0)
		local hinge = L.closed * CFrame.new(off)
		local goal = L.closed
		if state then
			goal = hinge * CFrame.Angles(0, math.rad(L.part:GetAttribute("SwingDeg")), 0) * hinge:Inverse() * L.closed
		end
		TweenService:Create(L.part, info, { CFrame = goal }):Play()
	end
end

sensor.Touched:Connect(function(hit)
	if hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid") then
		lastTouch = os.clock()
		setOpen(true)
	end
end)

task.spawn(function()
	while door.Parent do
		task.wait(0.4)
		if isOpen and os.clock() - lastTouch > (door:GetAttribute("CloseAfter") or 2.5) then setOpen(false) end
	end
end)
]==]

-- a doorway whose leaves swing out of the way. cf is the centre of the opening at floor level,
-- the door sits in the frame's XY plane and opens toward -Z.
function K.autoDoor(parent, cf, w, h, opts)
  opts = opts or {}
  local m = K.model(parent, opts.name or "AutoDoor")
  local col = opts.color or K.C.wood
  local mat = opts.mat or K.MAT.WoodPlanks
  local thick = opts.thick or 0.8
  local dark = col:Lerp(K.C.black, 0.3)

  K.box(m, cf * CFrame.new(-w / 2 - 0.8, h / 2, 0), Vector3.new(1.6, h + 1.6, thick + 2.4), K.MAT.Wood, dark, { name = "Jamb" })
  K.box(m, cf * CFrame.new(w / 2 + 0.8, h / 2, 0), Vector3.new(1.6, h + 1.6, thick + 2.4), K.MAT.Wood, dark, { name = "Jamb" })
  K.box(m, cf * CFrame.new(0, h + 0.8, 0), Vector3.new(w + 3.2, 1.6, thick + 2.4), K.MAT.Wood, dark, { name = "Lintel" })

  -- every moving piece records where its hinge is, measured in the door frame's own X
  local function moving(part, partX, hingeX, swing)
    K.attrs(part, { SwingDeg = swing, HingeX = hingeX - partX, HingeZ = 0 })
    return part
  end
  local function leaf(centreX, lw, swing)
    local hingeX = centreX + (swing > 0 and -lw / 2 or lw / 2)
    moving(K.box(m, cf * CFrame.new(centreX, h / 2, 0), Vector3.new(lw, h, thick), mat, col, { name = "Leaf" }), centreX, hingeX, swing)
    for _, f in ipairs({ 0.24, 0.76 }) do
      moving(K.box(m, cf * CFrame.new(centreX, h * f, -thick * 0.6), Vector3.new(lw * 0.94, 1, 0.4), K.MAT.Metal, K.C.iron, { name = "Band", cancollide = false }), centreX, hingeX, swing)
    end
    local hx = centreX + (swing > 0 and lw * 0.36 or -lw * 0.36)
    moving(K.ball(m, cf * CFrame.new(hx, h * 0.46, -thick * 0.9), 1, K.MAT.Metal, K.C.brass, { name = "Handle", cancollide = false }), hx, hingeX, swing)
  end

  if opts.single or w < 9 then
    leaf(0, w, opts.swing or -95)
  else
    leaf(-w / 4, w / 2 - 0.1, -95)
    leaf(w / 4, w / 2 - 0.1, 95)
  end

  K.box(m, cf * CFrame.new(0, h / 2, 0), Vector3.new(w + 3, h, 12), K.MAT.SmoothPlastic, K.C.white,
    { name = "Sensor", transparency = 1, cancollide = false })
  local s = Instance.new("Script")
  s.Name = "AutoDoor"
  s.Source = DOOR_SCRIPT
  s.Parent = m
  K.attrs(m, { CloseAfter = opts.closeAfter or 2.5 })
  return m
end

-- a barred cell door: same swing behaviour, iron bars instead of planks
function K.cellDoor(parent, cf, w, h, opts)
  opts = opts or {}
  local m = K.autoDoor(parent, cf, w, h, { name = opts.name or "CellDoor", color = K.C.iron, mat = K.MAT.Metal, thick = 0.5, single = true, swing = opts.swing or -95, closeAfter = opts.closeAfter or 4 })
  local leafPart
  for _, d in ipairs(m:GetDescendants()) do if d.Name == "Leaf" then leafPart = d end end
  if leafPart then
    leafPart.Transparency = 1
    leafPart.CanCollide = false
    local n = math.max(3, math.floor(w / 2))
    for i = 0, n do
      local x = -w / 2 + w * i / n
      local bar = K.cyl(m, leafPart.CFrame * CFrame.new(x, 0, 0), 0.32, h - 1, K.MAT.Metal, K.C.iron, { name = "Bar" })
      K.attrs(bar, { SwingDeg = leafPart:GetAttribute("SwingDeg"), HingeX = (leafPart:GetAttribute("HingeX") or 0) - x, HingeZ = 0 })
    end
    for _, f in ipairs({ 0.2, 0.8 }) do
      local rail = K.box(m, leafPart.CFrame * CFrame.new(0, (f - 0.5) * (h - 2), 0), Vector3.new(w, 0.7, 0.5), K.MAT.Metal, K.C.iron, { name = "CrossRail" })
      K.attrs(rail, { SwingDeg = leafPart:GetAttribute("SwingDeg"), HingeX = leafPart:GetAttribute("HingeX") or 0, HingeZ = 0 })
    end
  end
  return m
end

-- a run of vertical bars filling an opening: cell fronts, window grilles
function K.bars(parent, cf, w, h, opts)
  opts = opts or {}
  local m = K.model(parent, opts.name or "Bars")
  local n = math.max(2, math.floor(w / (opts.spacing or 2.2)))
  for i = 0, n do
    K.cyl(m, cf * CFrame.new(-w / 2 + w * i / n, h / 2, 0), opts.r or 0.32, h, K.MAT.Metal, opts.color or K.C.iron, { name = "Bar" })
  end
  for _, f in ipairs({ 0.25, 0.75 }) do
    K.box(m, cf * CFrame.new(0, h * f, 0), Vector3.new(w, 0.7, 0.5), K.MAT.Metal, opts.color or K.C.iron, { name = "CrossRail", cancollide = false })
  end
  return m
end
