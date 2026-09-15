-- PlayerJoin: run a join handler for EVERY player, including the ones who were already here.
--
-- Players.PlayerAdded does not fire retroactively, and it never has -- which is fine for a script that is
-- running before anybody can join, and wrong for every script in this game. Each of them requires
-- ServerConfig first, and ServerConfig makes a blocking DataStore call (100-300ms, longer on a bad day) to
-- work out which channel it is. A channel server is a RESERVED server: it is created BECAUSE a player is
-- being teleported into it, so that player can arrive while the scripts are still in their first lines.
--
-- A plain PlayerAdded connection therefore misses exactly the person the server was reserved for. What they
-- see is a character with no saved position, an empty bag, level 1, and no vehicles -- "sometimes my data
-- doesn't load when I join". It is not intermittent for any reason to do with data: it is a race with
-- startup, which is why it happens to the first player in and to nobody else.
--
-- Handlers run in their own thread. Every one of these waits on the profile, and one player's slow DataStore
-- read must not hold up the next player's -- or the rest of the script's own startup.
local Players = game:GetService("Players")

local PlayerJoin = {}

function PlayerJoin.Each(handler)
	-- A player who joins BETWEEN the connection below and the catch-up loop would be handed to both. Once
	-- per player, then, rather than trusting the two to be exclusive -- they are not.
	local seen = {}
	local function once(player)
		if seen[player] then return end
		seen[player] = true
		handler(player)
	end

	Players.PlayerAdded:Connect(function(player) task.spawn(once, player) end)
	Players.PlayerRemoving:Connect(function(player) seen[player] = nil end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(once, player)
	end
end

return PlayerJoin
