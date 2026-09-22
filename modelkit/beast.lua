-- beast — jointed four- and eight-legged creatures, loaded after rig.lua so it can extend R.
--
-- rig.lua makes PEOPLE: it asks Roblox for an R15 body and plays stock animation ids. A cow has
-- four legs and a spider has eight, and Roblox ships no walk cycle for either, so these rigs are
-- driven PROCEDURALLY instead — the controller writes Motor6D.Transform every Heartbeat from how
-- fast the creature is actually moving. No uploaded animation asset is needed, the gait stays in
-- step at any speed, and it settles to a breathing idle the moment the creature stops.
--
-- every joint carries its own gait settings as attributes (Phase / Swing / Fold / Axis), so the
-- one controller script drives a chicken, a cow, a wolf and a spider without knowing what it is on.
-- Retune a gait in the Properties panel without rebuilding: select a Motor6D, change Swing.
--
-- conventions, same as the rest of the kit: feet on y = 0, centred on x/z, facing -Z.
-- rig parts are UNANCHORED (a Humanoid cannot walk anchored parts) and land on the display pad.

local BMAT = Enum.Material

-- ---------------------------------------------------------------- primitives
-- a limb part: unanchored, massless, non-collidable. Only the root part collides, or the legs
-- catch on the ground and the creature trips over its own geometry.
function R.limbPart(m, name, cf, size, mat, color, opts)
  local p = Instance.new("Part")
  p.Name = name
  p.Size = size
  p.CFrame = cf
  p.Material = mat or BMAT.SmoothPlastic
  p.Color = color or K.C.leather
  p.Anchored = false
  p.CanCollide = false
  p.Massless = true
  p.TopSurface = Enum.SurfaceType.Smooth
  p.BottomSurface = Enum.SurfaceType.Smooth
  if opts then
    if opts.shape then p.Shape = opts.shape end
    if opts.transparency then p.Transparency = opts.transparency end
    if opts.reflectance then p.Reflectance = opts.reflectance end
    if opts.collide then p.CanCollide = true end
  end
  p.Parent = m
  return p
end

function R.limbBall(m, name, cf, d, mat, color)
  return R.limbPart(m, name, cf, Vector3.new(d, d, d), mat, color, { shape = Enum.PartType.Ball })
end

-- a Motor6D at a world-space point. Building the parts in their rest pose first and deriving C0/C1
-- from that is what lets the spec below be written in plain world coordinates.
function R.joint(p0, p1, at, name, gait)
  local j = Instance.new("Motor6D")
  j.Name = name
  j.Part0 = p0
  j.Part1 = p1
  j.C0 = p0.CFrame:Inverse() * at
  j.C1 = p1.CFrame:Inverse() * at
  if gait then for k, v in pairs(gait) do j:SetAttribute(k, v) end end
  j.Parent = p0
  return j
end

-- ---------------------------------------------------------------- the gait controller
local GAIT = [==[
-- BeastGait — procedural walk cycle plus wander, for rigs with no animation asset.
--
-- Reads every Motor6D under the model and animates the ones carrying a Phase attribute:
--   Phase  offset into the stride, in radians. Diagonal legs share a phase; that IS a trot.
--   Swing  peak rotation in radians at full speed
--   Fold   extra rotation applied only on the recovery half of the stride (knees, elbows)
--   Axis   "X" pitch (default, swings fore/aft) | "Y" yaw | "Z" roll
--   Idle   amplitude kept when standing still, so the creature breathes instead of freezing
-- Model attributes: WalkSpeed, WanderRadius, WanderMin, WanderMax, StrideRate, Bob
local RunService = game:GetService("RunService")
local beast = script.Parent
local humanoid = beast:WaitForChild("Humanoid")
local root = beast:WaitForChild("HumanoidRootPart")

local joints = {}
for _, d in ipairs(beast:GetDescendants()) do
	if d:IsA("Motor6D") and d:GetAttribute("Phase") then
		joints[#joints + 1] = { j = d, rest = d.C0 }
	end
end

humanoid.WalkSpeed = beast:GetAttribute("WalkSpeed") or humanoid.WalkSpeed
local rate = beast:GetAttribute("StrideRate") or 0.55
local bobAmt = beast:GetAttribute("Bob") or 0.12
local phase = 0

local function axisCF(axis, a)
	if axis == "Y" then return CFrame.Angles(0, a, 0) end
	if axis == "Z" then return CFrame.Angles(0, 0, a) end
	return CFrame.Angles(a, 0, 0)
end

RunService.Heartbeat:Connect(function(dt)
	local vel = root.AssemblyLinearVelocity
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	-- a standing creature still cycles, just slowly: that is the breathing idle
	phase += dt * (speed > 0.4 and speed * rate + 1 or 1.1)
	local drive = math.clamp(speed / 8, 0, 1)
	for _, e in ipairs(joints) do
		local j = e.j
		local amp = (j:GetAttribute("Swing") or 0) * drive
			+ (j:GetAttribute("Idle") or 0) * (1 - drive)
		local off = j:GetAttribute("Phase") or 0
		local s = math.sin(phase + off)
		local a = s * amp
		local fold = j:GetAttribute("Fold")
		if fold then a += math.max(0, -s) * fold * drive end
		j.Transform = axisCF(j:GetAttribute("Axis") or "X", a)
	end
	-- the body rides up and down twice per stride, which is what sells weight
	local bob = math.sin(phase * 2) * bobAmt * drive
	humanoid.HipHeight = (beast:GetAttribute("BaseHipHeight") or humanoid.HipHeight) + bob
end)

local radius = beast:GetAttribute("WanderRadius") or 0
if radius > 0 then
	local home = beast:GetPivot().Position
	task.spawn(function()
		while beast.Parent and humanoid.Health > 0 do
			task.wait(math.random(beast:GetAttribute("WanderMin") or 4, beast:GetAttribute("WanderMax") or 9))
			local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * radius
			humanoid:MoveTo(home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			humanoid.MoveToFinished:Wait()
		end
	end)
end
]==]

function R.beastController(m, opts)
  opts = opts or {}
  local s = Instance.new("Script")
  s.Name = "BeastGait"
  s.Source = GAIT
  s.Parent = m
  K.attrs(m, {
    WalkSpeed = opts.walkSpeed or 6,
    WanderRadius = opts.wander or 0,
    WanderMin = opts.wanderMin or 4,
    WanderMax = opts.wanderMax or 9,
    StrideRate = opts.strideRate or 0.55,
    Bob = opts.bob or 0.12,
  })
  return s
end

-- ---------------------------------------------------------------- four-legged body plan
-- spec (all in studs, all optional bar body/legs):
--   body   { len, w, h, y }        torso box, y = height of its centre
--   neck   { len, r, rise, reach } a sloped neck from the shoulder; rise/reach set its angle
--   head   { len, w, h, snout, jaw }
--   legs   { upper, lower, r, spanX, spanZ, hoof }
--   tail   { len, r, segs, tuft, droop }
--   ears   { len, w, up } | horns { len, r, curve } | mane | udder | woolly
-- returns model, humanoid, and a table of the named parts so a caller can dress it further.
function R.quad(m, spec)
  spec = spec or {}
  local B = spec.body or {}
  local L = spec.legs or {}
  local col = spec.color or K.C.leather
  local mat = spec.mat or BMAT.SmoothPlastic
  local belly = spec.belly or col:Lerp(K.C.white, 0.25)

  local bl, bw, bh = B.len or 11, B.w or 5.5, B.h or 5.5
  local up, low, lr = L.upper or 3.4, L.lower or 3.4, L.r or 0.85
  local spanX, spanZ = L.spanX or (bw * 0.62), L.spanZ or (bl * 0.34)
  local hoof = L.hoof or 0.9
  local by = B.y or (up + low + hoof + bh / 2 - 0.4)          -- torso centre rides on top of the legs

  local parts = {}
  -- the only collidable part: the Humanoid walks on this and nothing else
  local root = R.limbPart(m, "HumanoidRootPart", CFrame.new(0, by, 0), Vector3.new(bw * 0.8, bh * 0.8, bl * 0.7),
    mat, col, { transparency = 1, collide = true })
  root.Massless = false
  parts.root = root

  local torso = R.limbPart(m, "Torso", CFrame.new(0, by, 0), Vector3.new(bw, bh, bl), mat, col)
  parts.torso = torso
  R.joint(root, torso, CFrame.new(0, by, 0), "RootJoint")
  -- a belly panel and a rump both cost one part and do more for the silhouette than any detail
  local ubelly = R.limbPart(m, "Belly", CFrame.new(0, by - bh * 0.34, bl * 0.06), Vector3.new(bw * 1.01, bh * 0.34, bl * 0.82), mat, belly)
  R.joint(torso, ubelly, CFrame.new(0, by, 0), "BellyWeld")
  if spec.woolly then
    for i = 0, 5 do
      local t = i / 5
      R.limbBall(m, "Fleece", CFrame.new((t - 0.5) * 0 + 0, by + bh * 0.3, -bl / 2 + bl * (t + 0.08)), bw * 1.02, BMAT.Fabric, spec.fleece or K.C.canvas)
    end
    for _, p in ipairs(m:GetChildren()) do
      if p.Name == "Fleece" then R.joint(torso, p, p.CFrame, "FleeceWeld") end
    end
  end

  -- ---- neck and head, hung off the front of the torso (-Z is forward)
  local N = spec.neck or {}
  local H = spec.head or {}
  local nl, nr = N.len or 3.2, N.r or bw * 0.34
  local reach, rise = N.reach or (nl * 0.75), N.rise or (nl * 0.6)
  local shoulder = CFrame.new(0, by + bh * 0.22, -bl / 2 + 0.4)
  local neckMid = shoulder * CFrame.new(0, rise / 2, -reach / 2)
  local neck = R.limbPart(m, "Neck", CFrame.lookAt(neckMid.Position, shoulder.Position + Vector3.new(0, rise, -reach)),
    Vector3.new(nr * 2, nr * 2, math.sqrt(rise * rise + reach * reach) + nr), mat, col)
  R.joint(torso, neck, shoulder, "NeckJoint", { Phase = 0, Swing = 0, Idle = 0.045, Axis = "X" })
  parts.neck = neck

  local headAt = shoulder * CFrame.new(0, rise, -reach)
  local hl, hw, hh = H.len or 3.6, H.w or 2.6, H.h or 2.8
  local head = R.limbPart(m, "Head", headAt * CFrame.new(0, hh * 0.1, -hl / 2), Vector3.new(hw, hh, hl), mat, col)
  R.joint(neck, head, headAt, "HeadJoint", { Phase = 1.2, Swing = 0.06, Idle = 0.05, Axis = "X" })
  parts.head = head
  if H.snout then
    local s = R.limbPart(m, "Snout", head.CFrame * CFrame.new(0, -hh * 0.18, -hl / 2 - H.snout / 2),
      Vector3.new(hw * 0.66, hh * 0.42, H.snout), mat, spec.snoutColor or col:Lerp(K.C.white, 0.3))
    R.joint(head, s, head.CFrame, "SnoutWeld")
  end
  for _, sx in ipairs({ -1, 1 }) do
    local eye = R.limbBall(m, "Eye", head.CFrame * CFrame.new(sx * hw * 0.42, hh * 0.18, -hl * 0.22), 0.6, BMAT.SmoothPlastic, K.C.black)
    R.joint(head, eye, head.CFrame, "EyeWeld")
    if spec.ears then
      local E = spec.ears
      local ear = R.limbPart(m, "Ear", head.CFrame * CFrame.new(sx * hw * 0.5, hh * 0.5, hl * 0.1)
          * K.roll(sx * (E.up and 0.15 or 0.8)) * K.pitch(E.back or 0),
        Vector3.new(E.w or 0.5, E.len or 1.8, (E.d or 1.2)), mat, spec.earColor or col)
      R.joint(head, ear, head.CFrame, "EarWeld")
    end
    if spec.horns then
      -- a horn is a CHAIN that bends, not a stack of boxes at rising heights. The first pass
      -- spaced segments closer than their own length, so they merged into one lumpy mass that
      -- read as a second pair of ears. Each segment now points at the next and tapers.
      --   out   how far it leaves the skull sideways    fwd  positive sweeps forward, negative back
      --   curve how hard it bends outward per segment   rise how hard it bends upward per segment
      local Hr = spec.horns
      local segs = Hr.segs or 3
      local seglen = (Hr.len or 2) / segs
      local p0 = (head.CFrame * CFrame.new(sx * hw * 0.4, hh * 0.42, hl * 0.05)).Position
      local d = Vector3.new(sx * (Hr.out or 0.7), 1, -(Hr.fwd or 0)).Unit
      for i = 1, segs do
        local p1 = p0 + d * seglen
        local rr = (Hr.r or 0.5) * (1 - (i - 1) / (segs + 1))
        local hp = R.limbPart(m, "Horn", CFrame.lookAt(p0:Lerp(p1, 0.5), p1),
          Vector3.new(rr * 2, rr * 2, seglen * 1.18), BMAT.Slate, Hr.color or K.C.canvas:Lerp(K.C.black, 0.25))
        R.joint(head, hp, head.CFrame, "HornWeld")
        p0 = p1
        d = (d + Vector3.new(sx * (Hr.curve or 0.5) * 0.45, Hr.rise or 0.45, (Hr.sweep or 0))).Unit
      end
    end
  end

  -- ---- legs. Diagonal pairs share a phase: front-left with back-right is a trot, and a trot is
  -- what a cow, a wolf and a horse all do at walking pace.
  local phases = { math.pi * 0, math.pi, math.pi, math.pi * 0 }   -- FL, FR, BL, BR
  local sides = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }    -- x sign, z sign
  local names = { "FL", "FR", "BL", "BR" }
  for i = 1, 4 do
    local sx, sz = sides[i][1], sides[i][2]
    local hipAt = CFrame.new(sx * spanX, by - bh * 0.34, sz * spanZ)
    local u = R.limbPart(m, "Leg" .. names[i] .. "Upper", hipAt * CFrame.new(0, -up / 2, 0),
      Vector3.new(lr * 2, up, lr * 2), mat, spec.legColor or col)
    R.joint(torso, u, hipAt, "Hip" .. names[i], { Phase = phases[i], Swing = L.swing or 0.5, Idle = 0.02, Axis = "X" })
    local kneeAt = hipAt * CFrame.new(0, -up, 0)
    local lo = R.limbPart(m, "Leg" .. names[i] .. "Lower", kneeAt * CFrame.new(0, -low / 2, 0),
      Vector3.new(lr * 1.7, low, lr * 1.7), mat, spec.legColor or col)
    -- the knee only folds on the recovery half, which is the difference between walking and
    -- swinging four straight sticks back and forth
    R.joint(u, lo, kneeAt, "Knee" .. names[i], { Phase = phases[i], Swing = 0, Fold = (L.fold or 0.7) * sz, Axis = "X" })
    local footAt = kneeAt * CFrame.new(0, -low, 0)
    local f = R.limbPart(m, "Hoof" .. names[i], footAt * CFrame.new(0, -hoof / 2, -lr * 0.2),
      Vector3.new(lr * 2.1, hoof, lr * 2.8), BMAT.Slate, spec.hoofColor or col:Lerp(K.C.black, 0.45))
    R.joint(lo, f, footAt, "Ankle" .. names[i], { Phase = phases[i], Swing = 0.18, Axis = "X" })
  end

  -- ---- tail
  if spec.tail then
    local T = spec.tail
    local segs = T.segs or 4
    local prev, prevAt = torso, CFrame.new(0, by + bh * 0.24, bl / 2 - 0.2)
    for i = 1, segs do
      local sl = (T.len or 5) / segs
      local at = prevAt * CFrame.new(0, -(T.droop or 0.35) * sl, sl)
      -- each segment POINTS at the next joint. Axis-aligned boxes stepped down in a visible
      -- staircase instead of hanging, which is what a drooping tail has to do.
      local span = (at.Position - prevAt.Position)
      local seg = R.limbPart(m, "Tail" .. i, CFrame.lookAt(prevAt.Position:Lerp(at.Position, 0.5), at.Position),
        Vector3.new((T.r or 0.5) * 2 * (1 - i / (segs + 2)), (T.r or 0.5) * 2, span.Magnitude * 1.18), mat, spec.tailColor or col)
      R.joint(prev, seg, prevAt, "Tail" .. i .. "Joint",
        { Phase = i * 0.5, Swing = (T.swing or 0.22), Idle = 0.05, Axis = "Y" })
      prev, prevAt = seg, at
    end
    if T.tuft then
      local tuft = R.limbBall(m, "TailTuft", prevAt, (T.r or 0.5) * 3.4, BMAT.Fabric, T.tuft)
      R.joint(prev, tuft, prevAt, "TuftWeld")
    end
  end

  local hum = Instance.new("Humanoid")
  hum.RigType = Enum.HumanoidRigType.R15
  hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
  hum.MaxHealth = spec.health or 60
  hum.Health = hum.MaxHealth
  hum.WalkSpeed = spec.walkSpeed or 6
  hum.BreakJointsOnDeath = false
  hum.HipHeight = by - (bh * 0.8) / 2            -- root bottom to the ground
  hum.Parent = m
  Instance.new("Animator").Parent = hum
  m.PrimaryPart = root
  K.attrs(m, { BaseHipHeight = hum.HipHeight, Creature = spec.kind or "quad" })
  return m, hum, parts
end

-- ---------------------------------------------------------------- many-legged body plan
-- spec: body { len, w, h, y }, abdomen { len, w, h }, legs { pairs, upper, lower, r, spread, rise }
-- legs alternate phase down each side, which is the tripod-ish scuttle an arachnid actually uses.
function R.spider(m, spec)
  spec = spec or {}
  local B = spec.body or {}
  local L = spec.legs or {}
  local col = spec.color or K.C.coal
  local mat = spec.mat or BMAT.SmoothPlastic
  local bl, bw, bh = B.len or 4.5, B.w or 4, B.h or 2.6
  local up, low, lr = L.upper or 5, L.lower or 6, L.r or 0.42
  local by = B.y or (L.rise or 5.2)

  local root = R.limbPart(m, "HumanoidRootPart", CFrame.new(0, by, 0), Vector3.new(bw * 0.8, bh * 0.8, bl * 0.8),
    mat, col, { transparency = 1, collide = true })
  root.Massless = false
  local ceph = R.limbPart(m, "Torso", CFrame.new(0, by, -bl * 0.2), Vector3.new(bw, bh, bl), mat, col)
  R.joint(root, ceph, CFrame.new(0, by, 0), "RootJoint")
  local A = spec.abdomen or {}
  local abd = R.limbBall(m, "Abdomen", CFrame.new(0, by + (A.lift or 0.6), bl * (A.back or 0.85)), A.d or 6.5, mat, spec.abdomenColor or col)
  R.joint(ceph, abd, CFrame.new(0, by, bl * 0.4), "AbdomenJoint", { Phase = 0, Swing = 0, Idle = 0.04, Axis = "X" })
  if spec.stripe then
    local s = R.limbPart(m, "Mark", abd.CFrame * CFrame.new(0, (A.d or 6.5) * 0.34, 0), Vector3.new((A.d or 6.5) * 0.3, 0.3, (A.d or 6.5) * 0.5), BMAT.Neon, spec.stripe)
    R.joint(abd, s, abd.CFrame, "MarkWeld")
  end
  -- eyes: the row of them is the single thing that makes a lump of parts read as a spider
  for i = 0, 3 do
    for _, sx in ipairs({ -1, 1 }) do
      local d = (i < 2) and 0.55 or 0.35
      R.joint(ceph, R.limbBall(m, "Eye", ceph.CFrame * CFrame.new(sx * (0.5 + i * 0.42), bh * (0.3 - i * 0.12), -bl / 2 - 0.1), d,
        BMAT.Neon, spec.eyeColor or K.C.ember), ceph.CFrame, "EyeWeld")
    end
  end
  for _, sx in ipairs({ -1, 1 }) do             -- fangs
    local f = R.limbPart(m, "Fang", ceph.CFrame * CFrame.new(sx * 0.9, -bh * 0.4, -bl / 2 - 0.7) * K.pitch(0.5),
      Vector3.new(0.5, 1.8, 0.5), BMAT.Slate, spec.fangColor or K.C.canvas)
    R.joint(ceph, f, ceph.CFrame, "FangWeld")
  end

  local pairsN = L.pairs or 4
  for p = 0, pairsN - 1 do
    for _, sx in ipairs({ -1, 1 }) do
      local tag = (sx < 0 and "L" or "R") .. (p + 1)
      local ang = (L.fan or 0.55) * ((p / math.max(pairsN - 1, 1)) - 0.5) * 2
      local hipAt = CFrame.new(sx * bw * 0.45, by, -bl * 0.3 + bl * 0.55 * (p / math.max(pairsN - 1, 1)))
      -- the knee sits UP and OUT: that high elbow is the arachnid silhouette
      local dir = CFrame.new(hipAt.Position) * K.yaw(-ang * sx) * CFrame.new(sx * 1, 0, 0)
      local kneePos = hipAt.Position + Vector3.new(sx * up * 0.72, up * 0.6, ang * up)
      local footPos = kneePos + Vector3.new(sx * low * 0.55, -(by + up * 0.6), ang * low * 0.5)
      local u = R.limbPart(m, "Leg" .. tag .. "Upper", CFrame.lookAt(hipAt.Position:Lerp(kneePos, 0.5), kneePos),
        Vector3.new(lr * 2, lr * 2, (kneePos - hipAt.Position).Magnitude), mat, spec.legColor or col)
      R.joint(ceph, u, hipAt, "Hip" .. tag,
        { Phase = (p % 2 == 0) == (sx < 0) and 0 or math.pi, Swing = L.swing or 0.4, Idle = 0.03, Axis = "Y" })
      local lo = R.limbPart(m, "Leg" .. tag .. "Lower", CFrame.lookAt(kneePos:Lerp(footPos, 0.5), footPos),
        Vector3.new(lr * 1.6, lr * 1.6, (footPos - kneePos).Magnitude), mat, spec.legColor or col)
      R.joint(u, lo, CFrame.new(kneePos), "Knee" .. tag,
        { Phase = (p % 2 == 0) == (sx < 0) and 0 or math.pi, Swing = 0, Fold = L.fold or 0.45, Axis = "X" })
    end
  end

  local hum = Instance.new("Humanoid")
  hum.RigType = Enum.HumanoidRigType.R15
  hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
  hum.MaxHealth = spec.health or 60
  hum.Health = hum.MaxHealth
  hum.WalkSpeed = spec.walkSpeed or 9
  hum.BreakJointsOnDeath = false
  hum.HipHeight = by - (bh * 0.8) / 2
  hum.Parent = m
  Instance.new("Animator").Parent = hum
  m.PrimaryPart = root
  K.attrs(m, { BaseHipHeight = hum.HipHeight, Creature = spec.kind or "arachnid" })
  return m, hum
end

-- ---------------------------------------------------------------- birds
-- a bird is a quadruped with the front legs deleted and wings in their place, so it reuses the
-- same controller: the wings just get a bigger Swing on the Z axis.
function R.bird(m, spec)
  spec = spec or {}
  local col = spec.color or K.C.canvas
  local mat = spec.mat or BMAT.SmoothPlastic
  local bl, bw, bh = spec.len or 3.4, spec.w or 2.6, spec.h or 3
  local legLen = spec.legLen or 1.8
  local by = bh / 2 + legLen

  local root = R.limbPart(m, "HumanoidRootPart", CFrame.new(0, by, 0), Vector3.new(bw * 0.8, bh * 0.8, bl * 0.8),
    mat, col, { transparency = 1, collide = true })
  root.Massless = false
  local body = R.limbPart(m, "Torso", CFrame.new(0, by, 0), Vector3.new(bw, bh, bl), mat, col)
  R.joint(root, body, CFrame.new(0, by, 0), "RootJoint")
  local head = R.limbBall(m, "Head", CFrame.new(0, by + bh * 0.55, -bl * 0.35), bw * 0.72, mat, spec.headColor or col)
  R.joint(body, head, CFrame.new(0, by + bh * 0.3, -bl * 0.3), "HeadJoint", { Phase = 0, Swing = 0.3, Idle = 0.07, Axis = "X" })
  local beak = R.limbPart(m, "Beak", head.CFrame * CFrame.new(0, -0.15, -bw * 0.5), Vector3.new(0.5, 0.4, 1.1), BMAT.Slate, spec.beak or K.C.brass)
  R.joint(head, beak, head.CFrame, "BeakWeld")
  if spec.comb then
    local c = R.limbPart(m, "Comb", head.CFrame * CFrame.new(0, bw * 0.42, -0.1), Vector3.new(0.24, 0.9, 1.5), BMAT.SmoothPlastic, spec.comb)
    R.joint(head, c, head.CFrame, "CombWeld")
    local w = R.limbPart(m, "Wattle", head.CFrame * CFrame.new(0, -bw * 0.42, -bw * 0.38), Vector3.new(0.24, 0.8, 0.6), BMAT.SmoothPlastic, spec.comb)
    R.joint(head, w, head.CFrame, "WattleWeld")
  end
  for _, sx in ipairs({ -1, 1 }) do
    local shoulder = CFrame.new(sx * bw * 0.5, by + bh * 0.1, 0)
    local wing = R.limbPart(m, "Wing" .. (sx < 0 and "L" or "R"), shoulder * CFrame.new(sx * (spec.wing or 1.8) / 2, 0, 0),
      Vector3.new(spec.wing or 1.8, 0.4, bl * 0.85), mat, spec.wingColor or col:Lerp(K.C.black, 0.2))
    R.joint(body, wing, shoulder, "Wing" .. (sx < 0 and "L" or "R"),
      { Phase = 0, Swing = (spec.flap or 0.35) * -sx, Idle = 0.05, Axis = "Z" })
    -- legs, one stride out of phase with each other
    local hipAt = CFrame.new(sx * bw * 0.26, by - bh * 0.4, bl * 0.1)
    local leg = R.limbPart(m, "Leg" .. (sx < 0 and "L" or "R"), hipAt * CFrame.new(0, -legLen / 2, 0),
      Vector3.new(0.36, legLen, 0.36), BMAT.Slate, spec.foot or K.C.brass)
    R.joint(body, leg, hipAt, "Hip" .. (sx < 0 and "L" or "R"),
      { Phase = sx < 0 and 0 or math.pi, Swing = 0.55, Axis = "X" })
    local footAt = hipAt * CFrame.new(0, -legLen, 0)
    local foot = R.limbPart(m, "Foot" .. (sx < 0 and "L" or "R"), footAt * CFrame.new(0, -0.15, -0.45),
      Vector3.new(0.9, 0.3, 1.5), BMAT.Slate, spec.foot or K.C.brass)
    R.joint(leg, foot, footAt, "Ankle" .. (sx < 0 and "L" or "R"), { Phase = sx < 0 and 0 or math.pi, Swing = 0.2, Axis = "X" })
  end
  local tail = R.limbPart(m, "Tail", CFrame.new(0, by + bh * 0.35, bl * 0.6) * K.pitch(-0.5),
    Vector3.new(bw * 0.9, 0.4, bl * 0.8), mat, spec.tailColor or col:Lerp(K.C.black, 0.25))
  R.joint(body, tail, CFrame.new(0, by + bh * 0.3, bl * 0.4), "TailJoint", { Phase = 0.8, Swing = 0.2, Idle = 0.06, Axis = "X" })

  local hum = Instance.new("Humanoid")
  hum.RigType = Enum.HumanoidRigType.R15
  hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
  hum.MaxHealth = spec.health or 20
  hum.Health = hum.MaxHealth
  hum.WalkSpeed = spec.walkSpeed or 5
  hum.BreakJointsOnDeath = false
  hum.HipHeight = by - (bh * 0.8) / 2
  hum.Parent = m
  Instance.new("Animator").Parent = hum
  m.PrimaryPart = root
  K.attrs(m, { BaseHipHeight = hum.HipHeight, Creature = spec.kind or "bird" })
  return m, hum
end
