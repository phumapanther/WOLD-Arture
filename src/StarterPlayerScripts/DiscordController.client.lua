-- DiscordController: opens the invite panel when the town sign is pressed.
--
-- The panel is built once and kept, because it holds nothing that goes stale -- the address comes from the
-- shared config, and rebuilding it per press would only cost instances.
local Remotes = require(game.ReplicatedStorage.Remotes)
local SocialConfig = require(game.ReplicatedStorage.SocialConfig)
local DiscordGui = require(game.ReplicatedStorage.UI.DiscordGui)

local gui = DiscordGui.new(SocialConfig.DiscordInvite)

Remotes.ShowDiscord.OnClientEvent:Connect(function()
	gui:Show()
end)
