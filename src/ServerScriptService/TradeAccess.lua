-- TradeAccess: a hand-off from Trading to the prompt that starts a trade.
--
-- The same idea as RescueAccess and ProfileAccess: Trading owns the sessions and the swap, ClassActions
-- owns the proximity prompt, and neither requires the other.
--
-- Empty until Trading has published itself, so callers must cope with nil.
local TradeAccess = {}

-- Invite(actor, target) -> ok, message
TradeAccess.Invite = nil

return TradeAccess
