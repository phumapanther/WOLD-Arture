-- RescueAccess: a hand-off from PlayerRescue to the systems that need to start a carry.
--
-- The same idea as ProfileAccess: PlayerRescue owns the joint, the collision group and the network
-- ownership that carrying needs, and ClassActions must be able to start one after its consent prompt has
-- been answered -- without either file requiring the other, and without a second copy of that setup.
--
-- Empty until PlayerRescue has published itself, so every caller must cope with nil; in the lobby it is
-- never set at all.
local RescueAccess = {}

-- BeginCarry(carrier, target, consented) -> boolean
-- `consented` lifts the requirement that the target be downed, and only that.
RescueAccess.BeginCarry = nil

return RescueAccess
