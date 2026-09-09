-- FootstepController: the sound of walking on things.
--
-- Roblox ships exactly one footstep sound and plays it on every surface, so stone, sand and grass all sound
-- identical by default. This picks a sound from the material underfoot instead.
--
-- Split of work: this client times its OWN player's steps and reports each one to the server, which relays
-- it to everyone else. Timing locally is what makes it accurate -- the client already knows its material
-- and its speed on the frame it needs them, with no replication lag -- and relaying is what makes other
-- players audible. Playing another player's step is just "make a noise at that character", so the same
-- playback path serves both.
--
-- Nothing here is authoritative: a modified client can at worst make its own footsteps sound wrong.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundscapeConfig = require(game.ReplicatedStorage.SoundscapeConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local player = Players.LocalPlayer

--------------------------------------------------------------------------------
-- Playback
--------------------------------------------------------------------------------

-- Which sound set a material belongs to. Cobblestone is called out separately from the rest of the stone
-- group: a cobbled street is loose stone underfoot, and the gravel set sells that far better than the
-- poured-concrete one.
local function groupFor(material, inWater)
	if inWater then return SoundscapeConfig.WaterGroup end
	if material == Enum.Material.Cobblestone then return "Gravel" end
	return SoundscapeConfig.MaterialGroups[material] or SoundscapeConfig.DefaultGroup
end

local function playStep(character, group)
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local clips = SoundscapeConfig.Footsteps[group] or SoundscapeConfig.Footsteps[SoundscapeConfig.DefaultGroup]
	if not clips or #clips == 0 then return end

	local sound = Instance.new("Sound")
	sound.SoundId = clips[math.random(1, #clips)]
	sound.Volume = SoundscapeConfig.FootstepVolume
	sound.RollOffMaxDistance = SoundscapeConfig.FootstepDistance
	-- Random pitch per step. Four clips still repeat every fourth step, which the ear picks up as a pattern;
	-- a few percent of jitter is what stops a walk sounding like a metronome.
	local jitter = SoundscapeConfig.FootstepPitchJitter
	sound.PlaybackSpeed = 1 + (math.random() * 2 - 1) * jitter
	sound.Parent = root
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 2)
end

--------------------------------------------------------------------------------
-- Timing this player's own steps
--------------------------------------------------------------------------------

-- The engine has no "foot planted" signal, so steps are timed from how fast the character is travelling.
-- The gait thresholds mirror the speeds PlayerMovement sets (walk 4 / normal 8 / run 16).
local function stepInterval(speed)
	if speed >= 13 then return SoundscapeConfig.StepIntervalRun end
	if speed >= 6 then return SoundscapeConfig.StepIntervalNormal end
	return SoundscapeConfig.StepIntervalWalk
end

local sinceStep = 0

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		sinceStep = 0
		return
	end

	-- Airborne means no ground to hit. Checking FloorMaterial rather than the humanoid state for the same
	-- reason the fall damage does: mid-jump the state flickers back to Running for a frame or two.
	local material = humanoid.FloorMaterial
	local swimming = humanoid:GetState() == Enum.HumanoidStateType.Swimming
	if material == Enum.Material.Air and not swimming then
		-- Reset rather than accumulate, so landing plays a step promptly instead of after a leftover
		-- fraction of an interval.
		sinceStep = 0
		return
	end

	-- Horizontal speed only: falling should not tick off footsteps.
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if speed < SoundscapeConfig.MinStepSpeed then
		sinceStep = 0
		return
	end

	sinceStep += dt
	if sinceStep < stepInterval(speed) then return end
	sinceStep = 0

	-- Water underfoot beats whatever the riverbed is made of: wading should sound wet.
	local group = groupFor(material, swimming or material == Enum.Material.Water)
	playStep(character, group)
	Remotes.Footstep:FireServer(group)
end)

--------------------------------------------------------------------------------
-- Everyone else's steps
--------------------------------------------------------------------------------

Remotes.Footstep.OnClientEvent:Connect(function(other, group)
	-- The server never echoes a step back to its author, but guard anyway rather than depend on that.
	if other == player then return end
	playStep(other and other.Character, group)
end)
