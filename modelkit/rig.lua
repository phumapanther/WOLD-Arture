-- rig — real Roblox R15 characters for the modelkit workshop.
-- a rig model is jointed with Motor6D, so it plays Roblox animation tracks; everything the kit
-- builds on top (hair, hats, packs, weapons) is welded to a limb and unanchored so it moves along.
-- convention is unchanged: feet on y = 0, centred on x/z, facing -Z.
local R = {}
local Players = game:GetService("Players")
local MAT = Enum.Material
local rgb = Color3.fromRGB

R.LIMBS = { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand",
  "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
  "RightUpperLeg", "RightLowerLeg", "RightFoot", "HumanoidRootPart" }

-- default Roblox animation set (the ids the design brief listed)
R.ANIM = { idle = "rbxassetid://507766388", walk = "rbxassetid://507777826" }

function R.limb(m, name) return m:FindFirstChild(name) end

-- weld an added part onto a limb so animation carries it
function R.weld(part, limb)
  part.Anchored = false
  part.CanCollide = false
  part.Massless = true
  local w = Instance.new("WeldConstraint")
  w.Name = "WeldTo_" .. limb.Name
  w.Part0 = part
  w.Part1 = limb
  w.Parent = part
  return part
end

-- build gear in world space against a limb, then weld every part of it to that limb.
-- fn(holder, limbCFrame) — place things relative to the limb's current CFrame.
function R.attach(m, limbName, fn, holderName)
  local limb = R.limb(m, limbName)
  assert(limb, "rig has no limb named " .. limbName)
  local holder = Instance.new("Model")
  holder.Name = holderName or (limbName .. "Gear")
  holder.Parent = m
  fn(holder, limb.CFrame, limb)
  for _, p in ipairs(holder:GetDescendants()) do
    if p:IsA("BasePart") then R.weld(p, limb) end
  end
  return holder
end

-- ---------------------------------------------------------------- the rig itself
-- opts: skin, shirt, pants, height, width, head, face
function R.new(m, opts)
  opts = opts or {}
  local d = Instance.new("HumanoidDescription")
  d.HeadColor = opts.skin or rgb(240, 195, 160)
  d.LeftArmColor, d.RightArmColor = d.HeadColor, d.HeadColor
  d.TorsoColor = opts.shirt or rgb(130, 85, 50)
  d.LeftLegColor, d.RightLegColor = opts.pants or rgb(70, 50, 40), opts.pants or rgb(70, 50, 40)
  d.HeightScale = opts.height or 1
  d.WidthScale = opts.width or 1
  d.HeadScale = opts.head or 1
  d.DepthScale = opts.depth or 1
  d.BodyTypeScale = opts.bodyType or 0
  d.ProportionScale = opts.proportion or 0

  local src = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
  local mine = {}                                   -- only the rig's own parts move; anything already
  for _, c in ipairs(src:GetChildren()) do          -- in the model (a pedestal, say) stays where it is
    c.Parent = m
    if c:IsA("BasePart") then mine[#mine + 1] = c end
  end
  src:Destroy()

  local hum = m:FindFirstChildOfClass("Humanoid")
  hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
  hum.MaxHealth = opts.health or 100
  hum.Health = hum.MaxHealth
  hum.WalkSpeed = opts.walkSpeed or 6
  hum.BreakJointsOnDeath = false

  -- drop the rig so the soles rest on opts.baseY (the top of a pedestal, when there is one)
  local minY = math.huge
  for _, p in ipairs(mine) do minY = math.min(minY, p.Position.Y - p.Size.Y / 2) end
  local lift = CFrame.new(0, (opts.baseY or 0) - minY, 0)
  for _, p in ipairs(mine) do p.CFrame = lift * p.CFrame end

  if opts.face ~= false then R.face(m, opts.face) end
  return m, hum
end

-- eyes and mouth. the R15 head is a MeshPart with no decal of its own, so put a face texture on
-- its front face; part-built eyes go on top for characters whose look needs more than the texture.
function R.face(m, texture)
  local head = R.limb(m, "Head")
  local d = Instance.new("Decal")
  d.Name = "face"
  d.Face = Enum.NormalId.Front
  d.Texture = (type(texture) == "string" and texture) or "rbxasset://textures/face.png"
  d.Parent = head
  return d
end

-- glowing or plain eyes built from parts, sitting just proud of the head front
function R.eyes(m, opts)
  opts = opts or {}
  local head = R.limb(m, "Head")
  return R.attach(m, "Head", function(g, H)
    local z = -head.Size.Z / 2 - 0.02
    for _, s in ipairs({ -1, 1 }) do
      K.ball(g, H * CFrame.new(0.22 * s, 0.12, z), opts.size or 0.2, opts.mat or MAT.SmoothPlastic, opts.color or rgb(30, 30, 34), { name = "Eye" })
    end
    if opts.brow then
      for _, s in ipairs({ -1, 1 }) do
        K.box(g, H * CFrame.new(0.24 * s, 0.3, z) * K.roll(math.rad(9 * s)), Vector3.new(0.26, 0.07, 0.06), MAT.SmoothPlastic, opts.brow, { name = "Brow" })
      end
    end
  end, "Eyes")
end

-- ------------------------------------------------------------------------- hair
-- styles are built from small slabs capping the head mesh, then welded to it
local function cap(g, H, hs, color, mat, back)
  local w, h, d = hs.X, hs.Y, hs.Z
  K.box(g, H * CFrame.new(0, h * 0.42, 0.02), Vector3.new(w * 1.06, h * 0.34, d * 1.06), mat, color, { name = "HairTop" })
  K.box(g, H * CFrame.new(0, h * 0.16, d * 0.46), Vector3.new(w * 1.06, h * 0.55, d * 0.16), mat, color, { name = "HairBack" })
  for _, s in ipairs({ -1, 1 }) do
    K.box(g, H * CFrame.new(w * 0.5 * s, h * 0.14, 0.04), Vector3.new(w * 0.12, h * 0.55, d * 0.95), mat, color, { name = "HairSide" })
  end
  if back then
    K.box(g, H * CFrame.new(0, -h * 0.3, d * 0.5), Vector3.new(w * 0.9, h * 0.7, d * 0.2), mat, color, { name = "HairLong" })
  end
end

-- style: "short" | "long" | "ponytail" | "bun" | "bald" | "wild"
function R.hair(m, style, color, mat)
  if style == "bald" then return nil end
  local head = R.limb(m, "Head")
  local col = color or rgb(60, 42, 30)
  local material = mat or MAT.SmoothPlastic
  return R.attach(m, "Head", function(g, H)
    local hs = head.Size
    cap(g, H, hs, col, material, style == "long")
    if style == "ponytail" then
      K.rod(g, (H * CFrame.new(0, hs.Y * 0.1, hs.Z * 0.55)).Position, (H * CFrame.new(0, -hs.Y * 0.7, hs.Z * 0.85)).Position, hs.X * 0.13, material, col, { name = "Tail" })
      K.ball(g, H * CFrame.new(0, hs.Y * 0.12, hs.Z * 0.58), hs.X * 0.3, material, col:Lerp(rgb(0, 0, 0), 0.2), { name = "TailTie" })
    elseif style == "bun" then
      K.ball(g, H * CFrame.new(0, hs.Y * 0.62, hs.Z * 0.36), hs.X * 0.52, material, col, { name = "Bun" })
    elseif style == "wild" then
      for i = 0, 5 do
        local a = i * math.pi / 3
        K.box(g, H * CFrame.new(math.cos(a) * hs.X * 0.34, hs.Y * 0.56, math.sin(a) * hs.Z * 0.34) * CFrame.Angles(math.rad(20), a, math.rad(18)),
          Vector3.new(hs.X * 0.2, hs.Y * 0.4, hs.Z * 0.2), material, col, { name = "Tuft" })
      end
    end
  end, "Hair")
end

function R.beard(m, color, mat, long)
  local head = R.limb(m, "Head")
  local col = color or rgb(60, 42, 30)
  return R.attach(m, "Head", function(g, H)
    local hs = head.Size
    K.box(g, H * CFrame.new(0, -hs.Y * 0.33, -hs.Z * 0.36), Vector3.new(hs.X * 0.62, hs.Y * (long and 0.62 or 0.3), hs.Z * 0.34), mat or MAT.SmoothPlastic, col, { name = "Beard" })
    K.box(g, H * CFrame.new(0, -hs.Y * 0.1, -hs.Z * 0.47), Vector3.new(hs.X * 0.34, hs.Y * 0.09, hs.Z * 0.12), mat or MAT.SmoothPlastic, col, { name = "Moustache" })
  end, "Beard")
end

-- ------------------------------------------------------- animation + wander script
-- the controller runs on the server inside the NPC; ids and behaviour come from attributes so a
-- built NPC can be retuned in the Properties panel without rebuilding it.
local CONTROLLER = [==[
-- NPCController — idle/walk animation loop plus a wander behaviour.
-- tuning lives in the model's attributes: IdleAnim, WalkAnim, WanderRadius, WanderMin, WanderMax, WalkSpeed
local npc = script.Parent
local humanoid = npc:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")

local function anim(id, priority)
	local a = Instance.new("Animation")
	a.AnimationId = id
	local track = animator:LoadAnimation(a)
	track.Priority = priority
	track.Looped = true
	return track
end

local idleTrack = anim(npc:GetAttribute("IdleAnim") or "rbxassetid://507766388", Enum.AnimationPriority.Idle)
local walkTrack = anim(npc:GetAttribute("WalkAnim") or "rbxassetid://507777826", Enum.AnimationPriority.Movement)

idleTrack:Play(0.2)

humanoid.Running:Connect(function(speed)
	if speed > 0.5 then
		if not walkTrack.IsPlaying then
			idleTrack:Stop(0.2)
			walkTrack:Play(0.2)
		end
	elseif not idleTrack.IsPlaying then
		walkTrack:Stop(0.2)
		idleTrack:Play(0.2)
	end
end)

local radius = npc:GetAttribute("WanderRadius") or 0
if radius > 0 then
	humanoid.WalkSpeed = npc:GetAttribute("WalkSpeed") or humanoid.WalkSpeed
	local home = npc:GetPivot().Position
	task.spawn(function()
		while npc.Parent and humanoid.Health > 0 do
			task.wait(math.random(npc:GetAttribute("WanderMin") or 4, npc:GetAttribute("WanderMax") or 8))
			local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * radius
			humanoid:MoveTo(home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			-- MoveToFinished fires on arrival or after Roblox's 8 second timeout, so this never wedges
			humanoid.MoveToFinished:Wait()
		end
	end)
end
]==]

function R.controller(m, opts)
  opts = opts or {}
  local s = Instance.new("Script")
  s.Name = "NPCController"
  s.Source = CONTROLLER
  s.Parent = m
  K.attrs(m, {
    IdleAnim = opts.idle or R.ANIM.idle,
    WalkAnim = opts.walk or R.ANIM.walk,
    WanderRadius = opts.wander or 0,
    WanderMin = opts.wanderMin or 4,
    WanderMax = opts.wanderMax or 8,
    WalkSpeed = opts.walkSpeed or 6,
  })
  return s
end

-- recolour rig limbs, e.g. turning one arm into brass clockwork
function R.paint(m, names, color, mat)
  for _, n in ipairs(names) do
    local p = R.limb(m, n)
    if p then
      p.Color = color
      if mat then p.Material = mat end
    end
  end
end

-- slimes have no skeleton to animate, so they breathe and hop by moving their whole body model.
-- the pedestal stays behind because only the "Body" child is pivoted.
local SLIME = [==[
-- SlimeController — bobbing idle plus random arcing hops around the spawn point.
-- attributes: WanderRadius, HopEvery, HopHeight, HopTime
local RunService = game:GetService("RunService")
local slime = script.Parent
local body = slime:WaitForChild("Body")
local radius = slime:GetAttribute("WanderRadius") or 0
local hopEvery = slime:GetAttribute("HopEvery") or 3
local hopHeight = slime:GetAttribute("HopHeight") or 1.6
local hopTime = slime:GetAttribute("HopTime") or 0.7

local home = body:GetPivot()
local base = home
local from, to, started

task.spawn(function()
	while slime.Parent do
		task.wait(hopEvery * (0.6 + math.random()))
		if radius > 0 and not to then
			local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * radius
			from, to = base, home * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)
			started = os.clock()
		end
	end
end)

local t0 = os.clock()
RunService.Heartbeat:Connect(function()
	if to then
		local k = (os.clock() - started) / hopTime
		if k >= 1 then
			base, to = to, nil
			body:PivotTo(base)
		else
			local p = from.Position:Lerp(to.Position, k)
			local squash = math.sin(k * math.pi)
			body:PivotTo(CFrame.new(p + Vector3.new(0, squash * hopHeight, 0)) * CFrame.Angles(math.sin(k * math.pi * 2) * 0.14, 0, 0))
		end
	else
		local t = os.clock() - t0
		body:PivotTo(base
			* CFrame.new(0, math.sin(t * 2.2) * 0.16, 0)
			* CFrame.Angles(math.sin(t * 1.7) * 0.035, math.sin(t * 0.6) * 0.08, math.cos(t * 1.3) * 0.035))
	end
end)
]==]

function R.slimeController(m, opts)
  opts = opts or {}
  local s = Instance.new("Script")
  s.Name = "SlimeController"
  s.Source = SLIME
  s.Parent = m
  K.attrs(m, {
    WanderRadius = opts.wander or 0,
    HopEvery = opts.hopEvery or 3,
    HopHeight = opts.hopHeight or 1.6,
    HopTime = opts.hopTime or 0.7,
  })
  return s
end

-- How close you have to be to read an NPC's name. Roughly the distance at which you can tell one villager
-- from another by sight -- close enough to walk up and talk, not so far that a town reads as a wall of
-- floating labels.
R.NAMETAG_DISTANCE = 40

function R.nametag(m, title, role, color, anchor)
  local head = anchor or R.limb(m, "Head")
  local b = Instance.new("BillboardGui")
  b.Name = "NameTag"; b.Size = UDim2.new(0, 190, 0, 52); b.StudsOffset = Vector3.new(0, 2.6, 0)
  -- A BillboardGui with no MaxDistance is visible from ANY range, and AlwaysOnTop draws it through the
  -- terrain -- so every name in the capital hung in the sky above the hills, legible from the far shore.
  -- The cap is what turns a label into something you discover by walking up to someone.
  b.MaxDistance = R.NAMETAG_DISTANCE
  b.AlwaysOnTop = true; b.Parent = head
  local t = Instance.new("TextLabel")
  t.Size = UDim2.new(1, 0, 0.55, 0); t.BackgroundTransparency = 1; t.Text = title
  t.TextColor3 = color or rgb(255, 215, 100); t.TextScaled = true; t.Font = Enum.Font.GothamBold
  t.TextStrokeColor3 = rgb(20, 20, 20); t.TextStrokeTransparency = 0.2; t.Parent = b
  local r = Instance.new("TextLabel")
  r.Position = UDim2.new(0, 0, 0.55, 0); r.Size = UDim2.new(1, 0, 0.45, 0); r.BackgroundTransparency = 1
  r.Text = "[" .. role .. "]"; r.TextColor3 = rgb(220, 220, 220); r.TextScaled = true
  r.Font = Enum.Font.GothamMedium; r.TextStrokeColor3 = rgb(20, 20, 20); r.TextStrokeTransparency = 0.4; r.Parent = b
  return b
end

function R.prompt(m, action, object, anchor)
  local p = Instance.new("ProximityPrompt")
  p.ActionText = action; p.ObjectText = object
  p.MaxActivationDistance = 9; p.RequiresLineOfSight = false
  p.Parent = typeof(anchor) == "Instance" and anchor or R.limb(m, anchor or "UpperTorso")
  return p
end

return R
