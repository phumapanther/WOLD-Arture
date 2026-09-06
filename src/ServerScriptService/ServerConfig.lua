-- ServerConfig.lua: require this once; it does the (blocking, ~100-300ms) self-identification DataStore call up front
-- so every other server script sees a fully-populated table with no race.
local ChannelRegistry = require(script.Parent.Lobby.ChannelRegistry)

local ServerConfig = {}
ServerConfig.IsLobby = game.PrivateServerId == ""
if ServerConfig.IsLobby then
	ServerConfig.Mode = nil
	ServerConfig.Channel = nil
else
	ServerConfig.Mode, ServerConfig.Channel = ChannelRegistry.IdentifySelf()
end

return ServerConfig
