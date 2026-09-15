-- EmoteAccess: the hand-off between whatever asks for a pose and the controller that plays it.
--
-- Same shape as HudAccess and AimAccess, and for the same reason: the picker on the speaking stone and the
-- admin console both want to start an emote, and neither should have to reach into another client script to
-- do it. EmoteController fills these in at start-up.
--
-- Client-only. Nothing here is ever set on the server.
local EmoteAccess = {}

-- Play(id) -> ok, message. Asking for the pose already running stops it instead.
EmoteAccess.Play = function() return false, "ระบบท่าทางยังไม่พร้อม" end
EmoteAccess.Stop = function() end
EmoteAccess.Current = function() return nil end

return EmoteAccess
