-- HudAccess: a hand-off between the HUD and the other client screens that need to reach it.
--
-- The same idea as ProfileAccess on the server, for the same reason: the bag needs to know where the
-- hotbar is on screen to finish a drag onto it, and the HUD must not have to know the bag exists. Neither
-- controller requires the other; HudController publishes its GUI here, and anyone who needs it asks.
--
-- Empty until the HUD has built itself, so every caller must cope with nil -- in the lobby it is never set
-- at all.
local HudAccess = {}

local hud = nil

function HudAccess.Set(gui)
	hud = gui
end

function HudAccess.Get()
	return hud
end

return HudAccess
