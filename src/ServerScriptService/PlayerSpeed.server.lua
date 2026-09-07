-- PlayerSpeed: default WalkSpeed at 50% of Roblox's default (16 -> 8), prep for upcoming movement animations
-- (walk/run/sprint states are tuned relative to this baseline). Applies in every server, every character spawn.
local Players = game:GetService("Players")

local SPEED = 8

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = SPEED
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then onCharacterAdded(player.Character) end
end)
