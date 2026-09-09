-- ArrestAccess: a hand-off from Arrest to the prompt that starts one.
--
-- The same idea as RescueAccess and TradeAccess: Arrest owns the sessions and the hold, ClassActions owns
-- the proximity prompt, and neither requires the other.
--
-- Empty until Arrest has published itself, so callers must cope with nil.
local ArrestAccess = {}

-- Begin(guard, target) -> ok, message
ArrestAccess.Begin = nil

return ArrestAccess
