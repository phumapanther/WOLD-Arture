-- WeatherAccess: the one way anything outside Weather.server.lua can change the sky.
--
-- Same shape as DayNightAccess, and for the same reason: the admin command must be able to force a storm
-- without requiring the script that runs the weather, and the weather must stay free of any dependency on
-- the admin system.
local WeatherAccess = {}

-- Set by Weather.server at startup. Takes (kindId) -- a kind to hold the sky at, or nil to let it roll
-- again -- and returns the kind now in force. nil in the lobby, where no weather runs, so callers must check.
WeatherAccess.Set = nil

-- Reads back the weather now, as a kind id.
WeatherAccess.Current = nil

return WeatherAccess
