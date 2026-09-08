-- PlayerRoles.server.lua: loads each player's role from their profile and publishes the serializer that
-- saves it back. Mirrors PlayerProgression/PlayerInventory so all three lifecycles read the same way.
--
-- The role does nothing yet -- the Guard/Priest/Architect abilities are phase 4. This exists now so the
-- admin commands can hand a role out and have it survive a rejoin without a later data migration.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Roles = require(game.ServerScriptService.Roles)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)

if ServerConfig.IsLobby then return end

-- PlayerProfile calls this when it saves; publishing it here keeps the profile system free of any dependency
-- on roles.
ProfileAccess.SerializeRole = Roles.Serialize

local function load(player)
	-- Wait briefly for the profile session, so a returning player keeps their role rather than appearing
	-- with none. If it never arrives (a failed load) they start with no role, which is the safe direction.
	local saved
	for _ = 1, 40 do
		local data = ProfileAccess.Get(player)
		if data then
			saved = data.Role
			break
		end
		task.wait(0.1)
	end
	Roles.Add(player, saved)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(load, player)
	-- The attribute lives on the Player, not the character, so it survives respawns and needs no re-applying.
end)

Players.PlayerRemoving:Connect(function(player)
	Roles.Remove(player)
end)

-- Anyone already here when this starts (Studio Play, a hot reload).
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(load, player)
end
