-- FishingAccess: the hand-off between the combat system, which knows a player clicked, and the fishing
-- system, which knows what a fishing rod does with a click.
--
-- Same shape as MobAccess and ProfileAccess: PlayerCombat must be able to say "this swing was a cast"
-- without requiring Fishing.server, and Fishing.server needs to require the combat config. One of them has
-- to be the shallow one.
local FishingAccess = {}

-- Set by Fishing.server at startup. Takes (player) and returns true if the swing was consumed as a cast,
-- in which case combat should not also resolve it as an attack. Left nil in the lobby, where no fishing
-- runs -- every caller must check before calling.
FishingAccess.TryCast = nil

-- Set by Fishing.server. Returns true while the player is fishing, so other systems can stop it: walking
-- off, being downed, or unequipping the rod all end a session.
FishingAccess.IsFishing = nil
FishingAccess.Stop = nil

return FishingAccess
