-- WeatherController: draws whatever the server says the sky is doing.
--
-- Everything here is LOCAL and cosmetic. The lighting half of weather is applied on the server inside
-- DayNight and replicates on its own; what cannot replicate is the part that has to follow one camera --
-- rain falling around you, grit on your lens, a lightning flash. Those are drawn here, at this player's
-- camera, and cost nothing on anyone else's machine.
--
-- The particle emitter rides an invisible part parented to the camera rather than to the character: it
-- should keep snowing while you are dead, spectating, or sitting in a vehicle.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Remotes = require(game.ReplicatedStorage.Remotes)
local WeatherConfig = require(game.ReplicatedStorage.WeatherConfig)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

--------------------------------------------------------------------------------
-- The emitter that follows the camera
--------------------------------------------------------------------------------

local rig = Instance.new("Part")
rig.Name = "WOLD_WeatherRig"
rig.Anchored = true
rig.CanCollide = false
rig.CanQuery = false
rig.CanTouch = false
rig.Transparency = 1
rig.Size = Vector3.new(60, 1, 60)
rig.Parent = camera

local emitter = Instance.new("ParticleEmitter")
emitter.Enabled = false
emitter.Parent = rig

-- How each kind of falling thing looks. Values rather than assets: a rain streak is a thin white sliver and
-- a snowflake is a slow round dot, and both are cheaper to describe than to download.
local PARTICLES = {
	rain = {
		texture = "rbxasset://textures/particles/sparkles_main.dds",
		colour = Color3.fromRGB(190, 205, 225),
		size = NumberSequence.new(0.16),
		transparency = NumberSequence.new(0.35),
		rate = 420,
		speed = NumberRange.new(95, 120),
		lifetime = NumberRange.new(0.55, 0.75),
		squash = 7, -- stretched into a streak by its own speed
	},
	snow = {
		texture = "rbxasset://textures/particles/sparkles_main.dds",
		colour = Color3.fromRGB(245, 250, 255),
		size = NumberSequence.new(0.32),
		transparency = NumberSequence.new(0.2),
		rate = 220,
		speed = NumberRange.new(9, 16),
		lifetime = NumberRange.new(2.4, 3.4),
		squash = 1,
	},
	sand = {
		texture = "rbxasset://textures/particles/smoke_main.dds",
		colour = Color3.fromRGB(214, 178, 112),
		size = NumberSequence.new(3.2),
		transparency = NumberSequence.new(0.55),
		rate = 90,
		speed = NumberRange.new(55, 80),
		lifetime = NumberRange.new(1.2, 1.8),
		squash = 1,
		-- Sand blows sideways rather than falling: the whole point of a sandstorm is that it is weather with
		-- a direction.
		sideways = true,
	},
}

local function setParticles(kindName)
	local spec = kindName and PARTICLES[kindName]
	if not spec then
		emitter.Enabled = false
		return
	end
	emitter.Texture = spec.texture
	emitter.Color = ColorSequence.new(spec.colour)
	emitter.Size = spec.size
	emitter.Transparency = spec.transparency
	emitter.Rate = spec.rate
	emitter.Speed = spec.speed
	emitter.Lifetime = spec.lifetime
	emitter.SpreadAngle = Vector2.new(14, 14)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.LightEmission = 0.25
	emitter.SquashY = spec.squash or 1
	-- Straight down, or sideways for sand. EmissionDirection is in the rig's own space, and the rig is kept
	-- level below, so "down" stays down however the camera is tilted.
	emitter.Acceleration = spec.sideways and Vector3.new(0, -30, 0) or Vector3.new(0, -80, 0)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Enabled = true
end

--------------------------------------------------------------------------------
-- The lens: rain on the screen, grit in the air
--------------------------------------------------------------------------------

local screen = Instance.new("ScreenGui")
screen.Name = "WeatherScreen"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
-- Under every real interface: this is atmosphere, and it must never sit on top of a button.
screen.DisplayOrder = -5
screen.Parent = player:WaitForChild("PlayerGui")

local wet = Instance.new("ImageLabel")
wet.Size = UDim2.fromScale(1, 1)
wet.BackgroundTransparency = 1
wet.Image = "rbxasset://textures/particles/smoke_main.dds"
wet.ImageTransparency = 1
wet.ScaleType = Enum.ScaleType.Tile
wet.TileSize = UDim2.fromOffset(256, 256)
wet.ImageColor3 = Color3.fromRGB(180, 200, 225)
wet.Parent = screen

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = screen

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local currentKind = WeatherConfig.Default
local nextLightningAt = nil

local function applyKind(kindId)
	local kind = WeatherConfig.Kinds[kindId]
	if not kind then return end
	currentKind = kindId

	setParticles(kind.particles)

	-- The lens, eased rather than snapped.
	local target = 1 - (kind.wetScreen or 0)
	if kind.wetScreen then
		wet.ImageColor3 = kind.tint or Color3.fromRGB(180, 200, 225)
	end
	TweenService:Create(wet, TweenInfo.new(2), { ImageTransparency = target }):Play()

	if kind.lightning then
		nextLightningAt = os.clock() + math.random(kind.lightning.everyMin, kind.lightning.everyMax)
	else
		nextLightningAt = nil
	end
end

-- The server sends the kind now, the kind arriving, and how far along. The particles switch to the incoming
-- kind as soon as it is announced -- rain that starts as a trickle reads better than rain that appears at
-- full strength once the lighting has finished changing.
Remotes.WeatherChanged.OnClientEvent:Connect(function(current, incoming, blend)
	applyKind(incoming or current)
end)

--------------------------------------------------------------------------------
-- Per-frame: keep the rig over the camera, and run the lightning
--------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function()
	camera = workspace.CurrentCamera
	if rig.Parent ~= camera then rig.Parent = camera end

	-- Level, and above the camera, so the fall direction never tips with the view.
	rig.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 28, 0))

	if nextLightningAt and os.clock() >= nextLightningAt then
		local kind = WeatherConfig.Kinds[currentKind]
		local spec = kind and kind.lightning
		if spec then
			nextLightningAt = os.clock() + math.random(spec.everyMin, spec.everyMax)
			-- Two quick tweens rather than one: a strike is a snap to white and a slower fade out.
			flash.BackgroundTransparency = 0.55
			TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		else
			nextLightningAt = nil
		end
	end
end)
