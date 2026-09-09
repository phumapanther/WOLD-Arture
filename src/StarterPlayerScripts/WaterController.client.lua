-- WaterController: swimming, and the muffled world with your head under.
--
-- Three separate things, all driven off two booleans (in water / head submerged):
--   * strokes while swimming, timed the way footsteps are timed while walking
--   * a splash crossing the surface, one going in and one coming out
--   * while submerged: a low rumble, occasional bubbles, and everything else muffled and quiet
--
-- The muffling is what actually sells being underwater -- more than the drone does. It uses
-- SoundService.AmbientReverb, which has an UnderWater preset and applies to every sound in the game at
-- once. The alternative was routing every sound through a SoundGroup, which would have meant editing every
-- place that creates a sound; this needs none of them to know about water.
--
-- Client-side: what your own head is under is not something the server needs to arbitrate.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local SoundscapeConfig = require(game.ReplicatedStorage.SoundscapeConfig)

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local player = Players.LocalPlayer
local Water = SoundscapeConfig.Water

--------------------------------------------------------------------------------
-- Detecting water
--------------------------------------------------------------------------------

-- Swimming comes from the humanoid state; being SUBMERGED does not -- a player can swim along the surface
-- with their head in the air, which should sound completely different from being under. The head's own
-- voxel is what settles it: verified in play that ReadVoxels reports Water below the surface and Air above.
-- Measured in play: a character swimming normally floats with its head almost exactly ON the surface
-- (head y 61.07 against a surface at 61). Testing the head's own voxel therefore reports "underwater" the
-- whole time someone is swimming along the top, which would leave the muffled drone playing constantly and
-- the strokes never heard at all.
--
-- So the test is not "is the head in water" but "is the head far enough BELOW the surface to have gone
-- under" -- the margin below is what separates a normal swim from a dive.
local SUBMERGE_MARGIN = 3

local function isHeadUnderwater(character)
	local head = character:FindFirstChild("Head")
	if not head then return false end
	-- Sample a margin ABOVE the head: if that point is still water, the head is properly under rather than
	-- bobbing at the top. Guarded because ReadVoxels throws outside the terrain's bounds, which happens at
	-- the map edge and while a character is being rebuilt.
	local pos = head.Position + Vector3.new(0, SUBMERGE_MARGIN, 0)
	local region = Region3.new(pos - Vector3.new(2, 2, 2), pos + Vector3.new(2, 2, 2)):ExpandToGrid(4)
	local ok, material = pcall(function()
		return workspace.Terrain:ReadVoxels(region, 4)[1][1][1]
	end)
	return ok and material == Enum.Material.Water
end

--------------------------------------------------------------------------------
-- Sound helpers
--------------------------------------------------------------------------------

local function playOneShot(character, clips, volume, pitch, jitter)
	if not character or not clips or #clips == 0 then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local sound = Instance.new("Sound")
	sound.SoundId = clips[math.random(1, #clips)]
	sound.Volume = volume
	if pitch then
		sound.PlaybackSpeed = pitch + (math.random() * 2 - 1) * (jitter or 0)
	end
	sound.Parent = root
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 4)
end

-- The submerged drone and the muffling both live on the listener, not on a part: they are what the world
-- sounds like from where you are, not a noise coming from somewhere.
local submerged = Instance.new("Sound")
submerged.Name = "WOLD_Submerged"
submerged.SoundId = Water.SubmergedAmbience
submerged.Looped = true
submerged.Volume = 0
submerged.Parent = SoundService
submerged:Play()

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local wasSwimming = false
local wasSubmerged = false
local sinceStroke = 0
local nextBubbleAt = 0

-- Remembered so the reverb is only written when it actually changes, and so the original is restored rather
-- than assumed to be NoReverb.
local normalReverb = SoundService.AmbientReverb

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		-- Dying underwater must not leave the world muffled through the respawn.
		if wasSubmerged then
			SoundService.AmbientReverb = normalReverb
			workspace:SetAttribute("WOLD_Submerged", false)
			wasSubmerged = false
		end
		submerged.Volume = 0
		wasSwimming = false
		return
	end

	local swimming = humanoid:GetState() == Enum.HumanoidStateType.Swimming
	local under = swimming and isHeadUnderwater(character)

	-- Crossing the surface, either way.
	if swimming and not wasSwimming then
		playOneShot(character, Water.EnterSounds, Water.EnterVolume)
	elseif not swimming and wasSwimming then
		playOneShot(character, Water.ExitSounds, Water.ExitVolume)
	end
	wasSwimming = swimming

	-- Head going under or coming up. Muffling everything else is done once on the transition rather than
	-- every frame: writing the same reverb repeatedly would be pointless work.
	if under ~= wasSubmerged then
		SoundService.AmbientReverb = under and Enum.ReverbType.UnderWater or normalReverb
		-- Published for AmbienceController, which ducks the surface layers rather than sampling the
		-- terrain a second time on its own schedule. A local attribute: this is the local head.
		workspace:SetAttribute("WOLD_Submerged", under)
		wasSubmerged = under
		if under then
			-- Randomised so the first breath bubble does not always arrive at the same beat.
			nextBubbleAt = os.clock() + math.random() *
				(Water.BubbleIntervalMax - Water.BubbleIntervalMin) + Water.BubbleIntervalMin
		end
	end

	-- The drone swells and fades rather than clicking on, so bobbing up for air sounds like surfacing.
	local target = under and Water.SubmergedVolume or 0
	local step = dt / Water.SurfaceFadeSeconds * Water.SubmergedVolume
	if submerged.Volume < target then
		submerged.Volume = math.min(target, submerged.Volume + step)
	elseif submerged.Volume > target then
		submerged.Volume = math.max(target, submerged.Volume - step)
	end

	if under then
		-- Breath bubbles, on a randomised timer.
		if os.clock() >= nextBubbleAt then
			playOneShot(character, Water.BubbleSounds, Water.BubbleVolume)
			nextBubbleAt = os.clock() + math.random() *
				(Water.BubbleIntervalMax - Water.BubbleIntervalMin) + Water.BubbleIntervalMin
		end
		-- No strokes while under: the arms are still moving, but a surface splash heard from below is wrong.
		sinceStroke = 0
		return
	end

	-- Strokes, only while actually moving through the water. Treading water in place should be quiet.
	if not swimming then
		sinceStroke = 0
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local speed = root and root.AssemblyLinearVelocity.Magnitude or 0
	if speed < SoundscapeConfig.MinStepSpeed then
		sinceStroke = 0
		return
	end

	sinceStroke += dt
	if sinceStroke >= Water.StrokeInterval then
		sinceStroke = 0
		playOneShot(character, Water.Strokes, Water.StrokeVolume, Water.StrokePitch, Water.StrokePitchJitter)
	end
end)
