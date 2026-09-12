-- ServerConfig.lua: require this once; it does the (blocking, ~100-300ms) self-identification DataStore call up front
-- so every other server script sees a fully-populated table with no race.
local ChannelRegistry = require(script.Parent.Lobby.ChannelRegistry)

-- ponytail: Studio Play is ALWAYS the lobby (PrivateServerId is empty there), so every channel-only system —
-- vitals, the downed state, the HUD — is switched off and can't be tested without publishing. Flip this to
-- pretend Play is a channel server. Flip it back before publishing, or the real lobby will run gameplay.
local FORCE_CHANNEL_IN_STUDIO_FOR_TESTING = false

local ServerConfig = {}
ServerConfig.IsLobby = game.PrivateServerId == ""
if FORCE_CHANNEL_IN_STUDIO_FOR_TESTING and game:GetService("RunService"):IsStudio() then
	ServerConfig.IsLobby = false
end
if ServerConfig.IsLobby then
	ServerConfig.Mode = nil
	ServerConfig.Channel = nil
elseif FORCE_CHANNEL_IN_STUDIO_FOR_TESTING and game:GetService("RunService"):IsStudio() then
	-- There is no reserved server behind this fake channel, so skip the registry lookup it would fail.
	ServerConfig.Mode, ServerConfig.Channel = "Studio", 0
else
	ServerConfig.Mode, ServerConfig.Channel = ChannelRegistry.IdentifySelf()
end

-- game.PrivateServerId cannot be read from LocalScripts at all ("PrivateServerId cannot be checked on the
-- client") — replicate the one bit clients actually need via a Workspace Attribute, which replicates automatically.
workspace:SetAttribute("IsLobby", ServerConfig.IsLobby)

-- Printed once, from the module every server script requires before anything else, so the first line in a
-- server's log says which build is running and which half of the game it is. Worth its own line now that
-- there are real players: a bug report that begins "it happened in the lobby on V1" is a different bug from
-- the same words about a channel server.
local GameVersion = require(game.ReplicatedStorage.GameVersion)
ServerConfig.Version = GameVersion.Number
print(("[WOLD] %s (%s) -- %s"):format(GameVersion.Label(), GameVersion.Number,
	ServerConfig.IsLobby and "ล็อบบี้" or ("ช่อง " .. tostring(ServerConfig.Channel))))

return ServerConfig
