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

	-- The sparks. Big, bright, and they HANG: heavy drag kills most of the outward speed within the first
	-- half second, so the sphere snaps open and then just sits there glowing for a second or two before it
	-- starts to fall. That pause is the whole look -- without it the burst is a flicker.
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(colour)
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3.4),
		NumberSequenceKeypoint.new(0.15, 2.8),
		-- Still nearly full size at 70% of its life: it fades out rather than shrinking away, which is what
		-- keeps the shape readable while it hangs.
		NumberSequenceKeypoint.new(0.7, 2.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.75, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	-- 2.4-3.2s alive, of which the middle 1-2 is the hang. The user asked for it to hold; a lifetime shorter
	-- than the drag takes to bite would fade before the shape ever stopped moving.
	sparks.Lifetime = NumberRange.new(2.4, 3.2)
	sparks.Speed = NumberRange.new(55, 95)
	-- Every direction at once, which is what makes it a sphere rather than a fountain.
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	-- High drag is what buys the hang: the sparks fly out hard, then stop almost dead.
	sparks.Drag = 6
	-- Gentle gravity, so they drift down at the end instead of dropping out of the sky.
	sparks.Acceleration = Vector3.new(0, -7, 0)
	sparks.Rate = 0
	sparks.Parent = core

	-- A second, finer layer thrown further and faster: the long streaks that trail past the main sphere and
	-- make the burst read as a BANG rather than a puff.
	local streaks = Instance.new("ParticleEmitter")
	streaks.Color = ColorSequence.new(colour)
	streaks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	streaks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	streaks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	streaks.Lifetime = NumberRange.new(1.4, 2.2)
	streaks.Speed = NumberRange.new(110, 170)
	streaks.SpreadAngle = Vector2.new(180, 180)
	streaks.LightEmission = 1
	streaks.LightInfluence = 0
	streaks.Drag = 3
	streaks.Acceleration = Vector3.new(0, -12, 0)
	-- Stretched along their own travel, which is what turns a dot into a streak.
	streaks.SquashY = 4
	streaks.Rate = 0
	streaks.Parent = core

	-- The flash: a hard white core for a fraction of a second, the "ตู้ม".
	local pop = Instance.new("Part")
	pop.Name = "Flash"
	pop.Shape = Enum.PartType.Ball
	pop.Size = Vector3.new(3, 3, 3)
	pop.Position = position
	pop.Color = Color3.new(1, 1, 1)
	pop.Material = Enum.Material.Neon
	pop.Anchored = true
	pop.CanCollide = false
	pop.CanQuery = false
	pop.CanTouch = false
	pop.Parent = folder()
	TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(26, 26, 26),
		Transparency = 1,
	}):Play()
	Debris:AddItem(pop, 0.6)

	local flash = Instance.new("PointLight")
	flash.Color = colour
	flash.Brightness = 14
	flash.Range = 90
	flash.Shadows = false
	flash.Parent = core

	sparks:Emit(180)
	streaks:Emit(70)
	-- The light holds for a beat before it goes, so the sky stays lit while the sparks hang rather than
	-- going dark the instant they stop moving.
	TweenService:Create(flash, TweenInfo.new(0.25), { Brightness = 6 }):Play()
	task.delay(0.25, function()
		if flash.Parent then
			TweenService:Create(flash, TweenInfo.new(1.6), { Brightness = 0 }):Play()
		end
	end)

	-- Long enough for the slowest spark to finish falling. Destroying on the emit would cut the burst in
	-- half -- particles die with the emitter that owns them.
	Debris:AddItem(core, 6)
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
		-- The climb varies by a few tenths even when a volley launches together, so the bursts arrive as a
		-- ripple of bangs rather than one flat crack.
		local rise = TweenService:Create(
			shell,
			TweenInfo.new(1.3 + math.random() * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
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

-- Ground under (x, z), for a shell that has to start from the floor rather than mid-air.
local function groundUnder(x, z, fallbackY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder() }
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -1200, 0), params)
	return hit and hit.Position.Y + 2 or fallbackY
end

-- One shell at a named spot on the map. `at` is where it LAUNCHES FROM; it bursts `height` above that.
--
-- Takes x/z and finds its own ground, so an admin typing a coordinate does not have to know the terrain
-- height there -- the same rule the vehicle stations follow.
function Fireworks.At(x, z, height, fallbackY, colour)
	local from = Vector3.new(x, groundUnder(x, z, fallbackY or 0), z)
	Fireworks.Launch(from, height, colour, 0)
	return from
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
		local from = Vector3.new(at.X, groundUnder(at.X, at.Z, centre.Y), at.Z)

		-- All at once, per the user: a New Year volley is a wall of bangs, not a queue. A tiny jitter on the
		-- height is what keeps them from bursting on one flat plane like a row of streetlights.
		Fireworks.Launch(from, height + math.random(-14, 14), nil, 0)
	end
	return count
end

return Fireworks
