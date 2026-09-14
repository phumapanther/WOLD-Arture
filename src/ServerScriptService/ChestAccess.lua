-- ChestAccess: the one way anything outside TreasureChests.server can put a chest in the world.
--
-- Same shape as MobAccess and DayNightAccess, and for the same reason: the admin commands and the item-use
-- handler both need to drop a chest, and neither should have to require the script that owns them. One of
-- the two has to be the shallow one, and it is this.
local ChestAccess = {}

-- Set by TreasureChests.server at startup. Takes (tier, position) and returns true if a chest landed.
-- Left nil in the lobby, where no chests run, so every caller must check before calling.
ChestAccess.Spawn = nil

-- Takes (player, tier) and drops one beside them. Returns false if they have no character to stand near.
ChestAccess.SpawnNear = nil

return ChestAccess
