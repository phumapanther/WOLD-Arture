-- MobAccess: the hand-off between the combat system (which knows how a hit was made) and the monster
-- system (which knows what a monster is).
--
-- Exists for the same reason ProfileAccess and RescueAccess do: PlayerCombat must be able to damage a
-- monster without requiring Mobs.server, and Mobs.server must be free to require the combat config. One
-- of them has to be the shallow one, and it is this.
local MobAccess = {}

-- Set by Mobs.server at startup. Takes (model, damage, attacker) and returns true if the model really was
-- a live monster, so the caller knows whether to play a hit sound. Left nil in the lobby, where no
-- monsters run -- every caller must check before calling.
MobAccess.Damage = nil

return MobAccess
