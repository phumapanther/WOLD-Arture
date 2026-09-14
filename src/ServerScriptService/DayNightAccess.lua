-- DayNightAccess: the one way anything outside DayNight.server.lua can touch the world clock.
--
-- Same shape as MobAccess and RescueAccess, and for the same reason: AdminCommands must be able to stop the
-- sun without requiring the script that runs it, and DayNight must stay free of any dependency on the admin
-- system. One of the two has to be the shallow one, and it is this.
local DayNightAccess = {}

-- Set by DayNight.server.lua at startup. Takes (hour) -- a number to hold the clock at, or nil to let it run
-- again -- and returns the hour now in force. nil in the lobby, where no clock runs, so callers must check.
DayNightAccess.Hold = nil

-- Reads back the held hour, or nil when the clock is running normally.
DayNightAccess.HeldAt = nil

-- Set by DayNight.server at startup. Takes a function returning (weatherKindId, blend) and is called every
-- time the clock rewrites Lighting, which is the only place weather can be applied without being erased a
-- quarter of a second later. nil in the lobby.
DayNightAccess.SetWeatherSource = nil

return DayNightAccess
