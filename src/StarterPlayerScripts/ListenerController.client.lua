-- ListenerController: hears from where the CHARACTER is, not from where the camera is.
--
-- Roblox listens from the camera by default. In a third-person game that is wrong in a way that gets worse
-- the further you zoom out: the ear drifts backwards away from the body, so a conversation the player is
-- standing in the middle of goes quiet simply because they pulled the camera back to look around. Proximity
-- voice chat measures its falloff from the listener, so zooming out was muting the people next to you.
--
-- Pointing the listener at the character's head fixes both halves: voices fade with how far away someone is
-- FROM YOU, and world sounds are heard from where you are standing.
--
-- The head rather than the root part, because that is where ears are -- it is about two studs higher, which
-- is small but free, and it means a sound at head height is heard at full strength rather than slightly off.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

local function listenFrom(character)
	if not character then return end
	-- Head first; HumanoidRootPart is the fallback for a rig that has not finished assembling, and for any
	-- future rig that does not have a part called Head.
	local ear = character:WaitForChild("Head", 10) or character:FindFirstChild("HumanoidRootPart")
	if not ear then return end
	SoundService:SetListener(Enum.ListenerType.ObjectPosition, ear)
end

-- ObjectPosition rather than ObjectCFrame: position decides what you can HEAR, and CFrame would also turn
-- the stereo field with the head. A character's head swings around as they walk and look, and tying left
-- and right to it makes sounds slide across the player's ears for no reason they can see. Direction still
-- comes from the camera, which is where the player is actually looking.

if player.Character then
	listenFrom(player.Character)
end
player.CharacterAdded:Connect(listenFrom)
