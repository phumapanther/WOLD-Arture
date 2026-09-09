-- AimAccess: a hand-off from the crosshair to whatever needs to know where it is pointing.
--
-- The same idea as HudAccess: AimController owns the camera ray, CombatController owns the click, and
-- neither requires the other.
--
-- Empty until AimController has published itself, so callers must cope with nil -- in the lobby it is never
-- set at all.
local AimAccess = {}

-- Point() -> Vector3, the world point under the middle of the screen.
AimAccess.Point = nil

return AimAccess
