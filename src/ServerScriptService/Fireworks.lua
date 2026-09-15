-- Fireworks: a shell goes up, hangs, and bursts.
--
-- Roblox has no firework of its own. What it has is ParticleEmitter and PointLight, which is enough: a
-- small bright ball climbs on a tween, dies at the top, and throws a sphere of sparks that fade on their
-- own. Nothing here is physics -- a real projectile would be shoved around by anything it touched on the
-- way up, and the whole point is that it goes where it was aimed.
--
-- Built on the SERVER so everyone at the party sees the same sky. That costs a little replication for a few
-- seconds, which is the right trade for something the whole server is meant to look at together.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Fireworks = {}

-- The palette a shell picks from. Bright and saturated: a firework washed out by daylight is a grey smear.
local COLOURS = {
	Color3.fromRGB(255, 96, 96),
	Color3.fromRGB(255, 196, 64),
	Color3.fromRGB(120, 220, 255),
	Color3.fromRGB(170, 120, 255),
	Color3.fromRGB(120, 255, 160),
	Color3.fromRGB(255, 130, 220),
}

local FOLDER_NAME = "WOLD_Fireworks"

local function folder()
	local f = workspace:FindFirstChild(FOLDER_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = workspace
	end
	return f
end

-- The shell on its way up: a small glowing ball with a trail of sparks behind it.
local function makeShell(position, colour)
	local shell = Instance.new("Part")
	shell.Name = "Shell"
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.new(1.2, 1.2, 1.2)
	shell.Position = position
	shell.Color = colour
	shell.Material = Enum.Material.Neon
	-- Anchored and non-colliding: it is moved by a tween, and anything that could push it would ruin the
	-- arc. CanQuery off as well, so it never answers somebody else's raycast on the way past.
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.Parent = folder()

	local trail = Instance.new("ParticleEmitter")
	trail.Color = ColorSequence.new(colour)
	trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	trail.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Transparency = NumberSequence.new(0.2)
	trail.Lifetime = NumberRange.new(0.25, 0.45)
	trail.Rate = 90
	trail.Speed = NumberRange.new(1, 3)
	trail.SpreadAngle = Vector2.new(18, 18)
	trail.LightEmission = 1
	trail.Parent = shell

	local glow = Instance.new("PointLight")
	glow.Color = colour
	glow.Brightness = 3
	glow.Range = 18
	glow.Shadows = false
	glow.Parent = shell

	return shell
end

-- The burst: a sphere of sparks thrown outward, and a flash of light that fades with them.
local function burst(position, colour)
	local core = Instance.new("Part")
	core.Name = "Burst"
	core.Size = Vector3.new(1, 1, 1)
	core.Position = position
	core.Transparency = 1
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.Parent = folder()

	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(colour)
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.2),
		NumberSequenceKeypoint.new(0.6, 1.1),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Lifetime = NumberRange.new(1.1, 1.9)
	sparks.Speed = NumberRange.new(38, 62)
	-- Every direction at once, which is what makes it a sphere rather than a fountain.
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.LightEmission = 1
	sparks.Drag = 3.2 -- the sparks slow as they spread, so the shape opens and then hangs
	sparks.Acceleration = Vector3.new(0, -14, 0) -- and then fall
	sparks.Rate = 0
	sparks.Parent = core

	local flash = Instance.new("PointLight")
	flash.Color = colour
	flash.Brightness = 8
	flash.Range = 60
	flash.Shadows = false
	flash.Parent = core

	sparks:Emit(140)
	TweenService:Create(flash, TweenInfo.new(0.8), { Brightness = 0 }):Play()

	-- Long enough for the slowest spark to finish falling. Destroying on the emit would cut the burst in
	-- half -- particles die with the emitter that owns them.
	Debris:AddItem(core, 4)
end

-- Sends one shell up from `origin` and bursts it `height` studs above.
--
-- `delay` staggers a volley so the shells do not all climb in lockstep, which reads as one big firework
-- rather than several.
function Fireworks.Launch(origin, height, colour, startDelay)
	colour = colour or COLOURS[math.random(#COLOURS)]
	height = height or 120

	task.delay(startDelay or 0, function()
		local shell = makeShell(origin, colour)
		local peak = origin + Vector3.new(0, height, 0)

		-- Quad ease-out: fast off the ground and slowing as it rises, which is how a real shell moves and
		-- what makes the pause at the top read as a pause rather than a stall.
		local rise = TweenService:Create(
			shell,
			TweenInfo.new(1.4 + math.random() * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = peak }
		)
		rise:Play()
		rise.Completed:Connect(function()
			local at = shell.Position
			shell:Destroy()
			burst(at, colour)
		end)
	end)
end

-- A ring of shells around `centre`, all of them `radius` studs out.
--
-- The ring is the point: fireworks directly overhead are a bad view -- you look straight up and see the
-- underside of the burst. Standing back from them is what makes a sky worth looking at.
function Fireworks.Ring(centre, radius, count, height)
	count = math.clamp(count or 8, 1, 24)
	radius = radius or 100

	-- Started at a random angle so two volleys from the same spot do not land on the same points.
	local offset = math.random() * math.pi * 2
	for i = 1, count do
		local angle = offset + (i - 1) * (math.pi * 2 / count)
		local at = centre + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

		-- The ground under that spot, so a shell launched over a valley still starts at the valley floor
		-- rather than in mid-air. Falls back to the centre's own height when there is nothing below.
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { folder() }
		params.IgnoreWater = true
		local hit = workspace:Raycast(at + Vector3.new(0, 300, 0), Vector3.new(0, -1200, 0), params)
		local from = hit and Vector3.new(at.X, hit.Position.Y + 2, at.Z) or Vector3.new(at.X, centre.Y, at.Z)

		Fireworks.Launch(from, height, nil, (i - 1) * 0.12)
	end
	return count
end

return Fireworks
