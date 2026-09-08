-- ProfileAccess: a tiny hand-off between PlayerProfile (which owns the DataStore session) and the systems
-- that need to read or contribute to the saved data.
--
-- It exists to keep those systems from requiring each other in a cycle: PlayerProfile must be able to save
-- Progression's level without depending on a channel-only module, and Progression must be able to read the
-- saved level without depending on the profile lifecycle.
local ProfileAccess = {}

local Data = {} -- [player] = profile.Data, only while the session is live

function ProfileAccess.Set(player, data)
	Data[player] = data
end

function ProfileAccess.Get(player)
	return Data[player]
end

-- Set by Progression at startup: PlayerProfile calls this when saving. nil in the lobby, where no progression
-- system runs and there is nothing to save.
ProfileAccess.SerializeProgression = nil
ProfileAccess.SerializeInventory = nil

-- Set by PlayerProfile: copies a player's current level and bag into their profile immediately, rather than
-- waiting for the next autosave tick. Call it after anything worth keeping.
ProfileAccess.Flush = nil

return ProfileAccess
